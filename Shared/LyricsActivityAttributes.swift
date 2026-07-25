import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// 主 App、Widget 与实时活动共用的精简播放状态。
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
/// 歌词实时活动的固定歌曲身份与可更新展示状态。
struct LyricsActivityAttributes: ActivityAttributes {
    /// 实时活动每次更新携带的歌曲、歌词与播放进度。
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
