// PagerTheme.swift
// Monologue Widget Extension

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Pager Theme (寻呼机)

struct PagerWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily
    var isLight: Bool = false

    // 色彩系统
    private var bodyTop: Color { isLight ? Color(hex: "F4F3F0") : Color(hex: "353230") }
    private var bodyBottom: Color { isLight ? Color(hex: "E8E6E0") : Color(hex: "252320") }
    private var screenBg: Color { isLight ? Color(hex: "E8E8E8") : Color(hex: "161616") }
    private var amber: Color { isLight ? Color(hex: "181818") : Color(hex: "fca311") }
    private var signalLit: Color { isLight ? dynamicTop : Color(hex: "fca311") }


    private var dynamicTop: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "E5E4E0") }
        return Color(red: Double(entry.dominantRGB[0]), green: Double(entry.dominantRGB[1]), blue: Double(entry.dominantRGB[2]))
    }

    private var dynamicBottom: Color {
        guard entry.secondaryRGB.count == 3, !entry.isEmpty else { return Color(hex: "C8C6C0") }
        return Color(red: Double(entry.secondaryRGB[0]), green: Double(entry.secondaryRGB[1]), blue: Double(entry.secondaryRGB[2]))
    }

    private var btnMainTop: Color { isLight ? dynamicTop : Color(hex: "fca311") }
    private var btnMainBottom: Color { isLight ? dynamicBottom : Color(hex: "c47f0a") }

    private var btnBg: Color { isLight ? Color(hex: "D8D5D0") : Color(hex: "3a3630") }
    private var btnIcon: Color { isLight ? Color(hex: "A3A09A") : Color(hex: "78746c") }

    private var brandDim: Color { isLight ? Color(hex: "A09E98") : Color(hex: "807c76") }
    private var brandBright: Color { isLight ? Color(hex: "33312E") : Color.white.opacity(0.85) }

    private var song: String { entry.isEmpty ? "READY..." : entry.songName.uppercased() }
    private var artist: String { entry.isEmpty ? "M O T O P A G E R" : entry.artistName }

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
            let btnSz: CGFloat = min(w * 0.15, 24)

            VStack(spacing: 0) {
                // 品牌栏
                brandBar(fontSize: 9)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                // LCD 屏幕
                lcdScreen(cornerRadius: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song)
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(amber)
                            .padding(.top, 6)
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.interpolate)

                        Text(artist)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(amber.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)

                        Spacer(minLength: 2)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                Spacer(minLength: 4)

                // 按钮组
                if !entry.isEmpty {
                    HStack(spacing: 5) {
                        ctrlBtn(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, main: false)
                        ctrlBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 3, main: true)
                        ctrlBtn(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, main: false)
                    }
                    .padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 12)
                }
            }
            .background(deviceBody(cornerRadius: 22))
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            let btnSz: CGFloat = 32

            VStack(spacing: 0) {
                // ── 顶部品牌栏 + 音质 ──
                HStack(spacing: 0) {
                    Text("M O T O")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(brandDim)
                    Text(" P A G E R")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(brandBright)

                    Spacer()

                    signalBars(height: 9, active: !entry.isEmpty)

                    if !entry.qualityText.isEmpty {
                        Text(entry.qualityText)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(brandDim.opacity(0.3), lineWidth: 1))
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                // ── LCD 屏幕（含封面） ──
                lcdScreen(cornerRadius: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        // 封面
                        CoverImage(data: entry.coverImageData, radius: 6)
                            .frame(width: 62, height: 62)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(amber.opacity(0.35), lineWidth: 1))
                            .padding(.leading, 4)

                        // 歌曲信息
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(amber)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .contentTransition(.interpolate)

                            // 歌手 / 歌词
                            if !entry.lyricText.isEmpty {
                                (Text("\(artist) / ").foregroundStyle(amber.opacity(0.55)) +
                                 Text(entry.lyricText).foregroundStyle(amber))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .minimumScaleFactor(0.6)
                                    .contentTransition(.interpolate)
                            } else {
                                Text(artist)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(amber.opacity(0.55))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: 62, alignment: .topLeading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)

                Spacer(minLength: 4)

                // ── 底部：按钮 + BPM ──
                HStack {
                    if !entry.isEmpty {
                        HStack(spacing: 5) {
                            ctrlBtn(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, main: false)
                            ctrlBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 3, main: true)
                            ctrlBtn(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, main: false)
                        }
                    }

                    Spacer()

                    if let bpm = entry.tempoBPM, bpm > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(bpm)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(brandDim.opacity(0.8))
                            Text("bpm")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(brandDim.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .background(deviceBody(cornerRadius: 22))
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large

    private var largeLayout: some View {
        GeometryReader { geo in
            let btnSz: CGFloat = 40

            VStack(spacing: 0) {
                // ── 顶部品牌栏 + 音质 ──
                HStack(spacing: 0) {
                    Text("M O T O")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(brandDim)
                    Text(" P A G E R")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(brandBright)

                    Spacer()

                    signalBars(height: 11, active: !entry.isEmpty)

                    if !entry.qualityText.isEmpty {
                        Text(entry.qualityText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.6))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(brandDim.opacity(0.3), lineWidth: 1))
                            .padding(.leading, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer(minLength: 10)

                // ── LCD 屏幕（含大封面） ──
                lcdScreen(cornerRadius: 16) {
                    VStack(alignment: .center, spacing: 10) {
                        CoverImage(data: entry.coverImageData, radius: 8)
                            .frame(width: 110, height: 110)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(amber.opacity(0.35), lineWidth: 1))

                        VStack(alignment: .center, spacing: 10) {
                            Text(song)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(amber)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .contentTransition(.interpolate)

                            VStack(alignment: .center, spacing: 6) {
                                Text(artist)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(amber.opacity(0.55))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)

                                let subStr = entry.albumName.isEmpty ? entry.lyricText : entry.albumName
                                if !subStr.isEmpty {
                                    Text(subStr)
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundStyle(amber.opacity(0.48))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.4)
                                        .padding(.horizontal, 10)
                                        .frame(height: 40)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 12)

                // 按钮组
                if !entry.isEmpty {
                    HStack(spacing: 16) {
                        ctrlBtn(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz * 0.9, main: false)
                        ctrlBtn(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: (btnSz + 16) * 0.9, main: true)
                        ctrlBtn(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz * 0.9, main: false)
                    }
                } else {
                    Spacer().frame(height: btnSz)
                }

                Spacer(minLength: 10)

                // 底部元数据栏
                HStack(alignment: .lastTextBaseline) {
                    // 左侧 QS
                    Text(!entry.sourceName.isEmpty ? entry.sourceName.uppercased() : "QS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(brandDim.opacity(0.4))

                    Spacer()

                    // 中部 顺序
                    Text("顺序")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(brandDim.opacity(0.4))

                    Spacer()

                    // 右侧 BPM
                    if let bpm = entry.tempoBPM, bpm > 0 {
                        Text("\(bpm) BPM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.4))
                    } else {
                        Text("-- BPM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(brandDim.opacity(0.4))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
            .background(deviceBody(cornerRadius: 26))
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - 共享组件

    /// 品牌栏
    private func brandBar(fontSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("M O T O")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(brandDim)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(" P A G E R")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(brandBright)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer()

            // 信号指示
            signalBars(height: fontSize, active: !entry.isEmpty)
        }
    }

    /// 信号格 — 重新设计：无 SF Symbol，纯几何构建的复古数据扫描缓冲 (Scanning Buffer)
    private func signalBars(height: CGFloat, active: Bool) -> some View {
        TimelineView(.animation(minimumInterval: 0.4, paused: !entry.isPlaying)) { timeline in
            // 定义来回扫描的索引序列 (Ping-pong array)
            let positions = [0, 1, 2, 3, 4, 3, 2, 1]
            // 如果正在播放，根据时间推移取模计算当前高亮的块
            let pos = (active && entry.isPlaying) ? positions[Int(timeline.date.timeIntervalSince1970 / 0.4) % positions.count] : -1

            HStack(spacing: 4) {
                // "TX" 数据发射标识文字
                Text("TX")
                    .font(.system(size: height * 0.7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(entry.isPlaying ? signalLit.opacity(0.9) : brandDim.opacity(0.4))

                // 纯几何绘制的 5 段式扫描像素槽
                HStack(spacing: 1.5) {
                    ForEach(0..<5, id: \.self) { i in
                        let isLit = (i == pos)
                        Rectangle()
                            .fill(isLit ? signalLit.opacity(0.95) : brandDim.opacity(0.2))
                            .frame(width: 3.5, height: height * 0.75)
                            .animation(.none, value: isLit) // 硬切割动画，模拟真实老硬件的断电/通电质感
                    }
                }
            }
            .frame(height: height)
        }
    }

    /// LCD 屏幕 — 内凹效果
    private func lcdScreen<C: View>(cornerRadius cr: CGFloat, @ViewBuilder content: () -> C) -> some View {
        let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

        return ZStack(alignment: .leading) {
            // 底层：屏幕面板
            shape
                .fill(screenBg)

            // 内凹阴影 — 上边和左边暗色，模拟下沉
            shape
                .stroke(Color.black.opacity(isLight ? 0.25 : 0.6), lineWidth: 3)
                .blur(radius: 3)
                .offset(x: 1, y: 1)
                .mask(shape.padding(-1))

            // 内侧高光 — 底边和右边的微弱亮线
            shape
                .stroke(isLight ? Color.white.opacity(0.6) : Color.white.opacity(0.035), lineWidth: 2)
                .blur(radius: 1.5)
                .offset(x: -0.5, y: -0.5)
                .mask(shape.padding(-1))

            // 外轮廓
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [isLight ? Color.black.opacity(0.1) : Color.black.opacity(0.5), isLight ? Color.white.opacity(0.4) : Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // 左侧光标竖线
            RoundedRectangle(cornerRadius: 1)
                .fill(amber.opacity(0.12))
                .frame(width: 2)
                .padding(.vertical, 10)
                .padding(.leading, 6)

            // 内容
            content()
        }
    }

    /// 设备机身
    private func deviceBody(cornerRadius cr: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

        return ZStack {
            // 主体渐变
            shape.fill(
                LinearGradient(
                    colors: [bodyTop, bodyBottom],
                    startPoint: .top, endPoint: .bottom
                )
            )

            // 顶部高光边 — 金属感
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.01),
                            Color.black.opacity(0.15)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // 顶部光泽 — 微妙的磨砂金属反光
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.01),
                            Color.clear,
                            Color.clear
                        ],
                        startPoint: .top, endPoint: .center
                    )
                )

            // 微噪点质感
            shape
                .fill(isLight ? Color.black.opacity(0.005) : Color.white.opacity(0.008))
        }
        .shadow(color: Color.black.opacity(isLight ? 0.08 : 0.35), radius: 16, x: 0, y: 8)
        .shadow(color: Color.black.opacity(isLight ? 0.04 : 0.15), radius: 4, x: 0, y: 2)
    }

    /// 控制按钮 — 截图参考像素级还原
    private func ctrlBtn<I: AppIntent>(intent: I, icon: String, size: CGFloat, main: Bool) -> some View {
        // 让按钮极其扁平细长，且大幅缩小上下曲的主体面积
        let h = main ? size * 0.70 : size * 0.58
        let w = main ? h * 2.7 : h * 2.1
        let cr = h * 0.25
        let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

        return Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: h * 0.42, weight: .bold))
                // 播放键图标极暗，切歌键图标用低对比度的暗灰色
                .foregroundStyle(main ? Color(hex: "181510") : btnIcon)
                .frame(width: w, height: h)
                .background(
                    ZStack {
                        shape.fill(
                            LinearGradient(
                                colors: main
                                    ? [btnMainTop, btnMainBottom]
                                    : [btnBg, isLight ? btnBg.opacity(0.9) : btnBg.opacity(0.7)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        // 物理高光效果：顶部极细的白光边，底部略深
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(main ? 0.2 : 0.08),
                                    Color.clear,
                                    Color.black.opacity(0.3)
                                ],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                    }
                )
                // 紧致硬朗的底部下沉阴影
                .shadow(color: Color.black.opacity(isLight ? 0.15 : 0.5), radius: 1, x: 0, y: 1.5)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}
