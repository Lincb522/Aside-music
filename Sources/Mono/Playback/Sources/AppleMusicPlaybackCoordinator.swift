// Apple Music 受保护音频由 MusicKit 播放。该协调器只负责把 MusicKit
// 的播放时钟和状态接回 Mono 播放引擎的统一界面、队列和系统控制面。

import Foundation
@preconcurrency import MusicKit

/// MusicKit 的播放状态与播放时间 getter 底层都会请求 media server 快照。
/// 即使从 detached task 发起，MusicKit 仍可能把同步 XPC 工作落回主线程，
/// 在 Scene 创建或恢复期间触发 0x8BADF00D。Mono 因此完全不轮询这些 getter，
/// 只根据已经确认成功的播放命令维护本地单调时钟。
private struct AppleMusicPlaybackSnapshot: Sendable {
    let playbackTime: TimeInterval
    let isPlaying: Bool
    let isStopped: Bool
    let isPaused: Bool
}

@MainActor
final class AppleMusicPlaybackCoordinator {

    unowned let player: PlayerManager

    /// `ApplicationMusicPlayer.shared` 一旦被访问就会常驻：MusicKit 会在内部
    /// 创建 MPMusicPlayerApplicationController 并开始监听 media server 的
    /// 播放状态通知；之后每次回前台、每次系统播放状态变化，MusicKit 都会在
    /// 主线程同步读取 `playbackState`（同步 XPC）。这条路径不经过 Mono 代码，
    /// media server 一旦无响应就直接触发 scene-update 0x8BADF00D。
    /// 因此只有真正开始播放 Apple Music 时才创建它；从未使用 Apple Music 的
    /// 用户永远不会碰到这条 XPC 链路。
    private var musicPlayer: ApplicationMusicPlayer?
    private var activeCatalogID: String?
    private var activeRequestedIdentity: String?
    private var lastPlaybackTime: TimeInterval = 0
    private var playbackAnchorPosition: TimeInterval = 0
    private var playbackAnchorUptime: TimeInterval?
    private var wasAudiblyPlaying = false
    private var didReportNaturalEnd = false
    private var artworkResolutionTask: Task<Void, Never>?
    private var latestSnapshot = AppleMusicPlaybackSnapshot(
        playbackTime: 0,
        isPlaying: false,
        isStopped: true,
        isPaused: false
    )

    private(set) var isActive = false
    private(set) var activeArtworkURL: URL?

    /// 提供给逐字歌词等高频渲染面的 MusicKit 实时时钟。
    /// `player.currentTime` 仍由心跳统一提交，避免高频发布污染全局状态。
    var renderingPlaybackTime: TimeInterval? {
        guard isActive else { return nil }
        // `lastPlaybackTime` is committed by the low-frequency playback
        // heartbeat. Returning it directly makes every karaoke renderer hold
        // and then jump on the next heartbeat. Interpolate from the confirmed
        // local monotonic anchor instead; this performs no MusicKit/XPC query
        // and gives all 60 fps lyric surfaces a smooth clock.
        let time = resolvedLocalPlaybackTime()
        return time.isFinite && !time.isNaN && time >= 0 ? time : nil
    }

    init(player: PlayerManager) {
        self.player = player
    }

    /// 是否已经实例化过 MusicKit 播放器。用于诊断和避免无意义的 stop() 调用。
    var hasInstantiatedMusicPlayer: Bool { musicPlayer != nil }

    private func resolvedMusicPlayer() -> ApplicationMusicPlayer {
        if let musicPlayer { return musicPlayer }
        AppLogger.info(
            "[AppleMusic] 首次创建 ApplicationMusicPlayer.shared",
            step: "apple-music.player"
        )
        let created = ApplicationMusicPlayer.shared
        musicPlayer = created
        return created
    }

    func start(
        song: Song,
        autoPlay: Bool,
        startTime: TimeInterval,
        sessionID: Int
    ) async throws {
        AppLogger.info(
            "[AppleMusic] 开始解析可播放歌曲 target=\(song.name)",
            step: "apple-music.resolve"
        )
        let catalogSong = try await AppleMusicService.shared.playableSong(for: song)
        try Task.checkCancellation()
        guard player.playbackSessionId == sessionID else {
            throw CancellationError()
        }

        // 不在主线程读取或修改 MusicKit `state`。该对象会隐式请求
        // playbackState 快照，在 Scene 创建阶段可能同步阻塞 MediaPlayer。
        // Mono 使用单项 MusicKit 队列并在本地时钟到达结尾时主动切歌。
        let musicPlayer = resolvedMusicPlayer()
        musicPlayer.queue = ApplicationMusicPlayer.Queue(
            for: [catalogSong],
            startingAt: catalogSong
        )
        AppLogger.info(
            "[AppleMusic] MusicKit 队列已设置，开始缓冲 target=\(song.name)",
            step: "apple-music.prepare"
        )
        try await musicPlayer.prepareToPlay()
        try Task.checkCancellation()
        guard player.playbackSessionId == sessionID else {
            throw CancellationError()
        }
        AppLogger.info(
            "[AppleMusic] MusicKit 缓冲完成 target=\(song.name)",
            step: "apple-music.prepare"
        )

        let boundedStart = min(
            max(startTime, 0),
            max(Double(song.dt ?? 0) / 1_000, startTime)
        )
        if boundedStart > 0 {
            musicPlayer.playbackTime = boundedStart
        }

        // MusicKit 和 Mono 不能同时占用可闻输出。等 Apple Music 已准备好后
        // 再结束旧管线，把跨后端切歌的静音窗口压到最低。
        player.suppressStopHandlingUntil = Date().addingTimeInterval(1)
        player.streamPlayer.cancelNextPreparation()
        player.streamPlayer.stop()

        if autoPlay {
            AppLogger.info(
                "[AppleMusic] 提交播放命令 target=\(song.name)",
                step: "apple-music.play"
            )
            try await musicPlayer.play()
        }
        try Task.checkCancellation()
        guard player.playbackSessionId == sessionID else {
            musicPlayer.stop()
            throw CancellationError()
        }

        artworkResolutionTask?.cancel()
        activeCatalogID = catalogSong.id.rawValue
        activeRequestedIdentity = PlayerManager.playbackIdentityKey(for: song)
        activeArtworkURL = catalogSong.artwork?.url(width: 1200, height: 1200)
            ?? catalogSong.albums?.first?.artwork?.url(width: 1200, height: 1200)
            ?? song.coverUrl
        isActive = true
        lastPlaybackTime = boundedStart
        wasAudiblyPlaying = autoPlay
        didReportNaturalEnd = false
        resetLocalPlaybackClock(
            playbackTime: boundedStart,
            isPlaying: autoPlay,
            isStopped: !autoPlay,
            isPaused: !autoPlay
        )
        AppLogger.success(
            "[AppleMusic] 播放事务已提交 target=\(song.name) autoPlay=\(autoPlay)",
            step: "apple-music.play"
        )
        resolveMissingArtwork(
            for: song,
            preferred: catalogSong,
            sessionID: sessionID
        )
    }

    @discardableResult
    func resume() async throws -> Bool {
        guard isActive, let musicPlayer else { return false }
        try await musicPlayer.play()
        let playbackTime = resolvedLocalPlaybackTime()
        updateLocalPlaybackClock(position: playbackTime, isPlaying: true)
        latestSnapshot = AppleMusicPlaybackSnapshot(
            playbackTime: playbackTime,
            isPlaying: true,
            isStopped: false,
            isPaused: false
        )
        wasAudiblyPlaying = true
        didReportNaturalEnd = false
        player.isPlaying = true
        player.isLoading = false
        player.lastPausedAt = nil
        player.refreshPlaybackSurfaceState()
        player.saveState()
        return true
    }

    @discardableResult
    func pause() -> Bool {
        guard isActive, let musicPlayer else { return false }
        let playbackTime = resolvedLocalPlaybackTime()
        musicPlayer.pause()
        lastPlaybackTime = playbackTime
        updateLocalPlaybackClock(position: playbackTime, isPlaying: false)
        latestSnapshot = AppleMusicPlaybackSnapshot(
            playbackTime: playbackTime,
            isPlaying: false,
            isStopped: false,
            isPaused: true
        )
        wasAudiblyPlaying = false
        player.isPlaying = false
        player.isLoading = false
        player.lastPausedAt = Date()
        player.refreshPlaybackSurfaceState()
        player.saveState()
        return true
    }

    @discardableResult
    func seek(to time: TimeInterval) -> Bool {
        guard isActive, let musicPlayer else { return false }
        let duration = player.effectivePlaybackDuration
        let target = duration > 0
            ? min(max(time, 0), duration)
            : max(time, 0)
        musicPlayer.playbackTime = target
        lastPlaybackTime = target
        updateLocalPlaybackClock(position: target, isPlaying: latestSnapshot.isPlaying)
        latestSnapshot = AppleMusicPlaybackSnapshot(
            playbackTime: target,
            isPlaying: latestSnapshot.isPlaying,
            isStopped: false,
            isPaused: latestSnapshot.isPaused
        )
        player.currentTime = target
        player.pendingRestoreTime = nil
        player.isSeeking = false
        player.seekTargetTime = nil
        player.seekStartedAt = nil
        player.updateNowPlayingTime()
        player.saveState()
        return true
    }

    /// 返回 true 表示本次心跳已由 MusicKit 接管，Mono 心跳不应再读取
    /// FFmpeg 的旧时钟或触发旧管线恢复。
    @discardableResult
    func tick() -> Bool {
        guard isActive else { return false }

        let previousPlaybackTime = lastPlaybackTime
        let playbackTime = resolvedLocalPlaybackTime()
        latestSnapshot = AppleMusicPlaybackSnapshot(
            playbackTime: playbackTime,
            isPlaying: latestSnapshot.isPlaying,
            isStopped: latestSnapshot.isStopped,
            isPaused: latestSnapshot.isPaused
        )
        let snapshot = latestSnapshot
        if playbackTime.isFinite, playbackTime >= 0 {
            lastPlaybackTime = playbackTime
            player.currentTime = min(
                playbackTime,
                max(player.effectivePlaybackDuration, playbackTime)
            )
        }

        let isPlayingNow = snapshot.isPlaying

        if player.isPlaying != isPlayingNow {
            player.isPlaying = isPlayingNow
            player.isLoading = false
            player.refreshPlaybackSurfaceState()
        }

        if isPlayingNow {
            wasAudiblyPlaying = true
            didReportNaturalEnd = false
            if hasReachedNaturalEnd(currentTime: playbackTime) {
                didReportNaturalEnd = true
                wasAudiblyPlaying = false
                updateLocalPlaybackClock(position: playbackTime, isPlaying: false)
                latestSnapshot = AppleMusicPlaybackSnapshot(
                    playbackTime: playbackTime,
                    isPlaying: false,
                    isStopped: true,
                    isPaused: false
                )
                player.isPlaying = false
                player.playerDidFinishPlaying()
            }
        } else if wasAudiblyPlaying,
                  !didReportNaturalEnd,
                  snapshot.isStopped
                    || (snapshot.isPaused
                        && isNearNaturalEnd(
                            currentTime: playbackTime,
                            previousTime: previousPlaybackTime
                        )) {
            didReportNaturalEnd = true
            wasAudiblyPlaying = false
            player.playerDidFinishPlaying()
        }
        return true
    }

    func stopForMonoHandoff() {
        guard isActive else { return }
        stopLocalPlaybackClock()
        artworkResolutionTask?.cancel()
        artworkResolutionTask = nil
        isActive = false
        wasAudiblyPlaying = false
        didReportNaturalEnd = false
        activeCatalogID = nil
        activeRequestedIdentity = nil
        activeArtworkURL = nil
        musicPlayer?.stop()
    }

    func stopAndReset() {
        // 该方法在“停止并清空”“收起迷你播放器”等通用路径上被调用，
        // 绝大多数时候当前根本不是 Apple Music 播放。从未播过 Apple Music
        // 的会话里绝不能在这里顺手创建 MusicKit 播放器。
        stopLocalPlaybackClock()
        artworkResolutionTask?.cancel()
        artworkResolutionTask = nil
        isActive = false
        wasAudiblyPlaying = false
        didReportNaturalEnd = false
        activeCatalogID = nil
        activeRequestedIdentity = nil
        activeArtworkURL = nil
        lastPlaybackTime = 0
        musicPlayer?.stop()
    }

    private func resetLocalPlaybackClock(
        playbackTime: TimeInterval,
        isPlaying: Bool,
        isStopped: Bool,
        isPaused: Bool
    ) {
        updateLocalPlaybackClock(position: playbackTime, isPlaying: isPlaying)
        latestSnapshot = AppleMusicPlaybackSnapshot(
            playbackTime: playbackTime,
            isPlaying: isPlaying,
            isStopped: isStopped,
            isPaused: isPaused
        )
    }

    private func updateLocalPlaybackClock(position: TimeInterval, isPlaying: Bool) {
        let boundedPosition = max(0, position.isFinite ? position : 0)
        playbackAnchorPosition = boundedPosition
        playbackAnchorUptime = isPlaying ? ProcessInfo.processInfo.systemUptime : nil
    }

    private func resolvedLocalPlaybackTime() -> TimeInterval {
        guard let playbackAnchorUptime else { return playbackAnchorPosition }
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - playbackAnchorUptime)
        let resolved = playbackAnchorPosition + elapsed
        guard resolved.isFinite, !resolved.isNaN else { return playbackAnchorPosition }
        let duration = player.effectivePlaybackDuration
        return duration > 0 ? min(resolved, duration) : resolved
    }

    private func stopLocalPlaybackClock() {
        playbackAnchorPosition = 0
        playbackAnchorUptime = nil
        latestSnapshot = AppleMusicPlaybackSnapshot(
            playbackTime: 0,
            isPlaying: false,
            isStopped: true,
            isPaused: false
        )
    }

    func matches(_ song: Song) -> Bool {
        guard isActive else { return false }
        return activeCatalogID == song.appleMusicCatalogID
            || activeRequestedIdentity == PlayerManager.playbackIdentityKey(for: song)
    }

    private func isNearNaturalEnd(
        currentTime: TimeInterval,
        previousTime: TimeInterval
    ) -> Bool {
        let duration = player.effectivePlaybackDuration
        guard duration > 0 else { return false }
        let tolerance = max(2.5, min(duration * 0.015, 6))
        return max(max(currentTime, previousTime), lastPlaybackTime)
            >= max(duration - tolerance, 0)
    }

    private func hasReachedNaturalEnd(currentTime: TimeInterval) -> Bool {
        let duration = player.effectivePlaybackDuration
        guard duration > 0 else { return false }
        return currentTime >= max(duration - 0.08, 0)
    }

    private func resolveMissingArtwork(
        for song: Song,
        preferred catalogSong: MusicKit.Song,
        sessionID: Int
    ) {
        artworkResolutionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let resolvedURL = await AppleMusicService.shared.resolvedArtworkURL(
                for: song,
                preferred: catalogSong
            )
            guard !Task.isCancelled,
                  let resolvedURL,
                  self.player.playbackSessionId == sessionID,
                  self.matches(song) else {
                return
            }

            let artworkChanged = self.activeArtworkURL != resolvedURL
            self.activeArtworkURL = resolvedURL
            if artworkChanged,
               let currentSong = self.player.currentSong,
               PlayerManager.playbackIdentityKey(for: currentSong)
                    == PlayerManager.playbackIdentityKey(for: song) {
                self.player.updateNowPlayingArtwork(for: currentSong)
            }
        }
    }
}
