import Foundation

// MARK: - 推荐相关 API

public extension QQMusicClient {

    /// 获取主页推荐
    func homeFeed(
        page: Int = 1,
        direction: Int = 0,
        songCount: Int = 0,
        cache: [String]? = nil
    ) async throws -> JSON {
        var parameters: [String: Any] = [
            "page": page,
            "direction": direction,
            "s_num": songCount,
        ]
        if let cache { parameters["v_cache"] = cache }
        return try await requestWrapped("/recommend/get_home_feed", parameters: parameters)
    }

    /// 获取猜你喜欢
    func guessLike() async throws -> JSON {
        try await requestWrapped("/recommend/get_guess_recommend")
    }

    /// 获取雷达推荐
    func radarRecommend(page: Int = 1) async throws -> JSON {
        try await requestWrapped("/recommend/get_radar_recommend", params: ["page": String(page)])
    }

    /// 获取推荐歌单
    func recommendSonglist(page: Int = 1, num: Int = 25) async throws -> JSON {
        try await requestWrapped("/recommend/get_recommend_songlist", params: [
            "page": String(page),
            "num": String(num),
        ])
    }

    /// 获取推荐新歌
    func recommendNewSong(type: Int = 5) async throws -> JSON {
        try await requestWrapped("/recommend/get_recommend_newsong", params: ["type": String(type)])
    }

    /// 获取歌单广场分类。
    func songlistCategories() async throws -> JSON {
        try await requestWrapped("/recommend/get_songlist_categories")
    }

    /// 获取指定分类的歌单。
    func songlistsByCategory(
        categoryID: Int,
        sortID: Int = 5,
        page: Int = 0,
        size: Int = 30
    ) async throws -> JSON {
        try await requestWrapped("/recommend/get_songlist_by_category", params: [
            "category_id": String(categoryID),
            "sort_id": String(sortID),
            "page": String(page),
            "size": String(size),
        ])
    }
}
