// PlayerManager+Persistence.swift
// Monologue
//
// 状态持久化：保存/恢复播放状态、历史记录、听歌打卡

import Foundation
import Combine

extension PlayerManager {
    
    // MARK: - Persistence
    
    struct PlayerState: Codable {
        let currentSong: Song?
        let userQueue: [Song]
        let mode: PlayMode
        let history: [Song]
        let podcastHistory: [Song]?
        let playSource: PlaySource?
        let queueExhaustionBehavior: QueueExhaustionBehavior?
        let context: [Song]?
        let contextIndex: Int?
        let shuffledContext: [Song]?
        let playbackBackStack: [Song]?
        let playbackForwardStack: [Song]?
        let currentTime: Double?
        let duration: Double?
        let wasPlaying: Bool?
        // 播客/音乐上下文隔离
        let savedMusicContext: [Song]?
        let savedMusicContextIndex: Int?
        let savedMusicShuffledContext: [Song]?
        let savedMusicMode: PlayMode?
        let savedMusicSong: Song?
        let savedPodcastContext: [Song]?
        let savedPodcastContextIndex: Int?
        let savedPodcastRadioId: Int?
        let savedPodcastSong: Song?
        // 快速续播：上次会话已解析的播放输入（http 地址或本地路径）
        let lastPlaybackInput: String?
        let lastPlaybackInputResolvedAt: Date?
        let lastPlaybackDecryptionKey: String?
    }
    
    private func buildPlayerState() -> PlayerState {
        let trimmedContext = Array(context.prefix(maxPersistContextSize))
        let trimmedShuffled = Array(shuffledContext.prefix(maxPersistContextSize))
        let trimmedBackStack = Array(playbackBackStack.suffix(maxBackStackSize))
        let trimmedForwardStack = Array(playbackForwardStack.suffix(maxBackStackSize))
        let safeIndex = max(0, min(contextIndex, trimmedContext.count - 1))
        
        return PlayerState(
            currentSong: currentSong,
            userQueue: [],
            mode: mode,
            history: history,
            podcastHistory: podcastHistory,
            playSource: playSource,
            queueExhaustionBehavior: queueExhaustionBehavior,
            context: trimmedContext,
            contextIndex: safeIndex,
            shuffledContext: trimmedShuffled,
            playbackBackStack: trimmedBackStack,
            playbackForwardStack: trimmedForwardStack,
            currentTime: currentSong == nil ? nil : currentTime,
            duration: currentSong == nil ? nil : duration,
            wasPlaying: currentSong == nil ? nil : isPlaying,
            savedMusicContext: savedMusicContext.isEmpty ? nil : Array(savedMusicContext.prefix(maxPersistContextSize)),
            savedMusicContextIndex: savedMusicContext.isEmpty ? nil : savedMusicContextIndex,
            savedMusicShuffledContext: savedMusicShuffledContext.isEmpty ? nil : Array(savedMusicShuffledContext.prefix(maxPersistContextSize)),
            savedMusicMode: savedMusicContext.isEmpty ? nil : savedMusicMode,
            savedMusicSong: savedMusicSong,
            savedPodcastContext: savedPodcastContext.isEmpty ? nil : Array(savedPodcastContext.prefix(maxPersistContextSize)),
            savedPodcastContextIndex: savedPodcastContext.isEmpty ? nil : savedPodcastContextIndex,
            savedPodcastRadioId: savedPodcastRadioId,
            savedPodcastSong: savedPodcastSong,
            lastPlaybackInput: currentSong == nil ? nil : currentPlayingURL,
            lastPlaybackInputResolvedAt: currentSong == nil ? nil : playbackURLResolvedAt,
            lastPlaybackDecryptionKey: currentSong == nil ? nil : currentPlayingDecryptionKey
        )
    }
    
    private func saveStateSnapshotToUserDefaults(_ state: PlayerState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: AppConfig.StorageKeys.playerStateSnapshot)
    }

    private func markPersistedPlaybackProgress(from state: PlayerState) {
        lastPersistedProgressSongID = state.currentSong?.id
        lastPersistedProgressTime = max(state.currentTime ?? 0, 0)
    }

    private func persistState(_ state: PlayerState) {
        saveStateSnapshotToUserDefaults(state)
        OptimizedCacheManager.shared.setObject(state, forKey: AppConfig.StorageKeys.playerState)
        markPersistedPlaybackProgress(from: state)
    }
    
    private func restoreStateSnapshotFromUserDefaults() -> PlayerState? {
        guard let data = UserDefaults.standard.data(forKey: AppConfig.StorageKeys.playerStateSnapshot) else {
            return nil
        }
        return try? JSONDecoder().decode(PlayerState.self, from: data)
    }
    
    private func applyRestoredState(_ state: PlayerState) {
        self.mode = state.mode
        self.history = state.history
        self.podcastHistory = state.podcastHistory ?? []
        self.playSource = state.playSource ?? .normal
        self.queueExhaustionBehavior = state.queueExhaustionBehavior ?? .loop
        self.playbackBackStack = state.playbackBackStack ?? []
        self.playbackForwardStack = state.playbackForwardStack ?? []
        // 恢复保存的上下文
        self.savedMusicContext = state.savedMusicContext ?? []
        self.savedMusicContextIndex = state.savedMusicContextIndex ?? 0
        self.savedMusicShuffledContext = state.savedMusicShuffledContext ?? []
        self.savedMusicMode = state.savedMusicMode ?? .sequence
        self.savedMusicSong = state.savedMusicSong
        self.savedPodcastContext = state.savedPodcastContext ?? []
        self.savedPodcastContextIndex = state.savedPodcastContextIndex ?? 0
        self.savedPodcastRadioId = state.savedPodcastRadioId
        self.savedPodcastSong = state.savedPodcastSong
        self.currentSong = state.currentSong

        if let savedContext = state.context, !savedContext.isEmpty {
            self.context = savedContext
            self.contextIndex = state.contextIndex ?? 0
            if let savedShuffled = state.shuffledContext, !savedShuffled.isEmpty {
                self.shuffledContext = savedShuffled
            } else if self.mode == .shuffle {
                self.generateShuffledContext()
            }
        } else {
            self.context = state.currentSong.map { [$0] } ?? []
            self.contextIndex = 0
        }

        guard let song = currentSong else { return }
        
        let restoredDuration = state.duration ?? song.dt.map { Double($0) / 1000 }
        let restoredTime = min(max(state.currentTime ?? 0, 0), max((restoredDuration ?? 0) - 0.5, 0))
        self.duration = restoredDuration ?? 0
        self.currentTime = restoredTime
        self.pendingRestoreTime = restoredTime
        self.shouldAutoResumeAfterRestore = state.wasPlaying ?? false
        self.needsPlaybackRestoration = true
        // 上次会话已解析的播放输入：小组件唤醒续播时若仍可用，跳过取址直接开播
        if let input = state.lastPlaybackInput, !input.isEmpty {
            self.restoredPlaybackAsset = (
                songId: song.id,
                input: input,
                resolvedAt: state.lastPlaybackInputResolvedAt,
                decryptionKey: state.lastPlaybackDecryptionKey
            )
        }
        
        // 恢复后主动同步歌词位置，避免恢复后歌词停在第一行
        fetchLyricsForSong(song)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            LyricViewModel.shared.updateCurrentTime(restoredTime)
        }
        markPersistedPlaybackProgress(from: state)
    }
    
    func saveState() {
        saveStateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let state = self.buildPlayerState()
            self.persistState(state)
        }
        
        saveStateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveStateDebounceInterval, execute: workItem)
    }
    
    func saveStateImmediately() {
        saveStateWorkItem?.cancel()
        let state = buildPlayerState()
        persistState(state)
    }

    func savePlaybackProgressIfNeeded(force: Bool = false) {
        guard let song = currentSong else { return }

        let safeTime = max(currentTime, 0)
        guard safeTime.isFinite, !safeTime.isNaN else { return }

        if force {
            saveStateImmediately()
            return
        }

        guard isPlaying, safeTime >= 1 else { return }

        let songChanged = lastPersistedProgressSongID != song.id
        let advancedEnough = abs(safeTime - lastPersistedProgressTime) >= playbackProgressPersistenceInterval
        guard songChanged || advancedEnough else { return }

        saveStateImmediately()
    }
    
    func restoreState() {
        if let snapshot = restoreStateSnapshotFromUserDefaults() {
            applyRestoredState(snapshot)
            return
        }
        
        if let state = OptimizedCacheManager.shared.getObject(forKey: AppConfig.StorageKeys.playerState, type: PlayerState.self) {
            applyRestoredState(state)
            return
        }
        
        // 兼容旧版本
        if let state = CacheManager.shared.getObject(forKey: "player_state_v4", type: PlayerState.self) {
            self.mode = state.mode
            self.history = state.history
            self.podcastHistory = state.podcastHistory ?? []
            self.playSource = state.playSource ?? .normal
            self.queueExhaustionBehavior = state.queueExhaustionBehavior ?? .loop
            self.playbackForwardStack = state.playbackForwardStack ?? []
            
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
    
    func addToHistory(song: Song) {
        if playSource.isPodcast {
            // Deduplicate by episode ID only
            podcastHistory.removeAll { $0.id == song.id }
            
            podcastHistory.insert(song, at: 0)
            if podcastHistory.count > AppConfig.Player.maxHistoryCount {
                podcastHistory.removeLast()
            }
            saveState()
            // 播客不进听歌统计：结算并停止跟踪上一首音乐，
            // 否则播客播放进度会误累计到上一条音乐日志里
            ListeningStatsRecorder.shared.finalizeSession()
            return
        }
        
        history.removeAll { $0.id == song.id }
        history.insert(song, at: 0)
        if history.count > AppConfig.Player.maxHistoryCount {
            history.removeLast()
        }
        // 同时写入播放日志（听歌统计数据源），并让统计记录器跟踪真实播放时长
        let record = HistoryRepository().addPlayHistory(song: song)
        ListeningStatsRecorder.shared.beginSession(record: record, song: song)
    }
    
    func clearRecentPlaybackStack() {
        playbackBackStack.removeAll()
        saveStateImmediately()
    }
    
    /// 「最近播放」清空：只清 UI 列表并把恢复游标挪到现在，
    /// 播放日志（听歌统计的数据源）原样保留。
    func clearPlaybackHistory() {
        history.removeAll()
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: "playHistory.recentClearedAt"
        )
        saveStateImmediately()
    }
    
    func clearPodcastHistory() {
        podcastHistory.removeAll()
        saveStateImmediately()
    }
    
    /// 上报听歌记录到ncm服务端（最近播放、累计听歌数等）
    func scrobbleToCloud(song: Song) {
        guard isAppLoggedIn else { return }
        var bag: AnyCancellable?
        bag = APIService.shared.scrobble(id: song.id, sourceid: 0, time: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
                bag?.cancel()
                bag = nil
            }, receiveValue: { _ in
                AppLogger.info("听歌打卡成功: \(song.name)")
            })
    }
    
    func fetchHistory() {
        // 先从本地 SwiftData 恢复历史（保证离线也有数据）。
        // 只取「上次清空最近播放」之后的记录 —— 清空不删日志，只挪游标。
        let clearedAtStamp = UserDefaults.standard.double(forKey: "playHistory.recentClearedAt")
        let cutoff = clearedAtStamp > 0 ? Date(timeIntervalSince1970: clearedAtStamp) : nil
        let localHistory = HistoryRepository().getPlayHistory(
            limit: AppConfig.Player.maxHistoryCount,
            after: cutoff
        )
        if !localHistory.isEmpty {
            // 将 SwiftData 的记录合并到内存历史中（内存中已有的保留，因为内存版本信息更完整）
            let existingIds = Set(self.history.map { $0.id })
            let newSongs = localHistory
                .map { $0.toSong() }
                .filter { !existingIds.contains($0.id) }
            self.history.append(contentsOf: newSongs)
            // 按时间排序（最近的在前）— 内存中的已经是最近播放的
            if self.history.count > AppConfig.Player.maxHistoryCount {
                self.history = Array(self.history.prefix(AppConfig.Player.maxHistoryCount))
            }
        }
        
        // 再从服务端拉取最近播放，合并到本地（不覆盖）
        APIService.shared.fetchRecentSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                guard let self = self else { return }
                // 将服务端的歌曲合并到历史中（本地已有的不重复添加）
                for song in songs {
                    if !self.history.contains(where: { $0.id == song.id }) {
                        self.history.append(song)
                    }
                }
                // 截断
                if self.history.count > AppConfig.Player.maxHistoryCount {
                    self.history = Array(self.history.prefix(AppConfig.Player.maxHistoryCount))
                }
            })
            .store(in: &cancellables)
    }
    
    func restorePlaybackSessionIfNeeded(forceAutoPlay: Bool? = nil) {
        guard needsPlaybackRestoration, let song = currentSong else { return }
        
        needsPlaybackRestoration = false
        let resumeTime = max(pendingRestoreTime ?? currentTime, 0)
        let shouldAutoPlay = forceAutoPlay ?? false
        pendingRestoreTime = nil
        shouldAutoResumeAfterRestore = false
        
        // 快速续播：上次会话的播放输入仍可用时装入一次性快速通道，
        // loadAndPlay 会跳过「取 URL」API 往返直接开播（小组件唤醒立即出声）
        if let asset = validatedRestoredPlaybackAsset(for: song) {
            preresolvedRestorationInput = (input: asset.input, decryptionKey: asset.decryptionKey)
        }
        restoredPlaybackAsset = nil
        
        loadAndPlay(song: song, autoPlay: shouldAutoPlay, startTime: resumeTime)
    }
    
    /// 校验上次会话的播放输入是否仍可直接使用：
    /// · 本地文件（下载 / 解密缓存 / 汽水缓存）→ 文件还在即可；
    /// · 网络地址 → 解析时间在新鲜期内（与点播地址缓存同一窗口）。
    private func validatedRestoredPlaybackAsset(
        for song: Song
    ) -> (input: String, decryptionKey: String?)? {
        guard let asset = restoredPlaybackAsset, asset.songId == song.id else { return nil }
        let input = asset.input
        
        if input.hasPrefix("http") {
            guard let resolvedAt = asset.resolvedAt,
                  Date().timeIntervalSince(resolvedAt) < PlaybackURLCache.freshTTL else {
                return nil
            }
            return (input, asset.decryptionKey)
        }
        
        guard FileManager.default.fileExists(atPath: input) else { return nil }
        return (input, asset.decryptionKey)
    }
}
