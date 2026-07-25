// NCMClient+Message.swift
// 私信相关 API 接口
// 私信、通知、发送消息等

import Foundation

// MARK: - 私信与消息 API

extension NCMClient {

    /// 获取私信列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含私信列表
    public func msgPrivate(
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": "true",
        ]
        return try await request(
            "/api/msg/private/users",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取私信历史记录
    /// - Parameters:
    ///   - uid: 对方用户 ID
    ///   - limit: 每页数量，默认 30
    ///   - before: 上一页最后一条消息的时间戳，默认 0（获取最新）
    /// - Returns: API 响应，包含私信历史记录
    public func msgPrivateHistory(
        uid: Int,
        limit: Int = 30,
        offset: Int = 0,
        before: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "userId": uid,
            "limit": limit,
            "offset": offset,
            "time": before,
            "total": "true",
        ]
        return try await request(
            "/api/msg/private/history",
            data: data,
            crypto: .weapi
        )
    }

    /// 发送文本私信
    /// - Parameters:
    ///   - userIds: 接收者用户 ID 数组
    ///   - msg: 消息内容
    /// - Returns: API 响应
    public func sendText(
        userIds: [Int],
        msg: String
    ) async throws -> APIResponse {
        let userIdsJson = "[" + userIds.map { String($0) }.joined(separator: ",") + "]"
        let data: [String: Any] = [
            "type": "text",
            "userIds": userIdsJson,
            "msg": msg,
        ]
        return try await request(
            "/api/msg/private/send",
            data: data
        )
    }

    /// 发送歌曲私信
    /// - Parameters:
    ///   - userIds: 接收者用户 ID 数组
    ///   - id: 歌曲 ID
    ///   - msg: 附加消息，默认空字符串
    /// - Returns: API 响应
    public func sendSong(
        userIds: [Int],
        id: Int,
        msg: String = ""
    ) async throws -> APIResponse {
        let userIdsJson = "[" + userIds.map { String($0) }.joined(separator: ",") + "]"
        let data: [String: Any] = [
            "type": "song",
            "userIds": userIdsJson,
            "id": id,
            "msg": msg,
        ]
        return try await request(
            "/api/msg/private/send",
            data: data
        )
    }

    /// 发送歌单私信
    /// - Parameters:
    ///   - userIds: 接收者用户 ID 数组
    ///   - id: 歌单 ID
    ///   - msg: 附加消息，默认空字符串
    /// - Returns: API 响应
    public func sendPlaylist(
        userIds: [Int],
        id: Int,
        msg: String = ""
    ) async throws -> APIResponse {
        let userIdsJson = "[" + userIds.map { String($0) }.joined(separator: ",") + "]"
        let data: [String: Any] = [
            "type": "playlist",
            "userIds": userIdsJson,
            "id": id,
            "msg": msg,
        ]
        return try await request(
            "/api/msg/private/send",
            data: data
        )
    }

    /// 发送专辑私信
    /// - Parameters:
    ///   - userIds: 接收者用户 ID 数组
    ///   - id: 专辑 ID
    ///   - msg: 附加消息，默认空字符串
    /// - Returns: API 响应
    public func sendAlbum(
        userIds: [Int],
        id: Int,
        msg: String = ""
    ) async throws -> APIResponse {
        let userIdsJson = "[" + userIds.map { String($0) }.joined(separator: ",") + "]"
        let data: [String: Any] = [
            "type": "album",
            "userIds": userIdsJson,
            "id": id,
            "msg": msg,
        ]
        return try await request(
            "/api/msg/private/send",
            data: data
        )
    }

    /// 获取通知列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - lasttime: 上一页最后一条通知的时间戳，默认 -1（获取最新）
    /// - Returns: API 响应，包含通知列表
    public func msgNotices(
        limit: Int = 30,
        offset: Int = 0,
        lasttime: Int = -1
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "time": lasttime,
        ]
        return try await request(
            "/api/msg/notices",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取最近联系人
    /// - Returns: API 响应，包含最近联系人列表
    public func msgRecentcontact() async throws -> APIResponse {
        return try await request(
            "/api/msg/recentcontact/get",
            data: [:],
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取评论消息
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - before: 分页时间戳，默认 "-1"
    ///   - limit: 每页数量，默认 30
    /// - Returns: API 响应
    public func msgComments(uid: Int, before: String = "-1", limit: Int = 30, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "beforeTime": before,
            "limit": limit,
            "offset": offset,
            "total": "true",
            "uid": uid,
        ]
        return try await request("/api/v1/user/comments/\(uid)", data: data, crypto: .weapi)
    }

    /// 获取 @我 的消息
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func msgForwards(limit: Int = 30, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "offset": offset,
            "limit": limit,
            "total": "true",
        ]
        return try await request("/api/forwards/get", data: data, crypto: .weapi)
    }
}
