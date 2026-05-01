import SwiftUI

/// 最近播放 - 完整列表页
struct RecentPlayHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    let explicitSongs: [Song]?
    
    init(songs: [Song]? = nil) {
        self.explicitSongs = songs
    }
    
    @State private var showClearConfirm = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var recentSearch = ""
    @State private var isRecentSearching = false
    
    private var displaySongs: [Song] { explicitSongs ?? playerManager.history }
    private var recentFiltered: [Song] { displaySongs.filtered(by: recentSearch) }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if SequoiaStyle.isActive {
                SequoiaRootBackdrop()
            } else {
                ThemedPageBackground()
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        if MangaStyle.isActive {
                            MangaPageHeader(
                                eyebrow: "HISTORY",
                                title: String(localized: "profile_recently_played"),
                                subtitle: ""
                            ) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(MangaStyle.mint)
                                    MonologueIcon(icon: .history, size: 23, color: MangaStyle.strokeInk, lineWidth: 2)
                                }
                                .frame(width: 48, height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 2.5, y: 2.5))
                            }
                        } else if MujiStyle.isActive {
                            MujiPageHeader(
                                eyebrow: String(localized: "profile_recently_played"),
                                title: String(localized: "profile_recently_played"),
                                subtitle: ""
                            ) {
                                MujiIconBadge(icon: .history, tint: MujiStyle.tea, size: 48)
                            }
                        } else if NeumorphicStyle.isActive {
                            NeumorphicPageHeader(
                                eyebrow: "HISTORY",
                                title: String(localized: "profile_recently_played"),
                                subtitle: ""
                            ) {
                                NeumorphicIconBadge(icon: .history, tint: NeumorphicStyle.warm, size: 48)
                            }
                        } else if SequoiaStyle.isActive {
                            SequoiaPageHeader(
                                eyebrow: "HISTORY",
                                title: String(localized: "profile_recently_played"),
                                subtitle: ""
                            ) {
                                SequoiaIconBadge(icon: .history, tint: SequoiaStyle.accent, size: 48)
                            }
                        }

                        PlaylistSearchBar(
                            searchText: $recentSearch,
                            isSearching: $isRecentSearching,
                            isSelectMode: $isSelectMode,
                            selectedIds: $selectedSongIds,
                            songs: recentFiltered,
                            onBatchQueue: {
                                let selected = recentFiltered.filter { selectedSongIds.contains($0.id) }
                                SongBatchActionHelper.addToQueue(selected) {
                                    isSelectMode = false
                                    selectedSongIds.removeAll()
                                }
                            },
                            onBatchDownload: { recentBatchDownload() },
                            onBatchCollect: { showBatchAddToPlaylist = true }
                        )
                        
                        LazyVStack(spacing: 0) {
                            ForEach(Array(recentFiltered.enumerated()), id: \.element.id) { index, song in
                                SongListRow(
                                    song: song,
                                    index: index,
                                    isSelecting: isSelectMode,
                                    isSelected: selectedSongIds.contains(song.id),
                                    onArtistTap: nil,
                                    onDetailTap: nil,
                                    onAlbumTap: nil,
                                    onTap: {
                                        if isSelectMode {
                                            if selectedSongIds.contains(song.id) {
                                                selectedSongIds.remove(song.id)
                                            } else {
                                                selectedSongIds.insert(song.id)
                                            }
                                        } else {
                                            if let rid = song.podcastRadioId, rid > 0 {
                                                playerManager.playPodcast(song: song, in: recentFiltered, radioId: rid)
                                                NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: rid)
                                            } else {
                                                playerManager.play(song: song, in: recentFiltered)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    FloatingBarBottomSpacer()
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .navigationTitle(ThemedPageStyle.isActive ? "" : String(localized: "profile_recently_played"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            HStack {
                if explicitSongs == nil {
                    Button {
                        showClearConfirm = true
                    } label: {
                        MonologueIcon(
                            icon: .trash,
                            size: 16,
                            color: MangaStyle.isActive ? MangaStyle.red : (MujiStyle.isActive ? MujiStyle.red : (SequoiaStyle.isActive ? SequoiaStyle.red : (NeumorphicStyle.isActive ? NeumorphicStyle.red : .monologueTextPrimary)))
                        )
                    }
                    .disabled(playerManager.history.isEmpty)
                }
                
                Button {
                    if let first = displaySongs.first {
                        playerManager.playReplacingContext(song: first, in: displaySongs)
                    }
                } label: {
                    if MangaStyle.isActive {
                        MangaLabel(text: String(localized: "artist_play_all"), tint: MangaStyle.labelYellow, small: true)
                    } else if MujiStyle.isActive {
                        MujiActionPill(title: String(localized: "artist_play_all"), icon: .play, selected: true, tint: MujiStyle.clay)
                    } else if NeumorphicStyle.isActive {
                        NeumorphicPlayPill(title: String(localized: "artist_play_all"))
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(text: String(localized: "artist_play_all"), icon: .play, tint: SequoiaStyle.accent, selected: true)
                    } else {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: .play, size: 12, color: .monologueTextPrimary)
                            Text(LocalizedStringKey("artist_play_all"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
                        }
                    }
                }
                .disabled(displaySongs.isEmpty)
            }
        }
        .alert(String(localized: "清空播放历史"), isPresented: $showClearConfirm) {
            Button(String(localized: "取消"), role: .cancel) { }
            Button(String(localized: "清空"), role: .destructive) {
                playerManager.clearPlaybackHistory()
            }
        } message: {
            Text(String(localized: "确定要清空所有播放历史吗？此操作无法撤销。"))
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: recentFiltered.filter { selectedSongIds.contains($0.id) })
        }
    }
    
    private func recentBatchDownload() {
        let selected = recentFiltered.filter { selectedSongIds.contains($0.id) }
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
