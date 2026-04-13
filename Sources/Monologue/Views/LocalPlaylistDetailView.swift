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
            if SettingsManager.shared.coverBgPlaylist {
                PlaylistColorBackground(coverUrl: playlist?.displayCoverUrl?.sized(200))
            } else {
                MonologueBackground()
            }
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 0) {
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
                .scrollIndicators(.hidden)
                .refreshable {
                    _ = try? await LocalPlaylistCloudSyncManager.shared.refreshAndSync()
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
    
    private var headerView: some View {
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
    
    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
            MonologueIcon(icon: .musicNoteList, size: 36, color: .monologueTextSecondary.opacity(0.3))
        }
    }

    private func toolbarTrackCountView(_ count: Int) -> some View {
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
