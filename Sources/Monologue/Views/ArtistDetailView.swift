import SwiftUI

// MARK: - 歌手详情页（参考ncm风格：大图 Hero + Tab 切换）

struct ArtistDetailView: View {
    let artistId: Int
    @StateObject private var viewModel = ArtistDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
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
        let _ = settings.globalThemeRevision

        ZStack {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteRootBackdrop()
            } else if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else if SignalStyle.isActive {
                ThemeRenderBackdrop(theme: .default)
            } else if SequoiaStyle.isActive {
                SequoiaRootBackdrop()
            } else if BentoStyle.isActive {
                BentoRootBackdrop()
            } else if CapsuleStyle.isActive {
                CapsuleRootBackdrop()
            } else {
                (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()
            }

            ScrollView {
                if MinimalWhiteStyle.isActive {
                    minimalWhiteArtistDetailBody
                        .iPadContentWidth(900)
                } else if NeumorphicStyle.isActive {
                    neumorphicArtistDetailBody
                        .iPadContentWidth(900)
                } else if CapsuleStyle.isActive {
                    capsuleArtistDetailBody
                        .iPadContentWidth(900)
                } else {
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

// MARK: - 纯白歌手详情

extension ArtistDetailView {
    private var minimalWhiteArtistDetailBody: some View {
        VStack(spacing: 0) {
            minimalWhiteArtistImmersiveHeader

            tabBar
                .padding(.top, 18)

            tabContent
                .padding(.top, 12)
                .padding(.bottom, 120)
        }
    }

    private var minimalWhiteArtistImmersiveHeader: some View {
        let coverURL = viewModel.artist?.coverUrl?.sized(900)
        let portraitSize: CGFloat = DeviceLayout.isPad ? 168 : 136
        let heroHeight: CGFloat = DeviceLayout.isPad ? 478 : 426

        return ZStack(alignment: .bottom) {
            CachedAsyncImage(url: coverURL) {
                MinimalWhiteStyle.surfaceTint
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: heroHeight)
            .frame(maxWidth: .infinity)
            .blur(radius: 22)
            .opacity(0.18)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [
                        MinimalWhiteStyle.paper.opacity(0.42),
                        MinimalWhiteStyle.paper.opacity(0.78),
                        MinimalWhiteStyle.paper
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            VStack(spacing: 13) {
                CachedAsyncImage(url: coverURL) {
                    Circle()
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonologueIcon(icon: .profile, size: 38, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.55))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: portraitSize, height: portraitSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
                )
                .shadow(color: MinimalWhiteStyle.ink.opacity(0.10), radius: 22, x: 0, y: 12)

                Text(viewModel.artist?.name ?? "")
                    .font(MinimalWhiteStyle.titleFont(DeviceLayout.isPad ? 36 : 31, weight: .semibold))
                    .foregroundStyle(MinimalWhiteStyle.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                minimalWhiteArtistStatsLine

                if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                    Button(action: { showFullDescription = true }) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(desc)
                                .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                                .foregroundStyle(MinimalWhiteStyle.inkSoft)
                                .lineLimit(2)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)

                            MonologueIcon(icon: .chevronRight, size: 12, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.55)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(MinimalWhiteSurfaceBackground(cornerRadius: 15, elevated: false, tint: MinimalWhiteStyle.glassStrongFill))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent, lineWidth: 1.75)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                    }
                    .foregroundStyle(MinimalWhiteStyle.onAccent)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
                .disabled(viewModel.songs.isEmpty)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 24)
        }
        .frame(height: heroHeight)
        .padding(.top, DeviceLayout.headerTopPadding + 24)
    }

    private var minimalWhiteArtistStats: [String] {
        var items: [String] = []
        if viewModel.fansCount > 0 {
            items.append(String(format: NSLocalizedString("artist_fans_count", comment: ""), formatFansCount(viewModel.fansCount)))
        }
        if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
            items.append(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
        }
        if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
            items.append(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
        }
        return items
    }

    private var minimalWhiteArtistStatsLine: some View {
        HStack(spacing: 7) {
            ForEach(Array(minimalWhiteArtistStats.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Circle()
                        .fill(MinimalWhiteStyle.inkMuted.opacity(0.32))
                        .frame(width: 3, height: 3)
                }

                Text(item)
                    .font(MinimalWhiteStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(MinimalWhiteStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

// MARK: - 新拟物歌手详情

extension ArtistDetailView {
    private var neumorphicArtistDetailBody: some View {
        VStack(spacing: 15) {
            neumorphicArtistHeroConsole
            neumorphicArtistTabDock
            tabContent
                .padding(.top, 2)
        }
        .padding(.top, DeviceLayout.headerTopPadding + 18)
        .padding(.bottom, 120)
    }

    private var neumorphicArtistHeroConsole: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 15) {
                    neumorphicArtistCoverStack
                        .frame(width: DeviceLayout.isPad ? 150 : 124)

                    neumorphicArtistIdentityBlock
                }

                VStack(alignment: .leading, spacing: 14) {
                    neumorphicArtistCoverStack
                        .frame(maxWidth: .infinity, alignment: .center)

                    neumorphicArtistIdentityBlock
                }
            }

            neumorphicArtistMetricGrid
        }
        .padding(15)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 32,
                elevated: true,
                tint: NeumorphicStyle.accent.opacity(0.045),
                lightweight: true
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private var neumorphicArtistCoverStack: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(NeumorphicStyle.surfacePressed)
                .frame(width: DeviceLayout.isPad ? 150 : 124, height: DeviceLayout.isPad ? 168 : 146)
                .overlay(alignment: .topLeading) {
                    VStack(spacing: 7) {
                        Capsule().fill(NeumorphicStyle.accent.opacity(0.45)).frame(width: 26, height: 5)
                        Capsule().fill(NeumorphicStyle.sage.opacity(0.42)).frame(width: 18, height: 5)
                    }
                    .padding(14)
                }
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 31,
                        elevated: true,
                        tint: NeumorphicStyle.surfaceRaised,
                        lightweight: true
                    )
                )

            CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(700)) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .personCircle, size: 34, color: NeumorphicStyle.inkMuted.opacity(0.5), lineWidth: 1.8))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.isPad ? 132 : 108, height: DeviceLayout.isPad ? 132 : 108)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NeumorphicStyle.separator.opacity(0.36), lineWidth: 0.7)
            )
            .padding(.trailing, 8)
            .padding(.bottom, 8)

            MonologueIcon(icon: .sparkle, size: 14, color: NeumorphicStyle.warm, lineWidth: 1.75)
                .frame(width: 32, height: 32)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 14,
                        elevated: true,
                        tint: NeumorphicStyle.warm.opacity(0.13),
                        lightweight: true
                    )
                )
                .offset(x: 7, y: 7)
        }
        .frame(height: DeviceLayout.isPad ? 178 : 154)
    }

    private var neumorphicArtistIdentityBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                NeumorphicPill(text: "NCM", tint: NeumorphicStyle.warm, icon: .microphone, selected: true, compact: true)
                NeumorphicPill(text: "ARTIST", tint: NeumorphicStyle.accent, compact: true)
            }

            Text(viewModel.artist?.name ?? String(localized: "歌手"))
                .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 34 : 29, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 8) {
                        Text(desc)
                            .font(NeumorphicStyle.bodyFont(13, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        MonologueIcon(icon: .chevronRight, size: 10, color: NeumorphicStyle.inkMuted, lineWidth: 1.6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 17,
                            elevated: false,
                            pressed: true,
                            tint: NeumorphicStyle.surfacePressed,
                            lightweight: true
                        )
                    )
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var neumorphicArtistMetricGrid: some View {
        let songCount = viewModel.artist?.musicSize ?? (viewModel.songs.isEmpty ? nil : viewModel.songs.count)

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 9),
            GridItem(.flexible(), spacing: 9),
            GridItem(.flexible(), spacing: 9)
        ], spacing: 9) {
            if let songCount, songCount > 0 {
                neumorphicArtistMetricTile(
                    title: String(localized: "artist_tab_music"),
                    value: "\(songCount)",
                    icon: .musicNoteList,
                    tint: NeumorphicStyle.accent
                )
            }

            if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                neumorphicArtistMetricTile(
                    title: String(localized: "artist_tab_album"),
                    value: "\(albumSize)",
                    icon: .album,
                    tint: NeumorphicStyle.sage
                )
            }

            if viewModel.fansCount > 0 {
                neumorphicArtistMetricTile(
                    title: String(localized: "粉丝"),
                    value: formatFansCount(viewModel.fansCount),
                    icon: .like,
                    tint: NeumorphicStyle.warm
                )
            }
        }
    }

    private func neumorphicArtistMetricTile(title: String, value: String, icon: MonologueIcon.IconType, tint: Color) -> some View {
        HStack(spacing: 9) {
            MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.65)
                .frame(width: 30, height: 30)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 13,
                        elevated: false,
                        pressed: true,
                        tint: tint.opacity(0.1),
                        lightweight: true
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(NeumorphicStyle.labelFont(10, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
    }

    private var neumorphicArtistTabDock: some View {
        HStack(spacing: 7) {
            neumorphicArtistTabDockItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, icon: .musicNoteList, tint: NeumorphicStyle.accent)
            neumorphicArtistTabDockItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, icon: .album, tint: NeumorphicStyle.sage)
            neumorphicArtistTabDockItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, icon: .mv, tint: NeumorphicStyle.warm)
            neumorphicArtistTabDockItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, icon: .personCircle, tint: NeumorphicStyle.red)
        }
        .padding(6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 23, elevated: true, lightweight: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private func neumorphicArtistTabDockItem(_ title: String, index: Int, icon: MonologueIcon.IconType, tint: Color) -> some View {
        let selected = selectedTab == index

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 5) {
                MonologueIcon(icon: icon, size: 14, color: selected ? tint : NeumorphicStyle.inkMuted, lineWidth: 1.65)
                Text(title)
                    .font(NeumorphicStyle.labelFont(10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.14) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Hero 大图

extension ArtistDetailView {

    @ViewBuilder
    private var heroSection: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteHeroSection
        } else if MangaStyle.isActive {
            mangaHeroSection
        } else if NeumorphicStyle.isActive {
            neumorphicHeroSection
        } else if SignalStyle.isActive {
            signalHeroSection
        } else if SequoiaStyle.isActive {
            sequoiaHeroSection
        } else if MujiStyle.isActive {
            mujiHeroSection
        } else if BentoStyle.isActive {
            bentoHeroSection
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

    private var minimalWhiteHeroSection: some View {
        CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(900)) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MinimalWhiteStyle.controlGlassFill)
                .overlay(MonologueIcon(icon: .profile, size: 46, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5))
        }
        .aspectRatio(contentMode: .fill)
        .frame(height: DeviceLayout.isPad ? 290 : 220)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
        )
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassFill
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 22)
        .padding(.bottom, 4)
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
            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: 2.4)
            )
            .background(
                RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous)
                    .fill(MangaStyle.strokeInk)
                    .offset(x: MangaStyle.shadowOffset, y: MangaStyle.shadowOffset)
            )

            MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 34)
                .padding(14)
        }
        .rotationEffect(.degrees(-1.2))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 22)
        .padding(.bottom, 2)
    }

    /// Muji：人物特写 —— 跨页大图，如手帖人物专访首页
    private var mujiHeroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                MujiDotMark()

                Text("ARTIST")
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(2.2)
                    .fixedSize()

                Spacer(minLength: 8)

                if viewModel.fansCount > 0 {
                    Text(formatFansCount(viewModel.fansCount))
                        .font(MujiStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(MujiStyle.inkMuted)
                        .tracking(1.1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(800)) {
                Rectangle().fill(MujiStyle.wash(MujiStyle.clay))
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: DeviceLayout.isPad ? 320 : 236)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: MujiStyle.ink.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 14)
        }
        .padding(.top, DeviceLayout.headerTopPadding + 16)
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

    private var signalHeroSection: some View {
        CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(800)) {
            SignalStyle.controlPressed
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: DeviceLayout.isPad ? 260 : 210, height: DeviceLayout.isPad ? 260 : 210)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(SignalSurfaceBackground(cornerRadius: 32, elevated: true, fill: SignalStyle.control))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.7), lineWidth: 0.8)
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, DeviceLayout.headerTopPadding + 22)
        .padding(.bottom, 4)
    }

    private var sequoiaHeroSection: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(900)) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(SequoiaStyle.materialList)
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: DeviceLayout.isPad ? 300 : 238)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(SequoiaStyle.luminousSeparator.opacity(0.5), lineWidth: 0.7)
            )

            LinearGradient(
                colors: [
                    .clear,
                    SequoiaStyle.canvasBottom.opacity(colorScheme == .dark ? 0.84 : 0.72)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            HStack(spacing: 8) {
                SequoiaMeter(tint: SequoiaStyle.violet, count: 8)
                SequoiaPill(text: "ARTIST", tint: SequoiaStyle.violet, selected: true, compact: true)
            }
            .padding(14)
        }
        .background(SequoiaSurfaceBackground(cornerRadius: 32, elevated: true, role: .chrome))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 22)
        .padding(.bottom, 4)
    }

    private var bentoHeroSection: some View {
        BentoBlock(fill: BentoStyle.surface, radius: BentoStyle.blockRadiusLarge, padding: 12, stroked: true) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: viewModel.artist?.coverUrl?.sized(900)) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(BentoStyle.buckwheat.opacity(0.48))
                        .overlay(BentoIconBadge(icon: .profile, foreground: BentoStyle.tomato, size: 58))
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: DeviceLayout.isPad ? 286 : 220)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                LinearGradient(
                    colors: [.clear, BentoStyle.ink.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                HStack(spacing: 8) {
                    BentoTag(text: "ARTIST", color: BentoStyle.onAccent, background: BentoStyle.tomato)
                    if viewModel.fansCount > 0 {
                        BentoTag(text: formatFansCount(viewModel.fansCount), color: BentoStyle.onAccent, background: BentoStyle.nori.opacity(0.9))
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, BentoStyle.blockSpacing)
        .padding(.top, DeviceLayout.headerTopPadding + 12)
        .padding(.bottom, 2)
    }
}

// MARK: - 信息区域

extension ArtistDetailView {

    @ViewBuilder
    private var infoSection: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteInfoSection
        } else if MangaStyle.isActive {
            mangaInfoSection
        } else if NeumorphicStyle.isActive {
            neumorphicInfoSection
        } else if SignalStyle.isActive {
            signalInfoSection
        } else if SequoiaStyle.isActive {
            sequoiaInfoSection
        } else if MujiStyle.isActive {
            mujiInfoSection
        } else if BentoStyle.isActive {
            bentoInfoSection
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

    private var minimalWhiteInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                minimalWhiteArtistPill(text: "ARTIST")
                if viewModel.fansCount > 0 {
                    minimalWhiteArtistPill(text: formatFansCount(viewModel.fansCount))
                }
            }

            Text(viewModel.artist?.name ?? "")
                .font(MinimalWhiteStyle.titleFont(DeviceLayout.isPad ? 34 : 30, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    minimalWhiteArtistPill(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    minimalWhiteArtistPill(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                }
            }

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 8) {
                        Text(desc)
                            .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkMuted)
                            .lineLimit(2)
                        Spacer(minLength: 6)
                        MonologueIcon(icon: .chevronRight, size: 10, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5)
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
                    MonologueIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent, lineWidth: 1.75)
                    Text(LocalizedStringKey("artist_play_all"))
                        .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                }
                .foregroundStyle(MinimalWhiteStyle.onAccent)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassFill
            )
        )
    }

    private func minimalWhiteArtistPill(text: String) -> some View {
        Text(text)
            .font(MinimalWhiteStyle.labelFont(11, weight: .medium))
            .foregroundStyle(MinimalWhiteStyle.inkMuted)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(MinimalWhiteCapsuleBackground())
    }

    private var mangaInfoSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 23, foreground: MangaStyle.ink)
                MangaLabel(text: "ARTIST", tint: MangaStyle.labelYellow, small: true)
            }

            MangaMisprintTitle(text: viewModel.artist?.name ?? "", size: 30)
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
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)

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

            Spacer(minLength: 0)

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                HStack(spacing: 8) {
                    MonologueIcon(icon: .play, size: 13, color: MangaStyle.onStrokeInk, lineWidth: 2)
                    Text(LocalizedStringKey("artist_play_all"))
                        .font(MangaStyle.labelFont(13, weight: .black))
                        .tracking(0.6)
                }
                .foregroundColor(MangaStyle.onStrokeInk)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MangaStyle.strokeInk))
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(MangaStyle.accentPink)
                        .offset(x: 2.5, y: 2.5)
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 238 : 218, alignment: .topLeading)
        .background(
            // 歌手详情页唯一焦点分格：保留厚墨框错版投影
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite, poster: true)
        )
    }

    private var neumorphicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
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
                }

                Spacer(minLength: 10)

                NeumorphicIconBadge(icon: .profile, tint: NeumorphicStyle.sage, size: 46)
            }

            HStack(spacing: 8) {
                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    NeumorphicPill(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize), tint: NeumorphicStyle.sage, compact: true)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    NeumorphicPill(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize), tint: NeumorphicStyle.accent, compact: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)

            Group {
                if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                    Button(action: { showFullDescription = true }) {
                        neumorphicArtistNote(text: desc, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    neumorphicArtistNote(text: String(localized: "artist_no_bio"), showsChevron: false)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
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

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 246 : 228, alignment: .topLeading)
        .background(NeumorphicSurfaceBackground(cornerRadius: 28, elevated: true))
    }

    private func neumorphicArtistNote(text: String, showsChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(text)
                .font(NeumorphicStyle.labelFont(13, weight: .medium))
                .foregroundColor(NeumorphicStyle.inkSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if showsChevron {
                MonologueIcon(icon: .chevronRight, size: 10, color: NeumorphicStyle.inkSoft)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 18,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
    }

    private var signalInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SignalPill(text: "ARTIST", tint: SignalStyle.accent, selected: true, compact: true)
                if viewModel.fansCount > 0 {
                    SignalPill(text: formatFansCount(viewModel.fansCount), tint: SignalStyle.olive, compact: true)
                }
            }

            Text(viewModel.artist?.name ?? "")
                .font(SignalStyle.titleFont(DeviceLayout.isPad ? 34 : 30, weight: .bold))
                .foregroundStyle(SignalStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    SignalPill(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize), tint: SignalStyle.violet, compact: true)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    SignalPill(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize), tint: SignalStyle.amber, compact: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 6) {
                        Text(desc)
                            .font(SignalStyle.labelFont(13, weight: .medium))
                            .foregroundStyle(SignalStyle.inkSoft)
                            .lineLimit(2)
                        MonologueIcon(icon: .chevronRight, size: 10, color: SignalStyle.inkSoft)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                SignalPlayPill(title: String(localized: "artist_play_all"))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 240 : 220, alignment: .topLeading)
        .background(SignalSurfaceBackground(cornerRadius: 30, elevated: true, fill: SignalStyle.paper))
    }

    private var sequoiaInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SequoiaPill(text: "ARTIST", icon: .profile, tint: SequoiaStyle.violet, selected: true, compact: true)
                if viewModel.fansCount > 0 {
                    SequoiaPill(text: formatFansCount(viewModel.fansCount), tint: SequoiaStyle.aqua, compact: true)
                }
            }

            Text(viewModel.artist?.name ?? "")
                .font(SequoiaStyle.titleFont(DeviceLayout.isPad ? 34 : 30, weight: .semibold))
                .foregroundStyle(SequoiaStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    SequoiaPill(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize), tint: SequoiaStyle.green, compact: true)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    SequoiaPill(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize), tint: SequoiaStyle.accent, compact: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 6) {
                        Text(desc)
                            .font(SequoiaStyle.labelFont(13, weight: .regular))
                            .foregroundStyle(SequoiaStyle.inkSoft)
                            .lineLimit(2)
                        MonologueIcon(icon: .chevronRight, size: 10, color: SequoiaStyle.inkMuted, lineWidth: 1.45)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                HStack(spacing: 8) {
                    MonologueIcon(icon: .play, size: 13, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                    Text(LocalizedStringKey("artist_play_all"))
                        .font(SequoiaStyle.labelFont(13, weight: .semibold))
                }
                .foregroundStyle(SequoiaStyle.onAccent)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(SequoiaStyle.accentGradient, in: Capsule())
                .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 240 : 220, alignment: .topLeading)
        .background(SequoiaGlassBand(tint: SequoiaStyle.violet, cornerRadius: 26))
    }

    /// Muji：人物专访标题区 —— 衬线大名 + 作品统计脚注 + 引文式简介
    private var mujiInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.artist?.name ?? "")
                .font(MujiStyle.titleFont(DeviceLayout.isPad ? 34 : 30, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineSpacing(4)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                        .font(MujiStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(MujiStyle.inkSoft)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(MujiStyle.clay.opacity(0.85))
                            .frame(width: 3.5, height: 3.5)

                        Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                            .font(MujiStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(MujiStyle.inkSoft)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 10)

            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(alignment: .top, spacing: 11) {
                        Rectangle()
                            .fill(MujiStyle.clay.opacity(0.8))
                            .frame(width: 2)
                            .padding(.vertical, 2)

                        Text(desc.replacingOccurrences(of: "\n", with: " "))
                            .font(MujiStyle.bodyFont(12.5, weight: .regular))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineSpacing(4)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
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
            .padding(.top, 16)

            MujiListDivider()
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var bentoInfoSection: some View {
        BentoBlock(fill: BentoStyle.surfaceRaised, radius: BentoStyle.blockRadiusLarge, padding: 16, stroked: true) {
            VStack(alignment: .leading, spacing: 13) {
                Text(viewModel.artist?.name ?? "")
                    .font(BentoStyle.displayFont(DeviceLayout.isPad ? 34 : 30, weight: .black))
                    .foregroundStyle(BentoStyle.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                        BentoTag(text: String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize), color: BentoStyle.matcha)
                    }
                    if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                        BentoTag(text: String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize), color: BentoStyle.tomato)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)

                if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                    Button(action: { showFullDescription = true }) {
                        HStack(spacing: 8) {
                            Text(desc)
                                .font(BentoStyle.labelFont(13, weight: .medium))
                                .foregroundStyle(BentoStyle.inkSoft)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            MonologueIcon(icon: .chevronRight, size: 10, color: BentoStyle.inkMuted, lineWidth: 1.8)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(BentoStyle.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(BentoStyle.hairline.opacity(0.55), lineWidth: 0.7)
                                )
                        )
                    }
                    .buttonStyle(BentoPressStyle())
                }

                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .play, size: 13, color: BentoStyle.onAccent, lineWidth: 2)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(BentoStyle.labelFont(13, weight: .black))
                    }
                    .foregroundStyle(BentoStyle.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(BentoStyle.tomato, in: Capsule())
                }
                .buttonStyle(BentoPressStyle())
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func formatFansCount(_ count: Int) -> String {
        if count >= 10000 {
            let wan = Double(count) / 10000.0
            return wan >= 100 ? String(localized: "\(Int(wan))万") : String(format: String(localized: "%.1f万"), wan)
        }
        return "\(count)"
    }
}


// MARK: - 胶囊系统歌手详情

extension ArtistDetailView {
    private var capsuleArtistDetailBody: some View {
        VStack(spacing: 14) {
            capsuleArtistHeader
            capsuleArtistTabDock
            tabContent
                .padding(.top, 2)
        }
        .padding(.top, DeviceLayout.headerTopPadding + 18)
        .padding(.bottom, 120)
    }

    private var capsuleArtistHeader: some View {
        let artist = viewModel.artist
        let songCount = artist?.musicSize ?? (viewModel.songs.isEmpty ? nil : viewModel.songs.count)
        let chips = [
            songCount.map { "\($0) \(String(localized: "songs_unit"))" },
            artist?.albumSize.map { String(format: NSLocalizedString("artist_album_count", comment: ""), $0) },
            viewModel.fansCount > 0 ? formatFansCount(viewModel.fansCount) : nil
        ].compactMap { $0 }

        return CapsuleDetailHeader(
            eyebrow: artist?.isQQMusic == true ? "QCM ARTIST" : "NCM ARTIST",
            title: artist?.name ?? String(localized: "歌手"),
            subtitle: artist?.alias?.joined(separator: " / ") ?? "",
            coverURL: artist?.coverUrl?.sized(700),
            fallbackIcon: .personCircle,
            tint: artist?.isQQMusic == true ? CapsuleStyle.mint : CapsuleStyle.coral,
            chips: chips
        ) {
            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    CapsuleDetailActionPill(
                        title: String(localized: "artist_play_all"),
                        icon: .play,
                        tint: artist?.isQQMusic == true ? CapsuleStyle.mint : CapsuleStyle.coral
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                if artist?.briefDesc?.isEmpty == false {
                    Button(action: { showFullDescription = true }) {
                        CapsuleDetailIconButton(icon: .info, tint: CapsuleStyle.cyan)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                }
            }
        }
    }

    private var capsuleArtistTabDock: some View {
        HStack(spacing: 7) {
            capsuleArtistTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: CapsuleStyle.accent)
            capsuleArtistTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: CapsuleStyle.mint)
            capsuleArtistTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: CapsuleStyle.violet)
            capsuleArtistTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: CapsuleStyle.amber)
        }
        .padding(5)
        .background(CapsuleSurfaceBackground(cornerRadius: 20, elevated: false, tint: CapsuleStyle.surface.opacity(0.9)))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private func capsuleArtistTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) { selectedTab = index }
        }) {
            Text(title)
                .font(CapsuleStyle.labelFont(12, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? tint : CapsuleStyle.surfaceRaised.opacity(0.68))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.white.opacity(0.32) : CapsuleStyle.separator.opacity(0.38), lineWidth: 0.75)
                        )
                )
                .shadow(color: isSelected ? tint.opacity(0.13) : .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Tab 栏

extension ArtistDetailView {

    @ViewBuilder
    private var tabBar: some View {
        if MinimalWhiteStyle.isActive {
            HStack(spacing: 0) {
                minimalWhiteTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0)
                minimalWhiteTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1)
                minimalWhiteTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2)
                minimalWhiteTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MinimalWhiteStyle.hairline)
                    .frame(height: MinimalWhiteStyle.strokeWidth)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
        } else if MangaStyle.isActive {
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
        } else if SignalStyle.isActive {
            HStack(spacing: 8) {
                signalTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: SignalStyle.accent)
                signalTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: SignalStyle.olive)
                signalTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: SignalStyle.amber)
                signalTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: SignalStyle.violet)
            }
            .padding(5)
            .background(SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.controlPressed))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        } else if SequoiaStyle.isActive {
            HStack(spacing: 6) {
                sequoiaTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: SequoiaStyle.accent)
                sequoiaTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: SequoiaStyle.green)
                sequoiaTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: SequoiaStyle.aqua)
                sequoiaTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: SequoiaStyle.violet)
            }
            .padding(5)
            .background(SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, role: .chrome))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        } else if MujiStyle.isActive {
            HStack(spacing: 24) {
                mujiTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: MujiStyle.clay)
                mujiTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: MujiStyle.clay)
                mujiTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: MujiStyle.clay)
                mujiTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: MujiStyle.clay)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if BentoStyle.isActive {
            HStack(spacing: 6) {
                bentoTabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0, tint: BentoStyle.tomato)
                bentoTabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1, tint: BentoStyle.matcha)
                bentoTabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2, tint: BentoStyle.mustard)
                bentoTabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3, tint: BentoStyle.nori)
            }
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BentoStyle.surface)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(BentoStyle.hairline.opacity(0.62), lineWidth: 0.7))
            )
            .padding(.horizontal, BentoStyle.blockSpacing)
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

    private func minimalWhiteTabItem(_ title: String, index: Int) -> some View {
        let isSelected = selectedTab == index

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(MinimalWhiteStyle.labelFont(13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Capsule(style: .continuous)
                    .fill(isSelected ? MinimalWhiteStyle.ink : Color.clear)
                    .frame(width: isSelected ? 18 : 4, height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func mangaTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { selectedTab = index }
        }) {
            Text(title)
                .font(MangaStyle.labelFont(12, weight: isSelected ? .black : .bold))
                .foregroundColor(
                    isSelected
                        ? ThemeColorCustomization.readableForegroundColor(on: tint, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
                        : MangaStyle.inkSub
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        ZStack {
                            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                .fill(MangaStyle.strokeInk)
                                .offset(x: 1.5, y: 1.5)
                            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                .fill(tint)
                            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                            .fill(MangaStyle.bubbleWhite.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
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
            VStack(spacing: 6) {
                Text(title)
                    .font(MujiStyle.labelFont(13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? MujiStyle.ink : MujiStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Circle()
                    .fill(isSelected ? tint : Color.clear)
                    .frame(width: 4.5, height: 4.5)
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

    private func signalTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { selectedTab = index }
        }) {
            Text(title)
                .font(SignalStyle.labelFont(12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? SignalStyle.onAccent : SignalStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? tint : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 0.7)
                        )
                )
                .shadow(color: isSelected ? tint.opacity(0.18) : .clear, radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private func sequoiaTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) { selectedTab = index }
        }) {
            Text(title)
                .font(SequoiaStyle.labelFont(12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    SequoiaSurfaceBackground(
                        cornerRadius: 13,
                        elevated: isSelected,
                        pressed: !isSelected,
                        fill: isSelected ? tint.opacity(0.13) : SequoiaStyle.materialList,
                        role: isSelected ? .selected : .list
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func bentoTabItem(_ title: String, index: Int, tint: Color) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) { selectedTab = index }
        }) {
            Text(title)
                .font(BentoStyle.labelFont(12, weight: isSelected ? .black : .semibold))
                .foregroundStyle(isSelected ? BentoStyle.onAccent : BentoStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(isSelected ? tint : Color.clear)
                )
        }
        .buttonStyle(BentoPressStyle())
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

    private func minimalWhiteArtistTabSection<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            MinimalWhiteSectionTitle(title: title) {
                Text("\(count)")
                    .font(MinimalWhiteStyle.labelFont(12, weight: .medium))
                    .foregroundStyle(MinimalWhiteStyle.inkMuted)
            }

            content()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
    }

    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                loadingPlaceholder
            } else if viewModel.songs.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_songs", comment: ""))
            } else if MinimalWhiteStyle.isActive {
                minimalWhiteArtistTabSection(title: String(localized: "artist_tab_music"), count: artistSongFiltered.count) {
                    VStack(spacing: 0) {
                        artistSongSearchBar
                        artistSongRows
                    }
                    .background(
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    )
                }
                .monologueSheet(isPresented: $showArtistBatchPlaylist, preset: .standard) {
                    BatchAddToPlaylistSheet(songs: artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) })
                }
            } else if CapsuleStyle.isActive {
                CapsuleDetailSection(
                    title: "SONGS",
                    subtitle: String(format: NSLocalizedString("songs_count_format", comment: ""), artistSongFiltered.count),
                    icon: .musicNoteList,
                    tint: CapsuleStyle.accent
                ) {
                    artistSongSearchBar
                        .padding(.horizontal, -DeviceLayout.viewHorizontalPadding)

                    artistSongRows
                }
                .padding(.vertical, 10)
                .monologueSheet(isPresented: $showArtistBatchPlaylist, preset: .standard) {
                    BatchAddToPlaylistSheet(songs: artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) })
                }
            } else {
                VStack(spacing: 0) {
                    artistSongSearchBar
                    artistSongRows
                }
                .padding(.vertical, 10)
                .monologueSheet(isPresented: $showArtistBatchPlaylist, preset: .standard) {
                    BatchAddToPlaylistSheet(songs: artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) })
                }
            }
        }
    }

    private var artistSongSearchBar: some View {
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
    }

    private var artistSongRows: some View {
        LazyVStack(spacing: (CapsuleStyle.isActive || MinimalWhiteStyle.isActive) ? 4 : 0) {
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
            } else if MinimalWhiteStyle.isActive {
                minimalWhiteArtistTabSection(title: String(localized: "artist_tab_album"), count: viewModel.albums.count) {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.albums) { album in
                            albumRow(album)
                        }
                    }
                }
            } else if CapsuleStyle.isActive {
                CapsuleDetailSection(
                    title: "ALBUMS",
                    subtitle: "\(viewModel.albums.count)",
                    icon: .album,
                    tint: CapsuleStyle.violet
                ) {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.albums) { album in
                            albumRow(album)
                        }
                    }
                }
                .padding(.top, 8)
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
        let coverRadius: CGFloat = MinimalWhiteStyle.isActive ? 12 : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 8 : (BentoStyle.isActive ? 16 : (SignalStyle.isActive ? 18 : (NeumorphicStyle.isActive ? 18 : (CapsuleStyle.isActive ? 24 : (SequoiaStyle.isActive ? 18 : 10)))))))
        return Button(action: {
            selectedAlbumId = album.id
            showAlbumDetail = true
        }) {
            HStack(spacing: 14) {
                // 专辑封面
                if let coverUrl = album.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: coverRadius)
                            .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (BentoStyle.isActive ? BentoStyle.buckwheat.opacity(0.45) : (SignalStyle.isActive ? SignalStyle.controlPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint))))))))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .overlay {
                        if MangaStyle.isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: 1.5)
                        } else if MinimalWhiteStyle.isActive {
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                        } else if MujiStyle.isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                        } else if BentoStyle.isActive {
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .stroke(BentoStyle.hairline.opacity(0.55), lineWidth: 0.7)
                        } else if NeumorphicStyle.isActive {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                        } else if SignalStyle.isActive {
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                        } else if CapsuleStyle.isActive {
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .stroke(CapsuleStyle.hairline.opacity(0.72), lineWidth: 0.8)
                        } else if SequoiaStyle.isActive {
                            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                                .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: coverRadius)
                        .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (BentoStyle.isActive ? BentoStyle.buckwheat.opacity(0.45) : (SignalStyle.isActive ? SignalStyle.controlPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint))))))))
                        .frame(width: 72, height: 72)
                        .overlay(MonologueIcon(icon: .album, size: 24, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkMuted : (BentoStyle.isActive ? BentoStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.violet : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.3))))))))))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(album.name)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .medium) : (MangaStyle.isActive ? MangaStyle.bodyFont(16, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(16, weight: .regular) : (BentoStyle.isActive ? BentoStyle.bodyFont(15, weight: .heavy) : (SignalStyle.isActive ? SignalStyle.bodyFont(15, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : (CapsuleStyle.isActive ? CapsuleStyle.bodyFont(15, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .rounded(size: 16, weight: .medium)))))))))
                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (BentoStyle.isActive ? BentoStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))))))))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !album.publishDateText.isEmpty {
                            Text(album.publishDateText)
                                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (MangaStyle.isActive ? MangaStyle.bodyFont(12, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (BentoStyle.isActive ? BentoStyle.labelFont(11, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(12, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))))))))
                                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : (BentoStyle.isActive ? BentoStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))))))
                        }
                        if let size = album.size, size > 0 {
                            Text("\(size) Tracks")
                                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (MangaStyle.isActive ? MangaStyle.bodyFont(12, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (BentoStyle.isActive ? BentoStyle.labelFont(11, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(12, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))))))))
                                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : (BentoStyle.isActive ? BentoStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))))))
                        }
                    }
                }

                Spacer(minLength: 0)

                MonologueIcon(icon: .chevronRight, size: 12, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkMuted : (BentoStyle.isActive ? BentoStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (CapsuleStyle.isActive ? CapsuleStyle.cyan : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.4)))))))))
            }
            .padding(12)
            .background {
                if MangaStyle.isActive {
                    // 去卡片化：专辑行只留底部细墨线
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(MangaStyle.strokeInk.opacity(0.16))
                            .frame(height: 1)
                            .padding(.horizontal, 4)
                    }
                } else if MujiStyle.isActive {
                    VStack {
                        Spacer()
                        MujiListDivider()
                    }
                } else if BentoStyle.isActive {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(BentoStyle.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(BentoStyle.hairline.opacity(0.55), lineWidth: 0.7)
                        )
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 22, elevated: false, fill: SignalStyle.paper)
                } else if CapsuleStyle.isActive {
                    CapsuleSurfaceBackground(cornerRadius: 26, elevated: false, tint: CapsuleStyle.surface.opacity(0.86))
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, fill: SequoiaStyle.materialList, role: .list)
                } else if MinimalWhiteStyle.isActive {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.cardRadius,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
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
            } else if MinimalWhiteStyle.isActive {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                minimalWhiteArtistTabSection(title: String(localized: "artist_tab_video"), count: viewModel.mvs.count) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.mvs) { mv in
                            MVGridCard(mv: mv) {
                                selectedMV = MVIdItem(id: mv.id)
                            }
                        }
                    }
                }
            } else if CapsuleStyle.isActive {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                CapsuleDetailSection(
                    title: "VIDEOS",
                    subtitle: "\(viewModel.mvs.count)",
                    icon: .playCircle,
                    tint: CapsuleStyle.coral
                ) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.mvs) { mv in
                            MVGridCard(mv: mv) {
                                selectedMV = MVIdItem(id: mv.id)
                            }
                        }
                    }
                }
                .padding(.top, 8)
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
            } else if MinimalWhiteStyle.isActive {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                minimalWhiteArtistTabSection(title: String(localized: "artist_tab_similar"), count: viewModel.simiArtists.count) {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(viewModel.simiArtists) { artist in
                            minimalWhiteSimilarArtistCard(artist)
                        }
                    }
                }
            } else if CapsuleStyle.isActive {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                CapsuleDetailSection(
                    title: "SIMILAR",
                    subtitle: "\(viewModel.simiArtists.count)",
                    icon: .personCircle,
                    tint: CapsuleStyle.mint
                ) {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(viewModel.simiArtists) { artist in
                            capsuleSimilarArtistCard(artist)
                        }
                    }
                }
                .padding(.top, 8)
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
                                        RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (SignalStyle.isActive ? 24 : (NeumorphicStyle.isActive ? 24 : 45))))
                                            .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (SignalStyle.isActive ? SignalStyle.controlPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint)))))
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (SignalStyle.isActive ? 24 : (NeumorphicStyle.isActive ? 24 : 45))), style: .continuous))
                                    .overlay {
                                        if MangaStyle.isActive {
                                            RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous)
                                                .stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1)
                                        } else if MujiStyle.isActive {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                                        } else if NeumorphicStyle.isActive {
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                                        } else if SignalStyle.isActive {
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                                        } else if SequoiaStyle.isActive {
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                                        }
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (SignalStyle.isActive ? 24 : (NeumorphicStyle.isActive ? 24 : 45))))
                                        .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (SignalStyle.isActive ? SignalStyle.controlPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint)))))
                                        .frame(width: 90, height: 90)
                                        .overlay(MonologueIcon(icon: .personCircle, size: 32, color: MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.3)))))))
                                }

                                Text(artist.name)
                                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(13, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(13, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .semibold) : .rounded(size: 13, weight: .medium))))))
                                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))))
                                    .lineLimit(1)
                            }
                            .padding(ThemedPageStyle.isActive && !MangaStyle.isActive ? (SequoiaStyle.isActive ? 10 : 8) : 0)
                            .background {
                                if MangaStyle.isActive {
                                    // 去卡片化：相似歌手直接排在纸上
                                    EmptyView()
                                } else if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                                } else if SignalStyle.isActive {
                                    SignalSurfaceBackground(cornerRadius: 22, elevated: false, fill: SignalStyle.paper)
                                } else if SequoiaStyle.isActive {
                                    SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, fill: SequoiaStyle.materialList, role: .list)
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

    private func capsuleSimilarArtistCard(_ artist: ArtistInfo) -> some View {
        Button(action: {
            selectedArtistId = artist.id
            showArtistDetail = true
        }) {
            VStack(spacing: 9) {
                CachedAsyncImage(url: artist.coverUrl?.sized(300), width: 78, height: 78) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(CapsuleStyle.surfaceTint)
                        .overlay(MonologueIcon(icon: .personCircle, size: 28, color: CapsuleStyle.mint, lineWidth: 1.7))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.68), lineWidth: 0.8)
                )

                Text(artist.name)
                    .font(CapsuleStyle.labelFont(12, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                CapsuleSurfaceBackground(
                    cornerRadius: 24,
                    elevated: false,
                    tint: CapsuleStyle.surface.opacity(0.82)
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }

    private func minimalWhiteSimilarArtistCard(_ artist: ArtistInfo) -> some View {
        Button {
            selectedArtistId = artist.id
            showArtistDetail = true
        } label: {
            VStack(spacing: 9) {
                CachedAsyncImage(url: artist.coverUrl?.sized(300), width: 78, height: 78) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonologueIcon(icon: .personCircle, size: 28, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.7))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                Text(artist.name)
                    .font(MinimalWhiteStyle.labelFont(13, weight: .medium))
                    .foregroundStyle(MinimalWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: 占位视图

    private var loadingPlaceholder: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 48)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.accent : .monologueTextSecondary)))))
            if SignalStyle.isActive {
                Text("LOADING")
                    .font(SignalStyle.labelFont(11, weight: .bold))
                    .foregroundStyle(SignalStyle.inkMuted)
            } else if NeumorphicStyle.isActive {
                Text("LOADING")
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
            } else if CapsuleStyle.isActive {
                Text("LOADING")
                    .font(CapsuleStyle.labelFont(11, weight: .bold))
                    .foregroundStyle(CapsuleStyle.inkMuted)
            } else if SequoiaStyle.isActive {
                SequoiaMeter(tint: SequoiaStyle.accent, count: 8)
            }
            Spacer().frame(height: 48)
        }
        .frame(maxWidth: .infinity)
        .background {
            if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 26, elevated: false, tint: CapsuleStyle.surface.opacity(0.82))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome)
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            }
        }
        .padding(.horizontal, (CapsuleStyle.isActive || SequoiaStyle.isActive || MinimalWhiteStyle.isActive) ? DeviceLayout.viewHorizontalPadding : 0)
    }

    private func emptyPlaceholder(_ text: String) -> some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 48)
            if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .sparkle, tint: NeumorphicStyle.sage, size: 52)
            } else if SignalStyle.isActive {
                SignalIconBadge(icon: .sparkle, tint: SignalStyle.olive, size: 52)
            } else if CapsuleStyle.isActive {
                CapsuleIconBadge(icon: .sparkle, tint: CapsuleStyle.cyan, size: 52)
            } else if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: .sparkle, tint: SequoiaStyle.aqua, size: 52)
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .sparkle, size: 52)
            }
            Text(text)
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(14, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .rounded(size: 15))))))
                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))))
            Spacer().frame(height: 48)
        }
        .frame(maxWidth: .infinity)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: 26, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 26, elevated: false, tint: CapsuleStyle.surface.opacity(0.82))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome)
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            }
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
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
                        Circle().fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (SignalStyle.isActive ? SignalStyle.controlPressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint))))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay {
                        if NeumorphicStyle.isActive {
                            Circle()
                                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                        } else if SignalStyle.isActive {
                            Circle()
                                .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                        } else if SequoiaStyle.isActive {
                            Circle()
                                .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                        } else if MinimalWhiteStyle.isActive {
                            Circle()
                                .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.artist?.name ?? "")
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.titleFont(20, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(20, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(20, weight: .semibold) : .rounded(size: 20, weight: .bold)))))
                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))))

                    HStack(spacing: 12) {
                        if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                            HStack(spacing: 4) {
                                MonologueIcon(icon: .album, size: 12, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
                                Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                            }
                            .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))))
                            .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
                        }
                        if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                            HStack(spacing: 4) {
                                MonologueIcon(icon: .musicNote, size: 12, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
                                Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                            }
                            .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .rounded(size: 12)))))
                            .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
                        }
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else if SignalStyle.isActive {
                                SignalSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list)
                            } else if MinimalWhiteStyle.isActive {
                                MinimalWhiteCircleBackground(elevated: false)
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
                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.hairline : (SignalStyle.isActive ? SignalStyle.separator.opacity(0.52) : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : (SequoiaStyle.isActive ? SequoiaStyle.separator : Color.monologueSeparator))))
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
                                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .regular) : (SignalStyle.isActive ? SignalStyle.bodyFont(15, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular)))))
                                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))))
                                    .lineSpacing(6)
                            }
                        }

                        ForEach(desc.sections) { section in
                            bioCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.titleFont(16, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(16, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(16, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(16, weight: .semibold) : .rounded(size: 16, weight: .semibold)))))
                                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))))
                                    Text(section.content)
                                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(14, weight: .regular) : (SignalStyle.isActive ? SignalStyle.bodyFont(14, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .rounded(size: 14, weight: .regular)))))
                                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
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
                                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .regular) : (SignalStyle.isActive ? SignalStyle.bodyFont(15, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular)))))
                                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))))
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
                } else if SignalStyle.isActive {
                    ThemeRenderBackdrop(theme: .default)
                } else if SequoiaStyle.isActive {
                    SequoiaRootBackdrop()
                } else if MinimalWhiteStyle.isActive {
                    MinimalWhiteRootBackdrop()
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
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: 24, elevated: false, fill: SignalStyle.paper)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome)
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
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
            } else if SignalStyle.isActive {
                SignalIconBadge(icon: .info, tint: SignalStyle.olive, size: 52)
            } else if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: .info, tint: SequoiaStyle.aqua, size: 52)
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .info, size: 52)
            } else {
                MonologueIcon(icon: .info, size: 36, color: .monologueTextSecondary.opacity(0.3))
            }
            Text(LocalizedStringKey("artist_no_bio"))
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .rounded(size: 15)))))
                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
