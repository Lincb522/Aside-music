#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

@MainActor
final class LyricsLiveActivityManager {
    static let shared = LyricsLiveActivityManager()
    private static let isEnabled = false

    private var activeActivityID: String?
    private var activeSongID: String?
    private var lastState: LyricsActivityAttributes.ContentState?
    private var lastProgressBucket: Int = -1

    private init() {}

    func bootstrap(with player: PlayerManager) {
        guard Self.isEnabled else {
            Task {
                await endAllActivities()
            }
            return
        }

        Task {
            if player.currentSong == nil {
                await endAllActivities()
            } else {
                await sync(with: player, forceRestart: false)
            }
        }
    }

    func sync(with player: PlayerManager, forceRestart: Bool = false) async {
        guard Self.isEnabled else {
            await endCurrentActivity()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let song = player.currentSong else {
            await endCurrentActivity()
            return
        }

        let lyricState = buildState(from: player, song: song)
        let songID = String(song.id)
        let needsRestart = forceRestart || activeSongID != songID

        if needsRestart {
            await start(songID: songID, state: lyricState)
            return
        }

        // Only update if the core content (lyrics or playback state) changes.
        // Avoid evaluating progress/time to bypass system updating rate caps which drop text strings.
        let stateChanged = lastState?.playbackState != lyricState.playbackState
        let lyricChanged = lastState?.lyric != lyricState.lyric || lastState?.nextLyric != lyricState.nextLyric
        let shouldUpdate = lastState == nil || stateChanged || lyricChanged

        guard shouldUpdate, let activeActivityID else { return }

        await Self.updateActivity(
            withID: activeActivityID,
            state: lyricState,
            staleDate: staleDate(for: lyricState.playbackState)
        )
        lastState = lyricState
    }

    func endCurrentActivity() async {
        if let activeActivityID {
            await Self.endActivity(withID: activeActivityID)
        }
        activeActivityID = nil
        activeSongID = nil
        lastState = nil
        lastProgressBucket = -1
    }

    func endAllActivities() async {
        await Self.endAllSystemActivities()
        activeActivityID = nil
        activeSongID = nil
        lastState = nil
        lastProgressBucket = -1
    }

    private func start(songID: String, state: LyricsActivityAttributes.ContentState) async {
        await endCurrentActivity()

        let attributes = LyricsActivityAttributes(songID: songID)
        do {
            let activity = try Activity<LyricsActivityAttributes>.request(
                attributes: attributes,
                content: .init(
                    state: state,
                    staleDate: staleDate(for: state.playbackState)
                )
            )
            activeActivityID = activity.id
            activeSongID = songID
            lastState = state
        } catch {
            AppLogger.warning("[LiveActivity] 启动失败: \(error.localizedDescription)")
        }
    }

    nonisolated private static func updateActivity(
        withID activityID: String,
        state: LyricsActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        guard let activity = Activity<LyricsActivityAttributes>.activities.first(where: { $0.id == activityID }) else {
            return
        }

        await activity.update(
            .init(
                state: state,
                staleDate: staleDate
            )
        )
    }

    nonisolated private static func endActivity(withID activityID: String) async {
        guard let activity = Activity<LyricsActivityAttributes>.activities.first(where: { $0.id == activityID }) else {
            return
        }

        await activity.end(nil, dismissalPolicy: .immediate)
    }

    nonisolated private static func endAllSystemActivities() async {
        for activity in Activity<LyricsActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func buildState(from player: PlayerManager, song: Song) -> LyricsActivityAttributes.ContentState {
        let lyricVM = LyricViewModel.shared
        let lines = lyricVM.lyrics
        let idx = lyricVM.currentLineIndex
        let isCurrentSongLyrics = lyricVM.currentSongId == song.id

        let currentLyric: String = {
            guard isCurrentSongLyrics, lyricVM.hasLyrics, idx >= 0, idx < lines.count else {
                return player.isLoading ? String(localized: "加载歌词中") : song.name
            }
            let value = lines[idx].text.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? song.name : value
        }()

        let nextLyric: String? = {
            guard isCurrentSongLyrics, lyricVM.hasLyrics else { return nil }
            let nextIndex = idx + 1
            guard nextIndex >= 0, nextIndex < lines.count else { return nil }
            let value = lines[nextIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }()

        return LyricsActivityAttributes.ContentState(
            title: song.name,
            artist: song.artistName,
            album: song.album?.name ?? "",
            source: song.musicSource.widgetDisplayName,
            quality: player.qualityInfoText ?? player.qualityButtonText,
            lyric: currentLyric,
            nextLyric: nextLyric,
            playbackState: player.playbackSurfaceState,
            progress: normalizedProgress(currentTime: player.currentTime, duration: player.duration),
            elapsedTime: max(0, player.currentTime),
            duration: max(0, player.duration),
            updatedAt: Date()
        )
    }

    private func normalizedProgress(currentTime: Double, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        return max(0, min(1, currentTime / duration))
    }

    private func progressBucket(currentTime: Double) -> Int {
        Int(max(0, currentTime) / 2)
    }

    private func staleDate(for playbackState: PlaybackSurfaceState) -> Date? {
        switch playbackState {
        case .playing:
            return Date().addingTimeInterval(120)
        case .loading:
            return Date().addingTimeInterval(60)
        case .paused, .idle:
            return Date().addingTimeInterval(20)
        }
    }
}
#endif
