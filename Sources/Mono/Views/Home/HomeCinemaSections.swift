import SwiftUI

// MARK: - Classic Aside "Now Showing" cinema home components
// Adaptive light/dark movie-poster language used only by the classic Aside home.

@MainActor
enum HomeCinemaStyle {
    static var posterWidth: CGFloat { DeviceLayout.usesExpandedLayout ? 172 : 140 }
    static var posterBlockHeight: CGFloat { DeviceLayout.usesExpandedLayout ? 82 : 66 }
    static var posterHeight: CGFloat { posterWidth + posterBlockHeight }
    static var posterCorner: CGFloat { SignalStyle.isActive ? SignalStyle.cardRadius : 14 }
    static var heroHeight: CGFloat { DeviceLayout.bannerHeight }
    static var ticketGold: Color { SignalStyle.isActive ? SignalStyle.accent : Color(hex: "E7B24C") }

    static func kicker(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .heavy, design: SignalStyle.isActive ? .monospaced : .rounded)
    }

    static func filmTitle(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: SignalStyle.isActive ? .monospaced : .serif)
    }

    static func credit(_ size: CGFloat = 9) -> Font {
        .system(size: size, weight: .semibold, design: SignalStyle.isActive ? .monospaced : .rounded)
    }
}

// MARK: - Section Header (ticket stub + uppercase kicker + serif title)

struct CinemaSectionHeader: View {
    let sceneNumber: Int
    let kicker: String
    var title: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(String(format: "%02d", sceneNumber))
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.monoTextPrimary)
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.monoTextPrimary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.monoTextPrimary.opacity(0.14),
                                style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(kicker.uppercased())
                    .font(HomeCinemaStyle.kicker())
                    .tracking(2.6)
                    .foregroundColor(.monoTextSecondary)
                    .lineLimit(1)

                if !title.isEmpty {
                    Text(title)
                        .font(HomeCinemaStyle.filmTitle(20))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 8)

            if let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("view_all"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        MonoIcon(icon: .chevronRight, size: 8, color: .monoTextSecondary)
                    }
                    .foregroundColor(.monoTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.monoTextSecondary.opacity(0.08)))
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }
}

// MARK: - Poster Card (2:3 movie poster with burned-in title)

struct CinemaPosterCard: View {
    let coverURL: URL?
    let title: String
    var credit: String = ""
    var badge: String? = nil
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    var onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let w = HomeCinemaStyle.posterWidth

        Button(action: onTap) {
            VStack(spacing: 0) {
                // Full square cover — shown complete, never cropped
                ZStack(alignment: .top) {
                    CachedAsyncImage(url: coverURL, width: w, height: w) {
                        Rectangle().fill(Color.monoSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: w, height: w)
                    .clipped()

                    HStack(alignment: .top) {
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(0.4)
                                .foregroundColor(SignalStyle.isActive ? SignalStyle.onAccent : .black.opacity(0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(HomeCinemaStyle.ticketGold))
                        }
                        Spacer(minLength: 0)
                        if isCurrent {
                            PlayingVisualizerView(isAnimating: isPlaying, color: .white)
                                .frame(width: 16, height: 12)
                                .padding(6)
                                .background(Circle().fill(.black.opacity(0.42)))
                        }
                    }
                    .padding(8)
                }
                .frame(width: w, height: w)

                // Title plate below (adaptive) — the "one-sheet" credits block
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(HomeCinemaStyle.filmTitle(14, weight: .bold))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !credit.isEmpty {
                        Text(credit.uppercased())
                            .font(HomeCinemaStyle.credit())
                            .tracking(1.2)
                            .foregroundColor(.monoTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .frame(width: w, height: HomeCinemaStyle.posterBlockHeight, alignment: .topLeading)
            }
            .frame(width: w)
            // 半透明卡面：底板透出页面背景色，随任意背景自适应融合；
            // 浅色模式不加投影（投影会在底缘压出灰线），轮廓由卡面自带描边承担
            .background(ClassicAsideEmbeddedSurface(cornerRadius: HomeCinemaStyle.posterCorner))
            .clipShape(RoundedRectangle(cornerRadius: HomeCinemaStyle.posterCorner, style: .continuous))
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.12 : 0),
                radius: colorScheme == .dark ? 8 : 0,
                x: 0,
                y: colorScheme == .dark ? 5 : 0
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
    }
}

// MARK: - Playlist poster rail

struct CinemaPlaylistPosterRail: View {
    let sceneNumber: Int
    let kicker: String
    let title: String
    let playlists: [Playlist]
    var onViewAll: (() -> Void)? = nil
    let onTap: (Playlist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CinemaSectionHeader(sceneNumber: sceneNumber, kicker: kicker, title: title, action: onViewAll)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(Array(playlists.prefix(12))) { playlist in
                        CinemaPosterCard(
                            coverURL: playlist.coverUrl?.sized(400),
                            title: playlist.name,
                            credit: creditText(playlist),
                            onTap: { onTap(playlist) }
                        )
                        .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                .opacity(phase.isIdentity ? 1 : 0.55)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .compatScrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .compatViewAlignedScrollBehavior(limitNever: true)
        }
    }

    private func creditText(_ p: Playlist) -> String {
        if let tc = p.trackCount, tc > 0 {
            return "\(tc) " + NSLocalizedString("songs_unit", comment: "")
        }
        return ""
    }
}

// MARK: - Song poster rail

struct CinemaSongPosterRail: View {
    let sceneNumber: Int
    let kicker: String
    let title: String
    let songs: [Song]
    var showsRank: Bool = false
    var onViewAll: (() -> Void)? = nil
    let onPlay: (Song) -> Void

    @ObservedObject private var playback = SongRowPlaybackModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CinemaSectionHeader(sceneNumber: sceneNumber, kicker: kicker, title: title, action: onViewAll)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(Array(songs.prefix(15).enumerated()), id: \.element.identityKey) { idx, song in
                        let isCurrent = playback.currentSongId == song.id
                        CinemaPosterCard(
                            coverURL: song.coverUrl,
                            title: song.name,
                            credit: song.artistName,
                            badge: showsRank ? String(format: "NO.%d", idx + 1) : nil,
                            isCurrent: isCurrent,
                            isPlaying: isCurrent && playback.isPlaying,
                            onTap: { onPlay(song) }
                        )
                        .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                .opacity(phase.isIdentity ? 1 : 0.55)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .compatScrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .compatViewAlignedScrollBehavior(limitNever: true)
        }
    }
}

// MARK: - Now Showing hero carousel (banners)

struct CinemaHeroCarousel: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var index = 0
    @State private var isVisible = false
    private let timer = Timer.publish(every: 5.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $index) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { i, banner in
                    Button(action: { onTap(banner) }) {
                        heroCard(banner)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: HomeCinemaStyle.heroHeight)
            .onReceive(timer) { _ in
                guard isVisible, banners.count > 1 else { return }
                withAnimation(.easeInOut) { index = (index + 1) % banners.count }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }

            if banners.count > 1 {
                HStack(spacing: 5) {
                    ForEach(banners.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == index
                                  ? Color.monoTextPrimary.opacity(0.85)
                                  : Color.monoTextSecondary.opacity(0.24))
                            .frame(width: i == index ? 18 : 6, height: 5)
                            .animation(.spring(duration: 0.3), value: index)
                    }
                }
            }
        }
    }

    private func heroCard(_ banner: Banner) -> some View {
        let corner: CGFloat = DeviceLayout.usesExpandedLayout ? 22 : 18

        return ZStack(alignment: .topLeading) {
            // Wide banner shown in full at its natural height — no side cropping
            HomeBannerArtwork(url: banner.imageUrl, cornerRadius: corner) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.monoGlassTint)
            }

            Text("NOW SHOWING")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(2.5)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.34)))
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.8))
                .padding(10)
        }
        .frame(height: HomeCinemaStyle.heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }
}

// MARK: - Trailers row (MV + new song express entries)

struct CinemaTrailerRow: View {
    let onNewSongExpress: () -> Void
    let onMVDiscover: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CinemaSectionHeader(sceneNumber: 5, kicker: "Trailers & More")

            HStack(spacing: 12) {
                trailerCard(icon: .mv, title: "home_mv_zone", action: onMVDiscover)
                trailerCard(icon: .musicNote, title: "new_song_express", action: onNewSongExpress)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    private func trailerCard(
        icon: MonoIcon.IconType,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MonoIcon(icon: icon, size: 18, color: .monoTextPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.monoTextPrimary.opacity(0.07)))

                Text(LocalizedStringKey(title))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 68)
            .background(ClassicAsideEmbeddedSurface(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
    }
}
