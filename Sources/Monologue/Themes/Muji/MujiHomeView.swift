import SwiftUI

/// 无印良品版首页 — 极简杂志式排版，大量留白，衬线字体，纸质感
struct MujiHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true
    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var textPrimary: Color {
        MujiStyle.ink
    }

    private var textSecondary: Color {
        MujiStyle.inkSoft
    }

    private var accent: Color {
        MujiStyle.clay
    }

    private var separator: Color {
        MujiStyle.separator
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)

                if viewModel.isLoading {
                    mujiLoadingView
                } else {
                    scrollBody
                }
            }
            .onAppear {
                viewModel.ensureHomeDataLoaded(reason: "muji home appear")
                if hitokotoEnabled,
                   viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    viewModel.refreshHitokoto()
                }
                if !appeared {
                    if reduceMotion {
                        appeared = true
                    } else {
                        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { appeared = true }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
                    }) {
                        mujiAvatarView
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showPersonalFM = true }) {
                            MonologueIcon(icon: .radio, size: 15, color: textSecondary, lineWidth: 1.4)
                                .frame(width: 36, height: 36)
                                .background(MujiStyle.surfaceRaised, in: Circle())
                                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))
                        }
                        Button(action: { navigationPath.append(HomeView.HomeDestination.search) }) {
                            MonologueIcon(icon: .magnifyingGlass, size: 15, color: textSecondary, lineWidth: 1.4)
                                .frame(width: 36, height: 36)
                                .background(MujiStyle.surfaceRaised, in: Circle())
                                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))
                        }
                    }
                }
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { dest in
                mujiDestination(for: dest)
            }
            .fullScreenCover(isPresented: $showPersonalFM) { PersonalFMView() }
            .fullScreenCover(item: $bannerWebURL) { url in MonologueWebView(url: url, title: nil) }
        }
        .themeRenderSceneLayer()
    }

    // MARK: - 加载中

    private var mujiLoadingView: some View {
        VStack(spacing: 20) {
            Text("...")
                .font(MujiStyle.titleFont(28, weight: .light))
                .foregroundColor(textSecondary)
                .tracking(8)
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var mujiAvatarView: some View {
        let size: CGFloat = 36
        if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) {
                Circle().fill(MujiStyle.surfaceRaised)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6))
        } else {
            Circle()
                .fill(MujiStyle.surfaceRaised)
                .frame(width: size, height: size)
                .overlay(MonologueIcon(icon: .profile, size: 16, color: textSecondary))
                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6))
        }
    }

    // MARK: - 主体

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                mujiGreeting
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
                    .mujiStagger(appeared, order: 0, reduceMotion: reduceMotion)

                mujiIntroCard
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)
                    .mujiStagger(appeared, order: 1, reduceMotion: reduceMotion)

                mujiEntryCards
                    .padding(.horizontal, 28)
                    .mujiStagger(appeared, order: 2, reduceMotion: reduceMotion)
                    .padding(.bottom, 34)

                if !viewModel.banners.isEmpty {
                    mujiBannerSection
                        .padding(.horizontal, 12)
                        .padding(.bottom, 34)
                        .mujiStagger(appeared, order: 3, reduceMotion: reduceMotion)
                }

                if !viewModel.dailySongs.isEmpty {
                    mujiDailySection
                        .mujiStagger(appeared, order: 4, reduceMotion: reduceMotion)
                        .padding(.bottom, 36)
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    mujiPlaylistSection(
                        title: String(localized: "推荐歌单"),
                        playlists: viewModel.recommendPlaylists,
                        action: openLibrarySquare
                    )
                    .mujiStagger(appeared, order: 5, reduceMotion: reduceMotion)
                    .padding(.bottom, 36)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    mujiNewSongsSection
                        .mujiStagger(appeared, order: 6, reduceMotion: reduceMotion)
                        .padding(.bottom, 34)
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    mujiPlaylistSection(
                        title: String(localized: "更多发现"),
                        playlists: viewModel.qqRecommendPlaylists,
                        action: openLibrarySquare
                    )
                    .mujiStagger(appeared, order: 7, reduceMotion: reduceMotion)
                    .padding(.bottom, 36)
                }

                FloatingBarBottomSpacer()
            }
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

    private var mujiIntroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                MujiPill(text: hitokotoLabel, tint: MujiStyle.clay)

                Spacer(minLength: 10)

                MonologueIcon(icon: .hitokoto, size: 15, color: MujiStyle.inkMuted, lineWidth: 1.4)
                    .frame(width: 28, height: 28)
                    .background(MujiStyle.surface.opacity(0.74), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.6)
                    )
            }

            HStack(alignment: .top, spacing: 12) {
                MonologueSymbolIcon(name: "quote.opening", size: 16, color: MujiStyle.clay.opacity(0.72))
                    .padding(.top, 2)

                if usesHitokotoFallback {
                    Text(HitokotoFallbackSlogan.text)
                        .font(MujiStyle.bodyFont(18, weight: .regular))
                        .foregroundStyle(textPrimary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 58, alignment: .leading)
                        .layoutPriority(1)
                        .textSelection(.disabled)
                } else {
                    Text(mujiHeaderQuote)
                        .font(MujiStyle.bodyFont(18, weight: .regular))
                        .foregroundStyle(textPrimary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 58, alignment: .leading)
                        .layoutPriority(1)
                        .textSelection(.disabled)
                }
            }

            HStack(spacing: 10) {
                Rectangle()
                    .fill(MujiStyle.separator.opacity(0.78))
                    .frame(width: 42, height: 0.65)

                Text(hitokotoFootnote)
                    .font(MujiStyle.labelFont(9, weight: .semibold))
                    .foregroundStyle(MujiStyle.inkMuted)
                    .tracking(1.4)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 16)
        .mujiCard(cornerRadius: 14, elevated: true)
    }

    private var mujiHeaderQuote: String {
        viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var usesHitokotoFallback: Bool {
        !hitokotoEnabled || mujiHeaderQuote.isEmpty
    }

    private var hitokotoLabel: String {
        String(localized: "settings_hitokoto")
    }

    private var hitokotoFootnote: String {
        "HITOKOTO"
    }

    // MARK: - 问候

    private var mujiGreeting: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let nick = viewModel.userProfile?.nickname {
                Text(nick)
                    .font(MujiStyle.titleFont(28, weight: .regular))
                    .foregroundColor(textPrimary)
                    .tracking(0.5)
            }

            Text(mujiGreetingText)
                .font(MujiStyle.labelFont(11, weight: .medium))
                .foregroundColor(textSecondary)
                .tracking(1.6)
                .textCase(.uppercase)

            Rectangle()
                .fill(separator)
                .frame(width: 36, height: 0.8)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mujiGreetingText: String {
        MonologueTimeGreeting.localizedText
    }

    // MARK: - 每日推荐

    private var mujiDailySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MujiSectionTitle(
                title: String(localized: "每日推荐"),
                actionTitle: String(localized: "view_all"),
                action: { navigationPath.append(HomeView.HomeDestination.dailyRecommend) }
            )
            .padding(.horizontal, 28)

            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    let shouldReduceMotion = reduceMotion
                    ForEach(Array(viewModel.dailySongs.prefix(10).enumerated()), id: \.element.id) { _, song in
                        Button {
                            playerManager.play(song: song, in: viewModel.dailySongs)
                        } label: {
                            mujiSongCard(song)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985, opacity: 0.94))
                        .compatScrollTransition(animation: shouldReduceMotion ? .easeInOut(duration: 0.05) : .easeInOut(duration: 0.24)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : (shouldReduceMotion ? 1 : 0.95))
                                .opacity(phase.isIdentity ? 1 : (shouldReduceMotion ? 1 : 0.7))
                        }
                    }
                }
                .padding(.horizontal, 28)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private var mujiBannerSection: some View {
        MujiHomeBannerSection(banners: viewModel.banners) { banner in
            handleBannerTap(banner)
        }
    }

    private func mujiSongCard(_ song: Song) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id

        return VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: song.coverUrl) {
                RoundedRectangle(cornerRadius: 8).fill(separator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isCurrent ? MujiStyle.clay.opacity(0.72) : MujiStyle.hairline.opacity(0.45), lineWidth: isCurrent ? 0.9 : 0.6)
            }
            .overlay(alignment: .bottomTrailing) {
                if isCurrent {
                    MujiNowPlayingIndicator(isAnimating: playerManager.isPlaying)
                        .padding(7)
                        .transition(.scale(scale: 0.88, anchor: .bottomTrailing).combined(with: .opacity))
                }
            }
            .shadow(color: isCurrent ? MujiStyle.clay.opacity(0.16) : .black.opacity(0.055), radius: isCurrent ? 10 : 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(MujiStyle.bodyFont(12, weight: .regular))
                    .foregroundColor(isCurrent ? accent : textPrimary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(MujiStyle.labelFont(10, weight: .regular))
                    .foregroundColor(textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
        }
    }

    // MARK: - 新歌速递

    private var mujiNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MujiSectionTitle(
                title: String(localized: "qq_new_songs"),
                actionTitle: String(localized: "view_all"),
                action: { navigationPath.append(HomeView.HomeDestination.qcmNewSongs) }
            )
            .padding(.horizontal, 28)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    let shouldReduceMotion = reduceMotion
                    ForEach(Array(viewModel.qqNewSongs.prefix(8).enumerated()), id: \.element.id) { index, song in
                        Button {
                            playerManager.play(song: song, in: viewModel.qqNewSongs)
                        } label: {
                            mujiNewSongCard(song, rank: index + 1)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985, opacity: 0.94))
                        .compatScrollTransition(animation: shouldReduceMotion ? .easeInOut(duration: 0.05) : .easeInOut(duration: 0.24)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : (shouldReduceMotion ? 1 : 0.96))
                                .opacity(phase.isIdentity ? 1 : (shouldReduceMotion ? 1 : 0.72))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func mujiNewSongCard(_ song: Song, rank: Int) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id
        let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return HStack(spacing: 11) {
            CachedAsyncImage(url: song.coverUrl) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(separator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isCurrent ? MujiStyle.clay.opacity(0.72) : MujiStyle.hairline.opacity(0.46), lineWidth: 0.65)
            }
            .overlay(alignment: .bottomTrailing) {
                if isCurrent {
                    MujiNowPlayingIndicator(isAnimating: playerManager.isPlaying)
                        .scaleEffect(0.72, anchor: .bottomTrailing)
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%02d", rank))
                    .font(MujiStyle.labelFont(9, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(1)

                Text(song.name)
                    .font(MujiStyle.bodyFont(13, weight: .regular))
                    .foregroundStyle(isCurrent ? accent : textPrimary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(MujiStyle.labelFont(10, weight: .regular))
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(width: DeviceLayout.isPad ? 268 : 246, alignment: .leading)
        .background(MujiPaperCardBackground(cornerRadius: 12, elevated: false))
        .clipShape(cardShape)
        .overlay {
            cardShape
                .stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.65)
        }
    }

    // MARK: - 歌单

    private func mujiPlaylistSection(
        title: String,
        playlists: [Playlist],
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            MujiSectionTitle(
                title: title,
                actionTitle: action == nil ? nil : String(localized: "view_all"),
                action: action
            )
            .padding(.horizontal, 28)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ],
                spacing: 20
            ) {
                ForEach(Array(playlists.prefix(6).enumerated()), id: \.element.id) { _, pl in
                    Button {
                        navigationPath.append(HomeView.HomeDestination.playlist(pl))
                    } label: {
                        mujiPlaylistCard(pl)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985, opacity: 0.94))
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func mujiPlaylistCard(_ playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: playlist.coverUrl) {
                RoundedRectangle(cornerRadius: 8).fill(separator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

            Text(playlist.name)
                .font(MujiStyle.bodyFont(12, weight: .regular))
                .foregroundColor(textPrimary)
                .lineLimit(2)
        }
    }

    private var mujiEntryCards: some View {
        HStack(spacing: 10) {
            MujiHomeEntryCard(
                icon: .musicNoteList,
                title: String(localized: "new_song_express"),
                tint: MujiStyle.tea
            ) {
                navigationPath.append(HomeView.HomeDestination.newSongExpress)
            }

            MujiHomeEntryCard(
                icon: .mv,
                title: String(localized: "home_mv_zone"),
                tint: MujiStyle.indigo
            ) {
                navigationPath.append(HomeView.HomeDestination.mvDiscover)
            }

            MujiHomeEntryCard(
                icon: .moon,
                title: String(localized: "meditation_mode_title"),
                tint: MujiStyle.straw
            ) {
                navigationPath.append(HomeView.HomeDestination.meditationMode)
            }
        }
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

    // MARK: - Destinations

    @ViewBuilder
    private func mujiDestination(for dest: HomeView.HomeDestination) -> some View {
        switch dest {
        case .search: SearchView()
        case .dailyRecommend: DailyRecommendView()
        case let .playlist(p): PlaylistDetailView(playlist: p)
        case let .bannerPlaylist(p, bannerImage): PlaylistDetailView(playlist: p, bannerCoverURLString: bannerImage)
        case let .artist(id): ArtistDetailView(artistId: id)
        case let .album(id): AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil)
        case .mvDiscover: MVDiscoverView()
        case .newSongExpress: NewSongExpressView()
        case .qcmNewSongs: QCMNewSongsView()
        case .meditationMode: MeditationModeView()
        }
    }
}

private struct MujiHomeBannerSection: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 5.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $index) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { offset, banner in
                    MujiHomeBannerCard(banner: banner) {
                        onTap(banner)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 7)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)
            .frame(height: DeviceLayout.isPad ? 222 : 166)
            .onReceive(timer) { _ in
                guard banners.count > 1 else { return }
                if reduceMotion {
                    index = (index + 1) % banners.count
                } else {
                    withAnimation(.easeInOut(duration: 0.36)) {
                        index = (index + 1) % banners.count
                    }
                }
            }

            if banners.count > 1 {
                HStack(spacing: 7) {
                    ForEach(banners.indices, id: \.self) { dot in
                        Capsule()
                            .fill(dot == index ? MujiStyle.clay : MujiStyle.hairline.opacity(0.5))
                            .frame(width: dot == index ? 18 : 6, height: 4)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: index)
                    }
                }
            }
        }
    }
}

private struct MujiHomeBannerCard: View {
    let banner: Banner
    let action: () -> Void
    private let cornerRadius: CGFloat = 16

    private var cardHeight: CGFloat {
        DeviceLayout.isPad ? 192 : 136
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                HomeBannerArtwork(url: banner.imageUrl, cornerRadius: cornerRadius) {
                    cardShape
                        .fill(MujiStyle.surfaceRaised)
                        .overlay(MujiPaperTexture(opacity: 0.12))
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.48)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 10) {
                    Text(bannerLabel)
                        .font(MujiStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(MujiStyle.onImage)
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.25), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 0.6))

                    Spacer(minLength: 8)

                    MonologueIcon(icon: .chevronRight, size: 12, color: MujiStyle.onImage, lineWidth: 1.4)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.22), in: Circle())
                }
                .padding(12)
            }
            .frame(height: cardHeight)
            .compositingGroup()
            .clipShape(cardShape)
            .contentShape(cardShape)
            .overlay(
                cardShape
                    .stroke(MujiStyle.hairline.opacity(0.68), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.99, opacity: 0.96))
    }

    private var bannerLabel: String {
        if let typeTitle = banner.typeTitle, !typeTitle.isEmpty {
            return typeTitle
        }

        switch banner.targetType {
        case 1:
            return "Song"
        case 10:
            return String(localized: "artist_tab_album")
        case 1000:
            return String(localized: "home_playlist")
        default:
            return "Banner"
        }
    }
}

private struct MujiHomeEntryCard: View {
    let icon: MonologueIcon.IconType
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                MonologueIcon(icon: icon, size: 18, color: tint, lineWidth: 1.6)
                    .frame(width: 38, height: 38)
                    .background(MujiStyle.surface, in: Circle())
                    .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.48), lineWidth: 0.6))

                Text(title)
                    .font(MujiStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(MujiStyle.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.74)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)

                Rectangle()
                    .fill(tint.opacity(0.64))
                    .frame(width: 30, height: 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Muji Stagger

private extension View {
    func mujiStagger(_ appeared: Bool, order: Int, reduceMotion: Bool = false) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (reduceMotion ? 0 : 10))
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.05)
                    : .easeOut(duration: 0.42).delay(Double(order) * 0.06),
                value: appeared
            )
    }
}
