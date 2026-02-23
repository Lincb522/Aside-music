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
        case newSongExpress

        func hash(into hasher: inout Hasher) {
            switch self {
            case .search: hasher.combine("search")
            case .dailyRecommend: hasher.combine("daily")
            case .playlist(let p): hasher.combine("p_\(p.id)")
            case .artist(let id): hasher.combine("a_\(id)")
            case .album(let id): hasher.combine("al_\(id)")
            case .mvDiscover: hasher.combine("mv")
            case .newSongExpress: hasher.combine("newSong")
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
            case (.newSongExpress, .newSongExpress): return true
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

                            // QQ 音乐推荐歌单
                            if !viewModel.qqRecommendPlaylists.isEmpty {
                                qqRecommendPlaylistsSection
                            }

                            // QQ 音乐推荐新歌
                            if !viewModel.qqNewSongs.isEmpty {
                                qqNewSongsSection
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
                case .newSongExpress:
                    NewSongExpressView()
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
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.asideSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 24)
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 150)
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
            let playlist = Playlist(id: banner.targetId, name: banner.typeTitle ?? String(localized: "home_playlist"), coverImgUrl: banner.pic, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil)
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
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("view_all"))
                            .font(.rounded(size: 13, weight: .semibold))
                            .foregroundColor(.asideTextSecondary)
                        AsideIcon(icon: .chevronRight, size: 10, color: .asideTextSecondary)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
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
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 热门新歌 Top 5

    private var hotNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: NSLocalizedString("new_releases", comment: ""),
                subtitle: nil,
                action: { navigationPath.append(HomeDestination.newSongExpress) }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // 第一首大卡片
                    if let first = viewModel.popularSongs.first {
                        Button(action: {
                            playerManager.play(song: first, in: viewModel.popularSongs)
                        }) {
                            ZStack(alignment: .bottomLeading) {
                                CachedAsyncImage(url: first.coverUrl?.sized(400)) {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.asideSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.7)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("01")
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(first.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(first.artistName)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                                .padding(16)

                                // 播放状态
                                if playerManager.currentSong?.id == first.id {
                                    PlayingVisualizerView(isAnimating: playerManager.isPlaying, color: .white)
                                        .frame(width: 20)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                }
                            }
                            .frame(width: 200, height: 200)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }

                    // 2-5 竖排小卡片
                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.popularSongs.dropFirst().prefix(4).enumerated()), id: \.element.id) { index, song in
                            Button(action: {
                                playerManager.play(song: song, in: viewModel.popularSongs)
                            }) {
                                HStack(spacing: 12) {
                                    Text(String(format: "%02d", index + 2))
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(index < 2 ? .asideTextPrimary : .asideTextSecondary.opacity(0.6))
                                        .frame(width: 24)

                                    CachedAsyncImage(url: song.coverUrl) {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.asideSeparator)
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.name)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(.asideTextPrimary)
                                            .lineLimit(1)
                                        Text(song.artistName)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.asideTextSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)

                                    if playerManager.currentSong?.id == song.id {
                                        PlayingVisualizerView(isAnimating: playerManager.isPlaying, color: .asideTextPrimary)
                                            .frame(width: 16)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
                        }
                    }
                    .frame(width: 220)
                    .padding(.vertical, 8)
                    .background(
                        Color.clear // glassEffect applied via modifier
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    )
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - QQ 音乐推荐歌单

    private var qqRecommendPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: NSLocalizedString("qq_recommend_playlists", comment: ""),
                subtitle: NSLocalizedString("qq_recommend_playlists_desc", comment: "")
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.qqRecommendPlaylists.prefix(10)) { playlist in
                        Button(action: {
                            navigationPath.append(HomeDestination.playlist(playlist))
                        }) {
                            PlaylistVerticalCard(playlist: playlist)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - QQ 音乐推荐新歌

    private var qqNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: NSLocalizedString("qq_new_songs", comment: ""),
                subtitle: NSLocalizedString("qq_new_songs_desc", comment: "")
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.qqNewSongs.prefix(10)) { song in
                        SongCard(song: song) {
                            playerManager.play(song: song, in: viewModel.qqNewSongs)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - MV 入口

    private var bottomEntryCards: some View {
        VStack(spacing: 12) {
            // 新歌速递入口
            NavigationLink(value: HomeDestination.newSongExpress) {
                entryCardRow(icon: .musicNote, title: "new_song_express", subtitle: "new_releases")
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
            
            // MV 入口
            Button(action: {
                navigationPath.append(HomeDestination.mvDiscover)
            }) {
                entryCardRow(icon: .playCircleFill, title: "home_mv_zone", subtitle: "home_mv_zone_desc")
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
        }
        .padding(.horizontal, 24)
    }

    private func entryCardRow(icon: AsideIcon.IconType, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.asideAccent.opacity(0.1))
                    .frame(width: 40, height: 40)
                AsideIcon(icon: icon, size: 20, color: .asideAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text(LocalizedStringKey(subtitle))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            Spacer()
            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary.opacity(0.6))
        }
        .padding(16)
        .background(
            Color.clear // glassEffect applied via modifier
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("view_all"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        AsideIcon(icon: .chevronRight, size: 10, color: .asideTextSecondary)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
        .padding(.horizontal, 24)
    }
}

struct SongCard: View {
    let song: Song
    let onTap: () -> Void
    @ObservedObject private var player = PlayerManager.shared

    private var isCurrentSong: Bool {
        player.currentSong?.id == song.id
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.asideSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                    // 正在播放指示器
                    if isCurrentSong {
                        PlayingVisualizerView(isAnimating: player.isPlaying, color: .white)
                            .frame(width: 18)
                            .padding(10)
                    }
                }
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(isCurrentSong ? .asideAccent : .asideTextPrimary)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 150)
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
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.asideSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                if let count = playlist.playCount, count > 0 {
                    HStack(spacing: 3) {
                        AsideIcon(icon: .play, size: 7, color: .white)
                        Text(formatCount(count))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.clear).glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .clipShape(Capsule())
                    .padding(8)
                }
            }
            .frame(width: 150, height: 150)

            Text(playlist.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 150, alignment: .leading)
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.asideSeparator)
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
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
}

struct HeroCard: View {
    let song: Song

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: song.coverUrl) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.asideSeparator)
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
