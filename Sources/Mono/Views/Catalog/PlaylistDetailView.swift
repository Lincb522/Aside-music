import SwiftUI

// MARK: - Main View
struct PlaylistDetailView: View {
    let playlist: Playlist
    let initialSongs: [Song]?
    let bannerCoverURL: URL?

    @StateObject var viewModel = PlaylistDetailViewModel()

    @ObservedObject var playerManager = PlayerManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared
    @ObservedObject var settings = SettingsManager.shared

    @State var selectedSongForDetail: Song?
    @State var showSongDetail = false
    @State var selectedArtistId: Int?
    @State var showArtistDetail = false
    @State var selectedAlbumId: Int?
    @State var showAlbumDetail = false
    @State var selectedRelatedPlaylist: Playlist?
    @State var showRelatedPlaylist = false
    @State var isCollectedLocally = false
    @State var showCollectOptions = false

    @State var scrollOffset: CGFloat = 0
    @State var searchText = ""
    @State var isSearching = false
    @State var isSelectMode = false
    @State var selectedSongIds: Set<Int> = []
    @State var showBatchAddToPlaylist = false
    @State var showPlaylistDesc = false

    init(playlist: Playlist, songs: [Song]? = nil, bannerCoverURLString: String? = nil) {
        self.playlist = playlist
        self.initialSongs = songs
        self.bannerCoverURL = bannerCoverURLString.flatMap(URL.init(string:))
    }

    struct Theme {
        static let cream = Color.clear
        static var milk: Color { .monoMilk }
        static var accent: Color { .monoIconBackground }
        static var text: Color { .monoTextPrimary }
        static var secondaryText: Color { .monoTextSecondary }
        static let softShadow = Color.clear
    }

    var petWhiteDetailHorizontalPadding: CGFloat {
        DeviceLayout.isPad ? 8 : 4
    }

    /// aside(default) 及无独立分支主题走歌手页式 Hero 头部
    var usesAsideHero: Bool {
        bannerCoverURL == nil
            && !MinimalWhiteStyle.isActive && !PetWhiteStyle.isActive
            && !MangaStyle.isActive && !NeumorphicStyle.isActive
            && !SignalStyle.isActive && !MujiStyle.isActive
            && !CapsuleStyle.isActive && !BentoStyle.isActive
            && !SequoiaStyle.isActive
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteRootBackdrop()
            } else if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if PetWhiteStyle.isActive {
                PetWhiteRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else if SignalStyle.isActive {
                ThemeRenderBackdrop(theme: .default)
            } else if BentoStyle.isActive {
                BentoRootBackdrop()
            } else if CapsuleStyle.isActive {
                CapsuleRootBackdrop()
            } else if SettingsManager.shared.usesPlaylistCoverBackground {
                PlaylistColorBackground(coverUrl: playlist.coverUrl?.sized(200))
            } else {
                ThemedPageBackground()
            }

            ScrollView {
                VStack(spacing: 0) {
                    if usesAsideHero || SignalStyle.isActive {
                        // Hero 头部自带拉伸/视差，不叠加收缩动效
                        playlistHeaderContent
                    } else {
                        playlistHeaderContent
                            .monoPageHeaderCollapse()
                    }
                    PlaylistSearchBar(
                        searchText: $searchText,
                        isSearching: $isSearching,
                        onSearchActivated: { viewModel.loadAllRemaining() },
                        isSelectMode: $isSelectMode,
                        selectedIds: $selectedSongIds,
                        songs: filteredSongs,
                        onBatchQueue: {
                            let selected = filteredSongs.filter { selectedSongIds.contains($0.id) }
                            SongBatchActionHelper.addToQueue(selected) {
                                isSelectMode = false
                                selectedSongIds.removeAll()
                            }
                        },
                        onBatchDownload: { batchDownloadSelected() },
                        onBatchCollect: { showBatchAddToPlaylist = true }
                    )
                    songListSection
                        .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .monoScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: (usesAsideHero || SignalStyle.isActive) ? .top : [])
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                    toolbarTrackCountView(count)
                }
            }
        }
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            }
        }
        .navigationDestination(isPresented: $showRelatedPlaylist) {
            if let pl = selectedRelatedPlaylist {
                PlaylistDetailView(playlist: pl, songs: nil)

            }
        }
        .onAppear {
            if let songs = initialSongs {
                viewModel.setSongs(songs)
            } else {
                viewModel.fetchSongs(playlistId: playlist.id, source: playlist.source, playlist: playlist)
            }
            let name = playlist.name
            isCollectedLocally = LocalPlaylistManager.shared.playlists.contains { $0.name == name }
        }
        .monoSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            let selected = filteredSongs.filter { selectedSongIds.contains($0.id) }
            BatchAddToPlaylistSheet(songs: selected)
        }
        .monoSheet(isPresented: $showPlaylistDesc, preset: .standard){
            PlaylistDescSheet(
                coverUrl: playlist.coverUrl?.sized(200),
                title: viewModel.playlistDetail?.name ?? playlist.name,
                subtitle: playlist.creator?.nickname,
                descriptionText: viewModel.playlistDetail?.description ?? playlist.description
            )
        }
    }

    func batchDownloadSelected() {
        let selected = filteredSongs.filter { selectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(
            title: String(localized: "download_batch_added_title"),
            message: L10n.format("download_batch_queue_added_format", selected.count),
            primaryButtonTitle: String(localized: "common_confirm"),
            primaryAction: {}
        )
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }

}
