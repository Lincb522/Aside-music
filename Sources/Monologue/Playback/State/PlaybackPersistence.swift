// 播放状态持久化：快照存取（防抖 + 立即）、播放进度落盘、冷启动恢复、
// 最近播放历史（音乐/播客）、听歌打卡（scrobble）。
// PlayerState 模型定义在 Playback/PlaybackModels.swift。
// 由 PlayerManager 强持有；入口通过 PlayerManager 上的同名 facade 暴露。

import Foundation
import Combine

@MainActor
final class PlaybackPersistence {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    // MARK: - 防抖与进度落盘状态

    private var saveStateWorkItem: DispatchWorkItem?
    private let saveStateDebounceInterval: TimeInterval = AppConfig.Player.saveStateDebounceInterval
    private let playbackProgressPersistenceInterval: TimeInterval = AppConfig.Player.playbackProgressPersistenceInterval
    private var lastPersistedProgressSongID: Int?
    private var lastPersistedProgressTime: Double = 0

    // MARK: - 快照构建

    private func persistedQueueWindow(
        _ songs: [Song],
        currentSong: Song?,
        fallbackIndex: Int
    ) -> (songs: [Song], currentIndex: Int) {
        guard !songs.isEmpty else { return ([], 0) }
        let anchor = currentSong.flatMap { current in
            songs.firstIndex(where: { PlayerManager.matchesPlaybackTarget($0, expected: current) })
        } ?? max(0, min(fallbackIndex, songs.count - 1))
        guard songs.count > player.maxPersistContextSize else {
            return (songs, anchor)
        }

        let halfWindow = player.maxPersistContextSize / 2
        let maximumStart = songs.count - player.maxPersistContextSize
        let start = max(0, min(anchor - halfWindow, maximumStart))
        let end = start + player.maxPersistContextSize
        return (Array(songs[start..<end]), anchor - start)
    }

    private func buildPlayerState() -> PlayerManager.PlayerState {
        let player = self.player
        let orderedWindow = persistedQueueWindow(
            player.context,
            currentSong: player.currentSong,
            fallbackIndex: player.contextIndex
        )
        let shuffledWindow = persistedQueueWindow(
            player.shuffledContext,
            currentSong: player.currentSong,
            fallbackIndex: player.contextIndex
        )
        let trimmedContext = orderedWindow.songs
        let trimmedShuffled = shuffledWindow.songs
        let savedMusicWindow = persistedQueueWindow(
            player.savedMusicContext,
            currentSong: player.savedMusicSong,
            fallbackIndex: player.savedMusicContextIndex
        )
        let savedMusicShuffleWindow = persistedQueueWindow(
            player.savedMusicShuffledContext,
            currentSong: player.savedMusicSong,
            fallbackIndex: player.savedMusicContextIndex
        )
        let savedPodcastWindow = persistedQueueWindow(
            player.savedPodcastContext,
            currentSong: player.savedPodcastSong,
            fallbackIndex: player.savedPodcastContextIndex
        )
        let trimmedBackStack = Array(player.playbackBackStack.suffix(player.maxBackStackSize))
        let trimmedForwardStack = Array(player.playbackForwardStack.suffix(player.maxBackStackSize))
        let safeIndex = player.mode == .shuffle
            ? shuffledWindow.currentIndex
            : orderedWindow.currentIndex

        return PlayerManager.PlayerState(
            currentSong: player.currentSong,
            mode: player.mode,
            history: player.history,
            podcastHistory: player.podcastHistory,
            playSource: player.playSource,
            queueExhaustionBehavior: player.queueExhaustionBehavior,
            context: trimmedContext,
            contextIndex: safeIndex,
            shuffledContext: trimmedShuffled,
            playbackBackStack: trimmedBackStack,
            playbackForwardStack: trimmedForwardStack,
            currentTime: player.currentSong == nil ? nil : player.currentTime,
            duration: player.currentSong == nil ? nil : player.duration,
            wasPlaying: player.currentSong == nil ? nil : player.isPlaying,
            savedMusicContext: savedMusicWindow.songs.isEmpty ? nil : savedMusicWindow.songs,
            savedMusicContextIndex: savedMusicWindow.songs.isEmpty
                ? nil
                : (player.savedMusicMode == .shuffle
                    ? savedMusicShuffleWindow.currentIndex
                    : savedMusicWindow.currentIndex),
            savedMusicShuffledContext: savedMusicShuffleWindow.songs.isEmpty
                ? nil
                : savedMusicShuffleWindow.songs,
            savedMusicMode: player.savedMusicContext.isEmpty ? nil : player.savedMusicMode,
            savedMusicSong: player.savedMusicSong,
            savedPodcastContext: savedPodcastWindow.songs.isEmpty ? nil : savedPodcastWindow.songs,
            savedPodcastContextIndex: savedPodcastWindow.songs.isEmpty
                ? nil
                : savedPodcastWindow.currentIndex,
            savedPodcastRadioId: player.savedPodcastRadioId,
            savedPodcastSong: player.savedPodcastSong,
            lastPlaybackInput: player.currentSong?.isAppleMusic == true
                ? nil
                : player.currentPlayingURL,
            lastPlaybackInputResolvedAt: player.currentSong?.isAppleMusic == true
                ? nil
                : player.playbackURLResolvedAt,
            lastPlaybackDecryptionKey: player.currentSong?.isAppleMusic == true
                ? nil
                : player.currentPlayingDecryptionKey
        )
    }

    private func saveStateSnapshotToUserDefaults(_ state: PlayerManager.PlayerState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: AppConfig.StorageKeys.playerStateSnapshot)
    }

    private func markPersistedPlaybackProgress(from state: PlayerManager.PlayerState) {
        lastPersistedProgressSongID = state.currentSong?.id
        lastPersistedProgressTime = max(state.currentTime ?? 0, 0)
    }

    private func persistState(_ state: PlayerManager.PlayerState) {
        saveStateSnapshotToUserDefaults(state)
        OptimizedCacheManager.shared.setObject(state, forKey: AppConfig.StorageKeys.playerState)
        markPersistedPlaybackProgress(from: state)
    }

    private func restoreStateSnapshotFromUserDefaults() -> PlayerManager.PlayerState? {
        guard let data = UserDefaults.standard.data(forKey: AppConfig.StorageKeys.playerStateSnapshot) else {
            return nil
        }
        return try? JSONDecoder().decode(PlayerManager.PlayerState.self, from: data)
    }

    // MARK: - 恢复

    private func applyRestoredState(_ state: PlayerManager.PlayerState) {
        let player = self.player
        player.mode = state.mode
        player.history = state.history
        player.podcastHistory = state.podcastHistory ?? []
        player.playSource = state.playSource ?? .normal
        player.queueExhaustionBehavior = state.queueExhaustionBehavior ?? .loop
        player.playbackBackStack = state.playbackBackStack ?? []
        player.playbackForwardStack = state.playbackForwardStack ?? []
        // 恢复保存的上下文
        player.savedMusicContext = state.savedMusicContext ?? []
        player.savedMusicContextIndex = state.savedMusicContextIndex ?? 0
        player.savedMusicShuffledContext = state.savedMusicShuffledContext ?? []
        player.savedMusicMode = state.savedMusicMode ?? .sequence
        player.savedMusicSong = state.savedMusicSong
        player.savedPodcastContext = state.savedPodcastContext ?? []
        player.savedPodcastContextIndex = state.savedPodcastContextIndex ?? 0
        player.savedPodcastRadioId = state.savedPodcastRadioId
        player.savedPodcastSong = state.savedPodcastSong
        if let savedMusicSong = player.savedMusicSong {
            let activeSavedMusic = player.savedMusicMode == .shuffle
                ? player.savedMusicShuffledContext
                : player.savedMusicContext
            if let index = activeSavedMusic.firstIndex(where: {
                PlayerManager.matchesPlaybackTarget($0, expected: savedMusicSong)
            }) {
                player.savedMusicContextIndex = index
            }
        }
        if let savedPodcastSong = player.savedPodcastSong,
           let index = player.savedPodcastContext.firstIndex(where: {
               PlayerManager.matchesPlaybackTarget($0, expected: savedPodcastSong)
           }) {
            player.savedPodcastContextIndex = index
        }
        player.currentSong = state.currentSong

        if let savedContext = state.context, !savedContext.isEmpty {
            player.context = savedContext
            player.contextIndex = state.contextIndex ?? 0
            if let savedShuffled = state.shuffledContext, !savedShuffled.isEmpty {
                player.shuffledContext = savedShuffled
            } else if player.mode == .shuffle {
                player.generateShuffledContext()
            }
        } else {
            player.context = state.currentSong.map { [$0] } ?? []
            player.contextIndex = 0
        }

        guard let song = player.currentSong else { return }

        // 旧版本可能持久化的是截断前的绝对索引；新快照也始终按歌曲身份
        // 重新定位，保证 currentSong、下一首和待播时长使用同一游标。
        if let restoredIndex = player.currentContextList.firstIndex(where: {
            PlayerManager.matchesPlaybackTarget($0, expected: song)
        }) {
            player.contextIndex = restoredIndex
        } else if player.mode == .shuffle {
            let insertIndex = min(max(player.contextIndex, 0), player.shuffledContext.count)
            player.shuffledContext.insert(song, at: insertIndex)
            player.contextIndex = insertIndex
            if !player.context.contains(where: { PlayerManager.matchesPlaybackTarget($0, expected: song) }) {
                player.context.append(song)
            }
        } else {
            let insertIndex = min(max(player.contextIndex, 0), player.context.count)
            player.context.insert(song, at: insertIndex)
            player.contextIndex = insertIndex
        }

        let distinctQueueSongCount = Set(
            player.currentContextList.map {
                PlayerManager.playbackIdentityKey(for: $0)
            }
        ).count
        if player.mode != .loopSingle, distinctQueueSongCount <= 1 {
            player.queueExhaustionBehavior = .stopAtEnd
        }

        let restoredDuration = state.duration ?? song.dt.map { Double($0) / 1000 }
        let restoredTime = min(max(state.currentTime ?? 0, 0), max((restoredDuration ?? 0) - 0.5, 0))
        player.duration = restoredDuration ?? 0
        player.currentTime = restoredTime
        player.pendingRestoreTime = restoredTime
        player.shouldAutoResumeAfterRestore = state.wasPlaying ?? false
        player.needsPlaybackRestoration = true
        // 上次会话已解析的播放输入：小组件唤醒续播时若仍可用，跳过取址直接开播
        if let input = state.lastPlaybackInput, !input.isEmpty {
            player.restoredPlaybackAsset = (
                songId: song.id,
                input: input,
                resolvedAt: state.lastPlaybackInputResolvedAt,
                decryptionKey: state.lastPlaybackDecryptionKey
            )
        }

        // 恢复后主动同步歌词位置，避免恢复后歌词停在第一行
        player.fetchLyricsForSong(song)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            LyricViewModel.shared.updateCurrentTime(restoredTime)
        }
        markPersistedPlaybackProgress(from: state)
    }

    // MARK: - 存取入口

    func saveState() {
        saveStateWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
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
        guard let song = player.currentSong else { return }

        let safeTime = max(player.currentTime, 0)
        guard safeTime.isFinite, !safeTime.isNaN else { return }

        if force {
            saveStateImmediately()
            return
        }

        guard player.isPlaying, safeTime >= 1 else { return }

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

        if let state = OptimizedCacheManager.shared.getObject(forKey: AppConfig.StorageKeys.playerState, type: PlayerManager.PlayerState.self) {
            applyRestoredState(state)
            return
        }

        // 兼容旧版本
        if let state = CacheManager.shared.getObject(forKey: "player_state_v4", type: PlayerManager.PlayerState.self) {
            let player = self.player
            player.mode = state.mode
            player.history = state.history
            player.podcastHistory = state.podcastHistory ?? []
            player.playSource = state.playSource ?? .normal
            player.queueExhaustionBehavior = state.queueExhaustionBehavior ?? .loop
            player.playbackForwardStack = state.playbackForwardStack ?? []

            if let song = state.currentSong {
                player.currentSong = song
                player.context = [song]
                player.contextIndex = 0
                if player.mode != .loopSingle {
                    player.queueExhaustionBehavior = .stopAtEnd
                }
            }
            saveStateImmediately()
            CacheManager.shared.removeObject(forKey: "player_state_v4")
            CacheManager.shared.removeObject(forKey: "player_state_v3")
            CacheManager.shared.removeObject(forKey: "player_state_v2")
            return
        }
    }

    // MARK: - 历史记录

    func addToHistory(song: Song) {
        let player = self.player
        if player.playSource.isPodcast {
            player.podcastHistory.removeAll { PlayerManager.matchesPlaybackTarget($0, expected: song) }

            player.podcastHistory.insert(song, at: 0)
            if player.podcastHistory.count > AppConfig.Player.maxHistoryCount {
                player.podcastHistory.removeLast()
            }
            saveState()
            // 播客不进听歌统计：结算并停止跟踪上一首音乐，
            // 否则播客播放进度会误累计到上一条音乐日志里
            ListeningStatsRecorder.shared.finalizeSession()
            return
        }

        player.history.removeAll { PlayerManager.matchesPlaybackTarget($0, expected: song) }
        player.history.insert(song, at: 0)
        if player.history.count > AppConfig.Player.maxHistoryCount {
            player.history.removeLast()
        }
        // 同时写入播放日志（听歌统计数据源），并让统计记录器跟踪真实播放时长
        let record = HistoryRepository().addPlayHistory(song: song)
        ListeningStatsRecorder.shared.beginSession(record: record, song: song)
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
    }

    func clearRecentPlaybackStack() {
        player.playbackBackStack.removeAll()
        saveStateImmediately()
    }

    /// 「最近播放」清空：只清 UI 列表并把恢复游标挪到现在，
    /// 播放日志（听歌统计的数据源）原样保留。
    func clearPlaybackHistory() {
        player.history.removeAll()
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: "playHistory.recentClearedAt"
        )
        saveStateImmediately()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
    }

    func clearPodcastHistory() {
        player.podcastHistory.removeAll()
        saveStateImmediately()
    }

    /// 上报听歌记录到ncm服务端（最近播放、累计听歌数等）
    func scrobbleToCloud(song: Song) {
        guard player.isAppLoggedIn else { return }
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
        let player = self.player
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
            let existingIds = Set(player.history.map { $0.id })
            let newSongs = localHistory
                .map { $0.toSong() }
                .filter { !existingIds.contains($0.id) }
            player.history.append(contentsOf: newSongs)
            // 按时间排序（最近的在前）— 内存中的已经是最近播放的
            if player.history.count > AppConfig.Player.maxHistoryCount {
                player.history = Array(player.history.prefix(AppConfig.Player.maxHistoryCount))
            }
        }

        // 再从服务端拉取最近播放，合并到本地（不覆盖）
        APIService.shared.fetchRecentSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                guard self != nil else { return }
                // Combine 的 receive(on:) 只保证队列，不等同于 Swift
                // Concurrency 的 MainActor；显式切回主 actor 再修改 @Published。
                Task { @MainActor [weak self] in
                    guard let player = self?.player else { return }
                    // 将服务端的歌曲合并到历史中（本地已有的不重复添加）
                    for song in songs {
                        if !player.history.contains(where: {
                            PlayerManager.matchesPlaybackTarget($0, expected: song)
                        }) {
                            player.history.append(song)
                        }
                    }
                    // 截断
                    if player.history.count > AppConfig.Player.maxHistoryCount {
                        player.history = Array(player.history.prefix(AppConfig.Player.maxHistoryCount))
                    }
                }
            })
            .store(in: &player.cancellables)
    }

    // MARK: - 冷启动播放会话恢复

    func restorePlaybackSessionIfNeeded(forceAutoPlay: Bool? = nil) {
        let player = self.player
        guard player.needsPlaybackRestoration, let song = player.currentSong else { return }

        player.needsPlaybackRestoration = false
        let resumeTime = max(player.pendingRestoreTime ?? player.currentTime, 0)
        let shouldAutoPlay = forceAutoPlay ?? false
        player.pendingRestoreTime = nil
        player.shouldAutoResumeAfterRestore = false

        // 快速续播：上次会话的播放输入仍可用时装入一次性快速通道，
        // loadAndPlay 会跳过「取 URL」API 往返直接开播（小组件唤醒立即出声）
        if let asset = validatedRestoredPlaybackAsset(for: song) {
            player.preresolvedRestorationInput = (input: asset.input, decryptionKey: asset.decryptionKey)
        }
        player.restoredPlaybackAsset = nil

        player.loadAndPlay(
            song: song,
            autoPlay: shouldAutoPlay,
            startTime: resumeTime,
            fadeInDuration: shouldAutoPlay ? 0.95 : nil,
            fadeInReason: "cold-start restore"
        )
    }

    /// 校验上次会话的播放输入是否仍可直接使用：
    /// · 本地文件（下载 / 解密缓存 / 汽水缓存）→ 文件还在即可；
    /// · 网络地址 → 解析时间在新鲜期内（与点播地址缓存同一窗口）。
    private func validatedRestoredPlaybackAsset(
        for song: Song
    ) -> (input: String, decryptionKey: String?)? {
        guard let asset = player.restoredPlaybackAsset, asset.songId == song.id else { return nil }
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

    /// deinit 清理
    func cancelPendingWork() {
        saveStateWorkItem?.cancel()
        saveStateWorkItem = nil
    }
}

// MARK: - PlayerManager facade（外部与引擎扩展调用点保持不变）

extension PlayerManager {

    func saveState() {
        persistence.saveState()
    }

    func saveStateImmediately() {
        persistence.saveStateImmediately()
    }

    func savePlaybackProgressIfNeeded(force: Bool = false) {
        persistence.savePlaybackProgressIfNeeded(force: force)
    }

    func restoreState() {
        persistence.restoreState()
    }

    func addToHistory(song: Song) {
        persistence.addToHistory(song: song)
    }

    func clearRecentPlaybackStack() {
        persistence.clearRecentPlaybackStack()
    }

    func clearPlaybackHistory() {
        persistence.clearPlaybackHistory()
    }

    func clearPodcastHistory() {
        persistence.clearPodcastHistory()
    }

    func scrobbleToCloud(song: Song) {
        persistence.scrobbleToCloud(song: song)
    }

    func fetchHistory() {
        persistence.fetchHistory()
    }

    func restorePlaybackSessionIfNeeded(forceAutoPlay: Bool? = nil) {
        persistence.restorePlaybackSessionIfNeeded(forceAutoPlay: forceAutoPlay)
    }
}
