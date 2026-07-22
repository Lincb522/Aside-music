// NCMClient+Enhanced436.swift
// NeteaseCloudMusicApiEnhanced 4.36.2 新增模块接口

import Foundation

// MARK: - Enhanced 4.36.2 APIs

extension NCMClient {

    /// 获取关注歌手的新歌曲和 MV。
    public func artistNewSongMVListV2(
        startTimestamp: Int? = nil,
        sourceType: Int = 1,
        limit: Int = 10,
        firstRequest: Bool = true
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "sourceType": sourceType,
            "limit": limit,
            "firstRequest": firstRequest,
        ]
        if let startTimestamp {
            data["startTimestamp"] = startTimestamp
        }
        return try await request("/api/sub/artist/new/works/song-mv/list/v2", data: data)
    }

    /// 获取全部关注歌手最近的新歌。
    public func artistNewSongPlayall() async throws -> APIResponse {
        try await request("/api/sub/artist/new/works/song/playall", data: [:])
    }

    /// 解密 NeteaseCloudMusicApiEnhanced 支持的加密请求或响应数据。
    ///
    /// 此接口是服务端工具路由，仅支持已配置 `serverUrl` 的后端代理模式。
    public func decryptPayload(
        _ data: String,
        crypto: String = "eapi",
        isRequest: Bool = true
    ) async throws -> APIResponse {
        try await backendRoute("/decrypt", data: [
            "data": data,
            "crypto": crypto,
            "isReq": isRequest,
        ])
    }

    /// 获取听歌足迹歌曲播放排行。
    public func listenDataSongPlayRank(
        type: String = "month",
        endTime: Int? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = ["type": type]
        if let endTime { data["endTime"] = endTime }
        return try await request("/api/content/activity/listen/data/song/play/rank", data: data)
    }

    /// 获取 XEAPI 密钥。
    ///
    /// XEAPI 密钥协商由升级后的 Node 服务完成，因此此接口需要 `serverUrl`。
    public func registerXeapiKey(
        deviceID: String? = nil,
        currentKeyVersion: String? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = [:]
        if let deviceID { data["deviceId"] = deviceID }
        if let currentKeyVersion { data["currentKeyVersion"] = currentKeyVersion }
        return try await backendRoute("/register/xeapikey", data: data)
    }

    /// 提交歌曲播放状态。
    public func relayPlayStateSubmit(
        id: Int,
        sessionID: String? = nil,
        progress: Int = 0,
        playMode: String = "list_loop",
        type: String = "song"
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "id": id,
            "progress": progress,
            "playMode": playMode,
            "type": type,
        ]
        if let sessionID { data["sessionId"] = sessionID }
        return try await request("/api/relay/play/state/submit", data: data, crypto: .weapi)
    }

    /// 使用 NCBL 格式上报听歌打卡。
    ///
    /// 此接口由升级后的 Node 服务执行，需使用 `serverUrl`。未显式提供时会使用当前客户端 Cookie。
    public func scrobbleV1(
        id: Int,
        time: Int,
        total: Int? = nil,
        sourceID: String? = nil,
        source: String = "list",
        name: String = "",
        artist: String = "",
        bitrate: Int = 320,
        level: String = "exhigh",
        vip: Bool = false,
        cookie: String? = nil
    ) async throws -> APIResponse {
        let activeCookie = cookie ?? currentCookies
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "; ")
        var data: [String: Any] = [
            "id": id,
            "time": time,
            "source": source,
            "name": name,
            "artist": artist,
            "bitrate": bitrate,
            "level": level,
            "vip": vip,
            "cookie": activeCookie,
        ]
        if let total { data["total"] = total }
        if let sourceID { data["sourceid"] = sourceID }
        return try await backendRoute("/scrobble/v1", data: data)
    }

    /// 从云盘获取歌曲下载链接。
    public func songCloudDownload(id: Int) async throws -> APIResponse {
        try await request("/api/cloud/dowonload", data: ["id": id])
    }

    /// 一键领取全部会员成长值。
    ///
    /// 该接口使用 XEAPI，需配置 `serverUrl`。
    public func vipGrowthpointGetall() async throws -> APIResponse {
        try await backendRoute("/vip/growthpoint/getall")
    }

    /// 获取黑胶乐签打卡详情。
    public func vipSignDetail(timestamp: Int) async throws -> APIResponse {
        try await request("/api/vipnewcenter/app/level/user/checkin/history/detail", data: ["timestamp": timestamp])
    }

    /// 获取黑胶乐签打卡历史或状态。
    public func vipSignHistory(type: String = "0") async throws -> APIResponse {
        try await request("/api/vipnewcenter/app/minidesk/music/sign/pc", data: ["type": type])
    }

    /// 获取新版会员任务进度。
    ///
    /// 该接口使用 XEAPI，需配置 `serverUrl`。
    public func vipTasksV1(userID: Int? = nil) async throws -> APIResponse {
        var data: [String: Any] = [:]
        if let userID { data["id"] = userID }
        return try await backendRoute("/vip/tasks/v1", data: data)
    }
}
