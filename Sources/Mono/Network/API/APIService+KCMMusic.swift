import Foundation
@preconcurrency import Combine

extension APIService {
    func searchKugouSongsWithTotal(keyword: String, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<KCMSearchPage, Error> {
        asyncToPublisher {
            try await KCMMusicService.shared.searchSongs(keyword: keyword, page: page, pageSize: pageSize)
        }
    }

    func searchKugouArtists(keyword: String, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<KCMArtistSearchPage, Error> {
        asyncToPublisher { try await KCMMusicService.shared.searchArtists(keyword: keyword, page: page, pageSize: pageSize) }
    }

    func fetchKugouArtists(type: Int = 0, sex: Int = 0, pageSize: Int = 200) -> AnyPublisher<KCMArtistSearchPage, Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchArtists(type: type, sex: sex, pageSize: pageSize) }
    }

    func searchKugouPlaylists(keyword: String, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<KCMPlaylistSearchPage, Error> {
        asyncToPublisher { try await KCMMusicService.shared.searchPlaylists(keyword: keyword, page: page, pageSize: pageSize) }
    }

    func searchKugouAlbums(keyword: String, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<KCMAlbumSearchPage, Error> {
        asyncToPublisher { try await KCMMusicService.shared.searchAlbums(keyword: keyword, page: page, pageSize: pageSize) }
    }

    func searchKugouMVs(keyword: String, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<KCMMVSearchPage, Error> {
        asyncToPublisher { try await KCMMusicService.shared.searchMVs(keyword: keyword, page: page, pageSize: pageSize) }
    }

    func fetchKugouPlaylistCategories() -> AnyPublisher<[KCMPlaylistCategory], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchPlaylistCategories() }
    }

    func fetchKugouPlaylists(categoryID: Int, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<KCMPlaylistPage, Error> {
        asyncToPublisher {
            try await KCMMusicService.shared.fetchPlaylists(categoryID: categoryID, page: page, pageSize: pageSize)
        }
    }

    func fetchKugouPlaylistSongs(globalID: String, page: Int = 1, pageSize: Int = 50) -> AnyPublisher<[Song], Error> {
        asyncToPublisher {
            try await KCMMusicService.shared.fetchPlaylistSongs(globalID: globalID, page: page, pageSize: pageSize)
        }
    }

    func fetchKugouUserPlaylists() -> AnyPublisher<[Playlist], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchUserPlaylists() }
    }

    func fetchKugouRecommendedPlaylists(limit: Int = 12) -> AnyPublisher<[Playlist], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchRecommendedPlaylists(limit: limit) }
    }

    func fetchKugouTopLists() -> AnyPublisher<[TopList], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchTopLists() }
    }

    func fetchKugouSongURL(song: Song, quality: SoundQuality = .exhigh) -> AnyPublisher<KCMPlaybackURLResult, Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchSongURL(song: song, quality: quality) }
    }

    func fetchKugouSongQualities(song: Song) -> AnyPublisher<[KCMSongQualityInfo], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchSongQualities(song: song) }
    }

    func fetchKugouSongPlatformDetail(song: Song) -> AnyPublisher<PlatformSongDetail, Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchSongPlatformDetail(song: song) }
    }

    func fetchKugouLyrics(song: Song) -> AnyPublisher<String, Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchLyrics(song: song) }
    }

    func fetchKugouArtistSongs(id: Int, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchArtistSongs(id: id, page: page, pageSize: pageSize) }
    }

    func fetchKugouArtistAlbums(id: Int, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<[AlbumInfo], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchArtistAlbums(id: id, page: page, pageSize: pageSize) }
    }

    func fetchKugouAlbumSongs(id: String, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<[Song], Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchAlbumSongs(id: id, page: page, pageSize: pageSize) }
    }

    func fetchKugouMVURL(hash: String, videoID: Int? = nil) -> AnyPublisher<URL, Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchMVURL(hash: hash, videoID: videoID) }
    }

    func claimKugouDailyLiteVIP(date: Date = Date()) -> AnyPublisher<KCMDailyVIPClaimResult, Error> {
        asyncToPublisher { try await KCMMusicService.shared.claimDailyLiteVIP(date: date) }
    }

    func upgradeKugouDailyLiteVIP() -> AnyPublisher<Bool, Error> {
        asyncToPublisher { try await KCMMusicService.shared.upgradeDailyLiteVIP() }
    }
}
