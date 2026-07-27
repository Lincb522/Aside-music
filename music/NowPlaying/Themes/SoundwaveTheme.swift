import WidgetKit
import SwiftUI
import AppIntents

// MARK: - SoundwaveTheme (声波主题)

struct SoundwaveTheme: View {
    var entry: NowPlayingEntry
    var family: WidgetFamily

    private var song: String {
        return entry.songName.isEmpty ? "Mono" : entry.songName
    }

    private var artist: String {
        return entry.artistName.isEmpty ? "聆听你的声音" : entry.artistName
    }

    private var displayLyric: String {
        return entry.lyricText.isEmpty ? "" : entry.lyricText
    }

    // Colors
    private let cardBg = Color(hex: "151515")
    private let ringOrange = Color(hex: "CC7A33")
    private let playOrange = Color(hex: "F06A00")
    private let infoBg = Color(hex: "111112")
    private let pillBg = Color(hex: "1C1C1E")

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout
        default:
            smallLayout
        }
    }

    // MARK: - Small Layout

    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 背景
                cardBg.ignoresSafeArea()

                // 4个工业风螺丝角 (使用深色圆环模拟)
                let inset: CGFloat = 8
                Group {
                    screwCorner().position(x: inset, y: inset)
                    screwCorner().position(x: w - inset, y: inset)
                    screwCorner().position(x: inset, y: h - inset)
                    screwCorner().position(x: w - inset, y: h - inset)
                }

                // 内部主结构
                VStack(spacing: 8) {

                    // 顶部区域：表盘 + 按钮胶囊
                    HStack(spacing: 6) {
                        // 左边：雷达表盘形进度 (100%TRACK)
                        ZStack {
                            Circle()
                                .stroke(ringOrange.opacity(0.35), lineWidth: 2)

                            // 刻度线
                            ForEach(0..<12) { i in
                                Rectangle()
                                    .fill(ringOrange.opacity(i % 3 == 0 ? 0.7 : 0.4))
                                    .frame(width: 1.5, height: i % 3 == 0 ? 6 : 3)
                                    .offset(y: -22)
                                    .rotationEffect(.degrees(Double(i) * 30))
                            }

                            VStack(spacing: 1) {
                                Text("100%")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)

                                PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: ringOrange, height: 8)

                                Text("TRACK")
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundColor(ringOrange)
                            }
                        }
                        .frame(width: 50, height: 50)

                        // 右边：上下两个胶囊
                        VStack(spacing: 6) {
                            // VOL
                            HStack(spacing: 4) {
                                PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: playOrange, height: 10)
                                Text("VOL")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(ringOrange)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(pillBg))

                            // 控件胶囊
                            HStack(spacing: 0) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.gray.opacity(0.8))
                                        .frame(width: 22, height: 26)
                                }.buttonStyle(.plain)

                                Spacer(minLength: 2)

                                Button(intent: TogglePlaybackIntent()) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(playOrange)
                                        Image(systemName: entry.controlSymbolName)
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(.black)
                                    }
                                    .frame(width: 26, height: 26)
                                    .shadow(color: playOrange.opacity(0.4), radius: 3, y: 1.5)
                                }.buttonStyle(.plain)

                                Spacer(minLength: 2)

                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.gray.opacity(0.8))
                                        .frame(width: 22, height: 26)
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(pillBg))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 14)

                    // 下方：信号信息大卡片
                    ZStack(alignment: .bottomTrailing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT_SIGNAL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.gray.opacity(0.7))

                            Spacer(minLength: 4)

                            Text(song)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)

                            Text(artist)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(ringOrange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 64)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(infoBg))

                        // 卡片内部右下角的虚晃微型波形
                        PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: ringOrange.opacity(0.8), height: 10)
                            .padding(14)
                    }
                    .padding(.horizontal, 12)

                    Spacer()
                }

                // 最底部角落修饰字符 "SYS_LINK"
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(ringOrange.opacity(0.5)).frame(width: 5, height: 5)
                            Text("SYS_LINK")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(ringOrange.opacity(0.4))
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Medium Layout

    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack {
                cardBg.ignoresSafeArea()

                let inset: CGFloat = 8
                VStack {
                    HStack { screwCorner(); Spacer(); screwCorner() }
                    Spacer()
                    HStack { screwCorner(); Spacer(); screwCorner() }
                }
                .padding(inset)

                HStack(spacing: 12) {
                    // Left: Cover + Song Info + Controls (VStack)
                    VStack(alignment: .leading, spacing: 8) {
                        // Top row of left: Radar Cover
                        HStack(spacing: 12) {
                            // Radar
                            ZStack {
                                Circle().stroke(ringOrange.opacity(0.35), lineWidth: 2)
                                ForEach(0..<12) { i in
                                    Rectangle()
                                        .fill(ringOrange.opacity(i % 3 == 0 ? 0.7 : 0.4))
                                        .frame(width: 1.5, height: i % 3 == 0 ? 6 : 3)
                                        .offset(y: -22)
                                        .rotationEffect(.degrees(Double(i) * 30))
                                }

                                if let data = entry.coverImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                        .frame(width: 40, height: 40)
                                } else {
                                    Circle().fill(Color.white.opacity(0.1)).frame(width: 40, height: 40)
                                    Image(systemName: "music.note")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .frame(width: 50, height: 50)

                            // Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.4)

                                Text(artist)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(ringOrange)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                            }
                        }

                        Spacer()

                        // Controls Pill
                        HStack(spacing: 0) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 24, height: 32)
                            }.buttonStyle(.plain)

                            Spacer()

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(playOrange)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 32, height: 32)
                                .shadow(color: playOrange.opacity(0.4), radius: 3, y: 1.5)
                            }.buttonStyle(.plain)

                            Spacer()

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 24, height: 32)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(pillBg))
                    }
                    .frame(maxWidth: w * 0.44)

                    // Right: Lyrics Terminal
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            PlaybackWave(isActive: entry.isPlaying, barCount: 3, color: playOrange, height: 10)
                            Text("LYRICS_DATA")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(ringOrange)
                            Spacer()
                            Circle().fill(ringOrange.opacity(0.5)).frame(width: 4, height: 4)
                        }

                        Divider().background(Color.white.opacity(0.1))

                        Text(displayLyric)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .layoutPriority(1)

                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(infoBg)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ringOrange.opacity(0.15), lineWidth: 1))
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Large Layout

    private var largeLayout: some View {
        GeometryReader { _ in
            ZStack {
                cardBg.ignoresSafeArea()

                let inset: CGFloat = 10
                VStack {
                    HStack { screwCorner(); Spacer(); screwCorner() }
                    Spacer()
                    HStack { screwCorner(); Spacer(); screwCorner() }
                }
                .padding(inset)

                VStack(spacing: 12) {
                    // Row 1: Radar Cover + Info Panel
                    HStack(spacing: 16) {
                        // Radar Big Cover
                        ZStack {
                            Circle().stroke(ringOrange.opacity(0.35), lineWidth: 3)
                            ForEach(0..<18) { i in
                                Rectangle()
                                    .fill(ringOrange.opacity(i % 3 == 0 ? 0.7 : 0.4))
                                    .frame(width: 2, height: i % 3 == 0 ? 8 : 4)
                                    .offset(y: -42)
                                    .rotationEffect(.degrees(Double(i) * 20))
                            }

                            if let data = entry.coverImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                                    .frame(width: 76, height: 76)
                            } else {
                                Circle().fill(Color.white.opacity(0.1)).frame(width: 76, height: 76)
                            }
                        }
                        .frame(width: 90, height: 90)

                        // Vertical Song Info Hub
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOW_TRACKING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.gray.opacity(0.7))
                            Text(song)
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.4)
                            Text(artist)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(ringOrange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Row 2: Equalizer / Control Deck Strip
                    HStack {
                        SoundwaveEqualizerBars(isActive: entry.isPlaying, color: playOrange)
                        .padding(.leading, 12)

                        Spacer()

                        // Controls
                        HStack(spacing: 20) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 32, height: 40)
                            }.buttonStyle(.plain)

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(playOrange)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 40, height: 40)
                                .shadow(color: playOrange.opacity(0.4), radius: 3, y: 1.5)
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .frame(width: 32, height: 40)
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(pillBg)
                    .cornerRadius(16)
                    .padding(.horizontal, 14)

                    // Row 3: Massive Lyrics Screen
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PlaybackWave(isActive: entry.isPlaying, barCount: 4, color: playOrange, height: 12)
                            Text("LIVE_LYRICS_STREAM")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(ringOrange)
                            Spacer()
                            Circle().fill(ringOrange.opacity(0.5)).frame(width: 6, height: 6)
                        }

                        Divider().background(Color.white.opacity(0.1))

                        Text(displayLyric)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(6)
                            .minimumScaleFactor(0.4)
                            .layoutPriority(1)
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(infoBg)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(ringOrange.opacity(0.15), lineWidth: 1.5))
                            .overlay(
                                VStack {
                                    HStack { screwCorner(); Spacer(); screwCorner() }
                                    Spacer()
                                    HStack { screwCorner(); Spacer(); screwCorner() }
                                }
                                .padding(12)
                            )
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // 角落的仿真螺丝
    private func screwCorner() -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 8, height: 8)
            .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 6, height: 1)
                    .rotationEffect(.degrees(45))
            )
            .overlay(
                Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.5)
            )
    }
}

private struct SoundwaveEqualizerBars: View {
    let isActive: Bool
    let color: Color

    private let baseHeights: [CGFloat] = [12, 24, 18, 28, 16, 20]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            HStack(spacing: 4) {
                ForEach(baseHeights.indices, id: \.self) { index in
                    let pulse = phase(index: index, date: timeline.date)
                    Capsule()
                        .fill(color.opacity(0.5 + 0.28 * Double(pulse)))
                        .frame(width: 4, height: height(index: index, date: timeline.date))
                }
            }
        }
    }

    private func height(index: Int, date: Date) -> CGFloat {
        guard isActive else { return baseHeights[index] }
        let pulse = phase(index: index, date: date)
        return baseHeights[index] * (0.72 + 0.56 * pulse)
    }

    private func phase(index: Int, date: Date) -> CGFloat {
        let time = date.timeIntervalSinceReferenceDate * 4.8
        let wave = sin(time + Double(index) * 0.78) * 0.5 + 0.5
        return CGFloat(wave)
    }
}
