// 睡眠定时器（倒计时 / 播完本首再停 / ~3s 长淡出送走音乐）
// 与音量包络（软暂停淡出、恢复淡入、启动淡入请求）。
// 由 PlayerManager 强持有；@Published 的睡眠状态仍留在 PlayerManager 上供 UI 观察。

import Foundation

@MainActor
final class SleepAndFadeController {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    // MARK: - 睡眠定时器状态

    private var sleepTimerDeadline: Date?
    private var lastSleepUpdate: TimeInterval = 0

    // MARK: - 音量包络状态

    /// 正在执行的音量包络任务（暂停淡出 / 恢复淡入 / 睡眠长淡出）
    private var playbackFadeTask: Task<Void, Never>?
    /// 音量包络代际号：新包络启动或播放管线重置时递增，旧任务的收尾回调据此失效
    private var playbackFadeGeneration: Int = 0
    var isPlaybackFadeActive: Bool { playbackFadeTask != nil }
    /// 下一次播放管线启动时使用的一次性淡入请求。绑定歌曲并携带时长，
    /// 同时覆盖冷启动恢复与热启动重建，不影响正常无缝切歌。
    var playbackStartFadeSongID: Int?
    var playbackStartFadeDuration: TimeInterval = 0.75
    var playbackStartFadeReason: String = ""

    // MARK: - 睡眠定时器

    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        let total = TimeInterval(minutes * 60)
        sleepTimerDeadline = Date().addingTimeInterval(total)
        player.sleepTimerRemaining = total
        player.sleepTimerConfiguredMinutes = minutes
    }

    func cancelSleepTimer() {
        sleepTimerDeadline = nil
        player.sleepTimerRemaining = nil
        player.sleepTimerConfiguredMinutes = nil
        player.pendingSleepStopAfterCurrentTrack = false
        lastSleepUpdate = 0
    }

    func activateSleepStopAfterCurrentTrack() {
        sleepTimerDeadline = nil
        player.sleepTimerRemaining = nil
        player.sleepTimerConfiguredMinutes = nil
        lastSleepUpdate = 0
        player.pendingSleepStopAfterCurrentTrack = true
        player.hasPendingTrackTransition = false
        player.pendingNextSong = nil
        player.pendingTransitionStartedAt = nil
        player.disarmContinuityEngine()
        player.continuity.cancelNextTrackResolution()
        player.streamPlayer.cancelNextPreparation()
        player.saveState()
    }

    /// 由播放心跳每 0.25s 调用
    func tickSleepTimer() {
        guard let deadline = sleepTimerDeadline else { return }
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            if player.sleepTimerStopAfterCurrentTrack,
               player.currentSong != nil,
               player.isPlaying {
                activateSleepStopAfterCurrentTrack()
            } else {
                cancelSleepTimer()
                performSleepTimerStop()
            }
        } else {
            let rounded = remaining.rounded()
            if rounded != lastSleepUpdate {
                lastSleepUpdate = rounded
                player.sleepTimerRemaining = remaining
            }
        }
    }

    /// 睡眠定时器到点：用 ~3s 的长淡出送走音乐，而不是硬切静音。
    /// 淡出期间 UI 仍显示播放中（声音确实还在），淡完才真正挂起引擎。
    private func performSleepTimerStop() {
        let player = self.player
        guard player.isPlaying, player.streamPlayer.state == .playing else {
            player.streamPlayer.pause()
            player.isPlaying = false
            player.refreshPlaybackSurfaceState()
            player.saveState()
            return
        }
        beginPlaybackFade(to: 0, duration: 3.0) { [weak self] in
            guard let self else { return }
            let player = self.player
            player.streamPlayer.pause()
            player.streamPlayer.outputVolume = 1.0
            player.lastPausedAt = Date()
            player.isPlaying = false
            player.refreshPlaybackSurfaceState()
            player.saveState()
        }
    }

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

        let start = player.streamPlayer.outputVolume
        guard duration > 0.02, abs(start - target) > 0.01 else {
            player.streamPlayer.outputVolume = target
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
                self.player.streamPlayer.outputVolume = value
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
            player.streamPlayer.outputVolume = 1.0
        }
    }

    /// 丢弃尚未被 `.playing` 消费的启动淡入。AudioRenderer 会跨引擎重建
    /// 保留目标音量，因此停止或失败时必须显式恢复，不能把 0 留给下一次播放。
    func clearPlaybackStartFade(restoreVolume: Bool) {
        playbackStartFadeSongID = nil
        playbackStartFadeDuration = 0.75
        playbackStartFadeReason = ""
        if restoreVolume {
            player.streamPlayer.outputVolume = 1.0
        }
    }

    /// 登记一次性启动淡入请求（loadAndPlay 在装配新管线前调用）
    func requestPlaybackStartFade(songID: Int, duration: TimeInterval, reason: String) {
        playbackStartFadeSongID = songID
        playbackStartFadeDuration = max(0.2, duration)
        playbackStartFadeReason = reason
    }

    /// deinit 清理
    func cancelAllWork() {
        playbackFadeTask?.cancel()
        playbackFadeTask = nil
    }
}

// MARK: - PlayerManager facade（引擎扩展调用点保持不变）

extension PlayerManager {

    func beginPlaybackFade(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        sleepAndFade.beginPlaybackFade(to: target, duration: duration, completion: completion)
    }

    func cancelPlaybackFade(restoreVolume: Bool) {
        sleepAndFade.cancelPlaybackFade(restoreVolume: restoreVolume)
    }

    func clearPlaybackStartFade(restoreVolume: Bool) {
        sleepAndFade.clearPlaybackStartFade(restoreVolume: restoreVolume)
    }
}
