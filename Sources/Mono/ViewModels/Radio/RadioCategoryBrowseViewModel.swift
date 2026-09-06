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
    private var initialCancellable: AnyCancellable?
    private var loadMoreCancellable: AnyCancellable?
    private var categoryCancellable: AnyCancellable?
    private var categoryRequestID = 0

    /// 首次加载：拉取分类列表，选中第一个
    func initialLoad() {
        guard categories.isEmpty, !isLoading else { return }
        isLoading = true

        initialCancellable = APIService.shared.fetchDJCategories()
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
    }

    /// 选择分类，重新加载电台列表
    func selectCategory(_ cat: RadioCategory) {
        guard selectedCategory?.id != cat.id else { return }
        categoryRequestID += 1
        let requestID = categoryRequestID
        categoryCancellable?.cancel()
        loadMoreCancellable?.cancel()
        isLoadingMore = false
        selectedCategory = cat
        offset = 0
        radios = []
        hasMore = true
        isLoading = true

        categoryCancellable = APIService.shared.fetchDJCategoryHot(cateId: cat.id, limit: limit, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.categoryRequestID == requestID else { return }
                self.isLoading = false
            }, receiveValue: { [weak self] result in
                guard let self, self.categoryRequestID == requestID else { return }
                self.radios = result.radios
                self.offset = result.radios.count
                self.hasMore = result.hasMore
            })
    }

    /// 加载更多
    func loadMore() {
        guard !isLoadingMore, !isLoading, hasMore, let cat = selectedCategory else { return }
        let requestID = categoryRequestID
        isLoadingMore = true

        loadMoreCancellable = APIService.shared.fetchDJCategoryHot(cateId: cat.id, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.categoryRequestID == requestID else { return }
                self.isLoadingMore = false
            }, receiveValue: { [weak self] result in
                guard let self, self.categoryRequestID == requestID else { return }
                let existingIds = Set(self.radios.map { $0.id })
                let newStations = result.radios.filter { !existingIds.contains($0.id) }
                self.radios.append(contentsOf: newStations)
                self.offset += result.radios.count
                self.hasMore = result.hasMore
            })
    }
}
