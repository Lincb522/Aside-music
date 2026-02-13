import SwiftUI
import Combine

/// 播客搜索页面
struct PodcastSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PodcastSearchViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                    .padding(.top, DeviceLayout.headerTopPadding)

                if viewModel.searchText.isEmpty {
                    // 热门电台推荐
                    hotRadiosSection
                } else if viewModel.isSearching && viewModel.results.isEmpty {
                    Spacer()
                    AsideLoadingView(text: "SEARCHING")
                    Spacer()
                } else if !viewModel.searchText.isEmpty && viewModel.results.isEmpty && !viewModel.isSearching {
                    Spacer()
                    emptyResultView
                    Spacer()
                } else {
                    // 搜索结果
                    searchResultsList
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            isSearchFocused = true
            viewModel.fetchHotRadios()
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                AsideIcon(icon: .magnifyingGlass, size: 15, color: .asideTextSecondary, lineWidth: 1.4)

                TextField("搜索电台", text: $viewModel.searchText)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        AsideIcon(icon: .xmarkCircle, size: 14, color: .asideTextSecondary, lineWidth: 1.2)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.asideCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("取消") {
                dismiss()
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.asideTextPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - 热门电台

    private var hotRadiosSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("热门电台")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .padding(.horizontal, 20)

                if viewModel.isLoadingHot {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.hotRadios) { radio in
                            NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                                radioRow(radio: radio)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - 搜索结果

    private var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.results) { radio in
                    NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                        radioRow(radio: radio)
                    }
                    .buttonStyle(.plain)

                    // 滚动到底部加载更多
                    if radio.id == viewModel.results.last?.id && viewModel.hasMore {
                        Color.clear.frame(height: 1)
                            .onAppear { viewModel.loadMoreResults() }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }

                if !viewModel.hasMore && !viewModel.results.isEmpty {
                    NoMoreDataView()
                }
            }
            .padding(.bottom, 120)
        }
    }

    // MARK: - 空结果

    private var emptyResultView: some View {
        VStack(spacing: 12) {
            AsideIcon(icon: .magnifyingGlass, size: 36, color: .asideTextSecondary.opacity(0.5))
            Text("未找到相关电台")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
    }

    // MARK: - 电台行

    private func radioRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.asideCardBackground)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("\(count)期")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }

            Spacer()

            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary, lineWidth: 1.2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - ViewModel

class PodcastSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [RadioStation] = []
    @Published var hotRadios: [RadioStation] = []
    @Published var isSearching = false
    @Published var isLoadingHot = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    private var cancellables = Set<AnyCancellable>()
    private var searchOffset = 0
    private let limit = 30

    init() {
        // 防抖搜索
        $searchText
            .debounce(for: .milliseconds(AppConfig.UI.searchDebounceMs), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self = self else { return }
                if text.isEmpty {
                    self.results = []
                    self.isSearching = false
                } else {
                    self.performSearch(text: text)
                }
            }
            .store(in: &cancellables)
    }

    func fetchHotRadios() {
        guard hotRadios.isEmpty else { return }
        isLoadingHot = true

        APIService.shared.fetchDJHot(limit: 30, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingHot = false
            }, receiveValue: { [weak self] radios in
                self?.hotRadios = radios
            })
            .store(in: &cancellables)
    }

    private func performSearch(text: String) {
        isSearching = true
        searchOffset = 0
        results = []

        APIService.shared.searchDJRadio(keywords: text, limit: limit, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isSearching = false
            }, receiveValue: { [weak self] radios in
                guard let self = self else { return }
                self.results = radios
                self.searchOffset = radios.count
                self.hasMore = radios.count >= self.limit
            })
            .store(in: &cancellables)
    }

    func loadMoreResults() {
        guard !isLoadingMore, hasMore, !searchText.isEmpty else { return }
        isLoadingMore = true

        APIService.shared.searchDJRadio(keywords: searchText, limit: limit, offset: searchOffset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingMore = false
            }, receiveValue: { [weak self] radios in
                guard let self = self else { return }
                let existingIds = Set(self.results.map { $0.id })
                let newRadios = radios.filter { !existingIds.contains($0.id) }
                self.results.append(contentsOf: newRadios)
                self.searchOffset += radios.count
                self.hasMore = radios.count >= self.limit
            })
            .store(in: &cancellables)
    }
}
