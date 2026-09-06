import SwiftUI
import Combine

extension LibraryViewModel {
    // MARK: - Apple Music Playlist Square

    func fetchAppleMusicSquareData(reset: Bool = false) {
        if reset {
            appleMusicSquarePlaylists = []
            appleMusicSquarePage = 0
            hasMoreAppleMusicSquare = true
            isLoadingAppleMusicSquare = false
            isLoadingMoreAppleMusicSquare = false
        }

        if !reset, !appleMusicSquarePlaylists.isEmpty || appleSquareRequest.isRunning { return }
        loadAppleMusicSquarePlaylists(reset: true)
    }

    func loadAppleMusicSquarePlaylists(reset: Bool = false) {
        if reset {
            appleSquareRequest.cancel()
            isLoadingMoreAppleMusicSquare = false
            appleMusicSquarePlaylists = []
            appleMusicSquarePage = 0
            hasMoreAppleMusicSquare = true
            isLoadingAppleMusicSquare = true
        } else {
            guard !appleSquareRequest.isRunning else { return }
            guard hasMoreAppleMusicSquare, !isLoadingMoreAppleMusicSquare else { return }
            isLoadingMoreAppleMusicSquare = true
        }

        let page = reset ? 0 : appleMusicSquarePage
        let pageSize = 25
        let request = appleSquareRequest.begin()
        appleSquareRequest.task = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            defer {
                if self.appleSquareRequest.isCurrent(request) {
                    self.appleSquareRequest.finish(request)
                    self.isLoadingAppleMusicSquare = false
                    self.isLoadingMoreAppleMusicSquare = false
                }
            }
            do {
                let result = try await AppleMusicService.shared.searchPlaylists(
                    term: self.appleMusicSquareKeyword,
                    offset: page * pageSize,
                    limit: pageSize
                )
                guard !Task.isCancelled, self.appleSquareRequest.isCurrent(request) else { return }
                if reset {
                    self.appleMusicSquarePlaylists = result.playlists
                } else {
                    let existingIDs = Set(self.appleMusicSquarePlaylists.map(\.id))
                    self.appleMusicSquarePlaylists.append(contentsOf: result.playlists.filter {
                        !existingIDs.contains($0.id)
                    })
                }
                self.appleMusicSquarePage = page + 1
                self.hasMoreAppleMusicSquare = result.hasMore
            } catch {
                guard !Task.isCancelled, self.appleSquareRequest.isCurrent(request) else { return }
                self.hasMoreAppleMusicSquare = false
                AppLogger.warning(
                    "[AppleMusic] 歌单广场加载失败: \(error.localizedDescription)",
                    step: "apple-music.playlist-square"
                )
            }
        }
    }

    func loadMoreAppleMusicSquarePlaylists() {
        loadAppleMusicSquarePlaylists(reset: false)
    }

    // MARK: - Apple Music Artists

    func fetchAppleMusicArtistData(reset: Bool = false) {
        if reset {
            appleMusicArtists = []
            appleMusicArtistPage = 0
            hasMoreAppleMusicArtists = true
            isLoadingAppleMusicArtists = false
            isSearchingAppleMusicArtists = false
        }

        if !appleMusicArtistSearchText.isEmpty { return }
        if !reset, !appleMusicArtists.isEmpty || appleArtistRequest.isRunning { return }
        loadAppleMusicArtists(keyword: appleMusicArtistKeyword, reset: true, searching: false)
    }

    func loadMoreAppleMusicArtists() {
        guard !isSearchingAppleMusicArtists else { return }
        loadAppleMusicArtists(keyword: appleMusicArtistKeyword, reset: false, searching: false)
    }

    func searchAppleMusicArtists(keyword: String) {
        loadAppleMusicArtists(keyword: keyword, reset: true, searching: true)
    }

    func selectAppleMusicArtistCategory(_ index: Int) {
        guard appleMusicArtistCategories.indices.contains(index) else { return }
        appleMusicArtistCategory = index
        appleMusicArtistKeyword = appleMusicArtistCategories[index].keyword
        appleMusicArtistSearchText = ""
        fetchAppleMusicArtistData(reset: true)
    }

    private func loadAppleMusicArtists(
        keyword: String,
        reset: Bool,
        searching: Bool
    ) {
        if reset {
            appleArtistRequest.cancel()
            appleMusicArtists = []
            appleMusicArtistPage = 0
            hasMoreAppleMusicArtists = true
            isLoadingAppleMusicArtists = true
            isSearchingAppleMusicArtists = searching
        } else {
            guard !appleArtistRequest.isRunning else { return }
            guard hasMoreAppleMusicArtists, !isLoadingAppleMusicArtists else { return }
            isLoadingAppleMusicArtists = true
        }

        let page = reset ? 0 : appleMusicArtistPage
        let pageSize = 25
        let request = appleArtistRequest.begin()
        appleArtistRequest.task = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            defer {
                if self.appleArtistRequest.isCurrent(request) {
                    self.appleArtistRequest.finish(request)
                    self.isLoadingAppleMusicArtists = false
                }
            }
            do {
                let result = try await AppleMusicService.shared.searchArtists(
                    term: keyword,
                    offset: page * pageSize,
                    limit: pageSize
                )
                guard !Task.isCancelled, self.appleArtistRequest.isCurrent(request) else { return }
                if reset {
                    self.appleMusicArtists = result.artists
                } else {
                    let existingIDs = Set(self.appleMusicArtists.map(\.id))
                    self.appleMusicArtists.append(contentsOf: result.artists.filter {
                        !existingIDs.contains($0.id)
                    })
                }
                self.appleMusicArtistPage = page + 1
                self.hasMoreAppleMusicArtists = result.hasMore
            } catch {
                guard !Task.isCancelled, self.appleArtistRequest.isCurrent(request) else { return }
                self.hasMoreAppleMusicArtists = false
                AppLogger.warning(
                    "[AppleMusic] 歌手加载失败: \(error.localizedDescription)",
                    step: "apple-music.artists"
                )
            }
        }
    }
}
