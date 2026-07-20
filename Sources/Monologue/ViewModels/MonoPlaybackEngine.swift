// MonoPlaybackEngine.swift
// Monologue
//
// Mono播放引擎 facade - @Published 状态、队列模型、子系统持有与初始化。
//
// 扩展文件（保留公开 API 与呈现事务核心）：
//   MonoPlaybackEngine+Setup.swift       - 后台生命周期、切歌保活、代理装配
//   MonoPlaybackEngine+PlaybackAPI.swift  - 核心播放 API（play, playFM, 队列管理）
//   MonoPlaybackEngine+Controls.swift     - 播放控制（暂停/恢复、上下首、切换音质）
//   MonoPlaybackEngine+Seek.swift         - 进度控制（seek、快进、快退）
//   MonoPlaybackEngine+Internal.swift     - 呈现事务、队列快照、播放结束处理
//
// 播放子系统（Sources/Monologue/Playback/，由本类强持有）：
//   AudioSessionCoordinator   - 音频会话/中断/路由/看门狗
//   PlaybackHeartbeat         - 0.25s 心跳调度（进度/睡眠/无缝 tick）
//   GaplessEngine             - 无缝切歌 v2 两阶段状态机
//   MediaSourceResolver       - loadAndPlay 各源取址/下载/解密管线
//   NowPlayingController      - 锁屏/控制中心信息与远程命令
//   WidgetPlaybackSync        - 小组件数据同步
//   PlaybackPersistence       - 状态持久化、历史、scrobble、冷启动恢复
//   DecryptedAudioCacheGovernor - QMC/汽水解密缓存 LRU 治理
//   SleepAndFadeController    - 睡眠定时器与音量包络

import Foundation
import AVFoundation
@preconcurrency import Combine
import MediaPlayer
import UIKit
@preconcurrency import FFmpegSwiftSDK

@MainActor
class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    // 播放模式 / 来源 / 队列快照等纯值类型定义见 Playback/PlaybackModels.swift

    // MARK: - Mono播放引擎 FFmpeg SDK
    let streamPlayer = StreamPlayer()

    // MARK: - 播放子系统（facade 强持有，子系统 unowned 回引）
    private(set) lazy var audioSessionCoordinator = AudioSessionCoordinator(player: self)
    private(set) lazy var nowPlayingController = NowPlayingController(player: self)
    private(set) lazy var widgetSync = WidgetPlaybackSync(player: self)
    private(set) lazy var persistence = PlaybackPersistence(player: self)
    private(set) lazy var sleepAndFade = SleepAndFadeController(player: self)
    private(set) lazy var mediaResolver = MediaSourceResolver(player: self)
    private(set) lazy var gapless = GaplessEngine(player: self)
    private(set) lazy var cacheGovernor = DecryptedAudioCacheGovernor(player: self)
    private(set) lazy var heartbeat = PlaybackHeartbeat(player: self)
    
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
    private var lastPlaybackClockOverflowLogAt = Date.distantPast

    /// Keeps the UI/Now Playing clock inside the active track's real duration.
    /// A failed near-EOF seek can otherwise map audio restarted at zero onto the
    /// old resume timestamp and make a four-minute song appear five minutes long.
    func boundedEnginePlaybackTime(_ rawTime: Double) -> Double? {
        guard rawTime.isFinite, !rawTime.isNaN, rawTime >= 0 else { return nil }
        let metadataDuration = Double(currentSong?.dt ?? 0) / 1_000
        let expectedDuration = max(duration, metadataDuration)
        guard expectedDuration > 0 else { return rawTime }

        if rawTime > expectedDuration + 1,
           Date().timeIntervalSince(lastPlaybackClockOverflowLogAt) >= 10 {
            lastPlaybackClockOverflowLogAt = Date()
            AppLogger.warning(
                "[PlaybackClock] clamped out-of-range engine time raw=\(String(format: "%.2f", rawTime)) duration=\(String(format: "%.2f", expectedDuration))",
                step: "playback.clock.out-of-range"
            )
        }
        return min(rawTime, expectedDuration)
    }

    func isCurrentPlaybackNearNaturalEnd() -> Bool {
        let metadataDuration = Double(currentSong?.dt ?? 0) / 1_000
        let expectedDuration = max(duration, metadataDuration)
        guard expectedDuration > 1 else { return false }
        let position = min(
            max(currentTime, streamPlayer.currentTime),
            expectedDuration
        )
        let endGuard = max(3, min(10, expectedDuration * 0.03))
        return position >= expectedDuration - endGuard
    }
    @Published var showFullScreenPlayer = false
    @Published var mode: PlayMode = .sequence
    @Published var isTabBarHidden: Bool = false
    
    // MARK: - 流信息（Mono播放引擎底层 SDK 提供）
    @Published var streamInfo: StreamInfo?
    
    // MARK: - EQ 均衡器（Mono播放引擎底层 SDK 提供）
    var equalizer: AudioEqualizer {
        streamPlayer.equalizer
    }
    
    // MARK: - 音频效果（Mono播放引擎 FFmpeg avfilter）
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

    /// EQ 与空间处理之前的原始频谱，供 AI 调音等测量任务使用。
    var analysisSpectrumAnalyzer: SpectrumAnalyzer {
        streamPlayer.analysisSpectrumAnalyzer
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
        // 同步锁屏速率，避免锁屏进度按旧速率漂移
        if currentSong != nil {
            updateNowPlayingTime()
        }
    }

    // MARK: - 定时关闭（逻辑在 SleepAndFadeController）
    @Published var sleepTimerRemaining: TimeInterval? = nil
    @Published var sleepTimerConfiguredMinutes: Int? = nil
    @Published var sleepTimerStopAfterCurrentTrack = false
    @Published var pendingSleepStopAfterCurrentTrack = false

    func startSleepTimer(minutes: Int) {
        sleepAndFade.startSleepTimer(minutes: minutes)
    }

    func cancelSleepTimer() {
        sleepAndFade.cancelSleepTimer()
    }

    func activateSleepStopAfterCurrentTrack() {
        sleepAndFade.activateSleepStopAfterCurrentTrack()
    }

    // MARK: - 播放来源
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

    // MARK: - Queue System
    @Published var context: [Song] = []
    @Published var contextIndex: Int = 0
    @Published var shuffledContext: [Song] = []
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
    /// 音质切换 URL 获取的订阅
    var qualitySwitchCancellable: AnyCancellable?
    /// 音质切换轮询任务（可取消）
    var qualitySwitchPollWorkItem: DispatchWorkItem?
    /// 音质切换弱网兜底任务
    var qualitySwitchTimeoutTask: Task<Void, Never>?
    /// 当前播放源的解密密钥（汽水加密缓存等；单曲循环无缝回绕需要）
    var currentPlayingDecryptionKey: String?
    /// 标记是否为用户主动停止（区分 EOF 自然结束 vs 手动 stop）
    var isUserStopping: Bool = false
    /// 播放会话 ID，每次 loadAndPlay 递增，用于忽略旧会话的 .stopped 回调
    var playbackSessionId: Int = 0
    
    /// 当前播放的音频 URL（用于音频分析等功能）
    @Published var currentPlayingURL: String?
    @Published var isCurrentPlaybackUsingLocalFile = false
    /// 当前播放输入的解析时刻：网络流地址从这一刻开始老化，
    /// 恢复播放时超龄的地址会主动重新取址而不是硬 resume 进死流
    var playbackURLResolvedAt: Date?
    /// 冷启动恢复用：上次会话已解析的播放输入（http 地址或本地文件路径）。
    /// 仍然新鲜/存在时，小组件唤醒续播可跳过整个取 URL 往返直接开播。
    var restoredPlaybackAsset: (songId: Int, input: String, resolvedAt: Date?, decryptionKey: String?)?
    /// loadAndPlay 的一次性快速通道：设置后本次加载跳过取址直接开播
    var preresolvedRestorationInput: (input: String, decryptionKey: String?)?
    
    /// 当前歌曲动态封面 URL
    @Published var dynamicCoverUrl: String?
    
    /// 预加载的下一首歌曲信息（等待当前歌曲真正结束后再更新 UI）
    var pendingNextSong: Song? = nil
    /// 标记 SDK 已切换到下一首的 pipeline（但 UI 还没更新）
    var hasPendingTrackTransition: Bool = false

    /// 手动点播 / 下一曲正在准备的新歌。旧歌仍有声音时先保留旧的
    /// `currentSong`，直到 Mono 确认新管线已经进入 playing 再原子提交界面。
    /// 列表行订阅这个目标，立即展示“正在加载”；主播放器仍等到真实出声后才提交。
    @Published var pendingPlaybackPresentationSong: Song?
    /// 点歌过程中对队列和播放来源的临时修改。只有目标管线真正出声才提交；
    /// 取址/下载/会话激活失败则恢复旧歌对应的完整队列状态。
    var pendingPlaybackQueueSnapshot: PlaybackQueueTransactionSnapshot?
    var pendingPlaybackQueueCommitSnapshot: PlaybackQueueTransactionSnapshot?
    var pendingPlaybackPresentationSessionId: Int?
    /// 目标歌曲真正交给 Mono 的输入；只有内核回报同一输入已经出声，才提交 UI。
    var pendingPlaybackPresentationInput: String?
    var pendingPlaybackPresentationDecryptionKey: String?
    var pendingPlaybackPresentationStartTime: Double = 0
    var pendingPlaybackPresentationIsUnblocked = false
    var pendingPlaybackPresentationResolvedQuality: ResolvedPlaybackQuality?
    /// 未命中预热管线时，先在旧歌持续播放期间装配新管线；就绪后再热切。
    var manualPreparedSwitchSessionId: Int?
    var manualSwitchPreparationTask: Task<Void, Never>?
    
    /// 异常停止重试计数器（防止损坏音源无限重试）
    var abnormalStopRetryCount: Int = 0
    let maxAbnormalStopRetries: Int = 3

    /// 网络断流 URL 刷新重试计数（StreamPlayer 层重连失败后，应用层重新获取 URL 续播）
    var networkDisconnectRetryCount: Int = 0
    let maxNetworkDisconnectRetries: Int = 2
    
    /// 音频中断进行中（如微信录音）。状态由 AudioSessionCoordinator 持有，
    /// 这里保留转发给外部调用方（如 MonoNextSuiteManager）与播控扩展。
    var isUnderInterruption: Bool {
        get { audioSessionCoordinator.isUnderInterruption }
        set { audioSessionCoordinator.isUnderInterruption = newValue }
    }
    
    /// 音频中断前是否正在播放（用于中断恢复）
    var wasPlayingBeforeInterruption: Bool {
        get { audioSessionCoordinator.wasPlayingBeforeInterruption }
        set { audioSessionCoordinator.wasPlayingBeforeInterruption = newValue }
    }

    /// 最近一次实际应用到 AVAudioSession 的 options。外部（AudioMatchView）
    /// 会在借用会话后置 nil 强制下次重新激活。
    var lastAppliedAudioSessionOptions: AVAudioSession.CategoryOptions? {
        get { audioSessionCoordinator.lastAppliedAudioSessionOptions }
        set { audioSessionCoordinator.lastAppliedAudioSessionOptions = newValue }
    }
    
    /// 开始播放的时间戳，用于定时器中判断初始缓冲保护窗口
    var playbackStartedAt: Date?
    
    // MARK: - Seek State
    var seekDebounceWorkItem: DispatchWorkItem?
    /// seek 期间为 true，阻止定时器用旧的 streamPlayer.currentTime 覆盖进度条
    var isSeeking: Bool = false
    /// seek 目标时间，用于定时器判断 streamPlayer 是否已到达目标
    var seekTargetTime: Double? = nil
    /// isSeeking 开始的时间戳，用于超时保护
    var seekStartedAt: Date?
    /// 内核尚未确认目标位置时的有限重试次数。超时不能直接恢复旧进度，
    /// 否则向后拖动会表现为滑块自动弹回。
    var seekRetryCount = 0
    let maxSeekRetryCount = 2
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

    // MARK: - 后台播放（节流 + 切歌保活）
    /// App 是否处于后台。后台时降低轮询频率、跳过纯 UI 更新。
    var isAppInBackground: Bool = false
    /// 后台生命周期 observer tokens
    var backgroundStateObservers: [Any] = []
    /// 后台切歌保活任务：歌曲在后台自然结束后，向系统申请额外执行时间，
    /// 保证下一首的播放 URL 网络请求能在 App 被挂起前完成。
    var transitionKeepAliveTaskId: UIBackgroundTaskIdentifier = .invalid

    // MARK: - 断点续播保鲜
    /// 最近一次进入暂停的时刻。网络流暂停超过 `networkResumeRefreshThreshold`
    /// 后再恢复时，CDN URL 大概率已过期，直接重新取址从断点续播。
    var lastPausedAt: Date?
    /// 网络流暂停多久后恢复要走「重新取址续播」而非直接 resume（秒）
    nonisolated static let networkResumeRefreshThreshold: TimeInterval = 20 * 60

    /// 持久化时的最大 context 大小（防止序列化过大）
    let maxPersistContextSize = 200
    /// 回退栈最大长度（防止无限增长）
    let maxBackStackSize = 200
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
        audioSessionCoordinator.setupAudioSession()
        nowPlayingController.setupRemoteCommands()
        setupBackgroundStateObservers()
        setupStreamPlayerDelegate()
        let gaplessEnabled = Self.gaplessPlaybackEnabled()
        streamPlayer.setAutomaticPreparedTrackTransitionEnabled(gaplessEnabled)
        streamPlayer.setCrossfadeDuration(
            gaplessEnabled && Self.crossfadePlaybackEnabled()
                ? Self.crossfadePlaybackDuration
                : 0
        )
        heartbeat.start()
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
        // 上一会话可能留下超限的解密缓存，冷启动先做一次 LRU 收敛
        scheduleDecryptedAudioCacheCleanup(force: true)
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
            heartbeat.stop()
            cancellables.removeAll()
            qualitySwitchCancellable?.cancel()
            qualitySwitchPollWorkItem?.cancel()
            qualitySwitchTimeoutTask?.cancel()
            manualSwitchPreparationTask?.cancel()
            mediaResolver.cancelAll()
            gapless.cancelAllWork()
            widgetSync.cancelPendingWork()
            sleepAndFade.cancelAllWork()
            persistence.cancelPendingWork()
            audioSessionCoordinator.cancelAllWork()
            for observer in backgroundStateObservers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}


// MARK: - Mono播放引擎底层 SDK Delegate 适配器

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
        let playbackInput = player.currentPlaybackInput
        let errorDesc: String? = {
            if case .error(let e) = state { return e.description }
            return nil
        }()
        // 可通过「刷新 URL 重连」自愈的流错误：
        // 断流、连接失败（CDN 地址过期 403/404、socket 死亡）、超时、未知错误。
        // 仅格式不支持 / 解码 / 资源分配类错误换地址也无济于事，直接报错。
        let isRetryableStreamError: Bool = {
            if case .error(let e) = state {
                switch e {
                case .networkDisconnected, .connectionFailed, .connectionTimeout, .unknown:
                    return true
                case .unsupportedFormat, .decodingFailed, .resourceAllocationFailed:
                    return false
                }
            }
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
            // 全路径会话守卫：旧管线在会话递进前发出的迟到回调，不允许改写
            // 新会话的播放状态或触发新会话的重试逻辑。会话内的主动停止走
            // suppressStopHandlingUntil，其回调在会话递进后发出，不受影响。
            guard sessionAtCallback == pm.playbackSessionId else {
                AppLogger.debug(
                    "忽略过期播放回调 kind=\(String(describing: kind)) session=\(sessionAtCallback)/\(pm.playbackSessionId)"
                )
                return
            }
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
                if let info = streamInfo {
                    pm.streamInfo = info
                }
                pm.isPlaying = true
                pm.isLoading = false
                // 只有 Mono 已完成连接、解码、首段 PCM 预填充并进入 playing，
                // 才把手动切歌的新元数据提交给界面。
                pm.commitPendingPlaybackPresentationIfNeeded(
                    sessionId: sessionAtCallback,
                    engineInput: playbackInput
                )
                // 播放已恢复出声，音频会话重新保活 App，释放切歌后台任务
                pm.endTransitionKeepAlive()
                pm.qualitySwitchTimeoutTask?.cancel()
                pm.qualitySwitchTimeoutTask = nil
                pm.qualitySwitchRecoveryAttempts = 0
                // 网络重试预算按整首歌曲计算，不能仅因短暂进入 playing 就清零；
                // 否则“连接成功几秒又断开”会无限刷新 URL。新点歌时统一重置。
                if pm.pitchSemitones != 0 {
                    pm.audioEffects.setPitch(pm.pitchSemitones)
                    AppLogger.info("播放状态变为 playing，重新应用变调: \(pm.pitchSemitones) 半音")
                }
                if !pm.isSeeking {
                    if let t = pm.boundedEnginePlaybackTime(
                        pm.streamPlayer.currentTime
                    ), t > 0 {
                        pm.currentTime = t
                    }
                }
                LyricViewModel.shared.updateCurrentTime(pm.currentTime)
                pm.refreshPlaybackSurfaceState()
                if pm.sleepAndFade.playbackStartFadeSongID == pm.currentSong?.id {
                    let duration = pm.sleepAndFade.playbackStartFadeDuration
                    let reason = pm.sleepAndFade.playbackStartFadeReason
                    let durationText = String(format: "%.2f", duration)
                    pm.clearPlaybackStartFade(restoreVolume: false)
                    // AudioRenderer 会在 AVAudioEngine 创建前保留 0 音量；这里
                    // 再次收敛到 0，确保首个可闻 PCM 从包络起点开始。
                    pm.streamPlayer.outputVolume = 0.0
                    AppLogger.info("播放启动淡入 reason=\(reason) duration=\(durationText)s")
                    pm.beginPlaybackFade(to: 1.0, duration: duration)
                }
                pm.scheduleGaplessMediaPrefetchIfNeeded()
            case .paused:
                if let info = streamInfo {
                    pm.streamInfo = info
                }
                // A remotely selected track may intentionally start paused.
                // The pipeline is ready, so commit its identity without first
                // releasing output and racing a delayed pause.
                pm.commitPendingPlaybackPresentationIfNeeded(
                    sessionId: sessionAtCallback,
                    engineInput: playbackInput
                )
                pm.isPlaying = false
                pm.isLoading = false
                pm.lastPausedAt = Date()
                pm.endTransitionKeepAlive()
                pm.refreshPlaybackSurfaceState()
                pm.saveState()
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
                // 手动下一首仍在取址 / 下载 / preroll 时，这个 stop 属于旧歌。
                // 无论旧歌的元数据时长是否准确，都不能把它当成异常再次续播，
                // 否则会出现旧歌从头播第二遍，而界面已经准备显示下一首。
                if let pending = pm.pendingPlaybackPresentationSong {
                    pm.isLoading = true
                    pm.refreshPlaybackSurfaceState()
                    AppLogger.info(
                        "[PlaybackTransition] 旧管线已结束，继续等待目标歌曲 target=\(pending.name) engine=\(playbackInput ?? "nil")",
                        step: "playback.transition.old-pipeline-ended"
                    )
                    return
                }
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
                                // 异常结束多半是地址失效/截断：重试必须拿新鲜地址
                                PlaybackURLCache.shared.invalidate(song: song)
                                pm.loadAndPlay(
                                    song: song,
                                    startTime: resumeTime,
                                    fadeInDuration: 0.8,
                                    fadeInReason: "abnormal stream retry",
                                    preserveRetryBudget: true
                                )
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

                // A transport may report its final close as a network error
                // instead of EOF. Near the real track end this is completion,
                // not a reason to reload the same song from a failed seek.
                if isRetryableStreamError,
                   pm.pendingPlaybackPresentationSong == nil,
                   pm.isCurrentPlaybackNearNaturalEnd() {
                    pm.networkDisconnectRetryCount = 0
                    pm.abnormalStopRetryCount = 0
                    pm.isPlaying = false
                    pm.isLoading = false
                    pm.clearPlaybackStartFade(restoreVolume: true)
                    pm.cancelPlaybackFade(restoreVolume: true)
                    pm.endTransitionKeepAlive()
                    pm.currentTime = max(
                        pm.duration,
                        Double(pm.currentSong?.dt ?? 0) / 1_000
                    )
                    pm.refreshPlaybackSurfaceState()
                    pm.updateNowPlayingTime()
                    AppLogger.info(
                        "[PlaybackRecovery] near-end transport close treated as completion",
                        step: "playback.recovery.near-end-completion"
                    )
                    pm.playerDidFinishPlaying()
                    return
                }

                // 可自愈的流错误（断流/连接失败/超时/未知）+ 未超重试上限
                // → 静默刷新 URL 续播（不弹错误、保持 loading 态）。
                // 小组件/后台唤醒续播撞上过期 CDN 地址时也走这里，用户无感。
                if isRetryableStreamError,
                   pm.networkDisconnectRetryCount < pm.maxNetworkDisconnectRetries,
                   let song = pm.pendingPlaybackPresentationSong ?? pm.currentSong {
                    pm.networkDisconnectRetryCount += 1
                    pm.isPlaying = false
                    pm.isLoading = true
                    pm.refreshPlaybackSurfaceState()
                    let isPendingSong = pm.matchesPlaybackTarget(
                        pm.pendingPlaybackPresentationSong,
                        expected: song
                    )
                    let resumeTime = isPendingSong
                        ? pm.pendingPlaybackPresentationStartTime
                        : pm.currentTime
                    AppLogger.warning(
                        String(localized: "播放流中断，刷新 URL 续播 (第\(pm.networkDisconnectRetryCount)次): ") +
                        String(localized: "\(song.name), 从 \(String(format: "%.1f", resumeTime))s 恢复")
                    )
                    // 重试必须绕过地址缓存拿新鲜 URL
                    PlaybackURLCache.shared.invalidate(song: song)
                    pm.loadAndPlay(
                        song: song,
                        startTime: resumeTime,
                        fadeInDuration: 0.8,
                        fadeInReason: "network stream retry",
                        preserveRetryBudget: true
                    )
                    return
                }

                pm.isPlaying = false
                pm.isLoading = false
                pm.clearPlaybackStartFade(restoreVolume: true)
                pm.cancelPlaybackFade(restoreVolume: true)
                pm.endTransitionKeepAlive()
                pm.refreshPlaybackSurfaceState()
                pm.saveState()
                AppLogger.error("Mono播放引擎底层 SDK 播放错误: \(errorDesc ?? "unknown")")
                if let song = pm.pendingPlaybackPresentationSong ?? pm.currentSong {
                    _ = pm.discardPendingPlaybackPresentationIfNeeded(
                        song: song,
                        sessionId: pm.playbackSessionId
                    )
                    pm.showPlaybackError(song: song, error: FFmpegError.unknown(code: 0))
                }
            }
        }
    }
    
    func player(_ player: StreamPlayer, didEncounterError error: FFmpegError) {
        let desc = error.description
        Task { @MainActor [weak self] in
            guard self?.playerManager != nil else { return }
            // 播放状态与自动恢复只由 didChangeState(.error) 统一处理。
            // 这里保留诊断日志，避免第二条错误回调把正在进行的刷新 URL
            // 续播重新改成非 loading 状态。
            AppLogger.error("Mono播放引擎底层 SDK 错误: \(desc)")
        }
    }
    
    func player(_ player: StreamPlayer, didUpdateDuration duration: TimeInterval) {
        let dur = duration
        let sessionAtCallback = self.currentSessionId
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            guard sessionAtCallback == pm.playbackSessionId else { return }
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
            if pm.currentTime > dur {
                pm.currentTime = dur
            }
        }
    }
    
    func playerDidTransitionToNextTrack(_ player: StreamPlayer) {
        let streamInfo = player.streamInfo
        let playbackInput = player.currentPlaybackInput
        let sessionAtCallback = self.currentSessionId
        Task { @MainActor [weak self] in
            guard let pm = self?.playerManager else { return }
            // 回调发出后用户已显式切歌/停止（会话被作废），这次 transition
            // 属于被替换的旧管线，落地会把 UI 推进到已经不存在的下一首。
            guard sessionAtCallback == pm.playbackSessionId else {
                AppLogger.debug(
                    "忽略过期 transition 回调 session=\(sessionAtCallback)/\(pm.playbackSessionId)"
                )
                return
            }

            if let info = streamInfo {
                pm.streamInfo = info
            }

            if let sessionId = pm.manualPreparedSwitchSessionId {
                pm.completeManualPreparedSwitch(
                    sessionId: sessionId,
                    engineInput: playbackInput
                )
                return
            }
            
            if let seekTime = pm.pendingQualitySwitchSeek {
                AppLogger.info("无缝音质切换完成")
                pm.pendingQualitySwitchSeek = nil
                pm.currentTime = seekTime
                pm.isSeeking = false
            } else if pm.gapless.pendingLoopRestart {
                AppLogger.info("单曲循环无缝回绕")
                pm.gapless.pendingLoopRestart = false
                pm.handleSeamlessLoopRestart(engineInput: playbackInput)
            } else {
                guard pm.isGaplessPlaybackEnabled else {
                    AppLogger.info("无缝切歌已关闭，忽略下一首 transition 回调")
                    pm.cancelGaplessPreparation(resetPendingState: true)
                    return
                }
                AppLogger.info("歌曲播放结束，无缝切换到预加载下一首")
                pm.applyPendingTrackTransition(engineInput: playbackInput)
            }
        }
    }
}
