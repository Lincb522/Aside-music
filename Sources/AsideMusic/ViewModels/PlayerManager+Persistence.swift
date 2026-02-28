// PlayerManager+Persistence.swift
// AsideMusic
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
        let playSource: PlaySource?
        // v2: 完整播放队列持久化
        let context: [Song]?
        let contextIndex: Int?
        let shuffledContext: [Song]?
        // v3: 上一首回退栈
        let playbackBackStack: [Song]?
    }
    
    func saveState() {
        saveStateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 截断 context 以防过大
            let trimmedContext = Array(self.context.prefix(self.maxPersistContextSize))
            let trimmedShuffled = Array(self.shuffledContext.prefix(self.maxPersistContextSize))
            let trimmedBackStack = Array(self.playbackBackStack.suffix(self.maxBackStackSize))
            let safeIndex = max(0, min(self.contextIndex, trimmedContext.count - 1))
            
            let state = PlayerState(
                currentSong: self.currentSong,
                userQueue: [],
                mode: self.mode,
                history: self.history,
                playSource: self.playSource,
                context: trimmedContext,
                contextIndex: safeIndex,
                shuffledContext: trimmedShuffled,
                playbackBackStack: trimmedBackStack
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
        let trimmedBackStack = Array(playbackBackStack.suffix(maxBackStackSize))
        let safeIndex = max(0, min(contextIndex, trimmedContext.count - 1))
        
        let state = PlayerState(
            currentSong: currentSong,
            userQueue: [],
            mode: mode,
            history: history,
            playSource: playSource,
            context: trimmedContext,
            contextIndex: safeIndex,
            shuffledContext: trimmedShuffled,
            playbackBackStack: trimmedBackStack
        )
        OptimizedCacheManager.shared.setObject(state, forKey: AppConfig.StorageKeys.playerState)
    }
    
    func restoreState() {
        if let state = OptimizedCacheManager.shared.getObject(forKey: AppConfig.StorageKeys.playerState, type: PlayerState.self) {
            self.mode = state.mode
            self.history = state.history
            self.playSource = state.playSource ?? .normal
            self.playbackBackStack = state.playbackBackStack ?? []
            
            if let song = state.currentSong {
                self.currentSong = song
                
                // 恢复完整播放队列（v2）
                if let savedContext = state.context, !savedContext.isEmpty {
                    self.context = savedContext
                    self.contextIndex = state.contextIndex ?? 0
                    if let savedShuffled = state.shuffledContext, !savedShuffled.isEmpty {
                        self.shuffledContext = savedShuffled
                    } else if self.mode == .shuffle {
                        self.generateShuffledContext()
                    }
                } else {
                    self.context = [song]
                    self.contextIndex = 0
                }
            }
            return
        }
        
        // 兼容旧版本
        if let state = CacheManager.shared.getObject(forKey: "player_state_v4", type: PlayerState.self) {
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
    
    func addToHistory(song: Song) {
        history.removeAll { $0.id == song.id }
        history.insert(song, at: 0)
        if history.count > AppConfig.Player.maxHistoryCount {
            history.removeLast()
        }
        // 同时写入 SwiftData 持久化
        HistoryRepository().addPlayHistory(song: song)
    }
    
    /// 上报听歌记录到网易云服务端（最近播放、累计听歌数等）
    func scrobbleToCloud(song: Song) {
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
    
    func fetchHistory() {
        // 先从本地 SwiftData 恢复历史（保证离线也有数据）
        let localHistory = HistoryRepository().getPlayHistory(limit: AppConfig.Player.maxHistoryCount)
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
}
