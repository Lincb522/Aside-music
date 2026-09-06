import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - Artists

    func fetchArtistData(reset: Bool = false) {
        if reset {
            artistRequest.cancel()
            topArtists = []
            artistOffset = 0
            hasMoreArtists = true
            isLoadingArtists = false
        }
        guard artistSearchText.isEmpty, !isLoadingArtists, hasMoreArtists,
              !artistRequest.isRunning else { return }

        isLoadingArtists = true
        isSearchingArtists = false
        let limit = 30
        let offset = artistOffset
        let area = artistArea
        let type = artistType
        let initial = artistInitial
        let restoreCache = topArtists.isEmpty && offset == 0
        let cacheKey = "artists_\(area)_\(type)_\(initial)_0"
        let request = artistRequest.begin()
        artistRequest.task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            if restoreCache {
                let cached = await OptimizedCacheManager.shared.getObjectAsync(forKey: cacheKey, type: [ArtistInfo].self)
                guard let self, !Task.isCancelled, self.artistRequest.isCurrent(request) else { return }
                if let cached, !cached.isEmpty {
                    self.topArtists = cached
                    self.artistOffset = cached.count
                    self.isLoadingArtists = false
                    self.artistRequest.finish(request)
                    return
                }
            }
            guard let self, !Task.isCancelled, self.artistRequest.isCurrent(request) else { return }
            self.artistRequest.cancellable = self.apiService.fetchArtistList(type: type, area: area, initial: initial, limit: limit, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.artistRequest.isCurrent(request) else { return }
                    self.artistRequest.finish(request)
                    self.isLoadingArtists = false
                }, receiveValue: { [weak self] artists in
                    guard let self, self.artistRequest.isCurrent(request) else { return }
                    if offset == 0 {
                        self.topArtists = artists
                        OptimizedCacheManager.shared.setObject(artists, forKey: cacheKey)
                    } else {
                        let existingIds = Set(self.topArtists.map { $0.id })
                        let newArtists = artists.filter { !existingIds.contains($0.id) }
                        self.topArtists.append(contentsOf: newArtists)
                    }
                    self.hasMoreArtists = artists.count >= limit
                    self.artistOffset = offset + artists.count
                })
        }
    }

    func loadMoreArtists() {
        fetchArtistData(reset: false)
    }

    func searchArtists(keyword: String) {
        isLoadingArtists = true
        isSearchingArtists = true

        let request = artistRequest.begin()
        artistRequest.cancellable = apiService.searchArtists(keyword: keyword)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.artistRequest.isCurrent(request) else { return }
                self.artistRequest.finish(request)
                self.isLoadingArtists = false
            }, receiveValue: { [weak self] artists in
                guard let self, self.artistRequest.isCurrent(request) else { return }
                self.topArtists = artists
            })
    }
}
