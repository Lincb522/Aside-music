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
/// 可变配置与凭证均由锁保护；每个请求使用一次性状态快照。
public final class QQMusicClient: @unchecked Sendable {

    public struct ConfigurationSnapshot: Sendable {
        public let baseURL: URL
        public let timeout: TimeInterval
        public let maxRetries: Int
        public let apiToken: String?
    }

    private struct MutableValues: Sendable {
        var apiToken: String?
        var musicId: Int?
        var musicKey: String?
        var encryptUin: String?
        var loginType: Int?
    }

    private final class MutableState: @unchecked Sendable {
        private let lock = NSLock()
        private var values: MutableValues

        init(values: MutableValues) {
            self.values = values
        }

        func read<Value>(_ keyPath: KeyPath<MutableValues, Value>) -> Value {
            lock.lock()
            defer { lock.unlock() }
            return values[keyPath: keyPath]
        }

        func write<Value>(_ keyPath: WritableKeyPath<MutableValues, Value>, value: Value) {
            lock.lock()
            defer { lock.unlock() }
            values[keyPath: keyPath] = value
        }

        func snapshot() -> MutableValues {
            lock.lock()
            defer { lock.unlock() }
            return values
        }

        func replaceCredentials(
            musicId: Int?,
            musicKey: String?,
            encryptUin: String?,
            loginType: Int?
        ) {
            lock.lock()
            defer { lock.unlock() }
            values.musicId = musicId
            values.musicKey = musicKey
            values.encryptUin = encryptUin
            values.loginType = loginType
        }
    }

    private final class SharedStorage: @unchecked Sendable {
        private let lock = NSLock()
        private var client: QQMusicClient

        init(client: QQMusicClient) {
            self.client = client
        }

        func current() -> QQMusicClient {
            lock.lock()
            defer { lock.unlock() }
            return client
        }

        func replace(with client: QQMusicClient) {
            lock.lock()
            defer { lock.unlock() }
            self.client = client
        }
    }

    // MARK: - 属性

    /// 服务器地址
    public let baseURL: URL

    /// API 访问令牌
    public var apiToken: String? {
        get { mutableState.read(\.apiToken) }
        set { mutableState.write(\.apiToken, value: newValue) }
    }

    /// 用户 musicId（传递给服务端用于身份识别）
    public var musicId: Int? {
        get { mutableState.read(\.musicId) }
        set { mutableState.write(\.musicId, value: newValue) }
    }

    /// 用户 musicKey（传递给服务端用于鉴权）
    public var musicKey: String? {
        get { mutableState.read(\.musicKey) }
        set { mutableState.write(\.musicKey, value: newValue) }
    }

    /// 用户 encrypt_uin（传递给服务端用于查询用户资料）
    public var encryptUin: String? {
        get { mutableState.read(\.encryptUin) }
        set { mutableState.write(\.encryptUin, value: newValue) }
    }

    /// 登录类型（1=微信, 2=QQ）
    public var loginType: Int? {
        get { mutableState.read(\.loginType) }
        set { mutableState.write(\.loginType, value: newValue) }
    }

    /// 请求超时时间（秒）
    public let timeout: TimeInterval

    /// 最大重试次数
    public let maxRetries: Int

    /// URLSession
    private let session: URLSession

    private let mutableState: MutableState

    #if canImport(os)
    /// 日志
    private static let logger = Logger(subsystem: "QQMusicKit", category: "Network")
    #endif

    // MARK: - 单例

    /// 共享实例（需先调用 configure 设置服务器地址）
    private static let sharedStorage = SharedStorage(
        client: QQMusicClient(baseURL: URL(string: "http://localhost:8000")!)
    )

    public static var shared: QQMusicClient {
        get { sharedStorage.current() }
        set { sharedStorage.replace(with: newValue) }
    }

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
        session: URLSession? = nil,
        apiToken: String? = nil,
        musicId: Int? = nil,
        musicKey: String? = nil,
        encryptUin: String? = nil,
        loginType: Int? = nil
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.mutableState = MutableState(
            values: MutableValues(
                apiToken: apiToken,
                musicId: musicId,
                musicKey: musicKey,
                encryptUin: encryptUin,
                loginType: loginType
            )
        )

        if let session {
            self.session = session
        } else {
            // 每个客户端保留自己的内存 Cookie，避免登录与账号请求共享系统 Cookie 容器。
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout * 2
            self.session = URLSession(configuration: config)
        }
    }

    public var configurationSnapshot: ConfigurationSnapshot {
        let values = mutableState.snapshot()
        return ConfigurationSnapshot(
            baseURL: baseURL,
            timeout: timeout,
            maxRetries: maxRetries,
            apiToken: values.apiToken
        )
    }

    public func replaceCredentials(
        musicId: Int?,
        musicKey: String?,
        encryptUin: String?,
        loginType: Int?
    ) {
        mutableState.replaceCredentials(
            musicId: musicId,
            musicKey: musicKey,
            encryptUin: encryptUin,
            loginType: loginType
        )
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
        let requestIdentity = mutableState.snapshot()
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw QQMusicError.invalidURL(path)
        }

        var allParams = params
        if let token = requestIdentity.apiToken, !token.isEmpty {
            allParams["token"] = token
        }
        if let mid = requestIdentity.musicId {
            allParams["_musicid"] = String(mid)
        }
        if let mkey = requestIdentity.musicKey, !mkey.isEmpty {
            allParams["_musickey"] = mkey
        }
        if let euin = requestIdentity.encryptUin, !euin.isEmpty {
            allParams["_euin"] = euin
        }
        if let lt = requestIdentity.loginType {
            allParams["_login_type"] = String(lt)
        }
        if !allParams.isEmpty {
            components.queryItems = allParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw QQMusicError.invalidURL(path)
        }

        var urlRequest = URLRequest(url: url)
        if path.hasPrefix("/login/qrcode/") {
            urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
            urlRequest.setValue("no-store, no-cache, max-age=0", forHTTPHeaderField: "Cache-Control")
            urlRequest.setValue("no-cache", forHTTPHeaderField: "Pragma")
        }

        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                #if canImport(os)
                if attempt > 0 {
                    Self.logger.info("重试请求 (\(attempt)/\(self.maxRetries)): \(path)")
                }
                #endif

                let (data, response) = try await session.data(for: urlRequest)

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
