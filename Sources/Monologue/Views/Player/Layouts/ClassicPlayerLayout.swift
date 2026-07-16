import SwiftUI
import FFmpegSwiftSDK

/// 经典播放器布局 - 完全还原原始 FullScreenPlayerView 布局，仅增加主题切换按钮
struct ClassicPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var lyricAlignment = AILyricAlignmentAgent.shared
    @StateObject private var asideCoverColors = CoverColorExtractor()

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


    private var isThemedClassic: Bool { ThemedPageStyle.isActive }

    private var contentColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if ClayStyle.isActive { return ClayStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryContentColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if ClayStyle.isActive { return ClayStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var asideCoverAccent: Color {
        guard player.currentSong != nil else { return .monologueIconBackground }
        return asideCoverColors.dominantColor
    }

    private var asideCoverAccentForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: asideCoverAccent,
            light: Color(hex: "111318"),
            dark: .white
        )
    }

    private var progressColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if ClayStyle.isActive { return ClayStyle.accent }
        return contentColor.opacity(0.7)
    }

    private var classicArtworkCornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 12 }
        if MangaStyle.isActive { return 12 }
        if MujiStyle.isActive { return 22 }
        if NeumorphicStyle.isActive { return 22 }
        if CapsuleStyle.isActive { return 28 }
        if SequoiaStyle.isActive { return 24 }
        if ClayStyle.isActive { return 30 }
        return isThemedClassic ? 24 : 14
    }

    private func classicTitleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.titleFont(size, weight: weight) }
        if MangaStyle.isActive { return MangaStyle.titleFont(size, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(size, weight: weight == .bold ? .medium : weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(size, weight: weight == .bold ? .semibold : weight) }
        if CapsuleStyle.isActive { return CapsuleStyle.titleFont(size, weight: weight == .bold ? .bold : weight) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(size, weight: weight == .bold ? .semibold : weight) }
        if ClayStyle.isActive { return ClayStyle.titleFont(size, weight: weight == .bold ? .bold : weight) }
        return .rounded(size: size, weight: weight)
    }

    private func classicBodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(size, weight: weight) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(size, weight: weight == .regular ? .bold : weight) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(size, weight: weight == .bold ? .medium : weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(size, weight: weight) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(size, weight: weight) }
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(size, weight: weight == .bold ? .semibold : weight) }
        if ClayStyle.isActive { return ClayStyle.bodyFont(size, weight: weight) }
        return .rounded(size: size, weight: weight)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

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
                } else if CapsuleStyle.isActive {
                    capsulePlayerContent(geometry: geometry)
                } else if ClayStyle.isActive {
                    clayPlayerContent(geometry: geometry)
                } else if isThemedClassic {
                    classicPlayerContent(geometry: geometry)
                } else {
                    asideDefaultPlayerContent(geometry: geometry)
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
        .onAppear {
            refreshAsideCoverAccent()
        }
        .onChange(of: player.currentSong?.coverUrl?.absoluteString) { _, _ in
            refreshAsideCoverAccent()
        }
        .onChange(of: isThemedClassic) { _, themed in
            if !themed {
                refreshAsideCoverAccent()
            }
        }
        .monologueSheet(isPresented: $showQualitySheet, preset: .standard){
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
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
        .fullScreenCover(isPresented: $showEQSettings) {
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

    @ViewBuilder
    private func asideDefaultPlayerContent(geometry: GeometryProxy) -> some View {
        let usesWideLayout = geometry.size.width >= 560 && geometry.size.width > geometry.size.height

        if (DeviceLayout.isPad && geometry.size.width >= 760) || usesWideLayout {
            asideWidePlayerContent(geometry: geometry)
        } else {
            asidePhonePlayerContent(geometry: geometry)
        }
    }

    private func asidePhonePlayerContent(geometry: GeometryProxy) -> some View {
        let compactHeight = geometry.size.height < 740
        let horizontalPadding: CGFloat = compactHeight ? 22 : 24
        let widthBound = max(190, geometry.size.width - horizontalPadding * 2)
        let heightBound = geometry.size.height * (compactHeight ? 0.35 : 0.41)
        let asideArtworkMaxSize: CGFloat = DeviceLayout.isPad ? 480 : 380
        let artworkSize = min(asideArtworkMaxSize, min(widthBound, heightBound))
        let sectionSpacing: CGFloat = compactHeight ? 12 : 18

        return VStack(spacing: 0) {
            asideHeaderView
                .padding(.top, DeviceLayout.headerTopPadding)

            Spacer(minLength: compactHeight ? 6 : 14)

            asidePlaybackStage(size: artworkSize)

            Spacer(minLength: compactHeight ? 9 : 16)

            VStack(spacing: sectionSpacing) {
                asideTrackSummary
                asideProgressSection
                asideTransportBar
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, max(DeviceLayout.safeAreaBottom + 10, compactHeight ? 18 : 26))
        }
    }

    private func asideWidePlayerContent(geometry: GeometryProxy) -> some View {
        let isCompactWide = !DeviceLayout.isPad
        let horizontalPadding: CGFloat = isCompactWide ? 28 : 54
        let columnSpacing: CGFloat = isCompactWide ? 28 : 52
        let artworkSize = min(
            isCompactWide ? 320 : 500,
            min(
                geometry.size.width * (isCompactWide ? 0.36 : 0.46),
                geometry.size.height * (isCompactWide ? 0.64 : 0.58)
            )
        )

        return VStack(spacing: 0) {
            asideHeaderView
                .padding(.top, DeviceLayout.headerTopPadding)

            HStack(spacing: columnSpacing) {
                asidePlaybackStage(size: artworkSize)

                VStack(spacing: isCompactWide ? 16 : 24) {
                    asideTrackSummary
                    asideProgressSection
                    asideTransportBar
                }
                .frame(maxWidth: 470)
            }
            .frame(maxWidth: 1080, maxHeight: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(
                .bottom,
                max(DeviceLayout.safeAreaBottom + (isCompactWide ? 6 : 18), isCompactWide ? 12 : 34)
            )
        }
    }

    private var asideHeaderView: some View {
        HStack(spacing: 12) {
            MonologueBackButton(style: .dismiss, isDarkBackground: false)
                .contentShape(Circle())

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    .foregroundColor(contentColor)

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 190)

            Spacer(minLength: 0)

            asideHeaderIconButton(
                icon: .more,
                accessibilityLabel: String(localized: "player_more_title")
            ) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    showMoreMenu.toggle()
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    @ViewBuilder
    private func asidePlaybackStage(size: CGFloat) -> some View {
        if showLyrics, let song = player.currentSong {
            LyricsView(song: song, onBackgroundTap: {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    showLyrics = false
                }
            })
            .frame(width: size, height: size)
            .transition(.opacity)
        } else {
            artworkTile(size: size)
                .contentShape(RoundedRectangle(cornerRadius: classicArtworkCornerRadius, style: .continuous))
                .onTapWithHaptic {
                    guard player.currentSong != nil else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        showLyrics = true
                    }
                }
                .accessibilityLabel(String(localized: "settings_lyrics"))
                .accessibilityAddTraits(.isButton)
                .accessibilityHidden(player.currentSong == nil)
                .frame(width: size, height: size)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 100 { dismiss() }
                        }
                )
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var asideTrackSummary: some View {
        if showLyrics, player.currentSong != nil {
            lyricsModeSongInfo
        } else {
            asideTrackInfo
        }
    }

    private var asideTrackInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(player.currentSong?.name ?? "")
                    .monologuePlayerDisplayFont(
                        size: 27,
                        weight: .semibold,
                        fallback: .system(size: 27, weight: .semibold, design: .default)
                    )
                    .foregroundColor(contentColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 4)

                if let song = player.currentSong {
                    LikeButton(
                        songId: song.id,
                        isQQMusic: song.isQQMusic,
                        song: song,
                        size: 23,
                        activeColor: .red,
                        inactiveColor: contentColor
                    )
                    .frame(width: 44, height: 44)
                }
            }

            HStack(spacing: 8) {
                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? String(localized: "search_unknown_artist"))
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .disabled(player.currentSong == nil)

                Spacer(minLength: 6)

                asideQualityButton

                if player.currentSong != nil {
                    asideInlineIconButton(
                        icon: .comment,
                        accessibilityLabel: String(localized: "comment_title")
                    ) {
                        showComments = true
                    }
                }

                if AppConfig.Features.downloadEnabled, let song = player.currentSong {
                    let isDownloaded = downloadManager.isDownloaded(songId: song.id)

                    asideInlineIconButton(
                        icon: .playerDownload,
                        accessibilityLabel: String(localized: "song_download")
                    ) {
                        if !isDownloaded {
                            showDownloadSheet = true
                        }
                    }
                    .disabled(isDownloaded)
                    .opacity(isDownloaded ? 0.46 : 1)
                }
            }
        }
    }

    private var asideProgressSection: some View {
        VStack(spacing: 4) {
            asideProgressRail

            HStack {
                Text(formatTime(isDraggingSlider ? dragTimeValue : timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundColor(secondaryContentColor)
            .monospacedDigit()
        }
    }

    private var asideProgressRail: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let rawDuration = timePublisher.duration
            let duration = rawDuration.isFinite && rawDuration > 0 ? rawDuration : 0
            let rawDisplayedTime = isDraggingSlider ? dragTimeValue : timePublisher.currentTime
            let displayedTime = rawDisplayedTime.isFinite ? rawDisplayedTime : 0
            let progress = duration > 0 ? min(max(displayedTime / duration, 0), 1) : 0
            let progressX = width * CGFloat(progress)
            let railHeight: CGFloat = isDraggingSlider ? 6 : 4
            let thumbSize: CGFloat = isDraggingSlider ? 14 : 8
            let thumbOffset = min(
                max(progressX - thumbSize / 2, 0),
                max(width - thumbSize, 0)
            )

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(contentColor.opacity(colorScheme == .dark ? 0.18 : 0.1))
                    .frame(height: 4)

                if progress > 0 {
                    Capsule(style: .continuous)
                        .fill(asideCoverAccent)
                        .frame(
                            width: max(progressX, railHeight),
                            height: railHeight
                        )
                }

                if duration > 0 {
                    if isDraggingSlider {
                        Circle()
                            .fill(asideCoverAccent.opacity(0.16))
                            .frame(width: 26, height: 26)
                            .offset(x: thumbOffset - 6)
                    }

                    Circle()
                        .fill(asideCoverAccent)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12),
                            radius: isDraggingSlider ? 3 : 1.5,
                            y: 1
                        )
                        .offset(x: thumbOffset)
                }
            }
            .frame(width: width, height: geometry.size.height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        isDraggingSlider = true
                        let ratio = min(max(value.location.x / width, 0), 1)
                        dragTimeValue = Double(ratio) * duration
                    }
                    .onEnded { value in
                        guard duration > 0 else {
                            isDraggingSlider = false
                            return
                        }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        let target = Double(ratio) * duration
                        dragTimeValue = target
                        isDraggingSlider = false
                        player.seek(to: target)
                    }
            )
        }
        .frame(height: 28)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isDraggingSlider)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "播放进度"))
        .accessibilityValue(
            "\(formatTime(isDraggingSlider ? dragTimeValue : timePublisher.currentTime)) / \(formatTime(timePublisher.duration))"
        )
        .accessibilityAdjustableAction { direction in
            let duration = timePublisher.duration
            guard duration.isFinite, duration > 0 else { return }
            let rawCurrent = isDraggingSlider ? dragTimeValue : timePublisher.currentTime
            let current = rawCurrent.isFinite ? rawCurrent : 0
            let step = max(5, min(15, duration * 0.01))

            switch direction {
            case .increment:
                player.seek(to: min(current + step, duration))
            case .decrement:
                player.seek(to: max(current - step, 0))
            @unknown default:
                break
            }
        }
    }

    private var asideTransportBar: some View {
        let playButtonSize: CGFloat = DeviceLayout.isPad ? 72 : 68

        return HStack(spacing: 0) {
            asideTransportIconButton(
                icon: player.mode.monologueIcon,
                accessibilityLabel: player.mode.displayName
            ) {
                player.switchMode()
            }

            Spacer(minLength: 0)

            Button(action: { player.previous() }) {
                MonologueIcon(icon: .previous, size: 29, color: contentColor)
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .accessibilityLabel(String(localized: "上一首"))

            Spacer(minLength: 0)

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(asideCoverAccent)
                        .shadow(
                            color: asideCoverAccent.opacity(colorScheme == .dark ? 0.18 : 0.24),
                            radius: 7,
                            y: 4
                        )

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: asideCoverAccentForeground)
                            )
                    } else {
                        MonologueIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 29,
                            color: asideCoverAccentForeground
                        )
                    }
                }
                .frame(width: playButtonSize, height: playButtonSize)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
            .accessibilityLabel(
                player.isPlaying
                    ? String(localized: "暂停")
                    : String(localized: "action_play")
            )

            Spacer(minLength: 0)

            Button(action: { player.next() }) {
                MonologueIcon(icon: .next, size: 29, color: contentColor)
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
            .accessibilityLabel(String(localized: "playback_next_track"))

            Spacer(minLength: 0)

            asideTransportIconButton(
                icon: .list,
                accessibilityLabel: String(localized: "player_queue")
            ) {
                showPlaylist = true
            }
        }
    }

    private func refreshAsideCoverAccent() {
        guard !isThemedClassic else { return }
        asideCoverColors.extract(
            from: player.currentSong?.coverUrl?.sized(300).absoluteString
        )
    }

    private func asideHeaderIconButton(
        icon: MonologueIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 20, color: contentColor)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

    private var asideQualityButton: some View {
        Button(action: { showQualitySheet = true }) {
            Text(player.qualityButtonText)
                .font(.system(size: 9.5, weight: .semibold, design: .default))
                .tracking(0.2)
                .foregroundColor(contentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(contentColor.opacity(0.045))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(contentColor.opacity(0.16), lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .playerQualitySelectionAvailability()
    }

    private func asideInlineIconButton(
        icon: MonologueIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 18, color: secondaryContentColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(contentColor.opacity(0.055))
                )
                .contentShape(Circle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

    private func asideTransportIconButton(
        icon: MonologueIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 19, color: secondaryContentColor)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

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
                    MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true, tint: NeumorphicStyle.surface)
                } else if CapsuleStyle.isActive {
                    CapsuleSurfaceBackground(cornerRadius: 28, elevated: true, tint: CapsuleStyle.surface.opacity(0.94))
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 26, elevated: true, role: .chrome)
                } else if ClayStyle.isActive {
                    ClaySurfaceBackground(cornerRadius: 30, tint: ClayStyle.cream.opacity(0.96), elevated: true)
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
        .background(MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.paperWarm))
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
                .monologuePlayerDisplayFont(
                    size: 25,
                    weight: .black,
                    fallback: MangaStyle.titleFont(25, weight: .black)
                )
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
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 38, height: 12)
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.2))
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
        .background(MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite))
    }

    private func mujiListeningTray(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.isPad ? 300 : 246, max(190, geometry.size.width - 112))

        return VStack(spacing: 24) {
            artworkTile(size: artSize)
                .frame(width: artSize, height: artSize)
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    MujiDotMark()

                    Text("NOW PLAYING")
                        .font(MujiStyle.labelFont(9.5, weight: .semibold))
                        .foregroundColor(MujiStyle.clay)
                        .tracking(2)
                }

                Text(player.currentSong?.name ?? "Unknown Song")
                    .monologuePlayerDisplayFont(
                        size: 25,
                        weight: .medium,
                        fallback: MujiStyle.titleFont(25, weight: .medium)
                    )
                    .foregroundColor(MujiStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(MujiStyle.labelFont(12.5, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(1.4)
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
        .padding(.top, 18)
    }

    private var mujiTransportPanel: some View {
        VStack(spacing: 15) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection

            MujiStitchLine()
                .stroke(
                    MujiStyle.separator.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [0.1, 8])
                )
                .frame(height: 2)
                .padding(.horizontal, 22)

            controlsView
        }
        .padding(.horizontal, 6)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.92))
                .shadow(color: MujiStyle.ink.opacity(0.06), radius: 16, x: 0, y: 6)
        )
    }

    private func neumorphicPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 8)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    neumorphicListeningConsole(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showLyrics)

            neumorphicTransportConsole
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 14)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
        .themeRenderSceneLayer()
    }

    private func neumorphicListeningConsole(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18
        let availableWidth = geometry.size.width - horizontalPadding * 2
        let artSize = min(DeviceLayout.isPad ? 220 : 168, max(132, availableWidth * 0.42))

        return VStack(spacing: 12) {
            neumorphicArtworkStage(artSize: artSize)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private func neumorphicArtworkStage(artSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                neumorphicQualityChip

                Spacer(minLength: 12)

                neumorphicPlaybackMark
            }

            HStack(alignment: .center, spacing: 16) {
                artworkTile(size: artSize)
                    .frame(width: artSize, height: artSize)
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }

                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(player.currentSong?.name ?? "Unknown Song")
                            .monologuePlayerDisplayFont(
                                size: 24,
                                weight: .semibold,
                                fallback: NeumorphicStyle.titleFont(24, weight: .semibold)
                            )
                            .foregroundStyle(NeumorphicStyle.ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.74)

                        Button { showArtistDetail = true } label: {
                            Text(player.currentSong?.artistName ?? "Unknown Artist")
                                .font(NeumorphicStyle.bodyFont(14, weight: .medium))
                                .foregroundStyle(NeumorphicStyle.inkSoft)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                    }

                    neumorphicStatusDeck

                    HStack(spacing: 10) {
                        neumorphicLikeControl
                        neumorphicLyricsToggle
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 32,
                elevated: true,
                tint: NeumorphicStyle.surfaceRaised
            )
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Capsule().fill(NeumorphicStyle.accent.opacity(0.5)).frame(width: 24, height: 6)
                Capsule().fill(NeumorphicStyle.sage.opacity(0.34)).frame(width: 12, height: 6)
            }
            .padding(.leading, 26)
            .padding(.top, 12)
        }
    }

    private var neumorphicStatusDeck: some View {
        HStack(spacing: 8) {
            neumorphicMiniMeter

            VStack(alignment: .leading, spacing: 5) {
                Capsule()
                    .fill(NeumorphicStyle.accent.opacity(player.isPlaying ? 0.76 : 0.34))
                    .frame(width: player.isPlaying ? 58 : 36, height: 6)
                Capsule()
                    .fill(NeumorphicStyle.separator.opacity(0.55))
                    .frame(width: 78, height: 5)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 16,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: player.isPlaying)
    }

    private var neumorphicQualityChip: some View {
        Button(action: { showQualitySheet = true }) {
            HStack(spacing: 7) {
                MonologueIcon(icon: .headphones, size: 12, color: NeumorphicStyle.warm, lineWidth: 1.5)
                Text(player.qualityButtonText)
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
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
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
        .playerQualitySelectionAvailability()
    }

    @ViewBuilder
    private var neumorphicLikeControl: some View {
        if let song = player.currentSong {
            LikeButton(
                songId: song.id,
                isQQMusic: song.isQQMusic,
                song: song,
                size: 23,
                activeColor: NeumorphicStyle.red,
                inactiveColor: NeumorphicStyle.inkSoft
            )
            .frame(width: 42, height: 42)
            .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: true, lightweight: true))
        } else {
            MonologueIcon(icon: .like, size: 22, color: NeumorphicStyle.inkSoft, lineWidth: 1.5)
                .frame(width: 42, height: 42)
                .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: true, lightweight: true))
        }
    }

    private var neumorphicPlaybackMark: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(NeumorphicStyle.accent.opacity(player.isPlaying ? 0.92 : 0.42))
                .frame(width: player.isPlaying ? 22 : 10, height: 7)
            Capsule()
                .fill(NeumorphicStyle.sage.opacity(player.isPlaying ? 0.72 : 0.34))
                .frame(width: player.isPlaying ? 12 : 18, height: 7)
            Capsule()
                .fill(NeumorphicStyle.warm.opacity(player.isPlaying ? 0.68 : 0.3))
                .frame(width: player.isPlaying ? 8 : 12, height: 7)
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 15,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: player.isPlaying)
    }

    private var neumorphicLyricsToggle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                showLyrics.toggle()
            }
        }) {
            MonologueIcon(
                icon: .karaoke,
                size: 17,
                color: showLyrics ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft,
                lineWidth: 1.5
            )
            .frame(width: 42, height: 42)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: !showLyrics,
                    pressed: showLyrics,
                    tint: showLyrics ? NeumorphicStyle.accent.opacity(0.14) : NeumorphicStyle.surfaceRaised,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
    }

    private var neumorphicMiniMeter: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? NeumorphicStyle.accent.opacity(0.72) : NeumorphicStyle.sage.opacity(0.52))
                    .frame(width: 4, height: player.isPlaying ? CGFloat(9 + (index % 3) * 5) : 8)
            }
        }
        .frame(width: 36, height: 30)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 12,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: player.isPlaying)
    }

    private var neumorphicTransportConsole: some View {
        VStack(spacing: 14) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, 10)
            }

            neumorphicProgressChannel

            neumorphicTransportControls

            if let song = player.currentSong {
                neumorphicUtilityRail(song: song)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(NeumorphicSurfaceBackground(cornerRadius: 31, elevated: true, tint: NeumorphicStyle.surface))
        .overlay(alignment: .top) {
            Capsule()
                .fill(NeumorphicStyle.lightShadow(colorScheme, intensity: 0.34))
                .frame(width: 62, height: 4)
                .offset(y: 9)
        }
    }

    private var neumorphicProgressChannel: some View {
        VStack(spacing: 7) {
            FullScreenPlayerView.WaveformProgressBar(
                currentTime: Binding(
                    get: { isDraggingSlider ? dragTimeValue : timePublisher.currentTime },
                    set: { _ in }
                ),
                duration: timePublisher.duration,
                color: NeumorphicStyle.accent,
                trackOpacity: 0.12,
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
            .frame(height: 28)

            HStack {
                Text(formatTime(isDraggingSlider ? dragTimeValue : timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(NeumorphicStyle.labelFont(11, weight: .medium))
            .foregroundColor(NeumorphicStyle.inkMuted)
            .monospacedDigit()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 20,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
    }

    private var neumorphicTransportControls: some View {
        HStack(spacing: 8) {
            neumorphicIconButton(icon: player.mode.monologueIcon, diameter: 40, iconSize: 20, tint: NeumorphicStyle.inkSoft) {
                player.switchMode()
            }

            HStack(spacing: 6) {
                neumorphicIconButton(icon: .previous, diameter: 44, iconSize: 24, tint: NeumorphicStyle.ink) {
                    player.previous()
                }

                neumorphicMainPlayButton

                neumorphicIconButton(icon: .next, diameter: 44, iconSize: 24, tint: NeumorphicStyle.ink) {
                    player.next()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 6)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 31,
                    elevated: false,
                    pressed: true,
                    tint: NeumorphicStyle.surfacePressed,
                    lightweight: true
                )
            )

            neumorphicIconButton(icon: .list, diameter: 40, iconSize: 20, tint: NeumorphicStyle.inkSoft) {
                showPlaylist = true
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var neumorphicMainPlayButton: some View {
        Button(action: { player.togglePlayPause() }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 64, height: 64)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 32,
                            elevated: true,
                            tint: NeumorphicStyle.accent.opacity(player.isPlaying ? 0.22 : 0.16)
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        NeumorphicStyle.lightShadow(colorScheme, intensity: 0.58),
                                        NeumorphicStyle.accent.opacity(0.32),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .padding(5)
                    )

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: NeumorphicStyle.accent))
                        .scaleEffect(1.08)
                } else {
                    MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 30, color: NeumorphicStyle.accent, lineWidth: 1.6)
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
        .scaleEffect(player.isPlaying ? 1 : 0.97)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: player.isPlaying)
    }

    private func neumorphicIconButton(
        icon: MonologueIcon.IconType,
        diameter: CGFloat,
        iconSize: CGFloat,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: iconSize, color: tint, lineWidth: 1.5)
                .frame(width: diameter, height: diameter)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: diameter / 2,
                        elevated: true,
                        tint: NeumorphicStyle.surfaceRaised,
                        lightweight: true
                    )
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
    }

    private func neumorphicUtilityRail(song: Song) -> some View {
        HStack(spacing: 12) {
            neumorphicUtilityButton(icon: .comment, tint: NeumorphicStyle.sage) {
                showComments = true
            }

            if AppConfig.Features.downloadEnabled {
                // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                neumorphicDownloadButton(song: song)
            } else {
                // 沉浸模式按钮 — 占用原下载按钮的位置
                neumorphicUtilityButton(icon: .immersive, tint: NeumorphicStyle.warm) {
                    CinemaModeController.shared.present()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 20,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
    }

    private func neumorphicUtilityButton(
        icon: MonologueIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 21, color: tint, lineWidth: 1.45)
                .frame(width: 42, height: 42)
                .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true, lightweight: true))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
    }

    private func neumorphicDownloadButton(song: Song) -> some View {
        let isDownloaded = downloadManager.isDownloaded(songId: song.id)

        return Button {
            if !isDownloaded {
                showDownloadSheet = true
            }
        } label: {
            MonologueIcon(
                icon: .playerDownload,
                size: 21,
                color: isDownloaded ? NeumorphicStyle.inkMuted.opacity(0.58) : NeumorphicStyle.warm,
                lineWidth: 1.45
            )
            .frame(width: 42, height: 42)
            .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: !isDownloaded, pressed: isDownloaded, lightweight: true))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        .disabled(isDownloaded)
        .opacity(isDownloaded ? 0.62 : 1)
    }

    // MARK: - Capsule OS 播放器（重设计：单焦点、胶囊系统）
    // 设计语言:
    //   · 顶部单一胶囊条(返回 / 歌名 / 更多)
    //   · 大封面,纯净,无装饰色条、无旋转、无浮层按钮
    //   · 进度条平铺于封面下方,不放进额外玻璃卡
    //   · 5 枚等距小胶囊控件(质量/收藏/歌词/评论/下载)
    //   · 底部单一 Control Capsule(循环 / 上一首 / 大播放键 / 下一首 / 队列)
    private func capsulePlayerContent(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18

        return VStack(spacing: 0) {
            capsulePlayerTopBar
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 14)

            Group {
                if showLyrics {
                    capsuleLyricsStage(geometry: geometry)
                } else {
                    capsulePlaybackStage(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.44, dampingFraction: 0.88), value: showLyrics)

            capsuleControlDeck
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
        .themeRenderSceneLayer()
    }

    // MARK: - 顶部胶囊(单一条)

    private var capsulePlayerTopBar: some View {
        HStack(spacing: 8) {
            capsuleTopButton(icon: .chevronLeft) {
                dismiss()
            }

            HStack(spacing: 8) {
                MonologueIcon(
                    icon: player.isPlaying ? .musicNote : .play,
                    size: 13,
                    color: CapsuleStyle.accent,
                    lineWidth: 1.7
                )

                MarqueeText(
                    text: capsuleTopBarText,
                    font: CapsuleStyle.labelFont(12, weight: .semibold),
                    color: CapsuleStyle.ink,
                    speed: 28,
                    delayBeforeScroll: 1.8,
                    alignment: .center
                )
                .frame(height: 22)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(CapsuleStyle.surface.opacity(0.74))
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(
                Capsule().stroke(CapsuleStyle.hairline.opacity(0.68), lineWidth: 1)
            )

            capsuleTopButton(icon: .more) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            }
        }
    }

    private var capsuleTopBarText: String {
        guard let song = player.currentSong else {
            return String(localized: "未在播放")
        }
        let artist = song.artistName.isEmpty ? "" : " · \(song.artistName)"
        return "\(song.name)\(artist)"
    }

    private func capsuleTopButton(icon: MonologueIcon.IconType, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 18, color: CapsuleStyle.ink, lineWidth: 1.75)
                .frame(width: 44, height: 44)
                .background(
                    Capsule()
                        .fill(CapsuleStyle.surface.opacity(0.74))
                        .background(.ultraThinMaterial, in: Capsule())
                )
                .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.68), lineWidth: 1))
        }
        .buttonStyle(CapsulePressStyle())
    }

    // MARK: - 播放阶段(封面 + 歌曲信息 + 快捷操作)

    private func capsulePlaybackStage(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18
        let availableWidth = geometry.size.width - horizontalPadding * 2
        // 单焦点:封面占据主要视觉重量
        let artSize = min(DeviceLayout.isPad ? 340 : 300, max(220, availableWidth * 0.78))

        return VStack(spacing: 22) {
            capsuleCleanArtwork(size: artSize)
                .onTapWithHaptic {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                        showLyrics.toggle()
                    }
                }

            VStack(spacing: 6) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .monologuePlayerDisplayFont(
                        size: 24,
                        weight: .bold,
                        fallback: CapsuleStyle.titleFont(24, weight: .bold)
                    )
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(CapsuleStyle.bodyFont(14, weight: .semibold))
                        .foregroundStyle(CapsuleStyle.inkSoft)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                // 音质元数据
                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CapsuleStyle.inkMuted.opacity(0.72))
                        .lineLimit(1)
                }
            }

            capsuleQuickActionRow
                .padding(.top, 2)
        }
        .padding(.horizontal, horizontalPadding)
    }

    @ViewBuilder
    private func capsuleCleanArtwork(size: CGFloat) -> some View {
        let cornerRadius: CGFloat = 32

        ZStack {
            if let song = player.currentSong {
                ZStack {
                    CachedAsyncImage(url: song.coverUrl?.sized(800)) {
                        CapsuleStyle.surfaceTint
                    }
                    .aspectRatio(contentMode: .fill)

                    if let dynamicUrl = player.dynamicCoverUrl, !dynamicUrl.isEmpty {
                        DynamicCoverView(urlString: dynamicUrl, cornerRadius: cornerRadius)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CapsuleStyle.surfaceTint)
                    .overlay(
                        MonologueIcon(icon: .musicNoteList, size: 58, color: CapsuleStyle.inkMuted.opacity(0.45), lineWidth: 1.5)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CapsuleStyle.hairline.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 34, x: 0, y: 20)
        .shadow(color: CapsuleStyle.accent.opacity(0.08), radius: 20, x: 0, y: 12)
        .scaleEffect(player.isPlaying ? 1 : 0.97)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: player.isPlaying)
    }

    // MARK: - 快捷操作栏(5 枚等距小胶囊)

    private var capsuleQuickActionRow: some View {
        HStack(spacing: 10) {
            capsuleQualityChip
            capsuleLikeControl
            capsuleLyricsToggle
            capsuleCommentQuick
            if AppConfig.Features.downloadEnabled {
                // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                capsuleDownloadQuick
            } else {
                // 沉浸模式按钮 — 占用原下载按钮的位置
                capsuleImmersiveQuick
            }
        }
    }

    private var capsuleImmersiveQuick: some View {
        Button {
            CinemaModeController.shared.present()
        } label: {
            MonologueIcon(icon: .immersive, size: 16, color: CapsuleStyle.mint, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        }
        .buttonStyle(CapsulePressStyle())
        .disabled(player.currentSong == nil)
        .opacity(player.currentSong == nil ? 0.4 : 1)
    }

    private var capsuleQualityChip: some View {
        Button(action: { showQualitySheet = true }) {
            HStack(spacing: 6) {
                MonologueIcon(icon: .soundQuality, size: 13, color: CapsuleStyle.accent, lineWidth: 1.7)
                Text(player.qualityButtonText)
                    .font(CapsuleStyle.labelFont(11, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
            .overlay(Capsule().stroke(CapsuleStyle.accent.opacity(0.22), lineWidth: 0.9))
        }
        .buttonStyle(CapsulePressStyle())
        .playerQualitySelectionAvailability()
    }

    @ViewBuilder
    private var capsuleLikeControl: some View {
        if let song = player.currentSong {
            LikeButton(
                songId: song.id,
                isQQMusic: song.isQQMusic,
                song: song,
                size: 18,
                activeColor: CapsuleStyle.coral,
                inactiveColor: CapsuleStyle.inkSoft
            )
            .frame(width: 36, height: 36)
            .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        } else {
            MonologueIcon(icon: .like, size: 17, color: CapsuleStyle.inkSoft, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        }
    }

    private var capsuleLyricsToggle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                showLyrics.toggle()
            }
        }) {
            MonologueIcon(
                icon: .karaoke,
                size: 15,
                color: showLyrics ? CapsuleStyle.onAccent : CapsuleStyle.accent,
                lineWidth: 1.6
            )
            .frame(width: 36, height: 36)
            .background(
                capsulePillBackground(
                    tint: showLyrics ? CapsuleStyle.accent : CapsuleStyle.surfaceRaised.opacity(0.78)
                )
            )
        }
        .buttonStyle(CapsulePressStyle())
    }

    @ViewBuilder
    private var capsuleCommentQuick: some View {
        Button { showComments = true } label: {
            MonologueIcon(icon: .comment, size: 16, color: CapsuleStyle.violet, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        }
        .buttonStyle(CapsulePressStyle())
        .disabled(player.currentSong == nil)
        .opacity(player.currentSong == nil ? 0.4 : 1)
    }

    @ViewBuilder
    private var capsuleDownloadQuick: some View {
        if let song = player.currentSong {
            let isDownloaded = downloadManager.isDownloaded(songId: song.id)

            Button {
                if !isDownloaded {
                    showDownloadSheet = true
                }
            } label: {
                MonologueIcon(
                    icon: .playerDownload,
                    size: 16,
                    color: isDownloaded ? CapsuleStyle.inkMuted.opacity(0.6) : CapsuleStyle.mint,
                    lineWidth: 1.6
                )
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(isDownloaded ? 0.46 : 0.78)))
            }
            .buttonStyle(CapsulePressStyle())
            .disabled(isDownloaded)
            .opacity(isDownloaded ? 0.62 : 1)
        } else {
            MonologueIcon(icon: .playerDownload, size: 16, color: CapsuleStyle.inkSoft, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.5)))
                .opacity(0.4)
        }
    }

    // MARK: - 歌词阶段

    private func capsuleLyricsStage(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18
        let maxWidth = min(geometry.size.width - horizontalPadding * 2, DeviceLayout.isPad ? 660 : 480)

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                capsuleLyricsToggle

                Spacer(minLength: 0)

                if let song = player.currentSong {
                    LikeButton(
                        songId: song.id,
                        isQQMusic: song.isQQMusic,
                        song: song,
                        size: 20,
                        activeColor: CapsuleStyle.coral,
                        inactiveColor: CapsuleStyle.inkSoft
                    )
                    .frame(width: 36, height: 36)
                    .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
                }
            }

            if let song = player.currentSong {
                LyricsView(song: song, onBackgroundTap: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showLyrics.toggle()
                    }
                })
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(capsuleGlassPanel(cornerRadius: 30, tint: CapsuleStyle.surface.opacity(0.76)))
            } else {
                Color.clear
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 底部控件舱(单一 Capsule Deck)

    private var capsuleControlDeck: some View {
        VStack(spacing: 14) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, 6)
            }

            // 进度条(平铺,无玻璃外壳)
            capsuleProgressStrip

            // 主控胶囊:循环 / 上一 / 大播放 / 下一 / 队列
            capsuleTransportBar
        }
    }

    private var capsuleProgressStrip: some View {
        VStack(spacing: 6) {
            FullScreenPlayerView.WaveformProgressBar(
                currentTime: Binding(
                    get: { isDraggingSlider ? dragTimeValue : timePublisher.currentTime },
                    set: { _ in }
                ),
                duration: timePublisher.duration,
                color: CapsuleStyle.accent,
                trackOpacity: 0.14,
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
            .frame(height: 26)

            HStack {
                capsuleTimeChip(formatTime(isDraggingSlider ? dragTimeValue : timePublisher.currentTime), alignment: .leading)
                Spacer(minLength: 12)
                capsuleTimeChip(formatTime(timePublisher.duration), alignment: .trailing)
            }
            .padding(.horizontal, 4)
        }
    }

    private func capsuleTimeChip(_ text: String, alignment: Alignment = .center) -> some View {
        Text(text)
            .font(CapsuleStyle.labelFont(11, weight: .semibold))
            .foregroundStyle(CapsuleStyle.inkMuted)
            .monospacedDigit()
            .lineLimit(1)
            .frame(minWidth: 44, alignment: alignment)
    }

    private var capsuleTransportBar: some View {
        HStack(spacing: 10) {
            capsuleTransportSideButton(icon: player.mode.monologueIcon, tint: CapsuleStyle.inkSoft) {
                player.switchMode()
            }

            capsuleTransportSideButton(icon: .previous, tint: CapsuleStyle.ink, iconSize: 20) {
                player.previous()
            }

            capsuleMainPlayButton

            capsuleTransportSideButton(icon: .next, tint: CapsuleStyle.ink, iconSize: 20) {
                player.next()
            }

            capsuleTransportSideButton(icon: .list, tint: CapsuleStyle.inkSoft) {
                showPlaylist = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(CapsuleStyle.surface.opacity(0.82))
                .background(.ultraThinMaterial, in: Capsule())
        )
        .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.64), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 12)
        .shadow(color: CapsuleStyle.accent.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    private func capsuleTransportSideButton(
        icon: MonologueIcon.IconType,
        tint: Color,
        iconSize: CGFloat = 18,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: iconSize, color: tint, lineWidth: 1.65)
                .frame(width: 44, height: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(CapsulePressStyle())
    }

    private var capsuleMainPlayButton: some View {
        Button(action: { player.togglePlayPause() }) {
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.accent,
                                CapsuleStyle.accent.opacity(0.88),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 72, height: 52)
                    .overlay(Capsule().stroke(Color.white.opacity(0.38), lineWidth: 1))
                    .shadow(color: CapsuleStyle.accent.opacity(0.32), radius: 12, x: 0, y: 7)

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CapsuleStyle.onAccent))
                        .scaleEffect(1.05)
                } else {
                    MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 28, color: CapsuleStyle.onAccent, lineWidth: 1.8)
                }
            }
        }
        .buttonStyle(CapsulePressStyle())
        .scaleEffect(player.isPlaying ? 1 : 0.97)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: player.isPlaying)
    }

    // MARK: - 通用面板/胶囊背景

    private func capsuleGlassPanel(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CapsuleStyle.hairline.opacity(0.68), lineWidth: 1)
            )
            .shadow(color: CapsuleStyle.accent.opacity(0.06), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 7)
    }

    private func capsulePillBackground(tint: Color) -> some View {
        Capsule()
            .fill(tint)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.6), lineWidth: 0.8))
    }

    private func clayPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 12)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    clayListeningPod(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.48, dampingFraction: 0.86), value: showLyrics)

            clayTransportTray
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    private func clayListeningPod(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.isPad ? 286 : 224, max(174, geometry.size.width - 142))

        return VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(Color.clear)
                    .background(ClaySurfaceBackground(cornerRadius: 42, tint: ClayStyle.sky.opacity(0.12), elevated: true))
                    .frame(width: artSize + 54, height: artSize + 62)
                    .rotationEffect(.degrees(-1.5))

                artworkTile(size: artSize)
                    .frame(width: artSize, height: artSize)
                    .rotationEffect(.degrees(1.2))
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                            showLyrics.toggle()
                        }
                    }

                VStack {
                    HStack {
                        qualityButton
                        Spacer()
                        if let song = player.currentSong {
                            LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 23, activeColor: ClayStyle.berry, inactiveColor: ClayStyle.inkSoft)
                                .frame(width: 42, height: 42)
                                .background(ClaySurfaceBackground(cornerRadius: 17, tint: ClayStyle.cream, elevated: true, compact: true))
                        }
                    }
                    Spacer()
                }
                .padding(18)
                .frame(width: artSize + 54, height: artSize + 62)
            }

            clayTrackCapsule
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 24)
        }
        .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18)
    }

    private var clayTrackCapsule: some View {
        HStack(alignment: .center, spacing: 14) {
            ClayIconBubble(icon: player.isPlaying ? .pause : .play, tint: ClayStyle.accent, size: 46)

            VStack(alignment: .leading, spacing: 6) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .monologuePlayerDisplayFont(
                        size: 23,
                        weight: .bold,
                        fallback: ClayStyle.titleFont(23, weight: .bold)
                    )
                    .foregroundStyle(ClayStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(ClayStyle.bodyFont(14, weight: .medium))
                        .foregroundStyle(ClayStyle.inkSoft)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .karaoke, size: 17, color: ClayStyle.inkMuted, lineWidth: 1.55)
                .frame(width: 36, height: 36)
                .background(ClaySurfaceBackground(cornerRadius: 15, tint: ClayStyle.creamPressed, elevated: false, pressed: true, compact: true))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(ClaySurfaceBackground(cornerRadius: 24, tint: ClayStyle.cream.opacity(0.96), elevated: true))
    }

    private var clayTransportTray: some View {
        VStack(spacing: 15) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection
                .padding(.top, 2)

            HStack(spacing: 8) {
                Circle().fill(ClayStyle.butter).frame(width: 8, height: 8)
                Circle().fill(ClayStyle.mint).frame(width: 8, height: 8)
                Capsule().fill(ClayStyle.berry.opacity(0.8)).frame(width: 20, height: 8)
            }

            controlsView
        }
        .padding(.horizontal, 8)
        .padding(.top, 15)
        .padding(.bottom, 17)
        .background(ClaySurfaceBackground(cornerRadius: 28, tint: ClayStyle.cream.opacity(0.96), elevated: true))
    }

    private var qualityButton: some View {
        Button(action: { showQualitySheet = true }) {
            Text(player.qualityButtonText)
                .font(.system(size: 10, weight: isThemedClassic ? .bold : .heavy, design: isThemedClassic ? .default : .rounded))
                .tracking(isThemedClassic ? 0 : 0.5)
                .foregroundColor(qualityBadgeForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(qualityBadgeBackground)
                .overlay(
                    // aside 编辑部风格：极细描边胶囊
                    RoundedRectangle(cornerRadius: isThemedClassic ? 5 : 20)
                        .stroke(qualityBadgeStroke, lineWidth: MangaStyle.isActive ? 1.4 : 0.8)
                )
        }
        .buttonStyle(.plain)
        .playerQualitySelectionAvailability()
    }

    @ViewBuilder
    private var classicThemeBackdrop: some View {
        if MinimalWhiteStyle.isActive {
            MinimalWhiteRootBackdrop()
                .ignoresSafeArea()
        } else if MangaStyle.isActive {
            ZStack {
                MangaRootBackdrop()
                MangaDotsTexture(opacity: colorScheme == .dark ? 0.03 : 0.045, gap: 15)
            }
            .ignoresSafeArea()
        } else if MujiStyle.isActive {
            MujiRootBackdrop()
                .ignoresSafeArea()
        } else if NeumorphicStyle.isActive {
            ThemeRenderBackdrop(theme: .neumorphic)
                .ignoresSafeArea()
        } else if CapsuleStyle.isActive {
            ThemeRenderBackdrop(theme: .capsule)
                .ignoresSafeArea()
        } else if SequoiaStyle.isActive {
            ThemeRenderBackdrop(theme: .sequoia)
                .ignoresSafeArea()
        } else if ClayStyle.isActive {
            ClayRootBackdrop()
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
                    } else if CapsuleStyle.isActive {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(CapsuleStyle.surfaceRaised)
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(CapsuleStyle.hairline.opacity(0.7), lineWidth: 0.8)
                            )
                            .shadow(color: CapsuleStyle.accent.opacity(0.08), radius: 10, x: 0, y: 5)
                    } else if MinimalWhiteStyle.isActive {
                        MinimalWhiteCircleBackground(elevated: true)
                            .frame(width: 44, height: 44)
                    } else if SequoiaStyle.isActive {
                        Circle()
                            .fill(SequoiaStyle.materialRaised.opacity(0.82))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(SequoiaStyle.separator.opacity(0.72), lineWidth: 0.55))
                    } else if ClayStyle.isActive {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                            .background(ClaySurfaceBackground(cornerRadius: 22, tint: ClayStyle.cream, elevated: true, compact: true))
                    } else if MujiStyle.isActive {
                        Circle()
                            .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.1))
                            .frame(width: 44, height: 44)
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
                            MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialPressed : (ClayStyle.isActive ? ClayStyle.creamPressed : Color.gray.opacity(0.2)))))))
                        }
                        .aspectRatio(contentMode: .fill)

                        if let dynamicUrl = player.dynamicCoverUrl, !dynamicUrl.isEmpty {
                            DynamicCoverView(urlString: dynamicUrl, cornerRadius: cornerRadius)
                        }

                        AIEqualizerArtworkStatusView(
                            accent: asideCoverAccent,
                            isDarkArtwork: asideCoverColors.isDark
                        )
                            .padding(max(10, min(15, size * 0.038)))
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .bottomTrailing
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialPressed : (ClayStyle.isActive ? ClayStyle.creamPressed : Color.gray.opacity(0.1))))))))
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
        if MinimalWhiteStyle.isActive {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )
                .shadow(color: MinimalWhiteStyle.ink.opacity(0.045), radius: 10, x: 0, y: 4)
        } else if MangaStyle.isActive {
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
            // Muji 手帖：杏色水洗底纸错位衬托 + 极柔投影，像贴在手帖上的照片
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .fill(MujiStyle.wash(MujiStyle.tea, strength: 1.35))
                        .offset(x: 12, y: 14)
                )
                .shadow(color: MujiStyle.ink.opacity(0.1), radius: 22, x: 0, y: 10)
        } else if NeumorphicStyle.isActive {
            content
                .padding(10)
                .background(NeumorphicSurfaceBackground(cornerRadius: cornerRadius + 12, elevated: true, tint: NeumorphicStyle.surfaceRaised))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 12, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
                )
        } else if CapsuleStyle.isActive {
            content
                .padding(9)
                .background(CapsuleSurfaceBackground(cornerRadius: cornerRadius + 12, elevated: true, tint: CapsuleStyle.surfaceRaised))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 12, style: .continuous)
                        .stroke(CapsuleStyle.accent.opacity(0.16), lineWidth: 0.9)
                )
        } else if SequoiaStyle.isActive {
            content
                .padding(9)
                .background(SequoiaSurfaceBackground(cornerRadius: cornerRadius + 11, elevated: true, role: .chrome))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 11, style: .continuous)
                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.52), lineWidth: 0.65)
                )
        } else if ClayStyle.isActive {
            content
                .padding(10)
                .background(ClaySurfaceBackground(cornerRadius: cornerRadius + 14, tint: ClayStyle.creamRaised, elevated: true))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 14, style: .continuous)
                        .stroke(ClayStyle.separator.opacity(0.34), lineWidth: 0.8)
                )
        } else if isThemedClassic {
            content
                .monologueBackgroundExtension()
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        } else {
            content
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.16),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(contentColor.opacity(0.1), lineWidth: 0.7)
                )
        }
    }

    private var songInfoView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .monologuePlayerDisplayFont(
                        size: 26,
                        weight: .bold,
                        fallback: classicTitleFont(26, weight: .bold)
                    )
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
                    .font(.system(size: 10, weight: isThemedClassic ? .bold : .heavy, design: isThemedClassic ? .default : .rounded))
                    .tracking(isThemedClassic ? 0 : 0.5)
                    .foregroundColor(qualityBadgeForeground)
                    .padding(.horizontal, isThemedClassic ? 6 : 7)
                    .padding(.vertical, 3)
                    .background(qualityBadgeBackground)
                    .overlay(
                        // aside 编辑部风格：极细描边胶囊
                        RoundedRectangle(cornerRadius: isThemedClassic ? 4 : 20)
                            .stroke(qualityBadgeStroke, lineWidth: MangaStyle.isActive ? 1.4 : 0.8)
                    )
            }
            .playerQualitySelectionAvailability()

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
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 2, elevated: true, tint: MangaStyle.bubbleWhite)
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(cornerRadius: 20, elevated: true, tint: CapsuleStyle.surfaceRaised)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, role: .chrome)
        } else if ClayStyle.isActive {
            ClaySurfaceBackground(cornerRadius: 18, tint: ClayStyle.cream.opacity(0.94), elevated: true, compact: true)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var qualityBadgeBackground: some View {
        if MinimalWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(MinimalWhiteStyle.controlGlassFill)
        } else if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(MangaStyle.labelYellow)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.2))
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(NeumorphicStyle.surfaceRaised)
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CapsuleStyle.surfaceRaised)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(SequoiaStyle.selectedWash.opacity(0.86))
        } else if ClayStyle.isActive {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ClayStyle.butter.opacity(0.28))
        } else {
            Color.clear
        }
    }

    private var qualityBadgeStroke: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.hairline }
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return Color.clear }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator }
        if CapsuleStyle.isActive { return CapsuleStyle.accent.opacity(0.2) }
        if SequoiaStyle.isActive { return SequoiaStyle.accent.opacity(0.24) }
        if ClayStyle.isActive { return ClayStyle.accent.opacity(0.28) }
        return contentColor.opacity(0.34)
    }

    private var qualityBadgeForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.clay }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if ClayStyle.isActive { return ClayStyle.accent }
        return contentColor
    }

    private var lyricsModeSongInfo: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.name ?? "")
                    .monologuePlayerDisplayFont(
                        size: 20,
                        weight: .bold,
                        fallback: classicTitleFont(20, weight: .bold)
                    )
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

            if let song = player.currentSong {
                HStack(spacing: 2) {
                    lyricAlignmentQuickButton

                    LikeButton(
                        songId: song.id,
                        isQQMusic: song.isQQMusic,
                        song: song,
                        size: 22,
                        activeColor: .red,
                        inactiveColor: contentColor
                    )
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, isThemedClassic ? 8 : 0)
    }

    private var lyricAlignmentQuickButton: some View {
        Button {
            if lyricAlignment.phase.isWorking {
                lyricAlignment.cancel()
            } else {
                lyricAlignment.alignCurrentSong()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(contentColor.opacity(0.05))

                if lyricAlignment.phase.isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(contentColor)
                        .scaleEffect(0.78)
                } else {
                    MonologueIcon(
                        icon: .sparkle,
                        size: 18,
                        color: contentColor.opacity(lyricAlignment.canStartAlignment ? 1 : 0.52)
                    )
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(MonologueBouncingButtonStyle())
        .disabled(!lyricAlignment.canStartAlignment && !lyricAlignment.phase.isWorking)
        .accessibilityLabel(String(localized: "ai_lyric_align"))
        .accessibilityValue(lyricAlignment.statusText ?? "")
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
            .frame(height: 28)

            HStack {
                Text(formatTime(isDraggingSlider ? dragTimeValue : timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(classicBodyFont(11, weight: .medium))
            .foregroundColor(secondaryContentColor.opacity(0.6))
            .monospacedDigit()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    @ViewBuilder
    private var classicPlayButtonBackground: some View {
        let size = DeviceLayout.playerPlayButtonSize

        if MinimalWhiteStyle.isActive {
            Circle()
                .fill(MinimalWhiteStyle.accent)
                .frame(width: size, height: size)
        } else if MangaStyle.isActive {
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
                .fill(MujiStyle.clay)
                .frame(width: size, height: size)
                .shadow(color: MujiStyle.clay.opacity(0.32), radius: 16, x: 0, y: 8)
        } else if NeumorphicStyle.isActive {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .background(NeumorphicSurfaceBackground(cornerRadius: size / 2, elevated: true))
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .fill(CapsuleStyle.accent)
                .frame(width: size, height: size)
                .shadow(color: CapsuleStyle.accent.opacity(0.24), radius: 12, x: 0, y: 7)
        } else if SequoiaStyle.isActive {
            Circle()
                .fill(SequoiaStyle.accent)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)
                )
                .shadow(color: SequoiaStyle.accent.opacity(0.22), radius: 12, x: 0, y: 6)
        } else if ClayStyle.isActive {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .background(ClaySurfaceBackground(cornerRadius: size / 2, tint: ClayStyle.cream, elevated: true))
                .overlay(Circle().fill(ClayStyle.accent.opacity(0.12)).padding(8))
        } else {
            Circle()
                .fill(Color.monologueGlassTint)
                .frame(width: size, height: size)
                .monologueGlassCircle()
        }
    }

    private var classicPlayIconColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if ClayStyle.isActive { return ClayStyle.accent }
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

                    if AppConfig.Features.downloadEnabled {
                        // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
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
                    } else {
                        // 沉浸模式按钮 — 占用原下载按钮的位置
                        Button {
                            CinemaModeController.shared.present()
                        } label: {
                            MonologueIcon(icon: .immersive, size: 22, color: secondaryContentColor, lineWidth: 1.4)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .frame(width: 44)
                    }
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
