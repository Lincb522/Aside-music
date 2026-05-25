// PlayerManager.swift
// Monologue
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

        var displayName: String {
            switch self {
            case .sequence:
                return NSLocalizedString("mode_sequence", comment: "")
            case .loopSingle:
                return NSLocalizedString("mode_loop_one", comment: "")
            case .shuffle:
                return NSLocalizedString("mode_shuffle", comment: "")
            }
        }
        
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

    enum QueueExhaustionBehavior: String, Codable {
        case loop
        case stopAtEnd
    }
    
    // MARK: - FFmpeg StreamPlayer
    let streamPlayer = StreamPlayer()
    var timeUpdateTimer: Timer?
    var nowPlayingUpdateCounter: Int = 0
    var lastWidgetSongName: String = ""
    var lastWidgetPlaybackState: PlaybackSurfaceState = .idle
    var lastWidgetMetadataSignature: String = ""
    var lastWidgetLyricText: String = ""
    var lastWidgetProgressAnchorTime: TimeInterval = 0
    var lastWidgetProgressAnchorDate: Date?
    var lastWidgetProgressDuration: TimeInterval = 0
    var lastWidgetTempoSongID: Int?
    var widgetTempoSyncTask: Task<Void, Never>?
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    var currentTime: Double = 0 {
        didSet {
            if abs(currentTime - oldValue) > 0.01 {
                PlaybackTimePublisher.shared.currentTime = currentTime
            }
        }
    }
    var duration: Double = 0 {
        didSet {
            if abs(duration - oldValue) > 0.1 {
                PlaybackTimePublisher.shared.duration = duration
            }
        }
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
    
    // MARK: - 播客倍速控制
    @Published var playbackSpeed: Float = 1.0

    func setPlaybackSpeed(_ speed: Float) {
        let clamped = min(max(speed, 0.5), 3.0)
        playbackSpeed = clamped
        audioEffects.setTempo(clamped)
    }

    // MARK: - 定时关闭
    @Published var sleepTimerRemaining: TimeInterval? = nil
    @Published var sleepTimerConfiguredMinutes: Int? = nil
    @Published var sleepTimerStopAfterCurrentTrack = false
    @Published var pendingSleepStopAfterCurrentTrack = false
    private var sleepTimerDeadline: Date?
    private var lastSleepUpdate: TimeInterval = 0

    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        let total = TimeInterval(minutes * 60)
        sleepTimerDeadline = Date().addingTimeInterval(total)
        sleepTimerRemaining = total
        sleepTimerConfiguredMinutes = minutes
    }

    func cancelSleepTimer() {
        sleepTimerDeadline = nil
        sleepTimerRemaining = nil
        sleepTimerConfiguredMinutes = nil
        pendingSleepStopAfterCurrentTrack = false
        lastSleepUpdate = 0
    }

    func activateSleepStopAfterCurrentTrack() {
        sleepTimerDeadline = nil
        sleepTimerRemaining = nil
        sleepTimerConfiguredMinutes = nil
        lastSleepUpdate = 0
        pendingSleepStopAfterCurrentTrack = true
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        nextTrackCancellable?.cancel()
        streamPlayer.cancelNextPreparation()
        saveState()
    }

    /// 由 timeUpdateTimer 每 0.25s 调用
    func tickSleepTimer() {
        guard let deadline = sleepTimerDeadline else { return }
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            if sleepTimerStopAfterCurrentTrack,
               currentSong != nil,
               isPlaying {
                activateSleepStopAfterCurrentTrack()
            } else {
                cancelSleepTimer()
                streamPlayer.pause()
                isPlaying = false
                refreshPlaybackSurfaceState()
                saveState()
            }
        } else {
            let rounded = remaining.rounded()
            if rounded != lastSleepUpdate {
                lastSleepUpdate = rounded
                sleepTimerRemaining = remaining
            }
        }
    }

    // MARK: - 播放源类型
    enum PlaySource: Codable, Equatable {
        case normal
        case fm
        case podcast(radioId: Int)

        var isPodcast: Bool {
            if case .podcast = self { return true }
            return false
        }
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

    var playbackSurfaceState: PlaybackSurfaceState {
        guard currentSong != nil else { return .idle }
        if isLoading { return .loading }
        if isPlaying { return .playing }
        return .paused
    }
    
    // MARK: - 播放来源上下文
    struct PlayContext: Codable, Equatable {
        enum ContextType: String, Codable {
            case playlist, album, artist, dailyRecommend, rank
            case search, recentPlay, newSong, cloud, download, unknown
        }
        let type: ContextType
        let id: Int?
        let name: String
    }
    
    @Published var playContext: PlayContext?
    
    // MARK: - Settings
    @Published var soundQuality: SoundQuality = {
        PlayerManager.initialNeteasePlaybackQuality()
    }()
    
    /// qcm音质（qcm歌曲及解灰歌曲共用）
    @Published var qqMusicQuality: QQMusicQuality = {
        PlayerManager.initialQQPlaybackQuality()
    }()
    
    /// 当前播放的歌是否来自解灰源
    @Published var isCurrentSongUnblocked: Bool = false
    
    /// 汽水音乐当前选择的音质（如 "highest", "lossless" 等）
    var qishuiSelectedQuality: String = SettingsManager.shared.defaultQishuiPlaybackQuality

    static func defaultNeteasePlaybackQuality() -> SoundQuality {
        let defaultRaw = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.defaultPlaybackQuality)
            ?? SoundQuality.standard.rawValue
        return SoundQuality(rawValue: defaultRaw) ?? .standard
    }
    
    static func defaultQQPlaybackQuality() -> QQMusicQuality {
        let defaultRaw = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.qqMusicQuality)
            ?? QQMusicQuality.mp3_320.rawValue
        return QQMusicQuality(rawValue: defaultRaw) ?? .mp3_320
    }
    
    static func prefersHighestPlaybackQuality() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppConfig.StorageKeys.preferHighestPlaybackQuality) != nil else {
            return true
        }
        return defaults.bool(forKey: AppConfig.StorageKeys.preferHighestPlaybackQuality)
    }

    static func gaplessPlaybackEnabled() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppConfig.StorageKeys.gaplessPlaybackEnabled) != nil else {
            return false
        }
        return defaults.bool(forKey: AppConfig.StorageKeys.gaplessPlaybackEnabled)
    }
    
    static func initialNeteasePlaybackQuality() -> SoundQuality {
        prefersHighestPlaybackQuality() ? .jymaster : defaultNeteasePlaybackQuality()
    }
    
    static func initialQQPlaybackQuality() -> QQMusicQuality {
        prefersHighestPlaybackQuality() ? .master : defaultQQPlaybackQuality()
    }
    
    // MARK: - Queue System
    @Published var context: [Song] = []
    @Published var contextIndex: Int = 0
    @Published var shuffledContext: [Song] = []
    @Published var userQueue: [Song] = []
    @Published var history: [Song] = []
    @Published var podcastHistory: [Song] = []
    var queueExhaustionBehavior: QueueExhaustionBehavior = .loop
    /// 运行时回退栈：驱动 previous() 的“真实上一首”行为
    @Published var playbackBackStack: [Song] = []
    /// 运行时前进栈：在 previous() 后支持回到原先的“下一首”
    @Published var playbackForwardStack: [Song] = []
    
    // MARK: - 播客/音乐上下文隔离
    /// 切换到播客时保存的音乐上下文，以便切回时恢复
    var savedMusicContext: [Song] = []
    var savedMusicContextIndex: Int = 0
    var savedMusicShuffledContext: [Song] = []
    var savedMusicMode: PlayMode = .sequence
    var savedMusicSong: Song? = nil
    var savedMusicCurrentTime: Double = 0
    var savedMusicDuration: Double = 0
    /// 切换到音乐时保存的播客上下文
    var savedPodcastContext: [Song] = []
    var savedPodcastContextIndex: Int = 0
    var savedPodcastRadioId: Int? = nil
    var savedPodcastSong: Song? = nil
    var savedPodcastCurrentTime: Double = 0
    var savedPodcastDuration: Double = 0
    
    // MARK: - Internal Properties (供扩展文件访问)
    var cancellables = Set<AnyCancellable>()
    /// 当前播放 URL 获取的订阅（切歌时自动取消上一次）
    var playbackURLCancellable: AnyCancellable?
    /// 音质切换 URL 获取的订阅
    var qualitySwitchCancellable: AnyCancellable?
    /// 下一首预加载的订阅
    var nextTrackCancellable: AnyCancellable?
    /// QMC 预缓存任务（后台下载+解密下一首加密歌曲）
    var qmcPrefetchTask: Task<Void, Never>?
    /// 下一首音质预查询任务
    var nextQualityPrefetchTask: Task<Void, Never>?
    /// 预查询的音质缓存：songId/mid -> 最佳音质（QQ: QQMusicQuality.rawValue, ncm: SoundQuality.rawValue）
    var prefetchedQualityCache: [String: String] = [:]
    /// 当前会话是否已安排过一次下一首预加载，避免刚启动时重复 prepareNext
    var scheduledGaplessPreparationSessionId: Int?
    /// 音质切换轮询任务（可取消）
    var qualitySwitchPollWorkItem: DispatchWorkItem?
    /// 延后执行的下一首预加载任务
    var gaplessPreparationWorkItem: DispatchWorkItem?
    /// 音质切换弱网兜底任务
    var qualitySwitchTimeoutTask: Task<Void, Never>?
    var saveStateWorkItem: DispatchWorkItem?
    let saveStateDebounceInterval: TimeInterval = AppConfig.Player.saveStateDebounceInterval
    let playbackProgressPersistenceInterval: TimeInterval = AppConfig.Player.playbackProgressPersistenceInterval
    var lastPersistedProgressSongID: Int?
    var lastPersistedProgressTime: Double = 0
    /// 标记是否为用户主动停止（区分 EOF 自然结束 vs 手动 stop）
    var isUserStopping: Bool = false
    /// 播放会话 ID，每次 loadAndPlay 递增，用于忽略旧会话的 .stopped 回调
    var playbackSessionId: Int = 0
    
    /// 当前播放的音频 URL（用于音频分析等功能）
    @Published var currentPlayingURL: String?
    @Published var isCurrentPlaybackUsingLocalFile = false
    
    /// 当前歌曲动态封面 URL
    @Published var dynamicCoverUrl: String?
    
    /// 上次写入 NowPlaying 的歌词行索引，避免重复写入
    var lastNowPlayingLyricIndex: Int = -1
    /// 预加载的下一首歌曲信息（等待当前歌曲真正结束后再更新 UI）
    var pendingNextSong: Song? = nil
    /// 标记 SDK 已切换到下一首的 pipeline（但 UI 还没更新）
    var hasPendingTrackTransition: Bool = false
    
    /// 异常停止重试计数器（防止损坏音源无限重试）
    var abnormalStopRetryCount: Int = 0
    let maxAbnormalStopRetries: Int = 3

    /// 网络断流 URL 刷新重试计数（StreamPlayer 层重连失败后，应用层重新获取 URL 续播）
    var networkDisconnectRetryCount: Int = 0
    let maxNetworkDisconnectRetries: Int = 2
    
    /// 音频中断进行中（如微信录音），屏蔽路由变化触发的自动恢复
    var isUnderInterruption: Bool = false
    
    /// 音频中断前是否正在播放（用于中断恢复）
    var wasPlayingBeforeInterruption: Bool = false
    
    /// 开始播放的时间戳，用于定时器中判断初始缓冲保护窗口
    var playbackStartedAt: Date?
    
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
    /// 无缝切歌发起时的 session ID，用于检测用户是否手动切歌
    var pendingTransitionSessionId: Int = 0
    
    /// 音质切换时的 seek 位置，nil 表示不是音质切换
    var pendingQualitySwitchSeek: Double? = nil
    /// 当前歌曲的ncm音质是否由用户手动改过
    var hasManualNeteaseQualityOverride = false
    /// 当前歌曲的 QQ 音质是否由用户手动改过
    var hasManualQQQualityOverride = false
    /// 音质切换恢复次数，防止弱网下无限重试
    var qualitySwitchRecoveryAttempts = 0
    let maxQualitySwitchRecoveryAttempts = 2
    /// 重置播放内核时，短时间忽略 stop 回调，避免误判为 EOF/异常结束
    var suppressStopHandlingUntil: Date?
    
    /// 保持 delegate adapter 的强引用
    var delegateAdapter: StreamPlayerDelegateAdapter?
    
    /// NotificationCenter observer tokens
    var interruptionObserver: Any?
    var mediaResetObserver: Any?
    /// 次要音频降音提示（其他主媒体 App 开始/停止播放时系统发出的提示）
    var silenceHintObserver: Any?
    var foregroundObserver: Any?
    /// 音频路由变化（其他 App 释放会话等）时用于延迟尝试恢复播放
    var routeChangeObserver: Any?
    var routeChangeResumeWorkItem: DispatchWorkItem?
    /// 最近一次实际应用到 AVAudioSession 的 options，避免重复 setActive
    var lastAppliedAudioSessionOptions: AVAudioSession.CategoryOptions?

    // MARK: - 中断恢复（统一管理）
    /// 中断/路由恢复阶梯重试任务（0.4s → 1s → 2.5s → 5s）。
    /// 由 `scheduleInterruptionResumeRetry` 创建，失败时自动按下一档重试。
    var interruptionResumeTask: Task<Void, Never>?
    /// 中断超时看门狗。微信、抖音等部分 App 中断结束时不发 `.ended` 通知，
    /// 这里给 `isUnderInterruption` 加 60s 兜底，超时后强制清除并尝试恢复。
    var interruptionWatchdogTask: Task<Void, Never>?
    /// 中断开始时间戳，仅用于日志
    var interruptionStartedAt: Date?
    
    /// 持久化时的最大 context 大小（防止序列化过大）
    let maxPersistContextSize = 200
    /// 回退栈最大长度（防止无限增长）
    let maxBackStackSize = 200
    /// 正在执行“上一首回退”，用于避免 loadAndPlay 再次把当前歌压入回退栈
    var isApplyingBackNavigation: Bool = false
    /// 正在执行“下一首前进”，用于保留 previous() 产生的前进栈
    var isApplyingForwardNavigation: Bool = false
    /// 防止 playerDidFinishPlaying 被 .stopped 和 playerDidTransitionToNextTrack 双重触发
    var isHandlingPlaybackFinish: Bool = false
    
    /// 冷启动后待恢复的播放位置
    var pendingRestoreTime: Double?
    /// 冷启动后是否需要重新建立播放会话
    var needsPlaybackRestoration: Bool = false
    /// 冷启动恢复时是否应自动续播
    var shouldAutoResumeAfterRestore: Bool = false
    
    var isAppLoggedIn: Bool {
        UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
    }
    
    // MARK: - Computed Properties
    var currentContextList: [Song] {
        return mode == .shuffle ? shuffledContext : context
    }
    
    var playedContextSongs: [Song] {
        let list = currentContextList
        let safeIndex = max(0, min(contextIndex, list.count))
        return Array(list.prefix(safeIndex))
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
        if !isCurrentPlaybackQualitySelectable {
            return localPlaybackQualityButtonText
        }
        if currentSong?.isQishui == true {
            return QishuiQualityPickerSheet.displayName(for: qishuiSelectedQuality)
        }
        if isCurrentSongQQBacked {
            return qqMusicQuality.badgeText ?? String(localized: "标准")
        }
        return soundQuality.buttonText
    }

    private var localPlaybackQualityButtonText: String {
        currentSong?.localFileURL == nil ? "DOWNLOAD" : "LOCAL"
    }

    var streamInfoDisplayText: String? {
        guard let streamInfo else { return nil }
        let text = compactStreamInfoText(streamInfo)
        return text.isEmpty ? nil : text
    }

    var qualityInfoText: String? {
        guard currentSong != nil else { return nil }
        guard let streamInfoDisplayText else { return compactQualityInfoText }
        return "\(compactQualityInfoText) · \(streamInfoDisplayText)"
    }

    private var compactQualityInfoText: String {
        if !isCurrentPlaybackQualitySelectable, currentSong?.localFileURL == nil {
            return "DL"
        }
        if currentSong?.isQishui == true {
            return compactQishuiQualityText(for: qishuiSelectedQuality)
        }
        if isCurrentSongQQBacked {
            return qqMusicQuality.badgeText ?? String(localized: "标准")
        }
        return soundQuality.buttonText
    }

    private func compactQishuiQualityText(for quality: String) -> String {
        switch quality {
        case "lossless":
            return SoundQuality.lossless.buttonText
        case "spatial":
            return SoundQuality.sky.buttonText
        case "hi_res":
            return SoundQuality.hires.buttonText
        case "highest":
            return SoundQuality.exhigh.buttonText
        case "higher":
            return SoundQuality.higher.buttonText
        case "medium":
            return SoundQuality.standard.buttonText
        default:
            break
        }
        return qualityButtonText
    }

    private func compactStreamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec, !codec.isEmpty {
            parts.append(compactCodecText(codec))
        }
        if let sampleRate = info.sampleRate {
            var sampleRateText = compactSampleRateText(sampleRate)
            if let bitDepth = info.bitDepth, bitDepth > 0 {
                sampleRateText += "/\(bitDepth)bit"
            }
            parts.append(sampleRateText)
        } else if let bitDepth = info.bitDepth, bitDepth > 0 {
            parts.append("\(bitDepth)bit")
        }
        if let channelCount = info.channelCount, channelCount > 2 {
            parts.append("\(channelCount)ch")
        }
        return parts.joined(separator: " ")
    }

    private func compactCodecText(_ codec: String) -> String {
        let value = codec.lowercased()
        if value.contains("flac") { return "FLAC" }
        if value.contains("alac") { return "ALAC" }
        if value.contains("ape") { return "APE" }
        if value.contains("mp3") { return "MP3" }
        if value.contains("aac") { return "AAC" }
        if value.contains("opus") { return "OPUS" }
        if value.contains("ogg") || value.contains("vorbis") { return "OGG" }
        if value.contains("wav") || value.contains("pcm") { return "WAV" }
        return codec.uppercased()
    }

    private func compactSampleRateText(_ sampleRate: Int) -> String {
        if sampleRate >= 1000 {
            let kilohertz = Double(sampleRate) / 1000.0
            return kilohertz == kilohertz.rounded() ? "\(Int(kilohertz))kHz" : String(format: "%.1fkHz", kilohertz)
        }
        return "\(sampleRate)Hz"
    }

    var isCurrentPlaybackQualitySelectable: Bool {
        !isCurrentPlaybackUsingLocalFile
    }
    
    var isCurrentSongQQBacked: Bool {
        currentSong?.isQQMusic == true || isCurrentSongUnblocked
    }
    
    // MARK: - Init
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupStreamPlayerDelegate()
        startTimeUpdateTimer()
        restoreState()
        // 延后一拍同步小组件，避免冷启动时因节奏缓存查询触发 AudioLabManager，
        // 又在其初始化里反向访问 PlayerManager.shared，造成单例循环初始化。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncWidgetState()
            if self.currentSong != nil {
                self.updateNowPlayingArtwork(for: self.currentSong)
            }
        }
        fetchHistory()
        #if canImport(ActivityKit) && os(iOS)
        LyricsLiveActivityManager.shared.bootstrap(with: self)
        #endif
        // 恢复变调设置
        let savedPitch = UserDefaults.standard.float(forKey: "monologue_pitch_semitones")
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
            qualitySwitchTimeoutTask?.cancel()
            widgetTempoSyncTask?.cancel()
            saveStateWorkItem?.cancel()
        }
    }
}


// MARK: - StreamPlayer Delegate 适配器

/// 桥接 StreamPlayerDelegate 回调到 @MainActor PlayerManager
/// StreamPlayer 的回调可能在后台线程，需要 dispatch 到主线程
class StreamPlayerDelegateAdapter: StreamPlayerDelegate, @unchecked Sendable {
    nonisolated(unsafe) private weak var playerManager: PlayerManager?
    nonisolated(unsafe) var currentSessionId: Int = 0
    
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
        let isNetworkDisconnected: Bool = {
            if case .error(let e) = state { return e == .networkDisconnected }
            return false
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
        
        let sessionAtCallback = self.currentSessionId
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            switch kind {
            case .idle:
                pm.isPlaying = false
                pm.isLoading = false
                pm.refreshPlaybackSurfaceState()
            case .connecting:
                pm.isLoading = true
                pm.isPlaying = false
                pm.refreshPlaybackSurfaceState()
            case .playing:
                pm.isPlaying = true
                pm.isLoading = false
                pm.qualitySwitchTimeoutTask?.cancel()
                pm.qualitySwitchTimeoutTask = nil
                pm.qualitySwitchRecoveryAttempts = 0
                pm.networkDisconnectRetryCount = 0
                if let info = streamInfo {
                    pm.streamInfo = info
                }
                if pm.pitchSemitones != 0 {
                    pm.audioEffects.setPitch(pm.pitchSemitones)
                    AppLogger.info("播放状态变为 playing，重新应用变调: \(pm.pitchSemitones) 半音")
                }
                if !pm.isSeeking {
                    let t = pm.streamPlayer.currentTime
                    if t.isFinite && !t.isNaN && t > 0 {
                        pm.currentTime = t
                    }
                }
                LyricViewModel.shared.updateCurrentTime(pm.currentTime)
                pm.refreshPlaybackSurfaceState()
                pm.scheduleGaplessPreparationAfterPlaybackStartedIfNeeded()
            case .paused:
                pm.isPlaying = false
                pm.isLoading = false
                pm.refreshPlaybackSurfaceState()
            case .stopped:
                pm.isPlaying = false
                pm.isLoading = false
                pm.refreshPlaybackSurfaceState()
                if let deadline = pm.suppressStopHandlingUntil,
                   deadline > Date() {
                    pm.suppressStopHandlingUntil = nil
                    AppLogger.debug("忽略一次播放内核 stop 回调")
                    return
                }
                pm.suppressStopHandlingUntil = nil
                guard sessionAtCallback == pm.playbackSessionId else { return }
                if !pm.isUserStopping && pm.currentSong != nil {
                    // 以 API 元数据 dt 为基准判断预期时长，FFmpeg duration 作为备选
                    let expectedDuration: Double = {
                        if let metaMs = pm.currentSong?.dt, metaMs > 0 {
                            return Double(metaMs) / 1000.0
                        }
                        return pm.duration
                    }()
                    let remainingTime = expectedDuration - pm.currentTime

                    // 歌曲正常播完：将 currentTime 拉满到 duration，让进度条显示 100%
                    if pm.currentTime > 0 && pm.duration > 0 && pm.currentTime / pm.duration > 0.8 && remainingTime <= 15 {
                        pm.currentTime = pm.duration
                    }
                    
                    let isAbnormal: Bool
                    if expectedDuration <= 0 {
                        isAbnormal = pm.currentTime < 30
                    } else {
                        let playedRatio = pm.currentTime / expectedDuration
                        // 异常条件（满足其一即重试）：
                        // 1. 播放不到一半且不到 30 秒（原有：URL 失效、解码失败等）
                        // 2. 距离预期结束还有超过 15 秒（CDN 截断 / 文件不完整）
                        isAbnormal = (playedRatio < 0.5 && pm.currentTime < 30) || (remainingTime > 15)
                    }
                    
                    if isAbnormal {
                        pm.abnormalStopRetryCount += 1
                        if pm.abnormalStopRetryCount >= pm.maxAbnormalStopRetries {
                            AppLogger.warning("异常结束重试已达上限(\(pm.maxAbnormalStopRetries)次)，跳到下一首")
                            pm.abnormalStopRetryCount = 0
                            pm.autoNext()
                        } else {
                            let resumeTime = pm.currentTime
                            AppLogger.warning(
                                String(localized: "异常结束: 只播放了 \(String(format: "%.1f", pm.currentTime))s / ") +
                                String(localized: "期望 \(String(format: "%.1f", expectedDuration))s (剩余 \(String(format: "%.1f", remainingTime))s)，") +
                                String(localized: "重试第\(pm.abnormalStopRetryCount)次，从 \(String(format: "%.1f", resumeTime))s 续播")
                            )
                            if let song = pm.currentSong {
                                pm.loadAndPlay(song: song, startTime: resumeTime)
                            }
                        }
                    } else {
                        pm.abnormalStopRetryCount = 0
                        AppLogger.info("播放结束 (EOF)，自动下一首")
                        DispatchQueue.main.async {
                            pm.playerDidFinishPlaying()
                        }
                    }
                }
            case .error:
                pm.qualitySwitchTimeoutTask?.cancel()
                pm.qualitySwitchTimeoutTask = nil

                // 网络断流 + 未超重试上限 → 静默刷新 URL 续播（不弹错误、保持 loading 态）
                if isNetworkDisconnected,
                   pm.networkDisconnectRetryCount < pm.maxNetworkDisconnectRetries,
                   let song = pm.currentSong {
                    pm.networkDisconnectRetryCount += 1
                    pm.isPlaying = false
                    pm.isLoading = true
                    pm.refreshPlaybackSurfaceState()
                    let resumeTime = pm.currentTime
                    AppLogger.warning(
                        String(localized: "网络断流，刷新 URL 续播 (第\(pm.networkDisconnectRetryCount)次): ") +
                        String(localized: "\(song.name), 从 \(String(format: "%.1f", resumeTime))s 恢复")
                    )
                    pm.loadAndPlay(song: song, startTime: resumeTime)
                    return
                }

                pm.isPlaying = false
                pm.isLoading = false
                pm.refreshPlaybackSurfaceState()
                pm.saveState()
                AppLogger.error("FFmpeg 播放错误: \(errorDesc ?? "unknown")")
                if let song = pm.currentSong {
                    pm.showPlaybackError(song: song, error: FFmpegError.unknown(code: 0))
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
            pm.qualitySwitchTimeoutTask?.cancel()
            pm.qualitySwitchTimeoutTask = nil
            pm.refreshPlaybackSurfaceState()
            pm.saveState()
        }
    }
    
    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval) {
        let dur = duration
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            guard dur.isFinite && !dur.isNaN && dur > 0 else { return }

            // 过滤明显来自上一首的延迟回调（切歌后极短时间内收到比新歌元数据短很多的旧值）
            // 注意：不过滤 FFmpeg 值比元数据长的情况——那说明真实时长更长，应该信任
            if let metaMs = pm.currentSong?.dt, metaMs > 0 {
                let metaDuration = Double(metaMs) / 1000.0
                let isLikelyStaleDuration =
                    pm.currentTime < 0.5 &&
                    pm.duration > 0 &&
                    dur < metaDuration - 10.0  // FFmpeg 值比元数据短超过 10s，才视为旧歌回调

                if isLikelyStaleDuration {
                    AppLogger.debug(
                        String(localized: "忽略疑似旧歌曲 duration 回调: dur=\(dur), meta=\(metaDuration), song=\(pm.currentSong?.name ?? "nil")")
                    )
                    return
                }
            }

            pm.duration = dur
        }
    }
    
    func playerDidTransitionToNextTrack(_ player: StreamPlayer) {
        let streamInfo = player.streamInfo
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
                guard pm.isGaplessPlaybackEnabled else {
                    AppLogger.info("无缝切歌已关闭，忽略下一首 transition 回调")
                    pm.cancelGaplessPreparation(resetPendingState: true)
                    return
                }
                AppLogger.info("歌曲播放结束，无缝切换到预加载下一首")
                pm.applyPendingTrackTransition()
            }
        }
    }
}
