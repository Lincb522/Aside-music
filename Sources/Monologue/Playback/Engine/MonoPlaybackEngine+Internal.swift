// 播放呈现事务核心：队列事务快照、呈现提交/回滚、播放结束处理、
// 会话作废与共享查询（下一首、shuffle、本地文件、歌词/封面加载）。
// 取址/下载管线见 Playback/MediaSourceResolver.swift，
// 无缝切歌见 Playback/GaplessEngine.swift。

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

    // MARK: - 播放身份（实例转发，实现见 Playback/PlaybackModels.swift）

    func matchesPlaybackTarget(_ candidate: Song?, expected: Song) -> Bool {
        Self.matchesPlaybackTarget(candidate, expected: expected)
    }

    func playbackIdentityKey(for song: Song) -> String {
        Self.playbackIdentityKey(for: song)
    }

    // MARK: - 共享查询与附加内容

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
        return DownloadManager.shared.localFileURL(for: song)
    }

    /// 歌曲列表/搜索结果已携带音质元数据时直接复用，省去单独的音质查询。
    /// 元数据缺失时返回 nil，API 仍会走完整的最高可用音质探测，避免误降到标准音质。
    func modelReportedNeteaseQuality(for song: Song) -> SoundQuality? {
        guard !song.isQQMusic, !song.isQishui, !song.isAppleMusic else {
            return nil
        }
        guard song.h != nil || song.m != nil || song.l != nil
                || song.sq != nil || song.hr != nil || song.privilege != nil else {
            return nil
        }
        return song.maxQuality
    }

    /// 根据歌曲来源加载动态封面（仅ncm）
    func loadSongExtras(for song: Song) {
        dynamicCoverUrl = nil
        if !song.isQQMusic && !song.isQishui && !song.isAppleMusic {
            loadDynamicCover(songId: song.id)
        }
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

    // MARK: - 队列导航

    func pushSongToBackStack(_ song: Song) {
        if matchesPlaybackTarget(playbackBackStack.last, expected: song) {
            return
        }
        playbackBackStack.append(song)
        if playbackBackStack.count > maxBackStackSize {
            playbackBackStack.removeFirst(playbackBackStack.count - maxBackStackSize)
        }
    }

    func pushSongToForwardStack(_ song: Song) {
        if matchesPlaybackTarget(playbackForwardStack.last, expected: song) {
            return
        }
        playbackForwardStack.append(song)
        if playbackForwardStack.count > maxBackStackSize {
            playbackForwardStack.removeFirst(playbackForwardStack.count - maxBackStackSize)
        }
    }

    func rememberRecentPlaybackInput(
        _ input: String,
        decryptionKey: String?,
        for song: Song,
        preserveResolvedAt: Bool = false
    ) {
        guard !input.isEmpty else { return }
        let identity = playbackIdentityKey(for: song)
        let resolvedAt: Date
        if preserveResolvedAt,
           let existing = recentPlaybackInputs[identity],
           existing.input == input {
            resolvedAt = existing.resolvedAt
        } else {
            resolvedAt = Date()
        }
        recentPlaybackInputs[identity] = RecentPlaybackInput(
            input: input,
            decryptionKey: decryptionKey,
            resolvedQuality: resolvedPlaybackQualitySnapshot(for: song),
            resolvedAt: resolvedAt
        )
        if recentPlaybackInputs.count > 12 {
            let retained = recentPlaybackInputs
                .sorted { $0.value.resolvedAt > $1.value.resolvedAt }
                .prefix(12)
            recentPlaybackInputs = Dictionary(
                uniqueKeysWithValues: retained.map { ($0.key, $0.value) }
            )
        }
    }

    func recentPlaybackInput(for song: Song) -> RecentPlaybackInput? {
        let identity = playbackIdentityKey(for: song)
        guard let cached = recentPlaybackInputs[identity] else { return nil }
        if cached.input.hasPrefix("http://") || cached.input.hasPrefix("https://") {
            guard Date().timeIntervalSince(cached.resolvedAt) < PlaybackURLCache.freshTTL else {
                recentPlaybackInputs.removeValue(forKey: identity)
                return nil
            }
        } else {
            guard FileManager.default.fileExists(atPath: cached.input) else {
                recentPlaybackInputs.removeValue(forKey: identity)
                return nil
            }
        }
        return cached
    }

    private func resolvedPlaybackQualitySnapshot(for song: Song) -> ResolvedPlaybackQuality? {
        guard !song.isAppleMusic else { return nil }
        if matchesPlaybackTarget(pendingPlaybackPresentationSong, expected: song),
           let pendingPlaybackPresentationResolvedQuality {
            return pendingPlaybackPresentationResolvedQuality
        }
        if song.isQQMusic, let mid = song.qqMid {
            return .qq(mid: mid, quality: qqMusicQuality)
        }
        if song.isQishui, let trackId = song.qishuiTrackId {
            return .qishui(trackId: trackId, quality: qishuiSelectedQuality)
        }
        return .netease(songId: song.id, quality: soundQuality)
    }

    func upcomingPlaybackSong() -> Song? {
        let list = currentContextList
        guard !list.isEmpty else { return nil }

        if let currentSong,
           let candidate = playbackForwardStack.last,
           !matchesPlaybackTarget(candidate, expected: currentSong) {
            return candidate
        }

        let safeCurrentIndex = (contextIndex >= 0 && contextIndex < list.count) ? contextIndex : 0
        let allowsWrapping = queueExhaustionBehavior == .loop
        let maximumSteps = allowsWrapping
            ? list.count
            : max(0, list.count - safeCurrentIndex - 1)
        guard maximumSteps > 0 else { return nil }

        for offset in 1...maximumSteps {
            let rawIndex = safeCurrentIndex + offset
            if !allowsWrapping, rawIndex >= list.count {
                break
            }
            let candidate = list[rawIndex % list.count]
            if let currentSong,
               matchesPlaybackTarget(candidate, expected: currentSong) {
                continue
            }
            return candidate
        }
        return nil
    }

    func stopAfterQueueExhausted() {
        // 队列播完：结算听歌统计
        ListeningStatsRecorder.shared.finalizeSession()
        pendingPlaybackQueueSnapshot = nil
        pendingPlaybackQueueCommitSnapshot = nil
        invalidateInFlightPlaybackWork(reason: "queue exhausted")
        cancelPlaybackFade(restoreVolume: false)
        clearPlaybackStartFade(restoreVolume: true)
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        clearPendingPlaybackPresentation()
        disarmGaplessEngine()
        gapless.cancelNextTrackResolution()
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
        endTransitionKeepAlive()
        refreshPlaybackSurfaceState()
        saveState()
        syncWidgetState()
    }

    func applyAutomaticTransitionNavigationState(to song: Song) {
        guard let current = currentSong,
              !matchesPlaybackTarget(current, expected: song) else { return }

        pushSongToBackStack(current)
        if matchesPlaybackTarget(playbackForwardStack.last, expected: song) {
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
        if let index = shuffled.firstIndex(where: {
            matchesPlaybackTarget($0, expected: current)
        }) {
            shuffled.remove(at: index)
            shuffled.insert(current, at: 0)
        }
        shuffledContext = shuffled
        contextIndex = 0
    }

    // MARK: - 播放结束处理

    /// Mono播放引擎底层 SDK 播放结束回调（由 delegate adapter 调用）
    func playerDidFinishPlaying() {
        guard !isHandlingPlaybackFinish else {
            AppLogger.warning("playerDidFinishPlaying 重入，忽略")
            return
        }
        isHandlingPlaybackFinish = true
        defer { isHandlingPlaybackFinish = false }

        AppLogger.info("playerDidFinishPlaying 被调用, currentTime=\(currentTime), duration=\(duration), song=\(currentSong?.name ?? "nil")")
        // 音频输出已停止，先申请后台保活，确保切下一首的网络请求能完成
        beginTransitionKeepAlive(reason: "playerDidFinishPlaying")
        if pendingSleepStopAfterCurrentTrack {
            pendingSleepStopAfterCurrentTrack = false
            stopAfterQueueExhausted()
            return
        }
        // 用户已经点了下一曲，但目标仍在取址 / 下载 / preroll。此时旧歌自然
        // 结束也不能再推进一次队列；等待原请求完成后直接播目标歌曲。
        if pendingPlaybackPresentationSong != nil {
            AppLogger.info("当前歌曲已结束，等待手动选择的目标歌曲完成装载")
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

    func autoNext() {
        next()
    }

    // MARK: - 播放呈现事务（队列快照 + 出声提交）

    func clearPendingPlaybackPresentation() {
        manualSwitchPreparationTask?.cancel()
        manualSwitchPreparationTask = nil
        manualPreparedSwitchSessionId = nil
        pendingPlaybackPresentationSong = nil
        pendingPlaybackPresentationSessionId = nil
        pendingPlaybackPresentationInput = nil
        pendingPlaybackPresentationDecryptionKey = nil
        pendingPlaybackPresentationStartTime = 0
        pendingPlaybackPresentationIsUnblocked = false
        pendingPlaybackPresentationResolvedQuality = nil
        pendingPlaybackPresentationDuration = nil
    }

    private func capturePlaybackQueueTransactionSnapshot() -> PlaybackQueueTransactionSnapshot {
        PlaybackQueueTransactionSnapshot(
            context: context,
            contextIndex: contextIndex,
            shuffledContext: shuffledContext,
            playSource: playSource,
            queueExhaustionBehavior: queueExhaustionBehavior,
            mode: mode,
            playContext: playContext,
            playbackBackStack: playbackBackStack,
            playbackForwardStack: playbackForwardStack,
            savedMusicContext: savedMusicContext,
            savedMusicContextIndex: savedMusicContextIndex,
            savedMusicShuffledContext: savedMusicShuffledContext,
            savedMusicMode: savedMusicMode,
            savedMusicSong: savedMusicSong,
            savedPodcastContext: savedPodcastContext,
            savedPodcastContextIndex: savedPodcastContextIndex,
            savedPodcastRadioId: savedPodcastRadioId,
            savedPodcastSong: savedPodcastSong
        )
    }

    private func applyPlaybackQueueTransactionSnapshot(
        _ snapshot: PlaybackQueueTransactionSnapshot
    ) {
        context = snapshot.context
        contextIndex = snapshot.contextIndex
        shuffledContext = snapshot.shuffledContext
        playSource = snapshot.playSource
        queueExhaustionBehavior = snapshot.queueExhaustionBehavior
        mode = snapshot.mode
        playContext = snapshot.playContext
        playbackBackStack = snapshot.playbackBackStack
        playbackForwardStack = snapshot.playbackForwardStack
        savedMusicContext = snapshot.savedMusicContext
        savedMusicContextIndex = snapshot.savedMusicContextIndex
        savedMusicShuffledContext = snapshot.savedMusicShuffledContext
        savedMusicMode = snapshot.savedMusicMode
        savedMusicSong = snapshot.savedMusicSong
        savedPodcastContext = snapshot.savedPodcastContext
        savedPodcastContextIndex = snapshot.savedPodcastContextIndex
        savedPodcastRadioId = snapshot.savedPodcastRadioId
        savedPodcastSong = snapshot.savedPodcastSong
    }

    func stagePlaybackQueueMutationIfNeeded() {
        guard currentSong != nil, pendingPlaybackQueueSnapshot == nil else { return }
        pendingPlaybackQueueSnapshot = capturePlaybackQueueTransactionSnapshot()
    }

    /// API 层已经构造好目标队列，但旧歌仍在出声。把目标队列暂存起来，
    /// 对外恢复旧队列；待 Mono 确认真正出声后再一次性提交目标状态。
    func deferPendingPlaybackQueueMutationUntilCommit() {
        guard let rollbackSnapshot = pendingPlaybackQueueSnapshot else { return }
        pendingPlaybackQueueCommitSnapshot = capturePlaybackQueueTransactionSnapshot()
        applyPlaybackQueueTransactionSnapshot(rollbackSnapshot)
    }

    /// 点歌事务尚未提交时，目标队列的播放来源（取址策略以目标为准）
    var playbackTargetSource: PlaySource {
        pendingPlaybackQueueCommitSnapshot?.playSource ?? playSource
    }

    func commitPendingPlaybackQueueMutation() {
        if let commitSnapshot = pendingPlaybackQueueCommitSnapshot {
            applyPlaybackQueueTransactionSnapshot(commitSnapshot)
        }
        pendingPlaybackQueueSnapshot = nil
        pendingPlaybackQueueCommitSnapshot = nil
    }

    func rollbackPendingPlaybackQueueMutationIfNeeded() {
        guard let snapshot = pendingPlaybackQueueSnapshot else { return }
        applyPlaybackQueueTransactionSnapshot(snapshot)
        pendingPlaybackQueueSnapshot = nil
        pendingPlaybackQueueCommitSnapshot = nil
    }

    /// 将一首已经具备可播条件的歌曲提交给界面与系统 Now Playing。
    /// 手动切歌时由 Mono 的 `.playing` 回调调用，保证声音和元数据同拍切换。
    func publishPlaybackPresentation(
        song: Song,
        startTime: Double,
        isUnblocked: Bool
    ) {
        commitPendingPlaybackQueueMutation()
        let isNewPresentation = !matchesPlaybackTarget(currentSong, expected: song)
        if isNewPresentation {
            engineReportedDuration = nil
        }
        currentSong = song
        if let index = currentContextList.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            contextIndex = index
        }
        currentTime = max(0, startTime)
        duration = engineReportedDuration
            ?? song.dt.map { Double($0) / 1000.0 }
            ?? 0
        isCurrentSongUnblocked = isUnblocked

        fetchLyricsForSong(song)
        loadSongExtras(for: song)
        if isNewPresentation {
            addToHistory(song: song)
            if !song.isQQMusic && !song.isQishui && !song.isAppleMusic {
                scrobbleToCloud(song: song)
            }
        }

        saveState()
        updateNowPlayingInfo()
        updateNowPlayingArtwork(for: song)
        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor in
            await LyricsLiveActivityManager.shared.sync(
                with: self,
                forceRestart: isNewPresentation
            )
        }
        #endif
    }

    /// MusicKit 已经准备并接管输出后，按与 Mono `.playing` 回调相同的
    /// 事务边界提交界面、队列和系统 Now Playing。
    func commitAppleMusicPlaybackPresentation(
        song: Song,
        startTime: Double,
        autoPlay: Bool,
        sessionId: Int
    ) {
        guard playbackSessionId == sessionId,
              appleMusicPlayback.matches(song) else { return }

        if pendingPlaybackPresentationSessionId == sessionId,
           matchesPlaybackTarget(pendingPlaybackPresentationSong, expected: song) {
            clearPendingPlaybackPresentation()
            commitPendingPlaybackQueueMutation()
        }

        currentPlayingURL = "apple-music:\(song.appleMusicCatalogID ?? String(song.id))"
        currentPlayingDecryptionKey = nil
        playbackURLResolvedAt = Date()
        engineReportedDuration = nil
        streamInfo = nil
        isCurrentPlaybackUsingLocalFile = false
        isCurrentSongUnblocked = false
        isPlaying = autoPlay
        isLoading = false
        lastPausedAt = autoPlay ? nil : Date()

        publishPlaybackPresentation(
            song: song,
            startTime: startTime,
            isUnblocked: false
        )
        refreshPlaybackSurfaceState()
        saveState()
        AppLogger.info(
            "[AppleMusic] MusicKit 已出声，提交歌曲界面: \(song.name)",
            step: "apple-music.presentation"
        )
    }

    func commitPendingPlaybackPresentationIfNeeded(
        sessionId: Int,
        engineInput: String?
    ) {
        guard pendingPlaybackPresentationSessionId == sessionId,
              let song = pendingPlaybackPresentationSong else { return }
        guard let expectedInput = pendingPlaybackPresentationInput,
              let engineInput,
              engineInput == expectedInput else {
            AppLogger.warning(
                "[PlaybackPresentation] 忽略不匹配的出声回调 target=\(song.name) expected=\(pendingPlaybackPresentationInput ?? "nil") engine=\(engineInput ?? "nil") session=\(sessionId)",
                step: "playback.presentation.input-mismatch"
            )
            return
        }

        let startTime = pendingPlaybackPresentationStartTime
        let isUnblocked = pendingPlaybackPresentationIsUnblocked
        let resolvedQuality = pendingPlaybackPresentationResolvedQuality
        let decryptionKey = pendingPlaybackPresentationDecryptionKey
        let reportedDuration = pendingPlaybackPresentationDuration
        clearPendingPlaybackPresentation()
        commitPendingPlaybackQueueMutation()
        currentPlayingURL = engineInput
        playbackURLResolvedAt = Date()
        currentPlayingDecryptionKey = decryptionKey
        applyResolvedPlaybackQuality(resolvedQuality, for: song)
        publishPlaybackPresentation(
            song: song,
            startTime: startTime,
            isUnblocked: isUnblocked
        )
        if let reportedDuration,
           reportedDuration.isFinite,
           reportedDuration > 0 {
            engineReportedDuration = reportedDuration
            duration = reportedDuration
            updateNowPlayingInfo()
        }
        AppLogger.info("播放管线已出声，提交歌曲界面: \(song.name)")
    }

    func applyResolvedPlaybackQuality(_ resolved: ResolvedPlaybackQuality?, for song: Song) {
        guard let resolved else { return }
        switch resolved {
        case .netease(let songId, let quality) where !song.isQQMusic && song.id == songId:
            soundQuality = quality
        case .qq(let mid, let quality) where song.isQQMusic && song.qqMid == mid:
            qqMusicQuality = quality
        case .qishui(let trackId, let quality) where song.isQishui && song.qishuiTrackId == trackId:
            qishuiSelectedQuality = quality
        default:
            break
        }
    }

    /// Mono can keep one engine generation alive across a prepared-track switch,
    /// while app-level async work still needs a new session boundary.
    func advanceApplicationPlaybackSession() {
        playbackSessionId += 1
        delegateAdapter?.currentSessionId = playbackSessionId
    }

    /// At the transition callback the new track may already be audible because
    /// crossfade switches metadata at its midpoint. Reject an old-track clock if
    /// a non-crossfade notification fires a fraction early.
    func currentEngineTransitionTime() -> Double {
        let time = streamPlayer.currentTime
        let upperBound = max(
            3.0,
            Double(streamPlayer.currentCrossfadeDuration) + 1.0
        )
        guard time.isFinite,
              !time.isNaN,
              time >= 0,
              time <= upperBound else { return 0 }
        return time
    }

    /// 手动切歌未命中既有预热结果时，Mono 会让旧歌继续播放，同时在 next
    /// 通道装配目标歌曲。该回调只在热切真正完成后提交界面。
    func completeManualPreparedSwitch(sessionId: Int, engineInput: String?) {
        guard manualPreparedSwitchSessionId == sessionId,
              pendingPlaybackPresentationSessionId == sessionId else { return }
        guard let expectedInput = pendingPlaybackPresentationInput,
              let engineInput,
              engineInput == expectedInput else {
            AppLogger.warning(
                "[ManualSwitch] 忽略非目标管线 transition expected=\(pendingPlaybackPresentationInput ?? "nil") engine=\(engineInput ?? "nil") session=\(sessionId)",
                step: "playback.manual-switch.input-mismatch"
            )
            return
        }

        mediaResolver.completeLoadIfCurrent(
            sessionId: sessionId,
            engineInput: engineInput
        )
        manualSwitchPreparationTask?.cancel()
        manualSwitchPreparationTask = nil
        manualPreparedSwitchSessionId = nil
        // 正常 transition 已经消费了 next；若这是自动切歌的迟到通知，
        // 这里会顺便取消刚刚重复装入的同曲管线，防止同一首从头再播一次。
        streamPlayer.cancelNextPreparation()

        let preparedStreamInfo = streamPlayer.streamInfo
        if let info = preparedStreamInfo {
            streamInfo = info
        }
        let transitionTime = currentEngineTransitionTime()
        pendingPlaybackPresentationStartTime = transitionTime
        isPlaying = true
        isLoading = false
        commitPendingPlaybackPresentationIfNeeded(
            sessionId: sessionId,
            engineInput: engineInput
        )
        if let streamDuration = preparedStreamInfo?.duration, streamDuration > 0 {
            engineReportedDuration = streamDuration
            duration = streamDuration
        }
        LyricViewModel.shared.updateCurrentTime(transitionTime)
        endTransitionKeepAlive()
        refreshPlaybackSurfaceState()
        syncWidgetState()

        disarmGaplessEngine()
        gapless.scheduledGaplessPreparationSessionId = nil
        scheduleGaplessMediaPrefetchIfNeeded()
    }

    func updatePlaybackPresentationResolution(
        song: Song,
        sessionId: Int,
        isUnblocked: Bool,
        unblockedQQMid: String? = nil
    ) {
        if pendingPlaybackPresentationSessionId == sessionId,
           var pendingSong = pendingPlaybackPresentationSong,
           matchesPlaybackTarget(pendingSong, expected: song) {
            if let unblockedQQMid {
                pendingSong.qqMid = unblockedQQMid
                pendingPlaybackPresentationSong = pendingSong
            }
            pendingPlaybackPresentationIsUnblocked = isUnblocked
            return
        }

        guard matchesPlaybackTarget(currentSong, expected: song) else { return }
        if let unblockedQQMid {
            currentSong?.qqMid = unblockedQQMid
        }
        isCurrentSongUnblocked = isUnblocked
    }

    /// 取址或装载失败时放弃尚未展示的新歌，继续保留当前歌曲界面。
    @discardableResult
    func discardPendingPlaybackPresentationIfNeeded(song: Song, sessionId: Int) -> Bool {
        guard pendingPlaybackPresentationSessionId == sessionId,
              matchesPlaybackTarget(pendingPlaybackPresentationSong, expected: song) else { return false }
        rollbackPendingPlaybackQueueMutationIfNeeded()
        clearPendingPlaybackPresentation()
        if let currentSong,
           let currentIndex = currentContextList.firstIndex(where: {
               matchesPlaybackTarget($0, expected: currentSong)
           }) {
            contextIndex = currentIndex
        }
        return currentSong != nil
    }

    // MARK: - 播放事务作废

    /// 作废仍在进行的播放事务。所有显式切歌、停止、关闭播放器和外接输出断开
    /// 都必须先经过这里，避免旧取址/下载/预装配回调重新接管最新播放状态。
    func invalidateInFlightPlaybackWork(
        reason: String,
        advanceSession: Bool = true,
        clearPresentation: Bool = true
    ) {
        if advanceSession {
            playbackSessionId &+= 1
            delegateAdapter?.currentSessionId = playbackSessionId
        }

        mediaResolver.cancelPlaybackURLResolution()
        mediaResolver.cancelActiveMediaLoad()
        mediaResolver.cancelLoadWatchdog()
        gapless.cancelNextTrackResolution()
        gapless.cancelQmcPrefetch()
        gapless.cancelScheduledMediaPrefetch()
        qualitySwitchCancellable?.cancel()
        qualitySwitchCancellable = nil
        manualSwitchPreparationTask?.cancel()
        manualSwitchPreparationTask = nil
        manualPreparedSwitchSessionId = nil
        qualitySwitchPollWorkItem?.cancel()
        qualitySwitchPollWorkItem = nil
        qualitySwitchTimeoutTask?.cancel()
        qualitySwitchTimeoutTask = nil
        seekDebounceWorkItem?.cancel()
        seekDebounceWorkItem = nil

        streamPlayer.cancelNextPreparation()
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        pendingTransitionSessionId = 0
        pendingQualitySwitchSeek = nil
        disarmGaplessEngine()

        isSeeking = false
        seekTargetTime = nil
        seekStartedAt = nil
        seekRetryCount = 0
        if clearPresentation {
            clearPendingPlaybackPresentation()
        }

        // 旧歌仍在出声时，队列游标也必须回到旧歌。目标歌曲只有真正出声后
        // 才会由 publishPlaybackPresentation 再次提交游标。
        if let currentSong,
           let currentIndex = currentContextList.firstIndex(where: {
               matchesPlaybackTarget($0, expected: currentSong)
           }) {
            contextIndex = currentIndex
        }

        AppLogger.debug(
            "[PlaybackTransaction] 已作废旧播放事务 session=\(playbackSessionId) reason=\(reason)"
        )
    }

    /// Cancels a loading/track-switch transaction in response to an explicit
    /// pause command. The pipeline that is already audible is preserved; a
    /// target that has not started producing sound is discarded.
    func cancelLoadingPlaybackForUserPause() {
        guard isLoading else { return }

        let engineState = streamPlayer.state
        let engineInput = streamPlayer.currentPlaybackInput

        // The prepared target may already own the decoder even if its delegate
        // callback is waiting on the main queue. Commit only when it is actually
        // playing so UI and audio still describe the same paused song.
        if engineState == .playing,
           streamPlayer.isAudioOutputRunning,
           let pendingInput = pendingPlaybackPresentationInput,
           engineInput == pendingInput,
           let sessionId = pendingPlaybackPresentationSessionId {
            commitPendingPlaybackPresentationIfNeeded(
                sessionId: sessionId,
                engineInput: engineInput
            )
        }

        let audibleInput = currentPlayingURL
        let canPreserveAudiblePipeline =
            (engineState == .playing || engineState == .paused)
            && engineInput != nil
            && engineInput == audibleInput

        rollbackPendingPlaybackQueueMutationIfNeeded()
        invalidateInFlightPlaybackWork(reason: "user pause while loading")
        clearPlaybackStartFade(restoreVolume: true)

        if !canPreserveAudiblePipeline {
            suppressStopHandlingUntil = Date().addingTimeInterval(1)
            switch engineState {
            case .connecting, .playing, .paused:
                streamPlayer.stop()
            case .idle, .stopped, .error:
                break
            }
            isPlaying = false
        }

        isLoading = false
        endTransitionKeepAlive()
        refreshPlaybackSurfaceState()
        saveState()
        AppLogger.info(
            "[PlaybackTransition] 用户暂停并撤销待处理切歌 preserveAudible=\(canPreserveAudiblePipeline)",
            step: "playback.transition.cancelled-by-pause"
        )
    }

    // MARK: - 播放失败提示

    /// 弹出播放失败的具体错误提示（不自动跳过）
    func showPlaybackError(song: Song, error: Error) {
        let playbackError = error as? APIService.PlaybackError
        let preservedAudibleSong = discardPendingPlaybackPresentationIfNeeded(
            song: song,
            sessionId: playbackSessionId
        ) && streamPlayer.state == .playing
        isPlaying = preservedAudibleSong
        isLoading = false
        refreshPlaybackSurfaceState()
        saveState()
        // 播放失败的地址不可信，逐出缓存（下次点播重新解析）
        PlaybackURLCache.shared.invalidate(song: song)

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
}
