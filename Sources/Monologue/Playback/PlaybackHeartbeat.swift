// PlaybackHeartbeat.swift
// Monologue
//
// 0.25s 播放心跳：采样 StreamPlayer 进度、驱动睡眠定时器、无缝引擎阶段 B、
// seek 状态解除、假播放输出巡检、锁屏时间/歌词节流更新。
// 后台自动降频到 1Hz，降低整机功耗。

import Foundation

@MainActor
final class PlaybackHeartbeat {

    unowned let player: PlayerManager

    init(player: PlayerManager) {
        self.player = player
    }

    private var timer: Timer?
    /// 锁屏时间更新节流计数器（每 8 次 tick 或歌词换行时才更新一次）
    private var nowPlayingUpdateCounter: Int = 0
    /// 后台轮询节流计数器（后台时 0.25s 定时器每 4 次只执行 1 次）
    var backgroundTickSkipCounter: Int = 0

    func start() {
        stop()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let player = self.player

        // ── 睡眠定时器始终 tick（不受 isPlaying guard 影响） ──
        player.sleepAndFade.tickSleepTimer()

        // ── 后台节流：界面不可见时降到 1Hz 采样 ──
        // 锁屏进度由系统按 rate 自动推进、歌词行级同步 1s 粒度足够，
        // 大幅减少后台 CPU 唤醒次数，降低整机功耗。
        if player.isAppInBackground {
            backgroundTickSkipCounter += 1
            if backgroundTickSkipCounter % 4 != 0 { return }
        } else {
            backgroundTickSkipCounter = 0
        }

        // Mono 的音频管线可能已在后台完成无缝热切，但主线程元数据
        // 回调被系统延迟。每次有效 tick 都对账一次，避免回到 App
        // 仍显示上一首；引擎会在旧歌尾音尚未播完时阻止提前切 UI。
        player.reconcilePendingTrackTransitionWithEngine(
            reason: player.isAppInBackground ? "background tick" : "foreground tick"
        )

        // Route notifications are not guaranteed to describe every engine
        // invalidation. Detect the stale `.playing` + dead output combination
        // from the regular player heartbeat as a final safety net.
        if player.isPlaying,
           player.streamPlayer.state == .playing,
           !player.streamPlayer.isAudioOutputRunning {
            player.audioSessionCoordinator.scheduleAudioOutputRecoveryIfNeeded(reason: "playback heartbeat")
        }

        if player.currentSong != nil {
            player.repairSystemPlaybackSurfacesIfNeeded(
                reason: player.isAppInBackground
                    ? "background playback heartbeat"
                    : "foreground playback heartbeat"
            )
        }

        // 采样 StreamPlayer 状态
        let rawTime = player.streamPlayer.currentTime
        let boundedTime = player.boundedEnginePlaybackTime(rawTime)
        let time = boundedTime ?? rawTime
        let timeValid = boundedTime != nil
        let playing = player.isPlaying
        let seeking = player.isSeeking
        let seekTarget = player.seekTargetTime
        let seekStarted = player.seekStartedAt

        guard playing || (timeValid && time > 0) else { return }

        // ── isSeeking 状态解除 ──
        if seeking {
            var resolved = false
            if let target = seekTarget {
                // 必须确认播放内核已经到达目标附近。旧逻辑只判断
                // `time >= target - 1`，向后拖动时旧时间天然大于目标，
                // 会立刻结束 seeking 并把进度覆盖回拖动前的位置。
                if timeValid && abs(time - target) <= 1.0 {
                    resolved = true
                } else if let started = seekStarted,
                          Date().timeIntervalSince(started) > 1.5 {
                    if player.seekRetryCount < player.maxSeekRetryCount {
                        player.seekRetryCount += 1
                        player.seekStartedAt = Date()
                        player.streamPlayer.seek(to: target)
                        AppLogger.warning(
                            "Seek 尚未到达目标，重新提交第\(player.seekRetryCount)次 target=\(String(format: "%.2f", target)) current=\(String(format: "%.2f", time))",
                            step: "playback.seek.retry"
                        )
                    } else if let song = player.currentSong {
                        // 最后兜底重建当前歌曲到目标位置。不能把旧内核
                        // 时间写回 UI，否则向后拖动会直接弹回原位置。
                        AppLogger.warning(
                            "Seek 多次未生效，重建当前管线 target=\(String(format: "%.2f", target))",
                            step: "playback.seek.pipeline-rebuild"
                        )
                        player.isSeeking = false
                        player.seekTargetTime = nil
                        player.seekStartedAt = nil
                        player.seekRetryCount = 0
                        player.loadAndPlay(
                            song: song,
                            startTime: target,
                            fadeInDuration: 0.45,
                            fadeInReason: "seek recovery"
                        )
                        return
                    }
                }
            } else {
                resolved = true
            }
            if resolved {
                player.isSeeking = false
                player.seekTargetTime = nil
                player.seekStartedAt = nil
                player.seekRetryCount = 0
                if timeValid { player.currentTime = time }
            }
        }

        // ── 正常时间更新 ──
        if timeValid && !player.isSeeking {
            player.currentTime = time
        }
        LyricViewModel.shared.updateCurrentTime(player.currentTime)
        player.savePlaybackProgressIfNeeded()

        // ── 无缝引擎阶段 B：临近结尾装配下一首管线（后台随节流降为 1Hz） ──
        player.tickGaplessEngine()

        let lyricIdx = LyricViewModel.shared.currentLineIndex
        let lyricChanged = lyricIdx != player.nowPlayingController.lastNowPlayingLyricIndex

        nowPlayingUpdateCounter += 1
        if lyricChanged || nowPlayingUpdateCounter >= 8 {
            nowPlayingUpdateCounter = 0
            player.updateNowPlayingTime()
            #if canImport(ActivityKit) && os(iOS)
            Task { @MainActor in
                await LyricsLiveActivityManager.shared.sync(with: player)
            }
            #endif
        }
    }
}
