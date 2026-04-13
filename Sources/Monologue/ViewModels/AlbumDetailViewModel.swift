import Foundation
import Observation
import Combine

// MARK: - AlbumDetailViewModel

@MainActor
@Observable class AlbumDetailViewModel {
    var albumInfo: AlbumInfo?
    var songs: [Song] = []
    var isLoading = true
    var isSubscribed = false
    var isTogglingSubscription = false
    
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
    
    func toggleSubscription(id: Int) {
        guard !isTogglingSubscription else { return }
        isTogglingSubscription = true
        let newState = !isSubscribed
        
        APIService.shared.albumSub(id: id, subscribe: newState)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isTogglingSubscription = false
                if case .failure(let error) = completion {
                    AppLogger.error("专辑收藏操作失败: \(error)")
                }
            }, receiveValue: { [weak self] success in
                if success {
                    self?.isSubscribed = newState
                }
            })
            .store(in: &cancellables)
    }
}
