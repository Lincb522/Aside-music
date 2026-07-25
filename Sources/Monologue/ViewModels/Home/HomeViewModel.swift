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
    @Published private(set) var homeContentRevision = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var hitokotoFetchTask: Task<Void, Never>?
    private var hitokotoRequestGeneration = 0
    private var lastHitokotoAttempt: Date?
    private var lastHitokotoFailure: Date?
    private var lastHitokotoSuccess: Date?
    private var lastHomeHydrationAttempt: Date?
    private var homeRefreshStartedAt: Date?
    private var isHomeRefreshInFlight = false
    private var lastLoginRefreshAttempt: Date?
    private var homeLoadingStartedAt: Date?
    private var pendingLoginRefresh = false
    private var isRestoringLoginState = false
    private var emptyHomeRetryTask: Task<Void, Never>?
    private var emptyHomeAutomaticRetryCount = 0
    private var lastHomeContentFingerprint = ""
    private let apiService = APIService.shared
    private let styleManager = StyleManager.shared
    private let homeHydrationCooldown: TimeInterval = 20
    private let emptyHomeHydrationCooldown: TimeInterval = 3
    private let automaticHomeRefreshInterval: TimeInterval = 10 * 60
    private let homeRefreshStaleTimeout: TimeInterval = 40
    private let homeLoadingStaleTimeout: TimeInterval = 18
    private let loginRefreshCooldown: TimeInterval = 3
    private let maxEmptyHomeAutomaticRetryCount = 6
    private let emptyHomeBaseRetryDelay: TimeInterval = 1.6
    private static let userProfileBackupKey = "monologue_user_profile_backup"
    private static let lastSuccessfulHomeRefreshKey = "monologue_home_last_successful_refresh"
    
    private init() {
        primeInitialHomeState()

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

        OnlineAccessManager.shared.$lastTokenStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard OnlineAccessManager.shared.canUseOnlineFeatures else { return }
                self?.lastHomeHydrationAttempt = nil
                self?.ensureHomeDataLoaded(reason: "online access refreshed")
            }
            .store(in: &cancellables)

        OptimizedCacheManager.shared.$preloadStage
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stage in
                guard stage == .complete else { return }
                self?.reloadHomeCacheIfUseful(reason: "cache preload completed")
            }
            .store(in: &cancellables)

        OptimizedCacheManager.shared.$isDailySongsReady
            .combineLatest(OptimizedCacheManager.shared.$isPlaylistsReady)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDailySongsReady, isPlaylistsReady in
                guard isDailySongsReady || isPlaylistsReady else { return }
                self?.reloadHomeCacheIfUseful(reason: "cache ready flags updated")
            }
            .store(in: &cancellables)

        GlobalRefreshManager.shared.$isHomeDataReady
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                guard isReady else { return }
                self?.reloadHomeCacheIfUseful(reason: "global home data ready")
                self?.publishHomeContentChange(reason: "global home data ready")
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

    private func primeInitialHomeState() {
        loadCache()
        if SettingsManager.shared.hitokotoEnabled {
            _ = restoreCachedHitokotoForCurrentSettings()
        } else {
            hitokoto = nil
        }
        restoreLoginStateIfNeeded(reason: "home init")
    }
    
    func fetchData(forceDaily: Bool = false) {
        clearStaleHomeRefreshIfNeeded(reason: "direct fetch")
        guard !isHomeRefreshInFlight else {
            AppLogger.debug("HomeViewModel: 首页刷新请求正在进行，跳过重复请求")
            return
        }

        isHomeRefreshInFlight = true
        homeRefreshStartedAt = Date()
        scheduleHomeRefreshWatchdog(startedAt: homeRefreshStartedAt)

        loadCache()
        restoreLoginStateIfNeeded(reason: "home fetch")
        
        let styleMismatch = (styleManager.currentStyle != nil)
        
        if isHomeDataEmpty {
            startHomeLoading()
        }
        
        errorMessage = nil
        
        // 直接加载数据，不依赖用户登录状态
        // 后端 API 支持匿名访问，会返回公开推荐数据
        fetchAllData(forceDaily: forceDaily || styleMismatch)
    }

    func ensureHomeDataLoaded(reason: String = "home appear") {
        if needsHomeHydration {
            loadCache()
        }
        refreshHitokotoIfNeeded()
        restoreLoginStateIfNeeded(reason: reason)

        let clearedStaleLoading = clearStaleHomeLoadingIfNeeded(reason: reason)
        let clearedStaleRefresh = clearStaleHomeRefreshIfNeeded(reason: reason)
        if isHomeRefreshInFlight {
            return
        }

        let now = Date()
        let needsAutomaticRefresh = shouldAutomaticallyRefreshHome(at: now)
        guard needsHomeHydration || needsAutomaticRefresh else {
            finishHomeLoading()
            return
        }

        let cooldown = isHomeDataEmpty ? emptyHomeHydrationCooldown : homeHydrationCooldown
        if let lastHomeHydrationAttempt,
           !clearedStaleLoading,
           !clearedStaleRefresh,
           now.timeIntervalSince(lastHomeHydrationAttempt) < cooldown {
            scheduleEmptyHomeRetryIfNeeded(reason: "\(reason) cooldown")
            return
        }

        lastHomeHydrationAttempt = now
        let forceRefresh = needsAutomaticRefresh || dailySongs.isEmpty
        AppLogger.debug(
            "HomeViewModel: 自动刷新首页 - \(reason) force=\(forceRefresh) hydration=\(needsHomeHydration)"
        )
        fetchData(forceDaily: forceRefresh)
    }

    func retryHomeDataLoad(reason: String = "home retry", resetsEmptyRecovery: Bool = true) {
        clearStaleHomeRefreshIfNeeded(reason: reason)
        guard !isHomeRefreshInFlight else {
            AppLogger.debug("HomeViewModel: 首页正在刷新，忽略重复的手动刷新 - \(reason)")
            return
        }

        emptyHomeRetryTask?.cancel()
        emptyHomeRetryTask = nil
        if resetsEmptyRecovery {
            emptyHomeAutomaticRetryCount = 0
        }
        lastHomeHydrationAttempt = nil
        homeLoadingStartedAt = nil
        pendingLoginRefresh = false
        isLoading = false
        loadCache()
        refreshHitokotoIfNeeded()
        restoreLoginStateIfNeeded(reason: reason)
        AppLogger.debug("HomeViewModel: 手动重试首页数据 - \(reason)")
        fetchData(forceDaily: true)
    }

    func reloadHomeCacheIfUseful(reason: String) {
        let before = homeContentFingerprint
        loadCache()
        refreshHitokotoIfNeeded()

        if before != homeContentFingerprint {
            AppLogger.debug("HomeViewModel: 从缓存同步首页内容 - \(reason)")
        }

        if isHomeDataEmpty {
            scheduleEmptyHomeRetryIfNeeded(reason: "\(reason) empty after cache sync")
        } else {
            finishHomeLoading()
        }
    }

    func reloadHomeCacheForVisibleHomeIfNeeded(reason: String) {
        guard needsHomeHydration || isHomeDataEmpty else { return }
        reloadHomeCacheIfUseful(reason: reason)
    }

    func refreshThemeSensitiveHomeState(reason: String) {
        emptyHomeRetryTask?.cancel()
        emptyHomeRetryTask = nil
        emptyHomeAutomaticRetryCount = 0
        lastHomeHydrationAttempt = nil
        homeLoadingStartedAt = nil
        pendingLoginRefresh = false

        loadCache()
        if SettingsManager.shared.hitokotoEnabled {
            if hasUsableHitokoto {
                refreshHitokoto()
            } else {
                lastHitokotoAttempt = nil
                lastHitokotoFailure = nil
                refreshHitokoto(force: true)
            }
        }
        restoreLoginStateIfNeeded(reason: reason)
        ensureHomeDataLoaded(reason: reason)
        publishHomeContentChange(reason: reason)
        AppLogger.debug("[HomeThemeRefresh] reason=\(reason) themeId=\(SettingsManager.shared.globalThemeId.rawValue) hitokotoReady=\(hasUsableHitokoto) homeEmpty=\(isHomeDataEmpty)")
    }

    private var needsHomeHydration: Bool {
        dailySongs.isEmpty
            || banners.isEmpty
            || recommendPlaylists.isEmpty
            || qqRecommendPlaylists.isEmpty
            || qqNewSongs.isEmpty
            || shouldLoadUserProfile && userProfile == nil
    }

    var hasDisplayableHomeContent: Bool {
        !isHomeDataEmpty
    }

    private var isHomeDataEmpty: Bool {
        dailySongs.isEmpty
            && popularSongs.isEmpty
            && banners.isEmpty
            && recommendPlaylists.isEmpty
            && qqRecommendPlaylists.isEmpty
            && qqNewSongs.isEmpty
    }

    private var shouldLoadUserProfile: Bool {
        (UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.isLoggedIn)
            || apiService.currentCookie != nil
            || apiService.currentUserId != nil)
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

        if isLoading || isHomeRefreshInFlight {
            pendingLoginRefresh = true
            AppLogger.debug("HomeViewModel: 登录后首页数据正在加载，完成后补刷")
            return
        }

        AppLogger.debug("HomeViewModel: 登录成功，自动加载首页数据")
        fetchData(forceDaily: true)
    }

    private func restoreLoginStateIfNeeded(reason: String) {
        guard OnlineAccessManager.shared.hasStoredToken else { return }
        guard apiService.currentCookie != nil else { return }
        guard apiService.currentUserId == nil || userProfile == nil else { return }
        guard !isRestoringLoginState else { return }

        isRestoringLoginState = true
        AppLogger.debug("HomeViewModel: 尝试恢复登录态 - \(reason)")

        apiService.fetchLoginStatus()
            .timeout(.seconds(12), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isRestoringLoginState = false
                if case .failure(let error) = result {
                    AppLogger.warning("HomeViewModel: 登录态恢复失败: \(error)")
                }
            }, receiveValue: { [weak self] response in
                guard let self else { return }
                guard let profile = response.data.profile else { return }

                self.applyUserProfile(profile, reason: "login state restored")
                UserDefaults.standard.set(true, forKey: AppConfig.StorageKeys.isLoggedIn)
                self.lastHomeHydrationAttempt = nil
                self.fetchData(forceDaily: true)
            })
            .store(in: &cancellables)
    }
    
    private func loadCache() {
        // 使用优化的缓存管理器
        let cache = OptimizedCacheManager.shared
        
        if let cachedDaily = cache.getObject(forKey: "daily_songs", type: [Song].self) {
            assignIfIdentityChanged(cachedDaily, to: &dailySongs) { $0.id }
        }
        if let cachedPopular = cache.getObject(forKey: "popular_songs", type: [Song].self) {
            assignIfIdentityChanged(cachedPopular, to: &popularSongs) { $0.id }
        }
        if let cachedRecommend = cache.getObject(forKey: "recommend_playlists", type: [Playlist].self) {
            assignIfIdentityChanged(cachedRecommend, to: &recommendPlaylists) { $0.id }
        }
        if let cachedRecent = cache.getObject(forKey: "recent_songs", type: [Song].self) {
            assignIfIdentityChanged(cachedRecent, to: &recentSongs) { $0.id }
        }
        if let cachedBanners = cache.getObject(forKey: "banners", type: [Banner].self) {
            assignIfIdentityChanged(cachedBanners, to: &banners) { $0.id }
        }
        if let cachedQQPlaylists = cache.getObject(forKey: "qq_recommend_playlists", type: [Playlist].self) {
            assignIfIdentityChanged(cachedQQPlaylists, to: &qqRecommendPlaylists) { $0.id }
        }
        if let cachedQQNewSongs = cache.getObject(forKey: "qq_new_songs", type: [Song].self) {
            assignIfIdentityChanged(cachedQQNewSongs, to: &qqNewSongs) { $0.id }
        }
        if let cachedProfile = cache.getObject(forKey: "user_profile_detail", type: UserProfile.self) ?? restoreUserProfileBackup() {
            if userProfile != cachedProfile {
                userProfile = cachedProfile
                storeUserProfileBackup(cachedProfile)
            }
        }
        if !isHomeDataEmpty {
            markHomeDataArrived(reason: "cache load")
        }
    }

    private func assignIfIdentityChanged<Element, ID: Equatable>(
        _ cached: [Element],
        to target: inout [Element],
        id: (Element) -> ID
    ) {
        guard !hasSameIdentity(target, cached, id: id) else { return }
        target = cached
    }

    private func hasSameIdentity<Element, ID: Equatable>(
        _ lhs: [Element],
        _ rhs: [Element],
        id: (Element) -> ID
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { id($0) == id($1) }
    }

    private func applyUserProfile(_ profile: UserProfile, reason: String) {
        if apiService.currentUserId != profile.userId {
            apiService.currentUserId = profile.userId
        }
        userProfile = profile
        OptimizedCacheManager.shared.setObject(profile, forKey: "user_profile_detail")
        storeUserProfileBackup(profile)
        AppLogger.debug("HomeViewModel: 用户资料已同步 - \(reason) - \(profile.nickname)")
    }

    private func restoreUserProfileBackup() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.userProfileBackupKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    private func storeUserProfileBackup(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.userProfileBackupKey)
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
            guard !isHomeRefreshInFlight else { return }
            pendingLoginRefresh = false
            fetchData(forceDaily: true)
            return
        }

        if isHomeDataEmpty {
            scheduleEmptyHomeRetryIfNeeded(reason: "home loading finished empty")
        } else {
            markHomeDataArrived(reason: "home loading finished")
        }
    }

    private func markHomeDataArrived(reason: String = "home data arrived") {
        emptyHomeAutomaticRetryCount = 0
        emptyHomeRetryTask?.cancel()
        emptyHomeRetryTask = nil
        publishHomeContentChange(reason: reason)
    }

    private func markRemoteHomeDataArrived(reason: String) {
        UserDefaults.standard.set(Date(), forKey: Self.lastSuccessfulHomeRefreshKey)
        markHomeDataArrived(reason: reason)
    }

    private func shouldAutomaticallyRefreshHome(at now: Date) -> Bool {
        guard !isHomeDataEmpty else { return true }
        guard let lastRefresh = UserDefaults.standard.object(
            forKey: Self.lastSuccessfulHomeRefreshKey
        ) as? Date else {
            return true
        }

        if !Calendar.current.isDate(lastRefresh, inSameDayAs: now) {
            return true
        }

        return now.timeIntervalSince(lastRefresh) >= automaticHomeRefreshInterval
    }

    private func completeHomeRefresh() {
        isHomeRefreshInFlight = false
        homeRefreshStartedAt = nil
    }

    @discardableResult
    private func clearStaleHomeRefreshIfNeeded(reason: String) -> Bool {
        guard isHomeRefreshInFlight, let homeRefreshStartedAt else { return false }
        guard Date().timeIntervalSince(homeRefreshStartedAt) > homeRefreshStaleTimeout else {
            return false
        }

        AppLogger.warning("HomeViewModel: 首页刷新超时，允许重新请求 - \(reason)")
        completeHomeRefresh()
        return true
    }

    private func scheduleHomeRefreshWatchdog(startedAt: Date?) {
        guard let startedAt else { return }
        let timeout = homeRefreshStaleTimeout

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            await MainActor.run {
                guard self?.homeRefreshStartedAt == startedAt else { return }
                AppLogger.warning("HomeViewModel: 首页刷新超过 \(Int(timeout)) 秒，解除请求锁")
                self?.completeHomeRefresh()
                self?.finishHomeLoading()
            }
        }
    }

    private func publishHomeContentChange(reason: String) {
        let fingerprint = homeContentFingerprint
        guard fingerprint != lastHomeContentFingerprint else { return }
        lastHomeContentFingerprint = fingerprint
        homeContentRevision += 1
        AppLogger.debug("HomeViewModel: 首页内容版本 \(homeContentRevision) - \(reason) - \(fingerprint)")
    }

    private var homeContentFingerprint: String {
        [
            homeContentPart("daily", count: dailySongs.count, first: dailySongs.first?.id, last: dailySongs.last?.id),
            homeContentPart("popular", count: popularSongs.count, first: popularSongs.first?.id, last: popularSongs.last?.id),
            homeContentPart("banner", count: banners.count, first: banners.first?.id, last: banners.last?.id),
            homeContentPart("ncm-playlist", count: recommendPlaylists.count, first: recommendPlaylists.first?.id, last: recommendPlaylists.last?.id),
            homeContentPart("qq-playlist", count: qqRecommendPlaylists.count, first: qqRecommendPlaylists.first?.id, last: qqRecommendPlaylists.last?.id),
            homeContentPart("qq-song", count: qqNewSongs.count, first: qqNewSongs.first?.id, last: qqNewSongs.last?.id),
        ].joined(separator: "|")
    }

    private func homeContentPart<ID>(_ name: String, count: Int, first: ID?, last: ID?) -> String {
        let firstValue = first.map { String(describing: $0) } ?? "nil"
        let lastValue = last.map { String(describing: $0) } ?? "nil"
        return "\(name)-\(count)-\(firstValue)-\(lastValue)"
    }

    private func scheduleEmptyHomeRetryIfNeeded(reason: String) {
        guard isHomeDataEmpty, !isLoading else { return }
        guard emptyHomeAutomaticRetryCount < maxEmptyHomeAutomaticRetryCount else { return }
        guard emptyHomeRetryTask == nil else { return }

        let nextAttempt = emptyHomeAutomaticRetryCount + 1
        let delay = min(10, emptyHomeBaseRetryDelay * Double(nextAttempt))
        emptyHomeRetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                self.emptyHomeRetryTask = nil
                guard self.isHomeDataEmpty, !self.isLoading else { return }
                self.emptyHomeAutomaticRetryCount = nextAttempt
                AppLogger.warning("HomeViewModel: 首页空数据自动恢复第 \(nextAttempt) 次 - \(reason)")
                self.retryHomeDataLoad(
                    reason: "\(reason) auto recovery \(nextAttempt)",
                    resetsEmptyRecovery: false
                )
            }
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
            .receive(on: DispatchQueue.main)
            .flatMap { [weak self] response -> AnyPublisher<APIService.UserDetailResponse, Error> in
                guard let self = self, let profile = response.data.profile else {
                    return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
                }
                self.applyUserProfile(profile, reason: "login status fallback")
                return self.apiService.fetchUserDetail(uid: profile.userId)
            }
            .timeout(.seconds(15), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    if self?.userProfile == nil {
                        AppLogger.error("用户资料获取失败: \(error)")
                    } else {
                        AppLogger.warning("用户详情获取失败，已使用 loginStatus 资料: \(error)")
                    }
                }
                self?.finishHomeLoading()
                completion()
            }, receiveValue: { [weak self] detailResponse in
                self?.applyUserProfile(detailResponse.profile, reason: "user detail")
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
                self?.completeHomeRefresh()
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
                if !songs.isEmpty {
                    self?.markRemoteHomeDataArrived(reason: "popular songs")
                }
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
                    if !playlists.isEmpty {
                        self?.markRemoteHomeDataArrived(reason: "recommend playlists")
                    }
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
                self?.markRemoteHomeDataArrived(reason: "banners")
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
                if !playlists.isEmpty {
                    self?.markRemoteHomeDataArrived(reason: "qq recommend playlists")
                }
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
                if !songs.isEmpty {
                    self?.markRemoteHomeDataArrived(reason: "qq new songs")
                }
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
                    self?.applyUserProfile(response.profile, reason: "current user detail")
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
                    if !songs.isEmpty {
                        self?.markRemoteHomeDataArrived(reason: "style daily songs")
                    }
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "daily_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }

                    if !songs.isEmpty {
                        GlobalRefreshManager.shared.markDailyRefreshCompleted(for: .home)
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
                    if !songs.isEmpty {
                        self?.markRemoteHomeDataArrived(reason: "daily songs")
                    }
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "daily_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }
                    
                    if !songs.isEmpty {
                        GlobalRefreshManager.shared.markDailyRefreshCompleted(for: .home)
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
                self?.markRemoteHomeDataArrived(reason: "fallback daily songs")
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
    private static let hitokotoFailureCooldown: TimeInterval = 30
    private static let hitokotoCachePrefix = "monologue_hitokoto_cache"

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

        let type = settings.hitokotoType
        let cacheKey = Self.hitokotoCacheKey(type: type)
        if !hasUsableHitokoto {
            _ = restoreCachedHitokotoForCurrentSettings()
        }

        let now = Date()
        if let hitokotoFetchTask {
            if force {
                hitokotoFetchTask.cancel()
                self.hitokotoFetchTask = nil
                lastHitokotoAttempt = nil
                lastHitokotoFailure = nil
                AppLogger.debug("[DailyQuote] cancelPending themeId=\(settings.globalThemeId.rawValue) cacheKey=\(cacheKey)")
            } else {
                AppLogger.debug("[DailyQuote] skipPending themeId=\(settings.globalThemeId.rawValue) cacheKey=\(cacheKey)")
                return
            }
        }

        if !force,
           let lastHitokotoFailure,
           now.timeIntervalSince(lastHitokotoFailure) < Self.hitokotoFailureCooldown {
            if !hasUsableHitokoto {
                _ = restoreCachedHitokotoForCurrentSettings()
            }
            return
        }

        if !force,
           let lastHitokotoAttempt,
           now.timeIntervalSince(lastHitokotoAttempt) < Self.hitokotoMinimumRequestInterval {
            return
        }

        lastHitokotoAttempt = now

        let urls = Self.hitokotoURLs(type: type)
        hitokotoRequestGeneration &+= 1
        let requestGeneration = hitokotoRequestGeneration
        let requestThemeId = settings.globalThemeId.rawValue
        AppLogger.debug("[DailyQuote] request themeId=\(requestThemeId) cacheKey=\(cacheKey) force=\(force) generation=\(requestGeneration)")

        hitokotoFetchTask = Task { [weak self, urls, cacheKey, requestGeneration, requestThemeId] in
            var failures: [String] = []

            for url in urls {
                if Task.isCancelled {
                    await MainActor.run {
                        self?.handleHitokotoCancellation(generation: requestGeneration, themeId: requestThemeId, cacheKey: cacheKey)
                    }
                    return
                }

                do {
                    let hitokotoString = try await Self.requestHitokoto(url: url)
                    await MainActor.run {
                        self?.storeHitokoto(hitokotoString, generation: requestGeneration)
                    }
                    return
                } catch {
                    if Task.isCancelled {
                        await MainActor.run {
                            self?.handleHitokotoCancellation(generation: requestGeneration, themeId: requestThemeId, cacheKey: cacheKey)
                        }
                        return
                    }
                    failures.append("\(url.absoluteString): \(Self.describeHitokotoError(error))")
                    continue
                }
            }

            await MainActor.run {
                self?.handleHitokotoFailure(failures, generation: requestGeneration)
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
            queryItems.append(URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000))))
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

    @discardableResult
    private func restoreCachedHitokotoForCurrentSettings() -> Bool {
        let type = SettingsManager.shared.hitokotoType
        if restoreCachedHitokoto(type: type) {
            return true
        }

        guard !type.isEmpty else { return false }
        return restoreCachedHitokoto(type: "")
    }

    @discardableResult
    private func restoreCachedHitokoto(type: String) -> Bool {
        guard !hasUsableHitokoto else { return false }

        let key = Self.hitokotoCacheKey(type: type)
        guard let cached = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !cached.isEmpty else {
            return false
        }

        hitokoto = cached
        AppLogger.debug("[DailyQuote] cacheHit themeId=\(SettingsManager.shared.globalThemeId.rawValue) cacheKey=\(key)")
        return true
    }

    private static func hitokotoCacheKey(type: String) -> String {
        let suffix = type.isEmpty ? "all" : type
        return "\(hitokotoCachePrefix)_\(suffix)"
    }

    private func storeHitokoto(_ text: String, generation: Int? = nil) {
        if let generation, generation != hitokotoRequestGeneration {
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            handleHitokotoFailure(["empty response"], generation: generation)
            return
        }

        hitokoto = trimmed
        let cacheKey = Self.hitokotoCacheKey(type: SettingsManager.shared.hitokotoType)
        UserDefaults.standard.set(trimmed, forKey: cacheKey)
        let successDate = Date()
        lastHitokotoSuccess = successDate
        lastHitokotoFailure = nil
        hitokotoFetchTask = nil
        AppLogger.debug("[DailyQuote] store themeId=\(SettingsManager.shared.globalThemeId.rawValue) cacheKey=\(cacheKey)")
    }

    private func handleHitokotoCancellation(generation: Int, themeId: String, cacheKey: String) {
        guard generation == hitokotoRequestGeneration else { return }
        hitokotoFetchTask = nil
        AppLogger.debug("[DailyQuote] cancelled themeId=\(themeId) cacheKey=\(cacheKey) generation=\(generation)")
    }

    private func handleHitokotoFailure(_ failures: [String], generation: Int? = nil) {
        if let generation, generation != hitokotoRequestGeneration {
            return
        }

        lastHitokotoFailure = Date()
        hitokotoFetchTask = nil
        if !hasUsableHitokoto {
            _ = restoreCachedHitokotoForCurrentSettings()
        }

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
        emptyHomeRetryTask?.cancel()
        emptyHomeRetryTask = nil
        emptyHomeAutomaticRetryCount = 0
        completeHomeRefresh()
        userProfile = nil
        hitokoto = nil
        UserDefaults.standard.removeObject(forKey: Self.userProfileBackupKey)
        UserDefaults.standard.removeObject(forKey: Self.lastSuccessfulHomeRefreshKey)
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
