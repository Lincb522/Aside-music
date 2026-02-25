import Foundation
import Observation
import Combine

// MARK: - TopRadioListViewModel

@MainActor
@Observable class TopRadioListViewModel {
    var radios: [RadioStation] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true

    private let listType: TopRadioListView.ListType
    private var offset = 0
    private let limit = 30
    private var cancellables = Set<AnyCancellable>()

    init(listType: TopRadioListView.ListType) {
        self.listType = listType
    }

    func fetchRadios() {
        guard !isLoading else { return }
        isLoading = true
        offset = 0
        radios = []

        fetchPage(offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
            }, receiveValue: { [weak self] stations in
                guard let self = self else { return }
                self.radios = stations
                self.offset = stations.count
                self.hasMore = stations.count >= self.limit
            })
            .store(in: &cancellables)
    }

    func loadMore() {
        guard !isLoadingMore, !isLoading, hasMore else { return }
        isLoadingMore = true

        fetchPage(offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingMore = false
            }, receiveValue: { [weak self] stations in
                guard let self = self else { return }
                let existingIds = Set(self.radios.map { $0.id })
                let newStations = stations.filter { !existingIds.contains($0.id) }
                self.radios.append(contentsOf: newStations)
                self.offset += stations.count
                self.hasMore = stations.count >= self.limit
            })
            .store(in: &cancellables)
    }

    private func fetchPage(offset: Int) -> AnyPublisher<[RadioStation], Error> {
        switch listType {
        case .hot:
            return APIService.shared.fetchDJHot(limit: limit, offset: offset)
        case .toplist:
            return APIService.shared.fetchDJToplist(type: "hot", limit: limit, offset: offset)
        }
    }
}
