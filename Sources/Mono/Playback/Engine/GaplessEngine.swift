// Mono Continuity 连续播放引擎（阶段 A 预取 + 阶段 B 预装 + 会话事务去重）。
// 旧版在开播 0.35s 后立即解析下一首 URL 并装配 SDK 管线，带来一串问题：
// ① 长曲/播客临近结尾时预解析的 URL 早已过期，EOF 切换必然失败；
// ② 队列/播放模式中途变化不会重装，EOF 会切进已被移除的旧曲目；
// ③ 频繁手动切歌时每首都白白解析一次下一首 URL；
// ④ 汽水音乐完全没有无缝路径；单曲循环每轮整机重载，有可闻间隙。
// 新版拆成两阶段：
// - 阶段 A（开播稳定后）：只解析下一首真实音质和播放地址；需要本地媒体的
//   风控解密/汽水源同时低优先级落盘，不提前长期占用 CDN 连接。
// - 阶段 B（剩余 ≤12s，由进度心跳驱动）：复用阶段 A 的地址缓存，创建
//   新鲜 demuxer/decoder 并预解码 PCM。
// 队列/模式一变即失效重装（invalidatePreparation），
// EOF 恰落在重装窗口内时还有 applyPendingTrackTransition 的对账兜底。
// 跨界原则：待切换事务标记（hasPendingTrackTransition / pendingNextSong）与
// 队列游标推进等共享状态仍在 PlayerManager 上，本类通过 player 引用读写，
// 保证与呈现事务（pendingPlaybackPresentation*）的原子性不被拆散。

import Foundation
import Combine
import FFmpegSwiftSDK
import QQMusicKit

@MainActor
private func firstPublisherValue<P: Publisher>(_ publisher: P) async throws -> P.Output {
    for try await value in publisher.values {
        return value
    }
    throw NSError(
        domain: "PlaybackPrefetch",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "请求完成但没有返回播放数据"]
    )
}

@MainActor
final class MonoContinuityEngine {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    // MARK: - 装配窗口常量

    /// 阶段 B 装配窗口：剩余时长进入该窗口才装配管线
    static let gaplessArmWindow: TimeInterval = 12
    /// 就绪复查窗口：剩余进入该窗口且管线未就绪则重试装配
    static let gaplessRetryWindow: TimeInterval = 6
    /// 网络 demuxer 长时间不读包后容易被 CDN 断开，超过该时长不再热切。
    static let maxWarmNetworkPipelineAge: TimeInterval = 20

    // MARK: - 状态

    /// 阶段 A 已调度过的会话（防止同一首歌重复调度预取）
    var scheduledGaplessPreparationSessionId: Int?
    /// 阶段 A 延时调度任务
    var gaplessPreparationWorkItem: DispatchWorkItem?
    /// 阶段 B 已装配的会话标记
    var gaplessArmedSessionId: Int?
    /// 阶段 B 装配尝试次数（临近结尾限次重试）
    var gaplessArmAttempts: Int = 0
    var lastGaplessArmAttemptAt: Date?
    /// 单曲循环无缝回绕已装配
    var pendingLoopRestart = false
    /// 预装管线解析出的真实音质（切换完成时提交）
    var pendingGaplessResolvedQuality: PlayerManager.ResolvedPlaybackQuality?
    /// 交给 Mono next 通道的播放输入（切换回调用它对账）
    var pendingGaplessPlaybackInput: String?
    /// 下一首 URL 解析订阅
    var nextTrackCancellable: AnyCancellable?
    /// 阶段 A 重媒体预取任务（QMC 解密 / 汽水下载；同一时间只有一个）
    var qmcPrefetchTask: Task<Void, Never>?
    /// 汽水音乐阶段 A 预取产物（trackId + 本地文件 + 解密密钥）
    var qishuiGaplessAsset: (trackId: Int, fileURL: URL, decryptionKey: String?)?

    /// 预期整曲时长：优先 API 元数据，回落 FFmpeg 实测
    private var expectedCurrentTrackDuration: Double {
        player.effectivePlaybackDuration
    }

    // MARK: - 设置变化

    func handleGaplessPlaybackSettingChanged(enabled: Bool) {
        player.streamPlayer.setAutomaticPreparedTrackTransitionEnabled(enabled)
        player.streamPlayer.setCrossfadeDuration(
            enabled && PlayerManager.crossfadePlaybackEnabled()
                ? PlayerManager.crossfadePlaybackDuration
                : 0
        )
        if enabled {
            scheduledGaplessPreparationSessionId = nil
            disarm()
            guard player.isPlaying, player.currentSong != nil else { return }
            scheduleMediaPrefetchIfNeeded()
            return
        }

        cancelPreparation(resetPendingState: true)
    }

    func handleCrossfadePlaybackSettingChanged(enabled: Bool) {
        player.streamPlayer.setCrossfadeDuration(
            player.isGaplessPlaybackEnabled && enabled
                ? PlayerManager.crossfadePlaybackDuration
                : 0
        )
    }

    // MARK: - 装配状态管理

    /// 清空阶段 B 装配状态（不触碰 SDK 管线本身）
    func disarm() {
        gaplessArmedSessionId = nil
        gaplessArmAttempts = 0
        lastGaplessArmAttemptAt = nil
        pendingLoopRestart = false
        pendingGaplessResolvedQuality = nil
        pendingGaplessPlaybackInput = nil
    }

    func cancelPreparation(resetPendingState: Bool) {
        gaplessPreparationWorkItem?.cancel()
        gaplessPreparationWorkItem = nil
        scheduledGaplessPreparationSessionId = nil
        gaplessArmedSessionId = nil
        lastGaplessArmAttemptAt = nil

        nextTrackCancellable?.cancel()
        nextTrackCancellable = nil

        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil

        if player.pendingQualitySwitchSeek == nil {
            player.streamPlayer.cancelNextPreparation()
        }

        if resetPendingState {
            player.hasPendingTrackTransition = false
            player.pendingNextSong = nil
            player.pendingTransitionStartedAt = nil
            player.pendingTransitionSessionId = 0
            pendingLoopRestart = false
            gaplessArmAttempts = 0
            pendingGaplessResolvedQuality = nil
            pendingGaplessPlaybackInput = nil
        }
    }

    /// 取消下一首 URL 解析订阅
    func cancelNextTrackResolution() {
        nextTrackCancellable?.cancel()
        nextTrackCancellable = nil
    }

    /// 取消阶段 A 的重媒体预取任务
    func cancelQmcPrefetch() {
        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil
    }

    /// 取消阶段 A 的延时调度（含调度标记）
    func cancelScheduledMediaPrefetch() {
        gaplessPreparationWorkItem?.cancel()
        gaplessPreparationWorkItem = nil
        scheduledGaplessPreparationSessionId = nil
    }

    /// deinit 清理
    func cancelAllWork() {
        gaplessPreparationWorkItem?.cancel()
        gaplessPreparationWorkItem = nil
        nextTrackCancellable?.cancel()
        nextTrackCancellable = nil
        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil
    }

    // MARK: - 阶段 B：装配

    /// 阶段 B 主入口：由 0.25s 进度心跳驱动（后台降为 1Hz）。
    /// 装配一次后置位会话标记；临近 EOF 复查就绪状态，失败限次重装。
    func tick() {
        guard player.isGaplessPlaybackEnabled,
              player.isPlaying,
              player.currentSong?.isAppleMusic == false,
              player.pendingPlaybackPresentationSong == nil,
              player.pendingQualitySwitchSeek == nil,
              !player.pendingSleepStopAfterCurrentTrack,
              !player.isSeeking else { return }

        let expected = expectedCurrentTrackDuration
        guard expected > 1 else { return }
        let remaining = expected - player.currentTime
        let sessionId = player.playbackSessionId

        guard remaining <= Self.gaplessArmWindow else { return }
        // StreamPlayer 安装下一首后会消费 next 槽位，因此 isNextTrackReady 会变回
        // false；旧歌尾音排空前，切歌通知仍在延迟。此时绝不能把 false 当作
        // 预装失败再次装配，否则同一目标会残留为下一首并被完整播放两遍。
        guard !player.streamPlayer.isTrackTransitionNotificationDeferred else { return }
        // 阶段 A 的地址解析仍在进行时不要计入一次失败装配。缓存一写入，
        // 下一个 0.25s tick 会立刻进入阶段 B，不再被 4 秒重试节流拖住。
        if gaplessArmedSessionId != sessionId, qmcPrefetchTask != nil {
            return
        }
        if gaplessArmedSessionId == sessionId {
            if let next = player.upcomingPlaybackSong(),
               !isPreparedPipelineFresh(for: next) {
                AppLogger.info("[MonoContinuity] 曲尾刷新过久的网络预装管线")
                nextTrackCancellable?.cancel()
                nextTrackCancellable = nil
                player.streamPlayer.cancelNextPreparation()
                player.hasPendingTrackTransition = false
                player.pendingNextSong = nil
                player.pendingTransitionStartedAt = nil
                player.pendingTransitionSessionId = 0
                gaplessArmedSessionId = nil
                gaplessArmAttempts = 0
                lastGaplessArmAttemptAt = nil
                pendingGaplessResolvedQuality = nil
            } else {
            // 已装配：临近结尾复查 SDK 管线是否真的就绪（预加载静默失败时重试一次）
                guard remaining <= Self.gaplessRetryWindow,
                      remaining > 1.5,
                      gaplessArmAttempts < 2,
                      !player.streamPlayer.isNextTrackReady,
                      Date().timeIntervalSince(lastGaplessArmAttemptAt ?? .distantPast) > 3 else {
                    return
                }
                AppLogger.warning("[MonoContinuity] 管线未就绪，临近结尾重试装配")
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
        armPipeline(sessionId: sessionId)
    }

    /// 本地文件可长时间保持预装；网络管线只在短窗口内视为可靠。
    func isPreparedPipelineFresh(for song: Song) -> Bool {
        if player.localPlaybackURL(for: song) != nil
            || DecryptedAudioCacheGovernor.cachedQMCFileURL(for: song) != nil {
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
    private func armPipeline(sessionId: Int) {
        // 单曲循环：用当前源无缝回绕，不经过 loadAndPlay
        if player.mode == .loopSingle {
            guard let url = player.currentPlayingURL else { return }
            gaplessArmedSessionId = sessionId
            gaplessArmAttempts += 1
            pendingLoopRestart = true
            prepareGaplessPlaybackInput(url, decryptionKey: player.currentPlayingDecryptionKey)
            AppLogger.info("[MonoContinuity] 已装配单曲循环回绕")
            return
        }

        guard let next = player.upcomingPlaybackSong(),
              !next.isAppleMusic else { return }
        lastGaplessArmAttemptAt = Date()

        // 本地文件和已经解密落盘的 QMC 不需要等待重媒体预取，开播稳定后
        // 立即把完整 demux / decoder / preroll 管线暖好，手动下一曲可直接热切。
        if player.localPlaybackURL(for: next) != nil
            || DecryptedAudioCacheGovernor.cachedQMCFileURL(for: next) != nil {
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
            AppLogger.info("[MonoContinuity] 已装配汽水缓存: \(next.name)")
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
        player.streamPlayer.prepareNext(url: input, decryptionKey: decryptionKey)
    }

    // MARK: - 切换回调（单曲循环回绕 / 无缝切歌落地）

    /// 单曲循环无缝回绕完成：SDK 已从头开播同一首，重置进度与逐字歌词
    func handleSeamlessLoopRestart(engineInput: String?) {
        guard let expectedInput = pendingGaplessPlaybackInput,
              let engineInput,
              engineInput == expectedInput else {
            AppLogger.error(
                "[MonoContinuity] 单曲循环输入不一致 expected=\(pendingGaplessPlaybackInput ?? "nil") engine=\(engineInput ?? "nil")",
                step: "playback.loop.input-mismatch"
            )
            let song = player.currentSong
            cancelPreparation(resetPendingState: true)
            if let song {
                player.loadAndPlay(song: song)
            }
            return
        }
        player.advanceApplicationPlaybackSession()
        let transitionTime = player.currentEngineTransitionTime()
        player.currentTime = transitionTime
        LyricViewModel.shared.updateCurrentTime(transitionTime)
        player.playbackStartedAt = Date()
        if let song = player.currentSong {
            player.addToHistory(song: song)
        }
        // 允许下一轮循环重新装配
        disarm()
        player.updateNowPlayingInfo()
        player.saveState()
        player.syncWidgetState()
    }

    /// Reconciles app metadata when Mono has switched to a prepared pipeline but
    /// the delegate notification was delayed while the app was in the background.
    /// The engine explicitly reports its audible-tail deferral so this fallback
    /// never advances the UI while the previous track is still heard.
    func reconcilePendingTrackTransitionWithEngine(reason: String) {
        guard player.isGaplessPlaybackEnabled,
              player.hasPendingTrackTransition,
              player.pendingNextSong != nil,
              player.pendingQualitySwitchSeek == nil,
              !pendingLoopRestart,
              player.pendingTransitionSessionId == player.playbackSessionId,
              !player.streamPlayer.isTrackTransitionNotificationDeferred,
              let engineURL = player.streamPlayer.streamInfo?.url,
              let applicationURL = player.currentPlayingURL,
              engineURL != applicationURL else { return }

        AppLogger.warning(
            "[MonoContinuity] 引擎已切歌但应用元数据未同步，执行对账 (reason=\(reason))"
        )
        applyPendingTrackTransition(engineInput: player.streamPlayer.currentPlaybackInput)
    }

    /// Mono may have already installed the prepared next pipeline while its old
    /// audible tail is still draining. Treat another request for that same target
    /// as already in progress instead of preparing and replaying it a second time.
    @discardableResult
    func reconcileAlreadyActiveTarget(_ target: Song, reason: String) -> Bool {
        guard player.isGaplessPlaybackEnabled,
              player.hasPendingTrackTransition,
              player.matchesPlaybackTarget(player.pendingNextSong, expected: target),
              let expectedInput = pendingGaplessPlaybackInput,
              let engineInput = player.streamPlayer.currentPlaybackInput,
              engineInput == expectedInput else { return false }

        AppLogger.info(
            "[MonoContinuity] 目标管线已经在内核中生效，忽略重复切歌 target=\(target.name) reason=\(reason)",
            step: "playback.transition.already-active"
        )
        reconcilePendingTrackTransitionWithEngine(reason: reason)
        return true
    }

    /// 预装目标已进入底层管线、但呈现回调尚未提交时发生 stop/error，
    /// 恢复逻辑必须重开真实目标，不能依据仍显示在 UI 上的上一首进行重播。
    func activeTransitionRecoveryTarget(engineInput: String?) -> Song? {
        guard player.isGaplessPlaybackEnabled,
              player.hasPendingTrackTransition,
              player.pendingTransitionSessionId == player.playbackSessionId,
              let target = player.pendingNextSong,
              let expectedInput = pendingGaplessPlaybackInput,
              let engineInput,
              engineInput == expectedInput else { return nil }
        return target
    }

    private func isCurrentArmTarget(_ song: Song, sessionId: Int) -> Bool {
        player.playbackSessionId == sessionId
            && player.isGaplessPlaybackEnabled
            && gaplessArmedSessionId == sessionId
            && player.matchesPlaybackTarget(player.pendingNextSong, expected: song)
            && player.matchesPlaybackTarget(player.upcomingPlaybackSong(), expected: song)
    }

    private func isCurrentPrefetchTarget(_ song: Song, sessionId: Int) -> Bool {
        player.playbackSessionId == sessionId
            && player.isGaplessPlaybackEnabled
            && player.mode != .loopSingle
            && player.matchesPlaybackTarget(player.upcomingPlaybackSong(), expected: song)
    }

    /// 队列 / 播放模式变化后调用：已装配的下一首管线可能指向过期曲目。
    /// 下一首实际没变则原样保留；变了就拆掉，交给 tick 按新队列重装。
    func invalidatePreparation(reason: String) {
        guard player.isGaplessPlaybackEnabled else { return }
        guard player.pendingQualitySwitchSeek == nil else { return }

        let armed = gaplessArmedSessionId == player.playbackSessionId
        guard armed || player.hasPendingTrackTransition || pendingLoopRestart else {
            // 尚未装配管线：取消旧目标的异步预取，再换成新的下一首。
            // Combine continuation 不会因 Swift Task.cancel 自动停下，后续写入还会
            // 由目标校验拦截；这里清空任务槽位，让新目标无需等待旧请求结束。
            qmcPrefetchTask?.cancel()
            qmcPrefetchTask = nil
            scheduleMediaPrefetchIfNeeded(force: true)
            return
        }

        // 循环回绕装配与队列内容无关（模式变化会走 loadAndPlay/switchMode 复位）
        if pendingLoopRestart, player.mode == .loopSingle {
            return
        }

        // 装配目标与新队列一致 → 不折腾
        if !pendingLoopRestart,
           player.mode != .loopSingle,
           let pending = player.pendingNextSong,
           let upcoming = player.upcomingPlaybackSong(),
           player.matchesPlaybackTarget(pending, expected: upcoming) {
            return
        }

        AppLogger.info("[MonoContinuity] 队列已变化，重装下一首管线（\(reason)）")
        cancelPreparation(resetPendingState: true)
        scheduleMediaPrefetchIfNeeded(force: true)
        // tick 会在下一拍按新队列重新装配（gaplessArmedSessionId 已清空）
    }

    // MARK: - 阶段 A：媒体预取

    /// 阶段 A 调度：开播稳定后（或队列变化后）延时预取下一首重媒体。
    /// force = 队列变化触发的重预取（同时充当连续编辑的防抖）。
    func scheduleMediaPrefetchIfNeeded(force: Bool = false) {
        guard player.isGaplessPlaybackEnabled,
              player.pendingPlaybackPresentationSong == nil,
              player.currentSong?.isAppleMusic != true else { return }
        let sessionId = player.playbackSessionId
        if !force {
            guard scheduledGaplessPreparationSessionId != sessionId else { return }
        }
        scheduledGaplessPreparationSessionId = sessionId

        gaplessPreparationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.player.playbackSessionId == sessionId else { return }
            guard self.player.isPlaying, self.player.currentSong != nil else { return }
            self.beginMediaPrefetch()
        }
        gaplessPreparationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (force ? 0.35 : 0.65), execute: workItem)
    }

    /// 阶段 A 本体：开播稳定后只解析并缓存下一首地址，不创建会长时间
    /// 空置的网络 demuxer。需要完整本地媒体的来源会在后台下载完成。
    func beginMediaPrefetch() {
        guard player.isGaplessPlaybackEnabled,
              player.mode != .loopSingle,
              player.pendingPlaybackPresentationSong == nil else { return }
        guard let next = player.upcomingPlaybackSong(),
              !next.isAppleMusic else { return }
        let sessionId = player.playbackSessionId

        if next.isQishui {
            if player.localPlaybackURL(for: next) != nil {
                armPipeline(sessionId: sessionId)
                return
            }
            prefetchNextQishuiTrack(next)
            return
        }

        if next.isKugou {
            prefetchNextKugouTrack(next)
            return
        }

        if next.isQQMusic {
            prefetchNextQQTrack(next)
        } else {
            prefetchNextNCMTrack(next)
        }
    }

    // MARK: - 待切换下一首（EOF 对账）

    /// 准备下一首歌曲信息（不更新 UI，等待当前歌曲真正结束）
    func preparePendingNextTrack() {
        guard player.isGaplessPlaybackEnabled else {
            player.hasPendingTrackTransition = false
            player.pendingNextSong = nil
            player.pendingTransitionStartedAt = nil
            player.pendingTransitionSessionId = 0
            return
        }
        guard player.mode != .loopSingle else { return }
        guard !player.pendingSleepStopAfterCurrentTrack else {
            player.hasPendingTrackTransition = false
            player.pendingNextSong = nil
            player.pendingTransitionStartedAt = nil
            player.pendingTransitionSessionId = 0
            return
        }

        guard let upcoming = player.upcomingPlaybackSong() else {
            player.hasPendingTrackTransition = false
            player.pendingNextSong = nil
            player.pendingTransitionStartedAt = nil
            player.pendingTransitionSessionId = 0
            return
        }

        // 同一会话、同一目标的重试只更新底层预装管线，不重复创建应用层切换事务。
        // 避免阶段 B 复查与手动切歌同时进入时，把同一首登记为两次待切换。
        if player.hasPendingTrackTransition,
           player.pendingTransitionSessionId == player.playbackSessionId,
           player.matchesPlaybackTarget(player.pendingNextSong, expected: upcoming) {
            return
        }

        player.pendingNextSong = upcoming
        player.hasPendingTrackTransition = true
        player.pendingTransitionStartedAt = Date()
        player.pendingTransitionSessionId = player.playbackSessionId
    }

    /// 当前歌曲真正结束后，应用待切换的下一首
    func applyPendingTrackTransition(engineInput: String? = nil) {
        guard player.isGaplessPlaybackEnabled else {
            cancelPreparation(resetPendingState: true)
            return
        }

        if player.pendingSleepStopAfterCurrentTrack {
            player.pendingSleepStopAfterCurrentTrack = false
            player.stopAfterQueueExhausted()
            return
        }

        guard let song = player.pendingNextSong else {
            if player.hasPendingTrackTransition {
                AppLogger.warning("applyPendingTrackTransition: pendingNextSong 为 nil，重置标记")
            }
            player.hasPendingTrackTransition = false
            player.pendingNextSong = nil
            player.pendingTransitionStartedAt = nil
            player.pendingTransitionSessionId = 0
            return
        }

        // 用户已手动切歌（session 变了），放弃本次无缝切换
        if player.pendingTransitionSessionId != player.playbackSessionId {
            AppLogger.info("applyPendingTrackTransition: session 已变更，跳过")
            player.hasPendingTrackTransition = false
            player.pendingNextSong = nil
            player.pendingTransitionStartedAt = nil
            player.pendingTransitionSessionId = 0
            return
        }

        // 对账兜底：EOF 与队列编辑竞态时，装配好的下一首可能已不是队列的真实下一首
        // （invalidate 还没来得及拆装配就到了 EOF）。此时放弃无缝，硬切到正确曲目。
        if player.mode != .loopSingle,
           let expected = player.upcomingPlaybackSong(),
           !player.matchesPlaybackTarget(song, expected: expected) {
            AppLogger.warning("[MonoContinuity] EOF 与队列变化竞态，改播真实下一首: \(expected.name)")
            player.hasPendingTrackTransition = false
            player.pendingNextSong = nil
            player.pendingTransitionStartedAt = nil
            player.pendingTransitionSessionId = 0
            player.loadAndPlay(song: expected)
            return
        }

        let resolvedEngineInput = engineInput ?? player.streamPlayer.currentPlaybackInput
        guard let expectedInput = pendingGaplessPlaybackInput,
              let resolvedEngineInput,
              resolvedEngineInput == expectedInput else {
            AppLogger.error(
                "[MonoContinuity] 内核播放输入与待切歌曲不一致，拒绝提交 UI target=\(song.name) expected=\(pendingGaplessPlaybackInput ?? "nil") engine=\(resolvedEngineInput ?? "nil")",
                step: "playback.continuity.input-mismatch"
            )
            cancelPreparation(resetPendingState: true)
            player.loadAndPlay(song: song)
            return
        }

        player.hasPendingTrackTransition = false
        player.pendingNextSong = nil
        player.pendingTransitionStartedAt = nil
        player.pendingTransitionSessionId = 0

        player.advanceApplicationPlaybackSession()
        let transitionTime = player.currentEngineTransitionTime()

        player.applyAutomaticTransitionNavigationState(to: song)
        if let index = player.currentContextList.firstIndex(where: {
            player.matchesPlaybackTarget($0, expected: song)
        }) {
            player.contextIndex = index
        }

        player.commitPendingPlaybackQueueMutation()
        player.currentSong = song
        player.currentTime = transitionTime
        player.engineReportedDuration = nil
        player.duration = song.dt.map { Double($0) / 1000.0 } ?? 0
        player.applyResolvedPlaybackQuality(pendingGaplessResolvedQuality, for: song)
        pendingGaplessResolvedQuality = nil

        // 确保播放状态正确（无缝切歌时 SDK 一直在播放，isPlaying 应为 true）
        if !player.isPlaying {
            player.isPlaying = true
        }

        // 从 streamInfo 获取下一首的 duration（transitionToNextTrack 中不再单独发送 didUpdateDuration）
        if let nextDuration = player.streamPlayer.streamInfo?.duration, nextDuration > 0 {
            player.engineReportedDuration = nextDuration
            player.duration = nextDuration
        }

        // 同步「当前播放源」到已切换的新管线：
        // 单曲循环回绕装配 / 断流重连都依赖这两个字段，无缝切换不经过
        // startPlayback，不同步会让后续装配拿到上一首的过期地址。
        if let info = player.streamPlayer.streamInfo {
            player.currentPlayingURL = info.url
            // 无缝管线的地址在装配时（临近上一首结尾）解析，视作此刻新鲜
            player.playbackURLResolvedAt = Date()
        }
        if song.isQishui,
           let asset = qishuiGaplessAsset,
           asset.trackId == song.qishuiTrackId {
            player.currentPlayingDecryptionKey = asset.decryptionKey
        } else {
            player.currentPlayingDecryptionKey = nil
        }
        if let currentInput = player.currentPlayingURL {
            player.rememberRecentPlaybackInput(
                currentInput,
                decryptionKey: player.currentPlayingDecryptionKey,
                for: song
            )
        }

        player.fetchLyricsForSong(song)
        player.loadSongExtras(for: song)
        player.addToHistory(song: song)
        player.saveState()
        player.updateNowPlayingInfo()
        player.updateNowPlayingArtwork(for: song)
        player.syncWidgetState()
        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor [player] in
            await LyricsLiveActivityManager.shared.sync(with: player, forceRestart: true)
        }
        #endif

        // 无缝切歌不会经过 loadAndPlay，需要手动重置这些“按当前歌曲一次性执行”的任务状态
        qmcPrefetchTask?.cancel()
        qmcPrefetchTask = nil
        nextTrackCancellable?.cancel()
        player.playbackStartedAt = Date()
        LyricViewModel.shared.updateCurrentTime(transitionTime)

        // 重启无缝链路：阶段 A 立即调度（session 未变，需先清调度标记），
        // 阶段 B 交给进度 tick 在临近结尾时装配，形成连续无缝链条
        disarm()
        scheduledGaplessPreparationSessionId = nil
        scheduleMediaPrefetchIfNeeded()
    }

    // MARK: - 下一首 URL 解析与装配

    /// 预加载下一首歌曲的 URL，传给 StreamPlayer.prepareNext
    func prepareNextTrackURL() {
        guard player.isGaplessPlaybackEnabled else {
            cancelPreparation(resetPendingState: true)
            return
        }
        guard player.mode != .loopSingle else { return }
        let sessionId = player.playbackSessionId

        guard let song = player.upcomingPlaybackSong(),
              !song.isAppleMusic else { return }

        // 优先使用本地文件
        if let localURL = player.localPlaybackURL(for: song) {
            AppLogger.info("预加载下一首 (本地): \(song.name)")
            prepareGaplessPlaybackInput(localURL.playerInputString)
            return
        }

        if let cachedQMCFile = DecryptedAudioCacheGovernor.cachedQMCFileURL(for: song) {
            AppLogger.info("[QMC] 预加载下一首（解密缓存）: \(song.name)")
            prepareGaplessPlaybackInput(cachedQMCFile.playerInputString)
            return
        }

        // 汽水音乐不走本函数：需要先下载解密，由阶段 A 预取 + armPipeline 装配
        guard !song.isQishui else { return }

        nextTrackCancellable?.cancel()
        player.streamPlayer.cancelNextPreparation()

        // 网络获取 URL：与正式开播使用完全相同的音质策略与缓存键。
        if song.isKugou {
            let requestedQuality = player.kugouSoundQuality
            let cacheKey = PlaybackURLCache.kugouKey(
                hash: song.kugouHash ?? String(song.id),
                quality: requestedQuality.rawValue
            )
            let installResult: (KCMPlaybackURLResult) -> Void = { [weak self] result in
                guard let self,
                      self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                self.pendingGaplessResolvedQuality = .kugou(
                    hash: song.kugouHash ?? String(song.id),
                    quality: result.quality
                )
                AppLogger.info("[KCM] 装配下一首: \(song.name)")
                self.prepareGaplessPlaybackInput(result.url.playerInputString)
            }

            if let cached = PlaybackURLCache.shared.freshKugou(forKey: cacheKey) {
                AppLogger.info("[URLCache] KCM 无缝装配命中地址缓存: \(song.name)")
                installResult(cached)
                return
            }

            nextTrackCancellable = APIService.shared.fetchKugouSongURL(
                song: song,
                quality: requestedQuality
            )
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self,
                          self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                    if case .failure(let error) = completion {
                        AppLogger.warning("[KCM] 预加载下一首 URL 获取失败: \(error)")
                    }
                }, receiveValue: { [weak self] result in
                    guard let self,
                          self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                    PlaybackURLCache.shared.storeKugou(result, forKey: cacheKey)
                    installResult(result)
                })
        } else if song.isQQMusic, let mid = song.qqMid {
            let modelReportedQuality = song.qqMaxQuality
            let requestedQuality: QQMusicQuality? = SettingsManager.shared.preferHighestPlaybackQuality
                ? nil
                : PlayerManager.defaultQQPlaybackQuality()
            let cacheKey = PlaybackURLCache.qqKey(mid: mid, quality: requestedQuality?.rawValue)
            let installResult: (APIService.SongUrlResult) -> Void = { [weak self] result in
                guard let self,
                      self.isCurrentArmTarget(song, sessionId: sessionId),
                      let url = URL(string: result.url) else { return }
                self.rememberResolvedQuality(result, for: song)

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
                              self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                        if case .failure(let error) = completion {
                            AppLogger.warning("[QQMusic] 预加载下一首 URL 获取失败: \(error)")
                        }
                    }, receiveValue: { [weak self] result in
                        guard let self,
                              self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                        PlaybackURLCache.shared.store(result, forKey: cacheKey)
                        installResult(result)
                    })
            }
        } else {
            let modelReportedLevel = player.modelReportedNeteaseQuality(for: song)?.rawValue
            let requestedQuality: SoundQuality? = SettingsManager.shared.preferHighestPlaybackQuality
                ? nil
                : PlayerManager.defaultNeteasePlaybackQuality()
            let cacheKey = PlaybackURLCache.neteaseKey(
                id: song.id,
                level: requestedQuality?.rawValue,
                isPodcast: player.playSource.isPodcast
            )
            let installResult: (APIService.SongUrlResult) -> Void = { [weak self] result in
                guard let self,
                      self.isCurrentArmTarget(song, sessionId: sessionId),
                      let url = URL(string: result.url) else { return }
                self.rememberResolvedQuality(result, for: song)

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
                          self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                    if case .failure(let error) = completion {
                        AppLogger.warning("预加载下一首 URL 获取失败: \(error)")
                    }
                }, receiveValue: { [weak self] result in
                    guard let self,
                          self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                    if !self.player.playSource.isPodcast {
                        PlaybackURLCache.shared.store(result, forKey: cacheKey)
                    }
                    installResult(result)
                })
            }
        }
    }

    private func rememberResolvedQuality(_ result: APIService.SongUrlResult, for song: Song) {
        if song.isQQMusic,
           let mid = song.qqMid,
           let quality = result.actualQQQuality {
            pendingGaplessResolvedQuality = .qq(mid: mid, quality: quality)
        } else if !song.isQishui, !song.isKugou, !song.isAppleMusic,
                  let quality = result.actualNeteaseQuality {
            pendingGaplessResolvedQuality = .netease(songId: song.id, quality: quality)
        }
    }

    private func prepareDecryptedNextTrack(url: URL, ekey: String, song: Song, sessionId: Int) {
        guard isCurrentArmTarget(song, sessionId: sessionId) else { return }

        if let cachedFile = DecryptedAudioCacheGovernor.cachedQMCFileURL(for: song) {
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
                if !Task.isCancelled, self.player.playbackSessionId == sessionId {
                    self.qmcPrefetchTask = nil
                }
            }

            do {
                let ext = url.pathExtension.contains("mflac") ? "flac"
                         : url.pathExtension.contains("mgg") ? "ogg"
                         : "flac"
                let cachedFile = DecryptedAudioCacheGovernor.qmcCacheURL(for: song, extension: ext)

                if FileManager.default.fileExists(atPath: cachedFile.path),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: cachedFile.path),
                   let size = attrs[.size] as? Int, size > 1024 {
                    guard self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                    AppLogger.info("[QMC] 命中缓存，预加载下一首: \(song.name)")
                    DecryptedAudioCacheGovernor.touchCacheFile(at: cachedFile)
                    self.prepareGaplessPlaybackInput(cachedFile.playerInputString)
                    return
                }

                let decryptor = try QMCDecryptor.create(ekey: ekey)
                // 边下边解密，落位即装配
                let downloader = QMCStreamDownloader(decryptor: decryptor, destination: cachedFile)
                _ = try await downloader.download(from: url, priority: URLSessionTask.lowPriority)

                guard !Task.isCancelled,
                      self.isCurrentArmTarget(song, sessionId: sessionId) else { return }
                AppLogger.info("[QMC] 解密完成，预加载下一首: \(song.name)")
                self.prepareGaplessPlaybackInput(cachedFile.playerInputString)
            } catch {
                guard !Task.isCancelled else { return }
                guard self.player.playbackSessionId == sessionId else { return }
                AppLogger.warning("[QMC] 预加载下一首解密失败: \(song.name) - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 阶段 A 预取：KCM / QQ / NCM / 汽水

    /// 阶段 A：KCM 下一首预解析播放地址进短时缓存。
    /// 阶段 B 和用户手动切歌都会复用该结果，不再临近结尾才首次请求。
    func prefetchNextKugouTrack(_ song: Song) {
        guard player.isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard player.mode != .loopSingle, song.isKugou else { return }
        guard let hash = song.kugouHash, !hash.isEmpty else { return }

        let requestedQuality = player.kugouSoundQuality
        let cacheKey = PlaybackURLCache.kugouKey(
            hash: hash,
            quality: requestedQuality.rawValue
        )
        if PlaybackURLCache.shared.freshKugou(forKey: cacheKey) != nil {
            return
        }

        let sessionId = player.playbackSessionId
        let songName = song.name
        qmcPrefetchTask = Task {
            defer {
                if !Task.isCancelled { self.qmcPrefetchTask = nil }
            }
            do {
                AppLogger.info("[URL预解析] 开始预取下一首 KCM 地址: \(songName)")
                let result = try await firstPublisherValue(
                    APIService.shared.fetchKugouSongURL(
                        song: song,
                        quality: requestedQuality
                    )
                )
                guard !Task.isCancelled,
                      self.isCurrentPrefetchTarget(song, sessionId: sessionId) else { return }
                PlaybackURLCache.shared.storeKugou(result, forKey: cacheKey)
                AppLogger.info("[URL预解析] 下一首 KCM 地址已就绪: \(songName)")
            } catch {
                if !Task.isCancelled,
                   self.isCurrentPrefetchTarget(song, sessionId: sessionId) {
                    AppLogger.warning("[KCM预取] 预取失败: \(songName) - \(error.localizedDescription)")
                }
            }
        }
    }

    /// 正常 QQ 播放只预取直链；只有 Cookie 风控兜底明确返回加密媒体时，
    /// 才下载并解密到本地。
    func prefetchNextQQTrack(_ nextSong: Song) {
        guard player.isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard player.mode != .loopSingle else { return }
        guard nextSong.isQQMusic, let mid = nextSong.qqMid else { return }

        if player.localPlaybackURL(for: nextSong) != nil {
            return
        }

        let preferHighest = SettingsManager.shared.preferHighestPlaybackQuality
        let requestedQuality: QQMusicQuality? = preferHighest
            ? nil
            : PlayerManager.defaultQQPlaybackQuality()
        let cacheKey = PlaybackURLCache.qqKey(mid: mid, quality: requestedQuality?.rawValue)
        if let cached = PlaybackURLCache.shared.fresh(forKey: cacheKey),
           !cached.requiresQMCDecryption
            || DecryptedAudioCacheGovernor.cachedQMCFileURL(for: nextSong) != nil {
            return
        }
        let modelReportedQuality = nextSong.qqMaxQuality
        let songName = nextSong.name
        let cacheBaseName = DecryptedAudioCacheGovernor.qmcCacheBaseName(for: nextSong)
        let sessionId = player.playbackSessionId

        qmcPrefetchTask = Task {
            // 任务自然结束后释放预取槽位（被取消替换时不清，避免抹掉新任务句柄）
            defer {
                if !Task.isCancelled { self.qmcPrefetchTask = nil }
            }
            do {
                AppLogger.info("[URL预解析] 开始预取下一首 QQ 地址: \(songName)")

                let result = try await firstPublisherValue(
                    APIService.shared.fetchQQSongUrl(
                        mid: mid,
                        quality: requestedQuality,
                        prefetchedQuality: modelReportedQuality
                    )
                )

                guard !Task.isCancelled,
                      self.isCurrentPrefetchTarget(nextSong, sessionId: sessionId) else { return }

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
                let outFile = DecryptedAudioCacheGovernor.qmcCacheDir
                    .appendingPathComponent("\(cacheBaseName).\(ext)")

                // 边下边解密（临时文件原子落位，中途取消不会留下半截缓存）
                let downloader = QMCStreamDownloader(decryptor: decryptor, destination: outFile)
                let byteCount = try await downloader.download(from: url, priority: URLSessionTask.lowPriority)

                guard !Task.isCancelled,
                      self.isCurrentPrefetchTarget(nextSong, sessionId: sessionId) else { return }

                AppLogger.success("[QMC预缓存] Cookie 封控兜底已落盘: \(songName) (\(byteCount / 1024)KB)")
            } catch {
                if !Task.isCancelled,
                   self.isCurrentPrefetchTarget(nextSong, sessionId: sessionId) {
                    AppLogger.warning("[QQ预取] 预取失败: \(songName) - \(error.localizedDescription)")
                }
            }
        }
    }

    /// 阶段 A：NCM 下一首预解析播放地址进短时缓存。
    /// 命中后手动切歌零 API 往返。
    func prefetchNextNCMTrack(_ song: Song) {
        guard player.isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard !song.isQQMusic, !song.isQishui, !song.isKugou, !song.isAppleMusic else {
            return
        }

        let preferHighest = SettingsManager.shared.preferHighestPlaybackQuality
        let requestedQuality: SoundQuality? = preferHighest
            ? nil
            : PlayerManager.defaultNeteasePlaybackQuality()
        let modelReportedLevel = player.modelReportedNeteaseQuality(for: song)?.rawValue
        let cacheKey = PlaybackURLCache.neteaseKey(
            id: song.id,
            level: requestedQuality?.rawValue,
            isPodcast: player.playSource.isPodcast
        )

        if PlaybackURLCache.shared.fresh(forKey: cacheKey) != nil {
            return
        }

        let songName = song.name
        let songId = song.id
        let sessionId = player.playbackSessionId

        qmcPrefetchTask = Task {
            defer {
                if !Task.isCancelled { self.qmcPrefetchTask = nil }
            }
            do {
                let result = try await firstPublisherValue(
                    APIService.shared.fetchSongUrl(
                        id: songId,
                        level: requestedQuality?.rawValue,
                        prefetchedLevel: modelReportedLevel
                    )
                )

                guard !Task.isCancelled,
                      self.isCurrentPrefetchTarget(song, sessionId: sessionId) else { return }

                PlaybackURLCache.shared.store(result, forKey: cacheKey)
                AppLogger.info("[URL预解析] 下一首 NCM 地址已就绪: \(songName)")

            } catch {
                if !Task.isCancelled,
                   self.isCurrentPrefetchTarget(song, sessionId: sessionId) {
                    AppLogger.debug("[URL预解析] 下一首 NCM 预解析失败: \(songName) - \(error.localizedDescription)")
                }
            }
        }
    }

    /// 预下载下一首汽水音乐到本地缓存（阶段 A）。产物两用：
    /// ① armPipeline 用本地文件 + 解密密钥装配无缝管线；
    /// ② 手动切歌时 downloadAndPlayQishuiAudio 命中同名缓存文件秒开。
    func prefetchNextQishuiTrack(_ song: Song) {
        guard player.isGaplessPlaybackEnabled else { return }
        guard qmcPrefetchTask == nil else { return }
        guard let trackId = song.qishuiTrackId else { return }

        if let asset = qishuiGaplessAsset,
           asset.trackId == trackId,
           FileManager.default.fileExists(atPath: asset.fileURL.path) {
            return
        }

        let shouldAutoSelectHighest = SettingsManager.shared.preferHighestPlaybackQuality
        let requestedQuality = shouldAutoSelectHighest ? "lossless" : player.qishuiSelectedQuality
        let songName = song.name
        let sessionId = player.playbackSessionId

        qmcPrefetchTask = Task {
            // 任务自然结束后释放预取槽位（被取消替换时不清，避免抹掉新任务句柄）
            defer {
                if !Task.isCancelled { self.qmcPrefetchTask = nil }
            }
            do {
                AppLogger.info("[汽水预缓存] 开始预缓存下一首: \(songName)")

                let result = try await firstPublisherValue(
                    APIService.shared.fetchQishuiSongUrl(
                        trackId: trackId,
                        quality: requestedQuality
                    )
                )

                guard !Task.isCancelled,
                      self.isCurrentPrefetchTarget(song, sessionId: sessionId),
                      !result.url.isEmpty else { return }
                guard let url = URL(string: result.url) else { return }

                let ext = result.decryptionKey != nil ? "enc.mp4" : "m4a"
                let cacheFile = DecryptedAudioCacheGovernor.qishuiCacheDir
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
                    guard self.isCurrentPrefetchTarget(song, sessionId: sessionId) else {
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

                guard self.isCurrentPrefetchTarget(song, sessionId: sessionId) else { return }
                self.pendingGaplessResolvedQuality = .qishui(
                    trackId: trackId,
                    quality: result.quality
                )
                self.qishuiGaplessAsset = (trackId: trackId, fileURL: cacheFile, decryptionKey: result.decryptionKey)
                self.armPipeline(sessionId: sessionId)
            } catch {
                if !Task.isCancelled,
                   self.isCurrentPrefetchTarget(song, sessionId: sessionId) {
                    AppLogger.warning("[汽水预缓存] 预缓存失败: \(songName) - \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - PlayerManager facade（112 个外部调用点与引擎扩展保持不变）

extension PlayerManager {

    var isGaplessPlaybackEnabled: Bool {
        Self.gaplessPlaybackEnabled()
    }

    func handleGaplessPlaybackSettingChanged(enabled: Bool) {
        continuity.handleGaplessPlaybackSettingChanged(enabled: enabled)
    }

    func handleCrossfadePlaybackSettingChanged(enabled: Bool) {
        continuity.handleCrossfadePlaybackSettingChanged(enabled: enabled)
    }

    func disarmContinuityEngine() {
        continuity.disarm()
    }

    func cancelGaplessPreparation(resetPendingState: Bool) {
        continuity.cancelPreparation(resetPendingState: resetPendingState)
    }

    func tickContinuityEngine() {
        continuity.tick()
    }

    func isPreparedGaplessPipelineFresh(for song: Song) -> Bool {
        continuity.isPreparedPipelineFresh(for: song)
    }

    func handleSeamlessLoopRestart(engineInput: String?) {
        continuity.handleSeamlessLoopRestart(engineInput: engineInput)
    }

    func reconcilePendingTrackTransitionWithEngine(reason: String) {
        continuity.reconcilePendingTrackTransitionWithEngine(reason: reason)
    }

    @discardableResult
    func reconcileAlreadyActiveGaplessTarget(_ target: Song, reason: String) -> Bool {
        continuity.reconcileAlreadyActiveTarget(target, reason: reason)
    }

    func invalidateGaplessPreparation(reason: String) {
        continuity.invalidatePreparation(reason: reason)
    }

    func scheduleGaplessMediaPrefetchIfNeeded(force: Bool = false) {
        continuity.scheduleMediaPrefetchIfNeeded(force: force)
    }

    func applyPendingTrackTransition(engineInput: String? = nil) {
        continuity.applyPendingTrackTransition(engineInput: engineInput)
    }
}
