import SwiftUI

struct MangaHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var quoteText = ""
    @State private var hasAppeared = false

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                let safeWidth = max(
                    0,
                    proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing
                )
                let maximumWidth: CGFloat = DeviceLayout.isPad ? 680 : (safeWidth > 500 ? 460 : safeWidth)
                let pageWidth = min(safeWidth, maximumWidth)

                ZStack(alignment: .top) {
                    MangaComicPalette.ink
                        .ignoresSafeArea()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            mangaMasthead(width: pageWidth)

                            mangaFrontPage(width: pageWidth)
                        }
                        .frame(width: pageWidth)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        viewModel.fetchData()
                        if hitokotoEnabled {
                            viewModel.refreshHitokoto(force: true)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                synchronizeVisibleContent(reason: "manga cover appear")
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }
            .task {
                viewModel.reloadHomeCacheForVisibleHomeIfNeeded(reason: "manga cover task")
                viewModel.ensureHomeDataLoaded(reason: "manga cover task")
                if hitokotoEnabled, quoteText.isEmpty {
                    viewModel.refreshHitokoto(force: true)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                synchronizeVisibleContent(reason: "manga cover foreground")
            }
            .onChange(of: settings.globalThemeRevision) { _, _ in
                synchronizeVisibleContent(reason: "manga cover theme refresh")
            }
            .onChange(of: hitokotoEnabled) { _, enabled in
                if enabled {
                    viewModel.refreshHitokoto(force: true)
                    updateQuote(viewModel.hitokoto)
                } else {
                    quoteText = ""
                }
            }
            .onReceive(viewModel.$hitokoto) { value in
                updateQuote(value)
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { destination in
                mangaDestination(for: destination)
            }
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(item: $bannerWebURL) { url in
                MonologueWebView(url: url, title: nil)
            }
        }
        .themeRenderSceneLayer()
    }

    private func synchronizeVisibleContent(reason: String) {
        viewModel.reloadHomeCacheIfUseful(reason: reason)
        viewModel.ensureHomeDataLoaded(reason: reason)
        updateQuote(viewModel.hitokoto)
        if hitokotoEnabled, quoteText.isEmpty {
            viewModel.refreshHitokoto(force: true)
        }
    }

    private func updateQuote(_ value: String?) {
        quoteText = hitokotoEnabled
            ? (value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            : ""
    }

    private func mangaMasthead(width: CGFloat) -> some View {
        let layoutScale = min(1, max(0.72, width / 390))
        let height = min(156, max(118, width * 0.34))
        let compact = width < 380

        return ZStack(alignment: .bottom) {
            MangaComicPalette.ink

            MangaComicMastheadShape()
                .fill(MangaComicPalette.paper)
                .overlay {
                    GeometryReader { proxy in
                        ZStack {
                            Image("MangaPaperTexture")
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .opacity(0.34)
                                .blendMode(.multiply)

                            MangaComicPaperTexture(opacity: 0.09)
                            MangaComicHalftone(
                                color: MangaComicPalette.redDeep,
                                opacity: 0.035,
                                gap: 12
                            )
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipShape(MangaComicMastheadShape())
                    }
                }
                .overlay(
                    MangaComicMastheadShape()
                        .stroke(MangaComicPalette.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                )

            HStack(alignment: .bottom, spacing: compact ? 7 : 10) {
                Button {
                    NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
                } label: {
                    mangaAvatar(size: 62 * layoutScale)
                }
                .buttonStyle(MangaComicPressButtonStyle())

                VStack(alignment: .leading, spacing: compact ? 7 : 9) {
                    MangaComicRibbon(
                        text: mangaGreetingText,
                        fill: MangaComicPalette.red,
                        foreground: MangaComicPalette.whiteInk,
                        scale: layoutScale
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mangaCoverTitle)
                            .font(MangaComicPalette.displayFont(29 * layoutScale))
                            .foregroundStyle(MangaComicPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        MangaComicUnderline()
                            .frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: compact ? 7 : 9) {
                    MangaComicMastheadAction(
                        icon: .radio,
                        title: String(localized: "manga_header_fm"),
                        fill: MangaComicPalette.paper,
                        scale: layoutScale
                    ) {
                        showPersonalFM = true
                    }

                    MangaComicMastheadAction(
                        icon: .magnifyingGlass,
                        title: String(localized: "tab_search"),
                        fill: MangaComicPalette.red,
                        scale: layoutScale
                    ) {
                        navigationPath.append(HomeView.HomeDestination.search)
                    }
                }
            }
            .padding(.horizontal, compact ? 8 : 14)
            .padding(.bottom, 12 * layoutScale)
        }
        .frame(height: height)
        .overlay(alignment: .topLeading) {
            HStack(spacing: -4) {
                MangaComicLightningShape()
                    .fill(MangaComicPalette.whiteInk)
                    .frame(width: 26 * layoutScale, height: 42 * layoutScale)
                    .rotationEffect(.degrees(-13))
                MangaComicLightningShape()
                    .fill(MangaComicPalette.whiteInk)
                    .frame(width: 17 * layoutScale, height: 31 * layoutScale)
                    .rotationEffect(.degrees(8))
            }
            .offset(x: -3, y: 37 * layoutScale)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -8)
    }

    @ViewBuilder
    private func mangaAvatar(size: CGFloat) -> some View {
        let componentScale = size / 62

        ZStack {
            MangaComicAvatarBurst()
                .frame(width: size + 24 * componentScale, height: size + 24 * componentScale)

            Circle()
                .fill(MangaComicPalette.paper)
                .frame(width: size + 8, height: size + 8)
                .overlay(Circle().stroke(MangaComicPalette.ink, lineWidth: 3.3))

            Group {
                if let source = viewModel.userProfile?.avatarUrl,
                   let url = URL(string: source) {
                    CachedAsyncImage(url: url) {
                        MangaComicPalette.paperWarm
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        MangaComicPalette.paperWarm
                        MonologueIcon(icon: .profileFilled, size: size * 0.34, color: MangaComicPalette.ink, lineWidth: 2.2)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(MangaComicPalette.ink, lineWidth: 2.3))
        }
        .frame(width: size + 10 * componentScale, height: size + 12 * componentScale)
    }

    private func mangaFrontPage(width: CGFloat) -> some View {
        let pagePadding: CGFloat = DeviceLayout.isPad ? 16 : 7

        return LazyVStack(spacing: 5) {
            mangaLeadStory(width: width - pagePadding * 2)
                .padding(.horizontal, pagePadding)
                .padding(.top, 4)

            mangaFeatureTiles(width: width - pagePadding * 2)
                .padding(.horizontal, pagePadding)

            if !displayHomeData.banners.isEmpty {
                MangaPlatformBannerCarousel(banners: displayHomeData.banners, availableWidth: width - pagePadding * 2) { banner in
                    handleBannerTap(banner)
                }
                .padding(.horizontal, pagePadding)
            } else if !editorialSongs.isEmpty {
                MangaEditorialCarousel(songs: editorialSongs, availableWidth: width - pagePadding * 2) { song in
                    playerManager.play(song: song, in: editorialSongs)
                }
                .padding(.horizontal, pagePadding)
            }

            mangaRecommendationSection
                .padding(.top, displayHomeData.banners.isEmpty && editorialSongs.isEmpty ? 0 : -1)

            if !displayHomeData.recommendPlaylists.isEmpty {
                mangaPlaylistSection(
                    title: String(localized: "推荐歌单"),
                    playlists: displayHomeData.recommendPlaylists,
                    action: openLibrarySquare
                )
            }

            if !displayHomeData.qqNewSongs.isEmpty {
                mangaNewSongSection(songs: displayHomeData.qqNewSongs)
            }

            if !displayHomeData.qqRecommendPlaylists.isEmpty {
                mangaPlaylistSection(
                    title: String(localized: "qq_recommend_playlists"),
                    playlists: displayHomeData.qqRecommendPlaylists,
                    action: openLibrarySquare
                )
            }

            FloatingBarBottomSpacer(extra: 18)
        }
        .background(MangaComicPalette.ink)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 12)
    }

    private func mangaLeadStory(width: CGFloat) -> some View {
        let layoutScale = min(1, max(0.72, width / 376))
        let height = min(284, max(206, width * 0.60))

        return MangaComicPanel(fill: MangaComicPalette.paper, corner: 18, shadow: 4, innerBorder: true) {
            GeometryReader { proxy in
                let preferredCoverSide = proxy.size.width * (DeviceLayout.isPad ? 0.39 : 0.44)
                let coverSide = min(preferredCoverSide, max(132, proxy.size.height - 30))
                let leftWidth = proxy.size.width - coverSide - 28

                ZStack(alignment: .topLeading) {
                    MangaComicSpeedLines(color: MangaComicPalette.redDeep, opacity: 0.07)
                    MangaComicHalftone(color: MangaComicPalette.redDeep, opacity: 0.035, gap: 11)

                    MangaComicRibbon(
                        text: String(localized: "settings_hitokoto"),
                        fill: MangaComicPalette.red
                    )
                    .offset(x: 11, y: 12)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 7) {
                            Text("“")
                                .font(MangaComicPalette.headlineFont(44 * layoutScale))
                                .foregroundStyle(MangaComicPalette.ink)
                                .frame(width: 27, height: 36, alignment: .top)

                            Text(mangaQuote)
                                .font(MangaComicPalette.displayFont((DeviceLayout.isPad ? 26 : 22) * layoutScale))
                                .foregroundStyle(MangaComicPalette.ink)
                                .lineSpacing(5)
                                .lineLimit(3)
                                .minimumScaleFactor(0.68)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 10) {
                            mangaDateCard(scale: layoutScale)

                            if let song = mangaHeroSong {
                                mangaLeadPlayButton(song)
                            }
                        }
                    }
                    .frame(width: leftWidth, alignment: .leading)
                    .padding(.leading, 20)
                    .padding(.top, 64)
                    .padding(.bottom, 16)

                    if let song = mangaHeroSong {
                        mangaLeadCover(song: song)
                            .frame(width: coverSide, height: coverSide)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .offset(x: -12)
                    } else {
                        mangaEmptyLeadCover
                            .frame(width: coverSide, height: coverSide)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .offset(x: -12)
                    }

                    MangaComicLightningShape()
                        .fill(MangaComicPalette.red)
                        .overlay(MangaComicLightningShape().stroke(MangaComicPalette.ink, lineWidth: 1.5))
                        .frame(width: 50, height: 26)
                        .rotationEffect(.degrees(77))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: 5, y: 6)
                }
            }
        }
        .frame(height: height)
    }

    private var mangaQuote: String {
        let raw = quoteText.isEmpty ? HitokotoFallbackSlogan.text : quoteText
        guard raw.count > 52 else { return raw }
        return String(raw.prefix(51)) + "…"
    }

    private func mangaLeadCover(song: Song) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id

        return Button {
            playHeroSong(song)
        } label: {
            ZStack(alignment: .bottomLeading) {
                MangaComicPalette.violet

                CachedAsyncImage(url: song.coverUrl) {
                    MangaComicPalette.violet
                        .overlay(MangaComicHalftone(color: MangaComicPalette.whiteInk, opacity: 0.08, gap: 8))
                }
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                LinearGradient(
                    colors: [.clear, MangaComicPalette.ink.opacity(0.92)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(MangaComicPalette.headlineFont(15))
                        .foregroundStyle(MangaComicPalette.whiteInk)
                        .lineLimit(2)
                    Text(song.artistName)
                        .font(MangaComicPalette.bodyFont(11, weight: .bold))
                        .foregroundStyle(MangaComicPalette.whiteInk.opacity(0.76))
                        .lineLimit(1)
                }
                .padding(11)
            }
            .clipShape(MangaComicPanelShape(corner: 12))
            .overlay(MangaComicPanelShape(corner: 12).stroke(MangaComicPalette.ink, lineWidth: 3))
            .overlay(MangaComicPanelShape(corner: 12).stroke(MangaComicPalette.whiteInk.opacity(0.78), lineWidth: 1).padding(5))
            .background(MangaComicPanelShape(corner: 12).fill(MangaComicPalette.ink).offset(x: 3, y: 3))
            .overlay(alignment: .topTrailing) {
                ZStack {
                    MangaComicCutCornerShape(cut: 7)
                        .fill(MangaComicPalette.paper)
                    MangaComicCutCornerShape(cut: 7)
                        .stroke(MangaComicPalette.ink, lineWidth: 2)

                    if isCurrent {
                        MangaNowPlayingIndicator(isAnimating: playerManager.isPlaying)
                            .scaleEffect(0.78)
                    } else {
                        MonologueIcon(icon: .chart, size: 17, color: MangaComicPalette.ink, lineWidth: 2.2)
                    }
                }
                .frame(width: 36, height: 38)
                .offset(x: -7, y: 7)
            }
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }

    private var mangaEmptyLeadCover: some View {
        ZStack {
            MangaComicPalette.violet
            MangaComicHalftone(color: MangaComicPalette.whiteInk, opacity: 0.09, gap: 8)
            MonologueIcon(icon: .musicNote, size: 46, color: MangaComicPalette.whiteInk, lineWidth: 2.4)
        }
        .clipShape(MangaComicPanelShape(corner: 12))
        .overlay(MangaComicPanelShape(corner: 12).stroke(MangaComicPalette.ink, lineWidth: 3))
    }

    private func mangaLeadPlayButton(_ song: Song) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id
        let icon: MonologueIcon.IconType = isCurrent && playerManager.isPlaying ? .pause : .play

        return Button {
            playHeroSong(song)
        } label: {
            HStack(spacing: 8) {
                MangaComicCutCornerShape(cut: 5)
                    .fill(MangaComicPalette.red)
                    .frame(width: 27, height: 27)
                    .overlay(MangaComicCutCornerShape(cut: 5).stroke(MangaComicPalette.whiteInk.opacity(0.7), lineWidth: 1))
                    .overlay(MonologueIcon(icon: icon, size: 11, color: MangaComicPalette.whiteInk, lineWidth: 2.2))

                Text(String(localized: "action_play"))
                    .font(MangaComicPalette.headlineFont(14))
                    .foregroundStyle(MangaComicPalette.whiteInk)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(MangaComicPanelShape(corner: 9).fill(MangaComicPalette.ink))
            .overlay(MangaComicPanelShape(corner: 9).stroke(MangaComicPalette.paper, lineWidth: 1).padding(4))
            .overlay(MangaComicPanelShape(corner: 9).stroke(MangaComicPalette.ink, lineWidth: 2.4))
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }

    private func mangaDateCard(scale: CGFloat) -> some View {
        let date = Date()
        let day = Calendar.current.component(.day, from: date)
        let weekdayIndex = max(0, Calendar.current.component(.weekday, from: date) - 1)
        let weekday = Calendar.current.shortWeekdaySymbols[weekdayIndex]

        return HStack(spacing: 8) {
            Text("\(day)")
                .font(MangaComicPalette.headlineFont(28 * scale))
                .foregroundStyle(MangaComicPalette.red)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 1) {
                Text(weekday)
                    .font(MangaComicPalette.headlineFont(11 * scale))
                Text(mangaSecondaryDateText)
                    .font(MangaComicPalette.bodyFont(9 * scale, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(MangaComicPalette.ink)
        }
        .padding(.horizontal, 10 * scale)
        .frame(width: 96 * scale, height: 50 * scale)
        .background {
            MangaComicPanelShape(corner: 8 * scale)
                .fill(MangaComicPalette.paper)
                .overlay {
                    MangaComicPaperTexture(opacity: 0.07)
                        .clipShape(MangaComicPanelShape(corner: 8 * scale))
                }
        }
        .overlay {
            MangaComicPanelShape(corner: 8 * scale)
                .stroke(MangaComicPalette.ink, lineWidth: 2.2 * scale)
        }
        .overlay(alignment: .top) {
            HStack(spacing: 9 * scale) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    Capsule()
                        .fill(MangaComicPalette.ink)
                        .frame(width: 2.5 * scale, height: 8 * scale)
                }
            }
            .offset(y: -3.5 * scale)
        }
    }

    private var mangaSecondaryDateText: String {
        let date = Date()
        if Locale.preferredLanguages.first?.hasPrefix("zh") == true {
            let month = Calendar.current.component(.month, from: date)
            return "\(month)月"
        }
        return Calendar.current.shortMonthSymbols[Calendar.current.component(.month, from: date) - 1].uppercased()
    }

    private func mangaFeatureTiles(width: CGFloat) -> some View {
        let layoutScale = min(1, max(0.72, width / 376))

        return HStack(spacing: 8 * layoutScale) {
            MangaComicFeatureTile(
                icon: .musicNoteList,
                title: String(localized: "new_song_express"),
                subtitle: String(localized: "manga_tile_new_song_sub"),
                fill: MangaComicPalette.red,
                foreground: MangaComicPalette.whiteInk,
                badge: "NEW!"
            ) {
                navigationPath.append(HomeView.HomeDestination.newSongExpress)
            }

            MangaComicFeatureTile(
                icon: .mv,
                title: String(localized: "home_mv_zone"),
                subtitle: String(localized: "manga_tile_mv_sub"),
                fill: MangaComicPalette.paper,
                foreground: MangaComicPalette.ink
            ) {
                navigationPath.append(HomeView.HomeDestination.mvDiscover)
            }

            MangaComicFeatureTile(
                icon: .moon,
                title: String(localized: "meditation_mode_title"),
                subtitle: String(localized: "manga_tile_meditation_sub"),
                fill: MangaComicPalette.navy,
                foreground: MangaComicPalette.whiteInk
            ) {
                navigationPath.append(HomeView.HomeDestination.meditationMode)
            }
        }
        .frame(height: (DeviceLayout.isPad ? 98 : 78) * layoutScale)
    }

    private var mangaRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            MangaComicSectionHeader(
                title: String(localized: "每日推荐"),
                actionTitle: String(localized: "view_all")
            ) {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            }
            .padding(.horizontal, 12)

            if displayHomeData.dailySongs.isEmpty {
                mangaLoadingPanel
                    .padding(.horizontal, 12)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 11) {
                        ForEach(Array(displayHomeData.dailySongs.prefix(10).enumerated()), id: \.element.id) { index, song in
                            MangaComicSongPoster(song: song, index: index) {
                                playerManager.play(song: song, in: displayHomeData.dailySongs)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 7)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 15)
        .background {
            ZStack {
                MangaComicPalette.paper
                MangaComicPaperTexture(opacity: 0.11)
            }
        }
    }

    private var mangaLoadingPanel: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(MangaComicPalette.red)
            Text("...")
                .font(MangaComicPalette.headlineFont(18))
                .foregroundStyle(MangaComicPalette.ink)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(MangaComicPanelShape(corner: 12).fill(MangaComicPalette.paperWarm))
        .overlay(MangaComicPanelShape(corner: 12).stroke(MangaComicPalette.ink, lineWidth: 2.4))
    }

    private func mangaPlaylistSection(
        title: String,
        playlists: [Playlist],
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            MangaComicSectionHeader(
                title: title,
                actionTitle: String(localized: "view_all"),
                action: action
            )

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(playlists.prefix(10).enumerated()), id: \.element.id) { index, playlist in
                        MangaComicPlaylistPoster(playlist: playlist, index: index) {
                            navigationPath.append(HomeView.HomeDestination.playlist(playlist))
                        }
                    }
                }
                .padding(.bottom, 6)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 15)
        .background {
            ZStack {
                MangaComicPalette.paper
                MangaComicPaperTexture(opacity: 0.1)
            }
        }
    }

    private func mangaNewSongSection(songs: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaComicSectionHeader(
                title: String(localized: "new_song_express"),
                actionTitle: String(localized: "view_all")
            ) {
                navigationPath.append(HomeView.HomeDestination.newSongExpress)
            }

            VStack(spacing: 8) {
                ForEach(Array(songs.prefix(5).enumerated()), id: \.element.id) { index, song in
                    MangaComicSongRow(song: song, rank: index + 1, isCurrent: playerManager.currentSong?.id == song.id) {
                        playerManager.play(song: song, in: songs)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 15)
        .background(MangaComicPalette.paper)
    }

    private var mangaHeroSong: Song? {
        playerManager.currentSong
            ?? playerManager.history.first
            ?? displayHomeData.dailySongs.first
            ?? displayHomeData.qqNewSongs.first
    }

    private var editorialSongs: [Song] {
        let candidates = displayHomeData.qqNewSongs.isEmpty
            ? displayHomeData.dailySongs
            : displayHomeData.qqNewSongs
        return Array(candidates.prefix(6))
    }

    private func playHeroSong(_ song: Song) {
        let queue = displayHomeData.dailySongs
        if queue.contains(where: { $0.id == song.id }) {
            playerManager.play(song: song, in: queue)
        } else {
            playerManager.playSingle(song: song)
        }
    }

    private var mangaCoverTitle: String {
        let name = viewModel.userProfile?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "default_nickname") : name
    }

    private var mangaGreetingText: String {
        MonologueTimeGreeting.localizedText
    }

    private var displayHomeData: MangaHomeDataSnapshot {
        MangaHomeDataSnapshot(
            dailySongs: firstNonEmpty(
                nonEmpty(viewModel.dailySongs, cacheKey: "daily_songs", type: [Song].self),
                nonEmpty(viewModel.popularSongs, cacheKey: "popular_songs", type: [Song].self)
            ),
            banners: nonEmpty(viewModel.banners, cacheKey: "banners", type: [Banner].self),
            recommendPlaylists: nonEmpty(viewModel.recommendPlaylists, cacheKey: "recommend_playlists", type: [Playlist].self),
            qqRecommendPlaylists: nonEmpty(viewModel.qqRecommendPlaylists, cacheKey: "qq_recommend_playlists", type: [Playlist].self),
            qqNewSongs: nonEmpty(viewModel.qqNewSongs, cacheKey: "qq_new_songs", type: [Song].self)
        )
    }

    private func nonEmpty<T: Codable>(_ source: [T], cacheKey: String, type: [T].Type) -> [T] {
        source.isEmpty
            ? (OptimizedCacheManager.shared.getObject(forKey: cacheKey, type: type) ?? [])
            : source
    }

    private func firstNonEmpty<T>(_ candidates: [T]...) -> [T] {
        candidates.first(where: { !$0.isEmpty }) ?? []
    }

    private func openLibrarySquare() {
        UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
        NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
    }

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run {
                            playerManager.play(song: song, in: songs)
                        }
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
            if let urlText = banner.url, let url = URL(string: urlText) {
                bannerWebURL = url
            }
        }
    }

    @ViewBuilder
    private func mangaDestination(for destination: HomeView.HomeDestination) -> some View {
        switch destination {
        case .search:
            SearchView()
        case .dailyRecommend:
            DailyRecommendView()
        case .playlist(let playlist):
            PlaylistDetailView(playlist: playlist)
        case let .bannerPlaylist(playlist, bannerImage):
            PlaylistDetailView(playlist: playlist, bannerCoverURLString: bannerImage)
        case .artist(let id):
            ArtistDetailView(artistId: id)
        case .album(let id):
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

// MARK: - Masthead pieces

private struct MangaComicUnderline: View {
    var body: some View {
        Canvas { context, size in
            var black = Path()
            black.move(to: CGPoint(x: 0, y: size.height * 0.56))
            black.addLine(to: CGPoint(x: size.width * 0.56, y: size.height * 0.46))
            black.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.64))
            black.addLine(to: CGPoint(x: size.width, y: size.height * 0.1))
            context.stroke(black, with: .color(MangaComicPalette.ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))

            var red = Path()
            red.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.86))
            red.addLine(to: CGPoint(x: size.width * 0.58, y: size.height * 0.68))
            red.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.97))
            red.addLine(to: CGPoint(x: size.width * 0.84, y: size.height * 0.28))
            context.stroke(red, with: .color(MangaComicPalette.red), style: StrokeStyle(lineWidth: 4, lineCap: .square, lineJoin: .miter))
        }
        .allowsHitTesting(false)
    }
}

private struct MangaComicMastheadAction: View {
    let icon: MonologueIcon.IconType
    let title: String
    let fill: Color
    var scale: CGFloat = 1
    let action: () -> Void

    private var foreground: Color {
        fill == MangaComicPalette.red ? MangaComicPalette.whiteInk : MangaComicPalette.ink
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                MonologueIcon(icon: icon, size: 23 * scale, color: foreground, lineWidth: 2.5 * scale)
                    .frame(height: 27 * scale)
                Text(title)
                    .font(MangaComicPalette.headlineFont(10.5 * scale))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(
                width: (DeviceLayout.isPad ? 70 : 52) * scale,
                height: (DeviceLayout.isPad ? 72 : 60) * scale
            )
            .background(MangaComicCutCornerShape(cut: 8).fill(fill))
            .overlay(MangaComicPaperTexture(ink: foreground, opacity: 0.05).clipShape(MangaComicCutCornerShape(cut: 8)))
            .overlay(MangaComicCutCornerShape(cut: 8).stroke(MangaComicPalette.ink, lineWidth: 3))
            .background(MangaComicCutCornerShape(cut: 8).fill(MangaComicPalette.ink).offset(x: 3, y: 3))
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }
}

// MARK: - Front-page modules

private struct MangaPlatformBannerCarousel: View {
    let banners: [Banner]
    let availableWidth: CGFloat
    let onTap: (Banner) -> Void

    @State private var index = 0
    private let timer = Timer.publish(every: 5.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let bannerHeight = DeviceLayout.isPad
            ? min(178, max(142, availableWidth / 3.5))
            : min(140, max(112, availableWidth / 2.9))

        VStack(spacing: 7) {
            TabView(selection: $index) {
                ForEach(Array(banners.prefix(6).enumerated()), id: \.element.id) { offset, banner in
                    MangaPlatformBannerCard(banner: banner) {
                        onTap(banner)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: bannerHeight)
            .onReceive(timer) { _ in
                let count = min(banners.count, 6)
                guard count > 1 else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    index = (index + 1) % count
                }
            }
            .onChange(of: banners.count) { _, count in
                index = min(index, max(0, min(count, 6) - 1))
            }

            HStack(spacing: 8) {
                ForEach(0 ..< min(banners.count, 6), id: \.self) { dot in
                    Capsule()
                        .fill(dot == index ? MangaComicPalette.red : MangaComicPalette.ink.opacity(0.5))
                        .overlay(Capsule().stroke(MangaComicPalette.ink, lineWidth: dot == index ? 1.3 : 0))
                        .frame(width: dot == index ? 20 : 10, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            .background(MangaComicPalette.paper)
        }
        .padding(.top, 2)
        .background(MangaComicPalette.ink)
    }
}

private struct MangaPlatformBannerCard: View {
    let banner: Banner
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MangaComicPanel(fill: MangaComicPalette.violet, corner: 14, shadow: 3, innerBorder: true) {
                ZStack(alignment: .bottomLeading) {
                    HomeBannerArtwork(url: banner.imageUrl, cornerRadius: 12) {
                        MangaComicPalette.violet
                            .overlay(MangaComicHalftone(color: MangaComicPalette.whiteInk, opacity: 0.08, gap: 8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    LinearGradient(
                        colors: [.clear, MangaComicPalette.ink.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    if let title = banner.typeTitle, !title.isEmpty {
                        MangaComicRibbon(text: title, fill: MangaComicPalette.red)
                            .scaleEffect(0.76, anchor: .leading)
                            .padding(16)
                    }
                }
            }
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }
}

private struct MangaComicFeatureTile: View {
    let icon: MonologueIcon.IconType
    let title: String
    let subtitle: String
    let fill: Color
    let foreground: Color
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                let tileScale = min(1, max(0.68, proxy.size.width / 112))

                ZStack(alignment: .leading) {
                    let panelShape = MangaComicPanelShape(corner: 12)

                    panelShape.fill(fill)

                    if icon == .moon {
                        Image("MangaMeditationBackdrop")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .clipShape(panelShape)
                            .overlay(MangaComicPalette.ink.opacity(0.18).clipShape(panelShape))
                    } else {
                        MangaComicSpeedLines(
                            color: fill == MangaComicPalette.paper ? MangaComicPalette.redDeep : MangaComicPalette.ink,
                            opacity: fill == MangaComicPalette.paper ? 0.055 : 0.1
                        )
                        .clipShape(panelShape)
                    }

                    MangaComicHalftone(color: foreground, opacity: 0.06, gap: 7)
                        .clipShape(MangaComicPanelShape(corner: 12))

                    HStack(spacing: 8) {
                        ZStack {
                            MangaComicCutCornerShape(cut: 6)
                                .fill(fill == MangaComicPalette.paper ? MangaComicPalette.red : MangaComicPalette.paper)
                                .overlay(MangaComicCutCornerShape(cut: 6).stroke(MangaComicPalette.ink, lineWidth: 1.8))
                            MonologueIcon(
                                icon: icon,
                                size: min(24 * tileScale, proxy.size.width * 0.2),
                                color: MangaComicPalette.ink,
                                lineWidth: 2.2 * tileScale
                            )
                        }
                        .frame(width: 39 * tileScale, height: 43 * tileScale)
                        .rotationEffect(.degrees(-4))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(MangaComicPalette.headlineFont((DeviceLayout.isPad ? 16 : 13) * tileScale))
                                .foregroundStyle(foreground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.66)
                            Text(subtitle)
                                .font(MangaComicPalette.bodyFont((DeviceLayout.isPad ? 11 : 8.5) * tileScale, weight: .bold))
                                .foregroundStyle(foreground.opacity(0.8))
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                        }
                    }
                    .padding(.horizontal, 9 * tileScale)

                    MangaComicFourPointStar()
                        .fill(fill == MangaComicPalette.paper ? MangaComicPalette.gold : MangaComicPalette.paper)
                        .overlay(MangaComicFourPointStar().stroke(MangaComicPalette.ink, lineWidth: 1.2))
                        .frame(width: 18 * tileScale, height: 18 * tileScale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: -6, y: 5)
                }
                .overlay(MangaComicPanelShape(corner: 12).stroke(MangaComicPalette.ink, lineWidth: 3))
                .background(MangaComicPanelShape(corner: 12).fill(MangaComicPalette.ink).offset(x: 3, y: 3))
                .overlay(alignment: .bottomLeading) {
                    if let badge {
                        Text(badge)
                            .font(MangaComicPalette.headlineFont(11))
                            .foregroundStyle(MangaComicPalette.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MangaComicBurstShape(points: 11, innerRatio: 0.74).fill(MangaComicPalette.paper))
                            .overlay(MangaComicBurstShape(points: 11, innerRatio: 0.74).stroke(MangaComicPalette.ink, lineWidth: 1.7))
                            .rotationEffect(.degrees(-8))
                            .offset(x: -5, y: 7)
                    }
                }
            }
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }
}

private struct MangaEditorialCarousel: View {
    let songs: [Song]
    let availableWidth: CGFloat
    let onTap: (Song) -> Void
    @State private var index = 0
    private let timer = Timer.publish(every: 5.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let bannerHeight = DeviceLayout.isPad
            ? min(178, max(142, availableWidth / 3.5))
            : min(140, max(112, availableWidth / 2.9))

        VStack(spacing: 7) {
            TabView(selection: $index) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { offset, song in
                    MangaEditorialCard(song: song) {
                        onTap(song)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: bannerHeight)
            .onReceive(timer) { _ in
                guard songs.count > 1 else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    index = (index + 1) % songs.count
                }
            }

            HStack(spacing: 8) {
                ForEach(songs.indices, id: \.self) { dot in
                    Capsule()
                        .fill(dot == index ? MangaComicPalette.red : MangaComicPalette.ink.opacity(0.5))
                        .overlay(Capsule().stroke(MangaComicPalette.ink, lineWidth: dot == index ? 1.3 : 0))
                        .frame(width: dot == index ? 20 : 10, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            .background(MangaComicPalette.paper)
        }
        .padding(.top, 2)
        .background(MangaComicPalette.ink)
    }
}

private struct MangaEditorialCard: View {
    let song: Song
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MangaComicPanel(fill: MangaComicPalette.violet, corner: 14, shadow: 3, innerBorder: true) {
                ZStack(alignment: .leading) {
                    CachedAsyncImage(url: song.coverUrl) {
                        MangaComicPalette.violet
                            .overlay(MangaComicHalftone(color: MangaComicPalette.whiteInk, opacity: 0.08, gap: 8))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    LinearGradient(
                        colors: [MangaComicPalette.violet.opacity(0.98), MangaComicPalette.violet.opacity(0.72), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    MangaComicHalftone(color: MangaComicPalette.whiteInk, opacity: 0.07, gap: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.artistName)
                            .font(MangaComicPalette.bodyFont(12, weight: .bold))
                            .foregroundStyle(MangaComicPalette.whiteInk.opacity(0.88))
                            .lineLimit(2)

                        Text(song.name)
                            .font(MangaComicPalette.displayFont(DeviceLayout.isPad ? 36 : 30))
                            .foregroundStyle(MangaComicPalette.whiteInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)

                        MangaComicRibbon(text: String(localized: "new_song_express"), fill: MangaComicPalette.red)
                            .scaleEffect(0.76, anchor: .leading)
                    }
                    .padding(.leading, 23)
                    .padding(.vertical, 17)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                    MangaComicRoundControl(icon: .play, fill: MangaComicPalette.paper, foreground: MangaComicPalette.ink, size: 47)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(18)
                }
            }
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }
}

private struct MangaComicSongPoster: View {
    let song: Song
    let index: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: song.coverUrl) {
                        MangaComicPalette.paperWarm
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: index == 0 ? 142 : 118, height: index == 0 ? 142 : 118)
                    .clipShape(MangaComicPanelShape(corner: 11))

                    MangaComicRoundControl(icon: .play, fill: MangaComicPalette.red, size: 35)
                        .padding(8)
                }
                .overlay(MangaComicPanelShape(corner: 11).stroke(MangaComicPalette.ink, lineWidth: 2.6))
                .background(MangaComicPanelShape(corner: 11).fill(MangaComicPalette.ink).offset(x: 3, y: 3))

                Text(song.name)
                    .font(MangaComicPalette.headlineFont(13))
                    .foregroundStyle(MangaComicPalette.ink)
                    .lineLimit(1)
                    .frame(width: index == 0 ? 142 : 118, alignment: .leading)

                Text(song.artistName)
                    .font(MangaComicPalette.bodyFont(10, weight: .bold))
                    .foregroundStyle(MangaComicPalette.mutedInk)
                    .lineLimit(1)
                    .frame(width: index == 0 ? 142 : 118, alignment: .leading)
            }
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }
}

private struct MangaComicPlaylistPoster: View {
    let playlist: Playlist
    let index: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                CachedAsyncImage(url: playlist.coverUrl) {
                    MangaComicPalette.paperWarm
                        .overlay(MangaComicHalftone(opacity: 0.08, gap: 8))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 126, height: 126)
                .clipShape(MangaComicPanelShape(corner: 11))
                .overlay(MangaComicPanelShape(corner: 11).stroke(MangaComicPalette.ink, lineWidth: 2.6))
                .background(
                    MangaComicPanelShape(corner: 11)
                        .fill(index.isMultiple(of: 2) ? MangaComicPalette.red : MangaComicPalette.navy)
                        .offset(x: 4, y: 4)
                )

                Text(playlist.name)
                    .font(MangaComicPalette.headlineFont(13))
                    .foregroundStyle(MangaComicPalette.ink)
                    .lineLimit(2)
                    .frame(width: 126, alignment: .leading)
            }
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }
}

private struct MangaComicSongRow: View {
    let song: Song
    let rank: Int
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Text(String(format: "%02d", rank))
                    .font(MangaComicPalette.headlineFont(15))
                    .foregroundStyle(rank <= 3 ? MangaComicPalette.red : MangaComicPalette.mutedInk)
                    .monospacedDigit()

                CachedAsyncImage(url: song.coverUrl) {
                    MangaComicPalette.paperWarm
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(MangaComicCutCornerShape(cut: 6))
                .overlay(MangaComicCutCornerShape(cut: 6).stroke(MangaComicPalette.ink, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(MangaComicPalette.headlineFont(14))
                        .foregroundStyle(isCurrent ? MangaComicPalette.red : MangaComicPalette.ink)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(MangaComicPalette.bodyFont(10, weight: .bold))
                        .foregroundStyle(MangaComicPalette.mutedInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MangaComicRoundControl(icon: isCurrent ? .pause : .play, fill: MangaComicPalette.red, size: 34)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(MangaComicPanelShape(corner: 11).fill(MangaComicPalette.paperWarm))
            .overlay(MangaComicPanelShape(corner: 11).stroke(MangaComicPalette.ink, lineWidth: 2.3))
        }
        .buttonStyle(MangaComicPressButtonStyle())
    }
}

private struct MangaHomeDataSnapshot {
    var dailySongs: [Song] = []
    var banners: [Banner] = []
    var recommendPlaylists: [Playlist] = []
    var qqRecommendPlaylists: [Playlist] = []
    var qqNewSongs: [Song] = []
}
