import SwiftUI

struct ClarityHomeView: View {
    @ObservedObject private var model = HomeViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var path = NavigationPath()
    @State private var showFM = false
    @State private var bannerWebURL: URL?
    @State private var hitokotoRefreshRotation = 0.0
    @State private var didActivateHome = false

    private enum Destination: Hashable {
        case search
        case daily
        case playlist(Playlist)
        case bannerPlaylist(Playlist, String?)
        case album(Int)
        case mv
        case newSongs
        case meditation
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ClarityBackdrop()
                if model.isLoading && model.banners.isEmpty && model.dailySongs.isEmpty {
                    ProgressView().tint(ClarityStyle.accent)
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self, destination: destination)
            .fullScreenCover(isPresented: $showFM) { PersonalFMView() }
            .fullScreenCover(item: $bannerWebURL) { url in MonoWebView(url: url, title: nil) }
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
            activateHomeIfNeeded(reason: "clarity home appear")
        }
        .onReceive(NotificationCenter.default.publisher(for: .mainTabDidSettle)) { notification in
            guard notification.object as? Tab == .home,
                  MainTabActivationGate.isSettled(.home) else { return }
            activateHomeIfNeeded(reason: "clarity home selected")
        }
        .onChange(of: settings.hitokotoEnabled) { _, enabled in
            if enabled, MainTabActivationGate.isSettled(.home) {
                model.refreshHitokoto(force: true)
            }
        }
    }

    private func activateHomeIfNeeded(reason: String) {
        guard !didActivateHome else { return }
        didActivateHome = true
        model.ensureHomeDataLoaded(reason: reason)
        if settings.hitokotoEnabled {
            model.refreshHitokoto()
        }
    }

    private var content: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    primaryShell(in: proxy)

                    if settings.hitokotoEnabled { dailyQuote }

                    if !model.recommendPlaylists.isEmpty {
                        playlistRail(
                            title: String(localized: "home_ncm_recommended_playlists"),
                            playlists: model.recommendPlaylists
                        )
                    }
                    if !model.qqRecommendPlaylists.isEmpty {
                        playlistRail(
                            title: String(localized: "home_qcm_recommended_playlists"),
                            playlists: model.qqRecommendPlaylists
                        )
                    }
                    if !model.kugouRecommendPlaylists.isEmpty {
                        playlistRail(
                            title: String(localized: "home_kcm_recommended_playlists"),
                            playlists: model.kugouRecommendPlaylists
                        )
                    }
                    if !model.qqNewSongs.isEmpty { qcmList }

                    FloatingBarBottomSpacer()
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DeviceLayout.isPad ? 28 : 14)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
            .refreshable { model.retryHomeDataLoad(reason: "clarity home refresh") }
            .themeRenderScrollLayer()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(ClarityStyle.body(11.5, weight: .medium))
                    .foregroundStyle(ClarityStyle.inkSoft)
                Text(model.displayedIdentityProfile?.nickname ?? String(localized: "tabbar_home"))
                    .font(ClarityStyle.title(25, weight: .semibold))
                    .foregroundStyle(ClarityStyle.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ClarityCircleButton(icon: .moon, size: 39) { path.append(Destination.meditation) }
            ClarityCircleButton(icon: .search, size: 39) { path.append(Destination.search) }
            Button {
                NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
            } label: { avatar }
                .buttonStyle(ClarityPressStyle())
        }
        .padding(.horizontal, 5)
        .monoPageHeaderCollapse()
    }

    private var avatar: some View {
        Group {
            if let raw = model.displayedIdentityProfile?.avatarUrl, let url = URL(string: raw) {
                CachedAsyncImage(url: url, width: 42, height: 42) { Circle().fill(ClarityStyle.membraneStrong) }
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(ClarityStyle.membraneStrong)
                    .overlay(MonoIcon(icon: .profile, size: 17, color: ClarityStyle.inkSoft, lineWidth: 1.5))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.94), lineWidth: 1.2))
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 7)
    }

    private func primaryShell(in proxy: GeometryProxy) -> some View {
        ClarityShell(cornerRadius: DeviceLayout.isPad ? 38 : 32) {
            VStack(spacing: 0) {
                if !model.banners.isEmpty {
                    ClarityBannerCarousel(banners: Array(model.banners.prefix(6)), action: handleBannerTap)
                } else {
                    fallbackHero(width: min(proxy.size.width - 28, 720))
                }

                quickRail

                if !model.dailySongs.isEmpty {
                    Rectangle().fill(ClarityStyle.line).frame(height: 1).padding(.horizontal, 18)
                    dailyList
                }
            }
        }
    }

    private func fallbackHero(width: CGFloat) -> some View {
        let song = model.dailySongs.first ?? model.qqNewSongs.first
        let height = min(max(width * 0.43, 154), 208)
        return ZStack(alignment: .bottomLeading) {
            HomeBannerArtwork(url: song?.coverUrl, cornerRadius: 27) {
                LinearGradient(colors: [ClarityStyle.lilac.opacity(0.42), ClarityStyle.cyan.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            LinearGradient(colors: [.clear, Color.black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song?.name ?? String(localized: "daily_recommend"))
                        .font(ClarityStyle.title(21, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(song?.artistName ?? String(localized: "home_recommend_for_you"))
                        .font(ClarityStyle.body(11.5))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                }
                Spacer()
                if let song {
                    ClarityGlowButton(icon: .play, size: 46, tint: ClarityStyle.ink) {
                        PlayerManager.shared.play(song: song, in: model.dailySongs.isEmpty ? [song] : model.dailySongs)
                    }
                }
            }
            .padding(18)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .padding(12)
    }

    private var quickRail: some View {
        HStack(spacing: 0) {
            quickAction(.musicNoteList, "daily_recommend") { path.append(Destination.daily) }
            quickAction(.fm, "player_private_fm") { showFM = true }
            quickAction(.mv, "home_mv_zone") { path.append(Destination.mv) }
            quickAction(.musicNote, "new_song_express") { path.append(Destination.newSongs) }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 14)
    }

    private func quickAction(_ icon: MonoIcon.IconType, _ key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MonoIcon(icon: icon, size: 17, color: ClarityStyle.ink, lineWidth: 1.5)
                    .frame(width: 58, height: 48)
                    .background(
                        ClarityMembrane(
                            shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                            strength: .quiet
                        )
                    )
                Text(String(localized: String.LocalizationValue(key)))
                    .font(ClarityStyle.body(9.5, weight: .medium))
                    .foregroundStyle(ClarityStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ClarityPressStyle())
    }

    private var dailyQuote: some View {
        HStack(alignment: .center, spacing: 12) {
            MonoIcon(icon: .hitokoto, size: 17, color: ClarityStyle.inkSoft, lineWidth: 1.45)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "settings_hitokoto"))
                    .font(ClarityStyle.body(10, weight: .semibold))
                    .foregroundStyle(ClarityStyle.inkFaint)

                Text(hitokotoText)
                    .font(ClarityStyle.body(13, weight: .medium))
                    .foregroundStyle(ClarityStyle.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.linear(duration: 0.55)) {
                    hitokotoRefreshRotation += 360
                }
                model.refreshHitokoto(force: true)
            } label: {
                MonoIcon(icon: .refresh, size: 14, color: ClarityStyle.inkSoft, lineWidth: 1.5)
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(hitokotoRefreshRotation))
            }
            .buttonStyle(ClarityPressStyle())
            .accessibilityLabel(String(localized: "settings_hitokoto"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ClarityMembrane(
                shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                strength: .quiet
            )
        )
    }

    private var hitokotoText: String {
        let text = model.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? HitokotoFallbackSlogan.text : text
    }

    private var dailyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ClaritySectionHeading(title: String(localized: "made_for_you"), actionTitle: String(localized: "view_all")) {
                path.append(Destination.daily)
            }
            ForEach(Array(model.dailySongs.prefix(4).enumerated()), id: \.element.id) { index, song in
                clarityHomeSongRow(index: index, song: song, songs: model.dailySongs)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
    }

    private func playlistRail(title: String, playlists: [Playlist]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ClaritySectionHeading(title: title)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(playlists.prefix(12))) { playlist in
                        Button { path.append(Destination.playlist(playlist)) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ClarityArtwork(url: playlist.coverUrl, size: DeviceLayout.isPad ? 150 : 124, radius: 22)
                                Text(playlist.name)
                                    .font(ClarityStyle.body(12.5, weight: .semibold))
                                    .foregroundStyle(ClarityStyle.ink)
                                    .lineLimit(2)
                                Text(playlist.sourceShortName)
                                    .font(ClarityStyle.body(10))
                                    .foregroundStyle(ClarityStyle.inkFaint)
                            }
                            .frame(width: DeviceLayout.isPad ? 150 : 124, alignment: .leading)
                        }
                        .buttonStyle(ClarityPressStyle())
                    }
                }
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 6)
    }

    private var qcmList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ClaritySectionHeading(title: String(localized: "home_qq_new_songs"))
            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(Array(model.qqNewSongs.prefix(10))) { song in
                        Button { PlayerManager.shared.play(song: song, in: model.qqNewSongs) } label: {
                            HStack(spacing: 10) {
                                ClarityArtwork(url: song.coverUrl, size: 54, radius: 16)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.name).font(ClarityStyle.body(12.5, weight: .semibold)).foregroundStyle(ClarityStyle.ink).lineLimit(1)
                                    Text(song.artistName).font(ClarityStyle.body(10)).foregroundStyle(ClarityStyle.inkFaint).lineLimit(1)
                                }
                            }
                            .frame(width: 192, alignment: .leading)
                            .padding(10)
                        }
                        .buttonStyle(ClarityPressStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 6)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return String(localized: "good_late_night") }
        if hour < 12 { return String(localized: "good_morning") }
        if hour < 18 { return String(localized: "good_afternoon") }
        return String(localized: "good_evening")
    }

    private func handleBannerTap(_ banner: Banner) {
        switch banner.targetType {
        case 1:
            Task {
                guard let song = try? await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async().first else { return }
                await MainActor.run { PlayerManager.shared.play(song: song, in: [song]) }
            }
        case 10:
            path.append(Destination.album(banner.targetId))
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
            path.append(Destination.bannerPlaylist(playlist, banner.pic))
        case 1004:
            path.append(Destination.mv)
        default:
            if let raw = banner.url, let url = URL(string: raw) { bannerWebURL = url }
        }
    }

    @ViewBuilder
    private func destination(_ destination: Destination) -> some View {
        switch destination {
        case .search: ClaritySearchView().clarityDetailChrome(addsBackButton: true)
        case .daily: DailyRecommendView().clarityDetailChrome()
        case let .playlist(playlist): PlaylistDetailView(playlist: playlist).clarityDetailChrome(preservesImmersiveBackdrop: true)
        case let .bannerPlaylist(playlist, image): PlaylistDetailView(playlist: playlist, bannerCoverURLString: image).clarityDetailChrome(preservesImmersiveBackdrop: true)
        case let .album(id): AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil).clarityDetailChrome()
        case .mv: MVDiscoverView().clarityDetailChrome()
        case .newSongs: NewSongExpressView().clarityDetailChrome()
        case .meditation: ClarityMeditationView().clarityDetailChrome(addsBackButton: true)
        }
    }
}

private struct ClarityBannerCarousel: View {
    let banners: [Banner]
    let action: (Banner) -> Void
    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 5.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 5) {
            TabView(selection: $index) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { offset, banner in
                    Button { action(banner) } label: {
                        ZStack(alignment: .bottomTrailing) {
                            ClarityWideBannerArtwork(url: banner.imageUrl, cornerRadius: 27)
                            LinearGradient(colors: [.clear, Color.black.opacity(0.24)], startPoint: .center, endPoint: .bottom)
                            if let title = banner.typeTitle, !title.isEmpty {
                                Text(title)
                                    .font(ClarityStyle.body(10.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(ClarityMembrane(shape: Capsule(), strength: .quiet))
                                    .padding(12)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    }
                    .buttonStyle(ClarityPressStyle())
                    .padding(10)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(2.7, contentMode: .fit)
            .onReceive(timer) { _ in
                guard MainTabActivationGate.isSettled(.home) else { return }
                guard banners.count > 1 else { return }
                if reduceMotion { index = (index + 1) % banners.count }
                else { withAnimation(.easeInOut(duration: 0.32)) { index = (index + 1) % banners.count } }
            }

            if banners.count > 1 {
                HStack(spacing: 5) {
                    ForEach(banners.indices, id: \.self) { dot in
                        Capsule()
                            .fill(dot == index ? ClarityStyle.ink : ClarityStyle.line)
                            .frame(width: dot == index ? 15 : 5, height: 3)
                    }
                }
            }
        }
    }
}

/// Home banners are supplied as wide promotional artwork. The entire source
/// image stays visible; a softly enlarged copy only fills any residual letterbox.
private struct ClarityWideBannerArtwork: View {
    let url: URL?
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CachedAsyncImage(
                    url: url,
                    width: proxy.size.width,
                    height: proxy.size.height,
                    placeholder: { placeholder },
                    contentMode: .fill,
                    resizesArtworkURL: false
                )
                .blur(radius: 18)
                .scaleEffect(1.08)
                .opacity(0.34)
                .frame(width: proxy.size.width, height: proxy.size.height)

                CachedAsyncImage(
                    url: url,
                    width: proxy.size.width,
                    height: proxy.size.height,
                    placeholder: { placeholder },
                    contentMode: .fit,
                    resizesArtworkURL: false
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [ClarityStyle.lilac.opacity(0.42), ClarityStyle.cyan.opacity(0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private func clarityHomeSongRow(index: Int, song: Song, songs: [Song]) -> some View {
    Button { PlayerManager.shared.play(song: song, in: songs) } label: {
        HStack(spacing: 11) {
            Text(String(format: "%02d", index + 1))
                .font(ClarityStyle.body(9.5, weight: .semibold))
                .foregroundStyle(ClarityStyle.inkFaint)
                .frame(width: 20)
            ClarityArtwork(url: song.coverUrl, size: 44, radius: 13)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name).font(ClarityStyle.body(12.5, weight: .semibold)).foregroundStyle(ClarityStyle.ink).lineLimit(1)
                Text(song.artistName).font(ClarityStyle.body(10.5)).foregroundStyle(ClarityStyle.inkFaint).lineLimit(1)
            }
            Spacer(minLength: 8)
            MonoIcon(icon: .play, size: 12, color: ClarityStyle.inkSoft, lineWidth: 1.45)
        }
        .padding(.vertical, 2)
    }
    .buttonStyle(ClarityPressStyle())
}
