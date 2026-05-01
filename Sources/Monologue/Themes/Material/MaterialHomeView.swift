import SwiftUI

struct MaterialHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true

    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var appeared = false

    private let heroArtworkSize: CGFloat = 112

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)

                if viewModel.isLoading {
                    MonologueLoadingView(text: "LOADING HOME")
                } else {
                    scrollBody
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                showHomeContent()
                if viewModel.dailySongs.isEmpty { viewModel.fetchData() }
                if hitokotoEnabled,
                   viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    viewModel.refreshHitokoto()
                }
            }
            .task {
                showHomeContent()
            }
            .navigationDestination(for: HomeView.HomeDestination.self, destination: destinationView)
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(item: $bannerWebURL) { url in
                MonologueWebView(url: url, title: nil)
            }
        }
        .themeRenderSceneLayer()
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 18) {
                materialTopAppBar
                    .materialAppear(appeared, order: 0)

                materialCommandDeck
                    .materialAppear(appeared, order: 1)

                materialQuickActions
                    .materialAppear(appeared, order: 2)

                if !viewModel.banners.isEmpty {
                    materialBannerRail
                        .materialAppear(appeared, order: 3)
                }

                if !viewModel.dailySongs.isEmpty {
                    materialDailyFeed
                        .materialAppear(appeared, order: 4)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    materialQCMNewSongs
                        .materialAppear(appeared, order: 5)
                }

                if !viewModel.recommendPlaylists.isEmpty || !viewModel.qqRecommendPlaylists.isEmpty {
                    materialPlaylistFeed
                        .materialAppear(appeared, order: 6)
                }

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 8)
            .padding(.bottom, 8)
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

    private var materialTopAppBar: some View {
        HStack(spacing: 12) {
            Button {
                NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
            } label: {
                materialAvatar
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: LocalizedStringResource(stringLiteral: MonologueTimeGreeting.localizedKey)))
                    .font(MaterialStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(MaterialStyle.primary)
                    .lineLimit(1)

                Text(viewModel.userProfile?.nickname ?? String(localized: "default_nickname"))
                    .font(MaterialStyle.titleFont(23, weight: .bold))
                    .foregroundStyle(MaterialStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 12)

            MaterialControlButton(icon: .radio, tint: MaterialStyle.secondary) {
                showPersonalFM = true
            }

            MaterialControlButton(icon: .search, tint: MaterialStyle.primary) {
                navigationPath.append(HomeView.HomeDestination.search)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    @ViewBuilder
    private var materialAvatar: some View {
        let size: CGFloat = 48
        Group {
            if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) {
                    MaterialStyle.surfaceContainerHighest
                }
                .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    MaterialStyle.primary.opacity(0.13)
                    MonologueIcon(icon: .profileFilled, size: 20, color: MaterialStyle.primary, lineWidth: 1.8)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MaterialStyle.outline, lineWidth: 0.8)
        )
    }

    private var materialCommandDeck: some View {
        let song = materialHeroSong

        return Button {
            if let song {
                playerManager.play(song: song, in: materialHeroQueue)
            } else {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            }
        } label: {
            HStack(spacing: 16) {
                materialHeroArtwork(song: song)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        MaterialPill(
                            title: playerManager.currentSong == nil ? String(localized: "每日推荐") : String(localized: "正在播放"),
                            icon: playerManager.currentSong == nil ? .sparkle : .musicNote,
                            isSelected: true,
                            tint: MaterialStyle.primary
                        )

                        Spacer(minLength: 8)

                        MaterialPlayButton(isPlaying: song?.id == playerManager.currentSong?.id && playerManager.isPlaying)
                    }

                    Text(song?.name ?? String(localized: "为你量身打造"))
                        .font(MaterialStyle.titleFont(27, weight: .bold))
                        .foregroundStyle(MaterialStyle.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(materialHeroSubtitle(for: song))
                        .font(MaterialStyle.bodyFont(13, weight: .medium))
                        .foregroundStyle(MaterialStyle.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                MaterialSurfaceBackground(cornerRadius: 34, elevated: true, role: .tonal)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func materialHeroArtwork(song: Song?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(MaterialStyle.primary.opacity(0.12))

            if let song, let coverUrl = song.coverUrl {
                CachedAsyncImage(url: coverUrl, width: heroArtworkSize, height: heroArtworkSize) {
                    MaterialStyle.surfaceContainerHighest
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: heroArtworkSize, height: heroArtworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            } else {
                MaterialAmbientEqualizer()
                    .padding(24)
            }
        }
        .frame(width: heroArtworkSize, height: heroArtworkSize)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(MaterialStyle.outlineStrong.opacity(0.34), lineWidth: 0.8)
        )
    }

    private var materialQuickActions: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            materialActionTile(
                title: String(localized: "每日推荐"),
                subtitle: String(viewModel.dailySongs.count),
                icon: .sparkle,
                tint: MaterialStyle.primary
            ) {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            }

            materialActionTile(
                title: String(localized: "歌单广场"),
                subtitle: String(viewModel.recommendPlaylists.count + viewModel.qqRecommendPlaylists.count),
                icon: .musicNoteList,
                tint: MaterialStyle.green
            ) {
                UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
                NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
            }

            materialActionTile(
                title: "QCM 新歌",
                subtitle: String(viewModel.qqNewSongs.count),
                icon: .musicNote,
                tint: MaterialStyle.blue
            ) {
                navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
            }

            materialActionTile(
                title: String(localized: "home_mv_zone"),
                subtitle: String(localized: "MV"),
                icon: .mv,
                tint: MaterialStyle.tertiary
            ) {
                navigationPath.append(HomeView.HomeDestination.mvDiscover)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func materialActionTile(
        title: String,
        subtitle: String,
        icon: MonologueIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MaterialIconBadge(icon: icon, tint: tint, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MaterialStyle.labelFont(14, weight: .bold))
                        .foregroundStyle(MaterialStyle.ink)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(MaterialStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(MaterialStyle.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(minHeight: 70)
            .background(
                MaterialSurfaceBackground(cornerRadius: 22, elevated: false, role: .container)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    private var materialBannerRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            MaterialSectionHeader(
                title: String(localized: "home_banner_section_title"),
                actionTitle: nil,
                action: nil
            )

            TabView {
                ForEach(Array(viewModel.banners.prefix(6).enumerated()), id: \.element.id) { _, banner in
                    Button {
                        handleBannerTap(banner)
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            CachedAsyncImage(url: banner.imageUrl) {
                                MaterialStyle.surfaceContainerHighest
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipped()

                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.64)],
                                startPoint: .center,
                                endPoint: .bottom
                            )

                            if let typeTitle = banner.typeTitle, !typeTitle.isEmpty {
                                Text(typeTitle)
                                    .font(MaterialStyle.labelFont(12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color.black.opacity(0.34)))
                                    .padding(14)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(MaterialStyle.outline.opacity(0.55), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 162)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var materialDailyFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            MaterialSectionHeader(
                title: String(localized: "每日推荐"),
                actionTitle: String(localized: "查看全部")
            ) {
                navigationPath.append(HomeView.HomeDestination.dailyRecommend)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.dailySongs.prefix(10)) { song in
                        materialSongCard(song: song, queue: viewModel.dailySongs)
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            }
            .padding(.horizontal, -DeviceLayout.homeHorizontalPadding)
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var materialQCMNewSongs: some View {
        VStack(alignment: .leading, spacing: 12) {
            MaterialSectionHeader(
                title: "QCM 新歌",
                actionTitle: String(localized: "查看全部")
            ) {
                navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.qqNewSongs.prefix(4)) { song in
                    materialSongRow(song: song, queue: viewModel.qqNewSongs, tint: MaterialStyle.blue)
                }
            }
            .padding(8)
            .background(
                MaterialSurfaceBackground(cornerRadius: 26, elevated: false, role: .surface)
            )
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var materialPlaylistFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            MaterialSectionHeader(
                title: String(localized: "推荐歌单"),
                actionTitle: String(localized: "查看更多")
            ) {
                UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
                NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(materialPlaylists.prefix(12)) { playlist in
                        materialPlaylistCard(playlist)
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            }
            .padding(.horizontal, -DeviceLayout.homeHorizontalPadding)
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private func materialSongCard(song: Song, queue: [Song]) -> some View {
        Button {
            playerManager.play(song: song, in: queue)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                CachedAsyncImage(url: song.coverUrl, width: 136, height: 136) {
                    MaterialStyle.surfaceContainerHighest
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 136, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    MaterialSmallPlayBadge(isPlaying: song.id == playerManager.currentSong?.id && playerManager.isPlaying)
                        .padding(8)
                }

                Text(song.name)
                    .font(MaterialStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(MaterialStyle.ink)
                    .lineLimit(2)
                    .frame(width: 136, alignment: .leading)

                Text(song.artistName)
                    .font(MaterialStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(MaterialStyle.inkMuted)
                    .lineLimit(1)
                    .frame(width: 136, alignment: .leading)
            }
            .padding(10)
            .background(
                MaterialSurfaceBackground(cornerRadius: 28, elevated: false, role: .surface)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    private func materialSongRow(song: Song, queue: [Song], tint: Color) -> some View {
        Button {
            playerManager.play(song: song, in: queue)
        } label: {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl, width: 48, height: 48) {
                    tint.opacity(0.12)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(MaterialStyle.labelFont(14, weight: .bold))
                        .foregroundStyle(MaterialStyle.ink)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(MaterialStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(MaterialStyle.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MaterialSmallPlayBadge(isPlaying: song.id == playerManager.currentSong?.id && playerManager.isPlaying, tint: tint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(song.id == playerManager.currentSong?.id ? tint.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func materialPlaylistCard(_ playlist: Playlist) -> some View {
        Button {
            navigationPath.append(HomeView.HomeDestination.playlist(playlist))
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                CachedAsyncImage(url: playlist.coverUrl, width: 146, height: 116) {
                    MaterialStyle.surfaceContainerHighest
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 146, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text(playlist.name)
                    .font(MaterialStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(MaterialStyle.ink)
                    .lineLimit(2)
                    .frame(width: 146, alignment: .leading)
            }
            .padding(10)
            .background(
                MaterialSurfaceBackground(cornerRadius: 28, elevated: false, role: .container)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }

    private var materialHeroSong: Song? {
        playerManager.currentSong ?? viewModel.dailySongs.first ?? viewModel.qqNewSongs.first
    }

    private var materialHeroQueue: [Song] {
        if let current = playerManager.currentSong {
            return [current]
        }
        if !viewModel.dailySongs.isEmpty {
            return viewModel.dailySongs
        }
        return viewModel.qqNewSongs
    }

    private var materialPlaylists: [Playlist] {
        Array((viewModel.recommendPlaylists + viewModel.qqRecommendPlaylists).prefix(16))
    }

    private func materialHeroSubtitle(for song: Song?) -> String {
        if let song {
            let artist = song.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
            return artist.isEmpty ? String(localized: "Monologue") : artist
        }
        if hitokotoEnabled,
           let hitokoto = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hitokoto.isEmpty {
            return hitokoto
        }
        return String(localized: "Monologue")
    }

    private func showHomeContent() {
        guard !appeared else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            appeared = true
        }
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
    private func destinationView(for destination: HomeView.HomeDestination) -> some View {
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
        }
    }
}

private struct MaterialSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(MaterialStyle.titleFont(20, weight: .bold))
                .foregroundStyle(MaterialStyle.ink)
                .lineLimit(1)

            Spacer(minLength: 10)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(MaterialStyle.labelFont(12, weight: .bold))
                        .foregroundStyle(MaterialStyle.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(MaterialStyle.primary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MaterialPlayButton: View {
    var isPlaying: Bool

    var body: some View {
        MonologueIcon(icon: isPlaying ? .pause : .play, size: 18, color: MaterialStyle.onPrimary, lineWidth: 1.9)
            .frame(width: 48, height: 48)
            .background(Circle().fill(MaterialStyle.primary))
            .shadow(color: MaterialStyle.primary.opacity(0.24), radius: 14, x: 0, y: 8)
    }
}

private struct MaterialSmallPlayBadge: View {
    var isPlaying: Bool
    var tint: Color = MaterialStyle.primary

    var body: some View {
        MonologueIcon(icon: isPlaying ? .pause : .play, size: 13, color: MaterialStyle.onPrimary, lineWidth: 1.8)
            .frame(width: 34, height: 34)
            .background(Circle().fill(tint))
            .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

private struct MaterialAmbientEqualizer: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0 ..< 5, id: \.self) { index in
                Capsule()
                    .fill(MaterialStyle.primary.opacity(index == 2 ? 0.9 : 0.46))
                    .frame(width: 8, height: CGFloat([22, 38, 56, 34, 46][index]))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension View {
    func materialAppear(_ appeared: Bool, order: Int) -> some View {
        opacity(1)
            .offset(y: appeared ? 0 : 10)
            .scaleEffect(appeared ? 1 : 0.99)
            .animation(
                .spring(response: 0.38, dampingFraction: 0.88).delay(Double(order) * 0.035),
                value: appeared
            )
    }
}
