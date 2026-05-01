import SwiftUI

// MARK: - SearchView

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedPlaylist: Playlist?
    @State private var showPlaylistDetail = false
    @State private var selectedMVId: MVIdItem?
    @State private var selectedAlbumId: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var showAlbumDetail = false
    @FocusState private var isFocused: Bool
    @State private var isSearchBarExpanded: Bool = true

    // qcm详情导航
    @State private var qqDetailType: QQDetailType?
    @State private var showQQDetail = false
    @State private var selectedQQMV: QQMVVidItem?
    @State private var isSearchSelectMode = false
    @State private var searchSelectedIds: Set<Int> = []
    @State private var showSearchBatchPlaylist = false
    @State private var searchFilterText = ""
    @State private var isSearchFiltering = false
    @Namespace private var sequoiaSearchNamespace

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            searchRootContent
                .iPadContentWidth()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showPlaylistDetail) {
            if let playlist = selectedPlaylist {
                PlaylistDetailView(playlist: playlist, songs: nil)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showQQDetail) {
            if let detail = qqDetailType {
                QQMusicDetailView(detailType: detail)

            } else {
                EmptyView()
            }
        }
        .fullScreenCover(item: $selectedMVId) { item in
            MVPlayerView(mvId: item.id)
        }
        .fullScreenCover(item: $selectedQQMV) { item in
            QQMVPlayerView(vid: item.vid)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private var searchRootContent: some View {
        if viewModel.hasSearched {
            ZStack {
                searchContentView
                suggestionsOverlay
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if MangaStyle.isActive {
                    mangaSearchHeader
                } else if NeumorphicStyle.isActive {
                    neumorphicSearchHeader
                } else if SignalStyle.isActive {
                    signalSearchHeader
                } else if MujiStyle.isActive {
                    mujiSearchHeader
                } else if SequoiaStyle.isActive {
                    sequoiaSearchHeader
                }

                searchBarSection

                ZStack {
                    searchContentView
                    suggestionsOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 搜索栏

    private var mangaSearchHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow)

            VStack(alignment: .leading, spacing: 4) {
                MangaLabel(text: "SEARCH", tint: MangaStyle.labelYellow, small: true)

                Text(String(localized: "搜索"))
                    .font(MangaStyle.comicFont(26, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 10)
    }

    private var mujiSearchHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Text(String(localized: "搜索"))
                .font(MujiStyle.titleFont(24, weight: .regular))
                .foregroundStyle(MujiStyle.ink)

            Rectangle()
                .fill(MujiStyle.separator)
                .frame(height: 0.6)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 2)
        .padding(.bottom, 8)
    }

    private var neumorphicSearchHeader: some View {
        NeumorphicPageHeader(
            eyebrow: "SEARCH",
            title: String(localized: "搜索"),
            subtitle: ""
        ) {
            NeumorphicIconBadge(icon: .magnifyingGlass, tint: NeumorphicStyle.accent, size: 46)
        }
        .padding(.bottom, 2)
    }

    private var signalSearchHeader: some View {
        SignalPageHeader(
            eyebrow: "SEARCH",
            title: String(localized: "搜索"),
            subtitle: ""
        ) {
            SignalIconBadge(icon: .magnifyingGlass, tint: SignalStyle.accent, size: 46)
        }
        .padding(.bottom, 2)
    }

    private var sequoiaSearchHeader: some View {
        SequoiaPageHeader(
            eyebrow: "Search",
            title: String(localized: "搜索"),
            subtitle: ""
        ) {
            SequoiaIconBadge(icon: .magnifyingGlass, tint: SequoiaStyle.accent, size: 42)
        }
        .padding(.bottom, 2)
    }

    private var searchBarSection: some View {
        let showFullSearch = isSearchBarExpanded
        let searchRadius: CGFloat = MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : (NeumorphicStyle.isActive ? (showFullSearch ? 18 : 20) : (SignalStyle.isActive ? (showFullSearch ? 20 : 22) : (SequoiaStyle.isActive ? (showFullSearch ? 16 : 18) : (showFullSearch ? 16 : 21)))))

        return HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                searchBackButtonLabel
            }
            .buttonStyle(PlainButtonStyle())

            if !showFullSearch {
                Spacer(minLength: 0)
            }

            HStack(spacing: showFullSearch ? 8 : 0) {
                MonologueIcon(icon: .magnifyingGlass, size: 18, color: searchIconColor)

                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        if viewModel.query.isEmpty, viewModel.hasSearched, !viewModel.displayKeyword.isEmpty {
                            Text(viewModel.displayKeyword)
                                .font(searchFieldFont(weight: .medium))
                                .foregroundColor(searchPlaceholderColor)
                                .lineLimit(1)
                        } else if viewModel.query.isEmpty, let defaultKw = viewModel.defaultKeyword {
                            Text(defaultKw.showKeyword)
                                .font(searchFieldFont(weight: .medium))
                                .foregroundColor(searchPlaceholderColor)
                                .lineLimit(1)
                                .onTapWithHaptic {
                                    viewModel.performSearch(keyword: defaultKw.realkeyword)
                                    isFocused = false
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchBarExpanded = false
                                    }
                                }
                        }

                        TextField("", text: $viewModel.query)
                            .foregroundColor(searchTextColor)
                            .font(searchFieldFont(weight: .medium))
                            .monologueTextInputBehavior()
                            .focused($isFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                if !viewModel.query.isEmpty {
                                    viewModel.performSearch(keyword: viewModel.query)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchBarExpanded = false
                                    }
                                } else if viewModel.hasSearched {
                                    isFocused = false
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchBarExpanded = false
                                    }
                                } else if let defaultKw = viewModel.defaultKeyword {
                                    viewModel.performSearch(keyword: defaultKw.realkeyword)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchBarExpanded = false
                                    }
                                }
                            }
                    }

                    if showFullSearch {
                        Button(action: {
                            if viewModel.query.isEmpty {
                                isFocused = false
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isSearchBarExpanded = false
                                }
                            } else {
                                viewModel.query = ""
                            }
                        }) {
                            MonologueIcon(icon: .xmark, size: 18, color: searchIconColor)
                        }
                        .padding(.leading, 8)
                    }
                }
                .frame(maxWidth: showFullSearch ? .infinity : 0)
                .opacity(showFullSearch ? 1 : 0)
                .clipped()
            }
            .padding(.horizontal, showFullSearch ? 16 : 12)
            .padding(.vertical, viewModel.hasSearched ? (NeumorphicStyle.isActive ? 7 : 8) : (showFullSearch ? (SequoiaStyle.isActive ? 9 : 10) : 12))
            .background(
                Group {
                    if MangaStyle.isActive {
                        MangaCardBackground(cornerRadius: searchRadius, elevated: true)
                    } else if MujiStyle.isActive {
                        MujiPaperCardBackground(cornerRadius: searchRadius, elevated: true)
                    } else if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: searchRadius, elevated: true)
                    } else if SignalStyle.isActive {
                        SignalSurfaceBackground(cornerRadius: searchRadius, elevated: true, fill: SignalStyle.device)
                    } else if SequoiaStyle.isActive {
                        SequoiaSurfaceBackground(cornerRadius: searchRadius, elevated: true, fill: SequoiaStyle.materialChrome)
                    }
                }
            )
            .liquidGlassStyle(cornerRadius: searchRadius)
            .onTapGesture {
                if !showFullSearch {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSearchBarExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isFocused = true
                    }
                }
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, viewModel.hasSearched ? 0 : (ThemedPageStyle.isActive ? 0 : 4))
        .padding(.bottom, viewModel.hasSearched ? (NeumorphicStyle.isActive ? 3 : 6) : (ThemedPageStyle.isActive ? 12 : 6))
        .onChange(of: viewModel.hasSearched) { searched in
            if !searched {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearchBarExpanded = true
                }
            }
        }
    }

    private var searchBackButtonLabel: some View {
        let radius: CGFloat = MangaStyle.isActive ? MangaStyle.buttonRadius : (NeumorphicStyle.isActive ? 16 : (SignalStyle.isActive ? 17 : (SequoiaStyle.isActive ? 15 : 21)))
        let fill = MangaStyle.isActive ? MangaStyle.surface : (MujiStyle.isActive ? MujiStyle.surface : (NeumorphicStyle.isActive ? NeumorphicStyle.surfaceRaised : (SignalStyle.isActive ? SignalStyle.control : (SequoiaStyle.isActive ? SequoiaStyle.materialRaised : Color.monologueTextPrimary.opacity(0.04)))))
        let stroke = MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.hairline.opacity(0.5) : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.4) : (SignalStyle.isActive ? SignalStyle.separator.opacity(0.72) : (SequoiaStyle.isActive ? SequoiaStyle.separator : Color.monologueTextPrimary.opacity(0.05)))))

        return MonologueIcon(icon: .back, size: 18, color: SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)), lineWidth: 1.8)
            .frame(width: 42, height: 42)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(stroke, lineWidth: MangaStyle.isActive ? MangaStyle.strokeWidth : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var searchIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .gray
    }

    private var searchPlaceholderColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        return .monologueTextSecondary.opacity(0.6)
    }

    private var searchTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private func searchFieldFont(weight: Font.Weight) -> Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(15, weight: weight == .bold ? .bold : .medium) }
        if MujiStyle.isActive { return MujiStyle.labelFont(15, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(15, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(15, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: .regular) }
        return .rounded(size: 16, weight: .medium)
    }

    // MARK: - 搜索类型 Tab 栏

    @ViewBuilder
    private var searchTabBar: some View {
        if MangaStyle.isActive {
            mangaSearchTabBar
        } else if NeumorphicStyle.isActive {
            neumorphicSearchTabBar
        } else if SignalStyle.isActive {
            signalSearchTabBar
        } else if MujiStyle.isActive {
            mujiSearchTabBar
        } else if SequoiaStyle.isActive {
            sequoiaSearchTabBar
        } else {
            GeometryReader { proxy in
                let spacing: CGFloat = 8
                let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

                HStack(spacing: spacing) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Button(action: {
                            viewModel.switchTab(tab)
                        }) {
                            VStack(spacing: 6) {
                                Text(tab.rawValue)
                                    .font(.rounded(size: 15, weight: viewModel.currentTab == tab ? .bold : .medium))
                                    .foregroundColor(viewModel.currentTab == tab ? .monologueTextPrimary : .monologueTextSecondary)
                                    .animation(.none, value: viewModel.currentTab)

                                Capsule()
                                    .fill(Color.monologueTextPrimary)
                                    .frame(width: 24, height: 3)
                                    .opacity(viewModel.currentTab == tab ? 1 : 0)
                            }
                            .frame(width: itemWidth, height: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 8)
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentTab)
        }
    }

    private var mujiSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        Text(tab.rawValue)
                            .font(MujiStyle.labelFont(13, weight: viewModel.currentTab == tab ? .semibold : .regular))
                            .foregroundStyle(viewModel.currentTab == tab ? MujiStyle.onTint : MujiStyle.inkSoft)
                            .frame(width: itemWidth)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(viewModel.currentTab == tab ? MujiStyle.ink : MujiStyle.surface.opacity(0.74))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(viewModel.currentTab == tab ? Color.clear : MujiStyle.hairline.opacity(0.44), lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 4 : 8)
        }
        .frame(height: viewModel.hasSearched ? 44 : 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var neumorphicSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = viewModel.hasSearched ? 7 : 8
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        HStack(spacing: viewModel.hasSearched ? 0 : 6) {
                            if !viewModel.hasSearched {
                                MonologueIcon(
                                    icon: searchTabIcon(tab),
                                    size: 12,
                                    color: selected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft,
                                    lineWidth: 1.55
                                )
                            }

                            Text(tab.rawValue)
                                .font(NeumorphicStyle.labelFont(viewModel.hasSearched ? 11.5 : 12.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 9)
                        .background(
                            NeumorphicSurfaceBackground(
                                cornerRadius: viewModel.hasSearched ? 12 : 15,
                                elevated: selected,
                                pressed: !selected,
                                tint: selected ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 8)
        }
        .frame(height: viewModel.hasSearched ? 40 : 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signalSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = viewModel.hasSearched ? 7 : 8
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        HStack(spacing: viewModel.hasSearched ? 0 : 6) {
                            if !viewModel.hasSearched {
                                MonologueIcon(
                                    icon: searchTabIcon(tab),
                                    size: 12,
                                    color: selected ? SignalStyle.accent : SignalStyle.inkSoft,
                                    lineWidth: 1.6
                                )
                            }

                            Text(tab.rawValue)
                                .font(SignalStyle.labelFont(viewModel.hasSearched ? 11.5 : 12.5, weight: selected ? .bold : .semibold))
                                .foregroundStyle(selected ? SignalStyle.ink : SignalStyle.inkSoft)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 9)
                        .background(
                            SignalSurfaceBackground(
                                cornerRadius: viewModel.hasSearched ? 13 : 16,
                                elevated: selected,
                                pressed: !selected,
                                fill: selected ? SignalStyle.accent.opacity(0.14) : SignalStyle.control
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 8)
        }
        .frame(height: viewModel.hasSearched ? 40 : 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sequoiaSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = viewModel.hasSearched ? 5 : 6
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        HStack(spacing: viewModel.hasSearched ? 0 : 6) {
                            if !viewModel.hasSearched {
                                MonologueIcon(
                                    icon: searchTabIcon(tab),
                                    size: 12,
                                    color: selected ? SequoiaStyle.accent : SequoiaStyle.inkSoft,
                                    lineWidth: 1.5
                                )
                            }

                            Text(tab.rawValue)
                                .font(SequoiaStyle.labelFont(viewModel.hasSearched ? 11.5 : 12.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 9)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: viewModel.hasSearched ? 11 : 14, style: .continuous)
                                    .fill(SequoiaStyle.selectedWash)
                                    .matchedGeometryEffect(id: "search-tab", in: sequoiaSearchNamespace)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: viewModel.hasSearched ? 11 : 14, style: .continuous)
                                            .stroke(SequoiaStyle.accent.opacity(0.24), lineWidth: 0.56)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(SequoiaSurfaceBackground(cornerRadius: viewModel.hasSearched ? 15 : 18, elevated: true, role: .chrome))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 7)
        }
        .frame(height: viewModel.hasSearched ? 48 : 58)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mangaSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        Text(tab.rawValue)
                            .font(MangaStyle.labelFont(13, weight: viewModel.currentTab == tab ? .black : .bold))
                            .foregroundStyle(MangaStyle.ink)
                            .frame(width: itemWidth)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(viewModel.currentTab == tab ? MangaStyle.labelYellow : MangaStyle.bubbleWhite)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(MangaStyle.strokeInk, lineWidth: viewModel.currentTab == tab ? MangaStyle.strokeWidth : MangaStyle.fineStrokeWidth)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(MangaStyle.strokeInk)
                                    .offset(x: viewModel.currentTab == tab ? 2 : 0, y: viewModel.currentTab == tab ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 8)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func searchTabItemWidth(totalWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = CGFloat(SearchTab.allCases.count)
        let horizontalPadding = DeviceLayout.viewHorizontalPadding * 2
        let totalSpacing = spacing * max(count - 1, 0)
        let available = max(totalWidth - horizontalPadding - totalSpacing, 0)
        return max(floor(available / count), 44)
    }

    // MARK: - 搜索内容区域

    @ViewBuilder
    private var searchContentView: some View {
        if viewModel.hasSearched {
            searchedResultsScrollView
        } else if viewModel.query.isEmpty {
            emptySearchView
        }
    }

    private var searchedResultsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                searchBarSection

                if NeumorphicStyle.isActive {
                    neumorphicResultConsole
                } else if SignalStyle.isActive {
                    signalResultConsole
                } else if SequoiaStyle.isActive {
                    sequoiaResultConsole
                }

                searchTabBar
                platformTabBar

                let platformLoading = isPlatformLoading
                let platformEmpty = isPlatformEmpty

                if platformLoading && platformEmpty {
                    searchLoadingState
                } else if platformEmpty {
                    searchEmptyState
                } else {
                    if viewModel.currentTab == .songs {
                        searchSongsToolbarView
                    }

                    platformResultsRows
                }

                FloatingBarBottomSpacer()
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .simultaneousGesture(DragGesture().onChanged { _ in
            isFocused = false
        })
    }

    private var neumorphicResultConsole: some View {
        HStack(spacing: 12) {
            NeumorphicIconBadge(icon: searchTabIcon(viewModel.currentTab), tint: NeumorphicStyle.accent, size: 38)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text("SEARCH")
                        .font(NeumorphicStyle.labelFont(9, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.accent)
                        .tracking(1.1)

                    Capsule()
                        .fill(NeumorphicStyle.separator.opacity(0.76))
                        .frame(width: 18, height: 1)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "搜索") : viewModel.displayKeyword)
                    .font(NeumorphicStyle.titleFont(19, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 6) {
                    neumorphicResultChip(text: platformTabName(viewModel.selectedPlatform), tint: viewModel.selectedPlatform.themedBadgeColor)
                    neumorphicResultChip(text: viewModel.currentTab.rawValue, tint: NeumorphicStyle.sage)
                }
            }

            Spacer(minLength: 8)

            Group {
                if isPlatformLoading {
                    ProgressView()
                        .tint(NeumorphicStyle.accent)
                        .scaleEffect(0.78)
                } else {
                    Text("\(selectedPlatformResultCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(NeumorphicStyle.accent)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 42, minHeight: 38)
            .padding(.horizontal, 6)
            .background(NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    private func neumorphicResultChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(NeumorphicStyle.labelFont(10, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.13))
            )
    }

    private var signalResultConsole: some View {
        HStack(spacing: 12) {
            SignalPulseDot(tint: SignalStyle.accent, size: 22)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(platformTabName(viewModel.selectedPlatform).uppercased())
                        .font(SignalStyle.monoFont(9, weight: .semibold))
                        .foregroundStyle(SignalStyle.accent)

                    signalResultChip(text: viewModel.currentTab.rawValue, tint: SignalStyle.violet)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "搜索") : viewModel.displayKeyword)
                    .font(SignalStyle.titleFont(19, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                SignalSearchGroove(tint: viewModel.selectedPlatform.themedBadgeColor)
            }

            Spacer(minLength: 8)

            Group {
                if isPlatformLoading {
                    ProgressView()
                        .tint(SignalStyle.accent)
                        .scaleEffect(0.78)
                } else {
                    Text("\(selectedPlatformResultCount)")
                        .font(SignalStyle.monoFont(15, weight: .semibold))
                        .foregroundStyle(SignalStyle.accent)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 42, minHeight: 38)
            .padding(.horizontal, 6)
            .background(SignalSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, fill: SignalStyle.control))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(SignalSurfaceBackground(cornerRadius: 24, elevated: true, fill: SignalStyle.device))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    private func signalResultChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(SignalStyle.labelFont(10, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.13)))
    }

    private struct SignalSearchGroove: View {
        let tint: Color

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(index < 8 ? tint.opacity(0.74) : SignalStyle.inkMuted.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3 + CGFloat(index % 4))
                }
            }
            .frame(maxWidth: 150)
        }
    }

    private var sequoiaResultConsole: some View {
        HStack(spacing: 12) {
            SequoiaIconBadge(icon: searchTabIcon(viewModel.currentTab), tint: viewModel.selectedPlatform.themedBadgeColor, size: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(platformTabName(viewModel.selectedPlatform).uppercased())
                        .font(SequoiaStyle.labelFont(9.5, weight: .semibold))
                        .foregroundStyle(viewModel.selectedPlatform.themedBadgeColor)
                        .tracking(0.8)

                    SequoiaPill(text: viewModel.currentTab.rawValue, tint: SequoiaStyle.aqua, selected: false, compact: true)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "搜索") : viewModel.displayKeyword)
                    .font(SequoiaStyle.titleFont(19, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                SequoiaMeter(tint: viewModel.selectedPlatform.themedBadgeColor, count: 14)
            }

            Spacer(minLength: 8)

            Group {
                if isPlatformLoading {
                    ProgressView()
                        .tint(SequoiaStyle.accent)
                        .scaleEffect(0.78)
                } else {
                    Text("\(selectedPlatformResultCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(SequoiaStyle.accent)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 44, minHeight: 38)
            .padding(.horizontal, 6)
            .background(SequoiaSurfaceBackground(cornerRadius: 14, elevated: false, role: .list))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var searchLoadingState: some View {
        if NeumorphicStyle.isActive {
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
                title: String(localized: "搜索中"),
                tint: SequoiaStyle.accent,
                loading: true
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 36)
            .frame(minHeight: 320, alignment: .top)
        } else {
            MonologueLoadingView(text: "SEARCHING")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 320)
        }
    }

    private var searchEmptyState: some View {
        emptyResultsView
            .padding(.horizontal, (NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? DeviceLayout.viewHorizontalPadding : 0)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 320)
    }

    private var neumorphicResultMetaText: String {
        "\(platformTabName(viewModel.selectedPlatform)) · \(viewModel.currentTab.rawValue)"
    }

    private var selectedPlatformResultCount: Int {
        resultCount(for: viewModel.selectedPlatform, tab: viewModel.currentTab)
    }

    private var suggestionsTopPadding: CGFloat {
        viewModel.hasSearched ? ((NeumorphicStyle.isActive || SignalStyle.isActive) ? 54 : 58) : 4
    }

    private func resultCount(for source: MusicSource, tab: SearchTab) -> Int {
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
        case .local:
            return 0
        }
    }

    private func searchTabIcon(_ tab: SearchTab) -> MonologueIcon.IconType {
        switch tab {
        case .songs: return .musicNote
        case .artists: return .profile
        case .playlists: return .musicNoteList
        case .albums: return .album
        case .mvs: return .mv
        }
    }

    private struct NeumorphicLoadingPanel: View {
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

    private struct SignalLoadingPanel: View {
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

    private func neumorphicSearchSongsToolbar(currentSource: MusicSource, currentSongs: [Song]) -> some View {
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: currentSongs,
                    onBatchQueue: {
                        let selected = currentSongs.filter { searchSelectedIds.contains($0.id) }
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
                            MonologueIcon(icon: .play, size: 12, color: Color(light: .white, dark: .black), lineWidth: 1.7)
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    .disabled(currentSongs.isEmpty)
                    .opacity(currentSongs.isEmpty ? 0.55 : 1)

                    Spacer(minLength: 8)

                    neumorphicToolbarButton(icon: .search, tint: NeumorphicStyle.accent) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFiltering = true
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

    private func neumorphicToolbarButton(
        icon: MonologueIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: true, lightweight: true))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
    }

    private func signalSearchSongsToolbar(currentSource: MusicSource, currentSongs: [Song]) -> some View {
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: currentSongs,
                    onBatchQueue: {
                        let selected = currentSongs.filter { searchSelectedIds.contains($0.id) }
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
                            MonologueIcon(icon: .play, size: 12, color: SignalStyle.onAccent, lineWidth: 1.75)
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    .disabled(currentSongs.isEmpty)
                    .opacity(currentSongs.isEmpty ? 0.55 : 1)

                    Spacer(minLength: 8)

                    signalToolbarButton(icon: .search, tint: SignalStyle.accent) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFiltering = true
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

    private func signalToolbarButton(
        icon: MonologueIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.65)
                .frame(width: 32, height: 32)
                .background(SignalSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, fill: SignalStyle.control))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
    }

    // MARK: - 歌曲列表工具栏

    @ViewBuilder
    private var searchSongsToolbarView: some View {
        let currentSource = viewModel.selectedPlatform
        let currentSongs = expandedFilteredSongs(source: currentSource)

        if NeumorphicStyle.isActive {
            neumorphicSearchSongsToolbar(currentSource: currentSource, currentSongs: currentSongs)
        } else if SignalStyle.isActive {
            signalSearchSongsToolbar(currentSource: currentSource, currentSongs: currentSongs)
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
                            let selected = currentSongs.filter { searchSelectedIds.contains($0.id) }
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
                                MonologueIcon(icon: .play, size: 14, color: Color(UIColor.systemBackground))
                                    .frame(width: 24, height: 24)
                                    .background(Color.monologueTextPrimary)
                                    .clipShape(Circle())

                                Text(String(localized: "artist_play_all"))
                                    .font(.rounded(size: 14, weight: .semibold))
                                    .foregroundColor(.monologueTextPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.monologueTextPrimary.opacity(0.04))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchFiltering = true
                            }
                        } label: {
                            MonologueIcon(icon: .search, size: 15, color: .monologueTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monologueTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchSelectMode = true
                                searchSelectedIds.removeAll()
                            }
                        } label: {
                            MonologueIcon(icon: .checkmark, size: 15, color: .monologueTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monologueTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - 平台标签页

    @ViewBuilder
    private var platformTabBar: some View {
        if MangaStyle.isActive {
            mangaPlatformTabBar
        } else if NeumorphicStyle.isActive {
            neumorphicPlatformTabBar
        } else if SignalStyle.isActive {
            signalPlatformTabBar
        } else if MujiStyle.isActive {
            mujiPlatformTabBar
        } else if SequoiaStyle.isActive {
            sequoiaPlatformTabBar
        } else {
            let platforms: [MusicSource] = viewModel.currentTab == .songs
                ? [.netease, .qqmusic, .qishui]
                : [.netease, .qqmusic]
            HStack(spacing: 0) {
                ForEach(platforms, id: \.self) { platform in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedPlatform = platform
                        }
                    }) {
                        let tint = platform.themedBadgeColor
                        Text(platformTabName(platform))
                            .font(.rounded(size: 13, weight: viewModel.selectedPlatform == platform ? .bold : .medium))
                            .foregroundColor(viewModel.selectedPlatform == platform ? tint : tint.opacity(0.72))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                viewModel.selectedPlatform == platform
                                    ? Capsule().fill(tint.opacity(0.12))
                                    : nil
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 4)
        }
    }

    private var mujiPlatformTabBar: some View {
        let platforms: [MusicSource] = viewModel.currentTab == .songs
            ? [.netease, .qqmusic, .qishui]
            : [.netease, .qqmusic]

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedPlatform = platform
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    Text(platformTabName(platform))
                        .font(MujiStyle.labelFont(11, weight: .semibold))
                        .foregroundStyle(viewModel.selectedPlatform == platform ? tint : tint.opacity(0.68))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(viewModel.selectedPlatform == platform ? tint.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(MujiStyle.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.6)
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 4 : 8)
    }

    private var neumorphicPlatformTabBar: some View {
        let platforms: [MusicSource] = viewModel.currentTab == .songs
            ? [.netease, .qqmusic, .qishui]
            : [.netease, .qqmusic]

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedPlatform = platform
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    Text(platformTabName(platform))
                        .font(NeumorphicStyle.labelFont(viewModel.hasSearched ? 10.5 : 11, weight: .semibold))
                        .foregroundStyle(selected ? tint : tint.opacity(0.68))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 8)
                        .background(
                            RoundedRectangle(cornerRadius: viewModel.hasSearched ? 8 : 10, style: .continuous)
                                .fill(selected ? tint.opacity(0.13) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(viewModel.hasSearched ? 4 : 5)
        .background(NeumorphicSurfaceBackground(cornerRadius: viewModel.hasSearched ? 13 : 15, elevated: false, pressed: true, lightweight: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 2 : 8)
    }

    private var signalPlatformTabBar: some View {
        let platforms: [MusicSource] = viewModel.currentTab == .songs
            ? [.netease, .qqmusic, .qishui]
            : [.netease, .qqmusic]

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedPlatform = platform
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    Text(platformTabName(platform))
                        .font(SignalStyle.labelFont(viewModel.hasSearched ? 10.5 : 11, weight: .bold))
                        .foregroundStyle(selected ? tint : tint.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 8)
                        .background(
                            RoundedRectangle(cornerRadius: viewModel.hasSearched ? 9 : 11, style: .continuous)
                                .fill(selected ? tint.opacity(0.14) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(viewModel.hasSearched ? 4 : 5)
        .background(SignalSurfaceBackground(cornerRadius: viewModel.hasSearched ? 14 : 16, elevated: false, pressed: true, fill: SignalStyle.controlPressed))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 2 : 8)
    }

    private var sequoiaPlatformTabBar: some View {
        let platforms: [MusicSource] = viewModel.currentTab == .songs
            ? [.netease, .qqmusic, .qishui]
            : [.netease, .qqmusic]

        return HStack(spacing: 6) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        viewModel.selectedPlatform = platform
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                        Text(platformTabName(platform))
                            .font(SequoiaStyle.labelFont(viewModel.hasSearched ? 10.5 : 11, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, viewModel.hasSearched ? 7 : 8)
                    .background {
                        if selected {
                            Capsule()
                                .fill(tint.opacity(0.13))
                                .matchedGeometryEffect(id: "platform-tab", in: sequoiaSearchNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(SequoiaSurfaceBackground(cornerRadius: viewModel.hasSearched ? 14 : 16, elevated: false, role: .list))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 3 : 8)
    }

    private var mangaPlatformTabBar: some View {
        let platforms: [MusicSource] = viewModel.currentTab == .songs
            ? [.netease, .qqmusic, .qishui]
            : [.netease, .qqmusic]

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedPlatform = platform
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    Text(platformTabName(platform))
                        .font(MangaStyle.labelFont(11, weight: .black))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(viewModel.selectedPlatform == platform ? tint.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(viewModel.selectedPlatform == platform ? MangaStyle.strokeInk : Color.clear, lineWidth: MangaStyle.fineStrokeWidth)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(MangaCardBackground(cornerRadius: 12, elevated: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    private func platformTabName(_ source: MusicSource) -> String {
        switch source {
        case .netease: return "NCM"
        case .qqmusic: return "QCM"
        case .qishui: return "QSM"
        case .local: return "Local"
        }
    }

    private var isPlatformLoading: Bool {
        switch viewModel.selectedPlatform {
        case .netease: return viewModel.isNeteaseLoading
        case .qqmusic: return viewModel.isQQLoading
        case .qishui: return viewModel.isQishuiLoading
        case .local: return false
        }
    }

    private var isPlatformEmpty: Bool {
        switch viewModel.selectedPlatform {
        case .netease:
            switch viewModel.currentTab {
            case .songs: return viewModel.neteaseResults.isEmpty
            case .artists: return viewModel.neteaseArtistResults.isEmpty
            case .playlists: return viewModel.neteasePlaylistResults.isEmpty
            case .albums: return viewModel.neteaseAlbumResults.isEmpty
            case .mvs: return viewModel.neteaseMVResults.isEmpty
            }
        case .qqmusic:
            switch viewModel.currentTab {
            case .songs: return viewModel.qqResults.isEmpty
            case .artists: return viewModel.qqArtistResults.isEmpty
            case .playlists: return viewModel.qqPlaylistResults.isEmpty
            case .albums: return viewModel.qqAlbumResults.isEmpty
            case .mvs: return viewModel.qqMVResults.isEmpty
            }
        case .qishui: return viewModel.qishuiResults.isEmpty
        case .local: return true
        }
    }

    // MARK: - 平台结果列表

    private var platformResultsView: some View {
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

    private var platformResultsRows: some View {
        LazyVStack(spacing: (NeumorphicStyle.isActive || SignalStyle.isActive) ? 2 : 0) {
            switch viewModel.selectedPlatform {
            case .netease:
                neteaseResultsContent
            case .qqmusic:
                qqResultsContent
            case .qishui:
                qishuiResultsContent
            case .local:
                EmptyView()
            }
        }
        .padding(.top, (NeumorphicStyle.isActive || SignalStyle.isActive) ? 2 : 0)
    }

    @ViewBuilder
    private var neteaseResultsContent: some View {
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
            let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 16) {
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
    private var qqResultsContent: some View {
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
    private var qishuiResultsContent: some View {
        if viewModel.currentTab == .songs {
            expandedSongsList(source: .qishui)
        } else {
            EmptyView()
        }
    }

    // MARK: - (旧双列代码已移除，改为标签页模式)

    // MARK: - 展开单平台全屏列表

    private func expandedResultsView(source: MusicSource) -> some View {
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
                            MonologueIcon(icon: .back, size: 16, color: .monologueTextPrimary)
                            Text(expandedSourceName(source))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
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
                            MonologueIcon(icon: .search, size: 15, color: .monologueTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monologueTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchSelectMode = true
                                searchSelectedIds.removeAll()
                            }
                        } label: {
                            MonologueIcon(icon: .checkmark, size: 15, color: .monologueTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monologueTextPrimary.opacity(0.06))
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

    private func expandedSourceName(_ source: MusicSource) -> String {
        switch source {
        case .netease: return String(localized: "search_platform_netease")
        case .qqmusic: return String(localized: "search_platform_qq")
        case .qishui: return "QSM"
        case .local: return "本地"
        }
    }

    private func expandedFilteredSongs(source: MusicSource) -> [Song] {
        let songs: [Song]
        switch source {
        case .netease: songs = viewModel.neteaseResults
        case .qqmusic: songs = viewModel.qqResults
        case .qishui: songs = viewModel.qishuiResults
        case .local: songs = []
        }
        return songs.filtered(by: searchFilterText)
    }

    private func expandedSongsList(source: MusicSource) -> some View {
        let allSongs: [Song] = {
            switch source {
            case .netease: return viewModel.neteaseResults
            case .qqmusic: return viewModel.qqResults
            case .qishui: return viewModel.qishuiResults
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
        .monologueSheet(isPresented: $showSearchBatchPlaylist, preset: .standard) {
            BatchAddToPlaylistSheet(songs: songs.filter { searchSelectedIds.contains($0.id) })
        }
    }

    private func searchLoadMoreFooter(source: MusicSource) -> some View {
        Button {
            viewModel.loadMore(source: source)
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingMore(source: source) {
                    ProgressView()
                        .scaleEffect(0.72)
                        .tint(source.themedBadgeColor)
                } else {
                    MonologueIcon(icon: .chevronRight, size: 12, color: source.themedBadgeColor, lineWidth: 1.7)
                }

                Text(String(localized: "加载更多"))
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

    private func searchBatchDownload(source: MusicSource) {
        let songs = expandedFilteredSongs(source: source)
        let selected = songs.filter { searchSelectedIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isSearchSelectMode = false; searchSelectedIds.removeAll() }
    }

    // MARK: - 展开歌手列表

    private func expandedArtistsList(source: MusicSource) -> some View {
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

    private func expandedPlaylistsList(source: MusicSource) -> some View {
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

    private func expandedAlbumsList(source: MusicSource) -> some View {
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

    private var expandedMVsList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
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

    // MARK: - 通用行组件

    private func artistRow(artist: ArtistInfo) -> some View {
        Button(action: {
            if artist.isQQMusic {
                let mid = artist.qqMid ?? "\(artist.id)"
                qqDetailType = .artist(mid: mid, name: artist.name, coverUrl: artist.coverUrl?.absoluteString)
                showQQDetail = true
            } else {
                selectedArtistId = artist.id
                showArtistDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                    Circle().fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SignalStyle.isActive ? SignalStyle.controlPressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueSeparator)))
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay {
                    if NeumorphicStyle.isActive {
                        Circle()
                            .stroke(NeumorphicStyle.separator.opacity(0.42), lineWidth: 0.7)
                    } else if SignalStyle.isActive {
                        Circle()
                            .stroke(SignalStyle.separator.opacity(0.62), lineWidth: 0.7)
                    } else if SequoiaStyle.isActive {
                        Circle()
                            .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(16, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.bodyFont(16, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .rounded(size: 16, weight: .medium))))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let albumSize = artist.albumSize, albumSize > 0 {
                            Text(String(format: String(localized: "search_album_count"), albumSize))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                        }
                        if let musicSize = artist.musicSize, musicSize > 0 {
                            Text(String(format: String(localized: "search_song_count"), musicSize))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                        }
                    }
                }

                Spacer()

                MonologueIcon(icon: .chevronRight, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.5))))
            }
            .padding(.horizontal, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? 14 : DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? 12 : 10)
            .background {
                if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 10)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.paper)
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
                }
            }
            .padding(.horizontal, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            .padding(.vertical, MujiStyle.isActive ? 5 : ((NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? 6 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func playlistRow(playlist: Playlist) -> some View {
        Button(action: {
            if playlist.isQQMusic {
                qqDetailType = .playlist(id: playlist.id, name: playlist.name, coverUrl: playlist.coverUrl?.absoluteString, creatorName: playlist.creator?.nickname)
                showQQDetail = true
            } else {
                selectedPlaylist = playlist
                showPlaylistDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: (NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? 15 : 12)
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SignalStyle.isActive ? SignalStyle.controlPressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueSeparator)))
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: (NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? 15 : 12, style: .continuous))
                .overlay {
                    if NeumorphicStyle.isActive {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.42), lineWidth: 0.7)
                    } else if SignalStyle.isActive {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(SignalStyle.separator.opacity(0.62), lineWidth: 0.7)
                    } else if SequoiaStyle.isActive {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(16, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.bodyFont(16, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .rounded(size: 16, weight: .medium))))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let trackCount = playlist.trackCount, trackCount > 0 {
                            Text(String(format: String(localized: "search_track_count"), trackCount))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                        }
                        if let creator = playlist.creator?.nickname {
                            Text("by \(creator)")
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                MonologueIcon(icon: .chevronRight, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.5))))
            }
            .padding(.horizontal, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? 14 : DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? 12 : 10)
            .background {
                if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 10)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.paper)
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
                }
            }
            .padding(.horizontal, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            .padding(.vertical, MujiStyle.isActive ? 5 : ((NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? 6 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func albumRow(album: SearchAlbum) -> some View {
        Button(action: {
            if album.isQQMusic {
                let mid = album.qqMid ?? "\(album.id)"
                qqDetailType = .album(mid: mid, name: album.name, coverUrl: album.coverUrl?.absoluteString, artistName: album.artistName)
                showQQDetail = true
            } else {
                selectedAlbumId = album.id
                showAlbumDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: album.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: (NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? 15 : 12)
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SignalStyle.isActive ? SignalStyle.controlPressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueSeparator)))
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: (NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? 15 : 12, style: .continuous))
                .overlay {
                    if NeumorphicStyle.isActive {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.42), lineWidth: 0.7)
                    } else if SignalStyle.isActive {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(SignalStyle.separator.opacity(0.62), lineWidth: 0.7)
                    } else if SequoiaStyle.isActive {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(16, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.bodyFont(16, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .rounded(size: 16, weight: .medium))))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(album.artistName)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                            .lineLimit(1)

                        if let size = album.size, size > 0 {
                            Text(String(format: String(localized: "search_track_count"), size))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12, weight: .regular))))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                        }
                    }
                }

                Spacer()

                MonologueIcon(icon: .chevronRight, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.5))))
            }
            .padding(.horizontal, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? 14 : DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? 12 : 10)
            .background {
                if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 10)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.paper)
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
                }
            }
            .padding(.horizontal, MujiStyle.isActive || NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            .padding(.vertical, MujiStyle.isActive ? 5 : ((NeumorphicStyle.isActive || SignalStyle.isActive || SequoiaStyle.isActive) ? 6 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func mvsResultList(mvs: [MV]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(mvs.prefix(4)) { mv in
                MVGridCard(mv: mv) {
                    selectedMVId = MVIdItem(id: mv.id)
                    isFocused = false
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - QQ MV 结果列表

    private func qqMVsResultList(mvs: [QQMV]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(mvs.prefix(4)) { mv in
                qqMVGridCard(mv: mv)
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - QQ MV 网格卡片

    private func qqMVGridCard(mv: QQMV) -> some View {
        Button(action: {
            selectedQQMV = QQMVVidItem(vid: mv.vid)
            isFocused = false
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.monologueTextSecondary.opacity(0.06))
                        }
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.monologueTextSecondary.opacity(0.06))
                            .frame(height: 100)
                            .aspectRatio(16 / 9, contentMode: .fit)
                    }

                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.clear).monologueGlass(cornerRadius: (NeumorphicStyle.isActive || SignalStyle.isActive) ? 12 : 16)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mv.name)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.bodyFont(14, weight: .semibold) : .rounded(size: 14, weight: .semibold)))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : .monologueTextPrimary))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(mv.singerName ?? String(localized: "search_unknown_artist"))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : .rounded(size: 12)))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : .monologueTextSecondary))
                            .lineLimit(1)

                        if !mv.playCountText.isEmpty {
                            Circle()
                                .fill((NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : Color.monologueTextSecondary)).opacity(0.3))
                                .frame(width: 3, height: 3)
                            Text(mv.playCountText + String(localized: "search_play_count_suffix"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(11, weight: .medium) : .rounded(size: 11)))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : .monologueTextSecondary.opacity(0.6)))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding((NeumorphicStyle.isActive || SignalStyle.isActive) ? 10 : 0)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 22, elevated: true, fill: SignalStyle.device)
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    // MARK: - 展开 QQ MV 列表

    private var expandedQQMVsList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
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

    // MARK: - 最佳匹配卡片

    private func bestMatchSection(match: SearchMultimatchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("search_best_match"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 10)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    if let artist = match.artist {
                        bestMatchCard(
                            imageUrl: artist.coverUrl?.sized(200),
                            title: artist.name,
                            subtitle: String(localized: "search_type_artist"),
                            isCircle: true
                        ) {
                            selectedArtistId = artist.id
                            showArtistDetail = true
                        }
                    }

                    if let album = match.album {
                        bestMatchCard(
                            imageUrl: album.coverUrl?.sized(200),
                            title: album.name,
                            subtitle: album.artistName,
                            isCircle: false
                        ) {
                            selectedAlbumId = album.id
                            showAlbumDetail = true
                        }
                    }

                    if let playlist = match.playlist {
                        bestMatchCard(
                            imageUrl: playlist.coverUrl?.sized(200),
                            title: playlist.name,
                            subtitle: playlist.creator?.nickname ?? "",
                            isCircle: false
                        ) {
                            selectedPlaylist = playlist
                            showPlaylistDetail = true
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .padding(.top, 4)
    }

    private func bestMatchCard(
        imageUrl: URL?,
        title: String,
        subtitle: String,
        isCircle: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: imageUrl) {
                    RoundedRectangle(cornerRadius: isCircle ? 25 : 10)
                        .fill(Color.monologueSeparator)
                }
                .frame(width: 50, height: 50)
                .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 10)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.rounded(size: 12))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                MonologueIcon(icon: .chevronRight, size: 14, color: .monologueTextSecondary.opacity(0.5))
            }
            .padding(12)
            .frame(width: 220)
            .background(
                Group {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.monologueGlassTint)
                            .monologueGlass(cornerRadius: 20)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    // MARK: - 空结果提示

    @ViewBuilder
    private var emptyResultsView: some View {
        if NeumorphicStyle.isActive {
            VStack(spacing: 14) {
                NeumorphicIconBadge(icon: .magnifyingGlass, tint: NeumorphicStyle.inkMuted, size: 52)

                Text(viewModel.displayKeyword)
                    .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(String(localized: "search_no_results"))
                    .font(NeumorphicStyle.labelFont(12, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 38)
            .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
        } else if SequoiaStyle.isActive {
            SequoiaSearchStatePanel(
                icon: .magnifyingGlass,
                title: viewModel.displayKeyword.isEmpty ? String(localized: "search_no_results") : viewModel.displayKeyword,
                subtitle: String(localized: "search_no_results"),
                tint: SequoiaStyle.inkMuted
            )
        } else {
            ContentUnavailableView.search(text: viewModel.displayKeyword)
        }
    }

    // MARK: - 搜索历史 & 热搜

    @ViewBuilder
    private var emptySearchView: some View {
        if NeumorphicStyle.isActive {
            neumorphicEmptySearchView
        } else if MujiStyle.isActive {
            mujiEmptySearchView
        } else if SequoiaStyle.isActive {
            sequoiaEmptySearchView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 搜索历史
                    if !viewModel.searchHistory.isEmpty {
                        HStack {
                            Text(LocalizedStringKey("search_history"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.monologueTextSecondary)

                            Spacer()

                            Button(action: {
                                viewModel.clearAllHistory()
                            }) {
                                MonologueIcon(icon: .trash, size: 16, color: .monologueTextSecondary)
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                        ForEach(viewModel.searchHistory, id: \.id) { item in
                            Button(action: {
                                viewModel.performSearch(keyword: item.keyword)
                                isFocused = false
                            }) {
                                HStack(spacing: 14) {
                                    MonologueIcon(icon: .clock, size: 16, color: .monologueTextSecondary)

                                    Text(item.keyword)
                                        .font(.rounded(size: 16, weight: .regular))
                                        .foregroundColor(.monologueTextPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Button(action: {
                                        viewModel.deleteHistoryItem(keyword: item.keyword)
                                    }) {
                                        MonologueIcon(icon: .xmark, size: 12, color: .monologueTextSecondary.opacity(0.5))
                                    }
                                }
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // 热门搜索
                    if !viewModel.hotSearchItems.isEmpty {
                        Text(LocalizedStringKey("search_hot"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            .padding(.top, 20)
                            .padding(.bottom, 12)

                        FlowLayout(spacing: 10) {
                            ForEach(viewModel.hotSearchItems.prefix(20), id: \.searchWord) { item in
                                Button(action: {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                }) {
                                    Text(item.searchWord)
                                        .font(.rounded(size: 14, weight: .regular))
                                        .foregroundColor(.monologueTextPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .monologueGlass(cornerRadius: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private var sequoiaEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let defaultKeyword = viewModel.defaultKeyword {
                    Button {
                        viewModel.performSearch(keyword: defaultKeyword.realkeyword)
                        isFocused = false
                    } label: {
                        HStack(spacing: 13) {
                            SequoiaIconBadge(icon: .magnifyingGlass, tint: SequoiaStyle.accent, size: 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "搜索"))
                                    .font(SequoiaStyle.labelFont(10, weight: .semibold))
                                    .foregroundStyle(SequoiaStyle.inkMuted)
                                    .tracking(0.8)

                                Text(defaultKeyword.showKeyword)
                                    .font(SequoiaStyle.titleFont(19, weight: .semibold))
                                    .foregroundStyle(SequoiaStyle.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }

                            Spacer(minLength: 8)
                            SequoiaMeter(tint: SequoiaStyle.accent, count: 9)
                        }
                        .padding(13)
                        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                }

                if !viewModel.searchHistory.isEmpty {
                    sequoiaSearchShelf(
                        title: String(localized: "search_history"),
                        icon: .clock,
                        tint: SequoiaStyle.green,
                        actionIcon: .trash,
                        action: { viewModel.clearAllHistory() }
                    ) {
                        SequoiaListGroup {
                            ForEach(Array(viewModel.searchHistory.prefix(6).enumerated()), id: \.element.id) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 11) {
                                        MonologueIcon(icon: .clock, size: 14, color: SequoiaStyle.green, lineWidth: 1.5)
                                        Text(item.keyword)
                                            .font(SequoiaStyle.labelFont(14, weight: .medium))
                                            .foregroundStyle(SequoiaStyle.ink)
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonologueIcon(icon: .xmark, size: 11, color: SequoiaStyle.inkMuted, lineWidth: 1.45)
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < min(viewModel.searchHistory.count, 6) - 1 {
                                    Divider()
                                        .overlay(SequoiaStyle.separator)
                                        .padding(.leading, 42)
                                }
                            }
                        }
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    sequoiaSearchShelf(
                        title: String(localized: "search_hot"),
                        icon: .sparkle,
                        tint: SequoiaStyle.aqua
                    ) {
                        FlowLayout(spacing: 9) {
                            ForEach(viewModel.hotSearchItems.prefix(20), id: \.searchWord) { item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    SequoiaPill(text: item.searchWord, tint: SequoiaStyle.aqua, selected: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    private func sequoiaSearchShelf<Content: View>(
        title: String,
        icon: MonologueIcon.IconType,
        tint: Color,
        actionIcon: MonologueIcon.IconType? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                MonologueIcon(icon: icon, size: 15, color: tint, lineWidth: 1.55)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(0.11))
                    )
                Text(title)
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                Spacer(minLength: 8)
                if let actionIcon, let action {
                    Button(action: action) {
                        SequoiaControlButton(icon: actionIcon, tint: SequoiaStyle.inkMuted, size: 34)
                    }
                    .buttonStyle(.plain)
                }
            }
            SequoiaHairline(tint: tint.opacity(0.26))
            content()
        }
    }

    private var neumorphicEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let defaultKeyword = viewModel.defaultKeyword {
                    Button {
                        viewModel.performSearch(keyword: defaultKeyword.realkeyword)
                        isFocused = false
                    } label: {
                        HStack(spacing: 14) {
                            NeumorphicIconBadge(icon: .magnifyingGlass, tint: NeumorphicStyle.accent, size: 46)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("DEFAULT")
                                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                                    .foregroundStyle(NeumorphicStyle.inkMuted)
                                    .tracking(1.0)

                                Text(defaultKeyword.showKeyword)
                                    .font(NeumorphicStyle.titleFont(20, weight: .semibold))
                                    .foregroundStyle(NeumorphicStyle.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }

                            Spacer(minLength: 8)

                            MonologueIcon(icon: .chevronRight, size: 13, color: NeumorphicStyle.accent, lineWidth: 1.6)
                                .frame(width: 34, height: 34)
                                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true))
                        }
                        .padding(15)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                }

                if !viewModel.searchHistory.isEmpty {
                    neumorphicSearchShelf(
                        title: String(localized: "search_history"),
                        icon: .clock,
                        tint: NeumorphicStyle.sage,
                        actionIcon: .trash,
                        action: { viewModel.clearAllHistory() }
                    ) {
                        VStack(spacing: 8) {
                            ForEach(viewModel.searchHistory.prefix(6), id: \.id) { item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 10) {
                                        MonologueIcon(icon: .clock, size: 13, color: NeumorphicStyle.sage, lineWidth: 1.5)

                                        Text(item.keyword)
                                            .font(NeumorphicStyle.bodyFont(14, weight: .medium))
                                            .foregroundStyle(NeumorphicStyle.ink)
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonologueIcon(icon: .xmark, size: 10, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    neumorphicSearchShelf(
                        title: String(localized: "search_hot"),
                        icon: .chart,
                        tint: NeumorphicStyle.warm
                    ) {
                        FlowLayout(spacing: 10) {
                            ForEach(Array(viewModel.hotSearchItems.prefix(20).enumerated()), id: \.element.searchWord) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 7) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(index < 3 ? NeumorphicStyle.warm : NeumorphicStyle.inkMuted)

                                        Text(item.searchWord)
                                            .font(NeumorphicStyle.labelFont(13, weight: .medium))
                                            .foregroundStyle(NeumorphicStyle.ink)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true))
                                }
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func neumorphicSearchShelf<Content: View>(
        title: String,
        icon: MonologueIcon.IconType,
        tint: Color,
        actionIcon: MonologueIcon.IconType? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                NeumorphicIconBadge(icon: icon, tint: tint, size: 34)

                Text(title)
                    .font(NeumorphicStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)

                Spacer(minLength: 8)

                if let actionIcon, let action {
                    Button(action: action) {
                        MonologueIcon(icon: actionIcon, size: 14, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                            .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true))
                    }
                    .buttonStyle(.plain)
                }
            }

            content()
        }
        .padding(14)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
    }

    private var mujiEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            MujiSectionTitle(title: String(localized: "search_history"))

                            Spacer()

                            Button(action: { viewModel.clearAllHistory() }) {
                                MonologueIcon(icon: .trash, size: 15, color: MujiStyle.inkMuted)
                                    .frame(width: 34, height: 34)
                                    .background(MujiStyle.surface, in: Circle())
                                    .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6))
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.searchHistory.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(MujiStyle.labelFont(10, weight: .semibold))
                                            .foregroundStyle(MujiStyle.inkMuted)
                                            .frame(width: 24, alignment: .leading)

                                        Text(item.keyword)
                                            .font(MujiStyle.bodyFont(15, weight: .regular))
                                            .foregroundStyle(MujiStyle.ink)
                                            .lineLimit(1)

                                        Spacer()

                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonologueIcon(icon: .xmark, size: 11, color: MujiStyle.inkMuted.opacity(0.72))
                                                .frame(width: 26, height: 26)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if index < viewModel.searchHistory.count - 1 {
                                    MujiListDivider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        MujiSectionTitle(title: String(localized: "search_hot"))

                        FlowLayout(spacing: 10) {
                            ForEach(Array(viewModel.hotSearchItems.prefix(20).enumerated()), id: \.element.searchWord) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 7) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(MujiStyle.labelFont(9, weight: .semibold))
                                            .foregroundStyle(index < 3 ? MujiStyle.clay : MujiStyle.inkMuted)

                                        Text(item.searchWord)
                                            .font(MujiStyle.labelFont(13, weight: .regular))
                                            .foregroundStyle(MujiStyle.ink)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(MujiStyle.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.6)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(MujiPaperCardBackground(cornerRadius: 12))
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    // MARK: - 搜索建议浮层

    @ViewBuilder
    private var suggestionsOverlay: some View {
        if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
            if NeumorphicStyle.isActive {
                neumorphicSuggestionsOverlay
            } else if SequoiaStyle.isActive {
                sequoiaSuggestionsOverlay
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                                HStack(spacing: 12) {
                                    MonologueIcon(icon: .magnifyingGlass, size: 14, color: .monologueTextSecondary)

                                    Text(suggestion)
                                        .font(.rounded(size: 15, weight: .regular))
                                        .foregroundColor(.monologueTextPrimary)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isFocused = false
                                    viewModel.performSearch(keyword: suggestion)
                                }

                                if suggestion != viewModel.suggestions.last {
                                    Divider()
                                        .opacity(0.4)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .scrollDismissesKeyboard(.never)
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    .frame(maxHeight: 320)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .monologueGlass(cornerRadius: 16)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, suggestionsTopPadding)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
            }
        }
    }

    private var neumorphicSuggestionsOverlay: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        isFocused = false
                        viewModel.performSearch(keyword: suggestion)
                    } label: {
                        HStack(spacing: 11) {
                            MonologueIcon(icon: .magnifyingGlass, size: 13, color: NeumorphicStyle.accent, lineWidth: 1.55)
                                .frame(width: 30, height: 30)
                                .background(NeumorphicSurfaceBackground(cornerRadius: 11, elevated: false, pressed: true, lightweight: true))

                            Text(suggestion)
                                .font(NeumorphicStyle.bodyFont(15, weight: .medium))
                                .foregroundStyle(NeumorphicStyle.ink)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            MonologueIcon(icon: .chevronRight, size: 10, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .scrollDismissesKeyboard(.never)
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .frame(maxHeight: 328)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, suggestionsTopPadding)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
    }

    private var sequoiaSuggestionsOverlay: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element) { index, suggestion in
                    Button {
                        isFocused = false
                        viewModel.performSearch(keyword: suggestion)
                    } label: {
                        HStack(spacing: 11) {
                            MonologueIcon(icon: .magnifyingGlass, size: 13, color: SequoiaStyle.accent, lineWidth: 1.48)
                                .frame(width: 30, height: 30)
                                .background(SequoiaSurfaceBackground(cornerRadius: 11, elevated: false, role: .list))

                            Text(suggestion)
                                .font(SequoiaStyle.bodyFont(15, weight: .medium))
                                .foregroundStyle(SequoiaStyle.ink)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            MonologueIcon(icon: .chevronRight, size: 10, color: SequoiaStyle.inkMuted, lineWidth: 1.45)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.suggestions.count - 1 {
                        Divider()
                            .overlay(SequoiaStyle.separator)
                            .padding(.leading, 54)
                    }
                }
            }
            .padding(.vertical, 7)
        }
        .scrollDismissesKeyboard(.never)
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .frame(maxHeight: 328)
        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, suggestionsTopPadding)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
    }
}

private struct SequoiaSearchStatePanel: View {
    let icon: MonologueIcon.IconType
    let title: String
    var subtitle: String = ""
    var tint: Color = SequoiaStyle.accent
    var loading = false

    var body: some View {
        VStack(spacing: 13) {
            SequoiaIconBadge(icon: icon, tint: tint, size: 52)

            VStack(spacing: 5) {
                Text(title)
                    .font(SequoiaStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SequoiaStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(SequoiaStyle.inkMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }

            if loading {
                ProgressView()
                    .tint(tint)
                    .scaleEffect(0.82)
            } else {
                SequoiaMeter(tint: tint, count: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .padding(.horizontal, 18)
        .background(SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
    }
}
