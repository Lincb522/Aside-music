// PlayerManager.swift
// AsideMusic
//
// 播放器管理器 - 核心属性、枚举定义和初始化
// 功能实现分布在以下扩展文件中：
//   PlayerManager+Setup.swift       - 音频会话、远程控制、代理、定时器
//   PlayerManager+PlaybackAPI.swift  - 核心播放 API（play, playFM, 队列管理）
//   PlayerManager+Controls.swift     - 播放控制（暂停/恢复、上下首、切换音质）
//   PlayerManager+Seek.swift         - 进度控制（seek、快进、快退）
//   PlayerManager+NowPlaying.swift   - 锁屏/控制中心信息更新
//   PlayerManager+Persistence.swift  - 状态持久化、历史记录、听歌打卡
//   PlayerManager+Internal.swift     - 内部逻辑（shuffle、无缝切歌、loadAndPlay）

import Foundation
import AVFoundation
@preconcurrency import Combine
import MediaPlayer
@preconcurrency import FFmpegSwiftSDK

@MainActor
class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    // MARK: - Playback Modes
    enum PlayMode: String, Codable {
        case sequence
        case loopSingle
        case shuffle
        
        var icon: String {
            switch self {
            case .sequence: return "repeat"
            case .loopSingle: return "repeat.1"
            case .shuffle: return "shuffle"
            }
        }
        
        var next: PlayMode {
            switch self {
            case .sequence: return .loopSingle
            case .loopSingle: return .shuffle
            case .shuffle: return .sequence
            }
        }
    }
    
    // MARK: - FFmpeg StreamPlayer
    let streamPlayer = StreamPlayer()
    var timeUpdateTimer: Timer?
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentTime: Double = 0 {
        didSet { PlaybackTimePublisher.shared.currentTime = currentTime }
    }
    @Published var duration: Double = 0 {
        didSet { PlaybackTimePublisher.shared.duration = duration }
    }
    @Published var showFullScreenPlayer = false
    @Published var mode: PlayMode = .sequence
    @Published var isTabBarHidden: Bool = false
    
    // MARK: - 流信息（FFmpeg 提供）
    @Published var streamInfo: StreamInfo?
    
    // MARK: - EQ 均衡器（FFmpeg 提供）
    var equalizer: AudioEqualizer {
        streamPlayer.equalizer
    }
    
    // MARK: - 音频效果（FFmpeg avfilter）
    var audioEffects: AudioEffects {
        streamPlayer.audioEffects
    }
    
    // MARK: - 波形生成器
    var waveformGenerator: WaveformGenerator {
        streamPlayer.waveformGenerator
    }
    
    // MARK: - 频谱分析器
    var spectrumAnalyzer: SpectrumAnalyzer {
        streamPlayer.spectrumAnalyzer
    }
    
    // MARK: - 音频修复引擎
    var audioRepair: AudioRepairEngine {
        streamPlayer.audioRepair
    }
    
    // MARK: - 变调控制
    @Published var pitchSemitones: Float = 0
    
    func setPitch(_ semitones: Float) {
        let clamped = min(max(semitones, -12), 12)
        
        // 避免重复设置相同值导致滤镜图频繁重建（拖动滑块时可显著减少噪声）
        if abs(clamped - pitchSemitones) < 0.001 {
            return
        }
        
        pitchSemitones = clamped
        audioEffects.setPitch(clamped)
        // 持久化
        UserDefaults.standard.set(clamped, forKey: AppConfig.StorageKeys.pitchSemitones)
    }
    
    // MARK: - 播放源类型
    enum PlaySource: Codable, Equatable {
        case normal
        case fm
        case podcast(radioId: Int)
    }
    
    @Published var playSource: PlaySource = .normal
    
    var isPlayingFM: Bool {
        get { playSource == .fm }
        set { playSource = newValue ? .fm : .normal }
    }
    
    var isPlayingPodcast: Bool {
        if case .podcast = playSource { return true }
        return false
    }
    
    var currentRadioId: Int? {
        if case .podcast(let radioId) = playSource { return radioId }
        return nil
    }
    
    // MARK: - Settings
    @Published var soundQuality: SoundQuality = {
        if let rawValue = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.soundQuality),
           let quality = SoundQuality(rawValue: rawValue) {
            return quality
        }
        let defaultRaw = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.defaultPlaybackQuality) ?? "standard"
        return SoundQuality(rawValue: defaultRaw) ?? .standard
    }() {
        didSet {
            UserDefaults.standard.set(soundQuality.rawValue, forKey: AppConfig.StorageKeys.soundQuality)
        }
    }
    
    /// 酷狗音质（解灰歌曲独立体系）
    @Published var kugouQuality: KugouQuality = {
        if let rawValue = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.kugouQuality),
           let quality = KugouQuality(rawValue: rawValue) {
            return quality
        }
        return .high
    }() {
        didSet {
            UserDefaults.standard.set(kugouQuality.rawValue, forKey: AppConfig.StorageKeys.kugouQuality)
        }
    }
    
    /// QQ 音乐音质（QQ 音乐独立体系）
    @Published var qqMusicQuality: QQMusicQuality = {
        if let rawValue = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.qqMusicQuality),
           let quality = QQMusicQuality(rawValue: rawValue) {
            return quality
        }
        return .mp3_320
    }() {
        didSet {
            UserDefaults.standard.set(qqMusicQuality.rawValue, forKey: AppConfig.StorageKeys.qqMusicQuality)
        }
    }
    
    /// 当前播放的歌是否来自解灰源
    @Published var isCurrentSongUnblocked: Bool = false
    
    // MARK: - Queue System
    @Published var context: [Song] = []
    @Published var contextIndex: Int = 0
    @Published var shuffledContext: [Song] = []
    @Published var userQueue: [Song] = []
    @Published var history: [Song] = []
    /// 运行时回退栈：驱动 previous() 的“真实上一首”行为
    @Published var playbackBackStack: [Song] = []
    
    // MARK: - Internal Properties (供扩展文件访问)
    var cancellables = Set<AnyCancellable>()
    /// 当前播放 URL 获取的订阅（切歌时自动取消上一次）
    var playbackURLCancellable: AnyCancellable?
    /// 音质切换 URL 获取的订阅
    var qualitySwitchCancellable: AnyCancellable?
    /// 下一首预加载的订阅
    var nextTrackCancellable: AnyCancellable?
    /// 音质切换轮询任务（可取消）
    var qualitySwitchPollWorkItem: DispatchWorkItem?
    var saveStateWorkItem: DispatchWorkItem?
    let saveStateDebounceInterval: TimeInterval = AppConfig.Player.saveStateDebounceInterval
    /// 标记是否为用户主动停止（区分 EOF 自然结束 vs 手动 stop）
    var isUserStopping: Bool = false
    /// 播放会话 ID，每次 loadAndPlay 递增，用于忽略旧会话的 .stopped 回调
    var playbackSessionId: Int = 0
    
    /// 当前播放的音频 URL（用于音频分析等功能）
    @Published var currentPlayingURL: String?
    
    /// 当前歌曲副歌时间段
    @Published var chorusStartTime: TimeInterval?
    @Published var chorusEndTime: TimeInterval?
    
    /// 当前歌曲动态封面 URL
    @Published var dynamicCoverUrl: String?
    var consecutiveFailures: Int = 0
    let maxConsecutiveFailures: Int = AppConfig.Player.maxConsecutiveFailures
    var retryDelay: TimeInterval = AppConfig.Player.initialRetryDelay
    let maxRetryDelay: TimeInterval = AppConfig.Player.maxRetryDelay
    
    /// 预加载的下一首歌曲信息（等待当前歌曲真正结束后再更新 UI）
    var pendingNextSong: Song? = nil
    /// 标记 SDK 已切换到下一首的 pipeline（但 UI 还没更新）
    var hasPendingTrackTransition: Bool = false
    
    /// 异常停止重试计数器（防止损坏音源无限重试）
    var abnormalStopRetryCount: Int = 0
    let maxAbnormalStopRetries: Int = 3
    
    /// 音频中断前是否正在播放（用于中断恢复）
    var wasPlayingBeforeInterruption: Bool = false
    
    // MARK: - Remote Command Center
    let commandCenter = MPRemoteCommandCenter.shared()
    
    // MARK: - Seek State
    var seekDebounceWorkItem: DispatchWorkItem?
    /// seek 期间为 true，阻止定时器用旧的 streamPlayer.currentTime 覆盖进度条
    var isSeeking: Bool = false
    /// seek 目标时间，用于定时器判断 streamPlayer 是否已到达目标
    var seekTargetTime: Double? = nil
    /// isSeeking 开始的时间戳，用于超时保护
    var seekStartedAt: Date?
    /// hasPendingTrackTransition 开始的时间戳
    var pendingTransitionStartedAt: Date?
    
    /// 音质切换时的 seek 位置，nil 表示不是音质切换
    var pendingQualitySwitchSeek: Double? = nil
    
    /// 保持 delegate adapter 的强引用
    var delegateAdapter: StreamPlayerDelegateAdapter?
    
    /// 持久化时的最大 context 大小（防止序列化过大）
    let maxPersistContextSize = 200
    /// 回退栈最大长度（防止无限增长）
    let maxBackStackSize = 200
    /// 正在执行“上一首回退”，用于避免 loadAndPlay 再次把当前歌压入回退栈
    var isApplyingBackNavigation: Bool = false
    
    var isAppLoggedIn: Bool {
        UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
    }
    
    // MARK: - Computed Properties
    var currentContextList: [Song] {
        return mode == .shuffle ? shuffledContext : context
    }
    
    var currentIndexInContext: Int {
        return contextIndex
    }
    
    var upcomingSongs: [Song] {
        return Array(currentContextList.dropFirst(contextIndex + 1))
    }
    
    /// 播放上下文中剩余的歌曲
    var contextRemainingSongs: [Song] {
        return Array(currentContextList.dropFirst(contextIndex + 1))
    }
    
    /// 当前音质按钮显示文字（根据歌曲来源区分）
    var qualityButtonText: String {
        if currentSong?.isQQMusic == true {
            return qqMusicQuality.badgeText ?? "标准"
        }
        if isCurrentSongUnblocked {
            return kugouQuality.badgeText ?? "标准"
        }
        return soundQuality.buttonText
    }
    
    // MARK: - Init
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupStreamPlayerDelegate()
        startTimeUpdateTimer()
        restoreState()
        fetchHistory()
        // 恢复变调设置
        let savedPitch = UserDefaults.standard.float(forKey: "aside_pitch_semitones")
        if savedPitch != 0 {
            pitchSemitones = savedPitch
            audioEffects.setPitch(savedPitch)
        }
    }
    
    deinit {
        // Swift 6: deinit 是 nonisolated 的，不能直接访问非 Sendable 属性
        // 使用 MainActor.assumeIsolated 因为 @MainActor 类的 deinit 实际上在主线程执行
        MainActor.assumeIsolated {
            timeUpdateTimer?.invalidate()
            cancellables.removeAll()
            playbackURLCancellable?.cancel()
            qualitySwitchCancellable?.cancel()
            nextTrackCancellable?.cancel()
            qualitySwitchPollWorkItem?.cancel()
            saveStateWorkItem?.cancel()
        }
    }
}


// MARK: - StreamPlayer Delegate 适配器

/// 桥接 StreamPlayerDelegate 回调到 @MainActor PlayerManager
/// StreamPlayer 的回调可能在后台线程，需要 dispatch 到主线程
class StreamPlayerDelegateAdapter: StreamPlayerDelegate, @unchecked Sendable {
    nonisolated(unsafe) private weak var playerManager: PlayerManager?
    
    init(playerManager: PlayerManager) {
        self.playerManager = playerManager
    }
    
    func player(_ player: StreamPlayer, didChangeState state: PlaybackState) {
        // 在进入 @MainActor Task 前提取需要的值，避免非 Sendable 类型跨隔离域
        let streamInfo = player.streamInfo
        let errorDesc: String? = {
            if case .error(let e) = state { return e.description }
            return nil
        }()
        // 将 PlaybackState 转为 Sendable 的简单值
        enum StateKind: Sendable { case idle, connecting, playing, paused, stopped, error }
        let kind: StateKind = {
            switch state {
            case .idle: return .idle
            case .connecting: return .connecting
            case .playing: return .playing
            case .paused: return .paused
            case .stopped: return .stopped
            case .error: return .error
            }
        }()
        
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            let sessionAtCallback = pm.playbackSessionId
            switch kind {
            case .idle:
                pm.isPlaying = false
                pm.isLoading = false
            case .connecting:
                pm.isLoading = true
                pm.isPlaying = false
            case .playing:
                pm.isPlaying = true
                pm.isLoading = false
                if let info = streamInfo {
                    pm.streamInfo = info
                }
                if pm.pitchSemitones != 0 {
                    pm.audioEffects.setPitch(pm.pitchSemitones)
                    AppLogger.info("播放状态变为 playing，重新应用变调: \(pm.pitchSemitones) 半音")
                }
            case .paused:
                pm.isPlaying = false
                pm.isLoading = false
            case .stopped:
                pm.isPlaying = false
                pm.isLoading = false
                guard sessionAtCallback == pm.playbackSessionId else { return }
                if pm.hasPendingTrackTransition { return }
                if !pm.isUserStopping && pm.currentSong != nil {
                    // 实际音频数据可能比元数据 duration 短，修正以避免进度条看起来没播完
                    if pm.currentTime > 0 && pm.duration > 0 && pm.currentTime / pm.duration > 0.8 {
                        pm.duration = pm.currentTime
                    }
                    let playedRatio = pm.duration > 0 ? pm.currentTime / pm.duration : 0
                    if pm.duration > 0 && playedRatio < 0.5 && pm.currentTime < 30 {
                        pm.abnormalStopRetryCount += 1
                        if pm.abnormalStopRetryCount >= pm.maxAbnormalStopRetries {
                            AppLogger.warning("异常结束重试已达上限(\(pm.maxAbnormalStopRetries)次)，跳到下一首")
                            pm.abnormalStopRetryCount = 0
                            pm.autoNext()
                        } else {
                            AppLogger.warning("异常结束: 只播放了 \(String(format: "%.1f", pm.currentTime))s / \(String(format: "%.1f", pm.duration))s，重试第\(pm.abnormalStopRetryCount)次")
                            if let song = pm.currentSong {
                                pm.loadAndPlay(song: song)
                            }
                        }
                    } else {
                        pm.abnormalStopRetryCount = 0
                        AppLogger.info("播放结束 (EOF)，自动下一首")
                        pm.playerDidFinishPlaying()
                    }
                }
            case .error:
                pm.isPlaying = false
                pm.isLoading = false
                AppLogger.error("FFmpeg 播放错误: \(errorDesc ?? "unknown")")
                if pm.currentSong != nil {
                    pm.consecutiveFailures += 1
                    if pm.consecutiveFailures >= pm.maxConsecutiveFailures {
                        pm.consecutiveFailures = 0
                        pm.retryDelay = 1.0
                    } else {
                        let delay = pm.retryDelay
                        pm.retryDelay = min(pm.retryDelay * 2, pm.maxRetryDelay)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak pm] in
                            pm?.next()
                        }
                    }
                }
            }
        }
    }
    
    func player(_ player: StreamPlayer, didEncounterError error: FFmpegError) {
        let desc = error.description
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            AppLogger.error("FFmpeg 错误: \(desc)")
            pm.isPlaying = false
            pm.isLoading = false
        }
    }
    
    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval) {
        let dur = duration
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            if pm.hasPendingTrackTransition { return }
            if dur.isFinite && !dur.isNaN && dur > 0 {
                pm.duration = dur
            }
        }
    }
    
    func playerDidTransitionToNextTrack(_ player: StreamPlayer) {
        let streamInfo = player.streamInfo
        let actualDuration = player.previousTrackActualDuration
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            
            if let info = streamInfo {
                pm.streamInfo = info
            }
            
            if let seekTime = pm.pendingQualitySwitchSeek {
                AppLogger.info("无缝音质切换完成")
                pm.pendingQualitySwitchSeek = nil
                pm.currentTime = seekTime
                pm.isSeeking = false
            } else {
                // 用上一首的实际解码时长修正 duration，避免进度条看起来没播完
                if let actualDur = actualDuration, actualDur > 0, actualDur < pm.duration {
                    AppLogger.info("无缝切歌：修正 duration \(String(format: "%.1f", pm.duration)) → \(String(format: "%.1f", actualDur))")
                    pm.duration = actualDur
                }
                
                AppLogger.info("无缝切歌：SDK 已准备好下一首，等待当前歌曲结束")
                pm.preparePendingNextTrack()
                
                if pm.pendingNextSong != nil {
                    pm.hasPendingTrackTransition = true
                    pm.pendingTransitionStartedAt = Date()
                } else {
                    AppLogger.info("无缝切歌：无待切换歌曲（单曲循环或列表为空），走 finish 逻辑")
                    pm.playerDidFinishPlaying()
                }
            }
        }
    }
}
