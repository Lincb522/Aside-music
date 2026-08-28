import SwiftUI

extension SearchView {
    // MARK: - 展开单平台全屏列表

    func expandedResultsView(source: MusicSource) -> some View {
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: expandedFilteredSongs(source: source),
                    onBatchQueue: {
                        let selected = expandedFilteredSongs(source: source).filter { searchSelectedIds.contains($0.id) }
                        SongBatchActionHelper.addToQueue(selected) {
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                        }
                    },
                    onBatchDownload: { searchBatchDownload(source: source) },
                    onBatchCollect: { showSearchBatchPlaylist = true }
                )
            } else if isSearchFiltering {
                HStack(spacing: 8) {
                    PlaylistSearchBar(
                        searchText: $searchFilterText,
                        isSearching: $isSearchFiltering
                    )
                }
            } else {
                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.expandedSource = nil
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                            searchFilterText = ""
                            isSearchFiltering = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            MonoIcon(icon: .back, size: 16, color: .monoTextPrimary)
                            Text(expandedSourceName(source))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.monoTextPrimary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    if viewModel.currentTab == .songs {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchFiltering = true
                            }
                        } label: {
                            MonoIcon(icon: .search, size: 15, color: .monoTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monoTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchSelectMode = true
                                searchSelectedIds.removeAll()
                            }
                        } label: {
                            MonoIcon(icon: .like, size: 15, color: .monoAccentRed)
                                .frame(width: 30, height: 30)
                                .background(Color.monoTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchSelectMode = true
                                searchSelectedIds.removeAll()
                            }
                        } label: {
                            MonoIcon(icon: .checkmark, size: 15, color: .monoTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monoTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 8)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    switch viewModel.currentTab {
                    case .songs:
                        expandedSongsList(source: source)
                    case .artists:
                        expandedArtistsList(source: source)
                    case .playlists:
                        expandedPlaylistsList(source: source)
                    case .albums:
                        expandedAlbumsList(source: source)
                    case .mvs:
                        if source == .netease {
                            expandedMVsList
                        } else {
                            expandedQQMVsList
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .simultaneousGesture(DragGesture().onChanged { _ in
                isFocused = false
            })
        }
    }

    // MARK: - 展开歌曲列表

    func expandedSourceName(_ source: MusicSource) -> String {
        switch source {
        case .netease: return String(localized: "search_platform_netease")
        case .qqmusic: return String(localized: "search_platform_qq")
        case .qishui: return "QSM"
        case .kugou: return "KCM"
        case .appleMusic: return "Apple Music"
        case .local: return "本地"
        }
    }

    func expandedFilteredSongs(source: MusicSource) -> [Song] {
        let songs: [Song]
        switch source {
        case .netease: songs = viewModel.neteaseResults
        case .qqmusic: songs = viewModel.qqResults
        case .qishui: songs = viewModel.qishuiResults
        case .kugou: songs = viewModel.kugouResults
        case .appleMusic: songs = viewModel.appleMusicResults
        case .local: songs = []
        }
        return songs.filtered(by: searchFilterText)
    }

    func expandedSongsList(source: MusicSource) -> some View {
        let allSongs: [Song] = {
            switch source {
            case .netease: return viewModel.neteaseResults
            case .qqmusic: return viewModel.qqResults
            case .qishui: return viewModel.qishuiResults
            case .kugou: return viewModel.kugouResults
            case .appleMusic: return viewModel.appleMusicResults
            case .local: return []
            }
        }()
        let songs = expandedFilteredSongs(source: source)
        return Group {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                SongListRow(song: song, index: index, isSelecting: isSearchSelectMode, isSelected: searchSelectedIds.contains(song.id), onArtistTap: { artistId in
                    selectedArtistId = artistId
                    showArtistDetail = true
                }, onDetailTap: { detailSong in
                    selectedSongForDetail = detailSong
                    showSongDetail = true
                }, onAlbumTap: { albumId in
                    selectedAlbumId = albumId
                    showAlbumDetail = true
                }, onTap: {
                    if isSearchSelectMode {
                        if searchSelectedIds.contains(song.id) {
                            searchSelectedIds.remove(song.id)
                        } else {
                            searchSelectedIds.insert(song.id)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: songs)
                        isFocused = false
                    }
                })
                .onAppear {
                    if index >= max(allSongs.count - 3, 0) {
                        viewModel.loadMore(source: source)
                    }
                }
            }

            if viewModel.canLoadMore(source: source) {
                searchLoadMoreFooter(source: source)
                    .onAppear {
                        viewModel.loadMore(source: source)
                    }
            }
        }
        .monoSheet(isPresented: $showSearchBatchPlaylist, preset: .standard) {
            BatchAddToPlaylistSheet(songs: songs.filter { searchSelectedIds.contains($0.id) })
        }
    }

    func searchLoadMoreFooter(source: MusicSource) -> some View {
        Button {
            viewModel.loadMore(source: source)
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingMore(source: source) {
                    ProgressView()
                        .scaleEffect(0.72)
                        .tint(source.themedBadgeColor)
                } else {
                    MonoIcon(icon: .chevronRight, size: 12, color: source.themedBadgeColor, lineWidth: 1.7)
                }

                Text(String(localized: "event_load_more"))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .bold) : .rounded(size: 12, weight: .semibold)))
                    .foregroundStyle(source.themedBadgeColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, tint: source.themedBadgeColor.opacity(0.1), lightweight: true)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, fill: source.themedBadgeColor.opacity(0.12))
                } else {
                    Capsule().fill(source.themedBadgeColor.opacity(0.1))
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingMore(source: source))
    }

    func searchBatchDownload(source: MusicSource) {
        guard source != .appleMusic else {
            AlertManager.shared.show(
                title: "Apple Music",
                message: String(localized: "apple_music_download_unavailable"),
                primaryButtonTitle: String(localized: "common_confirm"),
                primaryAction: {}
            )
            return
        }
        let songs = expandedFilteredSongs(source: source)
        let selected = songs.filter { searchSelectedIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "download_batch_added_title"), message: L10n.format("download_batch_queue_added_format", selected.count), primaryButtonTitle: String(localized: "common_confirm"), primaryAction: {})
        withAnimation { isSearchSelectMode = false; searchSelectedIds.removeAll() }
    }

    // MARK: - 展开歌手列表

    func expandedArtistsList(source: MusicSource) -> some View {
        let artists = source == .netease ? viewModel.neteaseArtistResults : viewModel.qqArtistResults
        return ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
            artistRow(artist: artist)
                .onAppear {
                    if index == artists.count - 3 {
                        viewModel.loadMore(source: source)
                    }
                }
        }
    }

    // MARK: - 展开歌单列表

    func expandedPlaylistsList(source: MusicSource) -> some View {
        let playlists = source == .netease ? viewModel.neteasePlaylistResults : viewModel.qqPlaylistResults
        return ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
            playlistRow(playlist: playlist)
                .onAppear {
                    if index == playlists.count - 3 {
                        viewModel.loadMore(source: source)
                    }
                }
        }
    }

    // MARK: - 展开专辑列表

    func expandedAlbumsList(source: MusicSource) -> some View {
        let albums = source == .netease ? viewModel.neteaseAlbumResults : viewModel.qqAlbumResults
        return ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
            albumRow(album: album)
                .onAppear {
                    if index == albums.count - 3 {
                        viewModel.loadMore(source: source)
                    }
                }
        }
    }

    // MARK: - 展开 MV 列表（仅ncm）

    var expandedMVsList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 18),
            GridItem(.flexible(), spacing: 18),
        ]
        return LazyVGrid(columns: columns, spacing: 22) {
            ForEach(Array(viewModel.neteaseMVResults.enumerated()), id: \.element.id) { index, mv in
                MVGridCard(mv: mv) {
                    selectedMVId = MVIdItem(id: mv.id)
                    isFocused = false
                }
                .onAppear {
                    if index == viewModel.neteaseMVResults.count - 3 {
                        viewModel.loadMore(source: .netease)
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
    }

}
