import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var searchResults: [Song] = []
    @Published var suggestions: [String] = []
    @Published var isLoading = false
    @Published var hasSearched = false
    @Published var canLoadMore = true
    @Published var showSuggestions = false
    
    private var currentPage = 0
    private var isFetchingMore = false
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
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
        
        apiService.searchSongs(keyword: keyword, offset: 0)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveValue: { [weak self] songs in
                // 解灰开启时，将无版权歌曲排到前面（可通过解灰播放）
                if SettingsManager.shared.unblockEnabled {
                    let unavailable = songs.filter { $0.isUnavailable }
                    let available = songs.filter { !$0.isUnavailable }
                    self?.searchResults = unavailable + available
                } else {
                    self?.searchResults = songs
                }
                self?.canLoadMore = !songs.isEmpty
            })
            .store(in: &cancellables)
    }
    
    func loadMore() {
        guard !isFetchingMore && canLoadMore && !query.isEmpty else { return }
        
        isFetchingMore = true
        let nextPage = currentPage + 1
        let offset = nextPage * 30
        
        apiService.searchSongs(keyword: query, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isFetchingMore = false
            }, receiveValue: { [weak self] songs in
                guard let self = self else { return }
                
                if !songs.isEmpty {
                    // 去重：过滤掉已存在的歌曲
                    let existingIds = Set(self.searchResults.map { $0.id })
                    let newSongs = songs.filter { !existingIds.contains($0.id) }
                    
                    if !newSongs.isEmpty {
                        self.searchResults.append(contentsOf: newSongs)
                    }
                    self.currentPage = nextPage
                    // 如果返回的歌曲数量少于预期，说明可能没有更多了
                    self.canLoadMore = songs.count >= 30
                } else {
                    self.canLoadMore = false
                }
            })
            .store(in: &cancellables)
    }
    
    func clearSearch() {
        query = ""
        resetState()
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                .padding(.bottom, 20)
                
                ZStack {
                    if viewModel.hasSearched {
                        if viewModel.isLoading {
                            AsideLoadingView(text: "SEARCHING")
                        } else if viewModel.searchResults.isEmpty {
                            VStack(spacing: 16) {
                                AsideIcon(icon: .musicNoteList, size: 50, color: .gray.opacity(0.3))
                                Text(LocalizedStringKey("empty_no_results"))
                                    .font(.rounded(size: 16, weight: .medium))
                                    .foregroundColor(.asideTextSecondary)
                            }
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, song in
                                        SongListRow(song: song, index: index)
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
                                .padding(.bottom, 120)
                            }
                            .simultaneousGesture(DragGesture().onChanged { _ in
                                isFocused = false
                            })
                        }
                    } else if viewModel.query.isEmpty {
                        VStack(spacing: 16) {
                            AsideIcon(icon: .magnifyingGlass, size: 50, color: .gray.opacity(0.3))
                            Text(LocalizedStringKey("search_history"))
                                .font(.rounded(size: 16, weight: .medium))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                    
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}
