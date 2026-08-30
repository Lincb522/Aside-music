// NCMClient+Comment.swift
// 评论相关 API 接口
// 评论增删、热评、楼层评论等

import Foundation

// MARK: - 评论 API

extension NCMClient {

    /// 评论类型对应的 threadId 前缀映射
    private static let commentThreadPrefixes: [CommentType: String] = [
        .song: "R_SO_4_",
        .mv: "R_MV_5_",
        .playlist: "A_PL_0_",
        .album: "R_AL_3_",
        .dj: "A_DJ_1_",
        .video: "R_VI_62_",
        .event: "A_EV_2_",
        .podcast: "A_DR_14_",
    ]

    /// 发表/删除/回复评论
    /// - Parameters:
    ///   - action: 评论操作类型（发表、删除、回复）
    ///   - type: 评论资源类型
    ///   - id: 资源 ID
    ///   - content: 评论内容（发表和回复时需要）
    ///   - commentId: 评论 ID（删除和回复时需要）
    /// - Returns: API 响应
    public func comment(
        action: CommentAction,
        type: CommentType,
        id: Int,
        content: String = "",
        commentId: Int = 0
    ) async throws -> APIResponse {
        // ncm /comment 接口需要的参数格式
        // t: 操作类型 (1=发送, 0=删除, 2=回复)
        // type: 资源类型 (0=歌曲, 1=MV, 2=歌单, 3=专辑, 4=电台节目, 5=视频, 6=动态, 7=播客声音)
        // id: 资源 ID
        // content: 评论内容
        // commentId: 回复的评论 ID（回复时需要）
        var data: [String: Any] = [
            "t": action.rawValue,
            "type": type.rawValue,
            "id": id,
        ]
        switch action {
        case .add:
            data["content"] = content
        case .delete:
            data["commentId"] = commentId
        case .reply:
            data["content"] = content
            data["commentId"] = commentId
        }
        return try await request(
            "/api/resource/comments/\(action.rawValue == 1 ? "add" : action.rawValue == 0 ? "delete" : "reply")",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取新版评论列表
    /// - Parameters:
    ///   - type: 评论资源类型
    ///   - id: 资源 ID
    ///   - pageNo: 页码，默认 1
    ///   - pageSize: 每页数量，默认 20
    ///   - sortType: 排序类型，默认 99（推荐排序）
    ///   - cursor: 分页游标，默认空字符串
    /// - Returns: API 响应，包含评论列表
    public func commentNew(
        type: CommentType,
        id: Int,
        pageNo: Int = 1,
        pageSize: Int = 20,
        sortType: Int = 99,
        cursor: String = ""
    ) async throws -> APIResponse {
        let prefix = NCMClient.commentThreadPrefixes[type] ?? "R_SO_4_"
        let threadId = "\(prefix)\(id)"
        let data: [String: Any] = [
            "threadId": threadId,
            "pageNo": pageNo,
            "showInner": true,
            "pageSize": pageSize,
            "cursor": sortType == 3 ? cursor : String((pageNo - 1) * pageSize),
            "sortType": sortType,
        ]
        return try await request(
            "/api/v2/resource/comments",
            data: data
        )
    }

    /// 获取热评列表
    /// - Parameters:
    ///   - type: 评论资源类型
    ///   - id: 资源 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含热评列表
    public func commentHot(
        type: CommentType,
        id: Int,
        limit: Int = 20,
        offset: Int = 0,
        beforeTime: Int = 0
    ) async throws -> APIResponse {
        let prefix = NCMClient.commentThreadPrefixes[type] ?? "R_SO_4_"
        let threadId = "\(prefix)\(id)"
        let data: [String: Any] = [
            "rid": threadId,
            "limit": limit,
            "offset": offset,
            "beforeTime": beforeTime,
        ]
        return try await request(
            "/api/v1/resource/hotcomments/\(threadId)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取楼层评论
    /// - Parameters:
    ///   - type: 评论资源类型
    ///   - id: 资源 ID
    ///   - parentCommentId: 父评论 ID
    ///   - limit: 每页数量，默认 20
    ///   - time: 分页时间戳，默认 -1
    /// - Returns: API 响应，包含楼层评论列表
    public func commentFloor(
        type: CommentType,
        id: Int,
        parentCommentId: Int,
        limit: Int = 20,
        offset: Int = 0,
        time: Int = -1
    ) async throws -> APIResponse {
        let prefix = NCMClient.commentThreadPrefixes[type] ?? "R_SO_4_"
        let threadId = "\(prefix)\(id)"
        let data: [String: Any] = [
            "parentCommentId": parentCommentId,
            "threadId": threadId,
            "time": time,
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/resource/comment/floor/get",
            data: data,
            crypto: .weapi
        )
    }

    /// 评论点赞/取消点赞
    /// - Parameters:
    ///   - type: 评论资源类型
    ///   - id: 资源 ID
    ///   - commentId: 评论 ID
    ///   - like: 是否点赞（true 点赞，false 取消点赞）
    /// - Returns: API 响应
    public func commentLike(
        type: CommentType,
        id: Int,
        commentId: Int,
        like: Bool
    ) async throws -> APIResponse {
        let prefix = NCMClient.commentThreadPrefixes[type] ?? "R_SO_4_"
        let threadId = "\(prefix)\(id)"
        let data: [String: Any] = [
            "threadId": threadId,
            "commentId": commentId,
        ]
        return try await request(
            "/api/v1/comment/\(like ? "like" : "unlike")",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取歌曲评论
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含歌曲评论列表
    public func commentMusic(
        id: Int,
        limit: Int = 20,
        offset: Int = 0,
        beforeTime: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "rid": id,
            "limit": limit,
            "offset": offset,
            "beforeTime": beforeTime,
        ]
        return try await request(
            "/api/v1/resource/comments/R_SO_4_\(id)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取歌单评论
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含歌单评论列表
    public func commentPlaylist(
        id: Int,
        limit: Int = 20,
        offset: Int = 0,
        beforeTime: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "rid": id,
            "limit": limit,
            "offset": offset,
            "beforeTime": beforeTime,
        ]
        return try await request(
            "/api/v1/resource/comments/A_PL_0_\(id)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取专辑评论
    /// - Parameters:
    ///   - id: 专辑 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含专辑评论列表
    public func commentAlbum(
        id: Int,
        limit: Int = 20,
        offset: Int = 0,
        beforeTime: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "rid": id,
            "limit": limit,
            "offset": offset,
            "beforeTime": beforeTime,
        ]
        return try await request(
            "/api/v1/resource/comments/R_AL_3_\(id)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取 MV 评论
    /// - Parameters:
    ///   - id: MV ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含 MV 评论列表
    public func commentMv(
        id: Int,
        limit: Int = 20,
        offset: Int = 0,
        beforeTime: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "rid": id,
            "limit": limit,
            "offset": offset,
            "beforeTime": beforeTime,
        ]
        return try await request(
            "/api/v1/resource/comments/R_MV_5_\(id)",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取电台评论
    /// - Parameters:
    ///   - id: 电台节目 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    ///   - before: 分页时间戳，默认 0
    /// - Returns: API 响应
    public func commentDj(id: Int, limit: Int = 20, offset: Int = 0, before: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "rid": id,
            "limit": limit,
            "offset": offset,
            "beforeTime": before,
        ]
        return try await request("/api/v1/resource/comments/A_DJ_1_\(id)", data: data, crypto: .weapi)
    }

    /// 获取动态评论
    /// - Parameters:
    ///   - threadId: 动态 threadId
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    ///   - before: 分页时间戳，默认 0
    /// - Returns: API 响应
    public func commentEvent(threadId: String, limit: Int = 20, offset: Int = 0, before: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "beforeTime": before,
        ]
        return try await request("/api/v1/resource/comments/\(threadId)", data: data, crypto: .weapi)
    }

    /// 获取评论抱一抱列表
    /// - Parameters:
    ///   - uid: 目标用户 ID
    ///   - cid: 评论 ID
    ///   - sid: 资源 ID
    ///   - type: 资源类型，默认 0
    ///   - cursor: 分页游标，默认 "-1"
    ///   - page: 页码，默认 1
    ///   - pageSize: 每页数量，默认 100
    /// - Returns: API 响应
    public func commentHugList(
        uid: Int,
        cid: Int,
        sid: Int,
        type: Int = 0,
        cursor: String = "-1",
        page: Int = 1,
        pageSize: Int = 100
    ) async throws -> APIResponse {
        let prefix = NCMClient.commentThreadPrefixes[CommentType(rawValue: type) ?? .song] ?? "R_SO_4_"
        let threadId = "\(prefix)\(sid)"
        let data: [String: Any] = [
            "targetUserId": uid,
            "commentId": cid,
            "cursor": cursor,
            "threadId": threadId,
            "pageNo": page,
            "idCursor": -1,
            "pageSize": pageSize,
        ]
        return try await request("/api/v2/resource/comments/hug/list", data: data)
    }

    /// 获取视频评论
    /// - Parameters:
    ///   - id: 视频 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    ///   - before: 分页时间戳，默认 0
    /// - Returns: API 响应
    public func commentVideo(id: String, limit: Int = 20, offset: Int = 0, before: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "rid": id,
            "limit": limit,
            "offset": offset,
            "beforeTime": before,
        ]
        return try await request("/api/v1/resource/comments/R_VI_62_\(id)", data: data, crypto: .weapi)
    }
}
