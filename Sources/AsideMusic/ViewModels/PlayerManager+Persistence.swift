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
    }
    
    func saveState() {
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
    
    func restoreState() {
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
    
    func addToHistory(song: Song) {
        history.removeAll { $0.id == song.id }
        history.insert(song, at: 0)
        if history.count > AppConfig.Player.maxHistoryCount {
            history.removeLast()
        }
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
        APIService.shared.fetchRecentSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.history = songs
            })
            .store(in: &cancellables)
    }
}
