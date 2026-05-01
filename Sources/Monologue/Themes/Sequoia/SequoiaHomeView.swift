import SwiftUI

struct SequoiaHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var appeared = false
    @State private var bannerIndex = 0
    @State private var hitokotoRefreshing = false
    @State private var playlistCardsRevealed = false

    private let bannerTimer = Timer.publish(every: 6.2, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if let message = viewModel.errorMessage, viewModel.dailySongs.isEmpty {
                    errorView(message)
                } else {
                    scrollBody
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear(perform: appear)
            .onReceive(bannerTimer) { _ in
                guard viewModel.banners.count > 1 else { return }
                moveBanner(by: 1, count: viewModel.banners.count, haptic: false)
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
            LazyVStack(spacing: 15) {
                systemToolbar
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .sequoiaStagger(appeared, order: 0)

                if !viewModel.banners.isEmpty {
                    bannerRail
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .sequoiaStagger(appeared, order: 1)
                }

                if let hitokoto = hitokotoDisplayText {
                    hitokotoCard(hitokoto)
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .sequoiaStagger(appeared, order: 2)
                }

                nowPlayingRibbon
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .sequoiaStagger(appeared, order: 3)

                if !viewModel.dailySongs.isEmpty {
                    dailySection
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .sequoiaStagger(appeared, order: 4)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    qcmSongsSection
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .sequoiaStagger(appeared, order: 5)
                }

                playlistSection
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .sequoiaStagger(appeared, order: 6)

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 6)
            .padding(.bottom, 10)
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
        SequoiaStatePanel(
            title: "Monologue",
            subtitle: String(localized: "正在整理今日音乐"),
            icon: .musicNote,
            showsProgress: true
        )
        .padding(.horizontal, 40)
    }

    private func errorView(_ message: String) -> some View {
        SequoiaStatePanel(
            title: String(localized: "音乐暂时没有抵达"),
            subtitle: message,
            icon: .infoCircle,
            tint: SequoiaStyle.red
        )
        .padding(.horizontal, 40)
    }

    private var systemToolbar: some View {
        HStack(spacing: 13) {
            VStack(spacing: 4) {
                Capsule()
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 4, height: 26)
                Capsule()
                    .fill(SequoiaStyle.separator)
                    .frame(width: 4, height: 9)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(MonologueTimeGreeting.localizedText)
                    .font(SequoiaStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SequoiaStyle.inkMuted)

                Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(SequoiaStyle.titleFont(24, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .layoutPriority(1)

            Spacer(minLength: 10)

            toolbarButton(icon: .magnifyingGlass, tint: SequoiaStyle.inkSoft, label: String(localized: "搜索")) {
                navigationPath.append(HomeView.HomeDestination.search)
            }

            toolbarButton(icon: .radio, tint: SequoiaStyle.accent, label: "FM") {
                showPersonalFM = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SequoiaChromeBar(cornerRadius: 22))
    }

    private func toolbarButton(
        icon: MonologueIcon.IconType,
        tint: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SequoiaControlButton(icon: icon, tint: tint, size: 38)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        .accessibilityLabel(Text(label))
    }

    private var nowPlayingRibbon: some View {
        let song = player.currentSong ?? player.history.first
        let isPlaying = player.currentSong != nil
        let tint = isPlaying ? SequoiaStyle.accent : SequoiaStyle.graphite

        return Button {
            HapticManager.shared.soft()
            if isPlaying {
                NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
            } else {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            }
        } label: {
            HStack(spacing: 12) {
                coverArt(song: song, size: 58, radius: 14)
                    .overlay(alignment: .bottomTrailing) {
                        MonologueIcon(icon: isPlaying ? .waveform : .musicNote, size: 11, color: SequoiaStyle.onAccent, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(isPlaying ? AnyShapeStyle(SequoiaStyle.accentGradient) : AnyShapeStyle(tint)))
                            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 0.55))
                            .offset(x: 4, y: 4)
                            .scaleEffect(isPlaying && !reduceMotion ? 1.08 : 1)
                            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isPlaying)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        SequoiaPill(
                            text: isPlaying ? String(localized: "正在播放") : String(localized: "未在播放"),
                            icon: isPlaying ? .waveform : .musicNote,
                            tint: tint,
                            selected: isPlaying,
                            compact: true
                        )

                        SequoiaMeter(tint: tint, count: 6)
                            .opacity(isPlaying ? 1 : 0.5)
                            .animation(MonologueAnimation.micro, value: isPlaying)
                    }

                    MarqueeText(
                        text: song?.name ?? "Monologue",
                        font: SequoiaStyle.titleFont(17, weight: .semibold),
                        color: SequoiaStyle.ink,
                        speed: 24,
                        delayBeforeScroll: 1.2
                    )
                    .frame(height: 20)

                    Text(song?.artistName.isEmpty == false ? song!.artistName : String(localized: "音乐"))
                        .font(SequoiaStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(SequoiaStyle.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                SequoiaControlButton(icon: .chevronRight, tint: SequoiaStyle.accent, size: 36, selected: true)
            }
            .padding(11)
            .background(SequoiaGlassBand(tint: tint, cornerRadius: 22))
        }
        .buttonStyle(SequoiaHomePressButtonStyle(scale: 0.985, lift: 1, enableHaptic: false))
        .accessibilityElement(children: .combine)
    }

    private var bannerRail: some View {
        let banners = viewModel.banners
        let safeIndex = min(bannerIndex, max(banners.count - 1, 0))
        let banner = banners[safeIndex]

        return Button {
            HapticManager.shared.selection()
            handleBannerTap(banner)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: banner.imageUrl) {
                    coverPlaceholder(tint: SequoiaStyle.aqua)
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: bannerHeight)
                .clipped()
                .id(safeIndex)
                .transition(bannerTransition)
                .animation(bannerAnimation, value: safeIndex)

                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.5),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(spacing: 10) {
                    SequoiaPill(
                        text: bannerLabel(for: banner),
                        icon: .sparkle,
                        tint: SequoiaStyle.aqua,
                        selected: true,
                        compact: true
                    )

                    Spacer(minLength: 8)

                    bannerDots(count: banners.count, current: safeIndex)

                    MonologueIcon(icon: .chevronRight, size: 12, color: Color.white.opacity(0.86), lineWidth: 1.6)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 0.55))
                }
                .padding(12)
            }
            .frame(height: bannerHeight)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.36), SequoiaStyle.separator.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            )
            .shadow(color: SequoiaStyle.graphite.opacity(0.1), radius: 13, x: 0, y: 7)
            .themeRenderSurfaceLayer(isEnabled: true)
        }
        .buttonStyle(SequoiaHomePressButtonStyle(scale: 0.985, lift: 1, enableHaptic: false))
        .simultaneousGesture(bannerSwipeGesture(count: banners.count))
    }

    private var bannerHeight: CGFloat {
        DeviceLayout.isPad ? 194 : 148
    }

    private var bannerAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.01) : .easeInOut(duration: 0.28)
    }

    private var bannerTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 1.015)),
            removal: .opacity.combined(with: .scale(scale: 0.985))
        )
    }

    private func bannerSwipeGesture(count: Int) -> some Gesture {
        DragGesture(minimumDistance: 28)
            .onEnded { value in
                guard count > 1, abs(value.translation.width) > 34 else { return }
                moveBanner(by: value.translation.width < 0 ? 1 : -1, count: count, haptic: true)
            }
    }

    private func moveBanner(by offset: Int, count: Int, haptic: Bool) {
        guard count > 1 else { return }
        let nextIndex = (bannerIndex + offset + count) % count
        if haptic {
            HapticManager.shared.selection()
        }
        if reduceMotion {
            bannerIndex = nextIndex
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                bannerIndex = nextIndex
            }
        }
    }

    private func bannerLabel(for banner: Banner) -> String {
        let label = banner.typeTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? String(localized: "推荐") : label
    }

    private func bannerDots(count: Int, current: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<min(count, 6), id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.white.opacity(0.92) : Color.white.opacity(0.34))
                    .frame(width: index == current ? 18 : 6, height: 5)
                    .animation(.spring(response: 0.32, dampingFraction: 0.84), value: current)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
    }

    private func hitokotoCard(_ text: String) -> some View {
        HStack(spacing: 11) {
            SequoiaIconBadge(icon: .hitokoto, tint: SequoiaStyle.green, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "settings_hitokoto"))
                    .font(SequoiaStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SequoiaStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                MarqueeText(
                    text: text,
                    font: SequoiaStyle.labelFont(14, weight: .medium),
                    color: SequoiaStyle.ink,
                    speed: 20,
                    delayBeforeScroll: 1.1
                )
                .frame(height: 18)
            }
            .layoutPriority(1)

            Button {
                HapticManager.shared.selection()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    hitokotoRefreshing = true
                }
                viewModel.refreshHitokoto(force: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        hitokotoRefreshing = false
                    }
                }
            } label: {
                MonologueIcon(icon: .refresh, size: 14, color: SequoiaStyle.green, lineWidth: 1.55)
                    .rotationEffect(.degrees(hitokotoRefreshing ? 360 : 0))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(SequoiaStyle.green.opacity(0.12)))
                    .overlay(Circle().stroke(SequoiaStyle.green.opacity(0.18), lineWidth: 0.55))
            }
            .scaleEffect(hitokotoRefreshing && !reduceMotion ? 1.08 : 1)
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94, enableHaptic: false))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SequoiaSurfaceBackground(cornerRadius: 19, elevated: false, role: .list))
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
    }

    private var dailySection: some View {
        SequoiaSection(
            title: String(localized: "daily_recommend"),
            tint: SequoiaStyle.accent
        ) {
            Button {
                HapticManager.shared.light()
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            } label: {
                SequoiaPill(text: String(localized: "查看全部"), icon: .chevronRight, tint: SequoiaStyle.accent, selected: true, compact: true)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94, enableHaptic: false))
        } content: {
            SequoiaListGroup {
                ForEach(Array(viewModel.dailySongs.prefix(4).enumerated()), id: \.element.id) { index, song in
                    SequoiaSongRow(index: index + 1, song: song, tint: SequoiaStyle.accent) {
                        HapticManager.shared.light()
                        PlayerManager.shared.play(song: song, in: viewModel.dailySongs)
                    }
                    if index < min(viewModel.dailySongs.count, 4) - 1 {
                        SequoiaHairline()
                            .padding(.leading, 62)
                    }
                }
            }
        }
    }

    private var qcmSongsSection: some View {
        SequoiaSection(
            title: String(localized: "QCM推荐"),
            tint: SequoiaStyle.violet
        ) {
            Button {
                HapticManager.shared.light()
                navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
            } label: {
                SequoiaPill(text: String(localized: "查看全部"), icon: .chevronRight, tint: SequoiaStyle.violet, selected: true, compact: true)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94, enableHaptic: false))
        } content: {
            SequoiaListGroup {
                ForEach(Array(viewModel.qqNewSongs.prefix(4).enumerated()), id: \.element.id) { index, song in
                    SequoiaSongRow(index: index + 1, song: song, tint: SequoiaStyle.violet) {
                        HapticManager.shared.light()
                        PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs)
                    }
                    if index < min(viewModel.qqNewSongs.count, 4) - 1 {
                        SequoiaHairline()
                            .padding(.leading, 62)
                    }
                }
            }
        }
    }

    private var playlistSection: some View {
        SequoiaSection(
            title: String(localized: "推荐歌单"),
            tint: SequoiaStyle.aqua
        ) {
            HStack(spacing: 8) {
                Button {
                    openPlaylistSquare()
                } label: {
                    SequoiaPill(text: String(localized: "查看全部"), icon: .chevronRight, tint: SequoiaStyle.aqua, selected: true, compact: true)
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94, enableHaptic: false))

                Button {
                    openPlaylistSquare()
                } label: {
                    SequoiaPill(text: String(localized: "歌单广场"), icon: .gridSquare, tint: SequoiaStyle.accent, selected: false, compact: true)
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94, enableHaptic: false))
            }
        } content: {
            if uniquePlaylists.isEmpty {
                SequoiaStatePanel(
                    title: String(localized: "暂无歌单"),
                    icon: .musicNoteList,
                    tint: SequoiaStyle.aqua
                )
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 11) {
                        ForEach(Array(uniquePlaylists.enumerated()), id: \.element.id) { index, playlist in
                            Button {
                                HapticManager.shared.selection()
                                navigationPath.append(HomeView.HomeDestination.playlist(playlist))
                            } label: {
                                SequoiaPlaylistCard(
                                    playlist: playlist,
                                    index: index,
                                    isVisible: playlistCardsRevealed,
                                    reduceMotion: reduceMotion
                                )
                            }
                            .buttonStyle(SequoiaHomePressButtonStyle(scale: 0.97, lift: 1, enableHaptic: false))
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    revealPlaylistCards()
                }
                .onChange(of: uniquePlaylists.count) { _, _ in
                    revealPlaylistCards(reset: true)
                }
            }
        }
    }

    private var hitokotoDisplayText: String? {
        guard hitokotoEnabled else { return nil }
        let text = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private var uniquePlaylists: [Playlist] {
        var seen: Set<Int> = []
        return (viewModel.recommendPlaylists + viewModel.qqRecommendPlaylists).filter { playlist in
            guard !seen.contains(playlist.id) else { return false }
            seen.insert(playlist.id)
            return true
        }
    }

    private func appear() {
        if viewModel.dailySongs.isEmpty {
            viewModel.fetchData()
        }
        if hitokotoEnabled,
           viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        {
            viewModel.refreshHitokoto()
        }
        guard !appeared else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9).delay(0.04)) {
            appeared = true
        }
        revealPlaylistCards()
    }

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            let candidates = viewModel.dailySongs + viewModel.popularSongs + viewModel.qqNewSongs
            if let song = candidates.first(where: { $0.id == banner.targetId }) {
                PlayerManager.shared.play(song: song, in: candidates)
            }
        case 10:
            navigationPath.append(HomeView.HomeDestination.album(banner.targetId))
        case 100, 1000:
            let playlist = Playlist(
                id: banner.targetId,
                name: banner.typeTitle ?? String(localized: "歌单"),
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

    private func openPlaylistSquare() {
        HapticManager.shared.selection()
        UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
        NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
    }

    private func revealPlaylistCards(reset: Bool = false) {
        if reset {
            playlistCardsRevealed = false
        }
        guard !playlistCardsRevealed else { return }
        if reduceMotion {
            playlistCardsRevealed = true
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88).delay(0.04)) {
                playlistCardsRevealed = true
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

    @ViewBuilder
    private func coverArt(song: Song?, size: CGFloat, radius: CGFloat) -> some View {
        if let url = song?.coverUrl {
            CachedAsyncImage(url: url, width: size, height: size) {
                coverPlaceholder(tint: SequoiaStyle.accent)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            coverPlaceholder(tint: SequoiaStyle.accent)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    private func coverPlaceholder(tint: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.16), SequoiaStyle.aqua.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            MonologueIcon(icon: .musicNote, size: 24, color: tint.opacity(0.62), lineWidth: 1.55)
        }
    }
}

private struct SequoiaHomePressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var lift: CGFloat = 0
    var enableHaptic = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && !EdgeSwipeGuard.shared.isSwiping

        configuration.label
            .scaleEffect(reduceMotion || !isPressed ? 1 : scale)
            .offset(y: reduceMotion || !isPressed ? 0 : lift)
            .opacity(isPressed ? 0.94 : 1)
            .animation(MonologueAnimation.buttonPress, value: isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, enableHaptic, !EdgeSwipeGuard.shared.isSwiping else { return }
                HapticManager.shared.light()
            }
    }
}

private struct SequoiaSongRow: View {
    let index: Int
    let song: Song
    var tint: Color = SequoiaStyle.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(String(format: "%02d", index))
                    .font(SequoiaStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.inkMuted)
                    .frame(width: 26, alignment: .leading)

                cover

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.name,
                        font: SequoiaStyle.labelFont(14, weight: .semibold),
                        color: SequoiaStyle.ink,
                        speed: 22,
                        delayBeforeScroll: 1.1
                    )
                    .frame(height: 18)

                    MarqueeText(
                        text: song.artistName,
                        font: SequoiaStyle.labelFont(12, weight: .regular),
                        color: SequoiaStyle.inkSoft,
                        speed: 20,
                        delayBeforeScroll: 1.2
                    )
                    .frame(height: 17)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                MonologueIcon(icon: .playCircle, size: 18, color: tint.opacity(0.9), lineWidth: 1.55)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(SequoiaHomePressButtonStyle(scale: 0.985, lift: 0.5, enableHaptic: false))
        .themeRenderRowLayer()
    }

    private var cover: some View {
        Group {
            if let url = song.coverUrl {
                CachedAsyncImage(url: url, width: 38, height: 38) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            tint.opacity(0.12)
            MonologueIcon(icon: .musicNote, size: 16, color: tint.opacity(0.58), lineWidth: 1.5)
        }
    }
}

private struct SequoiaPlaylistCard: View {
    let playlist: Playlist
    let index: Int
    let isVisible: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover

            MarqueeText(
                text: playlist.name,
                font: SequoiaStyle.labelFont(13, weight: .semibold),
                color: SequoiaStyle.ink,
                speed: 20,
                delayBeforeScroll: 1.1
            )
            .frame(width: 112, height: 18, alignment: .leading)

            HStack(spacing: 5) {
                MonologueIcon(icon: .musicNoteList, size: 12, color: SequoiaStyle.inkMuted, lineWidth: 1.4)
                Text(trackText)
                    .font(SequoiaStyle.labelFont(10, weight: .medium))
                    .foregroundStyle(SequoiaStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(8)
        .frame(width: 128, alignment: .leading)
        .background(SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, role: .list))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isVisible || reduceMotion ? 1 : 0)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.965, anchor: .bottom)
        .offset(y: isVisible || reduceMotion ? 0 : 8)
        .animation(
            reduceMotion ? .easeOut(duration: 0.01) : .spring(response: 0.36, dampingFraction: 0.9).delay(Double(min(index, 8)) * 0.026),
            value: isVisible
        )
    }

    private var trackText: String {
        if let trackCount = playlist.trackCount {
            return "\(trackCount) \(String(localized: "songs_unit"))"
        }
        return String(localized: "歌单")
    }

    private var cover: some View {
        Group {
            if let url = playlist.coverUrl {
                CachedAsyncImage(url: url, width: 112, height: 112) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 112, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.26), lineWidth: 0.55)
        )
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [SequoiaStyle.aqua.opacity(0.14), SequoiaStyle.accent.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            MonologueIcon(icon: .musicNoteList, size: 24, color: SequoiaStyle.aqua.opacity(0.68), lineWidth: 1.55)
        }
    }
}

private struct SequoiaPlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 11) {
            cover

            VStack(alignment: .leading, spacing: 3) {
                MarqueeText(
                    text: playlist.name,
                    font: SequoiaStyle.labelFont(14, weight: .semibold),
                    color: SequoiaStyle.ink,
                    speed: 21,
                    delayBeforeScroll: 1.15
                )
                .frame(height: 18)

                Text(trackText)
                    .font(SequoiaStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(SequoiaStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)
            MonologueIcon(icon: .chevronRight, size: 12, color: SequoiaStyle.inkMuted, lineWidth: 1.45)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var trackText: String {
        if let trackCount = playlist.trackCount {
            return "\(trackCount) \(String(localized: "songs_unit"))"
        }
        return String(localized: "歌单")
    }

    private var cover: some View {
        Group {
            if let url = playlist.coverUrl {
                CachedAsyncImage(url: url, width: 46, height: 46) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            SequoiaStyle.aqua.opacity(0.12)
            MonologueIcon(icon: .musicNoteList, size: 19, color: SequoiaStyle.aqua.opacity(0.7), lineWidth: 1.55)
        }
    }
}

private struct SequoiaShortcutRow: View {
    let title: String
    let icon: MonologueIcon.IconType
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            SequoiaIconBadge(icon: icon, tint: tint, size: 34)
            Text(title)
                .font(SequoiaStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(SequoiaStyle.ink)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list))
    }
}
