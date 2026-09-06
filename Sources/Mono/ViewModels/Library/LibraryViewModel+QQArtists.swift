import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - QQ Artists

    func fetchQQArtistData(reset: Bool = false) {
        if reset {
            qqArtistRequest.cancel()
            qqArtists = []
            qqArtistPage = 1
            qqArtistSin = 0
            hasMoreQQArtists = true
            isLoadingQQArtists = false
            isSearchingQQArtists = false
        }
        guard qqArtistSearchText.isEmpty, !isLoadingQQArtists, hasMoreQQArtists,
              !qqArtistRequest.isRunning else { return }

        isLoadingQQArtists = true
        let pageSize = 80
        let area = qqArtistArea
        let sex = qqArtistSex
        let genre = qqArtistGenre
        let sin = qqArtistSin
        let page = qqArtistPage
        let restoreCache = qqArtists.isEmpty && sin == 0
        let cacheKey = "qq_artists_\(area)_\(sex)_\(genre)_0"
        let request = qqArtistRequest.begin()
        qqArtistRequest.task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            if restoreCache {
                let cached = await OptimizedCacheManager.shared.getObjectAsync(forKey: cacheKey, type: [ArtistInfo].self)
                guard let self, !Task.isCancelled, self.qqArtistRequest.isCurrent(request) else { return }
                if let cached, !cached.isEmpty {
                    self.qqArtists = cached
                    self.qqArtistSin = cached.count
                    self.isLoadingQQArtists = false
                    self.qqArtistRequest.finish(request)
                    return
                }
            }
            guard let self, !Task.isCancelled, self.qqArtistRequest.isCurrent(request) else { return }
            self.qqArtistRequest.cancellable = self.apiService.fetchQQSingerListIndex(
                area: area, sex: sex, genre: genre, index: -100, sin: sin, curPage: page
            )
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.qqArtistRequest.isCurrent(request) else { return }
                self.qqArtistRequest.finish(request)
                self.isLoadingQQArtists = false
            }, receiveValue: { [weak self] result in
                guard let self, self.qqArtistRequest.isCurrent(request) else { return }
                let (artists, total) = result
                if sin == 0 {
                    self.qqArtists = artists
                    OptimizedCacheManager.shared.setObject(artists, forKey: cacheKey)
                } else {
                    let existingIds = Set(self.qqArtists.map { $0.id })
                    let newArtists = artists.filter { !existingIds.contains($0.id) }
                    self.qqArtists.append(contentsOf: newArtists)
                }
                self.qqArtistSin = sin + artists.count
                self.qqArtistPage = page + 1
                self.hasMoreQQArtists = self.qqArtists.count < total && artists.count >= pageSize
            })
        }
    }

    func loadMoreQQArtists() {
        if !isSearchingQQArtists {
            fetchQQArtistData(reset: false)
        }
    }

    func searchQQArtists(keyword: String) {
        isLoadingQQArtists = true
        isSearchingQQArtists = true

        let request = qqArtistRequest.begin()
        qqArtistRequest.cancellable = apiService.searchQQArtists(keyword: keyword, page: 1, num: 30)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.qqArtistRequest.isCurrent(request) else { return }
                self.qqArtistRequest.finish(request)
                self.isLoadingQQArtists = false
            }, receiveValue: { [weak self] artists in
                guard let self, self.qqArtistRequest.isCurrent(request) else { return }
                self.qqArtists = artists
                self.hasMoreQQArtists = false
            })
    }
}
