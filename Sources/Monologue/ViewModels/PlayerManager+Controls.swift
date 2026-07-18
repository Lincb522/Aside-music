// PlayerManager+Controls.swift
// Monologue
//
// 播放控制：暂停/恢复、上/下一首、切换模式、停止、切换音质

import Foundation
import AVFoundation
import Combine

extension PlayerManager {

    // MARK: - 音量包络（软暂停 / 恢复淡入 / 睡眠长淡出）

    /// 把混音台音量平滑过渡到目标值，结束后执行 `completion`。
    ///
    /// 走 `streamPlayer.outputVolume`（AVAudioEngine 混音台），不触碰
    /// FFmpeg 滤镜图，逐步设置无重建开销。新包络启动会让旧包络
    /// （含其收尾回调）立即失效，连点播放/暂停不会出现状态错乱。
    func beginPlaybackFade(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        playbackFadeGeneration &+= 1
        let generation = playbackFadeGeneration
        playbackFadeTask?.cancel()
        playbackFadeTask = nil

        let start = streamPlayer.outputVolume
        guard duration > 0.02, abs(start - target) > 0.01 else {
            streamPlayer.outputVolume = target
            completion?()
            return
        }

        playbackFadeTask = Task { @MainActor [weak self] in
            let stepInterval: TimeInterval = 0.025
            let steps = max(4, Int(duration / stepInterval))
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                guard !Task.isCancelled, let self, self.playbackFadeGeneration == generation else { return }
                let progress = Float(step) / Float(steps)
                // Smoothstep 两端斜率都为 0，既不会起步突跳，也不会把主要
                // 音量变化堆到最后几十毫秒，冷/热恢复听起来更连贯。
                let eased = progress * progress * (3 - 2 * progress)
                let value = start + (target - start) * eased
                self.streamPlayer.outputVolume = value
            }
            guard let self, self.playbackFadeGeneration == generation else { return }
            self.playbackFadeTask = nil
            completion?()
        }
    }

    /// 取消进行中的音量包络（连同其收尾回调）。
    /// 播放管线重建（loadAndPlay/stop/音质切换）或中断接管时调用，
    /// 防止迟到的「淡出后挂起引擎」把新会话误暂停。
    func cancelPlaybackFade(restoreVolume: Bool) {
        playbackFadeGeneration &+= 1
        playbackFadeTask?.cancel()
        playbackFadeTask = nil
        if restoreVolume {
            streamPlayer.outputVolume = 1.0
        }
    }

    /// 丢弃尚未被 `.playing` 消费的启动淡入。AudioRenderer 会跨引擎重建
    /// 保留目标音量，因此停止或失败时必须显式恢复，不能把 0 留给下一次播放。
    func clearPlaybackStartFade(restoreVolume: Bool) {
        playbackStartFadeSongID = nil
        playbackStartFadeDuration = 0.75
        playbackStartFadeReason = ""
        if restoreVolume {
            streamPlayer.outputVolume = 1.0
        }
    }

    // MARK: - Playback Controls
    
    func togglePlayPause() {
        guard !isLoading else { return }

        // A visible pause button must always mean pause. Output recovery belongs
        // to explicit play commands; otherwise the first tap can revive a route
        // that the user is trying to stop.
        if isPlaying {
            pausePlayback()
        } else {
            playPlayback()
        }
    }

    @discardableResult
    func playPlayback() -> Bool {
        if isLoading {
            return currentSong != nil
        }
        if isPlaying {
            if streamPlayer.isAudioOutputRunning {
                return currentSong != nil
            }
            return recoverUnavailableAudioOutput(reason: "explicit play command")
        }

        // 接管任何进行中的淡出包络：它挂起引擎的收尾回调不能在新播放后触发
        cancelPlaybackFade(restoreVolume: false)

        if let song = currentSong, isCurrentPlaybackAtEnd {
            AppLogger.info("播放已在结尾，用户点击播放时从头开始: \(song.name)")
            currentTime = 0
            pendingRestoreTime = nil
            needsPlaybackRestoration = false
            loadAndPlay(
                song: song,
                startTime: 0,
                fadeInDuration: 0.7,
                fadeInReason: "warm restart from track end"
            )
            return true
        }

        if needsPlaybackRestoration, currentSong != nil {
            restorePlaybackSessionIfNeeded(forceAutoPlay: true)
            return true
        }

        // 用户主动触发（小组件、控制中心、播放器按钮）：取消所有自动重试，
        // 并保留 `wasPlayingBeforeInterruption` 标志直到 resume 真正成功，
        // 避免用户多次点击都失败时丢失中断上下文。
        if currentSong != nil, wasPlayingBeforeInterruption || isUnderInterruption {
            AppLogger.info("用户/外部控制触发中断后恢复播放")
            cancelInterruptionResumeRetry()
            cancelInterruptionWatchdog()
            isUnderInterruption = false
            // 立即尝试一次；若失败则启动阶梯重试，确保用户连点不会卡死
            if !resumeAfterInterruption(reason: "manual playback command") {
                scheduleInterruptionResumeRetry(reason: "manual playback command")
            }
            return true
        }

        switch streamPlayer.state {
        case .playing:
            // 两种可能：① 软暂停淡出尚未完成，用户又点了播放（引擎其实还在跑）；
            // ② 某些 VoIP/电话中断后底层状态停在 `.playing` 但 AudioEngine 已被系统暂停。
            // 统一处理：重新激活 session 并强制走一次 pause→resume，再淡入回满音量。
            activateAudioSessionForPlayback(reason: "playPlayback recover active stream")
            streamPlayer.pause()
            streamPlayer.outputVolume = 0.0
            guard streamPlayer.resume() else {
                return recoverUnavailableAudioOutput(reason: "active stream resume failed")
            }
            isPlaying = true
            isLoading = false
            lastPausedAt = nil
            refreshPlaybackSurfaceState()
            saveState()
            beginPlaybackFade(to: 1.0, duration: 0.7)
            return currentSong != nil
        case .connecting:
            isLoading = true
            refreshPlaybackSurfaceState()
            return currentSong != nil
        case .paused:
            // 网络流长时间暂停后 CDN URL 大概率过期：直接 resume 会先放完
            // 缓冲区再断流报错。这里主动重新取址，从当前进度无感续播。
            if let song = currentSong, isResumeLikelyStale {
                AppLogger.info("暂停超过 \(Int(Self.networkResumeRefreshThreshold / 60)) 分钟，重新取址续播: \(song.name)")
                lastPausedAt = nil
                loadAndPlay(
                    song: song,
                    startTime: max(currentTime, 0),
                    fadeInDuration: 0.78,
                    fadeInReason: "warm stale resume"
                )
                return true
            }
            // 懒激活：确保 session 处于激活态。
            // 冷启动恢复路径下，setupAudioSession 只预声明了 category，尚未 setActive；
            // 这里是用户显式点播放，必须在 streamPlayer.resume 前激活音频路由。
            activateAudioSessionForPlayback(reason: "playPlayback resume")
            streamPlayer.outputVolume = 0.0
            guard streamPlayer.resume() else {
                return recoverUnavailableAudioOutput(reason: "paused stream resume failed")
            }
            isPlaying = true
            lastPausedAt = nil
            refreshPlaybackSurfaceState()
            saveState()
            beginPlaybackFade(to: 1.0, duration: 0.7)
            return true
        case .idle, .stopped, .error:
            guard let song = currentSong else { return false }
            let storedResumeTime = max(pendingRestoreTime ?? currentTime, 0)
            let resumeTime: Double
            if duration > 0 && storedResumeTime >= max(duration - 0.5, 0) {
                resumeTime = 0
            } else {
                resumeTime = storedResumeTime
            }
            loadAndPlay(
                song: song,
                startTime: resumeTime,
                fadeInDuration: 0.75,
                fadeInReason: "warm playback start"
            )
            return true
        }
    }

    /// 暂停后恢复是否大概率撞上失效地址，恢复前应重新取址。
    /// 本地文件 / 已解密缓存 / 汽水缓存都是 file:// 输入，不受 URL 过期影响。
    /// 两个信号满足其一即视为过期：
    /// · 暂停时长超过阈值（连接早被系统回收，地址也大概率过期）；
    /// · 地址解析距今超过阈值且暂停已逾一分钟（长歌听到一半退后台：
    ///   暂停虽不算久，但 CDN 连接早被闲置回收，resume 触发的重连
    ///   会拿超龄旧地址撞 403）。秒级的前台快速暂停/恢复不受影响。
    var isResumeLikelyStale: Bool {
        guard currentPlayingURL?.hasPrefix("http") == true else { return false }
        guard let pausedAt = lastPausedAt else { return false }
        let pausedFor = Date().timeIntervalSince(pausedAt)
        if pausedFor > Self.networkResumeRefreshThreshold {
            return true
        }
        if pausedFor > 60,
           let resolvedAt = playbackURLResolvedAt,
           Date().timeIntervalSince(resolvedAt) > Self.networkResumeRefreshThreshold {
            return true
        }
        return false
    }

    private var isCurrentPlaybackAtEnd: Bool {
        let expectedDuration: Double = {
            if let metaMs = currentSong?.dt, metaMs > 0 {
                return Double(metaMs) / 1000.0
            }
            return duration
        }()

        guard expectedDuration > 0 else { return false }
        let referenceTime = max(currentTime, streamPlayer.currentTime)
        return referenceTime >= max(expectedDuration - 0.75, 0)
    }

    @discardableResult
    func pausePlayback() -> Bool {
        wasPlayingBeforeInterruption = false
        isUnderInterruption = false
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()
        endTransitionKeepAlive()
        audioOutputRecoveryTask?.cancel()
        audioOutputRecoveryTask = nil

        guard currentSong != nil else { return false }
        let engineState = streamPlayer.state
        let outputIsRunning = streamPlayer.isAudioOutputRunning
        let shouldPause = isPlaying || engineState == .playing || outputIsRunning
        guard shouldPause else {
            isPlaying = false
            isLoading = false
            refreshPlaybackSurfaceState()
            return true
        }

        isPlaying = false
        isLoading = false
        lastPausedAt = Date()
        refreshPlaybackSurfaceState()
        saveState()

        if engineState == .playing, outputIsRunning {
            // Normal user pause keeps the short anti-pop fade.
            beginPlaybackFade(to: 0.0, duration: 0.22) { [weak self] in
                guard let self else { return }
                _ = self.streamPlayer.pauseAudioOutputImmediately()
                self.streamPlayer.outputVolume = 1.0
            }
        } else {
            // State/output disagreement: converge immediately so one tap is enough.
            cancelPlaybackFade(restoreVolume: false)
            _ = streamPlayer.pauseAudioOutputImmediately()
            streamPlayer.outputVolume = 1.0
        }
        return true
    }
    
    func next() {
        guard let nextSong = upcomingPlaybackSong() else {
            stopAfterQueueExhausted()
            return
        }

        // Mono 可能已经切换了解码管线，只是在等待上一首可闻尾音结束后再提交 UI。
        // 此时再次 next 不能把同一目标重复装入，否则会出现同一首从头播放两遍。
        if reconcileAlreadyActiveGaplessTarget(nextSong, reason: "manual-next") {
            return
        }

        // 快路径：临近结尾时无缝管线已装配好下一首（demuxer/decoder 就绪），
        // 手动切歌直接热切到已就绪管线 —— 零取址、零重连、零可闻间隙。
        // UI 状态由 playerDidTransitionToNextTrack → applyPendingTrackTransition 统一更新。
        if isGaplessPlaybackEnabled,
           mode != .loopSingle,
           isPlaying,
           pendingQualitySwitchSeek == nil,
           !pendingLoopRestart,
           gaplessArmedSessionId == playbackSessionId,
           hasPendingTrackTransition,
           pendingNextSong?.id == nextSong.id,
           isPreparedGaplessPipelineFresh(for: nextSong),
           streamPlayer.isNextTrackReady {
            AppLogger.info("[Gapless] 手动切歌命中已装配管线，无缝热切: \(nextSong.name)")
            streamPlayer.switchToNext()
            return
        }

        if let index = currentContextList.firstIndex(where: {
            matchesPlaybackTarget($0, expected: nextSong)
        }) {
            contextIndex = index
        }
        loadAndPlay(song: nextSong)
    }
    
    func previous() {
        let list = currentContextList
        guard !list.isEmpty else { return }

        let safeCurrentIndex = (contextIndex >= 0 && contextIndex < list.count) ? contextIndex : 0
        var prevIndex = safeCurrentIndex - 1
        if prevIndex < 0 {
            prevIndex = list.count - 1
        }

        contextIndex = prevIndex
        loadAndPlay(song: list[prevIndex])
    }
    
    func switchMode() {
        mode = mode.next
        
        if mode == .shuffle {
            generateShuffledContext()
        } else {
            if let current = currentSong {
                contextIndex = context.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
        
        saveState()
        syncWidgetState()
        // 播放模式变化后「下一首」定义随之改变（含单曲循环回绕装配），重装无缝管线
        invalidateGaplessPreparation(reason: "switchMode:\(mode.rawValue)")
    }
    
    func stopAndClear() {
        isUserStopping = true
        // 结算听歌统计：停止播放后不再跟踪该行
        ListeningStatsRecorder.shared.finalizeSession()
        cancelPlaybackFade(restoreVolume: false)
        clearPlaybackStartFade(restoreVolume: true)
        endTransitionKeepAlive()
        nextTrackCancellable?.cancel()
        qmcPrefetchTask?.cancel()
        activeMediaLoadTask?.cancel()
        activeMediaLoadTask = nil
        qualitySwitchTimeoutTask?.cancel()
        qualitySwitchTimeoutTask = nil
        // 清理中断恢复链路
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()
        wasPlayingBeforeInterruption = false
        isUnderInterruption = false
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        streamPlayer.cancelNextPreparation()
        streamPlayer.stop()
        // 释放音频会话并通知其他 App 恢复播放（如 Apple Music、播客等）
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            lastAppliedAudioSessionOptions = nil
        } catch {
            AppLogger.warning("释放音频会话失败: \(error)")
        }
        isPlaying = false
        currentSong = nil
        streamInfo = nil
        context.removeAll()
        shuffledContext.removeAll()
        queueExhaustionBehavior = .loop
        playbackBackStack.removeAll()
        playbackForwardStack.removeAll()
        contextIndex = 0
        currentTime = 0
        duration = 0
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        clearPendingPlaybackPresentation()
        disarmGaplessEngine()
        pendingRestoreTime = nil
        needsPlaybackRestoration = false
        shouldAutoResumeAfterRestore = false
        // 清空保存的上下文
        savedMusicContext.removeAll()
        savedMusicShuffledContext.removeAll()
        savedMusicSong = nil
        savedPodcastContext.removeAll()
        savedPodcastSong = nil
        savedPodcastRadioId = nil
        isUserStopping = false

        refreshPlaybackSurfaceState()
        saveState()
        #if canImport(ActivityKit) && os(iOS)
        Task { @MainActor in
            await LyricsLiveActivityManager.shared.endCurrentActivity()
        }
        #endif
    }

    func dismissMiniPlayerPreservingQueue() {
        isUserStopping = true
        cancelPlaybackFade(restoreVolume: false)
        clearPlaybackStartFade(restoreVolume: true)
        nextTrackCancellable?.cancel()
        qmcPrefetchTask?.cancel()
        activeMediaLoadTask?.cancel()
        activeMediaLoadTask = nil
        qualitySwitchTimeoutTask?.cancel()
        qualitySwitchTimeoutTask = nil
        // 清理中断恢复链路
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()
        wasPlayingBeforeInterruption = false
        isUnderInterruption = false
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        streamPlayer.cancelNextPreparation()
        streamPlayer.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            lastAppliedAudioSessionOptions = nil
        } catch {
            AppLogger.warning("释放音频会话失败: \(error)")
        }
        isPlaying = false
        currentSong = nil
        streamInfo = nil
        currentTime = 0
        duration = 0
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        clearPendingPlaybackPresentation()
        disarmGaplessEngine()
        pendingRestoreTime = nil
        needsPlaybackRestoration = false
        shouldAutoResumeAfterRestore = false
        isUserStopping = false

        refreshPlaybackSurfaceState()
        saveStateImmediately()
    }
    
    func switchQuality(_ quality: SoundQuality) {
        guard isCurrentPlaybackQualitySelectable else { return }
        guard soundQuality != quality || !hasManualNeteaseQualityOverride else { return }

        // 游戏模式下用户手动切音质 → 同步更新备份值（由 GameModeManager 判断内部/外部）
        GameModeManager.shared.userDidSwitchSoundQuality(quality)

        guard let current = currentSong else {
            soundQuality = quality
            return
        }

        soundQuality = quality
        hasManualNeteaseQualityOverride = true
        restartCurrentSongForQualityChange(song: current, startTime: currentTime)
    }
    
    /// 切换汽水音乐音质
    func switchQishuiQuality(_ info: QishuiQualityInfo) {
        guard isCurrentPlaybackQualitySelectable else { return }
        guard let current = currentSong, current.isQishui else { return }
        soundQuality = info.soundQuality
        qishuiSelectedQuality = info.quality
        restartCurrentSongForQualityChange(song: current, startTime: currentTime)
    }
    
    /// 切换 qcm音质（仅对当前是 QQ 歌曲且已有 qqMid 时生效）
    func switchQQMusicQuality(_ quality: QQMusicQuality) {
        guard isCurrentPlaybackQualitySelectable else { return }
        guard qqMusicQuality != quality || !hasManualQQQualityOverride else { return }
        guard let current = currentSong else {
            qqMusicQuality = quality
            return
        }
        guard current.isQQMusic, current.qqMid != nil else {
            qqMusicQuality = quality
            return
        }
        
        qqMusicQuality = quality
        hasManualQQQualityOverride = true
        restartCurrentSongForQualityChange(song: current, startTime: currentTime)
    }
    
    private func restartCurrentSongForQualityChange(song: Song, startTime: Double) {
        qualitySwitchRecoveryAttempts = 0
        resetPlaybackPipelineForQualityChange()
        loadAndPlay(song: song, startTime: max(startTime, 0))
        scheduleQualitySwitchTimeout(songID: song.id, startTime: max(startTime, 0))
    }
    
    private func resetPlaybackPipelineForQualityChange() {
        cancelPlaybackFade(restoreVolume: false)
        qualitySwitchCancellable?.cancel()
        qualitySwitchCancellable = nil
        playbackURLCancellable?.cancel()
        playbackURLCancellable = nil
        qualitySwitchPollWorkItem?.cancel()
        qualitySwitchPollWorkItem = nil
        qualitySwitchTimeoutTask?.cancel()
        qualitySwitchTimeoutTask = nil
        pendingQualitySwitchSeek = nil
        hasPendingTrackTransition = false
        pendingNextSong = nil
        pendingTransitionStartedAt = nil
        clearPendingPlaybackPresentation()
        streamPlayer.cancelNextPreparation()
        suppressStopHandlingUntil = Date().addingTimeInterval(2)
        
        switch streamPlayer.state {
        case .connecting, .playing, .paused:
            streamPlayer.stop()
        case .idle, .stopped, .error:
            break
        }
    }
    
    private func scheduleQualitySwitchTimeout(songID: Int, startTime: Double) {
        qualitySwitchTimeoutTask?.cancel()
        let sessionId = playbackSessionId
        
        qualitySwitchTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                guard let self else { return }
                guard self.playbackSessionId == sessionId else { return }
                guard self.currentSong?.id == songID else { return }
                guard self.isLoading else { return }
                self.handleQualitySwitchTimeout(startTime: startTime)
            }
        }
    }
    
    private func handleQualitySwitchTimeout(startTime: Double) {
        guard let current = currentSong else { return }
        // 超时重连必须拿新鲜地址，绕过短时地址缓存
        PlaybackURLCache.shared.invalidate(song: current)
        
        if qualitySwitchRecoveryAttempts >= maxQualitySwitchRecoveryAttempts {
            AppLogger.warning("音质切换恢复已达上限，改为重新连接当前歌曲")
            qualitySwitchTimeoutTask?.cancel()
            qualitySwitchTimeoutTask = nil
            loadAndPlay(song: current, startTime: startTime)
            return
        }
        
        qualitySwitchRecoveryAttempts += 1
        
        if current.isQQMusic {
            if let nextLower = QQMusicQuality.nextLower(than: qqMusicQuality) {
                qqMusicQuality = nextLower
                AppLogger.warning("音质切换超时，自动降级到 \(nextLower.displayName)")
            } else {
                AppLogger.warning("音质切换超时，保持当前 QQ 音质重连")
            }
            hasManualQQQualityOverride = true
        } else {
            if let nextLower = SoundQuality.nextLower(than: soundQuality) {
                soundQuality = nextLower
                AppLogger.warning("音质切换超时，自动降级到 \(nextLower.displayName)")
            } else {
                AppLogger.warning("音质切换超时，保持当前 NCM 音质重连")
            }
            hasManualNeteaseQualityOverride = true
        }
        
        resetPlaybackPipelineForQualityChange()
        loadAndPlay(song: current, startTime: max(startTime, 0))
        scheduleQualitySwitchTimeout(songID: current.id, startTime: max(startTime, 0))
    }
}
