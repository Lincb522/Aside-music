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
    private let streamPlayer = StreamPlayer()
    private var timeUpdateTimer: Timer?
    
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
    
    /// 当前播放的歌是否来自解灰源
    @Published private(set) var isCurrentSongUnblocked: Bool = false
    
    // MARK: - Queue System
    @Published private(set) var context: [Song] = []
    @Published private(set) var contextIndex: Int = -1
    @Published private(set) var shuffledContext: [Song] = []
    @Published var userQueue: [Song] = []
    @Published var history: [Song] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var saveStateWorkItem: DispatchWorkItem?
    private let saveStateDebounceInterval: TimeInterval = AppConfig.Player.saveStateDebounceInterval
    /// 标记是否为用户主动停止（区分 EOF 自然结束 vs 手动 stop）
    var isUserStopping: Bool = false
    /// 播放会话 ID，每次 loadAndPlay 递增，用于忽略旧会话的 .stopped 回调
    var playbackSessionId: Int = 0
    
    /// 当前播放的音频 URL（用于音频分析等功能）
    @Published private(set) var currentPlayingURL: String?
    fileprivate var consecutiveFailures: Int = 0
    fileprivate let maxConsecutiveFailures: Int = AppConfig.Player.maxConsecutiveFailures
    fileprivate var retryDelay: TimeInterval = AppConfig.Player.initialRetryDelay
    fileprivate let maxRetryDelay: TimeInterval = AppConfig.Player.maxRetryDelay
    
    /// 预加载的下一首歌曲信息（等待当前歌曲真正结束后再更新 UI）
    fileprivate var pendingNextSong: Song? = nil
    /// 标记 SDK 已切换到下一首的 pipeline（但 UI 还没更新）
    fileprivate var hasPendingTrackTransition: Bool = false
    
    // MARK: - Remote Command Center
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    // MARK: - Computed Properties
    var currentContextList: [Song] {
        return mode == .shuffle ? shuffledContext : context
    }
    
    var currentIndexInContext: Int {
        return contextIndex
    }
    
    var upcomingSongs: [Song] {
        let contextRemaining = currentContextList.dropFirst(contextIndex + 1)
        return userQueue + contextRemaining
    }
    
    // MARK: - Init
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupStreamPlayerDelegate()
        startTimeUpdateTimer()
        fetchHistory()
        restoreState()
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

    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            AppLogger.error("AVAudioSession 配置失败: \(error)")
        }
        
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { _ in
            AppLogger.warning("媒体服务被重置，重建 audio session")
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
            } catch {
                AppLogger.error("重建 audio session 失败: \(error)")
            }
            // 如果正在播放，重新触发当前歌曲播放（让库重新走 AudioRenderer.start 流程）
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let song = self.currentSong, self.isPlaying {
                    let time = self.currentTime
                    AppLogger.info("媒体服务重置后重新播放: \(song.name), 从 \(String(format: "%.1f", time))s 继续")
                    self.loadAndPlay(song: song, startTime: time)
                }
            }
        }
    }
    
    private func setupRemoteCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    /// 设置 StreamPlayer delegate（通过桥接适配器）
    private func setupStreamPlayerDelegate() {
        let adapter = StreamPlayerDelegateAdapter(playerManager: self)
        self.delegateAdapter = adapter
        streamPlayer.delegate = adapter
    }
    
    /// 保持 delegate adapter 的强引用
    private var delegateAdapter: StreamPlayerDelegateAdapter?
    
    /// 定时器轮询 StreamPlayer 的 currentTime
    private func startTimeUpdateTimer() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying, !self.isLoading else { return }
                
                if self.isSeeking {
                    // seek 中：检查 streamPlayer 是否已到达目标位置
                    if let target = self.seekTargetTime {
                        let sdkTime = self.streamPlayer.currentTime
                        if sdkTime.isFinite && !sdkTime.isNaN && sdkTime >= target - 1.0 {
                            // SDK 已到达目标附近，解除 seeking
                            self.isSeeking = false
                            self.seekTargetTime = nil
                            self.currentTime = sdkTime
                        }
                        // 否则保持 currentTime 不变（停在用户拖到的位置）
                    }
                    return
                }
                
                let time = self.streamPlayer.currentTime
                if time.isFinite && !time.isNaN {
                    // 防止刚开始播放时进度条跳前：
                    // 如果当前显示接近 0 但 SDK 报告了一个较大的值，忽略它
                    let jump = time - self.currentTime
                    if self.currentTime < 1.0 && jump > 2.0 {
                        // 刚开始播放，SDK 的时间不可信（解码缓冲超前），跳过
                    } else {
                        // 检查是否有待切换的下一首
                        if self.hasPendingTrackTransition {
                            // SDK 已经在播放下一首了，此时 streamPlayer.currentTime 是下一首的时间
                            // 当下一首的时间 > 0.3 秒时，说明当前歌曲已经结束，可以切换 UI
                            if time > 0.3 {
                                AppLogger.info("检测到下一首已开始播放 (\(String(format: "%.2f", time))s)，切换 UI")
                                self.applyPendingTrackTransition()
                                return
                            }
                            // 下一首刚开始，继续等待
                            return
                        }
                        self.currentTime = time
                    }
                }
                self.updateNowPlayingTime()
                
                // 全局歌词同步
                LyricViewModel.shared.updateCurrentTime(self.currentTime)
            }
        }
    }


    // MARK: - Core Playback API
    
    func play(song: Song, in context: [Song]) {
        self.context = context
        self.playSource = .normal
        
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
        } else {
            self.context.insert(song, at: 0)
            self.contextIndex = 0
        }
        
        if mode == .shuffle {
            generateShuffledContext()
        }
        
        loadAndPlay(song: song)
    }
    
    func playFM(song: Song, in context: [Song], autoPlay: Bool = true) {
        self.context = context
        self.playSource = .fm
        
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
        } else {
            self.contextIndex = 0
        }
        
        self.mode = .sequence
        loadAndPlay(song: song, autoPlay: autoPlay)
    }
    
    /// 预设 FM 上下文（不触发播放），用于进入 FM 界面时展示歌曲信息
    func prepareFM(song: Song, in context: [Song]) {
        self.context = context
        self.playSource = .fm
        self.currentSong = song
        
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
        } else {
            self.contextIndex = 0
        }
        
        self.mode = .sequence
        saveState()
    }
    
    func playPodcast(song: Song, in context: [Song], radioId: Int) {
        self.context = context
        self.playSource = .podcast(radioId: radioId)
        
        var songToPlay = song
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
            songToPlay = context[index]
        } else {
            self.context.insert(song, at: 0)
            self.contextIndex = 0
        }
        
        self.mode = .sequence
        loadAndPlay(song: songToPlay)
    }
    
    func appendContext(songs: [Song]) {
        let newSongs = songs.filter { newSong in !self.context.contains(where: { $0.id == newSong.id }) }
        guard !newSongs.isEmpty else { return }
        
        self.context.append(contentsOf: newSongs)
        if mode == .shuffle {
            self.shuffledContext.append(contentsOf: newSongs.shuffled())
        }
        saveState()
    }
    
    func playSingle(song: Song) {
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        self.context = [song]
        self.contextIndex = 0
        self.shuffledContext = [song]
        self.playSource = .normal
        
        loadAndPlay(song: song)
    }
    
    func playNext(song: Song) {
        userQueue.removeAll { $0.id == song.id }
        userQueue.insert(song, at: 0)
        saveState()
    }
    
    func addToQueue(song: Song) {
        if !userQueue.contains(where: { $0.id == song.id }) {
            userQueue.append(song)
            saveState()
        }
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < userQueue.count else { return }
        userQueue.remove(at: index)
        saveState()
    }
    
    func removeFromUpcoming(at index: Int) {
        let userQueueCount = userQueue.count
        
        if index < userQueueCount {
            userQueue.remove(at: index)
        } else {
            let contextListIndex = contextIndex + 1 + (index - userQueueCount)
            let list = currentContextList
            
            if contextListIndex >= 0 && contextListIndex < list.count {
                let songToRemove = list[contextListIndex]
                context.removeAll { $0.id == songToRemove.id }
                if mode == .shuffle {
                    shuffledContext.removeAll { $0.id == songToRemove.id }
                }
            }
        }
        saveState()
    }
    
    func playFromQueue(song: Song) {
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        if let queueIndex = userQueue.firstIndex(where: { $0.id == song.id }) {
            userQueue.remove(at: queueIndex)
            if let contextListIndex = currentContextList.firstIndex(where: { $0.id == song.id }) {
                contextIndex = contextListIndex
            }
            loadAndPlay(song: song)
            return
        }
        
        if let contextListIndex = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = contextListIndex
            loadAndPlay(song: song)
            return
        }
        
        playSingle(song: song)
    }
    
    func isInUserQueue(song: Song) -> Bool {
        return userQueue.contains(where: { $0.id == song.id })
    }
    
    func isUpcomingIndexInUserQueue(at index: Int) -> Bool {
        return index < userQueue.count
    }
    
    func clearUserQueue() {
        userQueue.removeAll()
        saveState()
    }


    // MARK: - Playback Controls
    
    func togglePlayPause() {
        if isPlaying {
            streamPlayer.pause()
            isPlaying = false
        } else {
            streamPlayer.resume()
            isPlaying = true
        }
        updateNowPlayingTime()
    }
    
    func next() {
        consecutiveFailures = 0
        retryDelay = 1.0
        
        if let nextSong = userQueue.first {
            userQueue.removeFirst()
            if let index = currentContextList.firstIndex(where: { $0.id == nextSong.id }) {
                contextIndex = index
            }
            loadAndPlay(song: nextSong)
            return
        }
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0
        }
        
        contextIndex = nextIndex
        loadAndPlay(song: list[nextIndex])
    }
    
    func previous() {
        consecutiveFailures = 0
        retryDelay = 1.0
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var prevIndex = contextIndex - 1
        if prevIndex < 0 {
            prevIndex = list.count - 1
        }
        
        contextIndex = prevIndex
        loadAndPlay(song: list[prevIndex])
    }
    
    func switchMode() {
        mode = mode.next
        
        if mode == .shuffle {
            generateShuffledContext()
        } else {
            if let current = currentSong {
                contextIndex = context.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
        
        saveState()
    }
    
    func stopAndClear() {
        isUserStopping = true
        streamPlayer.stop()
        isPlaying = false
        currentSong = nil
        streamInfo = nil
        isUserStopping = false
        saveState()
    }
    
    func switchQuality(_ quality: SoundQuality) {
        guard soundQuality != quality else { return }
        
        if let current = currentSong {
            let time = currentTime
            
            Task { @MainActor in
                APIService.shared.fetchSongUrl(
                    id: current.id,
                    level: quality.rawValue,
                    kugouQuality: self.kugouQuality.rawValue
                )
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            AppLogger.error("切换音质失败: \(error)")
                            AlertManager.shared.show(
                                title: "切换失败",
                                message: "无法获取该音质的音频，请稍后重试",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self = self, let url = URL(string: result.url) else { return }
                        self.soundQuality = quality
                        self.isCurrentSongUnblocked = result.isUnblocked
                        self.streamInfo = nil
                        // 记录这是音质切换（不是切歌），seek 位置
                        self.pendingQualitySwitchSeek = time
                        // 用 prepareNext 预加载新音质的 URL
                        self.streamPlayer.prepareNext(url: url.absoluteString)
                        // prepareNext 完成后，用 switchToNext 触发切换
                        // switchToNext 会在播放循环中检查 forceTransition 并执行
                        self.pollAndSwitch(seekTo: time, attempts: 0)
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            soundQuality = quality
        }
    }
    
    /// 切换酷狗音质（解灰歌曲专用）
    func switchKugouQuality(_ quality: KugouQuality) {
        guard kugouQuality != quality else { return }
        
        if let current = currentSong, isCurrentSongUnblocked {
            let time = currentTime
            
            Task { @MainActor in
                APIService.shared.fetchSongUrl(
                    id: current.id,
                    level: self.soundQuality.rawValue,
                    kugouQuality: quality.rawValue
                )
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            AppLogger.error("切换酷狗音质失败: \(error)")
                            AlertManager.shared.show(
                                title: "切换失败",
                                message: "无法获取该音质的音频，请稍后重试",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self = self, let url = URL(string: result.url) else { return }
                        self.kugouQuality = quality
                        self.streamInfo = nil
                        self.pendingQualitySwitchSeek = time
                        self.streamPlayer.prepareNext(url: url.absoluteString)
                        self.pollAndSwitch(seekTo: time, attempts: 0)
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            kugouQuality = quality
        }
    }
    
    /// 音质切换时的 seek 位置，nil 表示不是音质切换
    fileprivate var pendingQualitySwitchSeek: Double? = nil
    
    /// 轮询预加载状态，就绪后触发切换
    private func pollAndSwitch(seekTo time: Double, attempts: Int) {
        guard attempts < 200 else {
            // 超时降级（200 * 0.05s = 10s）
            AppLogger.warning("音质切换预加载超时，降级为重新播放")
            pendingQualitySwitchSeek = nil
            streamPlayer.cancelNextPreparation()
            if let song = currentSong {
                loadAndPlay(song: song, startTime: time)
            }
            return
        }
        
        // 每次只尝试触发 switchToNext，如果预加载还没就绪会直接返回（不会重复设置标志）
        // switchToNext 内部有 guard isNextReady 保护
        streamPlayer.switchToNext(seekTo: time)
        
        // 短暂延迟后检查是否已切换
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            if self.pendingQualitySwitchSeek == nil {
                // 已在 delegate 回调中清除，说明切换成功
                return
            }
            self.pollAndSwitch(seekTo: time, attempts: attempts + 1)
        }
    }
    
    // MARK: - Seek
    
    private var seekDebounceWorkItem: DispatchWorkItem?
    /// seek 期间为 true，阻止定时器用旧的 streamPlayer.currentTime 覆盖进度条
    fileprivate var isSeeking: Bool = false
    /// seek 目标时间，用于定时器判断 streamPlayer 是否已到达目标
    private var seekTargetTime: Double? = nil
    
    func seek(to time: Double) {
        isSeeking = true
        seekTargetTime = time
        currentTime = time
        updateNowPlayingTime()
        
        // Debounce：快速拖动时只执行最后一次 seek
        seekDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.streamPlayer.seek(to: time)
        }
        seekDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }
    
    func seekForward(seconds: Double = 15) {
        seek(to: min(currentTime + seconds, duration))
    }
    
    func seekBackward(seconds: Double = 15) {
        seek(to: max(currentTime - seconds, 0))
    }


    // MARK: - Private Methods
    
    private func generateShuffledContext() {
        guard let current = currentSong else {
            shuffledContext = context.shuffled()
            return
        }
        
        var shuffled = context.shuffled()
        if let index = shuffled.firstIndex(where: { $0.id == current.id }) {
            shuffled.remove(at: index)
            shuffled.insert(current, at: 0)
        }
        shuffledContext = shuffled
        contextIndex = 0
    }
    
    /// StreamPlayer 播放结束回调（由 delegate adapter 调用）
    func playerDidFinishPlaying() {
        AppLogger.info("playerDidFinishPlaying 被调用, currentTime=\(currentTime), duration=\(duration), song=\(currentSong?.name ?? "nil")")
        switch mode {
        case .loopSingle:
            // 重新播放当前歌曲
            if let song = currentSong {
                loadAndPlay(song: song)
            }
        case .sequence, .shuffle:
            next()
        }
    }
    
    /// 无缝切歌：SDK 已自动切换到下一首的 pipeline，这里只更新 UI 状态
    /// 不调用 loadAndPlay（因为 StreamPlayer 已经在播放了）
    fileprivate func advanceToNextTrack() {
        // 单曲循环模式下不应该走到这里（SDK 不会 prepareNext），但保险起见
        guard mode != .loopSingle else { return }
        
        consecutiveFailures = 0
        retryDelay = 1.0
        
        // 确定下一首歌曲
        var nextSong: Song?
        
        // 从用户队列取下一首
        if let queueFirst = userQueue.first {
            userQueue.removeFirst()
            nextSong = queueFirst
            if let index = currentContextList.firstIndex(where: { $0.id == queueFirst.id }) {
                contextIndex = index
            }
        } else {
            // 从 context 列表取下一首
            let list = currentContextList
            guard !list.isEmpty else { return }
            
            var nextIndex = contextIndex + 1
            if nextIndex >= list.count {
                nextIndex = 0
            }
            
            contextIndex = nextIndex
            nextSong = list[nextIndex]
        }
        
        guard let song = nextSong else { return }
        
        // 立即更新 UI（SDK 已经在播放下一首了）
        currentSong = song
        LyricViewModel.shared.fetchLyrics(for: song.id)
        addToHistory(song: song)
        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
    }
    
    /// 准备下一首歌曲信息（不更新 UI，等待当前歌曲真正结束）
    fileprivate func preparePendingNextTrack() {
        // 单曲循环模式下不预加载
        guard mode != .loopSingle else { return }
        
        // 确定下一首歌曲
        if let queueFirst = userQueue.first {
            pendingNextSong = queueFirst
        } else {
            let list = currentContextList
            guard !list.isEmpty else { return }
            
            var nextIndex = contextIndex + 1
            if nextIndex >= list.count {
                nextIndex = 0
            }
            pendingNextSong = list[nextIndex]
        }
    }
    
    /// 当前歌曲真正结束后，应用待切换的下一首
    fileprivate func applyPendingTrackTransition() {
        guard hasPendingTrackTransition, let song = pendingNextSong else { return }
        
        hasPendingTrackTransition = false
        pendingNextSong = nil
        consecutiveFailures = 0
        retryDelay = 1.0
        
        // 更新队列索引
        if userQueue.first?.id == song.id {
            userQueue.removeFirst()
        }
        if let index = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = index
        }
        
        // 更新 UI
        currentSong = song
        currentTime = 0
        LyricViewModel.shared.fetchLyrics(for: song.id)
        addToHistory(song: song)
        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
        
        // 预加载下一首
        prepareNextTrackURL()
    }
    
    /// 预加载下一首歌曲的 URL，传给 StreamPlayer.prepareNext
    fileprivate func prepareNextTrackURL() {
        // 单曲循环不预加载（会重新 play）
        guard mode != .loopSingle else { return }
        
        // 确定下一首歌曲
        let nextSong: Song?
        if let queueFirst = userQueue.first {
            nextSong = queueFirst
        } else {
            let list = currentContextList
            guard !list.isEmpty else { return }
            var nextIndex = contextIndex + 1
            if nextIndex >= list.count {
                nextIndex = 0
            }
            nextSong = list[nextIndex]
        }
        
        guard let song = nextSong else { return }
        
        // 优先使用本地文件
        if let localURL = DownloadManager.shared.localFileURL(songId: song.id) {
            AppLogger.info("预加载下一首 (本地): \(song.name)")
            streamPlayer.prepareNext(url: localURL.absoluteString)
            return
        }
        
        // 网络获取 URL
        Task { @MainActor in
            APIService.shared.fetchSongUrl(
                id: song.id,
                level: self.soundQuality.rawValue,
                kugouQuality: self.kugouQuality.rawValue
            )
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.warning("预加载下一首 URL 获取失败: \(error)")
                }
            }, receiveValue: { [weak self] result in
                guard let self = self, let url = URL(string: result.url) else { return }
                AppLogger.info("预加载下一首 (网络): \(song.name)")
                self.streamPlayer.prepareNext(url: url.absoluteString)
            })
            .store(in: &self.cancellables)
        }
    }
    
    fileprivate func loadAndPlay(song: Song, autoPlay: Bool = true, startTime: Double = 0) {
        // 递增会话 ID，旧会话的 .stopped 回调会被忽略
        playbackSessionId += 1
        // 清除待切换状态（用户手动切歌）
        hasPendingTrackTransition = false
        pendingNextSong = nil
        
        isLoading = true
        currentSong = song
        isCurrentSongUnblocked = false
        streamInfo = nil
        addToHistory(song: song)
        saveState()
        
        // 全局歌词获取
        LyricViewModel.shared.fetchLyrics(for: song.id)
        
        // 上报听歌记录到网易云（异步，不阻塞播放）
        scrobbleToCloud(song: song)

        // 优先使用本地已下载文件
        if let localURL = DownloadManager.shared.localFileURL(songId: song.id) {
            AppLogger.info("使用本地下载文件播放: \(song.name)")
            self.consecutiveFailures = 0
            self.retryDelay = 1.0
            self.startPlayback(url: localURL, autoPlay: autoPlay, startTime: startTime)
            return
        }

        Task { @MainActor in
            APIService.shared.fetchSongUrl(
                id: song.id,
                level: self.soundQuality.rawValue,
                kugouQuality: self.kugouQuality.rawValue
            )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    if case .failure(let error) = completion {
                        AppLogger.error("获取播放 URL 失败: \(error)")
                        self.isLoading = false

                        let isUnavailable = error is APIService.PlaybackError &&
                            (error as! APIService.PlaybackError) == .unavailable

                        self.consecutiveFailures += 1

                        if self.consecutiveFailures >= self.maxConsecutiveFailures {
                            AlertManager.shared.show(
                                title: isUnavailable ? "无法播放" : "播放失败",
                                message: isUnavailable
                                    ? "连续多首歌曲暂无版权"
                                    : "连续多首歌曲无法播放，请检查网络连接",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                            self.consecutiveFailures = 0
                            self.retryDelay = 1.0
                            return
                        }

                        if autoPlay {
                            let currentDelay = self.retryDelay
                            self.retryDelay = min(self.retryDelay * 2, self.maxRetryDelay)
                            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) { [weak self] in
                                self?.autoNext()
                            }
                        }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self, let url = URL(string: result.url) else { return }
                    self.consecutiveFailures = 0
                    self.retryDelay = 1.0
                    self.isCurrentSongUnblocked = result.isUnblocked
                    
                    // 边听边存
                    if SettingsManager.shared.listenAndSave,
                       !DownloadManager.shared.isDownloaded(songId: song.id) {
                        DownloadManager.shared.download(song: song, quality: self.soundQuality)
                    }
                    
                    self.startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
                })
                .store(in: &self.cancellables)
        }
    }
    
    private func autoNext() {
        if let nextSong = userQueue.first {
            userQueue.removeFirst()
            if let index = currentContextList.firstIndex(where: { $0.id == nextSong.id }) {
                contextIndex = index
            }
            loadAndPlay(song: nextSong)
            return
        }
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0
        }
        
        contextIndex = nextIndex
        loadAndPlay(song: list[nextIndex])
    }
    
    private func startPlayback(url: URL, autoPlay: Bool = true, startTime: Double = 0) {
        isLoading = true
        
        if startTime <= 0 {
            self.currentTime = 0
            self.duration = 0
        }
        
        // 保存当前播放 URL（用于音频分析等功能）
        self.currentPlayingURL = url.absoluteString
        
        AppLogger.network("开始播放 (FFmpeg): \(url.absoluteString)")
        
        // 不需要手动 stop —— streamPlayer.play() 内部会先调用 stopInternal() 清理
        // 直接调用 play 即可，避免触发多余的 .stopped 回调
        
        AppLogger.info("startPlayback session=\(playbackSessionId), url=\(url.lastPathComponent)")
        
        // 使用 StreamPlayer 播放
        streamPlayer.play(url: url.absoluteString)
        
        if !autoPlay {
            // 如果不自动播放，立即暂停
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.streamPlayer.pause()
                self?.isPlaying = false
            }
        }
        
        // seek 到指定位置（切换音质时保留进度）
        if startTime > 0 {
            // 直接调用 seek，pending 模式会在播放循环启动后自动处理
            streamPlayer.seek(to: startTime)
            currentTime = startTime
        }
        
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: currentSong)
        
        // 预加载下一首（无缝切歌）
        if autoPlay {
            prepareNextTrackURL()
        }
    }


    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentSong?.name ?? ""
        info[MPMediaItemPropertyArtist] = currentSong?.artistName ?? ""
        info[MPMediaItemPropertyAlbumTitle] = currentSong?.album?.name ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlayingTime() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlayingArtwork(for song: Song?) {
        guard let coverUrl = song?.coverUrl else { return }
        
        Task.detached {
            do {
                let (data, _) = try await URLSession.shared.data(from: coverUrl)
                guard let image = UIImage(data: data) else { return }
                
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                
                await MainActor.run {
                    guard self.currentSong?.id == song?.id else { return }
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            } catch {
                AppLogger.warning("封面图下载失败: \(error)")
            }
        }
    }
    
    private func addToHistory(song: Song) {
        history.removeAll { $0.id == song.id }
        history.insert(song, at: 0)
        if history.count > AppConfig.Player.maxHistoryCount {
            history.removeLast()
        }
    }
    
    /// 上报听歌记录到网易云服务端（最近播放、累计听歌数等）
    private func scrobbleToCloud(song: Song) {
        guard isAppLoggedIn else { return }
        APIService.shared.scrobble(id: song.id, sourceid: 0, time: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.warning("听歌打卡失败: \(error.localizedDescription)")
                }
            }, receiveValue: { _ in
                AppLogger.info("听歌打卡成功: \(song.name)")
            })
            .store(in: &self.cancellables)
    }
    
    private var isAppLoggedIn: Bool {
        UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
    }
    
    // MARK: - Persistence
    
    struct PlayerState: Codable {
        let currentSong: Song?
        let userQueue: [Song]
        let mode: PlayMode
        let history: [Song]
        let playSource: PlaySource?
        // v2: 完整播放队列持久化
        let context: [Song]?
        let contextIndex: Int?
        let shuffledContext: [Song]?
    }
    
    /// 持久化时的最大 context 大小（防止序列化过大）
    private let maxPersistContextSize = 200
    
    private func saveState() {
        saveStateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 截断 context 以防过大
            let trimmedContext = Array(self.context.prefix(self.maxPersistContextSize))
            let trimmedShuffled = Array(self.shuffledContext.prefix(self.maxPersistContextSize))
            let safeIndex = min(self.contextIndex, trimmedContext.count - 1)
            
            let state = PlayerState(
                currentSong: self.currentSong,
                userQueue: self.userQueue,
                mode: self.mode,
                history: self.history,
                playSource: self.playSource,
                context: trimmedContext,
                contextIndex: safeIndex,
                shuffledContext: trimmedShuffled
            )
            OptimizedCacheManager.shared.setObject(state, forKey: AppConfig.StorageKeys.playerState)
        }
        
        saveStateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveStateDebounceInterval, execute: workItem)
    }
    
    func saveStateImmediately() {
        saveStateWorkItem?.cancel()
        let trimmedContext = Array(context.prefix(maxPersistContextSize))
        let trimmedShuffled = Array(shuffledContext.prefix(maxPersistContextSize))
        let safeIndex = min(contextIndex, trimmedContext.count - 1)
        
        let state = PlayerState(
            currentSong: currentSong,
            userQueue: userQueue,
            mode: mode,
            history: history,
            playSource: playSource,
            context: trimmedContext,
            contextIndex: safeIndex,
            shuffledContext: trimmedShuffled
        )
        OptimizedCacheManager.shared.setObject(state, forKey: AppConfig.StorageKeys.playerState)
    }
    
    private func restoreState() {
        if let state = OptimizedCacheManager.shared.getObject(forKey: AppConfig.StorageKeys.playerState, type: PlayerState.self) {
            self.userQueue = state.userQueue
            self.mode = state.mode
            self.history = state.history
            self.playSource = state.playSource ?? .normal
            
            if let song = state.currentSong {
                self.currentSong = song
                
                // 恢复完整播放队列（v2）
                if let savedContext = state.context, !savedContext.isEmpty {
                    self.context = savedContext
                    self.contextIndex = state.contextIndex ?? 0
                    if let savedShuffled = state.shuffledContext, !savedShuffled.isEmpty {
                        self.shuffledContext = savedShuffled
                    }
                } else {
                    // 兼容旧版：只有 currentSong，没有完整 context
                    self.context = [song]
                    self.contextIndex = 0
                }
            }
            return
        }
        
        // 兼容旧版本
        if let state = CacheManager.shared.getObject(forKey: "player_state_v4", type: PlayerState.self) {
            self.userQueue = state.userQueue
            self.mode = state.mode
            self.history = state.history
            self.playSource = state.playSource ?? .normal
            
            if let song = state.currentSong {
                self.currentSong = song
                self.context = [song]
                self.contextIndex = 0
            }
            saveStateImmediately()
            CacheManager.shared.removeObject(forKey: "player_state_v4")
            CacheManager.shared.removeObject(forKey: "player_state_v3")
            CacheManager.shared.removeObject(forKey: "player_state_v2")
            return
        }
    }
    
    func fetchHistory() {
        APIService.shared.fetchRecentSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.history = songs
            })
            .store(in: &cancellables)
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
                // 但不立即更新 UI，等当前歌曲进度到达末尾再切换
                AppLogger.info("无缝切歌：SDK 已准备好下一首，等待当前歌曲结束")
                pm.preparePendingNextTrack()
                pm.hasPendingTrackTransition = true
                // 重置进度（SDK 已经在播放下一首了，但 UI 还显示当前歌曲）
                // 不在这里重置 currentTime，让定时器继续更新直到歌曲结束
            }
        }
    }
}
