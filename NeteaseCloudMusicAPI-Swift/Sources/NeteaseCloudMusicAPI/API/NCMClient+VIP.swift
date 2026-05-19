// NCMClient+VIP.swift
// VIP 相关 API 接口
// VIP 信息、签到、云贝信息/签到/任务、成长值等

import Foundation

// MARK: - VIP 和云贝 API

extension NCMClient {

    /// 获取 VIP 信息
    /// - Parameter userId: 用户 ID，默认为空字符串（获取当前用户）
    /// - Returns: API 响应，包含 VIP 信息
    public func vipInfo(userId: String = "") async throws -> APIResponse {
        return try await request(
            "/api/music-vip-membership/front/vip/info",
            data: ["userId": userId],
            crypto: .weapi
        )
    }

    /// 获取 VIP 信息（v2 版本）
    /// - Parameter userId: 用户 ID，默认为空字符串（获取当前用户）
    /// - Returns: API 响应，包含 VIP 信息
    public func vipInfoV2(userId: String = "") async throws -> APIResponse {
        return try await request(
            "/api/music-vip-membership/client/vip/info",
            data: ["userId": userId],
            crypto: .weapi
        )
    }

    /// VIP 签到
    /// - Returns: API 响应
    public func vipSign() async throws -> APIResponse {
        return try await request(
            "/api/vip-center-bff/task/sign",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取云贝信息
    /// - Returns: API 响应，包含云贝余额等信息
    public func yunbeiInfo() async throws -> APIResponse {
        return try await request(
            "/api/v1/user/info",
            data: [:],
            crypto: .weapi
        )
    }

    /// 云贝签到
    /// - Returns: API 响应
    public func yunbeiSign() async throws -> APIResponse {
        return try await request(
            "/api/pointmall/user/sign",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取云贝任务列表
    /// - Returns: API 响应，包含云贝任务列表
    public func yunbeiTasks() async throws -> APIResponse {
        return try await request(
            "/api/usertool/task/list/all",
            data: [:],
            crypto: .weapi
        )
    }

    /// 完成云贝任务
    /// - Parameters:
    ///   - userTaskId: 用户任务 ID
    ///   - depositCode: 存款码，默认 0
    /// - Returns: API 响应
    public func yunbeiTaskFinish(
        userTaskId: Int,
        depositCode: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "userTaskId": userTaskId,
            "depositCode": depositCode,
        ]
        return try await request(
            "/api/usertool/task/point/receive",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取 VIP 成长值
    /// - Returns: API 响应，包含 VIP 成长值信息
    public func vipGrowthpoint() async throws -> APIResponse {
        return try await request(
            "/api/vipnewcenter/app/level/growhpoint/basic",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取 VIP 成长值详情
    /// - Parameters:
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含 VIP 成长值详情列表
    public func vipGrowthpointDetails(
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/vipnewcenter/app/level/growth/details",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 领取 VIP 成长值
    /// - Parameter ids: 任务 ID 字符串
    /// - Returns: API 响应
    public func vipGrowthpointGet(ids: String) async throws -> APIResponse {
        let data: [String: Any] = ["taskIds": ids]
        return try await request("/api/vipnewcenter/app/level/task/reward/get", data: data, crypto: .weapi)
    }

    /// 获取黑胶乐签签到信息
    /// - Returns: API 响应
    public func vipSignInfo() async throws -> APIResponse {
        return try await request("/api/vipnewcenter/app/user/sign/info", data: [:], crypto: .weapi)
    }

    /// 获取会员任务列表
    /// - Returns: API 响应
    public func vipTasks() async throws -> APIResponse {
        return try await request("/api/vipnewcenter/app/level/task/list", data: [:], crypto: .weapi)
    }

    /// 获取黑胶时光机
    /// - Parameters:
    ///   - startTime: 开始时间戳（可选）
    ///   - endTime: 结束时间戳（可选）
    ///   - limit: 每页数量，默认 60
    /// - Returns: API 响应
    public func vipTimemachine(startTime: Int? = nil, endTime: Int? = nil, limit: Int = 60, offset: Int = 0) async throws -> APIResponse {
        var data: [String: Any] = [:]
        if let startTime = startTime, let endTime = endTime {
            data["startTime"] = startTime
            data["endTime"] = endTime
            data["type"] = 1
            data["limit"] = limit
            data["offset"] = offset
        }
        return try await request("/api/vipmusic/newrecord/weekflow", data: data, crypto: .weapi)
    }

    /// 获取云贝数量（同 yunbeiInfo）
    /// - Returns: API 响应
    public func yunbei() async throws -> APIResponse {
        return try await request("/api/point/signed/get", data: [:], crypto: .weapi)
    }

    /// 获取云贝支出记录
    /// - Parameters:
    ///   - limit: 每页数量，默认 10
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func yunbeiExpense(limit: Int = 10, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/point/expense", data: data)
    }

    /// 云贝推歌
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - reason: 推荐理由，默认 "好歌献给你"
    ///   - yunbeiNum: 云贝数量，默认 10
    /// - Returns: API 响应
    public func yunbeiRcmdSong(id: Int, reason: String = "好歌献给你", yunbeiNum: Int = 10) async throws -> APIResponse {
        let data: [String: Any] = [
            "songId": id,
            "reason": reason,
            "scene": "",
            "fromUserId": -1,
            "yunbeiNum": yunbeiNum,
        ]
        return try await request("/api/yunbei/rcmd/song/submit", data: data, crypto: .weapi)
    }

    /// 获取云贝推歌历史记录
    /// - Parameters:
    ///   - size: 每页数量，默认 20
    ///   - cursor: 分页游标，默认空字符串
    /// - Returns: API 响应
    public func yunbeiRcmdSongHistory(size: Int = 20, cursor: String = "") async throws -> APIResponse {
        let pageJson = "{\"size\":\(size),\"cursor\":\"\(cursor)\"}"
        let data: [String: Any] = ["page": pageJson]
        return try await request("/api/yunbei/rcmd/song/history/list", data: data, crypto: .weapi)
    }

    /// 获取云贝收入记录
    /// - Parameters:
    ///   - limit: 每页数量，默认 10
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func yunbeiReceipt(limit: Int = 10, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/point/receipt", data: data)
    }

    /// 获取云贝待办任务
    /// - Returns: API 响应
    public func yunbeiTasksTodo() async throws -> APIResponse {
        return try await request("/api/usertool/task/todo/query", data: [:], crypto: .weapi)
    }

    /// 获取今日云贝信息
    /// - Returns: API 响应
    public func yunbeiToday() async throws -> APIResponse {
        return try await request("/api/point/today/get", data: [:], crypto: .weapi)
    }
}
