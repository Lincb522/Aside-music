import SwiftUI

extension SearchView {
    @ViewBuilder
    var searchLoadingState: some View {
        if MangaStyle.isActive {
            themeSearchStatePanel(
                icon: .magnifyingGlass,
                title: String(localized: "common_searching"),
                tint: MangaStyle.labelYellow,
                loading: true
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 36)
            .frame(minHeight: 320, alignment: .top)
        } else if MujiStyle.isActive {
            themeSearchStatePanel(
                icon: .magnifyingGlass,
                title: String(localized: "common_searching"),
                tint: MujiStyle.clay,
                loading: true
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 36)
            .frame(minHeight: 320, alignment: .top)
        } else if NeumorphicStyle.isActive {
            NeumorphicLoadingPanel(title: "SEARCHING")
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 36)
                .frame(minHeight: 320, alignment: .top)
        } else if SignalStyle.isActive {
            SignalLoadingPanel(title: "SEARCHING")
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 36)
                .frame(minHeight: 320, alignment: .top)
        } else if SequoiaStyle.isActive {
            SequoiaSearchStatePanel(
                icon: .magnifyingGlass,
                title: String(localized: "common_searching"),
                tint: SequoiaStyle.accent,
                loading: true
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 36)
            .frame(minHeight: 320, alignment: .top)
        } else if LiquidGlassStyle.isActive {
            LiquidGlassStatePanel(
                title: String(localized: "common_searching"),
                subtitle: nil,
                icon: .magnifyingGlass,
                tint: LiquidGlassStyle.accent,
                showsProgress: true
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 36)
            .frame(minHeight: 320, alignment: .top)
        } else if CapsuleStyle.isActive {
            themeSearchStatePanel(
                icon: .magnifyingGlass,
                title: String(localized: "common_searching"),
                tint: CapsuleStyle.accent,
                loading: true
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 36)
            .frame(minHeight: 320, alignment: .top)
        } else {
            MonoLoadingView(text: "SEARCHING")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 320)
        }
    }

    var searchEmptyState: some View {
        emptyResultsView
            .padding(.horizontal, searchStateNeedsHorizontalPadding ? DeviceLayout.viewHorizontalPadding : 0)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 320)
    }

    var searchStateNeedsHorizontalPadding: Bool {
        MinimalWhiteStyle.isActive
            || MangaStyle.isActive
            || MujiStyle.isActive
            || NeumorphicStyle.isActive
            || SignalStyle.isActive
            || SequoiaStyle.isActive
            || LiquidGlassStyle.isActive
            || CapsuleStyle.isActive
    }

    var neumorphicResultMetaText: String {
        "\(platformTabName(viewModel.selectedPlatform)) · \(viewModel.currentTab.rawValue)"
    }

    var selectedPlatformResultCount: Int {
        resultCount(for: viewModel.selectedPlatform, tab: viewModel.currentTab)
    }

    var suggestionsTopPadding: CGFloat {
        return viewModel.hasSearched ? ((NeumorphicStyle.isActive || SignalStyle.isActive) ? 54 : 58) : 4
    }

    func resultCount(for source: MusicSource, tab: SearchTab) -> Int {
        switch source {
        case .netease:
            switch tab {
            case .songs: return viewModel.displayedSongCount(for: .netease)
            case .artists: return viewModel.neteaseArtistResults.count
            case .playlists: return viewModel.neteasePlaylistResults.count
            case .albums: return viewModel.neteaseAlbumResults.count
            case .mvs: return viewModel.neteaseMVResults.count
            }
        case .qqmusic:
            switch tab {
            case .songs: return viewModel.displayedSongCount(for: .qqmusic)
            case .artists: return viewModel.qqArtistResults.count
            case .playlists: return viewModel.qqPlaylistResults.count
            case .albums: return viewModel.qqAlbumResults.count
            case .mvs: return viewModel.qqMVResults.count
            }
        case .qishui:
            return tab == .songs ? viewModel.displayedSongCount(for: .qishui) : 0
        case .kugou:
            switch tab {
            case .songs: return viewModel.displayedSongCount(for: .kugou)
            case .artists: return viewModel.kugouArtistResults.count
            case .playlists: return viewModel.kugouPlaylistResults.count
            case .albums: return viewModel.kugouAlbumResults.count
            case .mvs: return viewModel.kugouMVResults.count
            }
        case .appleMusic:
            switch tab {
            case .songs: return viewModel.displayedSongCount(for: .appleMusic)
            case .artists: return viewModel.appleMusicArtistResults.count
            case .playlists: return viewModel.appleMusicPlaylistResults.count
            case .albums: return viewModel.appleMusicAlbumResults.count
            case .mvs: return 0
            }
        case .local:
            return 0
        }
    }

    func searchTabIcon(_ tab: SearchTab) -> MonoIcon.IconType {
        switch tab {
        case .songs: return .musicNote
        case .artists: return .profile
        case .playlists: return .musicNoteList
        case .albums: return .album
        case .mvs: return .mv
        }
    }

    struct NeumorphicLoadingPanel: View {
        let title: String

        var body: some View {
            VStack(spacing: 14) {
                ProgressView()
                    .tint(NeumorphicStyle.accent)

                Text(title)
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .tracking(1.2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 38)
            .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
        }
    }

    struct SignalLoadingPanel: View {
        let title: String

        var body: some View {
            VStack(spacing: 14) {
                ProgressView()
                    .tint(SignalStyle.accent)

                Text(title)
                    .font(SignalStyle.monoFont(11, weight: .semibold))
                    .foregroundStyle(SignalStyle.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 38)
            .background(SignalSurfaceBackground(cornerRadius: 24, elevated: true, fill: SignalStyle.device))
        }
    }

    func neumorphicSearchSongsToolbar(currentSource: MusicSource, currentSongs: [Song]) -> some View {
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: currentSongs,
                    onBatchQueue: {
                        let selected = currentSongs.filter { searchSelectedIds.contains($0.identityKey) }
                        SongBatchActionHelper.addToQueue(selected) {
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                        }
                    },
                    onBatchDownload: { searchBatchDownload(source: currentSource) },
                    onBatchCollect: { showSearchBatchPlaylist = true }
                )
            } else if isSearchFiltering {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering
                )
            } else {
                HStack(spacing: 9) {
                    Button {
                        if !currentSongs.isEmpty {
                            viewModel.playAllSongs(source: currentSource, currentSongs: currentSongs)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            MonoIcon(icon: .play, size: 12, color: Color(light: .white, dark: .black), lineWidth: 1.7)
                                .frame(width: 24, height: 24)
                                .background(NeumorphicStyle.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(String(localized: "artist_play_all"))
                                .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                                .foregroundStyle(NeumorphicStyle.ink)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    .disabled(currentSongs.isEmpty)
                    .opacity(currentSongs.isEmpty ? 0.55 : 1)

                    Spacer(minLength: 8)

                    neumorphicToolbarButton(icon: .search, tint: NeumorphicStyle.accent) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFiltering = true
                        }
                    }

                    neumorphicToolbarButton(icon: .like, tint: NeumorphicStyle.red) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }

                    neumorphicToolbarButton(icon: .checkmark, tint: NeumorphicStyle.sage) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 4)
            }
        }
    }

    func neumorphicToolbarButton(
        icon: MonoIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: true, lightweight: true))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
    }

    func signalSearchSongsToolbar(currentSource: MusicSource, currentSongs: [Song]) -> some View {
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: currentSongs,
                    onBatchQueue: {
                        let selected = currentSongs.filter { searchSelectedIds.contains($0.identityKey) }
                        SongBatchActionHelper.addToQueue(selected) {
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                        }
                    },
                    onBatchDownload: { searchBatchDownload(source: currentSource) },
                    onBatchCollect: { showSearchBatchPlaylist = true }
                )
            } else if isSearchFiltering {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering
                )
            } else {
                HStack(spacing: 9) {
                    Button {
                        if !currentSongs.isEmpty {
                            viewModel.playAllSongs(source: currentSource, currentSongs: currentSongs)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            MonoIcon(icon: .play, size: 12, color: SignalStyle.onAccent, lineWidth: 1.75)
                                .frame(width: 24, height: 24)
                                .background(SignalStyle.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(String(localized: "artist_play_all"))
                                .font(SignalStyle.labelFont(12, weight: .bold))
                                .foregroundStyle(SignalStyle.ink)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SignalSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, fill: SignalStyle.control))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    .disabled(currentSongs.isEmpty)
                    .opacity(currentSongs.isEmpty ? 0.55 : 1)

                    Spacer(minLength: 8)

                    signalToolbarButton(icon: .search, tint: SignalStyle.accent) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFiltering = true
                        }
                    }

                    signalToolbarButton(icon: .like, tint: SignalStyle.red) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }

                    signalToolbarButton(icon: .checkmark, tint: SignalStyle.olive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 4)
            }
        }
    }

    func signalToolbarButton(
        icon: MonoIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.65)
                .frame(width: 32, height: 32)
                .background(SignalSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, fill: SignalStyle.control))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
    }

    func capsuleSearchSongsToolbar(currentSource: MusicSource, currentSongs: [Song]) -> some View {
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: currentSongs,
                    onBatchQueue: {
                        let selected = currentSongs.filter { searchSelectedIds.contains($0.identityKey) }
                        SongBatchActionHelper.addToQueue(selected) {
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                        }
                    },
                    onBatchDownload: { searchBatchDownload(source: currentSource) },
                    onBatchCollect: { showSearchBatchPlaylist = true }
                )
            } else if isSearchFiltering {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering
                )
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 8) {
                    Button {
                        if !currentSongs.isEmpty {
                            viewModel.playAllSongs(source: currentSource, currentSongs: currentSongs)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(CapsuleStyle.accent.opacity(currentSongs.isEmpty ? 0.36 : 1))
                                .frame(width: 20, height: 8)

                            MonoIcon(
                                icon: .play,
                                size: 12,
                                color: CapsuleStyle.onAccent,
                                lineWidth: 1.75
                            )
                            .frame(width: 28, height: 28)
                            .background(CapsuleStyle.accent.opacity(currentSongs.isEmpty ? 0.36 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(String(localized: "artist_play_all"))
                                .font(CapsuleStyle.labelFont(12, weight: .bold))
                                .foregroundStyle(CapsuleStyle.ink.opacity(currentSongs.isEmpty ? 0.55 : 1))
                                .lineLimit(1)
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 13)
                        .padding(.vertical, 7)
                        .background(CapsuleStyle.surfaceRaised.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(CapsulePressStyle())
                    .disabled(currentSongs.isEmpty)

                    Spacer(minLength: 8)

                    capsuleToolbarControl(icon: .search, tint: currentSource.themedBadgeColor) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            isSearchFiltering = true
                        }
                    }

                    capsuleToolbarControl(icon: .like, tint: CapsuleStyle.coral) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }

                    capsuleToolbarControl(icon: .checkmark, tint: CapsuleStyle.mint) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(CapsuleStyle.surface.opacity(0.76))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(CapsuleStyle.separator.opacity(0.4), lineWidth: 0.7)
                        )
                )
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 5)
            }
        }
    }

    func capsuleToolbarControl(
        icon: MonoIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.65)
                .frame(width: 36, height: 36)
                .background(CapsuleStyle.surfaceRaised.opacity(0.86), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(tint.opacity(0.24), lineWidth: 0.7)
                )
        }
        .buttonStyle(CapsulePressStyle())
    }

}
