import SwiftUI

struct ClaritySearchView: View {
    @StateObject private var model = SearchViewModel()
    @FocusState private var focused: Bool
    @State private var selectedMV: MVIdItem?
    @State private var selectedQQMV: QQMVVidItem?
    @State private var selectedKCMMV: KCMMV?

    private let sources: [MusicSource] = [.netease, .qqmusic, .kugou, .qishui, .appleMusic]

    var body: some View {
        ZStack {
            ClarityBackdrop()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    searchField
                    sourcePicker

                    if model.hasSearched {
                        typePicker
                        searchResults
                    } else {
                        discovery
                    }

                    FloatingBarBottomSpacer()
                }
                // Navigation chrome owns the safe-area offset on this pushed page.
                // Adding the root-tab header inset again left a large blank strip.
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedMV) { MVPlayerView(mvId: $0.id) }
        .fullScreenCover(item: $selectedQQMV) { QQMVPlayerView(vid: $0.vid) }
        .fullScreenCover(item: $selectedKCMMV) { KCMMVPlayerView(mv: $0) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(String(localized: "search_title"))
                .font(ClarityStyle.title(23, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
            Spacer()
            if model.hasSearched {
                ClarityCircleButton(icon: .close, size: 42) {
                    model.clearSearch()
                    focused = true
                }
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .monoPageHeaderCollapse()
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            MonoIcon(icon: .search, size: 17, color: ClarityStyle.inkSoft, lineWidth: 1.6)

            TextField(String(localized: "search_bar_placeholder"), text: $model.query)
                .font(ClarityStyle.body(15, weight: .medium))
                .foregroundStyle(ClarityStyle.ink)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { model.performSearch(keyword: model.query) }

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    model.clearSearch()
                } label: {
                    MonoIcon(icon: .xmarkCircle, size: 17, color: ClarityStyle.inkFaint, lineWidth: 1.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(ClarityMembrane(shape: Capsule(), strength: .strong))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var sourcePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(sources, id: \.self) { source in
                    Button {
                        model.selectedPlatform = source
                    } label: {
                        Text(source.shortName)
                            .font(ClarityStyle.body(11.5, weight: .semibold))
                            .foregroundStyle(model.selectedPlatform == source ? ClarityStyle.onSelection : ClarityStyle.inkSoft)
                            .padding(.horizontal, 15)
                            .frame(height: 36)
                            .background {
                                if model.selectedPlatform == source {
                                    ClaritySelectionLens(shape: Capsule())
                                } else {
                                    ClarityMembrane(shape: Capsule(), strength: .quiet)
                                }
                            }
                    }
                    .buttonStyle(ClarityPressStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var typePicker: some View {
        HStack(spacing: 0) {
            ForEach(SearchTab.allCases, id: \.rawValue) { tab in
                Button {
                    model.currentTab = tab
                    if model.hasSearched { model.performSearch(keyword: model.activeSearchKeyword) }
                } label: {
                    VStack(spacing: 8) {
                        Text(LocalizedStringKey(tab.rawValue))
                            .font(ClarityStyle.body(12, weight: model.currentTab == tab ? .bold : .medium))
                            .foregroundStyle(model.currentTab == tab ? ClarityStyle.ink : ClarityStyle.inkFaint)
                        Capsule()
                            .fill(model.currentTab == tab ? ClarityStyle.selection : Color.clear)
                            .frame(width: model.currentTab == tab ? 26 : 18, height: 2.5)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    @ViewBuilder
    private var searchResults: some View {
        if model.isLoading && selectedCount == 0 {
            ProgressView().tint(ClarityStyle.accent).frame(maxWidth: .infinity).padding(.top, 80)
        } else if selectedCount == 0 {
            emptyState
        } else {
            switch model.currentTab {
            case .songs: songResults
            case .artists: artistResults
            case .playlists: playlistResults
            case .albums: albumResults
            case .mvs: mvResults
            }
        }
    }

    private var songResults: some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                Button { PlayerManager.shared.play(song: song, in: songs) } label: {
                    HStack(spacing: 12) {
                        ClarityArtwork(url: song.coverUrl, size: 50, radius: 15)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.name).font(ClarityStyle.body(14, weight: .semibold)).foregroundStyle(ClarityStyle.ink).lineLimit(1)
                            Text(song.artistName).font(ClarityStyle.body(11.5)).foregroundStyle(ClarityStyle.inkSoft).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(song.musicSource.shortName)
                            .font(ClarityStyle.body(9.5, weight: .bold))
                            .foregroundStyle(ClarityStyle.inkFaint)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(ClarityPressStyle())
                if index < songs.count - 1 { Divider().overlay(ClarityStyle.line).padding(.leading, 76) }
            }
        }
        .background(ClarityMembrane(shape: RoundedRectangle(cornerRadius: 28, style: .continuous), strength: .regular))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var artistResults: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 15)], spacing: 18) {
            ForEach(artists, id: \.id) { artist in
                NavigationLink {
                    ArtistDetailView(artist: artist)
                } label: {
                    VStack(spacing: 9) {
                        ClarityArtwork(url: artist.coverUrl, size: 92, radius: 46)
                        Text(artist.name)
                            .font(ClarityStyle.body(12.5, weight: .semibold))
                            .foregroundStyle(ClarityStyle.ink)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(ClarityPressStyle())
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var playlistResults: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
            ForEach(playlists) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist)
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        GeometryReader { proxy in
                            ClarityArtwork(url: playlist.coverUrl, size: proxy.size.width, radius: 24)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        Text(playlist.name).font(ClarityStyle.body(12.5, weight: .semibold)).foregroundStyle(ClarityStyle.ink).lineLimit(2)
                    }
                }
                .buttonStyle(ClarityPressStyle())
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var albumResults: some View {
        LazyVStack(spacing: 12) {
            ForEach(albums) { album in
                NavigationLink {
                    AlbumDetailView(albumId: album.id, albumName: album.name, albumCoverUrl: album.coverUrl)
                } label: {
                    HStack(spacing: 13) {
                        ClarityArtwork(url: album.coverUrl, size: 62, radius: 18)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.name).font(ClarityStyle.body(14, weight: .semibold)).foregroundStyle(ClarityStyle.ink).lineLimit(1)
                            Text(album.artistName).font(ClarityStyle.body(11.5)).foregroundStyle(ClarityStyle.inkSoft).lineLimit(1)
                        }
                        Spacer()
                        MonoIcon(icon: .chevronRight, size: 13, color: ClarityStyle.inkFaint, lineWidth: 1.5)
                    }
                    .padding(12)
                    .background(ClarityMembrane(shape: RoundedRectangle(cornerRadius: 24, style: .continuous), strength: .quiet))
                }
                .buttonStyle(ClarityPressStyle())
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var mvResults: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
            if model.selectedPlatform == .netease {
                ForEach(model.neteaseMVResults) { mv in
                    clarityMVCard(name: mv.displayName, artist: mv.artistName ?? "", cover: mv.coverUrl.flatMap(URL.init(string:))) {
                        selectedMV = MVIdItem(id: mv.id)
                    }
                }
            } else if model.selectedPlatform == .qqmusic {
                ForEach(model.qqMVResults) { mv in
                    clarityMVCard(name: mv.name, artist: mv.singerName ?? "", cover: mv.coverUrl.flatMap(URL.init(string:))) {
                        selectedQQMV = QQMVVidItem(vid: mv.vid)
                    }
                }
            } else if model.selectedPlatform == .kugou {
                ForEach(model.kugouMVResults) { mv in
                    clarityMVCard(name: mv.name, artist: mv.artistName ?? "", cover: mv.coverURL.flatMap(URL.init(string:))) {
                        selectedKCMMV = mv
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func clarityMVCard(name: String, artist: String, cover: URL?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    ClarityArtwork(url: cover, size: proxy.size.width, radius: 22)
                        .overlay(alignment: .bottomTrailing) {
                            MonoIcon(icon: .play, size: 12, color: ClarityStyle.ink, lineWidth: 1.7)
                                .frame(width: 34, height: 34)
                                .background(ClarityMembrane(shape: Circle(), strength: .strong))
                                .padding(8)
                        }
                }
                .aspectRatio(16 / 10, contentMode: .fit)
                Text(name).font(ClarityStyle.body(12.5, weight: .semibold)).foregroundStyle(ClarityStyle.ink).lineLimit(1)
                Text(artist).font(ClarityStyle.body(10.5)).foregroundStyle(ClarityStyle.inkSoft).lineLimit(1)
            }
        }
        .buttonStyle(ClarityPressStyle())
    }

    private var discovery: some View {
        VStack(alignment: .leading, spacing: 18) {
            ClaritySectionHeading(title: String(localized: "search_hot_title"))
            FlowLayout(spacing: 10) {
                ForEach(model.hotSearchItems.prefix(12)) { item in
                    Button {
                        model.query = item.searchWord
                        model.performSearch(keyword: item.searchWord)
                    } label: {
                        Text(item.searchWord)
                            .font(ClarityStyle.body(12.5, weight: .medium))
                            .foregroundStyle(ClarityStyle.ink)
                            .padding(.horizontal, 15)
                            .frame(height: 38)
                            .background(ClarityMembrane(shape: Capsule(), strength: .quiet))
                    }
                    .buttonStyle(ClarityPressStyle())
                }
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            MonoIcon(icon: .search, size: 25, color: ClarityStyle.inkFaint, lineWidth: 1.5)
                .frame(width: 58, height: 58)
                .background(ClarityMembrane(shape: Circle(), strength: .regular))
            Text(String(localized: "search_no_results"))
                .font(ClarityStyle.body(14, weight: .semibold))
                .foregroundStyle(ClarityStyle.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    }

    private var songs: [Song] {
        switch model.selectedPlatform {
        case .netease: model.neteaseResults
        case .qqmusic: model.qqResults
        case .qishui: model.qishuiResults
        case .kugou: model.kugouResults
        case .appleMusic: model.appleMusicResults
        case .local: []
        }
    }

    private var artists: [ArtistInfo] {
        switch model.selectedPlatform {
        case .netease: model.neteaseArtistResults
        case .qqmusic: model.qqArtistResults
        case .kugou: model.kugouArtistResults
        case .appleMusic: model.appleMusicArtistResults
        case .qishui, .local: []
        }
    }

    private var playlists: [Playlist] {
        switch model.selectedPlatform {
        case .netease: model.neteasePlaylistResults
        case .qqmusic: model.qqPlaylistResults
        case .kugou: model.kugouPlaylistResults
        case .appleMusic: model.appleMusicPlaylistResults
        case .qishui, .local: []
        }
    }

    private var albums: [SearchAlbum] {
        switch model.selectedPlatform {
        case .netease: model.neteaseAlbumResults
        case .qqmusic: model.qqAlbumResults
        case .kugou: model.kugouAlbumResults
        case .appleMusic: model.appleMusicAlbumResults
        case .qishui, .local: []
        }
    }

    private var selectedCount: Int {
        switch model.currentTab {
        case .songs: return songs.count
        case .artists: return artists.count
        case .playlists: return playlists.count
        case .albums: return albums.count
        case .mvs:
            if model.selectedPlatform == .netease { return model.neteaseMVResults.count }
            if model.selectedPlatform == .qqmusic { return model.qqMVResults.count }
            if model.selectedPlatform == .kugou { return model.kugouMVResults.count }
            return 0
        }
    }
}
