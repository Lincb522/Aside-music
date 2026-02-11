import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var searchResults: [Song] = []
    @Published var suggestions: [String] = []
    @Published var searchHistory: [SearchHistory] = []
    @Published var hotSearchItems: [HotSearchItem] = []
    @Published var isLoading = false
    @Published var hasSearched = false
    @Published var canLoadMore = true
    @Published var showSuggestions = false

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

        performNeteaseSearch(keyword: keyword, offset: 0, isLoadMore: false)
    }
    
    func loadMore() {
        guard !isFetchingMore && canLoadMore && !query.isEmpty else { return }
        
        isFetchingMore = true
        let nextPage = currentPage + 1
        let offset = nextPage * 30
        performNeteaseSearch(keyword: query, offset: offset, isLoadMore: true)
    }

    private func performNeteaseSearch(keyword: String, offset: Int, isLoadMore: Bool) {
        apiService.searchSongs(keyword: keyword, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
                if isLoadMore { self?.isFetchingMore = false }
            }, receiveValue: { [weak self] songs in
                guard let self = self else { return }
                if isLoadMore {
                    if !songs.isEmpty {
                        let existingIds = Set(self.searchResults.map { $0.id })
                        let newSongs = songs.filter { !existingIds.contains($0.id) }
                        if !newSongs.isEmpty {
                            self.searchResults.append(contentsOf: newSongs)
                        }
                        self.currentPage += 1
                        self.canLoadMore = songs.count >= 30
                    } else {
                        self.canLoadMore = false
                    }
                } else {
                    self.searchResults = songs
                    self.canLoadMore = !songs.isEmpty
                }
            })
            .store(in: &cancellables)
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

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
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
    
    // MARK: - 搜索内容区域
    
    @ViewBuilder
    private var searchContentView: some View {
        if viewModel.hasSearched {
            if viewModel.isLoading && viewModel.searchResults.isEmpty {
                AsideLoadingView(text: "SEARCHING")
            } else if viewModel.searchResults.isEmpty {
                emptyResultsView
            } else {
                neteaseResultsListView
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
                    
                    // 标签流式布局
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
    
    // MARK: - 网易云结果列表
    
    private var neteaseResultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                neteaseResultsSection
            }
            .padding(.bottom, 120)
        }
        .simultaneousGesture(DragGesture().onChanged { _ in
            isFocused = false
        })
    }
    
    // MARK: - 网易云搜索结果
    
    @ViewBuilder
    private var neteaseResultsSection: some View {
        if !viewModel.searchResults.isEmpty {
            sectionHeader("网易云音乐", icon: .cloud)
            
            ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, song in
                SongListRow(song: song, index: index, onArtistTap: { artistId in
                    selectedArtistId = artistId
                    showArtistDetail = true
                }, onDetailTap: { detailSong in
                    selectedSongForDetail = detailSong
                    showSongDetail = true
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
            
            if viewModel.canLoadMore {
                AsideLoadingView(text: "LOADING MORE")
                    .padding(.vertical, 20)
            }
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
    
    // MARK: - 分区标题
    
    private func sectionHeader(_ title: String, icon: AsideIcon.IconType) -> some View {
        HStack(spacing: 8) {
            AsideIcon(icon: icon, size: 14, color: .asideTextSecondary)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
            
            Rectangle()
                .fill(Color.asideTextSecondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
