import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - QQ Artists

    func fetchQQArtistData(reset: Bool = false) {
        if reset {
            qqArtists = []
            qqArtistPage = 1
            qqArtistSin = 0
            hasMoreQQArtists = true
            isLoadingQQArtists = false
            isSearchingQQArtists = false
        }

        if !qqArtistSearchText.isEmpty { return }
        if isLoadingQQArtists || !hasMoreQQArtists { return }

        let cacheKey = "qq_artists_\(qqArtistArea)_\(qqArtistSex)_\(qqArtistGenre)_0"
        if qqArtists.isEmpty && qqArtistSin == 0 {
            if let cached = OptimizedCacheManager.shared.getObject(forKey: cacheKey, type: [ArtistInfo].self), !cached.isEmpty {
                self.qqArtists = cached
                self.qqArtistSin = cached.count
                return
            }
        }

        isLoadingQQArtists = true

        let pageSize = 80
        apiService.fetchQQSingerListIndex(
            area: qqArtistArea,
            sex: qqArtistSex,
            genre: qqArtistGenre,
            index: -100,
            sin: qqArtistSin,
            curPage: qqArtistPage
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] _ in
            self?.isLoadingQQArtists = false
        }, receiveValue: { [weak self] result in
            guard let self = self else { return }
            let (artists, total) = result
            if self.qqArtistSin == 0 {
                self.qqArtists = artists
                OptimizedCacheManager.shared.setObject(artists, forKey: cacheKey)
            } else {
                let existingIds = Set(self.qqArtists.map { $0.id })
                let newArtists = artists.filter { !existingIds.contains($0.id) }
                self.qqArtists.append(contentsOf: newArtists)
            }
            self.qqArtistSin += artists.count
            self.qqArtistPage += 1
            self.hasMoreQQArtists = self.qqArtists.count < total && artists.count >= pageSize
        })
        .store(in: &cancellables)
    }

    func loadMoreQQArtists() {
        if !isSearchingQQArtists {
            fetchQQArtistData(reset: false)
        }
    }

    func searchQQArtists(keyword: String) {
        isLoadingQQArtists = true
        isSearchingQQArtists = true

        apiService.searchQQArtists(keyword: keyword, page: 1, num: 30)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingQQArtists = false
            }, receiveValue: { [weak self] artists in
                self?.qqArtists = artists
                self?.hasMoreQQArtists = false
            })
            .store(in: &cancellables)
    }
}
