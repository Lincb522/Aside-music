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

    func handleCrossfadePlaybackSettingChanged(enabled: Bool) {
        streamPlayer.setCrossfadeDuration(
            isGaplessPlaybackEnabled && enabled
                ? Self.crossfadePlaybackDuration
                : 0
        )
    }

    // MARK: - 无缝引擎 v2（两阶段）
    //
    // 旧版在开播 0.35s 后立即解析下一首 URL 并装配 SDK 管线，带来一串问题：
    // ① 长曲/播客临近结尾时预解析的 URL 早已过期，EOF 切换必然失败；
    // ② 队列/播放模式中途变化不会重装，EOF 会切进已被移除的旧曲目；
    // ③ 频繁手动切歌时每首都白白解析一次下一首 URL；
    // ④ 汽水音乐完全没有无缝路径；单曲循环每轮整机重载，有可闻间隙。
    //
    // 新版拆成两阶段：
    // - 阶段 A（开播稳定后）：只解析下一首真实音质和播放地址；需要本地媒体的
    //   风控解密/汽水源同时低优先级落盘，不提前长期占用 CDN 连接。
    // - 阶段 B（剩余 ≤12s，由进度定时器驱动）：复用阶段 A 的地址缓存，创建
    //   新鲜 demuxer/decoder 并预解码 PCM。
    // 队列/模式一变即失效重装（invalidateGaplessPreparation），
    // EOF 恰落在重装窗口内时还有 applyPendingTrackTransition 的对账兜底。

    /// 阶段 B 装配窗口：剩余时长进入该窗口才装配管线
    static let gaplessArmWindow: TimeInterval = 12
    /// 就绪复查窗口：剩余进入该窗口且管线未就绪则重试装配
    static let gaplessRetryWindow: TimeInterval = 6
    /// 网络 demuxer 长时间不读包后容易被 CDN 断开，超过该时长不再热切。
    static let maxWarmNetworkPipelineAge: TimeInterval = 20

    /// 预期整曲时长：优先 API 元数据，回落 FFmpeg 实测
    private var expectedCurrentTrackDuration: Double {
        if let metaMs = currentSong?.dt, metaMs > 0 {
            return Double(metaMs) / 1000.0
        }
        return duration
    }

    func handleGaplessPlaybackSettingChanged(enabled: Bool) {
        streamPlayer.setAutomaticPreparedTrackTransitionEnabled(enabled)
        streamPlayer.setCrossfadeDuration(
            enabled && Self.crossfadePlaybackEnabled()
                ? Self.crossfadePlaybackDuration
                : 0
        )
        if enabled {
            scheduledGaplessPreparationSessionId = nil
            disarmGaplessEngine()
            guard isPlaying, currentSong != nil else { return }
            scheduleGaplessMediaPrefetchIfNeeded()
            return
        }

        cancelGaplessPreparation(resetPendingState: true)
    }

    /// 清空阶段 B 装配状态（不触碰 SDK 管线本身）
    func disarmGaplessEngine() {
        gaplessArmedSessionId = nil
        gaplessArmAttempts = 0
        lastGaplessArmAttemptAt = nil
        pendingLoopRestart = false
        pendingGaplessResolvedQuality = nil
        pendingGaplessPlaybackInput = nil
    }

    func cancelGaplessPreparation(resetPendingState: Bool) {
        gaplessPreparationWorkItem?.cancel()
        gaplessPreparationWorkItem = nil
        scheduledGaplessPreparationSessionId = nil
        gaplessArmedSessionId = nil
        lastGaplessArmAttemptAt = nil

        nextTrackCancellable?.cancel()
        nextTrackCancellable = nil

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
            pendingLoopRestart = false
            gaplessArmAttempts = 0
            pendingGaplessResolvedQuality = nil
            pendingGaplessPlaybackInput = nil
        }
    }

    /// 阶段 B 主入口：由 0.25s 进度定时器驱动（后台降为 1Hz）。
    /// 装配一次后置位会话标记；临近 EOF 复查就绪状态，失败限次重装。
    func tickGaplessEngine() {
        guard isGaplessPlaybackEnabled,
              isPlaying,
              currentSong != nil,
              pendingPlaybackPresentationSong == nil,
              pendingQualitySwitchSeek == nil,
              !pendingSleepStopAfterCurrentTrack,
              !isSeeking else { return }

        let expected = expectedCurrentTrackDuration
        guard expected > 1 else { return }
        let remaining = expected - currentTime
        let sessionId = playbackSessionId

        guard remaining <= Self.gaplessArmWindow else { return }
        // 阶段 A 的地址解析仍在进行时不要计入一次失败装配。缓存一写入，
        // 下一个 0.25s tick 会立刻进入阶段 B，不再被 4 秒重试节流拖住。
        if gaplessArmedSessionId != sessionId, qmcPrefetchTask != nil {
            return
        }
        if gaplessArmedSessionId == sessionId {
            if let next = upcomingPlaybackSong(),
               !isPreparedGaplessPipelineFresh(for: next) {
                AppLogger.info("[Gapless] 曲尾刷新过久的网络预装管线")
                nextTrackCancellable?.cancel()
                nextTrackCancellable = nil
                streamPlayer.cancelNextPreparation()
                hasPendingTrackTransition = false
                pendingNextSong = nil
                pendingTransitionStartedAt = nil
                pendingTransitionSessionId = 0
                gaplessArmedSessionId = nil
                gaplessArmAttempts = 0
                lastGaplessArmAttemptAt = nil
                pendingGaplessResolvedQuality = nil
            } else {
            // 已装配：临近结尾复查 SDK 管线是否真的就绪（预加载静默失败时重试一次）
                guard remaining <= Self.gaplessRetryWindow,
                      remaining > 1.5,
                      gaplessArmAttempts < 2,
                      !streamPlayer.isNextTrackReady,
                      Date().timeIntervalSince(lastGaplessArmAttemptAt ?? .distantPast) > 3 else {
                    return
                }
                AppLogger.warning("[Gapless] 管线未就绪，临近结尾重试装配")
                gaplessArmedSessionId = nil
                pendingLoopRestart = false
            }
        }

        // 媒体未就绪等场景的循环尝试节流
        if let last = lastGaplessArmAttemptAt,
           Date().timeIntervalSince(last) < 4 {
            return
        }
        lastGaplessArmAttemptAt = Date()
        armGaplessPipeline(sessionId: sessionId)
    }

    /// 本地文件可长时间保持预装；网络管线只在短窗口内视为可靠。
    func isPreparedGaplessPipelineFresh(for song: Song) -> Bool {
        if localPlaybackURL(for: song) != nil || cachedQMCFileURL(for: song.id) != nil {
            return true
        }
        if song.isQishui,
           let trackId = song.qishuiTrackId,
           let asset = qishuiGaplessAsset,
           asset.trackId == trackId,
           FileManager.default.fileExists(atPath: asset.fileURL.path) {
            return true
        }
        guard let preparedAt = lastGaplessArmAttemptAt else { return false }
        return Date().timeIntervalSince(preparedAt) <= Self.maxWarmNetworkPipelineAge
    }

    /// 装配 SDK next 管线（阶段 B 本体）
    private func armGaplessPipeline(sessionId: Int) {
        // 单曲循环：用当前源无缝回绕，不经过 loadAndPlay
        if mode == .loopSingle {
            guard let url = currentPlayingURL else { return }
            gaplessArmedSessionId = sessionId
            gaplessArmAttempts += 1
            pendingLoopRestart = true
            prepareGaplessPlaybackInput(url, decryptionKey: currentPlayingDecryptionKey)
            AppLogger.info("[Gapless] 已装配单曲循环回绕")
            return
        }

        guard let next = upcomingPlaybackSong() else { return }
        lastGaplessArmAttemptAt = Date()

        // 本地文件和已经解密落盘的 QMC 不需要等待重媒体预取，开播稳定后
        // 立即把完整 demux / decoder / preroll 管线暖好，手动下一曲可直接热切。
        if localPlaybackURL(for: next) != nil || cachedQMCFileURL(for: next.id) != nil {
            gaplessArmedSessionId = sessionId
            gaplessArmAttempts += 1
            preparePendingNextTrack()
            prepareNextTrackURL()
            return
        }

        // 汽水音乐：只有阶段 A 预取产物就绪才能无缝（加密 CDN 无法直接流式装配）
        if next.isQishui {
            guard let trackId = next.qishuiTrackId,
                  let asset = qishuiGaplessAsset,
                  asset.trackId == trackId,
                  FileManager.default.fileExists(atPath: asset.fileURL.path) else {
                // 媒体还没下载完：不置位装配标记，下个 tick（4s 节流）再试
                return
            }
            gaplessArmedSessionId = sessionId
            gaplessArmAttempts += 1
            preparePendingNextTrack()
            prepareGaplessPlaybackInput(
                asset.fileURL.playerInputString,
                decryptionKey: asset.decryptionKey
            )
            AppLogger.info("[Gapless] 已装配汽水缓存: \(next.name)")
            return
        }

        // 阶段 A 的地址解析仍在进行时不要并发发起第二次请求；完成后由下一次
        // tick 使用同一个 URL 缓存装配管线。
        guard qmcPrefetchTask == nil else { return }

        gaplessArmedSessionId = sessionId
        gaplessArmAttempts += 1
        preparePendingNextTrack()
        prepareNextTrackURL()
    }

    private func prepareGaplessPlaybackInput(
        _ input: String,
        decryptionKey: String? = nil
    ) {
        pendingGaplessPlaybackInput = input
        streamPlayer.prepareNext(url: input, decryptionKey: decryptionKey)
    }

    /// 单曲循环无缝回绕完成：SDK 已从头开播同一首，重置进度与逐字歌词
    func handleSeamlessLoopRestart(engineInput: String?) {
        guard let expectedInput = pendingGaplessPlaybackInput,
              let engineInput,
              engineInput == expectedInput else {
            AppLogger.error(
                "[Gapless] 单曲循环输入不一致 expected=\(pendingGaplessPlaybackInput ?? "nil") engine=\(engineInput ?? "nil")",
                step: "playback.loop.input-mismatch"
            )
            let song = currentSong
            cancelGaplessPreparation(resetPendingState: true)
            if let song {
                loadAndPlay(song: song)
            }
            return
        }
        advanceApplicationPlaybackSession()
        let transitionTime = currentEngineTransitionTime()
        currentTime = transitionTime
        LyricViewModel.shared.updateCurrentTime(transitionTime)
        playbackStartedAt = Date()
        if let song = currentSong {
            addToHistory(song: song)
        }
        // 允许下一轮循环重新装配
        disarmGaplessEngine()
        updateNowPlayingInfo()
        saveState()
        syncWidgetState()
    }

    /// Mono can keep one engine generation alive across a prepared-track switch,
    /// while app-level async work still needs a new session boundary.
    private func advanceApplicationPlaybackSession() {
        playbackSessionId += 1
        delegateAdapter?.currentSessionId = playbackSessionId
    }

    /// At the transition callback the new track may already be audible because
    /// crossfade switches metadata at its midpoint. Reject an old-track clock if
    /// a non-crossfade notification fires a fraction early.
    private func currentEngineTransitionTime() -> Double {
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

    /// Reconciles app metadata when Mono has switched to a prepared pipeline but
    /// the delegate notification was delayed while the app was in the background.
    /// The engine explicitly reports its audible-tail deferral so this fallback
    /// never advances the UI while the previous track is still heard.
    func reconcilePendingTrackTransitionWithEngine(reason: String) {
        guard isGaplessPlaybackEnabled,
              hasPendingTrackTransition,
              pendingNextSong != nil,
              pendingQualitySwitchSeek == nil,
              !pendingLoopRestart,
              pendingTransitionSessionId == playbackSessionId,
              !streamPlayer.isTrackTransitionNotificationDeferred,
              let engineURL = streamPlayer.streamInfo?.url,
              let applicationURL = currentPlayingURL,
              engineURL != applicationURL else { return }

        AppLogger.warning(
            "[Gapless] 引擎已切歌但应用元数据未同步，执行对账 (reason=\(reason))"
        )
        applyPendingTrackTransition(engineInput: streamPlayer.currentPlaybackInput)
    }

    func matchesPlaybackTarget(_ candidate: Song?, expected: Song) -> Bool {
        guard let candidate,
              candidate.id == expected.id,
              candidate.musicSource == expected.musicSource else { return false }

        if expected.isQQMusic {
            return candidate.qqMid == expected.qqMid
        }
        if expected.isQishui {
            return candidate.qishuiTrackId == expected.qishuiTrackId
        }
        return true
    }

    func playbackIdentityKey(for song: Song) -> String {
        if song.isQQMusic {
            return "qq:\(song.qqMid ?? String(song.id))"
        }
        if song.isQishui {
            return "qishui:\(song.qishuiTrackId.map { String($0) } ?? String(song.id))"
        }
        return "\(song.musicSource.rawValue):\(song.id)"
    }

    /// Mono may have already installed the prepared next pipeline while its old
    /// audible tail is still draining. Treat another request for that same target
    /// as already in progress instead of preparing and replaying it a second time.
    @discardableResult
    func reconcileAlreadyActiveGaplessTarget(_ target: Song, reason: String) -> Bool {
        guard isGaplessPlaybackEnabled,
              hasPendingTrackTransition,
              matchesPlaybackTarget(pendingNextSong, expected: target),
              let expectedInput = pendingGaplessPlaybackInput,
              let engineInput = streamPlayer.currentPlaybackInput,
              engineInput == expectedInput else { return false }

        AppLogger.info(
            "[Gapless] 目标管线已经在内核中生效，忽略重复切歌 target=\(target.name) reason=\(reason)",
            step: "playback.transition.already-active"
        )
        reconcilePendingTrackTransitionWithEngine(reason: reason)
        return true
    }

    private func isCurrentGaplessArmTarget(_ song: Song, sessionId: Int) -> Bool {
        playbackSessionId == sessionId
            && isGaplessPlaybackEnabled
            && gaplessArmedSessionId == sessionId
            && matchesPlaybackTarget(pendingNextSong, expected: song)
            && matchesPlaybackTarget(upcomingPlaybackSong(), expected: song)
    }

    private func isCurrentGaplessPrefetchTarget(_ song: Song, sessionId: Int) -> Bool {
        playbackSessionId == sessionId
            && isGaplessPlaybackEnabled
            && mode != .loopSingle
            && matchesPlaybackTarget(upcomingPlaybackSong(), expected: song)
    }

    /// 队列 / 播放模式变化后调用：已装配的下一首管线可能指向过期曲目。
    /// 下一首实际没变则原样保留；变了就拆掉，交给 tick 按新队列重装。
    func invalidateGaplessPreparation(reason: String) {
        guard isGaplessPlaybackEnabled else { return }
        guard pendingQualitySwitchSeek == nil else { return }

        let armed = gaplessArmedSessionId == playbackSessionId
        guard armed || hasPendingTrackTransition || pendingLoopRestart else {
            // 尚未装配管线：取消旧目标的异步预取，再换成新的下一首。
            // Combine continuation 不会因 Swift Task.cancel 自动停下，后续写入还会
            // 由目标校验拦截；这里清空任务槽位，让新目标无需等待旧请求结束。
            qmcPrefetchTask?.cancel()
            qmcPrefetchTask = nil
            scheduleGaplessMediaPrefetchIfNeeded(force: true)
            return
        }

        // 循环回绕装配与队列内容无关（模式变化会走 loadAndPlay/switchMode 复位）
        if pendingLoopRestart, mode == .loopSingle {
            return
        }

        // 装配目标与新队列一致 → 不折腾
        if !pendingLoopRestart,
           mode != .loopSingle,
           let pending = pendingNextSong,
           let upcoming = upcomingPlaybackSong(),
           matchesPlaybackTarget(pending, expected: upcoming) {
            return
        }

        AppLogger.info("[Gapless] 队列已变化，重装下一首管线（\(reason)）")
        cancelGaplessPreparation(resetPendingState: true)
        scheduleGaplessMediaPrefetchIfNeeded(force: true)
        // tick 会在下一拍按新队列重新装配（gaplessArmedSessionId 已清空）
    }

    /// 阶段 A 调度：开播稳定后（或队列变化后）延时预取下一首重媒体。
    /// force = 队列变化触发的重预取（同时充当连续编辑的防抖）。
    func scheduleGaplessMediaPrefetchIfNeeded(force: Bool = false) {
        guard isGaplessPlaybackEnabled,
              pendingPlaybackPresentationSong == nil else { return }
        let sessionId = playbackSessionId
        if !force {
            guard scheduledGaplessPreparationSessionId != sessionId else { return }
        }
        scheduledGaplessPreparationSessionId = sessionId

        gaplessPreparationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.playbackSessionId == sessionId else { return }
            guard self.isPlaying, self.currentSong != nil else { return }
            self.beginGaplessMediaPrefetch()
        }
        gaplessPreparationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (force ? 0.35 : 0.65), execute: workItem)
    }

    /// 阶段 A 本体：开播稳定后只解析并缓存下一首地址，不创建会长时间
    /// 空置的网络 demuxer。需要完整本地媒体的来源会在后台下载完成。
    func beginGaplessMediaPrefetch() {
        guard isGaplessPlaybackEnabled,
              mode != .loopSingle,
              pendingPlaybackPresentationSong == nil else { return }
        guard let next = upcomingPlaybackSong() else { return }
        let sessionId = playbackSessionId

        if next.isQishui {
            if localPlaybackURL(for: next) != nil {
                armGaplessPipeline(sessionId: sessionId)
                return
            }
            prefetchNextQishuiTrack(next)
            return
        }

        if next.isQQMusic {
            prefetchNextQQTrack(next)
        } else {
            prefetchNextNCMTrack(next)
        }
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
        return DownloadManager.shared.localFileURL(for: song)
    }

    /// 歌曲列表/搜索结果已携带音质元数据时直接复用，省去单独的音质查询。
    /// 元数据缺失时返回 nil，API 仍会走完整的最高可用音质探测，避免误降到标准音质。
    private func modelReportedNeteaseQuality(for song: Song) -> SoundQuality? {
        guard !song.isQQMusic, !song.isQishui else { return nil }
        guard song.h != nil || song.m != nil || song.l != nil
                || song.sq != nil || song.hr != nil || song.privilege != nil else {
            return nil
        }
        return song.maxQuality
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
        // 队列播完：结算听歌统计
        ListeningStatsRecorder.shared.finalizeSession()
        cancelPlaybackFade(restoreVolume: false)
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        clearPendingPlaybackPresentation()
        disarmGaplessEngine()
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
    
    /// StreamPlayer 播放结束回调（由 delegate adapter 调用）
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
            pendingTransitionSessionId = 0
            return
        }

        pendingNextSong = upcomingPlaybackSong()
        guard pendingNextSong != nil else {
            hasPendingTrackTransition = false
            pendingTransitionStartedAt = nil
            pendingTransitionSessionId = 0
            return
        }
        hasPendingTrackTransition = true
        pendingTransitionStartedAt = Date()
        pendingTransitionSessionId = playbackSessionId
    }
    
    /// 当前歌曲真正结束后，应用待切换的下一首
    func applyPendingTrackTransition(engineInput: String? = nil) {
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
            pendingTransitionSessionId = 0
            return
        }
        
        // 用户已手动切歌（session 变了），放弃本次无缝切换
        if pendingTransitionSessionId != playbackSessionId {
            AppLogger.info("applyPendingTrackTransition: session 已变更，跳过")
            hasPendingTrackTransition = false
            pendingNextSong = nil
            pendingTransitionStartedAt = nil
            pendingTransitionSessionId = 0
            return
        }

        // 对账兜底：EOF 与队列编辑竞态时，装配好的下一首可能已不是队列的真实下一首
        // （invalidate 还没来得及拆装配就到了 EOF）。此时放弃无缝，硬切到正确曲目。
        if mode != .loopSingle,
           let expected = upcomingPlaybackSong(),
           !matchesPlaybackTarget(song, expected: expected) {
            AppLogger.warning("[Gapless] EOF 与队列变化竞态，改播真实下一首: \(expected.name)")
            hasPendingTrackTransition = false
            pendingNextSong = nil
            pendingTransitionStartedAt = nil
            pendingTransitionSessionId = 0
            loadAndPlay(song: expected)
            return
        }

        let resolvedEngineInput = engineInput ?? streamPlayer.currentPlaybackInput
        guard let expectedInput = pendingGaplessPlaybackInput,
              let resolvedEngineInput,
              resolvedEngineInput == expectedInput else {
            AppLogger.error(
                "[Gapless] 内核播放输入与待切歌曲不一致，拒绝提交 UI target=\(song.name) expected=\(pendingGaplessPlaybackInput ?? "nil") engine=\(resolvedEngineInput ?? "nil")",
                step: "playback.gapless.input-mismatch"
            )
            cancelGaplessPreparation(resetPendingState: true)
            loadAndPlay(song: song)
            return
        }

        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        pendingTransitionSessionId = 0

        advanceApplicationPlaybackSession()
        let transitionTime = currentEngineTransitionTime()

        applyAutomaticTransitionNavigationState(to: song)
        if let index = currentContextList.firstIndex(where: { $0.id == song.id }) {
            contextIndex = index
        }
        
        currentSong = song
        currentTime = transitionTime
        duration = song.dt.map { Double($0) / 1000.0 } ?? 0
        applyResolvedPlaybackQuality(pendingGaplessResolvedQuality, for: song)
        pendingGaplessResolvedQuality = nil
        
        // 确保播放状态正确（无缝切歌时 SDK 一直在播放，isPlaying 应为 true）
        if !isPlaying {
            isPlaying = true
        }
        
        // 从 streamInfo 获取下一首的 duration（transitionToNextTrack 中不再单独发送 didUpdateDuration）
        if let nextDuration = streamPlayer.streamInfo?.duration, nextDuration > 0 {
            duration = nextDuration
        }

        // 同步「当前播放源」到已切换的新管线：
        // 单曲循环回绕装配 / 断流重连都依赖这两个字段，无缝切换不经过
        // startPlayback，不同步会让后续装配拿到上一首的过期地址。
        if let info = streamPlayer.streamInfo {
            currentPlayingURL = info.url
            // 无缝管线的地址在装配时（临近上一首结尾）解析，视作此刻新鲜
            playbackURLResolvedAt = Date()
        }
        if song.isQishui,
           let asset = qishuiGaplessAsset,
           asset.trackId == song.qishuiTrackId {
            currentPlayingDecryptionKey = asset.decryptionKey
        } else {
            currentPlayingDecryptionKey = nil
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
        nextTrackCancellable?.cancel()
        playbackStartedAt = Date()
        LyricViewModel.shared.updateCurrentTime(transitionTime)

        // 重启无缝链路：阶段 A 立即调度（session 未变，需先清调度标记），
        // 阶段 B 交给进度 tick 在临近结尾时装配，形成连续无缝链条
        disarmGaplessEngine()
        scheduledGaplessPreparationSessionId = nil
        scheduleGaplessMediaPrefetchIfNeeded()
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
            prepareGaplessPlaybackInput(localURL.playerInputString)
            return
        }
        
        if let cachedQMCFile = cachedQMCFileURL(for: song.id) {
            AppLogger.info("[QMC] 预加载下一首（解密缓存）: \(song.name)")
            prepareGaplessPlaybackInput(cachedQMCFile.playerInputString)
            return
        }
        
        // 汽水音乐不走本函数：需要先下载解密，由阶段 A 预取 + armGaplessPipeline 装配
        guard !song.isQishui else { return }

        nextTrackCancellable?.cancel()
        streamPlayer.cancelNextPreparation()

        // 网络获取 URL：与正式开播使用完全相同的音质策略与缓存键。
        if song.isQQMusic, let mid = song.qqMid {
            let modelReportedQuality = song.qqMaxQuality
            let requestedQuality: QQMusicQuality? = SettingsManager.shared.preferHighestPlaybackQuality
                ? nil
                : Self.defaultQQPlaybackQuality()
            let cacheKey = PlaybackURLCache.qqKey(mid: mid, quality: requestedQuality?.rawValue)
            let installResult: (APIService.SongUrlResult) -> Void = { [weak self] result in
                guard let self,
                      self.isCurrentGaplessArmTarget(song, sessionId: sessionId),
                      let url = URL(string: result.url) else { return }
                self.rememberGaplessResolvedQuality(result, for: song)

                if result.requiresQMCDecryption {
                    guard let ekey = result.qmcEkey,
                          SettingsManager.shared.qmcDecryptEnabled else {
                        AppLogger.warning("[QQMusic] 加密兜底不可用，取消下一首装配: \(song.name)")
                        return
                    }
                    self.prepareDecryptedNextTrack(
                        url: url,
                        ekey: ekey,
                        song: song,
                        sessionId: sessionId
                    )
                    return
                }

                AppLogger.info("[QQMusic] 复用已解析直链装配下一首: \(song.name)")
                self.prepareGaplessPlaybackInput(url.playerInputString)
            }

            if let cached = PlaybackURLCache.shared.fresh(forKey: cacheKey) {
                AppLogger.info("[URLCache] QQ 无缝装配命中地址缓存: \(song.name)")
                installResult(cached)
                return
            }

            Task { @MainActor in
                self.nextTrackCancellable = APIService.shared.fetchQQSongUrl(
                    mid: mid,
                    quality: requestedQuality,
                    prefetchedQuality: modelReportedQuality
                )
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        guard let self,
                              self.isCurrentGaplessArmTarget(song, sessionId: sessionId) else { return }
                        if case .failure(let error) = completion {
                            AppLogger.warning("[QQMusic] 预加载下一首 URL 获取失败: \(error)")
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self,
                              self.isCurrentGaplessArmTarget(song, sessionId: sessionId) else { return }
                        PlaybackURLCache.shared.store(result, forKey: cacheKey)
                        installResult(result)
                    })
            }
        } else {
            let modelReportedLevel = modelReportedNeteaseQuality(for: song)?.rawValue
            let requestedQuality: SoundQuality? = SettingsManager.shared.preferHighestPlaybackQuality
                ? nil
                : Self.defaultNeteasePlaybackQuality()
            let cacheKey = PlaybackURLCache.neteaseKey(
                id: song.id,
                level: requestedQuality?.rawValue,
                isPodcast: playSource.isPodcast
            )
            let installResult: (APIService.SongUrlResult) -> Void = { [weak self] result in
                guard let self,
                      self.isCurrentGaplessArmTarget(song, sessionId: sessionId),
                      let url = URL(string: result.url) else { return }
                self.rememberGaplessResolvedQuality(result, for: song)

                if let ekey = result.qmcEkey,
                   SettingsManager.shared.qmcDecryptEnabled {
                    self.prepareDecryptedNextTrack(
                        url: url,
                        ekey: ekey,
                        song: song,
                        sessionId: sessionId
                    )
                    return
                }

                AppLogger.info("[Netease] 复用已解析直链装配下一首: \(song.name)")
                self.prepareGaplessPlaybackInput(url.playerInputString)
            }

            if let cached = PlaybackURLCache.shared.fresh(forKey: cacheKey) {
                AppLogger.info("[URLCache] NCM 无缝装配命中地址缓存: \(song.name)")
                installResult(cached)
                return
            }

            Task { @MainActor in
                self.nextTrackCancellable = APIService.shared.fetchSongUrl(
                    id: song.id,
                    level: requestedQuality?.rawValue,
                    prefetchedLevel: modelReportedLevel
                )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self,
                          self.isCurrentGaplessArmTarget(song, sessionId: sessionId) else { return }
                    if case .failure(let error) = completion {
                        AppLogger.warning("预加载下一首 URL 获取失败: \(error)")
                    }
                }, receiveValue: { [weak self] result in
                    guard let self,
                          self.isCurrentGaplessArmTarget(song, sessionId: sessionId) else { return }
                    if !self.playSource.isPodcast {
                        PlaybackURLCache.shared.store(result, forKey: cacheKey)
                    }
                    installResult(result)
                })
            }
        }
    }
    
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
    }

    /// 将一首已经具备可播条件的歌曲提交给界面与系统 Now Playing。
    /// 手动切歌时由 Mono 的 `.playing` 回调调用，保证声音和元数据同拍切换。
    private func publishPlaybackPresentation(
        song: Song,
        startTime: Double,
        isUnblocked: Bool
    ) {
        let isNewPresentation = !matchesPlaybackTarget(currentSong, expected: song)
        currentSong = song
        if let index = currentContextList.firstIndex(where: {
            matchesPlaybackTarget($0, expected: song)
        }) {
            contextIndex = index
        }
        currentTime = max(0, startTime)
        duration = song.dt.map { Double($0) / 1000.0 } ?? 0
        isCurrentSongUnblocked = isUnblocked

        fetchLyricsForSong(song)
        loadSongExtras(for: song)
        if isNewPresentation {
            addToHistory(song: song)
            if !song.isQQMusic && !song.isQishui {
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
        clearPendingPlaybackPresentation()
        currentPlayingURL = engineInput
        playbackURLResolvedAt = Date()
        currentPlayingDecryptionKey = decryptionKey
        applyResolvedPlaybackQuality(resolvedQuality, for: song)
        publishPlaybackPresentation(
            song: song,
            startTime: startTime,
            isUnblocked: isUnblocked
        )
        AppLogger.info("播放管线已出声，提交歌曲界面: \(song.name)")
    }

    private func rememberGaplessResolvedQuality(_ result: APIService.SongUrlResult, for song: Song) {
        if song.isQQMusic,
           let mid = song.qqMid,
           let quality = result.actualQQQuality {
            pendingGaplessResolvedQuality = .qq(mid: mid, quality: quality)
        } else if let quality = result.actualNeteaseQuality {
            pendingGaplessResolvedQuality = .netease(songId: song.id, quality: quality)
        }
    }

    private func applyResolvedPlaybackQuality(_ resolved: ResolvedPlaybackQuality?, for song: Song) {
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
            duration = streamDuration
        }
        LyricViewModel.shared.updateCurrentTime(transitionTime)
        endTransitionKeepAlive()
        refreshPlaybackSurfaceState()
        syncWidgetState()

        disarmGaplessEngine()
        scheduledGaplessPreparationSessionId = nil
        scheduleGaplessMediaPrefetchIfNeeded()
    }

    private func updatePlaybackPresentationResolution(
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
        clearPendingPlaybackPresentation()
        if let currentSong,
           let currentIndex = currentContextList.firstIndex(where: {
               matchesPlaybackTarget($0, expected: currentSong)
           }) {
            contextIndex = currentIndex
        }
        return currentSong != nil
    }

    func loadAndPlay(song: Song, autoPlay: Bool = true, startTime: Double = 0) {
        if reconcileAlreadyActiveGaplessTarget(song, reason: "load-and-play") {
            return
        }

        let isNewSong = !matchesPlaybackTarget(currentSong, expected: song)
        // 一次性快速通道：进函数即消费，绝不泄漏到下一次加载
        let preresolvedInput = preresolvedRestorationInput
        preresolvedRestorationInput = nil

        // 后台切歌保活：URL 解析是网络请求，音频停止输出后系统随时可能挂起 App，
        // 申请短时后台任务护住「取 URL → 开播」的空窗期（前台调用时无副作用）。
        beginTransitionKeepAlive(reason: "loadAndPlay: \(song.name)")

        if let current = currentSong,
           !matchesPlaybackTarget(current, expected: song),
           pendingPlaybackPresentationSong == nil {
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
        // 让上一会话遗留的淡出包络失效（其收尾会挂起引擎，不能命中新会话）
        cancelPlaybackFade(restoreVolume: false)
        lastPausedAt = nil
        // 取消正在进行的预缓存（切歌后下一首会变）
        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil
        activeMediaLoadTask?.cancel()
        activeMediaLoadTask = nil
        nextTrackCancellable?.cancel()
        manualSwitchPreparationTask?.cancel()
        manualSwitchPreparationTask = nil
        manualPreparedSwitchSessionId = nil
        streamPlayer.cancelNextPreparation()
        // 清除待切换状态（用户手动切歌）
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        disarmGaplessEngine()
        // 清除 seek 状态
        isSeeking = false
        seekTargetTime = nil
        seekStartedAt = nil
        pendingRestoreTime = nil
        needsPlaybackRestoration = false
        shouldAutoResumeAfterRestore = false
        // 恢复窗口已关闭：丢弃上次会话的快速续播资产
        restoredPlaybackAsset = nil
        
        isLoading = true
        // 新歌回到全局策略；当前歌曲的手动切换仅在本曲生命周期内有效。
        if isNewSong {
            hasManualNeteaseQualityOverride = false
            hasManualQQQualityOverride = false
            soundQuality = Self.initialNeteasePlaybackQuality()
            qqMusicQuality = Self.initialQQPlaybackQuality()
        }
        let shouldDeferPresentation = isNewSong && currentSong != nil
        if shouldDeferPresentation {
            pendingPlaybackPresentationSong = song
            pendingPlaybackPresentationSessionId = playbackSessionId
            pendingPlaybackPresentationInput = nil
            pendingPlaybackPresentationDecryptionKey = nil
            pendingPlaybackPresentationStartTime = max(0, startTime)
            pendingPlaybackPresentationIsUnblocked = false
        } else {
            clearPendingPlaybackPresentation()
            publishPlaybackPresentation(song: song, startTime: startTime, isUnblocked: false)
        }
        isCurrentPlaybackUsingLocalFile = false
        if !shouldDeferPresentation {
            streamInfo = nil
        }
        qualitySwitchTimeoutTask?.cancel()
        qualitySwitchTimeoutTask = nil
        qualitySwitchRecoveryAttempts = 0

        // 切歌时重置重试计数器
        if startTime == 0 {
            abnormalStopRetryCount = 0
            networkDisconnectRetryCount = 0
        }
        // 优先使用本地已下载文件
        if let localURL = localPlaybackURL(for: song) {
            AppLogger.info("使用本地文件播放: \(song.name)")
            isCurrentPlaybackUsingLocalFile = true
            self.startPlayback(url: localURL, autoPlay: autoPlay, startTime: startTime)
            return
        }
        DownloadManager.shared.enqueueRestoredDownloadIfNeeded(for: song)

        // 冷启动快速续播（小组件/锁屏唤醒）：上次会话已解析的播放输入仍然
        // 新鲜（网络地址在有效期内）或仍然存在（本地缓存文件）时，
        // 跳过整个「取 URL」API 往返直接开播。若地址实际已失效，
        // 播放内核报错后会走静默刷新 URL 重试，用户无感回退到完整取址。
        if let pre = preresolvedInput {
            let url = pre.input.hasPrefix("http")
                ? URL(string: pre.input)
                : URL(fileURLWithPath: pre.input)
            if let url {
                AppLogger.info("快速续播：复用上次会话的播放输入 \(song.name)")
                startPlayback(url: url, autoPlay: autoPlay, startTime: startTime, decryptionKey: pre.decryptionKey)
                return
            }
        }

        // 根据歌曲来源获取播放 URL
        if song.isQishui, let trackId = song.qishuiTrackId {
            loadAndPlayQishuiSong(trackId: trackId, song: song, autoPlay: autoPlay, startTime: startTime)
        } else if song.isQQMusic, let mid = song.qqMid {
            loadAndPlayQQSong(mid: mid, song: song, autoPlay: autoPlay, startTime: startTime)
        } else {
            loadAndPlayNeteaseSong(song: song, autoPlay: autoPlay, startTime: startTime)
        }
    }
    
    /// 加载并播放ncm歌曲（按当前播放策略解析音质）
    private func loadAndPlayNeteaseSong(song: Song, autoPlay: Bool, startTime: Double) {
        let sessionId = playbackSessionId
        playbackURLCancellable?.cancel()
        let isPodcast = playSource.isPodcast
        let modelReportedLevel = modelReportedNeteaseQuality(for: song)?.rawValue
        let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality && !hasManualNeteaseQualityOverride
        let requestedQuality: SoundQuality? = shouldAutoSelectHighest ? nil : soundQuality
        let urlCacheKey = PlaybackURLCache.neteaseKey(
            id: song.id,
            level: requestedQuality?.rawValue,
            isPodcast: isPodcast
        )

        // 快速通道：短时间内已解析过同一地址（重播 / 来回切歌 / 阶段 A 预取），
        // 直接跳过整个 API 往返
        let cachedNeteaseResult = PlaybackURLCache.shared.fresh(forKey: urlCacheKey)
        if let cached = cachedNeteaseResult {
            AppLogger.info("[URLCache] NCM 命中缓存地址，秒开: \(song.name)")
            handleNeteaseSongUrlResult(
                cached, song: song, autoPlay: autoPlay, startTime: startTime,
                sessionId: sessionId, prefetchedLevel: modelReportedLevel
            )
            return
        }
        
        Task { @MainActor in
            self.playbackURLCancellable = APIService.shared.fetchSongUrl(
                id: song.id,
                level: requestedQuality?.rawValue,
                prefetchedLevel: modelReportedLevel,
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
                                // 标记为无版权，UI 层据此显示灰色；不再自动跳下一首
                                UnavailableSongsManager.shared.markUnavailable(song: song)
                                AppLogger.info("NCM歌曲无版权，标记灰色: \(song.name)")
                                self.showPlaybackError(song: song, error: error)
                            } else {
                                UnavailableSongsManager.shared.markTransient(song: song)
                                self.showPlaybackError(song: song, error: error)
                            }
                        }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    PlaybackURLCache.shared.store(result, forKey: urlCacheKey)
                    self.handleNeteaseSongUrlResult(
                        result, song: song, autoPlay: autoPlay, startTime: startTime,
                        sessionId: sessionId, prefetchedLevel: modelReportedLevel
                    )
                })
        }
    }

    /// NCM 取址成功后的统一处理（网络解析与缓存命中共用）
    private func handleNeteaseSongUrlResult(
        _ result: APIService.SongUrlResult,
        song: Song,
        autoPlay: Bool,
        startTime: Double,
        sessionId: Int,
        prefetchedLevel: String?
    ) {
        guard let url = URL(string: result.url) else { return }
        guard playbackSessionId == sessionId else { return }
        // 成功拿到 URL，清掉之前的失败标记
        UnavailableSongsManager.shared.clear(song: song)
        updatePlaybackPresentationResolution(
            song: song,
            sessionId: sessionId,
            isUnblocked: result.isUnblocked,
            unblockedQQMid: result.unblockedQQMid
        )
        let resolvedQuality = result.actualNeteaseQuality
            ?? prefetchedLevel.flatMap(SoundQuality.init(rawValue:))
        if let resolvedQuality {
            if pendingPlaybackPresentationSessionId == sessionId,
               matchesPlaybackTarget(pendingPlaybackPresentationSong, expected: song) {
                pendingPlaybackPresentationResolvedQuality = .netease(
                    songId: song.id,
                    quality: resolvedQuality
                )
            } else {
                soundQuality = resolvedQuality
            }
        }

        #if DEBUG
        print("[PlayerManager] NCM歌曲 URL 获取成功: \(song.name), isUnblocked=\(result.isUnblocked)")
        #endif

        if let ekey = result.qmcEkey {
            if SettingsManager.shared.qmcDecryptEnabled {
                AppLogger.info("[QMC] NCM歌曲(实际为QQ音源)需解密: \(song.name)")
                downloadDecryptAndPlay(
                    url: url, ekey: ekey, song: song,
                    autoPlay: autoPlay, startTime: startTime,
                    sessionId: sessionId
                )
            } else {
                isLoading = false
                refreshPlaybackSurfaceState()
                saveState()
                if autoPlay { showPlaybackError(song: song, error: APIService.PlaybackError.unavailable) }
            }
        } else {
            startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
        }
    }
    
    func autoNext() {
        next()
    }
    
    func startPlayback(url: URL, autoPlay: Bool = true, startTime: Double = 0, decryptionKey: String? = nil) {
        isLoading = true
        let defersPresentation = pendingPlaybackPresentationSessionId == playbackSessionId
        let input = url.playerInputString
        if defersPresentation {
            pendingPlaybackPresentationInput = input
            pendingPlaybackPresentationDecryptionKey = decryptionKey
        }
        gaplessPreparationWorkItem?.cancel()
        gaplessPreparationWorkItem = nil
        scheduledGaplessPreparationSessionId = nil
        disarmGaplessEngine()
        
        if startTime <= 0, !defersPresentation {
            self.currentTime = 0
            if self.duration <= 0, let metaMs = self.currentSong?.dt, metaMs > 0 {
                self.duration = Double(metaMs) / 1000.0
            }
        }
        
        // 保存当前播放 URL（用于音频分析等功能）
        if !defersPresentation {
            self.currentPlayingURL = input
            // 记录解析时刻：网络地址从此开始老化，恢复播放时超龄会重新取址
            self.playbackURLResolvedAt = Date()
            // 记录解密密钥：单曲循环无缝回绕装配同源管线时需要
            self.currentPlayingDecryptionKey = decryptionKey
        }
        
        AppLogger.network("开始播放 (FFmpeg): \(url.playerInputString)\(decryptionKey != nil ? " [encrypted]" : "")")

        AppLogger.info("startPlayback session=\(playbackSessionId), url=\(url.lastPathComponent)")

        playbackStartedAt = Date()

        // 开播前按当前策略激活音频会话（懒激活）：
        // 冷启动 setupAudioSession 只预声明 category、未 setActive。
        // 这里是真正需要把 session 接入系统音频路由的第一时间点。
        // `.automatic` 策略也会在此处按最新的 isOtherAudioPlaying 重新决议 options。
        activateAudioSessionForPlayback(reason: "loadAndPlay start")

        // 未命中开播后的预热结果时，不立即 stop 旧管线。先把目标歌曲装进
        // Mono next 通道并完成 preroll，真正 ready 后再丢弃旧尾音热切。
        // fastStart 用更小的预卷门槛尽早开声；装配一旦确定失败立即回退
        // 普通 play 路径（不再傻等超时），最长兜底等待 4 秒。
        if defersPresentation,
           autoPlay,
           startTime <= 0,
           streamPlayer.state == .playing {
            let sessionId = playbackSessionId
            if streamPlayer.currentPlaybackInput == input {
                AppLogger.info(
                    "[ManualSwitch] 目标歌曲已由无缝管线接管，复用现有 transition: \(pendingPlaybackPresentationSong?.name ?? "unknown")",
                    step: "playback.manual-switch.already-active"
                )
                manualPreparedSwitchSessionId = sessionId
                if streamPlayer.isTrackTransitionNotificationDeferred {
                    return
                }
                completeManualPreparedSwitch(
                    sessionId: sessionId,
                    engineInput: input
                )
                return
            }
            manualPreparedSwitchSessionId = sessionId
            streamPlayer.prepareNext(url: input, decryptionKey: decryptionKey, fastStart: true)
            manualSwitchPreparationTask?.cancel()
            manualSwitchPreparationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let fallbackToColdLoad: () -> Void = { [weak self] in
                    guard let self else { return }
                    self.manualPreparedSwitchSessionId = nil
                    self.manualSwitchPreparationTask = nil
                    self.streamPlayer.play(url: input, decryptionKey: decryptionKey)
                }
                for _ in 0..<160 {
                    do {
                        try await Task.sleep(nanoseconds: 25_000_000)
                    } catch {
                        return
                    }
                    guard self.playbackSessionId == sessionId,
                          self.manualPreparedSwitchSessionId == sessionId else { return }
                    if self.streamPlayer.isNextTrackReady {
                        self.streamPlayer.switchToNext()
                        return
                    }
                    if self.streamPlayer.hasNextPreparationFailed {
                        AppLogger.warning("手动切歌预热失败，立即回退普通装载")
                        fallbackToColdLoad()
                        return
                    }
                    switch self.streamPlayer.state {
                    case .idle, .stopped, .error:
                        AppLogger.info("旧管线已结束，立即冷启动待播歌曲")
                        fallbackToColdLoad()
                        return
                    case .connecting, .playing, .paused:
                        break
                    }
                }

                guard self.playbackSessionId == sessionId,
                      self.manualPreparedSwitchSessionId == sessionId else { return }
                AppLogger.warning("手动切歌预热超时，回退普通装载")
                fallbackToColdLoad()
            }
            return
        }

        streamPlayer.play(url: url.playerInputString, decryptionKey: decryptionKey)

        if !autoPlay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.streamPlayer.pause()
                self?.isPlaying = false
                // 冷启动静默恢复也算进入暂停态：URL 从此刻开始老化，
                // 过久后再点播放会走「重新取址续播」。
                self?.lastPausedAt = Date()
                self?.refreshPlaybackSurfaceState()
                self?.saveState()
            }
        }
        
        // seek 到指定位置（冷启动恢复 / 切换音质时保留进度）
        if startTime > 0 {
            if !defersPresentation {
                currentTime = startTime
                LyricViewModel.shared.updateCurrentTime(startTime)
            }
            isSeeking = true
            seekTargetTime = startTime
            seekStartedAt = Date()
            let sessionId = playbackSessionId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.playbackSessionId == sessionId else { return }
                self.streamPlayer.seek(to: startTime)
            }
        }
        
        if !defersPresentation {
            updateNowPlayingInfo()
            updateNowPlayingArtwork(for: currentSong)
        }
    }
    
    /// 加载并播放 qcm歌曲（按当前播放策略解析音质）
    private func loadAndPlayQQSong(mid: String, song: Song, autoPlay: Bool, startTime: Double) {
        let sessionId = playbackSessionId
        playbackURLCancellable?.cancel()
        let modelReportedQuality = song.qqMaxQuality
        let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality && !hasManualQQQualityOverride
        let requestedQuality: QQMusicQuality? = shouldAutoSelectHighest ? nil : qqMusicQuality
        let urlCacheKey = PlaybackURLCache.qqKey(mid: mid, quality: requestedQuality?.rawValue)

        // 快速通道：命中短时地址缓存直接开播（跳过 API 往返）
        let cachedQQResult = PlaybackURLCache.shared.fresh(forKey: urlCacheKey)
        if let cached = cachedQQResult {
            AppLogger.info("[URLCache] QQ 命中缓存地址，秒开: \(song.name)")
            handleQQSongUrlResult(
                cached, song: song, autoPlay: autoPlay, startTime: startTime,
                sessionId: sessionId
            )
            return
        }
        
        Task { @MainActor in
            self.playbackURLCancellable = APIService.shared.fetchQQSongUrl(
                mid: mid,
                quality: requestedQuality,
                prefetchedQuality: modelReportedQuality
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
                        // 标记失败：unavailable 走无版权，其他走 transient
                        if (error as? APIService.PlaybackError) == .unavailable {
                            UnavailableSongsManager.shared.markUnavailable(song: song)
                            AppLogger.info("[QQMusic] 数字专辑未购/无版权，标记灰色: \(song.name)")
                        } else {
                            UnavailableSongsManager.shared.markTransient(song: song)
                        }
                        if autoPlay {
                            self.showPlaybackError(song: song, error: error)
                        }
                    }
                }, receiveValue: { [weak self] result in
                    guard let self = self else { return }
                    guard self.playbackSessionId == sessionId else { return }
                    PlaybackURLCache.shared.store(result, forKey: urlCacheKey)
                    self.handleQQSongUrlResult(
                        result, song: song, autoPlay: autoPlay, startTime: startTime,
                        sessionId: sessionId
                    )
                })
        }
    }

    /// QQ 取址成功后的统一处理（网络解析与缓存命中共用）
    private func handleQQSongUrlResult(
        _ result: APIService.SongUrlResult,
        song: Song,
        autoPlay: Bool,
        startTime: Double,
        sessionId: Int
    ) {
        guard let url = URL(string: result.url) else { return }
        guard playbackSessionId == sessionId else { return }
        // 成功 → 清掉之前的失败标记
        UnavailableSongsManager.shared.clear(song: song)
        updatePlaybackPresentationResolution(
            song: song,
            sessionId: sessionId,
            isUnblocked: false
        )

        if let actual = result.actualQQQuality {
            if pendingPlaybackPresentationSessionId == sessionId,
               matchesPlaybackTarget(pendingPlaybackPresentationSong, expected: song) {
                pendingPlaybackPresentationResolvedQuality = .qq(mid: song.qqMid ?? "", quality: actual)
            } else {
                qqMusicQuality = actual
            }
        }

        if result.requiresQMCDecryption, let ekey = result.qmcEkey {
            if SettingsManager.shared.qmcDecryptEnabled {
                AppLogger.info("[QQMusic] Cookie 封控兜底，开始本地解密: \(song.name)")
                downloadDecryptAndPlay(
                    url: url, ekey: ekey, song: song,
                    autoPlay: autoPlay, startTime: startTime,
                    sessionId: sessionId
                )
            } else {
                isLoading = false
                refreshPlaybackSurfaceState()
                saveState()
                if autoPlay { showPlaybackError(song: song, error: APIService.PlaybackError.unavailable) }
            }
        } else {
            AppLogger.info("[QQMusic] 普通直链开始播放: \(song.name)")
            startPlayback(url: url, autoPlay: autoPlay, startTime: startTime)
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
        updatePlaybackPresentationResolution(
            song: song,
            sessionId: sessionId,
            isUnblocked: false
        )

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

                    if self.pendingPlaybackPresentationSessionId == sessionId,
                       self.matchesPlaybackTarget(self.pendingPlaybackPresentationSong, expected: song) {
                        self.pendingPlaybackPresentationResolvedQuality = .qishui(
                            trackId: trackId,
                            quality: result.quality
                        )
                    } else {
                        self.qishuiSelectedQuality = result.quality
                    }
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

        activeMediaLoadTask?.cancel()
        activeMediaLoadTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.playbackSessionId == sessionId {
                    self.activeMediaLoadTask = nil
                }
            }

            do {
                var request = URLRequest(url: url)
                request.setValue("https://www.qishui.com", forHTTPHeaderField: "Referer")
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
                request.networkServiceType = .responsiveData

                let downloadStart = CFAbsoluteTimeGetCurrent()
                let (temporaryURL, response) = try await URLSession.shared.download(for: request)
                let elapsed = CFAbsoluteTimeGetCurrent() - downloadStart

                try Task.checkCancellation()
                guard self.playbackSessionId == sessionId else { return }

                let httpResponse = response as? HTTPURLResponse
                guard httpResponse?.statusCode == 200 else {
                    let code = httpResponse?.statusCode ?? -1
                    throw NSError(domain: "QishuiPlayback", code: code, userInfo: [
                        NSLocalizedDescriptionKey: "CDN 下载失败 HTTP \(code)"
                    ])
                }

                if FileManager.default.fileExists(atPath: cacheFile.path) {
                    try? FileManager.default.removeItem(at: temporaryURL)
                } else {
                    try FileManager.default.moveItem(at: temporaryURL, to: cacheFile)
                }
                let attributes = try FileManager.default.attributesOfItem(atPath: cacheFile.path)
                let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
                guard fileSize > 0 else {
                    throw NSError(domain: "QishuiPlayback", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "CDN 下载文件为空"
                    ])
                }
                AppLogger.info("[Qishui] 下载完成 (\(fileSize / 1024)KB, \(String(format: "%.1f", elapsed))s), key=\(decryptionKey?.prefix(8) ?? "none")")

                try Task.checkCancellation()
                guard self.playbackSessionId == sessionId else { return }
                self.startPlayback(url: cacheFile, autoPlay: autoPlay, startTime: startTime, decryptionKey: decryptionKey)
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.error("[Qishui] 下载失败: \(error.localizedDescription)")
                guard self.playbackSessionId == sessionId else { return }
                self.isLoading = false
                self.refreshPlaybackSurfaceState()
                self.saveState()
                if autoPlay { self.showPlaybackError(song: song, error: error) }
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
        guard isCurrentGaplessArmTarget(song, sessionId: sessionId) else { return }

        if let cachedFile = cachedQMCFileURL(for: song.id) {
            qmcPrefetchTask?.cancel()
            qmcPrefetchTask = nil
            prepareGaplessPlaybackInput(cachedFile.playerInputString)
            return
        }

        // 短曲可能在阶段 A 下载尚未结束时进入阶段 B。统一复用同一个任务槽位，
        // 取消旧预取后由阶段 B 接管，避免对同一 QMC 文件发起两份并行下载。
        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if !Task.isCancelled, self.playbackSessionId == sessionId {
                    self.qmcPrefetchTask = nil
                }
            }

            do {
                let ext = url.pathExtension.contains("mflac") ? "flac"
                         : url.pathExtension.contains("mgg") ? "ogg"
                         : "flac"
                let cachedFile = Self.qmcCacheDir.appendingPathComponent("\(song.id).\(ext)")
                
                if FileManager.default.fileExists(atPath: cachedFile.path),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFile.path),
                   let size = attrs[.size] as? Int, size > 1024 {
                    guard self.isCurrentGaplessArmTarget(song, sessionId: sessionId) else { return }
                    AppLogger.info("[QMC] 命中缓存，预加载下一首: \(song.name)")
                    self.prepareGaplessPlaybackInput(cachedFile.playerInputString)
                    return
                }
                
                let decryptor = try QMCDecryptor.create(ekey: ekey)
                // 边下边解密，落位即装配
                let downloader = QMCStreamDownloader(decryptor: decryptor, destination: cachedFile)
                _ = try await downloader.download(from: url, priority: URLSessionTask.lowPriority)
                
                guard !Task.isCancelled,
                      self.isCurrentGaplessArmTarget(song, sessionId: sessionId) else { return }
                AppLogger.info("[QMC] 解密完成，预加载下一首: \(song.name)")
                self.prepareGaplessPlaybackInput(cachedFile.playerInputString)
            } catch {
                guard !Task.isCancelled else { return }
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
        activeMediaLoadTask?.cancel()
        activeMediaLoadTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.playbackSessionId == sessionId {
                    self.activeMediaLoadTask = nil
                }
            }

            do {
                try Task.checkCancellation()
                let ext = url.pathExtension.contains("mflac") ? "flac"
                         : url.pathExtension.contains("mgg") ? "ogg"
                         : "flac"
                let cachedFile = Self.qmcCacheDir.appendingPathComponent("\(song.id).\(ext)")

                if FileManager.default.fileExists(atPath: cachedFile.path),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFile.path),
                   let size = attrs[.size] as? Int, size > 1024 {
                    AppLogger.success("[QMC] 命中缓存，跳过下载解密: \(cachedFile.lastPathComponent) (\(size / 1024)KB)")
                    try Task.checkCancellation()
                    guard self.playbackSessionId == sessionId else { return }
                    self.startPlayback(url: cachedFile, autoPlay: autoPlay, startTime: startTime)
                    return
                }

                let decryptor = try QMCDecryptor.create(ekey: ekey)

                // 边下边解密：分块到达即按偏移解密落盘，省掉整段串行解密时间
                AppLogger.info("[QMC] 开始流式下载解密...")
                let downloadStart = CFAbsoluteTimeGetCurrent()
                let downloader = QMCStreamDownloader(decryptor: decryptor, destination: cachedFile)
                let byteCount = try await downloader.download(from: url, priority: URLSessionTask.highPriority)
                let downloadTime = CFAbsoluteTimeGetCurrent() - downloadStart

                guard self.playbackSessionId == sessionId else { return }

                AppLogger.success("[QMC] 下载+解密完成 (\(byteCount / 1024)KB，耗时 \(String(format: "%.1f", downloadTime))s): \(cachedFile.lastPathComponent)")

                await MainActor.run {
                    guard self.playbackSessionId == sessionId else { return }
                    self.startPlayback(url: cachedFile, autoPlay: autoPlay, startTime: startTime)
                }
            } catch {
                guard !Task.isCancelled else { return }
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
    
    // MARK: - QQ 下一首地址预取

    /// 正常 QQ 播放只预取直链；只有 Cookie 风控兜底明确返回加密媒体时，
    /// 才下载并解密到本地。
    func prefetchNextQQTrack(_ nextSong: Song) {
        guard isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard mode != .loopSingle else { return }
        guard nextSong.isQQMusic, let mid = nextSong.qqMid else { return }

        if localPlaybackURL(for: nextSong) != nil {
            return
        }

        let preferHighest = SettingsManager.shared.preferHighestPlaybackQuality
        let requestedQuality: QQMusicQuality? = preferHighest
            ? nil
            : Self.defaultQQPlaybackQuality()
        let cacheKey = PlaybackURLCache.qqKey(mid: mid, quality: requestedQuality?.rawValue)
        if let cached = PlaybackURLCache.shared.fresh(forKey: cacheKey),
           !cached.requiresQMCDecryption || cachedQMCFileURL(for: nextSong.id) != nil {
            return
        }
        let modelReportedQuality = nextSong.qqMaxQuality
        let songName = nextSong.name
        let songId = nextSong.id
        let sessionId = playbackSessionId

        qmcPrefetchTask = Task {
            // 任务自然结束后释放预取槽位（被取消替换时不清，避免抹掉新任务句柄）
            defer {
                if !Task.isCancelled { self.qmcPrefetchTask = nil }
            }
            do {
                AppLogger.info("[URL预解析] 开始预取下一首 QQ 地址: \(songName)")

                let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<APIService.SongUrlResult, Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = APIService.shared.fetchQQSongUrl(
                        mid: mid,
                        quality: requestedQuality,
                        prefetchedQuality: modelReportedQuality
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

                guard !Task.isCancelled,
                      self.isCurrentGaplessPrefetchTarget(nextSong, sessionId: sessionId) else { return }

                // 地址进短时缓存：手动切到这首时跳过 API 往返
                PlaybackURLCache.shared.store(
                    result,
                    forKey: cacheKey
                )

                guard result.requiresQMCDecryption,
                      let ekey = result.qmcEkey,
                      let url = URL(string: result.url) else {
                    AppLogger.info("[URL预解析] 下一首 QQ 直链已就绪: \(songName)")
                    return
                }

                let decryptor = try QMCDecryptor.create(ekey: ekey)

                let ext = url.pathExtension.contains("mflac") ? "flac"
                         : url.pathExtension.contains("mgg") ? "ogg"
                         : "flac"
                let outFile = Self.qmcCacheDir.appendingPathComponent("\(songId).\(ext)")

                // 边下边解密（临时文件原子落位，中途取消不会留下半截缓存）
                let downloader = QMCStreamDownloader(decryptor: decryptor, destination: outFile)
                let byteCount = try await downloader.download(from: url, priority: URLSessionTask.lowPriority)

                guard !Task.isCancelled,
                      self.isCurrentGaplessPrefetchTarget(nextSong, sessionId: sessionId) else { return }

                AppLogger.success("[QMC预缓存] Cookie 封控兜底已落盘: \(songName) (\(byteCount / 1024)KB)")
            } catch {
                if !Task.isCancelled,
                   self.isCurrentGaplessPrefetchTarget(nextSong, sessionId: sessionId) {
                    AppLogger.warning("[QQ预取] 预取失败: \(songName) - \(error.localizedDescription)")
                }
            }
        }
    }

    /// 阶段 A：NCM 下一首预解析播放地址进短时缓存。
    /// 命中后手动切歌零 API 往返；若解灰到 QMC 加密源则顺带下载解密，
    /// 让「NCM 解灰歌」也获得与 QQ 加密歌同级的无缝体验。
    func prefetchNextNCMTrack(_ song: Song) {
        guard isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard !song.isQQMusic, !song.isQishui else { return }

        let isPodcast = playSource.isPodcast
        let preferHighest = SettingsManager.shared.preferHighestPlaybackQuality
        let requestedQuality: SoundQuality? = preferHighest
            ? nil
            : Self.defaultNeteasePlaybackQuality()
        let modelReportedLevel = modelReportedNeteaseQuality(for: song)?.rawValue
        let cacheKey = PlaybackURLCache.neteaseKey(
            id: song.id,
            level: requestedQuality?.rawValue,
            isPodcast: isPodcast
        )

        if PlaybackURLCache.shared.fresh(forKey: cacheKey) != nil {
            return
        }

        let songName = song.name
        let songId = song.id
        let sessionId = playbackSessionId

        qmcPrefetchTask = Task {
            defer {
                if !Task.isCancelled { self.qmcPrefetchTask = nil }
            }
            do {
                let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<APIService.SongUrlResult, Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = APIService.shared.fetchSongUrl(
                        id: songId,
                        level: requestedQuality?.rawValue,
                        prefetchedLevel: modelReportedLevel,
                        skipUnblock: isPodcast
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

                guard !Task.isCancelled,
                      self.isCurrentGaplessPrefetchTarget(song, sessionId: sessionId) else { return }

                PlaybackURLCache.shared.store(result, forKey: cacheKey)
                AppLogger.info("[URL预解析] 下一首 NCM 地址已就绪: \(songName)")

                // 解灰到加密 QQ 源：顺带下载解密进 QMC 缓存（同名文件开播即命中）
                if let ekey = result.qmcEkey,
                   SettingsManager.shared.qmcDecryptEnabled,
                   let url = URL(string: result.url) {
                    let ext = url.pathExtension.contains("mgg") ? "ogg" : "flac"
                    let outFile = Self.qmcCacheDir.appendingPathComponent("\(songId).\(ext)")
                    guard !FileManager.default.fileExists(atPath: outFile.path) else { return }

                    let decryptor = try QMCDecryptor.create(ekey: ekey)
                    let downloader = QMCStreamDownloader(decryptor: decryptor, destination: outFile)
                    let byteCount = try await downloader.download(from: url, priority: URLSessionTask.lowPriority)
                    guard !Task.isCancelled,
                          self.isCurrentGaplessPrefetchTarget(song, sessionId: sessionId) else { return }
                    AppLogger.success("[QMC预缓存] 解灰源预缓存完成: \(songName) (\(byteCount / 1024)KB)")
                }
            } catch {
                if !Task.isCancelled,
                   self.isCurrentGaplessPrefetchTarget(song, sessionId: sessionId) {
                    AppLogger.debug("[URL预解析] 下一首 NCM 预解析失败: \(songName) - \(error.localizedDescription)")
                }
            }
        }
    }

    /// 预下载下一首汽水音乐到本地缓存（阶段 A）。产物两用：
    /// ① armGaplessPipeline 用本地文件 + 解密密钥装配无缝管线；
    /// ② 手动切歌时 downloadAndPlayQishuiAudio 命中同名缓存文件秒开。
    func prefetchNextQishuiTrack(_ song: Song) {
        guard isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard let trackId = song.qishuiTrackId else { return }

        if let asset = qishuiGaplessAsset,
           asset.trackId == trackId,
           FileManager.default.fileExists(atPath: asset.fileURL.path) {
            return
        }

        let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality
        let requestedQuality = shouldAutoSelectHighest ? "lossless" : qishuiSelectedQuality
        let songName = song.name
        let sessionId = playbackSessionId

        qmcPrefetchTask = Task {
            // 任务自然结束后释放预取槽位（被取消替换时不清，避免抹掉新任务句柄）
            defer {
                if !Task.isCancelled { self.qmcPrefetchTask = nil }
            }
            do {
                AppLogger.info("[汽水预缓存] 开始预缓存下一首: \(songName)")

                let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QishuiPlaybackResult, Error>) in
                    var cancellable: AnyCancellable?
                    cancellable = APIService.shared.fetchQishuiSongUrl(trackId: trackId, quality: requestedQuality)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                cont.resume(throwing: error)
                            }
                            _ = cancellable
                        }, receiveValue: { result in
                            cont.resume(returning: result)
                        })
                }

                guard !Task.isCancelled,
                      self.isCurrentGaplessPrefetchTarget(song, sessionId: sessionId),
                      !result.url.isEmpty else { return }
                guard let url = URL(string: result.url) else { return }

                let ext = result.decryptionKey != nil ? "enc.mp4" : "m4a"
                let cacheFile = Self.qishuiCacheDir
                    .appendingPathComponent("\(trackId)_\(result.quality).\(ext)")

                if FileManager.default.fileExists(atPath: cacheFile.path) {
                    AppLogger.info("[汽水预缓存] 命中已有缓存: \(songName)")
                } else {
                    var request = URLRequest(url: url)
                    request.setValue("https://www.qishui.com", forHTTPHeaderField: "Referer")
                    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
                    request.networkServiceType = .background

                    let (temporaryURL, response) = try await URLSession.shared.download(for: request)
                    try Task.checkCancellation()
                    guard self.isCurrentGaplessPrefetchTarget(song, sessionId: sessionId) else {
                        try? FileManager.default.removeItem(at: temporaryURL)
                        return
                    }

                    let httpResponse = response as? HTTPURLResponse
                    guard httpResponse?.statusCode == 200 else {
                        let code = httpResponse?.statusCode ?? -1
                        throw NSError(domain: "QishuiPrefetch", code: code, userInfo: [
                            NSLocalizedDescriptionKey: "CDN 下载失败 HTTP \(code)"
                        ])
                    }
                    if FileManager.default.fileExists(atPath: cacheFile.path) {
                        try? FileManager.default.removeItem(at: temporaryURL)
                    } else {
                        try FileManager.default.moveItem(at: temporaryURL, to: cacheFile)
                    }
                    let attributes = try FileManager.default.attributesOfItem(atPath: cacheFile.path)
                    let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
                    guard fileSize > 0 else {
                        throw NSError(domain: "QishuiPrefetch", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "CDN 下载文件为空"
                        ])
                    }
                    AppLogger.success("[汽水预缓存] 预缓存完成: \(songName) (\(fileSize / 1024)KB)")
                }

                guard self.isCurrentGaplessPrefetchTarget(song, sessionId: sessionId) else { return }
                self.pendingGaplessResolvedQuality = .qishui(
                    trackId: trackId,
                    quality: result.quality
                )
                self.qishuiGaplessAsset = (trackId: trackId, fileURL: cacheFile, decryptionKey: result.decryptionKey)
                self.armGaplessPipeline(sessionId: sessionId)
            } catch {
                if !Task.isCancelled,
                   self.isCurrentGaplessPrefetchTarget(song, sessionId: sessionId) {
                    AppLogger.warning("[汽水预缓存] 预缓存失败: \(songName) - \(error.localizedDescription)")
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
