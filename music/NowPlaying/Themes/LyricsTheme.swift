import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Lyrics Theme (歌词)

struct LyricsWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    /// 磨砂封面背景：封面放大重模糊，左上主色晕染定光向，下部压暗保白字。
    static func background(for entry: NowPlayingEntry) -> some View {
        ZStack {
            if let data = entry.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.4)
                    .blur(radius: 40, opaque: true)
                    .saturation(1.25)
            } else {
                LinearGradient(
                    colors: entry.isEmpty
                        ? [Color(hex: "1C1E26"), Color(hex: "0D0E13")]
                        : [entry.secondaryColor, entry.dominantColor.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [
                    entry.dominantColor.opacity(entry.isEmpty ? 0 : 0.32),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.38),
                    Color.black.opacity(0.54),
                    Color.black.opacity(0.76)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// 装饰强调色：仅用于引号/侧栏/进度等非正文元素，正文保持白色对比度
    private var accent: Color {
        entry.isEmpty ? Color(hex: "8FA8FF") : entry.dominantColor
    }

    private var displayCurrentLine: String {
        if entry.isEmpty { return "未在播放" }
        return entry.lyricText.isEmpty ? entry.songName : entry.lyricText
    }

    private var hasSyncedLyrics: Bool { entry.lyricCount > 0 }

    private var progressInterval: ClosedRange<Date>? {
        guard entry.playbackDuration > 0 else { return nil }
        let start = entry.playbackReferenceDate.addingTimeInterval(-entry.playbackCurrentTime)
        let end = start.addingTimeInterval(entry.playbackDuration)
        guard start < end else { return nil }
        return start...end
    }

    /// 歌词整体进度（0-1），用于小尺寸底部的位置刻度
    private var lyricProgress: CGFloat {
        guard hasSyncedLyrics, entry.lyricIndex >= 0, entry.lyricCount > 1 else { return 0 }
        return CGFloat(entry.lyricIndex) / CGFloat(entry.lyricCount - 1)
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium: mediumLayout
            case .systemLarge: largeLayout
            default: smallLayout
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Small

    /// 小尺寸：诗签。强调色巨引号压角，衬线歌词居中偏左，
    /// 底部歌名前置强调色短杠，刻度线右端悬浮动态波形。
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                quoteMark(size: 34)
                Spacer(minLength: 6)
                playbackGlyph(size: 10)
                    .padding(.top, 2)
            }

            Spacer(minLength: 2)

            lyricBlock(
                currentSize: 17,
                currentLineLimit: 4,
                lineSpacing: 3,
                showPrev: false,
                showNext: false,
                showTranslation: false
            )

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 10, height: 2.4)
                    Text(entry.isEmpty ? "Mono" : entry.songName)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                lyricTrack(height: 2.5)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }

    // MARK: - Medium

    /// 中尺寸：侧栏歌词条。强调色渐变竖杠作视觉锚，歌词与下一句沿杠排布，
    /// 头部信息与控制键收窄，让正文成为绝对主角。
    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    CoverImage(data: entry.coverImageData, radius: 7)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                        )

                    Text(entry.isEmpty ? "未在播放" : entry.songName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)

                    Text(entry.isEmpty ? "" : "· \(entry.artistName)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !entry.isEmpty {
                        controlButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, diameter: 28, iconSize: 11, prominent: true)
                        controlButton(intent: NextTrackIntent(), icon: "forward.fill", diameter: 28, iconSize: 10, prominent: false)
                    }
                }

                Spacer(minLength: 7)

                lyricBlock(
                    currentSize: 19,
                    currentLineLimit: 2,
                    lineSpacing: 2,
                    showPrev: false,
                    showNext: true,
                    showTranslation: false
                )

                Spacer(minLength: 9)

                progressBar(height: 2.5)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }

    // MARK: - Large

    /// 大尺寸：杂志内页。巨型强调色引号衬底，衬线大字 + 翻译 + 前后句，
    /// 底部控制键与「句号 / 总句数」徽章分列两端。
    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 11) {
                CoverImage(data: entry.coverImageData, radius: 11)
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.isEmpty ? "未在播放" : entry.songName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.isEmpty ? "Mono" : entry.artistName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                playbackGlyph(size: 13)
            }

            Spacer(minLength: 6)

            lyricBlock(
                currentSize: 24,
                currentLineLimit: 3,
                lineSpacing: 4,
                showPrev: true,
                showNext: true,
                showTranslation: true
            )
            .background(alignment: .topLeading) {
                quoteMark(size: 78)
                    .opacity(0.5)
                    .offset(x: -6, y: -30)
            }
            .padding(.top, 22)

            Spacer(minLength: 10)

            if !entry.isEmpty {
                HStack(spacing: 0) {
                    HStack(spacing: 13) {
                        controlButton(intent: PreviousTrackIntent(), icon: "backward.fill", diameter: 35, iconSize: 12, prominent: false)
                        controlButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, diameter: 44, iconSize: 16, prominent: true)
                        controlButton(intent: NextTrackIntent(), icon: "forward.fill", diameter: 35, iconSize: 12, prominent: false)
                    }

                    Spacer(minLength: 12)

                    if hasSyncedLyrics, entry.lyricIndex >= 0 {
                        Text("\(entry.lyricIndex + 1) / \(entry.lyricCount)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.66))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                    }
                }
                .padding(.bottom, 12)
            }

            progressBar(height: 3)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
    }

    // MARK: - Shared Pieces

    /// 歌词块：上一句 / 当前句（衬线大字）/ 翻译 / 下一句。
    /// 前后句沿一条微弱的时间线排布；以 lyricIndex 作身份触发推入过渡。
    @ViewBuilder
    private func lyricBlock(
        currentSize: CGFloat,
        currentLineLimit: Int,
        lineSpacing: CGFloat,
        showPrev: Bool,
        showNext: Bool,
        showTranslation: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if showPrev, !entry.prevLyricText.isEmpty {
                neighborLine(entry.prevLyricText)
            }

            Text(displayCurrentLine)
                .font(.system(size: currentSize, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(lineSpacing)
                .lineLimit(currentLineLimit)
                .minimumScaleFactor(0.58)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.4), radius: 5, y: 2)

            if showTranslation, !entry.lyricTranslation.isEmpty {
                Text(entry.lyricTranslation)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }

            if showNext, !entry.nextLyricText.isEmpty {
                neighborLine(entry.nextLyricText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id("lyricBlock-\(entry.lyricIndex)-\(entry.lyricText)")
        .transition(.push(from: .bottom).combined(with: .opacity))
    }

    /// 前后句：强调色小圆点引导的暗色行，衬出当前句的层级
    private func neighborLine(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent.opacity(0.75))
                .frame(width: 3.5, height: 3.5)
            Text(text)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
        }
    }

    /// 装饰引号：强调色渐变，衬线黑体
    private func quoteMark(size: CGFloat) -> some View {
        Text("\u{201C}")
            .font(.system(size: size, weight: .black, design: .serif))
            .foregroundStyle(
                LinearGradient(
                    colors: [accent, accent.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .brightness(0.18)
            .saturation(1.15)
            .frame(height: size * 0.52, alignment: .top)
            .clipped()
    }

    /// 播放状态图形（波形/音符/沙漏）
    private func playbackGlyph(size: CGFloat) -> some View {
        Image(systemName: entry.statusSymbolName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: entry.isPlaying)
            .contentTransition(.symbolEffect(.replace))
    }

    private func controlButton<I: AppIntent>(
        intent: I,
        icon: String,
        diameter: CGFloat,
        iconSize: CGFloat,
        prominent: Bool
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(prominent ? Color.black.opacity(0.85) : .white.opacity(0.85))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: diameter, height: diameter)
                .background(
                    Circle()
                        .fill(prominent ? AnyShapeStyle(Color.white.opacity(0.92)) : AnyShapeStyle(Color.white.opacity(0.14)))
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(prominent ? 0 : 0.18), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    /// 歌词位置刻度（小尺寸底部）：当前句在整首歌词中的位置，
    /// 亮段用强调色→白渐变，刻度头一颗光点。
    @ViewBuilder
    private func lyricTrack(height: CGFloat) -> some View {
        if hasSyncedLyrics {
            GeometryReader { geo in
                let filled = max(height, geo.size.width * lyricProgress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.9), .white.opacity(0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: filled)
                    Circle()
                        .fill(Color.white)
                        .frame(width: height * 1.8, height: height * 1.8)
                        .offset(x: filled - height * 0.9)
                        .shadow(color: .white.opacity(0.6), radius: 2)
                }
            }
            .frame(height: height)
        } else {
            progressBar(height: height)
        }
    }

    @ViewBuilder
    private func progressBar(height: CGFloat) -> some View {
        if entry.isEmpty || entry.playbackDuration <= 0 {
            EmptyView()
        } else if entry.isPlaying, let interval = progressInterval {
            ProgressView(timerInterval: interval, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.linear)
                .tint(.white.opacity(0.85))
                .frame(height: height)
        } else {
            ProgressView(value: min(max(entry.playbackCurrentTime / entry.playbackDuration, 0), 1))
                .progressViewStyle(.linear)
                .tint(.white.opacity(0.85))
                .frame(height: height)
        }
    }
}
