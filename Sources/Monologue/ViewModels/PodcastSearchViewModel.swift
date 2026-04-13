import Foundation
import Combine

// MARK: - PodcastSearchViewModel

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
