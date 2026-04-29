import SwiftUI

// MARK: - 歌手详情页（参考ncm风格：大图 Hero + Tab 切换）

struct ArtistDetailView: View {
    let artistId: Int
    @State private var viewModel = ArtistDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab = 0 // 0: 音乐, 1: 专辑, 2: 视频, 3: 相似
    @State private var showFullDescription = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var selectedMV: MVIdItem?
    @State private var headerImageHeight: CGFloat = 320
    @State private var scrollOffset: CGFloat = 0
    @State private var isArtistSelectMode = false
    @State private var artistSelectedSongIds: Set<Int> = []
    @State private var showArtistBatchPlaylist = false
    @State private var artistSongSearch = ""
    @State private var isArtistSongSearching = false

    // 从封面提取的颜色
    @State private var dominantColor: Color = .clear
    @State private var isAppeared = false

    var body: some View {
        ZStack {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else {
                (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 0) {
                    // Hero 大图区域（弹性拉伸）
                    heroSection

                    // 信息区域（名字、粉丝、关注按钮、播放按钮）
                    infoSection
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, ThemedPageStyle.isActive ? 12 : -40)

                    // Tab 栏
                    tabBar
                        .padding(.top, ThemedPageStyle.isActive ? 14 : 20)

                    // Tab 内容
                    tabContent
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                }
                .iPadContentWidth(900)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .monologueScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            }
        }
        .fullScreenCover(item: $selectedMV) { item in
            MVPlayerView(mvId: item.id)
        }
        .monologueSheet(isPresented: $showFullDescription, preset: .standard){
            ArtistBioSheet(viewModel: viewModel, artistId: artistId)
        }
        .onAppear {
            viewModel.loadData(artistId: artistId)
            withAnimation(.easeOut(duration: 0.5)) { isAppeared = true }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 { viewModel.loadAlbums(artistId: artistId) }
            if newTab == 2 { viewModel.loadMVs(artistId: artistId) }
            if newTab == 3 { viewModel.loadSimiArtists(artistId: artistId) }
        }
    }
}


// MARK: - Hero 大图

extension ArtistDetailView {

    @ViewBuilder
    private var heroSection: some View {
        if MangaStyle.isActive {
            mangaHeroSection
        } else if NeumorphicStyle.isActive {
            neumorphicHeroSection
        } else if MujiStyle.isActive {
            mujiHeroSection
        } else {
        let stretchHeight = headerImageHeight - scrollOffset

        ZStack(alignment: .bottom) {
            // 歌手大图（弹性拉伸）
            if let artist = viewModel.artist, let coverUrl = artist.coverUrl?.sized(800) {
                CachedAsyncImage(url: coverUrl) {
                    Rectangle().fill(Color.monologueGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: stretchHeight)
                .clipped()
                .monologueBackgroundExtension()
            } else {
                Rectangle()
                    .fill(Color.monologueGlassTint)
                    .frame(height: stretchHeight)
            }

            // 底部渐变遮罩
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7")).opacity(0.6),
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: stretchHeight)
        }
        .frame(height: stretchHeight)
        .padding(.bottom, scrollOffset)
        .offset(y: scrollOffset)
        }
    }

    private var mangaHeroSection: some View {
        ZStack(alignment: .bottomTrailing) {
            CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(800)) {
                MangaStyle.paperCool
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: DeviceLayout.isPad ? 300 : 240)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: 2.4)
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MangaStyle.strokeInk)
                    .offset(x: 3, y: 3)
            )

            MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 34)
                .padding(14)
        }
        .rotationEffect(.degrees(-1.2))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 22)
        .padding(.bottom, 2)
    }

    private var mujiHeroSection: some View {
        VStack(spacing: 0) {
            CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(800)) {
                MujiStyle.surfaceRaised
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.isPad ? 230 : 190, height: DeviceLayout.isPad ? 230 : 190)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
            )
            .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 5)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, DeviceLayout.headerTopPadding + 22)
        .padding(.bottom, 4)
    }

    private var neumorphicHeroSection: some View {
        CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(800)) {
            NeumorphicStyle.surfacePressed
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: DeviceLayout.isPad ? 260 : 210, height: DeviceLayout.isPad ? 260 : 210)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(NeumorphicSurfaceBackground(cornerRadius: 30, elevated: true))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, DeviceLayout.headerTopPadding + 22)
        .padding(.bottom, 4)
    }
}

// MARK: - 信息区域

extension ArtistDetailView {

    @ViewBuilder
    private var infoSection: some View {
        if MangaStyle.isActive {
            mangaInfoSection
        } else if NeumorphicStyle.isActive {
            neumorphicInfoSection
        } else if MujiStyle.isActive {
            mujiInfoSection
        } else {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.artist?.name ?? "")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(2)

            // 粉丝数 + 简介
            HStack(spacing: 16) {
                if viewModel.fansCount > 0 {
                    Text(String(format: NSLocalizedString("artist_fans_count", comment: ""), formatFansCount(viewModel.fansCount)))
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                }

                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                }
            }

            // 简介（可点击展开）
            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 4) {
                        Text(desc)
                            .font(.rounded(size: 13))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                        MonologueIcon(icon: .chevronRight, size: 10, color: .monologueTextSecondary)
                    }
                }
            }

            // 播放全部按钮
            HStack(spacing: 12) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .play, size: 14, color: .monologueIconForeground)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(.monologueIconForeground)
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.monologueIconBackground))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
                .disabled(viewModel.songs.isEmpty)

                Spacer()
            }
            .padding(.top, 4)
        }
        }
    }

    private var mangaInfoSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 23, foreground: MangaStyle.ink)
                MangaLabel(text: "ARTIST", tint: MangaStyle.labelYellow, small: true)
            }

            Text(viewModel.artist?.name ?? "")
                .font(MangaStyle.titleFont(30, weight: .black))
                .foregroundColor(MangaStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if viewModel.fansCount > 0 {
                    MangaLabel(text: formatFansCount(viewModel.fansCount), tint: MangaStyle.bubbleBlue, small: true, foreground: MangaStyle.ink)
                }

                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    MangaLabel(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize), tint: MangaStyle.mint, small: true)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    MangaLabel(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize), tint: MangaStyle.paperCool, small: true, foreground: MangaStyle.ink)
                }
            }

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 6) {
                        Text(desc)
                            .font(MangaStyle.bodyFont(13, weight: .bold))
                            .foregroundColor(MangaStyle.inkSub)
                            .lineLimit(2)
                        MonologueIcon(icon: .chevronRight, size: 10, color: MangaStyle.inkSub)
                    }
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                HStack(spacing: 8) {
                    MonologueIcon(icon: .play, size: 13, color: MangaStyle.strokeInk, lineWidth: 2)
                    Text(LocalizedStringKey("artist_play_all"))
                        .font(MangaStyle.labelFont(13, weight: .black))
                }
                .foregroundColor(MangaStyle.strokeInk)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(MangaStyle.labelYellow))
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.5))
                .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(16)
        .background(MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite))
    }

    private var neumorphicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                NeumorphicPill(text: "ARTIST", tint: NeumorphicStyle.accent, selected: true, compact: true)
                if viewModel.fansCount > 0 {
                    NeumorphicPill(text: formatFansCount(viewModel.fansCount), tint: NeumorphicStyle.warm, compact: true)
                }
            }

            Text(viewModel.artist?.name ?? "")
                .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 34 : 30, weight: .semibold))
                .foregroundColor(NeumorphicStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    NeumorphicPill(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize), tint: NeumorphicStyle.sage, compact: true)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    NeumorphicPill(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize), tint: NeumorphicStyle.accent, compact: true)
                }
            }

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 6) {
                        Text(desc)
                            .font(NeumorphicStyle.labelFont(13, weight: .medium))
                            .foregroundColor(NeumorphicStyle.inkSoft)
                            .lineLimit(2)
                        MonologueIcon(icon: .chevronRight, size: 10, color: NeumorphicStyle.inkSoft)
                    }
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                NeumorphicPlayPill(title: String(localized: "artist_play_all"), tint: NeumorphicStyle.accent)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(17)
        .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true))
    }

    private var mujiInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                MujiPill(text: "ARTIST", tint: MujiStyle.clay)
                if viewModel.fansCount > 0 {
                    MujiPill(text: formatFansCount(viewModel.fansCount), tint: MujiStyle.indigo)
                }
            }

            Text(viewModel.artist?.name ?? "")
                .font(MujiStyle.titleFont(DeviceLayout.isPad ? 34 : 30, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    MujiPill(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize), tint: MujiStyle.tea)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    MujiPill(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize), tint: MujiStyle.clay)
                }
            }

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 6) {
                        Text(desc)
                            .font(MujiStyle.bodyFont(13, weight: .regular))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineLimit(2)
                        MonologueIcon(icon: .chevronRight, size: 10, color: MujiStyle.inkSoft)
                    }
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                MujiActionPill(
                    title: String(localized: "artist_play_all"),
                    icon: .play,
                    selected: true,
                    tint: MujiStyle.clay
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)

            MujiListDivider()
        }
    }

    private func formatFansCount(_ count: Int) -> String {
        if count >= 10000 {
            let wan = Double(count) / 10000.0
            return wan >= 100 ? String(localized: "\(Int(wan))万") : String(format: String(localized: "%.1f万"), wan)
        }
        return "\(count)"
    }
}


// MARK: - Tab 栏

extension ArtistDetailView {

    @ViewBuilder
    private var tabBar: some View {
        if MangaStyle.isActive {
            HStack(spacing: 8) {
                mangaTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: MangaStyle.labelYellow)
                mangaTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: MangaStyle.bubbleBlue)
                mangaTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: MangaStyle.mint)
                mangaTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: MangaStyle.bubblePink)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        } else if NeumorphicStyle.isActive {
            HStack(spacing: 8) {
                neumorphicTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: NeumorphicStyle.accent)
                neumorphicTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: NeumorphicStyle.sage)
                neumorphicTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: NeumorphicStyle.warm)
                neumorphicTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: NeumorphicStyle.red)
            }
            .padding(5)
            .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        } else if MujiStyle.isActive {
            HStack(spacing: 24) {
                mujiTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: MujiStyle.clay)
                mujiTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: MujiStyle.tea)
                mujiTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: MujiStyle.indigo)
                mujiTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: MujiStyle.straw)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MujiStyle.separator.opacity(0.72))
                    .frame(height: 0.6)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        } else {
            HStack(spacing: 28) {
                tabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0)
                tabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1)
                tabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2)
                tabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tabItem(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.rounded(size: 17, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? .monologueTextPrimary : .monologueTextSecondary)

                Capsule()
                    .fill(selectedTab == index ? Color.monologueIconBackground : Color.clear)
                    .frame(width: 20, height: 3)
            }
        }
    }

    private func mangaTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { selectedTab = index }
        }) {
            Text(title)
                .font(MangaStyle.labelFont(12, weight: isSelected ? .black : .bold))
                .foregroundColor(isSelected ? MangaStyle.ink : MangaStyle.inkSub)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(MangaStyle.strokeInk)
                                .offset(x: 1.5, y: 1.5)
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(tint)
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(MangaStyle.bubbleWhite.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(MangaStyle.strokeInk.opacity(0.28), lineWidth: 1)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func mujiTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { selectedTab = index }
        }) {
            VStack(spacing: 7) {
                Text(title)
                    .font(MujiStyle.labelFont(13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? MujiStyle.ink : MujiStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Rectangle()
                    .fill(isSelected ? tint : Color.clear)
                    .frame(width: 18, height: 1.2)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func neumorphicTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { selectedTab = index }
        }) {
            Text(title)
                .font(NeumorphicStyle.labelFont(12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? tint : NeumorphicStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isSelected ? tint.opacity(0.13) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab 内容

extension ArtistDetailView {

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            songsTab
        case 1:
            albumsTab
        case 2:
            mvsTab
        case 3:
            simiArtistsTab
        default:
            EmptyView()
        }
    }

    // MARK: 音乐 Tab

    private var artistSongFiltered: [Song] { viewModel.songs.filtered(by: artistSongSearch) }

    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                loadingPlaceholder
            } else if viewModel.songs.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_songs", comment: ""))
            } else {
                VStack(spacing: 0) {
                    PlaylistSearchBar(
                        searchText: $artistSongSearch,
                        isSearching: $isArtistSongSearching,
                        isSelectMode: $isArtistSelectMode,
                        selectedIds: $artistSelectedSongIds,
                        songs: artistSongFiltered,
                        onBatchQueue: {
                            let selected = artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) }
                            SongBatchActionHelper.addToQueue(selected) {
                                isArtistSelectMode = false
                                artistSelectedSongIds.removeAll()
                            }
                        },
                        onBatchDownload: { artistBatchDownload() },
                        onBatchCollect: { showArtistBatchPlaylist = true }
                    )

                    LazyVStack(spacing: 0) {
                        ForEach(Array(artistSongFiltered.enumerated()), id: \.element.id) { index, song in
                            SongListRow(song: song, index: index, isSelecting: isArtistSelectMode, isSelected: artistSelectedSongIds.contains(song.id), onArtistTap: { artistId in
                                selectedArtistId = artistId
                                showArtistDetail = true
                            }, onDetailTap: { detailSong in
                                selectedSongForDetail = detailSong
                                showSongDetail = true
                            }, onAlbumTap: { albumId in
                                selectedAlbumId = albumId
                                showAlbumDetail = true
                            }, onTap: {
                                if isArtistSelectMode {
                                    if artistSelectedSongIds.contains(song.id) {
                                        artistSelectedSongIds.remove(song.id)
                                    } else {
                                        artistSelectedSongIds.insert(song.id)
                                    }
                                } else {
                                    PlayerManager.shared.play(song: song, in: artistSongFiltered)
                                }
                            })
                        }
                    }
                }
                .padding(.vertical, 10)
                .monologueSheet(isPresented: $showArtistBatchPlaylist, preset: .standard){
                    BatchAddToPlaylistSheet(songs: artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) })
                }
            }
        }
    }

    private func artistBatchDownload() {
        let selected = artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: PlayerManager.shared.qqMusicQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: PlayerManager.shared.soundQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isArtistSelectMode = false; artistSelectedSongIds.removeAll() }
    }

    // MARK: 专辑 Tab

    private var albumsTab: some View {
        Group {
            if viewModel.isLoadingAlbums && viewModel.albums.isEmpty {
                loadingPlaceholder
            } else if viewModel.albums.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_albums", comment: ""))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.albums) { album in
                        albumRow(album)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }

    private func albumRow(_ album: AlbumInfo) -> some View {
        let coverRadius: CGFloat = MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 8 : (NeumorphicStyle.isActive ? 18 : 10))
        return Button(action: {
            selectedAlbumId = album.id
            showAlbumDetail = true
        }) {
            HStack(spacing: 14) {
                // 专辑封面
                if let coverUrl = album.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: coverRadius)
                            .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .overlay {
                        if MangaStyle.isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: 1.5)
                        } else if MujiStyle.isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                        } else if NeumorphicStyle.isActive {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: coverRadius)
                        .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)))
                        .frame(width: 72, height: 72)
                        .overlay(MonologueIcon(icon: .album, size: 24, color: MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary.opacity(0.3)))))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(album.name)
                        .font(MangaStyle.isActive ? MangaStyle.bodyFont(16, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(16, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .rounded(size: 16, weight: .medium))))
                        .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !album.publishDateText.isEmpty {
                            Text(album.publishDateText)
                                .font(MangaStyle.isActive ? MangaStyle.bodyFont(12, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .rounded(size: 12))))
                                .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)))
                        }
                        if let size = album.size, size > 0 {
                            Text("\(size) Tracks")
                                .font(MangaStyle.isActive ? MangaStyle.bodyFont(12, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .rounded(size: 12))))
                                .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)))
                        }
                    }
                }

                Spacer(minLength: 0)

                MonologueIcon(icon: .chevronRight, size: 12, color: MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary.opacity(0.4))))
            }
            .padding(12)
            .background {
                if MangaStyle.isActive {
                    MangaCardBackground(cornerRadius: 15, elevated: true, tint: MangaStyle.bubbleWhite)
                } else if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 10)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.monologueGlassTint)
                        .monologueGlass(cornerRadius: 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }

    // MARK: 视频 Tab

    private var mvsTab: some View {
        Group {
            if viewModel.isLoadingMVs && viewModel.mvs.isEmpty {
                loadingPlaceholder
            } else if viewModel.mvs.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_videos", comment: ""))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.mvs) { mv in
                        MVGridCard(mv: mv) {
                            selectedMV = MVIdItem(id: mv.id)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }

    // MARK: 相似歌手 Tab

    private var simiArtistsTab: some View {
        Group {
            if viewModel.isLoadingSimi && viewModel.simiArtists.isEmpty {
                loadingPlaceholder
            } else if viewModel.simiArtists.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_similar", comment: ""))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.simiArtists) { artist in
                        Button(action: {
                            selectedArtistId = artist.id
                            showArtistDetail = true
                        }) {
                            VStack(spacing: 10) {
                                if let coverUrl = artist.coverUrl?.sized(300) {
                                    CachedAsyncImage(url: coverUrl) {
                                        RoundedRectangle(cornerRadius: MangaStyle.isActive ? 14 : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 24 : 45)))
                                            .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)))
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 14 : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 24 : 45)), style: .continuous))
                                    .overlay {
                                        if MangaStyle.isActive {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MangaStyle.strokeInk, lineWidth: 1.5)
                                        } else if MujiStyle.isActive {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                                        } else if NeumorphicStyle.isActive {
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                                        }
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: MangaStyle.isActive ? 14 : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 24 : 45)))
                                        .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)))
                                        .frame(width: 90, height: 90)
                                        .overlay(MonologueIcon(icon: .personCircle, size: 32, color: MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary.opacity(0.3)))))
                                }

                                Text(artist.name)
                                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(13, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .rounded(size: 13, weight: .medium))))
                                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)))
                                    .lineLimit(1)
                            }
                            .padding(ThemedPageStyle.isActive ? 8 : 0)
                            .background {
                                if MangaStyle.isActive {
                                    MangaCardBackground(cornerRadius: 15, elevated: true, tint: MangaStyle.bubbleWhite)
                                } else if MujiStyle.isActive {
                                    MujiPaperCardBackground(cornerRadius: 10)
                                } else if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                                }
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }

    // MARK: 占位视图

    private var loadingPlaceholder: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 48)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary))
            if NeumorphicStyle.isActive {
                Text("LOADING")
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
            }
            Spacer().frame(height: 48)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyPlaceholder(_ text: String) -> some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 48)
            if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .sparkle, tint: NeumorphicStyle.sage, size: 52)
            }
            Text(text)
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
            Spacer().frame(height: 48)
        }
        .frame(maxWidth: .infinity)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
            }
        }
        .padding(.horizontal, NeumorphicStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
    }
}


// MARK: - 歌手简介 Sheet

struct ArtistBioSheet: View {
    var viewModel: ArtistDetailViewModel
    let artistId: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部：歌手头像 + 名字
            HStack(spacing: 14) {
                if let artist = viewModel.artist {
                    CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                        Circle().fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay {
                        if NeumorphicStyle.isActive {
                            Circle()
                                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.artist?.name ?? "")
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .rounded(size: 20, weight: .bold))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)

                    HStack(spacing: 12) {
                        if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                            HStack(spacing: 4) {
                                MonologueIcon(icon: .album, size: 12, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                                Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                            }
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .rounded(size: 12))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                        }
                        if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                            HStack(spacing: 4) {
                                MonologueIcon(icon: .musicNote, size: 12, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                                Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                            }
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .rounded(size: 12))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                        }
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else {
                                Circle().fill(Color.monologueSeparator)
                            }
                        }
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : Color.monologueSeparator)
                .frame(height: 0.5)

            if viewModel.isLoadingDesc {
                Spacer()
                MonologueLoadingView(text: "LOADING")
                Spacer()
            } else if let desc = viewModel.descResult {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let brief = desc.briefDesc, !brief.isEmpty {
                            bioCard {
                                Text(brief)
                                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular))
                                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                                    .lineSpacing(6)
                            }
                        }

                        ForEach(desc.sections) { section in
                            bioCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(16, weight: .semibold) : .rounded(size: 16, weight: .semibold))
                                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                                    Text(section.content)
                                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .regular) : .rounded(size: 14, weight: .regular))
                                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                                        .lineSpacing(5)
                                }
                            }
                        }

                        if (desc.briefDesc ?? "").isEmpty && desc.sections.isEmpty {
                            noContentView
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let brief = viewModel.artist?.briefDesc, !brief.isEmpty {
                            bioCard {
                                Text(brief)
                                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular))
                                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                                    .lineSpacing(6)
                            }
                        } else {
                            noContentView
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .onAppear {
            viewModel.loadDesc(artistId: artistId)
        }
        .background {
            MonologueSheetAwareBackground {
                if NeumorphicStyle.isActive {
                    ThemeRenderBackdrop(theme: .neumorphic)
                } else {
                    ThemedPageBackground()
                }
            }
        }
    }

    private func bioCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
            }
        }
    }

    private var noContentView: some View {
        VStack(spacing: 14) {
            if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .info, tint: NeumorphicStyle.sage, size: 52)
            } else {
                MonologueIcon(icon: .info, size: 36, color: .monologueTextSecondary.opacity(0.3))
            }
            Text(LocalizedStringKey("artist_no_bio"))
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
