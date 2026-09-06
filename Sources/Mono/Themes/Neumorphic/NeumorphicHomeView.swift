import Combine
import SwiftUI

/// 首页内容模块枚举，控制各区块的展示与顺序。
private enum NeumorphicHomeModule: String, CaseIterable, Identifiable {
    case daily
    case newSongs
    case playlists
    case discover

    var id: String {
        rawValue
    }

    static let drawerModules: [NeumorphicHomeModule] = [.playlists, .newSongs, .discover]

    var title: String {
        switch self {
        case .daily: return String(localized: "每日")
        case .newSongs: return String(localized: "QCM 新歌")
        case .playlists: return String(localized: "歌单")
        case .discover: return String(localized: "发现")
        }
    }

    var icon: MonoIcon.IconType {
        switch self {
        case .daily: return .sparkle
        case .newSongs: return .musicNoteList
        case .playlists: return .musicNoteList
        case .discover: return .layers
        }
    }
}

/// Neumorphic 主题首页：以拟物软塑风格展示精选旋钮、每日推荐、新歌、歌单等模块，数据来自 `HomeViewModel`。
struct NeumorphicHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true
    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var appeared = false
    @State private var didActivateHome = false
    @State private var isHomeActive = false
    @State private var hitokotoRefreshRotation: Double = 0
    @State private var selectedModule: NeumorphicHomeModule = .playlists
    @State private var deckExpanded = false
    @State private var bannerIndex = 0
    @Namespace private var moduleNamespace
    @Environment(\.themeCustomizationRevision) private var themeRevision
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = themeRevision

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)

                if viewModel.isLoading {
                    loadingView
                } else {
                    scrollBody
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
                isHomeActive = true
                activateHomeIfNeeded(reason: "neumorphic home appear")
            }
            .onReceive(NotificationCenter.default.publisher(for: .mainTabDidSettle)) { notification in
                guard let tab = notification.object as? Tab else { return }
                isHomeActive = tab == .home
                guard tab == .home,
                      MainTabActivationGate.isSettled(.home) else { return }
                activateHomeIfNeeded(reason: "neumorphic home selected")
            }
            .onDisappear {
                isHomeActive = false
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { destination in
                destinationView(for: destination)
            }
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(item: $bannerWebURL) { url in
                MonoWebView(url: url, title: nil)
            }
        }
    }

    private func activateHomeIfNeeded(reason: String) {
        guard !didActivateHome else { return }
        didActivateHome = true
        viewModel.ensureHomeDataLoaded(reason: reason)
        if hitokotoEnabled,
           viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        {
            viewModel.refreshHitokoto()
        }
        guard !appeared else { return }
        withAnimation(.spring(response: 0.58, dampingFraction: 0.86).delay(0.06)) {
            appeared = true
        }
    }

    private var scrollBody: some View {
        ScrollView {
            LazyVStack(spacing: 28) {
                topConsole
                    .monoPageHeaderCollapse()
                    .neumorphicStagger(appeared, order: 0)

                tactileStage
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 1)

                if !viewModel.banners.isEmpty {
                    signalBannerRail
                        .neumorphicStagger(appeared, order: 2)
                }

                neumorphicShortcutGrid
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 3)

                dailyRecommendationRail
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 4)

                moduleDeck
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 5)

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 8)
            .iPadContentWidth(980)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable {
            viewModel.retryHomeDataLoad(reason: "neumorphic home pull refresh")
            if hitokotoEnabled {
                viewModel.refreshHitokoto(force: true)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(NeumorphicStyle.accent.opacity(0.08))
                    .frame(width: 84, height: 84)

                NeumorphicIconBadge(icon: .layers, tint: NeumorphicStyle.accent, size: 58)

                ProgressView()
                    .tint(NeumorphicStyle.accent)
                    .scaleEffect(0.72)
                    .offset(y: 43)
            }

            Text(String(localized: "正在加载"))
                .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.inkMuted)
        }
    }

    private var topConsole: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    homeIdentity
                    topConsoleActions
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 12) {
                    homeIdentity
                    Spacer(minLength: 8)
                    topConsoleActions
                }
            }
        }
        .padding(10)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 22,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surface.opacity(0.76)
            )
        )
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var homeIdentity: some View {
        HStack(spacing: 12) {
            Button {
                NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
            } label: {
                avatarView
            }
            .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.94))
            .accessibilityLabel(String(localized: "profile_title"))

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: LocalizedStringResource(stringLiteral: MonoTimeGreeting.localizedKey)))
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .tracking(0.8)

                Text(viewModel.displayedIdentityProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(NeumorphicStyle.titleFont(24, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private var topConsoleActions: some View {
        HStack(spacing: 10) {
            NeumorphicActionButton(size: 42, action: { showPersonalFM = true }) {
                MonoIcon(icon: .radio, size: 17, color: NeumorphicStyle.sage, lineWidth: 1.6)
            }
            .accessibilityLabel(String(localized: "personal_fm"))

            NeumorphicActionButton(size: 42, action: { navigationPath.append(HomeView.HomeDestination.search) }) {
                MonoIcon(icon: .magnifyingGlass, size: 17, color: NeumorphicStyle.accent, lineWidth: 1.6)
            }
            .accessibilityLabel(String(localized: "search"))
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 46
        if let avatarUrl = viewModel.displayedIdentityProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NeumorphicStyle.surface)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clear)
                .frame(width: size, height: size)
                .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true))
                .overlay(MonoIcon(icon: .profile, size: 18, color: NeumorphicStyle.inkMuted, lineWidth: 1.6))
        }
    }

    private var tactileStage: some View {
        VStack(spacing: 18) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 18) {
                    hitokotoPanel
                    NeumorphicFeaturedDial(dailySongs: viewModel.dailySongs, isActive: isHomeActive)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    hitokotoPanel
                    NeumorphicFeaturedDial(dailySongs: viewModel.dailySongs, isActive: isHomeActive)
                        .frame(width: DeviceLayout.usesExpandedLayout ? 174 : 132)
                }
            }

            NeumorphicFeaturedSongButton(dailySongs: viewModel.dailySongs, isActive: isHomeActive)
        }
        .padding(DeviceLayout.usesExpandedLayout ? 22 : 18)
        .background(NeumorphicSurfaceBackground(cornerRadius: NeumorphicStyle.heroRadius, elevated: true))
    }

    private var hitokotoPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(NeumorphicStyle.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: NeumorphicStyle.accent.opacity(0.32), radius: 5, x: 1, y: 2)

                Text(hitokotoLabel)
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.accent)
            }

            Text(usesHitokotoFallback ? HitokotoFallbackSlogan.text : hitokotoText)
                .font(NeumorphicStyle.bodyFont(dynamicTypeSize.isAccessibilitySize ? 20 : 18, weight: .medium))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

            if hitokotoEnabled {
                Button {
                    refreshHitokotoWithFeedback()
                } label: {
                    NeumorphicPill(
                        text: String(localized: "刷新"),
                        tint: NeumorphicStyle.warm,
                        icon: .refresh,
                        selected: false,
                        iconRotation: hitokotoRefreshRotation
                    )
                }
                .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.96))
            }
        }
    }

    private var neumorphicShortcutGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 154), spacing: 12)],
            spacing: 12
        ) {
            neumorphicShortcut(
                icon: .musicNoteList,
                title: "NCM · \(String(localized: "新歌速递"))",
                subtitle: "NEW RELEASES",
                tint: MusicSource.netease.themedBadgeColor,
                action: { navigationPath.append(HomeView.HomeDestination.newSongExpress) }
            )

            neumorphicShortcut(
                icon: .moon,
                title: String(localized: "meditation_mode_title"),
                subtitle: String(localized: "meditation_mode_eyebrow"),
                tint: NeumorphicStyle.sage,
                action: { navigationPath.append(HomeView.HomeDestination.meditationMode) }
            )
        }
    }

    private func neumorphicShortcut(
        icon: MonoIcon.IconType,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    NeumorphicIconBadge(icon: icon, tint: tint, size: 38)

                    Spacer(minLength: 8)

                    MonoIcon(icon: .chevronRight, size: 12, color: tint, lineWidth: 1.7)
                        .frame(width: 30, height: 30)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NeumorphicStyle.titleFont(16, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(NeumorphicStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.08)))
        }
        .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.97))
    }

    private var signalBannerRail: some View {
        let banners = Array(viewModel.banners.prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: String(localized: "精选推荐"),
                subtitle: nil,
                icon: .sparkle
            )
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            GeometryReader { proxy in
                let horizontalInset = DeviceLayout.homeHorizontalPadding
                let bannerWidth = max(proxy.size.width - horizontalInset * 2, 1)

                TabView(selection: $bannerIndex) {
                    ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                        Button {
                            handleBannerTap(banner)
                        } label: {
                            NeumorphicSignalBannerCard(
                                banner: banner,
                                width: bannerWidth,
                                height: homeBannerHeight
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.985))
                        .padding(.horizontal, horizontalInset)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(height: homeBannerHeight)
            .task(id: bannerRotationTaskID(count: banners.count)) {
                guard isHomeActive, !reduceMotion, banners.count > 1 else { return }

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                    } catch {
                        return
                    }
                    guard isHomeActive,
                          !reduceMotion,
                          MainTabActivationGate.isSettled(.home),
                          banners.count > 1 else { return }
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                        bannerIndex = (bannerIndex + 1) % banners.count
                    }
                }
            }
            .onChange(of: banners.count) { _, _ in
                guard MainTabActivationGate.isSettled(.home) else { return }
                if bannerIndex >= banners.count {
                    bannerIndex = 0
                }
            }

            if banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(banners.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == bannerIndex ? NeumorphicStyle.accent : NeumorphicStyle.inkMuted.opacity(0.22))
                            .frame(width: index == bannerIndex ? 18 : 6, height: 6)
                            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: bannerIndex)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, -2)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String?, icon: MonoIcon.IconType) -> some View {
        HStack(spacing: 10) {
            NeumorphicIconBadge(icon: icon, tint: NeumorphicStyle.sage, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
        }
    }

    private var moduleDeck: some View {
        let playlists = mergedPlaylists

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeumorphicIconBadge(icon: selectedModule.icon, tint: NeumorphicStyle.accent, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "声场抽屉"))
                        .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)

                    Text(moduleSubtitle(playlistCount: playlists.count))
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }

                Spacer()

                if selectedModule == .playlists {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            deckExpanded.toggle()
                        }
                    } label: {
                        NeumorphicPill(
                            text: deckExpanded ? String(localized: "收起") : String(localized: "展开"),
                            tint: NeumorphicStyle.sage,
                            icon: deckExpanded ? .chevronLeft : .chevronRight,
                            selected: deckExpanded,
                            compact: true
                        )
                    }
                    .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.96))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
                }
            }

            moduleSelector

            Group {
                switch selectedModule {
                case .daily:
                    dailyDrawer
                case .newSongs:
                    newSongsDrawer
                case .playlists:
                    playlistsDrawer(playlists)
                case .discover:
                    discoverDrawer
                }
            }
            .id(selectedModule)
            .transition(.opacity.combined(with: .scale(scale: 0.992, anchor: .top)))
            .clipped()
        }
        .padding(16)
        .background(NeumorphicSurfaceBackground(cornerRadius: 28, elevated: true))
        .animation(.easeInOut(duration: 0.18), value: selectedModule)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: deckExpanded)
    }

    private var dailyRecommendationRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: String(localized: "daily_recommend"),
                subtitle: "\(viewModel.dailySongs.count) \(String(localized: "songs_unit"))",
                icon: .sparkle
            )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(viewModel.dailySongs.prefix(4).enumerated()), id: \.element.identityKey) { index, song in
                        Button {
                            PlayerManager.shared.play(song: song, in: viewModel.dailySongs)
                        } label: {
                            NeumorphicDailySongCard(song: song, index: index + 1, isActive: isHomeActive)
                        }
                        .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.975))
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()

            Button {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            } label: {
                drawerFooter(title: String(localized: "view_all"), icon: .chevronRight)
            }
            .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.985))
        }
    }

    private var moduleSelector: some View {
        HStack(spacing: 6) {
            ForEach(NeumorphicHomeModule.drawerModules) { module in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedModule = module
                        if module != .playlists {
                            deckExpanded = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        MonoIcon(
                            icon: module.icon,
                            size: 12,
                            color: selectedModule == module ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft,
                            lineWidth: 1.55
                        )
                        Text(module.title)
                            .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                            .foregroundStyle(selectedModule == module ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedModule == module {
                            NeumorphicSurfaceBackground(
                                cornerRadius: 16,
                                elevated: true,
                                tint: NeumorphicStyle.accent.opacity(0.1),
                                lightweight: true
                            )
                                .matchedGeometryEffect(id: "selected-module", in: moduleNamespace)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if selectedModule == module {
                            Capsule()
                                .fill(NeumorphicStyle.accent)
                                .frame(width: 18, height: 2.5)
                                .offset(y: -3)
                        }
                    }
                }
                .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.97))
            }
        }
        .padding(5)
        .background(NeumorphicSurfaceBackground(cornerRadius: 19, elevated: false, pressed: true, lightweight: true))
    }

    private var dailyDrawer: some View {
        VStack(spacing: 10) {
            let songs = Array(viewModel.dailySongs.prefix(deckExpanded ? 8 : 4))
            ForEach(Array(songs.enumerated()), id: \.element.identityKey) { index, song in
                NeumorphicHomeSongRow(
                    song: song,
                    index: index + 1,
                    isActive: isHomeActive,
                    action: { PlayerManager.shared.play(song: song, in: viewModel.dailySongs) }
                )
            }

            Button {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            } label: {
                drawerFooter(title: String(localized: "view_all"), icon: .chevronRight)
            }
            .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.985))
        }
    }

    private var newSongsDrawer: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(visibleQQNewSongs, id: \.identityKey) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs)
                        } label: {
                            NeumorphicNewSongCard(song: song)
                        }
                        .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.97))
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()

            Button {
                navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
            } label: {
                drawerFooter(title: String(localized: "view_all"), icon: .chevronRight)
            }
            .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.985))
        }
    }

    private func playlistsDrawer(_ playlists: [Playlist]) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: DeviceLayout.usesExpandedLayout ? 168 : 138), spacing: 12)],
                spacing: 12
            ) {
                ForEach(visibleMergedPlaylists(from: playlists), id: \.neumorphicHomePlaylistKey) { playlist in
                    Button {
                        navigationPath.append(HomeView.HomeDestination.playlist(playlist))
                    } label: {
                        NeumorphicMiniPlaylistCard(playlist: playlist)
                    }
                    .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.97))
                }
            }

            Button {
                openLibrarySquare()
            } label: {
                drawerFooter(title: String(localized: "common_view_more"), icon: .chevronRight)
            }
            .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.985))
        }
    }

    private var discoverDrawer: some View {
        VStack(spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 12)],
                spacing: 12
            ) {
                NeumorphicHomeDiscoveryTile(
                    title: String(localized: "MV"),
                    subtitle: String(localized: "VIDEO"),
                    icon: .mv,
                    tint: NeumorphicStyle.warm,
                    action: { navigationPath.append(HomeView.HomeDestination.mvDiscover) }
                )

                NeumorphicHomeDiscoveryTile(
                    title: String(localized: "热门歌手"),
                    subtitle: "ARTISTS",
                    icon: .profile,
                    tint: NeumorphicStyle.accent,
                    action: openLibraryArtists
                )

                NeumorphicHomeDiscoveryTile(
                    title: String(localized: "recommended_playlists"),
                    subtitle: String(localized: "PLAYLIST"),
                    icon: .musicNoteList,
                    tint: NeumorphicStyle.red,
                    action: openLibrarySquare
                )
            }
        }
    }

    private func drawerFooter(title: String, icon: MonoIcon.IconType) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.accent)

            MonoIcon(icon: icon, size: 11, color: NeumorphicStyle.accent, lineWidth: 1.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
    }

    private func moduleSubtitle(playlistCount: Int) -> String {
        switch selectedModule {
        case .daily:
            return "\(viewModel.dailySongs.count) \(String(localized: "songs_unit"))"
        case .newSongs:
            return "QCM · \(viewModel.qqNewSongs.count)"
        case .playlists:
            return "\(playlistCount) \(String(localized: "张"))"
        case .discover:
            return String(localized: "MV · ARTISTS · PLAYLIST")
        }
    }

    private var hitokotoText: String {
        viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var usesHitokotoFallback: Bool {
        !hitokotoEnabled || hitokotoText.isEmpty
    }

    private var hitokotoLabel: String {
        String(localized: "settings_hitokoto")
    }

    private func refreshHitokotoWithFeedback() {
        withAnimation(.linear(duration: 0.58)) {
            hitokotoRefreshRotation += 360
        }
        viewModel.refreshHitokoto(force: true)
    }

    private var mergedPlaylists: [Playlist] {
        var seen = Set<String>()
        return (viewModel.recommendPlaylists + viewModel.qqRecommendPlaylists).filter { playlist in
            let key = playlist.neumorphicHomePlaylistKey
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func visibleMergedPlaylists(from playlists: [Playlist]) -> [Playlist] {
        deckExpanded ? playlists : Array(playlists.prefix(4))
    }

    private var visibleQQNewSongs: [Song] {
        Array(viewModel.qqNewSongs.prefix(8))
    }

    private var homeBannerHeight: CGFloat {
        DeviceLayout.usesExpandedLayout ? 184 : 146
    }

    private func bannerRotationTaskID(count: Int) -> String {
        "\(isHomeActive)-\(reduceMotion)-\(count)"
    }

    private func openLibrarySquare() {
        UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
        NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
    }

    private func openLibraryArtists() {
        UserDefaults.standard.set(true, forKey: "pendingLibraryArtistsSwitch")
        NotificationCenter.default.post(name: .init("SwitchToLibraryArtists"), object: nil)
    }

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run { PlayerManager.shared.play(song: song, in: [song]) }
                    }
                } catch {
                    AppLogger.error("Banner 歌曲加载失败: \(error)")
                }
            }
        case 10:
            navigationPath.append(HomeView.HomeDestination.album(banner.targetId))
        case 1000:
            let playlist = Playlist(
                id: banner.targetId,
                name: banner.typeTitle ?? String(localized: "home_playlist"),
                coverImgUrl: banner.pic,
                picUrl: nil,
                trackCount: nil,
                playCount: nil,
                subscribedCount: nil,
                shareCount: nil,
                commentCount: nil,
                creator: nil,
                description: nil,
                tags: nil
            )
            navigationPath.append(HomeView.HomeDestination.bannerPlaylist(playlist, banner.pic))
        case 1004:
            navigationPath.append(HomeView.HomeDestination.mvDiscover)
        default:
            if let urlString = banner.url, let url = URL(string: urlString) {
                bannerWebURL = url
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: HomeView.HomeDestination) -> some View {
        switch destination {
        case .search:
            SearchView()
        case .dailyRecommend:
            DailyRecommendView()
        case let .playlist(playlist):
            PlaylistDetailView(playlist: playlist)
        case let .bannerPlaylist(playlist, bannerImage):
            PlaylistDetailView(playlist: playlist, bannerCoverURLString: bannerImage)
        case let .artist(id):
            ArtistDetailView(artistId: id)
        case let .album(id):
            AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil)
        case .mvDiscover:
            MVDiscoverView()
        case .newSongExpress:
            NewSongExpressView()
        case .qcmNewSongs:
            QCMNewSongsView()
        case .meditationMode:
            MeditationModeView()
        }
    }
}

// MARK: - 首页子组件

/// 精选入口：旋转封面拨盘。
private struct NeumorphicFeaturedDial: View {
    let dailySongs: [Song]
    let isActive: Bool

    @State private var currentSong = PlayerManager.shared.currentSong
    @State private var historyFirstSong = PlayerManager.shared.history.first
    @State private var isPlaying = PlayerManager.shared.isPlaying
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dialSize: CGFloat = DeviceLayout.usesExpandedLayout ? 148 : 124
        let grooveSize = dialSize * 0.84
        let coverSize = dialSize * 0.69

        ZStack {
            Circle()
                .fill(NeumorphicStyle.surfacePressed)
                .frame(width: dialSize, height: dialSize)
                .shadow(
                    color: NeumorphicStyle.lightShadow(colorScheme, intensity: colorScheme == .dark ? 0.58 : 0.88),
                    radius: 14,
                    x: -7,
                    y: -7
                )
                .shadow(
                    color: NeumorphicStyle.darkShadow(colorScheme, intensity: 0.5),
                    radius: 16,
                    x: 7,
                    y: 8
                )

            Circle()
                .stroke(NeumorphicStyle.separator.opacity(0.55), lineWidth: 1)
                .frame(width: grooveSize, height: grooveSize)

            if let song = featuredSong {
                NeumorphicHomeSpinningCover(
                    coverUrl: song.coverUrl,
                    isPlaying: isActive && currentSong?.id == song.id && isPlaying,
                    size: coverSize
                )
            } else {
                MonoIcon(icon: .musicNote, size: 30, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
            }

            Circle()
                .fill(NeumorphicStyle.surfaceRaised)
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(NeumorphicStyle.inkMuted.opacity(0.18)).frame(width: 7, height: 7))
        }
        .frame(maxWidth: .infinity, minHeight: dialSize)
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
            currentSong = PlayerManager.shared.currentSong
            historyFirstSong = PlayerManager.shared.history.first
            isPlaying = PlayerManager.shared.isPlaying
        }
        .onReceive(PlayerManager.shared.$currentSong) { song in
            guard MainTabActivationGate.isSettled(.home) else { return }
            currentSong = song
        }
        .onReceive(PlayerManager.shared.$history.map { $0.first }.removeDuplicates { $0?.id == $1?.id }) { song in
            guard MainTabActivationGate.isSettled(.home) else { return }
            historyFirstSong = song
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            guard MainTabActivationGate.isSettled(.home) else { return }
            self.isPlaying = isPlaying
        }
    }

    private var featuredSong: Song? {
        currentSong ?? historyFirstSong ?? dailySongs.first
    }
}

private struct NeumorphicFeaturedSongButton: View {
    let dailySongs: [Song]
    let isActive: Bool

    @State private var currentSong = PlayerManager.shared.currentSong
    @State private var historyFirstSong = PlayerManager.shared.history.first
    @State private var isPlaying = PlayerManager.shared.isPlaying

    var body: some View {
        Group {
            if let song = featuredSong {
                Button {
                    playFeatured(song)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentSongCaption(for: song))
                                .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                                .foregroundStyle(NeumorphicStyle.inkMuted)
                                .tracking(1.0)

                            Text(song.name)
                                .font(NeumorphicStyle.labelFont(16, weight: .semibold))
                                .foregroundStyle(NeumorphicStyle.ink)
                                .lineLimit(1)

                            Text(song.artistName)
                                .font(NeumorphicStyle.labelFont(12, weight: .regular))
                                .foregroundStyle(NeumorphicStyle.inkSoft)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        ZStack {
                            Circle()
                                .fill(NeumorphicStyle.accent.opacity(0.18))
                                .frame(width: 42, height: 42)

                            if currentSong?.id == song.id && isPlaying {
                                PlayingVisualizerView(isAnimating: isActive, color: NeumorphicStyle.accent)
                                    .frame(width: 20, height: 16)
                            } else {
                                MonoIcon(icon: .play, size: 14, color: NeumorphicStyle.accent, lineWidth: 1.8)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true))
                }
                .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.97))
            }
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
            currentSong = PlayerManager.shared.currentSong
            historyFirstSong = PlayerManager.shared.history.first
            isPlaying = PlayerManager.shared.isPlaying
        }
        .onReceive(PlayerManager.shared.$currentSong) { song in
            guard MainTabActivationGate.isSettled(.home) else { return }
            currentSong = song
        }
        .onReceive(PlayerManager.shared.$history.map { $0.first }.removeDuplicates { $0?.id == $1?.id }) { song in
            guard MainTabActivationGate.isSettled(.home) else { return }
            historyFirstSong = song
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            guard MainTabActivationGate.isSettled(.home) else { return }
            self.isPlaying = isPlaying
        }
    }

    private var featuredSong: Song? {
        currentSong ?? historyFirstSong ?? dailySongs.first
    }

    private func currentSongCaption(for song: Song) -> String {
        if currentSong?.id == song.id {
            return String(localized: "正在播放")
        }
        if currentSong == nil, historyFirstSong?.id == song.id {
            return String(localized: "上次播放")
        }
        return String(localized: "今日首选")
    }

    private func playFeatured(_ song: Song) {
        let player = PlayerManager.shared
        if currentSong?.id == song.id {
            player.togglePlayPause()
        } else if dailySongs.contains(where: { $0.id == song.id }) {
            player.play(song: song, in: dailySongs)
        } else {
            player.play(song: song, in: [song])
        }
    }
}

private struct NeumorphicHomeSpinningCover: View {
    let coverUrl: URL?
    let isPlaying: Bool
    let size: CGFloat

    var body: some View {
        CachedAsyncImage(url: coverUrl, width: size, height: size) {
            Circle().fill(NeumorphicStyle.surface)
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: size, height: size)
        .clipShape(Circle())
        .modifier(NeumorphicCoverRotation(isPlaying: isPlaying))
    }
}

private struct NeumorphicCoverRotation: ViewModifier {
    let isPlaying: Bool

    @State private var storedAngle: Double = 0
    @State private var anchorDate: Date?
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let degreesPerSecond: Double = 10

    func body(content: Content) -> some View {
        TimelineView(
            AppFrameRate.animationTimeline(
                maximumFramesPerSecond: 30,
                paused: !rotationActive
            )
        ) { timeline in
            let displayedAngle = currentAngle(at: timeline.date)

            content
                .rotationEffect(.degrees(displayedAngle))
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .onAppear {
            isVisible = true
            synchronizeRotation(isActive: rotationActive)
        }
        .onDisappear {
            isVisible = false
            synchronizeRotation(isActive: false)
        }
        .onChange(of: rotationActive) { _, isActive in
            synchronizeRotation(isActive: isActive)
        }
    }

    private var rotationActive: Bool {
        isPlaying && isVisible && scenePhase == .active && !reduceMotion
    }

    private func currentAngle(at date: Date) -> Double {
        guard let anchorDate else {
            return storedAngle
        }
        let elapsed = max(0, date.timeIntervalSince(anchorDate))
        return storedAngle + elapsed * degreesPerSecond
    }

    private func synchronizeRotation(isActive: Bool) {
        let now = Date()
        if isActive {
            guard anchorDate == nil else { return }
            anchorDate = now
        } else if anchorDate != nil {
            storedAngle = currentAngle(at: now).truncatingRemainder(dividingBy: 360)
            anchorDate = nil
        }
    }
}

private struct NeumorphicSignalBannerCard: View {
    let banner: Banner
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HomeBannerArtwork(url: banner.imageUrl, cornerRadius: 28) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonoIcon(icon: .radio, size: 28, color: NeumorphicStyle.inkMuted.opacity(0.45)))
            }
            .frame(width: width, height: height)

            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            HStack(spacing: 8) {
                Text(banner.typeTitle ?? String(localized: "推荐"))
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                MonoIcon(icon: .chevronRight, size: 10, color: .white.opacity(0.88), lineWidth: 1.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.22), in: Capsule())
            .padding(12)
        }
        .frame(width: width, height: height)
        .background(NeumorphicSurfaceBackground(cornerRadius: 28, elevated: true))
    }
}

private struct NeumorphicDailySongCard: View {
    let song: Song
    let index: Int
    let isActive: Bool

    @State private var currentSongID = PlayerManager.shared.currentSong?.id
    @State private var playerIsPlaying = PlayerManager.shared.isPlaying

    var body: some View {
        let width: CGFloat = DeviceLayout.usesExpandedLayout ? 174 : 152
        let artworkSize = width - 20

        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: song.coverUrl, width: artworkSize, height: artworkSize) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(MonoIcon(icon: .musicNote, size: 24, color: NeumorphicStyle.inkMuted.opacity(0.5)))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                }

                Text(String(format: "%02d", index))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.28), in: Capsule())
                    .padding(9)

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(NeumorphicStyle.surface.opacity(0.62))

                    if isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                            .frame(width: 18, height: 14)
                    } else {
                        MonoIcon(icon: .play, size: 11, color: NeumorphicStyle.ink, lineWidth: 1.7)
                    }
                }
                .frame(width: 34, height: 34)
                .padding(9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(width: artworkSize, height: artworkSize)

            Text(song.name)
                .font(NeumorphicStyle.labelFont(14, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(1)

            Text(song.artistName)
                .font(NeumorphicStyle.labelFont(11))
                .foregroundStyle(NeumorphicStyle.inkSoft)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: width, alignment: .leading)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 26,
                elevated: true,
                tint: isPlaying ? NeumorphicStyle.accent.opacity(0.11) : nil
            )
        )
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
            currentSongID = PlayerManager.shared.currentSong?.id
            playerIsPlaying = PlayerManager.shared.isPlaying
        }
        .onReceive(PlayerManager.shared.$currentSong.map { $0?.id }.removeDuplicates()) { songID in
            guard MainTabActivationGate.isSettled(.home) else { return }
            currentSongID = songID
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            guard MainTabActivationGate.isSettled(.home) else { return }
            playerIsPlaying = isPlaying
        }
    }

    private var isPlaying: Bool {
        isActive && currentSongID == song.id && playerIsPlaying
    }
}

private struct NeumorphicHomeSongRow: View {
    let song: Song
    let index: Int
    let isActive: Bool
    let action: () -> Void

    @State private var currentSongID = PlayerManager.shared.currentSong?.id
    @State private var playerIsPlaying = PlayerManager.shared.isPlaying

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .frame(width: 25)

                CachedAsyncImage(url: song.coverUrl, width: 48, height: 48) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(NeumorphicStyle.labelFont(14, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(NeumorphicStyle.labelFont(11, weight: .regular))
                        .foregroundStyle(NeumorphicStyle.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isPlaying {
                    PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                        .frame(width: 22, height: 18)
                } else {
                    MonoIcon(icon: .play, size: 12, color: NeumorphicStyle.inkMuted, lineWidth: 1.7)
                        .frame(width: 32, height: 32)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true))
                }
            }
            .padding(10)
            .background(NeumorphicSurfaceBackground(cornerRadius: 19, elevated: false, pressed: !isPlaying, tint: isPlaying ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface, lightweight: true))
        }
        .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.985))
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
            currentSongID = PlayerManager.shared.currentSong?.id
            playerIsPlaying = PlayerManager.shared.isPlaying
        }
        .onReceive(PlayerManager.shared.$currentSong.map { $0?.id }.removeDuplicates()) { songID in
            guard MainTabActivationGate.isSettled(.home) else { return }
            currentSongID = songID
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            guard MainTabActivationGate.isSettled(.home) else { return }
            playerIsPlaying = isPlaying
        }
    }

    private var isPlaying: Bool {
        isActive && currentSongID == song.id && playerIsPlaying
    }
}

private struct NeumorphicNewSongCard: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CachedAsyncImage(url: song.coverUrl, width: 98, height: 98) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 98, height: 98)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(song.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(1)

            Text(song.artistName)
                .font(NeumorphicStyle.labelFont(11, weight: .regular))
                .foregroundStyle(NeumorphicStyle.inkSoft)
                .lineLimit(1)
        }
        .frame(width: 118, alignment: .leading)
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true))
    }
}

private struct NeumorphicMiniPlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: playlist.coverUrl, width: 220, height: 180) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(MonoIcon(icon: .musicNoteList, size: 24, color: NeumorphicStyle.inkMuted.opacity(0.5)))
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: DeviceLayout.usesExpandedLayout ? 146 : 116)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                LinearGradient(
                    colors: [.clear, .black.opacity(0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text(playlist.source == .qqmusic ? "QCM" : "NCM")
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.26), in: Capsule())
                    .padding(9)
            }

            Text(playlist.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
    }
}

private struct NeumorphicHomeDiscoveryTile: View {
    let title: String
    let subtitle: String
    let icon: MonoIcon.IconType
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                NeumorphicIconBadge(icon: icon, tint: tint, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NeumorphicStyle.labelFont(14, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .tracking(0.8)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .frame(minHeight: 112)
            .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, tint: tint.opacity(0.1)))
        }
        .buttonStyle(NeumorphicTactileButtonStyle(scale: 0.96))
    }
}

private extension Playlist {
    var neumorphicHomePlaylistKey: String {
        "\(source?.rawValue ?? "netease")-\(id)"
    }
}
