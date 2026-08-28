import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct ArtistLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showFilters = false
    @State private var showQQFilters = false
    @State private var showKugouFilters = false
    @State private var showAppleMusicFilters = false
    @FocusState private var focusedSearchField: SearchField?
    typealias Theme = PlaylistDetailView.Theme

    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: DeviceLayout.artistGridColumns)

    private enum SearchField: Hashable {
        case ncm
        case qq
        case kugou
        case appleMusic
    }

    private var hasActiveFilter: Bool {
        viewModel.artistArea != -1 || viewModel.artistType != -1 || viewModel.artistInitial != "-1"
    }

    private var hasActiveQQFilter: Bool {
        viewModel.qqArtistArea != .all || viewModel.qqArtistSex != .all || viewModel.qqArtistGenre != .all
    }

    private var hasActiveKugouFilter: Bool {
        viewModel.kugouArtistType != 0 || viewModel.kugouArtistSex != 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MusicSourcePicker(source: $viewModel.artistSource, sources: [.ncm, .qq, .kugou, .appleMusic], usesPlatformTint: false)
                Spacer()
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .onChange(of: viewModel.artistSource) { _, newSource in
                dismissArtistSearchKeyboard()
                viewModel.fetchArtistsForSelectedSource()
            }

            if viewModel.artistSource == .ncm {
                ncmArtistContent
            } else if viewModel.artistSource == .kugou {
                kugouArtistContent
            } else if viewModel.artistSource == .appleMusic {
                appleMusicArtistContent
            } else {
                qqArtistContent
            }
        }
        .background(Color.clear)
    }

    // MARK: - KCM Artists

    private var kugouArtistContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    MonoIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                    TextField(String(localized: "搜索 KCM 歌手"), text: $viewModel.kugouArtistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                        .monoTextInputBehavior()
                        .focused($focusedSearchField, equals: .kugou)
                        .submitLabel(.search)
                        .monoOnSubmit(text: $viewModel.kugouArtistSearchText) { _ in
                            dismissArtistSearchKeyboard()
                        }

                    if !viewModel.kugouArtistSearchText.isEmpty {
                        Button {
                            viewModel.kugouArtistSearchText = ""
                        } label: {
                            MonoIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monoGlass(cornerRadius: 20)
                    }
                }

                if !viewModel.isSearchingKugouArtists {
                    Button {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showKugouFilters.toggle()
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasActiveKugouFilter ? Color.monoGlassTint : Color.clear)
                                .background { Color.clear.monoGlass(cornerRadius: 14) }
                            MonoIcon(
                                icon: .filter,
                                size: 18,
                                color: hasActiveKugouFilter ? .monoIconForeground : Theme.secondaryText
                            )
                            .rotationEffect(.degrees(showKugouFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 12)
            .padding(.top, 8)

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingKugouArtists && showKugouFilters) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.kugouArtistTypes, selected: $viewModel.kugouArtistType) {
                            viewModel.fetchKugouArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    .themeRenderScrollLayer()

                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.kugouArtistSexes, selected: $viewModel.kugouArtistSex) {
                            viewModel.fetchKugouArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    .themeRenderScrollLayer()
                }
                .padding(.bottom, 16)
            }

            artistGrid(
                artists: viewModel.kugouArtists,
                isLoading: viewModel.isLoadingKugouArtists,
                hasMore: false,
                isSearching: viewModel.isSearchingKugouArtists
            ) { _ in }
        }
        .task { viewModel.fetchKugouArtistData() }
    }

    // MARK: - NCM Artists

    private var ncmArtistContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    MonoIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)

                    TextField(LocalizedStringKey("search_artists"), text: $viewModel.artistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                        .monoTextInputBehavior()
                        .focused($focusedSearchField, equals: .ncm)
                        .submitLabel(.search)
                        .monoOnSubmit(text: $viewModel.artistSearchText) { _ in
                            dismissArtistSearchKeyboard()
                            viewModel.fetchArtistData(reset: true)
                        }

                    if !viewModel.artistSearchText.isEmpty {
                        Button(action: {
                            viewModel.artistSearchText = ""
                            viewModel.fetchArtistData(reset: true)
                        }) {
                            MonoIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monoGlass(cornerRadius: 20)
                    }
                }

                if !viewModel.isSearchingArtists {
                    Button(action: {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(NeumorphicStyle.isActive ? Color.clear : (hasActiveFilter ? Color.monoGlassTint : Color.clear))
                                .background {
                                    if NeumorphicStyle.isActive {
                                        NeumorphicSurfaceBackground(
                                            cornerRadius: 14,
                                            elevated: hasActiveFilter,
                                            pressed: !hasActiveFilter,
                                            tint: hasActiveFilter ? NeumorphicStyle.sage.opacity(0.16) : NeumorphicStyle.surface,
                                            lightweight: true
                                        )
                                    } else {
                                        Color.clear.monoGlass(cornerRadius: 14)
                                    }
                                }

                            MonoIcon(
                                icon: .filter,
                                size: 18,
                                color: NeumorphicStyle.isActive ? (hasActiveFilter ? NeumorphicStyle.sage : NeumorphicStyle.inkMuted) : (hasActiveFilter ? .monoIconForeground : Theme.secondaryText)
                            )
                            .rotationEffect(.degrees(showFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 12)
            .padding(.top, 8)

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingArtists && showFilters) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistAreas.map { ($0.name, $0.value) }, selected: $viewModel.artistArea) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistTypes.map { ($0.name, $0.value) }, selected: $viewModel.artistType) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistInitials.map { ($0 == "-1" ? "search_hot" : $0, $0) }, selected: $viewModel.artistInitial) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
                .padding(.bottom, 16)
            }

            artistGrid(
                artists: viewModel.topArtists,
                isLoading: viewModel.isLoadingArtists,
                hasMore: viewModel.hasMoreArtists,
                isSearching: viewModel.isSearchingArtists
            ) { index in
                if index == viewModel.topArtists.count - 1 && !viewModel.isSearchingArtists {
                    viewModel.loadMoreArtists()
                }
            }
        }
    }

    // MARK: - QQ Artists

    private var qqArtistContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    MonoIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)

                    TextField(String(localized: "搜索QCM歌手"), text: $viewModel.qqArtistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                        .monoTextInputBehavior()
                        .focused($focusedSearchField, equals: .qq)
                        .submitLabel(.search)
                        .monoOnSubmit(text: $viewModel.qqArtistSearchText) { _ in
                            dismissArtistSearchKeyboard()
                        }

                    if !viewModel.qqArtistSearchText.isEmpty {
                        Button(action: {
                            viewModel.qqArtistSearchText = ""
                        }) {
                            MonoIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monoGlass(cornerRadius: 20)
                    }
                }

                if !viewModel.isSearchingQQArtists {
                    Button(action: {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showQQFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(NeumorphicStyle.isActive ? Color.clear : (hasActiveQQFilter ? Color.monoGlassTint : Color.clear))
                                .background {
                                    if NeumorphicStyle.isActive {
                                        NeumorphicSurfaceBackground(
                                            cornerRadius: 14,
                                            elevated: hasActiveQQFilter,
                                            pressed: !hasActiveQQFilter,
                                            tint: hasActiveQQFilter ? MusicSource.qqmusic.themedBadgeColor.opacity(0.15) : NeumorphicStyle.surface,
                                            lightweight: true
                                        )
                                    } else {
                                        Color.clear.monoGlass(cornerRadius: 14)
                                    }
                                }

                            MonoIcon(
                                icon: .filter,
                                size: 18,
                                color: NeumorphicStyle.isActive ? (hasActiveQQFilter ? MusicSource.qqmusic.themedBadgeColor : NeumorphicStyle.inkMuted) : (hasActiveQQFilter ? .monoIconForeground : Theme.secondaryText)
                            )
                            .rotationEffect(.degrees(showQQFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 12)
            .padding(.top, 8)

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingQQArtists && showQQFilters) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistAreas, selected: $viewModel.qqArtistArea)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistSexes, selected: $viewModel.qqArtistSex)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistGenres, selected: $viewModel.qqArtistGenre)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
                .padding(.bottom, 16)
            }

            artistGrid(
                artists: viewModel.qqArtists,
                isLoading: viewModel.isLoadingQQArtists,
                hasMore: viewModel.hasMoreQQArtists,
                isSearching: viewModel.isSearchingQQArtists
            ) { index in
                if index == viewModel.qqArtists.count - 1 {
                    viewModel.loadMoreQQArtists()
                }
            }
        }
    }

    // MARK: - Apple Music Artists

    private var appleMusicArtistContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    MonoIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)

                    TextField(String(localized: "搜索 Apple Music 歌手"), text: $viewModel.appleMusicArtistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                        .monoTextInputBehavior()
                        .focused($focusedSearchField, equals: .appleMusic)
                        .submitLabel(.search)
                        .monoOnSubmit(text: $viewModel.appleMusicArtistSearchText) { keyword in
                            dismissArtistSearchKeyboard()
                            if !keyword.isEmpty {
                                viewModel.searchAppleMusicArtists(keyword: keyword)
                            }
                        }

                    if !viewModel.appleMusicArtistSearchText.isEmpty {
                        Button(action: {
                            viewModel.appleMusicArtistSearchText = ""
                            viewModel.fetchAppleMusicArtistData(reset: true)
                        }) {
                            MonoIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monoGlass(cornerRadius: 20)
                    }
                }

                if !viewModel.isSearchingAppleMusicArtists {
                    Button {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAppleMusicFilters.toggle()
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(viewModel.appleMusicArtistCategory == 0 ? Color.clear : Color.monoGlassTint)
                                .background { Color.clear.monoGlass(cornerRadius: 14) }
                            MonoIcon(icon: .filter, size: 18, color: Theme.secondaryText)
                                .rotationEffect(.degrees(showAppleMusicFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 12)
            .padding(.top, 8)

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingAppleMusicArtists && showAppleMusicFilters) {
                ScrollView(.horizontal) {
                    filterRow(
                        options: Array(viewModel.appleMusicArtistCategories.enumerated()).map { ($0.element.name, $0.offset) },
                        selected: $viewModel.appleMusicArtistCategory
                    ) {
                        viewModel.selectAppleMusicArtistCategory(viewModel.appleMusicArtistCategory)
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
                .padding(.bottom, 16)
            }

            artistGrid(
                artists: viewModel.appleMusicArtists,
                isLoading: viewModel.isLoadingAppleMusicArtists,
                hasMore: viewModel.hasMoreAppleMusicArtists,
                isSearching: viewModel.isSearchingAppleMusicArtists
            ) { index in
                if index == viewModel.appleMusicArtists.count - 1 {
                    viewModel.loadMoreAppleMusicArtists()
                }
            }
        }
        .task {
            viewModel.fetchAppleMusicArtistData()
        }
    }

    // MARK: - Shared Artist Grid

    private func artistGrid(
        artists: [ArtistInfo],
        isLoading: Bool,
        hasMore: Bool,
        isSearching: Bool,
        onAppear: @escaping (Int) -> Void
    ) -> some View {
        ScrollView {
            if isLoading && artists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if artists.isEmpty {
                if NeumorphicStyle.isActive {
                    NeumorphicLibraryEmptyState(
                        icon: .personEmpty,
                        title: String(localized: "empty_no_artists"),
                        tint: NeumorphicStyle.sage
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        MonoIcon(icon: .personEmpty, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text(LocalizedStringKey("empty_no_artists"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                            VStack(spacing: 12) {
                                CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                                    NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.gray.opacity(0.1)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: NeumorphicStyle.isActive ? DeviceLayout.artistAvatarSize - 10 : DeviceLayout.artistAvatarSize,
                                    height: NeumorphicStyle.isActive ? DeviceLayout.artistAvatarSize - 10 : DeviceLayout.artistAvatarSize
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(NeumorphicStyle.isActive ? 0.06 : 0.1), radius: 8, x: 0, y: 4)

                                Text(artist.name)
                                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 14, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                            }
                            .padding(NeumorphicStyle.isActive ? 12 : 0)
                            .frame(maxWidth: .infinity)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true)
                                }
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            dismissArtistSearchKeyboard()
                        })
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
                        .onAppear { onAppear(index) }
                    }
                }
                .padding(DeviceLayout.viewHorizontalPadding)

                if hasMore && !isSearching {
                    LibraryInlineLoadingView()
                }
                if !hasMore && !artists.isEmpty && !isSearching {
                    NoMoreDataView()
                }
            }

            FloatingBarBottomSpacer()
        }
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(TapGesture().onEnded {
            dismissArtistSearchKeyboard()
        })
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    // MARK: - Filter Rows

    private func filterRow<T: Equatable>(options: [(String, T)], selected: Binding<T>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.0) { option in
                Button(action: {
                    dismissArtistSearchKeyboard()
                    if selected.wrappedValue != option.1 {
                        selected.wrappedValue = option.1
                        onChange()
                    }
                }) {
                    let isSelected = selected.wrappedValue == option.1
                    if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: NSLocalizedString(option.0, comment: ""),
                            tint: NeumorphicStyle.sage,
                            selected: isSelected
                        )
                    } else if MujiStyle.isActive {
                        mujiFilterPill(title: NSLocalizedString(option.0, comment: ""), selected: isSelected)
                    } else {
                        Text(LocalizedStringKey(option.0))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(isSelected ? Color.monoIconBackground : Color.monoGlassTint))
                            .foregroundColor(isSelected ? .monoIconForeground : .monoTextPrimary)
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }
        }
    }

    private func qqFilterRow<T: Equatable>(options: [(name: String, value: T)], selected: Binding<T>) -> some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.name) { option in
                Button(action: {
                    dismissArtistSearchKeyboard()
                    if selected.wrappedValue != option.value {
                        selected.wrappedValue = option.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }) {
                    let isSelected = selected.wrappedValue == option.value
                    if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: NSLocalizedString(option.name, comment: ""),
                            tint: MusicSource.qqmusic.themedBadgeColor,
                            selected: isSelected
                        )
                    } else if MujiStyle.isActive {
                        mujiFilterPill(title: NSLocalizedString(option.name, comment: ""), selected: isSelected)
                    } else {
                        Text(LocalizedStringKey(option.name))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(isSelected ? Color.monoIconBackground : Color.monoGlassTint))
                            .foregroundColor(isSelected ? .monoIconForeground : .monoTextPrimary)
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }
        }
    }

    /// Muji：目次式筛选项，圆点 + 墨色层级，不用填充块
    private func mujiFilterPill(title: String, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(selected ? MujiStyle.clay : MujiStyle.separator.opacity(0.85))
                .frame(width: 4, height: 4)

            Text(title)
                .font(MujiStyle.labelFont(12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? MujiStyle.ink : MujiStyle.inkMuted)
                .lineLimit(1)
        }
        .padding(.vertical, 9)
        .padding(.trailing, 4)
    }

    private func dismissArtistSearchKeyboard() {
        focusedSearchField = nil
    }
}

struct LibraryDisclosureReveal<Content: View>: View {
    let isExpanded: Bool
    let content: Content
    @State private var measuredHeight: CGFloat = 0

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { updateMeasuredHeight(proxy.size.height) }
                                .onChange(of: proxy.size.height) { _, newValue in
                                    updateMeasuredHeight(newValue)
                                }
                        }
                    }
            }
        }
        .frame(height: isExpanded ? measuredHeight : 0, alignment: .top)
        .clipShape(Rectangle())
        .clipped()
        .allowsHitTesting(isExpanded)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isExpanded)
    }

    private func updateMeasuredHeight(_ height: CGFloat) {
        guard height > 0, abs(measuredHeight - height) > 0.5 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            measuredHeight = height
        }
    }
}
