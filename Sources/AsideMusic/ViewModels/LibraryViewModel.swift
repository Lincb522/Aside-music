import SwiftUI
import Combine

// MARK: - LibraryViewModel (extracted from LibraryView.swift)

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()

    enum LibraryTab: String, CaseIterable {
        case my = "My Library"
        case square = "Playlists"
        case artists = "Artists"
        case charts = "Charts"

        var localizedKey: LocalizedStringKey {
            switch self {
            case .my: return "tab_library"
            case .square: return "lib_tab_playlists"
            case .artists: return "lib_tab_artists"
            case .charts: return "lib_tab_charts"
            }
        }
    }

    enum NavigationDestination: Hashable {
        case playlist(Playlist)
        case artist(Int)
        case artistInfo(ArtistInfo)
        case radioDetail(Int)
        case localPlaylist(String)

        func hash(into hasher: inout Hasher) {
            switch self {
            case .playlist(let p): hasher.combine("p_\(p.id)")
            case .artist(let id): hasher.combine("a_\(id)")
            case .artistInfo(let a): hasher.combine("a_\(a.id)")
            case .radioDetail(let id): hasher.combine("r_\(id)")
            case .localPlaylist(let id): hasher.combine("lp_\(id)")
            }
        }

        static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
            switch (lhs, rhs) {
            case (.playlist(let l), .playlist(let r)): return l.id == r.id
            case (.artist(let l), .artist(let r)): return l == r
            case (.artistInfo(let l), .artistInfo(let r)): return l.id == r.id
            case (.radioDetail(let l), .radioDetail(let r)): return l == r
            case (.localPlaylist(let l), .localPlaylist(let r)): return l == r
            default: return false
            }
        }
    }

    @Published var currentTab: LibraryTab = .my

    @Published var userPlaylists: [Playlist] = []

    @Published var squarePlaylists: [Playlist] = []
    @Published var playlistCategories: [PlaylistCategory] = []
    @Published var selectedCategory: String = NSLocalizedString("filter_all", comment: "")
    @Published var squareOffset: Int = 0
    @Published var hasMoreSquarePlaylists: Bool = true
    @Published var isLoadingMoreSquare: Bool = false
    @Published var isLoadingSquare: Bool = false

    // MARK: - Artists

    @Published var topArtists: [ArtistInfo] = []
    @Published var artistOffset: Int = 0
    @Published var hasMoreArtists: Bool = true
    @Published var isLoadingArtists: Bool = false

    // MARK: - Charts

    @Published var topLists: [TopList] = []

    @Published var artistArea: Int = -1
    @Published var artistType: Int = -1
    @Published var artistInitial: String = "-1"
    @Published var artistSearchText: String = ""
    @Published var isSearchingArtists = false

    let artistAreas: [(name: String, value: Int)] = [
        ("filter_all", -1), ("filter_chinese", 7), ("filter_western", 96), ("filter_japanese", 8), ("filter_korean", 16), ("filter_others", 0)
    ]
    let artistTypes: [(name: String, value: Int)] = [
        ("filter_all", -1), ("filter_male", 1), ("filter_female", 2), ("filter_band", 3)
    ]
    let artistInitials: [String] = ["-1"] + (65...90).map { String(UnicodeScalar($0)) } + ["#"]

    @Published var isLoadingCharts: Bool = false
    @Published var isLoading = false // 保留用于兼容，但不再使用

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    init() {
        // 订阅 GlobalRefreshManager 的刷新事件
        GlobalRefreshManager.shared.refreshLibraryPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] force in
                self?.fetchPlaylists(force: force)
            }
            .store(in: &cancellables)
        
        // 监听退出登录，清除用户歌单数据
        NotificationCenter.default.publisher(for: .didLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleLogout()
            }
            .store(in: &cancellables)

        fetchPlaylists()

        $artistSearchText
            .dropFirst()
            .debounce(for: .milliseconds(AppConfig.UI.searchDebounceMs), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                if !text.isEmpty {
                    self?.searchArtists(keyword: text)
                } else {
                    self?.fetchArtistData(reset: true)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - My Library
    
    /// 退出登录时清除用户相关数据
    private func handleLogout() {
        AppLogger.info("LibraryViewModel: 收到退出登录通知，清除数据")
        userPlaylists = []
        squarePlaylists = []
        topArtists = []
        topLists = []
    }

    func fetchPlaylists(force: Bool = false) {
        // 使用优化的缓存管理器加载缓存
        if userPlaylists.isEmpty {
            if let cachedUser = OptimizedCacheManager.shared.getObject(forKey: "user_playlists", type: [Playlist].self) {
                self.userPlaylists = cachedUser
            }
        }

        if !force && !userPlaylists.isEmpty {
            GlobalRefreshManager.shared.markLibraryDataReady()
            return
        }

        guard let uid = apiService.currentUserId else {
            #if DEBUG
            print("[Library] fetchPlaylists: currentUserId 为 nil，跳过")
            #endif
            GlobalRefreshManager.shared.markLibraryDataReady()
            return
        }

        #if DEBUG
        print("[Library] fetchPlaylists: uid=\(uid), force=\(force)")
        #endif

        // force 刷新时直接加载歌单，不需要重新验证登录状态
        if force {
            // 服务端数据可能有短暂延迟，等待 0.5 秒再请求
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadUserPlaylists(uid: uid)
            }
            return
        }

        apiService.fetchLoginStatus()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    #if DEBUG
                    print("[Library] fetchLoginStatus 失败: \(error)，使用已有 uid=\(uid) 加载歌单")
                    #endif
                    // 即使登录状态检查失败，也尝试用已有 uid 加载歌单
                    self?.loadUserPlaylists(uid: uid)
                }
            }, receiveValue: { [weak self] response in
                if let profile = response.data.profile {
                    self?.apiService.currentUserId = profile.userId
                    self?.loadUserPlaylists(uid: profile.userId)
                } else {
                    #if DEBUG
                    print("[Library] fetchLoginStatus 返回 profile 为 nil，使用已有 uid=\(uid) 加载歌单")
                    #endif
                    // profile 为 nil 但 uid 存在，仍然尝试加载歌单
                    self?.loadUserPlaylists(uid: uid)
                }
            })
            .store(in: &cancellables)
    }

    private func loadUserPlaylists(uid: Int) {
        #if DEBUG
        print("[Library] loadUserPlaylists: uid=\(uid)")
        #endif
        apiService.fetchUserPlaylists(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("歌单获取失败: \(error)")
                    #if DEBUG
                    print("[Library] ❌ 歌单获取失败: \(error)")
                    #endif
                }
                GlobalRefreshManager.shared.markLibraryDataReady()
            }, receiveValue: { [weak self] playlists in
                #if DEBUG
                print("[Library] ✅ 获取到 \(playlists.count) 个歌单")
                #endif
                // 过滤掉系统临时歌单（如 test_audit_tmp）
                let filtered = playlists.filter { !$0.name.hasPrefix("test_audit") && $0.name != "test_audit_tmp" }
                self?.userPlaylists = filtered
                // 初始化歌单收藏状态
                SubscriptionManager.shared.updatePlaylistSubscriptions(from: playlists, userId: uid)
                // 使用优化的缓存管理器
                OptimizedCacheManager.shared.setObject(playlists, forKey: "user_playlists")
                OptimizedCacheManager.shared.cachePlaylists(playlists)
            })
            .store(in: &cancellables)
    }

    // MARK: - Playlist Square

    func fetchSquareData() {
        if playlistCategories.isEmpty {
            if let cachedCats = OptimizedCacheManager.shared.getObject(forKey: "playlist_categories", type: [PlaylistCategory].self) {
                self.playlistCategories = cachedCats
            }

            if playlistCategories.isEmpty {
                apiService.fetchHotPlaylistCategories()
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] tags in
                        var allTags = [PlaylistCategory(name: NSLocalizedString("filter_all", comment: ""), id: -1, category: -1, hot: true)]
                        allTags.append(contentsOf: tags)
                        self?.playlistCategories = allTags
                        OptimizedCacheManager.shared.setObject(allTags, forKey: "playlist_categories")
                    })
                    .store(in: &cancellables)
            }
        }

        if squarePlaylists.isEmpty {
            loadSquarePlaylists(cat: selectedCategory, reset: true)
        }
    }

    func loadSquarePlaylists(cat: String, reset: Bool = false) {
        if reset {
            isLoadingSquare = true
            squareOffset = 0
            hasMoreSquarePlaylists = true
            squarePlaylists = []

            let cacheKey = "square_playlists_\(cat)"
            if let cached = OptimizedCacheManager.shared.getObject(forKey: cacheKey, type: [Playlist].self) {
                self.squarePlaylists = cached
                self.isLoadingSquare = false
                self.squareOffset = cached.count
            }
        } else {
            if isLoadingMoreSquare || !hasMoreSquarePlaylists { return }
            isLoadingMoreSquare = true
        }

        let limit = 30
        let offset = reset ? 0 : squareOffset

        apiService.fetchTopPlaylists(cat: cat, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingSquare = false
                self?.isLoadingMoreSquare = false
            }, receiveValue: { [weak self] playlists in
                guard let self = self else { return }

                if reset {
                    self.squarePlaylists = playlists
                    OptimizedCacheManager.shared.setObject(playlists, forKey: "square_playlists_\(cat)")
                } else {
                    // 去重：过滤掉已存在的歌单
                    let existingIds = Set(self.squarePlaylists.map { $0.id })
                    let newPlaylists = playlists.filter { !existingIds.contains($0.id) }
                    self.squarePlaylists.append(contentsOf: newPlaylists)
                }

                self.squareOffset += playlists.count
                self.hasMoreSquarePlaylists = playlists.count >= limit
            })
            .store(in: &cancellables)
    }

    func loadMoreSquarePlaylists() {
        loadSquarePlaylists(cat: selectedCategory, reset: false)
    }

    // MARK: - Artists

    func fetchArtistData(reset: Bool = false) {
        if reset {
            topArtists = []
            artistOffset = 0
            hasMoreArtists = true
            isLoadingArtists = false
        }

        if !artistSearchText.isEmpty {
            return
        }

        if topArtists.isEmpty && artistOffset == 0 {
            let cacheKey = "artists_\(artistArea)_\(artistType)_\(artistInitial)_0"
            if let cached = OptimizedCacheManager.shared.getObject(forKey: cacheKey, type: [ArtistInfo].self) {
                self.topArtists = cached
                if !cached.isEmpty {
                    self.isLoadingArtists = false
                    self.artistOffset = cached.count
                    return
                }
            }
        }

        if isLoadingArtists || !hasMoreArtists {
            return
        }

        isLoadingArtists = true
        isSearchingArtists = false

        let limit = 30
        let offset = artistOffset

        apiService.fetchArtistList(type: artistType, area: artistArea, initial: artistInitial, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingArtists = false
            }, receiveValue: { [weak self] artists in
                guard let self = self else { return }
                if offset == 0 {
                    self.topArtists = artists
                    let cacheKey = "artists_\(self.artistArea)_\(self.artistType)_\(self.artistInitial)_0"
                    OptimizedCacheManager.shared.setObject(artists, forKey: cacheKey)
                } else {
                    // 去重：过滤掉已存在的艺术家
                    let existingIds = Set(self.topArtists.map { $0.id })
                    let newArtists = artists.filter { !existingIds.contains($0.id) }
                    self.topArtists.append(contentsOf: newArtists)
                }
                self.hasMoreArtists = artists.count >= limit
                self.artistOffset += artists.count
            })
            .store(in: &cancellables)
    }

    func loadMoreArtists() {
        fetchArtistData(reset: false)
    }

    func searchArtists(keyword: String) {
        isLoadingArtists = true
        isSearchingArtists = true

        apiService.searchArtists(keyword: keyword)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingArtists = false
            }, receiveValue: { [weak self] artists in
                self?.topArtists = artists
            })
            .store(in: &cancellables)
    }

    // MARK: - Charts

    func fetchTopLists() {
        if !topLists.isEmpty { return }

        if let cached = OptimizedCacheManager.shared.getObject(forKey: "top_charts_lists", type: [TopList].self) {
            self.topLists = cached
        }

        if !topLists.isEmpty { return }

        isLoadingCharts = true

        apiService.fetchTopLists()
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingCharts = false
            }, receiveValue: { [weak self] lists in
                self?.topLists = lists
                OptimizedCacheManager.shared.setObject(lists, forKey: "top_charts_lists")
            })
            .store(in: &cancellables)
    }
}
