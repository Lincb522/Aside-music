import Foundation
import Combine

class PodcastViewModel: ObservableObject {
    @Published var personalizedRadios: [RadioStation] = []
    @Published var categories: [RadioCategory] = []
    @Published var recommendRadios: [RadioStation] = []
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

        Publishers.Zip3(personalizePublisher, categoriesPublisher, recommendPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] personalized, cats, recommend in
                self?.personalizedRadios = personalized
                self?.categories = cats
                self?.recommendRadios = recommend
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func refreshData() {
        fetchData()
    }
}
