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
    var hasVIPCookie: Bool { ncmVIP != nil }
    
    private let cookieKey = "monologue_music_cookie"
    private let userIdKey = "monologue_music_uid"

    @Published var currentUserId: Int? {
        didSet {
            if let uid = currentUserId {
                KeychainHelper.save(key: userIdKey, intValue: uid)
            } else {
                KeychainHelper.delete(key: userIdKey)
            }
            if currentUserId != nil {
                NotificationCenter.default.post(name: .didLogin, object: nil)
            } else {
                NotificationCenter.default.post(name: .didLogout, object: nil)
            }
        }
    }

    var currentCookie: String? {
        get { KeychainHelper.loadString(key: cookieKey) }
        set {
            if let value = newValue {
                KeychainHelper.save(key: cookieKey, value: value)
            } else {
                KeychainHelper.delete(key: cookieKey)
            }
            if let cookie = newValue {
                ncm.setCookie(cookie)
            }
            if newValue == nil && currentUserId != nil {
                currentUserId = nil
            }
        }
    }

    var isLoggedIn: Bool {
        return currentCookie != nil && currentUserId != nil
    }

    init() {
        let serverUrl = SecureConfig.apiBaseURL

        // 从 UserDefaults 迁移到 Keychain（一次性迁移）
        Self.migrateToKeychainIfNeeded()

        let savedCookie = KeychainHelper.loadString(key: cookieKey)
        let savedUid = KeychainHelper.loadInt(key: userIdKey)
        
        #if DEBUG
        print("[APIService] init - cookie: \(savedCookie.map { String(localized: "有(\($0.prefix(30))...)") } ?? String(localized: "无")), uid: \(savedUid?.description ?? String(localized: "无"))")
        #endif

        self.ncm = NCMClient(
            cookie: savedCookie,
            serverUrl: serverUrl
        )
        ncm.apiToken = SecureConfig.apiToken
        
        if let vipCookie = SecureConfig.vipCookie {
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
    func verifyToken() async -> TokenStatus {
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
        components.queryItems = [
            URLQueryItem(name: AccessRelay.tokenQueryName, value: token),
            URLQueryItem(name: "device_uuid", value: DeviceIdentifier.uuid)
        ]

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
                   let message = json["message"] as? String,
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
                #if DEBUG
                print("[APIService] VIP 状态检测失败: \(error)")
                #endif
            }
        }
    }

    // MARK: - 登出

    func logout() -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.logout()
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
        .handleEvents(receiveOutput: { [weak self] _ in
            // 清除 Keychain 中的凭证
            KeychainHelper.delete(key: "monologue_music_cookie")
            KeychainHelper.delete(key: "monologue_music_uid")
            UserDefaults.standard.set(false, forKey: AppConfig.StorageKeys.isLoggedIn)
            
            // 重置 VIP 状态（登出后 contentClient 自动回退到 ncmVIP）
            self?.isCurrentUserVIP = false
            
            // 直接设置内部状态，避免通过 didSet 重复发送通知
            // currentCookie 的 setter 会触发 currentUserId = nil，
            // currentUserId 的 didSet 会发送 .didLogout 通知
            self?.currentCookie = nil
            // currentUserId 此时已经被 currentCookie setter 设为 nil，无需再设置
            
            Task { @MainActor in
                OptimizedCacheManager.shared.clearAll()
            }
        })
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
        ncm.fetch([Song].self, keyPath: "data.dailySongs") { [ncm] in
            try await ncm.recommendSongs()
        }
    }

    func fetchRecommendPlaylists() -> AnyPublisher<[Playlist], Error> {
        ncm.fetch([Playlist].self, keyPath: "recommend") { [ncm] in
            try await ncm.recommendResource()
        }
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
                        return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
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
            guard let serverUrl = ncm.serverUrl else {
                let resp = try await ncm.banner(type: .iphone)
                guard let arr = resp.body["banners"] as? [[String: Any]] else { return [Banner]() }
                let data = try JSONSerialization.data(withJSONObject: arr)
                return try JSONDecoder().decode([Banner].self, from: data)
            }
            let body = try await Self.postToBackend(serverUrl: serverUrl, route: "/banner", params: ["type": 2])
            guard let arr = body["banners"] as? [[String: Any]] else { return [Banner]() }
            let data = try JSONSerialization.data(withJSONObject: arr)
            return try JSONDecoder().decode([Banner].self, from: data)
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
    func fetchSongUrl(id: Int, level: String? = nil, prefetchedLevel: String? = nil, skipUnblock: Bool = false) -> AnyPublisher<SongUrlResult, Error> {
        return asyncToPublisher { [weak self] in
            guard let self = self else { throw PlaybackError.unavailable }
            if await MainActor.run(body: { OnlineAccessManager.shared.lastTokenStatus }) == .expired {
                throw PlaybackError.tokenExpired
            }
            if await MainActor.run(body: { OnlineAccessManager.shared.lastTokenStatus }) == .missing {
                throw PlaybackError.tokenRequired
            }
            let client = self.contentClient

            let preferredQuality = level.flatMap(SoundQuality.init(rawValue:))
            let prefetchedQuality = prefetchedLevel.flatMap(SoundQuality.init(rawValue:))
            let availableInfos: [NeteaseSongQualityInfo]?

            do {
                let infos = try await self.queryNeteaseQualities(id: id, client: client)
                availableInfos = infos
                if !infos.isEmpty {
                    AppLogger.info("[Netease] 可用音质: \(infos.map(\.quality.displayName).joined(separator: " > "))")
                }
            } catch {
                availableInfos = nil
                AppLogger.warning("[Netease] 音质查询失败，按回退链盲试: \(error.localizedDescription)")
            }

            let candidates = self.buildNeteasePlaybackCandidates(
                preferred: preferredQuality,
                prefetched: prefetchedQuality,
                availableInfos: availableInfos
            )

            if candidates.isEmpty {
                let fallbackQuality = preferredQuality ?? prefetchedQuality ?? .exhigh
                AppLogger.warning("[Netease] 无可用音质信息，兜底尝试: \(fallbackQuality.displayName)")
                return try await self.tryNeteaseLevel(client: client, id: id, level: fallbackQuality.rawValue)
            }

            for quality in candidates {
                AppLogger.info("[Netease] 尝试: \(quality.displayName)")
                do {
                    let result = try await self.tryNeteaseLevel(client: client, id: id, level: quality.rawValue)
                    AppLogger.success("[Netease] \(quality.displayName) 获取成功")
                    return result
                } catch PlaybackError.tokenRequired {
                    throw PlaybackError.tokenRequired
                } catch {
                    AppLogger.debug("[Netease] \(quality.displayName) 失败，继续降级: \(error.localizedDescription)")
                }
            }

            throw PlaybackError.unavailable
        }
    }
    
    /// 尝试用指定级别获取ncm播放 URL
    private func tryNeteaseLevel(client: NCMClient, id: Int, level: String) async throws -> SongUrlResult {
        let qualityLevel = NeteaseCloudMusicAPI.SoundQualityType(rawValue: level) ?? .exhigh
        let response = try await client.songUrlV1(ids: [id], level: qualityLevel)
        if response.status == 403,
           let msg = response.body["message"] as? String,
           msg.lowercased().contains("token") {
            throw PlaybackError.tokenRequired
        }
        if let dataArray = response.body["data"] as? [[String: Any]],
           let first = dataArray.first,
           let url = first["url"] as? String, !url.isEmpty {
            return SongUrlResult(
                url: url,
                isUnblocked: false,
                actualNeteaseQuality: SoundQuality(rawValue: level)
            )
        }
        throw PlaybackError.unavailable
    }
    
    /// 查询ncm歌曲可用音质（供外部预查询）
    func prefetchNeteaseQualities(id: Int) async throws -> [NeteaseSongQualityInfo] {
        try await queryNeteaseQualities(id: id, client: contentClient)
    }
    
    /// 查询ncm歌曲可用音质
    private func queryNeteaseQualities(id: Int, client: NCMClient) async throws -> [NeteaseSongQualityInfo] {
        guard let serverUrl = ncm.serverUrl else { return [] }
        let body = try await Self.postToBackend(
            serverUrl: serverUrl,
            route: "/song/qualities",
            params: ["id": id],
            cookie: cookieHeader(for: client)
        )
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

    /// 将真实播放 URL 提交给后端，换取短链接
    static func shortenPlayUrl(_ playUrl: String) -> AnyPublisher<String, Error> {
        asyncToPublisher {
            let base = SecureConfig.apiBaseURL.hasSuffix("/")
                ? String(SecureConfig.apiBaseURL.dropLast())
                : SecureConfig.apiBaseURL
            let body = try await postToBackend(
                serverUrl: SecureConfig.apiBaseURL,
                route: "/play/shorten",
                params: ["url": playUrl]
            )
            if let data = body["data"] as? [String: Any],
               let code = data["code"] as? String {
                return "\(base)/play/\(code)"
            } else {
                throw URLError(.badServerResponse)
            }
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
            return try await self.queryNeteaseQualities(id: id, client: self.contentClient)
        }
    }

    private func cookieHeader(for client: NCMClient) -> String? {
        let cookies = client.currentCookies
        if !cookies.isEmpty {
            return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        }

        if client === ncm {
            return currentCookie
        }

        if let vipClient = ncmVIP, client === vipClient {
            return SecureConfig.vipCookie
        }

        return currentCookie ?? SecureConfig.vipCookie
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
