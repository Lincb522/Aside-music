// NCMClient+Recommend.swift
// 推荐相关 API 接口
// 个性化推荐、每日推荐、私人 FM 等

import Foundation

// MARK: - 推荐 API

extension NCMClient {

    /// 个性化推荐歌单
    /// - Parameter limit: 数量限制，默认 30
    /// - Returns: API 响应，包含推荐歌单列表
    public func personalized(limit: Int = 30, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
            "n": 1000,
        ]
        return try await request(
            "/api/personalized/playlist",
            data: data,
            crypto: .weapi
        )
    }

    /// 推荐新歌
    /// - Parameter limit: 数量限制，默认 10
    /// - Returns: API 响应，包含推荐新歌列表
    public func personalizedNewsong(limit: Int = 10, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "type": "recommend",
            "limit": limit,
            "offset": offset,
            "areaId": 0,
        ]
        return try await request(
            "/api/personalized/newsong",
            data: data,
            crypto: .weapi
        )
    }

    /// 推荐 MV
    /// - Returns: API 响应，包含推荐 MV 列表
    public func personalizedMv() async throws -> APIResponse {
        return try await request(
            "/api/personalized/mv",
            data: [:],
            crypto: .weapi
        )
    }

    /// 独家放送
    /// - Returns: API 响应，包含独家放送内容
    public func personalizedPrivatecontent() async throws -> APIResponse {
        return try await request(
            "/api/personalized/privatecontent",
            data: [:],
            crypto: .weapi
        )
    }

    /// 独家放送列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 60
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含独家放送列表
    public func personalizedPrivatecontentList(
        limit: Int = 60,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/v2/privatecontent/list",
            data: data,
            crypto: .weapi
        )
    }

    /// 每日推荐歌曲
    /// - Returns: API 响应，包含每日推荐歌曲列表
    public func recommendSongs() async throws -> APIResponse {
        return try await request(
            "/api/v3/discovery/recommend/songs",
            data: [:],
            crypto: .weapi
        )
    }

    /// 每日推荐歌单
    /// - Returns: API 响应，包含每日推荐歌单列表
    public func recommendResource() async throws -> APIResponse {
        return try await request(
            "/api/v1/discovery/recommend/resource",
            data: [:],
            crypto: .weapi
        )
    }

    /// 私人 FM
    /// - Returns: API 响应，包含私人 FM 歌曲
    public func personalFm() async throws -> APIResponse {
        return try await request(
            "/api/v1/radio/get",
            data: [:],
            crypto: .weapi
        )
    }

    /// 私人 FM 模式
    /// - Parameter mode: FM 模式，默认 "DEFAULT"
    /// - Returns: API 响应
    public func personalFmMode(mode: String = "DEFAULT") async throws -> APIResponse {
        let data: [String: Any] = [
            "mode": mode,
            "subMode": "DEFAULT",
            "limit": 3,
        ]
        return try await request(
            "/api/v1/radio/get",
            data: data
        )
    }

    // MARK: - 以下为补充接口

    /// 推荐电台节目
    /// - Returns: API 响应
    public func personalizedDjprogram() async throws -> APIResponse {
        return try await request("/api/personalized/djprogram", data: [:], crypto: .weapi)
    }

    /// 每日推荐歌曲 - 不感兴趣
    /// - Parameter id: 歌曲 ID
    /// - Returns: API 响应
    public func recommendSongsDislike(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "resId": id,
            "resType": 4,
            "sceneType": 1,
        ]
        return try await request("/api/v2/discovery/recommend/dislike", data: data, crypto: .weapi)
    }

    /// 获取历史每日推荐歌曲
    /// - Returns: API 响应
    public func historyRecommendSongs() async throws -> APIResponse {
        return try await request("/api/discovery/recommend/songs/history/recent", data: [:], crypto: .weapi)
    }

    /// 获取历史每日推荐歌曲详情
    /// - Parameter date: 日期字符串（可选）
    /// - Returns: API 响应
    public func historyRecommendSongsDetail(date: String = "") async throws -> APIResponse {
        let data: [String: Any] = ["date": date]
        return try await request("/api/discovery/recommend/songs/history/detail", data: data, crypto: .weapi)
    }

    /// 推荐节目
    /// - Parameters:
    ///   - type: 分类 ID
    ///   - limit: 每页数量，默认 10
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func programRecommend(type: Int, limit: Int = 10, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "cateId": type,
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/program/recommend/v1", data: data, crypto: .weapi)
    }
}
