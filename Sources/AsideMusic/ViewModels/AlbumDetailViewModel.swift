import Foundation
import Combine

// MARK: - AlbumDetailViewModel

@MainActor
class AlbumDetailViewModel: ObservableObject {
    @Published var albumInfo: AlbumInfo?
    @Published var songs: [Song] = []
    @Published var isLoading = true
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchAlbum(id: Int) {
        guard isLoading else { return }
        
        APIService.shared.fetchAlbumDetail(id: id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    AppLogger.error("专辑详情加载失败: \(error)")
                }
            }, receiveValue: { [weak self] result in
                self?.albumInfo = result.album
                self?.songs = result.songs
            })
            .store(in: &cancellables)
    }
}
