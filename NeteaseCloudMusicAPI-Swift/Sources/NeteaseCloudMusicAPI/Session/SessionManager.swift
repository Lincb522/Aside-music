// SessionManager.swift
// 会话管理器
// 管理 Cookie、设备元数据和认证状态
// 实现 Cookie 构建、更新、User-Agent 选择和会话序列化

import Foundation

// MARK: - 平台类型

/// 平台类型枚举
/// 决定 OS 元数据和 User-Agent 字符串的选择
public enum PlatformType: String, Codable, CaseIterable, Sendable {
    case pc
    case linux
    case android
    case iphone
}

// MARK: - 操作系统信息

/// 操作系统信息结构体
/// 包含平台对应的 OS 名称、应用版本、系统版本和渠道
struct OSInfo {
    /// 操作系统名称
    let os: String
    /// 应用版本号
    let appver: String
    /// 系统版本
    let osver: String
    /// 分发渠道
    let channel: String
}

// MARK: - 会话管理器

/// 会话管理器
/// 负责管理 Cookie 存储、设备元数据、认证状态和会话持久化
public class SessionManager {

    // MARK: - 公共属性

    /// 当前 Cookie 存储（键值对）— 通过 lock 保护线程安全
    public var cookies: [String: String] {
        get { lock.withLock { _cookies } }
        set { lock.withLock { _cookies = newValue } }
    }
    private var _cookies: [String: String]
    private let lock = NSLock()

    /// 当前平台类型
    public var platformType: PlatformType

    /// 匿名令牌（当无 MUSIC_U 时用作 MUSIC_A 的回退值）
    public var anonymousToken: String

    // MARK: - 静态映射表

    /// 平台类型 → OS 信息映射
    /// 包含各平台对应的操作系统名称、应用版本、系统版本和渠道信息
    static let osMap: [PlatformType: OSInfo] = [
        .pc: OSInfo(
            os: "pc",
            appver: "3.1.17.204416",
            osver: "Microsoft-Windows-10-Professional-build-19045-64bit",
            channel: "netease"
        ),
        .linux: OSInfo(
            os: "linux",
            appver: "1.2.1.0428",
            osver: "Deepin 20.9",
            channel: "netease"
        ),
        .android: OSInfo(
            os: "android",
            appver: "8.20.20.231215173437",
            osver: "14",
            channel: "xiaomi"
        ),
        .iphone: OSInfo(
            os: "iPhone OS",
            appver: "9.0.90",
            osver: "16.2",
            channel: "distribution"
        ),
    ]

    /// 加密模式 → 平台 → User-Agent 字符串映射
    /// 匹配 Node.js 源码中的 userAgentMap 定义
    static let userAgentMap: [CryptoMode: [PlatformType: String]] = [
        .weapi: [
            .pc: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0"
        ],
        .linuxapi: [
            .linux: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36"
        ],
        .api: [
            .pc: "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/3.0.18.203152",
            .android: "NeteaseMusic/9.1.65.240927161425(9001065);Dalvik/2.1.0 (Linux; U; Android 14; 23013RK75C Build/UKQ1.230804.001)",
            .iphone: "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)",
        ],
        .eapi: [
            .pc: "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/3.0.18.203152",
            .android: "NeteaseMusic/9.1.65.240927161425(9001065);Dalvik/2.1.0 (Linux; U; Android 14; 23013RK75C Build/UKQ1.230804.001)",
            .iphone: "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)",
        ],
    ]

    // MARK: - 内部属性

    /// 设备唯一标识符（启动时生成，会话生命周期内不变）
    internal var deviceId: String

    /// WNMCID 标识符（启动时生成）
    internal var wnmcid: String

    // MARK: - 初始化

    /// 初始化会话管理器
    /// - Parameters:
    ///   - platformType: 平台类型，默认为 `.iphone`
    ///   - anonymousToken: 匿名令牌，默认为空字符串
    ///   - cookies: 初始 Cookie 字典，默认为空
    public init(
        platformType: PlatformType = .iphone,
        anonymousToken: String = "",
        cookies: [String: String] = [:]
    ) {
        self.platformType = platformType
        self.anonymousToken = anonymousToken
        self._cookies = cookies
        self.deviceId = SessionManager.generateRandomHex(count: 32)
        self.wnmcid = SessionManager.generateWNMCID()
    }

    // MARK: - Cookie 构建（任务 5.2）

    /// 构建请求 Cookie 头字符串
    /// 生成包含设备元数据的完整 Cookie 头，用于 HTTP 请求
    /// - Parameters:
    ///   - uri: 请求的 URI 路径
    ///   - crypto: 加密模式
    /// - Returns: 格式化的 Cookie 头字符串（key=value; key=value; ...）
    public func buildCookieHeader(for uri: String, crypto: CryptoMode) -> String {
        let osInfo = SessionManager.osMap[platformType] ?? SessionManager.osMap[.pc]!

        // 整个读取操作在同一把锁内完成，保证一致性
        let cookieDict: [String: String] = lock.withLock {
            let nuid = _cookies["_ntes_nuid"] ?? SessionManager.generateRandomHex(count: 32)
            let nnid = _cookies["_ntes_nnid"] ?? "\(nuid),\(Int(Date().timeIntervalSince1970 * 1000))"

            var dict = _cookies
            dict["__remember_me"] = "true"
            dict["ntes_kaola_ad"] = "1"
            dict["_ntes_nuid"] = nuid
            dict["_ntes_nnid"] = nnid
            dict["WNMCID"] = _cookies["WNMCID"] ?? wnmcid
            dict["WEVNSM"] = _cookies["WEVNSM"] ?? "1.0.0"
            dict["osver"] = _cookies["osver"] ?? osInfo.osver
            dict["deviceId"] = _cookies["deviceId"] ?? deviceId
            dict["os"] = _cookies["os"] ?? osInfo.os
            dict["channel"] = _cookies["channel"] ?? osInfo.channel
            dict["appver"] = _cookies["appver"] ?? osInfo.appver

            if !uri.contains("login") {
                dict["NMTID"] = SessionManager.generateRandomHex(count: 16)
            }

            if dict["MUSIC_U"] == nil {
                dict["MUSIC_A"] = dict["MUSIC_A"] ?? anonymousToken
            }

            return dict
        }

        return SessionManager.cookieDictToString(cookieDict)
    }

    /// 构建 EAPI/API 专用请求头
    /// 生成包含设备信息和认证令牌的请求头字典
    /// - Parameter csrfToken: CSRF 令牌
    /// - Returns: 请求头字典
    public func buildEAPIHeader(csrfToken: String) -> [String: String] {
        let osInfo = SessionManager.osMap[platformType] ?? SessionManager.osMap[.pc]!
        let timestamp = Int(Date().timeIntervalSince1970)

        // 整个读取操作在同一把锁内完成
        return lock.withLock {
            var header: [String: String] = [
                "osver": _cookies["osver"] ?? osInfo.osver,
                "deviceId": _cookies["deviceId"] ?? deviceId,
                "os": _cookies["os"] ?? osInfo.os,
                "appver": _cookies["appver"] ?? osInfo.appver,
                "versioncode": _cookies["versioncode"] ?? "140",
                "mobilename": _cookies["mobilename"] ?? "",
                "buildver": _cookies["buildver"] ?? String(timestamp),
                "resolution": _cookies["resolution"] ?? "1920x1080",
                "__csrf": csrfToken,
                "channel": _cookies["channel"] ?? osInfo.channel,
                "requestId": SessionManager.generateRequestId(),
            ]

            if let musicU = _cookies["MUSIC_U"] {
                header["MUSIC_U"] = musicU
            }
            if let musicA = _cookies["MUSIC_A"] {
                header["MUSIC_A"] = musicA
            } else if _cookies["MUSIC_U"] == nil {
                header["MUSIC_A"] = anonymousToken
            }

            return header
        }
    }

    /// 从响应的 Set-Cookie 头更新 Cookie 存储
    /// 解析 Set-Cookie 头字符串列表，提取键值对并更新存储
    /// - Parameter setCookieHeaders: Set-Cookie 头字符串数组
    public func updateCookies(from setCookieHeaders: [String]) {
        // 防御：空数组直接返回
        guard !setCookieHeaders.isEmpty else { return }
        
        // 将输入拷贝为局部不可变数组，避免任何外部引用问题
        let headers = Array(setCookieHeaders)
        
        // 先在锁外完成所有解析（纯值类型操作）
        var parsed: [(String, String)] = []
        parsed.reserveCapacity(headers.count)
        
        for header in headers {
            // 取分号前的第一段 key=value
            let cookiePart: Substring
            if let semicolonIdx = header.firstIndex(of: ";") {
                cookiePart = header[header.startIndex..<semicolonIdx]
            } else {
                cookiePart = header[...]
            }
            
            guard let eqIdx = cookiePart.firstIndex(of: "=") else { continue }
            let key = String(cookiePart[cookiePart.startIndex..<eqIdx])
                .trimmingCharacters(in: .whitespaces)
            let value = String(cookiePart[cookiePart.index(after: eqIdx)...])
                .trimmingCharacters(in: .whitespaces)
            
            if !key.isEmpty {
                parsed.append((key, value))
            }
        }
        
        // 一次性加锁批量写入
        lock.withLock {
            for (key, value) in parsed {
                _cookies[key] = value
            }
        }
    }

    /// 选择 User-Agent 字符串
    /// 根据加密模式和当前平台类型从映射表中选择合适的 User-Agent
    /// - Parameter crypto: 加密模式
    /// - Returns: User-Agent 字符串，如果映射表中无对应项则返回空字符串
    public func chooseUserAgent(crypto: CryptoMode) -> String {
        // 对于 eapi 模式，使用 api 的 User-Agent 映射（匹配 Node.js 行为）
        let effectiveCrypto = crypto
        if let platformMap = SessionManager.userAgentMap[effectiveCrypto] {
            // 先尝试当前平台，再尝试默认平台
            if let ua = platformMap[platformType] {
                return ua
            }
            // 如果当前平台没有对应的 UA，返回映射中的第一个值
            if let firstUA = platformMap.values.first {
                return firstUA
            }
        }
        return ""
    }

    // MARK: - 序列化/反序列化（任务 5.3）

    /// 将会话状态序列化为 JSON 数据
    /// 使用 Codable 协议将会话的关键状态编码为 JSON
    /// - Returns: JSON 编码的 Data
    /// - Throws: 编码失败时抛出错误
    public func serialize() throws -> Data {
        let snapshotCookies = lock.withLock { _cookies }
        let state = SessionState(
            cookies: snapshotCookies,
            platformType: platformType,
            anonymousToken: anonymousToken,
            deviceId: deviceId,
            wnmcid: wnmcid
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            return try encoder.encode(state)
        } catch {
            throw NCMError.serializationFailed(detail: "会话序列化失败: \(error.localizedDescription)")
        }
    }

    /// 从 JSON 数据反序列化恢复会话
    /// - Parameter data: JSON 编码的会话数据
    /// - Returns: 恢复的 SessionManager 实例
    /// - Throws: 解码失败时抛出错误
    public static func deserialize(from data: Data) throws -> SessionManager {
        let decoder = JSONDecoder()
        let state: SessionState
        do {
            state = try decoder.decode(SessionState.self, from: data)
        } catch {
            throw NCMError.serializationFailed(detail: "会话反序列化失败: \(error.localizedDescription)")
        }
        let manager = SessionManager(
            platformType: state.platformType,
            anonymousToken: state.anonymousToken,
            cookies: state.cookies
        )
        manager.deviceId = state.deviceId
        manager.wnmcid = state.wnmcid
        return manager
    }

    // MARK: - 内部辅助方法

    /// 生成随机十六进制字符串
    /// - Parameter count: 字节数（输出字符串长度为 count * 2... 不，这里 count 是 hex 字符数）
    /// - Returns: 随机十六进制字符串
    internal static func generateRandomHex(count: Int) -> String {
        // 生成 count/2 个随机字节，转换为 hex 字符串
        let byteCount = (count + 1) / 2
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        // 截取到指定长度
        return String(hex.prefix(count))
    }

    /// 生成 WNMCID 标识符
    /// 格式：6个随机小写字母.时间戳.01.0
    /// - Returns: WNMCID 字符串
    internal static func generateWNMCID() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyz"
        var randomString = ""
        for _ in 0..<6 {
            let index = characters.index(
                characters.startIndex,
                offsetBy: Int.random(in: 0..<characters.count)
            )
            randomString.append(characters[index])
        }
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return "\(randomString).\(timestamp).01.0"
    }

    /// 生成请求 ID
    /// 格式：时间戳_四位随机数
    /// - Returns: 请求 ID 字符串
    internal static func generateRequestId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let random = String(format: "%04d", Int.random(in: 0..<1000))
        return "\(timestamp)_\(random)"
    }

    /// 将 Cookie 字典转换为 HTTP Cookie 头字符串
    /// 对键和值进行 URL 编码，用 "; " 分隔
    /// - Parameter dict: Cookie 键值对字典
    /// - Returns: 格式化的 Cookie 字符串
    internal static func cookieDictToString(_ dict: [String: String]) -> String {
        return dict.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "; ")
    }
}

// MARK: - 会话状态（用于序列化）

/// 会话状态结构体
/// 用于 Codable 序列化/反序列化会话管理器的关键状态
struct SessionState: Codable {
    /// Cookie 存储
    let cookies: [String: String]
    /// 平台类型
    let platformType: PlatformType
    /// 匿名令牌
    let anonymousToken: String
    /// 设备 ID
    let deviceId: String
    /// WNMCID 标识符
    let wnmcid: String
}
