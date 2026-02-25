import Foundation
import Observation
import Combine

@MainActor
@Observable class SongDetailViewModel {
    var relatedSongs: [Song] = []
    var simiSongs: [Song] = []
    var wikiBlocks: [SongWikiBlock] = []
    var isLoading = true
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
    
    func loadSimiSongs(songId: Int) {
        APIService.shared.fetchSimiSongs(id: songId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.simiSongs = songs
            })
            .store(in: &cancellables)
    }
    
    func loadSongWiki(songId: Int) {
        APIService.shared.fetchSongWiki(id: songId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] blocks in
                self?.wikiBlocks = blocks
            })
            .store(in: &cancellables)
    }
}
