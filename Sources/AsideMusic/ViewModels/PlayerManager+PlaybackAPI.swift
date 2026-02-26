// PlayerManager+PlaybackAPI.swift
// AsideMusic
//
// 核心播放 API：play, playFM, playPodcast, playSingle, 队列管理等

import Foundation

extension PlayerManager {
    
    // MARK: - Core Playback API
    
    func play(song: Song, in newContext: [Song]) {
        // 如果点击的是当前正在播放的歌，切换播放/暂停而不是重播
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        self.playSource = .normal
        
        // 当前没有播放队列，直接用新列表
        if self.context.isEmpty || self.currentSong == nil {
            self.context = newContext
            if let index = self.context.firstIndex(where: { $0.id == song.id }) {
                self.contextIndex = index
            } else {
                self.context.insert(song, at: 0)
                self.contextIndex = 0
            }
        } else {
            // 已有队列：把新歌单的全部歌曲插入到当前播放位置之后
            // 1. 去重：过滤掉已在当前队列中的歌（保留点击的那首）
            let existingIds = Set(self.context.map { $0.id })
            let uniqueNewSongs = newContext.filter { $0.id == song.id || !existingIds.contains($0.id) }
            
            // 2. 如果点击的歌已在队列中，先移除旧位置
            if let oldIndex = self.context.firstIndex(where: { $0.id == song.id }) {
                self.context.remove(at: oldIndex)
                // 如果移除的在当前播放位置之前或等于，索引需要回退
                if oldIndex <= self.contextIndex {
                    self.contextIndex = max(0, self.contextIndex - 1)
                }
            }
            
            // 3. 插入到当前播放位置之后
            let insertAt = min(self.contextIndex + 1, self.context.count)
            self.context.insert(contentsOf: uniqueNewSongs, at: insertAt)
            
            // 4. 更新索引指向点击的歌
            if let newIndex = self.context.firstIndex(where: { $0.id == song.id }) {
                self.contextIndex = newIndex
            } else {
                self.contextIndex = insertAt
            }
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
    
    /// 下一首播放：插入到 context 当前位置之后
    func playNext(song: Song) {
        // 去重：如果已在队列中，先移除旧位置
        if let oldIndex = context.firstIndex(where: { $0.id == song.id }) {
            context.remove(at: oldIndex)
            if oldIndex <= contextIndex {
                contextIndex = max(0, contextIndex - 1)
            }
        }
        let insertAt = min(contextIndex + 1, context.count)
        context.insert(song, at: insertAt)
        if mode == .shuffle {
            if let oldIdx = shuffledContext.firstIndex(where: { $0.id == song.id }) {
                shuffledContext.remove(at: oldIdx)
            }
            let shuffleInsert = min(contextIndex + 1, shuffledContext.count)
            shuffledContext.insert(song, at: shuffleInsert)
        }
        saveState()
    }
    
    /// 添加到队列末尾
    func addToQueue(song: Song) {
        if !context.contains(where: { $0.id == song.id }) {
            context.append(song)
            if mode == .shuffle {
                shuffledContext.append(song)
            }
            saveState()
        }
    }
    
    /// 从即将播放列表中移除（基于 context 中 contextIndex 之后的偏移）
    func removeFromUpcoming(at index: Int) {
        let actualIndex = contextIndex + 1 + index
        guard actualIndex < context.count else { return }
        context.remove(at: actualIndex)
        if mode == .shuffle && actualIndex < shuffledContext.count {
            shuffledContext.remove(at: actualIndex)
        }
        saveState()
    }
    
    /// 从队列中点击播放某首歌
    func playFromQueue(song: Song) {
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        // 在 context 中找到这首歌，更新 contextIndex
        if let idx = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = idx
            loadAndPlay(song: song)
            return
        }
        
        // 不在 context 中（比如从历史记录播放），插入到当前位置之后
        let insertIndex = min(contextIndex + 1, context.count)
        context.insert(song, at: insertIndex)
        if mode == .shuffle {
            let shuffleInsert = min(contextIndex + 1, shuffledContext.count)
            shuffledContext.insert(song, at: shuffleInsert)
        }
        contextIndex = insertIndex
        loadAndPlay(song: song)
    }
    
    /// 拖拽调整即将播放列表的顺序（upcoming 偏移量，基于 contextIndex + 1）
    func moveUpcoming(from source: IndexSet, to destination: Int) {
        let base = contextIndex + 1
        // 将 upcoming 偏移转换为 context 的实际索引
        let actualSource = IndexSet(source.map { $0 + base })
        let actualDestination = destination + base
        context.move(fromOffsets: actualSource, toOffset: actualDestination)
        if mode == .shuffle {
            shuffledContext.move(fromOffsets: actualSource, toOffset: actualDestination)
        }
        saveState()
    }
    
    /// 清空即将播放的队列（保留当前正在播放的歌）
    func clearUpcoming() {
        guard contextIndex + 1 < context.count else { return }
        context.removeSubrange((contextIndex + 1)...)
        if mode == .shuffle {
            let shuffleBase = contextIndex + 1
            if shuffleBase < shuffledContext.count {
                shuffledContext.removeSubrange(shuffleBase...)
            }
        }
        saveState()
    }
}
