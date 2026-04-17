// PlayerManager+Internal.swift
// Monologue
//
// 内部播放逻辑：shuffle 生成、播放结束处理、无缝切歌、预加载、loadAndPlay

import Foundation
import Combine
import FFmpegSwiftSDK
import QQMusicKit

private func playerInternalText(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func playerInternalFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: playerInternalText(key), locale: Locale.current, arguments: arguments)
}

extension PlayerManager {
    
    // MARK: - Internal Methods

    var isGaplessPlaybackEnabled: Bool {
        Self.gaplessPlaybackEnabled()
    }

    func handleGaplessPlaybackSettingChanged(enabled: Bool) {
        if enabled {
            scheduledGaplessPreparationSessionId = nil
            guard isPlaying, currentSong != nil else { return }
            prefetchNextTrackQuality()
            scheduleGaplessPreparationAfterPlaybackStartedIfNeeded()
            return
        }

        cancelGaplessPreparation(resetPendingState: true)
    }

    func cancelGaplessPreparation(resetPendingState: Bool) {
        gaplessPreparationWorkItem?.cancel()
        gaplessPreparationWorkItem = nil
        scheduledGaplessPreparationSessionId = nil

        nextTrackCancellable?.cancel()
        nextTrackCancellable = nil

        nextQualityPrefetchTask?.cancel()
        nextQualityPrefetchTask = nil

        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil

        if pendingQualitySwitchSeek == nil {
            streamPlayer.cancelNextPreparation()
        }

        if resetPendingState {
            hasPendingTrackTransition = false
            pendingNextSong = nil
            pendingTransitionStartedAt = nil
            pendingTransitionSessionId = 0
        }
    }

    func scheduleGaplessPreparationAfterPlaybackStartedIfNeeded() {
        guard isGaplessPlaybackEnabled else { return }
        let sessionId = playbackSessionId
        guard scheduledGaplessPreparationSessionId != sessionId else { return }
        scheduledGaplessPreparationSessionId = sessionId

        gaplessPreparationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.playbackSessionId == sessionId else { return }
            guard self.isPlaying, self.currentSong != nil else { return }
            self.prepareGaplessNextTrack()
        }
        gaplessPreparationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }
    
    /// 根据歌曲来源获取歌词（统一入口，避免重复判断）
    func fetchLyricsForSong(_ song: Song) {
        // 播客节目没有歌词，跳过请求
        guard !isPlayingPodcast else {
            LyricViewModel.shared.clearLyrics()
            return
        }
        LyricViewModel.shared.fetchLyrics(for: song)
    }

    func localPlaybackURL(for song: Song) -> URL? {
        if let localURL = song.localFileURL {
            return localURL
        }
        return DownloadManager.shared.localFileURL(songId: song.id, isQQ: song.isQQMusic)
    }
    
    /// 根据歌曲来源加载动态封面（仅ncm）
    func loadSongExtras(for song: Song) {
        dynamicCoverUrl = nil
        if !song.isQQMusic && !song.isQishui {
            loadDynamicCover(songId: song.id)
        }
    }

    func pushSongToBackStack(_ song: Song) {
        playbackBackStack.append(song)
        if playbackBackStack.count > maxBackStackSize {
            playbackBackStack.removeFirst(playbackBackStack.count - maxBackStackSize)
        }
    }

    func pushSongToForwardStack(_ song: Song) {
        playbackForwardStack.append(song)
        if playbackForwardStack.count > maxBackStackSize {
            playbackForwardStack.removeFirst(playbackForwardStack.count - maxBackStackSize)
        }
    }

    func upcomingPlaybackSong() -> Song? {
        let list = currentContextList
        guard !list.isEmpty else { return nil }

        let safeCurrentIndex = (contextIndex >= 0 && contextIndex < list.count) ? contextIndex : 0
        let nextIndex = safeCurrentIndex + 1
        if nextIndex >= list.count {
            return queueExhaustionBehavior == .stopAtEnd ? nil : list.first
        }
        return list[nextIndex]
    }

    func stopAfterQueueExhausted() {
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        nextTrackCancellable?.cancel()
        streamPlayer.cancelNextPreparation()

        switch streamPlayer.state {
        case .connecting, .playing, .paused:
            suppressStopHandlingUntil = Date().addingTimeInterval(1)
            streamPlayer.stop()
        case .idle, .stopped, .error:
            break
        }

        isLoading = false
        isPlaying = false
        refreshPlaybackSurfaceState()
        saveState()
        syncWidgetState()
    }

    func applyAutomaticTransitionNavigationState(to song: Song) {
        guard let current = currentSong, current.id != song.id else { return }

        pushSongToBackStack(current)
        if playbackForwardStack.last?.id == song.id {
            playbackForwardStack.removeLast()
        } else {
            playbackForwardStack.removeAll()
        }
    }
    
    func generateShuffledContext() {
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
    
    /// StreamPlayer 播放结束回调（由 delegate adapter 调用）
    func playerDidFinishPlaying() {
        guard !isHandlingPlaybackFinish else {
            AppLogger.warning("playerDidFinishPlaying 重入，忽略")
            return
        }
        isHandlingPlaybackFinish = true
        defer { isHandlingPlaybackFinish = false }
        
        AppLogger.info("playerDidFinishPlaying 被调用, currentTime=\(currentTime), duration=\(duration), song=\(currentSong?.name ?? "nil")")
        if pendingSleepStopAfterCurrentTrack {
            pendingSleepStopAfterCurrentTrack = false
            stopAfterQueueExhausted()
            return
        }
        switch mode {
        case .loopSingle:
            if let song = currentSong {
                loadAndPlay(song: song)
            }
        case .sequence, .shuffle:
            next()
        }
    }
    
    /// 无缝切歌：SDK 已自动切换到下一首的 pipeline，这里只更新 UI 状态
    func advanceToNextTrack() {
        guard mode != .loopSingle else { return }

        guard let song = upcomingPlaybackSong() else { return }
        applyAutomaticTransitionNavigationState(to: song)
        if let index = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = index
        }
        
        // 立即更新 UI（SDK 已经在播放下一首了）
        currentSong = song
        fetchLyricsForSong(song)
        loadSongExtras(for: song)
        addToHistory(song: song)
        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor in
            await LyricsLiveActivityManager.shared.sync(with: self, forceRestart: true)
        }
        #endif
    }
    
    /// 准备下一首歌曲信息（不更新 UI，等待当前歌曲真正结束）
    func preparePendingNextTrack() {
        guard isGaplessPlaybackEnabled else {
            hasPendingTrackTransition = false
            pendingNextSong = nil
            pendingTransitionStartedAt = nil
            pendingTransitionSessionId = 0
            return
        }
        guard mode != .loopSingle else { return }
        guard !pendingSleepStopAfterCurrentTrack else {
            hasPendingTrackTransition = false
            pendingNextSong = nil
            pendingTransitionStartedAt = nil
            return
        }

        pendingNextSong = upcomingPlaybackSong()
        guard pendingNextSong != nil else {
            hasPendingTrackTransition = false
            pendingTransitionStartedAt = nil
            return
        }
        hasPendingTrackTransition = true
        pendingTransitionStartedAt = Date()
        pendingTransitionSessionId = playbackSessionId
    }
    
    /// 当前歌曲真正结束后，应用待切换的下一首
    func applyPendingTrackTransition() {
        guard isGaplessPlaybackEnabled else {
            cancelGaplessPreparation(resetPendingState: true)
            return
        }

        if pendingSleepStopAfterCurrentTrack {
            pendingSleepStopAfterCurrentTrack = false
            stopAfterQueueExhausted()
            return
        }

        guard let song = pendingNextSong else {
            if hasPendingTrackTransition {
                AppLogger.warning("applyPendingTrackTransition: pendingNextSong 为 nil，重置标记")
            }
            hasPendingTrackTransition = false
            pendingNextSong = nil
            pendingTransitionStartedAt = nil
            return
        }
        
        // 用户已手动切歌（session 变了），放弃本次无缝切换
        if pendingTransitionSessionId != playbackSessionId {
            AppLogger.info("applyPendingTrackTransition: session 已变更，跳过")
            hasPendingTrackTransition = false
            pendingNextSong = nil
            pendingTransitionStartedAt = nil
            return
        }
        
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil

        applyAutomaticTransitionNavigationState(to: song)
        if let index = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = index
        }
        
        currentSong = song
        currentTime = 0
        duration = song.dt.map { Double($0) / 1000.0 } ?? 0
        
        // 确保播放状态正确（无缝切歌时 SDK 一直在播放，isPlaying 应为 true）
        if !isPlaying {
            isPlaying = true
        }
        
        // 从 streamInfo 获取下一首的 duration（transitionToNextTrack 中不再单独发送 didUpdateDuration）
        if let nextDuration = streamPlayer.streamInfo?.duration, nextDuration > 0 {
            duration = nextDuration
        }
        
        fetchLyricsForSong(song)
        loadSongExtras(for: song)
        addToHistory(song: song)
        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
        syncWidgetState()
        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor in
            await LyricsLiveActivityManager.shared.sync(with: self, forceRestart: true)
        }
        #endif
        
        // 无缝切歌不会经过 loadAndPlay，需要手动重置这些“按当前歌曲一次性执行”的任务状态
        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil
        nextQualityPrefetchTask?.cancel()
        nextQualityPrefetchTask = nil
        nextTrackCancellable?.cancel()
        playbackStartedAt = Date()
        LyricViewModel.shared.updateCurrentTime(0)
        
        // 为新的当前歌曲继续准备下一首，真正形成连续预加载链路
        prefetchNextTrackQuality()
        prepareGaplessNextTrack()
    }
    
    private func prepareGaplessNextTrack() {
        guard isGaplessPlaybackEnabled else {
            cancelGaplessPreparation(resetPendingState: true)
            return
        }
        guard mode != .loopSingle else { return }
        preparePendingNextTrack()
        prepareNextTrackURL()
    }
    
    /// 预加载下一首歌曲的 URL，传给 StreamPlayer.prepareNext
    func prepareNextTrackURL() {
        guard isGaplessPlaybackEnabled else {
            cancelGaplessPreparation(resetPendingState: true)
            return
        }
        guard mode != .loopSingle else { return }
        let sessionId = playbackSessionId

        guard let song = upcomingPlaybackSong() else { return }
        
        // 优先使用本地文件
        if let localURL = localPlaybackURL(for: song) {
            AppLogger.info("预加载下一首 (本地): \(song.name)")
            streamPlayer.prepareNext(url: localURL.playerInputString)
            return
        }
        
        if let cachedQMCFile = cachedQMCFileURL(for: song.id) {
            AppLogger.info("[QMC] 预加载下一首（解密缓存）: \(song.name)")
            streamPlayer.prepareNext(url: cachedQMCFile.playerInputString)
            return
        }
        
        nextTrackCancellable?.cancel()
        streamPlayer.cancelNextPreparation()
        
        // 网络获取 URL：每首歌单独按该曲最高可用音质（使用预缓存加速）
        if song.isQishui, let trackId = song.qishuiTrackId {
            let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality
            let requestedQuality = shouldAutoSelectHighest ? "lossless" : self.qishuiSelectedQuality
            Task { @MainActor in
                self.nextTrackCancellable = APIService.shared.fetchQishuiSongUrl(trackId: trackId, quality: requestedQuality)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] result in
                        guard let self, self.playbackSessionId == sessionId, self.isGaplessPlaybackEnabled else { return }
                        self.qishuiSelectedQuality = result.quality
                        // 如果不需要解密（普通直连），可以在这里传给 player
                        // 需要解密的话需要先下载，这里暂时只在缓存命中时无缝或者不处理
                        AppLogger.info("[Qishui] 获取到了预加载下一首 URL")
                        // 预下载或者传给 player
                        // 简单跳过 prepareNext 交给切歌时的 downloadAndPlayQishuiAudio 来做，避免重复下载引发冲突
                    })
            }
        } else if song.isQQMusic, let mid = song.qqMid {
            let cachedQQ = QQMusicQuality(rawValue: prefetchedQualityCache.removeValue(forKey: "qq_\(mid)") ?? "")
            Task { @MainActor in
                self.nextTrackCancellable = APIService.shared.fetchQQSongUrl(
                    mid: mid,
                    quality: nil,
                    prefetchedQuality: cachedQQ
                )
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        guard let self, self.playbackSessionId == sessionId else { return }
                        if case .failure(let error) = completion {
                            AppLogger.warning("[QQMusic] 预加载下一首 URL 获取失败: \(error)")
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self, self.playbackSessionId == sessionId else { return }
                        guard self.isGaplessPlaybackEnabled else { return }
                        guard let url = URL(string: result.url) else { return }
                        
                        if let ekey = result.qmcEkey, SettingsManager.shared.qmcDecryptEnabled {
                            self.prepareDecryptedNextTrack(url: url, ekey: ekey, song: song, sessionId: sessionId)
                            return
                        }
                        
                        AppLogger.info("[QQMusic] 预加载下一首 (网络): \(song.name)")
                        self.streamPlayer.prepareNext(url: url.playerInputString)
                    })
            }
        } else {
            let cachedNCM = prefetchedQualityCache.removeValue(forKey: "ncm_\(song.id)")
            Task { @MainActor in
                self.nextTrackCancellable = APIService.shared.fetchSongUrl(
                    id: song.id,
                    prefetchedLevel: cachedNCM
                )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self, self.playbackSessionId == sessionId else { return }
                    if case .failure(let error) = completion {
                        AppLogger.warning("预加载下一首 URL 获取失败: \(error)")
                    }
                }, receiveValue: { [weak self] result in
                    guard let self, self.playbackSessionId == sessionId else { return }
                    guard self.isGaplessPlaybackEnabled else { return }
                    guard let url = URL(string: result.url) else { return }
                    
                    if let ekey = result.qmcEkey, SettingsManager.shared.qmcDecryptEnabled {
                        self.prepareDecryptedNextTrack(url: url, ekey: ekey, song: song, sessionId: sessionId)
                        return
                    }
                    
                    AppLogger.info("预加载下一首 (网络): \(song.name)")
                    self.streamPlayer.prepareNext(url: url.playerInputString)
                })
            }
        }
    }
    
    func loadAndPlay(song: Song, autoPlay: Bool = true, startTime: Double = 0) {
        let isNewSong = currentSong?.id != song.id

        if let current = currentSong, current.id != song.id {
            // 手动切歌默认进入新的播放分支，应清空前进栈；
            // 只有 previous()/next() 的历史导航才保留它。
            if !isApplyingBackNavigation {
                pushSongToBackStack(current)
            }
            if !isApplyingBackNavigation && !isApplyingForwardNavigation {
                playbackForwardStack.removeAll()
            }
        }

        // 递增会话 ID，旧会话的回调会被忽略
        playbackSessionId += 1
        delegateAdapter?.currentSessionId = playbackSessionId
        isHandlingPlaybackFinish = false
        // 取消正在进行的预缓存（切歌后下一首会变）
        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil
        nextQualityPrefetchTask?.cancel()
        nextQualityPrefetchTask = nil
        nextTrackCancellable?.cancel()
        streamPlayer.cancelNextPreparation()
        // 清除待切换状态（用户手动切歌）
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        // 清除 seek 状态
        isSeeking = false
        seekTargetTime = nil
        seekStartedAt = nil
        pendingRestoreTime = nil
        needsPlaybackRestoration = false
        shouldAutoResumeAfterRestore = false
        
        isLoading = true
        currentSong = song
        if startTime <= 0 {
            currentTime = 0
            duration = song.dt.map { Double($0) / 1000.0 } ?? 0
        }
        isCurrentSongUnblocked = false
        streamInfo = nil
        qualitySwitchTimeoutTask?.cancel()
        qualitySwitchTimeoutTask = nil
        qualitySwitchRecoveryAttempts = 0
        
        // 新歌回到全局策略；当前歌曲的手动切换仅在本曲生命周期内有效。
        if isNewSong {
            hasManualNeteaseQualityOverride = false
            hasManualQQQualityOverride = false
            soundQuality = Self.initialNeteasePlaybackQuality()
            qqMusicQuality = Self.initialQQPlaybackQuality()
        }
        // 切歌时重置重试计数器
        if startTime == 0 {
            abnormalStopRetryCount = 0
            networkDisconnectRetryCount = 0
        }
        addToHistory(song: song)
        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor in
            await LyricsLiveActivityManager.shared.sync(with: self, forceRestart: true)
        }
        #endif
        
        // 全局歌词获取（根据来源选择不同歌词接口）
        fetchLyricsForSong(song)
        
        // 加载副歌时间和动态封面
        loadSongExtras(for: song)
        
        // 上报听歌记录到ncm（仅ncm歌曲）
        if !song.isQQMusic && !song.isQishui {
            scrobbleToCloud(song: song)
        }

        // 优先使用本地已下载文件
        if let localURL = localPlaybackURL(for: song) {
            AppLogger.info("使用本地文件播放: \(song.name)")
            self.startPlayback(url: localURL, autoPlay: autoPlay, startTime: startTime)
            return
        }

        // 根据歌曲来源获取播放 URL
        if song.isQishui, let trackId = song.qishuiTrackId {
            loadAndPlayQishuiSong(trackId: trackId, song: song, autoPlay: autoPlay, startTime: startTime)
        } else if song.isQQMusic, let mid = song.qqMid {
            loadAndPlayQQSong(mid: mid, song: song, autoPlay: autoPlay, startTime: startTime)
        } else {
            loadAndPlayNeteaseSong(song: song, autoPlay: autoPlay, startTime: startTime)
        }
        
        // 提前查询下一首的可用音质（后台静默执行，不阻塞当前播放）
        prefetchNextTrackQuality()
    }
    
    /// 提前查询下一首歌的可用音质，缓存结果供预加载/播放时直接使用
    private func prefetchNextTrackQuality() {
        guard isGaplessPlaybackEnabled else {
            nextQualityPrefetchTask?.cancel()
            nextQualityPrefetchTask = nil
            return
        }
        nextQualityPrefetchTask?.cancel()
        
        let list = currentContextList
        guard !list.isEmpty else { return }
        var nextIndex = contextIndex + 1
        if nextIndex >= list.count { nextIndex = 0 }
        let nextSong = list[nextIndex]
        
        if localPlaybackURL(for: nextSong) != nil {
            return
        }
        
        nextQualityPrefetchTask = Task {
            if nextSong.isQishui {
                AppLogger.info("[Prefetch] 下一首 汽水音乐音质暂不预查询: \(nextSong.name)")
            } else if nextSong.isQQMusic, let mid = nextSong.qqMid {
                do {
                    let infos = try await APIService.shared.prefetchQQQualities(mid: mid)
                    guard !Task.isCancelled else { return }
                    let available = Set(infos.map(\.quality))
                    let preferredQuality = SettingsManager.shared.preferHighestPlaybackQuality
                        ? nil
                        : Self.defaultQQPlaybackQuality()
                    if let best = QQMusicQuality
                        .fallbackCandidates(from: preferredQuality)
                        .first(where: available.contains) {
                        await MainActor.run {
                            guard self.isGaplessPlaybackEnabled else { return }
                            self.prefetchedQualityCache["qq_\(mid)"] = best.rawValue
                        }
                        AppLogger.info("[Prefetch] 下一首 QQ 音质预查询完成: \(nextSong.name) → \(best.displayName)")
                    }
                } catch {
                    AppLogger.debug("[Prefetch] 下一首 QQ 音质预查询失败: \(error.localizedDescription)")
                }
            } else {
                do {
                    let infos = try await APIService.shared.prefetchNeteaseQualities(id: nextSong.id)
                    guard !Task.isCancelled else { return }
                    let available = Set(infos.map { $0.quality })
                    let preferredQuality = SettingsManager.shared.preferHighestPlaybackQuality
                        ? nil
                        : Self.defaultNeteasePlaybackQuality()
                    if let best = SoundQuality
                        .fallbackCandidates(from: preferredQuality)
                        .first(where: available.contains) {
                        await MainActor.run {
                            guard self.isGaplessPlaybackEnabled else { return }
                            self.prefetchedQualityCache["ncm_\(nextSong.id)"] = best.rawValue
                        }
                        AppLogger.info("[Prefetch] 下一首 NCM 音质预查询完成: \(nextSong.name) → \(best.displayName)")
                    }
                } catch {
                    AppLogger.debug("[Prefetch] 下一首 NCM 音质预查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 加载并播放ncm歌曲（按当前播放策略解析音质）
    private func loadAndPlayNeteaseSong(song: Song, autoPlay: Bool, startTime: Double) {
        let sessionId = playbackSessionId
        playbackURLCancellable?.cancel()
        let isPodcast = playSource.isPodcast
        let cachedNCM = prefetchedQualityCache.removeValue(forKey: "ncm_\(song.id)")
        let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality && !hasManualNeteaseQualityOverride
        let requestedQuality = shouldAutoSelectHighest ? nil : soundQuality
        
        Task { @MainActor in
            self.playbackURLCancellable = APIService.shared.fetchSongUrl(
                id: song.id,
                level: requestedQuality?.rawValue,
                prefetchedLevel: cachedNCM,
                skipUnblock: isPodcast
            )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    if case .failure(let error) = completion {
                        AppLogger.error("获取播放 URL 失败（含解灰）: \(error)")
                        self.isLoading = false
                        self.refreshPlaybackSurfaceState()
                        self.saveState()
                        if autoPlay {
                            if (error as? APIService.PlaybackError) == .unavailable {
                                AppLogger.info("NCM歌曲无版权，自动跳过: \(song.name)")
                                self.next()
                            } else {
                                self.showPlaybackError(song: song, error: error)
                            }
                        }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self, let url = URL(string: result.url) else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    self.isCurrentSongUnblocked = result.isUnblocked
                    if let actualQuality = result.actualNeteaseQuality {
                        self.soundQuality = actualQuality
                    } else if let cachedNCM, let cachedQuality = SoundQuality(rawValue: cachedNCM) {
                        self.soundQuality = cachedQuality
                    }
                    
                    if result.isUnblocked, let mid = result.unblockedQQMid {
                        self.currentSong?.qqMid = mid
                    }
                    
                    #if DEBUG
                    print("[PlayerManager] NCM歌曲 URL 获取成功: \(song.name), isUnblocked=\(result.isUnblocked)")
                    #endif
                    
                    if SettingsManager.shared.listenAndSave,
                       !DownloadManager.shared.isDownloaded(songId: song.id, isQQ: song.isQQMusic) {
                        DownloadManager.shared.download(song: song, quality: self.soundQuality)
                    }
                    
                    if let ekey = result.qmcEkey {
                        if SettingsManager.shared.qmcDecryptEnabled {
                            AppLogger.info("[QMC] NCM歌曲(实际为QQ音源)需解密: \(song.name)")
                            self.downloadDecryptAndPlay(
                                url: url, ekey: ekey, song: song,
                                autoPlay: autoPlay, startTime: startTime,
                                sessionId: sessionId
                            )
                        } else {
                            self.isLoading = false
                            self.refreshPlaybackSurfaceState()
                            self.saveState()
                            if autoPlay { self.showPlaybackError(song: song, error: APIService.PlaybackError.unavailable) }
                        }
                    } else {
                        self.startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
                    }
                })
        }
    }
    
    func autoNext() {
        next()
    }
    
    func startPlayback(url: URL, autoPlay: Bool = true, startTime: Double = 0, decryptionKey: String? = nil) {
        isLoading = true
        gaplessPreparationWorkItem?.cancel()
        gaplessPreparationWorkItem = nil
        scheduledGaplessPreparationSessionId = nil
        
        if startTime <= 0 {
            self.currentTime = 0
            if self.duration <= 0, let metaMs = self.currentSong?.dt, metaMs > 0 {
                self.duration = Double(metaMs) / 1000.0
            }
        }
        
        // 保存当前播放 URL（用于音频分析等功能）
        self.currentPlayingURL = url.playerInputString
        
        AppLogger.network("开始播放 (FFmpeg): \(url.playerInputString)\(decryptionKey != nil ? " [encrypted]" : "")")
        
        AppLogger.info("startPlayback session=\(playbackSessionId), url=\(url.lastPathComponent)")
        
        playbackStartedAt = Date()
        
        streamPlayer.play(url: url.playerInputString, decryptionKey: decryptionKey)
        
        if !autoPlay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.streamPlayer.pause()
                self?.isPlaying = false
                self?.refreshPlaybackSurfaceState()
                self?.saveState()
            }
        }
        
        // seek 到指定位置（冷启动恢复 / 切换音质时保留进度）
        if startTime > 0 {
            currentTime = startTime
            isSeeking = true
            seekTargetTime = startTime
            seekStartedAt = Date()
            LyricViewModel.shared.updateCurrentTime(startTime)
            let sessionId = playbackSessionId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.playbackSessionId == sessionId else { return }
                self.streamPlayer.seek(to: startTime)
            }
        }
        
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: currentSong)
    }
    
    /// 加载并播放 qcm歌曲（按当前播放策略解析音质）
    private func loadAndPlayQQSong(mid: String, song: Song, autoPlay: Bool, startTime: Double) {
        let sessionId = playbackSessionId
        playbackURLCancellable?.cancel()
        let cachedQQ = QQMusicQuality(rawValue: prefetchedQualityCache.removeValue(forKey: "qq_\(mid)") ?? "")
        let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality && !hasManualQQQualityOverride
        let requestedQuality = shouldAutoSelectHighest ? nil : qqMusicQuality
        
        Task { @MainActor in
            self.playbackURLCancellable = APIService.shared.fetchQQSongUrl(
                mid: mid,
                quality: requestedQuality,
                prefetchedQuality: cachedQQ
            )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    if case .failure(let error) = completion {
                        AppLogger.error("[QQMusic] 获取播放 URL 失败: \(error)")
                        self.isLoading = false
                        self.refreshPlaybackSurfaceState()
                        self.saveState()
                        if autoPlay {
                            self.showPlaybackError(song: song, error: error)
                        }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self, let url = URL(string: result.url) else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    self.isCurrentSongUnblocked = false
                    
                    if let actual = result.actualQQQuality {
                        self.qqMusicQuality = actual
                    }
                    
                    if SettingsManager.shared.listenAndSave,
                       !DownloadManager.shared.isDownloaded(songId: song.id, isQQ: song.isQQMusic) {
                        DownloadManager.shared.downloadQQ(song: song, quality: self.qqMusicQuality)
                    }
                    
                    if let ekey = result.qmcEkey {
                        if SettingsManager.shared.qmcDecryptEnabled {
                            AppLogger.info("[QQMusic] 加密文件，需 QMC 解密: \(song.name)")
                            self.downloadDecryptAndPlay(
                                url: url, ekey: ekey, song: song,
                                autoPlay: autoPlay, startTime: startTime,
                                sessionId: sessionId
                            )
                        } else {
                            self.isLoading = false
                            self.refreshPlaybackSurfaceState()
                            self.saveState()
                            if autoPlay { self.showPlaybackError(song: song, error: APIService.PlaybackError.unavailable) }
                        }
                    } else {
                        AppLogger.info("[QQMusic] 开始播放: \(song.name)")
                        self.startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
                    }
                })
        }
    }
    
    // MARK: - 汽水音乐播放

    private static let qishuiCacheDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qishui_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func loadAndPlayQishuiSong(trackId: Int, song: Song, autoPlay: Bool, startTime: Double) {
        let sessionId = playbackSessionId
        playbackURLCancellable?.cancel()

        AppLogger.info("[Qishui] 获取播放信息: \(song.name) (trackId=\(trackId))")
        isCurrentSongUnblocked = false

        let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality
        let requestedQuality = shouldAutoSelectHighest ? "lossless" : self.qishuiSelectedQuality

        Task { @MainActor in
            self.playbackURLCancellable = APIService.shared.fetchQishuiSongUrl(trackId: trackId, quality: requestedQuality)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self, self.playbackSessionId == sessionId else { return }
                    if case .failure(let error) = completion {
                        AppLogger.error("[Qishui] 获取播放 URL 失败: \(error)")
                        self.isLoading = false
                        self.refreshPlaybackSurfaceState()
                        self.saveState()
                        if autoPlay { self.showPlaybackError(song: song, error: error) }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self, !result.url.isEmpty else { return }
                    guard self.playbackSessionId == sessionId else { return }

                    self.qishuiSelectedQuality = result.quality
                    self.downloadAndPlayQishuiAudio(
                        cdnUrl: result.url,
                        decryptionKey: result.decryptionKey,
                        trackId: trackId,
                        song: song,
                        quality: result.quality,
                        sessionId: sessionId,
                        autoPlay: autoPlay,
                        startTime: startTime
                    )
                })
        }
    }

    private func downloadAndPlayQishuiAudio(
        cdnUrl: String,
        decryptionKey: String?,
        trackId: Int,
        song: Song,
        quality: String,
        sessionId: Int,
        autoPlay: Bool,
        startTime: Double
    ) {
        let ext = decryptionKey != nil ? "enc.mp4" : "m4a"
        let cacheFile = Self.qishuiCacheDir.appendingPathComponent("\(trackId)_\(quality).\(ext)")

        if FileManager.default.fileExists(atPath: cacheFile.path) {
            AppLogger.info("[Qishui] 使用缓存: \(cacheFile.lastPathComponent)")
            startPlayback(url: cacheFile, autoPlay: autoPlay, startTime: startTime, decryptionKey: decryptionKey)
            return
        }

        guard let url = URL(string: cdnUrl) else {
            AppLogger.error("[Qishui] 无效的 CDN URL")
            isLoading = false
            return
        }

        Task {
            do {
                var request = URLRequest(url: url)
                request.setValue("https://www.qishui.com", forHTTPHeaderField: "Referer")
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

                let downloadStart = CFAbsoluteTimeGetCurrent()
                let (data, response) = try await URLSession.shared.data(for: request)
                let elapsed = CFAbsoluteTimeGetCurrent() - downloadStart

                guard self.playbackSessionId == sessionId else { return }

                let httpResponse = response as? HTTPURLResponse
                guard httpResponse?.statusCode == 200, !data.isEmpty else {
                    let code = httpResponse?.statusCode ?? -1
                    throw NSError(domain: "QishuiPlayback", code: code, userInfo: [
                        NSLocalizedDescriptionKey: "CDN 下载失败 HTTP \(code)"
                    ])
                }

                try data.write(to: cacheFile)
                AppLogger.info("[Qishui] 下载完成 (\(data.count / 1024)KB, \(String(format: "%.1f", elapsed))s), key=\(decryptionKey?.prefix(8) ?? "none")")

                await MainActor.run {
                    guard self.playbackSessionId == sessionId else { return }
                    self.startPlayback(url: cacheFile, autoPlay: autoPlay, startTime: startTime, decryptionKey: decryptionKey)
                }
            } catch {
                AppLogger.error("[Qishui] 下载失败: \(error.localizedDescription)")
                await MainActor.run {
                    guard self.playbackSessionId == sessionId else { return }
                    self.isLoading = false
                    self.refreshPlaybackSurfaceState()
                    self.saveState()
                    if autoPlay { self.showPlaybackError(song: song, error: error) }
                }
            }
        }
    }

    // MARK: - QMC 解密播放
    
    private static let qmcCacheDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qmc_decrypted", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    private func cachedQMCFileURL(for songId: Int) -> URL? {
        let flacCache = Self.qmcCacheDir.appendingPathComponent("\(songId).flac")
        if FileManager.default.fileExists(atPath: flacCache.path) {
            return flacCache
        }
        
        let oggCache = Self.qmcCacheDir.appendingPathComponent("\(songId).ogg")
        if FileManager.default.fileExists(atPath: oggCache.path) {
            return oggCache
        }
        
        return nil
    }
    
    private func prepareDecryptedNextTrack(url: URL, ekey: String, song: Song, sessionId: Int) {
        guard isGaplessPlaybackEnabled else { return }

        if let cachedFile = cachedQMCFileURL(for: song.id) {
            streamPlayer.prepareNext(url: cachedFile.playerInputString)
            return
        }
        
        Task { [weak self] in
            guard let self else { return }
            
            do {
                let ext = url.pathExtension.contains("mflac") ? "flac"
                         : url.pathExtension.contains("mgg") ? "ogg"
                         : "flac"
                let cachedFile = Self.qmcCacheDir.appendingPathComponent("\(song.id).\(ext)")
                
                if FileManager.default.fileExists(atPath: cachedFile.path),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFile.path),
                   let size = attrs[.size] as? Int, size > 1024 {
                    guard self.playbackSessionId == sessionId, self.isGaplessPlaybackEnabled else { return }
                    AppLogger.info("[QMC] 命中缓存，预加载下一首: \(song.name)")
                    self.streamPlayer.prepareNext(url: cachedFile.playerInputString)
                    return
                }
                
                let decryptor = try QMCDecryptor.create(ekey: ekey)
                let (data, response) = try await URLSession.shared.data(from: url)
                guard self.playbackSessionId == sessionId, self.isGaplessPlaybackEnabled else { return }
                
                let httpResponse = response as? HTTPURLResponse
                guard httpResponse?.statusCode == 200 || httpResponse == nil else { return }
                
                try await Task.detached(priority: .utility) {
                    let decrypted = decryptor.decryptData(data)
                    try decrypted.write(to: cachedFile)
                }.value
                
                guard self.playbackSessionId == sessionId, self.isGaplessPlaybackEnabled else { return }
                AppLogger.info("[QMC] 解密完成，预加载下一首: \(song.name)")
                self.streamPlayer.prepareNext(url: cachedFile.playerInputString)
            } catch {
                guard self.playbackSessionId == sessionId else { return }
                AppLogger.warning("[QMC] 预加载下一首解密失败: \(song.name) - \(error.localizedDescription)")
            }
        }
    }

    /// 下载加密文件 → QMC 解密 → 保存临时文件 → 播放（带缓存）
    private func downloadDecryptAndPlay(
        url: URL, ekey: String, song: Song,
        autoPlay: Bool, startTime: Double, sessionId: Int
    ) {
        Task {
            do {
                let ext = url.pathExtension.contains("mflac") ? "flac"
                         : url.pathExtension.contains("mgg") ? "ogg"
                         : "flac"
                let cachedFile = Self.qmcCacheDir.appendingPathComponent("\(song.id).\(ext)")

                if FileManager.default.fileExists(atPath: cachedFile.path),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFile.path),
                   let size = attrs[.size] as? Int, size > 1024 {
                    AppLogger.success("[QMC] 命中缓存，跳过下载解密: \(cachedFile.lastPathComponent) (\(size / 1024)KB)")
                    guard self.playbackSessionId == sessionId else { return }
                    self.startPlayback(url: cachedFile, autoPlay: autoPlay, startTime: startTime)
                    return
                }

                let decryptor = try QMCDecryptor.create(ekey: ekey)

                AppLogger.info("[QMC] 开始下载加密文件...")
                let downloadStart = CFAbsoluteTimeGetCurrent()
                let (data, response) = try await URLSession.shared.data(from: url)
                let downloadTime = CFAbsoluteTimeGetCurrent() - downloadStart

                guard self.playbackSessionId == sessionId else { return }

                let httpResponse = response as? HTTPURLResponse
                guard httpResponse?.statusCode == 200 || httpResponse == nil else {
                    throw QMCError.decryptionFailed
                }

                AppLogger.info("[QMC] 下载完成 (\(data.count / 1024)KB，耗时 \(String(format: "%.1f", downloadTime))s)，后台解密中...")

                let outFile = cachedFile
                let decryptStart = CFAbsoluteTimeGetCurrent()
                try await Task.detached(priority: .userInitiated) {
                    let decrypted = decryptor.decryptData(data)
                    try decrypted.write(to: outFile)
                }.value
                let decryptTime = CFAbsoluteTimeGetCurrent() - decryptStart

                AppLogger.success("[QMC] 解密完成 (耗时 \(String(format: "%.1f", decryptTime))s): \(cachedFile.lastPathComponent)")

                await MainActor.run {
                    guard self.playbackSessionId == sessionId else { return }
                    self.startPlayback(url: cachedFile, autoPlay: autoPlay, startTime: startTime)
                }
            } catch {
                AppLogger.error("[QMC] 解密播放失败: \(error.localizedDescription)")
                await MainActor.run {
                    guard self.playbackSessionId == sessionId else { return }
                    self.isLoading = false
                    self.refreshPlaybackSurfaceState()
                    self.saveState()
                    if autoPlay {
                        self.showPlaybackError(song: song, error: error)
                    }
                }
            }
        }
    }
    
    // MARK: - QMC 预缓存下一首

    /// 当前歌曲播放后，后台预下载+解密下一首 qcm加密歌曲
    func prefetchNextQMCTrack() {
        guard isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard mode != .loopSingle else { return }

        let list = currentContextList
        guard !list.isEmpty else { return }

        var nextIndex = contextIndex + 1
        if nextIndex >= list.count { nextIndex = 0 }
        let nextSong = list[nextIndex]

        guard nextSong.isQQMusic, let mid = nextSong.qqMid else { return }

        if localPlaybackURL(for: nextSong) != nil {
            return
        }

        let flacCache = Self.qmcCacheDir.appendingPathComponent("\(nextSong.id).flac")
        let oggCache = Self.qmcCacheDir.appendingPathComponent("\(nextSong.id).ogg")
        if FileManager.default.fileExists(atPath: flacCache.path) ||
           FileManager.default.fileExists(atPath: oggCache.path) {
            AppLogger.info("[QMC预缓存] 下一首已有缓存，跳过: \(nextSong.name)")
            return
        }

        let quality = qqMusicQuality
        let songName = nextSong.name
        let songId = nextSong.id

        qmcPrefetchTask = Task {
            do {
                AppLogger.info("[QMC预缓存] 开始预缓存下一首: \(songName)")

                let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<APIService.SongUrlResult, Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = APIService.shared.fetchQQSongUrl(
                        mid: mid,
                        quality: quality
                    )
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                cont.resume(throwing: error)
                            }
                            _ = cancellable
                        }, receiveValue: { result in
                            cont.resume(returning: result)
                        })
                }

                guard !Task.isCancelled else { return }

                guard let ekey = result.qmcEkey, let url = URL(string: result.url) else {
                    AppLogger.info("[QMC预缓存] \(songName) 非加密，无需预缓存")
                    return
                }

                let decryptor = try QMCDecryptor.create(ekey: ekey)

                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }

                let httpResponse = response as? HTTPURLResponse
                guard httpResponse?.statusCode == 200 || httpResponse == nil else { return }

                let ext = url.pathExtension.contains("mflac") ? "flac"
                         : url.pathExtension.contains("mgg") ? "ogg"
                         : "flac"
                let outFile = Self.qmcCacheDir.appendingPathComponent("\(songId).\(ext)")

                try await Task.detached(priority: .utility) {
                    let decrypted = decryptor.decryptData(data)
                    try decrypted.write(to: outFile)
                }.value

                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: outFile)
                    return
                }

                AppLogger.success("[QMC预缓存] 预缓存完成: \(songName) (\(data.count / 1024)KB)")
            } catch {
                if !Task.isCancelled {
                    AppLogger.warning("[QMC预缓存] 预缓存失败: \(songName) - \(error.localizedDescription)")
                }
            }
        }
    }

    /// 弹出资源失效提示
    private func showResourceUnavailable(song: Song) {
        AlertManager.shared.show(
            title: playerInternalText("playback_resource_expired_title"),
            message: playerInternalFormat("playback_resource_expired_message", song.name, song.artistName),
            primaryButtonTitle: playerInternalText("common_confirm"),
            secondaryButtonTitle: playerInternalText("playback_next_track"),
            primaryAction: {},
            secondaryAction: { [weak self] in
                self?.next()
            }
        )
    }
    
    // MARK: - 播放失败提示
    
    /// 弹出播放失败的具体错误提示（不自动跳过）
    func showPlaybackError(song: Song, error: Error) {
        let playbackError = error as? APIService.PlaybackError
        isPlaying = false
        isLoading = false
        refreshPlaybackSurfaceState()
        saveState()
        
        if playbackError == .tokenRequired {
            AlertManager.shared.showInput(
                title: playerInternalText("playback_token_prompt_title"),
                message: playerInternalText("playback_token_prompt_message"),
                placeholder: playerInternalText("access_token_input_placeholder"),
                primaryButtonTitle: playerInternalText("common_confirm"),
                secondaryButtonTitle: playerInternalText("common_later"),
                onConfirm: { token in
                    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    APIService.shared.applyToken(trimmed)
                    Task {
                        let result = await APIService.shared.verifyToken()
                        await MainActor.run {
                            switch result {
                            case .valid(let name):
                                AlertManager.shared.show(
                                    title: playerInternalText("access_validation_success_title"),
                                    message: name.isEmpty ? playerInternalText("access_validation_success_message") : playerInternalFormat("access_validation_success_message_name", name),
                                    primaryButtonTitle: playerInternalText("common_ok"),
                                    primaryAction: { AlertManager.shared.dismiss() }
                                )
                            case .validationDisabled:
                                AlertManager.shared.dismiss()
                            case .invalid, .missing:
                                SecureConfig.apiToken = nil
                                AlertManager.shared.show(
                                    title: playerInternalText("access_invalid_title"),
                                    message: playerInternalText("access_invalid_message"),
                                    primaryButtonTitle: playerInternalText("common_ok"),
                                    primaryAction: { AlertManager.shared.dismiss() }
                                )
                            case .expired:
                                AlertManager.shared.show(
                                    title: String(localized: "Token 已过期"),
                                    message: String(localized: "您输入的 Token 已经过期，请获取新的 Token 或者前往设置重新授权。"),
                                    primaryButtonTitle: playerInternalText("common_ok"),
                                    primaryAction: { AlertManager.shared.dismiss() }
                                )
                            case .deviceMismatch:
                                SecureConfig.apiToken = nil
                                AlertManager.shared.show(
                                    title: String(localized: "设备不匹配"),
                                    message: String(localized: "此 Token 已绑定到其他设备，无法在当前设备使用。请联系管理员或使用正确的 Token。"),
                                    primaryButtonTitle: playerInternalText("common_ok"),
                                    primaryAction: { AlertManager.shared.dismiss() }
                                )
                            case .networkError:
                                AlertManager.shared.show(
                                    title: playerInternalText("access_network_error_title"),
                                    message: playerInternalText("access_network_error_message"),
                                    primaryButtonTitle: playerInternalText("common_ok"),
                                    primaryAction: { AlertManager.shared.dismiss() }
                                )
                            }
                        }
                    }
                }
            )
            return
        }
        
        if playbackError == .tokenExpired {
            AlertManager.shared.show(
                title: String(localized: "Token 已过期"),
                message: String(localized: "当前授权的 Token 已过期，无法继续播放。请获取新的 Token 并在设置中重新授权。"),
                primaryButtonTitle: playerInternalText("common_ok"),
                primaryAction: { AlertManager.shared.dismiss() }
            )
            return
        }
        
        let errorMessage: String
        switch playbackError {
        case .unavailable:
            errorMessage = playerInternalText("playback_unavailable_message")
        case .networkError:
            errorMessage = playerInternalText("playback_network_message")
        default:
            errorMessage = error.localizedDescription
        }
        
        AlertManager.shared.show(
            title: playerInternalText("playback_cannot_play_title"),
            message: playerInternalFormat("playback_cannot_play_message", song.name, song.artistName, errorMessage),
            primaryButtonTitle: playerInternalText("common_confirm"),
            secondaryButtonTitle: playerInternalText("playback_next_track"),
            primaryAction: {},
            secondaryAction: { [weak self] in
                self?.next()
            }
        )
    }
    
    private func loadDynamicCover(songId: Int) {
        APIService.shared.fetchSongDynamicCover(id: songId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] url in
                guard let self = self, self.currentSong?.id == songId else { return }
                self.dynamicCoverUrl = url
            })
            .store(in: &cancellables)
    }
}
