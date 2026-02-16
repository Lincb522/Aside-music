import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @State private var showPersonalFM = false
    @State private var navigationPath = NavigationPath()
    @State private var bannerWebURL: URL?

    typealias Theme = PlaylistDetailView.Theme

    enum HomeDestination: Hashable {
        case search
        case dailyRecommend
        case playlist(Playlist)
        case artist(Int)
        case album(Int)
        case mvDiscover

        func hash(into hasher: inout Hasher) {
            switch self {
            case .search: hasher.combine("search")
            case .dailyRecommend: hasher.combine("daily")
            case .playlist(let p): hasher.combine("p_\(p.id)")
            case .artist(let id): hasher.combine("a_\(id)")
            case .album(let id): hasher.combine("al_\(id)")
            case .mvDiscover: hasher.combine("mv")
            }
        }

        static func == (lhs: HomeDestination, rhs: HomeDestination) -> Bool {
            switch (lhs, rhs) {
            case (.search, .search): return true
            case (.dailyRecommend, .dailyRecommend): return true
            case (.playlist(let l), .playlist(let r)): return l.id == r.id
            case (.artist(let l), .artist(let r)): return l == r
            case (.album(let l), .album(let r)): return l == r
            case (.mvDiscover, .mvDiscover): return true
            default: return false
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    AsideLoadingView(text: "LOADING HOME")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // 顶部栏
                            headerSection

                            // Banner 轮播
                            if !viewModel.banners.isEmpty {
                                bannerSection
                            }

                            // 每日推荐
                            if !viewModel.dailySongs.isEmpty {
                                dailyRecommendationsSection
                            }

                            // 推荐歌单
                            if !viewModel.recommendPlaylists.isEmpty {
                                recommendedPlaylistsSection
                            }

                            // 热门新歌 Top 5
                            if !viewModel.popularSongs.isEmpty {
                                hotNewSongsSection
                            }

                            // 底部双卡片入口
                            bottomEntryCards

                            Color.clear.frame(height: 120)
                        }
                    }
                    .refreshable {
                        viewModel.fetchData()
                    }
                }
            }
            .onAppear {
                if viewModel.dailySongs.isEmpty {
                    viewModel.fetchData()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .search:
                    SearchView()
                case .dailyRecommend:
                    DailyRecommendView()
                case .playlist(let playlist):
                    PlaylistDetailView(playlist: playlist)
                case .artist(let id):
                    ArtistDetailView(artistId: id)
                case .album(let id):
                    AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil)
                case .mvDiscover:
                    MVDiscoverView()
                }
            }
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(item: $bannerWebURL) { url in
                AsideWebView(url: url, title: nil)
            }
        }
    }

    // MARK: - 顶部栏

    private var headerSection: some View {
        HStack {
            HStack(spacing: 12) {
                if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
                    CachedAsyncImage(url: url) {
                        Circle().fill(Color.gray.opacity(0.05))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.05))
                        .frame(width: 44, height: 44)
                        .overlay(
                            AsideIcon(icon: .profile, size: 20, color: .asideTextSecondary)
                        )
                        .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(greetingMessage))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                    Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                }
            }

            Spacer()

            Button(action: { showPersonalFM = true }) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 44, height: 44)
                    AsideIcon(icon: .fm, size: 22, color: .asideTextPrimary)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())

            NavigationLink(value: HomeDestination.search) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 44, height: 44)
                    AsideIcon(icon: .search, size: 20, color: .asideTextPrimary)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }

    // MARK: - 搜索栏（保留，作为热搜展示入口）

    private var searchBarSection: some View {
        Button(action: {
            navigationPath.append(HomeDestination.search)
        }) {
            HStack {
                AsideIcon(icon: .search, size: 20, color: .asideTextSecondary)

                Text(viewModel.hotSearch.isEmpty ? NSLocalizedString("search_placeholder", comment: "") : viewModel.hotSearch)
                    .foregroundColor(.asideTextSecondary.opacity(0.6))
                    .font(.rounded(size: 15))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }

    // MARK: - Banner 轮播

    private var bannerSection: some View {
        TabView {
            ForEach(viewModel.banners) { banner in
                Button(action: { handleBannerTap(banner) }) {
                    CachedAsyncImage(url: banner.imageUrl) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.asideSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 140)
    }

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run {
                            PlayerManager.shared.playSingle(song: song)
                        }
                    }
                } catch {
                    AppLogger.error("Banner 歌曲加载失败: \(error)")
                }
            }
        case 10:
            navigationPath.append(HomeDestination.album(banner.targetId))
        case 1000:
            let playlist = Playlist(id: banner.targetId, name: banner.typeTitle ?? "歌单", coverImgUrl: banner.pic, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil)
            navigationPath.append(HomeDestination.playlist(playlist))
        case 1004:
            navigationPath.append(HomeDestination.mvDiscover)
        default:
            if let urlStr = banner.url, let url = URL(string: urlStr) {
                bannerWebURL = url
            }
        }
    }

    // MARK: - 每日推荐

    private var dailyRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("made_for_you"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Text(LocalizedStringKey("fresh_tunes_daily"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }

                Spacer()

                Button(action: {
                    navigationPath.append(HomeDestination.dailyRecommend)
                }) {
                    Text(LocalizedStringKey("view_all"))
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.dailySongs) { song in
                        SongCard(song: song) {
                            playerManager.play(song: song, in: viewModel.dailySongs)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 推荐歌单

    private var recommendedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: NSLocalizedString("playlists_love", comment: ""),
                subtitle: NSLocalizedString("based_on_taste", comment: ""),
                action: {
                    NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
                }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recommendPlaylists) { playlist in
                        Button(action: {
                            navigationPath.append(HomeDestination.playlist(playlist))
                        }) {
                            PlaylistVerticalCard(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 热门新歌 Top 5

    private var hotNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("new_releases"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.popularSongs.prefix(5).enumerated()), id: \.element.id) { index, song in
                    Button(action: {
                        playerManager.play(song: song, in: viewModel.popularSongs)
                    }) {
                        HStack(spacing: 14) {
                            // 排名序号
                            Text("\(index + 1)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(index < 3 ? .asideTextPrimary : .asideTextSecondary)
                                .frame(width: 28)

                            // 封面
                            CachedAsyncImage(url: song.coverUrl) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.asideSeparator)
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                Text(song.artistName)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.asideTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if playerManager.currentSong?.id == song.id {
                                PlayingVisualizerView(isAnimating: playerManager.isPlaying, color: .asideTextPrimary)
                                    .frame(width: 20)
                            } else {
                                AsideIcon(icon: .play, size: 14, color: .asideTextSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.asideSeparator)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
                }
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
            .padding(.horizontal, 24)
        }
    }

    // MARK: - MV 入口

    private var bottomEntryCards: some View {
        Button(action: {
            navigationPath.append(HomeDestination.mvDiscover)
        }) {
            HStack(spacing: 14) {
                AsideIcon(icon: .playCircleFill, size: 24, color: .asideTextPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MV 专区")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Text("看最新最热的音乐视频")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
                Spacer()
                AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
        .padding(.horizontal, 24)
    }

    // MARK: - 工具

    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "good_morning"
        case 12..<17: return "good_afternoon"
        default: return "good_evening"
        }
    }
}


// MARK: - 子组件

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            }

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text(LocalizedStringKey("view_all"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct SongCard: View {
    let song: Song
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.asideSeparator
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 140)
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }
}

struct PlaylistVerticalCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    Color.asideSeparator
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                HStack(spacing: 4) {
                    AsideIcon(icon: .play, size: 8, color: .white)
                    Text(formatCount(playlist.playCount))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(8)
            }
            .frame(width: 140, height: 140)

            Text(playlist.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 140, alignment: .leading)
                .frame(height: 36, alignment: .top)
        }
    }

    private func formatCount(_ count: Int?) -> String {
        guard let count = count else { return "0" }
        let locale = Locale.current
        if locale.language.languageCode?.identifier == "zh" {
            if count >= 100000000 {
                return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100000000)
            } else if count >= 10000 {
                return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10000)
            }
        } else {
            if count >= 1000000000 {
                return String(format: "%.1fB", Double(count) / 1000000000)
            } else if count >= 1000000 {
                return String(format: "%.1fM", Double(count) / 1000000)
            } else if count >= 1000 {
                return String(format: "%.1fK", Double(count) / 1000)
            }
        }
        return "\(count)"
    }
}

struct MiniSongRow: View {
    let song: Song
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.asideSeparator
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                AsideIcon(icon: .play, size: 14, color: .asideTextPrimary)
                    .padding(8)
                    .background(Circle().fill(Color.asideMilk))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
}

struct HeroCard: View {
    let song: Song

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: song.coverUrl) {
                Color.asideSeparator
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: 260)
            .clipped()

            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("tag_new_release"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(20)

                    Text(song.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }

                Spacer()

                AsideIcon(icon: .play, size: 64, color: .white)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .padding(24)
        }
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}
