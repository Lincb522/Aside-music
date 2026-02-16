import Foundation
import Combine

// MARK: - RadioCategoryBrowseViewModel

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
