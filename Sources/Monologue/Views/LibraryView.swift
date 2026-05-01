import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @ObservedObject private var settings = SettingsManager.shared

    typealias Theme = PlaylistDetailView.Theme

    /// 当前标签索引（用于滑动手势）
    @State private var tabIndex: Int = 0
    /// 拖拽偏移量
    @State private var dragOffset: CGFloat = 0
    @State private var libraryHeaderCollapseProgress: CGFloat = 0
    @State private var libraryHeaderDragStart: CGFloat?

    private let allTabs = LibraryViewModel.LibraryTab.allCases

    var body: some View {
        let _ = settings.globalThemeRevision
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if MangaStyle.isActive {
                    MangaLibraryExperience(viewModel: viewModel, tabIndex: $tabIndex)
                } else if NeumorphicStyle.isActive {
                    NeumorphicLibraryWorkspace(viewModel: viewModel, tabIndex: $tabIndex)
                } else {
                    ScrollableLibraryExperience(viewModel: viewModel, tabIndex: $tabIndex)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryViewModel.NavigationDestination.self) { destination in
                switch destination {
                case let .playlist(playlist):
                    PlaylistDetailView(playlist: playlist)

                case let .artist(id):
                    ArtistDetailView(artistId: id)

                case let .artistInfo(artist):
                    if artist.source == .qqmusic, let mid = artist.qqMid {
                        QQMusicDetailView(detailType: .artist(
                            mid: mid,
                            name: artist.name,
                            coverUrl: artist.picUrl ?? artist.img1v1Url
                        ))

                    } else {
                        ArtistDetailView(artistId: artist.id)
                    }

                case let .qqArtist(mid, name, coverUrl):
                    QQMusicDetailView(detailType: .artist(mid: mid, name: name, coverUrl: coverUrl))

                case let .radioDetail(id):
                    RadioDetailView(radioId: id)

                case let .localPlaylist(id):
                    LocalPlaylistDetailView(playlistId: id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibrarySquare"))) { _ in
                switchToTab(.square)
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibraryArtists"))) { _ in
                switchToTab(.artists)
            }
            .onAppear {
                if UserDefaults.standard.bool(forKey: "pendingLibrarySquareSwitch") {
                    UserDefaults.standard.set(false, forKey: "pendingLibrarySquareSwitch")
                    switchToTab(.square)
                }
                if UserDefaults.standard.bool(forKey: "pendingLibraryArtistsSwitch") {
                    UserDefaults.standard.set(false, forKey: "pendingLibraryArtistsSwitch")
                    switchToTab(.artists)
                }
            }
            .onChange(of: viewModel.currentTab) { _, newTab in
                if let idx = allTabs.firstIndex(of: newTab), idx != tabIndex {
                    tabIndex = idx
                }
                guard !NeumorphicStyle.isActive else { return }
                if newTab == .square {
                    if viewModel.squareSource == .qq {
                        viewModel.fetchQQSquareData()
                    } else {
                        viewModel.fetchSquareData()
                    }
                } else if newTab == .artists {
                    if viewModel.artistSource == .qq {
                        viewModel.fetchQQArtistData()
                    } else {
                        viewModel.fetchArtistData()
                    }
                } else if newTab == .charts {
                    if viewModel.chartsSource == .qq {
                        viewModel.fetchQQTopLists()
                    } else {
                        viewModel.fetchTopLists()
                    }
                }
            }
        }
    }

    private func switchToTab(_ tab: LibraryViewModel.LibraryTab) {
        guard let idx = allTabs.firstIndex(of: tab) else { return }
        tabIndex = idx
        viewModel.currentTab = tab
    }

    private var libraryHeaderCollapseDistance: CGFloat {
        if MujiStyle.isActive {
            return 156
        }
        return 132
    }

    private var libraryHeaderScrollGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                if libraryHeaderDragStart == nil {
                    libraryHeaderDragStart = libraryHeaderCollapseProgress
                }
                let start = libraryHeaderDragStart ?? libraryHeaderCollapseProgress
                let next = start - value.translation.height / max(libraryHeaderCollapseDistance, 1)
                libraryHeaderCollapseProgress = min(max(next, 0), 1)
            }
            .onEnded { value in
                guard libraryHeaderDragStart != nil else { return }
                let projected = libraryHeaderCollapseProgress - value.predictedEndTranslation.height / max(libraryHeaderCollapseDistance, 1) * 0.14
                libraryHeaderDragStart = nil
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    libraryHeaderCollapseProgress = projected > 0.42 ? 1 : 0
                }
            }
    }

    @ViewBuilder
    private var libraryHeaderView: some View {
        if MangaStyle.isActive {
            VStack(spacing: 14) {
                MangaPageHeader(
                    eyebrow: "COLLECTION",
                    title: String(localized: "tabbar_library"),
                    subtitle: ""
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MangaStyle.decoBlue)

                        MonologueIcon(icon: .libraryFilled, size: 22, color: MangaStyle.strokeInk, lineWidth: 2)
                    }
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MangaStyle.strokeInk)
                            .offset(x: 2.5, y: 2.5)
                    )
                }

                libraryTabPicker
            }
            .padding(.bottom, 10)
        } else if NeumorphicStyle.isActive {
            VStack(spacing: 14) {
                NeumorphicPageHeader(
                    eyebrow: "library",
                    title: String(localized: "tabbar_library"),
                    subtitle: ""
                ) {
                    NeumorphicIconBadge(icon: .library, tint: NeumorphicStyle.sage, size: 48)
                }

                libraryTabPicker
            }
            .padding(.bottom, 10)
        } else if MujiStyle.isActive {
            VStack(spacing: 14) {
                MujiPageHeader(
                    eyebrow: "collection shelves",
                    title: String(localized: "tabbar_library"),
                    subtitle: ""
                ) {
                    MujiIconBadge(icon: .library, tint: MujiStyle.tea, size: 48)
                }

                libraryTabPicker
            }
            .padding(.bottom, 10)
        } else {
            VStack(spacing: 14) {
                Text(LocalizedStringKey("tabbar_library"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

                libraryTabPicker
            }
            .padding(.top, DeviceLayout.headerTopPadding)
            .padding(.bottom, 8)
        }
    }

    private var libraryTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                Button(action: {
                    switchToTab(tab)
                }) {
                    VStack(spacing: 5) {
                        Text(tab.localizedKey)
                            .font(libraryTabFont(isSelected: tabIndex == index))
                            .foregroundStyle(libraryTabForeground(index: index))
                            .animation(.none, value: tabIndex)

                        Capsule()
                            .fill(NeumorphicStyle.isActive ? NeumorphicStyle.accent : (MujiStyle.isActive ? MujiStyle.clay : Color.monologueAccent))
                            .frame(width: 20, height: 2.5)
                            .opacity((ThemedPageStyle.isActive || defaultLibraryTabsUsePill) ? 0 : (tabIndex == index ? 1 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, (ThemedPageStyle.isActive || defaultLibraryTabsUsePill) ? 9 : 0)
                    .background {
                        if MangaStyle.isActive {
                            if tabIndex == index {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(MangaStyle.decoBlue)
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                            }
                        } else if MujiStyle.isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tabIndex == index ? MujiStyle.ink : Color.clear)
                        } else if NeumorphicStyle.isActive, tabIndex == index {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(NeumorphicStyle.accent.opacity(0.12))
                                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true))
                        } else if defaultLibraryTabsUsePill, tabIndex == index {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(defaultLibrarySelectedTabFill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding((ThemedPageStyle.isActive || defaultLibraryTabsUsePill) ? 5 : 0)
        .background {
            if MangaStyle.isActive {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(MangaStyle.surface)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                    .shadow(color: MangaStyle.strokeInk, radius: 0, x: MangaStyle.shadowOffset, y: MangaStyle.shadowOffset)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6)
                    )
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else if defaultLibraryTabsUsePill {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.monologueGlassTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.monologueSeparator.opacity(0.68), lineWidth: 0.7)
                    )
            }
        }
        .padding(.horizontal, DeviceLayout.isPad ? 24 : 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabIndex)
    }

    private var defaultLibraryTabsUsePill: Bool {
        !ThemedPageStyle.isActive
    }

    private var defaultLibrarySelectedTabFill: Color {
        Color(light: Color.black.opacity(0.88), dark: Color.white.opacity(0.9))
    }

    private var defaultLibrarySelectedTabForeground: Color {
        Color(light: Color.white, dark: Color(hex: "111111"))
    }

    private func libraryTabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive {
            return MangaStyle.comicFont(13, weight: isSelected ? .bold : .medium)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(14, weight: isSelected ? .semibold : .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(14, weight: isSelected ? .semibold : .medium)
        }
        return .system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded)
    }

    private func libraryTabForeground(index: Int) -> Color {
        let isSelected = tabIndex == index
        if MangaStyle.isActive {
            return isSelected ? MangaStyle.ink : MangaStyle.inkMuted
        }
        if MujiStyle.isActive {
            return isSelected ? MujiStyle.onTint : MujiStyle.inkSoft
        }
        if NeumorphicStyle.isActive {
            return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft
        }
        return isSelected ? defaultLibrarySelectedTabForeground : Color.monologueTextSecondary.opacity(0.82)
    }
}

// MARK: - Neumorphic Library Redesign

private struct LibraryCollapsingHeader<Content: View>: View {
    @Binding var progress: CGFloat
    let collapseDistance: CGFloat
    let content: Content

    init(progress: Binding<CGFloat>, collapseDistance: CGFloat, @ViewBuilder content: () -> Content) {
        self._progress = progress
        self.collapseDistance = collapseDistance
        self.content = content()
    }

    private var visibleHeight: CGFloat? {
        progress <= 0.001 ? nil : max(0, collapseDistance * (1 - progress))
    }

    var body: some View {
        content
            .offset(y: -collapseDistance * progress)
            .opacity(1 - progress * 0.2)
            .frame(height: visibleHeight, alignment: .top)
            .clipped()
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: progress)
    }
}

// MARK: - Neumorphic Library Workspace

private struct NeumorphicLibraryWorkspace: View {
    private enum Shelf: CaseIterable, Hashable {
        case localPlaylists
        case ncmPlaylists
        case qcmPlaylists
        case localPodcasts
        case ncmPodcasts

        var title: String {
            switch self {
            case .localPlaylists: return String(localized: "lib_local_playlists")
            case .ncmPlaylists: return String(localized: "lib_netease_playlists")
            case .qcmPlaylists: return String(localized: "QCM歌单")
            case .localPodcasts: return String(localized: "本地播客")
            case .ncmPodcasts: return String(localized: "NCM 播客")
            }
        }

        var icon: MonologueIcon.IconType {
            switch self {
            case .localPlaylists: return .musicNoteList
            case .ncmPlaylists, .qcmPlaylists: return .list
            case .localPodcasts, .ncmPodcasts: return .radio
            }
        }
    }

    private enum ArtistSearchField: Hashable {
        case ncm
        case qq
    }

    @ObservedObject var viewModel: LibraryViewModel
    @Binding var tabIndex: Int
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var localManager = LocalPlaylistManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var qqSession = QQUserSession.shared

    @State private var selectedShelf: Shelf = .localPlaylists
    @State private var showLibraryTools = false
    @State private var showFileImporter = false
    @State private var showQQImport = false
    @State private var isImporting = false
    @State private var qqUserPlaylists: [Playlist] = []
    @State private var isLoadingQQUserPlaylists = false
    @State private var hasLoadedQQUserPlaylists = false
    @State private var showArtistFilters = false
    @State private var showQQArtistFilters = false
    @FocusState private var focusedArtistSearchField: ArtistSearchField?
    @Namespace private var tabNamespace

    private let tabs = LibraryViewModel.LibraryTab.allCases
    private let controlColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let playlistColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let artistColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: DeviceLayout.artistGridColumns)

    private var deckOuterPadding: CGFloat {
        DeviceLayout.isPad ? DeviceLayout.libraryHorizontalPadding : 10
    }

    private var selectedTab: LibraryViewModel.LibraryTab {
        tabs[min(max(tabIndex, 0), tabs.count - 1)]
    }

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    headerConsole
                    pageContent
                }
                .padding(.bottom, 128)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .onAppear {
            syncTabFromViewModel()
            loadCurrentTab()
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
        .onChange(of: viewModel.currentTab) { _, _ in
            syncTabFromViewModel()
        }
        .onChange(of: tabIndex) { _, _ in
            if viewModel.currentTab != selectedTab {
                viewModel.currentTab = selectedTab
            }
            loadCurrentTab()
        }
        .onChange(of: qqSession.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                hasLoadedQQUserPlaylists = false
                loadQQUserPlaylistsIfNeeded(force: true)
            } else {
                qqUserPlaylists = []
                hasLoadedQQUserPlaylists = false
            }
        }
        .monologueSheet(isPresented: $showQQImport, preset: .large) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case let .failure(error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
    }

    private var headerConsole: some View {
        VStack(alignment: .leading, spacing: 12) {
            libraryTopBar
            libraryTabRail
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    private var libraryTopBar: some View {
        HStack(spacing: 13) {
            NeumorphicIconBadge(icon: .libraryFilled, tint: activeTint, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("LIBRARY")
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.inkMuted)

                Text(String(localized: "tabbar_library"))
                    .font(NeumorphicStyle.titleFont(23, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
    }

    private var libraryTabRail: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                libraryRailButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(NeumorphicSurfaceBackground(cornerRadius: 19, elevated: false, pressed: true, lightweight: true))
    }

    private func libraryRailButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 12,
                    color: selected ? tint : NeumorphicStyle.inkSoft,
                    lineWidth: 1.55
                )
                Text(tab.localizedKey)
                    .font(NeumorphicStyle.labelFont(11, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(NeumorphicStyle.surfaceRaised)
                        .matchedGeometryEffect(id: "library-tab", in: tabNamespace)
                        .shadow(color: Color.black.opacity(0.09), radius: 5, x: 3, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pageContent: some View {
        Group {
            switch selectedTab {
            case .my:
                myLibraryPage
            case .square:
                playlistDiscoveryPage
            case .artists:
                artistIndexPage
            case .charts:
                chartFlowPage
            }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var myLibraryPage: some View {
        libraryDeck(
            title: selectedShelf.title,
            icon: selectedShelf.icon,
            tint: tint(for: selectedShelf),
            trailing: {
                libraryToolsButton
            }
        ) {
            shelfSelector

            LibraryDisclosureReveal(isExpanded: showLibraryTools) {
                LazyVGrid(columns: controlColumns, spacing: 9) {
                    actionChip(title: String(localized: "lib_create"), icon: .add, tint: NeumorphicStyle.accent) {
                        createLocalPlaylist()
                    }
                    actionChip(title: String(localized: "lib_import_playlist"), icon: .download, tint: NeumorphicStyle.warm, isLoading: isImporting) {
                        showFileImporter = true
                    }
                    actionChip(title: String(localized: "从链接导入"), icon: .share, tint: NeumorphicStyle.sage, isLoading: isImporting) {
                        showImportLinkPrompt()
                    }
                    actionChip(title: String(localized: "QCM歌单"), icon: .musicNoteList, tint: MusicSource.qqmusic.themedBadgeColor) {
                        showQQImport = true
                    }
                }
                .padding(12)
                .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true))
            }

            shelfContent
        }
    }

    private var libraryToolsButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                showLibraryTools.toggle()
            }
        } label: {
            MonologueIcon(
                icon: showLibraryTools ? .close : .more,
                size: 14,
                color: showLibraryTools ? NeumorphicStyle.accent : NeumorphicStyle.inkMuted,
                lineWidth: 1.65
            )
            .frame(width: 38, height: 38)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 15,
                    elevated: showLibraryTools,
                    pressed: !showLibraryTools,
                    tint: showLibraryTools ? NeumorphicStyle.accent.opacity(0.14) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private var shelfSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(Shelf.allCases, id: \.self) { shelf in
                    let selected = selectedShelf == shelf
                    let tint = tint(for: shelf)
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            selectedShelf = shelf
                        }
                        if shelf == .qcmPlaylists {
                            loadQQUserPlaylistsIfNeeded()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            MonologueIcon(icon: shelf.icon, size: 13, color: selected ? tint : NeumorphicStyle.inkMuted, lineWidth: selected ? 1.8 : 1.5)
                            Text(shelf.title)
                                .font(NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 42)
                        .background(
                            NeumorphicSurfaceBackground(
                                cornerRadius: 17,
                                elevated: selected,
                                pressed: !selected,
                                tint: selected ? tint.opacity(0.17) : NeumorphicStyle.surface,
                                lightweight: true
                            )
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    @ViewBuilder
    private var shelfContent: some View {
        switch selectedShelf {
        case .localPlaylists:
            localPlaylistsContent
        case .ncmPlaylists:
            remotePlaylistsContent(playlists: viewModel.userPlaylists, emptyTitle: String(localized: "empty_no_playlists"), tint: MusicSource.netease.themedBadgeColor)
        case .qcmPlaylists:
            qcmPlaylistsContent
        case .localPodcasts:
            localPodcastsContent
        case .ncmPodcasts:
            ncmPodcastsContent
        }
    }

    private var localPlaylistsContent: some View {
        Group {
            if localManager.playlists.isEmpty {
                emptyCard(icon: .musicNoteList, title: String(localized: "lib_no_local_playlists"), tint: NeumorphicStyle.accent)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(localManager.playlists, id: \.id) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                            NeumorphicLocalShelfRow(playlist: playlist, tint: playlist.isFavorite ? NeumorphicStyle.red : (playlist.isDownload ? NeumorphicStyle.sage : NeumorphicStyle.accent))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func remotePlaylistsContent(playlists: [Playlist], emptyTitle: String, tint: Color) -> some View {
        Group {
            if playlists.isEmpty {
                emptyCard(icon: .list, title: emptyTitle, tint: tint)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            NeumorphicPlaylistShelfRow(playlist: playlist, tint: tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var qcmPlaylistsContent: some View {
        Group {
            if isLoadingQQUserPlaylists && qqUserPlaylists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: 0, minHeight: 240)
            } else if !qqSession.isLoggedIn {
                emptyCard(icon: .musicNoteList, title: String(localized: "请先登录 QCM"), tint: MusicSource.qqmusic.themedBadgeColor)
            } else {
                remotePlaylistsContent(playlists: qqUserPlaylists, emptyTitle: String(localized: "暂无 QCM 歌单"), tint: MusicSource.qqmusic.themedBadgeColor)
            }
        }
    }

    private var localPodcastsContent: some View {
        Group {
            if subManager.localSubscribedRadios.isEmpty {
                emptyCard(icon: .radio, title: String(localized: "暂无本地收藏"), tint: NeumorphicStyle.sage)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(subManager.localSubscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            NeumorphicPodcastShelfRow(radio: radio, tint: NeumorphicStyle.sage)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var ncmPodcastsContent: some View {
        Group {
            if subManager.isLoadingRadios && subManager.subscribedRadios.isEmpty {
                LibraryLoadingStateView(horizontalPadding: 0, minHeight: 240)
            } else if subManager.subscribedRadios.isEmpty {
                emptyCard(icon: .radio, title: String(localized: "lib_no_podcasts"), tint: NeumorphicStyle.warm)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(subManager.subscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            NeumorphicPodcastShelfRow(radio: radio, tint: NeumorphicStyle.warm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var playlistDiscoveryPage: some View {
        libraryDeck(
            title: String(localized: "歌单广场"),
            icon: .musicNoteList,
            tint: viewModel.squareSource == .qq ? MusicSource.qqmusic.themedBadgeColor : MusicSource.netease.themedBadgeColor
        ) {
            sourceSwitch(selected: viewModel.squareSource) { source in
                viewModel.squareSource = source
                source == .qq ? viewModel.fetchQQSquareData() : viewModel.fetchSquareData()
            }

            if viewModel.squareSource == .qq {
                filterBar {
                    ForEach(filteredQQCategories, id: \.id) { category in
                        filterChip(title: category.name, selected: viewModel.selectedQQCategoryId == category.id, tint: MusicSource.qqmusic.themedBadgeColor) {
                            viewModel.selectQQCategory(id: category.id, name: category.name)
                        }
                    }
                }
                playlistGrid(playlists: viewModel.qqSquarePlaylists, isLoading: viewModel.isLoadingQQSquare, emptyTitle: String(localized: "暂无QCM推荐歌单"))
                if viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                    loadMoreButton { viewModel.loadMoreQQSquarePlaylists() }
                }
            } else {
                filterBar {
                    ForEach(viewModel.playlistCategories, id: \.idString) { category in
                        filterChip(title: category.name, selected: viewModel.selectedCategory == category.name, tint: MusicSource.netease.themedBadgeColor) {
                            viewModel.selectedCategory = category.name
                            viewModel.loadSquarePlaylists(cat: category.name, reset: true)
                        }
                    }
                }
                playlistGrid(playlists: viewModel.squarePlaylists, isLoading: viewModel.isLoadingSquare, emptyTitle: String(localized: "empty_no_playlists"))
                if viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                    loadMoreButton { viewModel.loadMoreSquarePlaylists() }
                }
            }
        }
    }

    private var artistIndexPage: some View {
        libraryDeck(
            title: String(localized: "歌手"),
            icon: .personCircle,
            tint: viewModel.artistSource == .qq ? MusicSource.qqmusic.themedBadgeColor : NeumorphicStyle.warm
        ) {
            sourceSwitch(selected: viewModel.artistSource) { source in
                dismissArtistSearchKeyboard()
                showArtistFilters = false
                showQQArtistFilters = false
                viewModel.artistSource = source
                source == .qq ? viewModel.fetchQQArtistData(reset: true) : viewModel.fetchArtistData(reset: true)
            }

            if viewModel.artistSource == .qq {
                qqArtistSearchAndFilters
                artistGrid(artists: viewModel.qqArtists, isLoading: viewModel.isLoadingQQArtists, tint: MusicSource.qqmusic.themedBadgeColor)
                if viewModel.hasMoreQQArtists && !viewModel.qqArtists.isEmpty {
                    loadMoreButton { viewModel.loadMoreQQArtists() }
                }
            } else {
                ncmArtistSearchAndFilters
                artistGrid(artists: viewModel.topArtists, isLoading: viewModel.isLoadingArtists, tint: NeumorphicStyle.warm)
                if viewModel.hasMoreArtists && !viewModel.topArtists.isEmpty {
                    loadMoreButton { viewModel.loadMoreArtists() }
                }
            }
        }
    }

    private var ncmArtistSearchAndFilters: some View {
        VStack(spacing: 10) {
            artistSearchBar(
                text: $viewModel.artistSearchText,
                placeholder: LocalizedStringKey("search_artists"),
                field: .ncm,
                tint: NeumorphicStyle.warm,
                hasActiveFilter: hasActiveArtistFilter,
                isFilterExpanded: showArtistFilters,
                isSearching: viewModel.isSearchingArtists,
                onToggleFilter: {
                    showArtistFilters.toggle()
                },
                onClear: {
                    viewModel.artistSearchText = ""
                    viewModel.fetchArtistData(reset: true)
                },
                onSubmit: {
                    if viewModel.artistSearchText.isEmpty {
                        viewModel.fetchArtistData(reset: true)
                    } else {
                        viewModel.searchArtists(keyword: viewModel.artistSearchText)
                    }
                }
            )

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingArtists && showArtistFilters) {
                VStack(spacing: 10) {
                    filterBar {
                        ForEach(viewModel.artistAreas, id: \.value) { area in
                            filterChip(title: NSLocalizedString(area.name, comment: ""), selected: viewModel.artistArea == area.value, tint: NeumorphicStyle.warm) {
                                viewModel.artistArea = area.value
                                viewModel.fetchArtistData(reset: true)
                            }
                        }
                    }
                    filterBar {
                        ForEach(viewModel.artistTypes, id: \.value) { type in
                            filterChip(title: NSLocalizedString(type.name, comment: ""), selected: viewModel.artistType == type.value, tint: NeumorphicStyle.sage) {
                                viewModel.artistType = type.value
                                viewModel.fetchArtistData(reset: true)
                            }
                        }
                    }
                    filterBar {
                        ForEach(viewModel.artistInitials, id: \.self) { initial in
                            filterChip(title: initial == "-1" ? NSLocalizedString("search_hot", comment: "") : initial, selected: viewModel.artistInitial == initial, tint: NeumorphicStyle.accent) {
                                viewModel.artistInitial = initial
                                viewModel.fetchArtistData(reset: true)
                            }
                        }
                    }
                }
                .padding(.top, 1)
            }
        }
    }

    private var qqArtistSearchAndFilters: some View {
        VStack(spacing: 10) {
            artistSearchBar(
                text: $viewModel.qqArtistSearchText,
                placeholder: LocalizedStringKey("搜索QCM歌手"),
                field: .qq,
                tint: MusicSource.qqmusic.themedBadgeColor,
                hasActiveFilter: hasActiveQQArtistFilter,
                isFilterExpanded: showQQArtistFilters,
                isSearching: viewModel.isSearchingQQArtists,
                onToggleFilter: {
                    showQQArtistFilters.toggle()
                },
                onClear: {
                    viewModel.qqArtistSearchText = ""
                    viewModel.fetchQQArtistData(reset: true)
                },
                onSubmit: {
                    if !viewModel.qqArtistSearchText.isEmpty {
                        viewModel.searchQQArtists(keyword: viewModel.qqArtistSearchText)
                    }
                }
            )

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingQQArtists && showQQArtistFilters) {
                VStack(spacing: 10) {
                    filterBar {
                        ForEach(viewModel.qqArtistAreas, id: \.value) { area in
                            filterChip(title: NSLocalizedString(area.name, comment: ""), selected: viewModel.qqArtistArea == area.value, tint: MusicSource.qqmusic.themedBadgeColor) {
                                viewModel.qqArtistArea = area.value
                                viewModel.fetchQQArtistData(reset: true)
                            }
                        }
                    }
                    filterBar {
                        ForEach(viewModel.qqArtistSexes, id: \.value) { sex in
                            filterChip(title: NSLocalizedString(sex.name, comment: ""), selected: viewModel.qqArtistSex == sex.value, tint: NeumorphicStyle.accent) {
                                viewModel.qqArtistSex = sex.value
                                viewModel.fetchQQArtistData(reset: true)
                            }
                        }
                    }
                    filterBar {
                        ForEach(viewModel.qqArtistGenres, id: \.value) { genre in
                            filterChip(title: NSLocalizedString(genre.name, comment: ""), selected: viewModel.qqArtistGenre == genre.value, tint: NeumorphicStyle.sage) {
                                viewModel.qqArtistGenre = genre.value
                                viewModel.fetchQQArtistData(reset: true)
                            }
                        }
                    }
                }
                .padding(.top, 1)
            }
        }
    }

    private func artistSearchBar(
        text: Binding<String>,
        placeholder: LocalizedStringKey,
        field: ArtistSearchField,
        tint: Color,
        hasActiveFilter: Bool,
        isFilterExpanded: Bool,
        isSearching: Bool,
        onToggleFilter: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 9) {
            HStack(spacing: 9) {
                MonologueIcon(icon: .magnifyingGlass, size: 16, color: NeumorphicStyle.inkMuted, lineWidth: 1.7)

                TextField(placeholder, text: text)
                    .font(NeumorphicStyle.bodyFont(14, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .monologueTextInputBehavior()
                    .focused($focusedArtistSearchField, equals: field)
                    .submitLabel(.search)
                    .onSubmit {
                        dismissArtistSearchKeyboard()
                        onSubmit()
                    }

                if !text.wrappedValue.isEmpty {
                    Button {
                        dismissArtistSearchKeyboard()
                        onClear()
                    } label: {
                        MonologueIcon(icon: .close, size: 13, color: NeumorphicStyle.inkMuted, lineWidth: 1.7)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true))

            if !isSearching {
                Button {
                    dismissArtistSearchKeyboard()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        onToggleFilter()
                    }
                } label: {
                    MonologueIcon(
                        icon: .filter,
                        size: 15,
                        color: hasActiveFilter || isFilterExpanded ? tint : NeumorphicStyle.inkMuted,
                        lineWidth: 1.7
                    )
                    .rotationEffect(.degrees(isFilterExpanded ? 90 : 0))
                    .frame(width: 42, height: 42)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 16,
                            elevated: isFilterExpanded || hasActiveFilter,
                            pressed: !(isFilterExpanded || hasActiveFilter),
                            tint: hasActiveFilter ? tint.opacity(0.14) : NeumorphicStyle.surface,
                            lightweight: true
                        )
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            }
        }
    }

    private var chartFlowPage: some View {
        libraryDeck(
            title: String(localized: "榜单"),
            icon: .chart,
            tint: viewModel.chartsSource == .qq ? MusicSource.qqmusic.themedBadgeColor : NeumorphicStyle.red
        ) {
            sourceSwitch(selected: viewModel.chartsSource) { source in
                viewModel.chartsSource = source
                source == .qq ? viewModel.fetchQQTopLists() : viewModel.fetchTopLists()
            }

            if viewModel.chartsSource == .qq {
                if viewModel.isLoadingQQCharts && viewModel.qqTopLists.isEmpty {
                    LibraryLoadingStateView(horizontalPadding: 0, minHeight: 260)
                } else if viewModel.qqTopLists.isEmpty {
                    emptyCard(icon: .chart, title: String(localized: "暂无QCM排行榜"), tint: MusicSource.qqmusic.themedBadgeColor)
                } else {
                    ForEach(viewModel.qqTopLists) { group in
                        sectionTitle(group.groupName, tint: NeumorphicStyle.red)
                        LazyVStack(spacing: 10) {
                            ForEach(group.items) { item in
                                NavigationLink(value: qqChartDestination(item)) {
                                    NeumorphicQQChartShelfRow(item: item, tint: MusicSource.qqmusic.themedBadgeColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                    LibraryLoadingStateView(horizontalPadding: 0, minHeight: 260)
                } else if viewModel.topLists.isEmpty {
                    emptyCard(icon: .chart, title: String(localized: "empty_no_charts"), tint: NeumorphicStyle.red)
                } else {
                    let officialIds: Set<Int> = [19_723_756, 3_779_629, 2_884_035, 3_778_678]
                    let official = viewModel.topLists.filter { officialIds.contains($0.id) }
                    let others = viewModel.topLists.filter { !officialIds.contains($0.id) }

                    if !official.isEmpty {
                        sectionTitle(String(localized: "charts_official"), tint: NeumorphicStyle.red)
                        officialChartRail(official)
                    }

                    if !others.isEmpty {
                        sectionTitle(String(localized: "charts_more"), tint: NeumorphicStyle.warm)
                        LazyVGrid(columns: playlistColumns, spacing: 12) {
                            ForEach(others) { list in
                                NavigationLink(value: chartDestination(list)) {
                                    NeumorphicChartTile(list: list, tint: NeumorphicStyle.warm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func officialChartRail(_ lists: [TopList]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(lists) { list in
                    NavigationLink(value: chartDestination(list)) {
                        NeumorphicChartTile(list: list, tint: NeumorphicStyle.red)
                            .frame(width: DeviceLayout.isPad ? 180 : 148)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }


    private func libraryDeck<Content: View>(
        title: String,
        icon: MonologueIcon.IconType,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        libraryDeck(
            title: title,
            icon: icon,
            tint: tint,
            trailing: {
                EmptyView()
            },
            content: content
        )
    }

    private func libraryDeck<Content: View, Trailing: View>(
        title: String,
        icon: MonologueIcon.IconType,
        tint: Color,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeumorphicIconBadge(icon: icon, tint: tint, size: 38)

                Text(title)
                    .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                trailing()
            }

            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(neumorphicLibraryContentPanel(tint: tint))
        .padding(.horizontal, deckOuterPadding)
    }

    private func neumorphicLibraryContentPanel(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(NeumorphicStyle.surfaceRaised.opacity(0.96))
            .overlay(
                LinearGradient(
                    colors: [
                        Color(
                            light: Color.white.opacity(0.42),
                            dark: Color.white.opacity(0.05)
                        ),
                        tint.opacity(0.045),
                        NeumorphicStyle.surface.opacity(0.72),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        Color(
                            light: Color.white.opacity(0.44),
                            dark: Color.white.opacity(0.08)
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: Color(
                    light: Color.black.opacity(0.06),
                    dark: Color.black.opacity(0.26)
                ),
                radius: 12,
                x: 5,
                y: 7
            )
            .shadow(
                color: Color(
                    light: Color.white.opacity(0.54),
                    dark: Color.white.opacity(0.045)
                ),
                radius: 7,
                x: -4,
                y: -5
            )
    }

    private func sourceSwitch(selected: LibraryViewModel.MusicSource, onSelect: @escaping (LibraryViewModel.MusicSource) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(LibraryViewModel.MusicSource.allCases, id: \.self) { source in
                let isSelected = selected == source
                let tint = source == .ncm ? MusicSource.netease.themedBadgeColor : MusicSource.qqmusic.themedBadgeColor
                Button {
                    guard !isSelected else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        onSelect(source)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                        Text(source == .ncm ? "NCM" : "QCM")
                            .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                            .foregroundStyle(isSelected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 17,
                            elevated: isSelected,
                            pressed: !isSelected,
                            tint: isSelected ? tint.opacity(0.16) : NeumorphicStyle.surface,
                            lightweight: true
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 23, elevated: true, lightweight: true))
    }

    private func filterBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                content()
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    private func filterChip(title: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            guard !selected else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                action()
            }
        } label: {
            Text(title)
                .font(NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 16,
                        elevated: selected,
                        pressed: !selected,
                        tint: selected ? tint.opacity(0.16) : NeumorphicStyle.surface,
                        lightweight: true
                    )
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }

    private func actionChip(title: String, icon: MonologueIcon.IconType, tint: Color, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                        .scaleEffect(0.68)
                        .frame(width: 14, height: 14)
                } else {
                    MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.6)
                }
                Text(title)
                    .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, tint: tint.opacity(0.09), lightweight: true))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    private func playlistGrid(playlists: [Playlist], isLoading: Bool, emptyTitle: String) -> some View {
        Group {
            if isLoading && playlists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: 0, minHeight: 260)
            } else if playlists.isEmpty {
                emptyCard(icon: .list, title: emptyTitle, tint: NeumorphicStyle.sage)
            } else {
                LazyVGrid(columns: playlistColumns, spacing: 12) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            NeumorphicPlaylistShelfCard(
                                playlist: playlist,
                                tint: playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : MusicSource.netease.themedBadgeColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func artistGrid(artists: [ArtistInfo], isLoading: Bool, tint: Color) -> some View {
        Group {
            if isLoading && artists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: 0, minHeight: 260)
            } else if artists.isEmpty {
                emptyCard(icon: .personEmpty, title: String(localized: "empty_no_artists"), tint: tint)
            } else {
                LazyVGrid(columns: artistColumns, spacing: 12) {
                    ForEach(artists) { artist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                            NeumorphicArtistShelfTile(artist: artist, tint: tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func loadMoreButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey("查看更多"))
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true, tint: NeumorphicStyle.accent.opacity(0.12), lightweight: true))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
        .padding(.top, 2)
    }

    private func sectionTitle(_ title: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(title)
                .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
            Spacer(minLength: 0)
        }
    }

    private func emptyCard(icon: MonologueIcon.IconType, title: String, tint: Color) -> some View {
        VStack(spacing: 12) {
            MonologueIcon(icon: icon, size: 27, color: tint.opacity(0.72), lineWidth: 1.8)
                .frame(width: 54, height: 54)
                .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, tint: tint.opacity(0.11), lightweight: true))
            Text(title)
                .font(NeumorphicStyle.labelFont(13, weight: .medium))
                .foregroundStyle(NeumorphicStyle.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true, lightweight: true))
    }

    private var filteredQQCategories: [(id: Int, name: String)] {
        let hidden: Set<String> = [String(localized: "全部"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")]
        return viewModel.qqPlaylistCategories.filter { !hidden.contains($0.name.lowercased()) }
    }

    private var activeTint: Color {
        tint(for: selectedTab)
    }

    private var hasActiveArtistFilter: Bool {
        viewModel.artistArea != -1 || viewModel.artistType != -1 || viewModel.artistInitial != "-1"
    }

    private var hasActiveQQArtistFilter: Bool {
        viewModel.qqArtistArea != .all || viewModel.qqArtistSex != .all || viewModel.qqArtistGenre != .all
    }

    private func dismissArtistSearchKeyboard() {
        focusedArtistSearchField = nil
    }

    private func icon(for tab: LibraryViewModel.LibraryTab) -> MonologueIcon.IconType {
        switch tab {
        case .my: return .libraryFilled
        case .square: return .gridSquare
        case .artists: return .personCircle
        case .charts: return .chart
        }
    }

    private func tint(for tab: LibraryViewModel.LibraryTab) -> Color {
        switch tab {
        case .my: return NeumorphicStyle.accent
        case .square: return NeumorphicStyle.sage
        case .artists: return NeumorphicStyle.warm
        case .charts: return NeumorphicStyle.red
        }
    }

    private func tint(for shelf: Shelf) -> Color {
        switch shelf {
        case .localPlaylists: return NeumorphicStyle.accent
        case .ncmPlaylists: return MusicSource.netease.themedBadgeColor
        case .qcmPlaylists: return MusicSource.qqmusic.themedBadgeColor
        case .localPodcasts: return NeumorphicStyle.sage
        case .ncmPodcasts: return NeumorphicStyle.warm
        }
    }

    private func selectTab(_ tab: LibraryViewModel.LibraryTab, index: Int) {
        guard tabIndex != index || viewModel.currentTab != tab else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            tabIndex = index
            viewModel.currentTab = tab
        }
    }

    private func syncTabFromViewModel() {
        if let index = tabs.firstIndex(of: viewModel.currentTab), index != tabIndex {
            tabIndex = index
        }
    }

    private func loadCurrentTab() {
        load(selectedTab)
    }

    private func load(_ tab: LibraryViewModel.LibraryTab) {
        switch tab {
        case .my:
            viewModel.fetchPlaylists()
            if selectedShelf == .qcmPlaylists {
                loadQQUserPlaylistsIfNeeded()
            }
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        case .square:
            viewModel.squareSource == .qq ? viewModel.fetchQQSquareData() : viewModel.fetchSquareData()
        case .artists:
            viewModel.artistSource == .qq ? viewModel.fetchQQArtistData() : viewModel.fetchArtistData()
        case .charts:
            viewModel.chartsSource == .qq ? viewModel.fetchQQTopLists() : viewModel.fetchTopLists()
        }
    }

    private func loadQQUserPlaylistsIfNeeded(force: Bool = false) {
        guard force || !hasLoadedQQUserPlaylists else { return }
        guard !isLoadingQQUserPlaylists else { return }
        guard qqSession.isLoggedIn, let mid = qqSession.musicId else {
            qqUserPlaylists = []
            hasLoadedQQUserPlaylists = true
            return
        }

        isLoadingQQUserPlaylists = true
        Task { @MainActor in
            defer {
                isLoadingQQUserPlaylists = false
                hasLoadedQQUserPlaylists = true
            }

            do {
                let result: JSON = try await QQUserSession.shared.withUserSession { client in
                    try await client.createdSonglist(uin: String(mid))
                }
                qqUserPlaylists = Self.parseQQUserPlaylists(result)
            } catch {
                AppLogger.error("[Library] 加载 QCM 歌单失败: \(error)")
            }
        }
    }

    private static func parseQQUserPlaylists(_ result: JSON) -> [Playlist] {
        let list = result["v_playlist"]?.arrayValue ?? result.arrayValue ?? []
        return list.compactMap { json in
            guard let obj = json.objectValue else { return nil }
            let tid = obj["tid"]?.intValue ?? 0
            let name = obj["dirName"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
            let cover = obj["picUrl"]?.stringValue ?? obj["logo"]?.stringValue ?? ""
            let songCount = obj["songNum"]?.intValue ?? obj["song_cnt"]?.intValue ?? 0
            guard !name.isEmpty else { return nil }
            return Playlist(
                id: tid,
                name: name,
                coverImgUrl: cover,
                picUrl: nil,
                trackCount: songCount,
                playCount: nil,
                subscribedCount: nil,
                shareCount: nil,
                commentCount: nil,
                creator: nil,
                description: nil,
                tags: nil,
                source: .qqmusic
            )
        }
    }

    private func createLocalPlaylist() {
        AlertManager.shared.showInput(
            title: String(localized: "lib_create_playlist"),
            message: "",
            placeholder: String(localized: "lib_playlist_name"),
            primaryButtonTitle: String(localized: "lib_create"),
            secondaryButtonTitle: String(localized: "alert_cancel"),
            onConfirm: { name in
                guard !name.isEmpty else { return }
                _ = localManager.createPlaylist(name: name)
            }
        )
    }

    private func showImportLinkPrompt() {
        AlertManager.shared.showInput(
            title: String(localized: "从链接导入歌单"),
            message: "",
            placeholder: String(localized: "粘贴歌单链接"),
            primaryButtonTitle: String(localized: "导入"),
            secondaryButtonTitle: String(localized: "取消"),
            onConfirm: { url in
                importPlaylistFromURL(url)
            }
        )
    }

    private func importPlaylistFromFile(url: URL) {
        isImporting = true
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let parsed = try LocalPlaylistManager.parseExportFile(url: url)
            let ids = parsed.songIds
            let name = parsed.name
            guard !ids.isEmpty else {
                AlertManager.shared.show(title: String(localized: "lib_import_failed"), message: String(localized: "lib_import_no_songs"), primaryButtonTitle: String(localized: "lib_confirm"), primaryAction: {})
                isImporting = false
                return
            }

            Task {
                var allSongs: [Song] = []
                for i in stride(from: 0, to: ids.count, by: 50) {
                    let batch = Array(ids[i ..< min(i + 50, ids.count)])
                    do {
                        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                            var cancellable: AnyCancellable?
                            cancellable = APIService.shared.fetchSongDetails(ids: batch)
                                .sink(receiveCompletion: { completion in
                                    if case let .failure(error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                    cancellable?.cancel()
                                }, receiveValue: { songs in
                                    continuation.resume(returning: songs)
                                    cancellable?.cancel()
                                })
                        }
                        allSongs.append(contentsOf: songs)
                    } catch {
                        AppLogger.error("导入歌单批次获取失败: \(error)")
                    }
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(title: String(localized: "lib_import_failed"), message: String(localized: "lib_import_fetch_failed"), primaryButtonTitle: String(localized: "lib_confirm"), primaryAction: {})
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            }
        } catch {
            AlertManager.shared.show(title: String(localized: "lib_import_failed"), message: error.localizedDescription, primaryButtonTitle: String(localized: "lib_confirm"), primaryAction: {})
            isImporting = false
        }
    }

    private func importPlaylistFromURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isImporting = true

        if let qqId = extractQQPlaylistId(from: trimmed) {
            importQQPlaylist(id: qqId)
        } else if let ncmId = extractNCMPlaylistId(from: trimmed) {
            importNCMPlaylist(id: ncmId)
        } else {
            AlertManager.shared.show(title: String(localized: "lib_import_failed"), message: String(localized: "无法识别的歌单链接"), primaryButtonTitle: String(localized: "lib_confirm"), primaryAction: {})
            isImporting = false
        }
    }

    private func extractQQPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist/(\d+)"#, options: .regularExpression) {
            return Int(url[range].replacingOccurrences(of: "playlist/", with: ""))
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("y.qq.com") {
            return Int(String(url[range]).replacingOccurrences(of: "id=", with: ""))
        }
        return nil
    }

    private func extractNCMPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist\?id=(\d+)"#, options: .regularExpression) {
            return Int(String(url[range]).replacingOccurrences(of: "playlist?id=", with: ""))
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("music.163.com") {
            return Int(String(url[range]).replacingOccurrences(of: "id=", with: ""))
        }
        return nil
    }

    private func importQQPlaylist(id: Int) {
        Task {
            do {
                let detail = try await APIService.shared.qqClient.songlistDetail(songlistId: id, num: 1, page: 1)
                let name = detail["dirinfo"]?["title"]?.stringValue ?? String(localized: "QCM歌单")
                var allSongs: [Song] = []
                var page = 1
                var hasMore = true

                while hasMore {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: id, page: page, num: 50)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    hasMore = songs.count >= 50
                    page += 1
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(title: String(localized: "lib_import_failed"), message: String(localized: "歌单为空或获取失败"), primaryButtonTitle: String(localized: "lib_confirm"), primaryAction: {})
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(title: String(localized: "lib_import_failed"), message: String(localized: "QCM歌单导入失败: \(error.localizedDescription)"), primaryButtonTitle: String(localized: "lib_confirm"), primaryAction: {})
                    isImporting = false
                }
            }
        }
    }

    private func importNCMPlaylist(id: Int) {
        Task {
            var allSongs: [Song] = []
            var offset = 0
            let limit = 50
            var hasMore = true

            while hasMore {
                do {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: offset)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    hasMore = songs.count >= limit
                    offset += limit
                } catch {
                    hasMore = false
                }
            }

            await MainActor.run {
                if allSongs.isEmpty {
                    AlertManager.shared.show(title: String(localized: "lib_import_failed"), message: String(localized: "歌单为空或获取失败"), primaryButtonTitle: String(localized: "lib_confirm"), primaryAction: {})
                } else {
                    localManager.importPlaylist(name: String(localized: "NCM歌单"), songs: allSongs)
                }
                isImporting = false
            }
        }
    }

    private func chartDestination(_ list: TopList) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(id: list.id, name: list.name, coverImgUrl: list.coverImgUrl, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil, isTopList: true))
    }

    private func qqChartDestination(_ item: QQTopListItem) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(id: item.topId, name: item.title, coverImgUrl: item.coverUrl, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: item.intro.isEmpty ? nil : item.intro, tags: nil, source: .qqmusic, isTopList: true))
    }
}

// MARK: - Shared Scrollable Library

private struct ScrollableLibraryExperience: View {
    private enum MyLibraryColumn: CaseIterable, Hashable {
        case localPlaylists, ncmPlaylists, qcmPlaylists, localPodcasts, ncmPodcasts

        var title: String {
            switch self {
            case .localPlaylists: return String(localized: "lib_local_playlists")
            case .ncmPlaylists: return String(localized: "lib_netease_playlists")
            case .qcmPlaylists: return String(localized: "QCM歌单")
            case .localPodcasts: return String(localized: "本地播客")
            case .ncmPodcasts: return String(localized: "NCM 播客")
            }
        }

        var icon: MonologueIcon.IconType {
            switch self {
            case .localPlaylists: return .musicNoteList
            case .ncmPlaylists, .qcmPlaylists: return .list
            case .localPodcasts, .ncmPodcasts: return .radio
            }
        }
    }

    @ObservedObject var viewModel: LibraryViewModel
    @Binding var tabIndex: Int
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var localManager = LocalPlaylistManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var qqSession = QQUserSession.shared
    @State private var selectedMyLibraryColumn: MyLibraryColumn = .localPlaylists
    @State private var isLibraryActionsExpanded = false
    @State private var showFileImporter = false
    @State private var showQQImport = false
    @State private var isImporting = false
    @State private var qqUserPlaylists: [Playlist] = []
    @State private var isLoadingQQUserPlaylists = false
    @State private var hasLoadedQQUserPlaylists = false
    @Namespace private var sequoiaLibraryNamespace

    private let tabs = LibraryViewModel.LibraryTab.allCases
    private let twoColumns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]
    private let actionColumns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
    private let artistColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: DeviceLayout.artistGridColumns)

    private var selectedTab: LibraryViewModel.LibraryTab {
        tabs[min(max(tabIndex, 0), tabs.count - 1)]
    }

    private var activeTabTint: Color {
        tint(for: selectedTab)
    }

    private var activeTabEyebrow: String {
        switch selectedTab {
        case .my: return "COLLECTION"
        case .square: return "DISCOVER"
        case .artists: return "ARTISTS"
        case .charts: return "CHARTS"
        }
    }

    private var activeTabShortLabel: String {
        switch selectedTab {
        case .my: return String(localized: "我的")
        case .square: return String(localized: "广场")
        case .artists: return String(localized: "歌手")
        case .charts: return String(localized: "榜单")
        }
    }

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    tabContent
                }
                .padding(.bottom, 128)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .onAppear {
            syncTabFromViewModel()
            loadCurrentTab()
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
        .onChange(of: viewModel.currentTab) { _, _ in
            syncTabFromViewModel()
            loadCurrentTab()
        }
        .onChange(of: tabIndex) { _, _ in
            loadCurrentTab()
        }
        .onChange(of: qqSession.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                hasLoadedQQUserPlaylists = false
                loadQQUserPlaylistsIfNeeded(force: true)
            } else {
                qqUserPlaylists = []
                hasLoadedQQUserPlaylists = false
            }
        }
        .monologueSheet(isPresented: $showQQImport, preset: .large) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case let .failure(error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if NeumorphicStyle.isActive {
            neumorphicHeaderDeck
        } else if SignalStyle.isActive {
            signalHeaderDeck
        } else if SequoiaStyle.isActive {
            sequoiaHeaderDeck
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if MujiStyle.isActive {
                    MujiPageHeader(eyebrow: "collection shelves", title: String(localized: "tabbar_library"), subtitle: "") {
                        MujiIconBadge(icon: .library, tint: MujiStyle.tea, size: 48)
                    }
                } else {
                    HStack(spacing: 12) {
                        MonologueIcon(icon: .libraryFilled, size: 24, color: .monologueIconForeground, lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .background(Color.monologueIconBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.monologueIconBackground.opacity(0.18), radius: 10, y: 5)

                        Text(LocalizedStringKey("tabbar_library"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)

                        Spacer(minLength: 0)
                    }
                }

                tabStrip
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)
        }
    }

    private var neumorphicHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 14) {
                    NeumorphicIconBadge(icon: icon(for: selectedTab), tint: activeTabTint, size: 52)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(activeTabEyebrow)
                            .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                            .foregroundStyle(activeTabTint)
                            .tracking(1.1)

                        Text(String(localized: "tabbar_library"))
                            .font(NeumorphicStyle.titleFont(30, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.ink)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(activeTabShortLabel)
                        .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(activeTabTint)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(activeTabTint.opacity(0.13))
                        )
                }

            }
            .padding(16)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 28,
                    elevated: true,
                    tint: activeTabTint.opacity(0.06)
                )
            )

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
    }

    private var signalHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        SignalPulseDot(tint: activeTabTint, size: 18)

                        Text(activeTabEyebrow)
                            .font(SignalStyle.monoFont(10, weight: .semibold))
                            .foregroundStyle(activeTabTint)
                    }

                    Text(String(localized: "tabbar_library"))
                        .font(SignalStyle.titleFont(27, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    SignalLibraryMiniBars(tint: activeTabTint)
                    SignalPill(text: activeTabShortLabel, tint: activeTabTint, selected: true, compact: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SignalSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, fill: SignalStyle.control))
            }

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
    }

    private var sequoiaHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 13) {
                VStack(spacing: 4) {
                    Capsule()
                        .fill(activeTabTint)
                        .frame(width: 4, height: 26)
                    Capsule()
                        .fill(SequoiaStyle.separator)
                        .frame(width: 4, height: 10)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activeTabEyebrow)
                        .font(SequoiaStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(activeTabTint)
                        .tracking(0.9)

                    Text(String(localized: "tabbar_library"))
                        .font(SequoiaStyle.titleFont(25, weight: .semibold))
                        .foregroundStyle(SequoiaStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 9) {
                    SequoiaMeter(tint: activeTabTint, count: 9)
                    SequoiaPill(text: activeTabShortLabel, tint: activeTabTint, selected: true, compact: true)
                }
            }
            .padding(14)
            .background(SequoiaChromeBar(cornerRadius: 23))

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    @ViewBuilder
    private var tabStrip: some View {
        if NeumorphicStyle.isActive {
            neumorphicTabDeck
        } else if SignalStyle.isActive {
            signalTabDeck
        } else if SequoiaStyle.isActive {
            sequoiaTabDeck
        } else {
            HStack(spacing: 6) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    let selected = tabIndex == index
                    Button {
                        selectTab(tab, index: index)
                    } label: {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: icon(for: tab), size: 13, color: tabForeground(selected: selected), lineWidth: 1.8)
                            Text(tab.localizedKey)
                                .font(tabFont(selected: selected))
                                .foregroundColor(tabForeground(selected: selected))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: NeumorphicStyle.isActive ? 40 : 38)
                        .background(tabBackground(selected: selected, tint: tint(for: tab)))
                        .contentShape(RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(NeumorphicStyle.isActive ? 5 : 4)
            .background(panelBackground(cornerRadius: NeumorphicStyle.isActive ? 20 : 14))
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: tabIndex)
        }
    }

    private var neumorphicTabDeck: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                neumorphicTabButton(tab: tab, index: index)
            }
        }
        .padding(6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true))
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: tabIndex)
    }

    private func neumorphicTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            VStack(spacing: 5) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 15,
                    color: selected ? tint : NeumorphicStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(NeumorphicStyle.labelFont(10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.17) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private var signalTabDeck: some View {
        HStack(spacing: 7) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                signalTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(SignalSurfaceBackground(cornerRadius: 22, elevated: true, fill: SignalStyle.device))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    private func signalTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 14,
                    color: selected ? tint : SignalStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(SignalStyle.labelFont(11.5, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? SignalStyle.ink : SignalStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                SignalSurfaceBackground(
                    cornerRadius: 16,
                    elevated: selected,
                    pressed: !selected,
                    fill: selected ? tint.opacity(0.16) : SignalStyle.control
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private var sequoiaTabDeck: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                sequoiaTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, role: .chrome))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    private func sequoiaTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 13,
                    color: selected ? tint : SequoiaStyle.inkSoft,
                    lineWidth: selected ? 1.75 : 1.45
                )

                Text(tab.localizedKey)
                    .font(SequoiaStyle.labelFont(11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SequoiaStyle.selectedWash)
                        .matchedGeometryEffect(id: "library-tab", in: sequoiaLibraryNamespace)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(tint.opacity(0.24), lineWidth: 0.55)
                        )
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .my:
            myLibraryPage
        case .square:
            playlistSquarePage
        case .artists:
            artistsPage
        case .charts:
            chartsPage
        }
    }

    private var myLibraryPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            myLibraryControlPanel
            myLibraryColumnContent
        }
    }

    @ViewBuilder
    private var myLibraryControlPanel: some View {
        if NeumorphicStyle.isActive {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "浏览分区"))
                            .font(NeumorphicStyle.titleFont(16, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.ink)

                        Text(selectedMyLibraryColumn.title)
                            .font(NeumorphicStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(tint(for: selectedMyLibraryColumn))
                    }

                    Spacer(minLength: 8)

                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            isLibraryActionsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: isLibraryActionsExpanded ? .close : .more, size: 14, color: isLibraryActionsExpanded ? defaultAccent : NeumorphicStyle.inkSoft, lineWidth: 1.7)
                            Text(String(localized: "工具"))
                                .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                                .foregroundStyle(isLibraryActionsExpanded ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            NeumorphicSurfaceBackground(
                                cornerRadius: 15,
                                elevated: isLibraryActionsExpanded,
                                pressed: !isLibraryActionsExpanded,
                                tint: isLibraryActionsExpanded ? defaultAccent.opacity(0.15) : NeumorphicStyle.surface,
                                lightweight: true
                            )
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                }

                columnStrip

                LibraryDisclosureReveal(isExpanded: isLibraryActionsExpanded) {
                    actionStrip
                        .padding(10)
                        .background(
                            NeumorphicSurfaceBackground(
                                cornerRadius: 20,
                                elevated: false,
                                pressed: true,
                                lightweight: true
                            )
                        )
                }
            }
            .padding(13)
            .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true))
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    columnStrip.layoutPriority(1)

                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            isLibraryActionsExpanded.toggle()
                        }
                    } label: {
                        MonologueIcon(icon: isLibraryActionsExpanded ? .close : .more, size: 16, color: isLibraryActionsExpanded ? selectedChipText : secondaryText, lineWidth: 1.8)
                            .frame(width: 42, height: 42)
                            .background(panelBackground(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isLibraryActionsExpanded ? defaultAccent.opacity(0.14) : .clear)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                }

                LibraryDisclosureReveal(isExpanded: isLibraryActionsExpanded) {
                    actionStrip
                        .padding(10)
                        .background(panelBackground(cornerRadius: 18))
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        }
    }

    private var columnStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MyLibraryColumn.allCases, id: \.self) { column in
                    let selected = selectedMyLibraryColumn == column
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedMyLibraryColumn = column
                        }
                        if column == .qcmPlaylists {
                            loadQQUserPlaylistsIfNeeded()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            MonologueIcon(icon: column.icon, size: 14, color: selected ? selectedChipText : secondaryText, lineWidth: selected ? 2 : 1.6)
                            Text(column.title)
                                .font(chipFont(selected: selected))
                                .foregroundColor(selected ? selectedChipText : secondaryText)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 42)
                        .background(chipBackground(selected: selected, tint: tint(for: column), capsule: true))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    @ViewBuilder
    private var myLibraryColumnContent: some View {
        switch selectedMyLibraryColumn {
        case .localPlaylists: localPlaylistsSection
        case .ncmPlaylists: ncmPlaylistsSection
        case .qcmPlaylists: qcmPlaylistsSection
        case .localPodcasts: localPodcastsSection
        case .ncmPodcasts: ncmPodcastsSection
        }
    }

    private var actionStrip: some View {
        LazyVGrid(columns: actionColumns, spacing: 9) {
            actionChip(title: String(localized: "lib_create"), icon: .add, tint: defaultAccent) {
                createLocalPlaylist()
            }

            actionChip(title: String(localized: "lib_import_playlist"), icon: .download, tint: secondaryAccent, isLoading: isImporting) {
                showFileImporter = true
            }
            .disabled(isImporting)

            actionChip(title: String(localized: "从链接导入"), icon: .share, tint: tertiaryAccent, isLoading: isImporting) {
                showImportLinkPrompt()
            }
            .disabled(isImporting)

            actionChip(title: String(localized: "QCM歌单"), icon: .musicNoteList, tint: MusicSource.qqmusic.themedBadgeColor) {
                showQQImport = true
            }
        }
    }

    private var localPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.localPlaylists.title)

            if localManager.playlists.isEmpty {
                ThemedLibraryEmptyState(icon: .musicNoteList, title: String(localized: "lib_no_local_playlists"), tint: defaultAccent)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(localManager.playlists, id: \.id) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                            LocalPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private var ncmPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.ncmPlaylists.title)

            if viewModel.userPlaylists.isEmpty {
                ThemedLibraryEmptyState(icon: .list, title: String(localized: "empty_no_playlists"), tint: MusicSource.netease.themedBadgeColor)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.userPlaylists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private var qcmPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.qcmPlaylists.title)

            if isLoadingQQUserPlaylists && qqUserPlaylists.isEmpty {
                LibraryLoadingStateView()
            } else if !qqSession.isLoggedIn {
                ThemedLibraryEmptyState(icon: .musicNoteList, title: String(localized: "请先登录 QCM"), tint: MusicSource.qqmusic.themedBadgeColor)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else if qqUserPlaylists.isEmpty {
                ThemedLibraryEmptyState(icon: .list, title: String(localized: "暂无 QCM 歌单"), tint: MusicSource.qqmusic.themedBadgeColor)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(qqUserPlaylists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private var localPodcastsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.localPodcasts.title)

            if subManager.localSubscribedRadios.isEmpty {
                ThemedLibraryEmptyState(icon: .radio, title: String(localized: "暂无本地收藏"), tint: tertiaryAccent)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(subManager.localSubscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            ThemedLibraryPodcastRow(radio: radio, tint: tertiaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private var ncmPodcastsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.ncmPodcasts.title)

            if subManager.isLoadingRadios && subManager.subscribedRadios.isEmpty {
                LibraryLoadingStateView()
            } else if subManager.subscribedRadios.isEmpty {
                ThemedLibraryEmptyState(icon: .radio, title: String(localized: "lib_no_podcasts"), tint: secondaryAccent)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(subManager.subscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            ThemedLibraryPodcastRow(radio: radio, tint: secondaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private var playlistSquarePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            sourceStrip(selected: viewModel.squareSource) { source in
                viewModel.squareSource = source
                source == .qq ? viewModel.fetchQQSquareData() : viewModel.fetchSquareData()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

            if viewModel.squareSource == .qq {
                qqCategoryBar
                playlistGrid(playlists: viewModel.qqSquarePlaylists, isLoading: viewModel.isLoadingQQSquare, emptyTitle: String(localized: "暂无QCM推荐歌单"))

                if viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                    loadMoreButton { viewModel.loadMoreQQSquarePlaylists() }
                }
            } else {
                ncmCategoryBar
                playlistGrid(playlists: viewModel.squarePlaylists, isLoading: viewModel.isLoadingSquare, emptyTitle: String(localized: "empty_no_playlists"))

                if viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                    loadMoreButton { viewModel.loadMoreSquarePlaylists() }
                }
            }
        }
    }

    private var artistsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            sourceStrip(selected: viewModel.artistSource) { source in
                viewModel.artistSource = source
                source == .qq ? viewModel.fetchQQArtistData(reset: true) : viewModel.fetchArtistData(reset: true)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

            if viewModel.artistSource == .qq {
                qqArtistFilterBars
                artistGrid(artists: viewModel.qqArtists, isLoading: viewModel.isLoadingQQArtists, tint: MusicSource.qqmusic.themedBadgeColor)
                if viewModel.hasMoreQQArtists && !viewModel.qqArtists.isEmpty {
                    loadMoreButton { viewModel.loadMoreQQArtists() }
                }
            } else {
                ncmArtistFilterBars
                artistGrid(artists: viewModel.topArtists, isLoading: viewModel.isLoadingArtists, tint: tertiaryAccent)
                if viewModel.hasMoreArtists && !viewModel.topArtists.isEmpty {
                    loadMoreButton { viewModel.loadMoreArtists() }
                }
            }
        }
    }

    private var chartsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            if NeumorphicStyle.isActive {
                sourceStrip(selected: viewModel.chartsSource) { source in
                    viewModel.chartsSource = source
                    source == .qq ? viewModel.fetchQQTopLists() : viewModel.fetchTopLists()
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }

            if NeumorphicStyle.isActive, viewModel.chartsSource == .qq {
                qqChartsContent
            } else {
                if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                    LibraryLoadingStateView()
                } else if viewModel.topLists.isEmpty {
                    ThemedLibraryEmptyState(icon: .chart, title: String(localized: "empty_no_charts"), tint: secondaryAccent)
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                } else {
                    let officialIds: Set<Int> = [19_723_756, 3_779_629, 2_884_035, 3_778_678]
                    let official = viewModel.topLists.filter { officialIds.contains($0.id) }
                    let others = viewModel.topLists.filter { !officialIds.contains($0.id) }

                    if !official.isEmpty {
                        ThemedLibrarySectionHeader(title: String(localized: "charts_official"))
                        ScrollView(.horizontal) {
                            HStack(spacing: 14) {
                                ForEach(official) { list in
                                    NavigationLink(value: chartDestination(list)) {
                                        OfficialChartCard(list: list)
                                    }
                                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                                }
                            }
                            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                        }
                        .scrollIndicators(.hidden)
                        .themeRenderScrollLayer()
                    }

                    if !others.isEmpty {
                        ThemedLibrarySectionHeader(title: String(localized: "charts_more"))
                        LazyVGrid(columns: artistColumns, spacing: 16) {
                            ForEach(others) { list in
                                NavigationLink(value: chartDestination(list)) {
                                    CompactChartCard(list: list)
                                }
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                            }
                        }
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    }
                }
            }
        }
    }

    private var qqChartsContent: some View {
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
                                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
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
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                            }
                        }
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    }
                }
            }
        }
    }

    private var ncmCategoryBar: some View {
        horizontalFilterBar {
            ForEach(viewModel.playlistCategories, id: \.idString) { category in
                filterChip(title: category.name, selected: viewModel.selectedCategory == category.name, tint: MusicSource.netease.themedBadgeColor) {
                    viewModel.selectedCategory = category.name
                    viewModel.loadSquarePlaylists(cat: category.name, reset: true)
                }
            }
        }
    }

    private var qqCategoryBar: some View {
        horizontalFilterBar {
            ForEach(filteredQQCategories, id: \.id) { category in
                filterChip(title: category.name, selected: viewModel.selectedQQCategoryId == category.id, tint: MusicSource.qqmusic.themedBadgeColor) {
                    viewModel.selectQQCategory(id: category.id, name: category.name)
                }
            }
        }
    }

    private var filteredQQCategories: [(id: Int, name: String)] {
        let hidden: Set<String> = [String(localized: "全部"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")]
        return viewModel.qqPlaylistCategories.filter { !hidden.contains($0.name.lowercased()) }
    }

    private var ncmArtistFilterBars: some View {
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

    private var qqArtistFilterBars: some View {
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

    private func playlistGrid(playlists: [Playlist], isLoading: Bool, emptyTitle: String) -> some View {
        Group {
            if isLoading && playlists.isEmpty {
                LibraryLoadingStateView()
            } else if playlists.isEmpty {
                ThemedLibraryEmptyState(icon: .list, title: emptyTitle, tint: defaultAccent)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            if NeumorphicStyle.isActive {
                                NeumorphicPlaylistPoster(
                                    playlist: playlist,
                                    tint: playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : MusicSource.netease.themedBadgeColor
                                )
                            } else if SequoiaStyle.isActive {
                                SequoiaLibraryPlaylistTile(
                                    playlist: playlist,
                                    tint: playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : MusicSource.netease.themedBadgeColor
                                )
                            } else {
                                CinematicCard(playlist: playlist, height: 168)
                            }
                        }
                        .buttonStyle(CinematicPressStyle())
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private func artistGrid(artists: [ArtistInfo], isLoading: Bool, tint: Color) -> some View {
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private func sourceStrip(selected: LibraryViewModel.MusicSource, onSelect: @escaping (LibraryViewModel.MusicSource) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(LibraryViewModel.MusicSource.allCases, id: \.self) { source in
                let isSelected = selected == source
                let tint = source == .ncm ? MusicSource.netease.themedBadgeColor : MusicSource.qqmusic.themedBadgeColor
                Button {
                    guard !isSelected else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        onSelect(source)
                    }
                } label: {
                    if NeumorphicStyle.isActive {
                        HStack(spacing: 7) {
                            MonologueIcon(icon: source == .ncm ? .musicNoteList : .library, size: 13, color: isSelected ? tint : secondaryText, lineWidth: 1.65)
                            Text(source == .ncm ? "NCM" : "QCM")
                                .font(chipFont(selected: isSelected))
                                .foregroundColor(isSelected ? primaryText : secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(chipBackground(selected: isSelected, tint: tint, capsule: false))
                    } else {
                        Text(source == .ncm ? "NCM" : "QCM")
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

    private func horizontalFilterBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                content()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func filterChip(title: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
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
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }

    private func actionChip(title: String, icon: MonologueIcon.IconType, tint: Color, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                        .scaleEffect(0.68)
                        .frame(width: 14, height: 14)
                } else {
                    MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.7)
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
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private func loadMoreButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey("查看更多"))
                .font(chipFont(selected: true))
                .foregroundColor(selectedChipText)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(chipBackground(selected: true, tint: defaultAccent, capsule: false))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, 4)
    }

    private func selectTab(_ tab: LibraryViewModel.LibraryTab, index: Int) {
        tabIndex = index
        viewModel.currentTab = tab
        load(tab)
    }

    private func syncTabFromViewModel() {
        if let index = tabs.firstIndex(of: viewModel.currentTab), index != tabIndex {
            tabIndex = index
        }
    }

    private func loadCurrentTab() {
        load(selectedTab)
    }

    private func load(_ tab: LibraryViewModel.LibraryTab) {
        switch tab {
        case .my:
            viewModel.fetchPlaylists()
            if selectedMyLibraryColumn == .qcmPlaylists {
                loadQQUserPlaylistsIfNeeded()
            }
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        case .square:
            viewModel.squareSource == .qq ? viewModel.fetchQQSquareData() : viewModel.fetchSquareData()
        case .artists:
            viewModel.artistSource == .qq ? viewModel.fetchQQArtistData() : viewModel.fetchArtistData()
        case .charts:
            if NeumorphicStyle.isActive && viewModel.chartsSource == .qq {
                viewModel.fetchQQTopLists()
            } else {
                viewModel.fetchTopLists()
            }
        }
    }

    private func loadQQUserPlaylistsIfNeeded(force: Bool = false) {
        guard force || !hasLoadedQQUserPlaylists else { return }
        guard !isLoadingQQUserPlaylists else { return }
        guard qqSession.isLoggedIn, let mid = qqSession.musicId else {
            qqUserPlaylists = []
            hasLoadedQQUserPlaylists = true
            return
        }

        isLoadingQQUserPlaylists = true
        Task { @MainActor in
            defer {
                isLoadingQQUserPlaylists = false
                hasLoadedQQUserPlaylists = true
            }

            do {
                let result: JSON = try await QQUserSession.shared.withUserSession { client in
                    try await client.createdSonglist(uin: String(mid))
                }
                qqUserPlaylists = Self.parseQQUserPlaylists(result)
            } catch {
                AppLogger.error("[Library] 加载 QCM 歌单失败: \(error)")
            }
        }
    }

    private static func parseQQUserPlaylists(_ result: JSON) -> [Playlist] {
        let list = result["v_playlist"]?.arrayValue ?? result.arrayValue ?? []
        return list.compactMap { json in
            guard let obj = json.objectValue else { return nil }
            let tid = obj["tid"]?.intValue ?? 0
            let name = obj["dirName"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
            let cover = obj["picUrl"]?.stringValue ?? obj["logo"]?.stringValue ?? ""
            let songCount = obj["songNum"]?.intValue ?? obj["song_cnt"]?.intValue ?? 0
            guard !name.isEmpty else { return nil }
            return Playlist(
                id: tid,
                name: name,
                coverImgUrl: cover,
                picUrl: nil,
                trackCount: songCount,
                playCount: nil,
                subscribedCount: nil,
                shareCount: nil,
                commentCount: nil,
                creator: nil,
                description: nil,
                tags: nil,
                source: .qqmusic
            )
        }
    }

    private func createLocalPlaylist() {
        AlertManager.shared.showInput(
            title: String(localized: "lib_create_playlist"),
            message: "",
            placeholder: String(localized: "lib_playlist_name"),
            primaryButtonTitle: String(localized: "lib_create"),
            secondaryButtonTitle: String(localized: "alert_cancel"),
            onConfirm: { name in
                guard !name.isEmpty else { return }
                _ = localManager.createPlaylist(name: name)
            }
        )
    }

    private func showImportLinkPrompt() {
        AlertManager.shared.showInput(
            title: String(localized: "从链接导入歌单"),
            message: "",
            placeholder: String(localized: "粘贴歌单链接"),
            primaryButtonTitle: String(localized: "导入"),
            secondaryButtonTitle: String(localized: "取消"),
            onConfirm: { url in
                importPlaylistFromURL(url)
            }
        )
    }

    private func importPlaylistFromFile(url: URL) {
        isImporting = true
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let parsed = try LocalPlaylistManager.parseExportFile(url: url)
            let ids = parsed.songIds
            let name = parsed.name
            guard !ids.isEmpty else {
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: String(localized: "lib_import_no_songs"),
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
                isImporting = false
                return
            }

            Task {
                var allSongs: [Song] = []
                for i in stride(from: 0, to: ids.count, by: 50) {
                    let batch = Array(ids[i ..< min(i + 50, ids.count)])
                    do {
                        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                            var cancellable: AnyCancellable?
                            cancellable = APIService.shared.fetchSongDetails(ids: batch)
                                .sink(receiveCompletion: { completion in
                                    if case let .failure(error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                    cancellable?.cancel()
                                }, receiveValue: { songs in
                                    continuation.resume(returning: songs)
                                    cancellable?.cancel()
                                })
                        }
                        allSongs.append(contentsOf: songs)
                    } catch {
                        AppLogger.error("导入歌单批次获取失败: \(error)")
                    }
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "lib_import_fetch_failed"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            }
        } catch {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    private func importPlaylistFromURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isImporting = true

        if let qqId = extractQQPlaylistId(from: trimmed) {
            importQQPlaylist(id: qqId)
        } else if let ncmId = extractNCMPlaylistId(from: trimmed) {
            importNCMPlaylist(id: ncmId)
        } else {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: String(localized: "无法识别的歌单链接"),
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    private func extractQQPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist/(\d+)"#, options: .regularExpression) {
            return Int(url[range].replacingOccurrences(of: "playlist/", with: ""))
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("y.qq.com") {
            return Int(String(url[range]).replacingOccurrences(of: "id=", with: ""))
        }
        return nil
    }

    private func extractNCMPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist\?id=(\d+)"#, options: .regularExpression) {
            return Int(String(url[range]).replacingOccurrences(of: "playlist?id=", with: ""))
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("music.163.com") {
            return Int(String(url[range]).replacingOccurrences(of: "id=", with: ""))
        }
        return nil
    }

    private func importQQPlaylist(id: Int) {
        Task {
            do {
                let detail = try await APIService.shared.qqClient.songlistDetail(songlistId: id, num: 1, page: 1)
                let name = detail["dirinfo"]?["title"]?.stringValue ?? String(localized: "QCM歌单")
                var allSongs: [Song] = []
                var page = 1
                var hasMore = true

                while hasMore {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: id, page: page, num: 50)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    hasMore = songs.count >= 50
                    page += 1
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "歌单为空或获取失败"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "QCM歌单导入失败: \(error.localizedDescription)"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                    isImporting = false
                }
            }
        }
    }

    private func importNCMPlaylist(id: Int) {
        Task {
            var allSongs: [Song] = []
            var offset = 0
            let limit = 50
            var hasMore = true

            while hasMore {
                do {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: offset)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    hasMore = songs.count >= limit
                    offset += limit
                } catch {
                    hasMore = false
                }
            }

            await MainActor.run {
                if allSongs.isEmpty {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "歌单为空或获取失败"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                } else {
                    localManager.importPlaylist(name: String(localized: "NCM歌单"), songs: allSongs)
                }
                isImporting = false
            }
        }
    }

    private func chartDestination(_ list: TopList) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: list.id,
            name: list.name,
            coverImgUrl: list.coverImgUrl,
            picUrl: nil,
            trackCount: nil,
            playCount: nil,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: nil,
            tags: nil,
            isTopList: true
        ))
    }

    private func qqChartDestination(_ item: QQTopListItem) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: item.topId,
            name: item.title,
            coverImgUrl: item.coverUrl,
            picUrl: nil,
            trackCount: nil,
            playCount: nil,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: item.intro.isEmpty ? nil : item.intro,
            tags: nil,
            source: .qqmusic,
            isTopList: true
        ))
    }

    private func icon(for tab: LibraryViewModel.LibraryTab) -> MonologueIcon.IconType {
        switch tab {
        case .my: return .libraryFilled
        case .square: return .gridSquare
        case .artists: return .personCircle
        case .charts: return .chart
        }
    }

    private func tint(for tab: LibraryViewModel.LibraryTab) -> Color {
        switch tab {
        case .my: return defaultAccent
        case .square: return secondaryAccent
        case .artists: return tertiaryAccent
        case .charts: return quaternaryAccent
        }
    }

    private func tint(for column: MyLibraryColumn) -> Color {
        switch column {
        case .localPlaylists: return defaultAccent
        case .ncmPlaylists: return MusicSource.netease.themedBadgeColor
        case .qcmPlaylists: return MusicSource.qqmusic.themedBadgeColor
        case .localPodcasts: return tertiaryAccent
        case .ncmPodcasts: return secondaryAccent
        }
    }

    private var primaryText: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryText: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var defaultAccent: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if MujiStyle.isActive { return MujiStyle.tea }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monologueAccent
    }

    private var secondaryAccent: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
        if SignalStyle.isActive { return SignalStyle.olive }
        if MujiStyle.isActive { return MujiStyle.clay }
        if SequoiaStyle.isActive { return SequoiaStyle.aqua }
        return .monologueAccentBlue
    }

    private var tertiaryAccent: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.warm }
        if SignalStyle.isActive { return SignalStyle.rust }
        if MujiStyle.isActive { return MujiStyle.indigo }
        if SequoiaStyle.isActive { return SequoiaStyle.green }
        return .monologueAccentGreen
    }

    private var quaternaryAccent: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.red }
        if SignalStyle.isActive { return SignalStyle.red }
        if MujiStyle.isActive { return MujiStyle.red }
        if SequoiaStyle.isActive { return SequoiaStyle.violet }
        return .monologueAccentRed
    }

    private var selectedChipText: Color {
        MujiStyle.isActive ? MujiStyle.onTint : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueIconForeground)))
    }

    private var tabCornerRadius: CGFloat {
        NeumorphicStyle.isActive ? 15 : (SignalStyle.isActive ? 16 : (MujiStyle.isActive ? 8 : (SequoiaStyle.isActive ? 14 : 14)))
    }

    private func tabFont(selected: Bool) -> Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        return .system(size: 13, weight: selected ? .bold : .medium, design: .rounded)
    }

    private func chipFont(selected: Bool) -> Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        return .system(size: 13, weight: selected ? .semibold : .medium, design: .rounded)
    }

    private func tabForeground(selected: Bool) -> Color {
        selected ? selectedChipText : secondaryText
    }

    private func tabBackground(selected: Bool, tint: Color) -> some View {
        Group {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, tint: selected ? tint.opacity(0.15) : NeumorphicStyle.surface, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.16) : SignalStyle.control)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? SequoiaStyle.selectedWash : SequoiaStyle.materialList, role: selected ? .selected : .list)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
                    .fill(selected ? MujiStyle.ink : MujiStyle.surface.opacity(0.78))
                    .overlay(RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous).stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.45), lineWidth: 0.6))
            } else {
                RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
                    .fill(selected ? Color.monologueIconBackground : Color.monologueGlassTint)
            }
        }
    }

    private func chipBackground(selected: Bool, tint: Color, capsule: Bool) -> some View {
        Group {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: capsule ? 18 : 15, elevated: selected, pressed: !selected, tint: selected ? tint.opacity(0.16) : NeumorphicStyle.surface, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: capsule ? 12 : 10, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.18) : SignalStyle.control)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: capsule ? 18 : 13, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.13) : SequoiaStyle.materialList, role: selected ? .selected : .list)
            } else if MujiStyle.isActive {
                let shape = RoundedRectangle(cornerRadius: capsule ? 18 : 8, style: .continuous)
                shape
                    .fill(selected ? MujiStyle.ink : MujiStyle.surface.opacity(0.78))
                    .overlay(shape.stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))
            } else if capsule {
                Capsule().fill(selected ? Color.monologueIconBackground : Color.monologueGlassTint)
            } else {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? Color.monologueIconBackground : Color.monologueGlassTint)
            }
        }
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        Group {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: cornerRadius, elevated: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: min(cornerRadius, 18), elevated: true, fill: SignalStyle.device)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: min(cornerRadius, 20), elevated: true, role: .chrome)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
            } else {
                Color.clear.monologueGlass(cornerRadius: cornerRadius)
            }
        }
    }
}

private struct ThemedLibrarySectionHeader: View {
    let title: String

    var body: some View {
        if NeumorphicStyle.isActive {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(NeumorphicStyle.accent.opacity(0.78))
                    .frame(width: 4, height: 18)

                Text(title)
                    .font(NeumorphicStyle.titleFont(17, weight: .semibold))
                    .foregroundColor(NeumorphicStyle.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else if SignalStyle.isActive {
            HStack(spacing: 9) {
                SignalPulseDot(tint: SignalStyle.accent, size: 17)

                Text(title)
                    .font(SignalStyle.titleFont(16, weight: .bold))
                    .foregroundColor(SignalStyle.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else if SequoiaStyle.isActive {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 3, height: 18)

                Text(title)
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundColor(SequoiaStyle.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else {
            Text(title)
                .font(MujiStyle.isActive ? MujiStyle.titleFont(17, weight: .semibold) : .system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(MujiStyle.isActive ? MujiStyle.ink : .monologueTextPrimary)
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        }
    }
}

private struct SignalLibraryMiniBars: View {
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < 3 ? tint : SignalStyle.inkMuted.opacity(0.24))
                    .frame(width: 4, height: 6 + CGFloat(index) * 3)
            }
        }
        .frame(height: 17)
    }
}

private struct LibraryLoadingStateView: View {
    var text: String? = nil
    var horizontalPadding: CGFloat? = nil
    var minHeight: CGFloat? = nil

    var body: some View {
        let resolvedMinHeight = minHeight ?? (DeviceLayout.isPad ? 420 : 320)
        let resolvedPadding = horizontalPadding ?? DeviceLayout.libraryHorizontalPadding

        if SequoiaStyle.isActive {
            VStack(spacing: 12) {
                SequoiaIconBadge(icon: .library, tint: SequoiaStyle.accent, size: 50)
                ProgressView()
                    .tint(SequoiaStyle.accent)
                    .scaleEffect(0.82)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: resolvedMinHeight, alignment: .center)
            .background(SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
            .padding(.horizontal, resolvedPadding)
        } else {
            MonologueLoadingView(text: text)
                .frame(maxWidth: .infinity)
                .frame(minHeight: resolvedMinHeight, alignment: .center)
                .padding(.horizontal, resolvedPadding)
        }
    }
}

private struct LibraryInlineLoadingView: View {
    var text: String? = nil

    var body: some View {
        MonologueLoadingView(text: text, centered: false)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }
}

private struct ThemedLibraryEmptyState: View {
    let icon: MonologueIcon.IconType
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 12) {
            if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: icon, tint: tint, size: 50)
            } else {
                MonologueIcon(icon: icon, size: 28, color: tint.opacity(0.72), lineWidth: 1.8)
            }
            Text(title)
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (MujiStyle.isActive ? MujiStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.76))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome)
            } else {
                Color.clear.monologueGlass(cornerRadius: 18)
            }
        }
    }
}

private struct ThemedLibraryPodcastRow: View {
    let radio: RadioStation
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.listRowCoverStandard, height: DeviceLayout.listRowCoverStandard)
            .clipShape(RoundedRectangle(cornerRadius: SequoiaStyle.isActive ? 14 : 12, style: .continuous))
            .overlay {
                if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .semibold, design: .rounded)))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))
                    .lineLimit(1)

                Text(radio.dj?.nickname ?? radio.category ?? "Podcast")
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .medium, design: .rounded)))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (MujiStyle.isActive ? MujiStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                    .lineLimit(1)
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
        }
        .padding(14)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, tint: tint.opacity(0.08), lightweight: true)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, fill: tint.opacity(0.055), role: .list)
            } else {
                Color.clear.monologueGlass(cornerRadius: 18)
            }
        }
    }
}

private struct ThemedLibraryArtistCard: View {
    let artist: ArtistInfo
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.artistAvatarSize - (NeumorphicStyle.isActive ? 12 : 0), height: DeviceLayout.artistAvatarSize - (NeumorphicStyle.isActive ? 12 : 0))
            .clipShape(Circle())
            .shadow(color: tint.opacity(0.14), radius: 7, y: 3)

            Text(artist.name)
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded))))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))
                .lineLimit(1)
        }
        .padding(NeumorphicStyle.isActive || SequoiaStyle.isActive ? 12 : 0)
        .frame(maxWidth: .infinity)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, tint: tint.opacity(0.06), lightweight: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, fill: tint.opacity(0.055), role: .list)
            }
        }
    }
}

private struct SequoiaLibraryPlaylistTile: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        MonologueIcon(icon: .musicNoteList, size: 20, color: tint.opacity(0.62), lineWidth: 1.55)
                    )
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SequoiaStyle.separator, lineWidth: 0.55)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(playlist.name)
                    .font(SequoiaStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 33, alignment: .topLeading)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(tint.opacity(0.74))
                        .frame(width: 18, height: 3)
                    Text(metaText)
                        .font(SequoiaStyle.labelFont(10, weight: .medium))
                        .foregroundStyle(SequoiaStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list))
    }

    private var metaText: String {
        if let count = playlist.playCount, count > 0 {
            return cinematicFormatCount(count)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return playlist.source == .qqmusic ? "QCM" : "NCM"
    }
}

private struct NeumorphicPlaylistPoster: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(600)) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(
                            MonologueIcon(icon: .musicNoteList, size: 24, color: NeumorphicStyle.inkMuted.opacity(0.55), lineWidth: 1.7)
                        )
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                MonologueIcon(icon: .play, size: 12, color: Color(light: .white, dark: .black), lineWidth: 1.8)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(tint)
                            .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 4)
                    )
                    .padding(9)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(playlist.name)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(tint.opacity(0.78))
                        .frame(width: 18, height: 3)

                    Text(metaText)
                        .font(NeumorphicStyle.labelFont(10, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }

    private var metaText: String {
        if let count = playlist.playCount, count > 0 {
            return cinematicFormatCount(count)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return playlist.source == .qqmusic ? "QCM" : "NCM"
    }
}

private struct NeumorphicLocalShelfRow: View {
    let playlist: LocalPlaylist
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            cover
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    platformDot
                    Text(String(format: String(localized: "songs_count_format"), playlist.trackCount))
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
                .frame(width: 34, height: 34)
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.08), lightweight: true))
        }
        .padding(12)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }

    @ViewBuilder
    private var cover: some View {
        if let url = playlist.displayCoverUrl {
            CachedAsyncImage(url: url.sized(260)) {
                placeholder
            }
            .aspectRatio(contentMode: .fill)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.42), NeumorphicStyle.surfacePressed],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MonologueIcon(
                icon: playlist.isFavorite ? .liked : playlist.isDownload ? .download : .musicNoteList,
                size: 22,
                color: Color(light: .white, dark: NeumorphicStyle.ink),
                lineWidth: 1.8
            )
        }
    }

    private var platformDot: some View {
        Capsule()
            .fill(tint.opacity(0.82))
            .frame(width: 18, height: 4)
    }
}

private struct NeumorphicPlaylistShelfRow: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(260)) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .list, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(playlist.source == .qqmusic ? "QCM" : "NCM")
                        .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(tint)

                    Text(metaText)
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
                .frame(width: 34, height: 34)
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.08), lightweight: true))
        }
        .padding(12)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }

    private var metaText: String {
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        if let playCount = playlist.playCount, playCount > 0 {
            return cinematicFormatCount(playCount)
        }
        return String(localized: "歌单")
    }
}

private struct NeumorphicPodcastShelfRow: View {
    let radio: RadioStation
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .radio, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(radio.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(radio.dj?.nickname ?? radio.category ?? "Podcast")
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
                .frame(width: 34, height: 34)
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.08), lightweight: true))
        }
        .padding(12)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }
}

private struct NeumorphicPlaylistShelfCard: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(MonologueIcon(icon: .musicNoteList, size: 24, color: NeumorphicStyle.inkMuted.opacity(0.55), lineWidth: 1.7))
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(playlist.source == .qqmusic ? "QCM" : "NCM")
                    .font(NeumorphicStyle.labelFont(9, weight: .semibold))
                    .foregroundStyle(Color(light: .white, dark: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(tint))
                    .padding(8)
            }

            Text(playlist.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)
                .frame(minHeight: 36, alignment: .topLeading)

            HStack(spacing: 6) {
                Capsule()
                    .fill(tint.opacity(0.8))
                    .frame(width: 18, height: 3)
                Text(metaText)
                    .font(NeumorphicStyle.labelFont(10, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }

    private var metaText: String {
        if let playCount = playlist.playCount, playCount > 0 {
            return cinematicFormatCount(playCount)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return String(localized: "推荐")
    }
}

private struct NeumorphicArtistShelfTile: View {
    let artist: ArtistInfo
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(
                            MonologueIcon(
                                icon: .personCircle,
                                size: 25,
                                color: NeumorphicStyle.inkMuted.opacity(0.58),
                                lineWidth: 1.7
                            )
                        )
                }
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                MonologueIcon(icon: .chevronRight, size: 11, color: tint, lineWidth: 1.8)
                    .frame(width: 30, height: 30)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 12,
                            elevated: false,
                            pressed: true,
                            tint: tint.opacity(0.12),
                            lightweight: true
                        )
                    )
                    .padding(8)
            }

            Text(artist.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(1)

            HStack(spacing: 6) {
                Capsule()
                    .fill(tint.opacity(0.82))
                    .frame(width: 18, height: 3)

                Text(artist.source == .qqmusic ? "QCM" : "NCM")
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}

private struct NeumorphicChartShelfRow: View {
    let list: TopList
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: list.coverUrl?.sized(300)) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .chart, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(list.updateFrequency)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
        }
        .padding(12)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}

private struct NeumorphicQQChartShelfRow: View {
    let item: QQTopListItem
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: item.coverURL) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .chart, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(item.period.isEmpty ? item.intro : item.period)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
        }
        .padding(12)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}

private struct NeumorphicChartTile: View {
    let list: TopList
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CachedAsyncImage(url: list.coverUrl?.sized(300)) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(list.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)

            Text(list.updateFrequency)
                .font(NeumorphicStyle.labelFont(10, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}

private struct NeumorphicLibraryExperience: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var tabIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var headerCollapseProgress: CGFloat = 0
    @State private var headerDragStart: CGFloat?

    private let tabs = LibraryViewModel.LibraryTab.allCases

    var body: some View {
        ZStack {
            ThemedPageBackground(useRenderLayer: true)

            VStack(spacing: 0) {
                LibraryCollapsingHeader(progress: $headerCollapseProgress, collapseDistance: headerCollapseDistance) {
                    headerConsole
                }

                GeometryReader { geo in
                    let width = max(geo.size.width, 1)

                    HStack(spacing: 0) {
                        MyPlaylistsContainerView(viewModel: viewModel)
                            .frame(width: width)
                        PlaylistSquareView(viewModel: viewModel)
                            .frame(width: width)
                        ArtistLibraryView(viewModel: viewModel)
                            .frame(width: width)
                        ChartsLibraryView(viewModel: viewModel)
                            .frame(width: width)
                    }
                    .frame(width: width * CGFloat(tabs.count), alignment: .leading)
                    .offset(x: -CGFloat(tabIndex) * width + dragOffset)
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: tabIndex)
                    .gesture(pagingGesture(width: width))
                    .simultaneousGesture(headerScrollGesture)
                    .transaction { transaction in
                        transaction.disablesAnimations = width <= 1
                    }
                }
                .clipped()
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear(perform: clampTabIndex)
        .onChange(of: tabIndex) { _, _ in
            clampTabIndex()
        }
    }

    private var headerConsole: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                NeumorphicIconBadge(icon: .library, tint: activeTabTint, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("LIBRARY")
                            .font(NeumorphicStyle.labelFont(9, weight: .semibold))
                            .foregroundStyle(activeTabTint)
                            .tracking(1.1)

                        Capsule()
                            .fill(NeumorphicStyle.separator.opacity(0.76))
                            .frame(width: 18, height: 1)
                    }

                    Text(String(localized: "tabbar_library"))
                        .font(NeumorphicStyle.titleFont(20, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Text(activeTabLabel)
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(activeTabTint)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(activeTabTint.opacity(0.13))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true))
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)

            HStack(spacing: 7) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    neumorphicTabButton(tab: tab, index: index)
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
        .padding(.bottom, 8)
    }

    private var headerCollapseDistance: CGFloat { 168 }

    private var headerScrollGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                if headerDragStart == nil {
                    headerDragStart = headerCollapseProgress
                }
                let start = headerDragStart ?? headerCollapseProgress
                let next = start - value.translation.height / max(headerCollapseDistance, 1)
                headerCollapseProgress = min(max(next, 0), 1)
            }
            .onEnded { value in
                guard headerDragStart != nil else { return }
                let projected = headerCollapseProgress - value.predictedEndTranslation.height / max(headerCollapseDistance, 1) * 0.14
                headerDragStart = nil
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    headerCollapseProgress = projected > 0.42 ? 1 : 0
                }
            }
    }

    private func neumorphicTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tabTint(tab)

        return Button {
            switchToTab(tab, index: index)
        } label: {
            HStack(spacing: 5) {
                MonologueIcon(
                    icon: tabIcon(tab),
                    size: 12,
                    color: selected ? tint : NeumorphicStyle.inkSoft,
                    lineWidth: 1.55
                )

                Text(tab.localizedKey)
                    .font(NeumorphicStyle.labelFont(10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 13,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.17) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }

    private var activeTabLabel: String {
        guard tabs.indices.contains(tabIndex) else { return "COLLECTION" }
        switch tabs[tabIndex] {
        case .my: return "COLLECTION"
        case .square: return "DISCOVER"
        case .artists: return "ARTISTS"
        case .charts: return "CHARTS"
        }
    }

    private var activeTabTint: Color {
        guard tabs.indices.contains(tabIndex) else { return NeumorphicStyle.accent }
        return tabTint(tabs[tabIndex])
    }

    private func tabIcon(_ tab: LibraryViewModel.LibraryTab) -> MonologueIcon.IconType {
        switch tab {
        case .my: return .library
        case .square: return .musicNoteList
        case .artists: return .profile
        case .charts: return .chart
        }
    }

    private func tabTint(_ tab: LibraryViewModel.LibraryTab) -> Color {
        switch tab {
        case .my: return NeumorphicStyle.accent
        case .square: return NeumorphicStyle.warm
        case .artists: return NeumorphicStyle.sage
        case .charts: return NeumorphicStyle.red
        }
    }

    private func switchToTab(_ tab: LibraryViewModel.LibraryTab, index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            tabIndex = index
            viewModel.currentTab = tab
        }
    }

    private func clampTabIndex() {
        guard !tabs.indices.contains(tabIndex) else { return }
        tabIndex = 0
        viewModel.currentTab = tabs[0]
    }

    private func pagingGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                let threshold: CGFloat = width * 0.2
                var newIndex = tabIndex
                if value.translation.width < -threshold || value.predictedEndTranslation.width < -width * 0.4 {
                    newIndex = min(tabIndex + 1, tabs.count - 1)
                } else if value.translation.width > threshold || value.predictedEndTranslation.width > width * 0.4 {
                    newIndex = max(tabIndex - 1, 0)
                }
                dragOffset = 0
                switchToTab(tabs[newIndex], index: newIndex)
            }
    }
}

// MARK: - Subviews

struct MyPlaylistsContainerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedSubTab: Int = 0
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        let _ = settings.globalThemeRevision
        VStack(spacing: 0) {
            if NeumorphicStyle.isActive {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        subTabButton(title: String(localized: "lib_local_playlists"), index: 0)
                        subTabButton(title: String(localized: "lib_netease_playlists"), index: 1)
                        subTabButton(title: String(localized: "QCM歌单"), index: 2)
                        subTabButton(title: String(localized: "lib_my_podcasts"), index: 3)
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                .padding(.bottom, 12)
            } else {
                HStack(spacing: 0) {
                    subTabButton(title: String(localized: "lib_local_playlists"), index: 0)
                    subTabButton(title: String(localized: "lib_netease_playlists"), index: 1)
                    subTabButton(title: String(localized: "QCM歌单"), index: 2)
                    subTabButton(title: String(localized: "lib_my_podcasts"), index: 3)
                    Spacer()
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                .padding(.bottom, 14)
            }

            ZStack {
                LocalPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 0)

                NetEasePlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 1)

                QQPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 2)

                MyPodcastsView()
                    .opacity(selectedSubTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 3)
            }
        }
        .background(Color.clear)
    }

    private func subTabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSubTab = index
            }
        }) {
            Group {
                if MangaStyle.isActive {
                    Text(title)
                        .font(MangaStyle.comicFont(11, weight: selectedSubTab == index ? .bold : .medium))
                        .foregroundStyle(selectedSubTab == index ? MangaStyle.ink : MangaStyle.inkMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSubTab == index ? MangaStyle.labelYellow : MangaStyle.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                        )
                } else if MujiStyle.isActive {
                    Text(title)
                        .font(MujiStyle.labelFont(12, weight: selectedSubTab == index ? .semibold : .regular))
                        .foregroundStyle(selectedSubTab == index ? MujiStyle.onTint : MujiStyle.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSubTab == index ? MujiStyle.clay : MujiStyle.surface.opacity(0.72))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectedSubTab == index ? Color.clear : MujiStyle.hairline.opacity(0.44), lineWidth: 0.6)
                        )
                } else if NeumorphicStyle.isActive {
                    HStack(spacing: 7) {
                        MonologueIcon(
                            icon: neumorphicSubTabIcon(index),
                            size: 12,
                            color: selectedSubTab == index ? neumorphicSubTabTint(index) : NeumorphicStyle.inkSoft,
                            lineWidth: 1.55
                        )

                        Text(title)
                            .font(NeumorphicStyle.labelFont(12, weight: selectedSubTab == index ? .semibold : .medium))
                            .foregroundStyle(selectedSubTab == index ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 15,
                            elevated: selectedSubTab == index,
                            pressed: selectedSubTab != index,
                            tint: selectedSubTab == index ? neumorphicSubTabTint(index).opacity(0.18) : NeumorphicStyle.surface,
                            lightweight: true
                        )
                    )
                } else {
                    VStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 13, weight: selectedSubTab == index ? .bold : .medium, design: .rounded))
                            .foregroundColor(selectedSubTab == index ? Theme.text : Theme.secondaryText.opacity(0.7))
                            .animation(.none, value: selectedSubTab)

                        Capsule()
                            .fill(selectedSubTab == index ? Theme.text : Color.clear)
                            .frame(width: 16, height: 2)
                    }
                    .padding(.trailing, 20)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func neumorphicSubTabIcon(_ index: Int) -> MonologueIcon.IconType {
        switch index {
        case 0: return .musicNoteList
        case 1, 2: return .list
        case 3: return .radio
        default: return .library
        }
    }

    private func neumorphicSubTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return NeumorphicStyle.accent
        case 1: return MusicSource.netease.themedBadgeColor
        case 2: return MusicSource.qqmusic.themedBadgeColor
        case 3: return NeumorphicStyle.sage
        default: return NeumorphicStyle.warm
        }
    }
}

// MARK: - 本地歌单列表

struct LocalPlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var manager = LocalPlaylistManager.shared
    @State private var showFileImporter = false
    @State private var showQQImport = false
    @State private var isImporting = false
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Group {
            if manager.playlists.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        VStack(spacing: 14) {
                            NeumorphicLibraryEmptyState(
                                icon: .musicNoteList,
                                title: String(localized: "lib_no_local_playlists"),
                                tint: NeumorphicStyle.accent
                            )
                            neumorphicLocalActionsRow
                        }
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text(LocalizedStringKey("lib_no_local_playlists"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)

                            Button(action: showCreatePlaylistPrompt) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .add, size: 14, color: .monologueIconForeground)
                                    Text(LocalizedStringKey("lib_create_playlist"))
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.monologueIconForeground)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monologueIconBackground)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())

                            Button(action: { showFileImporter = true }) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .download, size: 14, color: Theme.secondaryText)
                                    Text(LocalizedStringKey("lib_import_playlist"))
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monologueGlassTint)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())

                            Button(action: showLinkImportPrompt) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .share, size: 14, color: Theme.secondaryText)
                                    Text("从链接导入")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monologueGlassTint)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())

                            Button(action: { showQQImport = true }) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .musicNoteList, size: 14, color: Theme.secondaryText)
                                    Text("QCM歌单")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monologueGlassTint)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            } else {
                List {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Group {
                            if NeumorphicStyle.isActive {
                                neumorphicLocalActionsRow
                            } else {
                                standardLocalActionsRow
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .themeRenderScrollLayer()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))

                    ForEach(manager.playlists, id: \.id) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                                EmptyView()
                            }
                            .opacity(0)

                            LocalPlaylistRow(playlist: playlist)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !playlist.isSystem {
                                Button(role: .destructive) {
                                    AlertManager.shared.show(
                                        title: String(localized: "lib_delete_playlist"),
                                        message: String(format: String(localized: "lib_confirm_delete"), playlist.name),
                                        primaryButtonTitle: String(localized: "lib_delete"),
                                        secondaryButtonTitle: String(localized: "alert_cancel"),
                                        primaryAction: {
                                            withAnimation { manager.deletePlaylist(playlist) }
                                        }
                                    )
                                } label: {
                                    Label(String(localized: "lib_delete"), systemImage: "trash")
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .monologueSheet(isPresented: $showQQImport, preset: .large) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case let .failure(error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
    }

    private var neumorphicLocalActionsRow: some View {
        HStack(spacing: 9) {
            neumorphicLocalActionButton(icon: .add, title: String(localized: "lib_create_playlist"), tint: NeumorphicStyle.accent) {
                showCreatePlaylistPrompt()
            }

            neumorphicLocalActionButton(icon: .download, title: String(localized: "lib_import_playlist"), tint: NeumorphicStyle.warm, isLoading: isImporting) {
                showFileImporter = true
            }

            neumorphicLocalActionButton(icon: .share, title: String(localized: "从链接导入"), tint: NeumorphicStyle.sage, isLoading: isImporting) {
                showLinkImportPrompt()
            }

            neumorphicLocalActionButton(icon: .musicNoteList, title: "QCM", tint: MusicSource.qqmusic.themedBadgeColor) {
                showQQImport = true
            }
        }
    }

    private var standardLocalActionsRow: some View {
        HStack(spacing: 10) {
            Button(action: showCreatePlaylistPrompt) {
                HStack(spacing: 6) {
                    MonologueIcon(icon: .add, size: 14, color: Theme.secondaryText)
                    Text(LocalizedStringKey("lib_create_playlist"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monologueGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Button(action: { showFileImporter = true }) {
                HStack(spacing: 6) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        MonologueIcon(icon: .download, size: 14, color: Theme.secondaryText)
                    }
                    Text(LocalizedStringKey("lib_import_playlist"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monologueGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .disabled(isImporting)

            Button(action: showLinkImportPrompt) {
                HStack(spacing: 6) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        MonologueIcon(icon: .share, size: 14, color: Theme.secondaryText)
                    }
                    Text("从链接导入")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monologueGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .disabled(isImporting)

            Button(action: { showQQImport = true }) {
                HStack(spacing: 6) {
                    MonologueIcon(icon: .musicNoteList, size: 14, color: Theme.secondaryText)
                    Text("QCM歌单")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monologueGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
    }

    private func neumorphicLocalActionButton(
        icon: MonologueIcon.IconType,
        title: String,
        tint: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                        .scaleEffect(0.68)
                        .frame(width: 14, height: 14)
                } else {
                    MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.55)
                }

                Text(title)
                    .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 16,
                    elevated: true,
                    tint: tint.opacity(0.11),
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        .disabled(isLoading)
        .opacity(isLoading ? 0.72 : 1)
    }

    private func showCreatePlaylistPrompt() {
        AlertManager.shared.showInput(
            title: String(localized: "lib_create_playlist"),
            message: "",
            placeholder: String(localized: "lib_playlist_name"),
            primaryButtonTitle: String(localized: "lib_create"),
            secondaryButtonTitle: String(localized: "alert_cancel"),
            onConfirm: { name in
                guard !name.isEmpty else { return }
                manager.createPlaylist(name: name)
            }
        )
    }

    private func showLinkImportPrompt() {
        AlertManager.shared.showInput(
            title: String(localized: "从链接导入歌单"),
            message: String(localized: "支持 QCM、NCM 的歌单分享链接"),
            placeholder: String(localized: "粘贴歌单链接"),
            primaryButtonTitle: String(localized: "导入"),
            secondaryButtonTitle: String(localized: "取消"),
            onConfirm: { url in
                self.importPlaylistFromURL(url)
            }
        )
    }

    // MARK: - 导入逻辑

    private func importPlaylistFromFile(url: URL) {
        isImporting = true

        // 获取文件访问权限
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let parsed = try LocalPlaylistManager.parseExportFile(url: url)
            let ids = parsed.songIds
            let name = parsed.name

            if ids.isEmpty {
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: String(localized: "lib_import_no_songs"),
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
                isImporting = false
                return
            }

            // 分批获取歌曲详情（每批 50 首）
            Task {
                var allSongs: [Song] = []
                let batchSize = 50
                for i in stride(from: 0, to: ids.count, by: batchSize) {
                    let batch = Array(ids[i ..< min(i + batchSize, ids.count)])
                    do {
                        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                            var cancellable: AnyCancellable?
                            cancellable = APIService.shared.fetchSongDetails(ids: batch)
                                .sink(receiveCompletion: { completion in
                                    if case let .failure(error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                    cancellable?.cancel()
                                }, receiveValue: { songs in
                                    continuation.resume(returning: songs)
                                })
                        }
                        allSongs.append(contentsOf: songs)
                    } catch {
                        AppLogger.error("导入歌单批次获取失败: \(error)")
                    }
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "lib_import_fetch_failed"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        manager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            }
        } catch {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    // MARK: - 从链接导入

    private func importPlaylistFromURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isImporting = true

        if let qqId = extractQQPlaylistId(from: trimmed) {
            importQQPlaylist(id: qqId)
        } else if let ncmId = extractNCMPlaylistId(from: trimmed) {
            importNCMPlaylist(id: ncmId)
        } else if let kugouPath = extractKugouSonglistPath(from: trimmed) {
            importKugouPlaylist(path: kugouPath)
        } else {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: String(localized: "无法识别的歌单链接，请使用 NCM、QCM 或酷狗的歌单分享链接"),
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    private func extractQQPlaylistId(from url: String) -> Int? {
        // https://y.qq.com/n/ryqq_v2/playlist/9350658112
        // https://i.y.qq.com/n2/m/share/details/taoge.html?id=9350658112
        if let range = url.range(of: #"playlist/(\d+)"#, options: .regularExpression) {
            let match = url[range]
            let digits = match.replacingOccurrences(of: "playlist/", with: "")
            return Int(digits)
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("y.qq.com") {
            let match = String(url[range])
            let digits = match.replacingOccurrences(of: "id=", with: "")
            return Int(digits)
        }
        return nil
    }

    private func extractNCMPlaylistId(from url: String) -> Int? {
        // https://music.163.com/playlist?id=123456
        // https://music.163.com/#/playlist?id=123456
        if let range = url.range(of: #"playlist\?id=(\d+)"#, options: .regularExpression) {
            let match = String(url[range])
            let digits = match.replacingOccurrences(of: "playlist?id=", with: "")
            return Int(digits)
        }
        return nil
    }

    /// 提取酷狗歌单路径：支持 m.kugou.com/songlist/gcid_xxx 格式
    private func extractKugouSonglistPath(from url: String) -> String? {
        // https://m.kugou.com/songlist/gcid_3z7g1nvrz5z08a/...
        if let range = url.range(of: #"m\.kugou\.com/songlist/(gcid_[A-Za-z0-9]+)"#, options: .regularExpression) {
            let match = String(url[range])
            if let gcidRange = match.range(of: #"gcid_[A-Za-z0-9]+"#, options: .regularExpression) {
                return String(match[gcidRange])
            }
        }
        // https://kugou.com/songlist/gcid_xxx 或其他变体
        if let range = url.range(of: #"kugou\.com/songlist/(gcid_[A-Za-z0-9]+)"#, options: .regularExpression) {
            let match = String(url[range])
            if let gcidRange = match.range(of: #"gcid_[A-Za-z0-9]+"#, options: .regularExpression) {
                return String(match[gcidRange])
            }
        }
        return nil
    }

    // MARK: - 酷狗歌单导入

    private func importKugouPlaylist(path: String) {
        Task {
            do {
                let urlString = "https://m.kugou.com/songlist/\(path)/"
                guard let url = URL(string: urlString) else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url, timeoutInterval: 15)
                request.setValue(
                    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                    forHTTPHeaderField: "User-Agent"
                )

                let (data, _) = try await URLSession.shared.data(for: request)
                guard let html = String(data: data, encoding: .utf8) else {
                    throw URLError(.cannotDecodeContentData)
                }

                let (playlistName, kugouSongs) = parseKugouHTML(html)

                if kugouSongs.isEmpty {
                    await MainActor.run {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "酷狗歌单为空或无法解析"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                        isImporting = false
                    }
                    return
                }

                AppLogger.info("[KugouImport] 解析到 \(kugouSongs.count) 首歌，开始搜索匹配...")

                var matchedSongs: [Song] = []
                let total = kugouSongs.count

                for (index, kg) in kugouSongs.enumerated() {
                    let keyword = "\(kg.artist) \(kg.title)"
                    AppLogger.info("[KugouImport] [\(index + 1)/\(total)] 搜索: \(keyword)")

                    if let song = await searchSongOnPlatforms(title: kg.title, artist: kg.artist) {
                        matchedSongs.append(song)
                    }

                    if index < total - 1 {
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                }

                await MainActor.run {
                    if matchedSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "酷狗歌单中的歌曲未能在 NCM/QCM 中找到匹配"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        let name = playlistName.isEmpty ? String(localized: "酷狗歌单") : playlistName
                        manager.importPlaylist(name: name, songs: matchedSongs)
                        let skipped = total - matchedSongs.count
                        if skipped > 0 {
                            AlertManager.shared.show(
                                title: String(localized: "导入完成"),
                                message: String(localized: "成功匹配 \(matchedSongs.count) 首，\(skipped) 首未找到"),
                                primaryButtonTitle: String(localized: "lib_confirm"),
                                primaryAction: {}
                            )
                        }
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "酷狗歌单导入失败: \(error.localizedDescription)"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                    isImporting = false
                }
            }
        }
    }

    private struct KugouSongInfo {
        let title: String
        let artist: String
    }

    /// 从酷狗 HTML 中解析 window.$output JSON，提取歌单名和歌曲列表
    private func parseKugouHTML(_ html: String) -> (name: String, songs: [KugouSongInfo]) {
        // 匹配 window.$output = {...} 或 window.$output={...}
        guard let outputRange = html.range(of: #"window\.\$output\s*=\s*\{"#, options: .regularExpression) else {
            AppLogger.error("[KugouImport] 未找到 window.$output")
            return ("", [])
        }

        let startIndex = html.index(outputRange.lowerBound, offsetBy: {
            let prefix = String(html[outputRange])
            return prefix.distance(from: prefix.startIndex, to: prefix.range(of: "{")!.lowerBound)
        }())

        // 找到匹配的闭合大括号
        var depth = 0
        var endIndex = startIndex
        var inString = false
        var escape = false

        for i in html[startIndex...].indices {
            let ch = html[i]
            if escape { escape = false; continue }
            if ch == "\\", inString { escape = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            if inString { continue }
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = html.index(after: i)
                    break
                }
            }
        }

        let jsonString = String(html[startIndex ..< endIndex])

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            AppLogger.error("[KugouImport] JSON 解析失败")
            return ("", [])
        }

        var playlistName = json["title"] as? String ?? json["name"] as? String ?? ""

        // 实际结构：info.listinfo.name
        if playlistName.isEmpty, let info = json["info"] as? [String: Any],
           let listinfo = info["listinfo"] as? [String: Any],
           let name = listinfo["name"] as? String
        {
            playlistName = name
        }

        var songs: [KugouSongInfo] = []

        // 实际结构：info.songs[]
        if let info = json["info"] as? [String: Any],
           let songList = info["songs"] as? [[String: Any]]
        {
            for item in songList {
                if let parsed = parseKugouSongItem(item) {
                    songs.append(parsed)
                }
            }
        }

        // 备用：顶层 songs 对象
        if songs.isEmpty, let songObj = json["songs"] as? [String: Any],
           let list = songObj["list"] as? [[String: Any]]
        {
            for item in list {
                if let parsed = parseKugouSongItem(item) {
                    songs.append(parsed)
                }
            }
        }

        // 备用：顶层 list 数组
        if songs.isEmpty, let list = json["list"] as? [[String: Any]] {
            for item in list {
                if let parsed = parseKugouSongItem(item) {
                    songs.append(parsed)
                }
            }
        }

        return (playlistName, songs)
    }

    private func parseKugouSongItem(_ item: [String: Any]) -> KugouSongInfo? {
        // 格式 1: name = "歌手 - 歌名"（实际 API 格式）
        if let name = item["name"] as? String ?? item["filename"] as? String {
            let parts = name.components(separatedBy: " - ")
            if parts.count >= 2 {
                let artist = parts[0].trimmingCharacters(in: .whitespaces)
                let title = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                if !artist.isEmpty, !title.isEmpty {
                    return KugouSongInfo(title: title, artist: artist)
                }
            }
        }
        // 格式 2: singerinfo + remark/songname 分开字段
        if let singerInfo = item["singerinfo"] as? [[String: Any]],
           let firstSinger = singerInfo.first,
           let singerName = firstSinger["name"] as? String
        {
            let songName = item["remark"] as? String ?? item["songname"] as? String ?? item["song_name"] as? String ?? ""
            if !songName.isEmpty {
                return KugouSongInfo(title: songName, artist: singerName)
            }
        }
        // 格式 3: singername + songname 直接字段
        if let songname = item["songname"] as? String ?? item["song_name"] as? String,
           let singername = item["singername"] as? String ?? item["author_name"] as? String
        {
            if !songname.isEmpty {
                return KugouSongInfo(title: songname, artist: singername)
            }
        }
        return nil
    }

    /// 在ncm和 qcm搜索匹配歌曲，优先ncm
    private func searchSongOnPlatforms(title: String, artist: String) async -> Song? {
        let keyword = "\(artist) \(title)"

        // 先搜ncm
        if let ncmSong = await searchNCMSong(keyword: keyword, title: title, artist: artist) {
            return ncmSong
        }

        // ncm没找到，搜 qcm
        if let qqSong = await searchQQSong(keyword: keyword, title: title, artist: artist) {
            return qqSong
        }

        AppLogger.info("[KugouImport] 未匹配: \(keyword)")
        return nil
    }

    private func searchNCMSong(keyword: String, title: String, artist: String) async -> Song? {
        do {
            let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                var resumed = false
                var cancellable: AnyCancellable?
                cancellable = APIService.shared.searchSongs(keyword: keyword, offset: 0)
                    .sink(receiveCompletion: { completion in
                        if case let .failure(error) = completion, !resumed {
                            resumed = true
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    }, receiveValue: { songs in
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume(returning: songs)
                        cancellable?.cancel()
                    })
            }
            return bestMatch(from: songs, title: title, artist: artist)
        } catch {
            return nil
        }
    }

    private func searchQQSong(keyword: String, title: String, artist: String) async -> Song? {
        do {
            let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                var resumed = false
                var cancellable: AnyCancellable?
                cancellable = APIService.shared.searchQQSongs(keyword: keyword, page: 1, num: 10)
                    .sink(receiveCompletion: { completion in
                        if case let .failure(error) = completion, !resumed {
                            resumed = true
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    }, receiveValue: { songs in
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume(returning: songs)
                        cancellable?.cancel()
                    })
            }
            return bestMatch(from: songs, title: title, artist: artist)
        } catch {
            return nil
        }
    }

    /// 从搜索结果中选出最佳匹配：标题和歌手名都相似
    private func bestMatch(from songs: [Song], title: String, artist: String) -> Song? {
        let normalizedTitle = title.lowercased()
        let normalizedArtist = artist.lowercased()

        let matchesArtist: (Song) -> Bool = { song in
            let a = song.artistName.lowercased()
            return a.contains(normalizedArtist) || normalizedArtist.contains(a)
        }

        if let exact = songs.first(where: {
            $0.name.lowercased() == normalizedTitle && matchesArtist($0)
        }) {
            return exact
        }

        if let partial = songs.first(where: {
            let t = $0.name.lowercased()
            return (t.contains(normalizedTitle) || normalizedTitle.contains(t)) && matchesArtist($0)
        }) {
            return partial
        }

        if let titleOnly = songs.first(where: {
            $0.name.lowercased() == normalizedTitle
        }) {
            return titleOnly
        }

        return nil
    }

    private func importQQPlaylist(id: Int) {
        Task {
            do {
                let detail = try await APIService.shared.qqClient.songlistDetail(songlistId: id, num: 1, page: 1)
                let name = detail["dirinfo"]?["title"]?.stringValue ?? String(localized: "QCM歌单")

                var allSongs: [Song] = []
                var page = 1
                var hasMore = true

                while hasMore {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: id, page: page, num: 50)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    if songs.count < 50 { hasMore = false }
                    page += 1
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "歌单为空或获取失败"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        manager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "QCM歌单导入失败: \(error.localizedDescription)"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                    isImporting = false
                }
            }
        }
    }

    private func importNCMPlaylist(id: Int) {
        Task {
            var allSongs: [Song] = []
            var offset = 0
            let limit = 50
            var hasMore = true
            let playlistName = String(localized: "NCM歌单")

            // 先获取歌单名
            do {
                let details: [Song] = try await withCheckedThrowingContinuation { continuation in
                    var resumed = false
                    var cancellable: AnyCancellable?
                    cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: 1, offset: 0)
                        .sink(receiveCompletion: { completion in
                            if case let .failure(error) = completion, !resumed {
                                resumed = true
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        }, receiveValue: { songs in
                            guard !resumed else { return }
                            resumed = true
                            continuation.resume(returning: songs)
                            cancellable?.cancel()
                        })
                }
                _ = details
            } catch {
                // 获取名称失败不影响导入
            }

            while hasMore {
                do {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: offset)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    if songs.count < limit { hasMore = false }
                    offset += limit
                } catch {
                    hasMore = false
                }
            }

            await MainActor.run {
                if allSongs.isEmpty {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "歌单为空或获取失败"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                } else {
                    manager.importPlaylist(name: playlistName, songs: allSongs)
                }
                isImporting = false
            }
        }
    }
}

private struct NeumorphicLibraryEmptyState: View {
    let icon: MonologueIcon.IconType
    let title: String
    var detail: String = ""
    var tint: Color = NeumorphicStyle.accent

    var body: some View {
        VStack(spacing: 12) {
            NeumorphicIconBadge(icon: icon, tint: tint, size: 56)

            Text(title)
                .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .multilineTextAlignment(.center)

            if !detail.isEmpty {
                Text(detail)
                    .font(NeumorphicStyle.labelFont(12))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
    }
}

struct LocalPlaylistRow: View {
    let playlist: LocalPlaylist
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let url = playlist.displayCoverUrl {
                    CachedAsyncImage(url: url.sized(200)) {
                        systemPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    systemPlaceholder
                }
            }
            .frame(width: DeviceLayout.listRowCoverStandard, height: DeviceLayout.listRowCoverStandard)
            .cornerRadius(SequoiaStyle.isActive ? 14 : 12)
            .overlay {
                if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                }
            }
            .shadow(color: SequoiaStyle.isActive ? Color.black.opacity(0.04) : Color.black.opacity(0.08), radius: SequoiaStyle.isActive ? 3 : 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(localRowTitleFont)
                    .foregroundColor(localRowPrimaryColor)
                    .lineLimit(1)

                Text(String(format: String(localized: "songs_count_format"), playlist.trackCount))
                    .font(localRowSubtitleFont)
                    .foregroundColor(localRowSecondaryColor)
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: localRowSecondaryColor.opacity(0.7))
        }
        .padding(14)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
            } else {
                Color.clear
                    .monologueGlass(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : 18))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 20 : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : (SequoiaStyle.isActive ? 20 : 18))), style: .continuous))
    }

    private var systemPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    playlist.isFavorite
                        ? LinearGradient(colors: [.pink.opacity(0.6), .red.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : playlist.isDownload
                        ? LinearGradient(colors: [.blue.opacity(0.5), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [
                                NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint),
                                NeumorphicStyle.isActive ? NeumorphicStyle.surface : (SequoiaStyle.isActive ? SequoiaStyle.materialRaised : Color.monologueGlassTint),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
            MonologueIcon(
                icon: playlist.isFavorite ? .liked : playlist.isDownload ? .download : .musicNoteList,
                size: 24,
                color: playlist.isSystem ? .white : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.3)))
            )
        }
    }

    private var localRowTitleFont: Font {
        if MangaStyle.isActive {
            return MangaStyle.comicFont(15, weight: .bold)
        }
        if MujiStyle.isActive {
            return MujiStyle.bodyFont(15, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.bodyFont(15, weight: .semibold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.bodyFont(15, weight: .semibold)
        }
        return .system(size: 15, weight: .semibold, design: .rounded)
    }

    private var localRowSubtitleFont: Font {
        if MangaStyle.isActive {
            return MangaStyle.comicFont(12, weight: .medium)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: .medium)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(12, weight: .regular)
        }
        return .system(size: 12, weight: .medium, design: .rounded)
    }

    private var localRowPrimaryColor: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text
    }

    private var localRowSecondaryColor: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText
    }
}

// MARK: - 我的播客（订阅的播客列表）

struct MyPodcastsView: View {
    typealias Theme = PlaylistDetailView.Theme
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        let _ = settings.globalThemeRevision
        VStack(spacing: 0) {
            // 自定义标签栏（与下载管理等页面风格统一）
            HStack(spacing: 0) {
                podcastTabButton(title: String(localized: "本地收藏"), index: 0)
                podcastTabButton(title: String(localized: "NCM 播客"), index: 1)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if selectedTab == 0 {
                localPodcastsList
            } else {
                ncmPodcastsList
            }
        }
        .onAppear {
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
    }

    private func podcastTabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            if NeumorphicStyle.isActive {
                HStack(spacing: 7) {
                    MonologueIcon(
                        icon: index == 0 ? .liked : .radio,
                        size: 13,
                        color: selectedTab == index ? NeumorphicStyle.sage : NeumorphicStyle.inkSoft,
                        lineWidth: 1.55
                    )
                    Text(title)
                        .font(NeumorphicStyle.labelFont(12, weight: selectedTab == index ? .semibold : .medium))
                        .foregroundStyle(selectedTab == index ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 15,
                        elevated: selectedTab == index,
                        pressed: selectedTab != index,
                        tint: selectedTab == index ? NeumorphicStyle.sage.opacity(0.16) : NeumorphicStyle.surface
                    )
                )
            } else {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium, design: .rounded))
                        .foregroundColor(selectedTab == index ? .monologueTextPrimary : .monologueTextSecondary)

                    Rectangle()
                        .fill(selectedTab == index ? Color.monologueTextPrimary : Color.clear)
                        .frame(height: 2)
                        .frame(width: 40)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private var localPodcastsList: some View {
        Group {
            if subManager.localSubscribedRadios.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .radio,
                            title: String(localized: "暂无本地收藏"),
                            tint: NeumorphicStyle.sage
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .radio, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text("暂无本地收藏")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            } else {
                List {
                    ForEach(subManager.localSubscribedRadios) { radio in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                                EmptyView()
                            }
                            .opacity(0)

                            podcastRow(radio: radio)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    subManager.removeLocalRadio(radio)
                                }
                            } label: {
                                Label(String(localized: "lib_unsubscribe"), systemImage: "heart.slash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    subManager.removeLocalRadio(radio)
                                }
                            } label: {
                                Label(String(localized: "lib_unsubscribe"), systemImage: "heart.slash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
    }

    private var ncmPodcastsList: some View {
        Group {
            if subManager.isLoadingRadios && subManager.subscribedRadios.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(LocalizedStringKey("lib_loading"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            } else if subManager.subscribedRadios.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .radio,
                            title: String(localized: "lib_no_podcasts"),
                            detail: String(localized: "lib_discover_podcasts"),
                            tint: MusicSource.netease.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .radio, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text(LocalizedStringKey("lib_no_podcasts"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)
                            Text(LocalizedStringKey("lib_discover_podcasts"))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(Theme.secondaryText.opacity(0.6))
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            } else {
                List {
                    ForEach(subManager.subscribedRadios) { radio in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                                EmptyView()
                            }
                            .opacity(0)

                            podcastRow(radio: radio)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                .refreshable {
                    subManager.fetchSubscribedRadios()
                }
            }
        }
    }

    private func podcastRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.monologueGlassTint)
            }
            .frame(width: DeviceLayout.listRowCoverSmall, height: DeviceLayout.listRowCoverSmall)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(radio.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .semibold) : .system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11) : .system(size: 11, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                        Text(String(format: String(localized: "lib_episode_count"), count))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11) : .system(size: 11, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary).opacity(0.7))
        }
        .padding(NeumorphicStyle.isActive ? 12 : 0)
        .padding(.vertical, NeumorphicStyle.isActive ? 0 : 5)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            }
        }
    }
}

struct NetEasePlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var subManager = SubscriptionManager.shared
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Group {
            if viewModel.userPlaylists.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .musicNoteList,
                            title: isAppLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 NCM"),
                            tint: MusicSource.netease.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text(isAppLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 NCM"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            } else {
                List {
                    ForEach(viewModel.userPlaylists) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                EmptyView()
                            }
                            .opacity(0)

                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                let isOwn = isUserCreated(playlist)
                                let title = isOwn ? String(localized: "lib_delete_playlist") : String(localized: "lib_uncollect")
                                let message = isOwn ? String(format: String(localized: "lib_confirm_delete"), playlist.name) : String(format: String(localized: "lib_confirm_uncollect"), playlist.name)
                                let buttonTitle = isOwn ? String(localized: "lib_delete") : String(localized: "lib_uncollect")
                                AlertManager.shared.show(
                                    title: title,
                                    message: message,
                                    primaryButtonTitle: buttonTitle,
                                    secondaryButtonTitle: String(localized: "alert_cancel"),
                                    primaryAction: { [viewModel, subManager] in
                                        let playlistId = playlist.id
                                        withAnimation {
                                            viewModel.userPlaylists.removeAll { $0.id == playlistId }
                                        }
                                        OptimizedCacheManager.shared.setObject(viewModel.userPlaylists, forKey: "user_playlists")
                                        if isOwn {
                                            subManager.deletePlaylist(id: playlistId) { success in
                                                if !success {
                                                    viewModel.fetchPlaylists(force: true)
                                                }
                                            }
                                        } else {
                                            subManager.unsubscribePlaylist(id: playlistId) { success in
                                                if !success {
                                                    viewModel.fetchPlaylists(force: true)
                                                }
                                            }
                                        }
                                    }
                                )
                            } label: {
                                Label(isUserCreated(playlist) ? String(localized: "lib_delete_playlist") : String(localized: "lib_uncollect"),
                                      systemImage: isUserCreated(playlist) ? "trash" : "heart.slash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                .refreshable {
                    viewModel.fetchPlaylists(force: true)
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            if viewModel.userPlaylists.isEmpty {
                viewModel.fetchPlaylists()
            }
        }
    }

    /// 判断歌单是否为用户自己创建的
    private func isUserCreated(_ playlist: Playlist) -> Bool {
        guard let uid = APIService.shared.currentUserId,
              let creatorId = playlist.creator?.userId
        else {
            return false
        }
        return creatorId == uid
    }
}

// MARK: - qcm歌单

struct QQPlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var qqSession = QQUserSession.shared
    @State private var qqPlaylists: [Playlist] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Group {
            if isLoading && qqPlaylists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("加载中...")
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            } else if qqPlaylists.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .musicNoteList,
                            title: qqSession.isLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 QCM"),
                            tint: MusicSource.qqmusic.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text(qqSession.isLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 QCM"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            } else {
                List {
                    ForEach(qqPlaylists) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                EmptyView()
                            }
                            .opacity(0)
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                .refreshable { await loadPlaylists(force: true) }
            }
        }
        .background(Color.clear)
        .onAppear {
            if !hasLoaded { Task { await loadPlaylists() } }
        }
        .onChange(of: qqSession.isLoggedIn) { _, loggedIn in
            if !loggedIn {
                qqPlaylists = []
                hasLoaded = false
            } else if !hasLoaded {
                Task { await loadPlaylists() }
            }
        }
    }

    private func loadPlaylists(force _: Bool = false) async {
        guard QQUserSession.shared.isLoggedIn else { return }
        guard let mid = QQUserSession.shared.musicId else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }

        do {
            let result: JSON = try await QQUserSession.shared.withUserSession { client in
                try await client.createdSonglist(uin: String(mid))
            }

            var items: [Playlist] = []
            let list = result["v_playlist"]?.arrayValue ?? result.arrayValue ?? []
            for json in list {
                guard let obj = json.objectValue else { continue }
                let tid = obj["tid"]?.intValue ?? 0
                let name = obj["dirName"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
                let cover = obj["picUrl"]?.stringValue ?? obj["logo"]?.stringValue ?? ""
                let songCount = obj["songNum"]?.intValue ?? obj["song_cnt"]?.intValue ?? 0
                if !name.isEmpty {
                    items.append(Playlist(
                        id: tid, name: name, coverImgUrl: cover, picUrl: nil,
                        trackCount: songCount, playCount: nil,
                        subscribedCount: nil, shareCount: nil, commentCount: nil,
                        creator: nil, description: nil, tags: nil, source: .qqmusic
                    ))
                }
            }
            qqPlaylists = items
        } catch {
            AppLogger.error("[QQPlaylists] 加载歌单失败: \(error)")
        }
    }
}

// MARK: - 音源切换器

struct MusicSourcePicker: View {
    @Binding var source: LibraryViewModel.MusicSource
    @Namespace private var ns
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LibraryViewModel.MusicSource.allCases, id: \.self) { s in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        source = s
                    }
                } label: {
                    let tint = s == .ncm ? MusicSource.netease.themedBadgeColor : MusicSource.qqmusic.themedBadgeColor
                    let selected = source == s

                    Text(s == .ncm ? "NCM" : "QCM")
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) : .system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
                        .foregroundColor(selected ? tint : tint.opacity(0.66))
                        .padding(.horizontal, NeumorphicStyle.isActive ? 13 : 14)
                        .padding(.vertical, NeumorphicStyle.isActive ? 8 : 7)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(
                                    cornerRadius: 14,
                                    elevated: selected,
                                    pressed: !selected,
                                    tint: selected ? tint.opacity(0.16) : NeumorphicStyle.surface,
                                    lightweight: true
                                )
                            } else if selected {
                                Capsule()
                                    .fill(tint.opacity(0.13))
                                    .matchedGeometryEffect(id: "sourcePill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(NeumorphicStyle.isActive ? 5 : 3)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else {
                Capsule().fill(Color.monologueTextPrimary.opacity(0.06))
            }
        }
    }
}

struct PlaylistSquareView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme
    @Namespace private var categoryNS

    private struct MosaicRow: Identifiable {
        let id: Int
        let playlists: [Playlist]
        let isWide: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MusicSourcePicker(source: $viewModel.squareSource)
                Spacer()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.top, 4)
            .onChange(of: viewModel.squareSource) { _, newSource in
                if newSource == .qq {
                    viewModel.fetchQQSquareData()
                } else {
                    viewModel.fetchSquareData()
                }
            }

            if viewModel.squareSource == .ncm {
                ncmContent
            } else {
                qqContent
            }
        }
        .background(Color.clear)
    }

    // MARK: - NCM Content

    private var ncmContent: some View {
        VStack(spacing: 0) {
            categoryBar

            ScrollView {
                if viewModel.isLoadingSquare && viewModel.squarePlaylists.isEmpty {
                    LibraryLoadingStateView()
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(buildRows(from: viewModel.squarePlaylists)) { row in
                            if row.isWide, let playlist = row.playlists.first {
                                NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                    CinematicCard(playlist: playlist, height: 220)
                                }
                                .buttonStyle(CinematicPressStyle())
                                .modifier(CinematicStaggerIn(order: row.id))
                                .onAppear { loadMoreIfLast(playlist) }
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(row.playlists) { p in
                                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(p)) {
                                            CinematicCard(playlist: p, height: 175)
                                        }
                                        .buttonStyle(CinematicPressStyle())
                                        .onAppear { loadMoreIfLast(p) }
                                    }
                                }
                                .modifier(CinematicStaggerIn(order: row.id))
                            }
                        }

                        if viewModel.isLoadingMoreSquare && viewModel.hasMoreSquarePlaylists {
                            LibraryInlineLoadingView()
                        }
                        if !viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.top, 8)
                }

                FloatingBarBottomSpacer()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - QQ Content

    private var qqContent: some View {
        VStack(spacing: 0) {
            qqCategoryBar

            ScrollView {
                if viewModel.isLoadingQQSquare && viewModel.qqSquarePlaylists.isEmpty {
                    LibraryLoadingStateView()
                } else if viewModel.qqSquarePlaylists.isEmpty {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .musicNoteList,
                            title: String(localized: "暂无QCM推荐歌单"),
                            tint: MusicSource.qqmusic.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 50, color: Theme.secondaryText.opacity(0.5))
                            Text("暂无QCM推荐歌单")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)
                        }
                        .padding(.top, 50)
                    }
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(buildRows(from: viewModel.qqSquarePlaylists)) { row in
                            if row.isWide, let playlist = row.playlists.first {
                                NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                    CinematicCard(playlist: playlist, height: 220)
                                }
                                .buttonStyle(CinematicPressStyle())
                                .modifier(CinematicStaggerIn(order: row.id))
                                .onAppear { loadMoreQQIfLast(playlist) }
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(row.playlists) { p in
                                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(p)) {
                                            CinematicCard(playlist: p, height: 175)
                                        }
                                        .buttonStyle(CinematicPressStyle())
                                        .onAppear { loadMoreQQIfLast(p) }
                                    }
                                }
                                .modifier(CinematicStaggerIn(order: row.id))
                            }
                        }

                        if viewModel.isLoadingMoreQQSquare && viewModel.hasMoreQQSquare {
                            LibraryInlineLoadingView()
                        }
                        if !viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.top, 8)
                }

                FloatingBarBottomSpacer()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollContentBackground(.hidden)
            .refreshable {
                viewModel.refreshQQSquare()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    // MARK: - QQ Category Bar

    private static let hiddenQQCategories: Set<String> = [String(localized: "全部"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")]

    private var filteredQQCategories: [(id: Int, name: String)] {
        viewModel.qqPlaylistCategories.filter { !Self.hiddenQQCategories.contains($0.name.lowercased()) }
    }

    private var qqCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filteredQQCategories, id: \.id) { cat in
                    let selected = viewModel.selectedQQCategoryId == cat.id
                    Button {
                        guard !selected else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectQQCategory(id: cat.id, name: cat.name)
                        }
                    } label: {
                        Text(cat.name)
                            .font(categoryFont(selected: selected))
                            .foregroundColor(categoryForeground(selected: selected, neumorphicTint: MusicSource.qqmusic.themedBadgeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(
                                        cornerRadius: 16,
                                        elevated: selected,
                                        pressed: !selected,
                                        tint: selected ? MusicSource.qqmusic.themedBadgeColor.opacity(0.16) : NeumorphicStyle.surface,
                                        lightweight: true
                                    )
                                } else if selected {
                                    Capsule()
                                        .fill(Color.monologueIconBackground)
                                        .matchedGeometryEffect(id: "qqCatPill", in: categoryNS)
                                } else if MujiStyle.isActive, selected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(MujiStyle.clay)
                                        .matchedGeometryEffect(id: "qqCatPill", in: categoryNS)
                                }
                            }
                            .background {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selected ? Color.clear : MujiStyle.surface.opacity(0.78))
                                } else if !NeumorphicStyle.isActive {
                                    Capsule().fill(selected ? Color.clear : Color.monologueGlassTint)
                                }
                            }
                            .overlay {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
        .themeRenderScrollLayer()
    }

    // MARK: - Animated Category Selector

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.playlistCategories, id: \.idString) { cat in
                    let selected = viewModel.selectedCategory == cat.name
                    Button {
                        guard !selected else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectedCategory = cat.name
                            viewModel.loadSquarePlaylists(cat: cat.name, reset: true)
                        }
                    } label: {
                        Text(cat.name)
                            .font(categoryFont(selected: selected))
                            .foregroundColor(categoryForeground(selected: selected, neumorphicTint: MusicSource.netease.themedBadgeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(
                                        cornerRadius: 16,
                                        elevated: selected,
                                        pressed: !selected,
                                        tint: selected ? MusicSource.netease.themedBadgeColor.opacity(0.16) : NeumorphicStyle.surface,
                                        lightweight: true
                                    )
                                } else if selected {
                                    Capsule()
                                        .fill(Color.monologueIconBackground)
                                        .matchedGeometryEffect(id: "squareCatPill", in: categoryNS)
                                } else if MujiStyle.isActive, selected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(MujiStyle.clay)
                                        .matchedGeometryEffect(id: "squareCatPill", in: categoryNS)
                                }
                            }
                            .background {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selected ? Color.clear : MujiStyle.surface.opacity(0.78))
                                } else if !NeumorphicStyle.isActive {
                                    Capsule().fill(selected ? Color.clear : Color.monologueGlassTint)
                                }
                            }
                            .overlay {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
        .themeRenderScrollLayer()
    }

    private func categoryFont(selected: Bool) -> Font {
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular)
        }
        return .system(size: 13, weight: selected ? .semibold : .medium, design: .rounded)
    }

    private func categoryForeground(selected: Bool, neumorphicTint: Color) -> Color {
        if NeumorphicStyle.isActive {
            return selected ? neumorphicTint : NeumorphicStyle.inkSoft
        }
        if MujiStyle.isActive {
            return selected
                ? ThemeColorCustomization.readableForegroundColor(on: MujiStyle.clay, light: MujiStyle.ink, dark: Color.white)
                : MujiStyle.inkSoft
        }
        return selected ? .monologueIconForeground : .monologueTextPrimary
    }

    // MARK: - Mosaic Layout (Hero → Duo → Duo → repeat)

    private func buildRows(from items: [Playlist]) -> [MosaicRow] {
        var rows: [MosaicRow] = []
        var i = 0
        while i < items.count {
            if rows.count % 3 == 0 {
                rows.append(.init(id: rows.count, playlists: [items[i]], isWide: true))
                i += 1
            } else if i + 1 < items.count {
                rows.append(.init(id: rows.count, playlists: [items[i], items[i + 1]], isWide: false))
                i += 2
            } else {
                rows.append(.init(id: rows.count, playlists: [items[i]], isWide: true))
                i += 1
            }
        }
        return rows
    }

    private func loadMoreIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.squarePlaylists.last?.id {
            viewModel.loadMoreSquarePlaylists()
    }
}

    private func loadMoreQQIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.qqSquarePlaylists.last?.id {
            viewModel.loadMoreQQSquarePlaylists()
        }
    }
}

// MARK: - Cinematic Full-Bleed Card

private struct CinematicCard: View {
    let playlist: Playlist
    let height: CGFloat

    var body: some View {
        if NeumorphicStyle.isActive {
            cardCore
                .padding(8)
                .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            cardCore
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
    }

    private var cardCore: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(height > 200 ? 1200 : 800)) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.monologueSeparator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: .black.opacity(0.25), location: 0.55),
                    .init(color: .black.opacity(0.82), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.name)
                        .font(.system(size: height > 200 ? 18 : 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 4)

                    if let count = playlist.playCount, count > 0 {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .play, size: 8, color: .white.opacity(0.75), lineWidth: 1.8)
                            Text(cinematicFormatCount(count))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.75))
                    }
                }

                Spacer()

                if height > 200 {
                    MonologueIcon(icon: .play, size: 15, color: .white, lineWidth: 2)
                        .padding(13)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private func cinematicFormatCount(_ count: Int) -> String {
    let lang = Locale.current.language.languageCode?.identifier
    if lang == "zh" {
        if count >= 100_000_000 { return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100_000_000) }
        if count >= 10000 { return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10000) }
    } else {
        if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
    }
    return "\(count)"
}

// MARK: - Staggered Entrance Animation

private struct CinematicStaggerIn: ViewModifier {
    let order: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 28)
            .scaleEffect(visible ? 1 : 0.92, anchor: .bottom)
            .onAppear {
                guard !visible else { return }
                let delay = order < 8 ? Double(order) * 0.065 : 0.03
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                    visible = true
                }
            }
    }
}

// MARK: - Cinematic Press Style

private struct CinematicPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ArtistLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showFilters = false
    @State private var showQQFilters = false
    @FocusState private var focusedSearchField: SearchField?
    typealias Theme = PlaylistDetailView.Theme

    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: DeviceLayout.artistGridColumns)

    private enum SearchField: Hashable {
        case ncm
        case qq
    }

    private var hasActiveFilter: Bool {
        viewModel.artistArea != -1 || viewModel.artistType != -1 || viewModel.artistInitial != "-1"
    }

    private var hasActiveQQFilter: Bool {
        viewModel.qqArtistArea != .all || viewModel.qqArtistSex != .all || viewModel.qqArtistGenre != .all
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MusicSourcePicker(source: $viewModel.artistSource)
                Spacer()
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .onChange(of: viewModel.artistSource) { _, newSource in
                dismissArtistSearchKeyboard()
                if newSource == .qq {
                    viewModel.fetchQQArtistData()
                } else {
                    viewModel.fetchArtistData()
                }
            }

            if viewModel.artistSource == .ncm {
                ncmArtistContent
            } else {
                qqArtistContent
            }
        }
        .background(Color.clear)
    }

    // MARK: - NCM Artists

    private var ncmArtistContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    MonologueIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)

                    TextField(LocalizedStringKey("search_artists"), text: $viewModel.artistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                        .monologueTextInputBehavior()
                        .focused($focusedSearchField, equals: .ncm)
                        .submitLabel(.search)
                        .onSubmit {
                            dismissArtistSearchKeyboard()
                            viewModel.fetchArtistData(reset: true)
                        }

                    if !viewModel.artistSearchText.isEmpty {
                        Button(action: {
                            viewModel.artistSearchText = ""
                            viewModel.fetchArtistData(reset: true)
                        }) {
                            MonologueIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monologueGlass(cornerRadius: 20)
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
                                .fill(NeumorphicStyle.isActive ? Color.clear : (hasActiveFilter ? Color.monologueGlassTint : Color.clear))
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
                                        Color.clear.monologueGlass(cornerRadius: 14)
                                    }
                                }

                            MonologueIcon(
                                icon: .filter,
                                size: 18,
                                color: NeumorphicStyle.isActive ? (hasActiveFilter ? NeumorphicStyle.sage : NeumorphicStyle.inkMuted) : (hasActiveFilter ? .monologueIconForeground : Theme.secondaryText)
                            )
                            .rotationEffect(.degrees(showFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
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
                    MonologueIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)

                    TextField(String(localized: "搜索QCM歌手"), text: $viewModel.qqArtistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                        .monologueTextInputBehavior()
                        .focused($focusedSearchField, equals: .qq)
                        .submitLabel(.search)
                        .onSubmit {
                            dismissArtistSearchKeyboard()
                        }

                    if !viewModel.qqArtistSearchText.isEmpty {
                        Button(action: {
                            viewModel.qqArtistSearchText = ""
                        }) {
                            MonologueIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monologueGlass(cornerRadius: 20)
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
                                .fill(NeumorphicStyle.isActive ? Color.clear : (hasActiveQQFilter ? Color.monologueGlassTint : Color.clear))
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
                                        Color.clear.monologueGlass(cornerRadius: 14)
                                    }
                                }

                            MonologueIcon(
                                icon: .filter,
                                size: 18,
                                color: NeumorphicStyle.isActive ? (hasActiveQQFilter ? MusicSource.qqmusic.themedBadgeColor : NeumorphicStyle.inkMuted) : (hasActiveQQFilter ? .monologueIconForeground : Theme.secondaryText)
                            )
                            .rotationEffect(.degrees(showQQFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
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
                        MonologueIcon(icon: .personEmpty, size: 50, color: Theme.secondaryText.opacity(0.5))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in
                    if focusedSearchField != nil {
                        focusedSearchField = nil
                    }
                }
        )
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
                            .background(Capsule().fill(isSelected ? Color.monologueIconBackground : Color.monologueGlassTint))
                            .foregroundColor(isSelected ? .monologueIconForeground : .monologueTextPrimary)
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
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
                            .background(Capsule().fill(isSelected ? Color.monologueIconBackground : Color.monologueGlassTint))
                            .foregroundColor(isSelected ? .monologueIconForeground : .monologueTextPrimary)
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }

    private func mujiFilterPill(title: String, selected: Bool) -> some View {
        Text(title)
            .font(MujiStyle.labelFont(12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? ThemeColorCustomization.readableForegroundColor(on: MujiStyle.clay, light: MujiStyle.ink, dark: Color.white) : MujiStyle.inkSoft)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? MujiStyle.clay : MujiStyle.surface.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
            )
    }

    private func dismissArtistSearchKeyboard() {
        focusedSearchField = nil
    }
}

private struct LibraryDisclosureReveal<Content: View>: View {
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

struct ChartsLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme

    private let officialIds: Set<Int> = [19_723_756, 3_779_629, 2_884_035, 3_778_678]

    private var officialCharts: [TopList] {
        viewModel.topLists.filter { officialIds.contains($0.id) }
    }

    private var otherCharts: [TopList] {
        viewModel.topLists.filter { !officialIds.contains($0.id) }
    }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: DeviceLayout.artistGridColumns)

    var body: some View {
        VStack(spacing: 0) {
            // HStack {
            //     MusicSourcePicker(source: $viewModel.chartsSource)
            //     Spacer()
            // }
            // .padding(.horizontal, 24)
            // .padding(.top, 4)
            // .onChange(of: viewModel.chartsSource) { _, newSource in
            //     if newSource == .qq {
            //         viewModel.fetchQQTopLists()
            //     } else {
            //         viewModel.fetchTopLists()
            //     }
            // }

            // 暂时隐藏 QQ 榜单选项，直接强制显示 NCM
            ncmChartsContent
        }
        .background(Color.clear)
    }

    // MARK: - NCM Charts

    private var ncmChartsContent: some View {
        ScrollView {
            if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if viewModel.topLists.isEmpty {
                if NeumorphicStyle.isActive {
                    NeumorphicLibraryEmptyState(
                        icon: .chart,
                        title: String(localized: "empty_no_charts"),
                        tint: NeumorphicStyle.red
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text(LocalizedStringKey("empty_no_charts"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    if !officialCharts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(LocalizedStringKey("charts_official"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                            ScrollView(.horizontal) {
                                HStack(spacing: 14) {
                                    ForEach(officialCharts) { list in
                                        NavigationLink(value: chartDestination(list)) {
                                            OfficialChartCard(list: list)
                                        }
                                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                                    }
                                }
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            }
                            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                        }
                    }

                    if !otherCharts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(LocalizedStringKey("charts_more"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(otherCharts) { list in
                                    NavigationLink(value: chartDestination(list)) {
                                        CompactChartCard(list: list)
                                    }
                                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                                }
                            }
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        }
                    }
                }
                .padding(.top, 8)
            }

            FloatingBarBottomSpacer()
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .scrollContentBackground(.hidden)
        .refreshable {
            await refreshCharts()
        }
    }

    // MARK: - QQ Charts

    private var qqChartsContent: some View {
        ScrollView {
            if viewModel.isLoadingQQCharts && viewModel.qqTopLists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if viewModel.qqTopLists.isEmpty {
                if NeumorphicStyle.isActive {
                    NeumorphicLibraryEmptyState(
                        icon: .chart,
                        title: String(localized: "暂无QCM排行榜"),
                        tint: MusicSource.qqmusic.themedBadgeColor
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text("暂无QCM排行榜")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(viewModel.qqTopLists) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(group.groupName)
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                            if group.groupId == 0 || group.items.count <= 4 {
                                // 官方榜：横向大卡片
                                ScrollView(.horizontal) {
                                    HStack(spacing: 14) {
                                        ForEach(group.items) { item in
                                            NavigationLink(value: qqChartDestination(item)) {
                                                QQOfficialChartCard(item: item)
                                            }
                                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                                        }
                                    }
                                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                                }
                                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                            } else {
                                // 其他榜：三列网格
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(group.items) { item in
                                        NavigationLink(value: qqChartDestination(item)) {
                                            QQChartCard(item: item)
                                        }
                                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                                    }
                                }
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }

            FloatingBarBottomSpacer()
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .scrollContentBackground(.hidden)
        .refreshable {
            await refreshQQCharts()
        }
    }

    // MARK: - Helpers

    private func chartDestination(_ list: TopList) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: list.id, name: list.name, coverImgUrl: list.coverImgUrl,
            picUrl: nil, trackCount: nil, playCount: nil,
            subscribedCount: nil, shareCount: nil, commentCount: nil,
            creator: nil, description: nil, tags: nil, isTopList: true
        ))
    }

    private func qqChartDestination(_ item: QQTopListItem) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: item.topId, name: item.title, coverImgUrl: item.coverUrl,
            picUrl: nil, trackCount: nil, playCount: nil,
            subscribedCount: nil, shareCount: nil, commentCount: nil,
            creator: nil, description: item.intro.isEmpty ? nil : item.intro,
            tags: nil, source: .qqmusic, isTopList: true
        ))
    }

    private func refreshCharts() async {
        viewModel.topLists = []
        viewModel.isLoadingCharts = true
        OptimizedCacheManager.shared.setObject([TopList](), forKey: "top_charts_lists")
        viewModel.fetchTopLists()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func refreshQQCharts() async {
        viewModel.qqTopLists = []
        viewModel.isLoadingQQCharts = true
        OptimizedCacheManager.shared.setObject([QQTopListGroup](), forKey: "qq_top_charts")
        viewModel.fetchQQTopLists()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }
}

// MARK: - QQ 排行榜卡片

private struct QQChartCard: View {
    let item: QQTopListItem
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = item.coverURL {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.monologueSeparator)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.monologueSeparator)
                    .aspectRatio(1, contentMode: .fit)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .topLeading)

                Text(item.intro.isEmpty ? " " : item.intro)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .medium) : .system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(NeumorphicStyle.isActive ? 8 : 0)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            }
        }
    }
}

// MARK: - QQ 官方排行榜大卡片

private struct QQOfficialChartCard: View {
    let item: QQTopListItem
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = item.coverURL {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.monologueSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monologueSeparator)
                    .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
            }

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(item.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !item.intro.isEmpty {
                    Text(item.intro)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(width: DeviceLayout.chartCardSize, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 官方榜单大卡片

private struct OfficialChartCard: View {
    let list: TopList
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: list.coverUrl?.sized(600)) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monologueSeparator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(list.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(list.updateFrequency)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(14)
            .frame(width: DeviceLayout.chartCardSize, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 紧凑榜单卡片

private struct CompactChartCard: View {
    let list: TopList
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: list.coverUrl?.sized(400)) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.monologueSeparator)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .topLeading)

                Text(list.updateFrequency)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .medium) : .system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(NeumorphicStyle.isActive ? 8 : 0)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            }
        }
    }
}

// MARK: - Components

struct LibraryPlaylistRow: View {
    let playlist: Playlist
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.listRowCoverStandard, height: DeviceLayout.listRowCoverStandard)
            .cornerRadius(SequoiaStyle.isActive ? 14 : 12)
            .overlay {
                if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                }
            }
            .shadow(color: SequoiaStyle.isActive ? Color.black.opacity(0.04) : Color.black.opacity(0.08), radius: SequoiaStyle.isActive ? 3 : 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .semibold, design: .rounded)))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : Theme.text))
                    .lineLimit(1)

                Text(String(format: NSLocalizedString("track_count_songs", comment: ""), playlist.trackCount ?? 0))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .medium, design: .rounded)))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : Theme.secondaryText))
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : Theme.secondaryText)).opacity(0.7))
        }
        .padding(14)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
            } else {
                Color.clear.monologueGlass(cornerRadius: 18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 20 : (SequoiaStyle.isActive ? 20 : 18), style: .continuous))
    }
}

// MARK: - Manga Library Redesign

private struct MangaLibraryExperience: View {
    private enum MangaMyLibraryColumn: CaseIterable, Hashable {
        case localPlaylists
        case ncmPlaylists
        case qcmPlaylists
        case localPodcasts
        case ncmPodcasts

        var title: String {
            switch self {
            case .localPlaylists: return String(localized: "lib_local_playlists")
            case .ncmPlaylists: return String(localized: "lib_netease_playlists")
            case .qcmPlaylists: return String(localized: "QCM歌单")
            case .localPodcasts: return String(localized: "本地播客")
            case .ncmPodcasts: return String(localized: "NCM 播客")
            }
        }

        var icon: MonologueIcon.IconType {
            switch self {
            case .localPlaylists: return .musicNoteList
            case .ncmPlaylists, .qcmPlaylists: return .list
            case .localPodcasts, .ncmPodcasts: return .radio
            }
        }

        var tint: Color {
            switch self {
            case .localPlaylists: return MangaStyle.labelYellow
            case .ncmPlaylists: return MangaStyle.bubbleBlue
            case .qcmPlaylists: return MangaStyle.bubblePink
            case .localPodcasts: return MangaStyle.mint
            case .ncmPodcasts: return MangaStyle.decoBlue
            }
        }
    }

    @ObservedObject var viewModel: LibraryViewModel
    @Binding var tabIndex: Int
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var localManager = LocalPlaylistManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var qqSession = QQUserSession.shared
    @State private var showFileImporter = false
    @State private var showQQImport = false
    @State private var isImporting = false
    @State private var selectedMyLibraryColumn: MangaMyLibraryColumn = .localPlaylists
    @State private var isLibraryActionsExpanded = false
    @State private var qqUserPlaylists: [Playlist] = []
    @State private var isLoadingQQUserPlaylists = false
    @State private var hasLoadedQQUserPlaylists = false

    private let tabs = LibraryViewModel.LibraryTab.allCases
    private let twoColumns = [
        GridItem(.flexible(), spacing: 13),
        GridItem(.flexible(), spacing: 13),
    ]
    private let controlColumns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9),
    ]
    private let threeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            ThemedPageBackground(useRenderLayer: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    magazineHeader
                    tabContent
                }
                .padding(.bottom, 128)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .onAppear {
            syncTabFromViewModel()
            loadCurrentTab()
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
        .onChange(of: viewModel.currentTab) { _, _ in
            syncTabFromViewModel()
            loadCurrentTab()
        }
        .onChange(of: tabIndex) { _, _ in
            loadCurrentTab()
        }
        .onChange(of: qqSession.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                hasLoadedQQUserPlaylists = false
                loadQQUserPlaylistsIfNeeded(force: true)
            } else {
                qqUserPlaylists = []
                hasLoadedQQUserPlaylists = false
            }
        }
        .monologueSheet(isPresented: $showQQImport, preset: .large) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case let .failure(error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
    }

    private var selectedTab: LibraryViewModel.LibraryTab {
        tabs[min(max(tabIndex, 0), tabs.count - 1)]
    }

    private var magazineHeader: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(MangaStyle.bubblePink)
                    MangaDotsTexture(opacity: 0.05, gap: 8)
                    MonologueIcon(icon: .libraryFilled, size: 23, color: MangaStyle.ink, lineWidth: 2)
                }
                .frame(width: 54, height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                )
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 2, y: 2)
                )
                .rotationEffect(.degrees(-2))

                VStack(alignment: .leading, spacing: 6) {
                    MangaLabel(text: "LIBRARY", tint: MangaStyle.labelYellow, small: true)

                    Text(LocalizedStringKey("tabbar_library"))
                        .font(MangaStyle.titleFont(DeviceLayout.isPad ? 30 : 26, weight: .black))
                        .foregroundStyle(MangaStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            mangaTabStrip
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    private var mangaTabStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                Button {
                    selectTab(tab, index: index)
                } label: {
                    HStack(spacing: 5) {
                        MonologueIcon(icon: icon(for: tab), size: 13, color: tabForeground(for: tab, selected: tabIndex == index), lineWidth: 1.8)
                        Text(tab.localizedKey)
                            .font(MangaStyle.labelFont(10, weight: .black))
                            .foregroundStyle(tabForeground(for: tab, selected: tabIndex == index))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tabIndex == index ? tint(for: tab) : MangaStyle.surface.opacity(0.58))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: tabIndex == index ? MangaStyle.strokeWidth : MangaStyle.fineStrokeWidth)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MangaStyle.strokeInk)
                            .offset(x: tabIndex == index ? 2 : 0.8, y: tabIndex == index ? 2 : 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MangaStyle.surface.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MangaStyle.strokeInk.opacity(0.9), lineWidth: MangaStyle.fineStrokeWidth)
        )
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .my:
            myLibraryPage
        case .square:
            playlistSquarePage
        case .artists:
            artistsPage
        case .charts:
            chartsPage
        }
    }

    private var myLibraryPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            mangaMyLibraryControlPanel
            mangaMyLibraryColumnContent
        }
    }

    private var mangaMyLibraryControlPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                mangaMyLibraryColumnStrip
                    .layoutPriority(1)

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        isLibraryActionsExpanded.toggle()
                    }
                } label: {
                    MonologueIcon(
                        icon: isLibraryActionsExpanded ? .close : .more,
                        size: 16,
                        color: MangaStyle.strokeInk,
                        lineWidth: 1.8
                    )
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(isLibraryActionsExpanded ? MangaStyle.labelYellow : MangaStyle.bubbleWhite.opacity(0.82))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }

            LibraryDisclosureReveal(isExpanded: isLibraryActionsExpanded) {
                mangaImportActionStrip
                    .padding(10)
                    .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: MangaStyle.bubbleWhite))
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private var mangaMyLibraryColumnStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MangaMyLibraryColumn.allCases, id: \.self) { column in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedMyLibraryColumn = column
                        }
                        if column == .qcmPlaylists {
                            loadQQUserPlaylistsIfNeeded()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            MonologueIcon(
                                icon: column.icon,
                                size: 14,
                                color: columnForeground(for: column, selected: selectedMyLibraryColumn == column),
                                lineWidth: selectedMyLibraryColumn == column ? 2 : 1.6
                            )

                            Text(column.title)
                                .font(MangaStyle.labelFont(11, weight: .black))
                                .foregroundStyle(columnForeground(for: column, selected: selectedMyLibraryColumn == column))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(
                            Capsule()
                                .fill(selectedMyLibraryColumn == column ? column.tint : MangaStyle.bubbleWhite.opacity(0.74))
                        )
                        .overlay(
                            Capsule()
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                        )
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(.bottom, 2)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    @ViewBuilder
    private var mangaMyLibraryColumnContent: some View {
        switch selectedMyLibraryColumn {
        case .localPlaylists:
            mangaLocalPlaylistsGrid
        case .ncmPlaylists:
            mangaNCMPlaylistsGrid
        case .qcmPlaylists:
            mangaQCMPlaylistsGrid
        case .localPodcasts:
            mangaLocalPodcastsGrid
        case .ncmPodcasts:
            mangaNCMPodcastsGrid
        }
    }

    private var mangaLocalPlaylistsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaLibrarySectionHeader(title: MangaMyLibraryColumn.localPlaylists.title)

            if localManager.playlists.isEmpty {
                MangaEmptyPanel(icon: .musicNoteList, title: String(localized: "lib_no_local_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(localManager.playlists, id: \.id) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                            MangaLocalPlaylistPoster(playlist: playlist)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        }
    }

    private var mangaNCMPlaylistsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaLibrarySectionHeader(title: MangaMyLibraryColumn.ncmPlaylists.title)

            if viewModel.userPlaylists.isEmpty {
                MangaEmptyPanel(icon: .list, title: String(localized: "empty_no_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else {
                mangaPlaylistGrid(playlists: viewModel.userPlaylists, isLoading: false)
            }
        }
    }

    private var mangaQCMPlaylistsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaLibrarySectionHeader(title: MangaMyLibraryColumn.qcmPlaylists.title)

            if isLoadingQQUserPlaylists && qqUserPlaylists.isEmpty {
                LibraryLoadingStateView(text: "LOADING QCM", horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if !qqSession.isLoggedIn {
                MangaEmptyPanel(icon: .musicNoteList, title: String(localized: "请先登录 QCM"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else if qqUserPlaylists.isEmpty {
                MangaEmptyPanel(icon: .list, title: String(localized: "暂无 QCM 歌单"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(qqUserPlaylists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            MangaPlaylistPoster(playlist: playlist, tint: MangaStyle.bubblePink)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        }
    }

    private var mangaLocalPodcastsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaLibrarySectionHeader(title: MangaMyLibraryColumn.localPodcasts.title)

            if subManager.localSubscribedRadios.isEmpty {
                MangaEmptyPanel(icon: .radio, title: String(localized: "暂无本地收藏"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(subManager.localSubscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            MangaPodcastPoster(radio: radio)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    subManager.removeLocalRadio(radio)
                                }
                            } label: {
                                Label(String(localized: "lib_unsubscribe"), systemImage: "heart.slash")
                            }
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        }
    }

    private var mangaNCMPodcastsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaLibrarySectionHeader(title: MangaMyLibraryColumn.ncmPodcasts.title)

            if subManager.isLoadingRadios && subManager.subscribedRadios.isEmpty {
                LibraryLoadingStateView(text: "LOADING PODCASTS", horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if subManager.subscribedRadios.isEmpty {
                MangaEmptyPanel(icon: .radio, title: String(localized: "lib_no_podcasts"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(subManager.subscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            MangaPodcastPoster(radio: radio)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        }
    }

    private var mangaImportActionStrip: some View {
        LazyVGrid(columns: controlColumns, spacing: 9) {
            MangaLibraryActionChip(
                title: String(localized: "lib_create"),
                icon: .add,
                tint: MangaStyle.labelYellow
            ) {
                createLocalPlaylist()
            }

            MangaLibraryActionChip(
                title: String(localized: "lib_import_playlist"),
                icon: .download,
                tint: MangaStyle.bubbleBlue,
                isLoading: isImporting
            ) {
                showFileImporter = true
            }
            .disabled(isImporting)

            MangaLibraryActionChip(
                title: String(localized: "从链接导入"),
                icon: .share,
                tint: MangaStyle.mint,
                isLoading: isImporting
            ) {
                showImportLinkPrompt()
            }
            .disabled(isImporting)

            MangaLibraryActionChip(
                title: String(localized: "QCM歌单"),
                icon: .musicNoteList,
                tint: MangaStyle.bubblePink
            ) {
                showQQImport = true
            }
        }
    }

    private var playlistSquarePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            MangaLibrarySourceStrip(
                selected: viewModel.squareSource,
                firstTitle: "NCM",
                secondTitle: "QCM"
            ) { source in
                viewModel.squareSource = source
                if source == .qq {
                    viewModel.fetchQQSquareData()
                } else {
                    viewModel.fetchSquareData()
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            if viewModel.squareSource == .qq {
                qqCategoryBar
                mangaPlaylistGrid(playlists: viewModel.qqSquarePlaylists, isLoading: viewModel.isLoadingQQSquare)

                if viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                    loadMorePanel {
                        viewModel.loadMoreQQSquarePlaylists()
                    }
                }
            } else {
                ncmCategoryBar
                mangaPlaylistGrid(playlists: viewModel.squarePlaylists, isLoading: viewModel.isLoadingSquare)

                if viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                    loadMorePanel {
                        viewModel.loadMoreSquarePlaylists()
                    }
                }
            }
        }
    }

    private var artistsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            MangaLibrarySourceStrip(
                selected: viewModel.artistSource,
                firstTitle: "NCM",
                secondTitle: "QCM"
            ) { source in
                viewModel.artistSource = source
                if source == .qq {
                    viewModel.fetchQQArtistData(reset: true)
                } else {
                    viewModel.fetchArtistData(reset: true)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            if viewModel.artistSource == .qq {
                qqArtistFilterBar
                qqArtistSexBar
                qqArtistGenreBar
                artistGrid(artists: viewModel.qqArtists, isLoading: viewModel.isLoadingQQArtists)
                if viewModel.hasMoreQQArtists && !viewModel.qqArtists.isEmpty {
                    loadMorePanel {
                        viewModel.loadMoreQQArtists()
                    }
                }
            } else {
                ncmArtistFilterBar
                ncmArtistTypeBar
                ncmArtistInitialBar
                artistGrid(artists: viewModel.topArtists, isLoading: viewModel.isLoadingArtists)
                if viewModel.hasMoreArtists && !viewModel.topArtists.isEmpty {
                    loadMorePanel {
                        viewModel.loadMoreArtists()
                    }
                }
            }
        }
    }

    private var chartsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            MangaLibrarySourceStrip(
                selected: viewModel.chartsSource,
                firstTitle: "NCM",
                secondTitle: "QCM"
            ) { source in
                viewModel.chartsSource = source
                if source == .qq {
                    viewModel.fetchQQTopLists()
                } else {
                    viewModel.fetchTopLists()
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            if viewModel.chartsSource == .qq {
                if viewModel.isLoadingQQCharts && viewModel.qqTopLists.isEmpty {
                    LibraryLoadingStateView(text: "LOADING CHARTS", horizontalPadding: DeviceLayout.viewHorizontalPadding)
                } else if viewModel.qqTopLists.isEmpty {
                    MangaEmptyPanel(icon: .chart, title: String(localized: "empty_no_charts"))
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                } else {
                    ForEach(viewModel.qqTopLists) { group in
                        MangaLibrarySectionHeader(title: group.groupName)
                        LazyVGrid(columns: twoColumns, spacing: 14) {
                            ForEach(group.items) { item in
                                NavigationLink(value: qqChartDestination(item)) {
                                    MangaQQChartPoster(item: item)
                                }
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                }
            } else {
                if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                    LibraryLoadingStateView(text: "LOADING CHARTS", horizontalPadding: DeviceLayout.viewHorizontalPadding)
                } else if viewModel.topLists.isEmpty {
                    MangaEmptyPanel(icon: .chart, title: String(localized: "empty_no_charts"))
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                } else {
                    MangaLibrarySectionHeader(title: String(localized: "lib_tab_charts"))
                    LazyVGrid(columns: twoColumns, spacing: 14) {
                        ForEach(viewModel.topLists) { list in
                            NavigationLink(value: chartDestination(list)) {
                                MangaChartPoster(list: list)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                }
            }
        }
    }

    private var ncmCategoryBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(Array(viewModel.playlistCategories.prefix(18)), id: \.idString) { category in
                    MangaFilterChip(
                        title: category.name,
                        selected: viewModel.selectedCategory == category.name,
                        tint: MangaStyle.labelYellow
                    ) {
                        viewModel.selectedCategory = category.name
                        viewModel.loadSquarePlaylists(cat: category.name, reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private var qqCategoryBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(Array(viewModel.qqPlaylistCategories.prefix(18)), id: \.id) { category in
                    MangaFilterChip(
                        title: category.name,
                        selected: viewModel.selectedQQCategoryId == category.id,
                        tint: MangaStyle.bubbleBlue
                    ) {
                        viewModel.selectedQQCategoryId = category.id
                        viewModel.selectedQQCategoryName = category.name
                        viewModel.loadQQSquarePlaylists(categoryId: category.id, reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private var ncmArtistFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(viewModel.artistAreas, id: \.value) { area in
                    MangaFilterChip(
                        title: NSLocalizedString(area.name, comment: ""),
                        selected: viewModel.artistArea == area.value,
                        tint: MangaStyle.mint
                    ) {
                        viewModel.artistArea = area.value
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private var ncmArtistTypeBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(viewModel.artistTypes, id: \.value) { type in
                    MangaFilterChip(
                        title: NSLocalizedString(type.name, comment: ""),
                        selected: viewModel.artistType == type.value,
                        tint: MangaStyle.bubbleBlue
                    ) {
                        viewModel.artistType = type.value
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private var ncmArtistInitialBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(viewModel.artistInitials, id: \.self) { initial in
                    MangaFilterChip(
                        title: initial == "-1" ? NSLocalizedString("search_hot", comment: "") : initial,
                        selected: viewModel.artistInitial == initial,
                        tint: MangaStyle.labelYellow
                    ) {
                        viewModel.artistInitial = initial
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private var qqArtistFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(viewModel.qqArtistAreas, id: \.value) { area in
                    MangaFilterChip(
                        title: NSLocalizedString(area.name, comment: ""),
                        selected: viewModel.qqArtistArea == area.value,
                        tint: MangaStyle.bubblePink
                    ) {
                        viewModel.qqArtistArea = area.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private var qqArtistSexBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(viewModel.qqArtistSexes, id: \.value) { sex in
                    MangaFilterChip(
                        title: NSLocalizedString(sex.name, comment: ""),
                        selected: viewModel.qqArtistSex == sex.value,
                        tint: MangaStyle.labelYellow
                    ) {
                        viewModel.qqArtistSex = sex.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private var qqArtistGenreBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(viewModel.qqArtistGenres, id: \.value) { genre in
                    MangaFilterChip(
                        title: NSLocalizedString(genre.name, comment: ""),
                        selected: viewModel.qqArtistGenre == genre.value,
                        tint: MangaStyle.mint
                    ) {
                        viewModel.qqArtistGenre = genre.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func mangaPlaylistGrid(playlists: [Playlist], isLoading: Bool) -> some View {
        Group {
            if isLoading && playlists.isEmpty {
                LibraryLoadingStateView(text: "LOADING PLAYLISTS", horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if playlists.isEmpty {
                MangaEmptyPanel(icon: .list, title: String(localized: "empty_no_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            MangaPlaylistPoster(playlist: playlist, tint: playlist.isQQMusic ? MangaStyle.bubbleBlue : MangaStyle.labelYellow)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        }
    }

    private func artistGrid(artists: [ArtistInfo], isLoading: Bool) -> some View {
        Group {
            if isLoading && artists.isEmpty {
                LibraryLoadingStateView(text: "LOADING ARTISTS", horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if artists.isEmpty {
                MangaEmptyPanel(icon: .personCircle, title: String(localized: "artist_no_similar"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else {
                LazyVGrid(columns: threeColumns, spacing: 15) {
                    ForEach(artists) { artist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                            MangaArtistPoster(artist: artist)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        }
    }

    private func loadMorePanel(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MangaLabel(text: String(localized: "查看更多"), tint: MangaStyle.decoBlue, small: true)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
        .padding(.top, 6)
        .padding(.bottom, 78)
    }

    private func selectTab(_ tab: LibraryViewModel.LibraryTab, index: Int) {
        tabIndex = index
        viewModel.currentTab = tab
        load(tab)
    }

    private func syncTabFromViewModel() {
        if let index = tabs.firstIndex(of: viewModel.currentTab), index != tabIndex {
            tabIndex = index
        }
    }

    private func loadCurrentTab() {
        load(selectedTab)
    }

    private func load(_ tab: LibraryViewModel.LibraryTab) {
        switch tab {
        case .my:
            viewModel.fetchPlaylists()
            loadQQUserPlaylistsIfNeeded()
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        case .square:
            if viewModel.squareSource == .qq {
                viewModel.fetchQQSquareData()
            } else {
                viewModel.fetchSquareData()
            }
        case .artists:
            if viewModel.artistSource == .qq {
                viewModel.fetchQQArtistData()
            } else {
                viewModel.fetchArtistData()
            }
        case .charts:
            if viewModel.chartsSource == .qq {
                viewModel.fetchQQTopLists()
            } else {
                viewModel.fetchTopLists()
            }
        }
    }

    private func columnForeground(for column: MangaMyLibraryColumn, selected: Bool) -> Color {
        guard selected else { return MangaStyle.inkSub }
        switch column {
        case .localPlaylists, .localPodcasts, .ncmPodcasts:
            return MangaStyle.strokeInk
        case .ncmPlaylists, .qcmPlaylists:
            return MangaStyle.ink
        }
    }

    private func loadQQUserPlaylistsIfNeeded(force: Bool = false) {
        guard force || !hasLoadedQQUserPlaylists else { return }
        guard !isLoadingQQUserPlaylists else { return }

        guard qqSession.isLoggedIn, let mid = qqSession.musicId else {
            qqUserPlaylists = []
            hasLoadedQQUserPlaylists = true
            return
        }

        isLoadingQQUserPlaylists = true

        Task { @MainActor in
            defer {
                isLoadingQQUserPlaylists = false
                hasLoadedQQUserPlaylists = true
            }

            do {
                let result: JSON = try await QQUserSession.shared.withUserSession { client in
                    try await client.createdSonglist(uin: String(mid))
                }
                qqUserPlaylists = Self.parseQQUserPlaylists(result)
            } catch {
                AppLogger.error("[MangaLibrary] 加载 QCM 歌单失败: \(error)")
            }
        }
    }

    private static func parseQQUserPlaylists(_ result: JSON) -> [Playlist] {
        let list = result["v_playlist"]?.arrayValue ?? result.arrayValue ?? []

        return list.compactMap { json in
            guard let obj = json.objectValue else { return nil }
            let tid = obj["tid"]?.intValue ?? 0
            let name = obj["dirName"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
            let cover = obj["picUrl"]?.stringValue ?? obj["logo"]?.stringValue ?? ""
            let songCount = obj["songNum"]?.intValue ?? obj["song_cnt"]?.intValue ?? 0

            guard !name.isEmpty else { return nil }

            return Playlist(
                id: tid,
                name: name,
                coverImgUrl: cover,
                picUrl: nil,
                trackCount: songCount,
                playCount: nil,
                subscribedCount: nil,
                shareCount: nil,
                commentCount: nil,
                creator: nil,
                description: nil,
                tags: nil,
                source: .qqmusic
            )
        }
    }

    private func createLocalPlaylist() {
        AlertManager.shared.showInput(
            title: String(localized: "lib_create_playlist"),
            message: "",
            placeholder: String(localized: "lib_playlist_name"),
            primaryButtonTitle: String(localized: "lib_create"),
            secondaryButtonTitle: String(localized: "alert_cancel"),
            onConfirm: { name in
                guard !name.isEmpty else { return }
                _ = localManager.createPlaylist(name: name)
            }
        )
    }

    private func showImportLinkPrompt() {
        AlertManager.shared.showInput(
            title: String(localized: "从链接导入歌单"),
            message: "",
            placeholder: String(localized: "粘贴歌单链接"),
            primaryButtonTitle: String(localized: "导入"),
            secondaryButtonTitle: String(localized: "取消"),
            onConfirm: { url in
                importPlaylistFromURL(url)
            }
        )
    }

    private func importPlaylistFromFile(url: URL) {
        isImporting = true

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let parsed = try LocalPlaylistManager.parseExportFile(url: url)
            let ids = parsed.songIds
            let name = parsed.name

            guard !ids.isEmpty else {
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: String(localized: "lib_import_no_songs"),
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
                isImporting = false
                return
            }

            Task {
                var allSongs: [Song] = []
                let batchSize = 50

                for i in stride(from: 0, to: ids.count, by: batchSize) {
                    let batch = Array(ids[i ..< min(i + batchSize, ids.count)])
                    do {
                        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                            var cancellable: AnyCancellable?
                            cancellable = APIService.shared.fetchSongDetails(ids: batch)
                                .sink(receiveCompletion: { completion in
                                    if case let .failure(error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                    cancellable?.cancel()
                                }, receiveValue: { songs in
                                    continuation.resume(returning: songs)
                                    cancellable?.cancel()
                                })
                        }
                        allSongs.append(contentsOf: songs)
                    } catch {
                        AppLogger.error("导入歌单批次获取失败: \(error)")
                    }
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "lib_import_fetch_failed"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            }
        } catch {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    private func importPlaylistFromURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isImporting = true

        if let qqId = extractQQPlaylistId(from: trimmed) {
            importQQPlaylist(id: qqId)
        } else if let ncmId = extractNCMPlaylistId(from: trimmed) {
            importNCMPlaylist(id: ncmId)
        } else {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: String(localized: "无法识别的歌单链接"),
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    private func extractQQPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist/(\d+)"#, options: .regularExpression) {
            let match = url[range]
            let digits = match.replacingOccurrences(of: "playlist/", with: "")
            return Int(digits)
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("y.qq.com") {
            let match = String(url[range])
            let digits = match.replacingOccurrences(of: "id=", with: "")
            return Int(digits)
        }
        return nil
    }

    private func extractNCMPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist\?id=(\d+)"#, options: .regularExpression) {
            let match = String(url[range])
            let digits = match.replacingOccurrences(of: "playlist?id=", with: "")
            return Int(digits)
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("music.163.com") {
            let match = String(url[range])
            let digits = match.replacingOccurrences(of: "id=", with: "")
            return Int(digits)
        }
        return nil
    }

    private func importQQPlaylist(id: Int) {
        Task {
            do {
                let detail = try await APIService.shared.qqClient.songlistDetail(songlistId: id, num: 1, page: 1)
                let name = detail["dirinfo"]?["title"]?.stringValue ?? String(localized: "QCM歌单")

                var allSongs: [Song] = []
                var page = 1
                var hasMore = true

                while hasMore {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: id, page: page, num: 50)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    if songs.count < 50 { hasMore = false }
                    page += 1
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "歌单为空或获取失败"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "QCM歌单导入失败: \(error.localizedDescription)"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                    isImporting = false
                }
            }
        }
    }

    private func importNCMPlaylist(id: Int) {
        Task {
            var allSongs: [Song] = []
            var offset = 0
            let limit = 50
            var hasMore = true

            while hasMore {
                do {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: offset)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    if songs.count < limit { hasMore = false }
                    offset += limit
                } catch {
                    hasMore = false
                }
            }

            await MainActor.run {
                if allSongs.isEmpty {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "歌单为空或获取失败"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                } else {
                    localManager.importPlaylist(name: String(localized: "NCM歌单"), songs: allSongs)
                }
                isImporting = false
            }
        }
    }

    private func icon(for tab: LibraryViewModel.LibraryTab) -> MonologueIcon.IconType {
        switch tab {
        case .my: return .libraryFilled
        case .square: return .gridSquare
        case .artists: return .personCircle
        case .charts: return .chart
        }
    }

    private func tint(for tab: LibraryViewModel.LibraryTab) -> Color {
        switch tab {
        case .my: return MangaStyle.labelYellow
        case .square: return MangaStyle.bubbleBlue
        case .artists: return MangaStyle.mint
        case .charts: return MangaStyle.bubblePink
        }
    }

    private func tabForeground(for tab: LibraryViewModel.LibraryTab, selected: Bool) -> Color {
        guard selected else { return MangaStyle.ink }
        switch tab {
        case .my, .artists:
            return MangaStyle.strokeInk
        case .square, .charts:
            return MangaStyle.ink
        }
    }

    private func chartDestination(_ list: TopList) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: list.id,
            name: list.name,
            coverImgUrl: list.coverImgUrl,
            picUrl: nil,
            trackCount: nil,
            playCount: nil,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: nil,
            tags: nil,
            isTopList: true
        ))
    }

    private func qqChartDestination(_ item: QQTopListItem) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: item.topId,
            name: item.title,
            coverImgUrl: item.coverUrl,
            picUrl: nil,
            trackCount: nil,
            playCount: nil,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: item.intro.isEmpty ? nil : item.intro,
            tags: nil,
            source: .qqmusic,
            isTopList: true
        ))
    }
}

private struct MangaLibrarySectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        MangaSectionTitle(
            title: title,
            actionTitle: actionTitle,
            mark: .star,
            action: action
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
    }
}

private struct MangaLibrarySourceStrip: View {
    let selected: LibraryViewModel.MusicSource
    let firstTitle: String
    let secondTitle: String
    let onSelect: (LibraryViewModel.MusicSource) -> Void

    var body: some View {
        HStack(spacing: 8) {
            sourceButton(title: firstTitle, source: .ncm, tint: MusicSource.netease.themedBadgeColor)
            sourceButton(title: secondTitle, source: .qq, tint: MusicSource.qqmusic.themedBadgeColor)
            Spacer(minLength: 0)
        }
        .padding(7)
        .background(MangaCardBackground(cornerRadius: 16, elevated: false, tint: MangaStyle.bubbleWhite))
    }

    private func sourceButton(title: String, source: LibraryViewModel.MusicSource, tint: Color) -> some View {
        Button {
            onSelect(source)
        } label: {
            Text(title)
                .font(MangaStyle.labelFont(12, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected == source ? tint : MangaStyle.surface.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MangaLibraryActionChip: View {
    let title: String
    let icon: MonologueIcon.IconType
    var tint: Color
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.72)
                        .frame(width: 16, height: 16)
                } else {
                    MonologueIcon(icon: icon, size: 16, color: MangaStyle.ink, lineWidth: 1.8)
                        .frame(width: 16, height: 16)
                }

                Text(title)
                    .font(MangaStyle.labelFont(12, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .compositingGroup()
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }
}

private struct MangaFilterChip: View {
    let title: String
    let selected: Bool
    var tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MangaStyle.labelFont(11, weight: .black))
                .foregroundStyle(selected ? MangaStyle.ink : MangaStyle.inkSub)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(
                    Capsule()
                        .fill(selected ? tint : MangaStyle.bubbleWhite.opacity(0.72))
                )
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                .clipShape(Capsule())
                .compositingGroup()
        }
        .buttonStyle(.plain)
    }
}

private struct MangaPodcastPoster: View {
    let radio: RadioStation

    var body: some View {
        MangaPosterShell(tint: MangaStyle.mint.opacity(0.92)) {
            VStack(alignment: .leading, spacing: 10) {
                CachedAsyncImage(url: radio.coverUrl?.sized(300)) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MangaStyle.paperCool)
                        .overlay(MangaDotsTexture(opacity: 0.04, gap: 10))
                        .overlay(
                            MonologueIcon(icon: .radio, size: 30, color: MangaStyle.inkSub, lineWidth: 1.8)
                        )
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))

                Text(radio.name)
                    .font(MangaStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                MangaLabel(text: radio.category ?? radio.dj?.nickname ?? "PODCAST", tint: MangaStyle.labelYellow, small: true)
            }
        }
    }
}

private struct MangaLocalPlaylistPoster: View {
    let playlist: LocalPlaylist

    var body: some View {
        MangaPosterShell(tint: playlist.isFavorite ? MangaStyle.bubblePink : (playlist.isDownload ? MangaStyle.bubbleBlue : MangaStyle.bubbleWhite)) {
            VStack(alignment: .leading, spacing: 10) {
                cover

                Text(playlist.name)
                    .font(MangaStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                MangaLabel(text: "\(playlist.trackCount) \(String(localized: "songs_unit"))", tint: MangaStyle.mint, small: true)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let url = playlist.displayCoverUrl {
            CachedAsyncImage(url: url.sized(300)) {
                placeholder
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MangaStyle.paperCool)
            MangaDotsTexture(opacity: 0.05, gap: 10)
            MonologueIcon(icon: .musicNoteList, size: 32, color: MangaStyle.inkSub, lineWidth: 1.8)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct MangaPlaylistPoster: View {
    let playlist: Playlist
    var tint: Color

    var body: some View {
        MangaPosterShell(tint: tint.opacity(0.9)) {
            VStack(alignment: .leading, spacing: 10) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MangaStyle.paperCool)
                        .overlay(MangaDotsTexture(opacity: 0.04, gap: 10))
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))

                Text(playlist.name)
                    .font(MangaStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                HStack(spacing: 6) {
                    if let count = playlist.trackCount {
                        MangaLabel(text: "\(count)", tint: MangaStyle.mint, small: true)
                    }
                    if let playCount = playlist.playCount {
                        MangaLabel(text: mangaFormatCount(playCount), tint: MangaStyle.bubblePink, small: true, foreground: MangaStyle.ink)
                    }
                }
            }
        }
    }
}

private struct MangaArtistPoster: View {
    let artist: ArtistInfo

    var body: some View {
        VStack(spacing: 9) {
            CachedAsyncImage(url: artist.coverUrl?.sized(300)) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MangaStyle.paperCool)
                    .overlay(MangaDotsTexture(opacity: 0.05, gap: 10))
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))

            Text(artist.name)
                .font(MangaStyle.bodyFont(12, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(8)
        .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: MangaStyle.bubbleWhite))
    }
}

private struct MangaChartPoster: View {
    let list: TopList

    var body: some View {
        MangaPosterShell(tint: MangaStyle.bubblePink) {
            VStack(alignment: .leading, spacing: 10) {
                CachedAsyncImage(url: list.coverUrl?.sized(400)) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MangaStyle.paperCool)
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))

                Text(list.name)
                    .font(MangaStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                MangaLabel(text: list.updateFrequency.isEmpty ? "CHART" : list.updateFrequency, tint: MangaStyle.labelYellow, small: true)
            }
        }
    }
}

private struct MangaQQChartPoster: View {
    let item: QQTopListItem

    var body: some View {
        MangaPosterShell(tint: MangaStyle.bubbleBlue) {
            VStack(alignment: .leading, spacing: 10) {
                CachedAsyncImage(url: item.coverURL?.sized(400)) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MangaStyle.paperCool)
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))

                Text(item.title)
                    .font(MangaStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                MangaLabel(text: item.period.isEmpty ? "QCM" : item.period, tint: MangaStyle.labelYellow, small: true)
            }
        }
    }
}

private struct MangaPosterShell<Content: View>: View {
    var tint: Color
    let content: Content

    init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MangaCardBackground(cornerRadius: 18, elevated: true, tint: tint))
    }
}

private struct MangaEmptyPanel: View {
    let icon: MonologueIcon.IconType
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            MonologueIcon(icon: icon, size: 34, color: MangaStyle.inkSub, lineWidth: 1.8)
            Text(title)
                .font(MangaStyle.bodyFont(14, weight: .black))
                .foregroundStyle(MangaStyle.inkSub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(MangaCardBackground(cornerRadius: 18, elevated: true, tint: MangaStyle.bubbleWhite))
    }
}

private func mangaFormatCount(_ count: Int) -> String {
    if count >= 100_000_000 {
        return String(format: "%.1f亿", Double(count) / 100_000_000)
    }
    if count >= 10000 {
        return String(format: "%.1f万", Double(count) / 10000)
    }
    return "\(count)"
}
