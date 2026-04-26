import SwiftUI
import UniformTypeIdentifiers

/// 本地歌单详情页
struct LocalPlaylistDetailView: View {
    let playlistId: String

    @ObservedObject private var manager = LocalPlaylistManager.shared
    @ObservedObject private var playerManager = PlayerManager.shared
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

    private var playlist: LocalPlaylist? {
        manager.playlists.first { $0.id == playlistId }
    }

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if SettingsManager.shared.coverBgPlaylist {
                PlaylistColorBackground(coverUrl: playlist?.displayCoverUrl?.sized(200))
            } else {
                MonologueBackground()
            }

            if MangaStyle.isActive || MujiStyle.isActive {
                ScrollView {
                    localPlaylistScrollableContent(includeHeader: true)
                }
                .scrollIndicators(.hidden)
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
                    .refreshable {
                        _ = try? await LocalPlaylistCloudSyncManager.shared.refreshAndSync()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let p = playlist {
                    toolbarTrackCountView(p.trackCount)
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
        .onAppear {
            Task {
                await LocalPlaylistCloudSyncManager.shared.refreshFromCloudIfNeeded()
            }
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
                songs: playlist?.songs.filtered(by: searchText) ?? [],
                onBatchQueue: {
                    let selected = (playlist?.songs ?? []).filter { selectedSongIds.contains($0.id) }
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

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        if MangaStyle.isActive {
            mangaHeaderView
        } else if MujiStyle.isActive {
            mujiHeaderView
        } else {
            VStack(alignment: .leading, spacing: 12) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if let url = p.displayCoverUrl {
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
                                let songs = p.songs
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

    private var mangaHeaderView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let p = playlist {
                HStack(alignment: .top, spacing: 14) {
                    Group {
                        if let url = p.displayCoverUrl {
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
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MangaStyle.ink, lineWidth: MangaStyle.strokeWidth))
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MangaStyle.ink).offset(x: 3, y: 3))
                    .rotationEffect(.degrees(-1.1))

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 22)
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

                        MangaLabel(text: "\(p.trackCount) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        let songs = p.songs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        HStack(spacing: 7) {
                            MonologueIcon(icon: .play, size: 13, color: MangaStyle.ink, lineWidth: 2)
                            Text(LocalizedStringKey("play_now"))
                                .font(MangaStyle.labelFont(12, weight: .black))
                        }
                        .foregroundStyle(MangaStyle.ink)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(MangaStyle.labelYellow))
                        .overlay(Capsule().stroke(MangaStyle.ink, lineWidth: MangaStyle.fineStrokeWidth))
                        .background(Capsule().fill(MangaStyle.ink).offset(x: 2, y: 2))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    .opacity(p.songs.isEmpty ? 0.55 : 1)
                    .disabled(p.songs.isEmpty)

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
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MangaStyle.ink, lineWidth: MangaStyle.fineStrokeWidth))
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MangaStyle.ink).offset(x: 2, y: 2))
    }

    private var mujiHeaderView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let p = playlist {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MujiPill(text: String(localized: "local_playlist_label"), tint: MujiStyle.tea)
                        MujiPill(text: "\(p.trackCount) \(String(localized: "songs_unit"))", tint: MujiStyle.indigo)
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
                        if let url = p.displayCoverUrl {
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
                        let songs = p.songs
                        if let first = songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: songs)
                        }
                    }) {
                        MujiActionPill(title: String(localized: "play_now"), icon: .play, selected: true, tint: MujiStyle.clay)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    .opacity(p.songs.isEmpty ? 0.55 : 1)
                    .disabled(p.songs.isEmpty)

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

    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
            MonologueIcon(icon: .musicNoteList, size: 36, color: .monologueTextSecondary.opacity(0.3))
        }
    }

    private func toolbarTrackCountView(_ count: Int) -> some View {
        Group {
            if MangaStyle.isActive {
                MangaLabel(text: "\(count) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true)
            } else if MujiStyle.isActive {
                MujiPill(text: "\(count) \(String(localized: "songs_unit"))", tint: MujiStyle.tea)
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
        LazyVStack(spacing: 0) {
            if let p = playlist {
                let songs = p.songs
                let displaySongs = songs.filtered(by: searchText)
                if songs.isEmpty {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("local_playlist_no_songs"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    .padding(.top, 60)
                } else {
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
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    manager.removeSong(id: song.id, from: p)
                                }
                            } label: {
                                Label(NSLocalizedString("local_playlist_remove", comment: ""), systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Color.clear.frame(height: 100)
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            let selected = (playlist?.songs ?? []).filter { selectedSongIds.contains($0.id) }
            BatchAddToPlaylistSheet(songs: selected)
        }
    }

    private func batchDownloadSelected() {
        let selected = (playlist?.songs ?? []).filter { selectedSongIds.contains($0.id) }
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
