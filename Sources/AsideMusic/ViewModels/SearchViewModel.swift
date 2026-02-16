import Foundation
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
    
    // MARK: - 网易云搜索结果
    @Published var neteaseResults: [Song] = []
    @Published var neteaseArtistResults: [ArtistInfo] = []
    @Published var neteasePlaylistResults: [Playlist] = []
    @Published var neteaseAlbumResults: [SearchAlbum] = []
    @Published var neteaseMVResults: [MV] = []
    @Published var isNeteaseLoading = false
    
    // MARK: - QQ 音乐搜索结果
    @Published var qqResults: [Song] = []
    @Published var qqArtistResults: [ArtistInfo] = []
    @Published var qqPlaylistResults: [Playlist] = []
    @Published var qqAlbumResults: [SearchAlbum] = []
    @Published var isQQLoading = false
    
    // MARK: - 通用状态
    @Published var suggestions: [String] = []
    @Published var searchHistory: [SearchHistory] = []
    @Published var hotSearchItems: [HotSearchItem] = []
    @Published var hasSearched = false
    @Published var showSuggestions = false
    @Published var currentTab: SearchTab = .songs
    
    /// 当前展开查看的平台（nil = 双列模式，非 nil = 单平台全屏列表）
    @Published var expandedSource: MusicSource? = nil

    private var neteaseCurrentPage = 0
    private var qqCurrentPage = 0
    private var neteaseCanLoadMore = true
    private var qqCanLoadMore = true
    private var isFetchingMoreNetease = false
    private var isFetchingMoreQQ = false
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private let cacheManager = OptimizedCacheManager.shared

    // MARK: - 兼容属性（供现有 UI 使用）
    
    var isLoading: Bool { isNeteaseLoading && isQQLoading }
    var canLoadMore: Bool {
        if let source = expandedSource {
            return source == .netease ? neteaseCanLoadMore : qqCanLoadMore
        }
        return neteaseCanLoadMore || qqCanLoadMore
    }
    
    /// 合并的歌曲结果（兼容旧代码）
    var searchResults: [Song] { neteaseResults + qqResults }

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
        neteaseResults = []
        neteaseArtistResults = []
        neteasePlaylistResults = []
        neteaseAlbumResults = []
        neteaseMVResults = []
        qqResults = []
        qqArtistResults = []
        qqPlaylistResults = []
        qqAlbumResults = []
        suggestions = []
        hasSearched = false
        showSuggestions = false
        expandedSource = nil
        neteaseCurrentPage = 0
        qqCurrentPage = 0
        neteaseCanLoadMore = true
        qqCanLoadMore = true
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
        hasSearched = true
        showSuggestions = false
        suggestions = []
        neteaseCurrentPage = 0
        qqCurrentPage = 0
        neteaseCanLoadMore = true
        qqCanLoadMore = true
        expandedSource = nil
        
        if query != keyword {
            query = keyword
        }
        
        cacheManager.addSearchHistory(keyword: keyword)
        loadSearchHistory()

        // 同时搜索两个平台
        executeNeteaseSearch(keyword: keyword, offset: 0, isLoadMore: false)
        executeQQSearch(keyword: keyword, page: 1, isLoadMore: false)
    }
    
    /// 切换搜索类型时重新搜索
    func switchTab(_ tab: SearchTab) {
        guard tab != currentTab else { return }
        currentTab = tab
        expandedSource = nil
        guard hasSearched, !query.isEmpty else { return }
        
        // 检查两个平台是否都已有该类型的结果
        let neteaseHasResults = hasNeteaseResults(for: tab)
        let qqHasResults = hasQQResults(for: tab)
        
        if !neteaseHasResults {
            neteaseCurrentPage = 0
            neteaseCanLoadMore = true
            executeNeteaseSearch(keyword: query, offset: 0, isLoadMore: false)
        }
        if !qqHasResults {
            qqCurrentPage = 0
            qqCanLoadMore = true
            executeQQSearch(keyword: query, page: 1, isLoadMore: false)
        }
    }
    
    /// 加载更多（指定平台）
    func loadMore(source: MusicSource) {
        guard !query.isEmpty else { return }
        
        switch source {
        case .netease:
            guard !isFetchingMoreNetease && neteaseCanLoadMore else { return }
            isFetchingMoreNetease = true
            let offset = (neteaseCurrentPage + 1) * 30
            executeNeteaseSearch(keyword: query, offset: offset, isLoadMore: true)
        case .qqmusic:
            guard !isFetchingMoreQQ && qqCanLoadMore else { return }
            isFetchingMoreQQ = true
            let page = qqCurrentPage + 2 // page 从 1 开始
            executeQQSearch(keyword: query, page: page, isLoadMore: true)
        }
    }
    
    /// 兼容旧的 loadMore
    func loadMore() {
        if let source = expandedSource {
            loadMore(source: source)
        }
    }

    // MARK: - 网易云搜索
    
    private func executeNeteaseSearch(keyword: String, offset: Int, isLoadMore: Bool) {
        isNeteaseLoading = !isLoadMore
        
        switch currentTab {
        case .songs:
            apiService.searchSongs(keyword: keyword, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isNeteaseLoading = false
                    if isLoadMore { self?.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] songs in
                    guard let self = self else { return }
                    self.handleNeteasePagination(newItems: songs, existing: &self.neteaseResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .artists:
            apiService.searchArtists(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isNeteaseLoading = false
                    if isLoadMore { self?.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] artists in
                    guard let self = self else { return }
                    self.handleNeteasePagination(newItems: artists, existing: &self.neteaseArtistResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .playlists:
            apiService.searchPlaylists(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isNeteaseLoading = false
                    if isLoadMore { self?.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] playlists in
                    guard let self = self else { return }
                    self.handleNeteasePagination(newItems: playlists, existing: &self.neteasePlaylistResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .albums:
            apiService.searchAlbums(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isNeteaseLoading = false
                    if isLoadMore { self?.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] albums in
                    guard let self = self else { return }
                    self.handleNeteasePagination(newItems: albums, existing: &self.neteaseAlbumResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .mvs:
            apiService.searchMVs(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isNeteaseLoading = false
                    if isLoadMore { self?.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] mvs in
                    guard let self = self else { return }
                    self.handleNeteasePagination(newItems: mvs, existing: &self.neteaseMVResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
        }
    }
    
    // MARK: - QQ 音乐搜索
    
    private func executeQQSearch(keyword: String, page: Int, isLoadMore: Bool) {
        isQQLoading = !isLoadMore
        
        switch currentTab {
        case .songs:
            apiService.searchQQSongs(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isQQLoading = false
                    if isLoadMore { self?.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] songs in
                    guard let self = self else { return }
                    self.handleQQPagination(newItems: songs, existing: &self.qqResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .artists:
            apiService.searchQQArtists(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isQQLoading = false
                    if isLoadMore { self?.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] artists in
                    guard let self = self else { return }
                    self.handleQQPagination(newItems: artists, existing: &self.qqArtistResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .playlists:
            apiService.searchQQPlaylists(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isQQLoading = false
                    if isLoadMore { self?.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] playlists in
                    guard let self = self else { return }
                    self.handleQQPagination(newItems: playlists, existing: &self.qqPlaylistResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .albums:
            apiService.searchQQAlbums(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isQQLoading = false
                    if isLoadMore { self?.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] albums in
                    guard let self = self else { return }
                    self.handleQQPagination(newItems: albums, existing: &self.qqAlbumResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
            
        case .mvs:
            // QQ 音乐 MV 搜索暂不支持
            isQQLoading = false
            if isLoadMore { isFetchingMoreQQ = false }
            qqCanLoadMore = false
        }
    }

    // MARK: - 分页处理
    
    private func handleNeteasePagination<T: Identifiable>(newItems: [T], existing: inout [T], isLoadMore: Bool) where T.ID: Hashable {
        if isLoadMore {
            if !newItems.isEmpty {
                let existingIds = Set(existing.map { $0.id })
                let filtered = newItems.filter { !existingIds.contains($0.id) }
                if !filtered.isEmpty {
                    existing.append(contentsOf: filtered)
                }
                neteaseCurrentPage += 1
                neteaseCanLoadMore = newItems.count >= 30
            } else {
                neteaseCanLoadMore = false
            }
        } else {
            existing = newItems
            neteaseCanLoadMore = !newItems.isEmpty
        }
    }
    
    private func handleQQPagination<T: Identifiable>(newItems: [T], existing: inout [T], isLoadMore: Bool) where T.ID: Hashable {
        if isLoadMore {
            if !newItems.isEmpty {
                let existingIds = Set(existing.map { $0.id })
                let filtered = newItems.filter { !existingIds.contains($0.id) }
                if !filtered.isEmpty {
                    existing.append(contentsOf: filtered)
                }
                qqCurrentPage += 1
                qqCanLoadMore = newItems.count >= 30
            } else {
                qqCanLoadMore = false
            }
        } else {
            existing = newItems
            qqCanLoadMore = !newItems.isEmpty
        }
    }
    
    // MARK: - 辅助方法
    
    private func hasNeteaseResults(for tab: SearchTab) -> Bool {
        switch tab {
        case .songs: return !neteaseResults.isEmpty
        case .artists: return !neteaseArtistResults.isEmpty
        case .playlists: return !neteasePlaylistResults.isEmpty
        case .albums: return !neteaseAlbumResults.isEmpty
        case .mvs: return !neteaseMVResults.isEmpty
        }
    }
    
    private func hasQQResults(for tab: SearchTab) -> Bool {
        switch tab {
        case .songs: return !qqResults.isEmpty
        case .artists: return !qqArtistResults.isEmpty
        case .playlists: return !qqPlaylistResults.isEmpty
        case .albums: return !qqAlbumResults.isEmpty
        case .mvs: return false // QQ 暂不支持 MV 搜索
        }
    }
    
    var currentResultsEmpty: Bool {
        switch currentTab {
        case .songs: return neteaseResults.isEmpty && qqResults.isEmpty
        case .artists: return neteaseArtistResults.isEmpty && qqArtistResults.isEmpty
        case .playlists: return neteasePlaylistResults.isEmpty && qqPlaylistResults.isEmpty
        case .albums: return neteaseAlbumResults.isEmpty && qqAlbumResults.isEmpty
        case .mvs: return neteaseMVResults.isEmpty
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
