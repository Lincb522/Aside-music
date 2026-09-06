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
        .task { await load(reset: true) }
    }

    private func loadMoreIfNeeded() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        Task { await load(reset: false) }
    }

    @MainActor
    private func load(reset: Bool) async {
        if reset {
            page = 0
            hasMore = true
            songs = []
            errorMessage = nil
            isLoading = true
        } else {
            isLoadingMore = true
        }

        do {
            let result = try await AppleMusicService.shared.searchSongs(
                term: artist.name,
                offset: page * pageSize,
                limit: pageSize
            )
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
            page += 1
            hasMore = result.hasMore
        } catch {
            errorMessage = error.localizedDescription
            hasMore = false
        }

        isLoading = false
        isLoadingMore = false
    }
}
