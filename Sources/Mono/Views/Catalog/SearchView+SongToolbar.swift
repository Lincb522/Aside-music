import SwiftUI

extension SearchView {
    // MARK: - 歌曲列表工具栏

    @ViewBuilder
    var searchSongsToolbarView: some View {
        let currentSource = viewModel.selectedPlatform
        let currentSongs = expandedFilteredSongs(source: currentSource)

        if NeumorphicStyle.isActive {
            neumorphicSearchSongsToolbar(currentSource: currentSource, currentSongs: currentSongs)
        } else if SignalStyle.isActive {
            signalSearchSongsToolbar(currentSource: currentSource, currentSongs: currentSongs)
        } else if CapsuleStyle.isActive {
            capsuleSearchSongsToolbar(currentSource: currentSource, currentSongs: currentSongs)
        } else if MangaStyle.isActive || MujiStyle.isActive {
            themedSearchSongsToolbar(currentSource: currentSource, currentSongs: currentSongs)
        } else {
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
                    HStack(spacing: 8) {
                        PlaylistSearchBar(
                            searchText: $searchFilterText,
                            isSearching: $isSearchFiltering
                        )
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 8)
                } else {
                    HStack(spacing: 12) {
                        Button(action: {
                            if !currentSongs.isEmpty {
                                viewModel.playAllSongs(source: currentSource, currentSongs: currentSongs)
                            }
                        }) {
                            HStack(spacing: 6) {
                                MonoIcon(icon: .play, size: 14, color: Color(UIColor.systemBackground))
                                    .frame(width: 24, height: 24)
                                    .background(Color.monoTextPrimary)
                                    .clipShape(Circle())

                                Text(String(localized: "artist_play_all"))
                                    .font(.rounded(size: 14, weight: .semibold))
                                    .foregroundColor(.monoTextPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.monoTextPrimary.opacity(0.04))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()

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
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    func themedSearchSongsToolbar(currentSource: MusicSource, currentSongs: [Song]) -> some View {
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
                HStack(spacing: 9) {
                    Button {
                        if !currentSongs.isEmpty {
                            viewModel.playAllSongs(source: currentSource, currentSongs: currentSongs)
                        }
                    } label: {
                        themedToolbarPlayLabel(isDisabled: currentSongs.isEmpty)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    .disabled(currentSongs.isEmpty)
                    .opacity(currentSongs.isEmpty ? 0.55 : 1)

                    Spacer(minLength: 8)

                    themedToolbarIconButton(icon: .search, tint: currentSource.themedBadgeColor) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFiltering = true
                        }
                    }

                    themedToolbarIconButton(icon: .like, tint: MujiStyle.isActive ? MujiStyle.clay : .monoAccentRed) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }

                    themedToolbarIconButton(icon: .checkmark, tint: themeToolbarSecondaryTint) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 6)
            }
        }
    }

    var themeToolbarSecondaryTint: Color {
        if MangaStyle.isActive { return MangaStyle.decoBlue }
        if MujiStyle.isActive { return MujiStyle.indigo }
        if CapsuleStyle.isActive { return CapsuleStyle.mint }
        return .monoAccent
    }

    func themedToolbarPlayLabel(isDisabled: Bool) -> some View {
        HStack(spacing: 7) {
            MonoIcon(icon: .play, size: 12, color: themeToolbarPlayIconColor, lineWidth: 1.75)
                .frame(width: 24, height: 24)
                .background(themeToolbarPlayIconBackground, in: RoundedRectangle(cornerRadius: themeToolbarIconCornerRadius, style: .continuous))

            Text(String(localized: "artist_play_all"))
                .font(themeToolbarFont)
                .foregroundStyle(themeToolbarPrimaryColor.opacity(isDisabled ? 0.6 : 1))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background { themeToolbarButtonBackground(tint: themeToolbarPlayIconBackground, selected: false) }
    }

    func themedToolbarIconButton(
        icon: MonoIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.65)
                .frame(width: 32, height: 32)
                .background { themeToolbarButtonBackground(tint: tint, selected: false) }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
    }

    var themeToolbarFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(12, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(12, weight: .bold) }
        return .rounded(size: 12, weight: .semibold)
    }

    var themeToolbarPrimaryColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    var themeToolbarPlayIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        return Color(UIColor.systemBackground)
    }

    var themeToolbarPlayIconBackground: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if MujiStyle.isActive { return MujiStyle.clay }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        return .monoTextPrimary
    }

    var themeToolbarIconCornerRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.buttonRadius }
        if MujiStyle.isActive { return 9 }
        if CapsuleStyle.isActive { return 11 }
        return 12
    }

    @ViewBuilder
    func themeToolbarButtonBackground(tint: Color, selected: Bool) -> some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                .fill(selected ? tint.opacity(0.22) : MangaStyle.bubbleWhite)
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk.opacity(0.45), lineWidth: MangaStyle.fineStrokeWidth))
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MujiStyle.surfaceRaised.opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(tint.opacity(0.22), lineWidth: 0.6))
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(cornerRadius: 14, elevated: true, tint: CapsuleStyle.surfaceRaised)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.18), lineWidth: 0.8))
        } else {
            Capsule().fill(Color.monoTextPrimary.opacity(0.07))
        }
    }

}
