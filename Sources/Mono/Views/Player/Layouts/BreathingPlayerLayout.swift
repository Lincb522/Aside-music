import SwiftUI
import FFmpegSwiftSDK

/// 呼吸体播放器 — 没有传统控制排布，交互收束为一个会呼吸的声音核心。
/// 轻触切换播放，横向拖拽切歌，纵向拖拽摸时间，长按渗出歌词。
struct BreathingPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var player = PlayerManager.shared
    private let timePublisher = PlaybackTimePublisher.shared

    @StateObject private var colorExtractor = CoverColorExtractor()
    @State private var showQualitySheet = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var showLyrics = false

    @State private var interactionAxis: InteractionAxis = .idle
    @State private var dragTranslation: CGSize = .zero
    @State private var seekAnchorTime: Double = 0
    @State private var pendingSeekTime: Double?
    @State private var crossedDragThreshold = false

    @State private var feedbackTitle: String?
    @State private var feedbackDetail: String?
    @State private var feedbackToken = UUID()
    @State private var showGestureLegend = true
    @State private var legendToken = UUID()

    private enum InteractionAxis {
        case idle
        case horizontal
        case vertical
    }

    private var ambientBase: Color {
        colorScheme == .dark ? Color(hex: "06070A") : Color(hex: "F4F5F8")
    }

    private var accentPrimary: Color {
        colorExtractor.dominantColor
    }

    private var accentSecondary: Color {
        colorExtractor.secondaryColor
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0C0F16")
    }

    private var subduedTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.62) : Color(hex: "556070")
    }

    private var displayedTime: Double {
        pendingSeekTime ?? timePublisher.currentTime
    }

    private var progress: Double {
        guard timePublisher.duration > 0 else { return 0 }
        return min(max(displayedTime / timePublisher.duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let safeAreaInsets = geo.safeAreaInsets

            ZStack {
                ambientBackground
                    .ignoresSafeArea()

                if let song = player.currentSong, showLyrics {
                    LyricsView(song: song) {
                        withAnimation(MonoAnimation.smooth) {
                            showLyrics = false
                        }
                        clearFeedback(after: 0)
                    }
                    .frame(width: size.width, height: size.height, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    breathingStage(in: size, safeAreaInsets: safeAreaInsets)
                        .frame(width: size.width, height: size.height, alignment: .center)
                        .transition(.opacity)
                }

                edgeSatellites(topInset: safeAreaInsets.top)
                    .frame(width: size.width, height: size.height, alignment: .top)
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        anchorFrame: anchorFrame,
                        onQuality: { showQualitySheet = true },
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .frame(width: size.width, height: size.height, alignment: .center)
        }
        .onAppear {
            extractPalette()
            scheduleLegendDismiss()
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            pendingSeekTime = nil
            interactionAxis = .idle
            dragTranslation = .zero
            crossedDragThreshold = false
            extractPalette()
            withAnimation(MonoAnimation.contentAppear) {
                showGestureLegend = true
            }
            scheduleLegendDismiss()
        }
        .onChange(of: showLyrics) { _, isShowing in
            if !isShowing {
                scheduleLegendDismiss()
            }
        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard) {
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
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
    }
}

// MARK: - Stage
extension BreathingPlayerLayout {
    private var ambientBackground: some View {
        ZStack {
            ambientBase

            if let url = player.currentSong?.coverUrl?.sized(800) {
                CachedAsyncImage(url: url) {
                    Rectangle().fill(.clear)
                }
                .aspectRatio(contentMode: .fill)
                .blur(radius: 90)
                .scaleEffect(1.45)
                .opacity(colorScheme == .dark ? 0.38 : 0.24)
            }

            RadialGradient(
                colors: [
                    accentPrimary.opacity(colorScheme == .dark ? 0.30 : 0.20),
                    accentSecondary.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    .clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 340
            )
            .blendMode(.plusLighter)

            LinearGradient(
                colors: [
                    ambientBase.opacity(colorScheme == .dark ? 0.15 : 0.04),
                    Color.black.opacity(colorScheme == .dark ? 0.45 : 0.08),
                    ambientBase.opacity(colorScheme == .dark ? 0.25 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func breathingStage(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let metrics = metrics(for: size, safeAreaInsets: safeAreaInsets)

        ZStack {
            stageContent(in: size, metrics: metrics)
            feedbackCloud(offsetY: metrics.feedbackOffsetY)
        }
        .animation(MonoAnimation.smooth, value: showGestureLegend)
        .animation(MonoAnimation.smooth, value: feedbackTitle)
    }

    private func stageContent(in size: CGSize, metrics: BreathingLayoutMetrics) -> some View {
        let stageWidth = max(size.width - metrics.horizontalPadding * 2, 0)
        let stageHeight = max(size.height - metrics.stageTopPadding - metrics.stageBottomPadding, 0)
        let topInset = metrics.isLandscape
            ? metrics.topSpacer
            : portraitClusterTopInset(stageHeight: stageHeight, metrics: metrics)

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: topInset)

            songCluster(in: size, metrics: metrics)

            Spacer(minLength: metrics.bottomSpacer)
        }
        .frame(width: stageWidth, height: stageHeight, alignment: .center)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.stageTopPadding)
        .padding(.bottom, metrics.stageBottomPadding)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private func portraitClusterTopInset(stageHeight: CGFloat, metrics: BreathingLayoutMetrics) -> CGFloat {
        let metadataHeight = max(metrics.artistCapsuleHeight, 36)
        let titleHeight = metrics.titleFont * 2.15
        let timeHeight = max(metrics.primaryTimeFont + 24, 44)
        let clusterHeight =
            metadataHeight +
            metrics.coreFootprintHeight +
            titleHeight +
            timeHeight +
            (metrics.contentSpacing * 3)
        let freeHeight = max(stageHeight - clusterHeight, 0)
        let biasedInset = freeHeight * 0.72
        return max(metrics.topSpacer, min(biasedInset, freeHeight))
    }

    @ViewBuilder
    private func songCluster(in size: CGSize, metrics: BreathingLayoutMetrics) -> some View {
        if let song = player.currentSong {
            if metrics.isLandscape {
                landscapeSongCluster(song, in: size, metrics: metrics)
            } else {
                portraitSongCluster(song, in: size, metrics: metrics)
            }
        } else {
            MonoIcon(icon: .radio, size: metrics.emptyStateFont, color: textColor.opacity(0.72), lineWidth: 1.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func portraitSongCluster(_ song: Song, in size: CGSize, metrics: BreathingLayoutMetrics) -> some View {
        VStack(spacing: metrics.contentSpacing) {
            metadataRow(song, metrics: metrics)
                .frame(maxWidth: metrics.metadataRowWidth)

            breathingCore(in: size, metrics: metrics)
                .frame(width: metrics.coreFootprintWidth, height: metrics.coreFootprintHeight)

            titleSignature(song, metrics: metrics)
                .frame(maxWidth: metrics.titleBlockWidth)

            timeWhispers(metrics: metrics)
        }
        .frame(maxWidth: .infinity)
    }

    private func landscapeSongCluster(_ song: Song, in size: CGSize, metrics: BreathingLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: metrics.landscapeSpacing) {
            VStack(alignment: .leading, spacing: metrics.contentSpacing) {
                metadataRow(song, metrics: metrics)
                titleSignature(song, metrics: metrics)
                timeWhispers(metrics: metrics)
            }
            .frame(maxWidth: metrics.textColumnWidth, alignment: .leading)

            breathingCore(in: size, metrics: metrics)
                .frame(width: metrics.coreFootprintWidth, height: metrics.coreFootprintHeight)
        }
        .frame(maxWidth: metrics.landscapeClusterWidth)
    }

    private func metadataRow(_ song: Song, metrics: BreathingLayoutMetrics) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let info = player.streamInfo {
                streamSignature(info, metrics: metrics)
                    .frame(maxWidth: metrics.streamTagMaxWidth, alignment: .leading)
            }

            Spacer(minLength: 0)

            artistSignature(song, metrics: metrics)
        }
    }

    private func titleSignature(_ song: Song, metrics: BreathingLayoutMetrics) -> some View {
        Text(song.name)
            .monoPlayerDisplayFont(
                size: metrics.titleFont,
                weight: .black,
                fallback: .system(size: metrics.titleFont, weight: .black, design: .rounded)
            )
            .foregroundStyle(textColor)
            .frame(width: metrics.titleWidth, alignment: metrics.isLandscape ? .leading : .center)
            .multilineTextAlignment(metrics.isLandscape ? .leading : .center)
            .lineLimit(metrics.isLandscape ? 3 : 2)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 18, x: 0, y: 10)
            .rotationEffect(.degrees(metrics.isLandscape ? -4 : -2))
            .opacity(showGestureLegend ? 0.98 : 0.90)
            .offset(x: dragTranslation.width * 0.06, y: dragTranslation.height * 0.03)
    }

    private func artistSignature(_ song: Song, metrics: BreathingLayoutMetrics) -> some View {
        Capsule()
            .fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.7 : 0.9))
            .overlay(
                Text(song.artistName.uppercased())
                    .font(.system(size: metrics.artistFont, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(subduedTextColor)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
            )
            .frame(width: metrics.artistCapsuleWidth, height: metrics.artistCapsuleHeight)
            .overlay(
                Capsule()
                    .strokeBorder(textColor.opacity(0.08), lineWidth: 1)
            )
            .rotationEffect(.degrees(6))
    }

    private func streamSignature(_ info: StreamInfo, metrics: BreathingLayoutMetrics) -> some View {
        Text(streamInfoText(info))
            .font(.system(size: metrics.streamInfoFont, weight: .semibold, design: .monospaced))
            .foregroundStyle(subduedTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(textColor.opacity(colorScheme == .dark ? 0.07 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(textColor.opacity(0.06), lineWidth: 1)
            )
            .rotationEffect(.degrees(-7))
    }

    private func timeWhispers(metrics: BreathingLayoutMetrics) -> some View {
        PlaybackTimeReader { _, _ in
            HStack(alignment: .center) {
                Text(formatTime(displayedTime))
                    .font(.system(size: metrics.primaryTimeFont, weight: .bold, design: .monospaced))
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.72 : 0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(textColor.opacity(0.08), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(-4))

                Spacer(minLength: 12)

                Text(formatTime(timePublisher.duration))
                    .font(.system(size: metrics.secondaryTimeFont, weight: .semibold, design: .monospaced))
                    .foregroundStyle(subduedTextColor)
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(textColor.opacity(colorScheme == .dark ? 0.07 : 0.05))
                    )
                    .rotationEffect(.degrees(8))
            }
            .frame(width: metrics.timeRowWidth)
        }
    }
}

// MARK: - Core
extension BreathingPlayerLayout {
    private func breathingCore(in size: CGSize, metrics: BreathingLayoutMetrics) -> some View {
        return ZStack {
            orbitDots(
                count: 34,
                radiusX: metrics.coreSize * 0.70,
                radiusY: metrics.coreSize * 0.60,
                phaseOffset: 0.1,
                leadingColor: textColor,
                secondaryColor: accentSecondary
            )

            orbitDots(
                count: 24,
                radiusX: metrics.coreSize * 0.93,
                radiusY: metrics.coreSize * 0.78,
                phaseOffset: 1.25,
                leadingColor: accentPrimary,
                secondaryColor: textColor
            )
            .opacity(0.68)

            interactiveOrb(coreSize: metrics.coreSize, size: size)
            .contentShape(Rectangle())
            .gesture(coreDragGesture(in: size))
            .onTapGesture {
                handleCoreTap()
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                withAnimation(MonoAnimation.panelToggle) {
                    showLyrics = true
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Breathing core")
            .accessibilityValue(player.isPlaying ? "Playing" : "Paused")
            .accessibilityHint("Tap to play or pause. Drag horizontally to switch tracks. Drag vertically to seek. Long press for lyrics.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("Play or pause")) {
                handleCoreTap()
            }
            .accessibilityAction(named: Text("Next track")) {
                player.next()
            }
            .accessibilityAction(named: Text("Previous track")) {
                player.previous()
            }
            .accessibilityAction(named: Text("Show lyrics")) {
                withAnimation(MonoAnimation.panelToggle) {
                    showLyrics = true
                }
            }
        }
    }

    private func interactiveOrb(coreSize: CGFloat, size: CGSize) -> some View {
        TimelineView(
            AppFrameRate.animationTimeline(
                maximumFramesPerSecond: 30,
                paused: !player.isPlaying && interactionAxis == .idle
            )
        ) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let amplitude = player.isPlaying ? coreSize * 0.075 : coreSize * 0.04
            let drift = blobDrift(for: coreSize)
            let scale = coreScale(for: phase)

            BreathingOrbVisual(
                coreSize: coreSize,
                phase: phase,
                amplitude: amplitude,
                drift: drift,
                scale: scale,
                accentPrimary: accentPrimary,
                accentSecondary: accentSecondary,
                textColor: textColor,
                subduedTextColor: subduedTextColor,
                colorScheme: colorScheme,
                coverURL: player.currentSong?.coverUrl?.sized(800),
                dynamicCoverURL: player.dynamicCoverUrl,
                isPlaying: player.isPlaying
            )
            .offset(x: dragTranslation.width * 0.18, y: dragTranslation.height * 0.12)
            .rotationEffect(.degrees(Double(dragTranslation.width / 18)))
        }
    }

    private func orbitDots(
        count: Int,
        radiusX: CGFloat,
        radiusY: CGFloat,
        phaseOffset: Double,
        leadingColor: Color,
        secondaryColor: Color
    ) -> some View {
        PlaybackTimeReader { _, _ in
            TimelineView(
                AppFrameRate.animationTimeline(
                    maximumFramesPerSecond: 30,
                    paused: !player.isPlaying && interactionAxis == .idle
                )
            ) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(0..<count, id: \.self) { index in
                        let fraction = Double(index) / Double(max(count - 1, 1))
                        let angle = fraction * .pi * 2 + phaseOffset + t * 0.18
                        let isLeading = fraction <= progress
                        let dotSize = isLeading ? 7.0 : 4.0
                        let x = CGFloat(cos(angle)) * radiusX
                        let y = CGFloat(sin(angle)) * radiusY

                        Circle()
                            .fill(isLeading ? leadingColor.opacity(0.92) : secondaryColor.opacity(0.18))
                            .frame(width: dotSize, height: dotSize)
                            .blur(radius: isLeading ? 0 : 0.1)
                            .offset(x: x, y: y)
                    }
                }
            }
            .drawingGroup()
        }
    }
}

private struct BreathingOrbVisual: View {
    let coreSize: CGFloat
    let phase: TimeInterval
    let amplitude: CGFloat
    let drift: CGFloat
    let scale: CGFloat
    let accentPrimary: Color
    let accentSecondary: Color
    let textColor: Color
    let subduedTextColor: Color
    let colorScheme: ColorScheme
    let coverURL: URL?
    let dynamicCoverURL: String?
    let isPlaying: Bool

    var body: some View {
        ZStack {
            glowShell
            mainCore
        }
        .frame(width: coreSize, height: coreSize)
        .scaleEffect(scale)
        .shadow(
            color: accentPrimary.opacity(colorScheme == .dark ? 0.26 : 0.18),
            radius: coreSize * 0.10,
            x: 0,
            y: coreSize * 0.04
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.10),
            radius: coreSize * 0.08,
            x: 0,
            y: coreSize * 0.05
        )
    }

    private var glowShell: some View {
        BreathingBlobShape(
            amplitude: amplitude * 1.32,
            phase: phase * 0.92,
            lobes: 6,
            twist: drift * 0.3
        )
        .fill(
            RadialGradient(
                colors: [
                    accentPrimary.opacity(colorScheme == .dark ? 0.52 : 0.42),
                    accentSecondary.opacity(colorScheme == .dark ? 0.38 : 0.30),
                    Color.black.opacity(colorScheme == .dark ? 0.32 : 0.08)
                ],
                center: .center,
                startRadius: 12,
                endRadius: coreSize * 0.55
            )
        )
        .frame(width: coreSize * 1.08, height: coreSize * 1.08)
        .blur(radius: coreSize * 0.06)
        .opacity(colorScheme == .dark ? 0.92 : 0.78)
        .scaleEffect(scale * 1.06)
    }

    private var mainCore: some View {
        BreathingBlobShape(
            amplitude: amplitude,
            phase: phase,
            lobes: 5,
            twist: drift
        )
        .fill(
            LinearGradient(
                colors: [
                    accentPrimary.opacity(colorScheme == .dark ? 0.95 : 0.80),
                    accentSecondary.opacity(colorScheme == .dark ? 0.82 : 0.64),
                    Color.white.opacity(colorScheme == .dark ? 0.10 : 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay { artworkOverlay }
        .overlay { highlightOverlay }
        .overlay { statusOverlay }
    }

    @ViewBuilder
    private var artworkOverlay: some View {
        let innerShape = BreathingBlobShape(
            amplitude: amplitude * 0.72,
            phase: phase + 0.4,
            lobes: 5,
            twist: drift * 0.25
        )

        ZStack {
            if let coverURL {
                CachedAsyncImage(url: coverURL) {
                    Rectangle()
                        .fill(textColor.opacity(0.08))
                }
                .aspectRatio(contentMode: .fill)
                .saturation(colorScheme == .dark ? 0.95 : 1.10)
                .contrast(colorScheme == .dark ? 1.05 : 1.12)
            } else {
                innerShape
                    .fill(textColor.opacity(colorScheme == .dark ? 0.10 : 0.08))
            }

            if let dynamicCoverURL, !dynamicCoverURL.isEmpty {
                DynamicCoverView(urlString: dynamicCoverURL, cornerRadius: 0)
            }
        }
            .frame(width: coreSize * 0.92, height: coreSize * 0.92)
            .clipShape(innerShape)
    }

    private var highlightOverlay: some View {
        Circle()
            .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.20))
            .frame(width: coreSize * 0.22, height: coreSize * 0.22)
            .blur(radius: coreSize * 0.06)
            .offset(x: -coreSize * 0.17, y: -coreSize * 0.21)
    }

    private var statusOverlay: some View {
        Text(isPlaying ? "LIVE" : "HOLD")
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(2)
            .foregroundStyle(textColor.opacity(0.82))
    }
}

// MARK: - Feedback
extension BreathingPlayerLayout {
    private func feedbackCloud(offsetY: CGFloat) -> some View {
        Group {
            if let feedbackTitle {
                VStack(spacing: 8) {
                    Text(feedbackTitle)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(textColor)

                    if let feedbackDetail {
                        Text(feedbackDetail)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(subduedTextColor)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.72 : 0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(textColor.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.08), radius: 18, x: 0, y: 10)
                .offset(y: offsetY)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private func edgeSatellites(topInset: CGFloat) -> some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    MonoSymbolIcon(name: "chevron.down", size: 16, color: textColor.opacity(0.92))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.76 : 0.94))
                        )
                        .overlay(
                            Circle()
                                .stroke(textColor.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                        showMoreMenu.toggle()
                    }
                } label: {
                    MonoIcon(icon: .more, size: 18, color: textColor.opacity(0.92), lineWidth: 1.5)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial.opacity(colorScheme == .dark ? 0.76 : 0.94))
                        )
                        .overlay(
                            Circle()
                                .stroke(textColor.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
                .playerMoreMenuAnchor()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct BreathingLayoutMetrics {
    let isLandscape: Bool
    let isCompactHeight: Bool
    let horizontalPadding: CGFloat
    let stageTopPadding: CGFloat
    let stageBottomPadding: CGFloat
    let topSpacer: CGFloat
    let bottomSpacer: CGFloat
    let contentSpacing: CGFloat
    let legendSpacing: CGFloat
    let coreSize: CGFloat
    let coreFootprintWidth: CGFloat
    let coreFootprintHeight: CGFloat
    let metadataRowWidth: CGFloat
    let streamTagMaxWidth: CGFloat
    let titleFont: CGFloat
    let titleWidth: CGFloat
    let titleBlockWidth: CGFloat
    let artistFont: CGFloat
    let artistCapsuleWidth: CGFloat
    let artistCapsuleHeight: CGFloat
    let streamInfoFont: CGFloat
    let primaryTimeFont: CGFloat
    let secondaryTimeFont: CGFloat
    let timeRowWidth: CGFloat
    let textColumnWidth: CGFloat
    let landscapeClusterWidth: CGFloat
    let landscapeSpacing: CGFloat
    let legendTitleFont: CGFloat
    let legendBodyFont: CGFloat
    let legendWidth: CGFloat
    let feedbackOffsetY: CGFloat
    let emptyStateFont: CGFloat
}

// MARK: - Actions
extension BreathingPlayerLayout {
    private func handleCoreTap() {
        player.togglePlayPause()
        scheduleLegendDismiss()
    }

    private func coreDragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                updateDragInteraction(translation: value.translation, in: size)
            }
            .onEnded { value in
                commitDragInteraction(translation: value.translation, in: size)
            }
    }

    private func updateDragInteraction(translation: CGSize, in size: CGSize) {
        if interactionAxis == .idle {
            guard abs(translation.width) > 8 || abs(translation.height) > 8 else { return }
            interactionAxis = abs(translation.width) > abs(translation.height) ? .horizontal : .vertical

            if interactionAxis == .vertical {
                seekAnchorTime = displayedTime
            }
        }

        dragTranslation = translation
        showGestureLegend = false

        switch interactionAxis {
        case .horizontal:
            let reached = abs(translation.width) > 84
            if reached && !crossedDragThreshold {
                crossedDragThreshold = true
                HapticManager.shared.medium()
            } else if !reached {
                crossedDragThreshold = false
            }

            let title = translation.width > 0 ? "PREV" : "NEXT"
            let detail = abs(translation.width) > 84 ? "RELEASE" : nil
            feedbackTitle = title
            feedbackDetail = detail
        case .vertical:
            let duration = max(timePublisher.duration, 1)
            let delta = Double((-translation.height / max(size.height, 1)) * CGFloat(duration * 0.78))
            let target = min(max(seekAnchorTime + delta, 0), timePublisher.duration)
            pendingSeekTime = target
            feedbackTitle = formatTime(target)
            feedbackDetail = nil
        case .idle:
            break
        }
    }

    private func commitDragInteraction(translation: CGSize, in size: CGSize) {
        defer {
            withAnimation(MonoAnimation.smooth) {
                interactionAxis = .idle
                dragTranslation = .zero
            }
            crossedDragThreshold = false
        }

        switch interactionAxis {
        case .horizontal:
            guard abs(translation.width) > 96 else {
                clearFeedback(after: 0.6)
                return
            }

            if translation.width > 0 {
                player.previous()
            } else {
                player.next()
            }
            clearFeedback(after: 0.2)
        case .vertical:
            let duration = max(timePublisher.duration, 1)
            let delta = Double((-translation.height / max(size.height, 1)) * CGFloat(duration * 0.78))
            let target = min(max(seekAnchorTime + delta, 0), timePublisher.duration)
            pendingSeekTime = target
            player.seek(to: target)
            feedbackTitle = formatTime(target)
            feedbackDetail = nil
            clearFeedback(after: 0.8)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pendingSeekTime = nil
            }
        case .idle:
            clearFeedback(after: 0.2)
        }
    }

    private func blobDrift(for coreSize: CGFloat) -> CGFloat {
        switch interactionAxis {
        case .horizontal:
            return max(min(dragTranslation.width / coreSize, 0.45), -0.45)
        case .vertical:
            return max(min(-dragTranslation.height / coreSize, 0.45), -0.45)
        case .idle:
            return 0
        }
    }

    private func coreScale(for phase: TimeInterval) -> CGFloat {
        let breathing = player.isPlaying ? CGFloat((sin(phase * 1.25) + 1) * 0.5) : 0.18
        let lift = CGFloat(1.0 + breathing * 0.045)
        let gestureLift = CGFloat(1.0 + min(abs(dragTranslation.width) + abs(dragTranslation.height), 90) / 1800)
        return lift * gestureLift
    }

    private func extractPalette() {
        colorExtractor.extract(from: player.currentSong?.coverUrl?.absoluteString)
    }

    private func metrics(for size: CGSize, safeAreaInsets: EdgeInsets) -> BreathingLayoutMetrics {
        let isLandscape = size.width > size.height
        let isCompactHeight = size.height < 430
        let shortestSide = min(size.width, size.height)
        let horizontalPadding = DeviceLayout.usesExpandedLayout ? 40.0 : (isLandscape ? 20.0 : DeviceLayout.viewHorizontalPadding)
        let stageTopPadding = safeAreaInsets.top + (isLandscape ? 16.0 : 24.0)
        let stageBottomPadding = safeAreaInsets.bottom + (isCompactHeight ? 12.0 : 18.0)
        let availableWidth = max(size.width - horizontalPadding * 2, 260)
        let availableHeight = max(size.height - stageTopPadding - stageBottomPadding, 260)
        let coreFootprintWidthFactor: CGFloat = isLandscape ? 1.80 : 1.72
        let coreFootprintHeightFactor: CGFloat = isLandscape ? 1.52 : 1.44
        let maxCoreFootprintWidth = availableWidth * 0.92
        let coreSize = min(
            availableWidth * (isLandscape ? 0.34 : 0.48),
            availableHeight * (isLandscape ? 0.52 : 0.32),
            maxCoreFootprintWidth / coreFootprintWidthFactor,
            shortestSide * (DeviceLayout.usesExpandedLayout ? 0.40 : (isLandscape ? 0.44 : 0.52)),
            DeviceLayout.usesExpandedLayout ? 400.0 : 240.0
        )
        let coreFootprintWidth = min(coreSize * coreFootprintWidthFactor, maxCoreFootprintWidth)
        let coreFootprintHeight = coreSize * coreFootprintHeightFactor
        let metadataRowWidth = min(availableWidth * 0.92, DeviceLayout.usesExpandedLayout ? 520.0 : (isLandscape ? 320.0 : availableWidth * 0.88))
        let titleWidth = min(
            availableWidth * (isLandscape ? 0.34 : 0.72),
            DeviceLayout.usesExpandedLayout ? 400.0 : 300.0
        )
        let titleFont = min(
            shortestSide * (isLandscape ? 0.060 : 0.088),
            coreSize * (isLandscape ? 0.26 : 0.24),
            DeviceLayout.usesExpandedLayout ? 54.0 : 40.0
        )
        let artistCapsuleWidth = min(
            max(metadataRowWidth * (isLandscape ? 0.42 : 0.38), 120),
            DeviceLayout.usesExpandedLayout ? 300.0 : 220.0
        )
        let titleBlockWidth = min(max(titleWidth, coreSize * 0.92), availableWidth * 0.88, DeviceLayout.usesExpandedLayout ? 440.0 : 320.0)
        let textColumnWidth = min(max(availableWidth - coreFootprintWidth - 28.0, 180.0), DeviceLayout.usesExpandedLayout ? 360.0 : 280.0)
        let landscapeClusterWidth = min(availableWidth * 0.96, textColumnWidth + coreFootprintWidth + 28.0)

        return BreathingLayoutMetrics(
            isLandscape: isLandscape,
            isCompactHeight: isCompactHeight,
            horizontalPadding: horizontalPadding,
            stageTopPadding: stageTopPadding,
            stageBottomPadding: stageBottomPadding,
            topSpacer: isLandscape ? 8 : 32,
            bottomSpacer: isLandscape ? 0 : 8,
            contentSpacing: isCompactHeight ? 14 : (isLandscape ? 18 : 24),
            legendSpacing: isCompactHeight ? 14 : (isLandscape ? 18 : 28),
            coreSize: coreSize,
            coreFootprintWidth: coreFootprintWidth,
            coreFootprintHeight: coreFootprintHeight,
            metadataRowWidth: metadataRowWidth,
            streamTagMaxWidth: min(metadataRowWidth * 0.56, DeviceLayout.usesExpandedLayout ? 240.0 : 180.0),
            titleFont: titleFont,
            titleWidth: titleWidth,
            titleBlockWidth: titleBlockWidth,
            artistFont: DeviceLayout.usesExpandedLayout ? 12 : (isCompactHeight ? 10 : 11),
            artistCapsuleWidth: artistCapsuleWidth,
            artistCapsuleHeight: DeviceLayout.usesExpandedLayout ? 40 : 36,
            streamInfoFont: DeviceLayout.usesExpandedLayout ? 11 : (isCompactHeight ? 9.5 : 10),
            primaryTimeFont: DeviceLayout.usesExpandedLayout ? 18 : (isCompactHeight ? 15 : 16),
            secondaryTimeFont: DeviceLayout.usesExpandedLayout ? 14 : 13,
            timeRowWidth: min(titleBlockWidth, availableWidth * 0.80, DeviceLayout.usesExpandedLayout ? 360.0 : 280.0),
            textColumnWidth: textColumnWidth,
            landscapeClusterWidth: landscapeClusterWidth,
            landscapeSpacing: isCompactHeight ? 20 : 28,
            legendTitleFont: DeviceLayout.usesExpandedLayout ? 13 : (isCompactHeight ? 11 : 12),
            legendBodyFont: DeviceLayout.usesExpandedLayout ? 12 : (isCompactHeight ? 10 : 11),
            legendWidth: min(availableWidth * 0.88, DeviceLayout.usesExpandedLayout ? 460.0 : (isLandscape ? 360.0 : 320.0)),
            feedbackOffsetY: -coreFootprintHeight * (isLandscape ? 0.42 : 0.72),
            emptyStateFont: min(shortestSide * 0.09, DeviceLayout.usesExpandedLayout ? 48.0 : 38.0)
        )
    }
}

// MARK: - Helpers
extension BreathingPlayerLayout {
    private func flashFeedback(_ title: String, detail: String? = nil, linger: Double = 1.35) {
        let token = UUID()
        feedbackToken = token

        withAnimation(MonoAnimation.smooth) {
            feedbackTitle = title
            feedbackDetail = detail
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(linger * 1_000_000_000))
            guard feedbackToken == token, interactionAxis == .idle else { return }
            withAnimation(MonoAnimation.easeOut) {
                feedbackTitle = nil
                feedbackDetail = nil
            }
        }
    }

    private func clearFeedback(after delay: Double) {
        let token = UUID()
        feedbackToken = token

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard feedbackToken == token, interactionAxis == .idle else { return }
            withAnimation(MonoAnimation.easeOut) {
                feedbackTitle = nil
                feedbackDetail = nil
            }
        }
    }

    private func scheduleLegendDismiss() {
        let token = UUID()
        legendToken = token

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_600_000_000)
            guard legendToken == token, interactionAxis == .idle, !showLyrics else { return }
            withAnimation(MonoAnimation.easeOut) {
                showGestureLegend = false
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let safeValue = max(seconds, 0)
        let total = Int(safeValue.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sampleRate = info.sampleRate {
            if sampleRate >= 1000 {
                let khz = Double(sampleRate) / 1000.0
                parts.append(khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz))
            } else {
                parts.append("\(sampleRate)Hz")
            }
        }
        if let bitDepth = info.bitDepth, bitDepth > 0 { parts.append("\(bitDepth)bit") }
        if let channelCount = info.channelCount, channelCount > 2 { parts.append("\(channelCount)ch") }
        return parts.joined(separator: " / ")
    }
}

/// 可呼吸的不规则声体。参数变化时形状会像活物一样轻微塌缩和鼓胀。
struct BreathingBlobShape: Shape {
    var amplitude: CGFloat
    var phase: Double
    var lobes: Double
    var twist: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(amplitude, phase) }
        set {
            amplitude = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.42
        let points = 120

        var path = Path()

        for index in 0...points {
            let progress = Double(index) / Double(points)
            let angle = progress * .pi * 2
            let layeredWave =
                CGFloat(sin(angle * lobes + phase)) * amplitude +
                CGFloat(sin(angle * (lobes + 2) - phase * 0.7)) * amplitude * 0.44 +
                CGFloat(cos(angle * 2 + phase * 0.38)) * amplitude * 0.28
            let radius = max(baseRadius + layeredWave + twist * baseRadius * CGFloat(cos(angle * 1.5)), baseRadius * 0.55)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}
