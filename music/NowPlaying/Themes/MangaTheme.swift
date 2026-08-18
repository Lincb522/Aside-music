import AppIntents
import SwiftUI
import WidgetKit

// MARK: - 漫画主题 · 彩色印刷
//
// 暖纸底 + 粉黄蓝印刷色的彩色漫画分格。
// 厚墨框 + 硬投影 + 网点渐晕，封面恢复彩色，
// 播放按钮做成粉色印泥章。
// 仅用于桌面小组件，与 App 内漫画播放器主题相互独立。

struct MangaTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private var ink: Color { Color(hex: "2D2D3A") }
    private var inkSoft: Color { Color(hex: "8888A0") }
    private var paper: Color { Color(hex: "FFF8EC") }
    private var tone: Color { Color(hex: "FFE8F0") }
    private var pink: Color { Color(hex: "FF8FAB") }
    private var pinkDeep: Color { Color(hex: "D86782") }
    private var yellow: Color { Color(hex: "FFE4B5") }
    private var blue: Color { Color(hex: "B8D4F0") }
    private var blueDeep: Color { Color(hex: "6A98BD") }

    private var song: String {
        entry.isEmpty ? "未在播放" : entry.songName
    }

    private var artist: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    private var lyric: String {
        entry.lyricText.isEmpty ? "              " : entry.lyricText
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallWidget
            case .systemMedium:
                mediumWidget
            case .systemLarge:
                largeWidget
            default:
                smallWidget
            }
        }
        .foregroundStyle(ink)
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Small

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    coverPanel(size: 62, border: 2.6, shadow: 3)
                        .rotationEffect(.degrees(-2.5))

                    playStamp(size: 28, iconSize: 10)
                        .offset(x: 6, y: 6)
                }

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    sfxBurst(size: 20)

                    if entry.queueCount > 0 {
                        queueSticker(fontSize: 8.5)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(song)
                .font(.system(size: 14, weight: .black))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text(artist)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(pinkDeep)
                    .lineLimit(1)

                Spacer(minLength: 0)

                statusChip
            }
        }
        .padding(12)
        .background(printPaper)
    }

    // MARK: - Medium

    private var mediumWidget: some View {
        HStack(spacing: 13) {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottomTrailing) {
                    coverPanel(size: 106, border: 3, shadow: 4)
                        .rotationEffect(.degrees(-2))

                    playStamp(size: 34, iconSize: 12)
                        .offset(x: 8, y: 8)
                }

                sfxBurst(size: 24)
                    .offset(x: -9, y: -9)
            }
            .frame(width: 120)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    statusChip

                    if entry.queueCount > 0 {
                        queueSticker(fontSize: 9)
                    }

                    if !entry.qualityText.isEmpty {
                        qualitySticker(entry.qualityText)
                    }
                }

                Text(song)
                    .font(.system(size: 19, weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(lyric)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if entry.isPlaying {
                        PlaybackWave(isActive: true, barCount: 4, color: pinkDeep, height: 11)
                            .frame(width: 20)
                    }

                    MangaHatchStrip(color: pink, opacity: 0.9)
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(printPaper)
    }

    // MARK: - Large

    private var largeWidget: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                coverPanel(size: 150, border: 3.2, shadow: 5)
                    .rotationEffect(.degrees(-1.6))

                sfxBurst(size: 30)
                    .offset(x: -11, y: -11)
            }
            .padding(.top, 6)

            VStack(spacing: 3) {
                Text(song)
                    .font(.system(size: 21, weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)

                Text(lyric)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                statusChip

                if entry.queueCount > 0 {
                    queueSticker(fontSize: 9.5)
                }

                if !entry.qualityText.isEmpty {
                    qualitySticker(entry.qualityText)
                }
            }

            playbackRow
        }
        .padding(12)
        .background(printPaper)
    }

    // MARK: - 组件

    /// 暖纸印刷底：纸色 + 粉蓝网点渐晕。
    private var printPaper: some View {
        ZStack {
            paper

            MangaPrintDots(color: pinkDeep, opacity: 0.08, gap: 8)
                .mask(RadialGradient(colors: [.black, .clear], center: .topTrailing, startRadius: 0, endRadius: 130))

            MangaPrintDots(color: blueDeep, opacity: 0.10, gap: 7)
                .mask(RadialGradient(colors: [.black, .clear], center: .bottomLeading, startRadius: 0, endRadius: 110))
        }
    }

    /// 彩色封面分格：厚墨框 + 白网点 + 墨色硬投影。
    private func coverPanel(size: CGFloat, border: CGFloat, shadow: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return ZStack {
            shape
                .fill(ink)
                .offset(x: shadow, y: shadow)

            if let data = entry.coverImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(shape)
            } else {
                shape
                    .fill(tone)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.34, weight: .black))
                            .foregroundStyle(pink)
                    )
            }

            MangaPrintDots(color: .white, opacity: 0.10, gap: 7)
                .frame(width: size, height: size)
                .clipShape(shape)

            shape.stroke(ink, lineWidth: border)

            shape
                .stroke(ink.opacity(0.9), lineWidth: 1)
                .padding(4)
        }
        .frame(width: size, height: size)
    }

    /// 粉色印泥章播放钮：墨影托底 + 反白符号，点按切播放状态。
    private func playStamp(size: CGFloat, iconSize: CGFloat) -> some View {
        Button(intent: TogglePlaybackIntent()) {
            ZStack {
                Circle()
                    .fill(ink)
                    .offset(x: size * 0.07, y: size * 0.07)

                Circle().fill(pink)
                Circle().stroke(ink, lineWidth: max(2, size * 0.075))
                Circle().stroke(Color.white.opacity(0.65), lineWidth: 1).padding(size * 0.13)

                Image(systemName: entry.controlSymbolName)
                    .font(.system(size: iconSize, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }

    /// 播放控制行：排线 + 粉色印泥章。
    private var playbackRow: some View {
        HStack(spacing: 14) {
            MangaHatchStrip(color: blue, opacity: 0.8)
                .frame(width: 40, height: 6)

            playStamp(size: 42, iconSize: 15)

            MangaHatchStrip(color: blue, opacity: 0.8)
                .frame(width: 40, height: 6)
        }
    }

    /// 拟声爆炸贴：粉爆形 + 反白音符，背后压黄色错版。
    private func sfxBurst(size: CGFloat) -> some View {
        ZStack {
            MangaBurst(points: 11, innerRatio: 0.72)
                .fill(yellow)
                .offset(x: 2, y: 2)

            MangaBurst(points: 11, innerRatio: 0.72)
                .fill(pink)

            MangaBurst(points: 11, innerRatio: 0.72)
                .stroke(ink, lineWidth: 1.6)

            Text("♪")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-8))
    }

    /// 状态贴纸：白底墨框 + 状态色圆点。
    private var statusChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.isPlaying ? pink : inkSoft)
                .frame(width: 5, height: 5)

            Text(entry.isPlaying ? "播放中" : "暂停")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(entry.isPlaying ? pinkDeep : inkSoft)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white, in: Capsule())
        .overlay(Capsule().stroke(ink, lineWidth: 1.2))
        .background(Capsule().fill(ink).offset(x: 1.4, y: 1.4))
    }

    /// 队列序贴：黄底墨字 + 圆角硬影。
    private func queueSticker(fontSize: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)

        return Text("\(min(entry.queueIndex, entry.queueCount))/\(entry.queueCount)")
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(shape.fill(yellow))
            .overlay(shape.stroke(ink, lineWidth: 1.4))
            .background(shape.fill(ink).offset(x: 1.6, y: 1.6))
            .rotationEffect(.degrees(2))
    }

    /// 音质贴纸：蓝底墨字。
    private func qualitySticker(_ text: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)

        return Text(text)
            .font(.system(size: 8, weight: .heavy))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(shape.fill(blue))
            .overlay(shape.stroke(ink, lineWidth: 1.2))
            .background(shape.fill(ink).offset(x: 1.4, y: 1.4))
    }
}

// MARK: - 形状

private struct MangaBurst: Shape {
    var points: Int = 12
    var innerRatio: CGFloat = 0.68

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = .pi / CGFloat(points)
        for i in 0 ..< points * 2 {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = step * CGFloat(i) - .pi / 2
            let pt = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

/// 交错排列的印刷网点。
private struct MangaPrintDots: View {
    var color: Color
    var opacity: Double
    var gap: CGFloat
    var dotScale: CGFloat = 0.24

    var body: some View {
        Canvas { context, size in
            let dot = gap * dotScale
            var y: CGFloat = gap / 2
            var row = 0
            while y < size.height {
                var x: CGFloat = gap / 2 + (row.isMultiple(of: 2) ? 0 : gap / 2)
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                        with: .color(color.opacity(opacity))
                    )
                    x += gap
                }
                y += gap
                row += 1
            }
        }
        .allowsHitTesting(false)
    }
}

/// 斜向排线条（漫画速度线式装饰）。
private struct MangaHatchStrip: View {
    var color: Color
    var opacity: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 4
            }
            context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("S", as: .systemSmall) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry.preview(theme: .manga)
}
