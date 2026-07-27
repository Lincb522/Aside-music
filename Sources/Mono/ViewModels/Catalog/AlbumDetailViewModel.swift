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
    private var source: MusicSource = .netease
    
    func fetchAlbum(id: Int) {
        guard isLoading else { return }
        source = .netease
        
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
        if initialAlbum.source == .kugou, let albumID = initialAlbum.kugouID, !albumID.isEmpty {
            guard isLoading else { return }
            source = .kugou
            albumInfo = initialAlbum
            APIService.shared.fetchKugouAlbumSongs(id: albumID, page: 1, pageSize: 100)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        AppLogger.error("[KCM] 加载专辑详情失败: \(error.localizedDescription)")
                        self?.loadKugouAlbumFallback(initialAlbum, albumID: albumID)
                    }
                }, receiveValue: { [weak self] songs in
                    guard let self else { return }
                    if songs.isEmpty {
                        self.loadKugouAlbumFallback(initialAlbum, albumID: albumID)
                    } else {
                        self.songs = songs
                        self.isLoading = false
                    }
                })
                .store(in: &cancellables)
            return
        }
        guard initialAlbum.source == .appleMusic,
              let albumID = initialAlbum.appleMusicID,
              !albumID.isEmpty else {
            fetchAlbum(id: initialAlbum.id)
            return
        }
        guard isLoading else { return }

        source = .appleMusic

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

    private func loadKugouAlbumFallback(_ album: AlbumInfo, albumID: String) {
        let keyword = [album.artist?.name, album.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        APIService.shared.searchKugouSongsWithTotal(keyword: keyword, page: 1, pageSize: 100)
            .map { page in
                page.songs.filter { song in
                    if String(song.kugouAlbumID ?? -1) == albumID { return true }
                    let songAlbum = song.al?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return !songAlbum.isEmpty
                        && songAlbum.compare(album.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    AppLogger.error("[KCM] 专辑搜索回退失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] songs in
                self?.songs = songs
            })
            .store(in: &cancellables)
    }
    
    func toggleSubscription(id: Int) {
        guard source == .netease else { return }
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
