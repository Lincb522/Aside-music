import Combine
import SwiftUI

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

    var icon: MonologueIcon.IconType {
        switch self {
        case .daily: return .sparkle
        case .newSongs: return .musicNote
        case .playlists: return .musicNoteList
        case .discover: return .layers
        }
    }
}

struct NeumorphicHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true
    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var appeared = false
    @State private var hitokotoRefreshing = false
    @State private var selectedModule: NeumorphicHomeModule = .playlists
    @State private var deckExpanded = false
    @State private var bannerIndex = 0
    @Namespace private var moduleNamespace
    private let bannerTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = settings.globalThemeRevision

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
            .onAppear {
                if viewModel.dailySongs.isEmpty { viewModel.fetchData() }
                if hitokotoEnabled,
                   viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
                {
                    viewModel.refreshHitokoto()
                }
                if !appeared {
                    withAnimation(.spring(response: 0.58, dampingFraction: 0.86).delay(0.06)) {
                        appeared = true
                    }
                }
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { destination in
                destinationView(for: destination)
            }
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(item: $bannerWebURL) { url in
                MonologueWebView(url: url, title: nil)
            }
        }
    }

    private var scrollBody: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                topConsole
                    .neumorphicStagger(appeared, order: 0)

                tactileStage
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 1)

                if !viewModel.banners.isEmpty {
                    signalBannerRail
                        .neumorphicStagger(appeared, order: 2)
                }

                dailyRecommendationRail
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 3)

                ncmNewSongExpressShortcut
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 4)

                moduleDeck
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .neumorphicStagger(appeared, order: 5)

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 8)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable {
            viewModel.fetchData()
            if hitokotoEnabled {
                viewModel.refreshHitokoto(force: true)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            NeumorphicIconBadge(icon: .layers, tint: NeumorphicStyle.accent, size: 58)

            Text("LOADING")
                .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.inkMuted)
                .tracking(1.4)
        }
    }

    private var topConsole: some View {
        HStack(spacing: 12) {
            Button {
                NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
            } label: {
                avatarView
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: LocalizedStringResource(stringLiteral: MonologueTimeGreeting.localizedKey)))
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .tracking(0.8)

                Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(NeumorphicStyle.titleFont(24, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            NeumorphicActionButton(size: 42, action: { showPersonalFM = true }) {
                MonologueIcon(icon: .radio, size: 17, color: NeumorphicStyle.sage, lineWidth: 1.6)
            }

            NeumorphicActionButton(size: 42, action: { navigationPath.append(HomeView.HomeDestination.search) }) {
                MonologueIcon(icon: .magnifyingGlass, size: 17, color: NeumorphicStyle.accent, lineWidth: 1.6)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 46
        if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
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
                .overlay(MonologueIcon(icon: .profile, size: 18, color: NeumorphicStyle.inkMuted, lineWidth: 1.6))
        }
    }

    private var tactileStage: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(NeumorphicStyle.accent)
                            .frame(width: 7, height: 7)

                        Text(hitokotoLabel)
                            .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.accent)
                            .tracking(1.0)
                    }

                    Text(hitokotoText)
                        .font(NeumorphicStyle.bodyFont(18, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if hitokotoEnabled {
                        HStack(spacing: 9) {
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                                    hitokotoRefreshing = true
                                }
                                viewModel.refreshHitokoto(force: true)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                        hitokotoRefreshing = false
                                    }
                                }
                            } label: {
                                NeumorphicPill(
                                    text: String(localized: "刷新"),
                                    tint: NeumorphicStyle.warm,
                                    icon: .refresh,
                                    selected: false
                                )
                                .rotationEffect(.degrees(hitokotoRefreshing ? 2 : 0))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                NeumorphicFeaturedDial(dailySongs: viewModel.dailySongs)
                    .frame(width: DeviceLayout.isPad ? 168 : 132)
            }

            NeumorphicFeaturedSongButton(dailySongs: viewModel.dailySongs)
        }
        .padding(18)
        .background(NeumorphicSurfaceBackground(cornerRadius: 30, elevated: true))
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

            TabView(selection: $bannerIndex) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    GeometryReader { proxy in
                        Button {
                            handleBannerTap(banner)
                        } label: {
                            NeumorphicSignalBannerCard(
                                banner: banner,
                                width: max(proxy.size.width, 260)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                    }
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 164)
            .onReceive(bannerTimer) { _ in
                guard banners.count > 1 else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                    bannerIndex = (bannerIndex + 1) % banners.count
                }
            }
            .onChange(of: viewModel.banners.count) { _, _ in
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

    private func sectionHeader(title: String, subtitle: String?, icon: MonologueIcon.IconType) -> some View {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeumorphicIconBadge(icon: selectedModule.icon, tint: NeumorphicStyle.accent, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "声场抽屉"))
                        .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)

                    Text(moduleSubtitle)
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
                    .buttonStyle(.plain)
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
                    playlistsDrawer
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
                title: String(localized: "每日推荐"),
                subtitle: "\(viewModel.dailySongs.count) \(String(localized: "首"))",
                icon: .sparkle
            )

            VStack(spacing: 9) {
                ForEach(Array(viewModel.dailySongs.prefix(4).enumerated()), id: \.element.id) { index, song in
                    NeumorphicHomeSongRow(
                        song: song,
                        index: index + 1,
                        action: { PlayerManager.shared.play(song: song, in: viewModel.dailySongs) }
                    )
                }

                Button {
                    navigationPath.append(HomeView.HomeDestination.dailyRecommend)
                } label: {
                    drawerFooter(title: String(localized: "查看全部"), icon: .chevronRight)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(NeumorphicSurfaceBackground(cornerRadius: 28, elevated: true))
    }

    private var ncmNewSongExpressShortcut: some View {
        Button {
            navigationPath.append(HomeView.HomeDestination.newSongExpress)
        } label: {
            HStack(spacing: 13) {
                NeumorphicIconBadge(icon: .musicNote, tint: MusicSource.netease.themedBadgeColor, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("NCM · \(String(localized: "新歌速递"))")
                        .font(NeumorphicStyle.titleFont(17, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)

                    Text("NEW RELEASES")
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                }

                Spacer(minLength: 8)

                MonologueIcon(icon: .chevronRight, size: 13, color: MusicSource.netease.themedBadgeColor, lineWidth: 1.7)
                    .frame(width: 34, height: 34)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true))
            }
            .padding(14)
            .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: MusicSource.netease.themedBadgeColor.opacity(0.08)))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
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
                        MonologueIcon(
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
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(NeumorphicStyle.surfaceRaised)
                                .matchedGeometryEffect(id: "selected-module", in: moduleNamespace)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 4, y: 5)
                                .shadow(color: Color.white.opacity(0.38), radius: 8, x: -4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(NeumorphicSurfaceBackground(cornerRadius: 19, elevated: false, pressed: true, lightweight: true))
    }

    private var dailyDrawer: some View {
        VStack(spacing: 10) {
            let songs = Array(viewModel.dailySongs.prefix(deckExpanded ? 8 : 4))
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                NeumorphicHomeSongRow(
                    song: song,
                    index: index + 1,
                    action: { PlayerManager.shared.play(song: song, in: viewModel.dailySongs) }
                )
            }

            Button {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            } label: {
                drawerFooter(title: String(localized: "查看全部"), icon: .chevronRight)
            }
            .buttonStyle(.plain)
        }
    }

    private var newSongsDrawer: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(visibleQQNewSongs) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs)
                        } label: {
                            NeumorphicNewSongCard(song: song)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()

            Button {
                navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
            } label: {
                drawerFooter(title: String(localized: "查看全部"), icon: .chevronRight)
            }
            .buttonStyle(.plain)
        }
    }

    private var playlistsDrawer: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(visibleMergedPlaylists, id: \.neumorphicHomePlaylistKey) { playlist in
                    Button {
                        navigationPath.append(HomeView.HomeDestination.playlist(playlist))
                    } label: {
                        NeumorphicMiniPlaylistCard(playlist: playlist)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                }
            }

            Button {
                openLibrarySquare()
            } label: {
                drawerFooter(title: String(localized: "查看更多"), icon: .chevronRight)
            }
            .buttonStyle(.plain)
        }
    }

    private var discoverDrawer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
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
                    title: String(localized: "推荐歌单"),
                    subtitle: String(localized: "PLAYLIST"),
                    icon: .musicNoteList,
                    tint: NeumorphicStyle.red,
                    action: openLibrarySquare
                )
            }
        }
    }

    private func drawerFooter(title: String, icon: MonologueIcon.IconType) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.accent)

            MonologueIcon(icon: icon, size: 11, color: NeumorphicStyle.accent, lineWidth: 1.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
    }

    private var moduleSubtitle: String {
        switch selectedModule {
        case .daily:
            return "\(viewModel.dailySongs.count) \(String(localized: "首"))"
        case .newSongs:
            return "QCM · \(viewModel.qqNewSongs.count)"
        case .playlists:
            return "\(mergedPlaylists.count) \(String(localized: "张"))"
        case .discover:
            return String(localized: "MV · ARTISTS · PLAYLIST")
        }
    }

    private var hitokotoText: String {
        guard hitokotoEnabled else { return "Monologue" }

        let trimmed = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Monologue" : trimmed
    }

    private var hitokotoLabel: String {
        hitokotoEnabled ? String(localized: "每日一言") : "Monologue"
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

    private var visibleMergedPlaylists: [Playlist] {
        deckExpanded ? mergedPlaylists : Array(mergedPlaylists.prefix(4))
    }

    private var visibleQQNewSongs: [Song] {
        Array(viewModel.qqNewSongs.prefix(8))
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
        }
    }
}

private struct NeumorphicFeaturedDial: View {
    let dailySongs: [Song]

    @State private var currentSong = PlayerManager.shared.currentSong
    @State private var historyFirstSong = PlayerManager.shared.history.first
    @State private var isPlaying = PlayerManager.shared.isPlaying

    var body: some View {
        ZStack {
            Circle()
                .fill(NeumorphicStyle.surfacePressed)
                .frame(width: 124, height: 124)
                .shadow(color: Color.black.opacity(0.16), radius: 16, x: 7, y: 8)
                .shadow(color: Color.white.opacity(0.34), radius: 14, x: -7, y: -7)

            Circle()
                .stroke(NeumorphicStyle.separator.opacity(0.55), lineWidth: 1)
                .frame(width: 104, height: 104)

            if let song = featuredSong {
                NeumorphicHomeSpinningCover(
                    coverUrl: song.coverUrl,
                    isPlaying: currentSong?.id == song.id && isPlaying
                )
            } else {
                MonologueIcon(icon: .musicNote, size: 30, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
            }

            Circle()
                .fill(NeumorphicStyle.surfaceRaised)
                .frame(width: 20, height: 20)
                .overlay(Circle().fill(NeumorphicStyle.inkMuted.opacity(0.18)).frame(width: 7, height: 7))
        }
        .frame(maxWidth: .infinity)
        .onReceive(PlayerManager.shared.$currentSong) { song in
            currentSong = song
        }
        .onReceive(PlayerManager.shared.$history.map { $0.first }.removeDuplicates { $0?.id == $1?.id }) { song in
            historyFirstSong = song
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            self.isPlaying = isPlaying
        }
    }

    private var featuredSong: Song? {
        currentSong ?? historyFirstSong ?? dailySongs.first
    }
}

private struct NeumorphicFeaturedSongButton: View {
    let dailySongs: [Song]

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
                                PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                                    .frame(width: 20, height: 16)
                            } else {
                                MonologueIcon(icon: .play, size: 14, color: NeumorphicStyle.accent, lineWidth: 1.8)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            }
        }
        .onReceive(PlayerManager.shared.$currentSong) { song in
            currentSong = song
        }
        .onReceive(PlayerManager.shared.$history.map { $0.first }.removeDuplicates { $0?.id == $1?.id }) { song in
            historyFirstSong = song
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
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

    @State private var storedAngle: Double = 0
    @State private var anchorDate: Date?

    private let degreesPerSecond: Double = 10

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(paused: !isPlaying)) { timeline in
            let displayedAngle = currentAngle(at: timeline.date)

            CachedAsyncImage(url: coverUrl, width: 86, height: 86) {
                Circle().fill(NeumorphicStyle.surface)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 86, height: 86)
            .clipShape(Circle())
            .rotationEffect(.degrees(displayedAngle))
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .onAppear {
            if isPlaying && anchorDate == nil {
                anchorDate = Date()
            }
        }
        .onChange(of: isPlaying) { _, isPlaying in
            let now = Date()
            if isPlaying {
                anchorDate = now
            } else {
                storedAngle = currentAngle(at: now).truncatingRemainder(dividingBy: 360)
                anchorDate = nil
            }
        }
    }

    private func currentAngle(at date: Date) -> Double {
        guard isPlaying, let anchorDate else {
            return storedAngle
        }
        let elapsed = max(0, date.timeIntervalSince(anchorDate))
        return storedAngle + elapsed * degreesPerSecond
    }
}

private struct NeumorphicSignalBannerCard: View {
    let banner: Banner
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: banner.imageUrl, width: width, height: 142) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .radio, size: 28, color: NeumorphicStyle.inkMuted.opacity(0.45)))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: 142)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            HStack(spacing: 8) {
                Text(banner.typeTitle ?? String(localized: "推荐"))
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                MonologueIcon(icon: .chevronRight, size: 10, color: .white.opacity(0.88), lineWidth: 1.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.22), in: Capsule())
            .padding(12)
        }
        .frame(width: width, height: 142)
        .background(NeumorphicSurfaceBackground(cornerRadius: 28, elevated: true))
    }
}

private struct NeumorphicHomeSongRow: View {
    let song: Song
    let index: Int
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
                    MonologueIcon(icon: .play, size: 12, color: NeumorphicStyle.inkMuted, lineWidth: 1.7)
                        .frame(width: 32, height: 32)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true))
                }
            }
            .padding(10)
            .background(NeumorphicSurfaceBackground(cornerRadius: 19, elevated: false, pressed: !isPlaying, tint: isPlaying ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface, lightweight: true))
        }
        .buttonStyle(.plain)
        .onReceive(PlayerManager.shared.$currentSong.map { $0?.id }.removeDuplicates()) { songID in
            currentSongID = songID
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            playerIsPlaying = isPlaying
        }
    }

    private var isPlaying: Bool {
        currentSongID == song.id && playerIsPlaying
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
        HStack(spacing: 10) {
            CachedAsyncImage(url: playlist.coverUrl, width: 48, height: 48) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)

                Text(playlist.source == .qqmusic ? "QCM" : "NCM")
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : MusicSource.netease.themedBadgeColor)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minHeight: 74)
        .background(NeumorphicSurfaceBackground(cornerRadius: 19, elevated: false, pressed: true, lightweight: true))
    }
}

private struct NeumorphicHomeDiscoveryTile: View {
    let title: String
    let subtitle: String
    let icon: MonologueIcon.IconType
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
            .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, tint: tint.opacity(0.1)))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }
}

private extension Playlist {
    var neumorphicHomePlaylistKey: String {
        "\(source?.rawValue ?? "netease")-\(id)"
    }
}
