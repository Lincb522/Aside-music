import SwiftUI
import Combine

/// 电台分类浏览页面 — 顶部分类标签，选中后展示该分类下的电台列表，无限加载
struct RadioCategoryBrowseView: View {
    @StateObject private var viewModel = RadioCategoryBrowseViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 分类标签栏
                if !viewModel.categories.isEmpty {
                    categoryBar
                }

                // 内容区
                if viewModel.isLoading && viewModel.radios.isEmpty {
                    Spacer()
                    AsideLoadingView(text: "加载中...")
                    Spacer()
                } else if viewModel.radios.isEmpty && !viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        AsideIcon(icon: .micSlash, size: 40, color: .asideTextSecondary)
                        Text("暂无电台")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.radios.enumerated()), id: \.element.id) { index, radio in
                                NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                                    radioRow(radio: radio)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if index >= viewModel.radios.count - 5 {
                                        viewModel.loadMore()
                                    }
                                }
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 16)
                            }

                            if !viewModel.hasMore && !viewModel.radios.isEmpty {
                                NoMoreDataView()
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AsideBackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("分类浏览")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
            }
        }
        .onAppear {
            viewModel.initialLoad()
        }
    }

    // MARK: - 分类标签栏

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { cat in
                    let isSelected = viewModel.selectedCategory?.id == cat.id
                    Button(action: {
                        viewModel.selectCategory(cat)
                    }) {
                        Text(cat.name)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(isSelected ? .asideIconForeground : .asideTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.asideIconBackground : Color.asideCardBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
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

@MainActor
class RadioCategoryBrowseViewModel: ObservableObject {
    @Published var categories: [RadioCategory] = []
    @Published var selectedCategory: RadioCategory?
    @Published var radios: [RadioStation] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    private var offset = 0
    private let limit = 30
    private var cancellables = Set<AnyCancellable>()
    private var loadMoreCancellable: AnyCancellable?

    /// 首次加载：拉取分类列表，选中第一个
    func initialLoad() {
        guard categories.isEmpty else { return }
        isLoading = true

        APIService.shared.fetchDJCategories()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] cats in
                guard let self = self else { return }
                self.categories = cats
                if let first = cats.first {
                    self.selectCategory(first)
                } else {
                    self.isLoading = false
                }
            })
            .store(in: &cancellables)
    }

    /// 选择分类，重新加载电台列表
    func selectCategory(_ cat: RadioCategory) {
        guard selectedCategory?.id != cat.id else { return }
        selectedCategory = cat
        offset = 0
        radios = []
        hasMore = true
        isLoading = true

        // 只取消加载更多的请求，不清空所有订阅
        loadMoreCancellable?.cancel()

        APIService.shared.fetchDJCategoryHot(cateId: cat.id, limit: limit, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                self.radios = result.radios
                self.offset = result.radios.count
                self.hasMore = result.hasMore
            })
            .store(in: &cancellables)
    }

    /// 加载更多
    func loadMore() {
        guard !isLoadingMore, !isLoading, hasMore, let cat = selectedCategory else { return }
        isLoadingMore = true

        loadMoreCancellable = APIService.shared.fetchDJCategoryHot(cateId: cat.id, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingMore = false
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                let existingIds = Set(self.radios.map { $0.id })
                let newStations = result.radios.filter { !existingIds.contains($0.id) }
                self.radios.append(contentsOf: newStations)
                self.offset += result.radios.count
                self.hasMore = result.hasMore
            })
    }
}
