// VinylTheme.swift
// Monologue Widget Extension

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 2. Vinyl Theme (黑胶)

private struct VinylWidgetAnimationFrame {
    let date: Date
    let isActive: Bool

    var time: TimeInterval {
        date.timeIntervalSinceReferenceDate
    }

    func recordRotationDegrees(base: Double) -> Double {
        guard isActive else { return base }
        return time * 42.0 + base
    }
}

private struct VinylWidgetAnimationTimeline<Content: View>: View {
    let isActive: Bool
    let fallbackDate: Date
    @ViewBuilder var content: (VinylWidgetAnimationFrame) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { context in
            let date = isActive ? context.date : fallbackDate
            content(VinylWidgetAnimationFrame(date: date, isActive: isActive))
        }
    }
}

struct VinylTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily
    @Environment(\.widgetContentMargins) private var widgetContentMargins

    private let shellColor = Color(hex: "0F1218")
    private let panelColor = Color(hex: "171B24")
    private let lineColor = Color.white.opacity(0.09)
    private let metalColor = Color(hex: "D9DDE4")
    private let dimTextColor = Color.white.opacity(0.66)

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    private var accentColor: Color {
        entry.isEmpty ? Color(hex: "C89B5B") : entry.dominantColor
    }

    private var accentSecondaryColor: Color {
        entry.isEmpty ? Color(hex: "745738") : entry.secondaryColor
    }

    private var isActivePlayback: Bool {
        entry.isPlaying || entry.isLoading
    }

    private var glossAngle: Double {
        let signature = [
            entry.songName,
            entry.artistName,
            entry.albumName,
            entry.sourceName
        ].joined(separator: "|")
        let hash = signature.unicodeScalars.reduce(0) { partial, scalar in
            (partial * 33 + Int(scalar.value)) % 360
        }
        return Double((hash + 28) % 360)
    }

    private struct BackgroundCoverageProfile {
        let heroGlowScale: CGFloat
        let heroGlowOffsetX: CGFloat
        let heroGlowOffsetY: CGFloat
        let ringScale: CGFloat
        let ringOffsetX: CGFloat
        let ringOffsetY: CGFloat
        let innerRingScale: CGFloat
        let accentCloudScale: CGFloat
        let accentCloudOffsetX: CGFloat
        let accentCloudOffsetY: CGFloat
        let guideWidthRatio: CGFloat
        let guideOffsetX: CGFloat
        let guideOffsetY: CGFloat
        let sheenWidthRatio: CGFloat
        let sheenHeightRatio: CGFloat
        let sheenOffsetX: CGFloat
        let sheenOffsetY: CGFloat
    }

    private var backgroundCoverageProfile: BackgroundCoverageProfile {
        switch family {
        case .systemSmall:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.12,
                heroGlowOffsetX: 0.20,
                heroGlowOffsetY: -0.22,
                ringScale: 1.00,
                ringOffsetX: 0.18,
                ringOffsetY: -0.12,
                innerRingScale: 0.74,
                accentCloudScale: 0.52,
                accentCloudOffsetX: -0.18,
                accentCloudOffsetY: 0.16,
                guideWidthRatio: 0.24,
                guideOffsetX: -0.18,
                guideOffsetY: 0.24,
                sheenWidthRatio: 0.72,
                sheenHeightRatio: 0.20,
                sheenOffsetX: -0.08,
                sheenOffsetY: -0.28
            )
        case .systemMedium:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.34,
                heroGlowOffsetX: 0.26,
                heroGlowOffsetY: -0.18,
                ringScale: 1.28,
                ringOffsetX: 0.24,
                ringOffsetY: -0.08,
                innerRingScale: 0.94,
                accentCloudScale: 0.62,
                accentCloudOffsetX: -0.24,
                accentCloudOffsetY: 0.18,
                guideWidthRatio: 0.30,
                guideOffsetX: -0.20,
                guideOffsetY: 0.22,
                sheenWidthRatio: 0.78,
                sheenHeightRatio: 0.18,
                sheenOffsetX: -0.05,
                sheenOffsetY: -0.26
            )
        case .systemLarge:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.58,
                heroGlowOffsetX: 0.30,
                heroGlowOffsetY: -0.14,
                ringScale: 1.52,
                ringOffsetX: 0.28,
                ringOffsetY: -0.04,
                innerRingScale: 1.10,
                accentCloudScale: 0.72,
                accentCloudOffsetX: -0.28,
                accentCloudOffsetY: 0.20,
                guideWidthRatio: 0.36,
                guideOffsetX: -0.22,
                guideOffsetY: 0.20,
                sheenWidthRatio: 0.84,
                sheenHeightRatio: 0.16,
                sheenOffsetX: -0.02,
                sheenOffsetY: -0.24
            )
        default:
            return BackgroundCoverageProfile(
                heroGlowScale: 1.12,
                heroGlowOffsetX: 0.20,
                heroGlowOffsetY: -0.22,
                ringScale: 1.00,
                ringOffsetX: 0.18,
                ringOffsetY: -0.12,
                innerRingScale: 0.74,
                accentCloudScale: 0.52,
                accentCloudOffsetX: -0.18,
                accentCloudOffsetY: 0.16,
                guideWidthRatio: 0.24,
                guideOffsetX: -0.18,
                guideOffsetY: 0.24,
                sheenWidthRatio: 0.72,
                sheenHeightRatio: 0.20,
                sheenOffsetX: -0.08,
                sheenOffsetY: -0.28
            )
        }
    }

    private var statusTitle: String {
        switch entry.playbackState {
        case .loading:
            return "缓冲中"
        case .playing:
            return "播放中"
        case .paused:
            return "已暂停"
        case .idle:
            return "未播放"
        }
    }

    private var tempoText: String {
        if let tempoBPM = entry.tempoBPM, tempoBPM > 0 {
            return "\(tempoBPM) BPM"
        }

        if entry.tempoIsAnalyzing {
            return "BPM ..."
        }

        return entry.isEmpty ? "BPM --" : "BPM --"
    }

    private var sourceText: String {
        if entry.isEmpty {
            return "未播放"
        }

        return entry.sourceName.isEmpty ? "未知来源" : entry.sourceName
    }

    private var smallSourceText: String {
        guard !entry.isEmpty else { return "-" }

        let normalizedSource = entry.sourceName.uppercased()
        if normalizedSource.contains("QQ") {
            return "Q"
        }
        if normalizedSource.contains("NETEASE") {
            return "N"
        }

        return String(entry.sourceName.prefix(1)).uppercased()
    }

    private var qualityDisplayText: String {
        entry.qualityText.isEmpty ? "--" : entry.qualityText
    }

    private var queueText: String {
        guard entry.queueIndex > 0, entry.queueCount > 0 else { return "--/--" }
        return "\(entry.queueIndex)/\(entry.queueCount)"
    }

    private var displayAlbumName: String {
        if entry.isEmpty {
            return "暂无专辑"
        }

        return entry.albumName.isEmpty ? "专辑信息缺失" : entry.albumName
    }

    private var playModeDisplayText: String {
        entry.playModeText.isEmpty ? "--" : entry.playModeText
    }

    private var displaySongName: String {
        entry.isEmpty ? "未在播放" : entry.songName
    }

    private var displayArtistName: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    private var contentInsets: EdgeInsets {
        let extraHorizontal: CGFloat
        let extraTop: CGFloat
        let extraBottom: CGFloat

        switch family {
        case .systemSmall:
            extraHorizontal = 8
            extraTop = 8
            extraBottom = 8
        case .systemMedium:
            extraHorizontal = 11
            extraTop = 14
            extraBottom = 15
        case .systemLarge:
            extraHorizontal = 12
            extraTop = 12
            extraBottom = 15
        default:
            extraHorizontal = 8
            extraTop = 8
            extraBottom = 8
        }

        return EdgeInsets(
            top: widgetContentMargins.top + extraTop,
            leading: widgetContentMargins.leading + extraHorizontal,
            bottom: widgetContentMargins.bottom + extraBottom,
            trailing: widgetContentMargins.trailing + extraHorizontal
        )
    }

    var body: some View {
        VinylWidgetAnimationTimeline(isActive: entry.isPlaying, fallbackDate: entry.date) { animationFrame in
            switch family {
            case .systemMedium:
                mediumLayout(animationFrame: animationFrame)
            case .systemLarge:
                largeLayout(animationFrame: animationFrame)
            default:
                smallLayout(animationFrame: animationFrame)
            }
        }
    }

    private func smallLayout(animationFrame: VinylWidgetAnimationFrame) -> some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - contentInsets.leading - contentInsets.trailing
            let contentHeight = geo.size.height - contentInsets.top - contentInsets.bottom
            let recordSize = min(contentHeight * 0.64, contentWidth * 0.42)

            ZStack {
                basePanel(cornerRadius: 24)
                    .frame(width: geo.size.width, height: geo.size.height)

                HStack(spacing: 8) {
                    ZStack(alignment: .topTrailing) {
                        VinylRecordView(
                            entry: entry,
                            size: recordSize,
                            accentColor: accentColor,
                            accentSecondaryColor: accentSecondaryColor,
                            glossAngle: glossAngle,
                            animationFrame: animationFrame
                        )

                        VinylTonearmView(
                            size: recordSize,
                            isActive: isActivePlayback,
                            metalColor: metalColor,
                            accentColor: accentColor
                        )
                        .frame(width: recordSize, height: recordSize)
                        .offset(x: recordSize * 0.01, y: recordSize * 0.015)
                    }
                    .frame(width: recordSize + 2, height: contentHeight)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            smallSourceBadge(title: smallSourceText)
                            Spacer(minLength: 2)
                            Text(qualityDisplayText)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(dimTextColor)
                        }

                        Spacer(minLength: 0)

                        Text(displaySongName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .contentTransition(.interpolate)

                        HStack(spacing: 4) {
                            playbackIndicator(height: 10, compact: true, animationFrame: animationFrame)
                            Text(displayArtistName)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(dimTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }

                        if !entry.isEmpty {
                            HStack(spacing: 5) {
                                transportButton(PreviousTrackIntent(), systemName: "backward.fill", diameter: 18, filled: false)
                                transportButton(TogglePlaybackIntent(), systemName: entry.controlSymbolName, diameter: 26, filled: true)
                                transportButton(NextTrackIntent(), systemName: "forward.fill", diameter: 18, filled: false)
                            }
                        } else {
                            Text(statusTitle)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(accentColor.opacity(0.92))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .background(recessedInfoPanel(cornerRadius: 18))
                }
                .padding(.top, contentInsets.top)
                .padding(.leading, contentInsets.leading)
                .padding(.bottom, contentInsets.bottom)
                .padding(.trailing, contentInsets.trailing)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func mediumLayout(animationFrame: VinylWidgetAnimationFrame) -> some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - contentInsets.leading - contentInsets.trailing
            let contentHeight = geo.size.height - contentInsets.top - contentInsets.bottom
            let recordSize = min(contentHeight * 0.71, contentWidth * 0.34)
            let recordStageWidth = recordSize + 20

            ZStack {
                basePanel(cornerRadius: 28)
                    .frame(width: geo.size.width, height: geo.size.height)

                VStack(alignment: .leading, spacing: 8) {
                    headerBadge(title: sourceText, compact: true)
                    .padding(.top, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .center, spacing: 12) {
                        mediumRecordStage(recordSize: recordSize, animationFrame: animationFrame)
                            .frame(width: recordStageWidth, height: recordSize + 18, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(displaySongName)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .contentTransition(.interpolate)

                            HStack(alignment: .top, spacing: 8) {
                                Text(displayArtistName)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(dimTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)

                                Spacer(minLength: 8)

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("队列")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(accentColor.opacity(0.95))
                                    Text(queueText)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(dimTextColor)
                                }
                            }

                            HStack(spacing: 8) {
                                playbackIndicator(height: 12, compact: false, animationFrame: animationFrame)

                                Text(statusTitle)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.84))

                                Spacer(minLength: 6)

                                Text(tempoText)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(dimTextColor)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(infoPanel(cornerRadius: 16))

                            Spacer(minLength: 0)

                            if !entry.isEmpty {
                                HStack(spacing: 0) {
                                    transportButton(PreviousTrackIntent(), systemName: "backward.fill", diameter: 21, filled: false)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    transportButton(TogglePlaybackIntent(), systemName: entry.controlSymbolName, diameter: 30, filled: true)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    transportButton(NextTrackIntent(), systemName: "forward.fill", diameter: 21, filled: false)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.horizontal, 2)
                                .padding(.top, 2)
                                .padding(.bottom, 3)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .offset(y: -4)
                    }
                }
                .padding(.top, contentInsets.top + 10)
                .padding(.leading, max(contentInsets.leading - 4, 0))
                .padding(.bottom, contentInsets.bottom + 10)
                .padding(.trailing, contentInsets.trailing)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func mediumRecordStage(recordSize: CGFloat, animationFrame: VinylWidgetAnimationFrame) -> some View {
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.045),
                            Color.white.opacity(0.018),
                            accentColor.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.03),
                                    accentColor.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(8)

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 4, height: recordSize * 0.72)
                .blur(radius: 3)
                .offset(x: 10, y: recordSize * 0.14)

            Circle()
                .fill(accentColor.opacity(0.10))
                .frame(width: recordSize * 0.82, height: recordSize * 0.82)
                .blur(radius: recordSize * 0.08)
                .offset(x: recordSize * 0.06, y: recordSize * 0.08)

            VinylRecordView(
                entry: entry,
                size: recordSize * 0.96,
                accentColor: accentColor,
                accentSecondaryColor: accentSecondaryColor,
                glossAngle: glossAngle,
                animationFrame: animationFrame
            )
            .offset(x: 6, y: 8)

            VinylTonearmView(
                size: recordSize * 0.96,
                isActive: isActivePlayback,
                metalColor: metalColor,
                accentColor: accentColor
            )
            .frame(width: recordSize * 0.96, height: recordSize * 0.96)
            .offset(x: 6, y: 8)
        }
    }

    private func largeLayout(animationFrame: VinylWidgetAnimationFrame) -> some View {
        GeometryReader { geo in
            let pad = contentInsets
            let w = geo.size.width - pad.leading - pad.trailing
            let h = geo.size.height - pad.top - pad.bottom
            let turntableWidth = w * 0.52
            let recordSize = min(turntableWidth - 16, h * 0.65)
            let coverSize: CGFloat = 72

            ZStack {
                basePanel(cornerRadius: 30)
                    .frame(width: geo.size.width, height: geo.size.height)

                HStack(alignment: .top, spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(lineColor, lineWidth: 1)
                            )

                        Circle()
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                            .frame(width: recordSize * 1.12, height: recordSize * 1.12)

                        ZStack(alignment: .topTrailing) {
                            VinylRecordView(
                                entry: entry,
                                size: recordSize,
                                accentColor: accentColor,
                                accentSecondaryColor: accentSecondaryColor,
                                glossAngle: glossAngle,
                                animationFrame: animationFrame
                            )

                            VinylTonearmView(
                                size: recordSize,
                                isActive: isActivePlayback,
                                metalColor: metalColor,
                                accentColor: accentColor
                            )
                            .frame(width: recordSize, height: recordSize)
                            .offset(x: recordSize * 0.01, y: recordSize * 0.015)
                        }
                    }
                    .frame(width: turntableWidth)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            if let data = entry.coverImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: coverSize, height: coverSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(accentColor.opacity(0.2))
                                    .frame(width: coverSize, height: coverSize)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayAlbumName)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(dimTextColor)
                                    .lineLimit(2)

                                HStack(spacing: 4) {
                                    headerBadge(title: sourceText, compact: true)
                                    Text(qualityDisplayText)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(accentColor.opacity(0.9))
                                }
                            }
                        }

                        Spacer().frame(height: 14)

                        Text(displaySongName)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .contentTransition(.interpolate)

                        Text(displayArtistName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(dimTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.top, 2)

                        if !entry.lyricText.isEmpty {
                            Text(entry.lyricText)
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(accentColor.opacity(0.75))
                                .italic()
                                .minimumScaleFactor(0.7)
                                .padding(.top, 8)
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            statBlock(title: "BPM", value: tempoText, compact: true)
                            statBlock(title: "模式", value: playModeDisplayText, compact: true)
                            statBlock(title: "队列", value: queueText, compact: true)
                        }
                        .padding(.bottom, 8)

                        HStack {
                            playbackIndicator(height: 12, compact: false, animationFrame: animationFrame)
                            Text(statusTitle)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.86))

                            Spacer(minLength: 4)

                            if !entry.isEmpty {
                                HStack(spacing: 8) {
                                    transportButton(PreviousTrackIntent(), systemName: "backward.fill", diameter: 22, filled: false)
                                    transportButton(TogglePlaybackIntent(), systemName: entry.controlSymbolName, diameter: 32, filled: true)
                                    transportButton(NextTrackIntent(), systemName: "forward.fill", diameter: 22, filled: false)
                                }
                            }
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, pad.top + 8)
                .padding(.bottom, pad.bottom + 6)
                .padding(.leading, pad.leading + 4)
                .padding(.trailing, pad.trailing + 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func transportButton<I: AppIntent>(
        _ intent: I,
        systemName: String,
        diameter: CGFloat,
        filled: Bool
    ) -> some View {
        Button(intent: intent) {
            ZStack {
                Circle()
                    .fill(
                        filled
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.98),
                                    accentSecondaryColor.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.05))
                    )

                Circle()
                    .stroke(Color.white.opacity(filled ? 0.10 : 0.12), lineWidth: 1)

                Image(systemName: systemName)
                    .font(.system(size: diameter * (filled ? 0.34 : 0.31), weight: .bold))
                    .foregroundStyle(filled ? shellColor : .white.opacity(0.88))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: diameter, height: diameter)
            .shadow(
                color: filled ? accentColor.opacity(0.32) : .black.opacity(0.16),
                radius: filled ? 12 : 6,
                x: 0,
                y: filled ? 6 : 3
            )
        }
        .buttonStyle(.plain)
    }

    private func playbackIndicator(height: CGFloat, compact: Bool, animationFrame: VinylWidgetAnimationFrame) -> some View {
        Group {
            if entry.isPlaying {
                PlaybackWave(
                    isActive: true,
                    barCount: compact ? 3 : 4,
                    color: accentColor.opacity(0.95),
                    height: height,
                    externalTime: animationFrame.time
                )
                    .frame(width: compact ? 12 : 18)
            } else {
                Image(systemName: entry.statusSymbolName)
                    .font(.system(size: compact ? 9 : 11, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.95))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }

    private func headerBadge(title: String, compact: Bool = false) -> some View {
        let dotSize: CGFloat = compact ? 5 : 6
        let horizontalPadding: CGFloat = compact ? 8 : 9
        let verticalPadding: CGFloat = compact ? 5 : 6

        return HStack(spacing: compact ? 5 : 6) {
            Circle()
                .fill(accentColor.opacity(0.95))
                .frame(width: dotSize, height: dotSize)
            Text(title)
                .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func smallSourceBadge(title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.94))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.10),
                                        accentColor.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }

    private func statBlock(title: String, value: String, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            Text(title)
                .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                .foregroundStyle(dimTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.system(size: compact ? 12 : 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func basePanel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        shellColor.opacity(0.96),
                        panelColor.opacity(0.98),
                        shellColor.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                panelDecoration(cornerRadius: cornerRadius)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.03),
                                Color.black.opacity(0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func panelDecoration(cornerRadius: CGFloat) -> some View {
        let profile = backgroundCoverageProfile

        return GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let minSide = min(width, height)
            let arcLineWidth = max(minSide * 0.010, 1)
            let ringDiameter = minSide * profile.ringScale
            let innerRingDiameter = minSide * profile.innerRingScale
            let guideWidth = width * profile.guideWidthRatio
            let heroGlowOpacity = entry.isEmpty ? 0.10 : 0.18

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.032),
                                .clear,
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: minSide * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.012),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: width * profile.sheenWidthRatio,
                        height: height * profile.sheenHeightRatio
                    )
                    .rotationEffect(.degrees(-14))
                    .blur(radius: minSide * 0.05)
                    .offset(x: width * profile.sheenOffsetX, y: height * profile.sheenOffsetY)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(heroGlowOpacity),
                                accentSecondaryColor.opacity(entry.isEmpty ? 0.05 : 0.10),
                                .clear
                            ],
                            center: .center,
                            startRadius: minSide * 0.06,
                            endRadius: minSide * 0.50
                        )
                    )
                    .frame(width: minSide * profile.heroGlowScale, height: minSide * profile.heroGlowScale)
                    .blur(radius: minSide * 0.08)
                    .offset(x: width * profile.heroGlowOffsetX, y: height * profile.heroGlowOffsetY)

                Circle()
                    .fill(accentSecondaryColor.opacity(0.05))
                    .frame(width: minSide * profile.accentCloudScale, height: minSide * profile.accentCloudScale)
                    .blur(radius: minSide * 0.11)
                    .offset(x: width * profile.accentCloudOffsetX, y: height * profile.accentCloudOffsetY)

                Circle()
                    .stroke(Color.white.opacity(0.032), lineWidth: 1)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .offset(x: width * profile.ringOffsetX, y: height * profile.ringOffsetY)

                Circle()
                    .stroke(Color.white.opacity(0.018), lineWidth: 1)
                    .frame(width: innerRingDiameter, height: innerRingDiameter)
                    .offset(
                        x: width * (profile.ringOffsetX + 0.02),
                        y: height * (profile.ringOffsetY + 0.01)
                    )

                Circle()
                    .trim(from: 0.09, to: 0.37)
                    .stroke(
                        AngularGradient(
                            colors: [
                                accentColor.opacity(0.20),
                                accentSecondaryColor.opacity(0.10),
                                .clear,
                                .clear
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter * 0.84, height: ringDiameter * 0.84)
                    .rotationEffect(.degrees(-22))
                    .offset(
                        x: width * (profile.ringOffsetX + 0.02),
                        y: height * (profile.ringOffsetY - 0.01)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: guideWidth, height: 1.2)

                    Capsule(style: .continuous)
                        .fill(accentSecondaryColor.opacity(0.13))
                        .frame(width: max(guideWidth * 0.58, 18), height: 1.6)
                }
                .offset(x: width * profile.guideOffsetX, y: height * profile.guideOffsetY)
            }
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private func infoPanel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(lineColor, lineWidth: 1)
            )
    }

    private func recessedInfoPanel(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .fill(
                LinearGradient(
                    colors: [
                        shellColor.opacity(0.76),
                        panelColor.opacity(0.90),
                        shellColor.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Simulating top-left dark inner shadow (bevel)
                shape.stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.45), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
            )
            .overlay(
                // Simulating bottom-right bright rim
                shape.stroke(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            )
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: entry.date)
    }
}

private struct VinylRecordView: View {
    let entry: NowPlayingEntry
    let size: CGFloat
    let accentColor: Color
    let accentSecondaryColor: Color
    let glossAngle: Double
    let animationFrame: VinylWidgetAnimationFrame

    /// 由整首歌播放进度派生的转角（18°/秒）：目标取本条 entry 展示结束时刻，
    /// 动画铺满 entry 间隔（时间线按 ≤2 秒网格生成），整曲匀速慢转不间断。
    private var rotationDegrees: Double {
        guard !entry.isEmpty else { return glossAngle }
        let targetTime = max(0, entry.playbackCurrentTime) + (entry.isPlaying ? max(0, entry.entryDisplayDuration) : 0)
        return targetTime * 18 + glossAngle
    }

    private var rotationAnimation: Animation {
        entry.isPlaying
            ? .linear(duration: min(2.0, max(0.1, entry.entryDisplayDuration)))
            : .snappy(duration: 0.4)
    }

    private var discPlate: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "3A3E47"), Color(hex: "1A1C22")],
                        center: .center, startRadius: size * 0.38, endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: size * 0.008)
                .frame(width: size * 0.985, height: size * 0.985)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "2A2E35"), Color(hex: "17191F"), Color(hex: "0E1014")],
                        center: .center, startRadius: size * 0.08, endRadius: size * 0.48
                    )
                )
                .frame(width: size * 0.94, height: size * 0.94)

            VinylGrooveView()
                .padding(size * 0.11)
                .frame(width: size * 0.94, height: size * 0.94)

            Circle()
                .trim(from: 0.08, to: 0.31)
                .stroke(accentColor.opacity(0.46),
                        style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round))
                .frame(width: size * 0.76, height: size * 0.76)
                .rotationEffect(.degrees(glossAngle * 0.68 + 18))
                .blur(radius: 0.2)

            VinylLabelView(
                entry: entry, size: size * 0.42,
                accentColor: accentColor, accentSecondaryColor: accentSecondaryColor
            )

            Circle().fill(Color(hex: "F3E3D2").opacity(0.94))
                .frame(width: size * 0.050, height: size * 0.050)
            Circle().fill(Color.black.opacity(0.86))
                .frame(width: size * 0.020, height: size * 0.020)
        }
    }

    private func glossRing(angle: Angle) -> some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.white.opacity(0.28), .clear, .white.opacity(0.12),
                                 .clear, .white.opacity(0.20), .clear],
                        center: .center
                    ),
                    lineWidth: size * 0.022
                )
                .frame(width: size * 0.92, height: size * 0.92)
                .rotationEffect(angle)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size * 0.014, height: size * 0.26)
                .offset(y: -size * 0.30)
                .rotationEffect(angle + .degrees(90))
        }
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.5), .clear],
                        center: .center, startRadius: size * 0.1, endRadius: size * 0.44
                    )
                )
                .frame(width: size * 1.05, height: size * 0.34)
                .offset(y: size * 0.40)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.6), .clear],
                        center: .center, startRadius: size * 0.05, endRadius: size * 0.31
                    )
                )
                .frame(width: size * 0.72, height: size * 0.18)
                .offset(y: size * 0.43)

            ZStack {
                discPlate
                glossRing(angle: .degrees(rotationDegrees))
            }
            .rotationEffect(.degrees(rotationDegrees))
            .animation(rotationAnimation, value: rotationDegrees)
        }
        .frame(width: size, height: size)
    }
}

private struct VinylGrooveView: View {
    var body: some View {
        Canvas { context, canvasSize in
            let minSide = min(canvasSize.width, canvasSize.height)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let innerRadius = minSide * 0.18
            let outerRadius = minSide * 0.49
            let ringCount = 26

            for index in 0..<ringCount {
                let progress = CGFloat(index) / CGFloat(ringCount - 1)
                let radius = innerRadius + (outerRadius - innerRadius) * progress
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                var path = Path()
                path.addEllipse(in: rect)

                context.stroke(
                    path,
                    with: .color(.white.opacity(0.15 - Double(progress) * 0.09)),
                    lineWidth: progress < 0.48 ? 0.55 : 0.8
                )
            }
        }
    }
}

private struct VinylLabelView: View {
    let entry: NowPlayingEntry
    let size: CGFloat
    let accentColor: Color
    let accentSecondaryColor: Color

    private var labelTitle: String {
        if entry.isEmpty {
            return "未播放"
        }

        return entry.sourceName.isEmpty ? "未知来源" : entry.sourceName
    }

    private var labelSubtitle: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    private var labelFooter: String {
        if let tempoBPM = entry.tempoBPM, tempoBPM > 0 {
            return "\(tempoBPM) BPM"
        }

        if entry.tempoIsAnalyzing {
            return "BPM ..."
        }

        if !entry.qualityText.isEmpty {
            return entry.qualityText
        }

        return "BPM --"
    }

    var body: some View {
        ZStack {
            if let data = entry.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.92, height: size * 0.92)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.clear,
                                        Color.black.opacity(0.12),
                                        Color.black.opacity(0.30)
                                    ],
                                    center: .center,
                                    startRadius: size * 0.02,
                                    endRadius: size * 0.48
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.96),
                                accentSecondaryColor.opacity(0.84),
                                accentColor.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            Circle()
                .stroke(Color.black.opacity(0.20), lineWidth: 4)
                .padding(4)

            Circle()
                .stroke(accentColor.opacity(0.24), lineWidth: 1.2)
                .padding(size * 0.08)

            VStack(spacing: size * 0.035) {
                Text(labelTitle)
                    .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Capsule(style: .continuous)
                    .fill(.white.opacity(0.42))
                    .frame(width: size * 0.40, height: 1.5)

                Text(labelSubtitle)
                    .font(.system(size: size * 0.085, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, size * 0.10)

                Text(labelFooter)
                    .font(.system(size: size * 0.078, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .shadow(color: .black.opacity(0.26), radius: 5, x: 0, y: 1)

            Circle()
                .fill(Color(hex: "F5E6D8").opacity(0.95))
                .frame(width: size * 0.16, height: size * 0.16)

            Circle()
                .fill(Color.black.opacity(0.82))
                .frame(width: size * 0.06, height: size * 0.06)
        }
        .frame(width: size, height: size)
    }
}

private struct VinylTonearmView: View {
    let size: CGFloat
    let isActive: Bool
    let metalColor: Color
    let accentColor: Color

    private var pivotDiameter: CGFloat {
        size * 0.115
    }

    private var armLength: CGFloat {
        size * 0.485
    }

    private var armThickness: CGFloat {
        size * 0.041
    }

    private var restingAngle: Double {
        18.0
    }

    private var activeAngle: Double {
        -7.5
    }

    private var angle: Double {
        isActive ? activeAngle : restingAngle
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "6E7582"),
                            Color(hex: "3A3F48")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: pivotDiameter, height: pivotDiameter)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .fill(Color.black.opacity(0.26))
                        .frame(width: pivotDiameter * 0.28, height: pivotDiameter * 0.28)
                )
                .shadow(color: .black.opacity(0.18), radius: size * 0.018, x: 0, y: size * 0.012)

            ZStack(alignment: .trailing) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.20))
                    .frame(width: armLength * 0.96, height: armThickness * 0.62)
                    .blur(radius: size * 0.008)
                    .offset(x: -size * 0.032, y: size * 0.012)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                metalColor.opacity(0.96),
                                Color(hex: "7A808B"),
                                Color(hex: "C1C6D0")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: armLength, height: armThickness)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .padding(size * 0.005)
                            .mask(
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .frame(width: size * 0.26, height: size * 0.012)
                    .offset(x: -size * 0.08)

                RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                    .fill(accentColor.opacity(0.96))
                    .frame(width: size * 0.046, height: size * 0.031)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .offset(x: size * 0.008)
            }
            .rotationEffect(.degrees(angle), anchor: .topTrailing)
            .offset(x: -size * 0.030, y: size * 0.058)
        }
        .frame(width: size, height: size, alignment: .topTrailing)
    }
}
