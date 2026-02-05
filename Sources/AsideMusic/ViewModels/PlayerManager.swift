import Foundation
import AVFoundation
import Combine
import MediaPlayer

class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    // MARK: - Playback Modes
    enum PlayMode: String, Codable {
        case sequence   // 顺序播放 (播完继续下一首)
        case loopSingle // 单曲循环
        case shuffle    // 随机播放
        
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
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var showFullScreenPlayer = false
    @Published var mode: PlayMode = .sequence
    @Published var isTabBarHidden: Bool = false // Controls visibility of custom tab bar
    @Published var isPlayingFM: Bool = false    // Tracks if current context is Personal FM
    
    // MARK: - Settings
    @Published var soundQuality: SoundQuality = {
        if let rawValue = UserDefaults.standard.string(forKey: "aside_sound_quality"),
           let quality = SoundQuality(rawValue: rawValue) {
            return quality
        }
        return .exhigh // Default
    }() {
        didSet {
            UserDefaults.standard.set(soundQuality.rawValue, forKey: "aside_sound_quality")
        }
    }
    
    // MARK: - Queue System (NEW: Context + UserQueue)
    
    /// 播放上下文 - 当前播放的歌单/专辑列表 (用于自动播放下一首)
    @Published private(set) var context: [Song] = []
    @Published private(set) var contextIndex: Int = -1
    @Published private(set) var shuffledContext: [Song] = [] // 随机模式下的上下文
    
    /// 用户队列 - 用户主动添加的 "下一首播放" 歌曲
    @Published var userQueue: [Song] = []
    
    /// 播放历史
    @Published var history: [Song] = []
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var currentArtwork: MPMediaItemArtwork?
    
    private var saveStateWorkItem: DispatchWorkItem?
    private let saveStateDebounceInterval: TimeInterval = 2.0
    
    // 网络错误重试计数器和指数退避
    private var consecutiveFailures: Int = 0
    private let maxConsecutiveFailures: Int = 3
    private var retryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 10.0
    
    // 用于追踪 playerItem 状态订阅
    private var playerItemStatusCancellable: AnyCancellable?
    
    // MARK: - Computed Properties
    
    /// 当前上下文列表 (根据播放模式返回原始或随机列表)
    var currentContextList: [Song] {
        return mode == .shuffle ? shuffledContext : context
    }
    
    /// 当前在上下文中的索引
    var currentIndexInContext: Int {
        return contextIndex
    }
    
    /// 接下来的歌曲列表 (用于 UI 显示)
    /// 包含: 用户插队歌曲 + 当前上下文后续歌曲
    var upcomingSongs: [Song] {
        let contextRemaining = currentContextList.dropFirst(contextIndex + 1)
        return userQueue + contextRemaining
    }
    
    // MARK: - Init
    
    init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        fetchHistory()
        restoreState()
    }
    
    deinit {
        // 清理播放器资源
        cleanupPlayer()
        
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
        
        // 清理 Combine 订阅
        cancellables.removeAll()
        
        // 取消待执行的保存任务
        saveStateWorkItem?.cancel()
        saveStateWorkItem = nil
    }
    
    // MARK: - Core Playback API
    
    /// 在指定上下文中播放歌曲 (点击歌单中的某首歌)
    /// - Parameters:
    ///   - song: 要播放的歌曲
    ///   - context: 歌曲所在的上下文列表 (歌单/专辑)
    func play(song: Song, in context: [Song]) {
        // 设置上下文
        self.context = context
        self.isPlayingFM = false
        
        // 找到歌曲在上下文中的位置
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
        } else {
            // 歌曲不在上下文中，添加到开头
            self.context.insert(song, at: 0)
            self.contextIndex = 0
        }
        
        // 如果是随机模式，生成随机上下文
        if mode == .shuffle {
            generateShuffledContext()
        }
        
        loadAndPlay(song: song)
    }
    
    /// 私人 FM 专用的播放方法
    func playFM(song: Song, in context: [Song], autoPlay: Bool = true) {
        self.context = context
        self.isPlayingFM = true
        
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
        } else {
            self.contextIndex = 0
        }
        
        // FM 通常不适用随机模式，或者其本身就是随机的，这里重置为顺序
        self.mode = .sequence
        
        loadAndPlay(song: song, autoPlay: autoPlay)
    }
    
    /// 追加上下文 (用于 FM 或 歌单分页加载)
    func appendContext(songs: [Song]) {
        // 过滤掉已经存在的歌曲避免死循环或重复
        let newSongs = songs.filter { newSong in !self.context.contains(where: { $0.id == newSong.id }) }
        guard !newSongs.isEmpty else { return }
        
        self.context.append(contentsOf: newSongs)
        if mode == .shuffle {
            self.shuffledContext.append(contentsOf: newSongs.shuffled())
        }
        saveState()
    }
    
    /// 播放单曲 (不改变上下文)
    func playSingle(song: Song) {
        // 如果是同一首歌，toggle play/pause
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        // 单曲播放，上下文只有这一首
        self.context = [song]
        self.contextIndex = 0
        self.shuffledContext = [song]
        self.isPlayingFM = false
        
        loadAndPlay(song: song)
    }
    
    /// 添加到用户队列 (下一首播放)
    func playNext(song: Song) {
        // 避免重复
        userQueue.removeAll { $0.id == song.id }
        userQueue.insert(song, at: 0)
        saveState()
    }
    
    /// 添加到用户队列末尾
    func addToQueue(song: Song) {
        // 避免重复
        if !userQueue.contains(where: { $0.id == song.id }) {
            userQueue.append(song)
            saveState()
        }
    }
    
    /// 从用户队列移除 (仅限 userQueue)
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < userQueue.count else { return }
        userQueue.remove(at: index)
        saveState()
    }
    
    /// 从 upcomingSongs 列表中移除 (处理 userQueue + contextRemaining 的混合索引)
    func removeFromUpcoming(at index: Int) {
        let userQueueCount = userQueue.count
        
        if index < userQueueCount {
            // 在 userQueue 范围内
            userQueue.remove(at: index)
        } else {
            // 在 contextRemaining 范围内，需要从 context 中移除
            let contextListIndex = contextIndex + 1 + (index - userQueueCount)
            let list = currentContextList
            
            if contextListIndex >= 0 && contextListIndex < list.count {
                let songToRemove = list[contextListIndex]
                
                // 从原始 context 中移除
                context.removeAll { $0.id == songToRemove.id }
                
                // 如果是随机模式，也从 shuffledContext 中移除
                if mode == .shuffle {
                    shuffledContext.removeAll { $0.id == songToRemove.id }
                }
            }
        }
        saveState()
    }
    
    /// 从队列中播放歌曲 (不破坏上下文)
    func playFromQueue(song: Song) {
        // 如果是同一首歌，toggle play/pause
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        // 检查是否在 userQueue 中
        if let queueIndex = userQueue.firstIndex(where: { $0.id == song.id }) {
            // 从 userQueue 中移除并播放
            userQueue.remove(at: queueIndex)
            
            // 尝试在 context 中找到位置
            if let contextListIndex = currentContextList.firstIndex(where: { $0.id == song.id }) {
                contextIndex = contextListIndex
            }
            // 如果不在 context 中，不更新 contextIndex
            
            loadAndPlay(song: song)
            return
        }
        
        // 检查是否在当前上下文中
        if let contextListIndex = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = contextListIndex
            loadAndPlay(song: song)
            return
        }
        
        // 都找不到，fallback 到 playSingle (极端情况)
        playSingle(song: song)
    }
    
    /// 检查歌曲是否在用户队列中 (用于 UI 判断是否显示删除按钮)
    func isInUserQueue(song: Song) -> Bool {
        return userQueue.contains(where: { $0.id == song.id })
    }
    
    /// 获取歌曲在 upcomingSongs 中是否属于 userQueue 部分
    func isUpcomingIndexInUserQueue(at index: Int) -> Bool {
        return index < userQueue.count
    }
    
    /// 清空用户队列
    func clearUserQueue() {
        userQueue.removeAll()
        saveState()
    }
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        setupNowPlayingInfo()
    }
    
    func next() {
        // 用户主动切歌时重置失败计数器和重试延迟
        consecutiveFailures = 0
        retryDelay = 1.0
        
        // 优先级: 用户队列 > 上下文
        if let nextSong = userQueue.first {
            userQueue.removeFirst()
            
            // 更新上下文索引 (如果在上下文中找到这首歌)
            if let index = currentContextList.firstIndex(where: { $0.id == nextSong.id }) {
                contextIndex = index
            }
            
            loadAndPlay(song: nextSong)
            return
        }
        
        // 从上下文播放下一首
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count {
            nextIndex = 0 // 循环到开头
        }
        
        contextIndex = nextIndex
        loadAndPlay(song: list[nextIndex])
    }
    
    func previous() {
        // 用户主动切歌时重置失败计数器和重试延迟
        consecutiveFailures = 0
        retryDelay = 1.0
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        
        var prevIndex = contextIndex - 1
        if prevIndex < 0 {
            prevIndex = list.count - 1 // 循环到末尾
        }
        
        contextIndex = prevIndex
        loadAndPlay(song: list[prevIndex])
    }
    
    func switchMode() {
        mode = mode.next
        
        if mode == .shuffle {
            generateShuffledContext()
        } else {
            // 恢复原始上下文索引
            if let current = currentSong {
                contextIndex = context.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
        
        saveState()
    }
    
    func stopAndClear() {
        player?.pause()
        isPlaying = false
        currentSong = nil // This will trigger UnifiedFloatingBar to hide mini player
        setupNowPlayingInfo()
        saveState()
    }
    
    func switchQuality(_ quality: SoundQuality) {
        guard soundQuality != quality else { return }
        
        let previousQuality = soundQuality
        
        // 如果当前有歌曲在播放，先获取新音质的 URL
        if let current = currentSong {
            let time = currentTime
            let wasPlaying = isPlaying
            
            // 在主线程获取设置值
            Task { @MainActor in
                let enableUnblock = SettingsManager.shared.unblockEnabled
                
                // 先获取新 URL，成功后再切换
                APIService.shared.fetchSongUrl(id: current.id, level: quality.rawValue, enableUnblock: enableUnblock)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            print("切换音质失败: \(error)")
                            // 保持原音质不变
                            AlertManager.shared.show(
                                title: "切换失败",
                                message: "无法获取该音质的音频，请稍后重试",
                                primaryButtonTitle: "确定",
                                primaryAction: {}
                            )
                        }
                    }, receiveValue: { [weak self] urlString in
                        guard let self = self, let url = URL(string: urlString) else { return }
                        // 成功获取新 URL，更新音质设置并播放
                        self.soundQuality = quality
                        self.startPlayback(url: url, autoPlay: wasPlaying, startTime: time)
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            // 没有播放中的歌曲，直接更新设置
            soundQuality = quality
        }
    }
    
    // MARK: - Seek
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime) { [weak self] _ in
            self?.updateNowPlayingInfoTime()
        }
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
        
        // 随机排列，但确保当前歌曲在第一位
        var shuffled = context.shuffled()
        if let index = shuffled.firstIndex(where: { $0.id == current.id }) {
            shuffled.remove(at: index)
            shuffled.insert(current, at: 0)
        }
        shuffledContext = shuffled
        contextIndex = 0
    }
    
    @objc private func playerDidFinishPlaying() {
        switch mode {
        case .loopSingle:
            // 单曲循环
            player?.seek(to: .zero)
            player?.play()
        case .sequence, .shuffle:
            // 顺序/随机播放下一首
            next()
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            if isPlaying {
                player?.pause()
                isPlaying = false
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    player?.play()
                    isPlaying = true
                }
            }
        @unknown default:
            break
        }
    }
    
    private func loadAndPlay(song: Song, autoPlay: Bool = true, startTime: Double = 0) {
        isLoading = true
        currentSong = song
        currentArtwork = nil
        loadArtwork(for: song)
        addToHistory(song: song)
        saveState()
        
        // 在主线程获取设置值
        Task { @MainActor in
            let enableUnblock = SettingsManager.shared.unblockEnabled
            
            APIService.shared.fetchSongUrl(id: song.id, level: self.soundQuality.rawValue, enableUnblock: enableUnblock)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    if case .failure(let error) = completion {
                        print("Failed to get song url: \(error)")
                        self.isLoading = false
                        
                        // 判断错误类型
                        let isUnavailable = error is APIService.PlaybackError && 
                            (error as! APIService.PlaybackError) == .unavailable
                        
                        // 增加失败计数
                        self.consecutiveFailures += 1
                        
                        // 检查是否超过最大失败次数
                        if self.consecutiveFailures >= self.maxConsecutiveFailures {
                            print("⚠️ 连续失败 \(self.consecutiveFailures) 次，停止自动播放下一首")
                            // 根据错误类型显示不同提示
                            if isUnavailable {
                                AlertManager.shared.show(
                                    title: "无法播放",
                                    message: "连续多首歌曲暂无版权，可在设置中开启「解灰」功能",
                                    primaryButtonTitle: "确定",
                                    primaryAction: {}
                                )
                            } else {
                                AlertManager.shared.show(
                                    title: "播放失败",
                                    message: "连续多首歌曲无法播放，请检查网络连接",
                                    primaryButtonTitle: "确定",
                                    primaryAction: {}
                                )
                            }
                            // 重置计数器和延迟
                            self.consecutiveFailures = 0
                            self.retryDelay = 1.0
                            return
                        }
                        
                        // 如果是自动播放且未超过限制，使用指数退避尝试下一首
                        if autoPlay {
                            print("尝试播放下一首 (失败次数: \(self.consecutiveFailures)/\(self.maxConsecutiveFailures), 延迟: \(self.retryDelay)秒)")
                            let currentDelay = self.retryDelay
                            // 指数退避：每次失败后延迟翻倍，最大不超过 maxRetryDelay
                            self.retryDelay = min(self.retryDelay * 2, self.maxRetryDelay)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) { [weak self] in
                            self?.autoNext()
                        }
                    }
                }
            }, receiveValue: { [weak self] urlString in
                guard let self = self, let url = URL(string: urlString) else { return }
                
                // 成功获取 URL，重置失败计数器和重试延迟
                self.consecutiveFailures = 0
                self.retryDelay = 1.0
                self.startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
            })
            .store(in: &self.cancellables)
        }
    }
    
    /// 自动播放下一首（不重置失败计数器）
    private func autoNext() {
        // 优先级: 用户队列 > 上下文
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
        // 清理旧的播放器资源
        cleanupPlayer()
        
        let playerItem = AVPlayerItem(url: url)
        
        // 添加 EQ 处理 (iOS 17+ 可用 assumeIsolated)
        let eqEnabled = MainActor.assumeIsolated { AudioEQManager.shared.isEnabled }
        if eqEnabled {
            AudioEQManager.shared.attachEQ(to: playerItem)
        }
        
        // 使用独立的 cancellable 追踪 playerItem 状态
        playerItemStatusCancellable = playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    DispatchQueue.main.async {
                        self?.setupNowPlayingInfo()
                    }
                }
            }
        
        player = AVPlayer(playerItem: playerItem)
        
        if startTime > 0 {
            player?.seek(to: CMTime(seconds: startTime, preferredTimescale: 1000))
        }
        
        if autoPlay {
            player?.play()
            isPlaying = true
        } else {
            player?.pause()
            isPlaying = false
        }
        isLoading = false
        
        // High frequency update for smooth UI (Lyrics/Progress)
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            // 安全地获取 duration
            guard let item = self.player?.currentItem else { return }
            let dur = item.duration.seconds
            if dur.isFinite && !dur.isNaN && self.duration != dur {
                self.duration = dur
                self.setupNowPlayingInfo()
            }
            self.updateNowPlayingInfoTime()
        }
        
        setupNowPlayingInfo()
    }
    
    /// 清理播放器资源，防止内存泄漏
    private func cleanupPlayer() {
        // 取消 playerItem 状态订阅
        playerItemStatusCancellable?.cancel()
        playerItemStatusCancellable = nil
        
        // 移除时间观察者
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        
        // 停止并清理播放器
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
    
    private func addToHistory(song: Song) {
        history.removeAll { $0.id == song.id }
        history.insert(song, at: 0)
        if history.count > 50 {
            history.removeLast()
        }
    }
    
    // MARK: - Persistence
    
    /// 持久化状态 - 不包含 context（临时上下文不保存）
    struct PlayerState: Codable {
        let currentSong: Song?
        let userQueue: [Song]  // 用户手动添加的播放列表
        let mode: PlayMode
        let history: [Song]
    }
    
    private func saveState() {
        saveStateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 只保存用户播放列表，不保存临时上下文
            let state = PlayerState(
                currentSong: self.currentSong,
                userQueue: self.userQueue,
                mode: self.mode,
                history: self.history
            )
            CacheManager.shared.setObject(state, forKey: "player_state_v3")
        }
        
        saveStateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveStateDebounceInterval, execute: workItem)
    }
    
    func saveStateImmediately() {
        saveStateWorkItem?.cancel()
        let state = PlayerState(
            currentSong: currentSong,
            userQueue: userQueue,
            mode: mode,
            history: history
        )
        CacheManager.shared.setObject(state, forKey: "player_state_v3")
    }
    
    private func restoreState() {
        // 尝试新版本状态
        if let state = CacheManager.shared.getObject(forKey: "player_state_v3", type: PlayerState.self) {
            self.userQueue = state.userQueue
            self.mode = state.mode
            self.history = state.history
            
            // 只恢复当前歌曲，不恢复整个上下文
            // 上下文在用户点击歌单时重新设置
            if let song = state.currentSong {
                self.currentSong = song
                // 如果有当前歌曲，将其作为最小上下文
                self.context = [song]
                self.contextIndex = 0
            }
            return
        }
        
        // 兼容旧版本状态 (v2)，迁移到新版本
        if let oldState = CacheManager.shared.getObject(forKey: "player_state_v2", type: OldPlayerState.self) {
            self.userQueue = oldState.userQueue
            self.mode = oldState.mode
            self.history = oldState.history
            
            if let song = oldState.currentSong {
                self.currentSong = song
                self.context = [song]
                self.contextIndex = 0
            }
            // 迁移后保存新版本
            saveStateImmediately()
        }
    }
    
    /// 旧版本状态结构（用于迁移）
    private struct OldPlayerState: Codable {
        let currentSong: Song?
        let context: [Song]
        let contextIndex: Int
        let userQueue: [Song]
        let mode: PlayMode
        let history: [Song]
    }
    
    func fetchHistory() {
        APIService.shared.fetchRecentSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.history = songs
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Audio Session
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
    }
    
    // MARK: - Remote Command Center
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
    }
    
    // MARK: - Now Playing Info
    
    private func loadArtwork(for song: Song) {
        guard let url = song.coverUrl else { return }
        
        if let cachedData = CacheManager.shared.getImageData(forKey: url.absoluteString),
           let image = UIImage(data: cachedData) {
            self.currentArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self.updateNowPlayingArtwork()
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.currentArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    self?.updateNowPlayingArtwork()
                }
            }
        }.resume()
    }
    
    private func updateNowPlayingArtwork() {
        guard let artwork = currentArtwork else { return }
        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        currentInfo[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
    }
    
    private func setupNowPlayingInfo() {
        guard let song = currentSong else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artistName
        
        if let dur = player?.currentItem?.duration.seconds, !dur.isNaN {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = dur
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let artwork = currentArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfoTime() {
        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        currentInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
    }
}