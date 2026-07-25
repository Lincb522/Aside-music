// NCMClient+MV.swift
// MV 和视频相关 API 接口
// MV 详情、链接、列表、收藏、视频详情等

import Foundation

// MARK: - MV 和视频 API

extension NCMClient {

    /// 获取 MV 详情
    /// - Parameter mvid: MV ID
    /// - Returns: API 响应，包含 MV 详细信息
    public func mvDetail(mvid: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": mvid,
        ]
        return try await request(
            "/api/v1/mv/detail",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取 MV 点赞/评论数等信息
    /// - Parameter mvid: MV ID
    /// - Returns: API 响应，包含 MV 点赞转发评论数
    public func mvDetailInfo(mvid: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "threadid": "R_MV_5_\(mvid)",
            "composeliked": true,
        ]
        return try await request(
            "/api/comment/commentthread/info",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取 MV 播放链接
    /// - Parameters:
    ///   - id: MV ID
    ///   - r: 分辨率，默认 1080
    /// - Returns: API 响应，包含 MV 播放链接
    public func mvUrl(id: Int, r: Int = 1080) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "r": r,
        ]
        return try await request(
            "/api/song/enhance/play/mv/url",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取 MV 列表
    /// - Parameters:
    ///   - area: MV 区域，默认 `.all`
    ///   - type: MV 类型，默认 `.all`
    ///   - order: 排序方式，默认 `.hot`
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含 MV 列表
    public func mvAll(
        area: MvArea = .all,
        type: MvType = .all,
        order: MvOrder = .hot,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "tags": String(
                data: try JSONSerialization.data(withJSONObject: [
                    "地区": area.rawValue,
                    "类型": type.rawValue,
                    "排序": order.rawValue,
                ]),
                encoding: .utf8
            )!,
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/mv/all",
            data: data
        )
    }

    /// 获取最新 MV
    /// - Parameters:
    ///   - area: MV 区域，默认 `.all`
    ///   - limit: 每页数量，默认 30
    /// - Returns: API 响应，包含最新 MV 列表
    public func mvFirst(
        area: MvArea = .all,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "area": area.rawValue,
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/mv/first",
            data: data
        )
    }

    /// 获取网易出品 MV
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含网易出品 MV 列表
    public func mvExclusiveRcmd(
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/mv/exclusive/rcmd",
            data: data
        )
    }

    /// 收藏/取消收藏 MV
    /// - Parameters:
    ///   - mvid: MV ID
    ///   - action: 操作类型（`.sub` 收藏，`.unsub` 取消收藏）
    /// - Returns: API 响应
    public func mvSub(
        mvid: Int,
        action: SubAction
    ) async throws -> APIResponse {
        let actionStr = action == .sub ? "sub" : "unsub"
        let data: [String: Any] = [
            "mvId": mvid,
            "mvIds": "[\(mvid)]",
        ]
        return try await request(
            "/api/mv/\(actionStr)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取已收藏 MV 列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 25
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含已收藏 MV 列表
    public func mvSublist(
        limit: Int = 25,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/cloudvideo/allvideo/sublist",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取视频详情
    /// - Parameter id: 视频 ID
    /// - Returns: API 响应，包含视频详细信息
    public func videoDetail(id: String) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/cloudvideo/v1/video/detail",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取视频点赞/评论数等信息
    /// - Parameter vid: 视频 ID
    /// - Returns: API 响应，包含视频点赞转发评论数
    public func videoDetailInfo(vid: String) async throws -> APIResponse {
        let data: [String: Any] = [
            "threadid": "R_VI_62_\(vid)",
            "composeliked": true,
        ]
        return try await request(
            "/api/comment/commentthread/info",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取视频播放链接
    /// - Parameters:
    ///   - id: 视频 ID
    ///   - resolution: 分辨率，默认 1080
    /// - Returns: API 响应，包含视频播放链接
    public func videoUrl(id: String, resolution: Int = 1080) async throws -> APIResponse {
        let data: [String: Any] = [
            "ids": "[\"\(id)\"]",
            "resolution": resolution,
        ]
        return try await request(
            "/api/cloudvideo/playurl",
            data: data,
            crypto: .weapi
        )
    }

    /// 收藏/取消收藏视频
    /// - Parameters:
    ///   - id: 视频 ID
    ///   - action: 操作类型（`.sub` 收藏，`.unsub` 取消收藏）
    /// - Returns: API 响应
    public func videoSub(
        id: String,
        action: SubAction
    ) async throws -> APIResponse {
        let actionStr = action == .sub ? "sub" : "unsub"
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/cloudvideo/video/\(actionStr)",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取视频分类列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 99
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func videoCategoryList(limit: Int = 99, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "offset": offset,
            "total": "true",
            "limit": limit,
        ]
        return try await request("/api/cloudvideo/category/list", data: data, crypto: .weapi)
    }

    /// 获取视频标签/分类下的视频
    /// - Parameters:
    ///   - id: 标签/分类 ID
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func videoGroup(id: Int, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "groupId": id,
            "offset": offset,
            "need_preview_url": "true",
            "total": true,
        ]
        return try await request("/api/videotimeline/videogroup/otherclient/get", data: data, crypto: .weapi)
    }

    /// 获取视频标签列表
    /// - Returns: API 响应
    public func videoGroupList() async throws -> APIResponse {
        return try await request("/api/cloudvideo/group/list", data: [:], crypto: .weapi)
    }

    /// 获取全部视频列表
    /// - Parameter offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func videoTimelineAll(offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "groupId": 0,
            "offset": offset,
            "need_preview_url": "true",
            "total": true,
        ]
        return try await request("/api/videotimeline/otherclient/get", data: data, crypto: .weapi)
    }

    /// 获取推荐视频
    /// - Parameter offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func videoTimelineRecommend(offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "offset": offset,
            "filterLives": "[]",
            "withProgramInfo": "true",
            "needUrl": "1",
            "resolution": "480",
        ]
        return try await request("/api/videotimeline/get", data: data, crypto: .weapi)
    }

    /// 获取相关视频
    /// - Parameter id: 视频/MV ID
    /// - Returns: API 响应
    public func relatedAllvideo(id: String) async throws -> APIResponse {
        let isNumeric = id.allSatisfy { $0.isNumber }
        let data: [String: Any] = [
            "id": id,
            "type": isNumeric ? 0 : 1,
        ]
        return try await request("/api/cloudvideo/v1/allvideo/rcmd", data: data, crypto: .weapi)
    }
}
