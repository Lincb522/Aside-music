import Combine
import SwiftUI

/// 首页内容模块枚举，控制各区块的展示与顺序。
private enum CapsuleHomeModule: CaseIterable, Identifiable {
    case daily
    case qcmNew
    case ncmNew
    case meditation
    case mv

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: return String(localized: "daily_recommend")
        case .qcmNew: return String(localized: "QCM 新歌")
        case .ncmNew: return String(localized: "新歌速递")
        case .meditation: return String(localized: "meditation_mode_title")
        case .mv: return "MV"
        }
    }

    var icon: MonoIcon.IconType {
        switch self {
        case .daily: return .sparkle
        case .qcmNew: return .musicNoteList
        case .ncmNew: return .musicNoteList
        case .meditation: return .moon
        case .mv: return .mv
        }
    }

    var tint: Color {
        switch self {
        case .daily: return CapsuleStyle.accent
        case .qcmNew: return CapsuleStyle.mint
        case .ncmNew: return CapsuleStyle.amber
        case .meditation: return CapsuleStyle.cyan
        case .mv: return CapsuleStyle.violet
        }
    }
}

/// Capsule 主题首页：聚合横幅、每日推荐、新歌、歌单等模块，数据来自 `HomeViewModel`。
struct CapsuleHomeView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var player = PlayerManager.shared
    @AppStorage("hitokotoEnabled") private var hitokotoEnabled = true

    @State private var navigationPath = NavigationPath()
    @State private var showPersonalFM = false
    @State private var bannerWebURL: URL?
    @State private var appeared = false
    @State private var bannerIndex = 0

    private let bannerTimer = Timer.publish(every: 5.4, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)

                if viewModel.isLoading && viewModel.dailySongs.isEmpty {
                    loadingView
                } else {
                    scrollBody
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                guard await MainTabActivationGate.waitUntilSettled(.home) else { return }
                viewModel.ensureHomeDataLoaded(reason: "capsule home appear")
                if hitokotoEnabled,
                   viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
                {
                    viewModel.refreshHitokoto()
                }
                if !appeared {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.86).delay(0.04)) {
                        appeared = true
                    }
                }
            }
            .navigationDestination(for: HomeView.HomeDestination.self) { destination in
                destinationView(for: destination)
            }
            .fullScreenCover(isPresented: $showPersonalFM) {
                PersonalFMView()
            }
            .fullScreenCover(item: $bannerWebURL) { url in
                MonoWebView(url: url, title: nil)
            }
        }
    }

    private var scrollBody: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                commandBar
                    .monoPageHeaderCollapse()
                    .capsuleHomeAppear(appeared, order: 0)

                capsuleConsole
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .capsuleHomeAppear(appeared, order: 1)

                mediaEntryDock
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .capsuleHomeAppear(appeared, order: 2)

                if !viewModel.banners.isEmpty {
                    bannerRail
                        .capsuleHomeAppear(appeared, order: 3)
                }

                if !viewModel.dailySongs.isEmpty {
                    dailyCapsuleList
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .capsuleHomeAppear(appeared, order: 4)
                }

                if !viewModel.qqNewSongs.isEmpty {
                    qcmSongStrip
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .capsuleHomeAppear(appeared, order: 5)
                }

                if !playlistPool.isEmpty {
                    playlistBoard
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .capsuleHomeAppear(appeared, order: 6)
                }

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 10)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable {
            viewModel.retryHomeDataLoad(reason: "capsule home pull refresh")
            if hitokotoEnabled {
                viewModel.refreshHitokoto(force: true)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            CapsuleIconBadge(icon: .layers, tint: CapsuleStyle.accent, size: 56)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill([CapsuleStyle.accent, CapsuleStyle.cyan, CapsuleStyle.violet][index].opacity(0.7))
                        .frame(width: index == 1 ? 26 : 14, height: 8)
                }
            }
        }
    }

    private var commandBar: some View {
        HStack(spacing: 12) {
            Button {
                NotificationCenter.default.post(name: .init("SwitchToProfile"), object: nil)
            } label: {
                avatarView
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: LocalizedStringResource(stringLiteral: MonoTimeGreeting.localizedKey)))
                    .font(CapsuleStyle.labelFont(11))
                    .foregroundStyle(CapsuleStyle.inkMuted)
                    .tracking(0.6)

                Text(viewModel.displayedIdentityProfile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                    .font(CapsuleStyle.titleFont(22, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 6)

            CapsuleActionButton(tint: CapsuleStyle.mint, action: { showPersonalFM = true }) {
                MonoIcon(icon: .fm, size: 17, color: CapsuleStyle.mint, lineWidth: 1.7)
            }

            CapsuleActionButton(action: { navigationPath.append(HomeView.HomeDestination.search) }) {
                MonoIcon(icon: .magnifyingGlass, size: 17, color: CapsuleStyle.accent, lineWidth: 1.7)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    @ViewBuilder
    private var avatarView: some View {
        let size: CGFloat = 46
        if let avatarUrl = viewModel.displayedIdentityProfile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CapsuleStyle.surfaceTint)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CapsuleStyle.hairline, lineWidth: 1)
            )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CapsuleStyle.surfaceRaised)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: 18, color: CapsuleStyle.inkMuted, lineWidth: 1.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(CapsuleStyle.hairline, lineWidth: 1)
                )
        }
    }

    private var capsuleConsole: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    CapsulePillLabel(
                        title: String(localized: "settings_hitokoto"),
                        icon: .sparkle,
                        tint: CapsuleStyle.accent,
                        selected: true
                    )

                    if usesHitokotoFallback {
                        Text(HitokotoFallbackSlogan.text)
                            .font(CapsuleStyle.bodyFont(18, weight: .semibold))
                            .foregroundStyle(CapsuleStyle.ink)
                            .lineSpacing(4)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    } else {
                        Text(hitokotoText)
                            .font(CapsuleStyle.bodyFont(18, weight: .semibold))
                            .foregroundStyle(CapsuleStyle.ink)
                            .lineSpacing(4)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(spacing: 6) {
                    Text(todayDay)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(CapsuleStyle.ink)
                        .monospacedDigit()
                    Text(todayMonth)
                        .font(CapsuleStyle.labelFont(12))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                }
                .frame(width: 72)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(CapsuleStyle.surfaceTint)
                )
            }

        }
        .padding(16)
        .background(CapsuleSurfaceBackground(cornerRadius: 32, elevated: true, tint: CapsuleStyle.surface.opacity(0.92)))
    }

    private var mediaEntryDock: some View {
        HStack(spacing: 0) {
            ForEach(Array(quickModules.enumerated()), id: \.element.id) { index, module in
                Button {
                    open(module)
                } label: {
                    capsuleMediaEntry(module)
                }
                .buttonStyle(CapsulePressStyle())

                if index != quickModules.count - 1 {
                    Rectangle()
                        .fill(CapsuleStyle.separator.opacity(0.48))
                        .frame(width: 1, height: 54)
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 30,
                elevated: true,
                tint: CapsuleStyle.surface.opacity(0.92)
            )
        )
    }

    private func capsuleMediaEntry(_ module: CapsuleHomeModule) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(module.tint.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay(MonoIcon(icon: module.icon, size: 16, color: module.tint, lineWidth: 1.8))

            Text(module.title)
                .font(CapsuleStyle.labelFont(12, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.74)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 78)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var quickModules: [CapsuleHomeModule] {
        [.ncmNew, .meditation, .mv]
    }

    private var bannerRail: some View {
        VStack(spacing: 9) {
            TabView(selection: $bannerIndex) {
                ForEach(Array(viewModel.banners.prefix(8).enumerated()), id: \.element.id) { index, banner in
                    CapsuleBannerCard(banner: banner) {
                        handleBannerTap(banner)
                    }
                    .tag(index)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding + (DeviceLayout.isPad ? 12 : 8))
                    .padding(.vertical, 5)
                }
            }
            .frame(height: 138)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onReceive(bannerTimer) { _ in
                guard MainTabActivationGate.isSettled(.home) else { return }
                let count = min(viewModel.banners.count, 8)
                guard count > 1 else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    bannerIndex = (bannerIndex + 1) % count
                }
            }
            .onChange(of: viewModel.banners.count) { _, count in
                guard MainTabActivationGate.isSettled(.home) else { return }
                let maxIndex = max(0, min(count, 8) - 1)
                if bannerIndex > maxIndex {
                    bannerIndex = 0
                }
            }

            if viewModel.banners.count > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<min(viewModel.banners.count, 8), id: \.self) { index in
                        Capsule()
                            .fill(index == bannerIndex ? CapsuleStyle.accent : CapsuleStyle.separator.opacity(0.5))
                            .frame(width: index == bannerIndex ? 22 : 7, height: 6)
                    }
                }
            }
        }
    }

    private var dailyCapsuleList: some View {
        VStack(spacing: 12) {
            CapsuleSectionTitle(title: String(localized: "daily_recommend"), tint: CapsuleStyle.accent) {
                Button {
                    navigationPath.append(HomeView.HomeDestination.dailyRecommend)
                } label: {
                    CapsulePillLabel(title: String(localized: "view_all"), tint: CapsuleStyle.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 9) {
                ForEach(Array(viewModel.dailySongs.prefix(4).enumerated()), id: \.element.id) { index, song in
                    CapsuleSongRow(song: song, index: index + 1, tint: index == 0 ? CapsuleStyle.accent : CapsuleStyle.cyan) {
                        PlayerManager.shared.play(song: song, in: viewModel.dailySongs)
                    }
                }
            }
        }
    }

    private var qcmSongStrip: some View {
        VStack(spacing: 12) {
            CapsuleSectionTitle(title: "QCM 新歌", tint: CapsuleStyle.mint) {
                Button {
                    navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
                } label: {
                    CapsulePillLabel(title: String(localized: "view_all"), tint: CapsuleStyle.mint)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.qqNewSongs.prefix(8).enumerated()), id: \.element.id) { index, song in
                        CapsuleSongChip(song: song, tint: index.isMultiple(of: 2) ? CapsuleStyle.mint : CapsuleStyle.violet) {
                            PlayerManager.shared.play(song: song, in: viewModel.qqNewSongs)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var playlistBoard: some View {
        VStack(spacing: 12) {
            CapsuleSectionTitle(title: String(localized: "recommended_playlists"), tint: CapsuleStyle.amber) {
                Button {
                    openLibrarySquare()
                } label: {
                    CapsulePillLabel(title: String(localized: "common_view_more"), tint: CapsuleStyle.amber)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(playlistPool.prefix(6).enumerated()), id: \.element.id) { index, playlist in
                    CapsulePlaylistTile(playlist: playlist, tint: playlistTints[index % playlistTints.count]) {
                        navigationPath.append(HomeView.HomeDestination.playlist(playlist))
                    }
                }
            }
        }
    }

    private var playlistPool: [Playlist] {
        viewModel.recommendPlaylists + viewModel.qqRecommendPlaylists
    }

    private var playlistTints: [Color] {
        [CapsuleStyle.accent, CapsuleStyle.mint, CapsuleStyle.amber, CapsuleStyle.violet, CapsuleStyle.coral, CapsuleStyle.cyan]
    }

    private var hitokotoText: String {
        viewModel.hitokoto?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var usesHitokotoFallback: Bool {
        !hitokotoEnabled || hitokotoText.isEmpty
    }

    private var todayDay: String {
        let day = Calendar.current.component(.day, from: Date())
        return String(format: "%02d", day)
    }

    private var todayMonth: String {
        let month = Calendar.current.component(.month, from: Date())
        return String(format: "/%02d", month)
    }

    private func open(_ module: CapsuleHomeModule) {
        switch module {
        case .daily:
            navigationPath.append(HomeView.HomeDestination.dailyRecommend)
        case .qcmNew:
            navigationPath.append(HomeView.HomeDestination.qcmNewSongs)
        case .ncmNew:
            navigationPath.append(HomeView.HomeDestination.newSongExpress)
        case .meditation:
            navigationPath.append(HomeView.HomeDestination.meditationMode)
        case .mv:
            navigationPath.append(HomeView.HomeDestination.mvDiscover)
        }
    }

    private func openLibrarySquare() {
        UserDefaults.standard.set(true, forKey: "pendingLibrarySquareSwitch")
        NotificationCenter.default.post(name: .init("SwitchToLibrarySquare"), object: nil)
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
        case .meditationMode:
            MeditationModeView()
        }
    }
}

// MARK: - 首页子组件

private struct CapsuleBannerCard: View {
    let banner: Banner
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                HomeBannerArtwork(
                    url: banner.imageUrl,
                    cornerRadius: 32,
                    placeholder: {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(CapsuleStyle.surfaceTint)
                            .overlay(MonoIcon(icon: .musicNote, size: 24, color: CapsuleStyle.inkMuted.opacity(0.55), lineWidth: 1.7))
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 122)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.38)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                HStack(spacing: 8) {
                    Text(banner.typeTitle ?? String(localized: "推荐"))
                        .font(CapsuleStyle.labelFont(12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    MonoIcon(icon: .chevronRight, size: 11, color: .white.opacity(0.86), lineWidth: 1.7)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(.black.opacity(0.22), in: Capsule())
                .padding(12)
            }
            .background(CapsuleSurfaceBackground(cornerRadius: 32, elevated: true, tint: CapsuleStyle.surface.opacity(0.3)))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 1.2)
            )
        }
        .buttonStyle(CapsulePressStyle())
    }
}

private struct CapsuleSongRow: View {
    let song: Song
    let index: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(width: 28)

                CapsuleArtwork(url: song.coverUrl, size: 48, radius: 18, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(CapsuleStyle.bodyFont(15, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)

                    Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                        .font(CapsuleStyle.bodyFont(12, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MonoIcon(icon: .play, size: 15, color: tint, lineWidth: 1.8)
                    .frame(width: 34, height: 34)
                    .background(Capsule().fill(tint.opacity(0.12)))
            }
            .padding(.horizontal, 10)
            .frame(height: 66)
            .background(CapsuleSurfaceBackground(cornerRadius: 26, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.82)))
        }
        .buttonStyle(CapsulePressStyle())
        .themeRenderRowLayer()
    }
}

private struct CapsuleSongChip: View {
    let song: Song
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                CapsuleArtwork(url: song.coverUrl, size: 86, radius: 27, tint: tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(CapsuleStyle.labelFont(13, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)

                    Text(song.artistName.isEmpty ? String(localized: "search_unknown_artist") : song.artistName)
                        .font(CapsuleStyle.bodyFont(11, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(width: 106, alignment: .leading)
            .padding(10)
            .background(CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.9)))
        }
        .buttonStyle(CapsulePressStyle())
        .themeRenderRowLayer()
    }
}

private struct CapsulePlaylistTile: View {
    let playlist: Playlist
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    CapsuleArtwork(url: playlist.coverUrl, size: nil, radius: 26, tint: tint)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.24, contentMode: .fit)

                    MonoIcon(icon: .play, size: 13, color: CapsuleStyle.onAccent, lineWidth: 1.7)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(tint))
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.name)
                        .font(CapsuleStyle.bodyFont(14, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(playlist.trackCount.map { "\($0) 首" } ?? (playlist.isQQMusic ? "QCM" : "NCM"))
                        .font(CapsuleStyle.labelFont(11))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.9)))
        }
        .buttonStyle(CapsulePressStyle())
        .themeRenderRowLayer()
    }
}

private struct CapsuleArtwork: View {
    let url: URL?
    let size: CGFloat?
    let radius: CGFloat
    let tint: Color

    var body: some View {
        CachedAsyncImage(url: url, width: size, height: size) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(0.16))
                .overlay(MonoIcon(icon: .musicNote, size: 18, color: tint.opacity(0.72), lineWidth: 1.7))
        }
        .aspectRatio(contentMode: .fill)
        .ifLet(size) { view, size in
            view.frame(width: size, height: size)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
        )
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }

    func capsuleHomeAppear(_ appeared: Bool, order: Int) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .spring(response: 0.44, dampingFraction: 0.86).delay(Double(order) * 0.045),
                value: appeared
            )
    }
}
