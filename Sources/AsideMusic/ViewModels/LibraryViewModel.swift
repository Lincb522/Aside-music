import SwiftUI
import Combine
@preconcurrency import QQMusicKit

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
        case qqArtist(mid: String, name: String, coverUrl: String?)
        case radioDetail(Int)
        case localPlaylist(String)

        func hash(into hasher: inout Hasher) {
            switch self {
            case .playlist(let p): hasher.combine("p_\(p.id)")
            case .artist(let id): hasher.combine("a_\(id)")
            case .artistInfo(let a): hasher.combine("a_\(a.id)")
            case .qqArtist(let mid, _, _): hasher.combine("qa_\(mid)")
            case .radioDetail(let id): hasher.combine("r_\(id)")
            case .localPlaylist(let id): hasher.combine("lp_\(id)")
            }
        }

        static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
            switch (lhs, rhs) {
            case (.playlist(let l), .playlist(let r)): return l.id == r.id
            case (.artist(let l), .artist(let r)): return l == r
            case (.artistInfo(let l), .artistInfo(let r)): return l.id == r.id
            case (.qqArtist(let lm, _, _), .qqArtist(let rm, _, _)): return lm == rm
            case (.radioDetail(let l), .radioDetail(let r)): return l == r
            case (.localPlaylist(let l), .localPlaylist(let r)): return l == r
            default: return false
            }
        }
    }

    /// 歌单广场/歌手/榜单的音源选择
    enum MusicSource: String, CaseIterable {
        case ncm = "NCM"
        case qq = "QQ"
    }

    @Published var currentTab: LibraryTab = .my

    @Published var userPlaylists: [Playlist] = []

    // MARK: - Playlist Square (NCM)
    @Published var squarePlaylists: [Playlist] = []
    @Published var playlistCategories: [PlaylistCategory] = []
    @Published var selectedCategory: String = NSLocalizedString("filter_all", comment: "")
    @Published var squareOffset: Int = 0
    @Published var hasMoreSquarePlaylists: Bool = true
    @Published var isLoadingMoreSquare: Bool = false
    @Published var isLoadingSquare: Bool = false
    @Published var squareSource: MusicSource = .ncm

    // MARK: - Playlist Square (QQ)
    @Published var qqSquarePlaylists: [Playlist] = []
    @Published var isLoadingQQSquare: Bool = false
    @Published var qqPlaylistCategories: [(id: Int, name: String)] = []
    @Published var selectedQQCategoryId: Int = 3317
    @Published var selectedQQCategoryName: String = "官方歌单"
    @Published var qqSquarePage: Int = 0
    @Published var hasMoreQQSquare: Bool = true
    @Published var isLoadingMoreQQSquare: Bool = false
    @Published var qqSquareSortId: Int = 5

    // MARK: - Artists (NCM)
    @Published var topArtists: [ArtistInfo] = []
    @Published var artistOffset: Int = 0
    @Published var hasMoreArtists: Bool = true
    @Published var isLoadingArtists: Bool = false
    @Published var artistSource: MusicSource = .ncm

    // MARK: - Artists (QQ)
    @Published var qqArtists: [ArtistInfo] = []
    @Published var qqArtistPage: Int = 1
    @Published var qqArtistSin: Int = 0
    @Published var hasMoreQQArtists: Bool = true
    @Published var isLoadingQQArtists: Bool = false
    @Published var qqArtistArea: AreaType = .all
    @Published var qqArtistSex: SexType = .all
    @Published var qqArtistGenre: GenreType = .all
    @Published var qqArtistSearchText: String = ""
    @Published var isSearchingQQArtists: Bool = false

    let qqArtistAreas: [(name: String, value: AreaType)] = [
        ("filter_all", .all), ("filter_chinese", .china), ("filter_western", .america),
        ("filter_japanese", .japan), ("filter_korean", .korea), ("台湾", .taiwan)
    ]
    let qqArtistSexes: [(name: String, value: SexType)] = [
        ("filter_all", .all), ("filter_male", .male), ("filter_female", .female), ("filter_band", .group)
    ]
    let qqArtistGenres: [(name: String, value: GenreType)] = [
        ("filter_all", .all), ("流行", .pop), ("说唱", .rap), ("摇滚", .rock),
        ("电子", .electronic), ("民谣", .folk), ("R&B", .rnb), ("爵士", .jazz), ("古典", .classical)
    ]

    // MARK: - Charts (NCM)
    @Published var topLists: [TopList] = []
    @Published var chartsSource: MusicSource = .ncm

    // MARK: - Charts (QQ)
    @Published var qqTopLists: [QQTopListGroup] = []
    @Published var isLoadingQQCharts: Bool = false

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
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private var playlistRetryCount = 0
    private let maxPlaylistRetries = 2

    init() {
        // 订阅 GlobalRefreshManager 的刷新事件
        GlobalRefreshManager.shared.refreshLibraryPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] force in
                self?.fetchPlaylists(force: force)
            }
            .store(in: &cancellables)
        
        // 监听登录成功，强制刷新歌单
        NotificationCenter.default.publisher(for: .didLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchPlaylists(force: true)
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

        $qqArtistSearchText
            .dropFirst()
            .debounce(for: .milliseconds(AppConfig.UI.searchDebounceMs), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                if !text.isEmpty {
                    self?.searchQQArtists(keyword: text)
                } else {
                    self?.isSearchingQQArtists = false
                    self?.fetchQQArtistData(reset: true)
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
        qqSquarePlaylists = []
        qqArtists = []
        qqTopLists = []
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
                    self?.retryLoadPlaylistsIfNeeded(uid: uid)
                }
                GlobalRefreshManager.shared.markLibraryDataReady()
            }, receiveValue: { [weak self] playlists in
                #if DEBUG
                print("[Library] ✅ 获取到 \(playlists.count) 个歌单")
                #endif
                self?.playlistRetryCount = 0
                let filtered = playlists.filter { !$0.name.hasPrefix("test_audit") && $0.name != "test_audit_tmp" }
                self?.userPlaylists = filtered
                SubscriptionManager.shared.updatePlaylistSubscriptions(from: playlists, userId: uid)
                OptimizedCacheManager.shared.setObject(playlists, forKey: "user_playlists")
                OptimizedCacheManager.shared.cachePlaylists(playlists)
            })
            .store(in: &cancellables)
    }
    
    private func retryLoadPlaylistsIfNeeded(uid: Int) {
        guard playlistRetryCount < maxPlaylistRetries, userPlaylists.isEmpty else { return }
        playlistRetryCount += 1
        let delay = Double(playlistRetryCount) * 3.0
        #if DEBUG
        print("[Library] 🔄 歌单加载失败，\(delay)秒后第\(playlistRetryCount)次重试")
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadUserPlaylists(uid: uid)
        }
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

        if let cached = OptimizedCacheManager.shared.getObject(forKey: "top_charts_lists", type: [TopList].self), !cached.isEmpty {
            self.topLists = cached
            return
        }

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

    // MARK: - QQ Playlist Square

    func fetchQQSquareData() {
        // 加载分类（只加载一次）
        if qqPlaylistCategories.isEmpty {
            fetchQQCategories()
        }
        // 加载歌单
        if !qqSquarePlaylists.isEmpty { return }
        loadQQSquarePlaylists(reset: true)
    }

    func refreshQQSquare() {
        loadQQSquarePlaylists(reset: true)
    }
    
    func fetchQQCategories() {
        apiService.fetchQQPlaylistCategories()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] categories in
                self?.qqPlaylistCategories = categories
            })
            .store(in: &cancellables)
    }
    
    func loadQQSquarePlaylists(categoryId: Int? = nil, reset: Bool = false) {
        let catId = categoryId ?? selectedQQCategoryId
        
        if reset {
            qqSquarePlaylists = []
            qqSquarePage = 0
            hasMoreQQSquare = true
            isLoadingQQSquare = true
        } else {
            guard hasMoreQQSquare, !isLoadingMoreQQSquare else { return }
            isLoadingMoreQQSquare = true
        }
        
        apiService.fetchQQPlaylistsByCategory(
            categoryId: catId,
            sortId: qqSquareSortId,
            page: qqSquarePage,
            size: 30
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] _ in
            self?.isLoadingQQSquare = false
            self?.isLoadingMoreQQSquare = false
        }, receiveValue: { [weak self] result in
            guard let self = self else { return }
            if reset {
                self.qqSquarePlaylists = result.playlists
            } else {
                self.qqSquarePlaylists.append(contentsOf: result.playlists)
            }
            self.hasMoreQQSquare = result.hasMore
            self.qqSquarePage += 1
            let cacheKey = "qq_square_playlists_\(catId)"
            OptimizedCacheManager.shared.setObject(self.qqSquarePlaylists, forKey: cacheKey)
        })
        .store(in: &cancellables)
    }
    
    func loadMoreQQSquarePlaylists() {
        loadQQSquarePlaylists(reset: false)
    }
    
    func selectQQCategory(id: Int, name: String) {
        guard id != selectedQQCategoryId else { return }
        selectedQQCategoryId = id
        selectedQQCategoryName = name
        loadQQSquarePlaylists(categoryId: id, reset: true)
    }

    // MARK: - QQ Artists

    func fetchQQArtistData(reset: Bool = false) {
        if reset {
            qqArtists = []
            qqArtistPage = 1
            qqArtistSin = 0
            hasMoreQQArtists = true
            isLoadingQQArtists = false
            isSearchingQQArtists = false
        }

        if !qqArtistSearchText.isEmpty { return }
        if isLoadingQQArtists || !hasMoreQQArtists { return }

        let cacheKey = "qq_artists_\(qqArtistArea)_\(qqArtistSex)_\(qqArtistGenre)_0"
        if qqArtists.isEmpty && qqArtistSin == 0 {
            if let cached = OptimizedCacheManager.shared.getObject(forKey: cacheKey, type: [ArtistInfo].self), !cached.isEmpty {
                self.qqArtists = cached
                self.qqArtistSin = cached.count
                return
            }
        }

        isLoadingQQArtists = true

        let pageSize = 80
        apiService.fetchQQSingerListIndex(
            area: qqArtistArea,
            sex: qqArtistSex,
            genre: qqArtistGenre,
            index: -100,
            sin: qqArtistSin,
            curPage: qqArtistPage
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] _ in
            self?.isLoadingQQArtists = false
        }, receiveValue: { [weak self] result in
            guard let self = self else { return }
            let (artists, total) = result
            if self.qqArtistSin == 0 {
                self.qqArtists = artists
                OptimizedCacheManager.shared.setObject(artists, forKey: cacheKey)
            } else {
                let existingIds = Set(self.qqArtists.map { $0.id })
                let newArtists = artists.filter { !existingIds.contains($0.id) }
                self.qqArtists.append(contentsOf: newArtists)
            }
            self.qqArtistSin += artists.count
            self.qqArtistPage += 1
            self.hasMoreQQArtists = self.qqArtists.count < total && artists.count >= pageSize
        })
        .store(in: &cancellables)
    }

    func loadMoreQQArtists() {
        if !isSearchingQQArtists {
            fetchQQArtistData(reset: false)
        }
    }

    func searchQQArtists(keyword: String) {
        isLoadingQQArtists = true
        isSearchingQQArtists = true

        apiService.searchQQArtists(keyword: keyword, page: 1, num: 30)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingQQArtists = false
            }, receiveValue: { [weak self] artists in
                self?.qqArtists = artists
                self?.hasMoreQQArtists = false
            })
            .store(in: &cancellables)
    }

    // MARK: - QQ Charts

    func fetchQQTopLists() {
        if !qqTopLists.isEmpty { return }

        if let cached = OptimizedCacheManager.shared.getObject(forKey: "qq_top_charts", type: [QQTopListGroup].self), !cached.isEmpty {
            self.qqTopLists = cached
            return
        }

        isLoadingQQCharts = true
        apiService.fetchQQTopCategory()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingQQCharts = false
            }, receiveValue: { [weak self] groups in
                self?.qqTopLists = groups
                OptimizedCacheManager.shared.setObject(groups, forKey: "qq_top_charts")
            })
            .store(in: &cancellables)
    }
}
