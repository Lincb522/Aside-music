import Foundation
#if canImport(os)
import os
#endif

/// qcm API 客户端
///
/// 所有 API 请求的入口，支持配置服务器地址、超时时间、重试策略。
///
/// 基本用法：
/// ```swift
/// QQMusicClient.configure(baseURL: URL(string: "http://你的IP:8000")!)
/// let songs = try await QQMusicClient.shared.search(keyword: "周杰伦")
/// ```
public final class QQMusicClient: @unchecked Sendable {

    // MARK: - 属性

    /// 服务器地址
    public let baseURL: URL

    /// API 访问令牌
    public var apiToken: String?

    /// 用户 musicId（传递给服务端用于身份识别）
    public var musicId: Int?

    /// 用户 musicKey（传递给服务端用于鉴权）
    public var musicKey: String?

    /// 用户 encrypt_uin（传递给服务端用于查询用户资料）
    public var encryptUin: String?

    /// 登录类型（1=微信, 2=QQ）
    public var loginType: Int?

    /// 请求超时时间（秒）
    public let timeout: TimeInterval

    /// 最大重试次数
    public let maxRetries: Int

    /// URLSession
    private let session: URLSession

    #if canImport(os)
    /// 日志
    private static let logger = Logger(subsystem: "QQMusicKit", category: "Network")
    #endif

    // MARK: - 单例

    /// 共享实例（需先调用 configure 设置服务器地址）
    public static var shared = QQMusicClient(baseURL: URL(string: "http://localhost:8000")!)

    /// 配置共享实例
    /// - Parameters:
    ///   - baseURL: 服务器地址
    ///   - timeout: 请求超时时间，默认 30 秒
    ///   - maxRetries: 最大重试次数，默认 1
    public static func configure(
        baseURL: URL,
        timeout: TimeInterval = 30,
        maxRetries: Int = 1
    ) {
        shared = QQMusicClient(baseURL: baseURL, timeout: timeout, maxRetries: maxRetries)
    }

    // MARK: - 初始化

    /// 创建客户端实例
    /// - Parameters:
    ///   - baseURL: 服务器地址
    ///   - timeout: 请求超时时间
    ///   - maxRetries: 最大重试次数
    ///   - session: 自定义 URLSession
    public init(
        baseURL: URL,
        timeout: TimeInterval = 30,
        maxRetries: Int = 1,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout * 2
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - 网络请求

    /// 发送 GET 请求并解码响应（用于专用路由，如 /auth/*, /login/*, /song/qualities）
    /// - Parameters:
    ///   - path: 请求路径
    ///   - params: 查询参数
    /// - Returns: 解码后的数据
    func request<T: Decodable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        let data = try await rawRequest(path, params: params)
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)

        guard response.code == 200 else {
            throw QQMusicError.apiError(
                code: response.code,
                message: response.message,
                errors: response.errors
            )
        }

        guard let result = response.data else {
            throw QQMusicError.emptyData
        }

        return result
    }

    /// 发送 GET 请求并解码通用路由响应（/{module}/{func} 返回 {"result": T, "source": "..."}）
    public func requestWrapped<T: Decodable>(_ path: String, params: [String: String] = [:]) async throws -> T {
        let data = try await rawRequest(path, params: params)
        let response = try JSONDecoder().decode(APIResponse<WrappedData<T>>.self, from: data)

        guard response.code == 200 else {
            throw QQMusicError.apiError(
                code: response.code,
                message: response.message,
                errors: response.errors
            )
        }

        guard let wrapped = response.data else {
            throw QQMusicError.emptyData
        }

        return wrapped.result
    }

    /// 调用通用模块路由，并自动将数组或对象参数编码为 JSON 查询参数。
    ///
    /// 此入口用于已升级服务端中尚未提供专用 Swift 方法的接口。`parameters`
    /// 支持字符串、数字、布尔值、数组及 JSON 对象。
    public func requestWrapped<T: Decodable>(
        _ path: String,
        parameters: [String: Any]
    ) async throws -> T {
        try await requestWrapped(path, params: try serializeParameters(parameters))
    }

    /// 调用任意 QQMusicApi 模块方法。
    ///
    /// 例如：`try await client.module("private_message", function: "get_sessions", parameters: [:])`。
    public func module<T: Decodable>(
        _ module: String,
        function: String,
        parameters: [String: Any] = [:]
    ) async throws -> T {
        try await requestWrapped("/\(module)/\(function)", parameters: parameters)
    }

    /// 发送 GET 请求，返回原始 APIResponse
    func requestRaw(_ path: String, params: [String: String] = [:]) async throws -> APIResponse<JSON> {
        let data = try await rawRequest(path, params: params)
        return try JSONDecoder().decode(APIResponse<JSON>.self, from: data)
    }

    /// 发送 GET 请求，解码通用路由响应并返回原始 APIResponse（含 source）
    func requestRawWrapped(_ path: String, params: [String: String] = [:]) async throws -> APIResponse<WrappedData<JSON>> {
        let data = try await rawRequest(path, params: params)
        return try JSONDecoder().decode(APIResponse<WrappedData<JSON>>.self, from: data)
    }

    /// 底层请求方法（带重试）
    private func rawRequest(_ path: String, params: [String: String]) async throws -> Data {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw QQMusicError.invalidURL(path)
        }

        var allParams = params
        if let token = apiToken, !token.isEmpty {
            allParams["token"] = token
        }
        if let mid = musicId {
            allParams["_musicid"] = String(mid)
        }
        if let mkey = musicKey, !mkey.isEmpty {
            allParams["_musickey"] = mkey
        }
        if let euin = encryptUin, !euin.isEmpty {
            allParams["_euin"] = euin
        }
        if let lt = loginType {
            allParams["_login_type"] = String(lt)
        }
        if !allParams.isEmpty {
            components.queryItems = allParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw QQMusicError.invalidURL(path)
        }

        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                #if canImport(os)
                if attempt > 0 {
                    Self.logger.info("重试请求 (\(attempt)/\(self.maxRetries)): \(path)")
                }
                #endif

                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw QQMusicError.invalidResponse
                }

                #if canImport(os)
                Self.logger.debug("\(httpResponse.statusCode) \(path)")
                #endif

                return data

            } catch {
                lastError = error

                // 不重试客户端错误
                if let musicError = error as? QQMusicError {
                    throw musicError
                }

                // 最后一次不等待
                if attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? QQMusicError.invalidResponse
    }

    private func serializeParameters(_ parameters: [String: Any]) throws -> [String: String] {
        try parameters.reduce(into: [:]) { result, item in
            let (name, value) = item
            switch value {
            case let value as String:
                result[name] = value
            case let value as Int:
                result[name] = String(value)
            case let value as Int64:
                result[name] = String(value)
            case let value as Double:
                result[name] = String(value)
            case let value as Float:
                result[name] = String(value)
            case let value as Bool:
                result[name] = String(value)
            case let value as NSNumber:
                result[name] = value.stringValue
            default:
                guard JSONSerialization.isValidJSONObject(value),
                      let data = try? JSONSerialization.data(withJSONObject: value),
                      let encoded = String(data: data, encoding: .utf8)
                else {
                    throw QQMusicError.invalidParameter(name: name)
                }
                result[name] = encoded
            }
        }
    }
}
