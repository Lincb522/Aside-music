import Foundation
import Combine

/// 分类电台列表 ViewModel，支持分页加载和去重
@MainActor
class CategoryRadioViewModel: ObservableObject {
    @Published var radios: [RadioStation] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    let category: RadioCategory
    private var offset = 0
    private let limit = 30
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    init(category: RadioCategory) {
        self.category = category
    }

    /// 首次加载
    func fetchRadios() {
        guard !isLoading else { return }
        isLoading = true
        offset = 0
        radios = []

        apiService.fetchDJCategoryHot(cateId: category.id, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    AppLogger.error("[CategoryRadioVM] 加载失败: \(error)")
                }
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                self.radios = result.radios
                self.offset = result.radios.count
                self.hasMore = result.hasMore
            })
            .store(in: &cancellables)
    }

    /// 分页加载更多
    func loadMore() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        apiService.fetchDJCategoryHot(cateId: category.id, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingMore = false
                if case .failure(let error) = completion {
                    AppLogger.error("[CategoryRadioVM] 加载更多失败: \(error)")
                }
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                let existingIds = Set(self.radios.map { $0.id })
                let newStations = result.radios.filter { !existingIds.contains($0.id) }
                self.radios.append(contentsOf: newStations)
                self.offset += result.radios.count
                self.hasMore = result.hasMore
            })
            .store(in: &cancellables)
    }
}
