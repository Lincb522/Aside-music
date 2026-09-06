import SwiftUI

struct HomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showPersonalFM = false
    @State private var navigationPath = NavigationPath()
    @State private var bannerWebURL: URL?
    @State private var appeared = false
    @State private var didActivateHome = false

    enum HomeDestination: Hashable {
        case search, dailyRecommend, playlist(Playlist), bannerPlaylist(Playlist, String?), artist(Int), album(Int), mvDiscover, newSongExpress, qcmNewSongs, meditationMode

        func hash(into hasher: inout Hasher) {
            switch self {
            case .search:           hasher.combine("search")
            case .dailyRecommend:   hasher.combine("daily")
            case .playlist(let p):  hasher.combine("p_\(p.id)")
            case let .bannerPlaylist(p, bannerImage):
                hasher.combine("bp_\(p.id)")
                hasher.combine(bannerImage)
            case .artist(let id):   hasher.combine("a_\(id)")
            case .album(let id):    hasher.combine("al_\(id)")
            case .mvDiscover:       hasher.combine("mv")
            case .newSongExpress:   hasher.combine("newSong")
            case .qcmNewSongs:      hasher.combine("qcmNewSongs")
            case .meditationMode:   hasher.combine("meditationMode")
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.search, .search), (.dailyRecommend, .dailyRecommend),
                 (.mvDiscover, .mvDiscover), (.newSongExpress, .newSongExpress),
                 (.qcmNewSongs, .qcmNewSongs), (.meditationMode, .meditationMode): return true
            case (.playlist(let l), .playlist(let r)): return l.id == r.id
            case let (.bannerPlaylist(l, lImage), .bannerPlaylist(r, rImage)):
                return l.id == r.id && lImage == rImage
            case (.artist(let l), .artist(let r)): return l == r
            case (.album(let l), .album(let r)): return l == r
            default: return false
            }
        }
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        if MinimalWhiteStyle.isActive {
            minimalWhiteBody
        } else {
            defaultBody
        }
    }

    private var defaultBody: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true).ignoresSafeArea()

                if viewModel.isLoading {
                    MonoLoadingView(text: "LOADING HOME")
                } else {
                    scrollBody
                }
            }
            .task {
                guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
                activateHomeIfNeeded(reason: "home appear", animatesAppearance: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mainTabDidSettle)) { notification in
                guard notification.object as? Tab == .home,
                      MainTabActivationGate.isSettled(.home) else { return }
                activateHomeIfNeeded(reason: "home selected", animatesAppearance: true)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !SignalStyle.isActive {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
                        }) {
                            homeAvatarView
                        }
                        .buttonStyle(.plain)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button(action: {
                                navigationPath.append(HomeDestination.meditationMode)
                            }) {
                                MonoIcon(icon: .moon, size: 15)
                                    .padding(3)
                            }

                            Button(action: {
                                showPersonalFM = true
                            }) {
                                MonoIcon(icon: .fm, size: 15)
                                    .padding(3)
                            }

                            Button(action: {
                                navigationPath.append(HomeDestination.search)
                            }) {
                                MonoIcon(icon: .search, size: 15)
                                    .padding(3)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .modifier(HomeToolbarCapsuleModifier())
                    }
                }
            }
            .navigationDestination(for: HomeDestination.self, destination: destinationView)
            .fullScreenCover(isPresented: $showPersonalFM) { PersonalFMView() }
            .fullScreenCover(item: $bannerWebURL) { url in MonoWebView(url: url, title: nil) }
        }
    }

    private var minimalWhiteBody: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                MinimalWhiteRootBackdrop().ignoresSafeArea()

                if viewModel.isLoading {
                    MonoLoadingView(text: "")
                } else {
                    minimalWhiteScrollBody
                }
            }
            .task {
                guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
                activateHomeIfNeeded(reason: "minimal white home appear", animatesAppearance: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mainTabDidSettle)) { notification in
                guard notification.object as? Tab == .home,
                      MainTabActivationGate.isSettled(.home) else { return }
                activateHomeIfNeeded(reason: "minimal white home selected", animatesAppearance: false)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeDestination.self, destination: destinationView)
            .fullScreenCover(isPresented: $showPersonalFM) { PersonalFMView() }
            .fullScreenCover(item: $bannerWebURL) { url in MonoWebView(url: url, title: nil) }
        }
    }

    private func activateHomeIfNeeded(reason: String, animatesAppearance: Bool) {
        guard !didActivateHome else { return }
        didActivateHome = true
        viewModel.ensureHomeDataLoaded(reason: reason)

        guard !appeared else { return }
        if animatesAppearance {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
        } else {
            appeared = true
        }
    }

    private var minimalWhiteScrollBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                minimalWhiteHeader

                if !viewModel.banners.isEmpty {
                    HomeBannerSection(banners: viewModel.banners, onTap: handleBannerTap)
                }

                minimalWhiteQuickActions

                if !viewModel.dailySongs.isEmpty || !viewModel.qqNewSongs.isEmpty {
                    minimalWhiteMusicBoard
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    HomeNCMPlaylistSection(
                        playlists: viewModel.recommendPlaylists,
                        onViewAll: { switchToLibrarySquare() },
                        onTap: { playlist in navigationPath.append(HomeDestination.playlist(playlist)) }
                    )
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    HomeQQPlaylistSection(
                        playlists: viewModel.qqRecommendPlaylists,
                        onViewAll: { switchToLibrarySquare() },
                        onTap: { playlist in navigationPath.append(HomeDestination.playlist(playlist)) }
                    )
                }

                if !viewModel.kugouRecommendPlaylists.isEmpty {
                    HomeNCMPlaylistSection(
                        playlists: viewModel.kugouRecommendPlaylists,
                        title: "KCM 推荐歌单",
                        subtitle: "",
                        onViewAll: { switchToLibrarySquare(source: .kugou) },
                        onTap: { playlist in navigationPath.append(HomeDestination.playlist(playlist)) }
                    )
                }

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 8)
            .padding(.bottom, 8)
            .iPadContentWidth(1180)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable { viewModel.retryHomeDataLoad(reason: "minimal white home refresh") }
    }

    private var minimalWhiteHeader: some View {
        HStack(spacing: 14) {
            Button {
                NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
            } label: {
                homeAvatarView
            }
            .buttonStyle(.plain)

            Text(String(localized: "tabbar_home"))
                .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)

            Spacer(minLength: 8)

            MinimalWhiteHeaderButton(icon: .moon) {
                navigationPath.append(HomeDestination.meditationMode)
            }
            MinimalWhiteHeaderButton(icon: .fm) {
                showPersonalFM = true
            }
            MinimalWhiteHeaderButton(icon: .search, selected: true) {
                navigationPath.append(HomeDestination.search)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .monoPageHeaderCollapse()
    }

    private var minimalWhiteQuickActions: some View {
        HStack(spacing: 10) {
            minimalWhiteQuickAction(icon: .musicNoteList, title: String(localized: "daily_recommend")) {
                navigationPath.append(HomeDestination.dailyRecommend)
            }

            minimalWhiteQuickAction(icon: .musicNote, title: String(localized: "new_song_express")) {
                navigationPath.append(HomeDestination.newSongExpress)
            }

            minimalWhiteQuickAction(icon: .mv, title: String(localized: "home_mv_zone")) {
                navigationPath.append(HomeDestination.mvDiscover)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func minimalWhiteQuickAction(
        icon: MonoIcon.IconType,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MonoIcon(icon: icon, size: 15, color: MinimalWhiteStyle.inkSoft, lineWidth: 1.7)
                    .frame(width: 30, height: 30)
                    .background(MinimalWhiteCircleBackground())

                Text(title)
                    .font(MinimalWhiteStyle.labelFont(12, weight: .medium))
                    .foregroundStyle(MinimalWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                MinimalWhiteSurfaceBackground(
                    cornerRadius: 15,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            )
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
    }

    @ViewBuilder
    private var minimalWhiteMusicBoard: some View {
        VStack(spacing: 0) {
            if !viewModel.dailySongs.isEmpty {
                minimalWhiteDailyBlock
            }

            if !viewModel.dailySongs.isEmpty && !viewModel.qqNewSongs.isEmpty {
                Rectangle()
                    .fill(MinimalWhiteStyle.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }

            if !viewModel.qqNewSongs.isEmpty {
                minimalWhiteNewSongsBlock
            }

        }
        .padding(.vertical, 8)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: 22,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        )
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var minimalWhiteDailyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            minimalWhiteBoardHeader(
                title: String(localized: "made_for_you"),
                action: { navigationPath.append(HomeDestination.dailyRecommend) }
            )

            ForEach(Array(viewModel.dailySongs.prefix(4).enumerated()), id: \.element.identityKey) { index, song in
                Button {
                    PlayerManager.shared.play(song: song, in: viewModel.dailySongs)
                } label: {
                    MinimalWhiteHomeSongRow(song: song, index: index + 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var minimalWhiteNewSongsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            minimalWhiteBoardHeader(
                title: NSLocalizedString("qq_new_songs", comment: ""),
                action: { navigationPath.append(HomeDestination.qcmNewSongs) }
            )

            ForEach(Array(viewModel.qqNewSongs.prefix(4).enumerated()), id: \.element.identityKey) { index, song in
                Button {
                    PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs)
                } label: {
                    MinimalWhiteHomeSongRow(song: song, index: index + 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func minimalWhiteBoardHeader(title: String, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(MinimalWhiteStyle.titleFont(18, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let action {
                Button(action: action) {
                    MinimalWhiteDisclosureGlyph()
                }
                .buttonStyle(.plain)
            }
        }
    }


    private func minimalWhiteHeaderButton(
        icon: MonoIcon.IconType,
        action: @escaping () -> Void
    ) -> some View {
        MinimalWhiteHeaderButton(icon: icon, action: action)
    }

    private func switchToLibrarySquare(source: LibraryViewModel.MusicSource? = nil) {
        UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
        if let source {
            UserDefaults.standard.set(source.rawValue, forKey: "pendingLibrarySquareSource")
        }
        NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: source)
    }


    // MARK: - Toolbar Greeting

    private var homeToolbarGreeting: some View {
        VStack(alignment: .leading, spacing: 1) {
            let hitokotoText = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if settings.hitokotoEnabled, !hitokotoText.isEmpty {
                Text(hitokotoText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monoTextSecondary.opacity(0.7))
                    .lineLimit(1)
            } else if settings.hitokotoEnabled {
                Text(HitokotoFallbackSlogan.text)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monoTextSecondary.opacity(0.7))
                    .lineLimit(1)
            } else {
                Text(String(localized: LocalizedStringResource(stringLiteral: homeGreetingKey)))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monoTextSecondary.opacity(0.7))
            }

            Text(viewModel.displayedIdentityProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.monoTextPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Toolbar Avatar

    @ViewBuilder
    private var homeAvatarView: some View {
        let size: CGFloat = 36
        if let avatarUrl = viewModel.displayedIdentityProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                Circle().fill(Color.monoSeparator)
            }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle().fill(Color.monoSeparator)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: 16, color: .monoTextSecondary))
        }
    }

    // MARK: - Greeting Section

    private var homeGreetingSection: some View {
        VStack(spacing: 12) {
            greetingRow
            if settings.hitokotoEnabled {
                let hitokotoText = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if hitokotoText.isEmpty {
                    hitokotoFallbackCard
                } else {
                    hitokotoCard(hitokotoText)
                }
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var greetingRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: LocalizedStringResource(stringLiteral: homeGreetingKey)))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.monoTextSecondary.opacity(0.7))

            Text(viewModel.displayedIdentityProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.monoTextPrimary, .monoTextPrimary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hitokotoFallbackCard: some View {
        HStack(alignment: .center, spacing: 12) {
            MonoSemanticIcon(
                semantic: .quote,
                fallback: .hitokoto,
                size: 17,
                color: .monoTextPrimary.opacity(0.42)
            )

            Text(HitokotoFallbackSlogan.text)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.monoTextPrimary.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.refreshHitokoto(force: true)
            } label: {
                MonoIcon(icon: .refresh, size: 12, color: .monoTextSecondary.opacity(0.5), lineWidth: 1.5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monoTextPrimary.opacity(0.04))
        )
    }

    private func hitokotoCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MonoSemanticIcon(
                semantic: .quote,
                fallback: .hitokoto,
                size: 17,
                color: .monoTextPrimary.opacity(0.42)
            )
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.monoTextPrimary.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.refreshHitokoto(force: true)
            } label: {
                MonoIcon(icon: .refresh, size: 12, color: .monoTextSecondary.opacity(0.5), lineWidth: 1.5)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monoTextPrimary.opacity(0.04))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var homeGreetingKey: String {
        MonoTimeGreeting.localizedKey
    }

    // MARK: - Scroll Body (Now Showing cinema layout)

    @ViewBuilder
    private var scrollBody: some View {
        if SignalStyle.isActive {
            signalScrollBody
        } else {
            cinemaScrollBody
        }
    }

    private var signalScrollBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                consoleMasthead

                if !viewModel.banners.isEmpty {
                    SignalHomeHero(banners: viewModel.banners, onTap: handleBannerTap)
                }

                signalHomeQuickActions

                if !viewModel.dailySongs.isEmpty {
                    SignalHomeSongSection(
                        title: String(localized: "made_for_you"),
                        songs: viewModel.dailySongs,
                        onViewAll: { navigationPath.append(HomeDestination.dailyRecommend) },
                        onPlay: { song in PlayerManager.shared.play(song: song, in: viewModel.dailySongs) }
                    )
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    SignalHomePlaylistSection(
                        title: String(localized: "playlists_love"),
                        playlists: viewModel.recommendPlaylists,
                        onViewAll: { switchToLibrarySquare() },
                        onTap: { playlist in navigationPath.append(HomeDestination.playlist(playlist)) }
                    )
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    SignalHomePlaylistSection(
                        title: String(localized: "qq_recommend_playlists"),
                        playlists: viewModel.qqRecommendPlaylists,
                        onViewAll: { switchToLibrarySquare() },
                        onTap: { playlist in navigationPath.append(HomeDestination.playlist(playlist)) }
                    )
                }

                if !viewModel.kugouRecommendPlaylists.isEmpty {
                    SignalHomePlaylistSection(
                        title: "KCM 推荐歌单",
                        playlists: viewModel.kugouRecommendPlaylists,
                        onViewAll: { switchToLibrarySquare(source: .kugou) },
                        onTap: { playlist in navigationPath.append(HomeDestination.playlist(playlist)) }
                    )
                }

                if !viewModel.qqNewSongs.isEmpty {
                    SignalHomeSongSection(
                        title: String(localized: "qq_new_songs"),
                        songs: viewModel.qqNewSongs,
                        onViewAll: { navigationPath.append(HomeDestination.qcmNewSongs) },
                        onPlay: { song in PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs) }
                    )
                }

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 2)
            .padding(.bottom, 8)
            .iPadContentWidth(1180)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable { viewModel.retryHomeDataLoad(reason: "signal home refresh") }
    }

    private var signalHomeQuickActions: some View {
        HStack(spacing: 0) {
            signalHomeAction(icon: .musicNoteList, title: String(localized: "daily_recommend")) {
                navigationPath.append(HomeDestination.dailyRecommend)
            }

            signalHomeAction(icon: .musicNote, title: String(localized: "new_song_express")) {
                navigationPath.append(HomeDestination.newSongExpress)
            }

            signalHomeAction(icon: .mv, title: String(localized: "home_mv_zone")) {
                navigationPath.append(HomeDestination.mvDiscover)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func signalHomeAction(
        icon: MonoIcon.IconType,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                MonoIcon(icon: icon, size: 17, color: SignalStyle.accent, lineWidth: 1.55)
                    .frame(width: 34, height: 26)

                Text(title)
                    .font(SignalStyle.labelFont(10.5, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cinemaScrollBody: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                cinemaMasthead
                    .padding(.bottom, 20)

                if !viewModel.banners.isEmpty {
                    CinemaHeroCarousel(banners: viewModel.banners, onTap: handleBannerTap)
                        .stagger(appeared, order: 0)
                        .padding(.bottom, 30)
                }

                if !viewModel.dailySongs.isEmpty {
                    CinemaSongPosterRail(
                        sceneNumber: 1,
                        kicker: "Today's Feature",
                        title: NSLocalizedString("made_for_you", comment: ""),
                        songs: viewModel.dailySongs,
                        showsRank: true,
                        onViewAll: { navigationPath.append(HomeDestination.dailyRecommend) },
                        onPlay: { song in PlayerManager.shared.play(song: song, in: viewModel.dailySongs) }
                    )
                    .stagger(appeared, order: 1)
                    .padding(.bottom, 30)
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    CinemaPlaylistPosterRail(
                        sceneNumber: 2,
                        kicker: "Feature Presentation",
                        title: NSLocalizedString("playlists_love", comment: ""),
                        playlists: viewModel.recommendPlaylists,
                        onViewAll: { switchToLibrarySquare() },
                        onTap: { pl in navigationPath.append(HomeDestination.playlist(pl)) }
                    )
                    .stagger(appeared, order: 2)
                    .padding(.bottom, 30)
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    CinemaPlaylistPosterRail(
                        sceneNumber: 3,
                        kicker: "Selected Screenings",
                        title: NSLocalizedString("qq_recommend_playlists", comment: ""),
                        playlists: viewModel.qqRecommendPlaylists,
                        onViewAll: { switchToLibrarySquare() },
                        onTap: { pl in navigationPath.append(HomeDestination.playlist(pl)) }
                    )
                    .stagger(appeared, order: 3)
                    .padding(.bottom, 30)
                }

                if !viewModel.kugouRecommendPlaylists.isEmpty {
                    CinemaPlaylistPosterRail(
                        sceneNumber: 4,
                        kicker: "KCM",
                        title: "KCM 推荐歌单",
                        playlists: viewModel.kugouRecommendPlaylists,
                        onViewAll: { switchToLibrarySquare(source: .kugou) },
                        onTap: { playlist in navigationPath.append(HomeDestination.playlist(playlist)) }
                    )
                    .stagger(appeared, order: 4)
                    .padding(.bottom, 30)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    CinemaSongPosterRail(
                        sceneNumber: 5,
                        kicker: "Coming Soon",
                        title: NSLocalizedString("qq_new_songs", comment: ""),
                        songs: viewModel.qqNewSongs,
                        onViewAll: { navigationPath.append(HomeDestination.qcmNewSongs) },
                        onPlay: { song in PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs) }
                    )
                    .stagger(appeared, order: 5)
                    .padding(.bottom, 34)
                }

                CinemaTrailerRow(
                    onNewSongExpress: { navigationPath.append(HomeDestination.newSongExpress) },
                    onMVDiscover: { navigationPath.append(HomeDestination.mvDiscover) }
                )
                .stagger(appeared, order: 6)

                FloatingBarBottomSpacer()
            }
            .padding(.top, 4)
            .iPadContentWidth(1180)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable { viewModel.retryHomeDataLoad(reason: "home pull refresh") }
    }

    // MARK: - Cinema Masthead

    @ViewBuilder
    private var cinemaMasthead: some View {
        if SignalStyle.isActive {
            consoleMasthead
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(localized: LocalizedStringResource(stringLiteral: homeGreetingKey)))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(cinemaDateString)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.monoTextSecondary.opacity(0.8))
                }

                Text(viewModel.displayedIdentityProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(.system(size: 27, weight: .heavy, design: .serif))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if settings.hitokotoEnabled {
                    let hitokotoText = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    cinemaTagline(hitokotoText.isEmpty ? HitokotoFallbackSlogan.text : hitokotoText)
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .monoPageHeaderCollapse()
        }
    }

    private var consoleMasthead: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SignalBreathingIndicator(size: 7)

                Text(String(localized: "tabbar_home"))
                    .font(SignalStyle.titleFont(27, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)

                Spacer(minLength: 8)

                signalHomeHeaderButton(icon: .profile) {
                    NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
                }

                signalHomeHeaderButton(icon: .moon) {
                    navigationPath.append(HomeDestination.meditationMode)
                }

                signalHomeHeaderButton(icon: .fm) {
                    showPersonalFM = true
                }

                signalHomeHeaderButton(icon: .search, tint: SignalStyle.accent) {
                    navigationPath.append(HomeDestination.search)
                }
            }

            HStack(spacing: 8) {
                Text(String(localized: LocalizedStringResource(stringLiteral: homeGreetingKey)))
                    .font(SignalStyle.labelFont(12, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)

                Spacer(minLength: 8)

                Text(cinemaDateString)
                    .font(SignalStyle.monoFont(10, weight: .medium))
                    .foregroundStyle(SignalStyle.inkMuted)
            }

            if settings.hitokotoEnabled {
                let text = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                cinemaTagline(text.isEmpty ? HitokotoFallbackSlogan.text : text)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .monoPageHeaderCollapse()
    }

    private func signalHomeHeaderButton(
        icon: MonoIcon.IconType,
        tint: Color = SignalStyle.inkSoft,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 15, color: tint, lineWidth: 1.6)
                .frame(width: 34, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
    }

    private var cinemaDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: Date())
    }

    private func cinemaTagline(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            if !SignalStyle.isActive {
                Capsule()
                    .fill(Color.monoAccent.opacity(0.65))
                    .frame(width: 2.5)
            }

            Group {
                if SignalStyle.isActive {
                    Text(text)
                        .font(SignalStyle.bodyFont(12, weight: .medium))
                } else {
                    Text(text)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .italic()
                }
            }
                .foregroundColor(.monoTextPrimary.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.refreshHitokoto(force: true)
            } label: {
                MonoIcon(icon: .refresh, size: 11, color: .monoTextSecondary.opacity(0.5), lineWidth: 1.5)
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Banner Tap

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run { PlayerManager.shared.play(song: song, in: [song]) }
                    }
                } catch { AppLogger.error("Banner 歌曲加载失败: \(error)") }
            }
        case 10:
            navigationPath.append(HomeDestination.album(banner.targetId))
        case 1000:
            let pl = Playlist(
                id: banner.targetId,
                name: banner.typeTitle ?? String(localized: "home_playlist"),
                coverImgUrl: banner.pic, picUrl: nil,
                trackCount: nil, playCount: nil, subscribedCount: nil,
                shareCount: nil, commentCount: nil, creator: nil,
                description: nil, tags: nil
            )
            navigationPath.append(HomeDestination.bannerPlaylist(pl, banner.pic))
        case 1004:
            navigationPath.append(HomeDestination.mvDiscover)
        default:
            if let urlStr = banner.url, let url = URL(string: urlStr) { bannerWebURL = url }
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destinationView(for dest: HomeDestination) -> some View {
        switch dest {
        case .search:           SearchView()
        case .dailyRecommend:   DailyRecommendView()
        case .playlist(let p):  PlaylistDetailView(playlist: p)
        case let .bannerPlaylist(p, bannerImage): PlaylistDetailView(playlist: p, bannerCoverURLString: bannerImage)
        case .artist(let id):   ArtistDetailView(artistId: id)
        case .album(let id):    AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil)
        case .mvDiscover:       MVDiscoverView()
        case .newSongExpress:   NewSongExpressView()
        case .qcmNewSongs:      QCMNewSongsView()
        case .meditationMode:   MeditationModeView()
        }
    }
}

private struct HomeToolbarCapsuleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if SignalStyle.isActive {
            content
        } else if ThemedPageStyle.isActive {
            content.monoGlassCapsule()
        } else if #available(iOS 26, *) {
            // iOS 26 的 ToolbarItem 已自带系统胶囊，经典主题不再重复叠玻璃。
            content
        } else {
            content.monoGlassCapsule()
        }
    }
}

// MARK: - Stagger

private extension View {
    func stagger(_ appeared: Bool, order: Int) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.82).delay(Double(order) * 0.06),
                value: appeared
            )
    }
}

private struct MinimalWhiteHomeSongRow: View {
    let song: Song
    let index: Int
    @ObservedObject private var playback = SongRowPlaybackModel.shared

    var body: some View {
        let isCurrent = playback.currentSongId == song.id

        return HStack(spacing: 11) {
            Text(String(format: "%02d", index))
                .font(MinimalWhiteStyle.labelFont(11, weight: .regular))
                .foregroundStyle(MinimalWhiteStyle.inkMuted)
                .frame(width: 24, alignment: .leading)

            CachedAsyncImage(url: song.coverUrl, width: 44, height: 44) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(MinimalWhiteStyle.controlGlassFill)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(MinimalWhiteStyle.bodyFont(14, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(MinimalWhiteStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(MinimalWhiteStyle.labelFont(12, weight: .regular))
                    .foregroundStyle(MinimalWhiteStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                PlayingVisualizerView(isAnimating: playback.isPlaying, color: MinimalWhiteStyle.ink)
                    .frame(width: 18, height: 14)
            } else {
                MonoIcon(icon: .play, size: 11, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6)
                    .frame(width: 24, height: 24)
                    .background(MinimalWhiteCircleBackground())
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

}
