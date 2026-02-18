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
import Combine
import MediaPlayer
import FFmpegSwiftSDK

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
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
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
    
    // MARK: - Internal Properties (供扩展文件访问)
    var cancellables = Set<AnyCancellable>()
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
    
    /// 音质切换时的 seek 位置，nil 表示不是音质切换
    var pendingQualitySwitchSeek: Double? = nil
    
    /// 保持 delegate adapter 的强引用
    var delegateAdapter: StreamPlayerDelegateAdapter?
    
    /// 持久化时的最大 context 大小（防止序列化过大）
    let maxPersistContextSize = 200
    
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
        let contextRemaining = Array(currentContextList.dropFirst(contextIndex + 1))
        // userQueue 中的歌优先显示，context 后续列表去掉 userQueue 中已有的
        let queueIds = Set(userQueue.map { $0.id })
        let filteredRemaining = contextRemaining.filter { !queueIds.contains($0.id) }
        return userQueue + filteredRemaining
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
        timeUpdateTimer?.invalidate()
        cancellables.removeAll()
        saveStateWorkItem?.cancel()
    }
}


// MARK: - StreamPlayer Delegate 适配器

/// 桥接 StreamPlayerDelegate 回调到 @MainActor PlayerManager
/// StreamPlayer 的回调可能在后台线程，需要 dispatch 到主线程
class StreamPlayerDelegateAdapter: StreamPlayerDelegate {
    private weak var playerManager: PlayerManager?
    
    init(playerManager: PlayerManager) {
        self.playerManager = playerManager
    }
    
    func player(_ player: StreamPlayer, didChangeState state: PlaybackState) {
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            // 记录当前会话 ID，用于校验 .stopped 回调
            let sessionAtCallback = pm.playbackSessionId
            switch state {
            case .idle:
                pm.isPlaying = false
                pm.isLoading = false
            case .connecting:
                pm.isLoading = true
                pm.isPlaying = false
            case .playing:
                pm.isPlaying = true
                pm.isLoading = false
                // 每次进入 playing 都更新流信息（切歌后 streamInfo 会变）
                if let info = player.streamInfo {
                    pm.streamInfo = info
                }
                // 重新应用变调设置（新的播放 pipeline 需要重新设置）
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
                // 忽略旧会话的 .stopped 回调（新歌已经开始播放）
                guard sessionAtCallback == pm.playbackSessionId else { return }
                // 非用户主动停止时处理播放结束
                if !pm.isUserStopping && pm.currentSong != nil {
                    // 保护：如果播放时间远小于总时长，说明不是正常结束（可能是连接中断）
                    let playedRatio = pm.duration > 0 ? pm.currentTime / pm.duration : 0
                    if pm.duration > 0 && playedRatio < 0.5 && pm.currentTime < 30 {
                        AppLogger.warning("异常结束: 只播放了 \(String(format: "%.1f", pm.currentTime))s / \(String(format: "%.1f", pm.duration))s，尝试重新播放")
                        if let song = pm.currentSong {
                            pm.loadAndPlay(song: song)
                        }
                    } else {
                        AppLogger.info("播放结束 (EOF)，自动下一首")
                        pm.playerDidFinishPlaying()
                    }
                }
            case .error(let error):
                pm.isPlaying = false
                pm.isLoading = false
                AppLogger.error("FFmpeg 播放错误: \(error.description)")
                // 自动重试或跳下一首
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
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            AppLogger.error("FFmpeg 错误: \(error.description)")
            pm.isPlaying = false
            pm.isLoading = false
        }
    }
    
    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval) {
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            if duration.isFinite && !duration.isNaN && duration > 0 {
                pm.duration = duration
            }
        }
    }
    
    func playerDidTransitionToNextTrack(_ player: StreamPlayer) {
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            
            // 更新 streamInfo
            if let info = player.streamInfo {
                pm.streamInfo = info
            }
            
            // 判断是音质切换还是切歌
            if let seekTime = pm.pendingQualitySwitchSeek {
                // 音质切换：不推进播放队列，只更新流信息和时间
                AppLogger.info("无缝音质切换完成")
                pm.pendingQualitySwitchSeek = nil
                pm.currentTime = seekTime
                pm.isSeeking = false
                // 重新预加载下一首
                pm.prepareNextTrackURL()
            } else {
                // 正常切歌：SDK 已切换到下一首的 pipeline
                AppLogger.info("无缝切歌：SDK 已准备好下一首，等待当前歌曲结束")
                pm.preparePendingNextTrack()
                pm.hasPendingTrackTransition = true
            }
        }
    }
}
