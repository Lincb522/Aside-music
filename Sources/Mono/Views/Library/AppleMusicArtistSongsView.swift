import SwiftUI

/// Apple Music 歌手曲目页：以歌手名为关键词分页搜索歌曲（每页 25 首），滚到底部自动加载更多。
struct AppleMusicArtistSongsView: View {
    let artist: ArtistInfo

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var page = 0
    @State private var errorMessage: String?
    @State private var pageTask: Task<Void, Never>?
    @State private var loadRevision = 0

    private let pageSize = 25

    @State private var selectedTab = 0
    @State private var showAddToPlaylist = false

    var body: some View {
        ArtistDetailPage(
            identity: ArtistNameArtworkIdentity(name: artist.name, aliases: artist.alias ?? [], qqMid: artist.qqMid),
            coverURL: artist.coverUrl?.sized(1000),
            source: MusicSource.appleMusic.shortName,
            tabs: [ArtistDetailTab(id: 0, title: String(localized: "artist_tab_songs"))],
            selectedTab: $selectedTab,
            canPlay: !songs.isEmpty,
            play: {
                if let first = songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: songs)
                }
            },
            secondaryAction: { showAddToPlaylist = true }
        ) {
            if isLoading && songs.isEmpty {
                ArtistContentState(isLoading: true, text: "")
            } else if songs.isEmpty {
                ArtistContentState(text: errorMessage ?? String(localized: "empty_no_songs"))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.element.identityKey) { index, song in
                        SongListRow(song: song, index: index, onTap: {
                            PlayerManager.shared.play(song: song, in: songs)
                        }, usesArtistStyle: true)
                        .onAppear {
                            if index == songs.count - 1 { loadMoreIfNeeded() }
                        }
                    }
                    if isLoadingMore { ProgressView().tint(.white).padding() }
                }
            }
        }
        .monoSheet(isPresented: $showAddToPlaylist, preset: .standard) {
            BatchAddToPlaylistSheet(songs: songs)
        }
        .task {
            if songs.isEmpty { await load(reset: true) }
        }
        .onDisappear {
            loadRevision += 1
            pageTask?.cancel()
            pageTask = nil
            isLoading = false
            isLoadingMore = false
        }
    }

    private func loadMoreIfNeeded() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        pageTask = Task { await load(reset: false) }
    }

    @MainActor
    private func load(reset: Bool) async {
        guard !Task.isCancelled else { return }
        if reset {
            loadRevision += 1
            pageTask?.cancel()
            pageTask = nil
            page = 0
            hasMore = true
            songs = []
            errorMessage = nil
            isLoading = true
        } else {
            isLoadingMore = true
        }

        let revision = loadRevision
        let requestedPage = page
        defer {
            if loadRevision == revision {
                isLoading = false
                isLoadingMore = false
                pageTask = nil
            }
        }
        do {
            let result = try await AppleMusicService.shared.searchSongs(
                term: artist.name,
                offset: requestedPage * pageSize,
                limit: pageSize
            )
            guard !Task.isCancelled, loadRevision == revision else { return }
            if reset {
                songs = result.songs
            } else {
                let existingIDs = Set(songs.map {
                    PlayerManager.playbackIdentityKey(for: $0)
                })
                songs.append(contentsOf: result.songs.filter {
                    !existingIDs.contains(PlayerManager.playbackIdentityKey(for: $0))
                })
            }
            page = requestedPage + 1
            hasMore = result.hasMore
        } catch {
            guard !Task.isCancelled, loadRevision == revision else { return }
            errorMessage = error.localizedDescription
            hasMore = false
        }

    }
}
