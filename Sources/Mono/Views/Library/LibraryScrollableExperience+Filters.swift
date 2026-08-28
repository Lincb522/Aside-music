import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

extension ScrollableLibraryExperience {
    var qqChartsContent: some View {
        Group {
            if viewModel.isLoadingQQCharts && viewModel.qqTopLists.isEmpty {
                LibraryLoadingStateView()
            } else if viewModel.qqTopLists.isEmpty {
                ThemedLibraryEmptyState(icon: .chart, title: String(localized: "暂无QCM排行榜"), tint: MusicSource.qqmusic.themedBadgeColor)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                ForEach(viewModel.qqTopLists) { group in
                    ThemedLibrarySectionHeader(title: group.groupName)

                    if group.groupId == 0 || group.items.count <= 4 {
                        ScrollView(.horizontal) {
                            HStack(spacing: 14) {
                                ForEach(group.items) { item in
                                    NavigationLink(value: qqChartDestination(item)) {
                                        QQOfficialChartCard(item: item)
                                    }
                                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                                }
                            }
                            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                        }
                        .scrollIndicators(.hidden)
                        .themeRenderScrollLayer()
                    } else {
                        LazyVGrid(columns: artistColumns, spacing: 16) {
                            ForEach(group.items) { item in
                                NavigationLink(value: qqChartDestination(item)) {
                                    QQChartCard(item: item)
                                }
                                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                            }
                        }
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    }
                }
            }
        }
    }

    var ncmCategoryBar: some View {
        horizontalFilterBar {
            ForEach(viewModel.playlistCategories, id: \.idString) { category in
                filterChip(title: category.name, selected: viewModel.selectedCategory == category.name, tint: MusicSource.netease.themedBadgeColor) {
                    viewModel.selectedCategory = category.name
                    viewModel.loadSquarePlaylists(cat: category.name, reset: true)
                }
            }
        }
    }

    var qqCategoryBar: some View {
        horizontalFilterBar {
            ForEach(filteredQQCategories, id: \.id) { category in
                filterChip(title: category.name, selected: viewModel.selectedQQCategoryId == category.id, tint: MusicSource.qqmusic.themedBadgeColor) {
                    viewModel.selectQQCategory(id: category.id, name: category.name)
                }
            }
        }
    }

    var kugouCategoryBar: some View {
        horizontalFilterBar {
            ForEach(viewModel.kugouPlaylistCategories) { category in
                filterChip(title: category.name, selected: viewModel.selectedKugouCategoryID == category.id, tint: MusicSource.kugou.themedBadgeColor) {
                    viewModel.selectKugouCategory(category)
                }
            }
        }
    }

    var filteredQQCategories: [(id: Int, name: String)] {
        let hidden: Set<String> = [String(localized: "filter_all"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")]
        return viewModel.qqPlaylistCategories.filter { !hidden.contains($0.name.lowercased()) }
    }

    var ncmArtistFilterBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            horizontalFilterBar {
                ForEach(viewModel.artistAreas, id: \.value) { area in
                    filterChip(title: NSLocalizedString(area.name, comment: ""), selected: viewModel.artistArea == area.value, tint: tertiaryAccent) {
                        viewModel.artistArea = area.value
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.artistTypes, id: \.value) { type in
                    filterChip(title: NSLocalizedString(type.name, comment: ""), selected: viewModel.artistType == type.value, tint: secondaryAccent) {
                        viewModel.artistType = type.value
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.artistInitials, id: \.self) { initial in
                    filterChip(title: initial == "-1" ? NSLocalizedString("search_hot", comment: "") : initial, selected: viewModel.artistInitial == initial, tint: defaultAccent) {
                        viewModel.artistInitial = initial
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
        }
    }

    var qqArtistFilterBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            horizontalFilterBar {
                ForEach(viewModel.qqArtistAreas, id: \.value) { area in
                    filterChip(title: NSLocalizedString(area.name, comment: ""), selected: viewModel.qqArtistArea == area.value, tint: MusicSource.qqmusic.themedBadgeColor) {
                        viewModel.qqArtistArea = area.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.qqArtistSexes, id: \.value) { sex in
                    filterChip(title: NSLocalizedString(sex.name, comment: ""), selected: viewModel.qqArtistSex == sex.value, tint: defaultAccent) {
                        viewModel.qqArtistSex = sex.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.qqArtistGenres, id: \.value) { genre in
                    filterChip(title: NSLocalizedString(genre.name, comment: ""), selected: viewModel.qqArtistGenre == genre.value, tint: tertiaryAccent) {
                        viewModel.qqArtistGenre = genre.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
        }
    }

    var kugouArtistFilterBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            horizontalFilterBar {
                ForEach(viewModel.kugouArtistTypes, id: \.value) { type in
                    filterChip(title: NSLocalizedString(type.name, comment: ""), selected: viewModel.kugouArtistType == type.value, tint: MusicSource.kugou.themedBadgeColor) {
                        viewModel.kugouArtistType = type.value
                        viewModel.fetchKugouArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.kugouArtistSexes, id: \.value) { sex in
                    filterChip(title: NSLocalizedString(sex.name, comment: ""), selected: viewModel.kugouArtistSex == sex.value, tint: tertiaryAccent) {
                        viewModel.kugouArtistSex = sex.value
                        viewModel.fetchKugouArtistData(reset: true)
                    }
                }
            }
        }
    }

    var appleMusicArtistFilterBar: some View {
        horizontalFilterBar {
            ForEach(Array(viewModel.appleMusicArtistCategories.enumerated()), id: \.offset) { index, category in
                filterChip(title: NSLocalizedString(category.name, comment: ""), selected: viewModel.appleMusicArtistCategory == index, tint: MusicSource.appleMusic.themedBadgeColor) {
                    viewModel.selectAppleMusicArtistCategory(index)
                }
            }
        }
    }

    func playlistGrid(playlists: [Playlist], isLoading: Bool, emptyTitle: String) -> some View {
        Group {
            if isLoading && playlists.isEmpty {
                LibraryLoadingStateView()
            } else if playlists.isEmpty {
                ThemedLibraryEmptyState(icon: .list, title: emptyTitle, tint: defaultAccent)
                    .padding(.horizontal, contentHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            if NeumorphicStyle.isActive {
                                NeumorphicPlaylistPoster(
                                    playlist: playlist,
                                    tint: playlistSourceTint(playlist)
                                )
                            } else if SequoiaStyle.isActive {
                                SequoiaLibraryPlaylistTile(
                                    playlist: playlist,
                                    tint: playlistSourceTint(playlist)
                                )
                            } else if PetWhiteStyle.isActive {
                                PetWhiteLibraryPlaylistCard(
                                    playlist: playlist,
                                    tint: playlistSourceTint(playlist)
                                )
                            } else {
                                CinematicCard(playlist: playlist, height: 168)
                            }
                        }
                        .buttonStyle(CinematicPressStyle())
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
            }
        }
    }

    func playlistSourceTint(_ playlist: Playlist) -> Color {
        switch playlist.source {
        case .qqmusic:
            return MusicSource.qqmusic.themedBadgeColor
        case .kugou:
            return MusicSource.kugou.themedBadgeColor
        case .appleMusic:
            return MusicSource.appleMusic.themedBadgeColor
        default:
            return MusicSource.netease.themedBadgeColor
        }
    }

    func artistGrid(artists: [ArtistInfo], isLoading: Bool, tint: Color) -> some View {
        Group {
            if isLoading && artists.isEmpty {
                LibraryLoadingStateView()
            } else if artists.isEmpty {
                ThemedLibraryEmptyState(icon: .personEmpty, title: String(localized: "empty_no_artists"), tint: tint)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVGrid(columns: artistColumns, spacing: 18) {
                    ForEach(artists) { artist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                            ThemedLibraryArtistCard(artist: artist, tint: tint)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    func sourceStrip(
        selected: LibraryViewModel.MusicSource,
        sources: [LibraryViewModel.MusicSource] = LibraryViewModel.MusicSource.allCases,
        onSelect: @escaping (LibraryViewModel.MusicSource) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(sources, id: \.self) { source in
                let isSelected = selected == source
                let tint: Color = {
                    switch source {
                    case .ncm: return MusicSource.netease.themedBadgeColor
                    case .qq: return MusicSource.qqmusic.themedBadgeColor
                    case .kugou: return MusicSource.kugou.themedBadgeColor
                    case .appleMusic: return MusicSource.appleMusic.themedBadgeColor
                    }
                }()
                let title = source.shortName
                Button {
                    guard !isSelected else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        onSelect(source)
                    }
                } label: {
                    if NeumorphicStyle.isActive {
                        HStack(spacing: 7) {
                            MonoIcon(icon: source == .appleMusic ? .musicNote : (source == .ncm ? .musicNoteList : .library), size: 13, color: isSelected ? tint : secondaryText, lineWidth: 1.65)
                            Text(title)
                                .font(chipFont(selected: isSelected))
                                .foregroundColor(isSelected ? primaryText : secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(chipBackground(selected: isSelected, tint: tint, capsule: false))
                    } else {
                        Text(title)
                            .font(chipFont(selected: isSelected))
                            .foregroundColor(isSelected ? selectedChipText : secondaryText)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(chipBackground(selected: isSelected, tint: tint, capsule: false))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(panelBackground(cornerRadius: 18))
    }

    func horizontalFilterBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                content()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.top, 2)
            .padding(.bottom, 6) // Extra padding to accommodate stroke overflow + bottom shadow (y: 3)
        }
        .padding(.top, -2)
        .padding(.bottom, -6) // Offset layout spacing
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    func filterChip(title: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            guard !selected else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                action()
            }
        } label: {
            HStack(spacing: 7) {
                if NeumorphicStyle.isActive {
                    Circle()
                        .fill(selected ? tint : tint.opacity(0.42))
                        .frame(width: 6, height: 6)
                }

                Text(title)
                    .font(chipFont(selected: selected))
                    .foregroundColor(selected ? selectedChipText : secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(chipBackground(selected: selected, tint: tint, capsule: false))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
    }

    func actionChip(title: String, icon: MonoIcon.IconType, tint: Color, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                        .scaleEffect(0.68)
                        .frame(width: 14, height: 14)
                } else if PetWhiteStyle.isActive {
                    PetWhitePackIcon(
                        icon: icon,
                        size: 15,
                        visualScale: 1.06,
                        fallbackColor: tint,
                        lineWidth: 1.7
                    )
                } else {
                    MonoIcon(icon: icon, size: 14, color: tint, lineWidth: 1.7)
                }

                Text(title)
                    .font(chipFont(selected: true))
                    .foregroundColor(primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .background(chipBackground(selected: false, tint: tint, capsule: false))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
    }

    func loadMoreButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey("查看更多"))
                .font(chipFont(selected: true))
                .foregroundColor(selectedChipText)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(chipBackground(selected: true, tint: defaultAccent, capsule: false))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, 4)
    }

}
