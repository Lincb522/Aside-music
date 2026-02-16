import Foundation
import Combine

@MainActor
class SongDetailViewModel: ObservableObject {
    @Published var relatedSongs: [Song] = []
    @Published var isLoading = true
    private var cancellables = Set<AnyCancellable>()
    
    func loadRelatedSongs(artistId: Int) {
        isLoading = true
        APIService.shared.fetchArtistTopSongs(id: artistId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Error loading related songs: \(error)")
                }
                self?.isLoading = false
            }, receiveValue: { [weak self] songs in
                self?.relatedSongs = songs
            })
            .store(in: &cancellables)
    }
}
