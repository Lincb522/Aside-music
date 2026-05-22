#if os(macOS)
import SwiftUI
import HiconIcons

struct MacHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var player = PlayerManager.shared
    @State private var navigationPath = NavigationPath()
    @State private var appeared = false
    @State private var bannerWebURL: URL?
    @State private var showPersonalFM = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground().ignoresSafeArea()

                if viewModel.isLoading {
                    MonologueLoadingView(text: "LOADING HOME")
                } else {
                    scrollContent
                }
            }
            .onAppear {
                viewModel.ensureHomeDataLoaded(reason: "mac home appear")
                if !appeared {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) {
                        appeared = true
                    }
                }
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { dest in
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
            .monologueSheet(isPresented: $showPersonalFM, preset: .detail) {
                PersonalFMView()
                    .frame(minWidth: 480, minHeight: 640)
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                macGreetingHeader
                    .staggerMac(appeared, order: 0)
                    .padding(.bottom, 24)

                if !viewModel.banners.isEmpty {
                    macBannerSection
                        .staggerMac(appeared, order: 1)
                        .padding(.bottom, 36)
                }

                if !viewModel.dailySongs.isEmpty {
                    macDailySection
                        .staggerMac(appeared, order: 2)
                        .padding(.bottom, 40)
                }

                if !viewModel.recommendPlaylists.isEmpty {
                    macPlaylistGrid(
                        title: String(localized: "ncm_recommend"),
                        playlists: viewModel.recommendPlaylists
                    )
                    .staggerMac(appeared, order: 3)
                    .padding(.bottom, 40)
                }

                if !viewModel.qqRecommendPlaylists.isEmpty {
                    macPlaylistGrid(
                        title: String(localized: "QCM推荐"),
                        playlists: viewModel.qqRecommendPlaylists
                    )
                    .staggerMac(appeared, order: 4)
                    .padding(.bottom, 40)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    macNewSongsSection
                        .staggerMac(appeared, order: 5)
                        .padding(.bottom, 40)
                }

                macEntryCards
                    .staggerMac(appeared, order: 6)

                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Greeting

    private var macGreetingHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                let hitokotoText = viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if SettingsManager.shared.hitokotoEnabled, !hitokotoText.isEmpty {
                    Text(hitokotoText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .lineLimit(1)
                } else if SettingsManager.shared.hitokotoEnabled {
                    MonoWordmarkImage(height: 13)
                        .frame(maxWidth: 54, alignment: .leading)
                } else {
                    Text(greetingText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                }

                Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.monologueTextPrimary, .monologueTextPrimary.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }

            Spacer()

            HStack(spacing: 10) {
                MacActionPill(icon: "radio.fill", label: String(localized: "私人FM")) {
                    showPersonalFM = true
                }
                MacActionPill(icon: "magnifyingglass", label: String(localized: "search_title")) {
                    navigationPath.append(HomeView.HomeDestination.search)
                }
            }
        }
        .padding(.top, 8)
    }

    private var greetingText: String {
        MonologueTimeGreeting.localizedText
    }

    // MARK: - Banner

    private var macBannerSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(viewModel.banners) { banner in
                    MacBannerCard(banner: banner) {
                        handleBannerTap(banner)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
    }

    // MARK: - Daily Songs

    private var macDailySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                macSectionTitle(String(localized: "made_for_you"), subtitle: "\(viewModel.dailySongs.count) \(NSLocalizedString("fresh_tunes_daily", comment: ""))")

                Spacer()

                MacViewAllButton {
                    navigationPath.append(HomeView.HomeDestination.dailyRecommend)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                ForEach(Array(viewModel.dailySongs.prefix(10).enumerated()), id: \.element.id) { idx, song in
                    MacSongCard(song: song, rank: idx + 1) {
                        player.play(song: song, in: viewModel.dailySongs)
                    }
                }
            }
        }
    }

    // MARK: - Playlist Grid

    private func macPlaylistGrid(title: String, playlists: [Playlist]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            macSectionTitle(title)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
                ForEach(playlists.prefix(10)) { playlist in
                    MacPlaylistCard(playlist: playlist) {
                        navigationPath.append(HomeView.HomeDestination.playlist(playlist))
                    }
                }
            }
        }
    }

    // MARK: - New Songs

    private var macNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                macSectionTitle(String(localized: "QCM新歌速递"))
                Spacer()
                Button {
                    navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
                } label: {
                    Text(LocalizedStringKey("view_all"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 8) {
                ForEach(Array(viewModel.qqNewSongs.prefix(9).enumerated()), id: \.element.id) { idx, song in
                    MacSongRow(song: song, index: idx + 1) {
                        player.play(song: song, in: viewModel.qqNewSongs)
                    }
                }
            }
        }
    }

    // MARK: - Entry Cards

    private var macEntryCards: some View {
        HStack(spacing: 16) {
            MacFeatureCard(icon: "music.note.list", title: String(localized: "new_song_express"), gradient: [Color(hex: "667eea"), Color(hex: "764ba2")]) {
                navigationPath.append(HomeView.HomeDestination.newSongExpress)
            }
            MacFeatureCard(icon: "play.rectangle.fill", title: "MV", gradient: [Color(hex: "f093fb"), Color(hex: "f5576c")]) {
                navigationPath.append(HomeView.HomeDestination.mvDiscover)
            }
        }
    }

    // MARK: - Section Title

    private func macSectionTitle(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Banner Tap

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                if let songs = try? await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async(),
                   let song = songs.first {
                    await MainActor.run { player.playSingle(song: song) }
                }
            }
        case 10:
            navigationPath.append(HomeView.HomeDestination.album(banner.targetId))
        case 1000:
            let pl = Playlist(
                id: banner.targetId, name: banner.typeTitle ?? "Playlist",
                coverImgUrl: banner.pic, picUrl: nil,
                trackCount: nil, playCount: nil, subscribedCount: nil,
                shareCount: nil, commentCount: nil, creator: nil,
                description: nil, tags: nil
            )
            navigationPath.append(HomeView.HomeDestination.bannerPlaylist(pl, banner.pic))
        default:
            if let urlStr = banner.url, let url = URL(string: urlStr) { bannerWebURL = url }
        }
    }
}

// MARK: - Components

struct MacActionPill: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isHovered ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MacViewAllButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(LocalizedStringKey("view_all"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(isHovered ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(isHovered ? 0.08 : 0.04)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MacBannerCard: View {
    let banner: Banner
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            CachedAsyncImage(url: banner.imageUrl) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 340, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.06), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MacSongCard: View {
    let song: Song
    let rank: Int
    let action: () -> Void

    @ObservedObject private var player = PlayerManager.shared
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id

        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 0).fill(Color.primary.opacity(0.04))
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()

                    if isHovered || isCurrent {
                        ZStack {
                            Color.black.opacity(0.3)

                            if isCurrent && player.isPlaying {
                                PlayingVisualizerView(isAnimating: true, color: .white)
                                    .frame(width: 24, height: 20)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white)
                            }
                        }
                        .transition(.opacity)
                    }

                    Text("\(rank)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.black.opacity(0.3)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(8)
                }
                .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(isCurrent ? .primary : .secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MacPlaylistCard: View {
    let playlist: Playlist
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    CachedAsyncImage(url: playlist.coverUrl) {
                        RoundedRectangle(cornerRadius: 0).fill(Color.primary.opacity(0.04))
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()

                    if isHovered {
                        ZStack {
                            Color.black.opacity(0.25)
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .shadow(radius: 8)
                        }
                        .transition(.opacity)
                    }
                }
                .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let count = playlist.playCount, count > 0 {
                        Text(formatCount(count))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 { return String(localized: "\(count / 100_000_000)亿次播放") }
        if count >= 10_000 { return String(localized: "\(count / 10_000)万次播放") }
        return String(localized: "\(count)次播放")
    }
}

struct MacSongRow: View {
    let song: Song
    let index: Int
    let action: () -> Void

    @ObservedObject private var player = PlayerManager.shared
    @State private var isHovered = false

    var body: some View {
        let isCurrent = player.currentSong?.id == song.id

        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    if isCurrent {
                        PlayingVisualizerView(isAnimating: player.isPlaying, color: .primary)
                            .frame(width: 18, height: 14)
                    } else {
                        Text("\(index)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 24)

                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.04))
                }
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(isCurrent ? .primary : .primary)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MacFeatureCard: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: gradient.first!.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 12 : 6, y: isHovered ? 4 : 2)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Stagger Animation

private extension View {
    func staggerMac(_ appeared: Bool, order: Int) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.82).delay(Double(order) * 0.05),
                value: appeared
            )
    }
}
#endif
