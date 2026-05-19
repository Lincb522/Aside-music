// NCMClient+User.swift
// 用户相关 API 接口
// 用户详情、歌单、听歌记录、关注等

import Foundation

// MARK: - 用户 API

extension NCMClient {

    /// 获取用户详情
    /// - Parameter uid: 用户 ID
    /// - Returns: API 响应，包含用户详细信息
    public func userDetail(uid: Int) async throws -> APIResponse {
        return try await request(
            "/api/v1/user/detail/\(uid)",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取用户歌单
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含用户歌单列表
    public func userPlaylist(
        uid: Int,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "uid": uid,
            "limit": limit,
            "offset": offset,
            "includeVideo": true,
        ]
        return try await request(
            "/api/user/playlist",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取用户听歌记录
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - type: 记录类型，默认为 `.all`（所有时间）
    /// - Returns: API 响应，包含听歌记录
    public func userRecord(
        uid: Int,
        type: UserRecordType = .all
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "uid": uid,
            "type": type.rawValue,
        ]
        return try await request(
            "/api/v1/play/record",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取用户关注列表
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含关注用户列表
    public func userFollows(
        uid: Int,
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "offset": offset,
            "limit": limit,
            "order": true,
        ]
        return try await request(
            "/api/user/getfollows/\(uid)",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取用户粉丝列表
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    ///   - lasttime: 上一页最后一条数据的时间戳，默认 -1
    /// - Returns: API 响应，包含粉丝用户列表
    public func userFolloweds(
        uid: Int,
        limit: Int = 30,
        offset: Int = 0,
        lasttime: Int = -1
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "userId": uid,
            "time": "\(lasttime)",
            "limit": limit,
            "offset": offset,
            "getcounts": "true",
        ]
        return try await request(
            "/api/user/getfolloweds/\(uid)",
            data: data,
            crypto: .eapi
        )
    }

    /// 获取用户等级信息
    /// - Returns: API 响应，包含用户等级详情
    public func userLevel() async throws -> APIResponse {
        return try await request(
            "/api/user/level",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取用户订阅数量
    /// - Returns: API 响应，包含各类订阅计数
    public func userSubcount() async throws -> APIResponse {
        return try await request(
            "/api/subcount",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取用户账号信息
    /// - Returns: API 响应，包含账号详细信息
    public func userAccount() async throws -> APIResponse {
        return try await request(
            "/api/nuser/account/get",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取用户绑定信息
    /// - Parameter uid: 用户 ID
    /// - Returns: API 响应，包含绑定的第三方账号信息
    public func userBinding(uid: Int) async throws -> APIResponse {
        return try await request(
            "/api/v1/user/bindings/\(uid)",
            data: [:],
            crypto: .weapi
        )
    }

    /// 关注/取关用户
    /// - Parameters:
    ///   - id: 目标用户 ID
    ///   - action: 操作类型（`.sub` 关注，`.unsub` 取关）
    /// - Returns: API 响应
    public func follow(
        id: Int,
        action: SubAction
    ) async throws -> APIResponse {
        let actionStr = action == .sub ? "follow" : "delfollow"
        return try await request(
            "/api/user/\(actionStr)/\(id)",
            data: [:],
            crypto: .weapi
        )
    }

    /// 更新用户信息
    /// - Parameters:
    ///   - nickname: 昵称
    ///   - signature: 个性签名
    ///   - gender: 性别（0 保密，1 男，2 女）
    ///   - birthday: 生日时间戳
    ///   - province: 省份编码
    ///   - city: 城市编码
    /// - Returns: API 响应
    public func userUpdate(
        nickname: String,
        signature: String,
        gender: Int,
        birthday: Int,
        province: Int,
        city: Int
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "nickname": nickname,
            "signature": signature,
            "gender": gender,
            "birthday": birthday,
            "province": province,
            "city": city,
        ]
        return try await request(
            "/api/user/profile/update",
            data: data
        )
    }

    // MARK: - 以下为补充接口

    /// 获取用户创建的电台
    /// - Parameter uid: 用户 ID
    /// - Returns: API 响应
    public func userAudio(uid: Int) async throws -> APIResponse {
        let data: [String: Any] = ["userId": uid]
        return try await request("/api/djradio/get/byuser", data: data, crypto: .weapi)
    }

    /// 绑定手机号
    /// - Parameters:
    ///   - phone: 手机号
    ///   - captcha: 验证码
    ///   - countrycode: 国家码，默认 "86"
    ///   - password: 密码（可选）
    /// - Returns: API 响应
    public func userBindingCellphone(
        phone: String,
        captcha: String,
        countrycode: String = "86",
        password: String = ""
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "phone": phone,
            "countrycode": countrycode,
            "captcha": captcha,
            "password": password.isEmpty ? "" : CryptoEngine.md5(password),
        ]
        return try await request("/api/user/bindingCellphone", data: data, crypto: .weapi)
    }

    /// 获取用户评论历史
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - limit: 每页数量，默认 10
    ///   - time: 分页时间戳，默认 0
    /// - Returns: API 响应
    public func userCommentHistory(uid: Int, limit: Int = 10, offset: Int = 0, time: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "compose_reminder": "true",
            "compose_hot_comment": "true",
            "limit": limit,
            "offset": offset,
            "user_id": uid,
            "time": time,
        ]
        return try await request("/api/comment/user/comment/history", data: data, crypto: .weapi)
    }

    /// 获取用户详情（新版）
    /// - Parameter uid: 用户 ID
    /// - Returns: API 响应
    public func userDetailNew(uid: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "all": "true",
            "userId": uid,
        ]
        return try await request("/api/w/v1/user/detail/\(uid)", data: data, crypto: .eapi)
    }

    /// 获取用户电台节目
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应
    public func userDj(uid: Int, limit: Int = 30, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/dj/program/\(uid)", data: data, crypto: .weapi)
    }

    /// 获取用户动态
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - lasttime: 上一页最后一条动态的时间戳，默认 -1
    ///   - limit: 每页数量，默认 30
    /// - Returns: API 响应
    public func userEvent(uid: Int, lasttime: Int = -1, limit: Int = 30, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "getcounts": true,
            "time": lasttime,
            "limit": limit,
            "offset": offset,
            "total": false,
        ]
        return try await request("/api/event/get/\(uid)", data: data)
    }

    /// 获取当前账号关注的用户/歌手（混合）
    /// - Parameters:
    ///   - size: 每页数量，默认 30
    ///   - cursor: 分页游标，默认 0
    ///   - scene: 场景（0 所有关注，1 关注的歌手，2 关注的用户），默认 0
    /// - Returns: API 响应
    public func userFollowMixed(size: Int = 30, cursor: Int = 0, scene: Int = 0) async throws -> APIResponse {
        let pageJson = "{\"size\":\(size),\"cursor\":\(cursor)}"
        let data: [String: Any] = [
            "authority": "false",
            "page": pageJson,
            "scene": scene,
            "size": size,
            "sortType": "0",
        ]
        return try await request("/api/user/follow/users/mixed/get/v2", data: data)
    }

    /// 获取用户徽章
    /// - Parameter uid: 用户 ID
    /// - Returns: API 响应
    public func userMedal(uid: Int) async throws -> APIResponse {
        let data: [String: Any] = ["uid": uid]
        return try await request("/api/medal/user/page", data: data)
    }

    /// 检查用户是否互相关注
    /// - Parameter uid: 目标用户 ID
    /// - Returns: API 响应
    public func userMutualfollowGet(uid: Int) async throws -> APIResponse {
        let data: [String: Any] = ["friendid": uid]
        return try await request("/api/user/mutualfollow/get", data: data)
    }

    /// 更换手机号
    /// - Parameters:
    ///   - phone: 新手机号
    ///   - captcha: 新手机验证码
    ///   - oldcaptcha: 旧手机验证码
    ///   - ctcode: 国家码，默认 "86"（兼容 rebind.js 的 ctcode 参数名）
    ///   - countrycode: 国家码，默认 "86"（兼容 user_replacephone.js 的 countrycode 参数名）
    /// - Returns: API 响应
    /// - Note: Node.js 源码中 rebind.js 使用 ctcode，user_replacephone.js 使用 countrycode，两者均有效
    public func userReplacephone(
        phone: String,
        captcha: String,
        oldcaptcha: String,
        countrycode: String = "86"
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "phone": phone,
            "captcha": captcha,
            "oldcaptcha": oldcaptcha,
            "ctcode": countrycode,
            "countrycode": countrycode,
        ]
        return try await request("/api/user/replaceCellphone", data: data, crypto: .weapi)
    }

    /// 获取用户社交状态
    /// - Parameter uid: 用户 ID
    /// - Returns: API 响应
    public func userSocialStatus(uid: Int) async throws -> APIResponse {
        let data: [String: Any] = ["visitorId": uid]
        return try await request("/api/social/user/status", data: data)
    }

    /// 编辑用户社交状态
    /// - Parameters:
    ///   - type: 状态类型
    ///   - iconUrl: 图标 URL
    ///   - content: 状态内容
    ///   - actionUrl: 跳转 URL
    /// - Returns: API 响应
    public func userSocialStatusEdit(
        type: Int,
        iconUrl: String = "",
        content: String = "",
        actionUrl: String = ""
    ) async throws -> APIResponse {
        let contentJson = "{\"type\":\(type),\"iconUrl\":\"\(iconUrl)\",\"content\":\"\(content)\",\"actionUrl\":\"\(actionUrl)\"}"
        let data: [String: Any] = ["content": contentJson]
        return try await request("/api/social/user/status/edit", data: data)
    }

    /// 获取相同社交状态的用户推荐
    /// - Returns: API 响应
    public func userSocialStatusRcmd() async throws -> APIResponse {
        return try await request("/api/social/user/status/rcmd", data: [:])
    }

    /// 获取支持设置的社交状态列表
    /// - Returns: API 响应
    public func userSocialStatusSupport() async throws -> APIResponse {
        return try await request("/api/social/user/status/support", data: [:])
    }
}
