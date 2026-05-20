import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - 单例
    static let shared = HomeViewModel()
    
    @Published var dailySongs: [Song] = []
    @Published var popularSongs: [Song] = []
    @Published var recommendPlaylists: [Playlist] = []
    @Published var recentSongs: [Song] = []
    @Published var banners: [Banner] = []
    @Published var hotSearch: String = NSLocalizedString("search_bar_placeholder", comment: "")
    @Published var userProfile: UserProfile?
    
    @Published var qqRecommendPlaylists: [Playlist] = []
    @Published var qqNewSongs: [Song] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hitokoto: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var hitokotoFetchTask: Task<Void, Never>?
    private var lastHitokotoAttempt: Date?
    private var lastHitokotoFailure: Date?
    private var lastHitokotoSuccess: Date?
    private var lastHomeHydrationAttempt: Date?
    private var lastLoginRefreshAttempt: Date?
    private var homeLoadingStartedAt: Date?
    private var pendingLoginRefresh = false
    private let apiService = APIService.shared
    private let styleManager = StyleManager.shared
    private let homeHydrationCooldown: TimeInterval = 20
    private let emptyHomeHydrationCooldown: TimeInterval = 3
    private let homeLoadingStaleTimeout: TimeInterval = 18
    private let loginRefreshCooldown: TimeInterval = 3
    
    private init() {
        // 只订阅 GlobalRefreshManager，它会统一管理所有刷新逻辑
        // 避免多重订阅导致的重复请求
        GlobalRefreshManager.shared.refreshHomePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] forceDaily in
                self?.fetchData(forceDaily: forceDaily)
            }
            .store(in: &cancellables)
            
        styleManager.$currentStyle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                AppLogger.debug("HomeViewModel - 风格切换为: \(style?.finalName ?? "Default")")
                self?.fetchDailySongsOrStyle(force: true, completion: {})
            }
            .store(in: &cancellables)

        // 登录流程会通过 GlobalRefreshManager 触发刷新，这里再兜接一次登录通知：
        // 如果首页 VM 当时已经存在，就立刻补齐首页数据；如果正在加载，则交给当前请求完成。
        NotificationCenter.default.publisher(for: .didLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleLogin()
            }
            .store(in: &cancellables)
        
        // 监听退出登录，清除数据并刷新
        NotificationCenter.default.publisher(for: .didLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleLogout()
            }
            .store(in: &cancellables)
    }
    
    func fetchData(forceDaily: Bool = false) {
        loadCache()
        
        let styleMismatch = (styleManager.currentStyle != nil)
        
        if isHomeDataEmpty && popularSongs.isEmpty {
            startHomeLoading()
        }
        
        errorMessage = nil
        
        // 直接加载数据，不依赖用户登录状态
        // 后端 API 支持匿名访问，会返回公开推荐数据
        fetchAllData(forceDaily: forceDaily || styleMismatch)
    }

    func ensureHomeDataLoaded(reason: String = "home appear") {
        loadCache()
        refreshHitokotoIfNeeded()

        guard needsHomeHydration else {
            finishHomeLoading()
            return
        }

        let clearedStaleLoading = clearStaleHomeLoadingIfNeeded(reason: reason)
        if isLoading {
            return
        }

        let now = Date()
        let cooldown = isHomeDataEmpty ? emptyHomeHydrationCooldown : homeHydrationCooldown
        if let lastHomeHydrationAttempt,
           !clearedStaleLoading,
           now.timeIntervalSince(lastHomeHydrationAttempt) < cooldown {
            return
        }

        lastHomeHydrationAttempt = now
        AppLogger.debug("HomeViewModel: 补齐首页数据 - \(reason)")
        fetchData(forceDaily: dailySongs.isEmpty)
    }

    func retryHomeDataLoad(reason: String = "home retry") {
        lastHomeHydrationAttempt = nil
        homeLoadingStartedAt = nil
        pendingLoginRefresh = false
        isLoading = false
        AppLogger.debug("HomeViewModel: 手动重试首页数据 - \(reason)")
        fetchData(forceDaily: true)
    }

    private var needsHomeHydration: Bool {
        dailySongs.isEmpty
            || banners.isEmpty
            || recommendPlaylists.isEmpty
            || qqRecommendPlaylists.isEmpty
            || qqNewSongs.isEmpty
            || shouldLoadUserProfile && userProfile == nil
    }

    private var isHomeDataEmpty: Bool {
        dailySongs.isEmpty
            && banners.isEmpty
            && recommendPlaylists.isEmpty
            && qqRecommendPlaylists.isEmpty
            && qqNewSongs.isEmpty
    }

    private var shouldLoadUserProfile: Bool {
        UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
            && OnlineAccessManager.shared.hasStoredToken
    }

    private func handleLogin() {
        let now = Date()
        if let lastLoginRefreshAttempt,
           now.timeIntervalSince(lastLoginRefreshAttempt) < loginRefreshCooldown {
            return
        }

        lastLoginRefreshAttempt = now
        lastHomeHydrationAttempt = nil

        if isLoading {
            pendingLoginRefresh = true
            AppLogger.debug("HomeViewModel: 登录后首页数据正在加载，完成后补刷")
            return
        }

        AppLogger.debug("HomeViewModel: 登录成功，自动加载首页数据")
        fetchData(forceDaily: true)
    }
    
    private func loadCache() {
        // 使用优化的缓存管理器
        let cache = OptimizedCacheManager.shared
        
        if let cachedDaily = cache.getObject(forKey: "daily_songs", type: [Song].self) {
            self.dailySongs = cachedDaily
        }
        if let cachedPopular = cache.getObject(forKey: "popular_songs", type: [Song].self) {
            self.popularSongs = cachedPopular
        }
        if let cachedRecommend = cache.getObject(forKey: "recommend_playlists", type: [Playlist].self) {
            self.recommendPlaylists = cachedRecommend
            // 同时缓存到数据库
            cache.cachePlaylists(cachedRecommend)
        }
        if let cachedRecent = cache.getObject(forKey: "recent_songs", type: [Song].self) {
            self.recentSongs = cachedRecent
        }
        if let cachedBanners = cache.getObject(forKey: "banners", type: [Banner].self) {
            self.banners = cachedBanners
        }
        if let cachedQQPlaylists = cache.getObject(forKey: "qq_recommend_playlists", type: [Playlist].self) {
            self.qqRecommendPlaylists = cachedQQPlaylists
        }
        if let cachedQQNewSongs = cache.getObject(forKey: "qq_new_songs", type: [Song].self) {
            self.qqNewSongs = cachedQQNewSongs
        }
        if let cachedProfile = cache.getObject(forKey: "user_profile_detail", type: UserProfile.self) {
            self.userProfile = cachedProfile
        }
    }

    private func startHomeLoading() {
        let startedAt = Date()
        let timeout = homeLoadingStaleTimeout
        isLoading = true
        homeLoadingStartedAt = startedAt

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            await MainActor.run {
                guard self?.homeLoadingStartedAt == startedAt else { return }
                AppLogger.warning("HomeViewModel: 首页加载超过 \(Int(timeout)) 秒，解除 loading")
                self?.finishHomeLoading()
            }
        }
    }

    private func finishHomeLoading() {
        isLoading = false
        homeLoadingStartedAt = nil
        if pendingLoginRefresh {
            pendingLoginRefresh = false
            fetchData(forceDaily: true)
        }
    }

    private func clearStaleHomeLoadingIfNeeded(reason: String) -> Bool {
        guard isLoading, let homeLoadingStartedAt else { return false }
        guard Date().timeIntervalSince(homeLoadingStartedAt) > homeLoadingStaleTimeout else { return false }

        AppLogger.warning("HomeViewModel: 首页加载超时，允许重新请求 - \(reason)")
        finishHomeLoading()
        return true
    }
    
    private func fetchUserProfile(completion: @escaping () -> Void) {
        apiService.fetchLoginStatus()
            .flatMap { [weak self] response -> AnyPublisher<APIService.UserDetailResponse, Error> in
                guard let self = self, let profile = response.data.profile else {
                    return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
                }
                self.apiService.currentUserId = profile.userId
                return self.apiService.fetchUserDetail(uid: profile.userId)
            }
            .timeout(.seconds(15), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    AppLogger.error("用户资料获取失败: \(error)")
                }
                self?.finishHomeLoading()
                completion()
            }, receiveValue: { [weak self] detailResponse in
                self?.userProfile = detailResponse.profile
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(detailResponse.profile, forKey: "user_profile_detail")
                }
            })
            .store(in: &cancellables)
    }
    
    private func fetchAllData(forceDaily: Bool) {
        // 跟踪数据加载完成状态
        var dailySongsLoaded = false
        var bannersLoaded = false
        var userProfileLoaded = !shouldLoadUserProfile
        
        fetchHitokoto()
        
        let checkAndMarkReady = { [weak self] in
            if dailySongsLoaded && bannersLoaded && userProfileLoaded {
                self?.finishHomeLoading()
                GlobalRefreshManager.shared.markHomeDataReady()
            }
        }
        
        // 每日推荐（支持风格切换）
        fetchDailySongsOrStyle(force: forceDaily || dailySongs.isEmpty) { 
            dailySongsLoaded = true
            checkAndMarkReady()
        }
            
        apiService.fetchPopularSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.popularSongs = songs
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(songs, forKey: "popular_songs")
                    OptimizedCacheManager.shared.cacheSongs(songs)
                }
            })
            .store(in: &cancellables)
            
        if forceDaily || recommendPlaylists.isEmpty || apiService.currentUserId != nil {
            apiService.fetchRecommendPlaylists()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        AppLogger.error("推荐歌单获取失败: \(error)")
                    }
                }, receiveValue: { [weak self] playlists in
                    self?.recommendPlaylists = playlists
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(playlists, forKey: "recommend_playlists")
                        OptimizedCacheManager.shared.cachePlaylists(playlists)
                    }
                })
                .store(in: &cancellables)
        }
        
        // Banner
        apiService.fetchBanners()
            .timeout(.seconds(15), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Banner 获取失败: \(error)")
                }
                bannersLoaded = true
                checkAndMarkReady()
            }, receiveValue: { [weak self] banners in
                guard !banners.isEmpty else { return }
                self?.banners = banners
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(banners, forKey: "banners")
                }
            })
            .store(in: &cancellables)
        
        // qcm推荐歌单
        apiService.fetchQQRecommendPlaylists()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("QQ推荐歌单获取失败: \(error)")
                }
            }, receiveValue: { [weak self] playlists in
                self?.qqRecommendPlaylists = playlists
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(playlists, forKey: "qq_recommend_playlists")
                }
            })
            .store(in: &cancellables)
        
        // qcm推荐新歌
        apiService.fetchQQRecommendNewSongs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("QQ推荐新歌获取失败: \(error)")
                }
            }, receiveValue: { [weak self] songs in
                self?.qqNewSongs = songs
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(songs, forKey: "qq_new_songs")
                    OptimizedCacheManager.shared.cacheSongs(songs)
                }
            })
            .store(in: &cancellables)
        
        // 热搜
        apiService.fetchHotSearch()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] items in
                if let first = items.first {
                    self?.hotSearch = first.searchWord
                }
            })
            .store(in: &cancellables)
        
        // 需要登录的数据
        if let uid = apiService.currentUserId {
            apiService.fetchRecentSongs()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                    self?.recentSongs = songs
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "recent_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }
                })
                .store(in: &cancellables)
            
            // 先尝试直接用 uid 获取用户详情
            apiService.fetchUserDetail(uid: uid)
                .timeout(.seconds(15), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completionResult in
                    if case .failure(let error) = completionResult {
                        AppLogger.warning("fetchUserDetail 失败: \(error)，尝试通过 loginStatus 获取")
                        // 降级：通过 loginStatus 获取用户信息
                        self?.fetchUserProfile {
                            userProfileLoaded = true
                            checkAndMarkReady()
                        }
                    }
                }, receiveValue: { [weak self] response in
                    self?.userProfile = response.profile
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(response.profile, forKey: "user_profile_detail")
                    }
                    userProfileLoaded = true
                    checkAndMarkReady()
                })
                .store(in: &cancellables)
        } else if shouldLoadUserProfile {
            fetchUserProfile {
                userProfileLoaded = true
                checkAndMarkReady()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchDailySongsOrStyle(force: Bool, completion: @escaping () -> Void = {}) {
        if !force && !dailySongs.isEmpty { 
            completion()
            return 
        }
        
        if let style = styleManager.currentStyle {
            AppLogger.debug("HomeViewModel: 获取风格歌曲: \(style.finalName)")
            var didReceiveSongs = false
            apiService.fetchStyleSongs(tagId: style.finalId)
                .timeout(.seconds(15), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        AppLogger.error("风格歌曲获取失败: \(error)")
                        self?.fetchFallbackDailySongs(completion: completion)
                        return
                    }

                    if !didReceiveSongs {
                        self?.fetchFallbackDailySongs(completion: completion)
                        return
                    }

                    completion()
                }, receiveValue: { [weak self] songs in
                    didReceiveSongs = !songs.isEmpty
                    self?.dailySongs = songs
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "daily_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }
                })
                .store(in: &cancellables)
        } else {
            AppLogger.debug("HomeViewModel: 获取标准每日推荐")
            var didReceiveSongs = false
            apiService.fetchDailySongs()
                .timeout(.seconds(15), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        AppLogger.error("每日推荐获取失败: \(error)")
                        self?.fetchFallbackDailySongs(completion: completion)
                        return
                    }

                    if !didReceiveSongs {
                        self?.fetchFallbackDailySongs(completion: completion)
                        return
                    }

                    completion()
                }, receiveValue: { [weak self] songs in
                    didReceiveSongs = !songs.isEmpty
                    self?.dailySongs = songs
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "daily_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }
                    
                    if !songs.isEmpty {
                        GlobalRefreshManager.shared.markDailyRefreshCompleted()
                    }
                })
                .store(in: &cancellables)
        }
    }

    private func fetchFallbackDailySongs(completion: @escaping () -> Void) {
        AppLogger.debug("HomeViewModel: 使用公开新歌兜底首页歌曲")
        apiService.fetchPopularSongs()
            .timeout(.seconds(15), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    AppLogger.error("首页歌曲兜底获取失败: \(error)")
                }
                completion()
            }, receiveValue: { [weak self] songs in
                guard !songs.isEmpty else { return }
                self?.dailySongs = songs
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(songs, forKey: "daily_songs")
                    OptimizedCacheManager.shared.cacheSongs(songs)
                }
            })
            .store(in: &cancellables)
    }

    // MARK: - Hitokoto 一言

    func refreshHitokoto(force: Bool = false, ignoresSetting: Bool = false) {
        fetchHitokoto(force: force, ignoresSetting: ignoresSetting)
    }

    private func refreshHitokotoIfNeeded() {
        guard SettingsManager.shared.hitokotoEnabled else {
            hitokoto = nil
            return
        }

        guard !hasUsableHitokoto else { return }
        refreshHitokoto()
    }

    private static let hitokotoMinimumRequestInterval: TimeInterval = 8
    private static let hitokotoFailureCooldown: TimeInterval = 10 * 60
    private static let hitokotoSuccessRefreshInterval: TimeInterval = 30 * 60

    private static let hitokotoHosts = [
        "https://v1.hitokoto.cn/"
    ]

    private struct HitokotoResponse: Decodable {
        let hitokoto: String
    }

    private func fetchHitokoto(force: Bool = false, ignoresSetting: Bool = false) {
        let settings = SettingsManager.shared
        guard ignoresSetting || settings.hitokotoEnabled else {
            hitokoto = nil
            return
        }

        let now = Date()
        if hitokotoFetchTask != nil {
            return
        }

        if !force,
           let lastHitokotoFailure,
           now.timeIntervalSince(lastHitokotoFailure) < Self.hitokotoFailureCooldown {
            return
        }

        if let lastHitokotoSuccess,
           !force,
           now.timeIntervalSince(lastHitokotoSuccess) < Self.hitokotoSuccessRefreshInterval,
           hasUsableHitokoto {
            return
        }

        if !force,
           let lastHitokotoAttempt,
           now.timeIntervalSince(lastHitokotoAttempt) < Self.hitokotoMinimumRequestInterval {
            return
        }

        lastHitokotoAttempt = now

        let type = settings.hitokotoType
        let urls = Self.hitokotoURLs(type: type)

        hitokotoFetchTask = Task { [weak self, urls] in
            var failures: [String] = []

            for url in urls {
                do {
                    let hitokotoString = try await Self.requestHitokoto(url: url)
                    await MainActor.run {
                        self?.storeHitokoto(hitokotoString)
                    }
                    return
                } catch {
                    failures.append("\(url.absoluteString): \(Self.describeHitokotoError(error))")
                    continue
                }
            }

            await MainActor.run {
                self?.handleHitokotoFailure(failures)
            }
        }
    }

    private static func hitokotoURLs(type: String) -> [URL] {
        hitokotoHosts.compactMap { host in
            guard var components = URLComponents(string: host) else { return nil }
            var queryItems = [URLQueryItem(name: "encode", value: "json")]
            if !type.isEmpty {
                queryItems.append(URLQueryItem(name: "c", value: type))
            }
            components.queryItems = queryItems
            return components.url
        }
    }

    private static func requestHitokoto(url: URL) async throws -> String {
        var lastError: Error?

        for attempt in 0..<2 {
            do {
                return try await performHitokotoRequest(url: url)
            } catch {
                lastError = error
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
            }
        }

        throw lastError ?? URLError(.cannotLoadFromNetwork)
    }

    private static func performHitokotoRequest(url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue(hitokotoUserAgent, forHTTPHeaderField: "User-Agent")
        request.networkServiceType = .responsiveData

        if #available(iOS 14.5, *) {
            request.assumesHTTP3Capable = false
        }

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = true

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }

        let responseBody: HitokotoResponse
        do {
            responseBody = try JSONDecoder().decode(HitokotoResponse.self, from: data)
        } catch {
            throw URLError(.cannotParseResponse)
        }

        let trimmed = responseBody.hitokoto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw URLError(.zeroByteResource)
        }

        return trimmed
    }

    private static var hitokotoUserAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Monologue/\(version) CFNetwork HitokotoClient"
    }

    private static func describeHitokotoError(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = ["\(nsError.domain)#\(nsError.code)", nsError.localizedDescription]

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying=\(underlying.domain)#\(underlying.code)")
            if let streamCode = underlying.userInfo["_kCFStreamErrorCodeKey"] {
                parts.append("streamCode=\(streamCode)")
            }
            if let streamDomain = underlying.userInfo["_kCFStreamErrorDomainKey"] {
                parts.append("streamDomain=\(streamDomain)")
            }
        }

        return parts.joined(separator: " ")
    }

    private var hasUsableHitokoto: Bool {
        hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func storeHitokoto(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            handleHitokotoFailure(["empty response"])
            return
        }

        hitokoto = trimmed
        let successDate = Date()
        lastHitokotoSuccess = successDate
        lastHitokotoFailure = nil
        hitokotoFetchTask = nil
    }

    private func handleHitokotoFailure(_ failures: [String]) {
        lastHitokotoFailure = Date()
        hitokotoFetchTask = nil
        if !hasUsableHitokoto {
            hitokoto = nil
        }

        let details = failures.isEmpty ? "" : "：\(failures.joined(separator: "；"))"
        AppLogger.warning("Hitokoto 暂不可用\(details)")
    }

    // MARK: - Actions
    
    /// 退出登录时清除用户相关数据
    private func handleLogout() {
        AppLogger.info("HomeViewModel: 收到退出登录通知，清除数据")
        userProfile = nil
        hitokoto = nil
        recentSongs = []
        dailySongs = []
        recommendPlaylists = []
        qqRecommendPlaylists = []
        qqNewSongs = []
        popularSongs = []
        banners = []
        hotSearch = NSLocalizedString("search_bar_placeholder", comment: "")
        
        // 清空所有缓存，防止 loadCache 恢复旧数据
        OptimizedCacheManager.shared.clearAll()
        
        // 重置数据就绪状态，确保后续加载能正确标记
        GlobalRefreshManager.shared.isHomeDataReady = false
        GlobalRefreshManager.shared.isLibraryDataReady = false
        GlobalRefreshManager.shared.isProfileDataReady = false
        
        // 重新获取公开数据（不需要登录的）
        fetchData(forceDaily: true)
    }
    
    func playPersonalFM() {
        apiService.fetchPersonalFM()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("FM 获取失败: \(error)")
                }
            }, receiveValue: { songs in
                if let first = songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: songs)
                }
            })
            .store(in: &cancellables)
    }
}
