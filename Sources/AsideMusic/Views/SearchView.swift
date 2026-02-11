import SwiftUI
import Combine

// MARK: - 搜索类型

enum SearchTab: String, CaseIterable {
    case songs = "单曲"
    case artists = "歌手"
    case playlists = "歌单"
    case albums = "专辑"
    case mvs = "MV"
}

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var searchResults: [Song] = []
    @Published var artistResults: [ArtistInfo] = []
    @Published var playlistResults: [Playlist] = []
    @Published var albumResults: [SearchAlbum] = []
    @Published var mvResults: [MV] = []
    @Published var suggestions: [String] = []
    @Published var searchHistory: [SearchHistory] = []
    @Published var hotSearchItems: [HotSearchItem] = []
    @Published var isLoading = false
    @Published var hasSearched = false
    @Published var canLoadMore = true
    @Published var showSuggestions = false
    @Published var currentTab: SearchTab = .songs

    private var currentPage = 0
    private var isFetchingMore = false
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private let cacheManager = OptimizedCacheManager.shared
    
    init() {
        loadSearchHistory()
        loadHotSearch()
        
        $query
            .debounce(for: .milliseconds(AppConfig.UI.searchDebounceMs), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] keyword in
                guard let self = self else { return }
                if !keyword.isEmpty {
                    if !self.hasSearched {
                        self.fetchSuggestions(keyword: keyword)
                    }
                } else {
                    self.resetState()
                }
            }
            .store(in: &cancellables)
    }
    
    private func resetState() {
        self.searchResults = []
        self.artistResults = []
        self.playlistResults = []
        self.albumResults = []
        self.mvResults = []
        self.suggestions = []
        self.hasSearched = false
        self.showSuggestions = false
        self.currentPage = 0
        self.canLoadMore = true
    }
    
    func loadSearchHistory() {
        searchHistory = cacheManager.getSearchHistory(limit: 20)
    }
    
    func loadHotSearch() {
        apiService.fetchHotSearch()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] items in
                self?.hotSearchItems = items
            })
            .store(in: &cancellables)
    }
    
    func fetchSuggestions(keyword: String) {
        self.showSuggestions = true
        apiService.fetchSearchSuggestions(keyword: keyword)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] suggestions in
                self?.suggestions = suggestions
            })
            .store(in: &cancellables)
    }
    
    func performSearch(keyword: String) {
        isLoading = true
        hasSearched = true
        showSuggestions = false
        suggestions = []
        currentPage = 0
        canLoadMore = true
        
        if query != keyword {
            query = keyword
        }
        
        // 保存搜索历史
        cacheManager.addSearchHistory(keyword: keyword)
        loadSearchHistory()

        executeSearch(keyword: keyword, offset: 0, isLoadMore: false)
    }
    
    /// 切换搜索类型时重新搜索
    func switchTab(_ tab: SearchTab) {
        guard tab != currentTab else { return }
        currentTab = tab
        guard hasSearched, !query.isEmpty else { return }
        
        // 如果该类型已有结果，不重复请求
        switch tab {
        case .songs: if !searchResults.isEmpty { return }
        case .artists: if !artistResults.isEmpty { return }
        case .playlists: if !playlistResults.isEmpty { return }
        case .albums: if !albumResults.isEmpty { return }
        case .mvs: if !mvResults.isEmpty { return }
        }
        
        isLoading = true
        currentPage = 0
        canLoadMore = true
        executeSearch(keyword: query, offset: 0, isLoadMore: false)
    }
    
    func loadMore() {
        guard !isFetchingMore && canLoadMore && !query.isEmpty else { return }
        
        isFetchingMore = true
        let nextPage = currentPage + 1
        let offset = nextPage * 30
        executeSearch(keyword: query, offset: offset, isLoadMore: true)
    }

    private func executeSearch(keyword: String, offset: Int, isLoadMore: Bool) {
        switch currentTab {
        case .songs:
            apiService.searchSongs(keyword: keyword, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                    if isLoadMore { self?.isFetchingMore = false }
                }, receiveValue: { [weak self] songs in
                    guard let self = self else { return }
                    self.handlePagination(newItems: songs, existing: &self.searchResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .artists:
            apiService.searchArtists(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                    if isLoadMore { self?.isFetchingMore = false }
                }, receiveValue: { [weak self] artists in
                    guard let self = self else { return }
                    self.handlePagination(newItems: artists, existing: &self.artistResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .playlists:
            apiService.searchPlaylists(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                    if isLoadMore { self?.isFetchingMore = false }
                }, receiveValue: { [weak self] playlists in
                    guard let self = self else { return }
                    self.handlePagination(newItems: playlists, existing: &self.playlistResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .albums:
            apiService.searchAlbums(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                    if isLoadMore { self?.isFetchingMore = false }
                }, receiveValue: { [weak self] albums in
                    guard let self = self else { return }
                    self.handlePagination(newItems: albums, existing: &self.albumResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .mvs:
            apiService.searchMVs(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                    if isLoadMore { self?.isFetchingMore = false }
                }, receiveValue: { [weak self] mvs in
                    guard let self = self else { return }
                    self.handlePagination(newItems: mvs, existing: &self.mvResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
        }
    }
    
    /// 通用分页处理
    private func handlePagination<T: Identifiable>(newItems: [T], existing: inout [T], isLoadMore: Bool) where T.ID: Hashable {
        if isLoadMore {
            if !newItems.isEmpty {
                let existingIds = Set(existing.map { $0.id })
                let filtered = newItems.filter { !existingIds.contains($0.id) }
                if !filtered.isEmpty {
                    existing.append(contentsOf: filtered)
                }
                currentPage += 1
                canLoadMore = newItems.count >= 30
            } else {
                canLoadMore = false
            }
        } else {
            existing = newItems
            canLoadMore = !newItems.isEmpty
        }
    }
    
    /// 当前 tab 是否有结果
    var currentResultsEmpty: Bool {
        switch currentTab {
        case .songs: return searchResults.isEmpty
        case .artists: return artistResults.isEmpty
        case .playlists: return playlistResults.isEmpty
        case .albums: return albumResults.isEmpty
        case .mvs: return mvResults.isEmpty
        }
    }
    
    func clearSearch() {
        query = ""
        resetState()
    }
    
    func deleteHistoryItem(keyword: String) {
        cacheManager.deleteSearchHistory(keyword: keyword)
        loadSearchHistory()
    }
    
    func clearAllHistory() {
        cacheManager.clearSearchHistory()
        loadSearchHistory()
    }
}


// MARK: - SearchView

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedPlaylist: Playlist?
    @State private var showPlaylistDetail = false
    @State private var selectedMVId: MVIdItem?
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                searchBarSection
                
                ZStack {
                    searchContentView
                    suggestionsOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)
            }
        }
        .navigationDestination(isPresented: $showPlaylistDetail) {
            if let playlist = selectedPlaylist {
                PlaylistDetailView(playlist: playlist, songs: nil)
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
        .fullScreenCover(item: $selectedMVId) { item in
            MVPlayerView(mvId: item.id)
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - 搜索栏
    
    private var searchBarSection: some View {
        VStack(spacing: 16) {
            HStack {
                AsideBackButton()
                
                Text(LocalizedStringKey("tab_search"))
                    .font(.rounded(size: 28, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, DeviceLayout.headerTopPadding)
            
            HStack(spacing: 12) {
                HStack {
                    AsideIcon(icon: .magnifyingGlass, size: 18, color: .gray)
                    
                    TextField(LocalizedStringKey("search_placeholder"), text: $viewModel.query)
                        .foregroundColor(.asideTextPrimary)
                        .font(.rounded(size: 16, weight: .medium))
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            if !viewModel.query.isEmpty {
                                viewModel.performSearch(keyword: viewModel.query)
                            }
                        }
                        .onChange(of: viewModel.query) { _, newValue in
                            if !newValue.isEmpty {
                                if viewModel.hasSearched {
                                    viewModel.hasSearched = false
                                    viewModel.showSuggestions = true
                                }
                            }
                        }
                    
                    if !viewModel.query.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            AsideIcon(icon: .xmark, size: 18, color: .gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.asideCardBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 12)
    }

    // MARK: - 搜索类型 Tab 栏
    
    private var searchTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Button(action: {
                    viewModel.switchTab(tab)
                }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.rounded(size: 14, weight: viewModel.currentTab == tab ? .semibold : .regular))
                            .foregroundColor(viewModel.currentTab == tab ? .asideTextPrimary : .asideTextSecondary)
                        
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(viewModel.currentTab == tab ? Color.asideTextPrimary : Color.clear)
                            .frame(width: 20, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - 搜索内容区域
    
    @ViewBuilder
    private var searchContentView: some View {
        if viewModel.hasSearched {
            VStack(spacing: 0) {
                searchTabBar
                
                if viewModel.isLoading && viewModel.currentResultsEmpty {
                    Spacer()
                    AsideLoadingView(text: "SEARCHING")
                    Spacer()
                } else if viewModel.currentResultsEmpty {
                    Spacer()
                    emptyResultsView
                    Spacer()
                } else {
                    resultsListView
                }
            }
        } else if viewModel.query.isEmpty {
            emptySearchView
        }
    }
    
    // MARK: - 空结果提示
    
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            AsideIcon(icon: .musicNoteList, size: 50, color: .gray.opacity(0.3))
            Text(LocalizedStringKey("empty_no_results"))
                .font(.rounded(size: 16, weight: .medium))
                .foregroundColor(.asideTextSecondary)
        }
    }

    // MARK: - 搜索历史 & 热搜
    
    private var emptySearchView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 搜索历史
                if !viewModel.searchHistory.isEmpty {
                    HStack {
                        Text("搜索历史")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.clearAllHistory()
                        }) {
                            AsideIcon(icon: .trash, size: 16, color: .asideTextSecondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ForEach(viewModel.searchHistory, id: \.id) { item in
                        Button(action: {
                            viewModel.performSearch(keyword: item.keyword)
                            isFocused = false
                        }) {
                            HStack(spacing: 14) {
                                AsideIcon(icon: .clock, size: 16, color: .asideTextSecondary)
                                
                                Text(item.keyword)
                                    .font(.rounded(size: 16, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.deleteHistoryItem(keyword: item.keyword)
                                }) {
                                    AsideIcon(icon: .xmark, size: 12, color: .asideTextSecondary.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // 热门搜索
                if !viewModel.hotSearchItems.isEmpty {
                    Text("热门搜索")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(Array(viewModel.hotSearchItems.prefix(20).enumerated()), id: \.offset) { index, item in
                            Button(action: {
                                viewModel.performSearch(keyword: item.searchWord)
                                isFocused = false
                            }) {
                                Text(item.searchWord)
                                    .font(.rounded(size: 14, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.asideCardBackground)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - 结果列表（根据当前 Tab 切换）
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch viewModel.currentTab {
                case .songs:
                    songsResultSection
                case .artists:
                    artistsResultSection
                case .playlists:
                    playlistsResultSection
                case .albums:
                    albumsResultSection
                case .mvs:
                    mvsResultSection
                }
            }
            .padding(.bottom, 120)
        }
        .simultaneousGesture(DragGesture().onChanged { _ in
            isFocused = false
        })
    }

    // MARK: - 单曲结果
    
    @ViewBuilder
    private var songsResultSection: some View {
        ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, song in
            SongListRow(song: song, index: index, onArtistTap: { artistId in
                selectedArtistId = artistId
                showArtistDetail = true
            }, onDetailTap: { detailSong in
                selectedSongForDetail = detailSong
                showSongDetail = true
            }, onAlbumTap: { albumId in
                selectedAlbumId = albumId
                showAlbumDetail = true
            })
                .asButton {
                    PlayerManager.shared.play(song: song, in: viewModel.searchResults)
                    isFocused = false
                }
                .onAppear {
                    if index == viewModel.searchResults.count - 1 {
                        viewModel.loadMore()
                    }
                }
        }
        
        if viewModel.canLoadMore && !viewModel.searchResults.isEmpty {
            AsideLoadingView(text: "LOADING MORE")
                .padding(.vertical, 20)
        }
    }
    
    // MARK: - 歌手结果
    
    @ViewBuilder
    private var artistsResultSection: some View {
        ForEach(Array(viewModel.artistResults.enumerated()), id: \.element.id) { index, artist in
            Button(action: {
                selectedArtistId = artist.id
                showArtistDetail = true
            }) {
                HStack(spacing: 14) {
                    CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                        Circle().fill(Color.asideCardBackground)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.name)
                            .font(.rounded(size: 16, weight: .medium))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            if let albumSize = artist.albumSize, albumSize > 0 {
                                Text("专辑: \(albumSize)")
                                    .font(.rounded(size: 12, weight: .regular))
                                    .foregroundColor(.asideTextSecondary)
                            }
                            if let musicSize = artist.musicSize, musicSize > 0 {
                                Text("歌曲: \(musicSize)")
                                    .font(.rounded(size: 12, weight: .regular))
                                    .foregroundColor(.asideTextSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                if index == viewModel.artistResults.count - 1 {
                    viewModel.loadMore()
                }
            }
        }
        
        if viewModel.canLoadMore && !viewModel.artistResults.isEmpty {
            AsideLoadingView(text: "LOADING MORE")
                .padding(.vertical, 20)
        }
    }

    // MARK: - 歌单结果
    
    @ViewBuilder
    private var playlistsResultSection: some View {
        ForEach(Array(viewModel.playlistResults.enumerated()), id: \.element.id) { index, playlist in
            Button(action: {
                selectedPlaylist = playlist
                showPlaylistDetail = true
            }) {
                HStack(spacing: 14) {
                    CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                        RoundedRectangle(cornerRadius: 10).fill(Color.asideCardBackground)
                    }
                    .frame(width: 56, height: 56)
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.rounded(size: 16, weight: .medium))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            if let trackCount = playlist.trackCount, trackCount > 0 {
                                Text("\(trackCount)首")
                                    .font(.rounded(size: 12, weight: .regular))
                                    .foregroundColor(.asideTextSecondary)
                            }
                            if let creator = playlist.creator?.nickname {
                                Text("by \(creator)")
                                    .font(.rounded(size: 12, weight: .regular))
                                    .foregroundColor(.asideTextSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                if index == viewModel.playlistResults.count - 1 {
                    viewModel.loadMore()
                }
            }
        }
        
        if viewModel.canLoadMore && !viewModel.playlistResults.isEmpty {
            AsideLoadingView(text: "LOADING MORE")
                .padding(.vertical, 20)
        }
    }
    
    // MARK: - 专辑结果
    
    @ViewBuilder
    private var albumsResultSection: some View {
        ForEach(Array(viewModel.albumResults.enumerated()), id: \.element.id) { index, album in
            Button(action: {
                selectedAlbumId = album.id
                showAlbumDetail = true
            }) {
                HStack(spacing: 14) {
                    CachedAsyncImage(url: album.coverUrl?.sized(200)) {
                        RoundedRectangle(cornerRadius: 10).fill(Color.asideCardBackground)
                    }
                    .frame(width: 56, height: 56)
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.name)
                            .font(.rounded(size: 16, weight: .medium))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(album.artistName)
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.asideTextSecondary)
                                .lineLimit(1)
                            
                            if let size = album.size, size > 0 {
                                Text("\(size)首")
                                    .font(.rounded(size: 12, weight: .regular))
                                    .foregroundColor(.asideTextSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                if index == viewModel.albumResults.count - 1 {
                    viewModel.loadMore()
                }
            }
        }
        
        if viewModel.canLoadMore && !viewModel.albumResults.isEmpty {
            AsideLoadingView(text: "LOADING MORE")
                .padding(.vertical, 20)
        }
    }
    
    // MARK: - MV 结果
    
    @ViewBuilder
    private var mvsResultSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(viewModel.mvResults.enumerated()), id: \.element.id) { index, mv in
                MVGridCard(mv: mv) {
                    selectedMVId = MVIdItem(id: mv.id)
                    isFocused = false
                }
                .onAppear {
                    if index == viewModel.mvResults.count - 1 {
                        viewModel.loadMore()
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        
        if viewModel.canLoadMore && !viewModel.mvResults.isEmpty {
            AsideLoadingView(text: "LOADING MORE")
                .padding(.vertical, 20)
        }
    }

    // MARK: - 搜索建议浮层
    
    @ViewBuilder
    private var suggestionsOverlay: some View {
        if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
            AsideBackground()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button(action: {
                            viewModel.performSearch(keyword: suggestion)
                            isFocused = false
                        }) {
                            HStack(spacing: 16) {
                                AsideIcon(icon: .magnifyingGlass, size: 16, color: .gray)
                                
                                Text(suggestion)
                                    .font(.rounded(size: 16, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 10)
            }
            .asideBackground()
        }
    }
}
