// StreamPlayer.swift
// FFmpegSwiftSDK
//
// Public API for streaming media playback. Orchestrates ConnectionManager,
// Demuxer, AudioDecoder, VideoDecoder, EQFilter, AudioRenderer, VideoRenderer,
// and AVSyncController into a unified playback pipeline.

import Foundation
import CFFmpeg
import AudioToolbox
import AVFoundation

// MARK: - PlaybackState

/// Represents the current state of the stream player.
public enum PlaybackState: Equatable {
    /// No playback session is active.
    case idle
    /// Connecting to the media source.
    case connecting
    /// Actively playing audio/video.
    case playing
    /// Playback is paused.
    case paused
    /// Playback has been stopped.
    case stopped
    /// An error occurred during playback.
    case error(FFmpegError)
}

// MARK: - StreamPlayerDelegate

/// Delegate protocol for receiving playback state changes, errors, and duration updates.
public protocol StreamPlayerDelegate: AnyObject {
    /// Called when the player's playback state changes.
    func player(_ player: StreamPlayer, didChangeState state: PlaybackState)
    /// Called when the player encounters an error.
    func player(_ player: StreamPlayer, didEncounterError error: FFmpegError)
    /// Called when the player updates the current playback duration/time.
    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval)
    /// 无缝切歌：当前歌曲播放完毕，已自动切换到预加载的下一首
    func playerDidTransitionToNextTrack(_ player: StreamPlayer)
}

// MARK: - StreamPlayer

/// A streaming media player that connects to a URL, demuxes, decodes, and renders audio/video.
///
/// `StreamPlayer` provides a simple API for playback control: `play(url:)`, `pause()`,
/// `resume()`, and `stop()`. Internally it orchestrates the full pipeline:
/// `ConnectionManager → Demuxer → Decoder → EQFilter → Renderer`.
///
/// Demuxing and decoding run on a dedicated background `DispatchQueue` to avoid
/// blocking the main thread. State changes are communicated via `StreamPlayerDelegate`.
///
/// Usage:
/// ```swift
/// let player = StreamPlayer()
/// player.delegate = self
/// player.play(url: "rtmp://example.com/live/stream")
/// // ...
/// player.pause()
/// player.resume()
/// player.stop()
/// ```
public final class StreamPlayer {

    // MARK: - Public Properties

    /// Delegate for receiving state changes, errors, and duration updates.
    public weak var delegate: StreamPlayerDelegate?

    /// The current playback state.
    public private(set) var state: PlaybackState = .idle {
        didSet {
            if oldValue != state {
                delegate?.player(self, didChangeState: state)
            }
        }
    }

    /// The current playback time in seconds.
    /// 实际播放位置 = 解码位置 - 缓冲队列中尚未播放的时长
    public var currentTime: TimeInterval {
        let deferredTransition = stateQueue.sync {
            (
                deadline: audibleTransitionDeadline,
                previousDuration: previousTrackActualDuration,
                transitionStartedAt: audibleTransitionStartedAt,
                displayStartTime: previousTrackDisplayStartTime
            )
        }
        if let deadline = deferredTransition.deadline,
           let previousDuration = deferredTransition.previousDuration,
           let transitionStartedAt = deferredTransition.transitionStartedAt,
           let displayStartTime = deferredTransition.displayStartTime,
           Date() < deadline {
            let elapsed = max(0, Date().timeIntervalSince(transitionStartedAt))
            return min(previousDuration, max(0, displayStartTime + elapsed))
        }

        let decoded = stateQueue.sync { self.decodedTime }
        let buffered = audioRenderer.queuedDuration
        return max(0, decoded - buffered)
    }

    /// 解码线程更新的已解码时间（入队时间点，非实际播放时间点）
    private var decodedTime: TimeInterval = 0

    /// 无缝切歌时，上一首歌曲的实际解码时长（EOF 时的 decodedTime）
    public private(set) var previousTrackActualDuration: TimeInterval?

    /// Metadata about the currently playing stream, or `nil` if not connected.
    public private(set) var streamInfo: StreamInfo?

    /// The public audio equalizer for adjusting frequency band gains.
    public let equalizer: AudioEqualizer

    /// 音频效果控制器：音量、变速、响度标准化。
    public let audioEffects: AudioEffects

    /// 实时频谱分析器。设置 onSpectrum 回调并启用后，
    /// 每个 FFT 窗口会回调一次频率幅度数据。
    public let spectrumAnalyzer: SpectrumAnalyzer

    /// 波形预览生成器。独立于播放 pipeline，可在后台生成波形数据。
    public let waveformGenerator: WaveformGenerator

    /// 元数据读取器。读取音频文件的 ID3 标签、专辑封面等。
    public let metadataReader: MetadataReader

    /// 歌词同步引擎。加载 LRC 歌词后，根据播放时间实时匹配当前行。
    ///
    /// ```swift
    /// player.lyricSyncer.load(lrcContent: lrcString)
    /// player.lyricSyncer.onSync = { lineIndex, line, wordIndex, progress in
    ///     // 更新 UI：高亮当前行
    /// }
    /// ```
    public let lyricSyncer: LyricSyncer

    /// 音频修复引擎。自动检测并修复削波、电流声、卡顿、爆音等问题。
    ///
    /// 推荐在播放开始时一键启用：
    /// ```swift
    /// player.audioRepair.enableAll()
    /// ```
    /// 也可按需单独启用：
    /// ```swift
    /// player.audioRepair.isDeclipEnabled = true
    /// player.audioRepair.isSoftLimiterEnabled = true
    /// ```
    public var audioRepair: AudioRepairEngine { repairEngine }
    
    /// 音频数据回调。在音频渲染线程调用，用于实时音频分析、识别等。
    /// 回调参数：PCM Float32 数据、帧数、声道数、采样率
    public var onAudioData: ((_ samples: UnsafePointer<Float>, _ frameCount: Int, _ channelCount: Int, _ sampleRate: Int) -> Void)?

    /// The video display layer. Add this to your view's layer hierarchy to show video.
    ///
    /// Usage (UIKit):
    /// ```swift
    /// view.layer.addSublayer(player.videoDisplayLayer)
    /// player.videoDisplayLayer.frame = view.bounds
    /// ```
    public var videoDisplayLayer: AVSampleBufferDisplayLayer {
        return videoRenderer.sampleBufferDisplayLayer
    }

    /// 视频是否正在使用 VideoToolbox 硬件加速解码。
    /// 仅在播放视频流时有意义，无视频时返回 false。
    public var isVideoHardwareAccelerated: Bool {
        return stateQueue.sync { videoDecoder?.isHardwareAccelerated ?? false }
    }

    // MARK: - Internal Components

    /// The EQ filter used for audio processing.
    internal let eqFilter: EQFilter

    /// FFmpeg avfilter 音频滤镜图（loudnorm、atempo、volume）
    internal let audioFilterGraph: AudioFilterGraph

    /// 音频修复引擎
    internal let repairEngine: AudioRepairEngine

    /// The connection manager for establishing media connections.
    private var connectionManager: ConnectionManager?

    /// The demuxer for separating audio/video packets.
    private var demuxer: Demuxer?

    /// The audio decoder.
    private var audioDecoder: AudioDecoder?

    /// The video decoder.
    private var videoDecoder: VideoDecoder?

    /// The audio renderer.
    private let audioRenderer: AudioRenderer

    /// The video renderer.
    private let videoRenderer: VideoRenderer

    /// The A/V sync controller.
    private let syncController: AVSyncController

    // MARK: - Queues & State

    /// Dedicated background queue for demuxing and decoding.
    private let playbackQueue = DispatchQueue(label: "com.ffmpeg-sdk.playback", qos: .userInitiated)

    /// Serial queue for synchronizing state changes.
    private let stateQueue = DispatchQueue(label: "com.ffmpeg-sdk.player-state")

    /// Flag indicating whether the playback loop should continue.
    private var isPlaybackActive: Bool = false

    /// The URL of the current playback session.
    private var currentURL: String?

    /// Seek 请求：播放循环会检查此值并在安全时刻执行 seek
    private var pendingSeekTime: TimeInterval? = nil
    private let seekLock = NSLock()

    /// seek 后的目标时间，用于抑制 seek 点之前的旧 PTS 更新 currentTime
    /// demuxer seek 到关键帧（通常在目标之前），解码出的前几个 packet PTS 会小于目标
    private var seekTargetTime: TimeInterval? = nil

    /// 音频流的 time_base，用于将 packet PTS 精确转换为秒
    private var audioTimeBase: AVRational = AVRational(num: 0, den: 1)

    /// 首个 audio packet 的 PTS（秒），用于消除容器/编码器起始偏移
    /// 很多音频文件第一个 packet PTS 不是 0（编码器延迟、容器头部偏移等）
    private var audioPTSOffset: TimeInterval? = nil

    /// 网络断流连续重连次数（成功读包后重置为 0）
    private var networkReconnectAttempts: Int = 0
    private let maxNetworkReconnectAttempts: Int = 3

    // MARK: - A-B 循环

    /// A-B 循环的 A 点（秒），nil = 未设置
    private var loopPointA: TimeInterval? = nil
    /// A-B 循环的 B 点（秒），nil = 未设置
    private var loopPointB: TimeInterval? = nil
    /// A-B 循环是否启用
    private var abLoopEnabled: Bool = false

    /// 交叉淡入淡出时长（秒）
    private var crossfadeDuration: Float = 0.0

    // MARK: - Gapless Playback (预加载下一首)

    /// 预加载的下一首 pipeline 组件
    private var nextConnectionManager: ConnectionManager?
    private var nextDemuxer: Demuxer?
    private var nextAudioDecoder: AudioDecoder?
    private var nextStreamInfo: StreamInfo?
    private var nextAudioTimeBase: AVRational = AVRational(num: 0, den: 1)
    private var nextURL: String?
    /// 预加载是否就绪
    private var isNextReady: Bool = false
    private var forceTransition: Bool = false
    /// 是否允许在 EOF 时自动切到已预加载的下一首。
    /// 关闭后仍然允许 prepareNext / switchToNext 用于音质切换等显式流程，
    /// 只是不会在当前歌曲自然结束时自动切到 next pipeline。
    private var automaticPreparedTrackTransitionEnabled: Bool = true
    /// 当前歌曲已切换到下一条 pipeline，但旧音频尾巴仍在输出中的截止时刻。
    /// 在此之前 currentTime 应保持在上一首结束位置，UI 也不应立刻切到下一首。
    private var audibleTransitionDeadline: Date?
    /// 延迟切换 UI 期间，旧歌曲尾声开始“继续走表”的起始时刻。
    private var audibleTransitionStartedAt: Date?
    /// 延迟切换 UI 期间，旧歌曲在切换当下的实际可听播放位置。
    private var previousTrackDisplayStartTime: TimeInterval?
    /// 延迟通知 app 层“已切到下一首”的任务。
    private var pendingTransitionNotificationWorkItem: DispatchWorkItem?
    /// 暂停信号量，暂停时阻塞解码线程，resume 时唤醒
    private let pauseSemaphore = DispatchSemaphore(value: 0)
    private let prepareQueue = DispatchQueue(label: "com.ffmpeg-sdk.prepare-next", qos: .utility)

    // MARK: - Initialization

    /// Creates a new `StreamPlayer` with default components.
    public init() {
        self.eqFilter = EQFilter()
        self.audioFilterGraph = AudioFilterGraph()
        self.repairEngine = AudioRepairEngine()
        self.equalizer = AudioEqualizer(filter: eqFilter)
        self.audioEffects = AudioEffects(filterGraph: audioFilterGraph)
        self.spectrumAnalyzer = SpectrumAnalyzer()
        self.waveformGenerator = WaveformGenerator()
        self.metadataReader = MetadataReader()
        self.lyricSyncer = LyricSyncer()
        self.audioRenderer = AudioRenderer()
        self.videoRenderer = VideoRenderer()
        self.syncController = AVSyncController()
        self.audioRenderer.setEQFilter(eqFilter)
        self.audioRenderer.setAudioFilterGraph(audioFilterGraph)
        self.audioRenderer.setSpectrumAnalyzer(spectrumAnalyzer)
        self.audioRenderer.setRepairEngine(repairEngine)
        // 设置 equalizer 的 audioEffects 引用，用于应用预设的环绕效果
        self.equalizer.audioEffects = self.audioEffects
        
        // 将 StreamPlayer 的音频回调桥接到 AudioRenderer
        self.audioRenderer.onAudioData = { [weak self] samples, frameCount, channelCount, sampleRate in
            self?.onAudioData?(samples, frameCount, channelCount, sampleRate)
        }
    }

    deinit {
        stopInternal()
    }

    // MARK: - Playback Control

    /// Starts playback from the given URL.
    ///
    /// This method is non-blocking. It kicks off the connection and playback
    /// pipeline on a background queue. State changes are reported via the delegate.
    ///
    /// If a session is already active, it is stopped first before starting the new one.
    ///
    /// - Parameter url: The URL of the media source (RTMP, HLS, RTSP, etc.).
    public func play(url: String, decryptionKey: String? = nil) {
        // Stop any existing session first
        stopInternal()
        // 清理预加载（手动切歌时预加载的下一首可能已不正确）
        cancelNextPreparation()

        // Allow video renderer to accept frames for the new session.
        videoRenderer.resetForNewSession()

        stateQueue.sync {
            self.isPlaybackActive = true
            self.currentURL = url
            self.decodedTime = 0
            self.streamInfo = nil
        }

        // Transition to connecting
        transitionState(to: .connecting)

        // Start the pipeline on the background queue
        playbackQueue.async { [weak self] in
            self?.startPipeline(url: url, decryptionKey: decryptionKey)
        }
    }

    /// Pauses the current playback.
    ///
    /// Audio and video rendering are paused but the session remains active.
    /// Call `resume()` to continue playback.
    public func pause() {
        guard state == .playing else { return }
        audioRenderer.pause()
        transitionState(to: .paused)
    }

    /// Resumes playback after a pause.
    ///
    /// Has no effect if the player is not in the `.paused` state.
    public func resume() {
        guard state == .paused else { return }
        audioRenderer.resume()
        transitionState(to: .playing)
        pauseSemaphore.signal()
    }

    /// Stops playback and releases all resources.
    ///
    /// After calling `stop()`, the player returns to a state where `play(url:)`
    /// can be called again to start a new session.
    public func stop() {
        stopInternal()
        transitionState(to: .stopped)
    }

    /// Seeks to the specified time position in seconds.
    ///
    /// 将 seek 请求投递给播放循环，由播放循环在安全时刻执行，
    /// 避免与 demuxer 的 readNextPacket 产生线程竞争。
    ///
    /// - Parameter time: The target position in seconds.
    public func seek(to time: TimeInterval) {
        seekLock.lock()
        pendingSeekTime = time
        seekLock.unlock()
        if state == .paused {
            pauseSemaphore.signal()
        }
    }

    // MARK: - A-B 循环

    /// 设置 A-B 循环区间。设置后自动启用循环。
    ///
    /// 播放到 B 点时自动 seek 回 A 点，实现精确区间循环。
    /// 适用于练歌、学习乐器等场景。
    ///
    /// - Parameters:
    ///   - pointA: A 点时间（秒）
    ///   - pointB: B 点时间（秒），必须大于 A 点
    public func setABLoop(pointA: TimeInterval, pointB: TimeInterval) {
        guard pointB > pointA else { return }
        stateQueue.sync {
            self.loopPointA = pointA
            self.loopPointB = pointB
            self.abLoopEnabled = true
        }
    }

    /// 清除 A-B 循环，恢复正常播放。
    public func clearABLoop() {
        stateQueue.sync {
            self.loopPointA = nil
            self.loopPointB = nil
            self.abLoopEnabled = false
        }
    }

    /// A-B 循环是否启用。
    public var isABLoopEnabled: Bool {
        stateQueue.sync { abLoopEnabled }
    }

    /// 当前 A-B 循环的 A 点（秒），nil = 未设置。
    public var abLoopPointA: TimeInterval? {
        stateQueue.sync { loopPointA }
    }

    /// 当前 A-B 循环的 B 点（秒），nil = 未设置。
    public var abLoopPointB: TimeInterval? {
        stateQueue.sync { loopPointB }
    }

    // MARK: - 交叉淡入淡出

    /// 设置交叉淡入淡出时长。
    ///
    /// 当使用 prepareNext + 无缝切歌时，当前歌曲结尾会淡出，
    /// 下一首歌曲开头会淡入，两者重叠产生 DJ 混音效果。
    ///
    /// - Parameter duration: 交叉淡入淡出时长（秒），0 = 关闭。
    ///   典型值：3~8 秒。
    public func setCrossfadeDuration(_ duration: Float) {
        audioEffects.setFadeIn(duration: duration)
        // 淡出需要知道歌曲总时长，在 startPipeline 中动态设置
        stateQueue.sync {
            self.crossfadeDuration = duration
        }
    }

    /// 当前交叉淡入淡出时长（秒）。
    public var currentCrossfadeDuration: Float {
        stateQueue.sync { crossfadeDuration }
    }

    /// 预加载下一首歌曲，实现无缝切歌（gapless playback）。
    ///
    /// 在后台队列连接并初始化下一首的 demuxer + decoder，
    /// 当前歌曲 EOF 时直接切换 pipeline，AudioRenderer 不中断。
    ///
    /// - Parameter url: 下一首歌曲的 URL
    public func prepareNext(url: String) {
        // 取消之前的预加载
        cancelNextPreparation()

        stateQueue.sync {
            self.nextURL = url
            self.isNextReady = false
        }

        prepareQueue.async { [weak self] in
            self?.performNextPreparation(url: url)
        }
    }

    /// 立即切换到预加载的下一首（用于音质切换等场景）。
    /// 不等 EOF，主动触发切换，可指定 seek 位置。
    /// - Parameter seekTo: 切换后 seek 到的位置（秒），nil 表示从头播放
    public func switchToNext(seekTo: TimeInterval? = nil) {
        guard stateQueue.sync(execute: { self.isNextReady }) else { return }
        // 投递 seek 请求，transitionToNextTrack 后播放循环会处理
        if let time = seekTo {
            seekLock.lock()
            pendingSeekTime = time
            seekLock.unlock()
        }
        // 设置标志让播放循环在下次迭代时触发切换
        stateQueue.sync {
            self.forceTransition = true
        }
    }

    /// 取消预加载
    public func cancelNextPreparation() {
        stateQueue.sync {
            nextConnectionManager?.disconnect()
            nextConnectionManager = nil
            nextDemuxer = nil
            nextAudioDecoder = nil
            nextStreamInfo = nil
            nextAudioTimeBase = AVRational(num: 0, den: 1)
            nextURL = nil
            isNextReady = false
            forceTransition = false
        }
    }

    /// 处理音频路由变化（蓝牙连接/断开）。
    ///
    /// 当蓝牙设备连接或断开导致硬件采样率变化时，安全重建音频引擎，
    /// 避免 `AVAudioSourceNode` 格式不匹配导致的闪退。
    public func handleAudioRouteChange() {
        audioRenderer.handleRouteChange()
    }

    /// 控制 EOF 时是否允许自动切到已预加载的下一首。
    /// 该开关不会影响显式的 `switchToNext()`，因此不会破坏音质切换流程。
    public func setAutomaticPreparedTrackTransitionEnabled(_ enabled: Bool) {
        stateQueue.sync {
            self.automaticPreparedTrackTransitionEnabled = enabled
        }
    }

    /// 在播放循环中安全执行 seek（仅在 playbackQueue 上调用）
    /// 尝试先预解目标位置的一小段音频，再切换到新位置，尽量缩短 seek 后的静音。
    private func processPendingSeek(demuxer: Demuxer) {
        seekLock.lock()
        guard let seekTime = pendingSeekTime else {
            seekLock.unlock()
            return
        }
        pendingSeekTime = nil
        seekLock.unlock()

        do {
            try demuxer.seek(to: seekTime)

            // seek 后清空解码器内部状态，避免旧位置残帧混入新位置
        stateQueue.sync {
                self.audioDecoder?.flush()
                self.videoDecoder?.flush()
                self.decodedTime = seekTime
                self.seekTargetTime = seekTime
                // seek 后让音频 PTS 偏移重新按目标位置计算。
                // 对冷启动恢复播放，新的解码流第一帧 PTS 往往就是 seek 目标附近；
                // 如果沿用“首帧归零”的逻辑，会让外部 currentTime 从 0 重新开始，
                // 导致 app 层永远认为还没 seek 到目标位置。
                self.audioPTSOffset = nil
            }

        syncController.reset()
        repairEngine.reset()
            lyricSyncer.reset()

            let prerollBatches = prepareSeekAudioPreroll(demuxer: demuxer)

            // 真正切到新位置前再清空旧队列，尽量让旧位置尾音覆盖 seek 准备期。
            audioRenderer.flushQueue()

            if !prerollBatches.isEmpty {
                for batch in prerollBatches {
                    handleDecodedAudioBuffers(
                        batch.buffers,
                        packetPTS: batch.packetPTS,
                        timeBase: batch.timeBase,
                        enqueueToRenderer: true
                    )
                }
                let prerollDuration = prerollBatches.reduce(0) { partial, batch in
                    partial + batch.buffers.reduce(0) { $0 + $1.duration }
                }
                print(
                    "[StreamPlayer] 🎯 seek preroll ready: target=\(String(format: "%.3f", seekTime))s, " +
                    "batches=\(prerollBatches.count), buffered=\(String(format: "%.3f", prerollDuration))s"
                )
            } else {
                print(
                    "[StreamPlayer] 🎯 seek preroll unavailable, fall back to direct refill: " +
                    "target=\(String(format: "%.3f", seekTime))s"
                )
            }
        } catch {
            print("[StreamPlayer] ⚠️ seek failed: target=\(String(format: "%.3f", seekTime))s, error=\(error)")
        }
    }

    private struct SeekAudioPrerollBatch {
        let packetPTS: Int64
        let timeBase: AVRational
        let buffers: [AudioBuffer]
    }

    private func prepareSeekAudioPreroll(demuxer: Demuxer) -> [SeekAudioPrerollBatch] {
        guard stateQueue.sync(execute: { self.audioDecoder != nil }) else { return [] }

        let maxPrerollDuration: TimeInterval = 0.22
        let maxPreparationTime: TimeInterval = 0.45
        let maxPackets = 48
        let timeBase = stateQueue.sync { self.audioTimeBase }

        var prerollBatches: [SeekAudioPrerollBatch] = []
        var prerollDuration: TimeInterval = 0
        let start = Date()

        for _ in 0..<maxPackets {
            if prerollDuration >= maxPrerollDuration {
                break
            }
            if Date().timeIntervalSince(start) > maxPreparationTime {
                break
            }

            let packet: Demuxer.PacketType?
            do {
                packet = try demuxer.readNextPacket()
            } catch {
                break
            }

            guard let packet else { break }

            switch packet {
            case .audio(let pkt):
                let packetPTS = pkt.pointee.pts
                defer {
                    releasePacket(pkt)
                }

                guard let decoder = stateQueue.sync(execute: { self.audioDecoder }) else {
                    continue
                }

                do {
                    let audioBuffers = try decoder.decodeAll(packet: pkt)
                    var validBuffers: [AudioBuffer] = []
                    validBuffers.reserveCapacity(audioBuffers.count)
                    for buffer in audioBuffers {
                        if buffer.frameCount > 0 && buffer.duration > 0 {
                            validBuffers.append(buffer)
                        } else {
                            buffer.data.deallocate()
                        }
                    }
                    guard !validBuffers.isEmpty else { continue }

                    prerollDuration += validBuffers.reduce(0) { $0 + $1.duration }
                    prerollBatches.append(
                        SeekAudioPrerollBatch(
                            packetPTS: packetPTS,
                            timeBase: timeBase,
                            buffers: validBuffers
                        )
                    )
        } catch {
                    continue
                }

            case .video(let pkt):
                releasePacket(pkt)
            }
        }

        return prerollBatches
    }

    // MARK: - Pipeline

    /// Starts the full playback pipeline: connect → demux → decode → render.
    ///
    /// This method runs on the playback queue and blocks until playback ends
    /// (either by reaching EOF, encountering an unrecoverable error, or being stopped).
    private func startPipeline(url: String, decryptionKey: String? = nil) {
        let manager = ConnectionManager()
        manager.decryptionKey = decryptionKey
        stateQueue.sync { self.connectionManager = manager }

        // Step 1: Connect
        let formatContext: FFmpegFormatContext
        do {
            // Use a semaphore to bridge async connect to the sync playback queue
            var connectResult: Result<FFmpegFormatContext, Error>?
            let semaphore = DispatchSemaphore(value: 0)

            Task {
                do {
                    let ctx = try await manager.connect(url: url)
                    connectResult = .success(ctx)
                } catch {
                    connectResult = .failure(error)
                }
                semaphore.signal()
            }

            semaphore.wait()

            switch connectResult! {
            case .success(let ctx):
                formatContext = ctx
            case .failure(let error):
                throw error
            }
        } catch {
            handleUnrecoverableError(error)
            return
        }

        // Check if we were stopped during connection
        guard isActive() else { return }

        // Step 2: Demux - find streams
        let demuxer = Demuxer(formatContext: formatContext, url: url)
        stateQueue.sync { self.demuxer = demuxer }

        let info: StreamInfo
        do {
            info = try demuxer.findStreams()
            stateQueue.sync { self.streamInfo = info }
        } catch {
            handleUnrecoverableError(error)
            return
        }

        guard isActive() else { return }

        // Step 3: 先启动 AudioRenderer，获取硬件实际采样率
        // iOS 设备请求高采样率（如 192kHz）后，硬件可能给出不同的实际值
        var hwSampleRate: Int? = nil
        if info.hasAudio, let sampleRate = info.sampleRate, let channelCount = info.channelCount {
            do {
                let format = makeAudioFormat(sampleRate: sampleRate, channelCount: channelCount)
                try audioRenderer.start(format: format)
                hwSampleRate = audioRenderer.actualSampleRate
            } catch {
                handleUnrecoverableError(error)
                return
            }
        }

        guard isActive() else { return }

        // Step 4: 初始化解码器，用硬件实际采样率作为 SwrContext 输出目标
        // 如果硬件采样率与源不同，SwrContext 会自动重采样
        do {
            try initializeDecoders(
                formatContext: formatContext,
                demuxer: demuxer,
                streamInfo: info,
                targetSampleRate: hwSampleRate
            )
        } catch {
            handleUnrecoverableError(error)
            return
        }

        // Transition to playing
        transitionState(to: .playing)

        // Notify duration if available
        if let duration = info.duration {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.player(self, didUpdateDuration: duration)
            }
        }

        // Step 5: Run the demux/decode loop
        syncController.reset()
        runPlaybackLoop(demuxer: demuxer)
    }

    /// Initializes audio and video decoders based on the discovered streams.
    private func initializeDecoders(
        formatContext: FFmpegFormatContext,
        demuxer: Demuxer,
        streamInfo: StreamInfo,
        targetSampleRate: Int? = nil
    ) throws {
        // Initialize audio decoder
        if streamInfo.hasAudio, demuxer.currentAudioStreamIndex >= 0 {
            let streamIndex = Int(demuxer.currentAudioStreamIndex)
            if let stream = formatContext.stream(at: streamIndex),
               let codecpar = stream.pointee.codecpar {
                let codecID = codecpar.pointee.codec_id
                // 保存音频流的 time_base，用于 PTS → 秒 的精确转换
                stateQueue.sync { self.audioTimeBase = stream.pointee.time_base }
                do {
                    let decoder = try AudioDecoder(
                        codecParameters: codecpar,
                        codecID: codecID,
                        targetSampleRate: targetSampleRate
                    )
                    stateQueue.sync { self.audioDecoder = decoder }
                } catch {
                    // Audio decoder init failure is unrecoverable if we only have audio
                    if !streamInfo.hasVideo { throw error }
                    // If we have video too, we can continue without audio
                }
            }
        }

        // Initialize video decoder
        if streamInfo.hasVideo, demuxer.currentVideoStreamIndex >= 0 {
            let streamIndex = Int(demuxer.currentVideoStreamIndex)
            if let stream = formatContext.stream(at: streamIndex),
               let codecpar = stream.pointee.codecpar {
                let codecID = codecpar.pointee.codec_id
                let timeBase = stream.pointee.time_base
                do {
                    let decoder = try VideoDecoder(
                        codecParameters: codecpar,
                        codecID: codecID,
                        timeBase: timeBase
                    )
                    stateQueue.sync { self.videoDecoder = decoder }
                } catch {
                    // Video decoder init failure is unrecoverable if we only have video
                    if !streamInfo.hasAudio { throw error }
                }
            }
        }
    }

    /// The main demux/decode loop. Reads packets, decodes them, and sends
    /// the output to the appropriate renderer.
    ///
    /// Individual frame decoding errors are caught and skipped (recoverable).
    /// Unrecoverable errors (resource allocation failures, connection loss,
    /// unsupported formats) stop the loop and trigger auto-stop via delegate.
    /// Network disconnection errors are detected and propagated through the
    /// ConnectionManager delegate before notifying the app layer.
    ///
    /// Backpressure: When the audio renderer's buffer queue exceeds the max
    /// threshold, the loop sleeps briefly to let the renderer catch up. This
    /// prevents unbounded memory growth and ensures we don't race past EOF
    /// before audio finishes playing.
    private func runPlaybackLoop(demuxer initialDemuxer: Demuxer) {
        while isActive() {
            // 优先处理强制切换（音质切换），确保 pendingSeekTime 作用在新 demuxer 上
            let shouldForceTransition = stateQueue.sync(execute: {
                let val = self.forceTransition
                self.forceTransition = false
                return val
            })
            if shouldForceTransition && transitionToNextTrack() {
                audioRenderer.flushQueue()
            }

            // 获取当前 demuxer（可能刚被 transition 替换）
            guard let currentDemuxer = stateQueue.sync(execute: { self.demuxer }) else { return }

            // 检查并处理 pending seek（线程安全，在 playbackQueue 上执行）
            processPendingSeek(demuxer: currentDemuxer)

            if state == .paused {
                pauseSemaphore.wait()
                continue
            }

            // Backpressure: wait if the audio renderer has too many queued buffers
            while isActive() && audioRenderer.queuedBufferCount > AudioRenderer.maxQueuedBuffers {
                Thread.sleep(forTimeInterval: 0.01)
            }
            guard isActive() else { return }

            let packet: Demuxer.PacketType?
            do {
                packet = try currentDemuxer.readNextPacket()
                networkReconnectAttempts = 0
            } catch let error as FFmpegError where error == .networkDisconnected {
                if attemptReconnect() {
                    continue
                }
                handleNetworkDisconnection()
                return
            } catch let error as FFmpegError where error.isUnrecoverable {
                handleUnrecoverableError(error)
                return
            } catch {
                handleUnrecoverableError(error)
                return
            }

            guard let packet = packet else {
                // EOF reached — drain decoder to get remaining buffered frames
                drainDecoderAtEOF()
                let underrunSerialAtEOF = audioRenderer.currentUnderrunSerial()
                let queuedTailAtEOF = audioRenderer.queuedDuration

                // 尝试无缝切换到预加载的下一首
                let shouldAutoTransitionToPreparedTrack = stateQueue.sync {
                    self.automaticPreparedTrackTransitionEnabled
                }
                if shouldAutoTransitionToPreparedTrack && transitionToNextTrack() {
                    continue
                }
                if !shouldAutoTransitionToPreparedTrack {
                    cancelNextPreparation()
                }
                // 没有预加载的下一首，正常结束
                waitForRendererDrain()
                waitForRendererUnderrun(
                    after: underrunSerialAtEOF,
                    maxWait: max(3.0, min(queuedTailAtEOF + 3.0, 15.0))
                )
                stopInternal()
                transitionState(to: .stopped)
                return
            }

            switch packet {
            case .audio(let pkt):
                if let unrecoverableError = processAudioPacket(pkt) {
                    handleUnrecoverableError(unrecoverableError)
                    return
                }
            case .video(let pkt):
                if let unrecoverableError = processVideoPacket(pkt) {
                    handleUnrecoverableError(unrecoverableError)
                    return
                }
            }
        }
    }

    /// Waits for the audio renderer to finish playing all queued buffers.
    ///
    /// EOF 时使用长超时，确保尾音完整播放；网络断流平滑收尾时可传入更短的超时窗口。
    private func waitForRendererDrain(maxWait: TimeInterval? = nil, requireActive: Bool = true) {
        let bufferedSeconds = audioRenderer.queuedDuration
        let resolvedMaxWait = maxWait ?? max(15.0, min(bufferedSeconds + 5.0, 20.0))
        let start = Date()
        while audioRenderer.queuedBufferCount > 0 {
            if requireActive && !isActive() {
                break
            }
            if Date().timeIntervalSince(start) > resolvedMaxWait {
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    /// Waits until the renderer has actually requested silence after EOF.
    /// This is more conservative than checking the queue alone, because
    /// AVAudioEngine may have already pulled some PCM ahead of audible output.
    private func waitForRendererUnderrun(
        after serial: UInt64,
        maxWait: TimeInterval,
        requireActive: Bool = true
    ) {
        let start = Date()
        while !audioRenderer.hasObservedUnderrun(since: serial) {
            if requireActive && !isActive() {
                break
            }
            if Date().timeIntervalSince(start) > maxWait {
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    // MARK: - Decoder Drain at EOF

    /// Drains the audio decoder at EOF to flush any remaining buffered frames into the renderer.
    private func drainDecoderAtEOF() {
        guard let decoder = stateQueue.sync(execute: { self.audioDecoder }) else { return }

        let remaining = decoder.drain()
        for buffer in remaining {
            audioRenderer.enqueue(buffer)

            let pts = stateQueue.sync { self.decodedTime }
            let endPts = pts + buffer.duration
            stateQueue.sync { self.decodedTime = endPts }
            syncController.updateAudioClock(endPts)
        }
    }

    // MARK: - Gapless: 预加载与切换

    /// 在后台执行下一首的预加载：连接 → demux → 初始化 decoder
    private func performNextPreparation(url: String) {
        let manager = ConnectionManager()

        // Step 1: 连接
        let formatContext: FFmpegFormatContext
        do {
            var connectResult: Result<FFmpegFormatContext, Error>?
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    let ctx = try await manager.connect(url: url)
                    connectResult = .success(ctx)
                } catch {
                    connectResult = .failure(error)
                }
                semaphore.signal()
            }
            semaphore.wait()

            switch connectResult! {
            case .success(let ctx): formatContext = ctx
            case .failure: return // 预加载失败，静默处理
            }
        }

        // 检查是否已被取消
        let stillValid = stateQueue.sync { self.nextURL == url }
        guard stillValid else {
            manager.disconnect()
            return
        }

        // Step 2: Demux - 查找流
        let demuxer = Demuxer(formatContext: formatContext, url: url)
        let info: StreamInfo
        do {
            info = try demuxer.findStreams()
        } catch {
            manager.disconnect()
            return
        }

        guard stateQueue.sync(execute: { self.nextURL == url }) else {
            manager.disconnect()
            return
        }

        // Step 3: 初始化 audio decoder
        // 使用当前 AudioRenderer 的采样率作为目标，避免需要重启 AudioUnit
        var decoder: AudioDecoder?
        var nextTimeBase = AVRational(num: 0, den: 1)
        if info.hasAudio, demuxer.currentAudioStreamIndex >= 0 {
            let streamIndex = Int(demuxer.currentAudioStreamIndex)
            if let stream = formatContext.stream(at: streamIndex),
               let codecpar = stream.pointee.codecpar {
                let codecID = codecpar.pointee.codec_id
                nextTimeBase = stream.pointee.time_base
                // 用当前 renderer 的实际采样率，这样不需要重启 AudioUnit
                let targetRate = audioRenderer.actualSampleRate > 0 ? audioRenderer.actualSampleRate : nil
                decoder = try? AudioDecoder(
                    codecParameters: codecpar,
                    codecID: codecID,
                    targetSampleRate: targetRate
                )
            }
        }

        guard decoder != nil else {
            manager.disconnect()
            return
        }

        guard stateQueue.sync(execute: { self.nextURL == url }) else {
            manager.disconnect()
            return
        }

        // 保存预加载结果
        stateQueue.sync {
            self.nextConnectionManager = manager
            self.nextDemuxer = demuxer
            self.nextAudioDecoder = decoder
            self.nextStreamInfo = info
            self.nextAudioTimeBase = nextTimeBase
            self.isNextReady = true
        }
    }

    /// 无缝切换到预加载的下一首。
    /// 在 playbackQueue 上调用（EOF 时），不停止 AudioRenderer。
    /// 如果新流的采样率或声道数与当前不同，会重启 AudioRenderer 以匹配新格式。
    /// - Returns: true 表示切换成功，播放循环应继续；false 表示没有预加载
    private func transitionToNextTrack() -> Bool {
        // 切 UI 的时机要和“用户还能听到上一首”的时机保持一致。
        // 这里不能再人为截断尾巴时长，否则在大缓冲场景下会提前显示下一首信息。
        let queuedTailDuration = audioRenderer.queuedDuration
        let remainingAudibleTail: TimeInterval
        if queuedTailDuration.isFinite && !queuedTailDuration.isNaN {
            remainingAudibleTail = max(0, queuedTailDuration)
        } else {
            remainingAudibleTail = 0
        }

        // 原子性地取出预加载的组件
        let (nextDemuxer, nextDecoder, nextInfo, nextTimeBase, nextConnMgr) = stateQueue.sync {
            () -> (Demuxer?, AudioDecoder?, StreamInfo?, AVRational, ConnectionManager?) in
            guard isNextReady else { return (nil, nil, nil, AVRational(num: 0, den: 1), nil) }

            let d = self.nextDemuxer
            let dec = self.nextAudioDecoder
            let info = self.nextStreamInfo
            let tb = self.nextAudioTimeBase
            let cm = self.nextConnectionManager

            // 清空预加载状态
            self.nextDemuxer = nil
            self.nextAudioDecoder = nil
            self.nextStreamInfo = nil
            self.nextAudioTimeBase = AVRational(num: 0, den: 1)
            self.nextConnectionManager = nil
            self.nextURL = nil
            self.isNextReady = false

            return (d, dec, info, tb, cm)
        }

        guard let demuxer = nextDemuxer, let decoder = nextDecoder, let info = nextInfo else {
            return false
        }

        // 检查新 decoder 的输出格式是否与当前 AudioRenderer 匹配
        let newSampleRate = decoder.outputSampleRate
        let newChannelCount = decoder.outputChannelCount
        let currentRendererRate = audioRenderer.actualSampleRate
        let needsRendererRestart =
            newSampleRate != currentRendererRate ||
            newChannelCount != stateQueue.sync(execute: { self.audioDecoder?.outputChannelCount ?? 0 })

        // 如果采样率或声道数变了，需要重启 AudioRenderer
        if needsRendererRestart {
            // 先清空旧缓冲区
            audioRenderer.flushQueue()
            // 停止旧的 AudioRenderer
            audioRenderer.stop()
            // 用新格式重启
            let format = makeAudioFormat(sampleRate: newSampleRate, channelCount: newChannelCount)
            do {
                try audioRenderer.start(format: format)
            } catch {
                // 重启失败，回退：尝试用旧格式重启
                let oldFormat = makeAudioFormat(sampleRate: currentRendererRate, channelCount: newChannelCount)
                try? audioRenderer.start(format: oldFormat)
            }
        }

        // 释放旧的 pipeline 组件（但不停止 AudioRenderer）
        stateQueue.sync {
            // 断开旧的连接管理器
            self.connectionManager?.disconnect()
            self.audioDecoder = nil
            self.videoDecoder = nil
            self.demuxer = demuxer
            self.audioDecoder = decoder
            self.connectionManager = nextConnMgr
            self.streamInfo = info
            self.audioTimeBase = nextTimeBase
            self.audioPTSOffset = nil  // 新歌曲重新计算 PTS 偏移
            self.currentURL = info.url
            // 如果有 pendingSeekTime（音质切换），保持当前时间不变
            // 否则是正常切歌，重置为 0
            if self.pendingSeekTime == nil {
                self.previousTrackActualDuration = self.decodedTime
                self.decodedTime = 0
                if needsRendererRestart {
                    self.audibleTransitionDeadline = nil
                    self.audibleTransitionStartedAt = nil
                    self.previousTrackDisplayStartTime = nil
                } else {
                    let now = Date()
                    self.audibleTransitionDeadline = now.addingTimeInterval(remainingAudibleTail)
                    self.audibleTransitionStartedAt = now
                    self.previousTrackDisplayStartTime = max(0, self.previousTrackActualDuration! - remainingAudibleTail)
                }
            } else {
                self.audibleTransitionDeadline = nil
                self.audibleTransitionStartedAt = nil
                self.previousTrackDisplayStartTime = nil
            }
        }

        // 重置同步控制器
        syncController.reset()

        // 注意：这里不再发送 didUpdateDuration，因为在无缝切歌场景下，
        // didUpdateDuration 会先于 playerDidTransitionToNextTrack 到达主线程，
        // 导致当前歌曲的进度条总时长被下一首的 duration 覆盖。
        // duration 已保存在 streamInfo 中，app 层在切歌完成后可从 streamInfo.duration 获取。

        // 通知 app 层已切换到下一首。
        // 对普通无缝切歌，需等待旧音频尾巴真正播完后再切 UI；
        // 对音质切换（pendingSeekTime != nil），则立即通知。
        let shouldDelayTransition = stateQueue.sync {
            self.pendingSeekTime == nil && !needsRendererRestart
        }
        let transitionDelay: TimeInterval = shouldDelayTransition ? max(0, remainingAudibleTail) : 0
        let notifyWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.stateQueue.sync {
                self.audibleTransitionDeadline = nil
                self.audibleTransitionStartedAt = nil
                self.previousTrackDisplayStartTime = nil
                self.pendingTransitionNotificationWorkItem = nil
            }
            self.delegate?.playerDidTransitionToNextTrack(self)
        }
        stateQueue.sync {
            pendingTransitionNotificationWorkItem?.cancel()
            pendingTransitionNotificationWorkItem = notifyWorkItem
        }
        if transitionDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDelay, execute: notifyWorkItem)
        } else {
            DispatchQueue.main.async(execute: notifyWorkItem)
        }

        return true
    }
    private func releasePacket(_ pkt: UnsafeMutablePointer<AVPacket>) {
            var packet: UnsafeMutablePointer<AVPacket>? = pkt
            av_packet_unref(pkt)
            av_packet_free(&packet)
        }

    private func handleDecodedAudioBuffers(
        _ audioBuffers: [AudioBuffer],
        packetPTS: Int64,
        timeBase: AVRational,
        enqueueToRenderer: Bool
    ) {
            for (index, audioBuffer) in audioBuffers.enumerated() {
            if enqueueToRenderer {
                audioRenderer.enqueue(audioBuffer)
            }

                let pts: TimeInterval
                let nopts = Int64(bitPattern: UInt64(0x8000000000000000)) // AV_NOPTS_VALUE
                if packetPTS != nopts && packetPTS >= 0 && timeBase.den > 0 {
                    let basePTS = Double(packetPTS) * Double(timeBase.num) / Double(timeBase.den)
                let offset = audioBuffers[..<index].reduce(0) { $0 + $1.duration }
                    let rawPTS = basePTS + offset
                    
                    let ptsOffset: TimeInterval = stateQueue.sync {
                        if self.audioPTSOffset == nil {
                            if let target = self.seekTargetTime {
                                self.audioPTSOffset = rawPTS - target
                            } else {
                                self.audioPTSOffset = rawPTS
                            }
                        }
                        return self.audioPTSOffset ?? 0
                    }
                    pts = rawPTS - ptsOffset
                } else {
                    let fallbackTime = stateQueue.sync { self.decodedTime }
                    pts = fallbackTime + audioBuffer.duration
                }

                syncController.updateAudioClock(pts)

                stateQueue.sync {
                    let endPts = pts + audioBuffer.duration
                    
                    if let target = self.seekTargetTime {
                        if pts >= target {
                            self.seekTargetTime = nil
                            self.decodedTime = endPts
                        }
                    } else {
                        self.decodedTime = endPts
                    }
                }

                lyricSyncer.update(time: pts)

                let shouldSeekToA: TimeInterval? = stateQueue.sync {
                    if self.abLoopEnabled,
                       let a = self.loopPointA,
                       let b = self.loopPointB,
                       pts >= b {
                        return a
                    }
                    return nil
                }
                if let a = shouldSeekToA {
                    seekLock.lock()
                    pendingSeekTime = a
                    seekLock.unlock()
            }
        }
    }

    ///
    /// 使用 packet PTS + audioTimeBase 精确计算播放时间，避免 duration 累加漂移。
    /// 可恢复错误（单帧解码失败）会被跳过，不可恢复错误会触发自动停止。
    ///
    /// - Returns: An unrecoverable `FFmpegError` if one occurred, or `nil` on success/skip.
    @discardableResult
    private func processAudioPacket(_ pkt: UnsafeMutablePointer<AVPacket>) -> FFmpegError? {
        // 在 defer 之前读取 PTS，因为 av_packet_unref 会清除它
        let packetPTS = pkt.pointee.pts
        let timeBase = stateQueue.sync { self.audioTimeBase }

        defer { releasePacket(pkt) }

        guard let decoder = audioDecoder else { return nil }

        do {
            let audioBuffers = try decoder.decodeAll(packet: pkt)
            handleDecodedAudioBuffers(
                audioBuffers,
                packetPTS: packetPTS,
                timeBase: timeBase,
                enqueueToRenderer: true
            )
            return nil
        } catch let error as FFmpegError where error.isUnrecoverable {
            return error
        } catch {
            return nil
        }
    }

    /// Processes a single video packet: decode → sync → render.
    ///
    /// Recoverable errors (individual frame decoding failures) are caught and
    /// skipped. Unrecoverable errors (resource allocation failures, etc.) are
    /// propagated to trigger an automatic stop.
    /// Frames that are too far behind audio are dropped per A/V sync logic.
    ///
    /// - Returns: An unrecoverable `FFmpegError` if one occurred, or `nil` on success/skip.
    @discardableResult
    private func processVideoPacket(_ pkt: UnsafeMutablePointer<AVPacket>) -> FFmpegError? {
        defer {
            var packet: UnsafeMutablePointer<AVPacket>? = pkt
            av_packet_unref(pkt)
            av_packet_free(&packet)
        }

        guard let decoder = videoDecoder else { return nil }

        do {
            let frame = try decoder.decode(packet: pkt)

            // Check A/V sync
            let action = syncController.syncAction(for: frame.pts)

            switch action {
            case .display(let delay):
                if delay > 0 {
                    Thread.sleep(forTimeInterval: delay)
                }
                videoRenderer.render(frame)
                syncController.updateVideoClock(frame.pts)

            case .drop:
                // Frame is too far behind audio - skip it
                break

            case .repeatPrevious(let delay):
                // Video is ahead of audio - wait then display
                Thread.sleep(forTimeInterval: delay)
                videoRenderer.render(frame)
                syncController.updateVideoClock(frame.pts)
            }
            return nil
        } catch let error as FFmpegError where error.isUnrecoverable {
            // Unrecoverable error — propagate to trigger auto-stop
            return error
        } catch {
            // Recoverable error (e.g., single frame decode failure) — skip and continue
            return nil
        }
    }

    // MARK: - Helpers

    /// Checks whether the playback loop should continue.
    private func isActive() -> Bool {
        return stateQueue.sync { isPlaybackActive }
    }

    /// Transitions the player state and notifies the delegate.
    private func transitionState(to newState: PlaybackState) {
        stateQueue.sync {
            self.state = newState
        }
    }

    /// Handles an unrecoverable error by stopping playback and notifying the delegate.
    private func handleUnrecoverableError(_ error: Error) {
        let ffError: FFmpegError
        if let fe = error as? FFmpegError {
            ffError = fe
        } else {
            ffError = .connectionFailed(code: -1, message: error.localizedDescription)
        }

        stopInternal()
        transitionState(to: .error(ffError))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.player(self, didEncounterError: ffError)
        }
    }

    // MARK: - Network Reconnection

    /// 在播放循环中无感断点续播：断开旧连接 → 立即重建 pipeline → seek 到断点 → 预填充缓冲。
    /// AudioRenderer 在整个过程中保持运行，利用已有缓冲覆盖重连耗时，实现无缝衔接。
    /// - Returns: true 表示重连成功，播放循环可继续；false 表示放弃。
    private func attemptReconnect() -> Bool {
        networkReconnectAttempts += 1
        guard networkReconnectAttempts <= maxNetworkReconnectAttempts else {
            print("[StreamPlayer] ❌ reconnect attempts exhausted (\(maxNetworkReconnectAttempts))")
            return false
        }

        let url = stateQueue.sync { self.currentURL }
        guard let url, !url.isEmpty else { return false }
        guard isActive() else { return false }

        let resumePosition = stateQueue.sync { self.decodedTime }
        let bufferedSeconds = audioRenderer.queuedDuration

        print(
            "[StreamPlayer] 🔄 network disconnected, seamless reconnect \(networkReconnectAttempts)/\(maxNetworkReconnectAttempts), " +
            "resume=\(String(format: "%.1f", resumePosition))s, buffer=\(String(format: "%.2f", bufferedSeconds))s"
        )

        // 非首次重连才短暂等待，首次立即尝试（缓冲区正在消耗，不能浪费时间）
        if networkReconnectAttempts > 1 {
            let delay: TimeInterval = networkReconnectAttempts == 2 ? 0.3 : 1.0
            Thread.sleep(forTimeInterval: delay)
        }

        guard isActive() else { return false }

        // 断开旧连接（保留 AudioRenderer 继续播放缓冲区中的音频）
        stateQueue.sync {
            self.connectionManager?.disconnect()
            self.connectionManager = nil
            self.audioDecoder = nil
            self.videoDecoder = nil
            self.demuxer = nil
        }

        // 重新连接
        let newManager = ConnectionManager()
        let formatContext: FFmpegFormatContext
        do {
            var connectResult: Result<FFmpegFormatContext, Error>?
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    let ctx = try await newManager.connect(url: url)
                    connectResult = .success(ctx)
                } catch {
                    connectResult = .failure(error)
                }
                semaphore.signal()
            }
            semaphore.wait()

            switch connectResult! {
            case .success(let ctx): formatContext = ctx
            case .failure(let error): throw error
            }
        } catch {
            print("[StreamPlayer] ⚠️ reconnect attempt \(networkReconnectAttempts) connect failed: \(error)")
            newManager.disconnect()
            return attemptReconnect()
        }

        guard isActive() else {
            newManager.disconnect()
            return false
        }

        // 重建 demuxer + decoder
        let newDemuxer = Demuxer(formatContext: formatContext, url: url)
        let info: StreamInfo
        do {
            info = try newDemuxer.findStreams()
        } catch {
            print("[StreamPlayer] ❌ reconnect findStreams failed: \(error)")
            newManager.disconnect()
            return false
        }

        guard info.hasAudio, newDemuxer.currentAudioStreamIndex >= 0 else {
            print("[StreamPlayer] ❌ reconnect: no audio stream")
            newManager.disconnect()
            return false
        }

        let streamIndex = Int(newDemuxer.currentAudioStreamIndex)
        guard let stream = formatContext.stream(at: streamIndex),
              let codecpar = stream.pointee.codecpar else {
            newManager.disconnect()
            return false
        }

        let targetRate = audioRenderer.actualSampleRate > 0 ? audioRenderer.actualSampleRate : nil
        let newDecoder: AudioDecoder
        do {
            newDecoder = try AudioDecoder(
                codecParameters: codecpar,
                codecID: codecpar.pointee.codec_id,
                targetSampleRate: targetRate
            )
        } catch {
            print("[StreamPlayer] ❌ reconnect decoder init failed: \(error)")
            newManager.disconnect()
            return false
        }

        // Seek 到断点位置
        do {
            try newDemuxer.seek(to: resumePosition)
        } catch {
            print("[StreamPlayer] ⚠️ reconnect seek failed: \(error)")
        }

        // 原子替换 pipeline 组件
        let newTimeBase = stream.pointee.time_base
        stateQueue.sync {
            self.connectionManager = newManager
            self.demuxer = newDemuxer
            self.audioDecoder = newDecoder
            self.videoDecoder = nil
            self.streamInfo = info
            self.audioTimeBase = newTimeBase
            self.audioPTSOffset = nil
            self.seekTargetTime = resumePosition
        }

        syncController.reset()
        repairEngine.reset()

        // 预填充缓冲区：在恢复播放循环前先解码一批 packet 喂给 AudioRenderer，
        // 确保重连后缓冲区有充足数据，避免断音。
        let prefilledDuration = prefillAudioBuffer(demuxer: newDemuxer, decoder: newDecoder, timeBase: newTimeBase)

        let postReconnectBuffer = audioRenderer.queuedDuration
        print(
            "[StreamPlayer] ✅ seamless reconnect succeeded, prefilled=\(String(format: "%.2f", prefilledDuration))s, " +
            "total buffer=\(String(format: "%.2f", postReconnectBuffer))s"
        )
        return true
    }

    /// 重连后预填充 AudioRenderer 缓冲区，尽量补满以保证无缝。
    /// - Returns: 预填充的音频时长（秒）
    private func prefillAudioBuffer(demuxer: Demuxer, decoder: AudioDecoder, timeBase: AVRational) -> TimeInterval {
        let targetPrefill: TimeInterval = 1.0
        let maxPackets = 64
        var totalDuration: TimeInterval = 0

        for _ in 0..<maxPackets {
            if totalDuration >= targetPrefill { break }
            guard isActive() else { break }

            let packet: Demuxer.PacketType?
            do {
                packet = try demuxer.readNextPacket()
            } catch {
                break
            }
            guard let packet else { break }

            switch packet {
            case .audio(let pkt):
                let packetPTS = pkt.pointee.pts
                defer { releasePacket(pkt) }
                do {
                    let buffers = try decoder.decodeAll(packet: pkt)
                    let batchDuration = buffers.reduce(0) { $0 + $1.duration }
                    handleDecodedAudioBuffers(
                        buffers,
                        packetPTS: packetPTS,
                        timeBase: timeBase,
                        enqueueToRenderer: true
                    )
                    totalDuration += batchDuration
                } catch {
                    continue
                }
            case .video(let pkt):
                releasePacket(pkt)
            }
        }

        return totalDuration
    }

    /// Handles a network disconnection detected during the demux/decode loop.
    ///
    /// Updates the ConnectionManager state to reflect the disconnection,
    /// stops playback, transitions to the error state, and notifies the
    /// app layer via the StreamPlayerDelegate.
    private func handleNetworkDisconnection() {
        let error = FFmpegError.networkDisconnected

        // Notify the ConnectionManager about the disconnection so its delegate
        // (if any) also receives the state change.
        stateQueue.sync {
            connectionManager?.delegate?.connectionManager(connectionManager!, didFailWith: error)
        }

        stopInternal(rendererStopStrategy: .gracefulNetworkDisconnect)
        transitionState(to: .error(error))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.player(self, didEncounterError: error)
        }
    }

    /// Stops playback and cleans up all resources without changing state.
    private func stopInternal(rendererStopStrategy: RendererStopStrategy = .immediate) {
        networkReconnectAttempts = 0
        stateQueue.sync {
            isPlaybackActive = false
            pendingTransitionNotificationWorkItem?.cancel()
            pendingTransitionNotificationWorkItem = nil
            audibleTransitionDeadline = nil
            audibleTransitionStartedAt = nil
            previousTrackDisplayStartTime = nil
            previousTrackActualDuration = nil
        }
        pauseSemaphore.signal()

        seekLock.lock()
        pendingSeekTime = nil
        seekLock.unlock()
        
        // 清除 seek 目标时间
        stateQueue.sync {
            seekTargetTime = nil
        }

        stopAudioRenderer(using: rendererStopStrategy)
        videoRenderer.clear()

        // Reset sync controller
        syncController.reset()

        // Clean up decoders
        stateQueue.sync {
            audioDecoder = nil
            videoDecoder = nil
            demuxer = nil
            audioTimeBase = AVRational(num: 0, den: 1)
            audioPTSOffset = nil
            decodedTime = 0
        }

        // Disconnect
        stateQueue.sync {
            connectionManager?.disconnect()
            connectionManager = nil
        }
    }

    private enum RendererStopStrategy {
        case immediate
        case gracefulNetworkDisconnect
    }

    private func stopAudioRenderer(using strategy: RendererStopStrategy) {
        switch strategy {
        case .immediate:
            audioRenderer.stop()
        case .gracefulNetworkDisconnect:
            gracefullyStopAudioRendererAfterNetworkDisconnection()
        }
    }

    private func gracefullyStopAudioRendererAfterNetworkDisconnection() {
        let initialQueuedBufferCount = audioRenderer.queuedBufferCount
        let initialQueuedDuration = audioRenderer.queuedDuration
        let drainWindow = min(0.75, max(0.15, initialQueuedDuration + 0.05))

        if initialQueuedBufferCount > 0 {
            print(
                "[StreamPlayer] 🌐 network disconnected, drain queued audio first: " +
                "buffers=\(initialQueuedBufferCount), duration=\(String(format: "%.3f", initialQueuedDuration))s, " +
                "window=\(String(format: "%.3f", drainWindow))s"
            )
            waitForRendererDrain(maxWait: drainWindow, requireActive: false)
        } else {
            print("[StreamPlayer] 🌐 network disconnected with empty renderer queue, fade out tail directly")
        }

        let remainingQueuedBufferCount = audioRenderer.queuedBufferCount
        let remainingQueuedDuration = audioRenderer.queuedDuration
        if remainingQueuedBufferCount > 0 {
            print(
                "[StreamPlayer] 🌐 renderer still has queued audio after short drain, " +
                "forcing graceful fade-out: buffers=\(remainingQueuedBufferCount), " +
                "duration=\(String(format: "%.3f", remainingQueuedDuration))s"
            )
        } else {
            print("[StreamPlayer] 🌐 renderer drained, scheduling graceful stop fade-out")
        }

        audioRenderer.gracefulStop(flushRemainingAudio: true)
    }

    /// Creates an `AudioStreamBasicDescription` for Float32 interleaved PCM.
    private func makeAudioFormat(sampleRate: Int, channelCount: Int) -> AudioStreamBasicDescription {
        return AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(channelCount * MemoryLayout<Float>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(channelCount * MemoryLayout<Float>.size),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32(MemoryLayout<Float>.size * 8),
            mReserved: 0
        )
    }
}
