// NewSongExpressView.swift
// 新歌速递页面 — 全新卡片式设计

import SwiftUI

struct NewSongExpressView: View {
    @State private var viewModel = NewSongExpressViewModel()
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var newSongSearch = ""
    @State private var isNewSongSearching = false

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if SignalStyle.isActive {
                ThemeRenderBackdrop(theme: .signal)
            } else {
                ThemedPageBackground()
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if MangaStyle.isActive {
                    MangaPageHeader(
                        eyebrow: "NEW SONGS",
                        title: String(localized: "new_song_express"),
                        subtitle: ""
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(MangaStyle.labelYellow)
                            MonologueIcon(icon: .musicNote, size: 23, color: MangaStyle.strokeInk, lineWidth: 2)
                        }
                        .frame(width: 48, height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 2.5, y: 2.5))
                    }
                } else if NeumorphicStyle.isActive {
                    NeumorphicPageHeader(
                        eyebrow: "NEW SONGS",
                        title: String(localized: "new_song_express"),
                        subtitle: ""
                    ) {
                        NeumorphicIconBadge(icon: .musicNote, tint: NeumorphicStyle.warm, size: 48)
                    }
                } else if MujiStyle.isActive {
                    MujiPageHeader(
                        eyebrow: String(localized: "new_song_express"),
                        title: String(localized: "new_song_express"),
                        subtitle: ""
                    ) {
                        MujiIconBadge(icon: .musicNote, tint: MujiStyle.clay, size: 48)
                    }
                } else if SignalStyle.isActive {
                    SignalPageHeader(
                        eyebrow: "NEW SONGS",
                        title: String(localized: "new_song_express"),
                        subtitle: ""
                    ) {
                        SignalIconBadge(icon: .musicNote, tint: SignalStyle.olive, size: 48)
                    }
                } else if SequoiaStyle.isActive {
                    SequoiaPageHeader(
                        eyebrow: "NEW SONGS",
                        title: String(localized: "new_song_express"),
                        subtitle: ""
                    ) {
                        SequoiaIconBadge(icon: .musicNote, tint: SequoiaStyle.green, size: 48)
                    }
                }

                typeSelector
                    .padding(.top, ThemedPageStyle.isActive ? 0 : 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(loadingTint)
                    Spacer()
                } else if viewModel.songs.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 完整列表
                            fullListSection
                        }
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
            }
        }
        .navigationTitle(ThemedPageStyle.isActive ? "" : String(localized: "new_song_express"))
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let shuffled = viewModel.songs.shuffled()
                    if let first = shuffled.first {
                        playerManager.playReplacingContext(song: first, in: shuffled)
                    }
                } label: {
                    MonologueIcon(icon: .shuffle, size: 16)
                }
                .opacity(viewModel.songs.isEmpty ? 0.3 : 1)
                .disabled(viewModel.songs.isEmpty)
            }
        }
        .navigationDestination(isPresented: $showArtistDetail) {
            if let id = selectedArtistId {
                ArtistDetailView(artistId: id)

            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let id = selectedAlbumId {
                AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil)

            }
        }
        .onAppear {
            if viewModel.songs.isEmpty {
                viewModel.loadSongs(type: 0)
            }
        }
    }

    // MARK: - 语种选择

    private var typeSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(NewSongExpressViewModel.songTypes) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.loadSongs(type: type.id)
                        }
                    } label: {
                        let isSelected = viewModel.selectedType == type.id
                        let mangaForeground = isSelected ? MangaStyle.strokeInk : MangaStyle.ink
                        Text(LocalizedStringKey(type.nameKey))
                            .font(typeChipFont(isSelected: isSelected))
                            .foregroundColor(MangaStyle.isActive ? mangaForeground : typeChipForeground(isSelected: isSelected))
                            .padding(.horizontal, MangaStyle.isActive ? 12 : (MujiStyle.isActive ? 13 : ((SignalStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 14 : 16)))
                            .padding(.vertical, ThemedPageStyle.isActive ? 9 : 8)
                            .background(typeChipBackground(isSelected: isSelected))
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    @ViewBuilder
    private func typeChipBackground(isSelected: Bool) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 16,
                elevated: isSelected,
                pressed: !isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface
            )
        } else if SequoiaStyle.isActive {
            Capsule()
                .fill(isSelected ? SequoiaStyle.accent : SequoiaStyle.materialList.opacity(0.76))
                .overlay(
                    Capsule()
                        .stroke((isSelected ? SequoiaStyle.accent : SequoiaStyle.separator).opacity(0.42), lineWidth: 0.55)
                )
        } else if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? SignalStyle.accent : SignalStyle.control)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.22) : SignalStyle.separator.opacity(0.75), lineWidth: 0.8)
                )
                .shadow(color: isSelected ? SignalStyle.accent.opacity(0.18) : .clear, radius: 12, x: 0, y: 7)
        } else {
            Capsule()
                .fill(MangaStyle.isActive ? (isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite.opacity(0.72)) : (MujiStyle.isActive ? (isSelected ? MujiStyle.clay : MujiStyle.surface.opacity(0.78)) : (isSelected ? Color.monologueAccent : Color.clear)))
                .overlay(
                    Capsule()
                        .stroke(MangaStyle.isActive ? MangaStyle.strokeInk : (MujiStyle.isActive && !isSelected ? MujiStyle.hairline.opacity(0.48) : Color.clear), lineWidth: MangaStyle.isActive ? MangaStyle.fineStrokeWidth : 0.6)
                )
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            if SignalStyle.isActive {
                SignalIconBadge(icon: .musicNote, tint: SignalStyle.olive, size: 54)
            } else if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: .musicNote, tint: SequoiaStyle.green, size: 54)
            } else {
                MonologueIcon(icon: .musicNote, size: 40, color: .monologueTextSecondary.opacity(0.3))
            }
            Text(LocalizedStringKey("empty_no_results"))
                .font(emptyStateFont)
                .foregroundColor(emptyStateColor)
        }
    }

    // MARK: - 完整列表

    private var fullListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 播放全部按钮
            HStack {
                Button(action: {
                    if let first = viewModel.songs.first {
                        playerManager.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    if MangaStyle.isActive {
                        HStack(spacing: 7) {
                            MonologueIcon(icon: .play, size: 13, color: MangaStyle.strokeInk, lineWidth: 2)
                            Text(LocalizedStringKey("artist_play_all"))
                                .font(MangaStyle.labelFont(12, weight: .black))
                        }
                        .foregroundStyle(MangaStyle.strokeInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(MangaStyle.labelYellow))
                        .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                        .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
                    } else if MujiStyle.isActive {
                        MujiActionPill(title: String(localized: "artist_play_all"), icon: .play, selected: true, tint: MujiStyle.clay)
                    } else if NeumorphicStyle.isActive {
                        NeumorphicPlayPill(title: String(localized: "artist_play_all"), tint: NeumorphicStyle.accent)
                    } else if SignalStyle.isActive {
                        SignalPlayPill(title: String(localized: "artist_play_all"))
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(text: String(localized: "artist_play_all"), icon: .play, tint: SequoiaStyle.accent, selected: true)
                    } else {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: .play, size: 12, color: .monologueTextPrimary)
                            Text(LocalizedStringKey("artist_play_all"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.monologueTextPrimary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                Spacer()

                Text(String(format: NSLocalizedString("songs_count_format", comment: ""), viewModel.songs.count))
                    .font(countFont)
                    .foregroundColor(countColor)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            PlaylistSearchBar(
                searchText: $newSongSearch,
                isSearching: $isNewSongSearching,
                isSelectMode: $isSelectMode,
                selectedIds: $selectedSongIds,
                songs: newSongFiltered,
                onBatchQueue: {
                    let selected = newSongFiltered.filter { selectedSongIds.contains($0.id) }
                    SongBatchActionHelper.addToQueue(selected) {
                        isSelectMode = false
                        selectedSongIds.removeAll()
                    }
                },
                onBatchDownload: { newSongBatchDownload() },
                onBatchCollect: { showBatchAddToPlaylist = true }
            )

            LazyVStack(spacing: 0) {
                ForEach(Array(newSongFiltered.enumerated()), id: \.element.id) { index, song in
                    SongListRow(
                        song: song,
                        index: index,
                        isSelecting: isSelectMode,
                        isSelected: selectedSongIds.contains(song.id),
                        onArtistTap: { id in
                            selectedArtistId = id
                            showArtistDetail = true
                        },
                        onDetailTap: { s in
                            selectedSongForDetail = s
                            showSongDetail = true
                        },
                        onAlbumTap: { id in
                            selectedAlbumId = id
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
                                playerManager.play(song: song, in: newSongFiltered)
                            }
                        }
                    )
                }

                NoMoreDataView()
            }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: newSongFiltered.filter { selectedSongIds.contains($0.id) })
        }
    }

    private var newSongFiltered: [Song] { viewModel.songs.filtered(by: newSongSearch) }

    private var loadingTint: Color {
        if SignalStyle.isActive { return SignalStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monologueTextSecondary
    }

    private func typeChipFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(12, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(14, weight: isSelected ? .semibold : .regular) }
        if SignalStyle.isActive { return SignalStyle.labelFont(14, weight: isSelected ? .bold : .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(14, weight: isSelected ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(14, weight: isSelected ? .semibold : .medium) }
        return .system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded)
    }

    private func typeChipForeground(isSelected: Bool) -> Color {
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.inkSoft }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent : SignalStyle.inkSoft }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.onAccent : SequoiaStyle.inkSoft }
        return isSelected ? .monologueIconForeground : .monologueTextSecondary
    }

    private var emptyStateFont: Font {
        if SignalStyle.isActive { return SignalStyle.labelFont(14, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(14, weight: .medium) }
        return .system(size: 14, weight: .medium, design: .rounded)
    }

    private var emptyStateColor: Color {
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var countFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .regular) }
        if SignalStyle.isActive { return SignalStyle.labelFont(13, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var countColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private func newSongBatchDownload() {
        let selected = newSongFiltered.filter { selectedSongIds.contains($0.id) }
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
