// NCMClient+DJ.swift
// 电台相关 API 接口
// 电台详情、节目列表、排行榜、分类、推荐、收藏等

import Foundation

// MARK: - 电台 API

extension NCMClient {

    /// 获取电台详情
    /// - Parameter rid: 电台 ID
    /// - Returns: API 响应，包含电台详细信息
    public func djDetail(rid: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": rid,
        ]
        return try await request(
            "/api/djradio/v2/get",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取电台节目列表
    /// - Parameters:
    ///   - rid: 电台 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    ///   - asc: 是否正序排列，默认 false
    /// - Returns: API 响应，包含电台节目列表
    public func djProgram(
        rid: Int,
        limit: Int = 30,
        offset: Int = 0,
        asc: Bool = false
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "radioId": rid,
            "limit": limit,
            "offset": offset,
            "asc": asc,
        ]
        return try await request(
            "/api/dj/program/byradio",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取节目详情
    /// - Parameter id: 节目 ID
    /// - Returns: API 响应，包含节目详细信息
    public func djProgramDetail(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
        ]
        return try await request(
            "/api/dj/program/detail",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取电台排行榜
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含电台排行榜列表
    public func djToplist(
        limit: Int = 30,
        offset: Int = 0,
        type: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "type": type,
        ]
        return try await request(
            "/api/djradio/toplist",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取节目排行榜
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含节目排行榜列表
    public func djProgramToplist(
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/program/toplist/v1",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取电台分类列表
    /// - Returns: API 响应，包含电台分类列表
    public func djCatelist() async throws -> APIResponse {
        return try await request(
            "/api/djradio/category/get",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取电台推荐
    /// - Returns: API 响应，包含推荐电台列表
    public func djRecommend() async throws -> APIResponse {
        return try await request(
            "/api/djradio/recommend/v1",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取分类电台推荐
    /// - Parameter cateId: 分类 ID
    /// - Returns: API 响应，包含该分类下的推荐电台
    public func djRecommendType(cateId: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "cateId": cateId,
        ]
        return try await request(
            "/api/djradio/recommend",
            data: data,
            crypto: .weapi
        )
    }

    /// 收藏/取消收藏电台
    /// - Parameters:
    ///   - rid: 电台 ID
    ///   - action: 操作类型（`.sub` 收藏，`.unsub` 取消收藏）
    /// - Returns: API 响应
    public func djSub(
        rid: Int,
        action: SubAction
    ) async throws -> APIResponse {
        let actionStr = action == .sub ? "sub" : "unsub"
        let data: [String: Any] = [
            "id": rid,
        ]
        return try await request(
            "/api/djradio/\(actionStr)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取已收藏电台列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含已收藏电台列表
    public func djSublist(
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/djradio/get/subed",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取热门电台
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含热门电台列表
    public func djHot(
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/djradio/hot/v1",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取电台 Banner
    /// - Returns: API 响应
    public func djBanner() async throws -> APIResponse {
        return try await request("/api/djradio/banner/get", data: [:], crypto: .weapi)
    }

    /// 获取电台非热门分类
    /// - Returns: API 响应
    public func djCategoryExcludehot() async throws -> APIResponse {
        return try await request("/api/djradio/category/excludehot", data: [:], crypto: .weapi)
    }

    /// 获取电台推荐分类
    /// - Returns: API 响应
    public func djCategoryRecommend() async throws -> APIResponse {
        return try await request("/api/djradio/home/category/recommend", data: [:], crypto: .weapi)
    }

    /// 获取付费电台列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func djPaygift(limit: Int = 30, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "_nmclfl": 1,
        ]
        return try await request("/api/djradio/home/paygift/list", data: data, crypto: .weapi)
    }

    /// 获取电台个性推荐
    /// - Parameter limit: 数量限制，默认 6
    /// - Returns: API 响应
    public func djPersonalizeRecommend(limit: Int = 6, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/djradio/personalize/rcmd", data: data, crypto: .weapi)
    }

    /// 获取电台 24 小时节目榜
    /// - Parameter limit: 数量限制，默认 100
    /// - Returns: API 响应
    public func djProgramToplistHours(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/djprogram/toplist/hours", data: data, crypto: .weapi)
    }

    /// 获取分类热门电台
    /// - Parameters:
    ///   - cateId: 分类 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func djRadioHot(cateId: Int, limit: Int = 30, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "cateId": cateId,
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/djradio/hot", data: data, crypto: .weapi)
    }

    /// 获取电台订阅者列表
    /// - Parameters:
    ///   - id: 电台 ID
    ///   - limit: 每页数量，默认 20
    ///   - time: 分页时间戳，默认 "-1"
    /// - Returns: API 响应
    public func djSubscriber(id: Int, limit: Int = 20, offset: Int = 0, time: String = "-1") async throws -> APIResponse {
        let data: [String: Any] = [
            "time": time,
            "id": id,
            "limit": limit,
            "offset": offset,
            "total": "true",
        ]
        return try await request("/api/djradio/subscriber", data: data, crypto: .weapi)
    }

    /// 获取电台今日优选
    /// - Parameter page: 页码，默认 0
    /// - Returns: API 响应
    public func djTodayPerfered(page: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["page": page]
        return try await request("/api/djradio/home/today/perfered", data: data, crypto: .weapi)
    }

    /// 获取电台 24 小时主播榜
    /// - Parameter limit: 数量限制，默认 100
    /// - Returns: API 响应
    public func djToplistHours(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/dj/toplist/hours", data: data, crypto: .weapi)
    }

    /// 获取电台新人榜
    /// - Parameters:
    ///   - limit: 每页数量，默认 100
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func djToplistNewcomer(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/dj/toplist/newcomer", data: data, crypto: .weapi)
    }

    /// 获取付费精品电台榜
    /// - Parameter limit: 数量限制，默认 100
    /// - Returns: API 响应
    public func djToplistPay(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/djradio/toplist/pay", data: data, crypto: .weapi)
    }

    /// 获取电台最热主播榜
    /// - Parameter limit: 数量限制，默认 100
    /// - Returns: API 响应
    public func djToplistPopular(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/dj/toplist/popular", data: data, crypto: .weapi)
    }

    /// 获取电台排行榜数据
    /// - Parameters:
    ///   - djRadioId: 电台 ID（可选）
    ///   - sortIndex: 排序（1 播放数，2 点赞数，3 评论数，4 分享数，5 收藏数），默认 1
    ///   - dataGapDays: 天数（7 一周，30 一个月，90 三个月），默认 7
    ///   - dataType: 数据类型，默认 3
    /// - Returns: API 响应
    public func djRadioTop(
        djRadioId: Int? = nil,
        sortIndex: Int = 1,
        dataGapDays: Int = 7,
        dataType: Int = 3
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "sortIndex": sortIndex,
            "dataGapDays": dataGapDays,
            "dataType": dataType,
        ]
        if let djRadioId = djRadioId {
            data["djRadioId"] = djRadioId
        }
        return try await request("/api/expert/worksdata/works/top/get", data: data)
    }
}
