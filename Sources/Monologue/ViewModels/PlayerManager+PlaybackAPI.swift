// PlayerManager+PlaybackAPI.swift
// Monologue
//
// 核心播放 API：play, playFM, playPodcast, playSingle, 队列管理等

import Foundation

extension PlayerManager {
    
    // MARK: - Core Playback API

    private var insertsPlaybackContext: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppConfig.StorageKeys.insertPlaybackContext) != nil else {
            return false
        }
        return defaults.bool(forKey: AppConfig.StorageKeys.insertPlaybackContext)
    }

    private func replacePlaybackContext(song: Song, in newContext: [Song]) {
        self.playSource = .normal
        self.queueExhaustionBehavior = .loop

        if let tapIndex = newContext.firstIndex(where: { $0.id == song.id }) {
            self.context = newContext
            self.contextIndex = tapIndex
        } else {
            self.context = [song] + newContext
            self.contextIndex = 0
        }

        if mode == .shuffle {
            generateShuffledContext()
            if let shuffledIndex = shuffledContext.firstIndex(where: { $0.id == song.id }) {
                contextIndex = shuffledIndex
            }
        }
    }

    private func insertPlaybackContext(song: Song, in newContext: [Song]) {
        self.playSource = .normal
        self.queueExhaustionBehavior = .loop

        let reordered: [Song]
        if let tapIndex = newContext.firstIndex(where: { $0.id == song.id }) {
            reordered = Array(newContext[tapIndex...]) + Array(newContext[..<tapIndex])
        } else {
            reordered = [song] + newContext
        }

        let newIds = Set(reordered.map { $0.id })
        let remaining = self.context.filter { !newIds.contains($0.id) }
        self.context = reordered + remaining
        self.contextIndex = 0

        if mode == .shuffle {
            generateShuffledContext()
            if let shuffledIndex = shuffledContext.firstIndex(where: { $0.id == song.id }) {
                contextIndex = shuffledIndex
            }
        }
    }

    private var hasRetainableCurrentQueue: Bool {
        let list = currentContextList
        guard currentSong != nil, !list.isEmpty else { return false }
        return list.indices.contains(contextIndex)
    }

    private func currentQueueAnchorIndex(in orderedList: [Song]) -> Int {
        if let current = currentSong,
           let index = orderedList.firstIndex(where: { $0.id == current.id }) {
            return index
        }
        return max(0, min(contextIndex, max(orderedList.count - 1, 0)))
    }

    private func isOrderedSubsequence(_ candidateIDs: [Int], of referenceIDs: [Int]) -> Bool {
        guard !candidateIDs.isEmpty else { return false }

        var searchStart = 0
        for candidateID in candidateIDs {
            guard searchStart < referenceIDs.count else { return false }
            guard let offset = referenceIDs[searchStart...].firstIndex(of: candidateID) else {
                return false
            }
            searchStart = offset + 1
        }
        return true
    }

    private func shouldKeepExistingQueuePosition(for song: Song, in newContext: [Song]) -> Bool {
        guard currentContextList.contains(where: { $0.id == song.id }) else { return false }
        guard !context.isEmpty, !newContext.isEmpty else { return false }

        let referenceIDs = context.map(\.id)
        let referenceIDSet = Set(referenceIDs)
        let overlappingIDs = newContext.map(\.id).filter { referenceIDSet.contains($0) }

        // 至少要能确认“这是同一播放上下文的一段”，避免单首卡片/搜索结果误判成同歌单。
        guard overlappingIDs.count > 1 else { return false }
        return isOrderedSubsequence(overlappingIDs, of: referenceIDs)
    }

    private func reorderedQueueByPromotingSongToCurrent(
        _ song: Song,
        in orderedList: [Song],
        currentIndex: Int
    ) -> ([Song], Int) {
        guard !orderedList.isEmpty else { return ([song], 0) }

        var updatedQueue = orderedList
        var anchorIndex = max(0, min(currentIndex, updatedQueue.count - 1))

        if let existingIndex = updatedQueue.firstIndex(where: { $0.id == song.id }) {
            updatedQueue.remove(at: existingIndex)
            if existingIndex <= anchorIndex {
                anchorIndex = max(0, anchorIndex - 1)
            }
        }

        let insertIndex = min(anchorIndex + 1, updatedQueue.count)
        updatedQueue.insert(song, at: insertIndex)
        return (updatedQueue, insertIndex)
    }

    private func reorderedQueueByInsertingBatchAfterCurrent(
        _ songs: [Song],
        in orderedList: [Song],
        currentIndex: Int
    ) -> ([Song], Int) {
        guard !songs.isEmpty else {
            return (orderedList, currentIndex)
        }

        let batchIDs = Set(songs.map(\.id))
        var updatedQueue = orderedList.filter { !batchIDs.contains($0.id) }

        let anchorIndex: Int
        if let current = currentSong,
           let currentPosition = updatedQueue.firstIndex(where: { $0.id == current.id }) {
            anchorIndex = currentPosition
        } else {
            anchorIndex = max(0, min(currentIndex, max(updatedQueue.count - 1, 0)))
        }

        let insertIndex = min(anchorIndex + 1, updatedQueue.count)
        updatedQueue.insert(contentsOf: songs, at: insertIndex)

        let resolvedCurrentIndex: Int
        if let current = currentSong,
           let currentPosition = updatedQueue.firstIndex(where: { $0.id == current.id }) {
            resolvedCurrentIndex = currentPosition
        } else {
            resolvedCurrentIndex = max(0, min(anchorIndex, max(updatedQueue.count - 1, 0)))
        }

        return (updatedQueue, resolvedCurrentIndex)
    }

    private func playSongKeepingCurrentQueue(song: Song) {
        self.playSource = .normal

        if mode == .shuffle {
            let orderedQueue = currentContextList.isEmpty ? context : currentContextList
            let anchorIndex = currentQueueAnchorIndex(in: orderedQueue)
            let (updatedQueue, newIndex) = reorderedQueueByPromotingSongToCurrent(
                song,
                in: orderedQueue,
                currentIndex: anchorIndex
            )
            shuffledContext = updatedQueue
            if !context.contains(where: { $0.id == song.id }) {
                context.append(song)
            }
            contextIndex = newIndex
            return
        }

        let anchorIndex = currentQueueAnchorIndex(in: context)
        let (updatedQueue, newIndex) = reorderedQueueByPromotingSongToCurrent(
            song,
            in: context,
            currentIndex: anchorIndex
        )
        context = updatedQueue
        contextIndex = newIndex
    }

    private func enqueueAtTailInSequence(_ song: Song) -> Bool {
        if let existingIndex = context.firstIndex(where: { $0.id == song.id }) {
            guard existingIndex <= contextIndex else { return false }
            context.remove(at: existingIndex)
            if existingIndex < contextIndex {
                contextIndex = max(0, contextIndex - 1)
            }
        }

        context.append(song)
        return true
    }

    private func enqueueAtTailInShuffle(_ song: Song) -> Bool {
        if let existingShuffleIndex = shuffledContext.firstIndex(where: { $0.id == song.id }) {
            guard existingShuffleIndex <= contextIndex else { return false }
        }

        if let existingIndex = context.firstIndex(where: { $0.id == song.id }) {
            context.remove(at: existingIndex)
        }

        if let existingShuffleIndex = shuffledContext.firstIndex(where: { $0.id == song.id }) {
            shuffledContext.remove(at: existingShuffleIndex)
            if existingShuffleIndex < contextIndex {
                contextIndex = max(0, contextIndex - 1)
            }
        }

        context.append(song)
        shuffledContext.append(song)
        return true
    }
    
    func play(song: Song, in newContext: [Song]) {
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }

        if hasRetainableCurrentQueue {
            if shouldKeepExistingQueuePosition(for: song, in: newContext) {
                playFromQueue(song: song)
            } else {
                playSongKeepingCurrentQueue(song: song)
                loadAndPlay(song: song)
            }
        } else {
            playSingle(song: song)
        }
    }

    func playReplacingContext(song: Song, in newContext: [Song]) {
        let isCurrentSongTarget = currentSong?.id == song.id

        if insertsPlaybackContext {
            insertPlaybackContext(song: song, in: newContext)
        } else {
            replacePlaybackContext(song: song, in: newContext)
        }

        if isCurrentSongTarget {
            if !isPlaying {
                _ = playPlayback()
            } else {
                saveState()
            }
            return
        }

        loadAndPlay(song: song)
    }
    
    func playFM(song: Song, in context: [Song], autoPlay: Bool = true) {
        self.context = context
        self.playSource = .fm
        self.queueExhaustionBehavior = .loop
        
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
        self.queueExhaustionBehavior = .loop
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
        self.queueExhaustionBehavior = .loop
        
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
    
    private static let contextUpperLimit = 500

    func appendContext(songs: [Song]) {
        let newSongs = songs.filter { newSong in !self.context.contains(where: { $0.id == newSong.id }) }
        guard !newSongs.isEmpty else { return }
        
        self.context.append(contentsOf: newSongs)
        if mode == .shuffle {
            self.shuffledContext.append(contentsOf: newSongs.shuffled())
        }
        trimContextIfNeeded()
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
        self.queueExhaustionBehavior = .stopAtEnd
        
        loadAndPlay(song: song)
    }
    
    /// 下一首播放：插入到 context 当前位置之后
    func playNext(song: Song) {
        if context.isEmpty || currentSong == nil {
            playSingle(song: song)
            return
        }
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
        AppLogger.info("[playNext] 插入 \(song.name) 到位置 \(insertAt), contextIndex=\(contextIndex), context.count=\(context.count), upcoming=\(contextRemainingSongs.count)")
        objectWillChange.send()
        saveState()
    }
    
    /// 添加到队列末尾
    func addToQueue(song: Song) {
        if context.isEmpty || currentSong == nil {
            playSingle(song: song)
            return
        }

        guard currentSong?.id != song.id else {
            return
        }

        let didEnqueue: Bool
        if mode == .shuffle {
            didEnqueue = enqueueAtTailInShuffle(song)
        } else {
            didEnqueue = enqueueAtTailInSequence(song)
        }

        guard didEnqueue else {
            return
        }

        objectWillChange.send()
        saveState()
    }

    func addToQueue(songs: [Song]) {
        var seenSongIDs = Set<Int>()
        let orderedSongs = songs.filter { song in
            seenSongIDs.insert(song.id).inserted && song.id != currentSong?.id
        }
        guard !orderedSongs.isEmpty else { return }

        if context.isEmpty || currentSong == nil {
            let firstSong = orderedSongs[0]
            playSingle(song: firstSong)

            let remainingSongs = Array(orderedSongs.dropFirst())
            guard !remainingSongs.isEmpty else { return }

            let anchorIndex = currentQueueAnchorIndex(in: context)
            let (updatedContext, resolvedContextIndex) = reorderedQueueByInsertingBatchAfterCurrent(
                remainingSongs,
                in: context,
                currentIndex: anchorIndex
            )
            context = updatedContext

            if mode == .shuffle {
                let shuffleAnchorIndex = currentQueueAnchorIndex(in: shuffledContext)
                let (updatedShuffledContext, resolvedShuffleIndex) = reorderedQueueByInsertingBatchAfterCurrent(
                    remainingSongs,
                    in: shuffledContext,
                    currentIndex: shuffleAnchorIndex
                )
                shuffledContext = updatedShuffledContext
                contextIndex = resolvedShuffleIndex
            } else {
                contextIndex = resolvedContextIndex
            }

            objectWillChange.send()
            saveState()
            return
        }

        let contextAnchorIndex = currentQueueAnchorIndex(in: context)
        let (updatedContext, resolvedContextIndex) = reorderedQueueByInsertingBatchAfterCurrent(
            orderedSongs,
            in: context,
            currentIndex: contextAnchorIndex
        )
        context = updatedContext

        if mode == .shuffle {
            let shuffleAnchorIndex = currentQueueAnchorIndex(in: shuffledContext)
            let (updatedShuffledContext, resolvedShuffleIndex) = reorderedQueueByInsertingBatchAfterCurrent(
                orderedSongs,
                in: shuffledContext,
                currentIndex: shuffleAnchorIndex
            )
            shuffledContext = updatedShuffledContext
            contextIndex = resolvedShuffleIndex
        } else {
            contextIndex = resolvedContextIndex
        }

        AppLogger.info(
            String(localized: "[addToQueue:batch] 插入 \(orderedSongs.count) 首到当前歌曲后, ") +
            "contextIndex=\(contextIndex), context.count=\(context.count), upcoming=\(contextRemainingSongs.count)"
        )
        objectWillChange.send()
        saveState()
    }
    
    /// 从即将播放列表中移除（基于当前播放列表 contextIndex 之后的偏移）
    func removeFromUpcoming(at index: Int) {
        let list = currentContextList
        let actualIndex = contextIndex + 1 + index
        guard actualIndex < list.count else { return }
        let songToRemove = list[actualIndex]
        
        context.removeAll { $0.id == songToRemove.id }
        if mode == .shuffle {
            shuffledContext.removeAll { $0.id == songToRemove.id }
        }
        if let current = currentSong,
           let newIdx = currentContextList.firstIndex(where: { $0.id == current.id }) {
            contextIndex = newIdx
        }
        saveState()
    }

    func removeFromContext(songID: Int) {
        let list = currentContextList
        guard let targetIndex = list.firstIndex(where: { $0.id == songID }) else { return }
        guard targetIndex != contextIndex else { return }

        let removedBeforeCurrent = targetIndex < contextIndex

        context.removeAll { $0.id == songID }
        if mode == .shuffle {
            shuffledContext.removeAll { $0.id == songID }
        }

        if removedBeforeCurrent {
            contextIndex = max(0, contextIndex - 1)
        }

        if let current = currentSong,
           let newIndex = currentContextList.firstIndex(where: { $0.id == current.id }) {
            contextIndex = newIndex
        } else {
            contextIndex = min(contextIndex, max(currentContextList.count - 1, 0))
        }

        objectWillChange.send()
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
        if mode == .shuffle {
            let actualSource = IndexSet(source.map { $0 + base })
            let actualDestination = destination + base
            shuffledContext.move(fromOffsets: actualSource, toOffset: actualDestination)
        } else {
            let actualSource = IndexSet(source.map { $0 + base })
            let actualDestination = destination + base
            context.move(fromOffsets: actualSource, toOffset: actualDestination)
        }
        saveState()
    }
    
    private func trimContextIfNeeded() {
        guard context.count > Self.contextUpperLimit else { return }
        let safeIndex = max(0, contextIndex)
        let keepStart = max(0, safeIndex - Self.contextUpperLimit / 2)
        let keepEnd = min(context.count, keepStart + Self.contextUpperLimit)
        context = Array(context[keepStart..<keepEnd])
        contextIndex = safeIndex - keepStart

        if mode == .shuffle {
            let currentIds = Set(context.map { $0.id })
            shuffledContext.removeAll { !currentIds.contains($0.id) }
        }
    }

    /// 清空即将播放的队列（保留当前正在播放的歌）
    func clearUpcoming() {
        let list = currentContextList
        guard contextIndex + 1 < list.count else { return }
        
        let keepIds = Set(list.prefix(contextIndex + 1).map { $0.id })
        context.removeAll { !keepIds.contains($0.id) }
        if mode == .shuffle {
            shuffledContext.removeAll { !keepIds.contains($0.id) }
        }
        if let current = currentSong,
           let newIdx = currentContextList.firstIndex(where: { $0.id == current.id }) {
            contextIndex = newIdx
        }
        saveState()
    }
}
