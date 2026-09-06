import SwiftUI
import FFmpegSwiftSDK

/// 纯液态玻璃播放器。
///
/// 主题不依赖全局外观的卡片与控制组件：背景、封面透镜、信息面板、
/// 进度轨道和播放按钮均由本布局自己的玻璃材质完成。iOS 26 使用原生
/// Liquid Glass，旧系统使用 Material 与高光边缘保持相同的视觉层级。
struct LiquidGlassPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var player = PlayerManager.shared
    private let timePublisher = PlaybackTimePublisher.shared
    @StateObject private var coverColors = CoverColorExtractor(minimumColorCount: 5)

    @State private var isDragging = false
    @State private var dragTime = 0.0
    @State private var showLyrics = false
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var showArtistDetail = false
    @State private var ambientMotion = false

    private var primary: Color { .white.opacity(0.96) }
    private var secondary: Color { .white.opacity(0.66) }
    private var accent: Color { coverColors.dominantColor }
    private var accentSecondary: Color { coverColors.secondaryColor }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                liquidBackdrop(in: geometry.size)

                if geometry.size.width >= 700 && geometry.size.width > geometry.size.height {
                    wideContent(in: geometry)
                } else {
                    portraitContent(in: geometry)
                }
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        anchorFrame: anchorFrame,
                        isDarkBackground: true,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .compatFontDesign(nil)
        .onAppear {
            refreshPalette()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                ambientMotion = true
            }
        }
        .onChange(of: player.currentSong?.coverUrl?.absoluteString) { _, _ in
            refreshPalette()
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            PlaylistPopupView()
        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard) {
            qualitySheet
        }
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
        .monoSheet(isPresented: $showComments, preset: .large) {
            if let song = player.currentSong {
                CommentView(song: song)
            }
        }
        .monoSheet(isPresented: $showArtistDetail, preset: .detail) {
            artistDetail
        }
    }
}

// MARK: - Layout

private extension LiquidGlassPlayerLayout {
    func portraitContent(in geometry: GeometryProxy) -> some View {
        let compact = geometry.size.height < 740
        let horizontalPadding: CGFloat = compact ? 16 : 20
        let availableWidth = geometry.size.width - horizontalPadding * 2
        let artworkHeightLimit = geometry.size.height * (compact ? 0.34 : 0.39)
        let artworkSize = min(DeviceLayout.usesExpandedLayout ? 430 : 370, availableWidth, artworkHeightLimit)

        return VStack(spacing: 0) {
            header
                .padding(.top, DeviceLayout.playerHeaderTopPadding)

            Spacer(minLength: compact ? 8 : 16)

            playbackStage(size: artworkSize)

            Spacer(minLength: compact ? 10 : 18)

            glassConsole(compact: compact)
                .frame(maxWidth: 580)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, max(DeviceLayout.safeAreaBottom + 8, compact ? 12 : 18))
        }
    }

    func wideContent(in geometry: GeometryProxy) -> some View {
        let artworkSize = min(
            geometry.size.height - DeviceLayout.playerHeaderTopPadding - 92,
            geometry.size.width * 0.38,
            500
        )

        return VStack(spacing: 0) {
            header
                .padding(.top, DeviceLayout.playerHeaderTopPadding)

            HStack(spacing: 42) {
                playbackStage(size: artworkSize)

                glassConsole(compact: false)
                    .frame(maxWidth: 460)
            }
            .frame(maxWidth: 1080, maxHeight: .infinity)
            .padding(.horizontal, 42)
            .padding(.bottom, max(DeviceLayout.safeAreaBottom + 8, 18))
        }
    }

    var header: some View {
        HStack(spacing: 12) {
            glassIconButton(
                icon: .chevronRight,
                size: 19,
                accessibilityLabel: String(localized: "返回"),
                rotation: 90
            ) {
                dismiss()
            }

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(primary)

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 210)

            Spacer(minLength: 0)

            glassIconButton(
                icon: .more,
                size: 20,
                accessibilityLabel: String(localized: "player_more_title")
            ) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    showMoreMenu.toggle()
                }
            }
            .playerMoreMenuAnchor()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }
}

// MARK: - Background and stage

private extension LiquidGlassPlayerLayout {
    func liquidBackdrop(in size: CGSize) -> some View {
        ZStack {
            Color(hex: "071018")

            if let coverURL = player.currentSong?.coverUrl?.sized(1400) {
                CachedAsyncImage(
                    url: coverURL,
                    width: size.width,
                    height: size.height
                ) {
                    Color(hex: "101B27")
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .scaleEffect(1.16)
                .blur(radius: 54, opaque: true)
                .saturation(1.18)
            }

            DynamicCoverPaletteLayer(colors: coverColors.palette, opacity: 0.94)
                .blendMode(.plusLighter)

            ambientLens(
                color: accent,
                width: size.width * 0.84,
                height: size.width * 0.58,
                x: ambientMotion ? size.width * 0.2 : -size.width * 0.18,
                y: ambientMotion ? -size.height * 0.2 : -size.height * 0.34
            )

            ambientLens(
                color: accentSecondary,
                width: size.width * 0.78,
                height: size.width * 0.7,
                x: ambientMotion ? -size.width * 0.28 : size.width * 0.18,
                y: ambientMotion ? size.height * 0.28 : size.height * 0.18
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [.white.opacity(0.08), .clear, .white.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: coverColors.resolvedURL)
    }

    func ambientLens(
        color: Color,
        width: CGFloat,
        height: CGFloat,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        Ellipse()
            .fill(color.opacity(0.28))
            .frame(width: width, height: height)
            .blur(radius: 62)
            .offset(x: x, y: y)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    func playbackStage(size: CGFloat) -> some View {
        if showLyrics, let song = player.currentSong {
            LyricsView(
                song: song,
                onBackgroundTap: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
                        showLyrics = false
                    }
                },
                adaptivePrimaryColor: coverColors.lyricContentColor,
                adaptiveSecondaryColor: coverColors.lyricSecondaryContentColor,
                enforcesAdaptiveContrast: true
            )
            .environment(\.colorScheme, coverColors.isLyricRegionDark ? .dark : .light)
            .frame(width: size, height: size)
            .background(
                LiquidPlayerGlassPanel(
                    cornerRadius: 34,
                    tint: accent.opacity(0.16),
                    elevated: true
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            liquidArtwork(size: size)
                .contentShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .onTapWithHaptic {
                    guard player.currentSong != nil else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
                        showLyrics = true
                    }
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 100 { dismiss() }
                        }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    func liquidArtwork(size: CGFloat) -> some View {
        ZStack {
            LiquidPlayerGlassPanel(
                cornerRadius: 38,
                tint: accent.opacity(0.13),
                elevated: true
            )

            artworkImage(size: max(1, size - 20))
                .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.68), .white.opacity(0.08), .white.opacity(0.32)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(0.28), radius: 20, y: 12)

            LiquidGlassSpecularBand(cornerRadius: 38)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if player.currentSong != nil {
                AIEqualizerArtworkStatusView(
                    accent: accent,
                    isDarkArtwork: coverColors.isDark
                )
                .padding(18)
            }
        }
    }

    @ViewBuilder
    func artworkImage(size: CGFloat) -> some View {
        if let song = player.currentSong {
            ZStack {
                CachedAsyncImage(
                    url: song.coverUrl?.sized(1200),
                    width: size,
                    height: size
                ) {
                    Color.white.opacity(0.08)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()

                if let dynamicURL = player.dynamicCoverUrl, !dynamicURL.isEmpty {
                    DynamicCoverView(urlString: dynamicURL, cornerRadius: 29)
                        .frame(width: size, height: size)
                        .clipped()
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(MonoIcon(icon: .musicNoteList, size: 64, color: secondary))
        }
    }
}

// MARK: - Glass console

private extension LiquidGlassPlayerLayout {
    func glassConsole(compact: Bool) -> some View {
        VStack(spacing: compact ? 11 : 15) {
            songIdentity
            progressSection
            transportControls(compact: compact)
        }
        .padding(.horizontal, compact ? 15 : 19)
        .padding(.top, compact ? 14 : 18)
        .padding(.bottom, compact ? 13 : 17)
        .background(
            LiquidPlayerGlassPanel(
                cornerRadius: 32,
                tint: accentSecondary.opacity(0.12),
                elevated: true
            )
        )
        .overlay(LiquidGlassSpecularBand(cornerRadius: 32).allowsHitTesting(false))
    }

    var songIdentity: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.name ?? String(localized: "暂无歌曲"))
                    .monoPlayerDisplayFont(
                        size: 22,
                        weight: .semibold,
                        fallback: .system(size: 22, weight: .semibold, design: .rounded)
                    )
                    .foregroundStyle(primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Button {
                    showArtistDetail = true
                } label: {
                    Text(player.currentSong?.artistName ?? String(localized: "search_unknown_artist"))
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .disabled(player.currentSong == nil)
            }

            Spacer(minLength: 4)

            qualityPill

            if let song = player.currentSong {
                LikeButton(
                    songId: song.id,
                    isQQMusic: song.isQQMusic,
                    song: song,
                    size: 22,
                    activeColor: Color(hex: "FF6685"),
                    inactiveColor: primary
                )
                .frame(width: 42, height: 42)
                .background(
                    LiquidPlayerGlassCircle(
                        tint: Color(hex: "FF6685").opacity(0.08),
                        interactive: true
                    )
                )
            }
        }
    }

    var qualityPill: some View {
        Button {
            showQualitySheet = true
        } label: {
            Text(player.qualityButtonText)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.3)
                .foregroundStyle(primary)
                .padding(.horizontal, 9)
                .frame(height: 31)
                .background(
                    LiquidPlayerGlassCapsule(
                        tint: accent.opacity(0.12),
                        interactive: true
                    )
                )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        .playerQualitySelectionAvailability()
    }

    var progressSection: some View {
        PlaybackTimeReader { _, _ in
            VStack(spacing: 3) {
                liquidProgressRail

                HStack {
                    Text(formatTime(isDragging ? dragTime : timePublisher.currentTime))
                    Spacer()
                    Text(formatTime(timePublisher.duration))
                }
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(secondary)
                .monospacedDigit()
            }
        }
    }

    var liquidProgressRail: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let duration = validDuration
            let displayedTime = isDragging ? dragTime : validCurrentTime
            let progress = duration > 0 ? min(max(displayedTime / duration, 0), 1) : 0
            let progressWidth = width * CGFloat(progress)
            let thumbSize: CGFloat = isDragging ? 15 : 10
            let thumbX = min(max(progressWidth - thumbSize / 2, 0), max(width - thumbSize, 0))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Color.white.opacity(0.08)))
                    .frame(height: 7)

                if progress > 0 {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentSecondary, accent, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(progressWidth, 7), height: 7)
                        .shadow(color: accent.opacity(0.36), radius: 5)
                }

                if duration > 0 {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.white.opacity(0.58)))
                        .overlay(Circle().stroke(Color.white.opacity(0.76), lineWidth: 0.7))
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: accent.opacity(0.4), radius: 5)
                        .offset(x: thumbX)
                }
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(seekGesture(width: width, duration: duration))
        }
        .frame(height: 28)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isDragging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "播放进度"))
        .accessibilityValue("\(formatTime(isDragging ? dragTime : validCurrentTime)) / \(formatTime(validDuration))")
    }

    func seekGesture(width: CGFloat, duration: Double) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard duration > 0 else { return }
                isDragging = true
                let ratio = min(max(value.location.x / width, 0), 1)
                dragTime = Double(ratio) * duration
            }
            .onEnded { value in
                guard duration > 0 else {
                    isDragging = false
                    return
                }
                let ratio = min(max(value.location.x / width, 0), 1)
                let target = Double(ratio) * duration
                dragTime = target
                isDragging = false
                player.seek(to: target)
            }
    }

    func transportControls(compact: Bool) -> some View {
        let playSize: CGFloat = compact ? 58 : 64

        return HStack(spacing: 0) {
            glassTransportButton(
                icon: player.mode.monoIcon,
                iconSize: 17,
                buttonSize: 42,
                accessibilityLabel: player.mode.displayName
            ) {
                player.switchMode()
            }

            Spacer(minLength: 0)

            glassTransportButton(
                icon: .previous,
                iconSize: 24,
                buttonSize: 48,
                accessibilityLabel: String(localized: "上一首")
            ) {
                player.previous()
            }

            Spacer(minLength: 0)

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    LiquidPlayerGlassCircle(tint: accent.opacity(0.28), interactive: true)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.28), accent.opacity(0.2), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: playSize * 0.72
                            )
                        )

                    if player.isLoading {
                        ProgressView().tint(primary)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 26,
                            color: primary,
                            lineWidth: 2
                        )
                        .offset(x: player.isPlaying ? 0 : 1.5)
                    }
                }
                .frame(width: playSize, height: playSize)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
            .accessibilityLabel(player.isPlaying ? String(localized: "暂停") : String(localized: "action_play"))

            Spacer(minLength: 0)

            glassTransportButton(
                icon: .next,
                iconSize: 24,
                buttonSize: 48,
                accessibilityLabel: String(localized: "playback_next_track")
            ) {
                player.next()
            }

            Spacer(minLength: 0)

            glassTransportButton(
                icon: .list,
                iconSize: 18,
                buttonSize: 42,
                accessibilityLabel: String(localized: "player_queue")
            ) {
                showPlaylist = true
            }
        }
    }

    func glassTransportButton(
        icon: MonoIcon.IconType,
        iconSize: CGFloat,
        buttonSize: CGFloat,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                LiquidPlayerGlassCircle(tint: accent.opacity(0.08), interactive: true)
                MonoIcon(icon: icon, size: iconSize, color: primary, lineWidth: 1.8)
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        .accessibilityLabel(accessibilityLabel)
    }

    func glassIconButton(
        icon: MonoIcon.IconType,
        size: CGFloat,
        accessibilityLabel: String,
        rotation: Double = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                LiquidPlayerGlassCircle(tint: accent.opacity(0.08), interactive: true)
                MonoIcon(icon: icon, size: size, color: primary, lineWidth: 1.8)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Data and destinations

private extension LiquidGlassPlayerLayout {
    var validDuration: Double {
        let value = timePublisher.duration
        return value.isFinite && value > 0 ? value : 0
    }

    var validCurrentTime: Double {
        let value = timePublisher.currentTime
        return value.isFinite ? max(0, value) : 0
    }

    func refreshPalette() {
        coverColors.extract(from: player.currentSong?.coverUrl?.sized(320).absoluteString)
    }

    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sampleRate = info.sampleRate {
            if sampleRate >= 1_000 {
                let kHz = Double(sampleRate) / 1_000
                parts.append(kHz == kHz.rounded() ? "\(Int(kHz))kHz" : String(format: "%.1fkHz", kHz))
            } else {
                parts.append("\(sampleRate)Hz")
            }
        }
        if let bitDepth = info.bitDepth, bitDepth > 0 { parts.append("\(bitDepth)bit") }
        if let channels = info.channelCount, channels > 2 { parts.append("\(channels)ch") }
        return parts.joined(separator: " / ")
    }

    var qualitySheet: some View {
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
            onSelectQishui: { info in
                player.switchQishuiQuality(info)
                showQualitySheet = false
            }
        )
    }

    @ViewBuilder
    var artistDetail: some View {
        if let song = player.currentSong {
            NavigationStack {
                if song.isQQMusic, let mid = song.qqArtistMid {
                    QQMusicDetailView(
                        detailType: .artist(mid: mid, name: song.artistName, coverUrl: nil)
                    )
                } else if let artistID = song.ar?.first?.id {
                    ArtistDetailView(artistId: artistID)
                }
            }
        }
    }
}

// MARK: - Theme-owned glass materials

private struct LiquidPlayerGlassPanel: View {
    let cornerRadius: CGFloat
    let tint: Color
    var elevated = false

    var body: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.018))
                .glassEffect(
                    .regular.tint(tint),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .shadow(color: .black.opacity(elevated ? 0.24 : 0.12), radius: elevated ? 24 : 12, y: elevated ? 12 : 6)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.24))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.56), .white.opacity(0.08), .white.opacity(0.24)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: .black.opacity(elevated ? 0.24 : 0.12), radius: elevated ? 24 : 12, y: elevated ? 12 : 6)
        }
    }
}

private struct LiquidPlayerGlassCircle: View {
    let tint: Color
    var interactive = false

    var body: some View {
        if #available(iOS 26, *) {
            Circle()
                .fill(Color.white.opacity(0.018))
                .glassEffect(.regular.tint(tint).interactive(interactive), in: .circle)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(tint.opacity(0.3)))
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.68), .white.opacity(0.1), .white.opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        }
    }
}

private struct LiquidPlayerGlassCapsule: View {
    let tint: Color
    var interactive = false

    var body: some View {
        if #available(iOS 26, *) {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.018))
                .glassEffect(.regular.tint(tint).interactive(interactive), in: .capsule)
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(tint.opacity(0.3)))
                .overlay(Capsule().stroke(Color.white.opacity(0.34), lineWidth: 0.65))
        }
    }
}

private struct LiquidGlassSpecularBand: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.7), location: 0),
                        .init(color: .white.opacity(0.12), location: 0.3),
                        .init(color: .clear, location: 0.56),
                        .init(color: .white.opacity(0.22), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 74, height: 2)
                    .blur(radius: 1.5)
                    .padding(.top, 11)
                    .padding(.leading, 22)
            }
    }
}
