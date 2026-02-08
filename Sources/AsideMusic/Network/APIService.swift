// APIService.swift
// 网易云音乐 API 服务层
// 完全基于 NeteaseCloudMusicAPI-Swift (NCMClient) 实现

import Foundation
import Combine
import NeteaseCloudMusicAPI

// MARK: - Notification Names
extension Notification.Name {
    static let didLogin = Notification.Name("AsideMusic.didLogin")
    static let didLogout = Notification.Name("AsideMusic.didLogout")
}

class APIService {
    static let shared = APIService()

    // MARK: - NCMClient 实例
    /// 网易云音乐 API 客户端（后端代理模式）
    let ncm: NCMClient

    private let cookieKey = "aside_music_cookie"
    private let userIdKey = "aside_music_uid"

    @Published var currentUserId: Int? {
        didSet {
            if let uid = currentUserId {
                UserDefaults.standard.set(uid, forKey: userIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userIdKey)
            }
            if currentUserId != nil {
                NotificationCenter.default.post(name: .didLogin, object: nil)
            } else {
                NotificationCenter.default.post(name: .didLogout, object: nil)
            }
        }
    }

    var currentCookie: String? {
        get { UserDefaults.standard.string(forKey: cookieKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: cookieKey)
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
        let serverUrl: String
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            serverUrl = envURL
        } else if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            serverUrl = plistURL
        } else {
            serverUrl = "http://114.66.31.109:3000"
        }

        let savedCookie = UserDefaults.standard.string(forKey: "aside_music_cookie")

        self.ncm = NCMClient(
            cookie: savedCookie,
            serverUrl: serverUrl
        )

        let uid = UserDefaults.standard.integer(forKey: userIdKey)
        self.currentUserId = uid == 0 ? nil : uid
        
        // 同步 isLoggedIn 标志：如果 cookie 和 uid 都存在，标记为已登录
        if savedCookie != nil && uid != 0 {
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
        }

        // 配置自动解灰：利用库内置的 autoUnblock 机制
        // songUrlV1 会自动检测不可用歌曲（无 URL、试听限制、VIP 歌曲）并通过第三方源匹配
        setupAutoUnblock()
        // 标记 APIService 已就绪，后续 UnblockSourceManager 音源变更可安全同步
        Task { @MainActor in
            UnblockSourceManager.shared.markAPIServiceReady()
        }
    }

    /// 配置 NCMClient 的自动解灰
    /// 将 UnblockSourceManager 管理的音源注入到 NCMClient
    func setupAutoUnblock() {
        // 通过 UserDefaults 直接读取，避免跨 actor 访问 SettingsManager
        let enabled: Bool
        if UserDefaults.standard.object(forKey: "unblockEnabled") == nil {
            enabled = true // 默认开启
        } else {
            enabled = UserDefaults.standard.bool(forKey: "unblockEnabled")
        }
        ncm.autoUnblock = enabled
        if enabled {
            ncm.unblockManager = UnblockSourceManager.shared.currentUnblockManager
        } else {
            ncm.unblockManager = nil
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
            self?.currentCookie = nil
            self?.currentUserId = nil
            UserDefaults.standard.removeObject(forKey: "aside_music_cookie")
            UserDefaults.standard.removeObject(forKey: "aside_music_uid")
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            NotificationCenter.default.post(name: .didLogout, object: nil)
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
            let cookie = response.cookies.isEmpty ? nil : response.cookies.joined(separator: "; ")
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
            let cookie = response.cookies.isEmpty ? nil : response.cookies.joined(separator: "; ")
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
        ncm.fetch([Playlist].self, keyPath: "playlist") { [ncm] in
            try await ncm.userPlaylist(uid: uid)
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

    func fetchArtistDetail(id: Int) -> AnyPublisher<ArtistInfo, Error> {
        ncm.fetch(ArtistInfo.self, keyPath: "data.artist") { [ncm] in
            try await ncm.artistDetail(id: id)
        }
    }

    func fetchArtistTopSongs(id: Int) -> AnyPublisher<[Song], Error> {
        ncm.fetch([Song].self, keyPath: "songs") { [ncm] in
            try await ncm.artistTopSong(id: id)
        }
    }

    func fetchPlaylistDetail(id: Int, cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil) -> AnyPublisher<Playlist, Error> {
        ncm.fetch(Playlist.self, keyPath: "playlist") { [ncm] in
            try await ncm.playlistDetail(id: id)
        }
    }

    func fetchBanners() -> AnyPublisher<[Banner], Error> {
        ncm.publisher { [ncm] in
            // NCMClient.banner() 传 clientType="iphone"，但 Node 后端 banner.js 期望 type=2（数字）
            // 后端会自己把 type 数字映射为 clientType 字符串再请求网易云
            // 这里直接用 postToBackend 传正确参数
            guard let serverUrl = ncm.serverUrl else {
                // 直连模式：直接用 NCMClient
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
                print("Personal FM: No songs found in response")
            }
            return songs
        }
        .handleEvents(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Personal FM Fetch Failed: \(error)")
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
        case unknown          // 未知错误

        var localizedDescription: String {
            switch self {
            case .unavailable:
                return "该歌曲暂无版权"
            case .networkError:
                return "网络连接失败"
            case .unknown:
                return "播放失败"
            }
        }
    }

    /// 歌曲URL结果
    struct SongUrlResult {
        let url: String
        let isUnblocked: Bool  // 是否来自第三方源（解灰）
        let source: String?    // 来源平台名称

        static func detectSource(from url: String) -> String {
            let lowered = url.lowercased()
            if lowered.contains("kuwo") { return "酷我音乐" }
            if lowered.contains("kugou") { return "酷狗音乐" }
            if lowered.contains("qq.com") || lowered.contains("qqmusic") { return "QQ音乐" }
            if lowered.contains("migu") { return "咪咕音乐" }
            if lowered.contains("bilibili") { return "哔哩哔哩" }
            if lowered.contains("youtube") || lowered.contains("ytimg") { return "YouTube" }
            if lowered.contains("pyncmd") || lowered.contains("163") { return "网易云" }
            return "第三方源"
        }
    }

    /// 获取歌曲播放URL（支持解灰）
    /// 利用库内置的 autoUnblock 机制：songUrlV1 会自动检测不可用歌曲并通过第三方源替换
    /// 如果 autoUnblock 也未能匹配，再手动走 UnblockManager 兜底
    func fetchSongUrl(id: Int, level: String = "exhigh", enableUnblock: Bool = true) -> AnyPublisher<SongUrlResult, Error> {
        let qualityLevel = NeteaseCloudMusicAPI.SoundQualityType(rawValue: level) ?? .exhigh

        // 同步解灰开关到 NCMClient
        ncm.autoUnblock = enableUnblock
        if enableUnblock {
            ncm.unblockManager = UnblockSourceManager.shared.currentUnblockManager
        }

        // songUrlV1 内部已集成 autoUnblock：
        // 无 VIP / 未登录 / 无版权 → 自动检测 needsUnblock → 调用 unblockManager.match
        let fetch = ncm.publisher { [ncm] in
            let response = try await ncm.songUrlV1(ids: [id], level: qualityLevel)
            guard let dataArray = response.body["data"] as? [[String: Any]],
                  let first = dataArray.first,
                  let url = first["url"] as? String, !url.isEmpty else {
                throw PlaybackError.unavailable
            }
            // 检测是否经过自动解灰
            let isUnblocked = first["_unblocked"] as? Bool ?? false
            let source = (first["_unblockedFrom"] as? String)
                ?? (isUnblocked ? SongUrlResult.detectSource(from: url) : nil)
            return SongUrlResult(url: url, isUnblocked: isUnblocked, source: source)
        }
        .eraseToAnyPublisher()

        if !enableUnblock {
            return fetch
        }

        // autoUnblock 未能匹配时（URL 仍为空），手动走 UnblockManager 兜底
        return fetch
            .catch { [weak self] _ -> AnyPublisher<SongUrlResult, Error> in
                guard let self = self else {
                    return Fail(error: PlaybackError.unavailable).eraseToAnyPublisher()
                }
                return self.fetchUnblockedSongUrl(id: id, quality: level)
            }
            .eraseToAnyPublisher()
    }

    /// 解灰接口 - 通过 UnblockSourceManager 管理的音源匹配
    /// 按优先级尝试所有已注册音源（用户自定义源 → 默认后端源）
    private func fetchUnblockedSongUrl(id: Int, quality: String = "320") -> AnyPublisher<SongUrlResult, Error> {
        let manager = UnblockSourceManager.shared.currentUnblockManager
        return ncm.publisher { [ncm] in

            // 先获取歌曲详情（歌名、歌手传给音源提高匹配率）
            var title: String?
            var artist: String?
            if let detailResp = try? await ncm.songDetail(ids: [id]),
               let songs = detailResp.body["songs"] as? [[String: Any]],
               let song = songs.first {
                title = song["name"] as? String
                let artists = (song["ar"] as? [[String: Any]] ?? [])
                    .compactMap { $0["name"] as? String }
                    .joined(separator: " / ")
                if !artists.isEmpty { artist = artists }
            }

            // 使用 UnblockManager 按优先级匹配
            guard let result = await manager.match(
                id: id,
                title: title,
                artist: artist,
                quality: quality
            ), !result.url.isEmpty else {
                throw PlaybackError.unavailable
            }

            let source = result.platform.isEmpty
                ? SongUrlResult.detectSource(from: result.url)
                : result.platform
            return SongUrlResult(url: result.url, isUnblocked: true, source: source)
        }
        .eraseToAnyPublisher()
    }

    /// 直接 POST 到 Node 后端指定路由（用于解灰等后端自定义接口）
    private static func postToBackend(serverUrl: String, route: String, params: [String: Any]) async throws -> [String: Any] {
        let base = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
        guard let url = URL(string: base + route) else { throw PlaybackError.networkError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let cookie = APIService.shared.currentCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    func fetchSongDetails(ids: [Int]) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.songDetail(ids: ids)
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

    func fetchTopPlaylists(cat: String = "全部", limit: Int = 30, offset: Int = 0) -> AnyPublisher<[Playlist], Error> {
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

    // MARK: - 用户

    struct UserDetailResponse: Codable {
        let profile: UserProfile
        let level: Int?
        let listenSongs: Int?
        let createTime: Int?
        let createDays: Int?
    }

    func fetchUserDetail(uid: Int) -> AnyPublisher<UserDetailResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.userDetail(uid: uid)
            // user_detail 返回 {code: 200, profile: {...}, level: 10, ...}
            // 直接从 body 中提取 profile 字段手动解码，避免非可选字段缺失导致整体解码失败
            guard let profileDict = response.body["profile"] as? [String: Any] else {
                throw NCMBridgeError.missingKey("profile")
            }
            let profileData = try JSONSerialization.data(withJSONObject: profileDict)
            let profile = try JSONDecoder().decode(UserProfile.self, from: profileData)
            return UserDetailResponse(
                profile: profile,
                level: response.body["level"] as? Int,
                listenSongs: response.body["listenSongs"] as? Int,
                createTime: response.body["createTime"] as? Int,
                createDays: response.body["createDays"] as? Int
            )
        }
    }

    struct UserUpdateResponse: Codable {
        let code: Int
    }

    func updateSignature(signature: String) -> AnyPublisher<UserUpdateResponse, Error> {
        ncm.publisher { [ncm] in
            // 先获取当前用户信息，避免覆盖其他字段
            var nickname = ""
            var gender = 0
            var birthday = 0
            var province = 0
            var city = 0
            
            let statusResp = try await ncm.loginStatus()
            // Node 后端 login_status.js 把响应包装在 data 里：{data: {code, profile, account}}
            // 直连模式下直接返回 {code, profile, account}
            let profileSource: [String: Any]?
            if let dataDict = statusResp.body["data"] as? [String: Any] {
                profileSource = dataDict["profile"] as? [String: Any]
            } else {
                profileSource = statusResp.body["profile"] as? [String: Any]
            }
            if let profile = profileSource {
                nickname = profile["nickname"] as? String ?? ""
                gender = profile["gender"] as? Int ?? 0
                birthday = profile["birthday"] as? Int ?? 0
                province = profile["province"] as? Int ?? 0
                city = profile["city"] as? Int ?? 0
            }
            
            let response = try await ncm.userUpdate(
                nickname: nickname,
                signature: signature,
                gender: gender,
                birthday: birthday,
                province: province,
                city: city
            )
            let code = response.body["code"] as? Int ?? 200
            return UserUpdateResponse(code: code)
        }
    }

    func fetchLyric(id: Int) -> AnyPublisher<LyricResponse, Error> {
        ncm.fetch(LyricResponse.self) { [ncm] in
            try await ncm.lyric(id: id)
        }
    }

    func likeSong(id: Int, like: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.like(id: id, like: like)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    struct LikedSongListResponse: Codable {
        let ids: [Int]
        let code: Int
    }

    func fetchLikedSongs(uid: Int) -> AnyPublisher<[Int], Error> {
        ncm.fetch([Int].self, keyPath: "ids") { [ncm] in
            try await ncm.likelist(uid: uid)
        }
    }

    // MARK: - 历史 & 风格

    struct HistoryDateResponse: Codable {
        let code: Int?
        let data: HistoryData?
        struct HistoryData: Codable {
            let dates: [String]?
        }
    }

    func fetchHistoryRecommendDates() -> AnyPublisher<[String], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.historyRecommendSongs()
            let dataDict = response.body["data"] as? [String: Any]
            let dates = dataDict?["dates"] as? [String] ?? []
            print("DEBUG: History API Response - code: \(response.body["code"] ?? -1), dates: \(dates.count)")
            return dates
        }
    }

    struct HistorySongsResponse: Codable {
        let code: Int?
        let data: HistorySongsData?

        struct HistorySongsData: Codable {
            let songs: [Song]?
        }
    }

    func fetchHistoryRecommendSongs(date: String) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.historyRecommendSongsDetail(date: date)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let songsArray = dataDict["songs"] as? [[String: Any]] else {
                print("DEBUG: History Songs API Response - no songs")
                return [Song]()
            }
            let songsData = try JSONSerialization.data(withJSONObject: songsArray)
            let songs = try JSONDecoder().decode([Song].self, from: songsData)
            print("DEBUG: History Songs API Response - songs count: \(songs.count)")
            return songs
        }
    }

    struct StyleListResponse: Codable {
        let code: Int
        let data: [StyleTag]?
    }

    struct StylePreferenceResponse: Codable {
        let code: Int
        let data: StylePreferenceData?

        struct StylePreferenceData: Codable {
             let tagPreference: [StyleTag]?
        }
    }

    struct StyleTag: Codable, Identifiable, Hashable {
        let tagId: Int?
        let tagName: String?
        let colorString: String?
        let rawId: Int?
        let rawName: String?

        enum CodingKeys: String, CodingKey {
            case tagId, tagName, colorString
            case rawId = "id"
            case rawName = "name"
        }

        var finalId: Int { tagId ?? rawId ?? 0 }
        var finalName: String { tagName ?? rawName ?? "Unknown" }

        var id: Int { finalId }

        init(id: String, name: String, type: Int = 0) {
            self.tagId = id.hashValue
            self.tagName = name
            self.rawId = id.hashValue
            self.rawName = name
            self.colorString = nil
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tagId = try container.decodeIfPresent(Int.self, forKey: .tagId)
            tagName = try container.decodeIfPresent(String.self, forKey: .tagName)
            colorString = try container.decodeIfPresent(String.self, forKey: .colorString)
            rawId = try container.decodeIfPresent(Int.self, forKey: .rawId)
            rawName = try container.decodeIfPresent(String.self, forKey: .rawName)
        }
    }

    func fetchStyleList() -> AnyPublisher<[StyleTag], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.styleList()
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [StyleTag]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([StyleTag].self, from: data)
        }
    }

    func fetchStylePreference() -> AnyPublisher<[StyleTag], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.stylePreference()
            guard let dataDict = response.body["data"] as? [String: Any],
                  let tagArray = dataDict["tagPreference"] as? [[String: Any]] else {
                return [StyleTag]()
            }
            let data = try JSONSerialization.data(withJSONObject: tagArray)
            return try JSONDecoder().decode([StyleTag].self, from: data)
        }
    }

    struct StyleSongResponse: Codable {
        let data: StyleSongData?
        struct StyleSongData: Codable {
            let songs: [Song]?
        }
    }

    func fetchStyleSongs(tagId: Int) -> AnyPublisher<[Song], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.styleSong(tagId: tagId)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let songsArray = dataDict["songs"] as? [[String: Any]] else {
                return [Song]()
            }
            let songsData = try JSONSerialization.data(withJSONObject: songsArray)
            return try JSONDecoder().decode([Song].self, from: songsData)
        }
    }

    // MARK: - 播客/电台接口

    func fetchDJPersonalizeRecommend(limit: Int = 6) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "data") { [ncm] in
            try await ncm.djPersonalizeRecommend(limit: limit)
        }
    }

    func fetchDJCategories() -> AnyPublisher<[RadioCategory], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djCatelist()
            guard let catsArray = response.body["categories"] as? [[String: Any]] else {
                return [RadioCategory]()
            }
            let data = try JSONSerialization.data(withJSONObject: catsArray)
            let cats = try JSONDecoder().decode([RadioCategory].self, from: data)
            print("📻 电台分类数量: \(cats.count), 名称: \(cats.map { $0.name })")
            return cats
        }
    }

    func fetchDJRecommend() -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "djRadios") { [ncm] in
            try await ncm.djRecommend()
        }
    }

    func fetchDJDetail(id: Int) -> AnyPublisher<RadioStation, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djDetail(rid: id)
            guard let dataDict = response.body["data"] as? [String: Any] ??
                  response.body["djRadio"] as? [String: Any] else {
                throw URLError(.badServerResponse)
            }
            let data = try JSONSerialization.data(withJSONObject: dataDict)
            return try JSONDecoder().decode(RadioStation.self, from: data)
        }
    }

    func fetchDJPrograms(radioId: Int, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioProgram], Error> {
        ncm.fetch([RadioProgram].self, keyPath: "programs") { [ncm] in
            try await ncm.djProgram(rid: radioId, limit: limit, offset: offset)
        }
    }

    func fetchDJCategoryHot(cateId: Int, limit: Int = 30, offset: Int = 0) -> AnyPublisher<(radios: [RadioStation], hasMore: Bool), Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djRadioHot(cateId: cateId, limit: limit, offset: offset)
            let radiosArray = response.body["djRadios"] as? [[String: Any]] ?? []
            let hasMore = response.body["hasMore"] as? Bool ?? (radiosArray.count >= limit)
            let data = try JSONSerialization.data(withJSONObject: radiosArray)
            let radios = try JSONDecoder().decode([RadioStation].self, from: data)
            print("📻 分类热门电台: cateId=\(cateId), offset=\(offset), 返回\(radios.count)条, hasMore=\(hasMore)")
            return (radios: radios, hasMore: hasMore)
        }
    }

    /// 热门电台榜（支持分页）
    func fetchDJToplist(type: String = "hot", limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "toplist") { [ncm] in
            try await ncm.djToplist(limit: limit, offset: offset)
        }
    }

    /// 热门电台（支持分页）
    func fetchDJHot(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "djRadios") { [ncm] in
            try await ncm.djHot(limit: limit, offset: offset)
        }
    }

    /// 搜索电台（cloudsearch type=1009）
    func searchDJRadio(keywords: String, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.cloudsearch(
                keywords: keywords,
                type: .dj,
                limit: limit,
                offset: offset
            )
            guard let result = response.body["result"] as? [String: Any],
                  let radiosArray = result["djRadios"] as? [[String: Any]] else {
                return [RadioStation]()
            }
            let data = try JSONSerialization.data(withJSONObject: radiosArray)
            return try JSONDecoder().decode([RadioStation].self, from: data)
        }
    }

    // MARK: - 收藏/订阅接口

    /// 获取用户订阅的播客列表
    func fetchDJSublist(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.fetch([RadioStation].self, keyPath: "djRadios") { [ncm] in
            try await ncm.djSublist(limit: limit, offset: offset)
        }
    }

    /// 订阅/取消订阅播客
    func subscribeDJ(rid: Int, subscribe: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djSub(
                rid: rid,
                action: subscribe ? .sub : .unsub
            )
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    /// 收藏/取消收藏歌单
    func subscribePlaylist(id: Int, subscribe: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.playlistSubscribe(
                id: id,
                action: subscribe ? .sub : .unsub
            )
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    /// 删除用户创建的歌单
    func deletePlaylist(id: Int) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.playlistDelete(ids: [id])
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
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
