import SwiftUI
import FFmpegSwiftSDK

/// 经典播放器布局 - 完全还原原始 FullScreenPlayerView 布局，仅增加主题切换按钮
struct ClassicPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showLyrics = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false

    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = false

    private var isThemedClassic: Bool { ThemedPageStyle.isActive }

    private var contentColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryContentColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var progressColor: Color {
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return contentColor.opacity(0.7)
    }

    private var classicArtworkCornerRadius: CGFloat {
        if MangaStyle.isActive { return 12 }
        if MujiStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return 22 }
        return 24
    }

    private func classicTitleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(size, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(size, weight: weight == .bold ? .medium : weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(size, weight: weight == .bold ? .semibold : weight) }
        return .rounded(size: size, weight: weight)
    }

    private func classicBodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(size, weight: weight == .regular ? .bold : weight) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(size, weight: weight == .bold ? .medium : weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(size, weight: weight) }
        return .rounded(size: size, weight: weight)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isThemedClassic {
                    classicThemeBackdrop
                }

                if showLyrics && !isThemedClassic {
                    Rectangle()
                        .fill(Color.monologueGlassTint)
                        .monologueGlass(cornerRadius: 16)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if MangaStyle.isActive {
                    mangaPlayerContent(geometry: geometry)
                } else if MujiStyle.isActive {
                    mujiPlayerContent(geometry: geometry)
                } else if NeumorphicStyle.isActive {
                    neumorphicPlayerContent(geometry: geometry)
                } else {
                    classicPlayerContent(geometry: geometry)
                }

                // 三点菜单浮层
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
        .onAppear { }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact){
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { quality in
                    player.switchQuality(quality)
                    showQualitySheet = false
                },
                onSelectQQ: { quality in
                    player.switchQQMusicQuality(quality)
                    showQualitySheet = false
                },
                songMid: player.currentSong?.qqMid,
                songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in player.switchQishuiQuality(info); showQualitySheet = false }
            )

        }
        .monologueSheet(isPresented: $showEQSettings, preset: .large){
            NavigationStack { EQSettingsView() }

        }
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker){
            PlayerThemePickerSheet()

        }
        .monologueSheet(isPresented: $showComments, preset: .large){
            if let song = player.currentSong {
                CommentView(
                    resourceId: song.id,
                    resourceType: .song,
                    songName: song.name,
                    artistName: song.artistName,
                    coverUrl: song.coverUrl
                )

            }
        }
        .monologueSheet(isPresented: $showArtistDetail, preset: .detail){
            if let song = player.currentSong {
                NavigationStack {
                    if song.isQQMusic, let mid = song.qqArtistMid {
                        QQMusicDetailView(detailType: .artist(mid: mid, name: song.artistName, coverUrl: nil))
                    } else if let artistId = song.ar?.first?.id {
                        ArtistDetailView(artistId: artistId)
                    }
                }

            }
        }
        .monologueSheet(isPresented: $showDownloadSheet, preset: .compact){
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }

            }
        }
    }

    // MARK: - 子视图

    private func classicPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 20)

            ZStack {
                artworkView(size: geometry.size.width - 64)
                    .opacity(showLyrics ? 0 : 1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height > 100 { dismiss() }
                            }
                    )

                if let song = player.currentSong {
                    LyricsView(song: song, onBackgroundTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    })
                    .opacity(showLyrics ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                }
            }
            .frame(maxHeight: .infinity)
            .onTapWithHaptic {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                }
            }

            Spacer()

            // 底部区域 — spacing: 32 与原始一致
            VStack(spacing: 32) {
                ZStack(alignment: .leading) {
                    // 用 songInfoView 撑高度，保证切换歌词时不跳动
                    songInfoView.opacity(showLyrics ? 0 : 1)
                    lyricsModeSongInfo.opacity(showLyrics ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.25), value: showLyrics)

                progressSection
                    .padding(.vertical, 8)

                controlsView
            }
            .padding(.horizontal, DeviceLayout.playerHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    private func mangaPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 14)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    mangaNowPlayingPanel(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: showLyrics)

            mangaTransportPanel
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 16)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    private func mujiPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 18)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    mujiListeningTray(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeInOut(duration: 0.28), value: showLyrics)

            mujiTransportPanel
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 20)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    @ViewBuilder
    private func themedLyricsPanel(geometry: GeometryProxy) -> some View {
        if let song = player.currentSong {
            LyricsView(song: song, onBackgroundTap: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                }
            })
            .padding(.horizontal, MangaStyle.isActive ? 18 : 20)
            .padding(.vertical, MangaStyle.isActive ? 14 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if MangaStyle.isActive {
                    MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite)
                } else if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 18, elevated: false)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true, tint: NeumorphicStyle.surface)
                }
            }
            .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18)
            .padding(.vertical, 8)
        } else {
            Color.clear
        }
    }

    private func mangaNowPlayingPanel(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.isPad ? 220 : 172, max(132, geometry.size.width * 0.42))

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                artworkTile(size: artSize)
                    .frame(width: artSize, height: artSize)
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }

                VStack(alignment: .leading, spacing: 12) {
                    mangaTitleBlock

                    HStack(spacing: 10) {
                        qualityButton

                        if let song = player.currentSong {
                            LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 24, activeColor: MangaStyle.accentPink, inactiveColor: MangaStyle.ink)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                mangaPill(MangaStyle.bubbleBlue)
                mangaPill(MangaStyle.labelYellow)
                mangaPill(MangaStyle.bubblePink)
                Spacer()
                MonologueIcon(icon: .karaoke, size: 16, color: MangaStyle.ink, lineWidth: 1.6)
                    .frame(width: 34, height: 34)
                    .background(MangaStyle.bubbleWhite, in: Circle())
                    .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.2))
            }
        }
        .padding(18)
        .background(MangaCardBackground(cornerRadius: 24, elevated: true, tint: MangaStyle.paperWarm))
        .overlay(alignment: .topTrailing) {
            MangaStar()
                .fill(MangaStyle.labelYellow)
                .overlay(MangaStar().stroke(MangaStyle.strokeInk, lineWidth: 1.5))
                .frame(width: 42, height: 42)
                .padding(10)
                .rotationEffect(.degrees(8))
        }
        .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18)
    }

    private var mangaTitleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(player.currentSong?.name ?? "Unknown Song")
                .font(MangaStyle.titleFont(25, weight: .black))
                .foregroundColor(MangaStyle.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.76)

            Button { showArtistDetail = true } label: {
                Text(player.currentSong?.artistName ?? "Unknown Artist")
                    .font(MangaStyle.bodyFont(15, weight: .bold))
                    .foregroundColor(MangaStyle.inkSub)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
        }
    }

    private func mangaPill(_ color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: 38, height: 12)
            .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.2))
    }

    private var mangaTransportPanel: some View {
        VStack(spacing: 16) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection
                .padding(.top, 2)

            controlsView
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite))
    }

    private func mujiListeningTray(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.isPad ? 300 : 246, max(190, geometry.size.width - 112))

        return VStack(spacing: 18) {
            artworkTile(size: artSize)
                .frame(width: artSize, height: artSize)
                .padding(12)
                .background(MujiPaperCardBackground(cornerRadius: 24, elevated: true))
                .onTapWithHaptic {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showLyrics.toggle()
                    }
                }

            mujiTrackLabel
        }
        .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 28)
    }

    private var mujiTrackLabel: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .font(MujiStyle.titleFont(24, weight: .medium))
                    .foregroundColor(MujiStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(MujiStyle.bodyFont(15, weight: .regular))
                        .foregroundColor(MujiStyle.inkSoft)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 10)

            VStack(spacing: 10) {
                qualityButton

                if let song = player.currentSong {
                    LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 24, activeColor: MujiStyle.clay, inactiveColor: MujiStyle.ink)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(MujiPaperCardBackground(cornerRadius: 14, elevated: false))
    }

    private var mujiTransportPanel: some View {
        VStack(spacing: 16) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection

            Rectangle()
                .fill(MujiStyle.hairline.opacity(0.5))
                .frame(height: 0.7)
                .padding(.horizontal, 22)

            controlsView
        }
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(MujiPaperCardBackground(cornerRadius: 18, elevated: false))
    }

    private func neumorphicPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 12)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    neumorphicListeningConsole(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.46, dampingFraction: 0.84), value: showLyrics)

            neumorphicTransportConsole
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    private func neumorphicListeningConsole(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.isPad ? 288 : 226, max(174, geometry.size.width - 138))

        return VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.clear)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 32, elevated: true, tint: NeumorphicStyle.surfaceRaised))
                    .frame(height: artSize + 54)

                artworkTile(size: artSize)
                    .frame(width: artSize, height: artSize)
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }

                VStack {
                    HStack {
                        NeumorphicPill(
                            text: player.qualityButtonText,
                            tint: NeumorphicStyle.warm,
                            icon: .headphones,
                            selected: true,
                            compact: true
                        )
                        .onTapGesture { showQualitySheet = true }

                        Spacer()

                        if let song = player.currentSong {
                            LikeButton(
                                songId: song.id,
                                isQQMusic: song.isQQMusic,
                                song: song,
                                size: 23,
                                activeColor: NeumorphicStyle.red,
                                inactiveColor: NeumorphicStyle.inkSoft
                            )
                            .frame(width: 40, height: 40)
                            .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false))
                        }
                    }

                    Spacer()
                }
                .padding(18)
            }
            .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 22)

            neumorphicTrackPanel
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 24)
        }
    }

    private var neumorphicTrackPanel: some View {
        HStack(alignment: .center, spacing: 14) {
            NeumorphicIconBadge(icon: player.isPlaying ? .pause : .play, tint: NeumorphicStyle.accent, size: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .font(NeumorphicStyle.titleFont(23, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(NeumorphicStyle.bodyFont(14, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkSoft)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .karaoke, size: 17, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
                .frame(width: 34, height: 34)
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, tint: NeumorphicStyle.surface))
    }

    private var neumorphicTransportConsole: some View {
        VStack(spacing: 15) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection
                .padding(.top, 4)

            controlsView
        }
        .padding(.horizontal, 8)
        .padding(.top, 15)
        .padding(.bottom, 17)
        .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true, tint: NeumorphicStyle.surface))
    }

    private var qualityButton: some View {
        Button(action: { showQualitySheet = true }) {
            Text(player.qualityButtonText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(qualityBadgeForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(qualityBadgeBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(qualityBadgeStroke, lineWidth: MangaStyle.isActive ? 1.4 : 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var classicThemeBackdrop: some View {
        if MangaStyle.isActive {
            ZStack {
                MangaRootBackdrop()
                MangaDotsTexture(opacity: colorScheme == .dark ? 0.03 : 0.045, gap: 15)
            }
            .ignoresSafeArea()
        } else if MujiStyle.isActive {
            MujiRootBackdrop()
                .ignoresSafeArea()
        } else if NeumorphicStyle.isActive {
            NeumorphicRootBackdrop()
                .ignoresSafeArea()
        }
    }

    private var headerView: some View {
        HStack {
            MonologueBackButton(style: .dismiss, isDarkBackground: false)
                .contentShape(Circle())

            Spacer()

            VStack(spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(classicBodyFont(12, weight: MangaStyle.isActive ? .black : .medium))
                    .foregroundColor(secondaryContentColor)
                    .tracking(1)

                if let name = player.currentSong?.name {
                    MarqueeText(
                        text: name,
                        font: classicBodyFont(13, weight: .semibold),
                        color: secondaryContentColor,
                        speed: 30,
                        delayBeforeScroll: 2.0,
                        alignment: .center
                    )
                    .frame(maxWidth: 180)
                }

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: MangaStyle.isActive ? .black : .medium, design: .monospaced))
                        .foregroundColor(secondaryContentColor.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 三点菜单按钮
            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() } }) {
                ZStack {
                    if NeumorphicStyle.isActive {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                            .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true))
                    } else {
                        Circle()
                            .fill(Color.monologueGlassTint)
                            .frame(width: 44, height: 44)
                            .monologueGlassCircle()
                    }
                    MonologueIcon(icon: .more, size: 22, color: contentColor)
                }
                .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    /// 封面视图 — 关键：内部 ZStack 带 .frame(maxHeight: .infinity) 让封面撑满中间区域
    private func artworkView(size: CGFloat) -> some View {
        let artSize = min(size, DeviceLayout.playerArtworkMaxSize)

        return artworkTile(size: artSize)
            .frame(maxHeight: .infinity)
    }

    private func artworkTile(size: CGFloat) -> some View {
        let cornerRadius = classicArtworkCornerRadius

        return classicArtworkFrame(
            ZStack {
                if let song = player.currentSong {
                    ZStack {
                        CachedAsyncImage(url: song.coverUrl?.sized(800)) {
                            MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.gray.opacity(0.2)))
                        }
                        .aspectRatio(contentMode: .fill)

                        if let dynamicUrl = player.dynamicCoverUrl, !dynamicUrl.isEmpty {
                            DynamicCoverView(urlString: dynamicUrl, cornerRadius: cornerRadius)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.gray.opacity(0.1))))
                        .overlay(
                            MonologueIcon(icon: .musicNoteList, size: 80, color: secondaryContentColor.opacity(0.32))
                        )
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)),
            cornerRadius: cornerRadius
        )
    }

    @ViewBuilder
    private func classicArtworkFrame<Content: View>(_ content: Content, cornerRadius: CGFloat) -> some View {
        if MangaStyle.isActive {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth + 0.6)
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 5, y: 5)
                )
                .rotationEffect(.degrees(-1.6))
        } else if MujiStyle.isActive {
            content
                .padding(8)
                .background(MujiPaperCardBackground(cornerRadius: cornerRadius + 8, elevated: true))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 8, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.7), lineWidth: 0.7)
                )
        } else if NeumorphicStyle.isActive {
            content
                .padding(10)
                .background(NeumorphicSurfaceBackground(cornerRadius: cornerRadius + 12, elevated: true, tint: NeumorphicStyle.surfaceRaised))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 12, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
                )
        } else {
            content
                .monologueBackgroundExtension()
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private var songInfoView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .font(classicTitleFont(26, weight: .bold))
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(classicBodyFont(18, weight: .medium))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(qualityBadgeForeground)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(qualityBadgeBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(qualityBadgeStroke, lineWidth: MangaStyle.isActive ? 1.4 : 1)
                    )
            }

            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 26, activeColor: .red, inactiveColor: contentColor)
            } else {
                MonologueIcon(icon: .like, size: 26, color: contentColor)
            }
        }
        .padding(.horizontal, isThemedClassic ? 14 : 0)
        .padding(.vertical, isThemedClassic ? 12 : 0)
        .background {
            classicInfoBackground
        }
    }

    @ViewBuilder
    private var classicInfoBackground: some View {
        if MangaStyle.isActive {
            MangaCardBackground(cornerRadius: 16, elevated: true, tint: MangaStyle.bubbleWhite)
        } else if MujiStyle.isActive {
            MujiPaperCardBackground(cornerRadius: 12, elevated: false)
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var qualityBadgeBackground: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(MangaStyle.labelYellow)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(MujiStyle.surfaceRaised)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(NeumorphicStyle.surfaceRaised)
        } else {
            Color.clear
        }
    }

    private var qualityBadgeStroke: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.hairline }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator }
        return contentColor.opacity(0.5)
    }

    private var qualityBadgeForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        return contentColor
    }

    private var lyricsModeSongInfo: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.name ?? "")
                    .font(classicTitleFont(20, weight: .bold))
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "")
                        .font(classicBodyFont(14, weight: .medium))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: { withAnimation { enableKaraoke.toggle() } }) {
                MonologueIcon(icon: .karaoke, size: 20, color: enableKaraoke ? contentColor : secondaryContentColor.opacity(0.3))
                    .padding(8)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }

            Button(action: { withAnimation { showTranslation.toggle() } }) {
                MonologueIcon(icon: .translate, size: 20, color: showTranslation ? contentColor : secondaryContentColor.opacity(0.3))
                    .padding(8)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }

            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 22, activeColor: .red, inactiveColor: contentColor)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, isThemedClassic ? 8 : 0)
    }

    /// 进度条区域 — 柔和融入背景的波形进度条
    private var progressSection: some View {
        VStack(spacing: 6) {
            FullScreenPlayerView.WaveformProgressBar(
                currentTime: Binding(
                    get: { isDraggingSlider ? dragTimeValue : timePublisher.currentTime },
                    set: { _ in }
                ),
                duration: timePublisher.duration,
                color: progressColor,
                trackOpacity: 0.1,
                isAnimating: player.isPlaying,
                onSeek: { time in
                    isDraggingSlider = true
                    dragTimeValue = time
                },
                onCommit: { time in
                    isDraggingSlider = false
                    player.seek(to: time)
                }
            )
            .frame(height: 20)

            HStack {
                Text(formatTime(isDraggingSlider ? dragTimeValue : timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.rounded(size: 11, weight: .medium))
            .foregroundColor(secondaryContentColor.opacity(0.6))
            .monospacedDigit()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    @ViewBuilder
    private var classicPlayButtonBackground: some View {
        let size = DeviceLayout.playerPlayButtonSize

        if MangaStyle.isActive {
            Circle()
                .fill(MangaStyle.labelYellow)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                .background(
                    Circle()
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 3.5, y: 3.5)
                )
        } else if MujiStyle.isActive {
            Circle()
                .fill(MujiStyle.surfaceRaised)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.72), lineWidth: 0.75))
                .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 7)
        } else if NeumorphicStyle.isActive {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .background(NeumorphicSurfaceBackground(cornerRadius: size / 2, elevated: true))
        } else {
            Circle()
                .fill(Color.monologueGlassTint)
                .frame(width: size, height: size)
                .monologueGlassCircle()
        }
    }

    private var classicPlayIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return .monologueTextPrimary
    }

    /// 控制按钮 — 与原始完全一致
    private var controlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .frame(width: 44)

                Spacer()

                Button(action: { player.previous() }) {
                    MonologueIcon(icon: .previous, size: 32, color: contentColor)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        classicPlayButtonBackground

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: classicPlayIconColor))
                                .scaleEffect(1.2)
                        } else {
                            MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 32, color: classicPlayIconColor)
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))

                Spacer()

                Button(action: { player.next() }) {
                    MonologueIcon(icon: .next, size: 32, color: contentColor)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                Button(action: { showPlaylist = true }) {
                    MonologueIcon(icon: .list, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .frame(width: 44)
            }

            if let song = player.currentSong {
                HStack(spacing: 0) {
                    Button { showComments = true } label: {
                        MonologueIcon(icon: .comment, size: 22, color: secondaryContentColor, lineWidth: 1.4)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .frame(width: 44)

                    Spacer()

                    Button {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            showDownloadSheet = true
                        }
                    } label: {
                        MonologueIcon(
                            icon: .playerDownload,
                            size: 22,
                            color: downloadManager.isDownloaded(songId: song.id) ? .monologueTextSecondary : secondaryContentColor,
                            lineWidth: 1.4
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .disabled(downloadManager.isDownloaded(songId: song.id))
                    .frame(width: 44)
                }
            }
        }
    }

    // MARK: - 辅助方法

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let khz = Double(sr) / 1000.0
                parts.append(khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz))
            } else { parts.append("\(sr)Hz") }
        }
        if let bd = info.bitDepth, bd > 0 { parts.append("\(bd)bit") }
        if let ch = info.channelCount, ch > 2 { parts.append("\(ch)ch") }
        return parts.joined(separator: " / ")
    }
}
