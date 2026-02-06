import Foundation
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let didLogin = Notification.Name("AsideMusic.didLogin")
    static let didLogout = Notification.Name("AsideMusic.didLogout")
}

// Removing Alamofire dependency completely to fix build errors
class APIService {
    static let shared = APIService()
    private var baseURL: String {
        // Priority:
        // 1. Process Environment (Xcode Scheme)
        // 2. Info.plist (Injected via .env script)
        // 3. Default Fallback
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            return envURL
        }
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            return plistURL
        }
        return "http://114.66.31.109:3000"
    }
    
    // Cookie & UserID
    private let cookieKey = "aside_music_cookie"
    private let userIdKey = "aside_music_uid"
    
    // 使用 @Published 属性以便观察者能够响应变化
    @Published var currentUserId: Int? {
        didSet {
            if let uid = currentUserId {
                UserDefaults.standard.set(uid, forKey: userIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userIdKey)
            }
            
            // 发送登录状态变化通知
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
            // Cookie 变化时也触发登录状态检查
            if newValue == nil && currentUserId != nil {
                currentUserId = nil
            }
        }
    }
    
    var isLoggedIn: Bool {
        return currentCookie != nil && currentUserId != nil
    }
    
    init() {
        // 从 UserDefaults 恢复 userId
        let uid = UserDefaults.standard.integer(forKey: userIdKey)
        self.currentUserId = uid == 0 ? nil : uid
    }
    
    func logout() -> AnyPublisher<SimpleResponse, Error> {
        return fetch("/logout")
            .handleEvents(receiveOutput: { [weak self] _ in
                // 清除内存中的状态
                self?.currentCookie = nil
                self?.currentUserId = nil
                
                // 清除 UserDefaults 中保存的数据（使用正确的 key）
                UserDefaults.standard.removeObject(forKey: "aside_music_cookie")
                UserDefaults.standard.removeObject(forKey: "aside_music_uid")
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
                
                // 发送退出登录通知
                NotificationCenter.default.post(name: .didLogout, object: nil)
                
                // 清除缓存数据
                Task { @MainActor in
                    OptimizedCacheManager.shared.clearAll()
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Core Fetch Method (Native URLSession)
    
    enum CachePolicy {
        case networkOnly
        case returnCacheDataElseLoad
        case returnCacheDataDontLoad
        case staleWhileRevalidate
    }
    
    // Primary Fetch Method
    func fetch<T: Codable>(_ endpoint: String, method: String = "GET", parameters: [String: Any]? = nil, cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil, retryCount: Int = 3) -> AnyPublisher<T, Error> {
        let cacheKey = "api_\(endpoint)"
        
        // Construct URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.uppercased()
        
        // Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let cookie = currentCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        // Body / Query
        if method.uppercased() == "GET" {
            // For GET, we assume parameters are already in endpoint string for simplicity in this project,
            // or we could append them here. But current usage puts them in endpoint.
            // Special handling for Netease Cookie in query if needed
            if let cookie = currentCookie, var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                var queryItems = components.queryItems ?? []
                // Check if cookie already exists to avoid duplication
                if !queryItems.contains(where: { $0.name == "cookie" }) {
                     queryItems.append(URLQueryItem(name: "cookie", value: cookie))
                     components.queryItems = queryItems
                     if let newUrl = components.url {
                         request.url = newUrl
                     }
                }
            }
        } else if let parameters = parameters {
             request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }
        
        // Network Publisher
        let networkPublisher = URLSession.shared.dataTaskPublisher(for: request)
            .retry(retryCount) // Add Retry Logic Here
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                // Netease API sometimes returns 200 even for errors, but let's check basic status
                guard 200..<300 ~= httpResponse.statusCode else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unable to decode body"
                    print("❌ API Error [\(httpResponse.statusCode)] for \(url.absoluteString)")
                    print("❌ Response Body: \(errorBody)")
                    
                    // Try to decode error message if possible
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let msg = errorJson["msg"] as? String {
                        print("❌ API Msg: \(msg)")
                    }
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .handleEvents(receiveOutput: { value in
                // Cache Success Response (GET only)
                if method.uppercased() == "GET" {
                    CacheManager.shared.setObject(value, forKey: cacheKey, ttl: ttl)
                }
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
            
        // Helper for Async Cache Fetch
        func fetchCache() -> AnyPublisher<T?, Error> {
            return Future<T?, Error> { promise in
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = CacheManager.shared.getObject(forKey: cacheKey, type: T.self)
                    promise(.success(data))
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        }
            
        // Cache Strategy
        switch cachePolicy {
        case .networkOnly:
            return networkPublisher
            
        case .returnCacheDataElseLoad:
            return fetchCache()
                .flatMap { cachedData -> AnyPublisher<T, Error> in
                    if let data = cachedData {
                        return Just(data).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    return networkPublisher
                }
                .eraseToAnyPublisher()
            
        case .returnCacheDataDontLoad:
            return fetchCache()
                .flatMap { cachedData -> AnyPublisher<T, Error> in
                    if let data = cachedData {
                        return Just(data).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    return Fail(error: URLError(.resourceUnavailable)).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
            
        case .staleWhileRevalidate:
            return fetchCache()
                .flatMap { cachedData -> AnyPublisher<T, Error> in
                    if let data = cachedData {
                        // Return Cache THEN Network
                        let cachePub = Just(data).setFailureType(to: Error.self)
                        return cachePub.merge(with: networkPublisher).eraseToAnyPublisher()
                    }
                    return networkPublisher
                }
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Auth
    
    func fetchLoginStatus() -> AnyPublisher<LoginStatusResponse, Error> {
        return fetch("/login/status?timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    // MARK: - Login APIs
    
    func fetchQRKey() -> AnyPublisher<QRKeyResponse, Error> {
        return fetch("/login/qr/key?timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    func fetchQRCreate(key: String) -> AnyPublisher<QRCreateResponse, Error> {
        return fetch("/login/qr/create?key=\(key)&qrimg=true&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    func checkQRStatus(key: String) -> AnyPublisher<QRCheckResponse, Error> {
        return fetch("/login/qr/check?key=\(key)&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    func sendCaptcha(phone: String) -> AnyPublisher<SimpleResponse, Error> {
        return fetch("/captcha/sent?phone=\(phone)&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    func loginCellphone(phone: String, captcha: String) -> AnyPublisher<LoginResponse, Error> {
        return fetch("/login/cellphone?phone=\(phone)&captcha=\(captcha)&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    // MARK: - Home Data APIs
    
    // 1. Daily Recommend Songs (Requires Login)
    func fetchDailySongs(cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil) -> AnyPublisher<[Song], Error> {
        return fetch("/recommend/songs", cachePolicy: cachePolicy, ttl: ttl)
            .map { (response: DailySongsResponse) -> [Song] in
                return response.data.dailySongs
            }
            .eraseToAnyPublisher()
    }
    
    // 2. Recommend Playlists (Requires Login)
    func fetchRecommendPlaylists() -> AnyPublisher<[Playlist], Error> {
        return fetch("/recommend/resource")
            .map { (response: RecommendResourceResponse) -> [Playlist] in
                return response.recommend
            }
            .eraseToAnyPublisher()
    }
    
    // 3. User Playlists (Requires UID)
    func fetchUserPlaylists(uid: Int) -> AnyPublisher<[Playlist], Error> {
        return fetch("/user/playlist?uid=\(uid)")
            .map { (response: UserPlaylistResponse) -> [Playlist] in
                return response.playlist
            }
            .eraseToAnyPublisher()
    }
    
    // 4. Popular of Week (Using Personalized New Songs as proxy for "Popular")
    func fetchPopularSongs() -> AnyPublisher<[Song], Error> {
        return fetch("/personalized/newsong?limit=10")
            .map { (response: PersonalizedNewSongResponse) -> [Song] in
                return response.result.map { $0.song.toSong() }
            }
            .eraseToAnyPublisher()
    }
    
    // 5. Recent Songs (Separate List)
    func fetchRecentSongs() -> AnyPublisher<[Song], Error> {
        return fetch("/record/recent/song?limit=50")
            .map { (response: RecentSongResponse) -> [Song] in
                return response.data?.list.map { $0.data } ?? []
            }
            .eraseToAnyPublisher()
    }
    
    struct PlaylistTrackResponse: Codable {
        let songs: [Song]
        let privileges: [Privilege]?
    }
    
    // 6. Playlist Tracks
    func fetchPlaylistTracks(id: Int, limit: Int = 30, offset: Int = 0, cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil) -> AnyPublisher<[Song], Error> {
        return fetch("/playlist/track/all?id=\(id)&limit=\(limit)&offset=\(offset)", cachePolicy: cachePolicy, ttl: ttl)
            .map { (response: PlaylistTrackResponse) -> [Song] in
                var songs = response.songs
                // Merge privileges into songs
                if let privileges = response.privileges {
                    // Create a dictionary for faster lookup
                    let privDict = Dictionary(uniqueKeysWithValues: privileges.compactMap { $0.id != nil ? ($0.id!, $0) : nil })
                    
                    for i in 0..<songs.count {
                        if let p = privDict[songs[i].id] {
                            songs[i].privilege = p
                        }
                    }
                }
                return songs
            }
            .eraseToAnyPublisher()
    }
    
    // 7. Artist Detail
    func fetchArtistDetail(id: Int) -> AnyPublisher<ArtistInfo, Error> {
        return fetch("/artist/detail?id=\(id)")
            .map { (response: ArtistDetailResponse) -> ArtistInfo in
                return response.data.artist
            }
            .eraseToAnyPublisher()
    }
    
    // 8. Artist Top Songs
    func fetchArtistTopSongs(id: Int) -> AnyPublisher<[Song], Error> {
        return fetch("/artist/top/song?id=\(id)")
            .map { (response: ArtistTopSongsResponse) -> [Song] in
                return response.songs
            }
            .eraseToAnyPublisher()
    }
    
    // 9. Playlist Detail
    func fetchPlaylistDetail(id: Int, cachePolicy: CachePolicy = .networkOnly, ttl: TimeInterval? = nil) -> AnyPublisher<Playlist, Error> {
        return fetch("/playlist/detail?id=\(id)", cachePolicy: cachePolicy, ttl: ttl)
            .map { (response: PlaylistDetailResponse) -> Playlist in
                return response.playlist
            }
            .eraseToAnyPublisher()
    }
    
    // 10. Banners
    func fetchBanners() -> AnyPublisher<[Banner], Error> {
        return fetch("/banner?type=2")
            .map { (response: BannerResponse) -> [Banner] in
                return response.banners
            }
            .eraseToAnyPublisher()
    }
    
    // 11. Top Lists
    func fetchTopLists() -> AnyPublisher<[TopList], Error> {
        return fetch("/toplist/detail")
            .map { (response: TopListResponse) -> [TopList] in
                return response.list
            }
            .eraseToAnyPublisher()
    }
    
    // 12. Hot Search
    func fetchHotSearch() -> AnyPublisher<[HotSearchItem], Error> {
        return fetch("/search/hot/detail")
            .map { (response: HotSearchResponse) -> [HotSearchItem] in
                return response.data
            }
            .eraseToAnyPublisher()
    }
    
    // 13. Homepage Dragon Ball (Icons)
    func fetchDragonBalls() -> AnyPublisher<[DragonBall], Error> {
        return fetch("/homepage/dragon/ball")
            .map { (response: DragonBallResponse) -> [DragonBall] in
                return response.data
            }
            .eraseToAnyPublisher()
    }
    
    // 14. Personal FM
    func fetchPersonalFM() -> AnyPublisher<[Song], Error> {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return fetch("/personal_fm?timestamp=\(timestamp)")
            .map { (response: PersonalFMResponse) -> [Song] in
                let songs = (response.data ?? response.result ?? []).map { $0.toSong() }
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
    
    // 15. FM Trash (Dislike)
    func trashFM(id: Int, time: Int = 0) -> AnyPublisher<SimpleResponse, Error> {
        // Netease API expects 'id' for songId, and 'time' (played duration in seconds)
        // Our backend wrapper maps query.id -> songId
        return fetch("/fm_trash?id=\(id)&time=\(time)&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
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
        
        /// 从 URL 域名推断来源平台
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
    /// - Parameters:
    ///   - id: 歌曲ID
    ///   - level: 音质等级
    ///   - enableUnblock: 是否启用解灰（URL为空时自动尝试其他音源）
    func fetchSongUrl(id: Int, level: String = "exhigh", enableUnblock: Bool = true) -> AnyPublisher<SongUrlResult, Error> {
        // 先尝试正常获取
        return fetch("/song/url/v1?id=\(id)&level=\(level)")
            .tryMap { (response: SongUrlResponse) -> SongUrlResult in
                guard let url = response.data.first?.url, !url.isEmpty else {
                    throw PlaybackError.unavailable
                }
                return SongUrlResult(url: url, isUnblocked: false, source: nil)
            }
            .catch { [weak self] error -> AnyPublisher<SongUrlResult, Error> in
                guard let self = self, enableUnblock else {
                    if error is PlaybackError {
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                    return Fail(error: PlaybackError.unavailable).eraseToAnyPublisher()
                }
                // 正常获取失败，尝试解灰
                return self.fetchUnblockedSongUrl(id: id)
            }
            .eraseToAnyPublisher()
    }
    
    /// 解灰接口 - 从其他音源匹配歌曲
    /// - Parameter id: 歌曲ID
    /// - Returns: 解锁后的播放URL
    private func fetchUnblockedSongUrl(id: Int) -> AnyPublisher<SongUrlResult, Error> {
        // 方式1: 使用 /song/url/match 接口
        return fetch("/song/url/match?id=\(id)")
            .tryMap { (response: UnblockResponse) -> SongUrlResult in
                guard let url = response.data, !url.isEmpty else {
                    throw PlaybackError.unavailable
                }
                let finalUrl = response.proxyUrl?.isEmpty == false ? response.proxyUrl! : url
                let source = SongUrlResult.detectSource(from: url)
                return SongUrlResult(url: finalUrl, isUnblocked: true, source: source)
            }
            .catch { [weak self] _ -> AnyPublisher<SongUrlResult, Error> in
                guard let self = self else {
                    return Fail(error: PlaybackError.unavailable).eraseToAnyPublisher()
                }
                // 方式2: 使用 ncmget 接口作为备用
                return self.fetchNcmGetUrl(id: id)
            }
            .eraseToAnyPublisher()
    }
    
    /// NCM Get 接口 - GD音乐台备用解灰
    private func fetchNcmGetUrl(id: Int) -> AnyPublisher<SongUrlResult, Error> {
        return fetch("/song/url/ncmget?id=\(id)&br=320")
            .tryMap { (response: NcmGetResponse) -> SongUrlResult in
                guard let url = response.data?.url, !url.isEmpty else {
                    throw PlaybackError.unavailable
                }
                let finalUrl = response.data?.proxyUrl?.isEmpty == false ? response.data!.proxyUrl! : url
                let source = SongUrlResult.detectSource(from: url)
                return SongUrlResult(url: finalUrl, isUnblocked: true, source: source)
            }
            .eraseToAnyPublisher()
    }
    
    // Batch fetch song details
    func fetchSongDetails(ids: [Int]) -> AnyPublisher<[Song], Error> {
        let idsStr = ids.map { String($0) }.joined(separator: ",")
        return fetch("/song/detail?ids=\(idsStr)")
            .map { (response: PlaylistTrackResponse) -> [Song] in
                // Reuse PlaylistTrackResponse structure as it matches (songs + privileges)
                var privilegeMap: [Int: Privilege] = [:]
                if let privileges = response.privileges {
                    for priv in privileges {
                        if let id = priv.id {
                            privilegeMap[id] = priv
                        }
                    }
                }
                return response.songs.map { song in
                    var mutableSong = song
                    if let priv = privilegeMap[song.id] {
                        mutableSong.privilege = priv
                    }
                    return mutableSong
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Playlist Square & Artists
    
    // 16. Playlist Categories (All)
    func fetchPlaylistCategories() -> AnyPublisher<[PlaylistCategory], Error> {
        return fetch("/playlist/catlist")
            .map { (response: PlaylistCatlistResponse) -> [PlaylistCategory] in
                return response.sub
            }
            .eraseToAnyPublisher()
    }
    
    // 17. Hot Playlist Categories
    func fetchHotPlaylistCategories() -> AnyPublisher<[PlaylistCategory], Error> {
        return fetch("/playlist/hot")
            .map { (response: PlaylistHotCatResponse) -> [PlaylistCategory] in
                return response.tags
            }
            .eraseToAnyPublisher()
    }
    
    // 18. Top Playlists (Playlist Square)
    func fetchTopPlaylists(cat: String = "全部", limit: Int = 30, offset: Int = 0) -> AnyPublisher<[Playlist], Error> {
        // Encoding category name
        let encodedCat = cat.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cat
        return fetch("/top/playlist?cat=\(encodedCat)&limit=\(limit)&offset=\(offset)")
            .map { (response: TopPlaylistResponse) -> [Playlist] in
                return response.playlists
            }
            .eraseToAnyPublisher()
    }
    
    struct ArtistListResponse: Codable {
        let artists: [ArtistInfo]
        let more: Bool
    }
    
    // 19. Artist List (Filtered)
    func fetchArtistList(type: Int = -1, area: Int = -1, initial: String = "-1", limit: Int = 30, offset: Int = 0) -> AnyPublisher<[ArtistInfo], Error> {
        // type: -1:全部 1:男歌手 2:女歌手 3:乐队
        // area: -1:全部 7:华语 96:欧美 8:日本 16:韩国 0:其他
        // initial: -1:热门 a-z:字母
        return fetch("/artist/list?type=\(type)&area=\(area)&initial=\(initial)&limit=\(limit)&offset=\(offset)")
            .map { (response: ArtistListResponse) -> [ArtistInfo] in
                return response.artists
            }
            .eraseToAnyPublisher()
    }
    
    // 20. Top Artists (Deprecated replacement, keeping for compatibility but using list mainly)
    func fetchTopArtists(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[ArtistInfo], Error> {
        return fetch("/top/artists?limit=\(limit)&offset=\(offset)")
            .map { (response: TopArtistsResponse) -> [ArtistInfo] in
                return response.artists
            }
            .eraseToAnyPublisher()
    }
    
    // 21. Search Artists
    func searchArtists(keyword: String, limit: Int = 30, offset: Int = 0) -> AnyPublisher<[ArtistInfo], Error> {
        // type=100 for artists
        let encodedKw = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        return fetch("/search?keywords=\(encodedKw)&type=100&limit=\(limit)&offset=\(offset)")
            .map { (response: SearchArtistResponse) -> [ArtistInfo] in
                return response.result.artists ?? []
            }
            .eraseToAnyPublisher()
    }
    
    // 23. User Detail (New)
    struct UserDetailResponse: Codable {
        let profile: UserProfile
        let level: Int
        let listenSongs: Int
        let createTime: Int
        let createDays: Int
    }
    
    func fetchUserDetail(uid: Int) -> AnyPublisher<UserDetailResponse, Error> {
        return fetch("/user/detail?uid=\(uid)")
    }
    
    // 22. User Signature (Update Profile)
    struct UserUpdateResponse: Codable {
        let code: Int
    }
    
    func updateSignature(signature: String) -> AnyPublisher<UserUpdateResponse, Error> {
        // /user/update?signature=xxx
        let encodedSig = signature.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? signature
        return fetch("/user/update?signature=\(encodedSig)&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    // 24. Lyric
    func fetchLyric(id: Int) -> AnyPublisher<LyricResponse, Error> {
        return fetch("/lyric?id=\(id)")
    }
    
    // 25. Like Music
    func likeSong(id: Int, like: Bool) -> AnyPublisher<SimpleResponse, Error> {
        return fetch("/like?id=\(id)&like=\(like)&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
    }
    
    // 26. Liked Songs List (IDs)
    struct LikedSongListResponse: Codable {
        let ids: [Int]
        let code: Int
    }
    
    func fetchLikedSongs(uid: Int) -> AnyPublisher<[Int], Error> {
        return fetch("/likelist?uid=\(uid)&timestamp=\(Int(Date().timeIntervalSince1970 * 1000))")
            .map { (response: LikedSongListResponse) -> [Int] in
                return response.ids
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - History & Style
    
    // 27. History Recommend Dates
    struct HistoryDateResponse: Codable {
        let code: Int?
        let data: HistoryData?
        struct HistoryData: Codable {
            let dates: [String]?
        }
    }
    
    func fetchHistoryRecommendDates() -> AnyPublisher<[String], Error> {
        return fetch("/history/recommend/songs")
            .handleEvents(receiveOutput: { (response: HistoryDateResponse) in
                print("DEBUG: History API Response - code: \(response.code ?? -1), data: \(String(describing: response.data))")
            })
            .map { (response: HistoryDateResponse) -> [String] in
                return response.data?.dates ?? []
            }
            .eraseToAnyPublisher()
    }
    
    // 28. History Recommend Songs Detail
    struct HistorySongsResponse: Codable {
        let code: Int?
        let data: HistorySongsData?
        
        struct HistorySongsData: Codable {
            let songs: [Song]?
        }
    }
    
    func fetchHistoryRecommendSongs(date: String) -> AnyPublisher<[Song], Error> {
        return fetch("/history/recommend/songs/detail?date=\(date)")
            .handleEvents(receiveOutput: { (response: HistorySongsResponse) in
                print("DEBUG: History Songs API Response - code: \(response.code ?? -1), songs count: \(response.data?.songs?.count ?? 0)")
            })
            .map { (response: HistorySongsResponse) -> [Song] in
                return response.data?.songs ?? []
            }
            .eraseToAnyPublisher()
    }
    
    // 29. Style List & Preference
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
        
        // Unified Accessors
        var finalId: Int { tagId ?? rawId ?? 0 }
        var finalName: String { tagName ?? rawName ?? "Unknown" }
        
        // Identifiable
        var id: Int { finalId }
        
        // Manual Init
        init(id: String, name: String, type: Int = 0) {
            // Mock ID generation from string hash for non-integer IDs
            self.tagId = id.hashValue
            self.tagName = name
            self.rawId = id.hashValue
            self.rawName = name
            self.colorString = nil
        }
        
        // Standard Decoder Init
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
        return fetch("/style/list")
            .tryMap { (response: StyleListResponse) -> [StyleTag] in
                return response.data ?? []
            }
            .eraseToAnyPublisher()
    }
    
    func fetchStylePreference() -> AnyPublisher<[StyleTag], Error> {
        return fetch("/style/preference")
            .tryMap { (response: StylePreferenceResponse) -> [StyleTag] in
                // Check code if needed, usually 200
                return response.data?.tagPreference ?? []
            }
            .eraseToAnyPublisher()
    }
    
    // 30. Style Songs
    struct StyleSongResponse: Codable {
        let data: StyleSongData?
        struct StyleSongData: Codable {
            let songs: [Song]?
        }
    }
    
    func fetchStyleSongs(tagId: Int) -> AnyPublisher<[Song], Error> {
        return fetch("/style/song?tagId=\(tagId)")
            .map { (response: StyleSongResponse) -> [Song] in
                return response.data?.songs ?? []
            }
            .eraseToAnyPublisher()
    }
}
