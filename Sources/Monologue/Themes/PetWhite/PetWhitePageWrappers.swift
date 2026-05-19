import SwiftUI

private enum PetWhitePageIdentity {
    case home
    case podcast
    case search
    case library
    case profile
    case localHome
    case localMusic
    case localLibrary
    case localProfile

    var tag: String {
        switch self {
        case .home: return "HOME"
        case .podcast: return "POD"
        case .search: return "SNIFF"
        case .library: return "BOX"
        case .profile: return "ME"
        case .localHome: return "LOCAL"
        case .localMusic: return "MUSIC"
        case .localLibrary: return "FILES"
        case .localProfile: return "SET"
        }
    }

    var icon: MonologueIcon.IconType {
        switch self {
        case .home, .localHome: return .homeFilled
        case .podcast: return .podcastFilled
        case .search: return .magnifyingGlass
        case .library, .localLibrary: return .library
        case .profile, .localProfile: return .profileFilled
        case .localMusic: return .musicNoteList
        }
    }

    var mascot: PetWhiteMascotMark.Kind {
        switch self {
        case .podcast, .localMusic:
            return .dog
        case .search, .profile, .localProfile:
            return .cat
        default:
            return .pair
        }
    }

    var tint: Color {
        switch self {
        case .home, .localHome: return PetWhiteStyle.dogOrange
        case .podcast, .localMusic: return PetWhiteStyle.mint
        case .search: return PetWhiteStyle.sky
        case .library, .localLibrary: return PetWhiteStyle.butter
        case .profile, .localProfile: return PetWhiteStyle.blush.opacity(0.78)
        }
    }
}

private struct PetWhiteThemeRoot<Content: View>: View {
    let page: PetWhitePageIdentity
    let content: Content
    @ObservedObject private var settings = SettingsManager.shared

    init(page: PetWhitePageIdentity, @ViewBuilder content: () -> Content) {
        self.page = page
        self.content = content()
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        content
            .tint(PetWhiteStyle.accent)
            .themeRenderSceneLayer()
        .background(PetWhiteRootBackdrop())
    }
}

private struct PetWhitePageChrome: View {
    let page: PetWhitePageIdentity

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PetWhiteSideRail(page: page)
                    .padding(.top, max(proxy.safeAreaInsets.top + 76, 92))
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                PetWhiteCornerTag(page: page)
                    .padding(.top, max(proxy.safeAreaInsets.top + 12, 22))
                    .padding(.trailing, DeviceLayout.isPad ? 30 : 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PetWhiteSideRail: View {
    let page: PetWhitePageIdentity

    var body: some View {
        VStack(spacing: 12) {
            PetWhiteMascotMark(kind: page.mascot, size: 30)

            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    PetWhitePawPrint(
                        size: index.isMultiple(of: 2) ? 18 : 14,
                        tint: index.isMultiple(of: 2) ? page.tint.opacity(0.62) : PetWhiteStyle.stroke.opacity(0.12)
                    )
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -12 : 12))
                }
            }
        }
        .opacity(0.92)
    }
}

private struct PetWhiteCornerTag: View {
    let page: PetWhitePageIdentity

    var body: some View {
        HStack(spacing: 8) {
            PetWhitePackIcon(icon: page.icon, size: 18, visualScale: 1.08)

            Text(page.tag)
                .font(PetWhiteStyle.labelFont(10, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .tracking(1.0)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(page.tint)
                .overlay(Capsule(style: .continuous).stroke(PetWhiteStyle.separator, lineWidth: 1))
        )
    }
}

struct PetWhiteHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: PetWhiteWebDestination?
    @State private var appeared = false
    @State private var contentRevision = 0

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)
                    .ignoresSafeArea()

                scrollBody
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                hydratePetWhiteHome(reason: "pet white home appear")
                revealHomeContent()
            }
            .onChange(of: settings.globalThemeRevision) { _, _ in
                appeared = false
                hydratePetWhiteHome(reason: "pet white theme revision")
                revealHomeContent()
            }
            .onReceive(viewModel.objectWillChange.receive(on: DispatchQueue.main)) { _ in
                contentRevision &+= 1
                revealHomeContent()
            }
            .navigationDestination(for: HomeView.HomeDestination.self, destination: destinationView)
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(item: $bannerWebURL) { url in
                MonologueWebView(url: url.url, title: nil)
            }
        }
        .themeRenderSceneLayer()
    }

    private var isInitialHomeLoading: Bool {
        viewModel.isLoading
            && isHomeDataEmpty
    }

    private var isHomeDataEmpty: Bool {
        viewModel.dailySongs.isEmpty
            && viewModel.banners.isEmpty
            && viewModel.recommendPlaylists.isEmpty
            && viewModel.qqRecommendPlaylists.isEmpty
            && viewModel.qqNewSongs.isEmpty
    }

    private var shouldHydrateHomeData: Bool {
        viewModel.dailySongs.isEmpty
            || viewModel.banners.isEmpty
            || viewModel.recommendPlaylists.isEmpty
            || viewModel.qqRecommendPlaylists.isEmpty
            || viewModel.qqNewSongs.isEmpty
    }

    private func hydratePetWhiteHome(reason: String) {
        viewModel.ensureHomeDataLoaded(reason: reason)

        if shouldHydrateHomeData {
            viewModel.fetchData(forceDaily: viewModel.dailySongs.isEmpty)
        }
    }

    private func revealHomeContent() {
        guard !appeared else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.04)) {
            appeared = true
        }
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroPanel
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 0)

                quickActionBoard
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 1)

                if !viewModel.banners.isEmpty {
                    PetWhiteBannerCarousel(
                        banners: viewModel.banners,
                        onTap: handleBannerTap
                    )
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 2)
                }

                if isInitialHomeLoading {
                    PetWhiteLoadingView()
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .petWhiteAppear(appeared, order: 3)
                }

                if !viewModel.dailySongs.isEmpty {
                    dailyTreats
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .petWhiteAppear(appeared, order: 4)
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    PetWhitePlaylistShelf(
                        title: String(localized: "推荐歌单"),
                        detail: String(localized: "based_on_taste"),
                        playlists: viewModel.recommendPlaylists,
                        tint: PetWhiteStyle.butter,
                        icon: .library,
                        onViewAll: openLibrarySquare,
                        onTap: { playlist in navigationPath.append(HomeView.HomeDestination.playlist(playlist)) }
                    )
                    .petWhiteAppear(appeared, order: 5)
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    PetWhitePlaylistShelf(
                        title: "QCM",
                        detail: String(localized: "更多发现"),
                        playlists: viewModel.qqRecommendPlaylists,
                        tint: PetWhiteStyle.sky,
                        icon: .podcast,
                        onViewAll: openLibrarySquare,
                        onTap: { playlist in navigationPath.append(HomeView.HomeDestination.playlist(playlist)) }
                    )
                    .petWhiteAppear(appeared, order: 6)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    PetWhiteNewSongsBoard(
                        songs: viewModel.qqNewSongs,
                        onViewAll: { navigationPath.append(HomeView.HomeDestination.qcmNewSongs) },
                        onPlay: { song in PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs) }
                    )
                    .petWhiteAppear(appeared, order: 7)
                }

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 14)
            .frame(maxWidth: .infinity, alignment: .top)
            .id(contentRevision)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable { viewModel.fetchData() }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                PetWhitePetPetIcon(size: 88)

                VStack(alignment: .leading, spacing: 7) {
                    PetWhitePill(text: "PET RADIO", tint: PetWhiteStyle.mint)

                    Text(String(localized: LocalizedStringResource(stringLiteral: MonologueTimeGreeting.localizedKey)))
                        .font(PetWhiteStyle.labelFont(12, weight: .black))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)

                    Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(PetWhiteStyle.titleFont(30, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }

                Spacer(minLength: 8)

                Button {
                    NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
                } label: {
                    avatarView
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }

            if SettingsManager.shared.hitokotoEnabled,
               let hitokoto = viewModel.hitokoto,
               !hitokoto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    PetWhiteProfileHeadIcon(filled: false, size: 24)

                    Text(hitokoto)
                        .font(PetWhiteStyle.bodyFont(14, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Button {
                        viewModel.refreshHitokoto(force: true)
                    } label: {
                        PetWhitePackIcon(icon: .refresh, size: 21, visualScale: 1.08)
                            .frame(width: 34, height: 34)
                            .background(PetWhiteStyle.butter, in: Circle())
                            .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.4))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(PetWhiteStyle.surfacePressed)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                        )
                )
            }
        }
        .padding(18)
        .background(PetWhiteSurfaceBackground(cornerRadius: 26, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 48
        if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) {
                PetWhiteMascotMark(kind: .cat, size: size)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 2))
        } else {
            PetWhiteMascotMark(kind: .cat, size: size)
        }
    }

    private var quickActionBoard: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            PetWhiteQuickAction(title: "FM", subtitle: String(localized: "私人漫游"), icon: .fm, tint: PetWhiteStyle.dogOrange) {
                showPersonalFM = true
            }
            PetWhiteQuickAction(title: String(localized: "搜索"), subtitle: "SNIFF", icon: .magnifyingGlass, tint: PetWhiteStyle.sky) {
                navigationPath.append(HomeView.HomeDestination.search)
            }
            PetWhiteQuickAction(title: String(localized: "new_song_express"), subtitle: "EXPRESS", icon: .musicNote, tint: PetWhiteStyle.mint) {
                navigationPath.append(HomeView.HomeDestination.newSongExpress)
            }
            PetWhiteQuickAction(title: "MV", subtitle: "VIDEO", icon: .mv, tint: PetWhiteStyle.butter) {
                navigationPath.append(HomeView.HomeDestination.mvDiscover)
            }
        }
    }

    private var dailyTreats: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: String(localized: "每日推荐"),
                detail: String(localized: "今天的第一口音乐"),
                icon: .musicNote,
                tint: PetWhiteStyle.mint,
                action: { navigationPath.append(HomeView.HomeDestination.dailyRecommend) }
            )

            VStack(spacing: 9) {
                ForEach(Array(viewModel.dailySongs.prefix(4).enumerated()), id: \.element.id) { index, song in
                    Button {
                        PlayerManager.shared.play(song: song, in: viewModel.dailySongs)
                    } label: {
                        PetWhiteSongTreatRow(index: index + 1, song: song)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                }
            }
            .padding(12)
            .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.dogOrange))
        }
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
                bannerWebURL = PetWhiteWebDestination(url: url)
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

    private func openLibrarySquare() {
        UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
        NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
    }
}

private struct PetWhiteWebDestination: Identifiable {
    let url: URL

    var id: URL { url }
}

private struct PetWhiteQuickAction: View {
    let title: String
    let subtitle: String
    let icon: MonologueIcon.IconType
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                PetWhiteIconBadge(icon: icon, tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PetWhiteStyle.labelFont(14, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(PetWhiteStyle.labelFont(10, weight: .black))
                        .foregroundStyle(PetWhiteStyle.inkMuted)
                        .tracking(0.7)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(PetWhiteSurfaceBackground(cornerRadius: 20, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: tint))
        }
        .buttonStyle(.plain)
    }
}

private struct PetWhiteSongTreatRow: View {
    let index: Int
    let song: Song

    var body: some View {
        HStack(spacing: 11) {
            Text(String(format: "%02d", index))
                .font(PetWhiteStyle.labelFont(11, weight: .black))
                .foregroundStyle(PetWhiteStyle.stroke)
                .frame(width: 34, height: 34)
                .background(PetWhiteStyle.mint, in: Circle())
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.4))

            CachedAsyncImage(url: song.coverUrl) {
                PetWhiteMascotMark(kind: index.isMultiple(of: 2) ? .dog : .cat, size: 42)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.5)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(PetWhiteStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            PetWhitePackIcon(icon: .play, size: 20, visualScale: 1.08)
                .frame(width: 30, height: 30)
                .background(PetWhiteStyle.butter, in: Circle())
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PetWhiteStyle.surfacePressed)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PetWhiteStyle.separator, lineWidth: 1)
                )
        )
    }
}

private struct PetWhiteBannerCarousel: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var bannerIndex = 0
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $bannerIndex) {
                ForEach(Array(banners.prefix(6).enumerated()), id: \.element.id) { index, banner in
                    Button {
                        onTap(banner)
                    } label: {
                        PetWhiteBannerCard(banner: banner)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: DeviceLayout.isPad ? 196 : 166)
            .onReceive(timer) { _ in
                guard banners.count > 1 else { return }
                withAnimation(MonologueAnimation.tabSwitch) {
                    bannerIndex = (bannerIndex + 1) % min(banners.count, 6)
                }
            }

            if banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(banners.count, 6), id: \.self) { index in
                        Capsule()
                            .fill(index == bannerIndex ? PetWhiteStyle.stroke : PetWhiteStyle.separator)
                            .frame(width: index == bannerIndex ? 20 : 7, height: 7)
                            .animation(MonologueAnimation.micro, value: bannerIndex)
                    }
                }
            }
        }
    }
}

private struct PetWhiteBannerCard: View {
    let banner: Banner

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: banner.imageUrl) {
                PetWhiteSurfaceBackground(cornerRadius: 28, elevated: false, tint: PetWhiteStyle.surfacePressed, accent: PetWhiteStyle.sky)
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: DeviceLayout.isPad ? 176 : 146)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            LinearGradient(
                colors: [.clear, PetWhiteStyle.stroke.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            HStack(spacing: 8) {
                PetWhiteIconBadge(icon: .sparkle, tint: PetWhiteStyle.butter, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(banner.typeTitle ?? "PET PICK")
                        .font(PetWhiteStyle.labelFont(12, weight: .black))
                        .foregroundStyle(PetWhiteStyle.paper)
                        .lineLimit(1)

                    Text("Furry Paws")
                        .font(PetWhiteStyle.labelFont(10, weight: .black))
                        .foregroundStyle(PetWhiteStyle.paper.opacity(0.82))
                        .tracking(0.8)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(PetWhiteStyle.stroke, lineWidth: 1.6)
        )
        .background(PetWhiteSurfaceBackground(cornerRadius: 28, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.sky))
    }
}

private struct PetWhitePlaylistShelf: View {
    let title: String
    let detail: String
    let playlists: [Playlist]
    let tint: Color
    let icon: MonologueIcon.IconType
    let onViewAll: () -> Void
    let onTap: (Playlist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: title,
                detail: detail,
                icon: icon,
                tint: tint,
                action: onViewAll
            )
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(playlists.prefix(10).enumerated()), id: \.element.id) { index, playlist in
                        Button {
                            onTap(playlist)
                        } label: {
                            PetWhitePlaylistCard(playlist: playlist, index: index, tint: tint)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        }
    }
}

private struct PetWhitePlaylistCard: View {
    let playlist: Playlist
    let index: Int
    let tint: Color

    private var cardWidth: CGFloat {
        DeviceLayout.isPad ? 168 : 136
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    PetWhiteMascotMark(kind: index.isMultiple(of: 2) ? .cat : .dog, size: 58)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PetWhiteStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if let playCount = playlist.playCount, playCount > 0 {
                    HStack(spacing: 4) {
                        PetWhitePackIcon(icon: .play, size: 13, visualScale: 1.05)
                        Text(PetWhiteHomeFormat.count(playCount))
                            .font(PetWhiteStyle.labelFont(10, weight: .black))
                    }
                    .foregroundStyle(PetWhiteStyle.stroke)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(PetWhiteStyle.paper.opacity(0.86), in: Capsule())
                    .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                    .padding(9)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.5)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(PetWhiteStyle.bodyFont(13, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top)

                Text(playlist.trackCount.map { "\($0) \(String(localized: "songs_unit"))" } ?? "Furry list")
                    .font(PetWhiteStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(width: cardWidth + 20)
        .background(PetWhiteSurfaceBackground(cornerRadius: 28, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: tint))
    }
}

private struct PetWhiteNewSongsBoard: View {
    let songs: [Song]
    let onViewAll: () -> Void
    let onPlay: (Song) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: String(localized: "qq_new_songs"),
                detail: String(localized: "qq_new_songs_desc"),
                icon: .musicNote,
                tint: PetWhiteStyle.mint,
                action: onViewAll
            )

            VStack(spacing: 10) {
                ForEach(Array(songs.prefix(5).enumerated()), id: \.element.id) { index, song in
                    Button {
                        onPlay(song)
                    } label: {
                        PetWhiteNewSongRow(index: index + 1, song: song)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                }
            }
            .padding(12)
            .background(PetWhiteSurfaceBackground(cornerRadius: 24, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }
}

private struct PetWhiteNewSongRow: View {
    let index: Int
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl) {
                    PetWhitePetPetIcon(size: 38)
                        .frame(width: 48, height: 48)
                        .background(PetWhiteStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                )

                Text("\(index)")
                    .font(PetWhiteStyle.labelFont(10, weight: .black))
                    .foregroundStyle(PetWhiteStyle.stroke)
                    .frame(width: 20, height: 20)
                    .background(PetWhiteStyle.butter, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                    .offset(x: 5, y: 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(PetWhiteStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            PetWhitePackIcon(icon: .playCircle, size: 24, visualScale: 1.06)
                .frame(width: 34, height: 34)
                .background(PetWhiteStyle.mint, in: Circle())
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.2))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PetWhiteStyle.surfacePressed)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PetWhiteStyle.separator, lineWidth: 1)
                )
        )
    }
}

private enum PetWhiteHomeFormat {
    static func count(_ count: Int) -> String {
        let locale = Locale.current
        if locale.language.languageCode?.identifier == "zh" {
            if count >= 100_000_000 {
                return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100_000_000)
            }
            if count >= 10_000 {
                return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10_000)
            }
        } else {
            if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
            if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
            if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        }
        return "\(count)"
    }
}

private struct PetWhiteLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            PetWhiteMascotMark(kind: .pair, size: 84)

            HStack(spacing: 8) {
                Capsule().fill(PetWhiteStyle.dogOrange).frame(width: 28, height: 8)
                Capsule().fill(PetWhiteStyle.mint).frame(width: 46, height: 8)
                Capsule().fill(PetWhiteStyle.blush).frame(width: 18, height: 8)
            }
        }
    }
}

struct PetWhitePodcastView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .podcast) {
            PodcastView()
        }
    }
}

struct PetWhiteSearchView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .search) {
            SearchView()
        }
    }
}

struct PetWhiteLibraryView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .library) {
            LibraryView()
        }
    }
}

struct PetWhiteProfileView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .profile) {
            ProfileView()
        }
    }
}

struct PetWhiteLocalHomeView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localHome) {
            LocalModeHomeView()
        }
    }
}

struct PetWhiteLocalMusicView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localMusic) {
            LocalMusicView()
        }
    }
}

struct PetWhiteLocalLibraryView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localLibrary) {
            LocalLibraryView()
        }
    }
}

struct PetWhiteLocalProfileView: View {
    var body: some View {
        PetWhiteThemeRoot(page: .localProfile) {
            LocalModeProfileView()
        }
    }
}

private extension View {
    func petWhiteAppear(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0.96)
            .offset(y: appeared ? 0 : 6)
            .animation(
                .spring(response: 0.42, dampingFraction: 0.84).delay(Double(order) * 0.04),
                value: appeared
            )
    }
}
