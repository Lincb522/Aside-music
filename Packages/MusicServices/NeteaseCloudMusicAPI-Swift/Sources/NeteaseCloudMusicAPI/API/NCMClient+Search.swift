// NCMClient+Search.swift
// 搜索相关 API 接口
// 搜索、云搜索、热搜、搜索建议等

import Foundation

// MARK: - 搜索 API

extension NCMClient {

    /// 搜索
    /// - Parameters:
    ///   - keywords: 搜索关键词
    ///   - type: 搜索类型，默认 `.single`（单曲）
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含搜索结果
    public func search(
        keywords: String,
        type: SearchType = .single,
        limit: Int = 30,
        offset: Int = 0,
        scene: String = ""
    ) async throws -> APIResponse {
        // type 为 2000 时使用语音搜索接口
        if type.rawValue == 2000 {
            let data: [String: Any] = [
                "keyword": keywords,
                "scene": scene,
                "limit": limit,
                "offset": offset,
            ]
            return try await request(
                "/api/search/voice/get",
                data: data
            )
        }
        let data: [String: Any] = [
            "s": keywords,
            "type": type.rawValue,
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/search/get",
            data: data
        )
    }

    /// 云搜索（更全面的搜索结果）
    /// - Parameters:
    ///   - keywords: 搜索关键词
    ///   - type: 搜索类型，默认 `.single`（单曲）
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含云搜索结果
    public func cloudsearch(
        keywords: String,
        type: SearchType = .single,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "s": keywords,
            "type": type.rawValue,
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/cloudsearch/pc",
            data: data
        )
    }

    /// 热搜详情
    /// - Returns: API 响应，包含热搜详细列表
    public func searchHotDetail() async throws -> APIResponse {
        return try await request(
            "/api/hotsearchlist/get",
            data: [:],
            crypto: .weapi
        )
    }

    /// 搜索建议
    /// - Parameters:
    ///   - keywords: 搜索关键词
    ///   - type: 建议类型，默认 `.mobile`
    /// - Returns: API 响应，包含搜索建议列表
    public func searchSuggest(
        keywords: String,
        type: SearchSuggestType = .mobile
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "s": keywords,
        ]
        return try await request(
            "/api/search/suggest/\(type.rawValue)",
            data: data,
            crypto: .weapi
        )
    }

    /// 搜索默认词
    /// - Returns: API 响应，包含默认搜索关键词
    public func searchDefault() async throws -> APIResponse {
        return try await request(
            "/api/search/defaultkeyword/get",
            data: [:]
        )
    }

    /// 多类型搜索匹配
    /// - Parameter keywords: 搜索关键词
    /// - Returns: API 响应，包含多类型匹配结果
    public func searchMultimatch(keywords: String) async throws -> APIResponse {
        let data: [String: Any] = [
            "s": keywords,
            "type": 1,
        ]
        return try await request(
            "/api/search/suggest/multimatch",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 热门搜索（简版）
    /// - Returns: API 响应
    public func searchHot() async throws -> APIResponse {
        let data: [String: Any] = ["type": 1111]
        return try await request("/api/search/hot", data: data)
    }

    /// 本地歌曲匹配音乐信息
    /// - Parameters:
    ///   - title: 歌曲标题
    ///   - artist: 歌手名
    ///   - album: 专辑名
    ///   - duration: 时长（毫秒）
    ///   - md5: 文件 MD5
    /// - Returns: API 响应
    public func searchMatch(
        title: String = "",
        artist: String = "",
        album: String = "",
        duration: Int = 0,
        md5: String = ""
    ) async throws -> APIResponse {
        let songs = "[{\"title\":\"\(title)\",\"album\":\"\(album)\",\"artist\":\"\(artist)\",\"duration\":\(duration),\"persistId\":\"\(md5)\"}]"
        let data: [String: Any] = ["songs": songs]
        return try await request("/api/search/match/new", data: data)
    }
}
