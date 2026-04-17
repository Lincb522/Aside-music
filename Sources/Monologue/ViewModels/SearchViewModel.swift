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
    
    // MARK: - ncm搜索结果
    @Published var neteaseResults: [Song] = []
    @Published var neteaseArtistResults: [ArtistInfo] = []
    @Published var neteasePlaylistResults: [Playlist] = []
    @Published var neteaseAlbumResults: [SearchAlbum] = []
    @Published var neteaseMVResults: [MV] = []
    @Published var isNeteaseLoading = false
    
    // MARK: - qcm搜索结果
    @Published var qqResults: [Song] = []
    @Published var qqArtistResults: [ArtistInfo] = []
    @Published var qqPlaylistResults: [Playlist] = []
    @Published var qqAlbumResults: [SearchAlbum] = []
    @Published var qqMVResults: [QQMV] = []
    @Published var isQQLoading = false
    
    // MARK: - 汽水音乐搜索结果
    @Published var qishuiResults: [Song] = []
    @Published var isQishuiLoading = false
    
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
    private var neteaseCanLoadMore = true
    private var qqCanLoadMore = true
    private var qishuiCanLoadMore = true
    private var isFetchingMoreNetease = false
    private var isFetchingMoreQQ = false
    private var isFetchingMoreQishui = false
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private let cacheManager = OptimizedCacheManager.shared

    // MARK: - 兼容属性（供现有 UI 使用）
    
    var isLoading: Bool { isNeteaseLoading && isQQLoading && isQishuiLoading }
    var canLoadMore: Bool {
        if let source = expandedSource {
            switch source {
            case .netease: return neteaseCanLoadMore
            case .qqmusic: return qqCanLoadMore
            case .qishui: return qishuiCanLoadMore
            case .local: return false
            }
        }
        return neteaseCanLoadMore || qqCanLoadMore || qishuiCanLoadMore
    }
    
    /// 合并的歌曲结果（兼容旧代码）
    var searchResults: [Song] { neteaseResults + qqResults + qishuiResults }

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
        suggestions = []
        hasSearched = false
        showSuggestions = false
        expandedSource = nil
        multimatchResult = nil
        neteaseCurrentPage = 0
        qqCurrentPage = 0
        qishuiCurrentPage = 0
        neteaseCanLoadMore = true
        qqCanLoadMore = true
        qishuiCanLoadMore = true
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
        self.showSuggestions = true
        apiService.fetchSearchSuggestions(keyword: keyword)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] suggestions in
                self?.suggestions = suggestions
            })
            .store(in: &cancellables)
    }
    
    func performSearch(keyword: String) {
        lastSearchedKeyword = keyword
        showSuggestions = false
        suggestions = []
        neteaseCurrentPage = 0
        qqCurrentPage = 0
        qishuiCurrentPage = 0
        neteaseCanLoadMore = true
        qqCanLoadMore = true
        qishuiCanLoadMore = true
        expandedSource = nil
        
        if query != keyword {
            query = keyword
        }
        hasSearched = true
        
        cacheManager.addSearchHistory(keyword: keyword)
        loadSearchHistory()

        // 同时搜索三个平台
        executeNeteaseSearch(keyword: keyword, offset: 0, isLoadMore: false)
        executeQQSearch(keyword: keyword, page: 1, isLoadMore: false)
        executeQishuiSearch(keyword: keyword, page: 0, isLoadMore: false)
        
        // 获取多类型最佳匹配
        apiService.fetchSearchMultimatch(keywords: keyword)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] result in
                // 只有至少有一个匹配结果时才显示
                if result.artist != nil || result.album != nil || result.playlist != nil {
                    self?.multimatchResult = result
                } else {
                    self?.multimatchResult = nil
                }
            })
            .store(in: &cancellables)
    }
    
    /// 切换搜索类型时重新搜索
    func switchTab(_ tab: SearchTab) {
        guard tab != currentTab else { return }
        currentTab = tab
        expandedSource = nil
        
        // 如果离开了单曲标签，且当前平台为汽水音乐，则自动切回网易云
        if tab != .songs && selectedPlatform == .qishui {
            selectedPlatform = .netease
        }
        
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
        case .qishui:
            guard !isFetchingMoreQishui && qishuiCanLoadMore else { return }
            isFetchingMoreQishui = true
            let page = qishuiCurrentPage + 1 // qishui page 从 0 开始
            executeQishuiSearch(keyword: query, page: page, isLoadMore: true)
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
    
    // MARK: - qcm搜索
    
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
            apiService.searchQQMVs(keyword: keyword, page: page, num: 30)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.isQQLoading = false
                    if isLoadMore { self?.isFetchingMoreQQ = false }
                }, receiveValue: { [weak self] mvs in
                    guard let self = self else { return }
                    self.handleQQPagination(newItems: mvs, existing: &self.qqMVResults, isLoadMore: isLoadMore)
                })
                .store(in: &cancellables)
        }
    }

    // MARK: - 汽水音乐搜索执行

    private func executeQishuiSearch(keyword: String, page: Int, isLoadMore: Bool) {
        guard currentTab == .songs else { return }
        isQishuiLoading = !isLoadMore
        apiService.searchQishuiSongs(keyword: keyword, page: page)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isQishuiLoading = false
                if isLoadMore { self?.isFetchingMoreQishui = false }
            }, receiveValue: { [weak self] songs in
                guard let self = self else { return }
                self.handleQishuiPagination(newItems: songs, existing: &self.qishuiResults, isLoadMore: isLoadMore)
            })
            .store(in: &cancellables)
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
    
    private func handleQishuiPagination<T: Identifiable>(newItems: [T], existing: inout [T], isLoadMore: Bool) where T.ID: Hashable {
        if isLoadMore {
            if !newItems.isEmpty {
                let existingIds = Set(existing.map { $0.id })
                let filtered = newItems.filter { !existingIds.contains($0.id) }
                if !filtered.isEmpty {
                    existing.append(contentsOf: filtered)
                }
                qishuiCurrentPage += 1
                qishuiCanLoadMore = newItems.count >= 20
            } else {
                qishuiCanLoadMore = false
            }
        } else {
            existing = newItems
            qishuiCanLoadMore = newItems.count >= 20
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
        case .mvs: return !qqMVResults.isEmpty
        }
    }
    
    var currentResultsEmpty: Bool {
        switch currentTab {
        case .songs: return neteaseResults.isEmpty && qqResults.isEmpty && qishuiResults.isEmpty
        case .artists: return neteaseArtistResults.isEmpty && qqArtistResults.isEmpty
        case .playlists: return neteasePlaylistResults.isEmpty && qqPlaylistResults.isEmpty
        case .albums: return neteaseAlbumResults.isEmpty && qqAlbumResults.isEmpty
        case .mvs: return neteaseMVResults.isEmpty && qqMVResults.isEmpty
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
        let keyword = query
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
        case .local:
            return
        }
    }
    
    /// 静默加载所有 NCM 剩余歌曲页
    private func silentLoadAllNetease(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true
        
        while keepLoading {
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
        neteaseCanLoadMore = false
    }
    
    /// 静默加载所有 QQ 剩余歌曲页
    private func silentLoadAllQQ(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true
        
        while keepLoading {
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
        qqCanLoadMore = false
    }

    /// 静默加载所有 汽水音乐 剩余歌曲页
    private func silentLoadAllQishui(keyword: String, startPage: Int) async {
        var page = startPage
        var keepLoading = true
        
        while keepLoading {
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
        qishuiCanLoadMore = false
    }
}
