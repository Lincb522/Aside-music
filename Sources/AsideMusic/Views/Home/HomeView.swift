import SwiftUI

struct HomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @State private var showPersonalFM = false
    @State private var navigationPath = NavigationPath()
    @State private var bannerWebURL: URL?
    @State private var appeared = false

    enum HomeDestination: Hashable {
        case search, dailyRecommend, playlist(Playlist), artist(Int), album(Int), mvDiscover, newSongExpress

        func hash(into hasher: inout Hasher) {
            switch self {
            case .search:           hasher.combine("search")
            case .dailyRecommend:   hasher.combine("daily")
            case .playlist(let p):  hasher.combine("p_\(p.id)")
            case .artist(let id):   hasher.combine("a_\(id)")
            case .album(let id):    hasher.combine("al_\(id)")
            case .mvDiscover:       hasher.combine("mv")
            case .newSongExpress:   hasher.combine("newSong")
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.search, .search), (.dailyRecommend, .dailyRecommend),
                 (.mvDiscover, .mvDiscover), (.newSongExpress, .newSongExpress): return true
            case (.playlist(let l), .playlist(let r)): return l.id == r.id
            case (.artist(let l), .artist(let r)): return l == r
            case (.album(let l), .album(let r)): return l == r
            default: return false
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AsideBackground().ignoresSafeArea()

                if viewModel.isLoading {
                    AsideLoadingView(text: "LOADING HOME")
                } else {
                    scrollBody
                }
            }
            .onAppear {
                if viewModel.dailySongs.isEmpty { viewModel.fetchData() }
                if !appeared {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) {
                        appeared = true
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeDestination.self, destination: destinationView)
            .fullScreenCover(isPresented: $showPersonalFM) { PersonalFMView() }
            .fullScreenCover(item: $bannerWebURL) { url in AsideWebView(url: url, title: nil) }
        }
    }


    // MARK: - Scroll Body

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶栏
                HomeHeader(
                    userProfile: viewModel.userProfile,
                    onPersonalFM: { showPersonalFM = true },
                    onSearch: { navigationPath.append(HomeDestination.search) }
                )
                .stagger(appeared, order: 0)

                // 每日推荐 — 大色块卡片（最醒目的位置）
                if !viewModel.dailySongs.isEmpty {
                    HomeDailySection(
                        songs: viewModel.dailySongs,
                        onViewAll: { navigationPath.append(HomeDestination.dailyRecommend) },
                        onPlay: { song in playerManager.play(song: song, in: viewModel.dailySongs) }
                    )
                    .stagger(appeared, order: 1)
                }

                // NCM 推荐歌单 — 方形封面横滑
                if !viewModel.recommendPlaylists.isEmpty {
                    HomeNCMPlaylistSection(
                        playlists: viewModel.recommendPlaylists,
                        onViewAll: {
                            NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
                        },
                        onTap: { pl in navigationPath.append(HomeDestination.playlist(pl)) }
                    )
                    .stagger(appeared, order: 2)
                }

                // QQ 推荐歌单 — 宽封面横滑
                if !viewModel.qqRecommendPlaylists.isEmpty {
                    HomeQQPlaylistSection(
                        playlists: viewModel.qqRecommendPlaylists,
                        onTap: { pl in navigationPath.append(HomeDestination.playlist(pl)) }
                    )
                    .stagger(appeared, order: 3)
                }

                // QQ 新歌 — 大号数字排版
                if !viewModel.qqNewSongs.isEmpty {
                    HomeNewSongsSection(songs: viewModel.qqNewSongs) { song in
                        playerManager.play(song: song, in: viewModel.qqNewSongs)
                    }
                    .stagger(appeared, order: 4)
                }

                // 底部入口 — 渐变色块
                HomeEntryCards(
                    onNewSongExpress: { navigationPath.append(HomeDestination.newSongExpress) },
                    onMVDiscover: { navigationPath.append(HomeDestination.mvDiscover) }
                )
                .stagger(appeared, order: 5)

                Color.clear.frame(height: 120)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { viewModel.fetchData() }
    }

    // MARK: - Banner Tap

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run { PlayerManager.shared.playSingle(song: song) }
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
            navigationPath.append(HomeDestination.playlist(pl))
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
        case .artist(let id):   ArtistDetailView(artistId: id)
        case .album(let id):    AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil)
        case .mvDiscover:       MVDiscoverView()
        case .newSongExpress:   NewSongExpressView()
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
