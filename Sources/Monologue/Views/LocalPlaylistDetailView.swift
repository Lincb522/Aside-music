import SwiftUI
import UniformTypeIdentifiers

/// 本地歌单详情页
struct LocalPlaylistDetailView: View {
    let playlistId: String

    @ObservedObject private var manager = LocalPlaylistManager.shared
    @ObservedObject private var localLibrary = LocalMusicLibraryManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

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
            ThemeRenderBackdrop(theme: .signal)
        } else if SequoiaStyle.isActive {
            SequoiaRootBackdrop()
        } else if CapsuleStyle.isActive {
            CapsuleRootBackdrop()
        } else if SettingsManager.shared.coverBgPlaylist {
            PlaylistColorBackground(coverUrl: playlistCoverUrl?.sized(200))
        } else {
                ThemedPageBackground()
            }

            if ThemedPageStyle.isActive {
                ScrollView {
                    localPlaylistScrollableContent(includeHeader: true)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                .refreshable {
                    _ = try? await LocalPlaylistCloudSyncManager.shared.refreshAndSync()
                }
            } else {
                VStack(spacing: 0) {
                    headerView

                    ScrollView {
                        localPlaylistScrollableContent(includeHeader: false)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    .refreshable {
                        _ = try? await LocalPlaylistCloudSyncManager.shared.refreshAndSync()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                            MonologueIcon(icon: .download, size: 16, color: .monologueTextPrimary)
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
                headerView
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
        } else {
            VStack(alignment: .leading, spacing: 12) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if let url = playlistCoverUrl {
                            CachedAsyncImage(url: url.sized(400)) {
                                coverPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            coverPlaceholder
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 180 : 120, height: DeviceLayout.isPad ? 180 : 120)
                    .cornerRadius(DeviceLayout.isPad ? 20 : 16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(p.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.secondaryText)
                                .lineLimit(1)
                        }

                        Text(LocalizedStringKey("local_playlist_label"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText.opacity(0.6))

                        Spacer().frame(height: 4)

                        HStack(spacing: 8) {
                            Button(action: {
                                let songs = playlistSongs
                                if let first = songs.first {
                                    PlayerManager.shared.playReplacingContext(song: first, in: songs)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .play, size: 12, color: .monologueIconForeground)
                                    Text(LocalizedStringKey("play_now"))
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.monologueIconForeground)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.accent)
                                .cornerRadius(20)
                                .monologueGlassCapsule()
                                .shadow(color: Theme.accent.opacity(0.2), radius: 5, x: 0, y: 2)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

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
                                    MonologueIcon(icon: .settings, size: 14, color: Theme.secondaryText)
                                        .frame(width: 32, height: 32)
                                        .background(Color.monologueGlassTint)
                                        .cornerRadius(16)
                                        .monologueGlass(cornerRadius: 16)
                                }
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                            }

                            Button(action: { exportPlaylist(p) }) {
                                MonologueIcon(icon: .download, size: 14, color: Theme.secondaryText)
                                    .frame(width: 32, height: 32)
                                    .background(Color.monologueGlassTint)
                                    .cornerRadius(16)
                                    .monologueGlass(cornerRadius: 16)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                            if !p.isSystem {
                                Button(action: {
                                    AlertManager.shared.show(
                                        title: NSLocalizedString("local_playlist_delete", comment: ""),
                                        message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                        primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                        secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                        primaryAction: {
                                            manager.deletePlaylist(p)
                                            dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                        }
                                    )
                                }) {
                                    MonologueIcon(icon: .trash, size: 14, color: Theme.secondaryText)
                                        .frame(width: 32, height: 32)
                                        .background(Color.monologueGlassTint)
                                        .cornerRadius(16)
                                        .monologueGlass(cornerRadius: 16)
                                }
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 24)
        .padding(.top, DeviceLayout.isPad ? 24 : 16)
        .padding(.bottom, DeviceLayout.isPad ? 32 : 24)
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
                            MonologueIcon(icon: .play, size: 13, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                            Text(LocalizedStringKey("play_now"))
                                .font(SequoiaStyle.labelFont(12, weight: .semibold))
                        }
                        .foregroundStyle(SequoiaStyle.onAccent)
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .background(SequoiaStyle.accentGradient, in: Capsule())
                        .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        sequoiaHeaderIconButton(icon: .download, tint: SequoiaStyle.aqua)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                }
                            )
                        }) {
                            sequoiaHeaderIconButton(icon: .trash, tint: SequoiaStyle.red)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                                PetWhiteStyle.mint.opacity(0.28)
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            PetWhiteIconBadge(icon: .musicNoteList, tint: PetWhiteStyle.mint, size: DeviceLayout.isPad ? 168 : 124)
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 168 : 124, height: DeviceLayout.isPad ? 168 : 124)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(PetWhiteStyle.stroke, lineWidth: PetWhiteStyle.strokeWidth)
                    )

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            PetWhitePill(text: String(localized: "local_playlist_label"), tint: PetWhiteStyle.mint)
                            PetWhitePill(text: "\(playlistTrackCount) \(String(localized: "songs_unit"))", tint: PetWhiteStyle.butter)
                        }

                        Text(p.name)
                            .font(PetWhiteStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .black))
                            .foregroundStyle(PetWhiteStyle.ink)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let desc = p.desc, !desc.isEmpty {
                            Text(desc)
                                .font(PetWhiteStyle.labelFont(12, weight: .semibold))
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        petWhiteLocalIconAction(icon: .download, tint: PetWhiteStyle.mint)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                }
                            )
                        }) {
                            petWhiteLocalIconAction(icon: .trash, tint: PetWhiteStyle.blush)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }
            }
        }
        .padding(16)
        .background(PetWhiteSurfaceBackground(cornerRadius: 28, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        .padding(.horizontal, petWhiteDetailHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
        .padding(.bottom, 14)
        .iPadContentWidth(1280)
    }

    private func petWhiteLocalAction(title: String, icon: MonologueIcon.IconType, tint: Color, filled: Bool) -> some View {
        HStack(spacing: 7) {
            PetWhitePackIcon(icon: icon, size: 14, visualScale: 1.05, fallbackColor: filled ? PetWhiteStyle.onAccent : PetWhiteStyle.stroke)
            Text(title)
                .font(PetWhiteStyle.labelFont(12, weight: .black))
        }
        .foregroundStyle(filled ? PetWhiteStyle.onAccent : PetWhiteStyle.stroke)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(filled ? tint : PetWhiteStyle.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: PetWhiteStyle.fineStrokeWidth))
    }

    private func petWhiteLocalIconAction(icon: MonologueIcon.IconType, tint: Color) -> some View {
        PetWhitePackIcon(icon: icon, size: 15, visualScale: 1.05, fallbackColor: PetWhiteStyle.stroke)
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
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 3, y: 3))
                    .rotationEffect(.degrees(-1.1))

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 22, foreground: MangaStyle.ink)
                            MangaLabel(text: String(localized: "local_playlist_label"), tint: MangaStyle.labelYellow, small: true)
                        }

                        Text(p.name)
                            .font(MangaStyle.titleFont(DeviceLayout.isPad ? 26 : 22, weight: .black))
                            .foregroundStyle(MangaStyle.ink)
                            .lineLimit(3)
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
                            MonologueIcon(icon: .play, size: 13, color: MangaStyle.strokeInk, lineWidth: 2)
                            Text(LocalizedStringKey("play_now"))
                                .font(MangaStyle.labelFont(12, weight: .black))
                        }
                        .foregroundStyle(MangaStyle.strokeInk)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(MangaStyle.labelYellow))
                        .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                        .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        mangaHeaderIconButton(icon: .download, tint: MangaStyle.mint)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                }
                            )
                        }) {
                            mangaHeaderIconButton(icon: .trash, tint: MangaStyle.bubblePink)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }
            }
        }
        .padding(16)
        .background(MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var mangaCoverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MangaStyle.paperCool)
            MangaDotsTexture(opacity: 0.05, gap: 10)
            MonologueIcon(icon: .musicNoteList, size: 34, color: MangaStyle.inkSub, lineWidth: 2)
        }
    }

    private func mangaHeaderIconButton(icon: MonologueIcon.IconType, tint: Color) -> some View {
        MonologueIcon(icon: icon, size: 14, color: MangaStyle.ink, lineWidth: 1.8)
            .frame(width: 36, height: 36)
            .background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        neumorphicHeaderIconButton(icon: .download, tint: NeumorphicStyle.warm)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                }
                            )
                        }) {
                            neumorphicHeaderIconButton(icon: .trash, tint: NeumorphicStyle.red)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(NeumorphicStyle.surfacePressed)
            NeumorphicIconBadge(icon: .musicNoteList, tint: NeumorphicStyle.accent, size: 52)
        }
    }

    private func neumorphicHeaderIconButton(icon: MonologueIcon.IconType, tint: Color) -> some View {
        MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.55)
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        signalHeaderIconButton(icon: .download, tint: SignalStyle.amber)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                }
                            )
                        }) {
                            signalHeaderIconButton(icon: .trash, tint: SignalStyle.rust)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SignalStyle.controlPressed)
            SignalIconBadge(icon: .musicNoteList, tint: SignalStyle.accent, size: 52)
        }
    }

    private func signalHeaderIconButton(icon: MonologueIcon.IconType, tint: Color) -> some View {
        MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.55)
            .frame(width: 38, height: 38)
            .background(SignalSurfaceBackground(cornerRadius: 14, elevated: true, fill: tint.opacity(0.12)))
    }

    private var mujiHeaderView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let p = playlist {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MujiPill(text: String(localized: "local_playlist_label"), tint: MujiStyle.tea)
                        MujiPill(text: "\(playlistTrackCount) \(String(localized: "songs_unit"))", tint: MujiStyle.indigo)
                    }

                    Text(p.name)
                        .font(MujiStyle.titleFont(DeviceLayout.isPad ? 32 : 28, weight: .regular))
                        .foregroundStyle(MujiStyle.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = p.desc, !desc.isEmpty {
                        Text(desc)
                            .font(MujiStyle.labelFont(12, weight: .regular))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        if let url = playlistCoverUrl {
                            CachedAsyncImage(url: url.sized(500)) {
                                mujiCoverPlaceholder
                            }
                            .aspectRatio(contentMode: .fill)
                        } else {
                            mujiCoverPlaceholder
                        }
                    }
                    .frame(width: DeviceLayout.isPad ? 230 : 190, height: DeviceLayout.isPad ? 230 : 190)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
                    )
                    .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 5)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = playlistSongs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        MujiActionPill(title: String(localized: "play_now"), icon: .play, selected: true, tint: MujiStyle.clay)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        mujiHeaderIconButton(icon: .download, tint: MujiStyle.tea)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                }
                            )
                        }) {
                            mujiHeaderIconButton(icon: .trash, tint: MujiStyle.red)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                MujiListDivider()
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        }
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var mujiCoverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MujiStyle.surfaceRaised)
            MonologueIcon(icon: .musicNoteList, size: 34, color: MujiStyle.inkMuted)
        }
    }

    private func mujiHeaderIconButton(icon: MonologueIcon.IconType, tint: Color) -> some View {
        MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.5)
            .frame(width: 34, height: 34)
            .background(MujiStyle.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MujiStyle.hairline.opacity(0.48), lineWidth: 0.6)
            )
    }

    @ViewBuilder
    private var capsuleHeaderView: some View {
        if let p = playlist {
            CapsuleDetailHeader(
                eyebrow: String(localized: "local_playlist_label"),
                title: p.name,
                subtitle: p.desc ?? "",
                coverURL: playlistCoverUrl?.sized(500),
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                    }

                    Button(action: { exportPlaylist(p) }) {
                        CapsuleDetailIconButton(icon: .download, tint: CapsuleStyle.cyan)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                    if !p.isSystem {
                        Button(action: {
                            AlertManager.shared.show(
                                title: NSLocalizedString("local_playlist_delete", comment: ""),
                                message: String(format: NSLocalizedString("local_playlist_delete_confirm", comment: ""), p.name),
                                primaryButtonTitle: NSLocalizedString("lib_delete", comment: ""),
                                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: ""),
                                primaryAction: {
                                    manager.deletePlaylist(p)
                                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                                }
                            )
                        }) {
                            CapsuleDetailIconButton(icon: .trash, tint: CapsuleStyle.coral)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                    }
                }
            }
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
            MonologueIcon(icon: .musicNoteList, size: 36, color: .monologueTextSecondary.opacity(0.3))
        }
    }

    private var sequoiaCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(SequoiaStyle.materialList)
            .overlay(MonologueIcon(icon: .musicNoteList, size: 30, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
    }

    private func sequoiaHeaderIconButton(icon: MonologueIcon.IconType, tint: Color) -> some View {
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
                    MonologueIcon(icon: .musicNoteList, size: 10, color: .monologueTextSecondary.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .background(Color.monologueTextPrimary.opacity(0.08))
                        .clipShape(Capsule())

                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text(LocalizedStringKey("songs_unit"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.monologueTextPrimary.opacity(0.06))
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
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard) {
            let selected = selectedPlaylistSongs
            BatchAddToPlaylistSheet(songs: selected)
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
                .background(PetWhiteSurfaceBackground(cornerRadius: 26, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
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
                MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
            }

            Text(LocalizedStringKey("local_playlist_no_songs"))
                .font(SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .system(size: 14, weight: .medium, design: .rounded))))
                .foregroundColor(SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
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
        if currentPlaylist.isLocalMusic, song.isLocal {
            localLibrary.deleteSong(song)
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
                localLibrary.deleteSongs(selectedPlaylistSongs)
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
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }
}
