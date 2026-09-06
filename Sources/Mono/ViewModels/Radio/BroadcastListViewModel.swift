import Foundation
import Combine

// MARK: - BroadcastListViewModel

@MainActor
class BroadcastListViewModel: ObservableObject {
    @Published var channels: [BroadcastChannel] = []
    @Published var regions: [BroadcastRegion] = []
    @Published var selectedRegionId: String = "0"
    @Published var isLoading = false

    private var initialCancellable: AnyCancellable?
    private var regionCancellable: AnyCancellable?
    private var regionRequestID = 0
    private let apiService = APIService.shared

    func fetchData() {
        guard !isLoading else { return }
        let requestID = regionRequestID
        isLoading = true

        // 同时获取地区信息和频道列表
        let regionPublisher = apiService.fetchBroadcastCategoryRegion()
            .catch { _ in Just((categories: [BroadcastCategory](), regions: [BroadcastRegion]())) }
        let channelPublisher = apiService.fetchBroadcastChannels(regionId: selectedRegionId, limit: 50)
            .catch { _ in Just([BroadcastChannel]()) }

        initialCancellable = Publishers.Zip(regionPublisher, channelPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] regionData, channels in
                guard let self else { return }
                self.regions = regionData.regions
                guard self.regionRequestID == requestID else { return }
                self.channels = channels
                self.isLoading = false
            }
    }

    func selectRegion(_ regionId: String) {
        guard regionId != selectedRegionId else { return }
        regionCancellable?.cancel()
        regionRequestID += 1
        let requestID = regionRequestID
        selectedRegionId = regionId
        isLoading = true
        channels = []

        regionCancellable = apiService.fetchBroadcastChannels(regionId: regionId, limit: 50)
            .catch { _ in Just([BroadcastChannel]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] channels in
                guard let self, self.regionRequestID == requestID else { return }
                self.channels = channels
                self.isLoading = false
            }
    }
}
