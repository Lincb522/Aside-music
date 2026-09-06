import SwiftUI

/// 无印良品版首页 — 青苔手帖
///
/// 一册清新的生活手帖：圆点刊头 + 水洗引文 + 目次 + 特辑，
/// 不用发丝线与描边，分区靠留白、水洗色块与针脚点缀。
struct MujiHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true
    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var appeared = false
    @State private var didActivateHome = false
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
            .task {
                guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
                activateHomeIfNeeded(reason: "muji home appear")
            }
            .onReceive(NotificationCenter.default.publisher(for: .mainTabDidSettle)) { notification in
                guard notification.object as? Tab == .home,
                      MainTabActivationGate.isSettled(.home) else { return }
                activateHomeIfNeeded(reason: "muji home selected")
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
                    HStack(spacing: 12) {
                        mujiToolbarButton(icon: .radio) { showPersonalFM = true }
                        mujiToolbarButton(icon: .magnifyingGlass) {
                            navigationPath.append(HomeView.HomeDestination.search)
                        }
                    }
                }
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { dest in
                mujiDestination(for: dest)
            }
            .fullScreenCover(isPresented: $showPersonalFM) { PersonalFMView() }
            .fullScreenCover(item: $bannerWebURL) { url in MonoWebView(url: url, title: nil) }
        }
        .themeRenderSceneLayer()
    }

    private func activateHomeIfNeeded(reason: String) {
        guard !didActivateHome else { return }
        didActivateHome = true
        viewModel.ensureHomeDataLoaded(reason: reason)
        if hitokotoEnabled,
           viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            viewModel.refreshHitokoto()
        }
        guard !appeared else { return }
        if reduceMotion {
            appeared = true
        } else {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) { appeared = true }
        }
    }

    private func mujiToolbarButton(icon: MonoIcon.IconType, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 15, color: accent, lineWidth: 1.5)
                .frame(width: 36, height: 36)
                .background(MujiStyle.wash(accent, strength: 1.1), in: Circle())
        }
    }

    // MARK: - 加载中

    private var mujiLoadingView: some View {
        VStack(spacing: 16) {
            MujiDotMark()

            Text(String(localized: "loading"))
                .font(MujiStyle.labelFont(11, weight: .medium))
                .foregroundColor(textSecondary)
                .tracking(2)
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var mujiAvatarView: some View {
        let size: CGFloat = 36
        if let avatarUrl = viewModel.displayedIdentityProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) {
                Circle().fill(MujiStyle.wash(accent))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .background(
                Circle()
                    .fill(MujiStyle.wash(accent, strength: 1.4))
                    .frame(width: size + 6, height: size + 6)
            )
        } else {
            Circle()
                .fill(MujiStyle.wash(accent, strength: 1.2))
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: 16, color: accent))
        }
    }

    // MARK: - 主体

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                mujiMasthead
                    .padding(.horizontal, 26)
                    .padding(.bottom, 24)
                    .monoPageHeaderCollapse()
                    .mujiStagger(appeared, order: 0, reduceMotion: reduceMotion)

                mujiPullQuote
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                    .mujiStagger(appeared, order: 1, reduceMotion: reduceMotion)

                mujiIndex
                    .padding(.horizontal, 26)
                    .padding(.bottom, 32)
                    .mujiStagger(appeared, order: 2, reduceMotion: reduceMotion)

                if !viewModel.banners.isEmpty {
                    mujiBannerSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        .mujiStagger(appeared, order: 3, reduceMotion: reduceMotion)
                }

                if !viewModel.dailySongs.isEmpty {
                    mujiDailySection
                        .mujiStagger(appeared, order: 4, reduceMotion: reduceMotion)
                        .padding(.bottom, 36)
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    mujiPlaylistSection(
                        title: String(localized: "recommended_playlists"),
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
            .iPadContentWidth(1080)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable {
            viewModel.retryHomeDataLoad(reason: "muji home pull refresh")
            if hitokotoEnabled {
                viewModel.refreshHitokoto(force: true)
            }
        }
    }

    // MARK: - 刊头

    /// 圆点日期行 + 问候 + 衬线名字，一册手帖的扉页
    private var mujiMasthead: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MujiDotMark()

                Text(mujiIssueLine)
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundColor(textSecondary)
                    .tracking(1.8)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Text("№\(String(format: "%02d", mujiWeekNumber))")
                    .font(MujiStyle.labelFont(9.5, weight: .semibold))
                    .foregroundColor(accent)
                    .tracking(1)
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MujiStyle.wash(accent, strength: 1.15), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(mujiGreetingText)
                    .font(MujiStyle.labelFont(11, weight: .medium))
                    .foregroundColor(textSecondary)
                    .tracking(1.8)
                    .textCase(.uppercase)

                Text(viewModel.displayedIdentityProfile?.nickname ?? String(localized: "default_nickname"))
                    .font(MujiStyle.titleFont(30, weight: .medium))
                    .foregroundColor(textPrimary)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mujiGreetingText: String {
        MonoTimeGreeting.localizedText
    }

    private var mujiWeekNumber: Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }

    private var mujiIssueLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: Date())
    }

    // MARK: - 一言（水洗引文）

    private var mujiPullQuote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("「")
                .font(MujiStyle.titleFont(26, weight: .medium))
                .foregroundStyle(accent.opacity(0.75))
                .frame(height: 18, alignment: .top)

            Text(usesHitokotoFallback ? HitokotoFallbackSlogan.text : mujiHeaderQuote)
                .font(MujiStyle.bodyFont(16.5, weight: .regular))
                .foregroundStyle(textPrimary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.disabled)

            HStack {
                Spacer()

                Text("HITOKOTO")
                    .font(MujiStyle.labelFont(8.5, weight: .semibold))
                    .foregroundStyle(MujiStyle.inkMuted)
                    .tracking(2.4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MujiStyle.wash(accent, strength: 0.85))
        )
    }

    private var mujiHeaderQuote: String {
        viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var usesHitokotoFallback: Bool {
        !hitokotoEnabled || mujiHeaderQuote.isEmpty
    }

    // MARK: - 目次（水洗图标行）

    private var mujiIndex: some View {
        VStack(spacing: 0) {
            mujiIndexRow(
                title: String(localized: "new_song_express"),
                caption: String(localized: "home_playlist"),
                icon: .musicNoteList,
                tint: accent
            ) {
                navigationPath.append(HomeView.HomeDestination.newSongExpress)
            }

            MujiListDivider()
                .padding(.leading, 54)

            mujiIndexRow(
                title: String(localized: "home_mv_zone"),
                caption: "MV",
                icon: .mv,
                tint: MujiStyle.indigo
            ) {
                navigationPath.append(HomeView.HomeDestination.mvDiscover)
            }

            MujiListDivider()
                .padding(.leading, 54)

            mujiIndexRow(
                title: String(localized: "meditation_mode_title"),
                caption: String(localized: "meditation_mode_title"),
                icon: .moon,
                tint: MujiStyle.tea
            ) {
                navigationPath.append(HomeView.HomeDestination.meditationMode)
            }
        }
    }

    private func mujiIndexRow(
        title: String,
        caption: String,
        icon: MonoIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                MujiIconBadge(icon: icon, tint: tint, size: 40)

                Text(title)
                    .font(MujiStyle.bodyFont(15.5, weight: .regular))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                MonoIcon(icon: .chevronRight, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.5)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.99, opacity: 0.9))
    }

    // MARK: - Banner

    private var mujiBannerSection: some View {
        MujiHomeBannerSection(banners: viewModel.banners) { banner in
            handleBannerTap(banner)
        }
    }

    // MARK: - 每日推荐（特辑）

    private var mujiDailySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            MujiSectionTitle(
                title: String(localized: "daily_recommend"),
                actionTitle: String(localized: "view_all"),
                action: { navigationPath.append(HomeView.HomeDestination.dailyRecommend) }
            )
            .padding(.horizontal, 26)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    let shouldReduceMotion = reduceMotion
                    ForEach(Array(viewModel.dailySongs.prefix(10).enumerated()), id: \.element.identityKey) { index, song in
                        Button {
                            playerManager.play(song: song, in: viewModel.dailySongs)
                        } label: {
                            mujiSongCard(song, index: index + 1)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.985, opacity: 0.94))
                        .compatScrollTransition(animation: shouldReduceMotion ? .easeInOut(duration: 0.05) : .easeInOut(duration: 0.24)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : (shouldReduceMotion ? 1 : 0.95))
                                .opacity(phase.isIdentity ? 1 : (shouldReduceMotion ? 1 : 0.7))
                        }
                    }
                }
                .padding(.horizontal, 26)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    /// 特辑图：圆角封面 + 图注（编号 · 曲名 · 歌手）
    private func mujiSongCard(_ song: Song, index: Int) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id
        let coverShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return VStack(alignment: .leading, spacing: 9) {
            CachedAsyncImage(url: song.coverUrl) {
                coverShape.fill(MujiStyle.wash(accent))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 124, height: 124)
            .clipShape(coverShape)
            .overlay(alignment: .bottomTrailing) {
                if isCurrent {
                    MujiNowPlayingIndicator(isAnimating: playerManager.isPlaying)
                        .padding(7)
                        .transition(.scale(scale: 0.88, anchor: .bottomTrailing).combined(with: .opacity))
                }
            }
            .shadow(color: isCurrent ? accent.opacity(0.22) : MujiStyle.ink.opacity(0.07), radius: isCurrent ? 11 : 8, x: 0, y: 4)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%02d", index))
                    .font(MujiStyle.titleFont(11, weight: .medium))
                    .foregroundColor(accent)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(song.name)
                        .font(MujiStyle.bodyFont(12.5, weight: .regular))
                        .foregroundColor(isCurrent ? accent : textPrimary)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(MujiStyle.labelFont(10, weight: .regular))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 124, alignment: .leading)
        }
    }

    // MARK: - 新歌速递（针脚列表）

    private var mujiNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MujiSectionTitle(
                title: String(localized: "qq_new_songs"),
                actionTitle: String(localized: "view_all"),
                action: { navigationPath.append(HomeView.HomeDestination.qcmNewSongs) }
            )
            .padding(.horizontal, 26)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.qqNewSongs.prefix(6).enumerated()), id: \.element.identityKey) { index, song in
                    Button {
                        playerManager.play(song: song, in: viewModel.qqNewSongs)
                    } label: {
                        mujiNewSongRow(song, rank: index + 1)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.995, opacity: 0.92))

                    if index < min(viewModel.qqNewSongs.count, 6) - 1 {
                        MujiListDivider()
                            .padding(.leading, 40)
                    }
                }
            }
            .padding(.horizontal, 26)
        }
    }

    private func mujiNewSongRow(_ song: Song, rank: Int) -> some View {
        let isCurrent = playerManager.currentSong?.id == song.id
        let coverShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return HStack(alignment: .center, spacing: 14) {
            Text(String(format: "%02d", rank))
                .font(MujiStyle.titleFont(14, weight: .medium))
                .foregroundStyle(rank <= 3 ? accent : MujiStyle.inkMuted)
                .monospacedDigit()
                .frame(width: 26, alignment: .leading)

            CachedAsyncImage(url: song.coverUrl) {
                coverShape.fill(MujiStyle.wash(accent))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 46, height: 46)
            .clipShape(coverShape)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(MujiStyle.bodyFont(14, weight: .regular))
                    .foregroundStyle(isCurrent ? accent : textPrimary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(MujiStyle.labelFont(10.5, weight: .regular))
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                MujiNowPlayingIndicator(isAnimating: playerManager.isPlaying)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 歌单（图注网格）

    private func mujiPlaylistSection(
        title: String,
        playlists: [Playlist],
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            MujiSectionTitle(
                title: title,
                actionTitle: action == nil ? nil : String(localized: "view_all"),
                action: action
            )
            .padding(.horizontal, 26)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 18),
                    GridItem(.flexible(), spacing: 18),
                ],
                spacing: 24
            ) {
                ForEach(Array(playlists.prefix(6).enumerated()), id: \.element.id) { _, pl in
                    Button {
                        navigationPath.append(HomeView.HomeDestination.playlist(pl))
                    } label: {
                        mujiPlaylistCard(pl)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.985, opacity: 0.94))
                }
            }
            .padding(.horizontal, 26)
        }
    }

    private func mujiPlaylistCard(_ playlist: Playlist) -> some View {
        let coverShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return VStack(alignment: .leading, spacing: 9) {
            CachedAsyncImage(url: playlist.coverUrl) {
                coverShape.fill(MujiStyle.wash(accent))
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: 160)
            .clipShape(coverShape)
            .shadow(color: MujiStyle.ink.opacity(0.07), radius: 8, x: 0, y: 4)

            Text(playlist.name)
                .font(MujiStyle.bodyFont(12.5, weight: .regular))
                .foregroundColor(textPrimary)
                .lineSpacing(2.5)
                .lineLimit(2)
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

// MARK: - Banner（跨页图 + 图注）

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
            .frame(height: DeviceLayout.usesExpandedLayout ? 222 : 166)
            .onReceive(timer) { _ in
                guard MainTabActivationGate.isSettled(.home) else { return }
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
                            .fill(dot == index ? MujiStyle.clay : MujiStyle.inkMuted.opacity(0.35))
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
        DeviceLayout.usesExpandedLayout ? 192 : 136
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                HomeBannerArtwork(url: banner.imageUrl, cornerRadius: cornerRadius) {
                    cardShape
                        .fill(MujiStyle.wash(MujiStyle.clay))
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.42)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 5, height: 5)

                        Text(bannerLabel)
                            .font(MujiStyle.labelFont(10, weight: .semibold))
                            .foregroundStyle(MujiStyle.onImage)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    MonoIcon(icon: .chevronRight, size: 12, color: MujiStyle.onImage, lineWidth: 1.4)
                }
                .padding(14)
            }
            .frame(height: cardHeight)
            .compositingGroup()
            .clipShape(cardShape)
            .contentShape(cardShape)
            .shadow(color: MujiStyle.ink.opacity(0.08), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.99, opacity: 0.96))
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
