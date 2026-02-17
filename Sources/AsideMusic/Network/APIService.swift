// APIService.swift
// 网易云音乐 API 服务层
// 完全基于 NeteaseCloudMusicAPI-Swift (NCMClient) 实现

import Foundation
import Combine
import NeteaseCloudMusicAPI
import QQMusicKit

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
    
    /// 解灰管理器
    private let _unblockManager = UnblockManager()

    private let cookieKey = "aside_music_cookie"
    private let userIdKey = "aside_music_uid"

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
        print("[APIService] init - cookie: \(savedCookie != nil ? "有(\(savedCookie!.prefix(30))...)" : "无"), uid: \(savedUid?.description ?? "无")")
        #endif

        self.ncm = NCMClient(
            cookie: savedCookie,
            serverUrl: serverUrl
        )

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

        // 配置解灰：保留 SDK 层 UnblockManager（备用），主要解灰逻辑在 fetchSongUrl 中 app 层处理
        _unblockManager.register(SearchUnblockSource(serverUrl: "http://114.66.31.109:4000"))
        ncm.unblockManager = _unblockManager
        
        // 关闭 SDK 自动解灰（解灰逻辑已移到 app 层 fetchSongUrl）
        ncm.autoUnblock = false
        
        // 初始化 QQ 音乐客户端（使用默认地址）
        let qqURL = URL(string: SecureConfig.qqMusicBaseURL)!
        QQMusicClient.configure(baseURL: qqURL, timeout: 30, maxRetries: 1)
    }
    
    /// 迁移：将 UserDefaults 中的 cookie/uid 迁移到 Keychain
    /// 如果 Keychain 为空且 UserDefaults 有值，始终尝试迁移
    private static func migrateToKeychainIfNeeded() {
        // 迁移 cookie：如果 Keychain 没有但 UserDefaults 有，就迁移
        if KeychainHelper.loadString(key: "aside_music_cookie") == nil,
           let oldCookie = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.cookie) {
            #if DEBUG
            print("[APIService] 迁移 cookie 到 Keychain")
            #endif
            KeychainHelper.save(key: "aside_music_cookie", value: oldCookie)
            if KeychainHelper.loadString(key: "aside_music_cookie") != nil {
                UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.cookie)
            }
        }
        
        // 迁移 uid：如果 Keychain 没有但 UserDefaults 有，就迁移
        if KeychainHelper.loadInt(key: "aside_music_uid") == nil {
            let oldUid = UserDefaults.standard.integer(forKey: AppConfig.StorageKeys.userId)
            if oldUid != 0 {
                #if DEBUG
                print("[APIService] 迁移 uid=\(oldUid) 到 Keychain")
                #endif
                KeychainHelper.save(key: "aside_music_uid", intValue: oldUid)
                if KeychainHelper.loadInt(key: "aside_music_uid") != nil {
                    UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.userId)
                }
            }
        }
    }
    
    /// 动态切换解灰开关
    func setUnblockEnabled(_ enabled: Bool) {
        ncm.autoUnblock = enabled
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
            KeychainHelper.delete(key: "aside_music_cookie")
            KeychainHelper.delete(key: "aside_music_uid")
            UserDefaults.standard.set(false, forKey: AppConfig.StorageKeys.isLoggedIn)
            
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
            // 加 timestamp 绕过后端 2 分钟缓存，确保收藏后能立即刷新
            try await ncm.userPlaylist(uid: uid, limit: 1000, timestamp: Int(Date().timeIntervalSince1970 * 1000))
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
        /// 是否来自解灰源（酷狗）
        let isUnblocked: Bool
    }

    /// 搜索解灰源（app 层直接调用，不走 SDK 解灰流程）
    private let searchUnblockSource = SearchUnblockSource(serverUrl: "http://114.66.31.109:4000")
    
    /// 获取歌曲播放URL
    /// 优先走网易云官方，不可用时 app 层直接调搜索解灰源（:4000）
    func fetchSongUrl(id: Int, level: String = "exhigh", kugouQuality: String = "320") -> AnyPublisher<SongUrlResult, Error> {
        let qualityLevel = NeteaseCloudMusicAPI.SoundQualityType(rawValue: level) ?? .exhigh

        return ncm.publisher { [ncm] in
            let response = try await ncm.songUrlV1(ids: [id], level: qualityLevel)
            if let dataArray = response.body["data"] as? [[String: Any]],
               let first = dataArray.first,
               let url = first["url"] as? String, !url.isEmpty {
                return SongUrlResult(url: url, isUnblocked: false)
            }
            // 官方不可用，返回空标记
            return SongUrlResult(url: "", isUnblocked: false)
        }
        .flatMap { [weak self] result -> AnyPublisher<SongUrlResult, Error> in
            if !result.url.isEmpty {
                return Just(result).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            // 官方不可用，走搜索解灰源（直接用酷狗音质）
            guard let self = self else {
                return Fail(error: PlaybackError.unavailable).eraseToAnyPublisher()
            }
            return self.fetchSongUrlFromSearch(id: id, kugouQuality: kugouQuality)
        }
        .eraseToAnyPublisher()
    }
    
    /// 通过搜索解灰源获取播放 URL（先拿歌曲详情再搜索）
    private func fetchSongUrlFromSearch(id: Int, kugouQuality: String) -> AnyPublisher<SongUrlResult, Error> {
        // 先获取歌曲详情（歌名、歌手），再用关键词搜索
        return fetchSongDetails(ids: [id])
            .flatMap { [weak self] songs -> AnyPublisher<SongUrlResult, Error> in
                guard let self = self else {
                    return Fail(error: PlaybackError.unavailable).eraseToAnyPublisher()
                }
                let song = songs.first
                let title = song?.name
                let artist = song?.artistName
                
                return Future<SongUrlResult, Error> { promise in
                    Task {
                        do {
                            let result = try await self.searchUnblockSource.match(
                                id: id, title: title, artist: artist, quality: kugouQuality
                            )
                            if !result.url.isEmpty {
                                AppLogger.info("搜索解灰成功: \(title ?? "") - \(artist ?? "")")
                                promise(.success(SongUrlResult(url: result.url, isUnblocked: true)))
                            } else {
                                AppLogger.warning("搜索解灰无结果: \(title ?? "")")
                                promise(.failure(PlaybackError.unavailable))
                            }
                        } catch {
                            AppLogger.error("搜索解灰失败: \(error)")
                            promise(.failure(PlaybackError.unavailable))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// 直接 POST 到 Node 后端指定路由
    static func postToBackend(serverUrl: String, route: String, params: [String: Any]) async throws -> [String: Any] {
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

    /// 将真实播放 URL 提交给后端，换取短链接
    static func shortenPlayUrl(_ playUrl: String) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            Task {
                do {
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
                        promise(.success("\(base)/play/\(code)"))
                    } else {
                        promise(.failure(URLError(.badServerResponse)))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
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

    // MARK: - 听歌打卡（上报播放记录到网易云）
    
    /// 上报听歌记录，让网易云服务端记录最近播放
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

    // MARK: - 缓存策略（保持兼容）

    enum CachePolicy {
        case networkOnly
        case returnCacheDataElseLoad
        case returnCacheDataDontLoad
        case staleWhileRevalidate
    }
}
