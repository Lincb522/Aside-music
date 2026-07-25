// NCMClient+Album.swift
// 专辑相关 API 接口
// 专辑详情、收藏、列表、数字专辑等

import Foundation

// MARK: - 专辑 API

extension NCMClient {

    /// 获取专辑详情
    /// - Parameter id: 专辑 ID
    /// - Returns: API 响应，包含专辑信息和歌曲列表
    public func album(id: Int) async throws -> APIResponse {
        return try await request(
            "/api/v1/album/\(id)",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取专辑动态信息（评论数、分享数、是否收藏等）
    /// - Parameter id: 专辑 ID
    /// - Returns: API 响应，包含专辑动态信息
    public func albumDetailDynamic(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/album/detail/dynamic",
            data: data,
            crypto: .weapi
        )
    }

    /// 收藏/取消收藏专辑
    /// - Parameters:
    ///   - id: 专辑 ID
    ///   - action: 操作类型（`.sub` 收藏，`.unsub` 取消收藏）
    /// - Returns: API 响应
    public func albumSub(
        id: Int,
        action: SubAction
    ) async throws -> APIResponse {
        let actionStr = action == .sub ? "sub" : "unsub"
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/album/\(actionStr)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取已收藏专辑列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 25
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含已收藏专辑列表
    public func albumSublist(
        limit: Int = 25,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/album/sublist",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取新碟列表
    /// - Parameters:
    ///   - area: 区域，默认 `.all`
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含新碟列表
    public func albumNew(
        area: AlbumListArea = .all,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
            "area": area.rawValue,
        ]
        return try await request(
            "/api/album/new",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取最新专辑
    /// - Returns: API 响应，包含最新专辑列表
    public func albumNewest() async throws -> APIResponse {
        return try await request(
            "/api/discovery/newAlbum",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取专辑详情（数字专辑）
    /// - Parameter id: 专辑 ID
    /// - Returns: API 响应，包含数字专辑详细信息
    public func albumDetail(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/vipmall/albumproduct/detail",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取已购数字专辑列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含已购数字专辑列表
    public func digitalAlbumPurchased(
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/digitalAlbum/purchased",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取数字专辑新碟上架列表
    /// - Parameters:
    ///   - area: 区域，默认 "ALL"
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    ///   - type: 类型（可选）
    /// - Returns: API 响应
    public func albumList(
        area: String = "ALL",
        limit: Int = 30,
        offset: Int = 0,
        type: String? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
            "area": area,
        ]
        if let type = type { data["type"] = type }
        return try await request("/api/vipmall/albumproduct/list", data: data, crypto: .weapi)
    }

    /// 获取数字专辑语种风格馆
    /// - Parameters:
    ///   - area: 区域，默认 `.zh`
    ///   - limit: 每页数量，默认 10
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func albumListStyle(
        area: AlbumListStyleArea = .zh,
        limit: Int = 10,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
            "area": area.rawValue,
        ]
        return try await request("/api/vipmall/appalbum/album/style", data: data, crypto: .weapi)
    }

    /// 获取专辑歌曲音质信息
    /// - Parameter id: 专辑 ID
    /// - Returns: API 响应
    public func albumPrivilege(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["id": id]
        return try await request("/api/album/privilege", data: data)
    }

    /// 获取数字专辑/单曲销量榜
    /// - Parameters:
    ///   - albumType: 专辑类型（0 数字专辑，1 数字单曲），默认 0
    ///   - type: 榜单类型（daily/week/year/total），默认 "daily"
    ///   - year: 年份（type 为 year 时需要）
    /// - Returns: API 响应
    /// - Parameters:
    ///   - albumType: 专辑类型（0 数字专辑，1 数字单曲），默认 0
    ///   - type: 榜单类型（daily/week/year/total），默认 "daily"
    ///   - year: 年份（type 为 year 时需要）
    public func albumSongsaleboard(
        albumType: Int = 0,
        type: String = "daily",
        year: Int? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = ["albumType": albumType]
        if let year = year { data["year"] = year }
        return try await request("/api/feealbum/songsaleboard/\(type)/type", data: data, crypto: .weapi)
    }

    /// 购买数字专辑
    /// - Parameters:
    ///   - id: 专辑 ID
    ///   - payment: 支付方式
    ///   - quantity: 购买数量，默认 1
    /// - Returns: API 响应
    public func digitalAlbumOrdering(id: Int, payment: Int, quantity: Int = 1) async throws -> APIResponse {
        let digitalResources = "[{\"business\":\"Album\",\"resourceID\":\(id),\"quantity\":\(quantity)}]"
        let data: [String: Any] = [
            "business": "Album",
            "paymentMethod": payment,
            "digitalResources": digitalResources,
            "from": "web",
        ]
        return try await request("/api/ordering/web/digital", data: data, crypto: .weapi)
    }

    /// 获取数字专辑销量
    /// - Parameter ids: 专辑 ID 字符串（逗号分隔）
    /// - Returns: API 响应
    public func digitalAlbumSales(ids: String) async throws -> APIResponse {
        let data: [String: Any] = ["albumIds": ids]
        return try await request("/api/vipmall/albumproduct/album/query/sales", data: data, crypto: .weapi)
    }
}
