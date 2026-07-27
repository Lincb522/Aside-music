import WidgetKit
import SwiftUI
import AppIntents

private let accentYellow = Color(hex: "E5A849")
private let accentGreen = Color(hex: "27AE60")

// MARK: - 1. Polaroid Theme (拍立得)

struct PolaroidTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let inkBlack = Color(hex: "1A1A1A")
    private let inkGray = Color(hex: "777777")

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    private var displaySongName: String {
        entry.isEmpty ? "未在播放" : entry.songName
    }

    private var displayArtistName: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge:  largeLayout
        default:            smallLayout
        }
    }

    // MARK: - Small 竖版拍立得

    private var smallLayout: some View {
        GeometryReader { geo in
            let frameSide: CGFloat = 10
            let frameTop: CGFloat = 8
            let infoH: CGFloat = 48
            let coverRadius: CGFloat = 12
            let coverH: CGFloat = geo.size.height - frameTop - infoH

            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    CoverImage(data: entry.coverImageData, radius: coverRadius)

                    if !entry.isEmpty {
                        LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                            .frame(height: 46)
                            .clipShape(UnevenRoundedRectangle(
                                topLeadingRadius: 0, bottomLeadingRadius: coverRadius,
                                bottomTrailingRadius: coverRadius, topTrailingRadius: 0, style: .continuous
                            ))

                        HStack(spacing: 26) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                            }.buttonStyle(.plain)
                            Button(intent: TogglePlaybackIntent()) {
                                Image(systemName: entry.controlSymbolName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .contentTransition(.symbolEffect(.replace))
                            }.buttonStyle(.plain)
                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                            }.buttonStyle(.plain)
                        }
                        .padding(.bottom, 22)
                    }
                }
                .frame(height: coverH)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .padding(.horizontal, frameSide)
                .padding(.top, frameTop)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundStyle(inkBlack)
                            Text(displaySongName)
                                .font(.system(size: 13, weight: .heavy, design: .serif)).foregroundStyle(inkBlack).lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .contentTransition(.interpolate)
                        }
                        ZStack(alignment: .leading) {
                            Text("playing now")
                                .font(.custom("Snell Roundhand", size: 16)).foregroundStyle(accentYellow.opacity(0.7)).offset(x: 2, y: -3)
                            Text(displayArtistName)
                                .font(.system(size: 9, weight: .medium)).foregroundStyle(inkGray).lineLimit(1).padding(.leading, 2)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(dateString).font(.system(size: 9, weight: .medium)).foregroundStyle(inkGray)
                        Text(entry.date, style: .time).font(.system(size: 12, weight: .bold)).foregroundStyle(inkBlack)
                        GreenSquiggle().stroke(accentGreen, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)).frame(width: 20, height: 3)
                    }
                }
                .frame(height: infoH)
                .padding(.horizontal, frameSide + 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Large 大尺寸拍立得（独立设计）

    private var largeLayout: some View {
        GeometryReader { geo in
            let frameSide: CGFloat = 16
            let frameTop: CGFloat = 14
            let infoH: CGFloat = 120
            let coverRadius: CGFloat = 18
            let coverH: CGFloat = geo.size.height - frameTop - infoH

            VStack(spacing: 0) {
                // 大封面 — 无控制按钮叠加，保持干净
                CoverImage(data: entry.coverImageData, radius: coverRadius)
                    .frame(height: coverH)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .padding(.horizontal, frameSide)
                    .padding(.top, frameTop)

                // 底部信息区 — 拍立得经典宽白边
                VStack(spacing: 0) {
                    // 歌曲信息行
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(inkBlack)
                                Text(displaySongName)
                                    .font(.system(size: 20, weight: .heavy, design: .serif))
                                    .foregroundStyle(inkBlack)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .contentTransition(.interpolate)
                            }

                            ZStack(alignment: .leading) {
                                Text("playing now")
                                    .font(.custom("Snell Roundhand", size: 28))
                                    .foregroundStyle(accentYellow.opacity(0.7))
                                    .offset(x: 2, y: -6)

                                Text(displayArtistName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(inkGray)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .padding(.leading, 2)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(dateString)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(inkGray)
                            Text(entry.date, style: .time)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(inkBlack)
                            GreenSquiggle()
                                .stroke(accentGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .frame(width: 32, height: 4)
                        }
                    }

                    Spacer(minLength: 0)

                    // 播放控件行 — 独立于封面，居中展示
                    if !entry.isEmpty {
                        HStack(spacing: 32) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.5))
                            }.buttonStyle(.plain)

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    Circle()
                                        .fill(inkBlack)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(hex: "F7F6F3"))
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.5))
                            }.buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(height: infoH)
                .padding(.horizontal, frameSide + 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Medium 横版拍立得

    private var mediumLayout: some View {
        GeometryReader { geo in
            let framePad: CGFloat = 10
            let coverRadius: CGFloat = 12
            let coverSize = geo.size.height - framePad * 2

            HStack(spacing: 0) {
                // 左侧：封面
                CoverImage(data: entry.coverImageData, radius: coverRadius)
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .padding(.leading, framePad)
                    .padding(.vertical, framePad)

                // 右侧
                VStack(alignment: .leading, spacing: 6) {
                    // 手写体装饰
                    Text("playing now ♪")
                        .font(.custom("Snell Roundhand", size: 24))
                        .foregroundStyle(accentYellow.opacity(0.65))

                    // 歌名
                    Text(displaySongName)
                        .font(.system(size: 18, weight: .heavy, design: .serif))
                        .foregroundStyle(inkBlack)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.interpolate)

                    // 歌手
                    HStack(spacing: 4) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 10))
                            .foregroundStyle(inkGray)
                        Text(displayArtistName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(inkGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }

                    Spacer(minLength: 4)

                    // 控件行
                    if !entry.isEmpty {
                        HStack(spacing: 18) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.4))
                            }.buttonStyle(.plain)

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    Circle()
                                        .fill(inkBlack)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(hex: "F7F6F3"))
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(inkBlack.opacity(0.4))
                            }.buttonStyle(.plain)

                            Spacer(minLength: 4)

                            HStack(spacing: 4) {
                                Text(dateString)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(inkGray)
                                Text(entry.date, style: .time)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(inkBlack)
                                GreenSquiggle()
                                    .stroke(accentGreen, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                                    .frame(width: 16, height: 3)
                            }
                        }
                    } else {
                        HStack(alignment: .bottom, spacing: 5) {
                            Text(dateString)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(inkGray)
                            Spacer()
                            Text(entry.date, style: .time)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(inkBlack)
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .padding(.vertical, framePad)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .widgetURL(URL(string: "mono://player"))
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: entry.date)
    }
}
