import Foundation
@preconcurrency import Combine

extension APIService {
    func searchKugouSongsWithTotal(keyword: String, page: Int = 1, pageSize: Int = 30) -> AnyPublisher<KCMSearchPage, Error> {
        asyncToPublisher {
            try await KCMMusicService.shared.searchSongs(keyword: keyword, page: page, pageSize: pageSize)
        }
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

    func fetchKugouSongURL(song: Song) -> AnyPublisher<URL, Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchSongURL(song: song) }
    }

    func fetchKugouLyrics(song: Song) -> AnyPublisher<String, Error> {
        asyncToPublisher { try await KCMMusicService.shared.fetchLyrics(song: song) }
    }

    func claimKugouDailyLiteVIP(date: Date = Date()) -> AnyPublisher<Bool, Error> {
        asyncToPublisher { try await KCMMusicService.shared.claimDailyLiteVIP(date: date) }
    }

    func upgradeKugouDailyLiteVIP() -> AnyPublisher<Bool, Error> {
        asyncToPublisher { try await KCMMusicService.shared.upgradeDailyLiteVIP() }
    }
}
