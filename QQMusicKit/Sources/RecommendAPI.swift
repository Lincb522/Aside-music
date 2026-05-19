import Foundation

// MARK: - 推荐相关 API

public extension QQMusicClient {

    /// 获取主页推荐
    func homeFeed() async throws -> JSON {
        try await requestWrapped("/recommend/get_home_feed")
    }

    /// 获取猜你喜欢
    func guessLike() async throws -> JSON {
        try await requestWrapped("/recommend/get_guess_recommend")
    }

    /// 获取雷达推荐
    func radarRecommend() async throws -> JSON {
        try await requestWrapped("/recommend/get_radar_recommend")
    }

    /// 获取推荐歌单
    func recommendSonglist() async throws -> JSON {
        try await requestWrapped("/recommend/get_recommend_songlist")
    }

    /// 获取推荐新歌
    func recommendNewSong() async throws -> JSON {
        try await requestWrapped("/recommend/get_recommend_newsong")
    }
}
