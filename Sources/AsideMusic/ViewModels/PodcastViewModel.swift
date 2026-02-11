import Foundation
import Combine

@MainActor
class PodcastViewModel: ObservableObject {
    @Published var personalizedRadios: [RadioStation] = []
    @Published var categories: [RadioCategory] = []
    @Published var recommendRadios: [RadioStation] = []
    @Published var broadcastChannels: [BroadcastChannel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    func fetchData() {
        isLoading = true
        errorMessage = nil

        let personalizePublisher = apiService.fetchDJPersonalizeRecommend(limit: 6)
            .catch { _ in Just([RadioStation]()) }
        let categoriesPublisher = apiService.fetchDJCategories()
            .catch { _ in Just([RadioCategory]()) }
        let recommendPublisher = apiService.fetchDJRecommend()
            .catch { _ in Just([RadioStation]()) }
        let broadcastPublisher = apiService.fetchBroadcastChannels(limit: 6)
            .catch { _ in Just([BroadcastChannel]()) }

        Publishers.Zip4(personalizePublisher, categoriesPublisher, recommendPublisher, broadcastPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] personalized, cats, recommend, broadcasts in
                self?.personalizedRadios = personalized
                self?.categories = cats
                self?.recommendRadios = recommend
                self?.broadcastChannels = broadcasts
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func refreshData() {
        fetchData()
    }
}
