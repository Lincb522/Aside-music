// PlayerManager+Controls.swift
// Monologue
//
// 播放控制：暂停/恢复、上/下一首、切换模式、停止、切换音质

import Foundation
import AVFoundation
import Combine

extension PlayerManager {
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        guard !isLoading else { return }

        if isPlaying {
            pausePlayback()
        } else {
            playPlayback()
        }
    }

    @discardableResult
    func playPlayback() -> Bool {
        if isPlaying || isLoading {
            return currentSong != nil
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
            // 某些 VoIP/电话中断后底层状态仍可能停在 `.playing`，
            // 但 AudioEngine 已被系统暂停。这里不要只把 UI 标成播放，
            // 而是重新激活 session 并强制走一次 pause→resume。
            activateAudioSessionForPlayback(reason: "playPlayback recover active stream")
            streamPlayer.pause()
            streamPlayer.resume()
            isPlaying = true
            isLoading = false
            refreshPlaybackSurfaceState()
            saveState()
            return currentSong != nil
        case .connecting:
            isLoading = true
            refreshPlaybackSurfaceState()
            return currentSong != nil
        case .paused:
            // 懒激活：确保 session 处于激活态。
            // 冷启动恢复路径下，setupAudioSession 只预声明了 category，尚未 setActive；
            // 这里是用户显式点播放，必须在 streamPlayer.resume 前激活音频路由。
            activateAudioSessionForPlayback(reason: "playPlayback resume")
            streamPlayer.resume()
            isPlaying = true
            refreshPlaybackSurfaceState()
            saveState()
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
            loadAndPlay(song: song, startTime: resumeTime)
            return true
        }
    }

    @discardableResult
    func pausePlayback() -> Bool {
        wasPlayingBeforeInterruption = false
        isUnderInterruption = false
        routeChangeResumeWorkItem?.cancel()
        routeChangeResumeWorkItem = nil
        cancelInterruptionResumeRetry()
        cancelInterruptionWatchdog()

        guard isPlaying else { return currentSong != nil }
        guard case .playing = streamPlayer.state else { return false }

        streamPlayer.pause()
        isPlaying = false
        refreshPlaybackSurfaceState()
        saveState()
        return true
    }
    
    func next() {
        guard let nextSong = upcomingPlaybackSong() else {
            stopAfterQueueExhausted()
            return
        }

        if let index = currentContextList.firstIndex(where: { $0.id == nextSong.id }) {
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
    }
    
    func stopAndClear() {
        isUserStopping = true
        nextTrackCancellable?.cancel()
        qmcPrefetchTask?.cancel()
        nextQualityPrefetchTask?.cancel()
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
        nextTrackCancellable?.cancel()
        qmcPrefetchTask?.cancel()
        nextQualityPrefetchTask?.cancel()
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
        pendingRestoreTime = nil
        needsPlaybackRestoration = false
        shouldAutoResumeAfterRestore = false
        isUserStopping = false

        refreshPlaybackSurfaceState()
        saveStateImmediately()
    }
    
    func switchQuality(_ quality: SoundQuality) {
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
        guard let current = currentSong, current.isQishui else { return }
        soundQuality = info.soundQuality
        qishuiSelectedQuality = info.quality
        restartCurrentSongForQualityChange(song: current, startTime: currentTime)
    }
    
    /// 切换 qcm音质（仅对当前是 QQ 歌曲且已有 qqMid 时生效）
    func switchQQMusicQuality(_ quality: QQMusicQuality) {
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
