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
    @Published private(set) var activeSearchKeyword: String = ""
    
    // MARK: - ncm搜索结果
    @Published var neteaseResults: [Song] = []
    @Published var neteaseArtistResults: [ArtistInfo] = []
    @Published var neteasePlaylistResults: [Playlist] = []
    @Published var neteaseAlbumResults: [SearchAlbum] = []
    @Published var neteaseMVResults: [MV] = []
    @Published var neteaseSongTotal: Int?
    @Published var isNeteaseLoading = false
    
    // MARK: - qcm搜索结果
    @Published var qqResults: [Song] = []
    @Published var qqArtistResults: [ArtistInfo] = []
    @Published var qqPlaylistResults: [Playlist] = []
    @Published var qqAlbumResults: [SearchAlbum] = []
    @Published var qqMVResults: [QQMV] = []
    @Published var qqSongTotal: Int?
    @Published var isQQLoading = false
    
    // MARK: - 汽水音乐搜索结果
    @Published var qishuiResults: [Song] = []
    @Published var qishuiSongTotal: Int?
    @Published var isQishuiLoading = false

    // MARK: - kcm搜索结果
    @Published var kugouResults: [Song] = []
    @Published var kugouArtistResults: [ArtistInfo] = []
    @Published var kugouPlaylistResults: [Playlist] = []
    @Published var kugouAlbumResults: [SearchAlbum] = []
    @Published var kugouMVResults: [KCMMV] = []
    @Published var kugouSongTotal: Int?
    @Published var isKugouLoading = false
    @Published var kugouErrorMessage: String?

    // MARK: - Apple Music 搜索结果
    @Published var appleMusicResults: [Song] = []
    @Published var appleMusicArtistResults: [ArtistInfo] = []
    @Published var appleMusicPlaylistResults: [Playlist] = []
    @Published var appleMusicAlbumResults: [SearchAlbum] = []
    @Published var isAppleMusicLoading = false
    @Published var appleMusicErrorMessage: String?
    
    // MARK: - 通用状态
    @Published var suggestions: [String] = []
    @Published var searchHistory: [SearchHistory] = []
    @Published var hotSearchItems: [HotSearchItem] = []
    @Published var hasSearched = false
    @Published var showSuggestions = false
    @Published var currentTab: SearchTab = .songs
    
    // MARK: - 搜索默认词 & 多类型匹配
    @Published var defaultKeyword: SearchDefaultResult?
    @Published var multimatchResult: SearchMultimatchResult?
    
    /// 当前展开查看的平台（nil = 双列模式，非 nil = 单平台全屏列表）
    @Published var expandedSource: MusicSource? = nil
    
    /// 当前选择的平台标签页
    @Published var selectedPlatform: MusicSource = .netease
    
    /// performSearch 最近一次搜索的关键词，用于 debounce 去重
    private var lastSearchedKeyword: String?

    private var neteaseCurrentPage = 0
    private var qqCurrentPage = 0
    private var qishuiCurrentPage = 0
    private var kugouCurrentPage = 1
    private var appleMusicCurrentPage = 0
    private var neteaseCanLoadMore = true
    private var qqCanLoadMore = true
    private var qishuiCanLoadMore = true
    private var kugouCanLoadMore = true
    private var appleMusicCanLoadMore = true
    private var neteaseCanLoadMoreByTab: [SearchTab: Bool] = [:]
    private var qqCanLoadMoreByTab: [SearchTab: Bool] = [:]
    private var kugouCanLoadMoreByTab: [SearchTab: Bool] = [:]
    private var appleMusicCanLoadMoreByTab: [SearchTab: Bool] = [:]
    private var kugouPageByTab: [SearchTab: Int] = [:]
    private var appleMusicPageByTab: [SearchTab: Int] = [:]
    private var isFetchingMoreNetease = false
    private var isFetchingMoreQQ = false
    private var isFetchingMoreQishui = false
    private var isFetchingMoreKugou = false
    private var isFetchingMoreAppleMusic = false
    private var qishuiTotalCountingTask: Task<Void, Never>?
    private var appleMusicSearchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellables = Set<AnyCancellable>()
    private var suggestionCancellable: AnyCancellable?
    private var neteaseRequestID = 0
    private var qqRequestID = 0
    private var qishuiRequestID = 0
    private var kugouRequestID = 0
    private var appleMusicRequestID = 0
    private let apiService = APIService.shared
    private let appleMusicService = AppleMusicService.shared
    private let cacheManager = OptimizedCacheManager.shared

    // MARK: - 兼容属性（供现有 UI 使用）
    
    var isLoading: Bool {
        isNeteaseLoading
            && isQQLoading
            && isQishuiLoading
            && isKugouLoading
            && isAppleMusicLoading
    }
    var canLoadMore: Bool {
        if let source = expandedSource {
            switch source {
            case .netease: return neteaseCanLoadMore
            case .qqmusic: return qqCanLoadMore
            case .qishui: return qishuiCanLoadMore
            case .kugou: return kugouCanLoadMore
            case .appleMusic: return appleMusicCanLoadMore
            case .local: return false
            }
        }
        return neteaseCanLoadMore || qqCanLoadMore || qishuiCanLoadMore || kugouCanLoadMore || appleMusicCanLoadMore
    }
    
    /// 合并的歌曲结果（兼容旧代码）
    var searchResults: [Song] {
        neteaseResults + qqResults + qishuiResults + kugouResults + appleMusicResults
    }

    init() {
        loadSearchHistory()
        loadHotSearch()
        loadSearchDefault()
        
        $query
            .debounce(for: .milliseconds(AppConfig.UI.searchDebounceMs), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] keyword in
                guard let self = self else { return }
                if !keyword.isEmpty {
                    if keyword == self.lastSearchedKeyword {
                        self.lastSearchedKeyword = nil
                        return
                    }
                    self.showSuggestions = true
                    self.fetchSuggestions(keyword: keyword)
                } else {
                    self.showSuggestions = false
                    self.suggestions = []
                }
            }
            .store(in: &cancellables)
    }
    
    private func resetState() {
        qishuiTotalCountingTask?.cancel()
        qishuiTotalCountingTask = nil
        appleMusicSearchTask?.cancel()
        appleMusicSearchTask = nil
        suggestionCancellable?.cancel()
        suggestionCancellable = nil
        searchCancellables.removeAll()
        neteaseRequestID += 1
        qqRequestID += 1
        qishuiRequestID += 1
        kugouRequestID += 1
        appleMusicRequestID += 1
        neteaseResults = []
        neteaseArtistResults = []
        neteasePlaylistResults = []
        neteaseAlbumResults = []
        neteaseMVResults = []
        neteaseSongTotal = nil
        qqResults = []
        qqArtistResults = []
        qqPlaylistResults = []
        qqAlbumResults = []
        qqMVResults = []
        qqSongTotal = nil
        qishuiResults = []
        qishuiSongTotal = nil
        kugouResults = []
        kugouArtistResults = []
        kugouPlaylistResults = []
        kugouAlbumResults = []
        kugouMVResults = []
        kugouSongTotal = nil
        kugouErrorMessage = nil
        appleMusicResults = []
        appleMusicArtistResults = []
        appleMusicPlaylistResults = []
        appleMusicAlbumResults = []
        appleMusicErrorMessage = nil
        suggestions = []
        hasSearched = false
        activeSearchKeyword = ""
        lastSearchedKeyword = nil
        showSuggestions = false
        expandedSource = nil
        multimatchResult = nil
        neteaseCurrentPage = 0
        qqCurrentPage = 0
        qishuiCurrentPage = 0
        kugouCurrentPage = 1
        appleMusicCurrentPage = 0
        neteaseCanLoadMore = true
        qqCanLoadMore = true
        qishuiCanLoadMore = true
        kugouCanLoadMore = true
        appleMusicCanLoadMore = true
        neteaseCanLoadMoreByTab = [:]
        qqCanLoadMoreByTab = [:]
        kugouCanLoadMoreByTab = [:]
        appleMusicCanLoadMoreByTab = [:]
        kugouPageByTab = [:]
        appleMusicPageByTab = [:]
        isNeteaseLoading = false
        isQQLoading = false
        isQishuiLoading = false
        isKugouLoading = false
        isAppleMusicLoading = false
        isFetchingMoreNetease = false
        isFetchingMoreQQ = false
        isFetchingMoreQishui = false
        isFetchingMoreKugou = false
        isFetchingMoreAppleMusic = false
    }

    private func resetResultsForNewKeyword() {
        searchCancellables.removeAll()
        neteaseResults = []
        neteaseArtistResults = []
        neteasePlaylistResults = []
        neteaseAlbumResults = []
        neteaseMVResults = []
        qqResults = []
        qqArtistResults = []
        qqPlaylistResults = []
        qqAlbumResults = []
        qqMVResults = []
        qishuiResults = []
        kugouResults = []
        kugouArtistResults = []
        kugouPlaylistResults = []
        kugouAlbumResults = []
        kugouMVResults = []
        kugouErrorMessage = nil
        appleMusicResults = []
        appleMusicArtistResults = []
        appleMusicPlaylistResults = []
        appleMusicAlbumResults = []
        appleMusicErrorMessage = nil
        neteaseCanLoadMoreByTab = [:]
        qqCanLoadMoreByTab = [:]
        kugouCanLoadMoreByTab = [:]
        appleMusicCanLoadMoreByTab = [:]
        kugouPageByTab = [:]
        appleMusicPageByTab = [:]
        multimatchResult = nil
        isNeteaseLoading = false
        isQQLoading = false
        isQishuiLoading = false
        isKugouLoading = false
        isAppleMusicLoading = false
        isFetchingMoreNetease = false
        isFetchingMoreQQ = false
        isFetchingMoreQishui = false
        isFetchingMoreKugou = false
        isFetchingMoreAppleMusic = false
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
    
    func loadSearchDefault() {
        apiService.fetchSearchDefault()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] result in
                if !result.showKeyword.isEmpty {
                    self?.defaultKeyword = result
                }
            })
            .store(in: &cancellables)
    }
    
    func fetchSuggestions(keyword: String) {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        suggestionCancellable?.cancel()
        showSuggestions = true
        suggestionCancellable = apiService.fetchSearchSuggestions(keyword: keyword)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] suggestions in
                guard let self,
                      self.query.trimmingCharacters(in: .whitespacesAndNewlines) == keyword else { return }
                self.suggestions = suggestions
            })
    }

    func beginSearchEditing() {
        let typedKeyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSearchedKeyword = nil
        if hasSearched, typedKeyword == activeSearchKeyword {
            query = ""
        }
        showSuggestions = false
        suggestions = []
    }
    
    func performSearch(keyword: String) {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        qishuiTotalCountingTask?.cancel()
        qishuiTotalCountingTask = nil
        appleMusicSearchTask?.cancel()
        appleMusicSearchTask = nil
        suggestionCancellable?.cancel()
        suggestionCancellable = nil
        resetResultsForNewKeyword()
        lastSearchedKeyword = keyword
        showSuggestions = false
        suggestions = []
        neteaseCurrentPage = 0
        qqCurrentPage = 0
        qishuiCurrentPage = 0
        kugouCurrentPage = 1
        appleMusicCurrentPage = 0
        neteaseCanLoadMore = true
        qqCanLoadMore = true
        qishuiCanLoadMore = true
        kugouCanLoadMore = true
        appleMusicCanLoadMore = true
        expandedSource = nil
        neteaseSongTotal = nil
        qqSongTotal = nil
        qishuiSongTotal = nil
        kugouSongTotal = nil
        
        if query != keyword {
            query = keyword
        }
        activeSearchKeyword = keyword
        hasSearched = true
        
        cacheManager.addSearchHistory(keyword: keyword)
        loadSearchHistory()

        // 已经授权过 Apple Music 时静默并行搜索；首次授权只在用户主动
        // 切到 Apple Music 标签后触发，避免普通搜索突然弹系统权限框。
        executeNeteaseSearch(keyword: keyword, offset: 0, isLoadMore: false)
        executeQQSearch(keyword: keyword, page: 1, isLoadMore: false)
        executeQishuiSearch(keyword: keyword, page: 0, isLoadMore: false)
        executeKugouSearch(keyword: keyword, page: 1, isLoadMore: false)
        if appleMusicService.isAuthorized {
            executeAppleMusicSearch(keyword: keyword, page: 0, isLoadMore: false)
        }
        
        // 获取多类型最佳匹配
        apiService.fetchSearchMultimatch(keywords: keyword)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] result in
                guard let self, self.activeSearchKeyword == keyword else { return }
                // 只有至少有一个匹配结果时才显示
                if result.artist != nil || result.album != nil || result.playlist != nil {
                    self.multimatchResult = result
                } else {
                    self.multimatchResult = nil
                }
            })
            .store(in: &searchCancellables)
    }

    func selectPlatform(_ platform: MusicSource) {
        selectedPlatform = platform
        guard hasSearched, !requestKeyword.isEmpty else { return }
        switch platform {
        case .kugou where !hasKugouResults(for: currentTab) && !isKugouLoading:
            kugouCanLoadMore = true
            executeKugouSearch(keyword: requestKeyword, page: 1, isLoadMore: false)
        case .appleMusic where currentTab != .mvs && !hasAppleMusicResults(for: currentTab) && !isAppleMusicLoading:
            appleMusicCanLoadMore = true
            executeAppleMusicSearch(keyword: requestKeyword, page: 0, isLoadMore: false)
        default:
            break
        }
    }
    
    /// 切换搜索类型时重新搜索
    func switchTab(_ tab: SearchTab) {
        guard tab != currentTab else { return }
        neteaseCanLoadMoreByTab[currentTab] = neteaseCanLoadMore
        qqCanLoadMoreByTab[currentTab] = qqCanLoadMore
        kugouCanLoadMoreByTab[currentTab] = kugouCanLoadMore
        appleMusicCanLoadMoreByTab[currentTab] = appleMusicCanLoadMore
        currentTab = tab
        neteaseCanLoadMore = neteaseCanLoadMoreByTab[tab] ?? true
        qqCanLoadMore = qqCanLoadMoreByTab[tab] ?? true
        kugouCanLoadMore = kugouCanLoadMoreByTab[tab] ?? true
        appleMusicCanLoadMore = appleMusicCanLoadMoreByTab[tab] ?? true
        expandedSource = nil
        
        if tab != .songs && selectedPlatform == .qishui {
            selectedPlatform = .netease
        } else if tab == .mvs && selectedPlatform == .appleMusic {
            selectedPlatform = .netease
        }
        
        let keyword = requestKeyword
        guard hasSearched, !keyword.isEmpty else { return }
        
        // 检查两个平台是否都已有该类型的结果
        let neteaseHasResults = hasNeteaseResults(for: tab)
        let qqHasResults = hasQQResults(for: tab)
        
        if !neteaseHasResults {
            neteaseCurrentPage = 0
            neteaseCanLoadMore = true
            executeNeteaseSearch(keyword: keyword, offset: 0, isLoadMore: false)
        }
        if !qqHasResults {
            qqCurrentPage = 0
            qqCanLoadMore = true
            executeQQSearch(keyword: keyword, page: 1, isLoadMore: false)
        }
        if !hasKugouResults(for: tab) {
            kugouCanLoadMore = true
            executeKugouSearch(keyword: keyword, page: 1, isLoadMore: false)
        }
        if tab != .mvs, !hasAppleMusicResults(for: tab), appleMusicService.isAuthorized {
            appleMusicCanLoadMore = true
            executeAppleMusicSearch(keyword: keyword, page: 0, isLoadMore: false)
        }
    }
    
    /// 加载更多（指定平台）
    func loadMore(source: MusicSource) {
        let keyword = requestKeyword
        guard !keyword.isEmpty else { return }
        
        switch source {
        case .netease:
            guard !isFetchingMoreNetease && neteaseCanLoadMore else { return }
            isFetchingMoreNetease = true
            let offset = neteaseResultCount(for: currentTab)
            executeNeteaseSearch(keyword: keyword, offset: offset, isLoadMore: true)
        case .qqmusic:
            guard !isFetchingMoreQQ && qqCanLoadMore else { return }
            isFetchingMoreQQ = true
            let page = qqResultCount(for: currentTab) / 30 + 1
            executeQQSearch(keyword: keyword, page: page, isLoadMore: true)
        case .qishui:
            guard !isFetchingMoreQishui && qishuiCanLoadMore else { return }
            isFetchingMoreQishui = true
            let page = qishuiCurrentPage + 1 // qishui page 从 0 开始
            executeQishuiSearch(keyword: keyword, page: page, isLoadMore: true)
        case .kugou:
            guard !isFetchingMoreKugou && kugouCanLoadMore else { return }
            isFetchingMoreKugou = true
            executeKugouSearch(
                keyword: keyword,
                page: (kugouPageByTab[currentTab] ?? 1) + 1,
                isLoadMore: true
            )
        case .appleMusic:
            guard !isFetchingMoreAppleMusic && appleMusicCanLoadMore else { return }
            isFetchingMoreAppleMusic = true
            executeAppleMusicSearch(
                keyword: keyword,
                page: (appleMusicPageByTab[currentTab] ?? 0) + 1,
                isLoadMore: true
            )
        case .local:
            return
        }
    }
    
    /// 兼容旧的 loadMore
    func loadMore() {
        if let source = expandedSource {
            loadMore(source: source)
        }
    }

    // MARK: - ncm搜索

    private func isCurrentNeteaseRequest(_ requestID: Int, keyword: String) -> Bool {
        neteaseRequestID == requestID && activeSearchKeyword == keyword
    }

    private func isCurrentQQRequest(_ requestID: Int, keyword: String) -> Bool {
        qqRequestID == requestID && activeSearchKeyword == keyword
    }

    private func isCurrentQishuiRequest(_ requestID: Int, keyword: String) -> Bool {
        qishuiRequestID == requestID && activeSearchKeyword == keyword
    }

    private func isCurrentKugouRequest(_ requestID: Int, keyword: String) -> Bool {
        kugouRequestID == requestID && activeSearchKeyword == keyword
    }

    private func isCurrentAppleMusicRequest(_ requestID: Int, keyword: String) -> Bool {
        appleMusicRequestID == requestID && activeSearchKeyword == keyword
    }
    
    /// 按当前结果类型执行 ncm 搜索；请求代际与关键词共同阻止过期响应覆盖新结果。
    private func executeNeteaseSearch(keyword: String, offset: Int, isLoadMore: Bool) {
        neteaseRequestID += 1
        let requestID = neteaseRequestID
        if !isLoadMore { isFetchingMoreNetease = false }
        isNeteaseLoading = !isLoadMore
        
        switch currentTab {
        case .songs:
            apiService.searchSongsWithTotal(keyword: keyword, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.isNeteaseLoading = false
                    if isLoadMore { self.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] result in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    SongArtworkFallbackRegistry.shared.register(result.songs)
                    if let total = result.total {
                        self.neteaseSongTotal = total
                    }
                    self.handleNeteasePagination(newItems: result.songs, existing: &self.neteaseResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .artists:
            apiService.searchArtists(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.isNeteaseLoading = false
                    if isLoadMore { self.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] artists in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.handleNeteasePagination(newItems: artists, existing: &self.neteaseArtistResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .playlists:
            apiService.searchPlaylists(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.isNeteaseLoading = false
                    if isLoadMore { self.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] playlists in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.handleNeteasePagination(newItems: playlists, existing: &self.neteasePlaylistResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .albums:
            apiService.searchAlbums(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.isNeteaseLoading = false
                    if isLoadMore { self.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] albums in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.handleNeteasePagination(newItems: albums, existing: &self.neteaseAlbumResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .mvs:
            apiService.searchMVs(keyword: keyword, limit: 30, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.isNeteaseLoading = false
                    if isLoadMore { self.isFetchingMoreNetease = false }
                }, receiveValue: { [weak self] mvs in
                    guard let self, self.isCurrentNeteaseRequest(requestID, keyword: keyword) else { return }
                    self.handleNeteasePagination(newItems: mvs, existing: &self.neteaseMVResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
        }
    }
    
    // MARK: - qcm搜索
    
    /// 按当前结果类型执行 qcm 搜索，并将首屏与翻页状态分别写入对应结果集。
    private func executeQQSearch(keyword: String, page: Int, isLoadMore: Bool) {
        qqRequestID += 1
        let requestID = qqRequestID
        if !isLoadMore { isFetchingMoreQQ = false }
        isQQLoading = !isLoadMore
        
        switch currentTab {
        case .songs:
            apiService.searchQQSongsWithTotal(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.isQQLoading = false
                    if isLoadMore { self.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] result in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    SongArtworkFallbackRegistry.shared.register(result.songs)
                    if let total = result.total {
                        self.qqSongTotal = total
                    }
                    self.handleQQPagination(newItems: result.songs, existing: &self.qqResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .artists:
            apiService.searchQQArtists(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.isQQLoading = false
                    if isLoadMore { self.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] artists in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.handleQQPagination(newItems: artists, existing: &self.qqArtistResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .playlists:
            apiService.searchQQPlaylists(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.isQQLoading = false
                    if isLoadMore { self.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] playlists in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.handleQQPagination(newItems: playlists, existing: &self.qqPlaylistResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .albums:
            apiService.searchQQAlbums(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.isQQLoading = false
                    if isLoadMore { self.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] albums in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.handleQQPagination(newItems: albums, existing: &self.qqAlbumResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
            
        case .mvs:
            apiService.searchQQMVs(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.isQQLoading = false
                    if isLoadMore { self.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] mvs in
                    guard let self, self.isCurrentQQRequest(requestID, keyword: keyword) else { return }
                    self.handleQQPagination(newItems: mvs, existing: &self.qqMVResults, isLoadMore: isLoadMore)
                })
                .store(in: &searchCancellables)
        }
    }

    // MARK: - qsm 搜索

    /// 执行 qsm 歌曲搜索；总数缺失时继续后台计数，并用 `hasMore` 维持分页状态。
    private func executeQishuiSearch(keyword: String, page: Int, isLoadMore: Bool) {
        qishuiRequestID += 1
        let requestID = qishuiRequestID
        guard currentTab == .songs else { return }
        if !isLoadMore { isFetchingMoreQishui = false }
        isQishuiLoading = !isLoadMore
        apiService.searchQishuiSongsWithTotal(keyword: keyword, page: page)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.isCurrentQishuiRequest(requestID, keyword: keyword) else { return }
                self.isQishuiLoading = false
                if isLoadMore { self.isFetchingMoreQishui = false }
            }, receiveValue: { [weak self] result in
                guard let self, self.isCurrentQishuiRequest(requestID, keyword: keyword) else { return }
                SongArtworkFallbackRegistry.shared.register(result.songs)
                if let total = result.total {
                    self.qishuiSongTotal = total
                }
                self.handleQishuiPagination(newItems: result.songs, existing: &self.qishuiResults, isLoadMore: isLoadMore)

                if let total = result.total {
                    self.qishuiCanLoadMore = self.qishuiResults.count < total
                } else {
                    self.qishuiCanLoadMore = result.hasMore && !result.songs.isEmpty
                    if !result.hasMore {
                        self.qishuiSongTotal = max(self.qishuiSongTotal ?? 0, self.qishuiResults.count)
                    } else if !isLoadMore {
                        self.startQishuiTotalCounting(keyword: keyword, startPage: page + 1)
                    }
                }
            })
            .store(in: &searchCancellables)
    }

    // MARK: - kcm 搜索

    private func executeKugouSearch(keyword: String, page: Int, isLoadMore: Bool) {
        kugouRequestID += 1
        let requestID = kugouRequestID
        let tab = currentTab
        if !isLoadMore { isFetchingMoreKugou = false }
        isKugouLoading = !isLoadMore
        kugouErrorMessage = nil

        let completion: (Subscribers.Completion<Error>) -> Void = { [weak self] completion in
            guard let self, self.isCurrentKugouRequest(requestID, keyword: keyword) else { return }
            self.isKugouLoading = false
            self.isFetchingMoreKugou = false
            if case .failure(let error) = completion {
                self.kugouCanLoadMore = false
                self.kugouCanLoadMoreByTab[tab] = false
                self.kugouErrorMessage = error.localizedDescription
            }
        }

        switch tab {
        case .songs:
            apiService.searchKugouSongsWithTotal(keyword: keyword, page: page, pageSize: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: completion, receiveValue: { [weak self] result in
                    guard let self, self.isCurrentKugouRequest(requestID, keyword: keyword) else { return }
                    SongArtworkFallbackRegistry.shared.register(result.songs)
                    Self.mergeSearchItems(result.songs, into: &self.kugouResults, isLoadMore: isLoadMore)
                    self.kugouSongTotal = result.total
                    self.kugouCanLoadMore = result.hasMore
                    self.kugouCanLoadMoreByTab[tab] = result.hasMore
                    self.kugouCurrentPage = page
                    self.kugouPageByTab[tab] = page
                })
                .store(in: &searchCancellables)
        case .artists:
            apiService.searchKugouArtists(keyword: keyword, page: page, pageSize: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: completion, receiveValue: { [weak self] result in
                    guard let self, self.isCurrentKugouRequest(requestID, keyword: keyword) else { return }
                    Self.mergeSearchItems(result.artists, into: &self.kugouArtistResults, isLoadMore: isLoadMore)
                    self.kugouCanLoadMore = result.hasMore
                    self.kugouCanLoadMoreByTab[tab] = result.hasMore
                    self.kugouPageByTab[tab] = page
                })
                .store(in: &searchCancellables)
        case .playlists:
            apiService.searchKugouPlaylists(keyword: keyword, page: page, pageSize: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: completion, receiveValue: { [weak self] result in
                    guard let self, self.isCurrentKugouRequest(requestID, keyword: keyword) else { return }
                    Self.mergeSearchItems(result.playlists, into: &self.kugouPlaylistResults, isLoadMore: isLoadMore)
                    self.kugouCanLoadMore = result.hasMore
                    self.kugouCanLoadMoreByTab[tab] = result.hasMore
                    self.kugouPageByTab[tab] = page
                })
                .store(in: &searchCancellables)
        case .albums:
            apiService.searchKugouAlbums(keyword: keyword, page: page, pageSize: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: completion, receiveValue: { [weak self] result in
                    guard let self, self.isCurrentKugouRequest(requestID, keyword: keyword) else { return }
                    Self.mergeSearchItems(result.albums, into: &self.kugouAlbumResults, isLoadMore: isLoadMore)
                    self.kugouCanLoadMore = result.hasMore
                    self.kugouCanLoadMoreByTab[tab] = result.hasMore
                    self.kugouPageByTab[tab] = page
                })
                .store(in: &searchCancellables)
        case .mvs:
            apiService.searchKugouMVs(keyword: keyword, page: page, pageSize: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: completion, receiveValue: { [weak self] result in
                    guard let self, self.isCurrentKugouRequest(requestID, keyword: keyword) else { return }
                    Self.mergeSearchItems(result.mvs, into: &self.kugouMVResults, isLoadMore: isLoadMore)
                    self.kugouCanLoadMore = result.hasMore
                    self.kugouCanLoadMoreByTab[tab] = result.hasMore
                    self.kugouPageByTab[tab] = page
                })
                .store(in: &searchCancellables)
        }
    }

    // MARK: - Apple Music 搜索执行

    private func executeAppleMusicSearch(keyword: String, page: Int, isLoadMore: Bool) {
        appleMusicRequestID += 1
        let requestID = appleMusicRequestID
        let tab = currentTab
        guard tab != .mvs else { return }
        if !isLoadMore { isFetchingMoreAppleMusic = false }
        isAppleMusicLoading = !isLoadMore
        appleMusicErrorMessage = nil
        appleMusicSearchTask?.cancel()
        appleMusicSearchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let pageSize = 25
                switch tab {
                case .songs:
                    let result = try await appleMusicService.searchSongs(term: keyword, offset: page * pageSize, limit: pageSize)
                    guard !Task.isCancelled, isCurrentAppleMusicRequest(requestID, keyword: keyword) else { return }
                    SongArtworkFallbackRegistry.shared.register(result.songs)
                    Self.mergeSearchItems(result.songs, into: &appleMusicResults, isLoadMore: isLoadMore)
                    appleMusicCanLoadMore = result.hasMore
                    appleMusicCanLoadMoreByTab[tab] = result.hasMore
                case .artists:
                    let result = try await appleMusicService.searchArtists(term: keyword, offset: page * pageSize, limit: pageSize)
                    guard !Task.isCancelled, isCurrentAppleMusicRequest(requestID, keyword: keyword) else { return }
                    Self.mergeSearchItems(result.artists, into: &appleMusicArtistResults, isLoadMore: isLoadMore)
                    appleMusicCanLoadMore = result.hasMore
                    appleMusicCanLoadMoreByTab[tab] = result.hasMore
                case .playlists:
                    let result = try await appleMusicService.searchPlaylists(term: keyword, offset: page * pageSize, limit: pageSize)
                    guard !Task.isCancelled, isCurrentAppleMusicRequest(requestID, keyword: keyword) else { return }
                    Self.mergeSearchItems(result.playlists, into: &appleMusicPlaylistResults, isLoadMore: isLoadMore)
                    appleMusicCanLoadMore = result.hasMore
                    appleMusicCanLoadMoreByTab[tab] = result.hasMore
                case .albums:
                    let result = try await appleMusicService.searchAlbums(term: keyword, offset: page * pageSize, limit: pageSize)
                    guard !Task.isCancelled, isCurrentAppleMusicRequest(requestID, keyword: keyword) else { return }
                    Self.mergeSearchItems(result.albums, into: &appleMusicAlbumResults, isLoadMore: isLoadMore)
                    appleMusicCanLoadMore = result.hasMore
                    appleMusicCanLoadMoreByTab[tab] = result.hasMore
                case .mvs:
                    return
                }
                appleMusicCurrentPage = page
                appleMusicPageByTab[tab] = page
            } catch {
                guard !Task.isCancelled,
                      isCurrentAppleMusicRequest(requestID, keyword: keyword) else { return }
                appleMusicCanLoadMore = false
                appleMusicCanLoadMoreByTab[tab] = false
                appleMusicErrorMessage = error.localizedDescription
                AppLogger.warning(
                    "[AppleMusic] 搜索失败: \(error.localizedDescription)",
                    step: "apple-music.search"
                )
            }
            guard isCurrentAppleMusicRequest(requestID, keyword: keyword) else { return }
            isAppleMusicLoading = false
            isFetchingMoreAppleMusic = false
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
                neteaseCanLoadMore = shouldKeepLoading(currentCount: existing.count, pageCount: newItems.count, total: currentTab == .songs ? neteaseSongTotal : nil, pageSize: 30)
            } else {
                neteaseCanLoadMore = false
            }
        } else {
            existing = newItems
            neteaseCanLoadMore = shouldKeepLoading(currentCount: existing.count, pageCount: newItems.count, total: currentTab == .songs ? neteaseSongTotal : nil, pageSize: 30)
        }
        neteaseCanLoadMoreByTab[currentTab] = neteaseCanLoadMore
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
                qqCanLoadMore = shouldKeepLoading(currentCount: existing.count, pageCount: newItems.count, total: currentTab == .songs ? qqSongTotal : nil, pageSize: 30)
            } else {
                qqCanLoadMore = false
            }
        } else {
            existing = newItems
            qqCanLoadMore = shouldKeepLoading(currentCount: existing.count, pageCount: newItems.count, total: currentTab == .songs ? qqSongTotal : nil, pageSize: 30)
        }
        qqCanLoadMoreByTab[currentTab] = qqCanLoadMore
    }
    
    private func handleQishuiPagination<T: Identifiable>(newItems: [T], existing: inout [T], isLoadMore: Bool) where T.ID: Hashable {
        if isLoadMore {
            if !newItems.isEmpty {
                let existingIds = Set(existing.map { $0.id })
                let filtered = newItems.filter { !existingIds.contains($0.id) }
                if !filtered.isEmpty {
                    existing.append(contentsOf: filtered)
                }
                qishuiCurrentPage += 1
                qishuiCanLoadMore = shouldKeepLoading(currentCount: existing.count, pageCount: newItems.count, total: qishuiSongTotal, pageSize: 20)
            } else {
                qishuiCanLoadMore = false
            }
        } else {
            existing = newItems
            qishuiCanLoadMore = shouldKeepLoading(currentCount: existing.count, pageCount: newItems.count, total: qishuiSongTotal, pageSize: 20)
        }
    }
    
    // MARK: - 辅助方法

    private static func mergeSearchItems<T: Identifiable>(
        _ newItems: [T],
        into existing: inout [T],
        isLoadMore: Bool
    ) where T.ID: Hashable {
        guard isLoadMore else {
            existing = newItems
            return
        }
        let existingIDs = Set(existing.map(\.id))
        existing.append(contentsOf: newItems.filter { !existingIDs.contains($0.id) })
    }
    
    private func hasNeteaseResults(for tab: SearchTab) -> Bool {
        switch tab {
        case .songs: return !neteaseResults.isEmpty
        case .artists: return !neteaseArtistResults.isEmpty
        case .playlists: return !neteasePlaylistResults.isEmpty
        case .albums: return !neteaseAlbumResults.isEmpty
        case .mvs: return !neteaseMVResults.isEmpty
        }
    }

    private func neteaseResultCount(for tab: SearchTab) -> Int {
        switch tab {
        case .songs: return neteaseResults.count
        case .artists: return neteaseArtistResults.count
        case .playlists: return neteasePlaylistResults.count
        case .albums: return neteaseAlbumResults.count
        case .mvs: return neteaseMVResults.count
        }
    }

    private func qqResultCount(for tab: SearchTab) -> Int {
        switch tab {
        case .songs: return qqResults.count
        case .artists: return qqArtistResults.count
        case .playlists: return qqPlaylistResults.count
        case .albums: return qqAlbumResults.count
        case .mvs: return qqMVResults.count
        }
    }
    
    private func hasQQResults(for tab: SearchTab) -> Bool {
        switch tab {
        case .songs: return !qqResults.isEmpty
        case .artists: return !qqArtistResults.isEmpty
        case .playlists: return !qqPlaylistResults.isEmpty
        case .albums: return !qqAlbumResults.isEmpty
        case .mvs: return !qqMVResults.isEmpty
        }
    }

    private func hasKugouResults(for tab: SearchTab) -> Bool {
        switch tab {
        case .songs: return !kugouResults.isEmpty
        case .artists: return !kugouArtistResults.isEmpty
        case .playlists: return !kugouPlaylistResults.isEmpty
        case .albums: return !kugouAlbumResults.isEmpty
        case .mvs: return !kugouMVResults.isEmpty
        }
    }

    private func hasAppleMusicResults(for tab: SearchTab) -> Bool {
        switch tab {
        case .songs: return !appleMusicResults.isEmpty
        case .artists: return !appleMusicArtistResults.isEmpty
        case .playlists: return !appleMusicPlaylistResults.isEmpty
        case .albums: return !appleMusicAlbumResults.isEmpty
        case .mvs: return false
        }
    }

    var currentResultsEmpty: Bool {
        switch currentTab {
        case .songs:
            return neteaseResults.isEmpty
                && qqResults.isEmpty
                && qishuiResults.isEmpty
                && kugouResults.isEmpty
                && appleMusicResults.isEmpty
        case .artists:
            return neteaseArtistResults.isEmpty && qqArtistResults.isEmpty
                && kugouArtistResults.isEmpty && appleMusicArtistResults.isEmpty
        case .playlists:
            return neteasePlaylistResults.isEmpty && qqPlaylistResults.isEmpty
                && kugouPlaylistResults.isEmpty && appleMusicPlaylistResults.isEmpty
        case .albums:
            return neteaseAlbumResults.isEmpty && qqAlbumResults.isEmpty
                && kugouAlbumResults.isEmpty && appleMusicAlbumResults.isEmpty
        case .mvs:
            return neteaseMVResults.isEmpty && qqMVResults.isEmpty && kugouMVResults.isEmpty
        }
    }

    func displayedSongCount(for source: MusicSource) -> Int {
        switch source {
        case .netease:
            return neteaseSongTotal ?? neteaseResults.count
        case .qqmusic:
            return qqSongTotal ?? qqResults.count
        case .qishui:
            return qishuiSongTotal ?? qishuiResults.count
        case .kugou:
            return kugouSongTotal ?? kugouResults.count
        case .appleMusic:
            return appleMusicResults.count
        case .local:
            return 0
        }
    }

    func canLoadMore(source: MusicSource) -> Bool {
        switch source {
        case .netease: return neteaseCanLoadMore
        case .qqmusic: return qqCanLoadMore
        case .qishui: return qishuiCanLoadMore
        case .kugou: return kugouCanLoadMore
        case .appleMusic: return appleMusicCanLoadMore
        case .local: return false
        }
    }

    func isLoadingMore(source: MusicSource) -> Bool {
        switch source {
        case .netease: return isFetchingMoreNetease
        case .qqmusic: return isFetchingMoreQQ
        case .qishui: return isFetchingMoreQishui
        case .kugou: return isFetchingMoreKugou
        case .appleMusic: return isFetchingMoreAppleMusic
        case .local: return false
        }
    }

    var displayKeyword: String {
        activeSearchKeyword.isEmpty ? query : activeSearchKeyword
    }

    private var requestKeyword: String {
        let typedKeyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasSearched, !activeSearchKeyword.isEmpty {
            return activeSearchKeyword
        }
        return typedKeyword
    }

    private func shouldKeepLoading(currentCount: Int, pageCount: Int, total: Int?, pageSize: Int) -> Bool {
        if let total, total > 0 {
            return currentCount < total
        }
        return pageCount >= pageSize
    }

    private func startQishuiTotalCounting(keyword: String, startPage: Int) {
        qishuiTotalCountingTask?.cancel()
        qishuiTotalCountingTask = Task { @MainActor [weak self] in
            await self?.countAllQishuiSongs(keyword: keyword, startPage: startPage)
        }
    }

    private func countAllQishuiSongs(keyword: String, startPage: Int) async {
        var page = startPage
        var countedTotal = qishuiResults.count
        var keepLoading = true

        while keepLoading, !Task.isCancelled, requestKeyword == keyword {
            do {
                let result = try await apiService.searchQishuiSongsWithTotal(keyword: keyword, page: page).async()
                if let total = result.total {
                    qishuiSongTotal = total
                    qishuiCanLoadMore = qishuiResults.count < total
                    return
                }

                if qishuiCurrentPage < page {
                    countedTotal += result.songs.count
                }
                countedTotal = max(countedTotal, qishuiResults.count)
                qishuiSongTotal = max(qishuiSongTotal ?? 0, countedTotal)

                keepLoading = result.hasMore && !result.songs.isEmpty
                page += 1
            } catch {
                keepLoading = false
            }
        }

        if requestKeyword == keyword, !Task.isCancelled {
            qishuiSongTotal = max(qishuiSongTotal ?? 0, countedTotal, qishuiResults.count)
            qishuiCanLoadMore = qishuiResults.count < (qishuiSongTotal ?? qishuiResults.count)
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
    
    // MARK: - 全部播放（含后台静默加载）
    
    /// 先播放当前已加载的歌曲，然后后台静默加载剩余页面并追加到播放队列
    func playAllSongs(source: MusicSource, currentSongs: [Song]) {
        guard !currentSongs.isEmpty else { return }
        
        // 立即开始播放已加载的歌曲
        PlayerManager.shared.playReplacingContext(song: currentSongs[0], in: currentSongs)
        
        // 后台静默加载剩余页并追加到播放队列
        let keyword = requestKeyword
        guard !keyword.isEmpty else { return }
        
        switch source {
        case .netease:
            guard neteaseCanLoadMore else { return }
            Task { @MainActor in
                await silentLoadAllNetease(keyword: keyword, startPage: neteaseCurrentPage + 1)
            }
        case .qqmusic:
            guard qqCanLoadMore else { return }
            Task { @MainActor in
                await silentLoadAllQQ(keyword: keyword, startPage: qqCurrentPage + 2)
            }
        case .qishui:
            guard qishuiCanLoadMore else { return }
            Task { @MainActor in
                await silentLoadAllQishui(keyword: keyword, startPage: qishuiCurrentPage + 1)
            }
        case .kugou:
            guard kugouCanLoadMore else { return }
            Task { @MainActor in
                await silentLoadAllKugou(keyword: keyword, startPage: kugouCurrentPage + 1)
            }
        case .appleMusic:
            guard appleMusicCanLoadMore else { return }
            Task { @MainActor in
                await silentLoadAllAppleMusic(
                    keyword: keyword,
                    startPage: appleMusicCurrentPage + 1
                )
            }
        case .local:
            return
        }
    }
    
    /// 静默加载所有 NCM 剩余歌曲页
    private func silentLoadAllNetease(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true
        
        while keepLoading, requestKeyword == keyword {
            let offset = page * 30
            do {
                let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                    apiService.searchSongs(keyword: keyword, offset: offset)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        }, receiveValue: { songs in
                            continuation.resume(returning: songs)
                        })
                        .store(in: &cancellables)
                }

                guard requestKeyword == keyword else { return }
                SongArtworkFallbackRegistry.shared.register(songs)
                
                if songs.isEmpty || songs.count < 30 {
                    keepLoading = false
                }
                
                if !songs.isEmpty {
                    // 去重后追加到已加载结果
                    let existingIds = Set(neteaseResults.map { $0.id })
                    let newSongs = songs.filter { !existingIds.contains($0.id) }
                    if !newSongs.isEmpty {
                        neteaseResults.append(contentsOf: newSongs)
                        // 追加到播放队列
                        PlayerManager.shared.appendContext(songs: newSongs)
                    }
                    neteaseCurrentPage = page
                }
                
                page += 1
            } catch {
                keepLoading = false
            }
        }
        if requestKeyword == keyword {
            neteaseCanLoadMore = false
        }
    }
    
    /// 静默加载所有 QQ 剩余歌曲页
    private func silentLoadAllQQ(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true
        
        while keepLoading, requestKeyword == keyword {
            do {
                let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                    apiService.searchQQSongs(keyword: keyword, page: page, num: 30)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        }, receiveValue: { songs in
                            continuation.resume(returning: songs)
                        })
                        .store(in: &cancellables)
                }

                guard requestKeyword == keyword else { return }
                SongArtworkFallbackRegistry.shared.register(songs)
                
                if songs.isEmpty || songs.count < 30 {
                    keepLoading = false
                }
                
                if !songs.isEmpty {
                    let existingIds = Set(qqResults.map { $0.id })
                    let newSongs = songs.filter { !existingIds.contains($0.id) }
                    if !newSongs.isEmpty {
                        qqResults.append(contentsOf: newSongs)
                        PlayerManager.shared.appendContext(songs: newSongs)
                    }
                    qqCurrentPage = page - 1
                }
                
                page += 1
            } catch {
                keepLoading = false
            }
        }
        if requestKeyword == keyword {
            qqCanLoadMore = false
        }
    }

    /// 静默加载所有 汽水音乐 剩余歌曲页
    private func silentLoadAllQishui(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true
        
        while keepLoading, requestKeyword == keyword {
            do {
                let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                    apiService.searchQishuiSongs(keyword: keyword, page: page)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        }, receiveValue: { songs in
                            continuation.resume(returning: songs)
                        })
                        .store(in: &cancellables)
                }

                guard requestKeyword == keyword else { return }
                SongArtworkFallbackRegistry.shared.register(songs)
                
                if songs.isEmpty || songs.count < 20 {
                    keepLoading = false
                }
                
                if !songs.isEmpty {
                    let existingIds = Set(qishuiResults.map { $0.id })
                    let newSongs = songs.filter { !existingIds.contains($0.id) }
                    if !newSongs.isEmpty {
                        qishuiResults.append(contentsOf: newSongs)
                        PlayerManager.shared.appendContext(songs: newSongs)
                    }
                    qishuiCurrentPage = page
                }
                
                page += 1
            } catch {
                keepLoading = false
            }
        }
        if requestKeyword == keyword {
            qishuiCanLoadMore = false
        }
    }

    private func silentLoadAllAppleMusic(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true
        let pageSize = 25

        while keepLoading, !Task.isCancelled, requestKeyword == keyword {
            do {
                let result = try await appleMusicService.searchSongs(
                    term: keyword,
                    offset: page * pageSize,
                    limit: pageSize
                )
                guard requestKeyword == keyword else { return }
                let existingIDs = Set(appleMusicResults.map {
                    PlayerManager.playbackIdentityKey(for: $0)
                })
                let newSongs = result.songs.filter {
                    !existingIDs.contains(PlayerManager.playbackIdentityKey(for: $0))
                }
                if !newSongs.isEmpty {
                    appleMusicResults.append(contentsOf: newSongs)
                    PlayerManager.shared.appendContext(songs: newSongs)
                }
                appleMusicCurrentPage = page
                keepLoading = result.hasMore && !result.songs.isEmpty
                page += 1
            } catch {
                keepLoading = false
            }
        }
        if requestKeyword == keyword {
            appleMusicCanLoadMore = false
        }
    }

    private func silentLoadAllKugou(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true

        while keepLoading, !Task.isCancelled, requestKeyword == keyword {
            do {
                let result = try await apiService.searchKugouSongsWithTotal(
                    keyword: keyword,
                    page: page,
                    pageSize: 30
                ).async()
                guard requestKeyword == keyword else { return }
                let existingIDs = Set(kugouResults.map(\.id))
                let newSongs = result.songs.filter { !existingIDs.contains($0.id) }
                if !newSongs.isEmpty {
                    kugouResults.append(contentsOf: newSongs)
                    PlayerManager.shared.appendContext(songs: newSongs)
                }
                kugouCurrentPage = page
                kugouSongTotal = result.total
                keepLoading = result.hasMore && !result.songs.isEmpty
                page += 1
            } catch {
                keepLoading = false
            }
        }
        if requestKeyword == keyword { kugouCanLoadMore = false }
    }
}
