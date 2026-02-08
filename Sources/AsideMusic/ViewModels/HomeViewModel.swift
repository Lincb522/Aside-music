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
            
        styleManager.$currentStyle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                print("DEBUG: HomeViewModel - Style changed to: \(style?.finalName ?? "Default")")
                self?.fetchDailySongsOrStyle(force: true, completion: {})
            }
            .store(in: &cancellables)
        
        // NOTE: 移除了对 NotificationCenter.didLogin 和 apiService.$currentUserId 的订阅
        // 这些事件现在由 GlobalRefreshManager 统一处理，避免登录时触发多次 fetchData
    }
    
    func fetchData(forceDaily: Bool = false) {
        loadCache()
        
        let styleMismatch = (styleManager.currentStyle != nil)
        
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
        apiService.fetchLoginStatus()
            .flatMap { [weak self] response -> AnyPublisher<APIService.UserDetailResponse, Error> in
                guard let self = self, let profile = response.data.profile else {
                    return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
                }
                self.apiService.currentUserId = profile.userId
                return self.apiService.fetchUserDetail(uid: profile.userId)
            }
            .sink(receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    print("User Profile Fetch Error: \(error)")
                    if self?.apiService.currentUserId != nil {
                        completion()
                    } else {
                        self?.isLoading = false
                    }
                } else {
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
        var userProfileLoaded = apiService.currentUserId == nil // 未登录时直接标记完成
        
        let checkAndMarkReady = { [weak self] in
            if dailySongsLoaded && bannersLoaded && userProfileLoaded {
                self?.isLoading = false
                GlobalRefreshManager.shared.markHomeDataReady()
            }
        }
        
        // 每日推荐（支持风格切换）
        fetchDailySongsOrStyle(force: forceDaily || dailySongs.isEmpty) { 
            dailySongsLoaded = true
            checkAndMarkReady()
        }
            
        apiService.fetchPopularSongs()
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.popularSongs = songs
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(songs, forKey: "popular_songs")
                    OptimizedCacheManager.shared.cacheSongs(songs)
                }
            })
            .store(in: &cancellables)
            
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
        
        // Banner
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
        
        // 热搜
        apiService.fetchHotSearch()
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] items in
                if let first = items.first {
                    self?.hotSearch = first.searchWord
                }
            })
            .store(in: &cancellables)
        
        // 需要登录的数据
        if let uid = apiService.currentUserId {
            apiService.fetchRecentSongs()
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
                .sink(receiveCompletion: { [weak self] completionResult in
                    if case .failure(let error) = completionResult {
                        print("⚠️ fetchUserDetail 失败: \(error)，尝试通过 loginStatus 获取")
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
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchDailySongsOrStyle(force: Bool, completion: @escaping () -> Void = {}) {
        if !force && !dailySongs.isEmpty { 
            completion()
            return 
        }
        
        if let style = styleManager.currentStyle {
            print("HomeViewModel: Fetching songs for style: \(style.finalName)")
            apiService.fetchStyleSongs(tagId: style.finalId)
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        print("Style Songs Error: \(error)")
                    }
                    completion()
                }, receiveValue: { [weak self] songs in
                    self?.dailySongs = songs
                    Task { @MainActor in
                        OptimizedCacheManager.shared.setObject(songs, forKey: "daily_songs")
                        OptimizedCacheManager.shared.cacheSongs(songs)
                    }
                })
                .store(in: &cancellables)
        } else {
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
                    PlayerManager.shared.play(song: first, in: songs)
                }
            })
            .store(in: &cancellables)
    }
}
