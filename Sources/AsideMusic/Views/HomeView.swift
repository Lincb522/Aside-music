import SwiftUI
import Combine

// MARK: - Home View
struct HomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @State private var searchText = ""
    @State private var showPersonalFM = false
    @State private var navigationPath = NavigationPath()

    typealias Theme = PlaylistDetailView.Theme

    enum HomeDestination: Hashable {
        case search
        case dailyRecommend
        case playlist(Playlist)
        case artist(Int)
        case mvDiscover

        func hash(into hasher: inout Hasher) {
            switch self {
            case .search: hasher.combine("search")
            case .dailyRecommend: hasher.combine("daily")
            case .playlist(let p): hasher.combine("p_\(p.id)")
            case .artist(let id): hasher.combine("a_\(id)")
            case .mvDiscover: hasher.combine("mv")
            }
        }

        static func == (lhs: HomeDestination, rhs: HomeDestination) -> Bool {
            switch (lhs, rhs) {
            case (.search, .search): return true
            case (.dailyRecommend, .dailyRecommend): return true
            case (.playlist(let l), .playlist(let r)): return l.id == r.id
            case (.artist(let l), .artist(let r)): return l == r
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
                        VStack(spacing: 20) {
                            headerSection

                            if !viewModel.banners.isEmpty {
                                bannerSection
                            } else if !viewModel.popularSongs.isEmpty {
                                heroSection
                            }

                            if !viewModel.dailySongs.isEmpty {
                                dailyRecommendationsSection
                            }

                            if !viewModel.recommendPlaylists.isEmpty {
                                recommendedPlaylistsSection
                            }

                            // MV 入口
                            mvEntrySection

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
                case .mvDiscover:
                    MVDiscoverView()
                }
            }
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 20) {
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
                                AsideIcon(icon: .profile, size: 20, color: Theme.secondaryText)
                            )
                            .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(greetingMessage))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                        Text(viewModel.userProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text)
                    }
                }

                Spacer()

                Button(action: { showPersonalFM = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.asideCardBackground)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

                        AsideIcon(icon: .fm, size: 24, color: Theme.accent)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())

                // TODO: 通知功能待实现
                NavigationLink(value: HomeDestination.search) {
                    ZStack(alignment: .topTrailing) {
                        AsideIcon(icon: .bell, size: 26, color: Theme.text)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.asideCardBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, DeviceLayout.headerTopPadding)

            Button(action: {
                navigationPath.append(HomeDestination.search)
            }) {
                HStack {
                    AsideIcon(icon: .search, size: 22, color: Theme.secondaryText)

                    Text(viewModel.hotSearch.isEmpty ? NSLocalizedString("search_placeholder", comment: "") : viewModel.hotSearch)
                        .foregroundColor(Theme.secondaryText.opacity(0.7))
                        .font(.rounded(size: 16))
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.asideCardBackground)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
        }
    }

    private var bannerSection: some View {
        TabView {
            ForEach(viewModel.banners) { banner in
                CachedAsyncImage(url: banner.imageUrl) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: 130)
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 150)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("new_releases"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 24)

            TabView {
                ForEach(viewModel.popularSongs.prefix(5)) { song in
                    Button(action: { PlayerManager.shared.play(song: song, in: Array(viewModel.popularSongs.prefix(5))) }) {
                        HeroCard(song: song)
                    }
                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
                    .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 260)
        }
    }

    private var dailyRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("made_for_you"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)

                    Text(LocalizedStringKey("fresh_tunes_daily"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }

                Spacer()

                Button(action: {
                    navigationPath.append(HomeDestination.dailyRecommend)
                }) {
                    Text(LocalizedStringKey("view_all"))
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(viewModel.dailySongs) { song in
                        SongCard(song: song) {
                            PlayerManager.shared.play(song: song, in: viewModel.dailySongs)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private var recommendedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: NSLocalizedString("playlists_love", comment: ""),
                subtitle: NSLocalizedString("based_on_taste", comment: ""),
                action: {
                    NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
                }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(viewModel.recommendPlaylists) { playlist in
                        Button(action: {
                            navigationPath.append(HomeDestination.playlist(playlist))
                        }) {
                            PlaylistVerticalCard(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "good_morning"
        case 12..<17: return "good_afternoon"
        default: return "good_evening"
        }
    }

    // MARK: - MV 入口

    private var mvEntrySection: some View {
        Button(action: {
            navigationPath.append(HomeDestination.mvDiscover)
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.asideAccentRed.opacity(0.1))
                        .frame(width: 52, height: 52)
                    AsideIcon(icon: .playCircleFill, size: 24, color: .asideAccentRed)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("MV 专区")
                        .font(.rounded(size: 17, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    Text("看最新最热的音乐视频")
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }

                Spacer()

                AsideIcon(icon: .chevronRight, size: 16, color: .asideTextSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.asideCardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 24)
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
}

// MARK: - Components

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    var action: (() -> Void)? = nil

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }
            }

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text(LocalizedStringKey("view_all"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct HeroCard: View {
    let song: Song
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: song.coverUrl) {
                Color.white.opacity(0.3)
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
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

struct SongCard: View {
    let song: Song
    let onTap: () -> Void
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.white.opacity(0.5)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(song.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
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
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    Color.white.opacity(0.5)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .clipped()
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                HStack(spacing: 4) {
                    AsideIcon(icon: .play, size: 10, color: .white)
                    Text(formatCount(playlist.playCount))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(10)
            }
            .frame(width: 140, height: 140)

            Text(playlist.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 140, alignment: .leading)
                .frame(height: 40, alignment: .top)
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
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.white.opacity(0.5)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)

                    Text(song.artistName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                AsideIcon(icon: .play, size: 14, color: Theme.accent)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.asideMilk)
                    )
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.asideCardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
}
