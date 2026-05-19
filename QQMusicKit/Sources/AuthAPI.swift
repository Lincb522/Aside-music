import Foundation

// MARK: - 认证相关 API

public extension QQMusicClient {

    /// 获取服务端登录状态
    ///
    /// ```swift
    /// let status = try await client.authStatus()
    /// if status.loggedIn {
    ///     print("已登录: \(status.musicid ?? 0)")
    /// }
    /// ```
    func authStatus() async throws -> AuthStatus {
        try await request("/auth/status")
    }

    /// 获取登录二维码
    /// - Parameter type: 登录类型（.qq 或 .wx）
    /// - Returns: 二维码信息，包含图片数据和轮询 ID
    func createQRCode(type: QRLoginType = .qq) async throws -> QRCode {
        try await request("/login/qrcode/create", params: ["type": type.rawValue])
    }

    /// 检查二维码扫码状态
    /// - Parameter qrId: 二维码 ID（从 createQRCode 获取）
    func checkQRCode(qrId: String) async throws -> QRCodeStatus {
        try await request("/login/qrcode/check", params: ["qr_id": qrId])
    }

    /// 轮询二维码状态直到终态
    ///
    /// 自动轮询直到登录成功、过期或被拒绝。
    ///
    /// ```swift
    /// let qr = try await client.createQRCode(type: .qq)
    /// // 显示 qr.imageData 给用户
    /// let result = try await client.pollQRCode(qrId: qr.qrId) { status in
    ///     print("当前状态: \(status.status)")
    /// }
    /// if result.isDone { print("登录成功") }
    /// ```
    ///
    /// - Parameters:
    ///   - qrId: 二维码 ID
    ///   - interval: 轮询间隔（秒），默认 3 秒
    ///   - timeout: 超时时间（秒），默认 300 秒
    ///   - onStatusChange: 状态变化回调
    /// - Returns: 最终状态
    func pollQRCode(
        qrId: String,
        interval: TimeInterval = 3,
        timeout: TimeInterval = 300,
        onStatusChange: (@Sendable (QRCodeStatus) -> Void)? = nil
    ) async throws -> QRCodeStatus {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let status = try await checkQRCode(qrId: qrId)
            onStatusChange?(status)

            if status.isFinal {
                return status
            }

            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        return QRCodeStatus(status: "TIMEOUT", musicid: nil, musickey: nil, account: nil, nickname: nil, avatar: nil, is_vip: nil, is_svip: nil, euin: nil, loginType: nil)
    }

    /// 发送手机验证码
    /// - Parameters:
    ///   - phone: 手机号
    ///   - countryCode: 国家码，默认 86
    func sendPhoneCode(phone: Int, countryCode: Int = 86) async throws -> PhoneSendStatus {
        try await request("/login/phone/send", params: [
            "phone": String(phone),
            "country_code": String(countryCode),
        ])
    }

    /// 手机验证码登录
    /// - Parameters:
    ///   - phone: 手机号
    ///   - code: 验证码
    ///   - countryCode: 国家码，默认 86
    func phoneLogin(phone: Int, code: Int, countryCode: Int = 86) async throws -> JSON {
        try await request("/login/phone/verify", params: [
            "phone": String(phone),
            "code": String(code),
            "country_code": String(countryCode),
        ])
    }

    /// 退出登录（清除服务端凭证）
    @discardableResult
    func logout() async throws -> APIResponse<JSON> {
        try await requestRaw("/login/logout")
    }
}
