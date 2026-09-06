import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - Playlist Square

    func fetchSquareData() {
        if playlistCategories.isEmpty, !categoryRequest.isRunning {
            let request = categoryRequest.begin()
            categoryRequest.task = Task { @MainActor [weak self] in
                guard !Task.isCancelled else { return }
                let cached = await OptimizedCacheManager.shared.getObjectAsync(
                    forKey: "playlist_categories", type: [PlaylistCategory].self
                )
                guard let self, !Task.isCancelled, self.categoryRequest.isCurrent(request) else { return }
                if let cached, !cached.isEmpty {
                    self.playlistCategories = cached
                    self.categoryRequest.finish(request)
                    return
                }
                self.categoryRequest.cancellable = self.apiService.fetchPlaylistCategories()
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] _ in
                        self?.categoryRequest.finish(request)
                    }, receiveValue: { [weak self] tags in
                        guard let self, self.categoryRequest.isCurrent(request) else { return }
                        var allTags = [PlaylistCategory(name: NSLocalizedString("filter_all", comment: ""), id: -1, category: -1, hot: true)]
                        allTags.append(contentsOf: tags)
                        self.playlistCategories = allTags
                        OptimizedCacheManager.shared.setObject(allTags, forKey: "playlist_categories")
                    })
            }
        }

        if squarePlaylists.isEmpty, !squareRequest.isRunning {
            loadSquarePlaylists(cat: selectedCategory, reset: true)
        }
    }

    func loadSquarePlaylists(cat: String, reset: Bool = false) {
        if reset {
            squareRequest.cancel()
            isLoadingSquare = true
            isLoadingMoreSquare = false
            squareOffset = 0
            hasMoreSquarePlaylists = true
            squarePlaylists = []
        } else {
            guard !squareRequest.isRunning else { return }
            if isLoadingMoreSquare || !hasMoreSquarePlaylists { return }
            isLoadingMoreSquare = true
        }

        let limit = 30
        let offset = reset ? 0 : squareOffset

        let request = squareRequest.begin()
        squareRequest.task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            if reset {
                let cached = await OptimizedCacheManager.shared.getObjectAsync(
                    forKey: "square_playlists_\(cat)", type: [Playlist].self
                )
                guard let self, !Task.isCancelled, self.squareRequest.isCurrent(request) else { return }
                if let cached {
                    self.squarePlaylists = cached
                    self.isLoadingSquare = false
                    self.squareOffset = cached.count
                }
            }
            guard let self, !Task.isCancelled, self.squareRequest.isCurrent(request) else { return }
            self.squareRequest.cancellable = self.apiService.fetchTopPlaylists(cat: cat, limit: limit, offset: offset)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.squareRequest.isCurrent(request) else { return }
                    self.squareRequest.finish(request)
                    self.isLoadingSquare = false
                    self.isLoadingMoreSquare = false
                }, receiveValue: { [weak self] playlists in
                    guard let self, self.squareRequest.isCurrent(request) else { return }

                    if reset {
                        self.squarePlaylists = playlists
                        OptimizedCacheManager.shared.setObject(playlists, forKey: "square_playlists_\(cat)")
                    } else {
                        // 去重：过滤掉已存在的歌单
                        let existingIds = Set(self.squarePlaylists.map { $0.id })
                        let newPlaylists = playlists.filter { !existingIds.contains($0.id) }
                        self.squarePlaylists.append(contentsOf: newPlaylists)
                    }

                    self.squareOffset = offset + playlists.count
                    self.hasMoreSquarePlaylists = playlists.count >= limit
                })
        }
    }

    func loadMoreSquarePlaylists() {
        loadSquarePlaylists(cat: selectedCategory, reset: false)
    }
}
