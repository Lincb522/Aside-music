// NCMClient+Song.swift
// 歌曲相关 API 接口
// 歌曲详情、播放链接、歌词、红心、听歌打卡等

import Foundation

// MARK: - 歌曲 API

extension NCMClient {

    /// 获取歌曲详情
    /// - Parameter ids: 歌曲 ID 数组
    /// - Returns: API 响应，包含歌曲详细信息
    public func songDetail(ids: [Int]) async throws -> APIResponse {
        let c = "[" + ids.map { "{\"id\":\($0)}" }.joined(separator: ",") + "]"
        let data: [String: Any] = [
            "c": c,
        ]
        return try await request(
            "/api/v3/song/detail",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取歌曲播放链接
    /// - Parameters:
    ///   - ids: 歌曲 ID 数组
    ///   - br: 码率，默认 999000
    /// - Returns: API 响应，包含歌曲播放链接
    /// - Note: 启用 `autoUnblock` 后，不可用的歌曲会自动尝试第三方音源匹配
    public func songUrl(ids: [Int], br: Int = 999000) async throws -> APIResponse {
        let data: [String: Any] = [
            "ids": String(data: try JSONSerialization.data(
                withJSONObject: ids.map { String($0) }), encoding: .utf8)!,
            "br": br,
        ]
        let response = try await request(
            "/api/song/enhance/player/url",
            data: data
        )

        // 自动解灰
        guard autoUnblock, let manager = unblockManager, !manager.sources.isEmpty else {
            return response
        }
        return await autoUnblockResponse(response, ids: ids, quality: "\(br / 1000)")
    }

    /// 获取歌曲播放链接（v1 版本，使用音质等级）
    /// - Parameters:
    ///   - ids: 歌曲 ID 数组
    ///   - level: 音质等级，默认 `.exhigh`
    /// - Returns: API 响应，包含歌曲播放链接
    /// - Note: 启用 `autoUnblock` 后，不可用的歌曲会自动尝试第三方音源匹配
    public func songUrlV1(ids: [Int], level: SoundQualityType = .exhigh) async throws -> APIResponse {
        var data: [String: Any] = [
            "ids": "[" + ids.map { String($0) }.joined(separator: ",") + "]",
            "level": level.rawValue,
            "encodeType": "flac",
        ]
        // 沉浸环绕声需要额外参数
        if level == .sky {
            data["immerseType"] = "c51"
        }
        let response = try await request(
            "/api/song/enhance/player/url/v1",
            data: data
        )

        // 自动解灰：将音质等级映射为码率字符串
        guard autoUnblock, let manager = unblockManager, !manager.sources.isEmpty else {
            return response
        }
        let quality: String
        switch level {
        case .standard: quality = "128"
        case .exhigh: quality = "320"
        case .lossless: quality = "flac"
        case .hires: quality = "999"
        case .jyeffect: quality = "999"
        case .sky: quality = "999"
        case .jymaster: quality = "999"
        }
        return await autoUnblockResponse(response, ids: ids, quality: quality)
    }

    /// 获取歌曲下载链接
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - br: 码率，默认 999000
    /// - Returns: API 响应，包含歌曲下载链接
    public func songDownloadUrl(id: Int, br: Int = 999000) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "br": br,
        ]
        return try await request(
            "/api/song/enhance/download/url",
            data: data
        )
    }

    /// 获取歌词
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应，包含歌词信息
    public func lyric(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "tv": -1,
            "lv": -1,
            "rv": -1,
            "kv": -1,
            "_nmclfl": 1,
        ]
        return try await request(
            "/api/song/lyric",
            data: data
        )
    }

    /// 获取新版歌词（包含逐字歌词）
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应，包含新版歌词信息
    public func lyricNew(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "cp": false,
            "tv": 0,
            "lv": 0,
            "rv": 0,
            "kv": 0,
            "yv": 0,
            "ytv": 0,
            "yrv": 0,
        ]
        return try await request(
            "/api/song/lyric/v1",
            data: data
        )
    }

    /// 红心/取消红心歌曲
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - like: 是否红心，默认 true
    /// - Returns: API 响应
    public func like(id: Int, like: Bool = true) async throws -> APIResponse {
        let data: [String: Any] = [
            "alg": "itembased",
            "trackId": id,
            "like": like,
            "time": "3",
        ]
        return try await request(
            "/api/radio/like",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取喜欢的歌曲列表
    /// - Parameter uid: 用户 ID
    /// - Returns: API 响应，包含喜欢的歌曲 ID 列表
    public func likelist(uid: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "uid": uid,
        ]
        return try await request(
            "/api/song/like/get",
            data: data
        )
    }

    /// 听歌打卡
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - sourceid: 来源 ID（如歌单 ID）
    ///   - time: 播放时长（秒），默认 0
    /// - Returns: API 响应
    public func scrobble(id: Int, sourceid: Int, time: Int = 0) async throws -> APIResponse {
        let logEntry: [String: Any] = [
            "action": "play",
            "json": [
                "download": 0,
                "end": "playend",
                "id": id,
                "sourceId": sourceid,
                "time": time,
                "type": "song",
                "wifi": 0,
                "source": "list",
                "mainsite": 1,
                "content": "",
            ] as [String: Any],
        ]
        let logsData = try JSONSerialization.data(withJSONObject: [logEntry])
        let logsString = String(data: logsData, encoding: .utf8) ?? "[]"
        let data: [String: Any] = [
            "logs": logsString,
        ]
        return try await request(
            "/api/feedback/weblog",
            data: data,
            crypto: .weapi
        )
    }

    /// 检查歌曲可用性
    /// - Parameters:
    ///   - ids: 歌曲 ID 数组
    ///   - br: 码率，默认 999000
    /// - Returns: API 响应
    public func checkMusic(ids: [Int], br: Int = 999000) async throws -> APIResponse {
        let data: [String: Any] = [
            "ids": "[" + ids.map { String($0) }.joined(separator: ",") + "]",
            "br": br,
        ]
        return try await request(
            "/api/song/enhance/player/url",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取歌曲副歌时间
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应，包含副歌时间信息
    public func songChorus(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "ids": "[\(id)]",
        ]
        return try await request("/api/song/chorus", data: data)
    }

    /// 获取会员下载歌曲记录
    /// - Parameters:
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func songDownlist(limit: Int = 20, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": "true",
        ]
        return try await request("/api/member/song/downlist", data: data)
    }

    /// 获取歌曲下载链接（v1 版本，使用音质等级）
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - level: 音质等级
    /// - Returns: API 响应
    public func songDownloadUrlV1(id: Int, level: SoundQualityType = .exhigh) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "immerseType": "c51",
            "level": level.rawValue,
        ]
        return try await request("/api/song/enhance/download/url/v1", data: data)
    }

    /// 获取歌曲动态封面
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应
    public func songDynamicCover(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["songId": id]
        return try await request("/api/songplay/dynamic-cover", data: data)
    }

    /// 检查歌曲是否已喜爱
    /// - Parameter ids: 歌曲 ID 字符串（逗号分隔）
    /// - Returns: API 响应
    public func songLikeCheck(ids: String) async throws -> APIResponse {
        let data: [String: Any] = ["trackIds": ids]
        return try await request("/api/song/like/check", data: data)
    }

    /// 获取歌词摘录信息
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应
    public func songLyricsMark(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["songId": id]
        return try await request("/api/song/play/lyrics/mark/song", data: data)
    }

    /// 添加/修改歌词摘录
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - markId: 摘录 ID（修改时传入），默认空字符串
    ///   - markData: 摘录数据 JSON 字符串，默认 "[]"
    /// - Returns: API 响应
    public func songLyricsMarkAdd(id: Int, markId: String = "", markData: String = "[]") async throws -> APIResponse {
        let data: [String: Any] = [
            "songId": id,
            "markId": markId,
            "data": markData,
        ]
        return try await request("/api/song/play/lyrics/mark/add", data: data)
    }

    /// 删除歌词摘录
    /// - Parameter id: 摘录 ID
    /// - Returns: API 响应
    public func songLyricsMarkDel(id: String) async throws -> APIResponse {
        let data: [String: Any] = ["markIds": id]
        return try await request("/api/song/play/lyrics/mark/del", data: data)
    }

    /// 获取我的歌词本
    /// - Parameters:
    ///   - limit: 每页数量，默认 10
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func songLyricsMarkUserPage(limit: Int = 10, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/song/play/lyrics/mark/user/page", data: data)
    }

    /// 获取会员本月下载歌曲记录
    /// - Parameters:
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func songMonthdownlist(limit: Int = 20, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": "true",
        ]
        return try await request("/api/member/song/monthdownlist", data: data)
    }

    /// 获取歌曲音质详情
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应
    public func songMusicDetail(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["songId": id]
        return try await request("/api/song/music/detail/get", data: data)
    }

    /// 更新歌单中歌曲顺序
    /// - Parameters:
    ///   - pid: 歌单 ID
    ///   - ids: 歌曲 ID 排序字符串
    /// - Returns: API 响应
    public func songOrderUpdate(pid: Int, ids: String) async throws -> APIResponse {
        let data: [String: Any] = [
            "pid": pid,
            "trackIds": ids,
            "op": "update",
        ]
        return try await request("/api/playlist/manipulate/tracks", data: data)
    }

    /// 获取已购单曲列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func songPurchased(limit: Int = 20, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/single/mybought/song/list", data: data, crypto: .weapi)
    }

    /// 获取歌曲红心数量
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应
    public func songRedCount(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["songId": id]
        return try await request("/api/song/red/count", data: data)
    }

    /// 获取已购买单曲下载记录
    /// - Parameters:
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func songSingledownlist(limit: Int = 20, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": "true",
        ]
        return try await request("/api/member/song/singledownlist", data: data)
    }

    /// 获取音乐百科基础信息
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应
    public func songWikiSummary(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["songId": id]
        return try await request("/api/song/play/about/block/page", data: data)
    }
}
