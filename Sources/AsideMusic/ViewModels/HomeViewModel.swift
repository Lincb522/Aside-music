import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - 单例
    static let shared = HomeViewModel()
    
    // Data Sources
    @Published var dailySongs: [Song] = []
    @Published var popularSongs: [Song] = [] // Changed to array for Carousel
    @Published var recommendPlaylists: [Playlist] = []
    // @Published var userPlaylists: [Playlist] = [] // Moved to LibraryViewModel
    @Published var recentSongs: [Song] = []
    @Published var banners: [Banner] = []
    @Published var hotSearch: String = NSLocalizedString("search_bar_placeholder", comment: "")
    @Published var userProfile: UserProfile?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private let styleManager = StyleManager.shared
    
    private init() {
        // 只订阅 GlobalRefreshManager，它会统一管理所有刷新逻辑
        // 避免多重订阅导致的重复请求
        GlobalRefreshManager.shared.refreshHomePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] forceDaily in
                self?.fetchData(forceDaily: forceDaily)
            }
            .store(in: &cancellables)
            
        // Subscribe to StyleManager
        styleManager.$currentStyle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                print("DEBUG: HomeViewModel - Style changed to: \(style?.finalName ?? "Default")")
                // When style changes, refresh daily songs immediately
                self?.fetchDailySongsOrStyle(force: true, completion: {})
            }
            .store(in: &cancellables)
        
        // NOTE: 移除了对 NotificationCenter.didLogin 和 apiService.$currentUserId 的订阅
        // 这些事件现在由 GlobalRefreshManager 统一处理，避免登录时触发多次 fetchData
    }
    
    func fetchData(forceDaily: Bool = false) {
        // Load cache first
        loadCache()
        
        // If we have a persisted style but loaded standard songs from cache, we need to force refresh
        let styleMismatch = (styleManager.currentStyle != nil)
        
        // Only show loading if we have no data
        if dailySongs.isEmpty && popularSongs.isEmpty && recommendPlaylists.isEmpty {
            isLoading = true
        }
        
        errorMessage = nil
        
        // 直接加载数据，不依赖用户登录状态
        // 后端 API 支持匿名访问，会返回公开推荐数据
        fetchAllData(forceDaily: forceDaily || styleMismatch)
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
        if let cachedProfile = cache.getObject(forKey: "user_profile_detail", type: UserProfile.self) {
            self.userProfile = cachedProfile
        }
    }
    
    private func fetchUserProfile(completion: @escaping () -> Void) {
        // First get login status to get UID
        apiService.fetchLoginStatus()
            .flatMap { [weak self] response -> AnyPublisher<APIService.UserDetailResponse, Error> in
                guard let self = self, let profile = response.data.profile else {
                    // Not logged in or no profile
                    return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
                }
                self.apiService.currentUserId = profile.userId
                // Then fetch full user detail using UID to get follows/followers/signature
                return self.apiService.fetchUserDetail(uid: profile.userId)
            }
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    print("User Profile Fetch Error: \(error)")
                    // If fetch failed but we already have a UID (e.g. from LoginViewModel), 
                    // we should still proceed to fetch content.
                    if self?.apiService.currentUserId != nil {
                        completion()
                    } else {
                        // Truly failed to get user identity, stop loading
                        self?.isLoading = false
                    }
                } else {
                    // Success case handles completion in receiveValue or implicit finish
                    // But sink's receiveCompletion is called after receiveValue
                    completion()
                }
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
        
        let checkAndMarkReady = { [weak self] in
            if dailySongsLoaded && bannersLoaded {
                self?.isLoading = false
                GlobalRefreshManager.shared.markHomeDataReady()
            }
        }
        
        // 1. Daily Songs (Smart Refresh with Style Support)
        fetchDailySongsOrStyle(force: forceDaily || dailySongs.isEmpty) { 
            dailySongsLoaded = true
            checkAndMarkReady()
        }
            
        // 2. Popular Songs (Weekly)
        apiService.fetchPopularSongs()
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.popularSongs = songs
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(songs, forKey: "popular_songs")
                    OptimizedCacheManager.shared.cacheSongs(songs)
                }
            })
            .store(in: &cancellables)
            
        // 3. Recommend Playlists (Smart Refresh)
        if forceDaily || recommendPlaylists.isEmpty {
            apiService.fetchRecommendPlaylists()
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Recommend Playlist Error: \(error)")
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
        
        // 4. Banners (不需要登录)
        apiService.fetchBanners()
            .sink(receiveCompletion: { _ in
                bannersLoaded = true
                checkAndMarkReady()
            }, receiveValue: { [weak self] banners in
                self?.banners = banners
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(banners, forKey: "banners")
                }
            })
            .store(in: &cancellables)
        
        // 5. Hot Search (不需要登录)
        apiService.fetchHotSearch()
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] items in
                if let first = items.first {
                    self?.hotSearch = first.searchWord
                }
            })
            .store(in: &cancellables)
        
        // 6. 需要登录的数据（Recent Songs, User Profile）
        if let uid = apiService.currentUserId {
            // Recent Songs
            apiService.fetchRecentSongs()
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                    self?.recentSongs = songs
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "recent_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }
                })
                .store(in: &cancellables)
            
            // User Profile
            apiService.fetchUserDetail(uid: uid)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                    self?.userProfile = response.profile
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(response.profile, forKey: "user_profile_detail")
                    }
                })
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchDailySongsOrStyle(force: Bool, completion: @escaping () -> Void = {}) {
        if !force && !dailySongs.isEmpty { 
            completion()
            return 
        }
        
        if let style = styleManager.currentStyle {
            // Fetch Style Songs
            print("HomeViewModel: Fetching songs for style: \(style.finalName)")
            apiService.fetchStyleSongs(tagId: style.finalId)
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        print("Style Songs Error: \(error)")
                    }
                    completion()
                }, receiveValue: { [weak self] songs in
                    self?.dailySongs = songs
                    // Note: We might want separate cache keys for styles, or just overwrite daily_songs
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "daily_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }
                })
                .store(in: &cancellables)
        } else {
            // Fetch Standard Daily Songs
            print("HomeViewModel: Fetching standard daily songs")
            apiService.fetchDailySongs()
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        print("Daily Songs Fetch Error: \(error)")
                    }
                    completion()
                }, receiveValue: { [weak self] songs in
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

    // MARK: - Actions
    
    func playPersonalFM() {
        apiService.fetchPersonalFM()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("FM Error: \(error)")
                }
            }, receiveValue: { songs in
                if let first = songs.first {
                    // For FM, we usually want to replace the queue or have a special mode
                    // For now, we just play the list
                    PlayerManager.shared.play(song: first, in: songs)
                }
            })
            .store(in: &cancellables)
    }
}
