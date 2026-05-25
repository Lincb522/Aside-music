// APIService.swift
// ncm API 服务层
// 完全基于 NeteaseCloudMusicAPI-Swift (NCMClient) 实现

import Foundation
@preconcurrency import Combine
import NeteaseCloudMusicAPI
import QQMusicKit

// MARK: - Notification Names
extension Notification.Name {
    static let didLogin = Notification.Name("Monologue.didLogin")
    static let didLogout = Notification.Name("Monologue.didLogout")
}

class APIService: @unchecked Sendable {
    static let shared = APIService()

    private enum AccessRelay {
        private static let mask: UInt8 = 0x39
        private static let verifySeed: [UInt8] = [22, 102, 88, 93, 84, 80, 87, 22, 88, 73, 80, 22, 79, 92, 75, 80, 95, 64]
        private static let tokenSeed: [UInt8] = [77, 86, 82, 92, 87]

        static var verifyPath: String {
            reveal(verifySeed)
        }

        static var tokenQueryName: String {
            reveal(tokenSeed)
        }

        private static func reveal(_ seed: [UInt8]) -> String {
            String(decoding: seed.map { $0 ^ mask }, as: UTF8.self)
        }
    }

    // MARK: - NCMClient 实例
    /// ncm API 客户端（后端代理模式）— 用户自己的 Cookie
    let ncm: NCMClient
    
    /// VIP 客户端 — 服务器 VIP 账号 Cookie（非会员用户的内容请求回退）
    private(set) var ncmVIP: NCMClient?
    
    /// 当前用户是否为ncm会员（黑胶 VIP）
    @Published var isCurrentUserVIP: Bool = false
    
    /// 内容请求使用的客户端（歌曲URL/歌词/详情等）
    /// 已登录且有会员 → ncm（用户自己）；未登录或无会员 → ncmVIP（服务器 VIP）
    var contentClient: NCMClient {
        if isCurrentUserVIP { return ncm }
        return ncmVIP ?? ncm
    }

    /// 是否配置了服务器 VIP Cookie
    var hasVIPCookie: Bool { ncmVIP != nil && vipCookieHeader != nil }
    
    private let cookieKey = "monologue_music_cookie"
    private let userIdKey = "monologue_music_uid"

    @Published var currentUserId: Int? {
        didSet {
            if let uid = currentUserId {
                KeychainHelper.save(key: userIdKey, intValue: uid)
            } else {
                KeychainHelper.delete(key: userIdKey)
            }
            let isAuthenticated = currentCookie != nil && currentUserId != nil
            UserDefaults.standard.set(isAuthenticated, forKey: AppConfig.StorageKeys.isLoggedIn)
            if oldValue == nil, currentUserId != nil, isAuthenticated {
                NotificationCenter.default.post(name: .didLogin, object: nil)
            } else if oldValue != nil, currentUserId == nil {
                NotificationCenter.default.post(name: .didLogout, object: nil)
            }
        }
    }

    var currentCookie: String? {
        get {
            guard let raw = KeychainHelper.loadString(key: cookieKey), !raw.isEmpty else {
                return nil
            }
            // 兼容旧存档:早期把原始 Set-Cookie 串直接存进 Keychain,读出来时统一清洗
            let normalized = Self.normalizeCookieHeader(raw)
            return normalized.isEmpty ? nil : normalized
        }
        set {
            // 登录接口返回的是原始 Set-Cookie 拼接串,
            // 直接塞给 "Cookie" 请求头会让后端把 Max-Age / Expires / Path 等属性当作 cookie,
            // 导致真实的 MUSIC_U 被污染,网易云判定为未登录(code 301)。
            // 在存储前先清洗成 "k=v; k=v" 的标准请求头格式。
            let normalized = newValue.map { Self.normalizeCookieHeader($0) }

            if let value = normalized, !value.isEmpty {
                KeychainHelper.save(key: cookieKey, value: value)
            } else {
                KeychainHelper.delete(key: cookieKey)
            }
            if let cookie = normalized, !cookie.isEmpty {
                // 先清空 NCMClient 内部可能被污染的 session cookie,再注入清洗后的新值
                ncm.clearCookies()
                ncm.setCookie(cookie)
            }
            if (normalized == nil || normalized?.isEmpty == true) && currentUserId != nil {
                currentUserId = nil
            }
        }
    }

    /// 将登录接口返回的原始 Set-Cookie 拼接串(含 Max-Age / Expires / Path / Domain 等属性)
    /// 清洗为可直接用于 "Cookie" 请求头的 "k=v; k=v" 格式。
    ///
    /// - 去掉 cookie 属性(Max-Age / Expires / Path / Domain / Secure / HttpOnly / SameSite)
    /// - 跳过 Max-Age=0 或已过期的 cookie(Set-Cookie 里用于清除登录态的占位,如 MUSIC_SNS=)
    /// - 保留最后一次出现的 key(Set-Cookie 串里后写的覆盖先写的)
    /// - 去掉空 key / 无 "=" 的段
    static func normalizeCookieHeader(_ raw: String) -> String {
        // 已经是清洗后的标准格式(没有 Max-Age / Expires / Path 等属性),原样返回
        let hasSetCookieAttributes = raw.range(
            of: #"\b(?:Max-Age|Expires|Path|Domain|Secure|HttpOnly|SameSite)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        guard hasSetCookieAttributes else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let reservedAttributes: Set<String> = [
            "max-age", "expires", "path", "domain",
            "secure", "httponly", "samesite", "version", "comment", "priority"
        ]

        var pairs: [(String, String)] = []
        var indexByKey: [String: Int] = [:]
        var skipCurrent = false

        for rawSegment in raw.split(separator: ";", omittingEmptySubsequences: true) {
            let segment = rawSegment.trimmingCharacters(in: .whitespaces)
            if segment.isEmpty { continue }

            let parts = segment.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = parts.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""

            let lowered = key.lowercased()

            if reservedAttributes.contains(lowered) {
                // 碰到 Max-Age=0 / Expires=过去时间 → 当前 cookie 是"清除"指令,跳过紧邻的 pair
                if lowered == "max-age", let age = Int(value), age <= 0 {
                    if let last = pairs.last {
                        indexByKey.removeValue(forKey: last.0.lowercased())
                        pairs.removeLast()
                    }
                    skipCurrent = true
                }
                continue
            }

            if skipCurrent {
                skipCurrent = false
                continue
            }

            if key.isEmpty { continue }

            // 同名 key 取后面出现的那一个
            if let existingIndex = indexByKey[lowered] {
                pairs[existingIndex] = (key, value)
            } else {
                indexByKey[lowered] = pairs.count
                pairs.append((key, value))
            }
        }

        return pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "; ")
    }

    private static func normalizedCookieHeader(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let normalized = normalizeCookieHeader(raw)
        return normalized.isEmpty ? nil : normalized
    }

    private var vipCookieHeader: String? {
        Self.normalizedCookieHeader(SecureConfig.vipCookie)
    }

    var isLoggedIn: Bool {
        return currentCookie != nil && currentUserId != nil
    }

    init() {
        let serverUrl = SecureConfig.apiBaseURL

        // 从 UserDefaults 迁移到 Keychain（一次性迁移）
        Self.migrateToKeychainIfNeeded()

        let rawSavedCookie = KeychainHelper.loadString(key: cookieKey)
        // 兼容旧存档:早期把原始 Set-Cookie 串存进 Keychain,启动时先清洗
        let savedCookie: String? = {
            guard let raw = rawSavedCookie, !raw.isEmpty else { return nil }
            let cleaned = Self.normalizeCookieHeader(raw)
            return cleaned.isEmpty ? nil : cleaned
        }()
        // 如果清洗后跟存档不一致,回写 Keychain,避免下次启动再清洗
        if let cleaned = savedCookie, cleaned != rawSavedCookie {
            KeychainHelper.save(key: cookieKey, value: cleaned)
            #if DEBUG
            print("[APIService] init - cookie 已从旧 Set-Cookie 串格式迁移到标准请求头格式")
            #endif
        }
        let savedUid = KeychainHelper.loadInt(key: userIdKey)
        
        #if DEBUG
        print("[APIService] init - cookie: \(savedCookie.map { String(localized: "有(\($0.prefix(30))...)") } ?? String(localized: "无")), uid: \(savedUid?.description ?? String(localized: "无"))")
        #endif

        self.ncm = NCMClient(
            cookie: savedCookie,
            serverUrl: serverUrl
        )
        ncm.apiToken = SecureConfig.apiToken
        
        if let vipCookie = Self.normalizedCookieHeader(SecureConfig.vipCookie) {
            self.ncmVIP = NCMClient(cookie: vipCookie, serverUrl: serverUrl)
            ncmVIP?.apiToken = SecureConfig.apiToken
            #if DEBUG
            print("[APIService] VIP Cookie 已配置，NCM VIP 已初始化")
            #endif
        }

        // 直接赋值给底层存储，避免触发 didSet（didSet 中会重新写 Keychain）
        self.currentUserId = savedUid
        
        // 同步 isLoggedIn 标志
        if savedCookie != nil && savedUid != nil {
            UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.isLoggedIn)
            #if DEBUG
            print("[APIService] ✅ 已登录，同步 isLoggedIn = true")
            #endif
        } else {
            UserDefaults.standard.set(false, forKey: AppConfig.StorageKeys.isLoggedIn)
            #if DEBUG
            print("[APIService] ❌ 未登录，同步 isLoggedIn = false")
            #endif
        }

        ncm.autoUnblock = false
        
        // 启动时检测 VIP 状态（如果已登录）
        if savedCookie != nil && savedUid != nil {
            checkUserVIPStatus()
        }
        
        if let qqURL = URL(string: SecureConfig.qqMusicBaseURL) {
            QQMusicClient.configure(baseURL: qqURL, timeout: 30, maxRetries: 1)
            qqClient.apiToken = SecureConfig.apiToken
        } else {
            AppLogger.error("QQ_MUSIC_BASE_URL 配置无效: \(SecureConfig.qqMusicBaseURL)")
        }
    }
    
    /// 迁移：将 UserDefaults 中的 cookie/uid 迁移到 Keychain
    /// 如果 Keychain 为空且 UserDefaults 有值，始终尝试迁移
    private static func migrateToKeychainIfNeeded() {
        // 迁移 cookie：如果 Keychain 没有但 UserDefaults 有，就迁移
        if KeychainHelper.loadString(key: "monologue_music_cookie") == nil,
           let oldCookie = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.cookie) {
            #if DEBUG
            print("[APIService] 迁移 cookie 到 Keychain")
            #endif
            KeychainHelper.save(key: "monologue_music_cookie", value: oldCookie)
            if KeychainHelper.loadString(key: "monologue_music_cookie") != nil {
                UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.cookie)
            }
        }
        
        // 迁移 uid：如果 Keychain 没有但 UserDefaults 有，就迁移
        if KeychainHelper.loadInt(key: "monologue_music_uid") == nil {
            let oldUid = UserDefaults.standard.integer(forKey: AppConfig.StorageKeys.userId)
            if oldUid != 0 {
                #if DEBUG
                print("[APIService] 迁移 uid=\(oldUid) 到 Keychain")
                #endif
                KeychainHelper.save(key: "monologue_music_uid", intValue: oldUid)
                if KeychainHelper.loadInt(key: "monologue_music_uid") != nil {
                    UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.userId)
                }
            }
        }
    }
    
    // MARK: - Token 验证

    enum TokenStatus: Equatable {
        case valid(name: String)
        case validationDisabled
        case missing
        case invalid
        case expired
        case deviceMismatch  // 设备不匹配（一机一码校验失败）
        case networkError

    }

    /// 启动时验证 API Token（带设备绑定）
    func verifyToken(isRefresh: Bool = false) async -> TokenStatus {
        guard let token = SecureConfig.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return .missing
        }

        guard var components = URLComponents(string: SecureConfig.apiBaseURL) else {
            return .networkError
        }

        let currentPath = components.path
        components.path = currentPath.hasSuffix("/")
            ? "\(currentPath)\(AccessRelay.verifyPath.dropFirst())"
            : "\(currentPath)\(AccessRelay.verifyPath)"
        
        var queryItems = [
            URLQueryItem(name: AccessRelay.tokenQueryName, value: token),
            URLQueryItem(name: "device_uuid", value: DeviceIdentifier.uuid)
        ]
        if isRefresh {
            queryItems.append(URLQueryItem(name: "is_refresh", value: "1"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            return .networkError
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // 上报设备信息到服务端进行绑定验证
            let deviceInfo = DeviceIdentifier.deviceInfo
            request.httpBody = try? JSONSerialization.data(withJSONObject: deviceInfo)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .networkError }

            if http.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let valid = json["valid"] as? Bool, valid {
                        if let enabled = json["enabled"] as? Bool, !enabled {
                            return .validationDisabled
                        }
                        let name = json["name"] as? String ?? ""
                        return .valid(name: name)
                    } else {
                        let reason = json["reason"] as? String ?? ""
                        if reason == "expired" {
                            return .expired
                        } else if reason == "device_limit" {
                            return .deviceMismatch
                        } else if reason == "missing" {
                            return .missing
                        } else {
                            return .invalid
                        }
                    }
                }
                return .validationDisabled
            } else if http.statusCode == 401 {
                return .missing
            } else if http.statusCode == 403 {
                // 检查是否是设备不匹配错误
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = (json["message"] ?? json["error"]) as? String,
                   message.lowercased().contains("device") {
                    return .deviceMismatch
                }
                return .invalid
            } else {
                return .networkError
            }
        } catch {
            return .networkError
        }
    }
    
    /// 保存 token 并同步到各 SDK client
    func applyToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let persistedToken = trimmed.isEmpty ? nil : trimmed
        let runtimeToken = persistedToken ?? ""

        SecureConfig.apiToken = persistedToken
        ncm.apiToken = runtimeToken
        ncmVIP?.apiToken = runtimeToken
        qqClient.apiToken = runtimeToken
    }
    
    // MARK: - VIP 状态检测
    
    /// 检测当前登录用户的会员状态
    /// 登录成功/App 启动恢复登录时调用
    func checkUserVIPStatus() {
        guard isLoggedIn else {
            isCurrentUserVIP = false
            return
        }
        Task {
            do {
                let status = try await fetchLoginStatus().async()
                let vipType = status.data.profile?.vipType ?? 0
                await MainActor.run {
                    self.isCurrentUserVIP = vipType > 0
                    #if DEBUG
                    print("[APIService] VIP 状态检测: vipType=\(vipType), isVIP=\(vipType > 0)")
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.isCurrentUserVIP = false
                }
                #if DEBUG
                print("[APIService] VIP 状态检测失败: \(error)")
                #endif
            }
        }
    }

    // MARK: - 登出

    func clearLocalLoginState(clearCache: Bool = true) {
        let wasLoggedIn = currentCookie != nil
            || currentUserId != nil
            || UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
        let hadUserId = currentUserId != nil

        KeychainHelper.delete(key: "monologue_music_cookie")
        KeychainHelper.delete(key: "monologue_music_uid")
        UserDefaults.standard.set(false, forKey: AppConfig.StorageKeys.isLoggedIn)

        isCurrentUserVIP = false
        ncm.clearCookies()
        currentUserId = nil

        if wasLoggedIn, !hadUserId {
            NotificationCenter.default.post(name: .didLogout, object: nil)
        }

        if clearCache {
            Task { @MainActor in
                OptimizedCacheManager.shared.clearAll()
                LikeManager.shared.refreshLikes()
            }
        }
    }

    func logout() -> AnyPublisher<SimpleResponse, Error> {
        let serverUrl = ncm.serverUrl ?? SecureConfig.apiBaseURL
        let cookieSnapshot = currentCookie
        let tokenSnapshot = SecureConfig.apiToken
        let logoutClient = NCMClient(cookie: cookieSnapshot, serverUrl: serverUrl)
        logoutClient.apiToken = tokenSnapshot

        clearLocalLoginState()

        return logoutClient.publisher { [logoutClient] in
            let response = try await logoutClient.logout()
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
        .eraseToAnyPublisher()
    }

    // MARK: - 认证

    func fetchLoginStatus() -> AnyPublisher<LoginStatusResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.loginStatus()
            // Node 后端 login_status.js 返回 {data: {code: 200, profile: {...}, account: {...}}}
            // 直连模式返回 {code: 200, profile: {...}, account: {...}}
            var profile: UserProfile? = nil
            // 优先从 data 包装层取（后端代理模式）
            let profileSource: [String: Any]?
            if let dataDict = response.body["data"] as? [String: Any] {
                profileSource = dataDict["profile"] as? [String: Any]
            } else {
                profileSource = response.body["profile"] as? [String: Any]
            }
            if let profileDict = profileSource {
                let data = try JSONSerialization.data(withJSONObject: profileDict)
                profile = try JSONDecoder().decode(UserProfile.self, from: data)
            }
            return LoginStatusResponse(data: LoginStatusData(profile: profile))
        }
    }

    // MARK: - 登录接口

    func fetchQRKey() -> AnyPublisher<QRKeyResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.loginQrKey()
            // Node 后端 login_qr_key.js 返回 {data: {unikey: "xxx", code: 200}, code: 200}
            let unikey: String
            if let dataDict = response.body["data"] as? [String: Any],
               let key = dataDict["unikey"] as? String {
                unikey = key
            } else {
                // 直连模式下可能直接返回 unikey
                unikey = response.body["unikey"] as? String ?? ""
            }
            return QRKeyResponse(data: QRKeyData(unikey: unikey))
        }
    }

    func fetchQRCreate(key: String) -> AnyPublisher<QRCreateResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.loginQrCreate(key: key)
            // NCMClient 的 loginQrCreate 直接构建 URL
            let data = response.body["data"] as? [String: Any]
            let qrurl = data?["qrurl"] as? String ?? ""
            // 二维码图片需要客户端自行生成，这里返回 URL
            return QRCreateResponse(data: QRCreateData(qrimg: "", qrurl: qrurl))
        }
    }

    func checkQRStatus(key: String) -> AnyPublisher<QRCheckResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.loginQrCheck(key: key)
            let code = response.body["code"] as? Int ?? 0
            let message = response.body["message"] as? String ?? ""
            // 优先从 JSON body 中取 cookie（Node 后端把登录 cookie 放在 body 里），
            // 其次从 HTTP Set-Cookie 头取
            let cookie: String?
            if let bodyCookie = response.body["cookie"] as? String, !bodyCookie.isEmpty {
                cookie = bodyCookie
            } else if !response.cookies.isEmpty {
                cookie = response.cookies.joined(separator: "; ")
            } else {
                cookie = nil
            }
            return QRCheckResponse(code: code, message: message, cookie: cookie)
        }
    }

    func sendCaptcha(phone: String) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.captchaSent(phone: phone)
            let code = response.body["code"] as? Int ?? 0
            let message = response.body["message"] as? String
            return SimpleResponse(code: code, message: message)
        }
    }

    func loginCellphone(phone: String, captcha: String) -> AnyPublisher<LoginResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.loginCellphone(phone: phone, captcha: captcha)
            let code = response.body["code"] as? Int ?? 0
            // 优先从 JSON body 中取 cookie（Node 后端把登录 cookie 放在 body 里），
            // 其次从 HTTP Set-Cookie 头取
            let cookie: String?
            if let bodyCookie = response.body["cookie"] as? String, !bodyCookie.isEmpty {
                cookie = bodyCookie
            } else if !response.cookies.isEmpty {
                cookie = response.cookies.joined(separator: "; ")
            } else {
                cookie = nil
            }
            var profile: UserProfile? = nil
            if let profileDict = response.body["profile"] as? [String: Any] {
                let data = try JSONSerialization.data(withJSONObject: profileDict)
                profile = try JSONDecoder().decode(UserProfile.self, from: data)
            }
            return LoginResponse(code: code, cookie: cookie, profile: profile)
        }
    }

    // MARK: - 首页数据接口

    func fetchDailySongs(cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.recommendSongs()
            if let code = response.body["code"] as? Int, code != 200 {
                let msg = response.body["msg"] as? String
                    ?? response.body["message"] as? String
                    ?? String(localized: "未知错误")
                throw NCMBridgeError.apiError(code, msg)
            }
            return try Self.decodeDailySongs(from: response.body)
        }
    }

    private static func decodeDailySongs(from body: [String: Any]) throws -> [Song] {
        let candidateKeyPaths = [
            ["data", "dailySongs"],
            ["data", "songs"],
            ["dailySongs"],
            ["recommend"],
            ["data", "recommend"],
            ["songs"]
        ]

        for keyPath in candidateKeyPaths {
            guard let rawValue = value(in: body, at: keyPath) else { continue }
            if let songs = decodeSongList(from: rawValue) {
                AppLogger.debug("每日推荐解析字段: \(keyPath.joined(separator: ".")), count=\(songs.count)")
                return songs
            }
        }

        let dataKeys = (body["data"] as? [String: Any])?.keys.sorted().joined(separator: ", ") ?? "nil"
        AppLogger.warning("每日推荐响应缺少歌曲列表字段，bodyKeys=\(body.keys.sorted().joined(separator: ", ")), dataKeys=\(dataKeys)")
        throw NCMBridgeError.missingKey("dailySongs")
    }

    private static func value(in body: [String: Any], at keyPath: [String]) -> Any? {
        var current: Any = body
        for key in keyPath {
            guard let dict = current as? [String: Any],
                  let next = dict[key],
                  !(next is NSNull) else {
                return nil
            }
            current = next
        }
        return current
    }

    private static func decodeSongList(from rawValue: Any) -> [Song]? {
        guard let array = rawValue as? [Any] else { return nil }
        guard !array.isEmpty else { return [] }

        let decoder = JSONDecoder()
        let songs = array.compactMap { item -> Song? in
            let rawSong = nestedSongObject(from: item)
            guard JSONSerialization.isValidJSONObject(rawSong),
                  let data = try? JSONSerialization.data(withJSONObject: rawSong) else {
                return nil
            }
            if let song = try? decoder.decode(Song.self, from: data) {
                return song
            }
            if let detail = try? decoder.decode(SongDetail.self, from: data) {
                return detail.toSong()
            }
            return nil
        }

        return songs.isEmpty ? nil : songs
    }

    private static func nestedSongObject(from item: Any) -> Any {
        guard let dict = item as? [String: Any] else { return item }
        for key in ["song", "songInfo", "data"] {
            if let nested = dict[key] as? [String: Any] {
                return nested
            }
        }
        return dict
    }

    func fetchRecommendPlaylists() -> AnyPublisher<[Playlist], Error> {
        ncm.publisher { [ncm] in
            do {
                let response = try await ncm.recommendResource()
                if let playlists = try Self.decodePlaylistArray(from: response.body, keyPath: ["recommend"]),
                   !playlists.isEmpty {
                    return playlists
                }
                AppLogger.warning("推荐歌单为空，切换到公开个性化歌单")
            } catch {
                AppLogger.warning("推荐歌单获取失败，切换到公开个性化歌单: \(error)")
            }

            let fallbackResponse = try await ncm.personalized(limit: 18)
            if let playlists = try Self.decodePlaylistArray(from: fallbackResponse.body, keyPath: ["result"]),
               !playlists.isEmpty {
                return playlists
            }
            if let playlists = try Self.decodePlaylistArray(from: fallbackResponse.body, keyPath: ["playlists"]),
               !playlists.isEmpty {
                return playlists
            }
            return []
        }
    }

    private static func decodePlaylistArray(from body: [String: Any], keyPath: [String]) throws -> [Playlist]? {
        guard let rawValue = value(in: body, at: keyPath) else { return nil }
        guard let array = rawValue as? [[String: Any]] else { return nil }
        let data = try JSONSerialization.data(withJSONObject: array)
        return try JSONDecoder().decode([Playlist].self, from: data)
    }

    func fetchUserPlaylists(uid: Int) -> AnyPublisher<[Playlist], Error> {
        ncm.publisher { [ncm] in
            #if DEBUG
            print("[API] fetchUserPlaylists: uid=\(uid), serverUrl=\(ncm.serverUrl ?? "nil")")
            print("[API] cookie存在: \(APIService.shared.currentCookie != nil)")
            #endif
            // 直接用 postToBackend 绕过后端 2 分钟缓存
            if let serverUrl = ncm.serverUrl {
                let params: [String: Any] = [
                    "uid": uid,
                    "limit": 1000,
                    "offset": 0,
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                ]
                // 优先使用 NCMClient sessionManager 中的最新 cookie（proxyRequest 会更新它）
                let cookieHeader: String? = {
                    let cookies = ncm.currentCookies
                    if !cookies.isEmpty {
                        let header = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
                        // NCMClient 内部可能把 Set-Cookie 里的 Max-Age / Expires / Path 等属性
                        // 也当作 cookie,需要清洗
                        let normalized = Self.normalizeCookieHeader(header)
                        if !normalized.isEmpty {
                            return normalized
                        }
                    }
                    return APIService.shared.currentCookie
                }()
                let body = try await Self.postToBackend(serverUrl: serverUrl, route: "/user/playlist", params: params, cookie: cookieHeader)
                #if DEBUG
                print("[API] postToBackend 响应 keys: \(body.keys.sorted())")
                if let code = body["code"] as? Int { print("[API] 响应 code=\(code)") }
                #endif
                guard let playlistArray = body["playlist"] as? [[String: Any]] else {
                    #if DEBUG
                    print("[API] ⚠️ 响应中无 playlist 数组，body: \(String(describing: body).prefix(300))")
                    #endif
                    return [Playlist]()
                }
                #if DEBUG
                print("[API] 获取到 \(playlistArray.count) 个歌单")
                #endif
                let data = try JSONSerialization.data(withJSONObject: playlistArray)
                return try JSONDecoder().decode([Playlist].self, from: data)
            }
            // 无后端时走 SDK
            let response = try await ncm.userPlaylist(uid: uid, limit: 1000)
            guard let playlistArray = response.body["playlist"] as? [[String: Any]] else {
                #if DEBUG
                print("[API] ⚠️ SDK 响应中无 playlist 数组")
                #endif
                return [Playlist]()
            }
            let data = try JSONSerialization.data(withJSONObject: playlistArray)
            return try JSONDecoder().decode([Playlist].self, from: data)
        }
    }

    func fetchPopularSongs() -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.personalizedNewsong(limit: 10)
            guard let resultArray = response.body["result"] as? [[String: Any]] else {
                return [Song]()
            }
            let data = try JSONSerialization.data(withJSONObject: resultArray)
            let results = try JSONDecoder().decode([PersonalizedNewSongResult].self, from: data)
            return results.map { $0.song.toSong() }
        }
    }

    func fetchRecentSongs() -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.recordRecentSong(limit: 50)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let listArray = dataDict["list"] as? [[String: Any]] else {
                return [Song]()
            }
            let listData = try JSONSerialization.data(withJSONObject: listArray)
            let items = try JSONDecoder().decode([RecentSongItem].self, from: listData)
            return items.map { $0.data }
        }
    }

    // MARK: - 歌单曲目响应（内部类型）
    struct PlaylistTrackResponse: Codable {
        let songs: [Song]
        let privileges: [Privilege]?
    }

    func fetchPlaylistTracks(id: Int, limit: Int = 30, offset: Int = 0, cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.playlistTrackAll(id: id, limit: limit, offset: offset)
            guard let songsArray = response.body["songs"] as? [[String: Any]] else {
                return [Song]()
            }
            // 容错解码：逐首解码，跳过字段缺失的下架/不可用歌曲，避免单首异常导致整个歌单加载失败
            let decoder = JSONDecoder()
            var songs = songsArray.compactMap { dict -> Song? in
                guard let itemData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                do {
                    return try decoder.decode(Song.self, from: itemData)
                } catch {
                    #if DEBUG
                    let songId = dict["id"] ?? "unknown"
                    let songName = dict["name"] ?? "unknown"
                    print("[API] ⚠️ 歌曲解码失败 id=\(songId) name=\(songName)")
                    if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
                       let jsonStr = String(data: jsonData, encoding: .utf8) {
                        print("[API]    原始 JSON:\n\(jsonStr)")
                    }
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let ctx):
                            print("[API]    缺少字段: \(key.stringValue), 路径: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
                        case .valueNotFound(let type, let ctx):
                            print("[API]    值为 null: 期望 \(type), 路径: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
                        case .typeMismatch(let type, let ctx):
                            print("[API]    类型不匹配: 期望 \(type), 路径: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
                        case .dataCorrupted(let ctx):
                            print("[API]    数据损坏: \(ctx.debugDescription), 路径: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
                        @unknown default:
                            print("[API]    解码错误: \(error)")
                        }
                    } else {
                        print("[API]    错误: \(error)")
                    }
                    #endif
                    return nil
                }
            }

            if let privArray = response.body["privileges"] as? [[String: Any]] {
                let privData = try JSONSerialization.data(withJSONObject: privArray)
                let privileges = try JSONDecoder().decode([Privilege].self, from: privData)
                let privDict = Dictionary(uniqueKeysWithValues: privileges.compactMap {
                    $0.id != nil ? ($0.id!, $0) : nil
                })
                for i in 0..<songs.count {
                    if let p = privDict[songs[i].id] {
                        songs[i].privilege = p
                    }
                }
            }
            return songs
        }
    }

    func fetchArtistDetail(id: Int) -> AnyPublisher<ArtistInfo, Error> {
        // 使用 artists 接口（/api/v1/artist/{id}），返回 picUrl/img1v1Url 字段
        // artistDetail 接口（/api/artist/head/info/get）返回 cover/avatar 字段名不同
        ncm.fetch(ArtistInfo.self, keyPath: "artist") { [ncm] in
            try await ncm.artists(id: id)
        }
    }

    func fetchArtistTopSongs(id: Int) -> AnyPublisher<[Song], Error> {
        ncm.fetch([Song].self, keyPath: "songs") { [ncm] in
            try await ncm.artistTopSong(id: id)
        }
    }
    
    /// 获取歌手详细描述（分段介绍）
    func fetchArtistDesc(id: Int) -> AnyPublisher<ArtistDescResult, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.artistDesc(id: id)
            let briefDesc = response.body["briefDesc"] as? String
            var sections: [ArtistDescSection] = []
            if let introArray = response.body["introduction"] as? [[String: Any]] {
                for intro in introArray {
                    let title = intro["ti"] as? String ?? ""
                    let content = intro["txt"] as? String ?? ""
                    if !content.isEmpty {
                        sections.append(ArtistDescSection(title: title, content: content))
                    }
                }
            }
            return ArtistDescResult(briefDesc: briefDesc, sections: sections)
        }
    }

    /// 获取歌手专辑列表
    func fetchArtistAlbums(id: Int, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[AlbumInfo], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.artistAlbum(id: id, limit: limit, offset: offset)
            guard let albumsArray = response.body["hotAlbums"] as? [[String: Any]] else {
                return [AlbumInfo]()
            }
            let data = try JSONSerialization.data(withJSONObject: albumsArray)
            return try JSONDecoder().decode([AlbumInfo].self, from: data)
        }
    }

    /// 获取歌手粉丝数量
    func fetchArtistFollowCount(id: Int) -> AnyPublisher<Int, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.artistFollowCount(id: id)
            if let data = response.body["data"] as? [String: Any],
               let count = data["fansCnt"] as? Int {
                return count
            }
            return 0
        }
    }

    /// 收藏/取消收藏歌手
    func artistSub(id: Int, subscribe: Bool) -> AnyPublisher<Bool, Error> {
        ncm.publisher { [ncm] in
            let action: SubAction = subscribe ? .sub : .unsub
            let response = try await ncm.artistSub(id: id, action: action)
            return response.body["code"] as? Int == 200
        }
    }

    func fetchPlaylistDetail(id: Int, cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil) -> AnyPublisher<Playlist, Error> {
        ncm.fetch(Playlist.self, keyPath: "playlist") { [ncm] in
            try await ncm.playlistDetail(id: id)
        }
    }
    
    /// 获取专辑详情（专辑信息 + 歌曲列表）
    func fetchAlbumDetail(id: Int) -> AnyPublisher<AlbumDetailResult, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.album(id: id)
            
            // 解析专辑信息
            var albumInfo: AlbumInfo?
            if let albumDict = response.body["album"] as? [String: Any] {
                let data = try JSONSerialization.data(withJSONObject: albumDict)
                albumInfo = try JSONDecoder().decode(AlbumInfo.self, from: data)
            }
            
            // 解析歌曲列表，并用专辑封面回填缺失的 picUrl
            var songs: [Song] = []
            if var songsArray = response.body["songs"] as? [[String: Any]] {
                let albumPicUrl = (response.body["album"] as? [String: Any])?["picUrl"] as? String
                for i in songsArray.indices {
                    if var al = songsArray[i]["al"] as? [String: Any], al["picUrl"] == nil || (al["picUrl"] as? String)?.isEmpty == true {
                        al["picUrl"] = albumPicUrl
                        songsArray[i]["al"] = al
                    }
                }
                let data = try JSONSerialization.data(withJSONObject: songsArray)
                songs = try JSONDecoder().decode([Song].self, from: data)
            }
            
            return AlbumDetailResult(album: albumInfo, songs: songs)
        }
    }

    func fetchBanners() -> AnyPublisher<[Banner], Error> {
        ncm.publisher { [ncm] in
            var allDicts: [[String: Any]] = []
            
            if ncm.serverUrl != nil {
                if let newBody = try? await ncm.banner(type: .iphone).body,
                   let arr1 = newBody["banners"] as? [[String: Any]] {
                    allDicts.append(contentsOf: arr1)
                }

                if let oldBody = try? await ncm.bannerBackup(type: .iphone).body,
                   let arr2 = oldBody["banners"] as? [[String: Any]] {
                    allDicts.append(contentsOf: arr2)
                }
            } else {
                let resp = try await ncm.banner(type: .iphone)
                let arr = resp.body["banners"] as? [[String: Any]] ?? []
                allDicts.append(contentsOf: arr)
            }
            
            let data = try JSONSerialization.data(withJSONObject: allDicts)
            let allBanners = try JSONDecoder().decode([Banner].self, from: data)
            
            var seenIds = Set<Int>()
            var uniqueBanners = [Banner]()
            for banner in allBanners {
                if !seenIds.contains(banner.targetId) {
                    seenIds.insert(banner.targetId)
                    uniqueBanners.append(banner)
                }
            }
            
            // 根据日志，当天的 API 并没有 targetType = 1 (新单曲) 的内容
            // 只有 1000(歌单) 和 3000(网页活动/演出)
            // 为了避免首页跑空，我们保留歌曲相关的实体类型：1(单曲), 10(专辑), 1000(歌单)
            // 直接过滤掉 targetType == 3000（含有“演出”、“独家策划”等网页重定向广告）
            return uniqueBanners.filter { banner in
                // 1: 单曲, 10: 专辑, 1000: 歌单
                return [1, 10, 1000].contains(banner.targetType)
            }
        }
    }

    func fetchTopLists() -> AnyPublisher<[TopList], Error> {
        ncm.fetch([TopList].self, keyPath: "list") { [ncm] in
            try await ncm.toplistDetail()
        }
    }

    func fetchHotSearch() -> AnyPublisher<[HotSearchItem], Error> {
        ncm.fetch([HotSearchItem].self, keyPath: "data") { [ncm] in
            try await ncm.searchHotDetail()
        }
    }

    func fetchDragonBalls() -> AnyPublisher<[DragonBall], Error> {
        ncm.fetch([DragonBall].self, keyPath: "data") { [ncm] in
            try await ncm.homepageDragonBall()
        }
    }

    func fetchPersonalFM() -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.personalFm()
            let fmSongs: [FMSong]
            if let dataArray = response.body["data"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: dataArray)
                fmSongs = try JSONDecoder().decode([FMSong].self, from: data)
            } else {
                fmSongs = []
            }
            let songs = fmSongs.map { $0.toSong() }
            if songs.isEmpty {
                AppLogger.debug("Personal FM: 响应中没有歌曲")
            }
            return songs
        }
        .handleEvents(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                AppLogger.error("Personal FM 获取失败: \(error)")
            }
        })
        .eraseToAnyPublisher()
    }

    func trashFM(id: Int, time: Int = 0) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.fmTrash(id: id, time: time)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    // MARK: - Song URL & Detail

    private func contentClientCandidates() -> [NCMClient] {
        var clients: [NCMClient] = []

        func appendUnique(_ client: NCMClient) {
            guard !clients.contains(where: { $0 === client }) else { return }
            clients.append(client)
        }

        // 播放 URL / 音质查询属于内容解锁链路。
        // 只要配置了内置 VIP Cookie，就优先使用它，避免用户账号 VIP 状态误判时被低音质结果截断。
        if let ncmVIP {
            appendUnique(ncmVIP)
        }
        appendUnique(ncm)

        return clients
    }

    private func contentClientLabel(_ client: NCMClient) -> String {
        if let vipClient = ncmVIP, client === vipClient {
            return "vip-cookie"
        }
        if client === ncm {
            return "user-cookie"
        }
        return "unknown-cookie"
    }

    /// 播放错误类型
    enum PlaybackError: Error {
        case unavailable      // 无版权
        case networkError     // 网络错误
        case tokenRequired    // 未配置 API Token
        case tokenExpired     // Token 已过期
        case unknown          // 未知错误

        var localizedDescription: String {
            switch self {
            case .unavailable:
                return NSLocalizedString("playback_error_unavailable", comment: "")
            case .networkError:
                return NSLocalizedString("playback_error_network", comment: "")
            case .tokenRequired:
                return NSLocalizedString("playback_error_token_required", comment: "")
            case .tokenExpired:
                return String(localized: "Token 已过期，请重新获取")
            case .unknown:
                return NSLocalizedString("playback_error_unknown", comment: "")
            }
        }
    }

    /// 歌曲URL结果
    struct SongUrlResult: Sendable {
        let url: String
        /// 是否来自解灰源（qcm）
        let isUnblocked: Bool
        /// 解灰匹配到的 qcm mid（用于后续音质切换）
        var unblockedQQMid: String? = nil
        /// QMC 加密文件的 ekey（需要客户端解密）
        var qmcEkey: String? = nil
        /// 实际使用的ncm音质（自动选择时回传给播放端更新 UI）
        var actualNeteaseQuality: SoundQuality? = nil
        /// 实际使用的 QQ 音质（自动选择时回传给播放端更新 UI）
        var actualQQQuality: QQMusicQuality? = nil
    }

    /// 获取歌曲播放URL
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - level: 期望音质；传 nil 时自动按最高音质策略解析
    ///   - prefetchedLevel: 预查询缓存的最佳音质（由 PlayerManager 传入）
    ///   - skipUnblock: 是否跳过（播客等场景）
    func fetchSongUrl(id: Int, level: String? = nil, prefetchedLevel: String? = nil, skipUnblock: Bool = false, isDownload: Bool = false) -> AnyPublisher<SongUrlResult, Error> {
        return asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }
            if await MainActor.run(body: { OnlineAccessManager.shared.lastTokenStatus }) == .expired {
                throw PlaybackError.tokenExpired
            }
            if await MainActor.run(body: { OnlineAccessManager.shared.lastTokenStatus }) == .missing {
                throw PlaybackError.tokenRequired
            }
            let preferredQuality = level.flatMap(SoundQuality.init(rawValue:))
            let prefetchedQuality = prefetchedLevel.flatMap(SoundQuality.init(rawValue:))
            let clients = self.contentClientCandidates()
            var lastError: Error?

            for (index, client) in clients.enumerated() {
                let clientLabel = self.contentClientLabel(client)
                do {
                    return try await self.resolveNeteaseSongUrl(
                        id: id,
                        client: client,
                        clientLabel: clientLabel,
                        preferredQuality: preferredQuality,
                        prefetchedQuality: prefetchedQuality,
                        isDownload: isDownload
                    )
                } catch PlaybackError.tokenRequired {
                    throw PlaybackError.tokenRequired
                } catch PlaybackError.tokenExpired {
                    throw PlaybackError.tokenExpired
                } catch {
                    lastError = error
                    if index < clients.count - 1 {
                        AppLogger.warning("[Netease] \(clientLabel) 播放 URL 获取失败，切换 Cookie 兜底: \(error.localizedDescription)")
                    } else {
                        AppLogger.warning("[Netease] \(clientLabel) 播放 URL 获取失败，无更多 Cookie 可兜底: \(error.localizedDescription)")
                    }
                }
            }

            if let lastError {
                throw lastError
            }
            throw PlaybackError.unavailable
        }
    }

    private func resolveNeteaseSongUrl(
        id: Int,
        client: NCMClient,
        clientLabel: String,
        preferredQuality: SoundQuality?,
        prefetchedQuality: SoundQuality?,
        isDownload: Bool
    ) async throws -> SongUrlResult {
        let availableInfos: [NeteaseSongQualityInfo]?

        do {
            let infos = try await queryNeteaseQualities(id: id, client: client)
            availableInfos = infos
            if !infos.isEmpty {
                AppLogger.info("[Netease] \(clientLabel) 可用音质: \(infos.map(\.quality.displayName).joined(separator: " > "))")
            }
        } catch {
            availableInfos = nil
            AppLogger.warning("[Netease] \(clientLabel) 音质查询失败，按回退链盲试: \(error.localizedDescription)")
        }

        let candidates = buildNeteasePlaybackCandidates(
            preferred: preferredQuality,
            prefetched: prefetchedQuality,
            availableInfos: availableInfos
        )

        // 快速路径：availableInfos 已知真实可用档位时，直接用第一个（"最高可用"）
        // 成功即返回，节省串行重试的网络延迟
        if availableInfos != nil, let best = candidates.first {
            AppLogger.info("[Netease] \(clientLabel) 使用最高可用音质: \(best.displayName)")
            do {
                let result = try await tryNeteaseLevel(client: client, id: id, level: best.rawValue, isDownload: isDownload)
                AppLogger.success("[Netease] \(clientLabel) \(best.displayName) 获取成功（快速路径）")
                return result
            } catch PlaybackError.tokenRequired {
                throw PlaybackError.tokenRequired
            } catch {
                AppLogger.warning("[Netease] \(clientLabel) 最高可用档 \(best.displayName) 失败，回退到候选链: \(error.localizedDescription)")
            }
            // 快速路径失败则走剩余候选链
            for quality in candidates.dropFirst() {
                AppLogger.info("[Netease] \(clientLabel) 降级尝试: \(quality.displayName)")
                do {
                    let result = try await tryNeteaseLevel(client: client, id: id, level: quality.rawValue, isDownload: isDownload)
                    AppLogger.success("[Netease] \(clientLabel) \(quality.displayName) 获取成功")
                    return result
                } catch PlaybackError.tokenRequired {
                    throw PlaybackError.tokenRequired
                } catch {
                    AppLogger.debug("[Netease] \(clientLabel) \(quality.displayName) 失败，继续降级: \(error.localizedDescription)")
                }
            }
            throw PlaybackError.unavailable
        }

        // 兜底：availableInfos 查询失败时走盲试候选链
        if candidates.isEmpty {
            let fallbackQuality = preferredQuality ?? prefetchedQuality ?? .exhigh
            AppLogger.warning("[Netease] \(clientLabel) 无可用音质信息，兜底尝试: \(fallbackQuality.displayName)")
            return try await tryNeteaseLevel(client: client, id: id, level: fallbackQuality.rawValue, isDownload: isDownload)
        }

        for quality in candidates {
            AppLogger.info("[Netease] \(clientLabel) 盲试: \(quality.displayName)")
            do {
                let result = try await tryNeteaseLevel(client: client, id: id, level: quality.rawValue, isDownload: isDownload)
                AppLogger.success("[Netease] \(clientLabel) \(quality.displayName) 获取成功（盲试）")
                return result
            } catch PlaybackError.tokenRequired {
                throw PlaybackError.tokenRequired
            } catch {
                AppLogger.debug("[Netease] \(clientLabel) \(quality.displayName) 失败，继续降级: \(error.localizedDescription)")
            }
        }

        throw PlaybackError.unavailable
    }
    
    /// 尝试用指定级别获取ncm播放 URL
    private func tryNeteaseLevel(client: NCMClient, id: Int, level: String, isDownload: Bool = false) async throws -> SongUrlResult {
        let qualityLevel = NeteaseCloudMusicAPI.SoundQualityType(rawValue: level) ?? .exhigh
        
        // 如果是下载，手动在原始 URL 上添加 _download=1 标识（即便 SDK 不支持，NGINX 也能拦截到）
        var response = try await client.songUrlV1(ids: [id], level: qualityLevel)
        
        if isDownload,
           var dataArray = response.body["data"] as? [[String: Any]],
           !dataArray.isEmpty {
            for i in 0..<dataArray.count {
                if let originalUrl = dataArray[i]["url"] as? String, !originalUrl.isEmpty {
                    let separator = originalUrl.contains("?") ? "&" : "?"
                    dataArray[i]["url"] = originalUrl + separator + "_download=1"
                }
            }
            // 写回 response body
            var newBody = response.body
            newBody["data"] = dataArray
            response = APIResponse(status: response.status, body: newBody, cookies: response.cookies)
        }
        if response.status == 403,
           let msg = response.body["message"] as? String,
           msg.lowercased().contains("token") {
            throw PlaybackError.tokenRequired
        }
        if let dataArray = response.body["data"] as? [[String: Any]],
           let first = dataArray.first,
           let url = first["url"] as? String, !url.isEmpty {
            let requestedQuality = SoundQuality(rawValue: level)
            let actualQuality = (first["level"] as? String).flatMap(SoundQuality.init(rawValue:)) ?? requestedQuality

            if let requestedQuality,
               let actualQuality,
               requestedQuality != .standard,
               actualQuality != requestedQuality {
                AppLogger.debug("[Netease] 请求 \(requestedQuality.displayName) 实际返回 \(actualQuality.displayName)，继续降级尝试")
                throw PlaybackError.unavailable
            }

            return SongUrlResult(
                url: url,
                isUnblocked: false,
                actualNeteaseQuality: actualQuality
            )
        }
        throw PlaybackError.unavailable
    }
    
    /// 查询ncm歌曲可用音质（供外部预查询）
    func prefetchNeteaseQualities(id: Int) async throws -> [NeteaseSongQualityInfo] {
        var lastError: Error?
        for client in contentClientCandidates() {
            do {
                let infos = try await queryNeteaseQualities(id: id, client: client)
                if !infos.isEmpty {
                    return infos
                }
            } catch {
                lastError = error
                AppLogger.debug("[Netease] \(contentClientLabel(client)) 预查询音质失败: \(error.localizedDescription)")
            }
        }
        if let lastError {
            throw lastError
        }
        return []
    }
    
    /// 查询ncm歌曲可用音质
    private func queryNeteaseQualities(id: Int, client: NCMClient) async throws -> [NeteaseSongQualityInfo] {
        guard client.serverUrl != nil else { return [] }
        let response = try await client.songQualities(id: id)
        let body = response.body
        guard let data = body["data"] as? [String: Any],
              let qualities = data["qualities"] as? [[String: Any]] else {
            return []
        }
        return qualities.compactMap { item -> NeteaseSongQualityInfo? in
            guard let level = item["level"] as? String,
                  let quality = SoundQuality(rawValue: level) else { return nil }
            return NeteaseSongQualityInfo(
                quality: quality,
                name: item["name"] as? String ?? quality.displayName,
                bitrate: item["bitrate"] as? Int ?? 0,
                size: item["size"] as? Int ?? 0
            )
        }
    }
    
    private func buildNeteasePlaybackCandidates(
        preferred: SoundQuality?,
        prefetched: SoundQuality?,
        availableInfos: [NeteaseSongQualityInfo]?
    ) -> [SoundQuality] {
        var candidates = SoundQuality.fallbackCandidates(from: preferred)

        if let availableInfos {
            let available = Set(availableInfos.map(\.quality))
            candidates = candidates.filter { available.contains($0) }
        }

        if let prefetched,
           let index = candidates.firstIndex(of: prefetched) {
            candidates.remove(at: index)
            candidates.insert(prefetched, at: 0)
        }

        return candidates
    }
    
    /// 直接获取ncm歌曲播放 URL
    func fetchNeteaseDirectUrl(songId: Int, level: String = "exhigh") -> AnyPublisher<SongUrlResult, Error> {
        let qualityLevel = NeteaseCloudMusicAPI.SoundQualityType(rawValue: level) ?? .exhigh
        let client = contentClient
        return client.publisher { [client] in
            let urlResponse = try await client.songUrlV1(ids: [songId], level: qualityLevel)
            if let dataArray = urlResponse.body["data"] as? [[String: Any]],
               let first = dataArray.first,
               let url = first["url"] as? String, !url.isEmpty {
                return SongUrlResult(url: url, isUnblocked: true)
            }
            throw PlaybackError.unavailable
        }
    }

    // MARK: - 歌曲模糊匹配工具

    static func fuzzyMatchSong(songs: [Song], title: String, artist: String) -> Song? {
        let nTitle = normalizeSongString(title)
        let nArtist = normalizeSongString(artist)
        var bestMatch: Song?
        var bestScore: Double = 0

        for song in songs {
            let titleScore = stringSimilarity(nTitle, normalizeSongString(song.name))
            let artistScore = artist.isEmpty ? 1.0 : stringSimilarity(nArtist, normalizeSongString(song.artistName))
            let totalScore = titleScore * 0.6 + artistScore * 0.4

            if totalScore > bestScore {
                bestScore = totalScore
                bestMatch = song
            }
        }

        guard bestScore >= 0.7 else {
            AppLogger.warning("[NeteaseUnblock] 最佳匹配分数 \(String(format: "%.2f", bestScore)) 低于精准阈值 0.7")
            return nil
        }
        return bestMatch
    }

    static func normalizeSongString(_ str: String) -> String {
        str.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics
                .union(.init(charactersIn: "\u{4E00}"..."\u{9FFF}")).inverted)
            .joined()
    }

    static func stringSimilarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return a == b ? 1.0 : 0.0 }
        if a.contains(b) || b.contains(a) {
            return max(Double(min(a.count, b.count)) / Double(max(a.count, b.count)), 0.8)
        }
        let ac = Array(a), bc = Array(b)
        let m = ac.count, n = bc.count
        if Double(min(m, n)) / Double(max(m, n)) < 0.3 { return 0.2 }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m { for j in 1...n {
            dp[i][j] = ac[i-1] == bc[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
        }}
        return Double(dp[m][n] * 2) / Double(m + n)
    }

    /// 直接 POST 到 Node 后端指定路由
    static func postToBackend(serverUrl: String, route: String, params: [String: Any], cookie: String? = nil) async throws -> [String: Any] {
        let base = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
        var urlString = base + route
        if let token = SecureConfig.apiToken, !token.isEmpty {
            urlString += (urlString.contains("?") ? "&" : "?") + "\(AccessRelay.tokenQueryName)=\(token)"
        }
        // 添加设备 UUID 到 URL 参数
        urlString += (urlString.contains("?") ? "&" : "?") + "device_uuid=\(DeviceIdentifier.uuid)"

        guard let url = URL(string: urlString) else { throw PlaybackError.networkError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        // 优先使用传入的 cookie，回退到 APIService 存储的 cookie
        let effectiveCookie = cookie ?? APIService.shared.currentCookie
        if let c = effectiveCookie {
            request.setValue(c, forHTTPHeaderField: "Cookie")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        let (data, response) = try await URLSession.shared.data(for: request)
        // 校验 HTTP 状态码
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            AppLogger.error("postToBackend \(route) HTTP \(httpResponse.statusCode)")
            throw PlaybackError.networkError
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            AppLogger.error("postToBackend \(route) 响应解析失败")
            throw PlaybackError.networkError
        }
        return json
    }

    /// 将播放信息提交到 Mono 官网，换取官网短链接
    static func shortenPlayUrl(
        _ playUrl: String,
        song: Song? = nil,
        source: MusicSource? = nil,
        qqQualityRaw: String? = nil,
        qishuiQualityRaw: String? = nil
    ) -> AnyPublisher<String, Error> {
        asyncToPublisher {
            let base = SecureConfig.officialWebsiteBaseURL.hasSuffix("/")
                ? String(SecureConfig.officialWebsiteBaseURL.dropLast())
                : SecureConfig.officialWebsiteBaseURL
            guard let url = URL(string: "\(base)/api/public/play/shorten") else {
                throw URLError(.badURL)
            }

            let resolvedSource = source ?? song?.musicSource ?? .netease
            var params: [String: Any] = [
                "url": playUrl,
                "source": resolvedSource.rawValue
            ]
            if let song {
                params["songId"] = song.id
                params["name"] = song.name
                params["artistName"] = song.artistName
                params["albumName"] = song.al?.name
                params["coverUrl"] = song.coverUrl?.absoluteString
                params["duration"] = song.dt
                params["qqMid"] = song.qqMid
                params["qishuiTrackId"] = song.qishuiTrackId
            }
            params["qqQualityRaw"] = qqQualityRaw
            params["qishuiQualityRaw"] = qishuiQualityRaw

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: params)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                throw URLError(.badServerResponse)
            }

            if let url = body["url"] as? String {
                return url
            }
            if let data = body["data"] as? [String: Any],
               let url = data["url"] as? String {
                return url
            }
            if let code = body["code"] as? String {
                return "\(base)/play/\(code)"
            }
            if let data = body["data"] as? [String: Any],
               let code = data["code"] as? String {
                return "\(base)/play/\(code)"
            }
            throw URLError(.badServerResponse)
        }
    }

    func fetchSongDetails(ids: [Int]) -> AnyPublisher<[Song], Error> {
        let client = contentClient
        return client.publisher { [client] in
            let response = try await client.songDetail(ids: ids)
            guard let songsArray = response.body["songs"] as? [[String: Any]] else {
                return [Song]()
            }
            let songsData = try JSONSerialization.data(withJSONObject: songsArray)
            var songs = try JSONDecoder().decode([Song].self, from: songsData)

            if let privArray = response.body["privileges"] as? [[String: Any]] {
                let privData = try JSONSerialization.data(withJSONObject: privArray)
                let privileges = try JSONDecoder().decode([Privilege].self, from: privData)
                let privDict = Dictionary(uniqueKeysWithValues: privileges.compactMap {
                    $0.id != nil ? ($0.id!, $0) : nil
                })
                for i in 0..<songs.count {
                    if let p = privDict[songs[i].id] {
                        songs[i].privilege = p
                    }
                }
            }
            return songs
        }
    }

    // MARK: - 歌曲音质查询

    /// 查询ncm歌曲可用音质列表
    /// - Parameter id: 歌曲 ID
    /// - Returns: 歌曲支持的音质列表
    func fetchSongQualities(id: Int) -> AnyPublisher<[NeteaseSongQualityInfo], Error> {
        asyncToPublisher { [weak self] in
            guard let self = self else { return [] }
            var lastError: Error?
            for client in self.contentClientCandidates() {
                do {
                    let infos = try await self.queryNeteaseQualities(id: id, client: client)
                    if !infos.isEmpty {
                        return infos
                    }
                } catch {
                    lastError = error
                    AppLogger.debug("[Netease] \(self.contentClientLabel(client)) 音质列表获取失败: \(error.localizedDescription)")
                }
            }
            if let lastError {
                throw lastError
            }
            return []
        }
    }

    private func cookieHeader(for client: NCMClient) -> String? {
        let cookies = client.currentCookies
        if !cookies.isEmpty {
            let header = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            // NCMClient sessionManager 可能把 Set-Cookie 里的 Max-Age / Expires / Path 等属性
            // 也当作 cookie,发出去会导致网易云判定未登录
            let normalized = Self.normalizeCookieHeader(header)
            if !normalized.isEmpty {
                return normalized
            }
        }

        if client === ncm {
            return currentCookie
        }

        if let vipClient = ncmVIP, client === vipClient {
            return vipCookieHeader
        }

        return currentCookie ?? vipCookieHeader
    }

    // MARK: - 听歌打卡（上报播放记录到ncm）
    
    /// 上报听歌记录，让ncm服务端记录最近播放
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - sourceid: 来源 ID（歌单 ID），无来源传 0
    ///   - time: 播放时长（秒）
    func scrobble(id: Int, sourceid: Int = 0, time: Int = 0) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.scrobble(id: id, sourceid: sourceid, time: time)
            let code = response.body["code"] as? Int ?? 200
            return SimpleResponse(code: code, message: nil)
        }
    }

    // MARK: - 歌单广场 & 歌手

    func fetchPlaylistCategories() -> AnyPublisher<[PlaylistCategory], Error> {
        ncm.fetch([PlaylistCategory].self, keyPath: "sub") { [ncm] in
            try await ncm.playlistCatlist()
        }
    }

    func fetchHotPlaylistCategories() -> AnyPublisher<[PlaylistCategory], Error> {
        ncm.fetch([PlaylistCategory].self, keyPath: "tags") { [ncm] in
            try await ncm.playlistHot()
        }
    }

    func fetchTopPlaylists(cat: String = String(localized: "全部"), limit: Int = 30, offset: Int = 0) -> AnyPublisher<[Playlist], Error> {
        ncm.fetch([Playlist].self, keyPath: "playlists") { [ncm] in
            try await ncm.topPlaylist(cat: cat, limit: limit, offset: offset)
        }
    }

    struct ArtistListResponse: Codable {
        let artists: [ArtistInfo]
        let more: Bool
    }

    func fetchArtistList(type: Int = -1, area: Int = -1, initial: String = "-1", limit: Int = 30, offset: Int = 0) -> AnyPublisher<[ArtistInfo], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.artistList(
                area: ArtistArea(rawValue: String(area)) ?? .all,
                type: ArtistType(rawValue: String(type)) ?? .male,
                initial: initial,
                limit: limit,
                offset: offset
            )
            guard let artistsArray = response.body["artists"] as? [[String: Any]] else {
                return [ArtistInfo]()
            }
            let data = try JSONSerialization.data(withJSONObject: artistsArray)
            return try JSONDecoder().decode([ArtistInfo].self, from: data)
        }
    }

    func fetchTopArtists(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[ArtistInfo], Error> {
        ncm.fetch([ArtistInfo].self, keyPath: "artists") { [ncm] in
            try await ncm.topArtists(limit: limit, offset: offset)
        }
    }

    func searchArtists(keyword: String, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[ArtistInfo], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.cloudsearch(
                keywords: keyword,
                type: .artist,
                limit: limit,
                offset: offset
            )
            guard let result = response.body["result"] as? [String: Any],
                  let artistsArray = result["artists"] as? [[String: Any]] else {
                return [ArtistInfo]()
            }
            let data = try JSONSerialization.data(withJSONObject: artistsArray)
            return try JSONDecoder().decode([ArtistInfo].self, from: data)
        }
    }

    // MARK: - 缓存策略（保持兼容）

    enum CachePolicy {
        case networkOnly
        case returnCacheDataElseLoad
        case returnCacheDataDontLoad
        case staleWhileRevalidate
    }
}
