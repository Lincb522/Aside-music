import Foundation
import AVFoundation
import Combine
import MediaPlayer

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
    
    // MARK: - AVPlayer
    private var avPlayer = AVPlayer()
    private var playerItemObservers = Set<AnyCancellable>()
    private var timeObserverToken: Any?
    private var didPlayToEndObserver: NSObjectProtocol?
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var showFullScreenPlayer = false
    @Published var mode: PlayMode = .sequence
    @Published var isTabBarHidden: Bool = false
    @Published var isCurrentSongUnblocked: Bool = false
    @Published var currentSongSource: String? = nil
    
    // MARK: - 播放源类型
    enum PlaySource: Codable, Equatable {
        case normal          // 普通歌曲播放
        case fm              // 私人 FM
        case podcast(radioId: Int)  // 播客/电台
    }
    
    @Published var playSource: PlaySource = .normal
    
    /// 向后兼容：是否正在播放 FM
    var isPlayingFM: Bool {
        get { playSource == .fm }
        set { playSource = newValue ? .fm : .normal }
    }
    
    /// 是否正在播放播客
    var isPlayingPodcast: Bool {
        if case .podcast = playSource { return true }
        return false
    }
    
    /// 当前播客电台 ID（如果正在播放播客）
    var currentRadioId: Int? {
        if case .podcast(let radioId) = playSource { return radioId }
        return nil
    }
    
    // MARK: - Settings
    @Published var soundQuality: SoundQuality = {
        if let rawValue = UserDefaults.standard.string(forKey: "aside_sound_quality"),
           let quality = SoundQuality(rawValue: rawValue) {
            return quality
        }
        return .exhigh
    }() {
        didSet {
            UserDefaults.standard.set(soundQuality.rawValue, forKey: "aside_sound_quality")
        }
    }
    
    // MARK: - Queue System
    @Published private(set) var context: [Song] = []
    @Published private(set) var contextIndex: Int = -1
    @Published private(set) var shuffledContext: [Song] = []
    @Published var userQueue: [Song] = []
    @Published var history: [Song] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var saveStateWorkItem: DispatchWorkItem?
    private let saveStateDebounceInterval: TimeInterval = 2.0
    private var consecutiveFailures: Int = 0
    private let maxConsecutiveFailures: Int = 3
    private var retryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 10.0
    
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
        setupPeriodicTimeObserver()
        setupPlayerObservers()
        fetchHistory()
        restoreState()
    }
    
    deinit {
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
        }
        if let observer = didPlayToEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
            print("[PlayerManager] AVAudioSession 配置失败: \(error)")
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
    
    private func setupPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let seconds = time.seconds
                if seconds.isFinite && !seconds.isNaN {
                    self.currentTime = seconds
                }
                self.updateNowPlayingTime()
            }
        }
    }
    
    private func setupPlayerObservers() {
        avPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .playing:
                    self.isPlaying = true
                    self.isLoading = false
                case .paused:
                    self.isPlaying = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        didPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let item = notification.object as? AVPlayerItem,
                  item == self.avPlayer.currentItem else { return }
            Task { @MainActor in
                self.playerDidFinishPlaying()
            }
        }
    }
    
    private func observePlayerItem(_ item: AVPlayerItem) {
        playerItemObservers.removeAll()
        
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    let dur = item.duration.seconds
                    if dur.isFinite && !dur.isNaN && dur > 0 {
                        self.duration = dur
                    }
                case .failed:
                    self.isPlaying = false
                    self.isLoading = false
                    print("❌ AVPlayerItem 加载失败: \(item.error?.localizedDescription ?? "未知错误")")
                default:
                    break
                }
            }
            .store(in: &playerItemObservers)
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
    
    /// 播客/电台模式播放
    func playPodcast(song: Song, in context: [Song], radioId: Int) {
        self.context = context
        self.playSource = .podcast(radioId: radioId)
        
        // 优先使用 context 中已注入播客封面的 song
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
            avPlayer.pause()
        } else {
            avPlayer.play()
        }
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
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        isPlaying = false
        currentSong = nil
        saveState()
    }
    
    func switchQuality(_ quality: SoundQuality) {
        guard soundQuality != quality else { return }
        
        if let current = currentSong {
            let time = currentTime
            let wasPlaying = isPlaying
            
            Task { @MainActor in
                let enableUnblock = SettingsManager.shared.unblockEnabled
                
                APIService.shared.fetchSongUrl(id: current.id, level: quality.rawValue, enableUnblock: enableUnblock)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("切换音质失败: \(error)")
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
                        self.currentSongSource = result.source
                        self.startPlayback(url: url, autoPlay: wasPlaying, startTime: time)
                    })
                    .store(in: &self.cancellables)
            }
        } else {
            soundQuality = quality
        }
    }
    
    // MARK: - Seek
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        avPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
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
    
    private func playerDidFinishPlaying() {
        switch mode {
        case .loopSingle:
            seek(to: 0)
            avPlayer.play()
        case .sequence, .shuffle:
            next()
        }
    }
    
    private func loadAndPlay(song: Song, autoPlay: Bool = true, startTime: Double = 0) {
        isLoading = true
        currentSong = song
        addToHistory(song: song)
        saveState()
        
        Task { @MainActor in
            let enableUnblock = SettingsManager.shared.unblockEnabled
            
            APIService.shared.fetchSongUrl(id: song.id, level: self.soundQuality.rawValue, enableUnblock: enableUnblock)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    if case .failure(let error) = completion {
                        print("Failed to get song url: \(error)")
                        self.isLoading = false
                        
                        let isUnavailable = error is APIService.PlaybackError && 
                            (error as! APIService.PlaybackError) == .unavailable
                        
                        self.consecutiveFailures += 1
                        
                        if self.consecutiveFailures >= self.maxConsecutiveFailures {
                            print("⚠️ 连续失败 \(self.consecutiveFailures) 次，停止自动播放下一首")
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
                            self.consecutiveFailures = 0
                            self.retryDelay = 1.0
                            return
                        }
                        
                        if autoPlay {
                            print("尝试播放下一首 (失败次数: \(self.consecutiveFailures)/\(self.maxConsecutiveFailures), 延迟: \(self.retryDelay)秒)")
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
                    self.currentSongSource = result.source
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
        isLoading = false
        
        // 切换音质时保留当前进度，仅新歌曲才重置
        if startTime <= 0 {
            self.currentTime = 0
            self.duration = 0
        }
        
        let playerItem = AVPlayerItem(url: url)
        observePlayerItem(playerItem)
        avPlayer.replaceCurrentItem(with: playerItem)
        
        if startTime > 0 {
            let cmTime = CMTime(seconds: startTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            avPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        if autoPlay {
            avPlayer.play()
        }
        
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: currentSong)
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
                    // 确保还是同一首歌
                    guard self.currentSong?.id == song?.id else { return }
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            } catch {
                print("[PlayerManager] 封面图下载失败: \(error)")
            }
        }
    }
    
    private func addToHistory(song: Song) {
        history.removeAll { $0.id == song.id }
        history.insert(song, at: 0)
        if history.count > 50 {
            history.removeLast()
        }
    }
    
    // MARK: - Persistence
    
    struct PlayerState: Codable {
        let currentSong: Song?
        let userQueue: [Song]
        let mode: PlayMode
        let history: [Song]
        let playSource: PlaySource?
    }
    
    private func saveState() {
        saveStateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let state = PlayerState(
                currentSong: self.currentSong,
                userQueue: self.userQueue,
                mode: self.mode,
                history: self.history,
                playSource: self.playSource
            )
            CacheManager.shared.setObject(state, forKey: "player_state_v4")
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
            history: history,
            playSource: playSource
        )
        CacheManager.shared.setObject(state, forKey: "player_state_v4")
    }
    
    private func restoreState() {
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
            return
        }
        
        // 兼容旧版本 v3
        if let state = CacheManager.shared.getObject(forKey: "player_state_v3", type: PlayerState.self) {
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
            return
        }
        
        if let oldState = CacheManager.shared.getObject(forKey: "player_state_v2", type: OldPlayerState.self) {
            self.userQueue = oldState.userQueue
            self.mode = oldState.mode
            self.history = oldState.history
            
            if let song = oldState.currentSong {
                self.currentSong = song
                self.context = [song]
                self.contextIndex = 0
            }
            saveStateImmediately()
        }
    }
    
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
}
