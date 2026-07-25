import Foundation
import Combine

// MARK: - AlbumDetailViewModel

@MainActor
class AlbumDetailViewModel: ObservableObject {
    @Published var albumInfo: AlbumInfo?
    @Published var songs: [Song] = []
    @Published var isLoading = true
    @Published var isSubscribed = false
    @Published var isTogglingSubscription = false
    
    private var cancellables = Set<AnyCancellable>()
    private var appleMusicTask: Task<Void, Never>?
    
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

    func fetchAlbum(_ initialAlbum: AlbumInfo) {
        guard initialAlbum.source == .appleMusic,
              let albumID = initialAlbum.appleMusicID,
              !albumID.isEmpty else {
            fetchAlbum(id: initialAlbum.id)
            return
        }
        guard isLoading else { return }

        albumInfo = initialAlbum
        appleMusicTask?.cancel()
        appleMusicTask = Task { [weak self] in
            do {
                let page = try await AppleMusicService.shared.albumDetail(albumID: albumID)
                guard !Task.isCancelled else { return }
                self?.albumInfo = page.album
                self?.songs = page.songs
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.error(
                    "[AppleMusic] 加载专辑详情失败 albumID=\(albumID): \(error.localizedDescription)",
                    step: "apple-music.album-detail"
                )
            }
            self?.isLoading = false
        }
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
