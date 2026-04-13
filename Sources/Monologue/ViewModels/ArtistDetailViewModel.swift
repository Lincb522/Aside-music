import Foundation
import Observation
import Combine

// MARK: - ArtistDetailViewModel

@MainActor
@Observable class ArtistDetailViewModel {
    var artist: ArtistInfo?
    var songs: [Song] = []
    var albums: [AlbumInfo] = []
    var mvs: [MV] = []
    var simiArtists: [ArtistInfo] = []
    var fansCount: Int = 0
    var isFollowed: Bool = false
    var isLoading = true
    var isLoadingAlbums = false
    var isLoadingMVs = false
    var isLoadingSimi = false
    var descResult: ArtistDescResult?
    var isLoadingDesc = false
    private var cancellables = Set<AnyCancellable>()

    func loadData(artistId: Int) {
        if artist?.id == artistId && !songs.isEmpty { return }
        isLoading = true

        let detailPub = APIService.shared.fetchArtistDetail(id: artistId)
        let songsPub = APIService.shared.fetchArtistTopSongs(id: artistId)
        let fansPub = APIService.shared.fetchArtistFollowCount(id: artistId)

        Publishers.Zip3(detailPub, songsPub, fansPub)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("加载歌手数据失败: \(error)")
                }
                self?.isLoading = false
            }, receiveValue: { [weak self] (artist, songs, fans) in
                self?.artist = artist
                self?.songs = songs
                self?.fansCount = fans
            })
            .store(in: &cancellables)
    }

    func loadAlbums(artistId: Int) {
        guard albums.isEmpty, !isLoadingAlbums else { return }
        isLoadingAlbums = true

        APIService.shared.fetchArtistAlbums(id: artistId, limit: 50)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingAlbums = false
            }, receiveValue: { [weak self] albums in
                self?.albums = albums
            })
            .store(in: &cancellables)
    }

    func loadMVs(artistId: Int) {
        guard mvs.isEmpty, !isLoadingMVs else { return }
        isLoadingMVs = true

        APIService.shared.fetchArtistMVs(id: artistId, limit: 50)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingMVs = false
            }, receiveValue: { [weak self] mvs in
                self?.mvs = mvs
            })
            .store(in: &cancellables)
    }

    func loadDesc(artistId: Int) {
        guard descResult == nil, !isLoadingDesc else { return }
        isLoadingDesc = true

        APIService.shared.fetchArtistDesc(id: artistId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingDesc = false
            }, receiveValue: { [weak self] result in
                self?.descResult = result
            })
            .store(in: &cancellables)
    }

    func toggleFollow(artistId: Int) {
        let newState = !isFollowed
        APIService.shared.artistSub(id: artistId, subscribe: newState)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] success in
                if success { self?.isFollowed = newState }
            })
            .store(in: &cancellables)
    }

    func loadSimiArtists(artistId: Int) {
        guard simiArtists.isEmpty, !isLoadingSimi else { return }
        isLoadingSimi = true
        APIService.shared.fetchSimiArtists(id: artistId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingSimi = false
            }, receiveValue: { [weak self] artists in
                self?.simiArtists = artists
            })
            .store(in: &cancellables)
    }
}
