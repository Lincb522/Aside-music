import Foundation
import Combine

// MARK: - BroadcastListViewModel

@MainActor
class BroadcastListViewModel: ObservableObject {
    @Published var channels: [BroadcastChannel] = []
    @Published var regions: [BroadcastRegion] = []
    @Published var selectedRegionId: String = "0"
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    func fetchData() {
        isLoading = true

        // 同时获取地区信息和频道列表
        let regionPublisher = apiService.fetchBroadcastCategoryRegion()
            .catch { _ in Just((categories: [BroadcastCategory](), regions: [BroadcastRegion]())) }
        let channelPublisher = apiService.fetchBroadcastChannels(regionId: selectedRegionId, limit: 50)
            .catch { _ in Just([BroadcastChannel]()) }

        Publishers.Zip(regionPublisher, channelPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] regionData, channels in
                self?.regions = regionData.regions
                self?.channels = channels
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func selectRegion(_ regionId: String) {
        guard regionId != selectedRegionId else { return }
        selectedRegionId = regionId
        isLoading = true
        channels = []

        apiService.fetchBroadcastChannels(regionId: regionId, limit: 50)
            .catch { _ in Just([BroadcastChannel]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] channels in
                self?.channels = channels
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }
}
