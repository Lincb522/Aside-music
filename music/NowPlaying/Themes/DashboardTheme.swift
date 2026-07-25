import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Dashboard Theme (仪表盘)

struct DashboardTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    // 色彩系统 — 深色仪表盘
    private let bgColor = Color(hex: "1C1C1E")
    private let cardBg = Color(hex: "242428")
    private let pillBg = Color.white.opacity(0.06)
    private let textWhite = Color.white
    private let textGray = Color(hex: "98989D")
    private let accentBar = Color(hex: "FF9F0A") // 橙黄色竖条
    private let indicatorDot = Color(hex: "8B6914") // 偏深金/棕色指示点
    private let btnColor = Color(hex: "7C7C80") // 未激活按钮颜色

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    private var song: String { entry.isEmpty ? "Dashboard" : entry.songName }
    private var artist: String { entry.isEmpty ? "Not Playing" : entry.artistName }
    private var displayLyric: String { entry.lyricText.isEmpty ? "" : entry.lyricText }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge:  largeLayout
        default:            smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let coverSize: CGFloat = min(w * 0.42, h * 0.38)

            VStack(spacing: 0) {
                // 上半部：封面 + 标签
                HStack(alignment: .top, spacing: 8) {
                    // 凹陷封面
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cardBg)
                            .frame(width: coverSize, height: coverSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )

                        if let data = entry.coverImageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: coverSize - 6, height: coverSize - 6)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(textGray.opacity(0.4))
                        }
                    }

                    // 右侧标签
                    VStack(alignment: .trailing, spacing: 6) {
                        // 音质标签
                        dashboardPill(
                            icon: "music.note",
                            text: entry.qualityText.isEmpty ? "Standard" : entry.qualityText
                        )

                        // 播放模式标签
                        dashboardPill(
                            icon: "play.fill",
                            text: entry.playModeText.isEmpty ? "顺序" : entry.playModeText
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer(minLength: 4)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(song)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(textWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    HStack(spacing: 5) {
                        // 橙色竖条
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentBar)
                            .frame(width: 2.5, height: 12)

                        Text(artist)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(textGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

                Spacer(minLength: 4)

                // 底部控制按钮
                if !entry.isEmpty {
                    HStack(spacing: 0) {
                        dashboardBtn(intent: PreviousTrackIntent(), icon: "backward.fill")
                        dashboardBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, isMain: true)
                        dashboardBtn(intent: NextTrackIntent(), icon: "forward.fill")

                        Spacer()

                        DashboardActivityDot(isActive: entry.isPlaying, color: indicatorDot, size: 6)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 12)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let coverSize: CGFloat = h - 24

            HStack(spacing: 0) {
                // 左侧封面
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardBg)
                        .frame(width: coverSize, height: coverSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )

                    if let data = entry.coverImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize - 8, height: coverSize - 8)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(textGray.opacity(0.4))
                    }
                }
                .padding(.leading, 14)

                // 右侧
                VStack(alignment: .leading, spacing: 0) {
                    // 标签
                    HStack(spacing: 6) {
                        dashboardPill(icon: "music.note", text: entry.qualityText.isEmpty ? "Standard" : entry.qualityText)
                        dashboardPill(icon: "play.fill", text: entry.playModeText.isEmpty ? "顺序" : entry.playModeText)
                        Spacer()
                        DashboardActivityDot(isActive: entry.isPlaying, color: indicatorDot, size: 6)
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 4)

                    // 歌曲信息
                    Text(song)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(textWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentBar)
                            .frame(width: 2.5, height: 12)
                        Text(artist)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(textGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)
                    }
                    .padding(.top, 2)

                    // 歌词滚动框 (独特跑马灯切入动画)
                    if !displayLyric.isEmpty {
                        Text(displayLyric)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentBar)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(cardBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                    )
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .id(displayLyric)
                            .clipped() // 防止滑动时溢出
                    }

                    Spacer(minLength: 4)

                    // 按钮
                    if !entry.isEmpty {
                        HStack(spacing: 0) {
                            dashboardBtn(intent: PreviousTrackIntent(), icon: "backward.fill")
                            dashboardBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, isMain: true)
                            dashboardBtn(intent: NextTrackIntent(), icon: "forward.fill")
                        }
                        .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let coverSize: CGFloat = min(w * 0.45, 150) // 左侧中等偏大封面

            VStack(spacing: 0) {
                // 上半部分：分栏布局 (类似中控双屏)
                HStack(alignment: .top, spacing: 16) {
                    // 左侧：封面
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBg)
                            .frame(width: coverSize, height: coverSize)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))

                        if let data = entry.coverImageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: coverSize - 10, height: coverSize - 10)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(textGray.opacity(0.4))
                        }
                    }

                    // 右侧：信息与标签
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部标签区
                        HStack(spacing: 6) {
                            dashboardPill(icon: "music.note", text: entry.qualityText.isEmpty ? "Standard" : entry.qualityText)
                            dashboardPill(icon: "play.fill", text: entry.playModeText.isEmpty ? "顺序" : entry.playModeText)
                            Spacer(minLength: 0)
                            DashboardActivityDot(isActive: entry.isPlaying, color: indicatorDot, size: 8)
                        }

                        Spacer(minLength: 10)

                        // 歌曲名
                        Text(song)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(textWhite)
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)
                            .padding(.bottom, 6)

                        // 歌手名
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(accentBar)
                                .frame(width: 3, height: 14)
                            Text(artist)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(textGray)
                                .lineLimit(2)
                                .minimumScaleFactor(0.4)
                                .contentTransition(.interpolate)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(height: coverSize, alignment: .top) // 让右侧与封面等高
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer(minLength: 16)

                // 中间部分：巨大的歌词遥测面板
                if !displayLyric.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "teletype")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(accentBar.opacity(0.8))
                            Text("LYRICS_TELEMETRY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(textGray.opacity(0.8))
                        }

                        Text(displayLyric)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(textWhite.opacity(0.95))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8) // 保证缩放不缩略
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1) // 防止外部布局挤压缩略
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .id(displayLyric)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: w - 40, alignment: .topLeading) // 强制全宽，优先保证文本不被截断
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cardBg.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 1))
                    )
                }

                Spacer(minLength: 16)

                // 底部部分：超宽扁平控制栏
                if !entry.isEmpty {
                    HStack(spacing: 0) {
                        dashboardBtn(intent: PreviousTrackIntent(), icon: "backward.fill", btnW: 60, btnH: 44, iconSize: 18)
                        Spacer()
                        dashboardBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, isMain: true, btnW: 100, btnH: 44, iconSize: 26)
                        Spacer()
                        dashboardBtn(intent: NextTrackIntent(), icon: "forward.fill", btnW: 60, btnH: 44, iconSize: 18)
                    }
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.04), lineWidth: 1))
                    .padding(.horizontal, 30)
                    .padding(.bottom, 24)
                } else {
                    Spacer().frame(height: 24)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - 胶囊标签

    private func dashboardPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .foregroundStyle(textWhite.opacity(0.75))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(pillBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    // MARK: - 扁平控制按钮

    private func dashboardBtn<I: AppIntent>(intent: I, icon: String, isMain: Bool = false, btnW: CGFloat = 36, btnH: CGFloat = 28, iconSize: CGFloat = 14) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: isMain ? iconSize + 4 : iconSize, weight: .semibold))
                .foregroundStyle(isMain ? textWhite : btnColor)
                .frame(width: btnW, height: btnH)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardActivityDot: View {
    let isActive: Bool
    let color: Color
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            let pulse = isActive
                ? (sin(timeline.date.timeIntervalSinceReferenceDate * 3.4) + 1.0) * 0.5
                : 0.0

            Circle()
                .fill(color.opacity(0.72 + 0.28 * pulse))
                .frame(width: size, height: size)
                .scaleEffect(CGFloat(1.0 + 0.14 * pulse))
                .shadow(color: Color.black.opacity(0.8), radius: 1, x: 0, y: 1)
                .shadow(color: color.opacity(0.22 + 0.36 * pulse), radius: CGFloat(2 + 3 * pulse))
        }
    }
}
