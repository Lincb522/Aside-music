// PlayerManager+PlaybackAPI.swift
// AsideMusic
//
// 核心播放 API：play, playFM, playPodcast, playSingle, 队列管理等

import Foundation

extension PlayerManager {
    
    // MARK: - Core Playback API
    
    func play(song: Song, in context: [Song]) {
        // 如果点击的是当前正在播放的歌，切换播放/暂停而不是重播
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        // 替换为新的播放列表
        self.context = context
        self.playSource = .normal
        
        if let index = self.context.firstIndex(where: { $0.id == song.id }) {
            self.contextIndex = index
        } else {
            // 歌曲不在列表中，插入到开头
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
            // 从 userQueue 中移除
            userQueue.remove(at: index)
        } else {
            // 从 context 后续列表中移除
            // upcomingSongs 的 context 部分已经过滤掉了 userQueue 中的歌
            // 需要找到实际对应的歌曲再从 context 中删除
            let queueIds = Set(userQueue.map { $0.id })
            let contextRemaining = Array(currentContextList.dropFirst(contextIndex + 1))
                .filter { !queueIds.contains($0.id) }
            let remainingIndex = index - userQueueCount
            
            guard remainingIndex >= 0 && remainingIndex < contextRemaining.count else { return }
            let songToRemove = contextRemaining[remainingIndex]
            context.removeAll { $0.id == songToRemove.id }
            if mode == .shuffle {
                shuffledContext.removeAll { $0.id == songToRemove.id }
            }
        }
        saveState()
    }
    
    func playFromQueue(song: Song) {
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        // 优先从 userQueue 中取
        if let queueIndex = userQueue.firstIndex(where: { $0.id == song.id }) {
            userQueue.remove(at: queueIndex)
        }
        
        // 在当前播放列表中找到这首歌
        if let contextListIndex = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = contextListIndex
            loadAndPlay(song: song)
            return
        }
        
        // 歌曲不在当前列表中（比如从历史记录播放），插入到当前位置之后
        let insertIndex = min(contextIndex + 1, context.count)
        context.insert(song, at: insertIndex)
        if mode == .shuffle {
            let shuffleInsert = min(contextIndex + 1, shuffledContext.count)
            shuffledContext.insert(song, at: shuffleInsert)
        }
        contextIndex = insertIndex
        loadAndPlay(song: song)
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
}
