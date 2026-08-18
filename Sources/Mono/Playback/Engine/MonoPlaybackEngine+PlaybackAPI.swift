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

    /// 从"全部播放"等场景传入的列表中过滤掉**不可用**歌曲（无版权 / VIP 限制无 Cookie / 未购数字专辑 / 运行时兜底失败标记）。
    /// 用户主动点击的 `tappedSong` 保留不过滤，即使它本身 unavailable —— 由 loadAndPlay 负责弹窗。
    /// 这样做到：点全部播放时自动排除灰色歌，但手动点灰色歌仍给明确反馈。
    private func filterUnavailable(_ songs: [Song], keeping tappedSong: Song?) -> [Song] {
        let unavailableManager = UnavailableSongsManager.shared
        let hasVIPCookie = APIService.shared.hasVIPCookie
        return songs.filter { candidate in
            // 用户点击的歌保留
            if let tapped = tappedSong,
               matchesPlaybackTarget(candidate, expected: tapped) {
                return true
            }
            // 本地歌曲直接保留（它们通常有文件就能播）
            if candidate.isLocal { return true }
            // 明确不可用的跳过
            if candidate.isNoCopyright { return false }
            if candidate.isVIPRestricted && !hasVIPCookie { return false }
            if candidate.isUnpurchasedDigitalAlbum { return false }
            if unavailableManager.isUnavailable(song: candidate) { return false }
            return true
        }
    }

    private func replacePlaybackContext(song: Song, in newContext: [Song]) {
        self.playSource = .normal

        if let tapIndex = newContext.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            self.context = newContext
            self.contextIndex = tapIndex
        } else {
            self.context = [song] + newContext
            self.contextIndex = 0
        }

        if mode == .shuffle {
            generateShuffledContext()
            if let shuffledIndex = shuffledContext.firstIndex(where: {
                matchesPlaybackTarget($0, expected: song)
            }) {
                contextIndex = shuffledIndex
            }
        }
        queueExhaustionBehavior = currentContextList.count > 1
            ? .loop
            : .stopAtEnd
    }

    private func insertPlaybackContext(song: Song, in newContext: [Song]) {
        self.playSource = .normal

        let reordered: [Song]
        if let tapIndex = newContext.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            reordered = Array(newContext[tapIndex...]) + Array(newContext[..<tapIndex])
        } else {
            reordered = [song] + newContext
        }

        let newIds = Set(reordered.map { playbackIdentityKey(for: $0) })
        let remaining = self.context.filter {
            !newIds.contains(playbackIdentityKey(for: $0))
        }
        self.context = reordered + remaining
        self.contextIndex = 0

        if mode == .shuffle {
            generateShuffledContext()
            if let shuffledIndex = shuffledContext.firstIndex(where: {
                matchesPlaybackTarget($0, expected: song)
            }) {
                contextIndex = shuffledIndex
            }
        }
        queueExhaustionBehavior = currentContextList.count > 1
            ? .loop
            : .stopAtEnd
    }

    private var hasRetainableCurrentQueue: Bool {
        let list = currentContextList
        guard !list.isEmpty else { return false }
        return list.indices.contains(contextIndex)
    }

    private func currentQueueAnchorIndex(in orderedList: [Song]) -> Int {
        if let current = currentSong,
           let index = orderedList.firstIndex(where: {
               matchesPlaybackTarget($0, expected: current)
           }) {
            return index
        }
        return max(0, min(contextIndex, max(orderedList.count - 1, 0)))
    }

    private func isOrderedSubsequence(_ candidateIDs: [String], of referenceIDs: [String]) -> Bool {
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
        guard currentContextList.contains(where: {
            matchesPlaybackTarget($0, expected: song)
        }) else { return false }
        guard !context.isEmpty, !newContext.isEmpty else { return false }

        let referenceIDs = context.map { playbackIdentityKey(for: $0) }
        let referenceIDSet = Set(referenceIDs)
        let overlappingIDs = newContext
            .map { playbackIdentityKey(for: $0) }
            .filter { referenceIDSet.contains($0) }

        // 至少要能确认“这是同一播放上下文的一段”，避免单首卡片/搜索结果误判成同歌单。
        guard overlappingIDs.count > 1 else { return false }
        return isOrderedSubsequence(overlappingIDs, of: referenceIDs)
    }

    private func reorderedQueueByInsertingBatchAfterCurrent(
        _ songs: [Song],
        in orderedList: [Song],
        currentIndex: Int
    ) -> ([Song], Int) {
        guard !songs.isEmpty else {
            return (orderedList, currentIndex)
        }

        let batchIDs = Set(songs.map { playbackIdentityKey(for: $0) })
        var updatedQueue = orderedList.filter {
            !batchIDs.contains(playbackIdentityKey(for: $0))
        }

        let anchorIndex: Int
        if let current = currentSong,
           let currentPosition = updatedQueue.firstIndex(where: {
               matchesPlaybackTarget($0, expected: current)
           }) {
            anchorIndex = currentPosition
        } else {
            anchorIndex = max(0, min(currentIndex, max(updatedQueue.count - 1, 0)))
        }

        let insertIndex = min(anchorIndex + 1, updatedQueue.count)
        updatedQueue.insert(contentsOf: songs, at: insertIndex)

        let resolvedCurrentIndex: Int
        if let current = currentSong,
           let currentPosition = updatedQueue.firstIndex(where: {
               matchesPlaybackTarget($0, expected: current)
           }) {
            resolvedCurrentIndex = currentPosition
        } else {
            resolvedCurrentIndex = max(0, min(anchorIndex, max(updatedQueue.count - 1, 0)))
        }

        return (updatedQueue, resolvedCurrentIndex)
    }

    private func playSongKeepingCurrentQueue(song: Song) {
        self.playSource = .normal

        if mode == .shuffle {
            if let newIndex = shuffledContext.firstIndex(where: {
                matchesPlaybackTarget($0, expected: song)
            }) {
                contextIndex = newIndex
            } else {
                let insertIndex = min(contextIndex + 1, shuffledContext.count)
                shuffledContext.insert(song, at: insertIndex)
                if !context.contains(where: {
                    matchesPlaybackTarget($0, expected: song)
                }) {
                    context.append(song)
                }
                contextIndex = insertIndex
            }
            return
        }

        if let newIndex = context.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            contextIndex = newIndex
        } else {
            let insertIndex = min(contextIndex + 1, context.count)
            context.insert(song, at: insertIndex)
            contextIndex = insertIndex
        }
    }

    private func enqueueAtTailInSequence(_ song: Song) -> Bool {
        if let existingIndex = context.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
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
        if let existingShuffleIndex = shuffledContext.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            guard existingShuffleIndex <= contextIndex else { return false }
        }

        if let existingIndex = context.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            context.remove(at: existingIndex)
        }

        if let existingShuffleIndex = shuffledContext.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
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
        if matchesPlaybackTarget(currentSong, expected: song) {
            togglePlayPause()
            return
        }
        stagePlaybackQueueMutationIfNeeded()
        ensureMusicContextRestored()

        // "全部播放"等场景：过滤无版权/VIP 限制/未购数字专辑/已标灰失败的歌
        let filteredContext = filterUnavailable(newContext, keeping: song)

        if hasRetainableCurrentQueue {
            if shouldKeepExistingQueuePosition(for: song, in: filteredContext) {
                playFromQueue(song: song)
            } else {
                playSongKeepingCurrentQueue(song: song)
                loadAndPlay(song: song)
            }
        } else if filteredContext.count > 1 {
            replacePlaybackContext(song: song, in: filteredContext)
            loadAndPlay(song: song)
        } else {
            playSingle(song: song)
        }
    }

    func playReplacingContext(song: Song, in newContext: [Song]) {
        let isCurrentSongTarget = matchesPlaybackTarget(currentSong, expected: song)
        if !isCurrentSongTarget {
            stagePlaybackQueueMutationIfNeeded()
        }
        ensureMusicContextRestored()

        // 过滤灰色歌曲
        let filteredContext = filterUnavailable(newContext, keeping: song)

        if insertsPlaybackContext {
            insertPlaybackContext(song: song, in: filteredContext)
        } else {
            replacePlaybackContext(song: song, in: filteredContext)
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
        if !matchesPlaybackTarget(currentSong, expected: song) {
            stagePlaybackQueueMutationIfNeeded()
        }
        if isPlayingPodcast { savePodcastContext() }
        self.context = context
        self.playSource = .fm
        self.queueExhaustionBehavior = .loop
        
        if let index = context.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            self.contextIndex = index
        } else {
            self.contextIndex = 0
        }
        
        self.mode = .sequence
        loadAndPlay(song: song, autoPlay: autoPlay)
    }
    
    /// 预设 FM 上下文（不触发播放），用于进入 FM 界面时展示歌曲信息
    func prepareFM(song: Song, in context: [Song]) {
        // 预览不能覆盖仍绑定旧音频管线的 currentSong。否则旧歌暂停时进入
        // FM，再点播放会恢复旧声音，但界面已经变成 FM 歌曲。
        guard currentSong == nil else { return }
        self.context = context
        self.playSource = .fm
        self.queueExhaustionBehavior = .loop
        self.currentSong = song
        
        if let index = context.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            self.contextIndex = index
        } else {
            self.contextIndex = 0
        }
        
        self.mode = .sequence
        saveState()
    }
    
    func playPodcast(song: Song, in context: [Song], radioId: Int, restoreSavedContext: Bool = true) {
        if !matchesPlaybackTarget(currentSong, expected: song) {
            stagePlaybackQueueMutationIfNeeded()
        }
        if !restoreSavedContext {
            cancelSleepTimer()
        }

        // 如果当前正在播放音乐（非播客），先保存音乐上下文
        if !isPlayingPodcast {
            saveMusicContext()
        }
        // 如果之前有保存的播客上下文且是同一个电台，尝试恢复
        if restoreSavedContext,
           savedPodcastRadioId == radioId, !savedPodcastContext.isEmpty,
           savedPodcastContext.contains(where: {
               matchesPlaybackTarget($0, expected: song)
           }) {
            self.context = savedPodcastContext
            self.contextIndex = savedPodcastContext.firstIndex(where: {
                matchesPlaybackTarget($0, expected: song)
            }) ?? savedPodcastContextIndex
            clearSavedPodcastContext()
        } else {
            if !restoreSavedContext, savedPodcastRadioId == radioId {
                clearSavedPodcastContext()
            }
            self.context = context
            if let index = context.firstIndex(where: {
                matchesPlaybackTarget($0, expected: song)
            }) {
                self.contextIndex = index
            } else {
                self.context.insert(song, at: 0)
                self.contextIndex = 0
            }
        }
        
        self.playSource = .podcast(radioId: radioId)
        self.queueExhaustionBehavior = .loop
        self.mode = .sequence
        
        let songToPlay = self.context.indices.contains(self.contextIndex) ? self.context[self.contextIndex] : song
        loadAndPlay(song: songToPlay)
    }
    
    // MARK: - 播客/音乐上下文隔离
    
    /// 保存当前音乐播放上下文（从音乐切到播客时调用）
    func saveMusicContext() {
        guard !isPlayingPodcast, playSource != .fm else { return }
        savedMusicContext = context
        savedMusicContextIndex = contextIndex
        savedMusicShuffledContext = shuffledContext
        savedMusicMode = mode
        savedMusicSong = currentSong
        savedMusicCurrentTime = currentTime
        savedMusicDuration = duration
    }
    
    /// 保存当前播客播放上下文（从播客切到音乐时调用）
    func savePodcastContext() {
        guard isPlayingPodcast, case .podcast(let radioId) = playSource else { return }
        savedPodcastContext = context
        savedPodcastContextIndex = contextIndex
        savedPodcastRadioId = radioId
        savedPodcastSong = currentSong
        savedPodcastCurrentTime = currentTime
        savedPodcastDuration = duration
    }
    
    /// 确保当前音乐上下文已恢复（在从播客/FM 切换回普通音乐时调用）
    func ensureMusicContextRestored() {
        if isPlayingPodcast || playSource == .fm {
            if isPlayingPodcast { savePodcastContext() }
            self.playSource = .normal
            self.queueExhaustionBehavior = .loop
            
            // 恢复音乐上下文
            if !savedMusicContext.isEmpty {
                self.context = savedMusicContext
                self.contextIndex = savedMusicContextIndex
                self.shuffledContext = savedMusicShuffledContext
                self.mode = savedMusicMode
            } else {
                self.context = []
                self.contextIndex = 0
                self.shuffledContext = []
            }
            clearSavedMusicContext()
        }
    }

    func stopPodcastPlaybackRestoringMusicContext() {
        cancelSleepTimer()

        guard isPlayingPodcast else {
            dismissMiniPlayerPreservingQueue()
            return
        }

        dismissMiniPlayerPreservingQueue()
        self.playSource = .normal
        self.queueExhaustionBehavior = .loop

        if !savedMusicContext.isEmpty {
            self.context = savedMusicContext
            self.contextIndex = savedMusicContextIndex
            self.shuffledContext = savedMusicShuffledContext
            self.mode = savedMusicMode
        } else {
            self.context = []
            self.contextIndex = 0
            self.shuffledContext = []
        }

        playbackBackStack.removeAll()
        playbackForwardStack.removeAll()
        clearSavedMusicContext()
        clearSavedPodcastContext()
        savedPodcastRadioId = nil
        refreshPlaybackSurfaceState()
        saveState()
    }
    
    private func clearSavedMusicContext() {
        savedMusicContext = []
        savedMusicContextIndex = 0
        savedMusicShuffledContext = []
        savedMusicSong = nil
        savedMusicCurrentTime = 0
        savedMusicDuration = 0
    }
    
    private func clearSavedPodcastContext() {
        savedPodcastContext = []
        savedPodcastContextIndex = 0
        savedPodcastSong = nil
        savedPodcastCurrentTime = 0
        savedPodcastDuration = 0
        // 保留 savedPodcastRadioId 以便判断是否是同一电台
    }
    
    private static let contextUpperLimit = 500

    func appendContext(songs: [Song]) {
        let newSongs = songs.filter { newSong in
            !self.context.contains(where: {
                matchesPlaybackTarget($0, expected: newSong)
            })
        }
        guard !newSongs.isEmpty else { return }
        
        self.context.append(contentsOf: newSongs)
        if mode == .shuffle {
            self.shuffledContext.append(contentsOf: newSongs.shuffled())
        }
        trimContextIfNeeded()
        saveState()
    }
    
    func playSingle(song: Song) {
        if matchesPlaybackTarget(currentSong, expected: song) {
            togglePlayPause()
            return
        }
        stagePlaybackQueueMutationIfNeeded()
        ensureMusicContextRestored()

        if currentSong == nil, hasRetainableCurrentQueue {
            playSongKeepingCurrentQueue(song: song)
            loadAndPlay(song: song)
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
        ensureMusicContextRestored()
        if context.isEmpty || currentSong == nil {
            playSingle(song: song)
            return
        }
        var orderedCurrentIndex = currentSong.flatMap { current in
            context.firstIndex(where: { matchesPlaybackTarget($0, expected: current) })
        } ?? max(0, min(contextIndex, max(context.count - 1, 0)))
        if let oldIndex = context.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            context.remove(at: oldIndex)
            if oldIndex < orderedCurrentIndex {
                orderedCurrentIndex = max(0, orderedCurrentIndex - 1)
            }
        }
        let insertAt = min(orderedCurrentIndex + 1, context.count)
        context.insert(song, at: insertAt)
        if mode == .shuffle {
            var shuffleCurrentIndex = currentSong.flatMap { current in
                shuffledContext.firstIndex(where: {
                    matchesPlaybackTarget($0, expected: current)
                })
            } ?? max(0, min(contextIndex, max(shuffledContext.count - 1, 0)))
            if let oldIdx = shuffledContext.firstIndex(where: {
                matchesPlaybackTarget($0, expected: song)
            }) {
                shuffledContext.remove(at: oldIdx)
                if oldIdx < shuffleCurrentIndex {
                    shuffleCurrentIndex = max(0, shuffleCurrentIndex - 1)
                }
            }
            let shuffleInsert = min(shuffleCurrentIndex + 1, shuffledContext.count)
            shuffledContext.insert(song, at: shuffleInsert)
            contextIndex = shuffleCurrentIndex
        } else {
            contextIndex = orderedCurrentIndex
        }
        AppLogger.info("[playNext] 插入 \(song.name) 到位置 \(insertAt), contextIndex=\(contextIndex), context.count=\(context.count), upcoming=\(contextRemainingSongs.count)")
        objectWillChange.send()
        saveState()
        invalidateGaplessPreparation(reason: "playNext")
    }
    
    /// 添加到队列末尾
    func addToQueue(song: Song) {
        ensureMusicContextRestored()
        if context.isEmpty || currentSong == nil {
            playSingle(song: song)
            return
        }

        guard !matchesPlaybackTarget(currentSong, expected: song) else {
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
        invalidateGaplessPreparation(reason: "addToQueue")
    }

    func addToQueue(songs: [Song]) {
        ensureMusicContextRestored()
        var seenSongIDs = Set<String>()
        let orderedSongs = songs.filter { song in
            let key = playbackIdentityKey(for: song)
            return seenSongIDs.insert(key).inserted
                && !matchesPlaybackTarget(currentSong, expected: song)
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
            invalidateGaplessPreparation(reason: "addToQueue:batch")
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
            "[addToQueue:batch] 插入 \(orderedSongs.count) 首到当前歌曲后, " +
            "contextIndex=\(contextIndex), context.count=\(context.count), upcoming=\(contextRemainingSongs.count)"
        )
        objectWillChange.send()
        saveState()
        invalidateGaplessPreparation(reason: "addToQueue:batch")
    }

    /// Replaces the ordered queue used by a Mono Session without restarting the
    /// currently audible track. Session playback is intentionally sequential so
    /// every participant observes the same next-track order.
    func replaceMonoSessionQueue(
        with songs: [Song],
        preferredCurrentSong: Song? = nil
    ) {
        var identities = Set<String>()
        var normalized = songs.filter { song in
            identities.insert(playbackIdentityKey(for: song)).inserted
        }
        let anchor = preferredCurrentSong ?? currentSong
        if let anchor,
           !normalized.contains(where: { matchesPlaybackTarget($0, expected: anchor) }) {
            normalized.insert(anchor, at: 0)
        }
        guard !normalized.isEmpty else { return }

        context = normalized
        shuffledContext = []
        mode = .sequence
        if let anchor,
           let index = normalized.firstIndex(where: {
               matchesPlaybackTarget($0, expected: anchor)
           }) {
            contextIndex = index
        } else {
            contextIndex = 0
        }
        objectWillChange.send()
        saveState()
        invalidateGaplessPreparation(reason: "mono-session-queue")
    }
    
    /// 从即将播放列表中移除（基于当前播放列表 contextIndex 之后的偏移）
    func removeFromUpcoming(at index: Int) {
        let list = currentContextList
        let actualIndex = contextIndex + 1 + index
        guard actualIndex < list.count else { return }
        let songToRemove = list[actualIndex]
        
        context.removeAll { matchesPlaybackTarget($0, expected: songToRemove) }
        if mode == .shuffle {
            shuffledContext.removeAll { matchesPlaybackTarget($0, expected: songToRemove) }
        }
        if let current = currentSong,
           let newIdx = currentContextList.firstIndex(where: {
               matchesPlaybackTarget($0, expected: current)
           }) {
            contextIndex = newIdx
        }
        saveState()
        invalidateGaplessPreparation(reason: "removeFromUpcoming")
    }

    func removeFromContext(songID: Int) {
        let list = currentContextList
        guard let targetIndex = list.firstIndex(where: { $0.id == songID }) else { return }
        guard targetIndex != contextIndex else { return }
        let target = list[targetIndex]

        let removedBeforeCurrent = targetIndex < contextIndex

        context.removeAll { matchesPlaybackTarget($0, expected: target) }
        if mode == .shuffle {
            shuffledContext.removeAll { matchesPlaybackTarget($0, expected: target) }
        }

        if removedBeforeCurrent {
            contextIndex = max(0, contextIndex - 1)
        }

        if let current = currentSong,
           let newIndex = currentContextList.firstIndex(where: {
               matchesPlaybackTarget($0, expected: current)
           }) {
            contextIndex = newIndex
        } else {
            contextIndex = min(contextIndex, max(currentContextList.count - 1, 0))
        }

        objectWillChange.send()
        saveState()
        invalidateGaplessPreparation(reason: "removeFromContext")
    }
    
    /// 从队列中点击播放某首歌
    func playFromQueue(song: Song) {
        if matchesPlaybackTarget(currentSong, expected: song) {
            togglePlayPause()
            return
        }
        stagePlaybackQueueMutationIfNeeded()
        
        // 手动点选只切换当前游标，不改写队列。中间经过但没有真正播放的歌曲
        // 是否属于“已播放”由播放会话统计决定，不能再通过队列索引推断。
        if currentContextList.contains(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            playSongKeepingCurrentQueue(song: song)
            AppLogger.info(
                "[Queue] 手动点播并保持原队列顺序: \(song.name), " +
                "contextIndex=\(contextIndex)"
            )
            loadAndPlay(song: song)
            return
        }
        
        // 不在 context 中（比如从历史记录播放），插入到当前位置之后
        let insertIndex = min(contextIndex + 1, context.count)
        context.insert(song, at: insertIndex)
        if mode == .shuffle {
            // 随机模式下 contextIndex 索引的是 shuffledContext，
            // 必须用随机列表里的插入位置，否则指到错误的槽位
            let shuffleInsert = min(contextIndex + 1, shuffledContext.count)
            shuffledContext.insert(song, at: shuffleInsert)
            contextIndex = shuffleInsert
        } else {
            contextIndex = insertIndex
        }
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
        invalidateGaplessPreparation(reason: "moveUpcoming")
    }
    
    private func trimContextIfNeeded() {
        guard context.count > Self.contextUpperLimit else { return }
        let safeIndex = max(0, contextIndex)
        let keepStart = max(0, safeIndex - Self.contextUpperLimit / 2)
        let keepEnd = min(context.count, keepStart + Self.contextUpperLimit)
        context = Array(context[keepStart..<keepEnd])
        contextIndex = safeIndex - keepStart

        if mode == .shuffle {
            let currentIds = Set(context.map { playbackIdentityKey(for: $0) })
            shuffledContext.removeAll {
                !currentIds.contains(playbackIdentityKey(for: $0))
            }
        }
    }

    /// 清空即将播放的队列（保留当前正在播放的歌）
    func clearUpcoming() {
        let list = currentContextList
        guard contextIndex + 1 < list.count else { return }
        
        let keepIds = Set(list.prefix(contextIndex + 1).map {
            playbackIdentityKey(for: $0)
        })
        context.removeAll { !keepIds.contains(playbackIdentityKey(for: $0)) }
        if mode == .shuffle {
            shuffledContext.removeAll { !keepIds.contains(playbackIdentityKey(for: $0)) }
        }
        if let current = currentSong,
           let newIdx = currentContextList.firstIndex(where: {
               matchesPlaybackTarget($0, expected: current)
           }) {
            contextIndex = newIdx
        }
        saveState()
        invalidateGaplessPreparation(reason: "clearUpcoming")
    }
}
