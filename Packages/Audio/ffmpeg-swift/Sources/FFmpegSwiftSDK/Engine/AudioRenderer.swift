// AudioRenderer.swift
// FFmpegSwiftSDK
//
// Renders decoded audio PCM data to the system audio device using AVAudioEngine.
// Uses AVAudioSourceNode as the data provider, reading from a thread-safe buffer queue.
// The FFmpeg decode thread enqueues buffers; AVAudioSourceNode's render block pulls them.

import Foundation
import AudioToolbox
import AVFoundation
import CoreAudio

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
    /// 23 ms proved insufficient against IME/keyboard bursts (typing loads both
    /// the app main thread and mediaserverd); music playback tolerates ~46 ms
    /// of output latency with no downside, so favor stability aggressively.
    private static let recommendedIOBufferDuration: TimeInterval = 2048.0 / 44_100.0
    /// Bluetooth output adds codec and radio scheduling jitter outside the app's
    /// PCM queue. A slightly wider hardware runway prevents short system stalls
    /// from becoming audible crackles; music playback does not need game-like
    /// output latency.
    private static let bluetoothIOBufferDuration: TimeInterval = 2048.0 / 48_000.0
    /// Thermal throttling reduces the amount of CPU time available to each
    /// realtime callback. Music playback can trade a little more latency for a
    /// much wider render deadline without changing the decoded signal.
    private static let thermallyProtectedIOBufferDuration: TimeInterval = 4096.0 / 48_000.0

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
    private var renderCallbackSerial: UInt64 = 0
    private var lastRenderCallbackUptimeNanoseconds: UInt64 = 0
    private var recentRealPCMFrameCount: Int = 0
    private var recentOutputPeak: Float = 0

    /// Serializes start/stop lifecycle to prevent concurrent engine disposal.
    private let lifecycleLock = NSLock()
    /// Desired mixer volume survives AVAudioEngine disposal/recreation so a
    /// startup fade can begin muted before the first hardware render callback.
    private var outputVolumeStorage: Float = 1.0
    /// Independent multiplier for temporary system/game voice ducking. Keeping
    /// it separate prevents a voice hint from overwriting pause or sleep fades.
    private var duckingVolumeStorage: Float = 1.0
    /// Real-time spatial pan is applied by AVAudioMixerNode and therefore does
    /// not rebuild FFmpeg filters or disturb the decoder queue.
    private var outputPanStorage: Float = 0
    /// Pointer retirement and thermal checks are housekeeping, not playback
    /// deadlines. Utility QoS keeps them from competing with the audio callback.
    private let maintenanceQueue = DispatchQueue(
        label: "FFmpegSwiftSDK.AudioRenderer.maintenance",
        qos: .utility
    )
    private var thermalPolicyLock = os_unfair_lock_s()
    /// 0 = unrestricted, 1 = suspend visual analysis, 2 = suspend all analysis.
    private var realtimeProtectionLevel = 0
    private var lastThermalPolicyCheckAt: UInt64 = 0
    private var lastAppliedThermalPolicy = -1

    /// Output-stage processors stay behind the PCM queue so interactive changes
    /// affect the next hardware callback instead of waiting for decoded audio to drain.
    private var eqFilter: EQFilter?
    private var audioFilterGraph: AudioFilterGraph?
    private var repairEngine: AudioRepairEngine?

    /// Optional spectrum analyzer.
    private var spectrumAnalyzer: SpectrumAnalyzer?

    /// Pre-DSP analyzer used by measurement and calibration tasks. Keeping it
    /// separate prevents UI spectrum callbacks from being duplicated and lets
    /// analysis observe the decoded signal before playback effects are applied.
    private var analysisSpectrumAnalyzer: SpectrumAnalyzer?

    /// Optional audio data callback for real-time analysis.
    var onAudioData: ((_ samples: UnsafePointer<Float>, _ frameCount: Int, _ channelCount: Int, _ sampleRate: Int) -> Void)?

    /// Sample rate of the PCM buffers consumed by the source node.
    private var sampleRate: Int = 44100

    /// Number of channels in the current audio stream.
    private var channelCount: Int = 2

    /// FIFO queue of PCM audio buffers waiting to be rendered.
    /// Use a head index instead of `removeFirst()` so the real-time render callback
    /// never has to memmove the remaining queue contents.
    private struct QueuedAudioBuffer {
        let buffer: AudioBuffer
        let presentationTime: TimeInterval?
    }

    /// Fixed-capacity SPSC-style storage. Access is still serialized by
    /// `bufferLock`, but enqueue/dequeue are O(1) and never compact an Array
    /// while the hardware render thread is waiting for the same lock.
    private struct AudioBufferRing {
        private var storage: [QueuedAudioBuffer?]
        private(set) var count = 0
        private var readIndex = 0
        private var writeIndex = 0

        init(capacity: Int) {
            storage = Array(repeating: nil, count: max(1, capacity))
        }

        var isEmpty: Bool { count == 0 }

        var first: QueuedAudioBuffer? {
            guard count > 0 else { return nil }
            return storage[readIndex]
        }

        @discardableResult
        mutating func append(_ value: QueuedAudioBuffer) -> Bool {
            guard count < storage.count else { return false }
            storage[writeIndex] = value
            writeIndex = (writeIndex + 1) % storage.count
            count += 1
            return true
        }

        @discardableResult
        mutating func removeFirst() -> QueuedAudioBuffer? {
            guard count > 0 else { return nil }
            let value = storage[readIndex]
            storage[readIndex] = nil
            readIndex = (readIndex + 1) % storage.count
            count -= 1
            if count == 0 {
                readIndex = 0
                writeIndex = 0
            }
            return value
        }

        mutating func drainPointers(into destination: inout [UnsafeMutablePointer<Float>]) {
            while let queued = removeFirst() {
                destination.append(queued.buffer.data)
            }
        }
    }

    // Decoder backpressure is capped at 400 buffers. Keep ample fixed runway
    // for handoffs without ever growing storage from the realtime path.
    private var bufferQueue = AudioBufferRing(capacity: 1_024)
    /// O(1) queue duration and audible clock. Both are updated while holding
    /// `bufferLock`, so UI reads never scan the PCM queue used by the render thread.
    private var queuedAudioDuration: TimeInterval = 0
    private var audiblePresentationTime: TimeInterval?
    /// Monotonic amount of real PCM handed to the audio device. Silence inserted
    /// for buffering/underruns is intentionally excluded, so app-side listening
    /// statistics can follow actual audible output instead of UI or wall-clock time.
    private var audibleOutputDuration: TimeInterval = 0

    /// A network stream that has genuinely starved must rebuild a short runway
    /// before it is allowed to feed the hardware again. Without this hysteresis,
    /// a weak connection alternates between one decoded packet and silence, which
    /// is heard as repeated syllable-level stuttering.
    private var isRebuffering = false
    private var inputHasEnded = false
    private static let rebufferRecoveryDuration: TimeInterval = 0.35
    /// 上次断粮时刻（uptime ns）。孤立的一次断粮（CPU 尖峰/锁竞争）
    /// 下个回调直接恢复；短窗口内连续断粮才判定为网络饥饿，
    /// 进入 rebufferRecoveryDuration 迟滞，避免把几毫秒的毛刺放大成长静音。
    private var lastStarvationAt: UInt64 = 0
    private static let starvationClusterWindowNanos: UInt64 = 1_500_000_000

    /// Secondary PCM lane used for real overlap mixing at a prepared-track boundary.
    private var crossfadeQueue = AudioBufferRing(capacity: 1_024)
    private var crossfadeBufferOffset = 0
    private var crossfadeQueuedDuration: TimeInterval = 0
    private var crossfadePresentationTime: TimeInterval?
    private var isCrossfadeActive = false
    private var isCrossfadeMixing = false
    private var crossfadePlannedDuration: TimeInterval = 0
    private var crossfadeTotalFrames = 0
    private var crossfadeFramesRendered = 0
    private var crossfadeOutgoingTrim: Float = 1
    private var crossfadeIncomingTrim: Float = 1

    /// Tracks the read offset (in samples) into the front buffer of the queue.
    private var currentBufferOffset: Int = 0
    private var pendingBufferDeallocations: [UnsafeMutablePointer<Float>] = []
    /// Maintenance-thread scratch storage. Keeping a second uniquely-owned array
    /// avoids copy-on-write reallocations while `bufferLock` is held periodically.
    private var deallocationDrainScratch: [UnsafeMutablePointer<Float>] = []
    private var deallocationTimer: DispatchSourceTimer?

    /// Pre-allocated interleaved scratch buffer for the render block.
    /// Avoids per-callback malloc/free on the real-time audio thread.
    private var interleavedScratch: UnsafeMutablePointer<Float>?
    private var interleavedScratchCapacity: Int = 0
    private var crossfadeScratch: UnsafeMutablePointer<Float>?
    
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

    /// Stable PCM channel count consumed by the current engine session.
    var actualChannelCount: Int {
        lifecycleLock.lock()
        let value = channelCount
        lifecycleLock.unlock()
        return value
    }

    /// Current hardware output sample rate, used only to detect route changes.
    private var hardwareSampleRate: Int = 0

    /// Maximum number of queued buffers before backpressure kicks in.
    /// 400 buffers ≈ 9-10 秒音频（AAC/MP3 每包 ~23ms），
    /// 为 CDN 断流重连预留充足缓冲窗口。
    static let maxQueuedBuffers = 400
    /// 触发高水位后先让队列明显回落，再恢复批量解码，避免整首歌都让
    /// user-interactive 线程以 10ms 周期空转轮询。
    static let backpressureResumeQueuedBuffers = 320

    /// Returns the current number of queued audio buffers.
    var queuedBufferCount: Int {
        os_unfair_lock_lock(&bufferLock)
        let count = bufferQueue.count + crossfadeQueue.count
        os_unfair_lock_unlock(&bufferLock)
        return count
    }

    /// Returns total duration of all queued buffers in seconds.
    var queuedDuration: TimeInterval {
        os_unfair_lock_lock(&bufferLock)
        let overlap = isCrossfadeActive
            ? min(crossfadePlannedDuration, min(queuedAudioDuration, crossfadeQueuedDuration))
            : 0
        let total = max(0, queuedAudioDuration + crossfadeQueuedDuration - overlap)
        os_unfair_lock_unlock(&bufferLock)
        return total
    }

    /// Presentation timestamp of the PCM most recently consumed by the hardware.
    var currentPresentationTime: TimeInterval? {
        os_unfair_lock_lock(&bufferLock)
        // The app switches its visible track at the overlap midpoint. Expose the
        // new lane's clock from the same point so the progress UI never shows the
        // previous song's timestamp under the new song metadata.
        let time: TimeInterval?
        if isCrossfadeMixing,
           crossfadeFramesRendered * 2 >= crossfadeTotalFrames,
           let crossfadePresentationTime {
            time = crossfadePresentationTime
        } else {
            time = audiblePresentationTime
        }
        os_unfair_lock_unlock(&bufferLock)
        return time
    }

    /// Total real audio duration consumed by the render callback during this
    /// renderer's lifetime. It deliberately survives seek, track and engine resets.
    var totalAudibleOutputDuration: TimeInterval {
        os_unfair_lock_lock(&bufferLock)
        let duration = audibleOutputDuration
        os_unfair_lock_unlock(&bufferLock)
        return duration
    }

    /// Whether the configured output engine is really delivering audio.
    /// PlaybackState alone cannot answer this after Bluetooth/media-service resets.
    var isOutputRunning: Bool {
        lifecycleLock.lock()
        let running = isStarted && (engine?.isRunning == true)
        lifecycleLock.unlock()
        return running
    }

    func currentUnderrunSerial() -> UInt64 {
        os_unfair_lock_lock(&renderObservationLock)
        let serial = underrunSerial
        os_unfair_lock_unlock(&renderObservationLock)
        return serial
    }

    func outputDiagnostics() -> AudioOutputDiagnostics {
        let now = DispatchTime.now().uptimeNanoseconds
        os_unfair_lock_lock(&renderObservationLock)
        let callbackSerial = renderCallbackSerial
        let callbackUptime = lastRenderCallbackUptimeNanoseconds
        let realPCMFrameCount = recentRealPCMFrameCount
        let outputPeak = recentOutputPeak
        let currentUnderrunSerial = underrunSerial
        os_unfair_lock_unlock(&renderObservationLock)

        let callbackAge: TimeInterval?
        if callbackUptime == 0 || now < callbackUptime {
            callbackAge = nil
        } else {
            callbackAge = TimeInterval(now - callbackUptime) / 1_000_000_000
        }

        return AudioOutputDiagnostics(
            isEngineRunning: isOutputRunning,
            renderCallbackSerial: callbackSerial,
            lastRenderCallbackAge: callbackAge,
            recentRealPCMFrameCount: realPCMFrameCount,
            recentOutputPeak: outputPeak,
            underrunSerial: currentUnderrunSerial,
            queuedBufferCount: queuedBufferCount,
            queuedDuration: queuedDuration,
            totalRealPCMOutputDuration: totalAudibleOutputDuration
        )
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

    private func recordRenderObservation(
        output: UnsafePointer<Float>,
        sampleCount: Int,
        realPCMFrameCount: Int
    ) {
        var peak: Float = 0
        if sampleCount > 0 {
            let stride = max(1, sampleCount / 256)
            var index = 0
            while index < sampleCount {
                peak = max(peak, abs(output[index]))
                index += stride
            }
        }

        os_unfair_lock_lock(&renderObservationLock)
        renderCallbackSerial &+= 1
        lastRenderCallbackUptimeNanoseconds = DispatchTime.now().uptimeNanoseconds
        recentRealPCMFrameCount = realPCMFrameCount
        recentOutputPeak = peak
        os_unfair_lock_unlock(&renderObservationLock)
    }

    private func drainPendingBufferDeallocations() {
        deallocationDrainScratch.removeAll(keepingCapacity: true)
        os_unfair_lock_lock(&bufferLock)
        deallocationDrainScratch.append(contentsOf: pendingBufferDeallocations)
        pendingBufferDeallocations.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(&bufferLock)

        for pointer in deallocationDrainScratch {
            pointer.deallocate()
        }
        deallocationDrainScratch.removeAll(keepingCapacity: true)
    }

    private func startDeallocationTimerLocked() {
        guard deallocationTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: maintenanceQueue)
        timer.schedule(
            deadline: .now() + 0.25,
            repeating: 0.25,
            leeway: .milliseconds(75)
        )
        timer.setEventHandler { [weak self] in
            self?.performPeriodicMaintenance()
        }
        deallocationTimer = timer
        timer.resume()
    }

    private func performPeriodicMaintenance() {
        drainPendingBufferDeallocations()
        refreshThermalPolicyIfNeeded()
    }

    private func stopDeallocationTimerLocked() {
        deallocationTimer?.setEventHandler {}
        deallocationTimer?.cancel()
        deallocationTimer = nil
    }

    // MARK: - Initialization

    init() {
        // Completed PCM buffers are retired by the maintenance timer. Reserving
        // generously keeps the render callback's append path allocation-free.
        pendingBufferDeallocations.reserveCapacity(1024)
        deallocationDrainScratch.reserveCapacity(1024)
    }

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

    #if os(iOS) || os(tvOS)
    private static func preferredIOBufferDuration(for session: AVAudioSession) -> TimeInterval {
        let info = ProcessInfo.processInfo
        if info.isLowPowerModeEnabled {
            return thermallyProtectedIOBufferDuration
        }
        switch info.thermalState {
        case .fair, .serious, .critical:
            return thermallyProtectedIOBufferDuration
        case .nominal:
            break
        @unknown default:
            return thermallyProtectedIOBufferDuration
        }

        let usesBluetooth = session.currentRoute.outputs.contains { output in
            switch output.portType {
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                return true
            default:
                return false
            }
        }
        return usesBluetooth ? bluetoothIOBufferDuration : recommendedIOBufferDuration
    }

    private func refreshThermalPolicyIfNeeded(force: Bool = false) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard force || now &- lastThermalPolicyCheckAt >= 1_000_000_000 else { return }
        lastThermalPolicyCheckAt = now

        let info = ProcessInfo.processInfo
        let level: Int
        if info.thermalState == .critical {
            level = 2
        } else if info.isLowPowerModeEnabled
                    || info.thermalState == .fair
                    || info.thermalState == .serious {
            level = 1
        } else {
            level = 0
        }

        os_unfair_lock_lock(&thermalPolicyLock)
        realtimeProtectionLevel = level
        os_unfair_lock_unlock(&thermalPolicyLock)

        guard force || level != lastAppliedThermalPolicy else { return }
        lastAppliedThermalPolicy = level

        let session = AVAudioSession.sharedInstance()
        let preferredDuration = Self.preferredIOBufferDuration(for: session)
        try? session.setPreferredIOBufferDuration(preferredDuration)
        print(
            "[AudioRenderer] thermal policy level=\(level) " +
            "preferredIO=\(String(format: "%.1f", preferredDuration * 1_000))ms"
        )
    }
    #else
    private func refreshThermalPolicyIfNeeded(force: Bool = false) {}
    #endif

    private func currentRealtimeProtectionLevel() -> Int {
        // A contended policy lock is exceptionally brief. Prefer the protective
        // visual-analysis policy for that callback rather than doing optional
        // work on the realtime thread while the policy is changing.
        guard os_unfair_lock_trylock(&thermalPolicyLock) else { return 1 }
        let level = realtimeProtectionLevel
        os_unfair_lock_unlock(&thermalPolicyLock)
        return level
    }

    /// 混音台输出音量（0.0~1.0）。
    ///
    /// 直接作用于 `mainMixerNode.outputVolume`，在渲染混音阶段生效，
    /// 不触碰 FFmpeg 滤镜图（无需重建、实时安全），适合做暂停/恢复的
    /// 短淡入淡出与定时关闭的长淡出。目标值会跨引擎重建保留，确保
    /// 新音频设备的第一帧也能从指定包络起点开始。
    var outputVolume: Float {
        get {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            return outputVolumeStorage
        }
        set {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            let clamped = max(0.0, min(newValue, 1.0))
            outputVolumeStorage = clamped
            engine?.mainMixerNode.outputVolume = clamped * duckingVolumeStorage
        }
    }

    /// Temporary output multiplier (0.0~1.0) composed with `outputVolume`.
    var duckingVolume: Float {
        get {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            return duckingVolumeStorage
        }
        set {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            let clamped = max(0.0, min(newValue, 1.0))
            duckingVolumeStorage = clamped
            engine?.mainMixerNode.outputVolume = outputVolumeStorage * clamped
        }
    }

    /// Output-stage pan (-1...1). This is safe to update at motion-sensor rate.
    var outputPan: Float {
        get {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            return outputPanStorage
        }
        set {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            let clamped = max(-1, min(newValue, 1))
            outputPanStorage = clamped
            engine?.mainMixerNode.pan = clamped
        }
    }

    func setEQFilter(_ filter: EQFilter?) {
        eqFilter = filter
    }

    func setAudioFilterGraph(_ graph: AudioFilterGraph?) {
        audioFilterGraph = graph
    }

    func setRepairEngine(_ engine: AudioRepairEngine?) {
        repairEngine = engine
    }

    /// Sets the spectrum analyzer for real-time FFT analysis.
    func setSpectrumAnalyzer(_ analyzer: SpectrumAnalyzer?) {
        spectrumAnalyzer = analyzer
    }

    func setAnalysisSpectrumAnalyzer(_ analyzer: SpectrumAnalyzer?) {
        analysisSpectrumAnalyzer = analyzer
    }

    // MARK: - Route Change Handling

    /// 处理音频路由变化（蓝牙连接/断开）。
    ///
    /// 当硬件采样率因路由变化而改变时，安全重建 AVAudioEngine
    /// 以避免 `AVAudioSourceNode` 格式不匹配导致的闪退。
    @discardableResult
    func handleRouteChange() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        guard actualSampleRate > 0, channelCount > 0 else { return false }

        #if os(iOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setPreferredIOBufferDuration(
            Self.preferredIOBufferDuration(for: session)
        )
        #endif
        let newHWRate = currentHardwareSampleRate()
        let previousHWRate = hardwareSampleRate > 0 ? hardwareSampleRate : actualSampleRate
        let outputIsAlive = isStarted && (engine?.isRunning == true)
        guard newHWRate > 0 else { return outputIsAlive }
        guard newHWRate != previousHWRate || !outputIsAlive else { return true }

        print("[AudioRenderer] 🔄 route/output change: hardware \(previousHWRate)Hz → \(newHWRate)Hz, running=\(outputIsAlive); rebuilding at source \(sampleRate)Hz")
        rebuildEngineLocked(hardwareSampleRate: newHWRate)
        return isStarted && (engine?.isRunning == true)
    }

    /// 在持有 lifecycleLock 的前提下重建 AVAudioEngine。
    ///
    /// 保留 bufferQueue 中的待播放数据，仅拆除并重建引擎和 sourceNode。
    /// 新引擎沿用当前 PCM 输入采样率创建 AVAudioFormat，并记录新的硬件采样率。
    private func rebuildEngineLocked(hardwareSampleRate newHardwareSampleRate: Int) {
        // 1. 拆除旧引擎（保留 buffer queue！）
        if let oldEngine = engine {
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
        crossfadeScratch?.deallocate()
        crossfadeScratch = nil
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
        let initialCapacity = 8192 * channelCount
        interleavedScratch = .allocate(capacity: initialCapacity)
        crossfadeScratch = .allocate(capacity: initialCapacity)
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
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            guard needed <= renderer.interleavedScratchCapacity,
                  let interleaved = renderer.interleavedScratch else {
                for buffer in ablPointer {
                    guard let data = buffer.mData else { continue }
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }

            renderer.fillBuffer(interleaved, frameCount: frames, channelCount: chCount)

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
        audioEngine.mainMixerNode.outputVolume = outputVolumeStorage * duckingVolumeStorage
        audioEngine.mainMixerNode.pan = outputPanStorage

        audioEngine.prepare()

        do {
            try audioEngine.start()
            self.engine = audioEngine
            self.sourceNode = node
            self.isStarted = true
            print("[AudioRenderer] ✅ engine rebuilt successfully at source \(sampleRate)Hz, hardware \(newHardwareSampleRate)Hz")
        } catch {
            print("[AudioRenderer] ❌ rebuild engine.start() failed: \(error.localizedDescription)")
            audioEngine.detach(node)
            interleavedScratch?.deallocate()
            interleavedScratch = nil
            interleavedScratchCapacity = 0
            crossfadeScratch?.deallocate()
            crossfadeScratch = nil
            lastFrameSamples?.deallocate()
            lastFrameSamples = nil
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
        refreshThermalPolicyIfNeeded(force: true)
        try? session.setPreferredSampleRate(format.mSampleRate)
        // Favor playback stability over low latency.
        // Third-party keyboards can briefly monopolize CPU on the main/system side;
        // a wider hardware buffer gives AVAudioEngine more headroom and reduces
        // audible underruns/crackles when the keyboard appears.
        try? session.setPreferredIOBufferDuration(
            Self.preferredIOBufferDuration(for: session)
        )
        let hwRate = session.sampleRate
        #else
        let hwRate = format.mSampleRate
        #endif

        sampleRate = Int(hwRate)
        channelCount = Int(format.mChannelsPerFrame)
        actualSampleRate = Int(hwRate)
        hardwareSampleRate = Int(hwRate)
        os_unfair_lock_lock(&bufferLock)
        isRebuffering = false
        inputHasEnded = false
        os_unfair_lock_unlock(&bufferLock)

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
        // Allocate enough for route changes and unusually large callbacks without
        // ever reallocating from the real-time render thread.
        let initialCapacity = 8192 * channelCount
        interleavedScratch = .allocate(capacity: initialCapacity)
        crossfadeScratch = .allocate(capacity: initialCapacity)
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
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            guard needed <= renderer.interleavedScratchCapacity,
                  let interleaved = renderer.interleavedScratch else {
                for buffer in ablPointer {
                    guard let data = buffer.mData else { continue }
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }

            renderer.fillBuffer(interleaved, frameCount: frames, channelCount: chCount)

            // Deinterleave into separate channel buffers
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
        audioEngine.mainMixerNode.outputVolume = outputVolumeStorage * duckingVolumeStorage
        audioEngine.mainMixerNode.pan = outputPanStorage

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            audioEngine.detach(node)
            interleavedScratch?.deallocate()
            interleavedScratch = nil
            interleavedScratchCapacity = 0
            crossfadeScratch?.deallocate()
            crossfadeScratch = nil
            lastFrameSamples?.deallocate()
            lastFrameSamples = nil
            throw FFmpegError.resourceAllocationFailed(resource: "AVAudioEngine.start: \(error.localizedDescription)")
        }

        self.engine = audioEngine
        self.sourceNode = node
        isStarted = true
        startDeallocationTimerLocked()
    }

    /// Enqueues a PCM audio buffer for playback.
    private var lastLowWaterLogTime: UInt64 = 0

    func enqueue(_ buffer: AudioBuffer, presentationTime: TimeInterval? = nil) {
        // Ownership transfers to the renderer at this boundary. Serialize the
        // started check with stop() so a late decoder result from an invalidated
        // playback generation is released instead of entering a stopped engine.
        lifecycleLock.lock()
        guard isStarted, !isStopping else {
            lifecycleLock.unlock()
            buffer.data.deallocate()
            return
        }
        guard buffer.sampleRate == sampleRate,
              buffer.channelCount == channelCount else {
            let expected = "\(sampleRate)Hz/\(channelCount)ch"
            let received = "\(buffer.sampleRate)Hz/\(buffer.channelCount)ch"
            lifecycleLock.unlock()
            buffer.data.deallocate()
            print("[AudioRenderer] rejected PCM format \(received); expected \(expected)")
            return
        }

        os_unfair_lock_lock(&bufferLock)
        let queued = QueuedAudioBuffer(buffer: buffer, presentationTime: presentationTime)
        let didEnqueue: Bool
        if isCrossfadeActive {
            didEnqueue = crossfadeQueue.append(queued)
            if didEnqueue { crossfadeQueuedDuration += buffer.duration }
        } else {
            didEnqueue = bufferQueue.append(queued)
            if didEnqueue { queuedAudioDuration += buffer.duration }
        }
        let count = bufferQueue.count + crossfadeQueue.count
        os_unfair_lock_unlock(&bufferLock)
        lifecycleLock.unlock()

        guard didEnqueue else {
            // Backpressure should keep each lane far below the fixed capacity.
            // Release ownership safely if a broken producer violates that
            // contract instead of overwriting unread PCM.
            buffer.data.deallocate()
            print("[AudioRenderer] rejected PCM: realtime ring is full")
            return
        }

        if count <= 3 {
            let now = DispatchTime.now().uptimeNanoseconds
            if now - lastLowWaterLogTime > 1_000_000_000 {
                lastLowWaterLogTime = now
                print("[AudioRenderer] 📉 low buffer: \(count) queued, duration=\(String(format: "%.2f", buffer.duration))s")
            }
        }
    }

    /// Routes subsequently enqueued PCM to a second lane. The render callback
    /// starts consuming it only when the primary lane reaches the overlap window.
    @discardableResult
    func beginCrossfade(
        duration: TimeInterval,
        outgoingGainDB: Float = 0,
        incomingGainDB: Float = 0
    ) -> Bool {
        os_unfair_lock_lock(&bufferLock)
        defer { os_unfair_lock_unlock(&bufferLock) }
        guard !isCrossfadeActive,
              duration > 0,
              !bufferQueue.isEmpty,
              queuedAudioDuration > 0 else { return false }

        isCrossfadeActive = true
        isCrossfadeMixing = false
        crossfadePlannedDuration = min(duration, queuedAudioDuration)
        crossfadeTotalFrames = max(1, Int(crossfadePlannedDuration * Double(max(sampleRate, 1))))
        crossfadeFramesRendered = 0
        crossfadeOutgoingTrim = powf(10, min(3, max(-6, outgoingGainDB)) / 20)
        crossfadeIncomingTrim = powf(10, min(3, max(-6, incomingGainDB)) / 20)
        crossfadePresentationTime = nil
        return true
    }

    /// Pauses audio playback.
    @discardableResult
    func pause() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard let engine = engine, isStarted else { return false }
        guard engine.isRunning else { return true }
        engine.pause()
        return !engine.isRunning
    }

    /// Resumes audio playback after a pause.
    @discardableResult
    func resume() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard actualSampleRate > 0, channelCount > 0 else { return false }

        // 检查 pause 期间采样率是否因蓝牙连接/断开而改变
        #if os(iOS) || os(tvOS)
        let currentHWRate = currentHardwareSampleRate()
        let previousHWRate = hardwareSampleRate > 0 ? hardwareSampleRate : actualSampleRate
        if !isStarted || engine == nil || (currentHWRate > 0 && currentHWRate != previousHWRate) {
            print("[AudioRenderer] ⚠️ output unavailable or route changed during pause (\(previousHWRate)→\(currentHWRate)), rebuilding")
            rebuildEngineLocked(hardwareSampleRate: currentHWRate)
            return isStarted && (engine?.isRunning == true)
        }
        #endif

        guard isStarted, let engine else { return false }
        guard !engine.isRunning else { return true }

        do {
            try engine.start()
            return engine.isRunning
        } catch {
            print("[AudioRenderer] resume failed: \(error.localizedDescription), attempting rebuild")
            rebuildEngineLocked(hardwareSampleRate: currentHardwareSampleRate())
            return isStarted && (self.engine?.isRunning == true)
        }
    }

    /// Marks that more PCM may arrive. Called after seek/reconnect/track switch.
    func markInputActive() {
        os_unfair_lock_lock(&bufferLock)
        inputHasEnded = false
        os_unfair_lock_unlock(&bufferLock)
    }

    /// Lets the renderer drain a short final tail without waiting for the
    /// starvation recovery threshold once demuxer EOF has been confirmed.
    func markInputEnded() {
        os_unfair_lock_lock(&bufferLock)
        inputHasEnded = true
        isRebuffering = false
        os_unfair_lock_unlock(&bufferLock)
    }

    /// Flushes all queued audio buffers without stopping the engine.
    ///
    /// Used during seek to clear stale audio data before new data arrives.
    func flushQueue() {
        setStopping(true)
        var pendingDeallocations: [UnsafeMutablePointer<Float>] = []
        os_unfair_lock_lock(&bufferLock)
        let flushedCount = bufferQueue.count + crossfadeQueue.count
        bufferQueue.drainPointers(into: &pendingDeallocations)
        crossfadeQueue.drainPointers(into: &pendingDeallocations)
        currentBufferOffset = 0
        crossfadeBufferOffset = 0
        queuedAudioDuration = 0
        crossfadeQueuedDuration = 0
        isRebuffering = false
        inputHasEnded = false
        audiblePresentationTime = nil
        crossfadePresentationTime = nil
        isCrossfadeActive = false
        isCrossfadeMixing = false
        crossfadePlannedDuration = 0
        crossfadeTotalFrames = 0
        crossfadeFramesRendered = 0
        pendingDeallocations.append(contentsOf: pendingBufferDeallocations)
        pendingBufferDeallocations.removeAll()
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

        gracefulStopWorkItem?.cancel()
        gracefulStopWorkItem = nil
        stopDeallocationTimerLocked()

        setStopping(true)

        if let engine = engine {
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
        crossfadeScratch?.deallocate()
        crossfadeScratch = nil
        lastFrameSamples?.deallocate()
        lastFrameSamples = nil
        wasUnderrun = false

        var pendingDeallocations: [UnsafeMutablePointer<Float>] = []
        os_unfair_lock_lock(&bufferLock)
        bufferQueue.drainPointers(into: &pendingDeallocations)
        crossfadeQueue.drainPointers(into: &pendingDeallocations)
        currentBufferOffset = 0
        crossfadeBufferOffset = 0
        queuedAudioDuration = 0
        crossfadeQueuedDuration = 0
        isRebuffering = false
        inputHasEnded = false
        audiblePresentationTime = nil
        crossfadePresentationTime = nil
        isCrossfadeActive = false
        isCrossfadeMixing = false
        crossfadePlannedDuration = 0
        crossfadeTotalFrames = 0
        crossfadeFramesRendered = 0
        pendingDeallocations.append(contentsOf: pendingBufferDeallocations)
        pendingBufferDeallocations.removeAll()
        os_unfair_lock_unlock(&bufferLock)
        for pointer in pendingDeallocations {
            pointer.deallocate()
        }

        isStarted = false
        setStopping(false)
    }

    // MARK: - Render Block Data Provider

    /// Consecutive underrun tracking for fade recovery.
    private var underrunCount: Int = 0
    
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
            recordRenderObservation(
                output: UnsafePointer(output),
                sampleCount: totalSamples,
                realPCMFrameCount: 0
            )
            return
        }

        var samplesWritten = 0

        os_unfair_lock_lock(&bufferLock)

        let bufferedDuration = queuedAudioDuration + crossfadeQueuedDuration
        if isRebuffering,
           !inputHasEnded,
           bufferedDuration < Self.rebufferRecoveryDuration {
            os_unfair_lock_unlock(&bufferLock)
            output.update(repeating: 0, count: totalSamples)
            markUnderrunObserved()
            underrunCount += 1
            wasUnderrun = true
            recordRenderObservation(
                output: UnsafePointer(output),
                sampleCount: totalSamples,
                realPCMFrameCount: 0
            )
            return
        }
        if isRebuffering {
            isRebuffering = false
        }

        while samplesWritten < totalSamples && !bufferQueue.isEmpty {
            guard let queued = bufferQueue.first else {
                _ = bufferQueue.removeFirst()
                currentBufferOffset = 0
                continue
            }
            let front = queued.buffer
            let frontTotalSamples = front.frameCount * front.channelCount
            let availableSamples = frontTotalSamples - currentBufferOffset
            let samplesToRead = min(totalSamples - samplesWritten, availableSamples)

            output.advanced(by: samplesWritten)
                .update(from: front.data.advanced(by: currentBufferOffset), count: samplesToRead)

            samplesWritten += samplesToRead
            currentBufferOffset += samplesToRead
            let consumedDuration = TimeInterval(samplesToRead)
                / TimeInterval(max(front.channelCount * front.sampleRate, 1))
            queuedAudioDuration = max(0, queuedAudioDuration - consumedDuration)
            if let presentationTime = queued.presentationTime {
                let consumedFrames = currentBufferOffset / max(front.channelCount, 1)
                audiblePresentationTime = presentationTime
                    + TimeInterval(consumedFrames) / TimeInterval(max(front.sampleRate, 1))
            }

            if currentBufferOffset >= frontTotalSamples {
                pendingBufferDeallocations.append(front.data)
                _ = bufferQueue.removeFirst()
                currentBufferOffset = 0
            }
        }

        let primarySamplesWritten = samplesWritten
        let callbackDuration = TimeInterval(frameCount) / TimeInterval(max(sampleRate, 1))
        if isCrossfadeActive,
           !isCrossfadeMixing,
           queuedAudioDuration <= crossfadePlannedDuration + callbackDuration {
            isCrossfadeMixing = true
        }

        if isCrossfadeMixing,
           let crossfadeScratch,
           !crossfadeQueue.isEmpty {
            crossfadeScratch.update(repeating: 0, count: totalSamples)
            var secondarySamplesWritten = 0

            while secondarySamplesWritten < totalSamples,
                  !crossfadeQueue.isEmpty {
                guard let queued = crossfadeQueue.first else {
                    _ = crossfadeQueue.removeFirst()
                    crossfadeBufferOffset = 0
                    continue
                }
                let front = queued.buffer
                let frontTotalSamples = front.frameCount * front.channelCount
                let availableSamples = frontTotalSamples - crossfadeBufferOffset
                let samplesToRead = min(
                    totalSamples - secondarySamplesWritten,
                    availableSamples
                )

                crossfadeScratch.advanced(by: secondarySamplesWritten).update(
                    from: front.data.advanced(by: crossfadeBufferOffset),
                    count: samplesToRead
                )
                secondarySamplesWritten += samplesToRead
                crossfadeBufferOffset += samplesToRead

                let consumedDuration = TimeInterval(samplesToRead)
                    / TimeInterval(max(front.channelCount * front.sampleRate, 1))
                crossfadeQueuedDuration = max(0, crossfadeQueuedDuration - consumedDuration)
                if let presentationTime = queued.presentationTime {
                    let consumedFrames = crossfadeBufferOffset / max(front.channelCount, 1)
                    crossfadePresentationTime = presentationTime
                        + TimeInterval(consumedFrames) / TimeInterval(max(front.sampleRate, 1))
                }

                if crossfadeBufferOffset >= frontTotalSamples {
                    pendingBufferDeallocations.append(front.data)
                    _ = crossfadeQueue.removeFirst()
                    crossfadeBufferOffset = 0
                }
            }

            if primarySamplesWritten < totalSamples {
                output.advanced(by: primarySamplesWritten).update(
                    repeating: 0,
                    count: totalSamples - primarySamplesWritten
                )
            }

            let primaryFrames = primarySamplesWritten / max(channelCount, 1)
            let secondaryFrames = secondarySamplesWritten / max(channelCount, 1)
            let overlapFrames = min(primaryFrames, secondaryFrames)
            for frame in 0..<overlapFrames {
                let progress = min(
                    1,
                    Float(crossfadeFramesRendered + frame + 1)
                        / Float(max(crossfadeTotalFrames, 1))
                )
                let outgoingLevel = 1 + (crossfadeOutgoingTrim - 1) * progress
                let incomingLevel = crossfadeIncomingTrim + (1 - crossfadeIncomingTrim) * progress
                let oldGain = sqrtf(max(0, 1 - progress)) * outgoingLevel
                let newGain = sqrtf(progress) * incomingLevel
                for channel in 0..<channelCount {
                    let index = frame * channelCount + channel
                    output[index] = output[index] * oldGain
                        + crossfadeScratch[index] * newGain
                }
            }

            // If the primary lane ends inside this hardware callback, the
            // remainder belongs entirely to the new track. Conversely, when
            // the secondary lane is temporarily short, keep the primary signal
            // untouched instead of fading it toward silence.
            if secondaryFrames > primaryFrames {
                for frame in primaryFrames..<secondaryFrames {
                    for channel in 0..<channelCount {
                        let index = frame * channelCount + channel
                        output[index] = crossfadeScratch[index]
                    }
                }
            }

            crossfadeFramesRendered += overlapFrames
            samplesWritten = max(primarySamplesWritten, secondarySamplesWritten)
        }

        if isCrossfadeActive, bufferQueue.isEmpty {
            swap(&bufferQueue, &crossfadeQueue)
            currentBufferOffset = crossfadeBufferOffset
            queuedAudioDuration = crossfadeQueuedDuration
            audiblePresentationTime = crossfadePresentationTime

            crossfadeBufferOffset = 0
            crossfadeQueuedDuration = 0
            crossfadePresentationTime = nil
            isCrossfadeActive = false
            isCrossfadeMixing = false
            crossfadePlannedDuration = 0
            crossfadeTotalFrames = 0
            crossfadeFramesRendered = 0
        }

        if samplesWritten < totalSamples, !inputHasEnded {
            let now = DispatchTime.now().uptimeNanoseconds
            if now &- lastStarvationAt < Self.starvationClusterWindowNanos {
                isRebuffering = true
            }
            lastStarvationAt = now
        }

        // `samplesWritten` still contains only PCM consumed from the primary or
        // crossfade queues here. Any synthetic fade tail / zero fill is added
        // after releasing the lock and therefore never enters listening stats.
        let audibleFramesWritten = samplesWritten / max(channelCount, 1)
        if audibleFramesWritten > 0 {
            audibleOutputDuration += TimeInterval(audibleFramesWritten)
                / TimeInterval(max(sampleRate, 1))
        }

        os_unfair_lock_unlock(&bufferLock)

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

        guard samplesWritten > 0 else {
            recordRenderObservation(
                output: UnsafePointer(output),
                sampleCount: totalSamples,
                realPCMFrameCount: audibleFramesWritten
            )
            return
        }

        // Feed the dedicated measurement path before AudioFilterGraph, fixed EQ,
        // and repair processing. `SpectrumAnalyzer.feed` is try-lock based and
        // never waits on its worker from the real-time render callback.
        let protectionLevel = currentRealtimeProtectionLevel()
        if protectionLevel < 2,
           let analyzer = analysisSpectrumAnalyzer,
           analyzer.isActive {
            let analysisFrameCount = min(
                frameCount,
                samplesWritten / max(channelCount, 1)
            )
            if analysisFrameCount > 0 {
                analyzer.feed(
                    samples: output,
                    frameCount: analysisFrameCount,
                    channelCount: channelCount,
                    sampleRate: Double(sampleRate)
                )
            }
        }

        // 在效果器之前保存 raw PCM 末尾样本，确保不连续检测比较的是同类信号
        if totalSamples >= channelCount, let lastFrameSamples {
            let lastFrameOffset = totalSamples - channelCount
            for channel in 0..<channelCount {
                lastFrameSamples[channel] = output[lastFrameOffset + channel]
            }
        }

        if let graph = audioFilterGraph {
            let buffer = AudioBuffer(
                data: output,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: sampleRate
            )
            let processed = graph.process(buffer)
            if processed.data != output {
                // 非原地输出指向滤镜图持有的持久 scratch，只读拷贝、
                // 绝不在实时线程上释放。
                let processedSampleCount = processed.frameCount * processed.channelCount
                let copyCount = min(processedSampleCount, totalSamples)
                output.update(from: processed.data, count: copyCount)
                if copyCount < totalSamples {
                    output.advanced(by: copyCount).update(
                        repeating: 0,
                        count: totalSamples - copyCount
                    )
                }
            }
        }

        if let eqFilter {
            let buffer = AudioBuffer(
                data: output,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: sampleRate
            )
            _ = eqFilter.process(buffer)
        }

        if let repairEngine {
            repairEngine.process(
                output,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: sampleRate
            )
        }

        // Feed post-effect visual analysis directly from the already available
        // interleaved render buffer. A permanent mainMixer tap created another
        // AVAudioEngine delivery path even when no consumer existed.
        if protectionLevel == 0,
           let analyzer = spectrumAnalyzer,
           analyzer.isActive {
            analyzer.feed(
                samples: output,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: Double(sampleRate)
            )
        }

        if protectionLevel < 2, let callback = onAudioData {
            callback(output, frameCount, channelCount, sampleRate)
        }

        recordRenderObservation(
            output: UnsafePointer(output),
            sampleCount: totalSamples,
            realPCMFrameCount: audibleFramesWritten
        )
    }
}
