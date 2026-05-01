import SwiftUI

struct HomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showPersonalFM = false
    @State private var navigationPath = NavigationPath()
    @State private var bannerWebURL: URL?
    @State private var appeared = false

    enum HomeDestination: Hashable {
        case search, dailyRecommend, playlist(Playlist), bannerPlaylist(Playlist, String?), artist(Int), album(Int), mvDiscover, newSongExpress, qcmNewSongs

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
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.search, .search), (.dailyRecommend, .dailyRecommend),
                 (.mvDiscover, .mvDiscover), (.newSongExpress, .newSongExpress),
                 (.qcmNewSongs, .qcmNewSongs): return true
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

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true).ignoresSafeArea()

                if viewModel.isLoading {
                    MonologueLoadingView(text: "LOADING HOME")
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
                    }) {
                        homeAvatarView
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showPersonalFM = true
                        }) {
                            MonologueIcon(icon: .fm, size: 16)
                                .padding(3)
                        }

                        Button(action: {
                            navigationPath.append(HomeDestination.search)
                        }) {
                            MonologueIcon(icon: .search, size: 16)
                                .padding(3)
                        }
                    }
                }
            }
            .navigationDestination(for: HomeDestination.self, destination: destinationView)
            .fullScreenCover(isPresented: $showPersonalFM) { PersonalFMView() }
            .fullScreenCover(item: $bannerWebURL) { url in MonologueWebView(url: url, title: nil) }
        }
    }


    // MARK: - Toolbar Greeting

    private var homeToolbarGreeting: some View {
        VStack(alignment: .leading, spacing: 1) {
            if SettingsManager.shared.hitokotoEnabled,
               let hitokoto = viewModel.hitokoto, !hitokoto.isEmpty {
                Text(hitokoto)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary.opacity(0.7))
                    .lineLimit(1)
            } else {
                Text(String(localized: LocalizedStringResource(stringLiteral: homeGreetingKey)))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary.opacity(0.7))
            }

            Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Toolbar Avatar

    @ViewBuilder
    private var homeAvatarView: some View {
        let size: CGFloat = 36
        if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) { Circle().fill(Color.monologueSeparator) }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle().fill(Color.monologueSeparator)
                .frame(width: size, height: size)
                .overlay(MonologueIcon(icon: .profile, size: 16, color: .monologueTextSecondary))
        }
    }

    // MARK: - Greeting Section

    private var homeGreetingSection: some View {
        VStack(spacing: 12) {
            greetingRow
            if SettingsManager.shared.hitokotoEnabled,
               let hitokoto = viewModel.hitokoto, !hitokoto.isEmpty {
                hitokotoCard(hitokoto)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var greetingRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: LocalizedStringResource(stringLiteral: homeGreetingKey)))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary.opacity(0.7))

            Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.monologueTextPrimary, .monologueTextPrimary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @State private var hitokotoRefreshing = false

    private func hitokotoCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MonologueSymbolIcon(name: "quote.opening", size: 17, color: .monologueTextPrimary.opacity(0.42))
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.monologueTextPrimary.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    hitokotoRefreshing = true
                }
                viewModel.refreshHitokoto()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation { hitokotoRefreshing = false }
                }
            } label: {
                MonologueIcon(icon: .refresh, size: 12, color: .monologueTextSecondary.opacity(0.5), lineWidth: 1.5)
                    .rotationEffect(.degrees(hitokotoRefreshing ? 360 : 0))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueTextPrimary.opacity(0.04))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var homeGreetingKey: String {
        MonologueTimeGreeting.localizedKey
    }

    // MARK: - Scroll Body

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: 0) {
                homeGreetingSection
                    .padding(.bottom, 14)

                if !viewModel.banners.isEmpty {
                    HomeBannerSection(
                        banners: viewModel.banners,
                        onTap: handleBannerTap
                    )
                    .stagger(appeared, order: 0)
                    .padding(.bottom, 28)
                }

                if !viewModel.dailySongs.isEmpty {
                    HomeDailySection(
                        songs: viewModel.dailySongs,
                        onViewAll: { navigationPath.append(HomeDestination.dailyRecommend) },
                        onPlay: { song in PlayerManager.shared.play(song: song, in: viewModel.dailySongs) }
                    )
                    .stagger(appeared, order: 1)
                    .padding(.bottom, 32)
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    HomeNCMPlaylistSection(
                        playlists: viewModel.recommendPlaylists,
                        onViewAll: {
                            UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
                            NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
                        },
                        onTap: { pl in navigationPath.append(HomeDestination.playlist(pl)) }
                    )
                    .stagger(appeared, order: 2)
                    .padding(.bottom, 32)
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    HomeQQPlaylistSection(
                        playlists: viewModel.qqRecommendPlaylists,
                        onViewAll: {
                            UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
                            NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
                        },
                        onTap: { pl in navigationPath.append(HomeDestination.playlist(pl)) }
                    )
                    .stagger(appeared, order: 3)
                    .padding(.bottom, 32)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    HomeNewSongsSection(
                        songs: viewModel.qqNewSongs,
                        onViewAll: { navigationPath.append(HomeDestination.qcmNewSongs) },
                        onPlay: { song in
                            PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs)
                        }
                    )
                    .stagger(appeared, order: 4)
                    .padding(.bottom, 36)
                }

                HomeEntryCards(
                    onNewSongExpress: { navigationPath.append(HomeDestination.newSongExpress) },
                    onMVDiscover: { navigationPath.append(HomeDestination.mvDiscover) }
                )
                .stagger(appeared, order: 5)

                FloatingBarBottomSpacer()
            }
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
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
