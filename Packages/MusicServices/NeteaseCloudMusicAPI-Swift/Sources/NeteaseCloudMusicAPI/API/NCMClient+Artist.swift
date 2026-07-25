// NCMClient+Artist.swift
// 歌手相关 API 接口
// 歌手详情、歌曲、专辑、MV、相似歌手、歌手列表、收藏等

import Foundation

// MARK: - 歌手 API

extension NCMClient {

    /// 获取歌手详情
    /// - Parameter id: 歌手 ID
    /// - Returns: API 响应，包含歌手详细信息
    public func artistDetail(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/artist/head/info/get",
            data: data
        )
    }

    /// 获取歌手信息（含热门歌曲）
    /// - Parameter id: 歌手 ID
    /// - Returns: API 响应，包含歌手信息和热门歌曲
    public func artists(id: Int) async throws -> APIResponse {
        return try await request(
            "/api/v1/artist/\(id)",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取歌手歌曲列表
    /// - Parameters:
    ///   - id: 歌手 ID
    ///   - limit: 每页数量，默认 50
    ///   - offset: 偏移量，默认 0
    ///   - order: 排序方式，默认 `.hot`（热门排序）
    /// - Returns: API 响应，包含歌手歌曲列表
    public func artistSongs(
        id: Int,
        limit: Int = 50,
        offset: Int = 0,
        order: ArtistSongsOrder = .hot
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "private_cloud": true,
            "work_type": 1,
            "order": order.rawValue,
            "offset": offset,
            "limit": limit,
        ]
        return try await request(
            "/api/v1/artist/songs",
            data: data
        )
    }

    /// 获取歌手专辑列表
    /// - Parameters:
    ///   - id: 歌手 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含歌手专辑列表
    public func artistAlbum(
        id: Int,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/artist/albums/\(id)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取歌手 MV 列表
    /// - Parameters:
    ///   - id: 歌手 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含歌手 MV 列表
    public func artistMv(
        id: Int,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "artistId": id,
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/artist/mvs",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取歌手描述
    /// - Parameter id: 歌手 ID
    /// - Returns: API 响应，包含歌手描述信息
    public func artistDesc(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/artist/introduction",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取相似歌手
    /// - Parameter id: 歌手 ID
    /// - Returns: API 响应，包含相似歌手列表
    public func simiArtist(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "artistid": id,
        ]
        return try await request(
            "/api/discovery/simiArtist",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取歌手列表
    /// - Parameters:
    ///   - area: 歌手区域，默认 `.all`
    ///   - type: 歌手类型，默认 `.male`
    ///   - initial: 首字母筛选，默认为空字符串
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含歌手列表
    public func artistList(
        area: ArtistArea = .all,
        type: ArtistType = .male,
        initial: String = "",
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "type": type.rawValue,
            "area": area.rawValue,
            "initial": initial,
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/v1/artist/list",
            data: data,
            crypto: .weapi
        )
    }

    /// 收藏/取消收藏歌手
    /// - Parameters:
    ///   - id: 歌手 ID
    ///   - action: 操作类型（`.sub` 收藏，`.unsub` 取消收藏）
    /// - Returns: API 响应
    public func artistSub(
        id: Int,
        action: SubAction
    ) async throws -> APIResponse {
        let actionStr = action == .sub ? "sub" : "unsub"
        let data: [String: Any] = [
            "artistId": id,
            "artistIds": "[\(id)]",
        ]
        return try await request(
            "/api/artist/\(actionStr)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取已收藏歌手列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 25
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含已收藏歌手列表
    public func artistSublist(
        limit: Int = 25,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/artist/sublist",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取歌手热门 50 首歌曲
    /// - Parameter id: 歌手 ID
    /// - Returns: API 响应，包含歌手热门歌曲列表
    public func artistTopSong(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/artist/top/song",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取歌手动态信息
    /// - Parameter id: 歌手 ID
    /// - Returns: API 响应
    public func artistDetailDynamic(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["id": id]
        return try await request("/api/artist/detail/dynamic", data: data)
    }

    /// 获取歌手粉丝列表
    /// - Parameters:
    ///   - id: 歌手 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func artistFans(id: Int, limit: Int = 20, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/artist/fans/get", data: data, crypto: .weapi)
    }

    /// 获取歌手粉丝数量
    /// - Parameter id: 歌手 ID
    /// - Returns: API 响应
    public func artistFollowCount(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["id": id]
        return try await request("/api/artist/follow/count/get", data: data, crypto: .weapi)
    }

    /// 获取关注歌手的新 MV
    /// - Parameters:
    ///   - limit: 每页数量，默认 20
    ///   - before: 时间戳（可选）
    /// - Returns: API 响应
    public func artistNewMv(limit: Int = 20, offset: Int = 0, before: Int? = nil) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "startTimestamp": before ?? Int(Date().timeIntervalSince1970 * 1000),
        ]
        return try await request("/api/sub/artist/new/works/mv/list", data: data, crypto: .weapi)
    }

    /// 获取关注歌手的新歌
    /// - Parameters:
    ///   - limit: 每页数量，默认 20
    ///   - before: 时间戳（可选）
    /// - Returns: API 响应
    public func artistNewSong(limit: Int = 20, offset: Int = 0, before: Int? = nil) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "startTimestamp": before ?? Int(Date().timeIntervalSince1970 * 1000),
        ]
        return try await request("/api/sub/artist/new/works/song/list", data: data, crypto: .weapi)
    }

    /// 获取歌手相关视频
    /// - Parameters:
    ///   - id: 歌手 ID
    ///   - size: 每页数量，默认 10
    ///   - cursor: 分页游标，默认 0
    ///   - order: 排序方式，默认 0
    /// - Returns: API 响应
    public func artistVideo(id: Int, size: Int = 10, cursor: Int = 0, order: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "artistId": id,
            "page": "{\"size\":\(size),\"cursor\":\(cursor)}",
            "tab": 0,
            "order": order,
        ]
        return try await request("/api/mlog/artist/video", data: data, crypto: .weapi)
    }
}
