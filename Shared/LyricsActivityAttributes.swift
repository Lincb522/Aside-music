import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

enum PlaybackSurfaceState: String, Codable, Hashable {
    case idle
    case loading
    case playing
    case paused

    var isPlaying: Bool {
        self == .playing
    }

    var isLoading: Bool {
        self == .loading
    }
}

#if canImport(ActivityKit)
struct LyricsActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var album: String
        var source: String
        var quality: String
        var lyric: String
        var nextLyric: String?
        var playbackState: PlaybackSurfaceState
        var progress: Double
        var elapsedTime: Double
        var duration: Double
        var updatedAt: Date

        var isPlaying: Bool {
            playbackState.isPlaying
        }

        var isLoading: Bool {
            playbackState.isLoading
        }
    }

    var songID: String
}
#endif
