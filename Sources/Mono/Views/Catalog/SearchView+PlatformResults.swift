import SwiftUI

extension SearchView {
    // MARK: - 平台结果列表

    var platformResultsView: some View {
        ScrollView {
            platformResultsRows
                .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .simultaneousGesture(DragGesture().onChanged { _ in
            isFocused = false
        })
    }

    var platformResultsRows: some View {
        LazyVStack(spacing: themedSearchResultRowsSpacing) {
            switch viewModel.selectedPlatform {
            case .netease:
                neteaseResultsContent
            case .qqmusic:
                qqResultsContent
            case .qishui:
                qishuiResultsContent
            case .kugou:
                kugouResultsContent
            case .appleMusic:
                appleMusicResultsContent
            case .local:
                EmptyView()
            }
        }
        .padding(.top, themedSearchResultRowsActive ? 2 : 0)
    }

    var themedSearchResultRowsActive: Bool {
        return MangaStyle.isActive
            || PetWhiteStyle.isActive
            || MujiStyle.isActive
            || NeumorphicStyle.isActive
            || SignalStyle.isActive
            || SequoiaStyle.isActive
            || CapsuleStyle.isActive
    }

    var themedSearchResultRowsSpacing: CGFloat {
        return themedSearchResultRowsActive ? 6 : 0
    }

    var searchResultRowHorizontalPadding: CGFloat {
        return themedSearchResultRowsActive ? 14 : DeviceLayout.viewHorizontalPadding
    }

    var searchResultRowVerticalPadding: CGFloat {
        return themedSearchResultRowsActive ? 12 : 10
    }

    var searchResultOuterHorizontalPadding: CGFloat {
        return themedSearchResultRowsActive ? DeviceLayout.viewHorizontalPadding : 0
    }

    var searchResultOuterVerticalPadding: CGFloat {
        if MujiStyle.isActive { return 0 }
        return themedSearchResultRowsActive ? 6 : 0
    }

    var searchResultCoverCornerRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if PetWhiteStyle.isActive { return 16 }
        if MujiStyle.isActive { return 10 }
        if CapsuleStyle.isActive { return 17 }
        if NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive { return 15 }
        return 12
    }

    var searchResultPlaceholderFill: Color {
        if MangaStyle.isActive { return MangaStyle.surface }
        if PetWhiteStyle.isActive { return PetWhiteStyle.surfacePressed }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SignalStyle.isActive { return SignalStyle.controlPressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceRaised }
        return Color.monoSeparator
    }

    var searchResultImageStrokeColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.85) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.stroke.opacity(0.62) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.55) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.42) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(0.62) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.78) }
        if CapsuleStyle.isActive { return CapsuleStyle.separator.opacity(0.46) }
        return .clear
    }

    var searchResultImageStrokeWidth: CGFloat {
        return themedSearchResultRowsActive ? 0.7 : 0
    }

    var searchResultTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(15.5, weight: .black) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(15.5, weight: .semibold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(16, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(16, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.bodyFont(16, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(15, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(15.5, weight: .bold) }
        return .rounded(size: 16, weight: .medium)
    }

    var searchResultTitleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    var searchResultMetaFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(12, weight: .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(12, weight: .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(12, weight: .semibold) }
        return .rounded(size: 12, weight: .regular)
    }

    var searchResultMetaColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        return .monoTextSecondary
    }

    var searchResultChevronColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        return .monoTextSecondary.opacity(0.5)
    }

    @ViewBuilder
    var searchResultRowBackground: some View {
        if MangaStyle.isActive {
            // 周刊印刷：无卡片，行底一根细规则线
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(MangaStyle.strokeInk.opacity(0.16))
                    .frame(height: 1)
                    .padding(.horizontal, 6)
            }
        } else if PetWhiteStyle.isActive {
            PetWhiteSurfaceBackground(
                cornerRadius: PetWhiteStyle.cardRadius,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised.opacity(0.88),
                accent: PetWhiteStyle.sky
            )
        } else if MujiStyle.isActive {
            // Muji：无卡片，行间一道针脚
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                MujiListDivider()
                    .padding(.horizontal, 6)
            }
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
        } else if SignalStyle.isActive {
            SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.paper)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(cornerRadius: 20, elevated: true, tint: CapsuleStyle.surface.opacity(0.9))
        }
    }

    @ViewBuilder
    var neteaseResultsContent: some View {
        switch viewModel.currentTab {
        case .songs:
            expandedSongsList(source: .netease)
        case .artists:
            ForEach(Array(viewModel.neteaseArtistResults.enumerated()), id: \.element.id) { index, artist in
                artistRow(artist: artist)
                    .onAppear {
                        if index == viewModel.neteaseArtistResults.count - 3 {
                            viewModel.loadMore(source: .netease)
                        }
                    }
            }
        case .playlists:
            ForEach(Array(viewModel.neteasePlaylistResults.enumerated()), id: \.element.id) { index, playlist in
                playlistRow(playlist: playlist)
                    .onAppear {
                        if index == viewModel.neteasePlaylistResults.count - 3 {
                            viewModel.loadMore(source: .netease)
                        }
                    }
            }
        case .albums:
            ForEach(Array(viewModel.neteaseAlbumResults.enumerated()), id: \.element.id) { index, album in
                albumRow(album: album)
                    .onAppear {
                        if index == viewModel.neteaseAlbumResults.count - 3 {
                            viewModel.loadMore(source: .netease)
                        }
                    }
            }
        case .mvs:
            let columns = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
            LazyVGrid(columns: columns, spacing: 22) {
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

    @ViewBuilder
    var qqResultsContent: some View {
        switch viewModel.currentTab {
        case .songs:
            expandedSongsList(source: .qqmusic)
        case .artists:
            ForEach(Array(viewModel.qqArtistResults.enumerated()), id: \.element.id) { index, artist in
                artistRow(artist: artist)
                    .onAppear {
                        if index == viewModel.qqArtistResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        case .playlists:
            ForEach(Array(viewModel.qqPlaylistResults.enumerated()), id: \.element.id) { index, playlist in
                playlistRow(playlist: playlist)
                    .onAppear {
                        if index == viewModel.qqPlaylistResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        case .albums:
            ForEach(Array(viewModel.qqAlbumResults.enumerated()), id: \.element.id) { index, album in
                albumRow(album: album)
                    .onAppear {
                        if index == viewModel.qqAlbumResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        case .mvs:
            let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(viewModel.qqMVResults.enumerated()), id: \.element.id) { index, mv in
                    qqMVGridCard(mv: mv)
                        .onAppear {
                            if index == viewModel.qqMVResults.count - 3 {
                                viewModel.loadMore(source: .qqmusic)
                            }
                        }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    var qishuiResultsContent: some View {
        if viewModel.currentTab == .songs {
            expandedSongsList(source: .qishui)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    var kugouResultsContent: some View {
        switch viewModel.currentTab {
        case .songs:
            expandedSongsList(source: .kugou)
        case .artists:
            platformRows(viewModel.kugouArtistResults, source: .kugou) { artistRow(artist: $0) }
        case .playlists:
            platformRows(viewModel.kugouPlaylistResults, source: .kugou) { playlistRow(playlist: $0) }
        case .albums:
            platformRows(viewModel.kugouAlbumResults, source: .kugou) { albumRow(album: $0) }
        case .mvs:
            let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(viewModel.kugouMVResults.enumerated()), id: \.element.id) { index, mv in
                    kcmMVGridCard(mv: mv)
                        .onAppear {
                            if index >= max(viewModel.kugouMVResults.count - 3, 0) {
                                viewModel.loadMore(source: .kugou)
                            }
                        }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    var appleMusicResultsContent: some View {
        switch viewModel.currentTab {
        case .songs:
            expandedSongsList(source: .appleMusic)
        case .artists:
            platformRows(viewModel.appleMusicArtistResults, source: .appleMusic) { artistRow(artist: $0) }
        case .playlists:
            platformRows(viewModel.appleMusicPlaylistResults, source: .appleMusic) { playlistRow(playlist: $0) }
        case .albums:
            platformRows(viewModel.appleMusicAlbumResults, source: .appleMusic) { albumRow(album: $0) }
        case .mvs:
            EmptyView()
        }
    }

    func platformRows<Item: Identifiable, Row: View>(
        _ items: [Item],
        source: MusicSource,
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            row(item)
                .onAppear {
                    if index >= max(items.count - 3, 0) {
                        viewModel.loadMore(source: source)
                    }
                }
        }
    }

    // MARK: - (旧双列代码已移除，改为标签页模式)

}
