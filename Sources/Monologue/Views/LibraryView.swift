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
    @State private var libraryHeaderHeight: CGFloat = 0

    private let allTabs = LibraryViewModel.LibraryTab.allCases

    var body: some View {
        let _ = settings.globalThemeRevision
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if MangaStyle.isActive {
                    MangaLibraryExperience(viewModel: viewModel, tabIndex: $tabIndex)
                } else if NeumorphicStyle.isActive {
                    NeumorphicLibraryWorkspace(viewModel: viewModel, tabIndex: $tabIndex)
                } else if PetWhiteStyle.isActive {
                    ScrollableLibraryExperience(viewModel: viewModel, tabIndex: $tabIndex)
                } else if ThemedPageStyle.isActive {
                    ScrollableLibraryExperience(viewModel: viewModel, tabIndex: $tabIndex)
                } else {
                    defaultLibraryExperience
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
                if !ThemedPageStyle.isActive {
                    loadDefaultLibraryTab(newTab)
                    return
                }
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

    private var defaultLibraryExperience: some View {
        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                libraryHeaderView
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: LibraryHeaderHeightPreferenceKey.self, value: geo.size.height)
                        }
                    )
                    .frame(height: defaultLibraryHeaderCollapsedHeight, alignment: .top)
                    .opacity(Double(1 - libraryHeaderCollapseProgress))
                    .clipped()
                    .allowsHitTesting(libraryHeaderCollapseProgress < 0.5)

                TabView(selection: $tabIndex) {
                    MyPlaylistsContainerView(viewModel: viewModel)
                        .tag(0)

                    PlaylistSquareView(viewModel: viewModel)
                        .tag(1)

                    ArtistLibraryView(viewModel: viewModel)
                        .tag(2)

                    ChartsLibraryView(viewModel: viewModel)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                .simultaneousGesture(libraryHeaderScrollGesture)
            }
        }
        .onPreferenceChange(LibraryHeaderHeightPreferenceKey.self) { height in
            if height > libraryHeaderHeight {
                libraryHeaderHeight = height
            }
        }
        .onAppear {
            loadDefaultLibraryTab(viewModel.currentTab)
        }
        .onChange(of: tabIndex) { _, index in
            if libraryHeaderCollapseProgress != 0 {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    libraryHeaderCollapseProgress = 0
                }
            }
            guard allTabs.indices.contains(index) else { return }
            let tab = allTabs[index]
            guard viewModel.currentTab != tab else { return }
            viewModel.currentTab = tab
        }
    }

    private var defaultLibraryHeaderCollapsedHeight: CGFloat? {
        guard libraryHeaderHeight > 0 else { return nil }
        return libraryHeaderHeight * (1 - libraryHeaderCollapseProgress)
    }

    private func switchToTab(_ tab: LibraryViewModel.LibraryTab) {
        guard let idx = allTabs.firstIndex(of: tab) else { return }
        tabIndex = idx
        viewModel.currentTab = tab
    }

    private func loadDefaultLibraryTab(_ tab: LibraryViewModel.LibraryTab) {
        switch tab {
        case .my:
            viewModel.fetchPlaylists()
        case .square:
            viewModel.squareSource == .qq ? viewModel.fetchQQSquareData() : viewModel.fetchSquareData()
        case .artists:
            viewModel.artistSource == .qq ? viewModel.fetchQQArtistData() : viewModel.fetchArtistData()
        case .charts:
            viewModel.chartsSource == .qq ? viewModel.fetchQQTopLists() : viewModel.fetchTopLists()
        }
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
            // 周刊印刷刊头:话数眉题 + 错版大标题
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    MangaLabel(text: "MUSIC SHELF", tint: MangaStyle.labelYellow, small: true)

                    MangaMisprintTitle(text: String(localized: "tabbar_library"), size: 28)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding + 8)

                libraryTabPicker
            }
            .padding(.bottom, 10)
        } else if NeumorphicStyle.isActive {
            VStack(spacing: 14) {
                Text(String(localized: "tabbar_library"))
                    .font(NeumorphicStyle.titleFont(29, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .padding(.top, DeviceLayout.headerTopPadding + 8)

                libraryTabPicker
            }
            .padding(.bottom, 10)
        } else if MujiStyle.isActive {
            // 清新刊头 + 目次式页签
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .center, spacing: 8) {
                        MujiDotMark()

                        Text("MUSIC SHELF")
                            .font(MujiStyle.labelFont(10, weight: .semibold))
                            .foregroundStyle(MujiStyle.clay)
                            .tracking(2.2)
                            .fixedSize()
                    }

                    Text(String(localized: "tabbar_library"))
                        .font(MujiStyle.titleFont(30, weight: .medium))
                        .foregroundStyle(MujiStyle.ink)
                        .tracking(0.3)
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding + 6)

                mujiLibraryTabRow
            }
            .padding(.bottom, 8)
        } else if SettingsManager.shared.globalThemeId == .default {
            asideLibraryHeader
        } else {
            VStack(spacing: 14) {
                Text(LocalizedStringKey("tabbar_library"))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .tracking(0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

                libraryTabPicker
            }
            .padding(.top, DeviceLayout.headerTopPadding)
            .padding(.bottom, 8)
        }
    }

    /// aside 音乐库页头：大标题带强调色句点，页签左对齐 + 短下划线
    /// （与搜索页的页签语言保持一致）
    private var asideLibraryHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(LocalizedStringKey("tabbar_library"))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Circle()
                    .fill(Color.monologueAccent)
                    .frame(width: 7, height: 7)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

            HStack(spacing: 26) {
                ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                    let selected = tabIndex == index

                    Button(action: {
                        switchToTab(tab)
                    }) {
                        VStack(spacing: 5) {
                            Text(tab.localizedKey)
                                .font(.system(size: 15, weight: selected ? .heavy : .medium, design: .rounded))
                                .foregroundColor(
                                    selected
                                        ? .monologueTextPrimary
                                        : .monologueTextSecondary.opacity(0.8)
                                )
                                .animation(.none, value: tabIndex)

                            Capsule()
                                .fill(Color.monologueAccent)
                                .frame(width: 16, height: 3)
                                .opacity(selected ? 1 : 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabIndex)
        }
        .padding(.top, DeviceLayout.headerTopPadding)
        .padding(.bottom, 10)
    }

    /// Muji：目次式页签 —— 衬线文字 + 陶土短下划线，与检索页同一套语言
    private var mujiLibraryTabRow: some View {
        HStack(spacing: 24) {
            ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                let selected = tabIndex == index

                Button(action: {
                    switchToTab(tab)
                }) {
                    VStack(spacing: 5) {
                        Text(tab.localizedKey)
                            .font(MujiStyle.bodyFont(14.5, weight: selected ? .medium : .regular))
                            .foregroundStyle(selected ? MujiStyle.ink : MujiStyle.inkMuted)
                            .animation(.none, value: tabIndex)

                        Circle()
                            .fill(MujiStyle.clay)
                            .frame(width: 4.5, height: 4.5)
                            .opacity(selected ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabIndex)
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
                            .fill(libraryTabUnderlineColor)
                            .frame(width: 20, height: 2.5)
                            .opacity((ThemedPageStyle.isActive || defaultLibraryTabsUsePill) ? 0 : (tabIndex == index ? 1 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, (ThemedPageStyle.isActive || defaultLibraryTabsUsePill) ? 9 : 0)
                    .background {
                        if MangaStyle.isActive {
                            if tabIndex == index {
                                // 周刊印刷:朱红印章块 + 墨线 + 硬错版影
                                RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                    .fill(MangaStyle.labelYellow)
                                    .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                                    .background(
                                        RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                            .fill(MangaStyle.strokeInk)
                                            .offset(x: 2, y: 2)
                                    )
                            }
                        } else if MujiStyle.isActive {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(tabIndex == index ? MujiStyle.clay : Color.clear)
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
                RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous)
                    .fill(MangaStyle.surface)
                    .overlay(RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                    .shadow(color: MangaStyle.strokeInk, radius: 0, x: MangaStyle.shadowOffset, y: MangaStyle.shadowOffset)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.8))
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
        false
    }

    private var libraryTabUnderlineColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if MujiStyle.isActive { return MujiStyle.clay }
        return .monologueTextPrimary
    }

    private var defaultLibrarySelectedTabFill: Color {
        Color(light: Color.black.opacity(0.88), dark: Color.white.opacity(0.9))
    }

    private var defaultLibrarySelectedTabForeground: Color {
        Color(light: Color.white, dark: Color(hex: "111111"))
    }

    private func libraryTabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive {
            return MangaStyle.labelFont(13, weight: isSelected ? .heavy : .bold)
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
            return isSelected
                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
                : MangaStyle.inkMuted
        }
        if MujiStyle.isActive {
            return isSelected ? MujiStyle.onTint : MujiStyle.inkSoft
        }
        if NeumorphicStyle.isActive {
            return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft
        }
        if defaultLibraryTabsUsePill {
            return isSelected ? defaultLibrarySelectedTabForeground : Color.monologueTextSecondary.opacity(0.82)
        }
        return isSelected ? Color.monologueTextPrimary : Color.monologueTextSecondary.opacity(0.72)
    }
}

private struct LibraryHeaderHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
