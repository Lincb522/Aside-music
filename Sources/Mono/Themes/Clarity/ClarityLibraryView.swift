import SwiftUI

struct ClarityLibraryView: View {
    @StateObject private var model = LibraryViewModel()
    @State private var tab: LibraryViewModel.LibraryTab = .my

    var body: some View {
        NavigationStack(path: $model.navigationPath) {
            GeometryReader { viewport in
                let artworkSize = libraryArtworkSize(for: viewport.size.width)

                ZStack {
                    ClarityBackdrop()
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            header
                            tabPicker
                            if tab != .my { sourcePicker }
                            bodyContent(artworkSize: artworkSize)
                            FloatingBarBottomSpacer()
                        }
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DeviceLayout.headerTopPadding + 8)
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable { reload(force: true) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryViewModel.NavigationDestination.self) { destination in
                switch destination {
                case .playlist, .localPlaylist:
                    destinationView(destination).clarityDetailChrome(preservesImmersiveBackdrop: true)
                default:
                    destinationView(destination).clarityDetailChrome()
                }
            }
        }
        .onChange(of: tab) { _, value in
            model.currentTab = value
            reload(force: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibrarySquare"))) { notification in
            if let source = notification.object as? LibraryViewModel.MusicSource {
                model.squareSource = source
            }
            tab = .square
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibraryArtists"))) { _ in
            tab = .artists
        }
    }

    private var header: some View {
        HStack {
            Text(String(localized: "tabbar_library"))
                .font(ClarityStyle.title(23, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
            Spacer()
            NavigationLink(value: LibraryViewModel.NavigationDestination.externalPlaylistImport) {
                MonoIcon(icon: .add, size: 18, color: ClarityStyle.ink, lineWidth: 1.7)
                    .frame(width: 44, height: 44)
                    .background(ClarityMembrane(shape: Circle(), strength: .regular))
            }
            .buttonStyle(ClarityPressStyle())
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .monoPageHeaderCollapse()
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(LibraryViewModel.LibraryTab.allCases, id: \.rawValue) { item in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) { tab = item }
                } label: {
                    Text(item.localizedKey)
                        .font(ClarityStyle.body(11.5, weight: tab == item ? .bold : .medium))
                        .foregroundStyle(tab == item ? ClarityStyle.onSelection : ClarityStyle.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if tab == item {
                                ClaritySelectionLens(shape: Capsule())
                                    .matchedGeometryEffect(id: "clarity-library-tab", in: tabNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(ClarityMembrane(shape: Capsule(), strength: .regular))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    @Namespace private var tabNamespace

    private var sourcePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(LibraryViewModel.MusicSource.allCases, id: \.rawValue) { source in
                    Button {
                        switch tab {
                        case .square: model.squareSource = source
                        case .artists: model.artistSource = source
                        case .charts: model.chartsSource = source
                        case .my: break
                        }
                        reload(force: false)
                    } label: {
                        Text(source.shortName)
                            .font(ClarityStyle.body(11, weight: .semibold))
                            .foregroundStyle(activeSource == source ? ClarityStyle.ink : ClarityStyle.inkFaint)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(ClarityMembrane(shape: Capsule(), strength: activeSource == source ? .regular : .quiet, selected: activeSource == source))
                    }
                    .buttonStyle(ClarityPressStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func bodyContent(artworkSize: CGFloat) -> some View {
        switch tab {
        case .my: playlistGrid(myPlaylists, title: String(localized: "tab_library"), artworkSize: artworkSize)
        case .square: playlistGrid(squarePlaylists, title: String(localized: "lib_tab_playlists"), artworkSize: artworkSize)
        case .artists: artistsGrid
        case .charts: chartGrid(artworkSize: artworkSize)
        }
    }

    private func playlistGrid(_ playlists: [Playlist], title: String, artworkSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            ClaritySectionHeading(title: title)
            if playlists.isEmpty && model.isLoading {
                ProgressView().tint(ClarityStyle.accent).frame(maxWidth: .infinity).padding(.vertical, 80)
            } else if playlists.isEmpty {
                emptyState(icon: .musicNoteList, title: String(localized: "library_empty_playlists"))
            } else {
                LazyVGrid(columns: grid, spacing: 20) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            VStack(alignment: .leading, spacing: 9) {
                                ClarityArtwork(url: playlist.coverUrl, size: artworkSize, radius: 27)
                                Text(playlist.name)
                                    .font(ClarityStyle.body(13, weight: .semibold))
                                    .foregroundStyle(ClarityStyle.ink)
                                    .lineLimit(2)
                                HStack(spacing: 5) {
                                    Text(playlist.sourceShortName)
                                    if let count = playlist.trackCount { Text("· \(count)") }
                                }
                                .font(ClarityStyle.body(10.5, weight: .medium))
                                .foregroundStyle(ClarityStyle.inkFaint)
                            }
                        }
                        .buttonStyle(ClarityPressStyle())
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var artistsGrid: some View {
        VStack(alignment: .leading, spacing: 15) {
            ClaritySectionHeading(title: String(localized: "lib_tab_artists"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 16)], spacing: 21) {
                ForEach(displayedArtists, id: \.id) { artist in
                    NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                        VStack(spacing: 10) {
                            ClarityArtwork(url: artist.coverUrl, size: 96, radius: 48)
                            Text(artist.name)
                                .font(ClarityStyle.body(12.5, weight: .semibold))
                                .foregroundStyle(ClarityStyle.ink)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(ClarityPressStyle())
                }
            }
            if displayedArtists.isEmpty { emptyState(icon: .profile, title: String(localized: "library_empty_artists")) }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func chartGrid(artworkSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            ClaritySectionHeading(title: String(localized: "lib_tab_charts"))
            LazyVGrid(columns: grid, spacing: 20) {
                ForEach(model.displayedTopLists) { chart in
                    let playlist = Playlist(
                        id: chart.id,
                        name: chart.name,
                        coverImgUrl: chart.coverImgUrl,
                        picUrl: nil,
                        trackCount: nil,
                        playCount: nil,
                        subscribedCount: nil,
                        shareCount: nil,
                        commentCount: nil,
                        creator: nil,
                        description: chart.updateFrequency,
                        tags: nil,
                        source: chart.source,
                        isTopList: true,
                        kugouID: chart.kugouID
                    )
                    NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                        VStack(alignment: .leading, spacing: 9) {
                            ClarityArtwork(url: chart.coverUrl, size: artworkSize, radius: 27)
                            Text(chart.name).font(ClarityStyle.body(13, weight: .semibold)).foregroundStyle(ClarityStyle.ink).lineLimit(1)
                            Text(chart.updateFrequency).font(ClarityStyle.body(10.5)).foregroundStyle(ClarityStyle.inkFaint).lineLimit(1)
                        }
                    }
                    .buttonStyle(ClarityPressStyle())
                }
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func emptyState(icon: MonoIcon.IconType, title: String) -> some View {
        VStack(spacing: 12) {
            MonoIcon(icon: icon, size: 24, color: ClarityStyle.inkFaint, lineWidth: 1.5)
                .frame(width: 58, height: 58)
                .background(ClarityMembrane(shape: Circle(), strength: .regular))
            Text(title).font(ClarityStyle.body(13, weight: .medium)).foregroundStyle(ClarityStyle.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 74)
    }

    private var grid: [GridItem] {
        [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]
    }

    private func libraryArtworkSize(for viewportWidth: CGFloat) -> CGFloat {
        let boundedWidth = min(max(viewportWidth, 320), 720)
        let available = boundedWidth - DeviceLayout.homeHorizontalPadding * 2 - 15
        return max(120, floor(available / 2))
    }

    private var myPlaylists: [Playlist] {
        model.userPlaylists + model.kugouUserPlaylists
    }

    private var squarePlaylists: [Playlist] {
        switch model.squareSource {
        case .ncm: model.squarePlaylists
        case .qq: model.qqSquarePlaylists
        case .kugou: model.kugouSquarePlaylists
        case .appleMusic: model.appleMusicSquarePlaylists
        }
    }

    private var displayedArtists: [ArtistInfo] {
        switch model.artistSource {
        case .ncm: model.topArtists
        case .qq: model.qqArtists
        case .kugou: model.kugouArtists
        case .appleMusic: model.appleMusicArtists
        }
    }

    private var activeSource: LibraryViewModel.MusicSource {
        switch tab {
        case .square: model.squareSource
        case .artists: model.artistSource
        case .charts: model.chartsSource
        case .my: .ncm
        }
    }

    private func reload(force: Bool) {
        switch tab {
        case .my: model.fetchPlaylists(force: force)
        case .square: model.fetchSquareForSelectedSource()
        case .artists: model.fetchArtistsForSelectedSource(reset: force)
        case .charts: model.fetchChartsForSelectedSource()
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: LibraryViewModel.NavigationDestination) -> some View {
        switch destination {
        case let .playlist(playlist): PlaylistDetailView(playlist: playlist)
        case let .artist(id): ArtistDetailView(artistId: id)
        case let .artistInfo(artist): ArtistDetailView(artist: artist)
        case let .qqArtist(mid, name, cover): QQMusicDetailView(detailType: .artist(mid: mid, name: name, coverUrl: cover))
        case let .radioDetail(id): RadioDetailView(radioId: id)
        case let .localPlaylist(id): LocalPlaylistDetailView(playlistId: id)
        case .externalPlaylistImport: ExternalPlaylistImportView()
        }
    }
}
