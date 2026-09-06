import Foundation
import Combine

// MARK: - TopRadioListViewModel

@MainActor
class TopRadioListViewModel: ObservableObject {
    @Published var radios: [RadioStation] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    private let listType: TopRadioListView.ListType
    private var offset = 0
    private let limit = 30
    private var listCancellable: AnyCancellable?
    private var pageCancellable: AnyCancellable?
    private var requestID = 0

    init(listType: TopRadioListView.ListType) {
        self.listType = listType
    }

    func fetchRadios() {
        guard !isLoading else { return }
        requestID += 1
        let request = requestID
        listCancellable?.cancel()
        pageCancellable?.cancel()
        isLoadingMore = false
        isLoading = true
        offset = 0
        radios = []

        listCancellable = fetchPage(offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.requestID == request else { return }
                self.isLoading = false
            }, receiveValue: { [weak self] stations in
                guard let self, self.requestID == request else { return }
                self.radios = stations
                self.offset = stations.count
                self.hasMore = stations.count >= self.limit
            })
    }

    func loadMore() {
        guard !isLoadingMore, !isLoading, hasMore else { return }
        let request = requestID
        isLoadingMore = true

        pageCancellable = fetchPage(offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.requestID == request else { return }
                self.isLoadingMore = false
            }, receiveValue: { [weak self] stations in
                guard let self, self.requestID == request else { return }
                let existingIds = Set(self.radios.map { $0.id })
                let newStations = stations.filter { !existingIds.contains($0.id) }
                self.radios.append(contentsOf: newStations)
                self.offset += stations.count
                self.hasMore = stations.count >= self.limit
            })
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
