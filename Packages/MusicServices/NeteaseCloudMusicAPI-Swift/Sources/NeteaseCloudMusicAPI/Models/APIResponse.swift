// APIResponse.swift
// API 响应模型
// 定义统一的 API 响应类型、加密模式枚举和请求选项

import Foundation

// MARK: - 加密模式

/// 加密模式枚举
/// 定义ncm API 支持的四种加密模式
public enum CryptoMode: String, Sendable {
    /// WeAPI 模式：使用 AES-CBC 双重加密 + RSA 加密密钥
    case weapi
    /// LinuxAPI 模式：使用 AES-ECB 加密的 Linux 客户端模式
    case linuxapi
    /// EAPI 模式：使用 AES-ECB 加密 + MD5 签名
    case eapi
    /// 明文模式：无加密，直接发送原始数据
    case api
}

// MARK: - 请求选项

/// 请求配置选项
/// 包含加密模式、User-Agent、真实 IP 和 EAPI 响应解密标志
public struct RequestOptions: Sendable {
    /// 加密模式
    var crypto: CryptoMode
    /// 自定义 User-Agent（可选，为 nil 时使用默认值）
    var ua: String?
    /// 真实 IP 地址（可选，用于设置 X-Real-IP 和 X-Forwarded-For 头）
    var realIP: String?
    /// EAPI 响应是否需要解密（可选，为 true 时解密响应体）
    var e_r: Bool?

    /// 初始化请求选项
    /// - Parameters:
    ///   - crypto: 加密模式，默认为 `.eapi`
    ///   - ua: 自定义 User-Agent
    ///   - realIP: 真实 IP 地址
    ///   - e_r: EAPI 响应解密标志
    public init(crypto: CryptoMode = .eapi, ua: String? = nil, realIP: String? = nil, e_r: Bool? = nil) {
        self.crypto = crypto
        self.ua = ua
        self.realIP = realIP
        self.e_r = e_r
    }
}

// MARK: - API 响应

/// 统一的 API 响应类型
/// 包含 HTTP 状态码、解码后的响应体和更新的 Cookie
// [String: Any] 不能自动满足 Sendable，但在我们的使用场景中
// 响应体在创建后不会被修改，因此标记为 @unchecked Sendable 是安全的
public struct APIResponse: @unchecked Sendable {
    /// HTTP 状态码（经过归一化处理）
    public let status: Int
    /// 解码后的响应体（JSON 字典）
    public let body: [String: Any]
    /// 响应中返回的 Set-Cookie 值列表
    public let cookies: [String]

    /// 初始化 API 响应
    /// - Parameters:
    ///   - status: HTTP 状态码
    ///   - body: 响应体字典
    ///   - cookies: Cookie 列表
    public init(status: Int, body: [String: Any], cookies: [String]) {
        self.status = status
        self.body = body
        self.cookies = cookies
    }
}
