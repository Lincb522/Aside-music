// AudioRenderer.swift
// FFmpegSwiftSDK
//
// Renders decoded audio PCM data to the system audio device using AVAudioEngine.
// Uses AVAudioSourceNode as the data provider, reading from a thread-safe buffer queue.
// The FFmpeg decode thread enqueues buffers; AVAudioSourceNode's render block pulls them.

import Foundation
import AudioToolbox
import AVFoundation

/// Renders PCM audio data to the system audio output device.
///
/// `AudioRenderer` uses AVAudioEngine with an AVAudioSourceNode to output audio.
/// Audio data is enqueued via `enqueue(_:)` and pulled by the source node render block.
///
/// Lifecycle: `start(format:)` → `pause()` / `resume()` → `stop()`
///
/// Thread safety: The internal buffer queue is protected by `os_unfair_lock`, allowing
/// concurrent enqueue (from the decode thread) and dequeue (from the render block).
final class AudioRenderer {
    /// Give the render thread more slack to survive transient CPU spikes from
    /// system UI and third-party keyboard extensions without audible underruns.
    private static let recommendedIOBufferDuration: TimeInterval = 1024.0 / 44_100.0

    // MARK: - AVAudioEngine

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // MARK: - Properties

    /// Lock protecting the buffer queue.
    private var bufferLock = os_unfair_lock_s()
    /// Tracks render-thread underrun observations so callers can wait for
    /// the source node to actually ask for silence after queued PCM drains.
    private var renderObservationLock = os_unfair_lock_s()
    private var underrunSerial: UInt64 = 0

    /// Serializes start/stop lifecycle to prevent concurrent engine disposal.
    private let lifecycleLock = NSLock()
    private let maintenanceQueue = DispatchQueue(label: "FFmpegSwiftSDK.AudioRenderer.maintenance", qos: .userInitiated)

    /// Optional EQ filter applied in real-time during the render block.
    private var eqFilter: EQFilter?

    /// Optional FFmpeg avfilter audio filter graph (loudnorm, atempo, volume).
    private var audioFilterGraph: AudioFilterGraph?

    /// Optional spectrum analyzer.
    private var spectrumAnalyzer: SpectrumAnalyzer?

    /// Optional audio repair engine (after all effects, before output).
    private var repairEngine: AudioRepairEngine?

    /// Optional audio data callback for real-time analysis.
    var onAudioData: ((_ samples: UnsafePointer<Float>, _ frameCount: Int, _ channelCount: Int, _ sampleRate: Int) -> Void)?

    /// Sample rate of the PCM buffers consumed by the source node.
    private var sampleRate: Int = 44100

    /// Number of channels in the current audio stream.
    private var channelCount: Int = 2

    /// FIFO queue of PCM audio buffers waiting to be rendered.
    /// Use a head index instead of `removeFirst()` so the real-time render callback
    /// never has to memmove the remaining queue contents.
    private var bufferQueue: [AudioBuffer?] = []
    private var bufferQueueHead: Int = 0

    /// Tracks the read offset (in samples) into the front buffer of the queue.
    private var currentBufferOffset: Int = 0
    private var pendingBufferDeallocations: [UnsafeMutablePointer<Float>] = []
    private var pendingDeallocationDrainScheduled = false

    /// Pre-allocated interleaved scratch buffer for the render block.
    /// Avoids per-callback malloc/free on the real-time audio thread.
    private var interleavedScratch: UnsafeMutablePointer<Float>?
    private var interleavedScratchCapacity: Int = 0
    
    /// 上一帧最终输出的每声道末尾采样，用于断粮时平滑缓降到静音，避免 click/pop。
    private var lastFrameSamples: UnsafeMutablePointer<Float>?

    /// PCM 样本级不连续检测阈值：相邻回调边界的振幅差超过此值时自动 crossfade。
    /// 0.8 足以捕获 TCP 断流重连后的解码垃圾帧（接近满量程阶跃），
    /// 同时不会误触正常音乐波形（即使最强的瞬态也很少超过 0.8）。
    private let discontinuityThreshold: Float = 0.8
    /// 不连续 crossfade 的样本数（每声道），~2.9ms at 44.1kHz
    private let discontinuityCrossfadeSamples = 128

    /// Whether the renderer is currently started.
    private var isStarted: Bool = false
    
    /// Delays the final hard stop so the render callback can output one short fade-out tail first.
    private var gracefulStopWorkItem: DispatchWorkItem?

    /// Set to `true` before tearing down so the render block outputs silence.
    private var _isStopping = false
    private var stopLock = os_unfair_lock_s()

    fileprivate var isStopping: Bool {
        os_unfair_lock_lock(&stopLock)
        let val = _isStopping
        os_unfair_lock_unlock(&stopLock)
        return val
    }

    private func setStopping(_ value: Bool) {
        os_unfair_lock_lock(&stopLock)
        _isStopping = value
        os_unfair_lock_unlock(&stopLock)
    }

    /// Renderer input sample rate (also used as the decoder output target).
    private(set) var actualSampleRate: Int = 0

    /// Current hardware output sample rate, used only to detect route changes.
    private var hardwareSampleRate: Int = 0

    /// Maximum number of queued buffers before backpressure kicks in.
    /// 400 buffers ≈ 9-10 秒音频（AAC/MP3 每包 ~23ms），
    /// 为 CDN 断流重连预留充足缓冲窗口。
    static let maxQueuedBuffers = 400

    /// Returns the current number of queued audio buffers.
    var queuedBufferCount: Int {
        os_unfair_lock_lock(&bufferLock)
        let count = max(0, bufferQueue.count - bufferQueueHead)
        os_unfair_lock_unlock(&bufferLock)
        return count
    }

    /// Returns total duration of all queued buffers in seconds.
    var queuedDuration: TimeInterval {
        os_unfair_lock_lock(&bufferLock)
        var total: TimeInterval = 0
        for index in bufferQueueHead..<bufferQueue.count {
            guard let buffer = bufferQueue[index] else { continue }
            if index == bufferQueueHead && currentBufferOffset > 0 {
                let totalSamples = buffer.frameCount * buffer.channelCount
                let remainRatio = Double(totalSamples - currentBufferOffset) / Double(max(totalSamples, 1))
                total += buffer.duration * remainRatio
            } else {
                total += buffer.duration
            }
        }
        os_unfair_lock_unlock(&bufferLock)
        return total
    }

    func currentUnderrunSerial() -> UInt64 {
        os_unfair_lock_lock(&renderObservationLock)
        let serial = underrunSerial
        os_unfair_lock_unlock(&renderObservationLock)
        return serial
    }

    func hasObservedUnderrun(since serial: UInt64) -> Bool {
        os_unfair_lock_lock(&renderObservationLock)
        let observed = underrunSerial > serial
        os_unfair_lock_unlock(&renderObservationLock)
        return observed
    }

    private func markUnderrunObserved() {
        os_unfair_lock_lock(&renderObservationLock)
        underrunSerial &+= 1
        os_unfair_lock_unlock(&renderObservationLock)
    }

    private func compactBufferQueueLockedIfNeeded() {
        guard bufferQueueHead > 0 else { return }
        if bufferQueueHead >= bufferQueue.count {
            bufferQueue.removeAll(keepingCapacity: true)
            bufferQueueHead = 0
            return
        }
        guard bufferQueueHead >= 32, bufferQueueHead * 2 >= bufferQueue.count else { return }
        bufferQueue.removeFirst(bufferQueueHead)
        bufferQueueHead = 0
    }

    private func enqueuePendingBufferDeallocation(_ pointer: UnsafeMutablePointer<Float>) {
        var shouldSchedule = false
        os_unfair_lock_lock(&bufferLock)
        pendingBufferDeallocations.append(pointer)
        if !pendingDeallocationDrainScheduled {
            pendingDeallocationDrainScheduled = true
            shouldSchedule = true
        }
        os_unfair_lock_unlock(&bufferLock)

        guard shouldSchedule else { return }
        maintenanceQueue.async { [weak self] in
            self?.drainPendingBufferDeallocations()
        }
    }

    private func drainPendingBufferDeallocations() {
        while true {
            let pending: [UnsafeMutablePointer<Float>]
            os_unfair_lock_lock(&bufferLock)
            pending = pendingBufferDeallocations
            pendingBufferDeallocations.removeAll(keepingCapacity: true)
            if pending.isEmpty {
                pendingDeallocationDrainScheduled = false
                os_unfair_lock_unlock(&bufferLock)
                return
            }
            os_unfair_lock_unlock(&bufferLock)

            for pointer in pending {
                pointer.deallocate()
            }
        }
    }

    // MARK: - Initialization

    init() {}

    deinit {
        stop()
    }

    // MARK: - Public Interface

    private func currentHardwareSampleRate() -> Int {
        #if os(iOS) || os(tvOS)
        let rate = Int(AVAudioSession.sharedInstance().sampleRate)
        return rate > 0 ? rate : (hardwareSampleRate > 0 ? hardwareSampleRate : sampleRate)
        #else
        return hardwareSampleRate > 0 ? hardwareSampleRate : sampleRate
        #endif
    }

    /// Sets the EQ filter to apply in real-time during audio rendering.
    func setEQFilter(_ filter: EQFilter?) {
        eqFilter = filter
    }

    /// Sets the FFmpeg avfilter audio filter graph.
    func setAudioFilterGraph(_ graph: AudioFilterGraph?) {
        audioFilterGraph = graph
    }

    /// Sets the spectrum analyzer for real-time FFT analysis.
    func setSpectrumAnalyzer(_ analyzer: SpectrumAnalyzer?) {
        spectrumAnalyzer = analyzer
    }

    /// Sets the audio repair engine for automatic audio artifact fixing.
    func setRepairEngine(_ engine: AudioRepairEngine?) {
        repairEngine = engine
    }

    // MARK: - Route Change Handling

    /// 处理音频路由变化（蓝牙连接/断开）。
    ///
    /// 当硬件采样率因路由变化而改变时，安全重建 AVAudioEngine
    /// 以避免 `AVAudioSourceNode` 格式不匹配导致的闪退。
    func handleRouteChange() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        guard isStarted else { return }

        let newHWRate = currentHardwareSampleRate()
        let previousHWRate = hardwareSampleRate > 0 ? hardwareSampleRate : actualSampleRate
        guard newHWRate > 0, newHWRate != previousHWRate else { return }

        print("[AudioRenderer] 🔄 route change detected: hardware \(previousHWRate)Hz → \(newHWRate)Hz, rebuilding engine at source \(sampleRate)Hz")
        rebuildEngineLocked(hardwareSampleRate: newHWRate)
    }

    /// 在持有 lifecycleLock 的前提下重建 AVAudioEngine。
    ///
    /// 保留 bufferQueue 中的待播放数据，仅拆除并重建引擎和 sourceNode。
    /// 新引擎沿用当前 PCM 输入采样率创建 AVAudioFormat，并记录新的硬件采样率。
    private func rebuildEngineLocked(hardwareSampleRate newHardwareSampleRate: Int) {
        // 1. 拆除旧引擎（保留 buffer queue！）
        if let oldEngine = engine {
            oldEngine.mainMixerNode.removeTap(onBus: 0)
            oldEngine.stop()
            if let node = sourceNode {
                oldEngine.detach(node)
            }
        }
        sourceNode = nil
        engine = nil

        // 释放旧的 scratch buffers
        interleavedScratch?.deallocate()
        interleavedScratch = nil
        interleavedScratchCapacity = 0
        lastFrameSamples?.deallocate()
        lastFrameSamples = nil
        wasUnderrun = false

        // 2. 只更新硬件采样率。PCM 已由当前 decoder 按 `sampleRate` 输出，
        // route change 时不能把 queued PCM 当成新硬件采样率播放，否则会变调/变速。
        hardwareSampleRate = newHardwareSampleRate

        // 3. 创建新的 AVAudioFormat
        let rendererRate = Double(sampleRate)
        let avFormat: AVAudioFormat
        if channelCount > 2 {
            let layoutTag: AudioChannelLayoutTag
            switch channelCount {
            case 3:  layoutTag = kAudioChannelLayoutTag_MPEG_3_0_A
            case 4:  layoutTag = kAudioChannelLayoutTag_Quadraphonic
            case 5:  layoutTag = kAudioChannelLayoutTag_MPEG_5_0_A
            case 6:  layoutTag = kAudioChannelLayoutTag_MPEG_5_1_A
            case 7:  layoutTag = kAudioChannelLayoutTag_MPEG_6_1_A
            case 8:  layoutTag = kAudioChannelLayoutTag_MPEG_7_1_A
            default: layoutTag = kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channelCount)
            }
            guard let layout = AVAudioChannelLayout(layoutTag: layoutTag) else {
                print("[AudioRenderer] ❌ rebuild failed: cannot create channel layout")
                isStarted = false
                return
            }
            avFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: rendererRate,
                interleaved: false,
                channelLayout: layout
            )
        } else {
            guard let fmt = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: rendererRate,
                channels: AVAudioChannelCount(channelCount),
                interleaved: false
            ) else {
                print("[AudioRenderer] ❌ rebuild failed: cannot create AVAudioFormat")
                isStarted = false
                return
            }
            avFormat = fmt
        }

        // 4. 重新分配 scratch buffers
        let initialCapacity = 4096 * channelCount
        interleavedScratch = .allocate(capacity: initialCapacity)
        interleavedScratchCapacity = initialCapacity
        lastFrameSamples = .allocate(capacity: channelCount)
        lastFrameSamples?.initialize(repeating: 0, count: channelCount)
        wasUnderrun = false

        // 5. 创建新的 AVAudioSourceNode 和 AVAudioEngine
        let refCon = Unmanaged.passUnretained(self).toOpaque()
        let chCount = channelCount

        let node = AVAudioSourceNode(format: avFormat) { _, _, frameCount, audioBufferList -> OSStatus in
            let renderer = Unmanaged<AudioRenderer>.fromOpaque(refCon).takeUnretainedValue()
            let frames = Int(frameCount)
            let needed = frames * chCount

            let interleaved: UnsafeMutablePointer<Float>
            if needed <= renderer.interleavedScratchCapacity, let scratch = renderer.interleavedScratch {
                interleaved = scratch
            } else {
                renderer.interleavedScratch?.deallocate()
                renderer.interleavedScratch = .allocate(capacity: needed)
                renderer.interleavedScratchCapacity = needed
                interleaved = renderer.interleavedScratch!
            }

            renderer.fillBuffer(interleaved, frameCount: frames, channelCount: chCount)

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            if chCount == 1 {
                if let outData = ablPointer[0].mData?.assumingMemoryBound(to: Float.self) {
                    outData.update(from: interleaved, count: frames)
                }
            } else {
                for ch in 0..<min(chCount, ablPointer.count) {
                    guard let outData = ablPointer[ch].mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for f in 0..<frames {
                        outData[f] = interleaved[f * chCount + ch]
                    }
                }
            }

            return noErr
        }

        let audioEngine = AVAudioEngine()
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: avFormat)
        audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)

        let tapBufferSize: AVAudioFrameCount = 2048
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: nil) { [weak self] pcmBuffer, _ in
            guard let self = self else { return }
            guard let floatData = pcmBuffer.floatChannelData else { return }
            let frames = Int(pcmBuffer.frameLength)
            let channels = Int(pcmBuffer.format.channelCount)

            if let analyzer = self.spectrumAnalyzer, analyzer.isEnabled {
                if pcmBuffer.format.isInterleaved {
                    analyzer.feed(samples: floatData[0], frameCount: frames, channelCount: channels)
                } else {
                    analyzer.feed(samples: floatData[0], frameCount: frames, channelCount: 1)
                }
            }

            if let callback = self.onAudioData {
                if pcmBuffer.format.isInterleaved {
                    callback(floatData[0], frames, channels, Int(pcmBuffer.format.sampleRate))
                } else {
                    callback(floatData[0], frames, 1, Int(pcmBuffer.format.sampleRate))
                }
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            self.engine = audioEngine
            self.sourceNode = node
            print("[AudioRenderer] ✅ engine rebuilt successfully at source \(sampleRate)Hz, hardware \(newHardwareSampleRate)Hz")
        } catch {
            print("[AudioRenderer] ❌ rebuild engine.start() failed: \(error.localizedDescription)")
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            audioEngine.detach(node)
            isStarted = false
        }
    }

    /// Starts the audio renderer with the given audio format.
    ///
    /// Creates and starts an AVAudioEngine with an AVAudioSourceNode.
    /// The format describes the PCM data that will be enqueued.
    ///
    /// - Parameter format: The audio stream format describing the PCM data.
    /// - Throws: `FFmpegError.resourceAllocationFailed` if the engine cannot be started.
    func start(format: AudioStreamBasicDescription) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        guard !isStarted else { return }
        gracefulStopWorkItem?.cancel()
        gracefulStopWorkItem = nil

        #if os(iOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setPreferredSampleRate(format.mSampleRate)
        // Favor playback stability over low latency.
        // Third-party keyboards can briefly monopolize CPU on the main/system side;
        // a ~23 ms hardware buffer gives AVAudioEngine more headroom and reduces
        // audible underruns/crackles when the keyboard appears.
        try? session.setPreferredIOBufferDuration(Self.recommendedIOBufferDuration)
        let hwRate = session.sampleRate
        #else
        let hwRate = format.mSampleRate
        #endif

        sampleRate = Int(hwRate)
        channelCount = Int(format.mChannelsPerFrame)
        actualSampleRate = Int(hwRate)
        hardwareSampleRate = Int(hwRate)

        let audioEngine = AVAudioEngine()

        // AVAudioEngine internal nodes require non-interleaved (deinterleaved) format.
        // For multi-channel (>2ch, e.g. 5.1 surround), we must provide an explicit
        // AVAudioChannelLayout; the channels-only initializer returns nil for >2ch.
        let avFormat: AVAudioFormat
        if channelCount > 2 {
            let layoutTag: AudioChannelLayoutTag
            switch channelCount {
            case 3:  layoutTag = kAudioChannelLayoutTag_MPEG_3_0_A
            case 4:  layoutTag = kAudioChannelLayoutTag_Quadraphonic
            case 5:  layoutTag = kAudioChannelLayoutTag_MPEG_5_0_A
            case 6:  layoutTag = kAudioChannelLayoutTag_MPEG_5_1_A
            case 7:  layoutTag = kAudioChannelLayoutTag_MPEG_6_1_A
            case 8:  layoutTag = kAudioChannelLayoutTag_MPEG_7_1_A
            default: layoutTag = kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channelCount)
            }
            guard let layout = AVAudioChannelLayout(layoutTag: layoutTag) else {
                throw FFmpegError.resourceAllocationFailed(resource: "AVAudioChannelLayout")
            }
            avFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: hwRate,
                interleaved: false,
                channelLayout: layout
            )
        } else {
            guard let fmt = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: hwRate,
                channels: AVAudioChannelCount(channelCount),
                interleaved: false
            ) else {
                throw FFmpegError.resourceAllocationFailed(resource: "AVAudioFormat")
            }
            avFormat = fmt
        }

        // Pre-allocate scratch buffer for deinterleaving.
        // iOS typical render callback: 512 or 1024 frames × 2 channels = 1024~2048 floats.
        // Allocate enough for the largest expected callback (4096 frames stereo).
        let initialCapacity = 4096 * channelCount
        interleavedScratch = .allocate(capacity: initialCapacity)
        interleavedScratchCapacity = initialCapacity
        lastFrameSamples = .allocate(capacity: channelCount)
        lastFrameSamples?.initialize(repeating: 0, count: channelCount)
        wasUnderrun = false

        // AVAudioSourceNode render block — pulls interleaved data from bufferQueue,
        // then deinterleaves into the non-interleaved AudioBufferList that
        // AVAudioEngine expects.
        let refCon = Unmanaged.passUnretained(self).toOpaque()
        let chCount = channelCount

        let node = AVAudioSourceNode(format: avFormat) { _, _, frameCount, audioBufferList -> OSStatus in
            let renderer = Unmanaged<AudioRenderer>.fromOpaque(refCon).takeUnretainedValue()
            let frames = Int(frameCount)
            let needed = frames * chCount

            // Use pre-allocated scratch; grow only if needed (rare)
            let interleaved: UnsafeMutablePointer<Float>
            if needed <= renderer.interleavedScratchCapacity, let scratch = renderer.interleavedScratch {
                interleaved = scratch
            } else {
                renderer.interleavedScratch?.deallocate()
                renderer.interleavedScratch = .allocate(capacity: needed)
                renderer.interleavedScratchCapacity = needed
                interleaved = renderer.interleavedScratch!
            }

            renderer.fillBuffer(interleaved, frameCount: frames, channelCount: chCount)

            // Deinterleave into separate channel buffers
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            if chCount == 1 {
                if let outData = ablPointer[0].mData?.assumingMemoryBound(to: Float.self) {
                    outData.update(from: interleaved, count: frames)
                }
            } else {
                for ch in 0..<min(chCount, ablPointer.count) {
                    guard let outData = ablPointer[ch].mData?.assumingMemoryBound(to: Float.self) else { continue }
                    for f in 0..<frames {
                        outData[f] = interleaved[f * chCount + ch]
                    }
                }
            }

            return noErr
        }

        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: avFormat)
        audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)

        // Install tap on mainMixerNode for spectrum analysis and audio data callbacks.
        // Runs on a separate (non-real-time) thread managed by AVAudioEngine.
        let tapBufferSize: AVAudioFrameCount = 2048
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: nil) { [weak self] pcmBuffer, _ in
            guard let self = self else { return }

            guard let floatData = pcmBuffer.floatChannelData else { return }
            let frames = Int(pcmBuffer.frameLength)
            let channels = Int(pcmBuffer.format.channelCount)

            if let analyzer = self.spectrumAnalyzer, analyzer.isEnabled {
                if pcmBuffer.format.isInterleaved {
                    analyzer.feed(samples: floatData[0], frameCount: frames, channelCount: channels)
                } else {
                    // Non-interleaved: feed left channel only (mono mix).
                    analyzer.feed(samples: floatData[0], frameCount: frames, channelCount: 1)
                }
            }

            if let callback = self.onAudioData {
                if pcmBuffer.format.isInterleaved {
                    callback(floatData[0], frames, channels, Int(pcmBuffer.format.sampleRate))
                } else {
                    callback(floatData[0], frames, 1, Int(pcmBuffer.format.sampleRate))
                }
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            throw FFmpegError.resourceAllocationFailed(resource: "AVAudioEngine.start: \(error.localizedDescription)")
        }

        self.engine = audioEngine
        self.sourceNode = node
        isStarted = true
    }

    /// Enqueues a PCM audio buffer for playback.
    private var lastLowWaterLogTime: UInt64 = 0

    func enqueue(_ buffer: AudioBuffer) {
        os_unfair_lock_lock(&bufferLock)
        bufferQueue.append(buffer)
        compactBufferQueueLockedIfNeeded()
        let count = max(0, bufferQueue.count - bufferQueueHead)
        os_unfair_lock_unlock(&bufferLock)

        if count <= 3 {
            let now = mach_absolute_time()
            if now - lastLowWaterLogTime > 1_000_000_000 {
                lastLowWaterLogTime = now
                print("[AudioRenderer] 📉 low buffer: \(count) queued, duration=\(String(format: "%.2f", buffer.duration))s")
            }
        }
    }

    /// Pauses audio playback.
    func pause() {
        guard let engine = engine, isStarted, engine.isRunning else { return }
        engine.pause()
    }

    /// Resumes audio playback after a pause.
    func resume() {
        guard isStarted, let engine = engine, !engine.isRunning else { return }

        // 检查 pause 期间采样率是否因蓝牙连接/断开而改变
        #if os(iOS) || os(tvOS)
        let currentHWRate = currentHardwareSampleRate()
        let previousHWRate = hardwareSampleRate > 0 ? hardwareSampleRate : actualSampleRate
        if currentHWRate > 0, currentHWRate != previousHWRate {
            print("[AudioRenderer] ⚠️ hardware sample rate changed during pause (\(previousHWRate)→\(currentHWRate)), rebuilding")
            lifecycleLock.lock()
            rebuildEngineLocked(hardwareSampleRate: currentHWRate)
            lifecycleLock.unlock()
            return
        }
        #endif

        do {
            try engine.start()
        } catch {
            print("[AudioRenderer] resume failed: \(error.localizedDescription), attempting rebuild")
            lifecycleLock.lock()
            rebuildEngineLocked(hardwareSampleRate: currentHardwareSampleRate())
            lifecycleLock.unlock()
        }
    }

    /// Flushes all queued audio buffers without stopping the engine.
    ///
    /// Used during seek to clear stale audio data before new data arrives.
    func flushQueue() {
        setStopping(true)
        var pendingDeallocations: [UnsafeMutablePointer<Float>] = []
        os_unfair_lock_lock(&bufferLock)
        let flushedCount = max(0, bufferQueue.count - bufferQueueHead)
        for index in bufferQueueHead..<bufferQueue.count {
            bufferQueue[index]?.data.deallocate()
            bufferQueue[index] = nil
        }
        bufferQueue.removeAll()
        bufferQueueHead = 0
        currentBufferOffset = 0
        pendingDeallocations = pendingBufferDeallocations
        pendingBufferDeallocations.removeAll()
        pendingDeallocationDrainScheduled = false
        os_unfair_lock_unlock(&bufferLock)
        for pointer in pendingDeallocations {
            pointer.deallocate()
        }
        setStopping(false)
        print("[AudioRenderer] 🗑️ flushed \(flushedCount) buffers (seek/stop)")
    }
    
    /// Gracefully stops audio by first clearing queued PCM and letting the next render callback
    /// output a short fade-out tail based on the last played samples, then performing a hard stop.
    ///
    /// Use this for network interruptions or transient disconnects where a hard engine stop can click.
    func gracefulStop(flushRemainingAudio: Bool = true) {
        let delay: TimeInterval
        let workItem: DispatchWorkItem
        
        lifecycleLock.lock()
        guard isStarted else {
            lifecycleLock.unlock()
            return
        }
        
        gracefulStopWorkItem?.cancel()
        delay = max(0.08, Double(fadeSampleCount) / Double(max(sampleRate, 1)) + 0.03)
        workItem = DispatchWorkItem { [weak self] in
            self?.stop()
        }
        gracefulStopWorkItem = workItem
        lifecycleLock.unlock()
        
        if flushRemainingAudio {
            flushQueue()
        }
        
        print("[AudioRenderer] 🌙 graceful stop scheduled after \(String(format: "%.3f", delay))s")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Stops audio playback and releases all resources.
    ///
    /// After calling `stop()`, you must call `start(format:)` again to resume playback.
    func stop() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        guard isStarted else { return }
        gracefulStopWorkItem?.cancel()
        gracefulStopWorkItem = nil

        setStopping(true)

        if let engine = engine {
            engine.mainMixerNode.removeTap(onBus: 0)
            engine.stop()

            if let node = sourceNode {
                engine.detach(node)
            }

            self.sourceNode = nil
            self.engine = nil
        }

        interleavedScratch?.deallocate()
        interleavedScratch = nil
        interleavedScratchCapacity = 0
        lastFrameSamples?.deallocate()
        lastFrameSamples = nil
        wasUnderrun = false

        var pendingDeallocations: [UnsafeMutablePointer<Float>] = []
        os_unfair_lock_lock(&bufferLock)
        for index in bufferQueueHead..<bufferQueue.count {
            bufferQueue[index]?.data.deallocate()
            bufferQueue[index] = nil
        }
        bufferQueue.removeAll()
        bufferQueueHead = 0
        currentBufferOffset = 0
        pendingDeallocations = pendingBufferDeallocations
        pendingBufferDeallocations.removeAll()
        pendingDeallocationDrainScheduled = false
        os_unfair_lock_unlock(&bufferLock)
        for pointer in pendingDeallocations {
            pointer.deallocate()
        }

        isStarted = false
        setStopping(false)
    }

    // MARK: - Render Block Data Provider

    /// Underrun tracking for debug logging.
    private var underrunCount: Int = 0
    private var lastUnderrunLogTime: UInt64 = 0
    
    /// Tracks whether the previous render callback was an underrun, used for fade-in/out.
    private var wasUnderrun: Bool = false
    
    /// Number of samples per channel for fade-in/out ramps.
    /// Use roughly 25 ms so brief underruns caused by system UI spikes are softened.
    private var fadeSampleCount: Int {
        max(1024, sampleRate / 40)
    }

    /// Fills the output buffer by pulling samples from the buffer queue.
    ///
    /// Called from the AVAudioSourceNode render block on the audio thread.
    fileprivate func fillBuffer(_ output: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        let totalSamples = frameCount * channelCount

        guard !isStopping else {
            output.update(repeating: 0, count: totalSamples)
            return
        }

        var samplesWritten = 0
        var buffersToRelease: [UnsafeMutablePointer<Float>] = []

        os_unfair_lock_lock(&bufferLock)

        while samplesWritten < totalSamples && bufferQueueHead < bufferQueue.count {
            guard let front = bufferQueue[bufferQueueHead] else {
                bufferQueueHead += 1
                currentBufferOffset = 0
                continue
            }
            let frontTotalSamples = front.frameCount * front.channelCount
            let availableSamples = frontTotalSamples - currentBufferOffset
            let samplesToRead = min(totalSamples - samplesWritten, availableSamples)

            output.advanced(by: samplesWritten)
                .update(from: front.data.advanced(by: currentBufferOffset), count: samplesToRead)

            samplesWritten += samplesToRead
            currentBufferOffset += samplesToRead

            if currentBufferOffset >= frontTotalSamples {
                buffersToRelease.append(front.data)
                bufferQueue[bufferQueueHead] = nil
                bufferQueueHead += 1
                currentBufferOffset = 0
            }
        }

        os_unfair_lock_unlock(&bufferLock)

        if !buffersToRelease.isEmpty {
            for pointer in buffersToRelease {
                enqueuePendingBufferDeallocation(pointer)
            }
        }

        if samplesWritten < totalSamples {
            markUnderrunObserved()
            if samplesWritten > 0 {
                // 队列在本次回调中途耗尽：把尾巴平滑淡出后补零。
                let fadeOutSamples = min(fadeSampleCount * channelCount, samplesWritten)
                if fadeOutSamples > 0 {
                    let fadeFrames = fadeOutSamples / channelCount
                    let startOffset = samplesWritten - fadeOutSamples
                    for i in 0..<fadeOutSamples {
                        let frame = i / channelCount
                        let gain = Float(fadeFrames - 1 - frame) / Float(max(fadeFrames, 1))
                        output[startOffset + i] *= gain
                    }
                }
            } else if !wasUnderrun, let lastFrameSamples {
                // 队列在整个回调前就已空：从上一帧末尾采样平滑缓降到静音，
                // 防止“非零样本 -> 直接补零”的硬切啪嗒声。
                let fadeFrames = min(fadeSampleCount, frameCount)
                for frame in 0..<fadeFrames {
                    let gain = Float(fadeFrames - 1 - frame) / Float(max(fadeFrames, 1))
                    for channel in 0..<channelCount {
                        output[frame * channelCount + channel] = lastFrameSamples[channel] * gain
                    }
                }
                samplesWritten = fadeFrames * channelCount
            }
            
            let remaining = totalSamples - samplesWritten
            output.advanced(by: samplesWritten).update(repeating: 0, count: remaining)

            underrunCount += 1
            wasUnderrun = true
            let now = mach_absolute_time()
            if now - lastUnderrunLogTime > 1_000_000_000 {
                lastUnderrunLogTime = now
                print("[AudioRenderer] ⚠️ buffer underrun #\(underrunCount): requested=\(frameCount) frames, got=\(samplesWritten / max(channelCount, 1))")
            }
        } else {
            if wasUnderrun {
                // Fade-in when resuming from underrun
                let fadeInSamples = min(fadeSampleCount * channelCount, totalSamples)
                let fadeFrames = fadeInSamples / channelCount
                for i in 0..<fadeInSamples {
                    let frame = i / channelCount
                    let gain = Float(frame) / Float(max(fadeFrames, 1))
                    output[i] *= gain
                }
            } else if let lastFrameSamples, channelCount > 0 {
                // 检测相邻回调边界的 PCM 振幅突变（TCP 断流重连后的解码垃圾帧）。
                // 正常音乐波形在 ~512-1024 帧窗口内不会出现大幅度阶跃，
                // 但损坏帧/重连位移会导致第一个样本与上一次末尾样本严重不匹配。
                var maxDelta: Float = 0
                for ch in 0..<channelCount {
                    let delta = abs(output[ch] - lastFrameSamples[ch])
                    if delta > maxDelta { maxDelta = delta }
                }
                if maxDelta > discontinuityThreshold {
                    let crossfadeFrames = min(discontinuityCrossfadeSamples, frameCount)
                    for frame in 0..<crossfadeFrames {
                        let t = Float(frame) / Float(max(crossfadeFrames, 1))
                        for ch in 0..<channelCount {
                            let idx = frame * channelCount + ch
                            let oldVal = lastFrameSamples[ch]
                            output[idx] = oldVal * (1 - t) + output[idx] * t
                        }
                    }
                }
            }
            wasUnderrun = false
            underrunCount = 0
        }

        guard samplesWritten > 0 else { return }

        // 在效果器之前保存 raw PCM 末尾样本，确保不连续检测比较的是同类信号
        if totalSamples >= channelCount, let lastFrameSamples {
            let lastFrameOffset = totalSamples - channelCount
            for channel in 0..<channelCount {
                lastFrameSamples[channel] = output[lastFrameOffset + channel]
            }
        }

        // Apply FFmpeg avfilter graph (loudnorm, atempo, volume)
        if let graph = audioFilterGraph, graph.isActive {
            let buf = AudioBuffer(
                data: output,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: sampleRate
            )
            let processed = graph.process(buf)
            if processed.data != output {
                let outSamples = processed.frameCount * processed.channelCount
                let copyCount = min(outSamples, totalSamples)
                output.update(from: processed.data, count: copyCount)
                if copyCount < totalSamples {
                    output.advanced(by: copyCount).update(repeating: 0, count: totalSamples - copyCount)
                }
                processed.data.deallocate()
            }
        }

        // Apply EQ filter
        if let filter = eqFilter {
            let buf = AudioBuffer(
                data: output,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: sampleRate
            )
            _ = filter.process(buf)
        }

        // Audio repair engine (after all effects, before output)
        if let engine = repairEngine, engine.isActive {
            engine.process(output, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        }
    }
}
