import Foundation
import Combine

// MARK: - ArtistDetailViewModel

@MainActor
class ArtistDetailViewModel: ObservableObject {
    @Published var artist: ArtistInfo?
    @Published var songs: [Song] = []
    @Published var albums: [AlbumInfo] = []
    @Published var mvs: [MV] = []
    @Published var simiArtists: [ArtistInfo] = []
    @Published var fansCount: Int = 0
    @Published var isFollowed: Bool = false
    @Published var isLoading = true
    @Published var isLoadingAlbums = false
    @Published var isLoadingMVs = false
    @Published var isLoadingSimi = false
    @Published var descResult: ArtistDescResult?
    @Published var isLoadingDesc = false
    private var cancellables = Set<AnyCancellable>()
    private var appleMusicTask: Task<Void, Never>?
    private let dataRequest = LibraryRequestScope()
    private var activeArtistKey: String?

    func loadData(artistId: Int) {
        if artist?.id == artistId && !songs.isEmpty { return }
        guard let request = beginDataLoad(key: "netease:\(artistId)") else { return }
        isLoading = true

        let detailPub = APIService.shared.fetchArtistDetail(id: artistId)
        let songsPub = APIService.shared.fetchArtistTopSongs(id: artistId)
        let fansPub = APIService.shared.fetchArtistFollowCount(id: artistId)

        dataRequest.cancellable = Publishers.Zip3(detailPub, songsPub, fansPub)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.dataRequest.isCurrent(request) else { return }
                self.dataRequest.finish(request)
                if case .failure(let error) = completion {
                    AppLogger.error("加载歌手数据失败: \(error)")
                }
                self.isLoading = false
            }, receiveValue: { [weak self] (artist, songs, fans) in
                guard let self, self.dataRequest.isCurrent(request) else { return }
                self.artist = artist
                self.songs = songs
                self.fansCount = fans
            })
    }

    func loadData(artist initialArtist: ArtistInfo) {
        if initialArtist.source == .kugou {
            loadKugouData(artist: initialArtist)
            return
        }
        guard initialArtist.source == .appleMusic,
              let artistID = initialArtist.appleMusicID,
              !artistID.isEmpty else {
            loadData(artistId: initialArtist.id)
            return
        }
        if artist?.appleMusicID == artistID, !songs.isEmpty { return }

        guard let request = beginDataLoad(key: "appleMusic:\(artistID)") else { return }
        artist = initialArtist
        isLoading = true
        isLoadingAlbums = true
        isLoadingSimi = true
        isLoadingMVs = false
        mvs = []

        appleMusicTask = Task { [weak self] in
            do {
                let page = try await AppleMusicService.shared.artistDetail(artistID: artistID)
                guard !Task.isCancelled, self?.dataRequest.isCurrent(request) == true else { return }
                self?.artist = page.artist
                self?.songs = page.songs
                self?.albums = page.albums
                self?.simiArtists = page.similarArtists
                self?.descResult = ArtistDescResult(
                    briefDesc: page.artist.briefDesc,
                    sections: []
                )
            } catch {
                guard !Task.isCancelled, self?.dataRequest.isCurrent(request) == true else { return }
                AppLogger.error(
                    "[AppleMusic] 加载歌手详情失败 artistID=\(artistID): \(error.localizedDescription)",
                    step: "apple-music.artist-detail"
                )
            }
            self?.dataRequest.finish(request)
            self?.isLoading = false
            self?.isLoadingAlbums = false
            self?.isLoadingSimi = false
        }
    }

    private func loadKugouData(artist initialArtist: ArtistInfo) {
        if artist?.source == .kugou, artist?.id == initialArtist.id, !songs.isEmpty { return }
        guard let request = beginDataLoad(key: "kugou:\(initialArtist.id)") else { return }
        artist = initialArtist
        isLoading = true
        isLoadingAlbums = true
        isLoadingMVs = false
        isLoadingSimi = false
        mvs = []
        simiArtists = []
        descResult = ArtistDescResult(briefDesc: initialArtist.briefDesc, sections: [])

        dataRequest.cancellable = Publishers.Zip(
            APIService.shared.fetchKugouArtistSongs(id: initialArtist.id, pageSize: 50),
            APIService.shared.fetchKugouArtistAlbums(id: initialArtist.id, pageSize: 50)
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            guard let self, self.dataRequest.isCurrent(request) else { return }
            self.dataRequest.finish(request)
            self.isLoading = false
            self.isLoadingAlbums = false
            if case .failure(let error) = completion {
                AppLogger.error("[KCM] 加载歌手详情失败: \(error.localizedDescription)")
            }
        }, receiveValue: { [weak self] songs, albums in
            guard let self, self.dataRequest.isCurrent(request) else { return }
            self.songs = songs
            self.albums = albums
        })
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

    private func beginDataLoad(key: String) -> Int? {
        guard activeArtistKey != key || !dataRequest.isRunning else { return nil }
        appleMusicTask?.cancel()
        activeArtistKey = key
        return dataRequest.begin()
    }

    deinit { appleMusicTask?.cancel() }
}
