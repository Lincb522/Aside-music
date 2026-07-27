// Apple Music 受保护音频由 MusicKit 播放。该协调器只负责把 MusicKit
// 的播放时钟和状态接回 Mono 播放引擎的统一界面、队列和系统控制面。

import Foundation
@preconcurrency import MusicKit

@MainActor
final class AppleMusicPlaybackCoordinator {

    unowned let player: PlayerManager

    private let musicPlayer = ApplicationMusicPlayer.shared
    private var activeCatalogID: String?
    private var activeRequestedIdentity: String?
    private var lastPlaybackTime: TimeInterval = 0
    private var wasAudiblyPlaying = false
    private var didReportNaturalEnd = false
    private var artworkResolutionTask: Task<Void, Never>?

    private(set) var isActive = false
    private(set) var activeArtworkURL: URL?

    init(player: PlayerManager) {
        self.player = player
    }

    func start(
        song: Song,
        autoPlay: Bool,
        startTime: TimeInterval,
        sessionID: Int
    ) async throws {
        let catalogSong = try await AppleMusicService.shared.playableSong(for: song)
        try Task.checkCancellation()
        guard player.playbackSessionId == sessionID else {
            throw CancellationError()
        }

        // Mono 自己维护播放模式与队列。清掉 MusicKit 可能继承的单曲循环/
        // 随机状态，避免单项 MusicKit 队列在结尾自行重播而不回调下一曲。
        musicPlayer.state.repeatMode = MusicPlayer.RepeatMode.none
        musicPlayer.state.shuffleMode = .off
        musicPlayer.queue = ApplicationMusicPlayer.Queue(
            for: [catalogSong],
            startingAt: catalogSong
        )
        try await musicPlayer.prepareToPlay()
        try Task.checkCancellation()
        guard player.playbackSessionId == sessionID else {
            throw CancellationError()
        }

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
        resolveMissingArtwork(
            for: song,
            preferred: catalogSong,
            sessionID: sessionID
        )
    }

    @discardableResult
    func resume() async throws -> Bool {
        guard isActive else { return false }
        try await musicPlayer.play()
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
        guard isActive else { return false }
        musicPlayer.pause()
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
        guard isActive else { return false }
        let duration = player.effectivePlaybackDuration
        let target = duration > 0
            ? min(max(time, 0), duration)
            : max(time, 0)
        musicPlayer.playbackTime = target
        lastPlaybackTime = target
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
        let playbackTime = musicPlayer.playbackTime
        if playbackTime.isFinite, playbackTime >= 0 {
            lastPlaybackTime = playbackTime
            player.currentTime = min(
                playbackTime,
                max(player.effectivePlaybackDuration, playbackTime)
            )
        }

        let status = musicPlayer.state.playbackStatus
        let isPlayingNow = status == .playing
            || status == .seekingForward
            || status == .seekingBackward

        if player.isPlaying != isPlayingNow {
            player.isPlaying = isPlayingNow
            player.isLoading = false
            player.refreshPlaybackSurfaceState()
        }

        if isPlayingNow {
            wasAudiblyPlaying = true
            didReportNaturalEnd = false
        } else if wasAudiblyPlaying,
                  !didReportNaturalEnd,
                  status == .stopped
                    || (status == .paused
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
        artworkResolutionTask?.cancel()
        artworkResolutionTask = nil
        isActive = false
        wasAudiblyPlaying = false
        didReportNaturalEnd = false
        activeCatalogID = nil
        activeRequestedIdentity = nil
        activeArtworkURL = nil
        musicPlayer.stop()
    }

    func stopAndReset() {
        artworkResolutionTask?.cancel()
        artworkResolutionTask = nil
        isActive = false
        wasAudiblyPlaying = false
        didReportNaturalEnd = false
        activeCatalogID = nil
        activeRequestedIdentity = nil
        activeArtworkURL = nil
        lastPlaybackTime = 0
        musicPlayer.stop()
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
