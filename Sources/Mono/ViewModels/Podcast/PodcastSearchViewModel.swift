import Foundation
import Combine

// MARK: - PodcastSearchViewModel

@MainActor
class PodcastSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [RadioStation] = []
    @Published var hotRadios: [RadioStation] = []
    @Published var isSearching = false
    @Published var isLoadingHot = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?
    private var loadMoreCancellable: AnyCancellable?
    private var hotCancellable: AnyCancellable?
    private var searchRequestID = 0
    private var activeSearchText = ""
    private var searchOffset = 0
    private let limit = 30

    init() {
        // 防抖搜索
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(AppConfig.UI.searchDebounceMs), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                if text.isEmpty {
                    self.cancelSearchRequests()
                    self.results = []
                    self.isSearching = false
                } else {
                    self.performSearch(text: text)
                }
            }
            .store(in: &cancellables)
    }

    func fetchHotRadios() {
        guard hotRadios.isEmpty, !isLoadingHot else { return }
        isLoadingHot = true

        hotCancellable = APIService.shared.fetchDJHot(limit: 30, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingHot = false
            }, receiveValue: { [weak self] radios in
                self?.hotRadios = radios
            })
    }

    private func performSearch(text: String) {
        cancelSearchRequests()
        let requestID = searchRequestID
        activeSearchText = text
        isSearching = true
        searchOffset = 0
        results = []

        searchCancellable = APIService.shared.searchDJRadio(keywords: text, limit: limit, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.searchRequestID == requestID, self.searchText == text else { return }
                self.isSearching = false
            }, receiveValue: { [weak self] radios in
                guard let self, self.searchRequestID == requestID, self.searchText == text else { return }
                self.results = radios
                self.searchOffset = radios.count
                self.hasMore = radios.count >= self.limit
            })
    }

    func loadMoreResults() {
        guard !isLoadingMore, !isSearching, hasMore, !searchText.isEmpty, searchText == activeSearchText else { return }
        let text = searchText
        let requestID = searchRequestID
        isLoadingMore = true

        loadMoreCancellable = APIService.shared.searchDJRadio(keywords: text, limit: limit, offset: searchOffset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.searchRequestID == requestID, self.searchText == text else { return }
                self.isLoadingMore = false
            }, receiveValue: { [weak self] radios in
                guard let self, self.searchRequestID == requestID, self.searchText == text else { return }
                let existingIds = Set(self.results.map { $0.id })
                let newRadios = radios.filter { !existingIds.contains($0.id) }
                self.results.append(contentsOf: newRadios)
                self.searchOffset += radios.count
                self.hasMore = radios.count >= self.limit
            })
    }

    private func cancelSearchRequests() {
        searchRequestID += 1
        activeSearchText = ""
        searchCancellable?.cancel()
        searchCancellable = nil
        loadMoreCancellable?.cancel()
        loadMoreCancellable = nil
        isLoadingMore = false
    }
}
