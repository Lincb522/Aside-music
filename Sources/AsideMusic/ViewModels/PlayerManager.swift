import Foundation
import AVFoundation
import Combine
import MediaPlayer
import SwiftAudioEx

@MainActor
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
    
    // MARK: - SwiftAudioEx Player
    let audioPlayer: AudioPlayer = {
        let p = AudioPlayer()
        p.automaticallyUpdateNowPlayingInfo = true
        p.remoteCommands = [
            .play, .pause, .next, .previous, .changePlaybackPosition
        ]
        return p
    }()
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var showFullScreenPlayer = false
    @Published var mode: PlayMode = .sequence
    @Published var isTabBarHidden: Bool = false
    @Published var isPlayingFM: Bool = false
    @Published var isCurrentSongUnblocked: Bool = false  // 当前歌曲是否来自第三方源
    @Published var currentSongSource: String? = nil     // 来源平台名称
    
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
    private var timeUpdateTimer: Timer?
    
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
        setupAudioPlayer()
        fetchHistory()
        restoreState()
    }
    
    deinit {
        timeUpdateTimer?.invalidate()
        cancellables.removeAll()
        saveStateWorkItem?.cancel()
    }
    
    private func setupAudioPlayer() {
        audioPlayer.event.stateChange.addListener(self) { [weak self] state in
            DispatchQueue.main.async { self?.handleStateChange(state: state) }
        }
        audioPlayer.event.playbackEnd.addListener(self) { [weak self] reason in
            DispatchQueue.main.async { self?.handlePlaybackEnd(reason: reason) }
        }
        audioPlayer.event.updateDuration.addListener(self) { [weak self] duration in
            DispatchQueue.main.async { self?.handleDurationUpdate(duration: duration) }
        }
        
        // 自定义远程命令处理
        audioPlayer.remoteCommandController.handlePlayCommand = { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        audioPlayer.remoteCommandController.handlePauseCommand = { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        audioPlayer.remoteCommandController.handleNextTrackCommand = { [weak self] _ in
            self?.next()
            return .success
        }
        audioPlayer.remoteCommandController.handlePreviousTrackCommand = { [weak self] _ in
            self?.previous()
            return .success
        }
        audioPlayer.remoteCommandController.handleChangePlaybackPositionCommand = { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
        
        // 定时更新播放时间
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentTime = self.audioPlayer.currentTime
            }
        }
    }
    
    // MARK: - SwiftAudioEx Event Handlers
    
    private func handleStateChange(state: AudioPlayerState) {
        switch state {
        case .playing:
            isPlaying = true
            isLoading = false
        case .paused, .stopped, .ended:
            isPlaying = false
            isLoading = false
        case .loading, .buffering:
            isLoading = true
        case .idle, .ready:
            isPlaying = false
            isLoading = false
        case .failed:
            isPlaying = false
            isLoading = false
        }
    }
    
    private func handlePlaybackEnd(reason: PlaybackEndedReason) {
        switch reason {
        case .playedUntilEnd:
            playerDidFinishPlaying()
        case .playerStopped, .cleared:
            isPlaying = false
        case .failed:
            isPlaying = false
            print("❌ 播放失败")
        case .skippedToNext, .skippedToPrevious, .jumpedToIndex:
            break
        }
    }
    
    private func handleDurationUpdate(duration: Double) {
        if duration.isFinite && !duration.isNaN && duration > 0 {
            self.duration = duration
        }
    }
    
    // MARK: - Core Playback API
    
    func play(song: Song, in context: [Song]) {
        self.context = context
        self.isPlayingFM = false
        
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
        self.isPlayingFM = true
        
        if let index = context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
        } else {
            self.contextIndex = 0
        }
        
        self.mode = .sequence
        loadAndPlay(song: song, autoPlay: autoPlay)
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
        self.isPlayingFM = false
        
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
        audioPlayer.togglePlaying()
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
        audioPlayer.stop()
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
        audioPlayer.seek(to: time)
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
            audioPlayer.play()
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
        
        let song = currentSong
        let item = DefaultAudioItem(
            audioUrl: url.absoluteString,
            artist: song?.artistName,
            title: song?.name,
            albumTitle: song?.album?.name,
            sourceType: .stream
        )
        
        try? audioPlayer.load(item: item, playWhenReady: autoPlay)
        
        if startTime > 0 {
            audioPlayer.seek(to: startTime)
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
    }
    
    private func saveState() {
        saveStateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
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
        if let state = CacheManager.shared.getObject(forKey: "player_state_v3", type: PlayerState.self) {
            self.userQueue = state.userQueue
            self.mode = state.mode
            self.history = state.history
            
            if let song = state.currentSong {
                self.currentSong = song
                self.context = [song]
                self.contextIndex = 0
            }
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
