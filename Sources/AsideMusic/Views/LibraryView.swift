import SwiftUI
import Combine

// MARK: - ViewModel

class LibraryViewModel: ObservableObject {
    // Navigation Path Management
    @Published var navigationPath = NavigationPath()
    
    enum LibraryTab: String, CaseIterable {
        case my = "My Library"
        case square = "Playlists"
        case artists = "Artists"
        case charts = "Charts"
        
        var localizedKey: LocalizedStringKey {
            switch self {
            case .my: return "tab_library" // Reusing tab_library or make specific one
            case .square: return "lib_tab_playlists"
            case .artists: return "lib_tab_artists"
            case .charts: return "lib_tab_charts"
            }
        }
    }
    
    // Navigation Destinations
    enum NavigationDestination: Hashable {
        case playlist(Playlist)
        case artist(Int)
        case artistInfo(ArtistInfo) // For cases where we have full info object
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .playlist(let p): hasher.combine("p_\(p.id)")
            case .artist(let id): hasher.combine("a_\(id)")
            case .artistInfo(let a): hasher.combine("a_\(a.id)")
            }
        }
        
        static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
            switch (lhs, rhs) {
            case (.playlist(let l), .playlist(let r)): return l.id == r.id
            case (.artist(let l), .artist(let r)): return l == r
            case (.artistInfo(let l), .artistInfo(let r)): return l.id == r.id
            default: return false
            }
        }
    }

    // Tab Selection
    @Published var currentTab: LibraryTab = .my
    
    // My Library Data
    @Published var userPlaylists: [Playlist] = []
    
    // Playlist Square Data
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
    
    // Artist Filters
    @Published var artistArea: Int = -1
    @Published var artistType: Int = -1
    @Published var artistInitial: String = "-1"
    @Published var artistSearchText: String = ""
    @Published var isSearchingArtists = false
    
    // Filter Options
    let artistAreas: [(name: String, value: Int)] = [
        ("filter_all", -1), ("filter_chinese", 7), ("filter_western", 96), ("filter_japanese", 8), ("filter_korean", 16), ("filter_others", 0)
    ]
    let artistTypes: [(name: String, value: Int)] = [
        ("filter_all", -1), ("filter_male", 1), ("filter_female", 2), ("filter_band", 3)
    ]
    let artistInitials: [String] = ["-1"] + (65...90).map { String(UnicodeScalar($0)) } + ["#"] // -1 is Hot, # is Other
    
    @Published var isLoadingCharts: Bool = false
    @Published var isLoading = false // 保留用于兼容，但不再使用
    private var searchDebounceTimer: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        // 订阅 GlobalRefreshManager 的刷新事件
        Task { @MainActor in
            GlobalRefreshManager.shared.refreshLibraryPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] force in
                    self?.fetchPlaylists(force: force)
                }
                .store(in: &self.cancellables)
        }
        
        // Initial fetch
        fetchPlaylists()
        
        // Debounce Search
        $artistSearchText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
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
    
    func fetchPlaylists(force: Bool = false) {
        // Load cache first - 使用优化的缓存管理器
        if userPlaylists.isEmpty {
            Task { @MainActor in
                if let cachedUser = OptimizedCacheManager.shared.getObject(forKey: "user_playlists", type: [Playlist].self) {
                    self.userPlaylists = cachedUser
                }
            }
        }
        
        if !force && !userPlaylists.isEmpty {
            // 有缓存数据，标记完成
            Task { @MainActor in
                GlobalRefreshManager.shared.markLibraryDataReady()
            }
            return
        }
        
        // 尝试获取用户歌单（需要登录）
        // 如果没有登录，直接标记完成
        guard apiService.currentUserId != nil else {
            Task { @MainActor in
                GlobalRefreshManager.shared.markLibraryDataReady()
            }
            return
        }
        
        // Ensure login status
        apiService.fetchLoginStatus()
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    // 登录状态获取失败，也标记完成
                    Task { @MainActor in
                        GlobalRefreshManager.shared.markLibraryDataReady()
                    }
                }
            }, receiveValue: { [weak self] response in
                if let profile = response.data.profile {
                    self?.apiService.currentUserId = profile.userId
                    self?.loadUserPlaylists(uid: profile.userId)
                } else {
                    // 没有用户信息，标记完成
                    Task { @MainActor in
                        GlobalRefreshManager.shared.markLibraryDataReady()
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    private func loadUserPlaylists(uid: Int) {
        apiService.fetchUserPlaylists(uid: uid)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Library Playlist Error: \(error)")
                }
                // 标记 Library 数据加载完成
                Task { @MainActor in
                    GlobalRefreshManager.shared.markLibraryDataReady()
                }
            }, receiveValue: { [weak self] playlists in
                self?.userPlaylists = playlists
                // 使用优化的缓存管理器
                Task { @MainActor in
                    OptimizedCacheManager.shared.setObject(playlists, forKey: "user_playlists")
                    OptimizedCacheManager.shared.cachePlaylists(playlists)
                }
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Playlist Square
    
    func fetchSquareData() {
        // Fetch Categories
        if playlistCategories.isEmpty {
            // Try Cache for Categories
            if let cachedCats = CacheManager.shared.getObject(forKey: "playlist_categories", type: [PlaylistCategory].self) {
                self.playlistCategories = cachedCats
            }
            
            // Only fetch if still empty or force needed (not implemented here yet)
            if playlistCategories.isEmpty {
                apiService.fetchHotPlaylistCategories()
                    .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] tags in
                        // Add "All" manually if needed, or rely on API
                        var allTags = [PlaylistCategory(name: NSLocalizedString("filter_all", comment: ""), id: -1, category: -1, hot: true)]
                        allTags.append(contentsOf: tags)
                        self?.playlistCategories = allTags
                        CacheManager.shared.setObject(allTags, forKey: "playlist_categories")
                    })
                    .store(in: &cancellables)
            }
        }
        
        // Fetch Playlists if empty
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
            
            // Try Cache only for first page
            let cacheKey = "square_playlists_\(cat)"
            if let cached = CacheManager.shared.getObject(forKey: cacheKey, type: [Playlist].self) {
                self.squarePlaylists = cached
                self.isLoadingSquare = false
                // If we have cache, we still fetch fresh data, or maybe just set offset
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
                    CacheManager.shared.setObject(playlists, forKey: "square_playlists_\(cat)")
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
        
        // If searching, don't fetch list
        if !artistSearchText.isEmpty {
            return
        }
        
        // For initial load (reset=true or no data), proceed
        // For loadMore (reset=false with existing data), also proceed to fetch next page
        
        // Try Cache for first page only if we have no data
        if topArtists.isEmpty && artistOffset == 0 {
            let cacheKey = "artists_\(artistArea)_\(artistType)_\(artistInitial)_0"
            if let cached = CacheManager.shared.getObject(forKey: cacheKey, type: [ArtistInfo].self) {
                self.topArtists = cached
                // Don't return here, we can still fetch fresh data in background or just assume cache is good
                // But to avoid "reloading" flicker, we set isLoadingArtists = false
                // If you want to force refresh behind scenes, you can continue, but usually cache is enough for "instant" feel
                
                // Let's assume if we have cache, we are good for now unless user pulls to refresh (which calls reset=true)
                if !cached.isEmpty {
                    self.isLoadingArtists = false
                    // Update offset so next loadMore works
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
                    // Cache first page
                    let cacheKey = "artists_\(self.artistArea)_\(self.artistType)_\(self.artistInitial)_0"
                    CacheManager.shared.setObject(artists, forKey: cacheKey)
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
        
        // Try Cache
        if let cached = CacheManager.shared.getObject(forKey: "top_charts_lists", type: [TopList].self) {
            self.topLists = cached
        }
        
        if !topLists.isEmpty { return } // If cache hit, don't fetch
        
        isLoadingCharts = true
        
        apiService.fetchTopLists()
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingCharts = false
            }, receiveValue: { [weak self] lists in
                self?.topLists = lists
                CacheManager.shared.setObject(lists, forKey: "top_charts_lists")
            })
            .store(in: &cancellables)
    }
}

// MARK: - Main View

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @Namespace private var animation
    
    // Theme Reference
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header with Tabs
                    headerView
                    
                    // Content
                    TabView(selection: $viewModel.currentTab) {
                        MyPlaylistsContainerView(viewModel: viewModel)
                            .tag(LibraryViewModel.LibraryTab.my)
                        
                        PlaylistSquareView(viewModel: viewModel)
                            .tag(LibraryViewModel.LibraryTab.square)
                        
                        ArtistLibraryView(viewModel: viewModel)
                            .tag(LibraryViewModel.LibraryTab.artists)
                        
                        ChartsLibraryView(viewModel: viewModel)
                            .tag(LibraryViewModel.LibraryTab.charts)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .background(Color.clear)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
            .navigationDestination(for: LibraryViewModel.NavigationDestination.self) { destination in
                switch destination {
                case .playlist(let playlist):
                    PlaylistDetailView(playlist: playlist)
                case .artist(let id):
                    ArtistDetailView(artistId: id)
                case .artistInfo(let artist):
                    ArtistDetailView(artistId: artist.id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibrarySquare"))) { _ in
                withAnimation {
                    viewModel.currentTab = .square
                }
            }
            // Removed direct NotificationCenter and onChange(of: isLoggedIn)
            // Handled by GlobalRefreshManager inside LibraryViewModel
            .onChange(of: viewModel.currentTab) { _, newTab in
                if newTab == .square {
                    viewModel.fetchSquareData()
                } else if newTab == .artists {
                    viewModel.fetchArtistData()
                } else if newTab == .charts {
                    viewModel.fetchTopLists()
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            HStack {
                Text(LocalizedStringKey("tab_library"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, DeviceLayout.headerTopPadding)
            
            // Custom Segmented Control
            HStack(spacing: 0) {
                ForEach(LibraryViewModel.LibraryTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.currentTab = tab
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(tab.localizedKey)
                                .font(.system(size: 16, weight: viewModel.currentTab == tab ? .bold : .medium, design: .rounded))
                                .foregroundColor(viewModel.currentTab == tab ? Theme.text : Theme.secondaryText)
                            
                            if viewModel.currentTab == tab {
                                Capsule()
                                    .fill(Theme.text)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "TabIndicator", in: animation)
                            } else {
                                Capsule()
                                    .fill(Color.clear)
                                    .frame(height: 3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(Color.clear)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Subviews

struct MyPlaylistsContainerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var selectedSubTab: Int = 0 // 0: NetEase, 1: Local
    @Namespace private var subTabAnimation
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Sub-Tab Switcher
            HStack(spacing: 0) {
                subTabButton(title: "网易云歌单", index: 0)
                subTabButton(title: "本地歌单", index: 1)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Content
            if selectedSubTab == 0 {
                NetEasePlaylistsView(viewModel: viewModel)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                LocalPlaylistsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Color.clear)
    }
    
    private func subTabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSubTab = index
            }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: selectedSubTab == index ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedSubTab == index ? Theme.text : Theme.secondaryText)
                
                if selectedSubTab == index {
                    Capsule()
                        .fill(Theme.text)
                        .frame(width: 20, height: 3)
                        .matchedGeometryEffect(id: "SubTabInd", in: subTabAnimation)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: 20, height: 3)
                }
            }
            .padding(.trailing, 24)
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }
}

struct LocalPlaylistsView: View {
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            // Removed Icon
            Text("本地歌单功能开发中...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Theme.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct NetEasePlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                if viewModel.userPlaylists.isEmpty {
                    // Empty State - 用户歌单为空时显示空状态
                    VStack(spacing: 16) {
                        AsideIcon(icon: .musicNoteList, size: 40, color: .gray.opacity(0.3))
                        Text(LocalizedStringKey("library_playlists_empty"))
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(viewModel.userPlaylists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
                    }
                }
                
                Color.clear.frame(height: 120) // Bottom Padding
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            viewModel.fetchPlaylists(force: true)
        }
    }
}

struct PlaylistSquareView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Categories Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.playlistCategories, id: \.idString) { cat in
                        Button(action: {
                            if viewModel.selectedCategory != cat.name {
                                viewModel.selectedCategory = cat.name
                                viewModel.loadSquarePlaylists(cat: cat.name, reset: true)
                            }
                        }) {
                            Text(cat.name)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedCategory == cat.name ? Theme.text : Color.white)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                )
                                .foregroundColor(viewModel.selectedCategory == cat.name ? .white : Theme.text)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .scrollContentBackground(.hidden)
            
            // Playlists Grid
            ScrollView(showsIndicators: false) {
                if viewModel.isLoadingSquare && viewModel.squarePlaylists.isEmpty {
                    AsideLoadingView()
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(viewModel.squarePlaylists.enumerated()), id: \.element.id) { index, playlist in
                            NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                PlaylistVerticalCard(playlist: playlist)
                                    .frame(maxWidth: .infinity) // Ensure card takes available width in grid
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.96))
                            .onAppear {
                                if index == viewModel.squarePlaylists.count - 1 {
                                    viewModel.loadMoreSquarePlaylists()
                                }
                            }
                        }
                    }
                    .padding(24)
                    
                    if viewModel.isLoadingMoreSquare && viewModel.hasMoreSquarePlaylists {
                        AsideLoadingView(centered: false)
                            .padding()
                    }
                }
                
                Color.clear.frame(height: 120)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.clear)
    }
}

struct ArtistLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                AsideIcon(icon: .magnifyingGlass, size: 18, color: Theme.secondaryText)
                
                TextField(LocalizedStringKey("search_artists"), text: $viewModel.artistSearchText)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Theme.text)
                
                if !viewModel.artistSearchText.isEmpty {
                    Button(action: {
                        viewModel.artistSearchText = ""
                        viewModel.fetchArtistData(reset: true)
                    }) {
                        AsideIcon(icon: .xmark, size: 18, color: Theme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .padding(.top, 8)
            
            // Filters (Only show when not searching)
            if !viewModel.isSearchingArtists {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Area Filter
                        filterRow(options: viewModel.artistAreas.map { ($0.name, $0.value) }, selected: $viewModel.artistArea)
                        
                        // Type Filter
                        filterRow(options: viewModel.artistTypes.map { ($0.name, $0.value) }, selected: $viewModel.artistType)
                        
                        // Initial Filter
                        filterRow(options: viewModel.artistInitials.map { ($0 == "-1" ? "search_hot" : $0, $0) }, selected: $viewModel.artistInitial)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .scrollContentBackground(.hidden)
            }
            
            // Content
            ScrollView(showsIndicators: false) {
                if viewModel.isLoadingArtists && viewModel.topArtists.isEmpty {
                    AsideLoadingView()
                } else if viewModel.topArtists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(Theme.secondaryText.opacity(0.5))
                        Text(LocalizedStringKey("empty_no_artists"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(Array(viewModel.topArtists.enumerated()), id: \.element.id) { index, artist in
                            NavigationLink(value: LibraryViewModel.NavigationDestination.artist(artist.id)) {
                                VStack(spacing: 12) {
                                    CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                                        Color.gray.opacity(0.1)
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    
                                    Text(artist.name)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .lineLimit(1)
                                        .foregroundColor(Theme.text)
                                }
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                            .onAppear {
                                if index == viewModel.topArtists.count - 1 && !viewModel.isSearchingArtists {
                                    viewModel.loadMoreArtists()
                                }
                            }
                        }
                    }
                    .padding(24)
                    
                    if viewModel.hasMoreArtists && !viewModel.isSearchingArtists {
                        AsideLoadingView()
                            .padding()
                    }
                }
                
                Color.clear.frame(height: 120)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .background(Color.clear)
    }
    
    private func filterRow<T: Equatable>(options: [(String, T)], selected: Binding<T>) -> some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.0) { option in
                Button(action: {
                    if selected.wrappedValue != option.1 {
                        selected.wrappedValue = option.1
                        viewModel.fetchArtistData(reset: true)
                    }
                }) {
                    Text(LocalizedStringKey(option.0))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected.wrappedValue == option.1 ? Theme.text : Color.white)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .foregroundColor(selected.wrappedValue == option.1 ? .white : Theme.text)
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
    }
}

struct ChartsLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                AsideLoadingView()
            } else if viewModel.topLists.isEmpty {
                 VStack(spacing: 16) {
                     AsideIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                     Text(LocalizedStringKey("empty_no_charts"))
                         .font(.system(size: 16, weight: .medium, design: .rounded))
                         .foregroundColor(Theme.secondaryText)
                 }
                 .padding(.top, 50)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.topLists) { list in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(Playlist(id: list.id, name: list.name, coverImgUrl: list.coverImgUrl, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil))) {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: list.coverUrl?.sized(400)) {
                                    Color.gray.opacity(0.1)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 110)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                
                                Text(list.name)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.text)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Text(list.updateFrequency)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(Theme.secondaryText)
                            }
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                    }
                }
                .padding(24)
            }
            
            Color.clear.frame(height: 120)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Components

struct LibraryPlaylistRow: View {
    let playlist: Playlist
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        HStack(spacing: 16) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                
                Text(String(format: NSLocalizedString("track_count_songs", comment: ""), playlist.trackCount ?? 0))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
            }
            
            Spacer()
            
            AsideIcon(icon: .chevronRight, size: 14, color: Theme.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
