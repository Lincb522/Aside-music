import SwiftUI
import UniformTypeIdentifiers

/// 本地歌单详情页
struct LocalPlaylistDetailView: View {
    let playlistId: String

    @ObservedObject private var manager = LocalPlaylistManager.shared
    @ObservedObject private var localLibrary = LocalMusicLibraryManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss

    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var exportDocument: JSONFileDocument?
    @State private var exportFileName = ""
    @State private var showExportSheet = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var showLocalMusicImporter = false
    @State private var isImportingLocalMusic = false
    @State private var playlistSongs: [Song] = []
    @State private var filteredPlaylistSongs: [Song] = []
    @State private var playlistSummary: LocalPlaylistSummary?
    @State private var scrollOffset: CGFloat = 0
    @State private var showPlaylistDesc = false

    /// aside(默认)主题使用歌手页风格的沉浸式头图
    private var usesAsideHero: Bool {
        !MangaStyle.isActive && !PetWhiteStyle.isActive && !MujiStyle.isActive
            && !NeumorphicStyle.isActive && !SignalStyle.isActive
            && !SequoiaStyle.isActive && !CapsuleStyle.isActive
    }

    private var playlist: LocalPlaylist? {
        manager.playlists.first { $0.id == playlistId }
    }

    private var canRemoveSongsFromCurrentPlaylist: Bool {
        guard let playlist else { return false }
        return playlist.isFavorite || playlist.isLocalMusic || !playlist.isSystem
    }

    private var canImportLocalMusicIntoCurrentPlaylist: Bool {
        guard let playlist else { return false }
        return !playlist.isDownload
    }

    private var playlistCoverUrl: URL? {
        playlistSummary?.displayCoverUrl
    }

    private var playlistTrackCount: Int {
        playlistSummary?.trackCount ?? playlistSongs.count
    }

    private var selectedPlaylistSongs: [Song] {
        playlistSongs.filter { selectedSongIds.contains($0.id) }
    }

    typealias Theme = PlaylistDetailView.Theme

    private var petWhiteDetailHorizontalPadding: CGFloat {
        DeviceLayout.isPad ? 8 : 4
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if PetWhiteStyle.isActive {
                PetWhiteRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
        } else if NeumorphicStyle.isActive {
            ThemeRenderBackdrop(theme: .neumorphic)
        } else if SignalStyle.isActive {
            ThemeRenderBackdrop(theme: .default)
        } else if SequoiaStyle.isActive {
            SequoiaRootBackdrop()
        } else if CapsuleStyle.isActive {
            CapsuleRootBackdrop()
        } else if SettingsManager.shared.coverBgPlaylist {
            PlaylistColorBackground(coverUrl: playlistCoverUrl?.sized(200))
        } else {
                ThemedPageBackground()
            }

            ScrollView {
                localPlaylistScrollableContent(includeHeader: true)
            }
            .scrollIndicators(.hidden)
            .monoScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: usesAsideHero ? .top : [])
            .themeRenderScrollLayer()
            .refreshable {
                _ = try? await LocalPlaylistCloudSyncManager.shared.refreshAndSync()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canImportLocalMusicIntoCurrentPlaylist {
                    Button {
                        showLocalMusicImporter = true
                    } label: {
                        if isImportingLocalMusic || localLibrary.isProcessing {
                            ProgressView()
                                .scaleEffect(0.72)
                        } else {
                            MonoIcon(icon: .download, size: 16, color: .monoTextPrimary)
                        }
                    }
                    .disabled(isImportingLocalMusic || localLibrary.isProcessing)
                }

                if playlist != nil {
                    toolbarTrackCountView(playlistTrackCount)
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
        .fileExporter(
            isPresented: $showExportSheet,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName
        ) { result in
            if case .failure(let error) = result {
                AlertManager.shared.show(
                    title: String(localized: "local_playlist_export_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
        .fileImporter(
            isPresented: $showLocalMusicImporter,
            allowedContentTypes: LocalMusicLibraryManager.importableContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleLocalMusicImport(result)
        }
        .onAppear {
            refreshPlaylistSnapshot()
            Task {
                await LocalPlaylistCloudSyncManager.shared.refreshFromCloudIfNeeded()
            }
        }
        .onChange(of: manager.revision) { _, _ in
            refreshPlaylistSnapshot()
        }
        .onChange(of: searchText) { _, _ in
            refreshFilteredPlaylistSongs()
        }
    }

    private func localPlaylistScrollableContent(includeHeader: Bool) -> some View {
        VStack(spacing: 0) {
            if includeHeader {
                if usesAsideHero {
                    headerView
                } else {
                    headerView
                        .monoPageHeaderCollapse()
                }
            }

            PlaylistSearchBar(
                searchText: $searchText,
                isSearching: $isSearching,
                isSelectMode: $isSelectMode,
                selectedIds: $selectedSongIds,
                songs: filteredPlaylistSongs,
                onBatchQueue: {
                    SongBatchActionHelper.addToQueue(selectedPlaylistSongs) {
                        isSelectMode = false
                        selectedSongIds.removeAll()
                    }
                },
                onBatchDownload: { batchDownloadSelected() },
                onBatchCollect: playlist?.isFavorite == true ? nil : { showBatchAddToPlaylist = true },
                onBatchRemove: canRemoveSongsFromCurrentPlaylist ? { batchRemoveSelected() } : nil
            )

            if let progress = localLibrary.importProgress {
                LocalImportProgressPanel(progress: progress)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .padding(.bottom, 10)
            }

            songListSection
                .padding(.bottom, 100)
        }
    }

    private func refreshPlaylistSnapshot() {
        guard let playlist else {
            playlistSongs = []
            filteredPlaylistSongs = []
            playlistSummary = nil
            selectedSongIds.removeAll()
            return
        }

        let songs = manager.songs(for: playlist)
        playlistSongs = songs
        playlistSummary = manager.summary(for: playlist)
        selectedSongIds = selectedSongIds.intersection(Set(songs.map(\.id)))
        refreshFilteredPlaylistSongs()
    }

    private func refreshFilteredPlaylistSongs() {
        filteredPlaylistSongs = playlistSongs.filtered(by: searchText)
    }

    // MARK: - 导出

    private func exportPlaylist(_ playlist: LocalPlaylist) {
        do {
            let payload = try manager.exportPlaylist(playlist)
            exportDocument = JSONFileDocument(data: payload.data)
            exportFileName = payload.suggestedFileName
            showExportSheet = true
        } catch {
            AlertManager.shared.show(
                title: String(localized: "local_playlist_export_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
        }
    }

    private func handleLocalMusicImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                await importLocalMusicIntoCurrentPlaylist(from: urls)
            }
        case .failure(let error):
            AlertManager.shared.show(
                title: String(localized: "local_import_failed_title"),
                message: error.localizedDescription,
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
        }
    }

    @MainActor
    private func importLocalMusicIntoCurrentPlaylist(from urls: [URL]) async {
        guard canImportLocalMusicIntoCurrentPlaylist else { return }
        let targetId = playlistId
        let playlistName = playlist?.name ?? ""

        isImportingLocalMusic = true
        let result = await localLibrary.importItems(from: urls)

        let addedCount = manager.playlists.first(where: { $0.id == targetId }).map {
            manager.addSongs(result.importedSongs, to: $0)
        } ?? 0

        isImportingLocalMusic = false
        AppLogger.info("[LocalMusicImport] playlist=\(playlistName) added=\(addedCount) \(result.summaryText)")
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        if MangaStyle.isActive {
            mangaHeaderView
        } else if PetWhiteStyle.isActive {
            petWhiteHeaderView
        } else if MujiStyle.isActive {
            mujiHeaderView
        } else if NeumorphicStyle.isActive {
            neumorphicHeaderView
        } else if SignalStyle.isActive {
            signalHeaderView
        } else if SequoiaStyle.isActive {
            sequoiaHeaderView
        } else if CapsuleStyle.isActive {
            capsuleHeaderView
        } else if let p = playlist {
            AsideDetailHeroHeader(
                coverUrl: playlistCoverUrl?.sized(800),
                placeholderImageName: "LocalPlaylistPlaceholder",
                title: p.name,
                metaItems: [
                    String(localized: "local_playlist_label"),
                    "\(playlistTrackCount) \(String(localized: "songs_unit"))",
                ],
                descriptionText: p.desc,
                onDescriptionTap: (p.desc?.isEmpty ?? true) ? nil : { showPlaylistDesc = true },
                scrollOffset: scrollOffset,
                heroHeight: 320,
                playAllDisabled: playlistSongs.isEmpty,
                onPlayAll: {
                    let songs = playlistSongs
                    if let first = songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: songs)
                    }
                }
            ) {
                if !p.isSystem {
                    Button(action: {
                        AlertManager.shared.showInput(
                            title: NSLocalizedString("local_playlist_rename", comment: ""),
                            message: "",
                            placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                            primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                            secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                            onConfirm: { name in
                                if !name.isEmpty {
                                    manager.renamePlaylist(p, name: name)
                                }
                            }
                        )
                        AlertManager.shared.inputText = p.name
                    }) {
                        MonoIcon(icon: .settings, size: 15, color: Theme.secondaryText)
                            .frame(width: 40, height: 40)
                            .background(Color.monoGlassTint)
                            .cornerRadius(20)
                            .monoGlass(cornerRadius: 20)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                }

                Button(action: { exportPlaylist(p) }) {
                    MonoIcon(icon: .download, size: 15, color: Theme.secondaryText)
                        .frame(width: 40, height: 40)
                        .background(Color.monoGlassTint)
                        .cornerRadius(20)
                        .monoGlass(cornerRadius: 20)
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                if !p.isSystem {
                    Button(action: {
                        AlertManager.shared.show(
                            title: NSLocalizedString("local_playlist_delete", comment: ""),
                            message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                            primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                            secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                            primaryAction: {
                                manager.deletePlaylist(p)
                                dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                            }
                        )
                    }) {
                        MonoIcon(icon: .trash, size: 15, color: Theme.secondaryText)
                            .frame(width: 40, height: 40)
                            .background(Color.monoGlassTint)
                            .cornerRadius(20)
                            .monoGlass(cornerRadius: 20)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                }
            }
            .padding(.bottom, DeviceLayout.isPad ? 20 : 12)
            .iPadContentWidth(900)
        }
    }

    private var sequoiaHeaderView: some View {
        VStack(alignment: .leading, spacing: 15) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 15) {
                    Group {
                        if let url = playlistCoverUrl {
                            CachedAsyncImage(url: url.sized(500)) {
                                sequoiaCoverPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            sequoiaCoverPlaceholder
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 168 : 126, height: DeviceLayout.isPad ? 168 : 126)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(SequoiaStyle.luminousSeparator.opacity(0.56), lineWidth: 0.7)
                    )
                    .background(SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            SequoiaPill(text: String(localized: "local_playlist_label"), icon: .musicNoteList, tint: SequoiaStyle.green, selected: true, compact: true)
                            SequoiaPill(text: "\(playlistTrackCount) \(String(localized: "songs_unit"))", tint: SequoiaStyle.aqua, compact: true)
                        }

                        Text(p.name)
                            .font(SequoiaStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold))
                            .foregroundStyle(SequoiaStyle.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(SequoiaStyle.labelFont(12, weight: .regular))
                                .foregroundStyle(SequoiaStyle.inkSoft)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SequoiaMeter(tint: p.isFavorite ? SequoiaStyle.red : SequoiaStyle.green, count: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        HStack(spacing: 7) {
                            MonoIcon(icon: .play, size: 13, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                            Text(LocalizedStringKey("play_now"))
                                .font(SequoiaStyle.labelFont(12, weight: .semibold))
                        }
                        .foregroundStyle(SequoiaStyle.onAccent)
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .background(SequoiaStyle.accentGradient, in: Capsule())
                        .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .opacity(playlistSongs.isEmpty ? 0.55 : 1)
                    .disabled(playlistSongs.isEmpty)

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: NSLocalizedString("local_playlist_rename", comment: ""),
                                message: "",
                                placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                                primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                onConfirm: { name in
                                    if !name.isEmpty {
                                        manager.renamePlaylist(p, name: name)
                                    }
                                }
                            )
                            AlertManager.shared.inputText = p.name
                        }) {
                            sequoiaHeaderIconButton(icon: .settings, tint: SequoiaStyle.accent)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        sequoiaHeaderIconButton(icon: .download, tint: SequoiaStyle.aqua)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                                }
                            )
                        }) {
                            sequoiaHeaderIconButton(icon: .trash, tint: SequoiaStyle.red)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }
                }
            }
        }
        .padding(16)
        .background(SequoiaGlassBand(tint: SequoiaStyle.green, cornerRadius: 26))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var petWhiteHeaderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if let url = playlistCoverUrl {
                            CachedAsyncImage(url: url.sized(400)) {
                                LocalPlaylistPlaceholderArtwork()
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            LocalPlaylistPlaceholderArtwork()
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 168 : 124, height: DeviceLayout.isPad ? 168 : 124)
                    .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous))
                    .petWhiteClayShadow()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(String(localized: "local_playlist_label").uppercased())
                                .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(PetWhiteStyle.dogEar)

                            Text("· \(playlistTrackCount) \(String(localized: "songs_unit"))")
                                .font(PetWhiteStyle.labelFont(11))
                                .foregroundStyle(PetWhiteStyle.inkMuted)
                        }
                        .lineLimit(1)

                        Text(p.name)
                            .font(PetWhiteStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .bold))
                            .foregroundStyle(PetWhiteStyle.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(PetWhiteStyle.labelFont(12))
                                .foregroundStyle(PetWhiteStyle.inkSoft)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        petWhiteLocalAction(title: String(localized: "play_now"), icon: .play, tint: PetWhiteStyle.dogOrange, filled: true)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .disabled(playlistSongs.isEmpty)
                    .opacity(playlistSongs.isEmpty ? 0.55 : 1)

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: NSLocalizedString("local_playlist_rename", comment: ""),
                                message: "",
                                placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                                primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                onConfirm: { name in
                                    if !name.isEmpty {
                                        manager.renamePlaylist(p, name: name)
                                    }
                                }
                            )
                            AlertManager.shared.inputText = p.name
                        }) {
                            petWhiteLocalIconAction(icon: .settings, tint: PetWhiteStyle.sky)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        petWhiteLocalIconAction(icon: .download, tint: PetWhiteStyle.mint)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                                }
                            )
                        }) {
                            petWhiteLocalIconAction(icon: .trash, tint: PetWhiteStyle.blush)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }
                }
            }
        }
        .padding(16)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        .padding(.horizontal, petWhiteDetailHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
        .padding(.bottom, 14)
        .iPadContentWidth(1280)
    }

    private func petWhiteLocalAction(title: String, icon: MonoIcon.IconType, tint: Color, filled: Bool) -> some View {
        HStack(spacing: 7) {
            PetWhitePackIcon(icon: icon, size: 14, visualScale: 1.05, fallbackColor: filled ? PetWhiteStyle.onAccent : PetWhiteStyle.ink)
            Text(title)
                .font(PetWhiteStyle.labelFont(12, weight: .black))
        }
        .foregroundStyle(filled ? PetWhiteStyle.onAccent : PetWhiteStyle.ink)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(filled ? tint : PetWhiteStyle.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: PetWhiteStyle.fineStrokeWidth))
    }

    private func petWhiteLocalIconAction(icon: MonoIcon.IconType, tint: Color) -> some View {
        PetWhitePackIcon(icon: icon, size: 15, visualScale: 1.05, fallbackColor: PetWhiteStyle.ink)
            .frame(width: 38, height: 38)
            .background(PetWhiteSurfaceBackground(cornerRadius: 15, elevated: false, tint: tint.opacity(0.20), accent: tint))
    }

    private var mangaHeaderView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 14) {
                    Group {
                        if let url = playlistCoverUrl {
                            CachedAsyncImage(url: url.sized(500)) {
                                mangaCoverPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            mangaCoverPlaceholder
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 170 : 124, height: DeviceLayout.isPad ? 170 : 124)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                    .background(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 3, y: 3))
                    .rotationEffect(.degrees(-1.1))

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 22, foreground: MangaStyle.ink)
                            MangaLabel(text: String(localized: "local_playlist_label"), tint: MangaStyle.labelYellow, small: true)
                        }

                        MangaMisprintTitle(text: p.name, size: DeviceLayout.isPad ? 26 : 22)
                            .fixedSize(horizontal: false, vertical: true)

                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(MangaStyle.bodyFont(12, weight: .bold))
                                .foregroundStyle(MangaStyle.inkSub)
                                .lineLimit(2)
                        }

                        MangaLabel(text: "\(playlistTrackCount) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true, foreground: MangaStyle.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        HStack(spacing: 7) {
                            MonoIcon(icon: .play, size: 13, color: MangaStyle.onStrokeInk, lineWidth: 2)
                            Text(LocalizedStringKey("play_now"))
                                .font(MangaStyle.labelFont(12, weight: .black))
                                .tracking(0.6)
                        }
                        .foregroundStyle(MangaStyle.onStrokeInk)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MangaStyle.strokeInk))
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(MangaStyle.accentPink)
                                .offset(x: 2.5, y: 2.5)
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .opacity(playlistSongs.isEmpty ? 0.55 : 1)
                    .disabled(playlistSongs.isEmpty)

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: NSLocalizedString("local_playlist_rename", comment: ""),
                                message: "",
                                placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                                primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                onConfirm: { name in
                                    if !name.isEmpty {
                                        manager.renamePlaylist(p, name: name)
                                    }
                                }
                            )
                            AlertManager.shared.inputText = p.name
                        }) {
                            mangaHeaderIconButton(icon: .settings, tint: MangaStyle.bubbleBlue)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        mangaHeaderIconButton(icon: .download, tint: MangaStyle.mint)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                                }
                            )
                        }) {
                            mangaHeaderIconButton(icon: .trash, tint: MangaStyle.bubblePink)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }
                }
            }
        }
        .padding(16)
        .background(
            // 本地歌单详情页唯一焦点分格：保留厚墨框错版投影
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite, poster: true)
        )
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var mangaCoverPlaceholder: some View {
        LocalPlaylistPlaceholderArtwork()
    }

    private func mangaHeaderIconButton(icon: MonoIcon.IconType, tint: Color) -> some View {
        MonoIcon(icon: icon, size: 14, color: MangaStyle.ink, lineWidth: 1.8)
            .frame(width: 36, height: 36)
            .background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
            .background(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
    }

    private var neumorphicHeaderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if let url = playlistCoverUrl {
                            CachedAsyncImage(url: url.sized(500)) {
                                neumorphicCoverPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            neumorphicCoverPlaceholder
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 172 : 128, height: DeviceLayout.isPad ? 172 : 128)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 7) {
                            NeumorphicPill(text: String(localized: "local_playlist_label"), tint: NeumorphicStyle.accent, selected: true, compact: true)
                            NeumorphicPill(text: "\(playlistTrackCount) \(String(localized: "songs_unit"))", tint: NeumorphicStyle.sage, compact: true)
                        }

                        Text(p.name)
                            .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(NeumorphicStyle.labelFont(12, weight: .medium))
                                .foregroundStyle(NeumorphicStyle.inkSoft)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        NeumorphicPlayPill(title: String(localized: "play_now"), tint: NeumorphicStyle.accent)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .opacity(playlistSongs.isEmpty ? 0.55 : 1)
                    .disabled(playlistSongs.isEmpty)

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: NSLocalizedString("local_playlist_rename", comment: ""),
                                message: "",
                                placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                                primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                onConfirm: { name in
                                    if !name.isEmpty {
                                        manager.renamePlaylist(p, name: name)
                                    }
                                }
                            )
                            AlertManager.shared.inputText = p.name
                        }) {
                            neumorphicHeaderIconButton(icon: .settings, tint: NeumorphicStyle.sage)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        neumorphicHeaderIconButton(icon: .download, tint: NeumorphicStyle.warm)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                                }
                            )
                        }) {
                            neumorphicHeaderIconButton(icon: .trash, tint: NeumorphicStyle.red)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }
                }
            }
        }
        .padding(17)
        .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var neumorphicCoverPlaceholder: some View {
        LocalPlaylistPlaceholderArtwork()
    }

    private func neumorphicHeaderIconButton(icon: MonoIcon.IconType, tint: Color) -> some View {
        MonoIcon(icon: icon, size: 14, color: tint, lineWidth: 1.55)
            .frame(width: 38, height: 38)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 14,
                    elevated: true,
                    tint: tint.opacity(0.12)
                )
            )
    }

    private var signalHeaderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if let url = playlistCoverUrl {
                            CachedAsyncImage(url: url.sized(500)) {
                                signalCoverPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            signalCoverPlaceholder
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 172 : 128, height: DeviceLayout.isPad ? 172 : 128)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .background(SignalSurfaceBackground(cornerRadius: 26, elevated: true, fill: SignalStyle.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(SignalStyle.separator.opacity(0.7), lineWidth: 0.8)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 7) {
                            SignalPill(text: String(localized: "local_playlist_label"), tint: SignalStyle.accent, selected: true, compact: true)
                            SignalPill(text: "\(playlistTrackCount) \(String(localized: "songs_unit"))", tint: SignalStyle.olive, compact: true)
                        }

                        Text(p.name)
                            .font(SignalStyle.titleFont(DeviceLayout.isPad ? 28 : 24, weight: .bold))
                            .foregroundStyle(SignalStyle.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(SignalStyle.labelFont(12, weight: .medium))
                                .foregroundStyle(SignalStyle.inkSoft)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        SignalPlayPill(title: String(localized: "play_now"))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .opacity(playlistSongs.isEmpty ? 0.55 : 1)
                    .disabled(playlistSongs.isEmpty)

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: NSLocalizedString("local_playlist_rename", comment: ""),
                                message: "",
                                placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                                primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                onConfirm: { name in
                                    if !name.isEmpty {
                                        manager.renamePlaylist(p, name: name)
                                    }
                                }
                            )
                            AlertManager.shared.inputText = p.name
                        }) {
                            signalHeaderIconButton(icon: .settings, tint: SignalStyle.olive)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        signalHeaderIconButton(icon: .download, tint: SignalStyle.amber)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                                }
                            )
                        }) {
                            signalHeaderIconButton(icon: .trash, tint: SignalStyle.rust)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }
                }
            }
        }
        .padding(17)
        .background(SignalSurfaceBackground(cornerRadius: 30, elevated: true, fill: SignalStyle.paper))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var signalCoverPlaceholder: some View {
        LocalPlaylistPlaceholderArtwork()
    }

    private func signalHeaderIconButton(icon: MonoIcon.IconType, tint: Color) -> some View {
        MonoIcon(icon: icon, size: 14, color: tint, lineWidth: 1.55)
            .frame(width: 38, height: 38)
            .background(SignalSurfaceBackground(cornerRadius: 14, elevated: true, fill: tint.opacity(0.12)))
    }

    /// Muji：杂志特辑页 —— 眉题行 + 跨页封面 + 衬线标题 + 图注简介
    private var mujiHeaderView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let p = playlist {
                HStack(alignment: .center, spacing: 8) {
                    MujiDotMark()

                    Text(String(localized: "local_playlist_label").uppercased())
                        .font(MujiStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(MujiStyle.clay)
                        .tracking(2.2)
                        .fixedSize()

                    Spacer(minLength: 8)

                    Text("\(playlistTrackCount) \(String(localized: "songs_unit"))")
                        .font(MujiStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(MujiStyle.inkMuted)
                        .tracking(1.1)
                        .fixedSize()
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                Group {
                    if let url = playlistCoverUrl {
                        CachedAsyncImage(url: url.sized(800)) {
                            mujiCoverPlaceholder
                        }
                        .aspectRatio(contentMode: .fill)
                    } else {
                        mujiCoverPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: DeviceLayout.isPad ? 300 : 216)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: MujiStyle.ink.opacity(0.08), radius: 12, x: 0, y: 6)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text(p.name)
                        .font(MujiStyle.titleFont(DeviceLayout.isPad ? 30 : 26, weight: .regular))
                        .foregroundStyle(MujiStyle.ink)
                        .lineSpacing(4)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = p.desc, !desc.isEmpty {
                        HStack(alignment: .top, spacing: 11) {
                            Rectangle()
                                .fill(MujiStyle.clay.opacity(0.8))
                                .frame(width: 2)
                                .padding(.vertical, 2)

                            Text(desc)
                                .font(MujiStyle.bodyFont(12.5, weight: .regular))
                                .foregroundStyle(MujiStyle.inkSoft)
                                .lineSpacing(4)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 16)

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        MujiActionPill(title: String(localized: "play_now"), icon: .play, selected: true, tint: MujiStyle.clay)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .opacity(playlistSongs.isEmpty ? 0.55 : 1)
                    .disabled(playlistSongs.isEmpty)

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: NSLocalizedString("local_playlist_rename", comment: ""),
                                message: "",
                                placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                                primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                onConfirm: { name in
                                    if !name.isEmpty {
                                        manager.renamePlaylist(p, name: name)
                                    }
                                }
                            )
                            AlertManager.shared.inputText = p.name
                        }) {
                            mujiHeaderIconButton(icon: .settings, tint: MujiStyle.indigo)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        mujiHeaderIconButton(icon: .download, tint: MujiStyle.tea)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                                }
                            )
                        }) {
                            mujiHeaderIconButton(icon: .trash, tint: MujiStyle.red)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                MujiListDivider()
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 18)
            }
        }
        .padding(.top, DeviceLayout.isPad ? 24 : 14)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var mujiCoverPlaceholder: some View {
        LocalPlaylistPlaceholderArtwork()
    }

    /// 动作图标：发丝细圈，与杂志语言一致
    private func mujiHeaderIconButton(icon: MonoIcon.IconType, tint: Color) -> some View {
        MonoIcon(icon: icon, size: 14, color: tint, lineWidth: 1.5)
            .frame(width: 36, height: 36)
            .overlay(
                Circle()
                    .stroke(MujiStyle.hairline.opacity(0.72), lineWidth: 0.8)
            )
            .contentShape(Circle())
    }

    @ViewBuilder
    private var capsuleHeaderView: some View {
        if let p = playlist {
            CapsuleDetailHeader(
                eyebrow: String(localized: "local_playlist_label"),
                title: p.name,
                subtitle: p.desc ?? "",
                coverURL: playlistCoverUrl?.sized(500),
                fallbackImageName: "LocalPlaylistPlaceholder",
                fallbackIcon: .musicNoteList,
                tint: CapsuleStyle.accent,
                chips: ["\(playlistTrackCount) \(String(localized: "songs_unit"))", p.isSystem ? "SYSTEM" : "LOCAL"]
            ) {
                HStack(spacing: 9) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        CapsuleDetailActionPill(
                            title: String(localized: "play_now"),
                            icon: .play,
                            tint: CapsuleStyle.accent
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                    .opacity(playlistSongs.isEmpty ? 0.55 : 1)
                    .disabled(playlistSongs.isEmpty)

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: NSLocalizedString("local_playlist_rename", comment: ""),
                                message: "",
                                placeholder: NSLocalizedString("local_playlist_name", comment: ""),
                                primaryButtonTitle: NSLocalizedString("confirm", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                onConfirm: { name in
                                    if !name.isEmpty {
                                        manager.renamePlaylist(p, name: name)
                                    }
                                }
                            )
                            AlertManager.shared.inputText = p.name
                        }) {
                            CapsuleDetailIconButton(icon: .settings, tint: CapsuleStyle.mint)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        CapsuleDetailIconButton(icon: .download, tint: CapsuleStyle.cyan)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
                                }
                            )
                        }) {
                            CapsuleDetailIconButton(icon: .trash, tint: CapsuleStyle.coral)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
                    }
                }
            }
        }
    }

    private var sequoiaCoverPlaceholder: some View {
        LocalPlaylistPlaceholderArtwork()
    }

    private func sequoiaHeaderIconButton(icon: MonoIcon.IconType, tint: Color) -> some View {
        SequoiaControlButton(icon: icon, tint: tint, size: 38)
    }

    private func toolbarTrackCountView(_ count: Int) -> some View {
        Group {
            if MangaStyle.isActive {
                MangaLabel(text: "\(count) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true, foreground: MangaStyle.ink)
            } else if MujiStyle.isActive {
                MujiPill(text: "\(count) \(String(localized: "songs_unit"))", tint: MujiStyle.tea)
            } else if NeumorphicStyle.isActive {
                NeumorphicPill(text: "\(count)", tint: NeumorphicStyle.sage, icon: .musicNoteList, compact: true)
            } else if SignalStyle.isActive {
                SignalPill(text: "\(count)", tint: SignalStyle.olive, icon: .musicNoteList, compact: true)
            } else if SequoiaStyle.isActive {
                SequoiaPill(text: "\(count)", icon: .musicNoteList, tint: SequoiaStyle.green, compact: true)
            } else if CapsuleStyle.isActive {
                CapsuleDetailChip(text: "\(count)", icon: .musicNoteList, tint: CapsuleStyle.accent)
            } else {
                HStack(spacing: 4) {
                    MonoIcon(icon: .musicNoteList, size: 10, color: .monoTextSecondary.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .background(Color.monoTextPrimary.opacity(0.08))
                        .clipShape(Capsule())

                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.monoTextPrimary)

                    Text(LocalizedStringKey("songs_unit"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.monoTextPrimary.opacity(0.06))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Song List

    private var songListSection: some View {
        Group {
            if CapsuleStyle.isActive {
                capsuleLocalSongListSection
            } else if PetWhiteStyle.isActive {
                petWhiteLocalSongListSection
            } else {
                defaultLocalSongListSection
            }
        }
        .monoSheet(isPresented: $showBatchAddToPlaylist, preset: .standard) {
            let selected = selectedPlaylistSongs
            BatchAddToPlaylistSheet(songs: selected)
        }
        .monoSheet(isPresented: $showPlaylistDesc, preset: .standard) {
            PlaylistDescSheet(
                coverUrl: playlistCoverUrl?.sized(200),
                title: playlist?.name ?? "",
                subtitle: String(localized: "local_playlist_label"),
                descriptionText: playlist?.desc
            )
        }
    }

    private var petWhiteLocalSongListSection: some View {
        LazyVStack(spacing: 14) {
            if let currentPlaylist = playlist {
                let songs = playlistSongs
                let displaySongs = filteredPlaylistSongs
                VStack(alignment: .leading, spacing: 12) {
                    PetWhiteSectionTitle(
                        title: "LOCAL",
                        detail: String(format: NSLocalizedString("songs_count_format", comment: ""), displaySongs.count),
                        icon: .musicNoteList,
                        tint: PetWhiteStyle.mint
                    )

                    if songs.isEmpty {
                        localEmptyState
                            .padding(.top, 0)
                    } else {
                        localSongRows(playlist: currentPlaylist, songs: displaySongs)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
                .padding(.horizontal, petWhiteDetailHorizontalPadding)
            }

            FloatingBarBottomSpacer()
        }
    }

    private var capsuleLocalSongListSection: some View {
        LazyVStack(spacing: 14) {
            if let currentPlaylist = playlist {
                let songs = playlistSongs
                let displaySongs = filteredPlaylistSongs
                if songs.isEmpty {
                    CapsuleDetailSection(title: "LOCAL", icon: .musicNoteList, tint: CapsuleStyle.mint) {
                        CapsuleDetailEmptyState(title: "local_playlist_no_songs", icon: .musicNoteList, tint: CapsuleStyle.mint)
                    }
                } else {
                    CapsuleDetailSection(
                        title: "LOCAL",
                        subtitle: String(format: NSLocalizedString("songs_count_format", comment: ""), displaySongs.count),
                        icon: .musicNoteList,
                        tint: CapsuleStyle.mint
                    ) {
                        localSongRows(playlist: currentPlaylist, songs: displaySongs)
                    }
                }
            }

            FloatingBarBottomSpacer()
        }
    }

    private var defaultLocalSongListSection: some View {
        LazyVStack(spacing: 0) {
            if let currentPlaylist = playlist {
                let songs = playlistSongs
                let displaySongs = filteredPlaylistSongs
                if songs.isEmpty {
                    localEmptyState
                } else {
                    localSongRows(playlist: currentPlaylist, songs: displaySongs)
                }
            }

            FloatingBarBottomSpacer()
        }
    }

    private var localEmptyState: some View {
        VStack(spacing: 16) {
            if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .musicNoteList, tint: NeumorphicStyle.accent, size: 54)
            } else if SignalStyle.isActive {
                SignalIconBadge(icon: .musicNoteList, tint: SignalStyle.accent, size: 54)
            } else if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: .musicNoteList, tint: SequoiaStyle.green, size: 54)
            } else {
                MonoIcon(icon: .musicNoteList, size: 40, color: .monoTextSecondary.opacity(0.3))
            }

            Text(LocalizedStringKey("local_playlist_no_songs"))
                .font(SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .system(size: 14, weight: .medium, design: .rounded))))
                .foregroundColor(SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThemedPageStyle.isActive ? 34 : 0)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: 26, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome)
            }
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
        .padding(.top, 60)
    }

    private func localSongRows(playlist currentPlaylist: LocalPlaylist, songs displaySongs: [Song]) -> some View {
        ForEach(Array(displaySongs.enumerated()), id: \.element.id) { index, song in
            SongListRow(
                song: song,
                index: index,
                isSelecting: isSelectMode,
                isSelected: selectedSongIds.contains(song.id),
                onArtistTap: { artistId in
                    selectedArtistId = artistId
                    showArtistDetail = true
                },
                onDetailTap: { detailSong in
                    selectedSongForDetail = detailSong
                    showSongDetail = true
                },
                onAlbumTap: { albumId in
                    selectedAlbumId = albumId
                    showAlbumDetail = true
                },
                onTap: {
                    if isSelectMode {
                        if selectedSongIds.contains(song.id) {
                            selectedSongIds.remove(song.id)
                        } else {
                            selectedSongIds.insert(song.id)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: displaySongs)
                    }
                },
                horizontalPadding: PetWhiteStyle.isActive ? CGFloat(0) : nil
            )
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    withAnimation {
                        removeSongFromPlaylist(song, playlist: currentPlaylist)
                    }
                } label: {
                    Label(
                        NSLocalizedString(currentPlaylist.isLocalMusic ? "local_action_delete_local_song" : "local_playlist_remove", comment: ""),
                        systemImage: "trash"
                    )
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    withAnimation {
                        removeSongFromPlaylist(song, playlist: currentPlaylist)
                    }
                } label: {
                    Label(
                        NSLocalizedString(currentPlaylist.isLocalMusic ? "local_action_delete_local_song" : "local_playlist_remove", comment: ""),
                        systemImage: "trash"
                    )
                }
            }
        }
    }

    private func removeSongFromPlaylist(_ song: Song, playlist currentPlaylist: LocalPlaylist) {
        if currentPlaylist.isLocalMusic {
            if song.isLocal {
                localLibrary.deleteSong(song)
            } else {
                // 已下载歌曲：连同下载记录与文件一起删，否则同步时会被重新并回本地音乐
                manager.removeDownloadedSong(song)
            }
        } else if currentPlaylist.isFavorite {
            manager.removeFromFavorite(songId: song.id)
        } else {
            manager.removeSong(id: song.id, from: currentPlaylist)
        }
    }

    private func batchRemoveSelected() {
        guard canRemoveSongsFromCurrentPlaylist, let currentPlaylist = playlist else { return }
        let ids = selectedSongIds
        guard !ids.isEmpty else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            if currentPlaylist.isLocalMusic {
                let selected = selectedPlaylistSongs
                localLibrary.deleteSongs(selected)
                for song in selected where !song.isLocal {
                    manager.removeDownloadedSong(song)
                }
            } else {
                manager.removeSongs(ids: ids, from: currentPlaylist)
            }
            isSelectMode = false
            selectedSongIds.removeAll()
        }
    }

    private func batchDownloadSelected() {
        let selected = selectedPlaylistSongs
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "download_batch_added_title"), message: L10n.format("download_batch_queue_added_format", selected.count), primaryButtonTitle: String(localized: "common_confirm"), primaryAction: {})
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }
}
