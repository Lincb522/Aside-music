// NCMClient+Auth.swift
// 认证相关 API 接口
// 登录、登出、验证码、注册、二维码登录等

import Foundation

// MARK: - 认证 API

extension NCMClient {

    /// 手机号登录
    /// - Parameters:
    ///   - phone: 手机号
    ///   - password: 密码（明文，内部会进行 MD5 加密），验证码登录时可为空
    ///   - countrycode: 国家码，默认为 "86"（中国大陆）
    ///   - captcha: 验证码（可选），传入时使用验证码登录替代密码登录
    /// - Returns: API 响应，包含用户信息和认证 Cookie
    public func loginCellphone(
        phone: String,
        password: String = "",
        countrycode: String = "86",
        captcha: String? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "type": "1",
            "https": "true",
            "phone": phone,
            "countrycode": countrycode,
            "remember": "true",
        ]
        // 支持验证码登录：captcha 不为 nil 时用验证码替代密码
        if let captcha = captcha {
            data["captcha"] = captcha
        } else {
            data["password"] = CryptoEngine.md5(password)
        }
        return try await request(
            "/api/w/login/cellphone",
            data: data,
            crypto: .weapi
        )
    }

    /// 邮箱登录
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - password: 密码（明文，内部会进行 MD5 加密）
    /// - Returns: API 响应，包含用户信息和认证 Cookie
    public func loginEmail(
        email: String,
        password: String
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "type": "0",
            "https": "true",
            "username": email,
            "password": CryptoEngine.md5(password),
            "rememberLogin": "true",
        ]
        return try await request(
            "/api/w/login",
            data: data
        )
    }

    /// 登出
    /// - Returns: API 响应
    public func logout() async throws -> APIResponse {
        return try await request(
            "/api/logout",
            data: [:]
        )
    }

    /// 发送验证码
    /// - Parameters:
    ///   - phone: 手机号
    ///   - ctcode: 国家码，默认为 "86"
    /// - Returns: API 响应
    public func captchaSent(
        phone: String,
        ctcode: String = "86"
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "ctcode": ctcode,
            "secrete": "music_middleuser_pclogin",
            "cellphone": phone,
        ]
        return try await request(
            "/api/sms/captcha/sent",
            data: data,
            crypto: .weapi
        )
    }

    /// 验证验证码
    /// - Parameters:
    ///   - phone: 手机号
    ///   - captcha: 验证码
    ///   - ctcode: 国家码，默认为 "86"
    /// - Returns: API 响应
    public func captchaVerify(
        phone: String,
        captcha: String,
        ctcode: String = "86"
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "ctcode": ctcode,
            "cellphone": phone,
            "captcha": captcha,
        ]
        return try await request(
            "/api/sms/captcha/verify",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取二维码登录 Key
    /// - Returns: API 响应，包含二维码 unikey
    public func loginQrKey() async throws -> APIResponse {
        let data: [String: Any] = [
            "type": 3,
        ]
        return try await request(
            "/api/login/qrcode/unikey",
            data: data
        )
    }

    /// 创建二维码
    /// - Parameters:
    ///   - key: 二维码 key（由 loginQrKey 获取）
    ///   - qrimg: 是否生成二维码图片，默认为 true
    /// - Returns: API 响应，包含二维码 URL
    public func loginQrCreate(
        key: String,
        qrimg: Bool = true
    ) async throws -> APIResponse {
        // 二维码创建是客户端本地操作，构建 URL 并返回
        let url = "https://music.163.com/login?codekey=\(key)"
        let body: [String: Any] = [
            "code": 200,
            "data": [
                "qrurl": url,
            ] as [String: Any],
        ]
        return APIResponse(status: 200, body: body, cookies: [])
    }

    /// 检查二维码扫描状态
    /// - Parameter key: 二维码 key
    /// - Returns: API 响应，包含扫描状态
    public func loginQrCheck(key: String) async throws -> APIResponse {
        let data: [String: Any] = [
            "key": key,
            "type": 3,
        ]
        return try await request(
            "/api/login/qrcode/client/login",
            data: data
        )
    }

    /// 获取登录状态
    /// - Returns: API 响应，包含当前登录用户信息
    public func loginStatus() async throws -> APIResponse {
        return try await request(
            "/api/w/nuser/account/get",
            data: [:],
            crypto: .weapi
        )
    }

    /// 刷新登录状态
    /// - Returns: API 响应
    public func loginRefresh() async throws -> APIResponse {
        return try await request(
            "/api/login/token/refresh",
            data: [:]
        )
    }

    /// 手机号注册
    /// - Parameters:
    ///   - phone: 手机号
    ///   - password: 密码（明文，内部会进行 MD5 加密）
    ///   - captcha: 验证码
    ///   - nickname: 昵称
    ///   - countrycode: 国家码，默认为 "86"
    /// - Returns: API 响应
    public func registerCellphone(
        phone: String,
        password: String,
        captcha: String,
        nickname: String,
        countrycode: String = "86"
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "captcha": captcha,
            "phone": phone,
            "password": CryptoEngine.md5(password),
            "nickname": nickname,
            "countrycode": countrycode,
            "force": "false",
        ]
        return try await request(
            "/api/w/register/cellphone",
            data: data
        )
    }
}
