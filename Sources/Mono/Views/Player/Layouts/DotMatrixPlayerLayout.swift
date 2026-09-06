import SwiftUI
import SwiftPixelGrid
import UIKit

/// 独立点阵播放器。
///
/// 这不是现有 8-bit 像素主题的换皮：封面观察窗、点阵时间轴、九点信号核心、
/// 横竖屏编排和交互均由本主题独立完成。SwiftPixelGrid 只负责高效的九点 Canvas 动画。
struct DotMatrixPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var player = PlayerManager.shared
    private let time = PlaybackTimePublisher.shared
    @StateObject private var colors = CoverColorExtractor(minimumColorCount: 5)

    @State private var showsLyrics = false
    @State private var showsQueue = false
    @State private var showsQuality = false
    @State private var showsMore = false
    @State private var showsEQ = false
    @State private var showsTheme = false
    @State private var isSeeking = false
    @State private var seekTime = 0.0

    private var dotMatrixPalette: [Color] {
        guard colors.resolvedURL != nil else {
            return [
                Color(hex: "68F8CF"),
                Color(hex: "76A8FF"),
                Color(hex: "B879FF"),
                Color(hex: "FF7DAF")
            ]
        }
        return DotMatrixAccentResolver.resolve(colors.palette)
    }

    private var accent: Color {
        dotMatrixPalette.first ?? Color(hex: "68F8CF")
    }

    private var secondaryAccent: Color {
        dotMatrixPalette.dropFirst().first ?? Color(hex: "76A8FF")
    }

    private var pixelColors: [PixelGridColor] {
        let source = dotMatrixPalette.isEmpty
            ? [Color(hex: "68F8CF"), Color(hex: "76A8FF")]
            : dotMatrixPalette
        // 九格不是简单彩虹排序：中心保持主色，四角与边缘交替使用封面色，
        // 让轨道动画移动时仍能辨认其运动方向。
        let distribution = [0, 1, 2, 1, 0, 2, 3, 2, 0]
        return distribution.map { index in
            pixelGridColor(source[index % source.count])
        }
    }

    private func pixelGridColor(_ color: Color) -> PixelGridColor {
        let resolved = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .cyan
        }
        let r = UInt32(min(max(red, 0), 1) * 255)
        let g = UInt32(min(max(green, 0), 1) * 255)
        let b = UInt32(min(max(blue, 0), 1) * 255)
        return .hex((r << 16) | (g << 8) | b)
    }

    private func pixelGridAnimation(_ preset: PixelGridPreset) -> PixelGridAnimation {
        let base = preset.animation
        return (try? PixelGridAnimation(
            name: "\(base.name)-cover-palette",
            delays: base.delays,
            duration: base.duration,
            colors: pixelColors
        )) ?? base
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = DotMatrixMetrics(
                size: proxy.size,
                headerTopPadding: DeviceLayout.playerHeaderTopPadding,
                isPad: DeviceLayout.usesExpandedLayout
            )

            ZStack {
                DotMatrixBackdrop(
                    primary: accent,
                    secondary: secondaryAccent,
                    palette: dotMatrixPalette,
                    isPlaying: player.isPlaying,
                    reduceMotion: reduceMotion,
                    songIdentity: player.currentSong?.id ?? 0
                )

                VStack(spacing: 0) {
                    toolbar(metrics: metrics)

                    if metrics.usesWideLayout {
                        wideContent(metrics: metrics)
                    } else {
                        portraitContent(metrics: metrics)
                    }
                }
                .frame(maxWidth: metrics.maximumWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, metrics.horizontalInset)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, metrics.bottomInset))
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showsMore {
                    PlayerMoreMenu(
                        isPresented: $showsMore,
                        anchorFrame: anchorFrame,
                        isDarkBackground: true,
                        onQuality: { showsQuality = true },
                        onEQ: { showsEQ = true },
                        onTheme: { showsTheme = true }
                    )
                }
            }
        }
        .compatFontDesign(nil)
        .onAppear { refreshPalette() }
        .onChange(of: player.currentSong?.coverUrl?.absoluteString) { _, _ in
            refreshPalette()
        }
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            PlaylistPopupView()
        }
        .monoSheet(isPresented: $showsQuality, preset: .standard) {
            qualitySheet
        }
        .fullScreenCover(isPresented: $showsEQ) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showsTheme, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
    }
}

// MARK: - Layout

private extension DotMatrixPlayerLayout {
    func toolbar(metrics: DotMatrixMetrics) -> some View {
        HStack(spacing: 10) {
            dotButton(icon: .back, label: String(localized: "返回")) {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DOT MATRIX")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.94))

                Text(queuePositionText)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
            }

            Spacer(minLength: 4)

            Button {
                showsQuality = true
            } label: {
                Text(player.qualityButtonText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(DotMatrixOutlineShape(accent: accent.opacity(0.32)))
            }
            .buttonStyle(DotMatrixPressStyle())
            .playerQualitySelectionAvailability()

            dotButton(icon: .more, label: String(localized: "更多")) {
                showsMore = true
            }
            .playerMoreMenuAnchor()
        }
        .padding(.top, metrics.headerTopInset)
        .padding(.bottom, metrics.headerBottomInset)
    }

    func portraitContent(metrics: DotMatrixMetrics) -> some View {
        VStack(spacing: 0) {
            playbackStage(size: metrics.stageSize)

            songInformation(compact: metrics.isCompact)
                .padding(.top, metrics.informationTopInset)

            progressSection(compact: metrics.isCompact)
                .padding(.top, metrics.progressTopInset)

            Spacer(minLength: metrics.minimumSpacer)

            transportControls(compact: metrics.isCompact)
        }
    }

    func wideContent(metrics: DotMatrixMetrics) -> some View {
        HStack(spacing: metrics.wideGap) {
            playbackStage(size: metrics.stageSize)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                songInformation(compact: false)

                progressSection(compact: false)
                    .padding(.top, 24)

                transportControls(compact: false)
                    .padding(.top, 30)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stage

private extension DotMatrixPlayerLayout {
    @ViewBuilder
    func playbackStage(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.34))

            if showsLyrics, let song = player.currentSong {
                LyricsView(
                    song: song,
                    onBackgroundTap: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
                            showsLyrics = false
                        }
                    },
                    adaptivePrimaryColor: .white,
                    adaptiveSecondaryColor: Color.white.opacity(0.58),
                    enforcesAdaptiveContrast: true
                )
                .environment(\.colorScheme, .dark)
                .padding(10)
                .transition(.opacity)
            } else {
                artworkStage(size: size)
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .onTapWithHaptic {
                        guard player.currentSong != nil else { return }
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
                            showsLyrics = true
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            playbackStateLabel
                .padding(15)
        }
        .overlay(alignment: .bottomTrailing) {
            PixelGrid(
                animation: pixelGridAnimation(.orbit),
                bloom: PixelGridBloom(amount: 3.5, intensity: 0.34),
                cornerRadius: 1,
                isAnimating: player.isPlaying && !reduceMotion,
                scale: 2.2,
                accessibilityLabel: player.isPlaying ? String(localized: "正在播放") : String(localized: "已暂停")
            )
            .padding(18)
        }
        .shadow(color: accent.opacity(0.16), radius: 30, y: 12)
    }

    func artworkStage(size: CGFloat) -> some View {
        ZStack {
            Color(hex: "0B1113")

            if let song = player.currentSong {
                CachedAsyncImage(
                    url: song.coverUrl?.sized(1000),
                    width: size,
                    height: size
                ) {
                    DotMatrixArtworkPlaceholder(accent: accent)
                }
                .aspectRatio(contentMode: .fill)

                if let dynamicURL = player.dynamicCoverUrl, !dynamicURL.isEmpty {
                    DynamicCoverView(urlString: dynamicURL, cornerRadius: 0)
                }
            } else {
                DotMatrixArtworkPlaceholder(accent: accent)
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.08), Color.black.opacity(0.64)],
                startPoint: .top,
                endPoint: .bottom
            )

            DotMatrixArtworkOverlay(accent: accent)
                .allowsHitTesting(false)

            if player.isPlaying && !reduceMotion {
                DotMatrixScanLine(accent: accent)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }

    var playbackStateLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(player.isPlaying ? accent : Color.white.opacity(0.34))
                .frame(width: 6, height: 6)
                .shadow(color: player.isPlaying ? accent.opacity(0.8) : .clear, radius: 4)

            Text(player.isPlaying ? "PLAY" : "HOLD")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 9)
        .frame(height: 25)
        .background(Color.black.opacity(0.46), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7))
    }
}

// MARK: - Information and progress

private extension DotMatrixPlayerLayout {
    func songInformation(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 7) {
            Text(player.currentSong?.name ?? String(localized: "暂无歌曲"))
                .monoPlayerDisplayFont(
                    size: compact ? 21 : 25,
                    weight: .bold,
                    fallback: .system(size: compact ? 21 : 25, weight: .bold, design: .rounded)
                )
                .foregroundStyle(Color.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 8) {
                Text(player.currentSong?.artistName ?? "—")
                    .font(.system(size: compact ? 12 : 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .lineLimit(1)

                if let albumName = player.currentSong?.al?.name, !albumName.isEmpty {
                    Circle()
                        .fill(accent.opacity(0.72))
                        .frame(width: 3, height: 3)

                    Text(albumName)
                        .font(.system(size: compact ? 11 : 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.38))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func progressSection(compact: Bool) -> some View {
        PlaybackTimeReader { _, _ in
            VStack(spacing: compact ? 5 : 8) {
                DotMatrixProgressRail(
                    progress: displayProgress,
                    accent: accent,
                    secondaryAccent: secondaryAccent,
                    isEnabled: validDuration > 0,
                    onChanged: { ratio in
                        isSeeking = true
                        seekTime = ratio * validDuration
                    },
                    onEnded: { ratio in
                        let target = ratio * validDuration
                        seekTime = target
                        isSeeking = false
                        player.seek(to: target)
                    }
                )
                .frame(height: compact ? 30 : 36)

                HStack {
                    Text(formatTime(isSeeking ? seekTime : validCurrentTime))
                    Spacer()
                    Text(formatTime(validDuration))
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.42))
            }
        }
    }

    var displayProgress: Double {
        guard validDuration > 0 else { return 0 }
        let value = isSeeking ? seekTime : validCurrentTime
        return min(max(value / validDuration, 0), 1)
    }
}

// MARK: - Transport

private extension DotMatrixPlayerLayout {
    func transportControls(compact: Bool) -> some View {
        let sideSize: CGFloat = compact ? 42 : 48
        let coreSize: CGFloat = compact ? 68 : 78

        return HStack(spacing: 0) {
            transportButton(
                icon: player.mode.monoIcon,
                size: sideSize,
                iconSize: 17,
                label: player.mode.displayName
            ) {
                player.switchMode()
            }

            Spacer(minLength: 8)

            transportButton(
                icon: .previous,
                size: sideSize,
                iconSize: 23,
                label: String(localized: "上一首")
            ) {
                player.previous()
            }

            Spacer(minLength: 8)

            DotMatrixSignalButton(
                size: coreSize,
                accent: accent,
                pixelColors: pixelColors,
                isPlaying: player.isPlaying,
                isLoading: player.isLoading,
                reduceMotion: reduceMotion
            ) {
                player.togglePlayPause()
            }

            Spacer(minLength: 8)

            transportButton(
                icon: .next,
                size: sideSize,
                iconSize: 23,
                label: String(localized: "playback_next_track")
            ) {
                player.next()
            }

            Spacer(minLength: 8)

            transportButton(
                icon: .list,
                size: sideSize,
                iconSize: 18,
                label: String(localized: "player_queue")
            ) {
                showsQueue = true
            }
        }
        .frame(maxWidth: .infinity)
    }

    func transportButton(
        icon: MonoIcon.IconType,
        size: CGFloat,
        iconSize: CGFloat,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                DotMatrixOutlineShape(accent: accent.opacity(0.22))
                MonoIcon(icon: icon, size: iconSize, color: Color.white.opacity(0.82), lineWidth: 1.8)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(DotMatrixPressStyle())
        .accessibilityLabel(label)
    }

    func dotButton(icon: MonoIcon.IconType, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                DotMatrixOutlineShape(accent: Color.white.opacity(0.12))
                MonoIcon(icon: icon, size: 17, color: Color.white.opacity(0.84), lineWidth: 1.8)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(DotMatrixPressStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Data and destinations

private extension DotMatrixPlayerLayout {
    var validDuration: Double {
        let value = time.duration
        return value.isFinite && value > 0 ? value : 0
    }

    var validCurrentTime: Double {
        let value = time.currentTime
        return value.isFinite ? max(value, 0) : 0
    }

    var queuePositionText: String {
        let queue = player.currentContextList.filter { $0.podcastRadioId == nil }
        guard let current = player.currentSong,
              let index = queue.firstIndex(where: { $0.id == current.id }) else {
            return "00 / 00"
        }
        return String(format: "%02d / %02d", index + 1, queue.count)
    }

    func refreshPalette() {
        colors.extract(from: player.currentSong?.coverUrl?.sized(480).absoluteString)
    }

    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var qualitySheet: some View {
        SoundQualitySheet(
            currentQuality: player.soundQuality,
            currentQQQuality: player.qqMusicQuality,
            isQQMusic: player.currentSong?.isQQMusic == true,
            onSelectNetease: { quality in
                player.switchQuality(quality)
                showsQuality = false
            },
            onSelectQQ: { quality in
                player.switchQQMusicQuality(quality)
                showsQuality = false
            },
            songMid: player.currentSong?.qqMid,
            songId: player.currentSong?.id,
            isQishui: player.currentSong?.isQishui == true,
            qishuiTrackId: player.currentSong?.qishuiTrackId,
            onSelectQishui: { info in
                player.switchQishuiQuality(info)
                showsQuality = false
            }
        )
    }
}

// MARK: - Metrics

private struct DotMatrixMetrics {
    let size: CGSize
    let headerTopPadding: CGFloat
    let isPad: Bool

    var usesWideLayout: Bool {
        size.width >= 720 && size.width > size.height
    }

    var isCompact: Bool {
        !usesWideLayout && size.height < 730
    }

    var maximumWidth: CGFloat {
        usesWideLayout ? min(size.width, 1120) : min(size.width, 560)
    }

    var horizontalInset: CGFloat {
        if usesWideLayout { return 30 }
        return size.width < 380 ? 15 : 20
    }

    var headerTopInset: CGFloat {
        max(headerTopPadding, 8)
    }

    var headerBottomInset: CGFloat {
        isCompact ? 7 : 12
    }

    var stageSize: CGFloat {
        if usesWideLayout {
            return min(size.height * 0.68, size.width * 0.43, 470)
        }
        let widthLimit = size.width - horizontalInset * 2
        let heightRatio = isCompact ? 0.39 : 0.43
        return min(widthLimit, size.height * heightRatio, isPad ? 430 : 390)
    }

    var informationTopInset: CGFloat { isCompact ? 10 : 18 }
    var progressTopInset: CGFloat { isCompact ? 8 : 18 }
    var minimumSpacer: CGFloat { isCompact ? 7 : 14 }
    var bottomInset: CGFloat { isCompact ? 5 : 10 }
    var wideGap: CGFloat { min(max(size.width * 0.055, 30), 72) }
}

// MARK: - Adaptive accent

/// 点阵主题显示在近黑背景上，不能直接把封面的黑色主簇作为发光色。
/// 这里仍使用全局取色引擎给出的完整调色板，只在主题出口选择具有可见度的色簇，
/// 并保持原始色相进行亮度归一化，而不是另起一套封面取色。
@MainActor
private enum DotMatrixAccentResolver {
    private struct Candidate {
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
        let score: CGFloat

        var normalizedColor: Color {
            Color(
                hue: Double(hue),
                saturation: Double(min(max(saturation, 0.46), 0.88)),
                brightness: Double(min(max(brightness, 0.76), 0.98))
            )
        }
    }

    static func resolve(_ palette: [Color]) -> [Color] {
        let candidates = palette.compactMap(candidate(for:)).sorted { lhs, rhs in
            lhs.score > rhs.score
        }

        guard let primary = candidates.first else {
            return [
                Color(hex: "68F8CF"),
                Color(hex: "76A8FF"),
                Color(hex: "B879FF"),
                Color(hex: "FF7DAF")
            ]
        }

        var selected = [primary]
        for candidate in candidates.dropFirst() {
            guard selected.allSatisfy({
                circularHueDistance(candidate.hue, $0.hue) >= 0.045
            }) else { continue }
            selected.append(candidate)
            if selected.count == 4 { break }
        }

        var resolved = selected.map(\.normalizedColor)
        // 单色或低色差封面依旧使用封面主色调，只生成邻近色而不是退化为黑色
        // 或强行套用无关的彩虹色。
        let analogousOffsets: [CGFloat] = [0.075, -0.065, 0.15]
        for offset in analogousOffsets where resolved.count < 4 {
            let hue = (primary.hue + offset + 1).truncatingRemainder(dividingBy: 1)
            resolved.append(
                Color(
                    hue: Double(hue),
                    saturation: Double(min(max(primary.saturation, 0.48), 0.82)),
                    brightness: Double(min(max(primary.brightness, 0.8), 0.98))
                )
            )
        }
        return Array(resolved.prefix(4))
    }

    private static func candidate(for color: Color) -> Candidate? {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        ), alpha > 0.05 else { return nil }

        // 黑、近黑和无色灰不适合作为黑底点阵发光色。保留它们作为背景分析
        // 结果，但不让它们进入点阵强调色候选。
        guard brightness >= 0.14, saturation >= 0.12 else { return nil }
        let visibility = brightness * 0.58 + saturation * 0.42
        let darkPenalty = brightness < 0.28 ? (0.28 - brightness) * 1.8 : 0
        return Candidate(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            score: visibility - darkPenalty
        )
    }

    private static func circularHueDistance(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let direct = abs(lhs - rhs)
        return min(direct, 1 - direct)
    }
}

// MARK: - Visual components

private struct DotMatrixBackdrop: View {
    let primary: Color
    let secondary: Color
    let palette: [Color]
    let isPlaying: Bool
    let reduceMotion: Bool
    let songIdentity: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color(hex: "050A0C")

                RadialGradient(
                    colors: [primary.opacity(0.22), primary.opacity(0.05), .clear],
                    center: .init(x: 0.22, y: 0.16),
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.78
                )

                RadialGradient(
                    colors: [secondary.opacity(0.16), .clear],
                    center: .init(x: 0.88, y: 0.72),
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.66
                )

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !isPlaying)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        drawDots(context: &context, size: size, phase: phase, palette: palette)
                    }
                }

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.12), Color.black.opacity(0.56)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                DotMatrixBarAnimation(
                    primary: primary,
                    secondary: secondary,
                    palette: palette,
                    songIdentity: songIdentity,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion
                )
                .frame(height: min(max(proxy.size.height * 0.082, 52), 72))
                .padding(.horizontal, 8)
                .opacity(0.72)
            }
        }
        .ignoresSafeArea()
    }

    private func drawDots(
        context: inout GraphicsContext,
        size: CGSize,
        phase: TimeInterval,
        palette: [Color]
    ) {
        let spacing: CGFloat = 22
        let columns = Int(size.width / spacing) + 2
        let rows = Int(size.height / spacing) + 2

        for row in 0..<rows {
            for column in 0..<columns {
                let x = CGFloat(column) * spacing
                let y = CGFloat(row) * spacing
                let wave = sin(Double(column) * 0.38 + Double(row) * 0.24 + phase * 0.8)
                let opacity = 0.045 + max(wave, 0) * 0.045
                let radius: CGFloat = wave > 0.72 ? 1.15 : 0.72
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                let source = palette.isEmpty ? [Color.white] : palette
                let color = source[(column + row * 2) % source.count]
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
    }
}

/// 背景底部的点阵柱状动画。它是主题氛围动画而非播放进度或实时频谱；
/// 每首歌根据稳定 identity 获得不同节奏，播放时连续起伏，暂停时保持静止。
private struct DotMatrixBarAnimation: View {
    let primary: Color
    let secondary: Color
    let palette: [Color]
    let songIdentity: Int
    let isPlaying: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 24.0,
                paused: reduceMotion || !isPlaying
            )
        ) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let columnStep: CGFloat = size.width < 430 ? 8 : 10
                let rowStep: CGFloat = 7
                let columnCount = max(1, Int(size.width / columnStep))
                let maximumRows = max(4, Int(size.height / rowStep))

                for column in 0..<columnCount {
                    let heightRatio = columnHeightRatio(
                        column: column,
                        total: columnCount,
                        phase: phase
                    )
                    let rowCount = max(2, Int(Double(maximumRows) * heightRatio))

                    for row in 0..<rowCount {
                        let x = CGFloat(column) * columnStep + columnStep * 0.5
                        let y = size.height - CGFloat(row) * rowStep - rowStep * 0.6
                        let verticalRatio = Double(row) / Double(max(rowCount - 1, 1))
                        let crest = verticalRatio > 0.82
                        let radius: CGFloat = crest ? 1.55 : 1.3
                        let rect = CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        let source = palette.isEmpty ? [primary, secondary] : palette
                        let horizontalRatio = Double(column) / Double(max(columnCount - 1, 1))
                        let colorPosition = horizontalRatio * Double(source.count - 1)
                            + verticalRatio * 0.82
                        let color = source[Int(colorPosition.rounded(.down)) % source.count]
                        let opacity = 0.42 + verticalRatio * 0.42
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(color.opacity(opacity))
                        )

                        if crest && isPlaying {
                            let glowRect = rect.insetBy(dx: -1.8, dy: -1.8)
                            context.fill(
                                Path(ellipseIn: glowRect),
                                with: .color(color.opacity(0.11))
                            )
                        }
                    }
                }
            }
        }
        .mask(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.72), location: 0.24),
                    .init(color: .white, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func columnHeightRatio(column: Int, total: Int, phase: TimeInterval) -> Double {
        let identityPhase = Double(abs(songIdentity % 997)) / 997.0 * .pi * 2
        let x = Double(column) / Double(max(total - 1, 1))
        let motion = reduceMotion || !isPlaying ? 0 : phase
        let broad = sin(x * .pi * 4.2 + identityPhase + motion * 1.05) * 0.17
        let counterWave = cos(x * .pi * 7.4 - identityPhase * 0.58 - motion * 0.72) * 0.12
        let detail = sin(x * .pi * 15.0 + identityPhase * 0.36 + motion * 1.66) * 0.075
        let breathing = sin(motion * 0.88 + x * .pi * 2) * 0.045
        return min(max(0.50 + broad + counterWave + detail + breathing, 0.16), 0.94)
    }

}

private struct DotMatrixArtworkOverlay: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let spacing: CGFloat = max(13, size.width / 25)
                let rows = Int(size.height / spacing) + 1
                let columns = Int(size.width / spacing) + 1

                for row in 0..<rows {
                    for column in 0..<columns {
                        let x = CGFloat(column) * spacing + spacing * 0.5
                        let y = CGFloat(row) * spacing + spacing * 0.5
                        let edge = min(x, y, size.width - x, size.height - y)
                        let opacity = edge < spacing * 2 ? 0.24 : 0.075
                        let rect = CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)
                        context.fill(Path(ellipseIn: rect), with: .color(accent.opacity(opacity)))
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct DotMatrixScanLine: View {
    let accent: Color
    @State private var position: CGFloat = -0.1

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, accent.opacity(0.34), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .shadow(color: accent.opacity(0.5), radius: 5)
                .offset(y: proxy.size.height * position)
                .onAppear {
                    position = -0.1
                    withAnimation(.linear(duration: 4.6).repeatForever(autoreverses: false)) {
                        position = 1.1
                    }
                }
        }
    }
}

private struct DotMatrixArtworkPlaceholder: View {
    let accent: Color

    var body: some View {
        ZStack {
            Color(hex: "0A1113")
            PixelGrid(
                preset: .centerOut,
                bloom: PixelGridBloom(amount: 4, intensity: 0.32),
                cornerRadius: 1,
                isAnimating: true,
                scale: 4,
                accessibilityLabel: String(localized: "封面加载中")
            )
            .opacity(0.76)
        }
    }
}

private struct DotMatrixProgressRail: View {
    let progress: Double
    let accent: Color
    let secondaryAccent: Color
    let isEnabled: Bool
    let onChanged: (Double) -> Void
    let onEnded: (Double) -> Void

    private let count = 36

    var body: some View {
        GeometryReader { proxy in
            let available = max(proxy.size.width, 1)
            let dotStep = available / CGFloat(count)
            let activeCount = Int((Double(count) * min(max(progress, 0), 1)).rounded(.down))

            ZStack(alignment: .leading) {
                ForEach(0..<count, id: \.self) { index in
                    let isActive = index < activeCount
                    let isHead = index == min(activeCount, count - 1)
                    Circle()
                        .fill(dotColor(index: index, isActive: isActive))
                        .frame(width: isHead && isActive ? 5.5 : 3.5, height: isHead && isActive ? 5.5 : 3.5)
                        .shadow(color: isHead && isActive ? accent.opacity(0.7) : .clear, radius: 5)
                        .position(x: dotStep * (CGFloat(index) + 0.5), y: proxy.size.height * 0.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        onChanged(ratio(for: value.location.x, width: available))
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        onEnded(ratio(for: value.location.x, width: available))
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "播放进度"))
        .accessibilityValue("\(Int(progress * 100))%")
    }

    private func ratio(for x: CGFloat, width: CGFloat) -> Double {
        Double(min(max(x / width, 0), 1))
    }

    private func dotColor(index: Int, isActive: Bool) -> Color {
        guard isActive else { return Color.white.opacity(0.16) }
        let mix = Double(index) / Double(max(count - 1, 1))
        return mix < 0.56 ? accent : secondaryAccent
    }
}

private struct DotMatrixSignalButton: View {
    let size: CGFloat
    let accent: Color
    let pixelColors: [PixelGridColor]
    let isPlaying: Bool
    let isLoading: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.34))
                    .overlay(Circle().stroke(accent.opacity(0.38), lineWidth: 1))
                    .shadow(color: accent.opacity(isPlaying ? 0.32 : 0.12), radius: 18)

                PixelGrid(
                    animation: signalAnimation,
                    bloom: PixelGridBloom(amount: 4, intensity: 0.42),
                    cornerRadius: 1,
                    isAnimating: isPlaying && !reduceMotion,
                    scale: size >= 76 ? 5.2 : 4.5,
                    accessibilityLabel: isPlaying ? String(localized: "暂停") : String(localized: "action_play")
                )

                Circle()
                    .fill(Color(hex: "07100F").opacity(0.88))
                    .frame(width: size * 0.39, height: size * 0.39)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.72)
                } else {
                    MonoIcon(
                        icon: isPlaying ? .pause : .play,
                        size: size * 0.22,
                        color: Color.white.opacity(0.94),
                        lineWidth: 2
                    )
                    .offset(x: isPlaying ? 0 : 1)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(DotMatrixPressStyle(scale: 0.92))
        .accessibilityLabel(isPlaying ? String(localized: "暂停") : String(localized: "action_play"))
    }

    private var signalAnimation: PixelGridAnimation {
        let preset: PixelGridPreset = isPlaying ? .orbit : .centerOut
        let base = preset.animation
        guard pixelColors.count == 9 else { return base }
        return (try? PixelGridAnimation(
            name: "\(base.name)-cover-palette",
            delays: base.delays,
            duration: base.duration,
            colors: pixelColors
        )) ?? base
    }
}

private struct DotMatrixOutlineShape: View {
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.white.opacity(0.035))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(accent, lineWidth: 0.8)
            }
    }
}

private struct DotMatrixPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
