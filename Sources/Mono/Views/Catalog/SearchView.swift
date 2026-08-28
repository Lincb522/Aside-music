import SwiftUI

// MARK: - SearchView

struct SearchView: View {
    @StateObject var viewModel = SearchViewModel()
    @ObservedObject var settings = SettingsManager.shared
    @State var selectedArtistId: Int?
    @State var selectedArtist: ArtistInfo?
    @State var showArtistDetail = false
    @State var selectedSongForDetail: Song?
    @State var showSongDetail = false
    @State var selectedPlaylist: Playlist?
    @State var showPlaylistDetail = false
    @State var selectedMVId: MVIdItem?
    @State var selectedAlbumId: Int?
    @State var selectedAlbum: AlbumInfo?
    @Environment(\.dismiss) var dismiss
    @State var showAlbumDetail = false
    @FocusState var isFocused: Bool
    @State var isSearchBarExpanded: Bool = true

    // qcm详情导航
    @State var qqDetailType: QQDetailType?
    @State var showQQDetail = false
    @State var selectedQQMV: QQMVVidItem?
    @State var selectedKCMMV: KCMMV?
    @State var isSearchSelectMode = false
    @State var searchSelectedIds: Set<Int> = []
    @State var showSearchBatchPlaylist = false
    @State var searchFilterText = ""
    @State var isSearchFiltering = false
    @Namespace var sequoiaSearchNamespace

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            searchRootContent
                .iPadContentWidth()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoEdgeSwipeToDismiss()
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artist = selectedArtist {
                ArtistDetailView(artist: artist)
            } else if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showPlaylistDetail) {
            if let playlist = selectedPlaylist {
                PlaylistDetailView(playlist: playlist, songs: nil)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let album = selectedAlbum {
                AlbumDetailView(album: album)
            } else if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showQQDetail) {
            if let detail = qqDetailType {
                QQMusicDetailView(detailType: detail)

            } else {
                EmptyView()
            }
        }
        .fullScreenCover(item: $selectedMVId) { item in
            MVPlayerView(mvId: item.id)
        }
        .fullScreenCover(item: $selectedQQMV) { item in
            QQMVPlayerView(vid: item.vid)
        }
        .fullScreenCover(item: $selectedKCMMV) { item in
            KCMMVPlayerView(mv: item)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    var searchRootContent: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteSearchRoot
        } else if viewModel.hasSearched {
            ZStack {
                searchContentView
                suggestionsOverlay
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if PetWhiteStyle.isActive {
            petWhiteInitialSearchRoot
        } else {
            VStack(spacing: 0) {
                if MangaStyle.isActive {
                    mangaSearchHeader
                } else if PetWhiteStyle.isActive {
                    petWhiteSearchHeader
                } else if NeumorphicStyle.isActive {
                    neumorphicSearchHeader
                } else if SignalStyle.isActive {
                    signalSearchHeader
                } else if MujiStyle.isActive {
                    mujiSearchHeader
                } else if SequoiaStyle.isActive {
                    sequoiaSearchHeader
                } else if LiquidGlassStyle.isActive {
                    liquidGlassSearchHeader
                } else if CapsuleStyle.isActive {
                    capsuleSearchHeader
                } else {
                    defaultSearchHeader
                }

                searchBarSection

                ZStack {
                    searchContentView
                    suggestionsOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    var minimalWhiteSearchRoot: some View {
        VStack(spacing: 0) {
            searchBarSection
                .padding(.top, DeviceLayout.headerTopPadding + 8)
                .padding(.bottom, 12)

            ZStack {
                searchContentView
                suggestionsOverlay
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var petWhiteInitialSearchRoot: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    petWhiteSearchHeader
                    searchBarSection

                    if viewModel.query.isEmpty {
                        petWhiteEmptySearchView
                    }

                    FloatingBarBottomSpacer()
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()

            suggestionsOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
