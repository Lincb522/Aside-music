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
    @State private var appeared = false

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)

                if viewModel.isLoading {
                    mangaLoadingView
                } else {
                    scrollBody
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                showHomeContentIfNeeded()
                hydrateHome(reason: "manga appear")
            }
            .task {
                showHomeContentIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                hydrateHome(reason: "manga foreground")
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { dest in
                mangaDestination(for: dest)
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

    private func showHomeContentIfNeeded() {
        guard !appeared else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
            appeared = true
        }
    }

    private func hydrateHome(reason: String) {
        viewModel.ensureHomeDataLoaded(reason: reason)
        if hitokotoEnabled,
           viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            viewModel.refreshHitokoto()
        }
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 20) {
                mangaTopBar
                    .mangaStagger(appeared, order: 0)

                mangaHeroPanel
                    .padding(.horizontal, mangaHomeFeatureHorizontalPadding)
                    .mangaStagger(appeared, order: 1)

                if !viewModel.banners.isEmpty {
                    mangaBannerSection
                        .mangaStagger(appeared, order: 2)
                }

                if !viewModel.dailySongs.isEmpty {
                    mangaDailySection
                        .mangaStagger(appeared, order: 3)
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    mangaPlaylistSection(
                        title: String(localized: "推荐歌单"),
                        playlists: viewModel.recommendPlaylists,
                        tint: MangaStyle.labelYellow
                    )
                    .mangaStagger(appeared, order: 4)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    mangaNewSongsSection
                        .mangaStagger(appeared, order: 5)
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    mangaDiscoverySection
                        .mangaStagger(appeared, order: 6)
                }

                mangaEntryCards
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .mangaStagger(appeared, order: 7)

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 6)
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

    private var mangaTopBar: some View {
        HStack(spacing: 12) {
            Button {
                NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
            } label: {
                mangaAvatarView
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                MangaLabel(text: mangaGreetingText, tint: MangaStyle.labelYellow, small: true)

                Text(viewModel.userProfile?.nickname ?? String(localized: "default_nickname"))
                    .font(MangaStyle.titleFont(22, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 12)

            MangaActionButton(icon: .radio, tint: MangaStyle.bubbleBlue, foreground: MangaStyle.ink) {
                showPersonalFM = true
            }

            MangaActionButton(icon: .magnifyingGlass, tint: MangaStyle.bubblePink, foreground: MangaStyle.ink) {
                navigationPath.append(HomeView.HomeDestination.search)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var mangaLoadingView: some View {
        VStack(spacing: 16) {
            MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 52)
                .frame(width: 52, height: 52)

            Text("...")
                .font(MangaStyle.titleFont(24, weight: .black))
                .foregroundColor(MangaStyle.inkSub)
        }
    }

    @ViewBuilder
    private var mangaAvatarView: some View {
        let size: CGFloat = 46
        Group {
            if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) {
                    MangaStyle.labelYellow.opacity(0.35)
                }
                .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    MangaStyle.labelYellow.opacity(0.75)
                    MonologueIcon(icon: .profileFilled, size: 18, color: MangaStyle.strokeInk, lineWidth: 1.8)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var mangaHeroPanel: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                MangaLabel(text: hitokotoLabel, tint: MangaStyle.accentPink, small: true)

                Text(mangaHeaderLine)
                    .font(MangaStyle.titleFont(24, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 58, alignment: .leading)
                    .layoutPriority(1)

                HStack(spacing: 8) {
                    mangaDateBadge

                    if let featuredSong = mangaHeroSong {
                        Button {
                            playHeroSong(featuredSong)
                        } label: {
                            HStack(spacing: 6) {
                                MonologueIcon(
                                    icon: playerManager.currentSong?.id == featuredSong.id && playerManager.isPlaying ? .pause : .play,
                                    size: 11,
                                    color: MangaStyle.strokeInk,
                                    lineWidth: 2
                                )
                                Text(String(localized: "action_play"))
                                    .font(MangaStyle.labelFont(11, weight: .black))
                            }
                            .foregroundStyle(MangaStyle.strokeInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(MangaStyle.labelYellow))
                            .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let featuredSong = mangaHeroSong {
                mangaHeroCover(song: featuredSong)
            }
        }
        .padding(16)
        .background(
            MangaCardBackground(
                cornerRadius: 20,
                elevated: true,
                tint: MangaStyle.bubbleWhite
            )
        )
    }

    private func mangaHeroCover(song: Song) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id

        return Button {
            playHeroSong(song)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: song.coverUrl) {
                    MangaStyle.decoBlue.opacity(0.35)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 118, height: 148)
                .clipped()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(MangaStyle.bodyFont(11, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(song.artistName)
                        .font(MangaStyle.bodyFont(9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                .padding(9)

                if isCurrent {
                    MangaNowPlayingIndicator(isAnimating: playerManager.isPlaying)
                        .scaleEffect(0.76, anchor: .topTrailing)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: 118, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: isCurrent ? 3 : MangaStyle.strokeWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MangaStyle.strokeInk)
                    .offset(x: 3, y: 3)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle())
        .rotationEffect(.degrees(-2.5))
    }

    private var mangaHeroSong: Song? {
        playerManager.currentSong ?? playerManager.history.first ?? viewModel.dailySongs.first
    }

    private func playHeroSong(_ song: Song) {
        if playerManager.currentSong?.id == song.id {
            playerManager.playSingle(song: song)
        } else if viewModel.dailySongs.contains(where: { $0.id == song.id }) {
            playerManager.play(song: song, in: viewModel.dailySongs)
        } else {
            playerManager.playSingle(song: song)
        }
    }

    private var mangaDateBadge: some View {
        let day = Calendar.current.component(.day, from: Date())
        let weekday = Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]

        return HStack(spacing: 5) {
            Text("\(day)")
                .font(MangaStyle.titleFont(18, weight: .black))
            Text(weekday)
                .font(MangaStyle.labelFont(10, weight: .black))
        }
        .foregroundStyle(MangaStyle.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(MangaStyle.bubbleBlue))
        .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
    }

    private var mangaDailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(
                title: String(localized: "每日推荐"),
                actionTitle: String(localized: "view_all"),
                mark: .heart
            ) {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(viewModel.dailySongs.prefix(10).enumerated()), id: \.element.id) { index, song in
                        mangaSongPanel(song, index: index)
                            .scrollTransition(.animated(.spring(response: 0.32, dampingFraction: 0.82))) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                    .opacity(phase.isIdentity ? 1 : 0.72)
                                    .rotationEffect(.degrees(phase.isIdentity ? 0 : phase.value * -1.8))
                            }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private var mangaBannerSection: some View {
        MangaHomeBannerSection(banners: viewModel.banners) { banner in
            handleBannerTap(banner)
        }
        .padding(.horizontal, mangaHomeFeatureHorizontalPadding)
    }

    private var mangaHomeFeatureHorizontalPadding: CGFloat {
        DeviceLayout.isPad ? DeviceLayout.homeHorizontalPadding : 12
    }

    private func mangaSongPanel(_ song: Song, index: Int) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id
        let width: CGFloat = index == 0 ? 152 : 126
        let height: CGFloat = index == 0 ? 186 : 166

        return Button {
            playerManager.play(song: song, in: viewModel.dailySongs)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(url: song.coverUrl) {
                        MangaStyle.paperCool
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height - 52)
                    .clipped()

                    if isCurrent {
                        MangaNowPlayingIndicator(isAnimating: playerManager.isPlaying)
                            .scaleEffect(0.72, anchor: .topTrailing)
                            .padding(7)
                    } else {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(MangaStyle.strokeInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(MangaStyle.labelYellow))
                            .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1))
                            .padding(7)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(MangaStyle.bodyFont(12, weight: .black))
                        .foregroundStyle(MangaStyle.ink)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(MangaStyle.bodyFont(10, weight: .bold))
                        .foregroundStyle(MangaStyle.inkSub)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .frame(width: width, alignment: .leading)
                .background(MangaStyle.bubbleWhite)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: isCurrent ? 3 : MangaStyle.strokeWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MangaStyle.strokeInk)
                    .offset(x: 2.5, y: 2.5)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    private var mangaNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(
                title: String(localized: "qq_new_songs"),
                actionTitle: String(localized: "view_all"),
                mark: .star,
                action: { navigationPath.append(HomeView.HomeDestination.qcmNewSongs) }
            )
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(viewModel.qqNewSongs.prefix(8).enumerated()), id: \.element.id) { index, song in
                        mangaNewSongCard(song, rank: index + 1)
                            .scrollTransition(.animated(.spring(response: 0.32, dampingFraction: 0.82))) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                    .opacity(phase.isIdentity ? 1 : 0.66)
                            }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func mangaNewSongCard(_ song: Song, rank: Int) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id

        return Button {
            playerManager.play(song: song, in: viewModel.qqNewSongs)
        } label: {
            HStack(spacing: 10) {
                ZStack(alignment: .topLeading) {
                    CachedAsyncImage(url: song.coverUrl) {
                        MangaStyle.paperCool
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipped()

                    MangaLabel(text: "\(rank)", tint: MangaStyle.bubblePink, small: true, foreground: MangaStyle.ink)
                        .padding(5)

                    if isCurrent {
                        MangaNowPlayingIndicator(isAnimating: playerManager.isPlaying)
                            .scaleEffect(0.62, anchor: .bottomTrailing)
                            .padding(5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))

                VStack(alignment: .leading, spacing: 5) {
                    Text(song.name)
                        .font(MangaStyle.bodyFont(13, weight: .black))
                        .foregroundStyle(isCurrent ? MangaStyle.accentPink : MangaStyle.ink)
                        .lineLimit(2)

                    Text(song.artistName)
                        .font(MangaStyle.bodyFont(10, weight: .bold))
                        .foregroundStyle(MangaStyle.inkSub)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)
            }
            .padding(9)
            .frame(width: 216, alignment: .leading)
            .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: rank.isMultiple(of: 2) ? MangaStyle.bubbleBlue : MangaStyle.bubbleWhite))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    private func mangaPlaylistSection(
        title: String,
        playlists: [Playlist],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(
                title: title,
                actionTitle: String(localized: "view_all"),
                mark: .star,
                action: openLibrarySquare
            )
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(Array(playlists.prefix(6).enumerated()), id: \.element.id) { index, playlist in
                    mangaPlaylistCard(playlist, index: index, tint: index.isMultiple(of: 2) ? tint : MangaStyle.bubbleBlue)
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    private func mangaPlaylistCard(_ playlist: Playlist, index: Int, tint: Color) -> some View {
        Button {
            navigationPath.append(HomeView.HomeDestination.playlist(playlist))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(url: playlist.coverUrl) {
                        MangaStyle.separator.opacity(0.3)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: index == 0 ? 136 : 118)
                    .clipped()

                    MangaLabel(text: String(format: "%02d", index + 1), tint: tint, small: true)
                        .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                )

                Text(playlist.name)
                    .font(MangaStyle.bodyFont(13, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 34, alignment: .topLeading)
            }
            .padding(9)
            .background(MangaCardBackground(cornerRadius: 14, elevated: true))
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    private var mangaDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(
                title: String(localized: "更多发现"),
                actionTitle: String(localized: "view_all"),
                mark: .star,
                action: openLibrarySquare
            )
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            VStack(spacing: 10) {
                ForEach(Array(viewModel.qqRecommendPlaylists.prefix(6).enumerated()), id: \.element.id) { index, playlist in
                    mangaDiscoveryRow(playlist, index: index)
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    private func mangaDiscoveryRow(_ playlist: Playlist, index: Int) -> some View {
        Button {
            navigationPath.append(HomeView.HomeDestination.playlist(playlist))
        } label: {
            HStack(spacing: 11) {
                CachedAsyncImage(url: playlist.coverUrl) {
                    MangaStyle.decoBlue.opacity(0.28)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.name)
                        .font(MangaStyle.bodyFont(14, weight: .black))
                        .foregroundStyle(MangaStyle.ink)
                        .lineLimit(2)

                    MangaListDivider()
                }

                Spacer(minLength: 8)

                MonologueIcon(icon: .chevronRight, size: 13, color: MangaStyle.ink, lineWidth: 1.8)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(index.isMultiple(of: 2) ? MangaStyle.bubblePink : MangaStyle.bubbleBlue))
                    .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
            }
            .padding(10)
            .background(
                MangaCardBackground(
                    cornerRadius: 16,
                    elevated: true,
                    tint: index.isMultiple(of: 2) ? MangaStyle.bubbleWhite : MangaStyle.surface
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    private var mangaEntryCards: some View {
        HStack(spacing: 12) {
            MangaHomeEntryCard(
                icon: .musicNoteList,
                title: String(localized: "new_song_express"),
                tint: MangaStyle.labelYellow,
                foreground: MangaStyle.strokeInk,
                angle: -1.6
            ) {
                navigationPath.append(HomeView.HomeDestination.newSongExpress)
            }

            MangaHomeEntryCard(
                icon: .mv,
                title: String(localized: "home_mv_zone"),
                tint: MangaStyle.bubblePink,
                angle: 1.4
            ) {
                navigationPath.append(HomeView.HomeDestination.mvDiscover)
            }
        }
    }

    private var mangaHeaderLine: String {
        guard hitokotoEnabled else { return "Monologue" }

        if let hitokoto = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hitokoto.isEmpty {
            return hitokoto
        }

        return "Monologue"
    }

    private var hitokotoLabel: String {
        hitokotoEnabled ? String(localized: "settings_hitokoto") : "Monologue"
    }

    private var mangaGreetingText: String {
        MonologueTimeGreeting.localizedText
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
                            PlayerManager.shared.play(song: song, in: [song])
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
            if let urlString = banner.url, let url = URL(string: urlString) {
                bannerWebURL = url
            }
        }
    }

    @ViewBuilder
    private func mangaDestination(for dest: HomeView.HomeDestination) -> some View {
        switch dest {
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
        }
    }
}

private struct MangaHomeBannerSection: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var index = 0
    private let timer = Timer.publish(every: 5.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $index) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { offset, banner in
                    MangaHomeBannerCard(banner: banner) {
                        onTap(banner)
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 5)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: DeviceLayout.isPad ? 214 : 154)
            .onReceive(timer) { _ in
                guard banners.count > 1 else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    index = (index + 1) % banners.count
                }
            }

            if banners.count > 1 {
                HStack(spacing: 6) {
                    ForEach(banners.indices, id: \.self) { dot in
                        Capsule()
                            .fill(dot == index ? MangaStyle.ink : MangaStyle.ink.opacity(0.22))
                            .frame(width: dot == index ? 18 : 7, height: 7)
                            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: index)
                    }
                }
            }
        }
    }
}

private struct MangaHomeBannerCard: View {
    let banner: Banner
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: banner.imageUrl) {
                    MangaStyle.paperCool
                        .overlay(MangaDotsTexture(opacity: 0.06, gap: 10))
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: DeviceLayout.isPad ? 186 : 126)
                .clipped()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.68)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 8) {
                    MangaLabel(text: bannerLabel, tint: MangaStyle.labelYellow, small: true)
                    Spacer(minLength: 8)
                    MonologueIcon(icon: .chevronRight, size: 13, color: MangaStyle.ink, lineWidth: 2)
                        .frame(width: 30, height: 30)
                        .background(MangaStyle.bubbleWhite, in: Circle())
                    .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                }
                .padding(11)
            }
            .frame(height: DeviceLayout.isPad ? 186 : 126)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MangaStyle.strokeInk)
                    .offset(x: 3, y: 3)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }

    private var bannerLabel: String {
        if let typeTitle = banner.typeTitle, !typeTitle.isEmpty {
            return typeTitle
        }

        switch banner.targetType {
        case 1:
            return "SONG"
        case 10:
            return String(localized: "artist_tab_album")
        case 1000:
            return String(localized: "home_playlist")
        default:
            return "BANNER"
        }
    }
}

private struct MangaHomeEntryCard: View {
    let icon: MonologueIcon.IconType
    let title: String
    let tint: Color
    var foreground: Color = MangaStyle.ink
    let angle: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(tint)
                        MonologueIcon(icon: icon, size: 20, color: foreground, lineWidth: 2)
                    }
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))

                    Spacer()

                    MonologueIcon(icon: .chevronRight, size: 12, color: MangaStyle.ink, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .background(MangaStyle.bubbleWhite, in: Circle())
                        .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                }

                Spacer(minLength: 4)

                Text(title)
                    .font(MangaStyle.titleFont(16, weight: .black))
                    .foregroundStyle(foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DeviceLayout.entryCardHeight)
            .background(
                MangaCardBackground(
                    cornerRadius: 18,
                    elevated: true,
                    tint: tint.opacity(0.9)
                )
            )
            .rotationEffect(.degrees(angle))
        }
        .buttonStyle(.plain)
    }
}
