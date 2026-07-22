// RadioTheme.swift
// Monologue Widget Extension

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Radio Theme (收音机)

struct RadioTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let chassis = Color(hex: "1E1E1E")
    private let chassisDeep = Color(hex: "111112")
    private let lcd = Color(hex: "3CBDAE")
    private let lcdHot = Color(hex: "71E4D5")
    private let lcdInk = Color(hex: "111112")
    private let tunerInk = Color.white.opacity(0.92)
    private let tunerTick = Color.white.opacity(0.18)

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    private var song: String { entry.isEmpty ? "FM Radio" : entry.songName }
    private var artist: String { entry.isEmpty ? "Tune In" : entry.artistName }
    private var statusText: String {
        if entry.isLoading { return "SCAN" }
        return entry.isPlaying ? "LIVE" : "STBY"
    }
    private var frequencySeed: Int {
        (song + artist).unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }
    private var frequencyText: String {
        let value = entry.isEmpty ? 101.4 : 101.0 + Double(frequencySeed % 19) / 10.0
        return String(format: "%.1f", value)
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }

    private var smallLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = max(7, min(w, h) * 0.045)
            let innerW = w - pad * 2
            let innerH = h - pad * 2
            let screenH = innerH * 0.48
            let tunerH = innerH * 0.22
            let buttonSize = min(innerW * 0.18, 22)

            ZStack {
                radioBody(cornerRadius: min(w, h) * 0.18)

                VStack(spacing: 4) {
                    lcdPanel(width: innerW, height: screenH, compact: true)
                    tunerStrip(width: innerW, height: tunerH, showLabels: true)
                    if !entry.isEmpty {
                        controls(buttonSize: buttonSize, spacing: innerW * 0.08)
                    }
                }
                .padding(pad)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var mediumLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = 10
            let innerW = w - pad * 2
            let innerH = h - pad * 2
            let screenW = min(innerW * 0.54, innerH * 1.38)
            let sideW = innerW - screenW - 10

            ZStack {
                radioBody(cornerRadius: 26)

                HStack(spacing: 10) {
                    lcdPanel(width: screenW, height: innerH, compact: false)

                    VStack(alignment: .leading, spacing: 7) {
                        stationInfo(compact: true)
                        tunerStrip(width: sideW, height: min(50, innerH * 0.36), showLabels: true)
                        if !entry.isEmpty {
                            controls(buttonSize: 29, spacing: 11)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(width: sideW, height: innerH)
                }
                .padding(pad)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = 14
            let innerW = w - pad * 2
            let innerH = h - pad * 2
            let screenH = min(innerH * 0.44, 154)
            let tunerH = min(innerH * 0.19, 66)

            ZStack {
                radioBody(cornerRadius: 38)

                VStack(spacing: 9) {
                    lcdPanel(width: innerW, height: screenH, compact: false)
                    stationInfo(compact: false)
                    tunerStrip(width: innerW, height: tunerH, showLabels: true)
                    if !entry.isEmpty {
                        controls(buttonSize: 36, spacing: 18)
                    }
                }
                .padding(pad)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    private func radioBody(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "252525"), chassis, chassisDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.55), lineWidth: 2)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    private func lcdPanel(width: CGFloat, height: CGFloat, compact: Bool) -> some View {
        let radius = min(width, height) * (compact ? 0.20 : 0.28)
        let freqSize = min(height * (compact ? 0.42 : 0.48), width * (compact ? 0.26 : 0.25))
        let unitSize = max(10, min(freqSize * 0.34, compact ? 16 : 24))
        let badgeSize = max(9, min(height * 0.18, compact ? 15 : 22))

        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(lcd)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [lcdHot.opacity(0.85), lcd.opacity(0.92), Color(hex: "278C82").opacity(0.92)],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(width, height) * 0.7
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(lcdScanlines(width: width, height: height, radius: radius))
                .overlay(lcdVerticalGrid(radius: radius))

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("FM")
                        .font(.system(size: badgeSize, weight: .black, design: .monospaced))
                        .foregroundStyle(lcd)
                        .padding(.horizontal, compact ? 5 : 8)
                        .padding(.vertical, compact ? 2 : 4)
                        .background(lcdInk.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 7, style: .continuous))

                    Spacer(minLength: 4)

                    Text(statusText)
                        .font(.system(size: max(8, badgeSize * 0.62), weight: .bold, design: .monospaced))
                        .foregroundStyle(lcdInk.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: compact ? 2 : 5) {
                    Text(frequencyText)
                        .font(.system(size: freqSize, weight: .heavy, design: .monospaced))
                        .foregroundStyle(lcdInk)
                        .monospacedDigit()
                    Text("KHz")
                        .font(.system(size: unitSize, weight: .heavy, design: .monospaced))
                        .foregroundStyle(lcdInk)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                Text(song.uppercased())
                    .font(.system(size: compact ? 7 : 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(lcdInk.opacity(compact ? 0.55 : 0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, compact ? 9 : 16)
            .padding(.vertical, compact ? 8 : 14)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: lcd.opacity(0.32), radius: compact ? 8 : 14, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 3)
    }

    private func lcdScanlines(width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        VStack(spacing: max(3, height / 18)) {
            ForEach(0..<12, id: \.self) { _ in
                Rectangle()
                    .fill(lcdInk.opacity(0.07))
                    .frame(height: 1)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func lcdVerticalGrid(radius: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<28, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
            }
        }
        .blendMode(.softLight)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func tunerStrip(width: CGFloat, height: CGFloat, showLabels: Bool) -> some View {
        let tickCount = 25
        let markerWidth = max(5, min(width * 0.045, 14))

        return ZStack {
            RoundedRectangle(cornerRadius: min(18, height * 0.33), style: .continuous)
                .fill(Color.black.opacity(0.12))

            VStack(spacing: 0) {
                if showLabels {
                    HStack {
                        Text("101")
                        Spacer()
                        Text("102")
                    }
                    .font(.system(size: max(9, height * 0.22), weight: .bold, design: .monospaced))
                    .foregroundStyle(tunerInk)
                    .monospacedDigit()
                    .padding(.horizontal, width * 0.17)
                    .padding(.top, max(2, height * 0.08))
                }

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { index in
                        let isMajor = index % 6 == 0
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(isMajor ? tunerInk.opacity(0.34) : tunerTick)
                            .frame(width: isMajor ? 2 : 1, height: height * (isMajor ? 0.32 : 0.2))
                        if index < tickCount - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, width * 0.08)
                .padding(.bottom, max(5, height * 0.12))
            }

            RoundedRectangle(cornerRadius: markerWidth / 2, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .frame(width: markerWidth, height: height * 0.78)
                .shadow(color: Color.white.opacity(0.35), radius: 3, x: 0, y: 0)
        }
        .frame(width: width, height: height)
    }

    private func stationInfo(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            coverTile(size: compact ? 30 : 44)

            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                Text(song)
                    .font(.system(size: compact ? 12 : 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .contentTransition(.interpolate)

                Text(artist)
                    .font(.system(size: compact ? 9 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .contentTransition(.interpolate)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func coverTile(size: CGFloat) -> some View {
        if let data = entry.coverImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "radio")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(lcd.opacity(0.9))
                )
        }
    }

    @ViewBuilder
    private func controls(buttonSize: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            radioButton(intent: PreviousTrackIntent(), icon: "backward.fill", size: buttonSize, isMain: false)
            radioButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: buttonSize * 1.12, isMain: true)
            radioButton(intent: NextTrackIntent(), icon: "forward.fill", size: buttonSize, isMain: false)
        }
    }

    private func radioButton<I: AppIntent>(intent: I, icon: String, size: CGFloat, isMain: Bool) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(isMain ? lcdInk : Color.white.opacity(0.86))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isMain ? lcd : Color.white.opacity(0.08))
                        .overlay(
                            Circle()
                                .stroke(isMain ? lcdHot.opacity(0.45) : Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.38), radius: 3, x: 0, y: 2)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Radio Theme

private struct LegacyRadioTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    // 从封面取色生成动态配色
    private var dominantColor: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "D0CEC8") }
        return Color(red: Double(entry.dominantRGB[0]), green: Double(entry.dominantRGB[1]), blue: Double(entry.dominantRGB[2]))
    }

    private var secondaryColor: Color {
        guard entry.secondaryRGB.count == 3, !entry.isEmpty else { return Color(hex: "E8E6E2") }
        return Color(red: Double(entry.secondaryRGB[0]), green: Double(entry.secondaryRGB[1]), blue: Double(entry.secondaryRGB[2]))
    }

    /// 背景色：封面主色 → 调高亮度、降低饱和度，保持柔和拟物感
    private var bgTop: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "F0EEEA") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        // 混合白色 75%，保留 25% 色调
        return Color(red: r * 0.25 + 0.75, green: g * 0.25 + 0.75, blue: b * 0.25 + 0.75)
    }

    private var bgBottom: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "E6E4E0") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        // 混合白色 65%，保留 35% 色调，略深
        return Color(red: r * 0.35 + 0.65, green: g * 0.35 + 0.65, blue: b * 0.35 + 0.65)
    }

    // 文字
    private let textPrimary = Color(hex: "2C2C2C")
    private let textSecondary = Color(hex: "9A9A9A")
    private let fmColor = Color(hex: "A0A0A0")

    // 刻度盘 — 跟随背景色调
    private var dialScreenBg: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "D8D6D2") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        return Color(red: r * 0.3 + 0.56, green: g * 0.3 + 0.56, blue: b * 0.3 + 0.56)
    }

    private var dialScreenTop: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "E2E0DC") }
        let r = Double(entry.dominantRGB[0])
        let g = Double(entry.dominantRGB[1])
        let b = Double(entry.dominantRGB[2])
        return Color(red: r * 0.25 + 0.63, green: g * 0.25 + 0.63, blue: b * 0.25 + 0.63)
    }

    private let dialInnerShadow = Color(hex: "B0AEA8")
    private let tickColor = Color(hex: "B0ADA6")
    private let tickMajorColor = Color(hex: "9A9894")
    private let needleColor = Color(hex: "A8A6A0")
    private let freqColor = Color(hex: "8A8884")

    // 按钮
    private let btnTopColor = Color(hex: "F2F0EC")
    private let btnBottomColor = Color(hex: "E0DDD8")
    private let btnShadowColor = Color(hex: "C0BDB6")
    private let btnIconColor = Color(hex: "7A7874")

    private var song: String { entry.isEmpty ? "FM Radio" : entry.songName }
    private var artist: String { entry.isEmpty ? "Tune In" : entry.artistName }

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
            let btnSz: CGFloat = min(w * 0.21, 30)

            VStack(spacing: 0) {
                // FM 标签
                HStack {
                    Spacer()
                    Text("FM")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(fmColor)
                }
                .padding(.trailing, 14)
                .padding(.top, 10)

                // 频率刻度盘 — 凹陷屏幕
                radioDialScreen(width: w - 24, height: h * 0.35)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 1) {
                    Text(song)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    Text(artist)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 6)

                Spacer(minLength: 2)

                // 控制按钮
                if !entry.isEmpty {
                    HStack(spacing: w * 0.06) {
                        radioKnob(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, isMain: false)
                        radioKnob(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 6, isMain: true)
                        radioKnob(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, isMain: false)
                    }
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
            let w = geo.size.width
            let h = geo.size.height
            let coverSize: CGFloat = h - 24
            let btnSz: CGFloat = 28

            HStack(spacing: 0) {
                // 左侧 — 凹陷封面框
                ZStack {
                    // 凹陷底座
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [bgBottom.opacity(0.6), bgBottom.opacity(0.4)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.05), Color.clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                )
                        )
                        .frame(width: coverSize, height: coverSize)

                    // 封面图片
                    if let data = entry.coverImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize - 8, height: coverSize - 8)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: "radio")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(textSecondary.opacity(0.5))
                    }
                }
                .frame(width: coverSize + 4)
                .padding(.leading, 12)

                // 右侧 — 信息和控制
                VStack(alignment: .leading, spacing: 0) {
                    // RADIO + 音质
                    HStack {
                        Text("RADIO")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(fmColor)
                            .tracking(1)
                        Spacer()
                        if !entry.qualityText.isEmpty {
                            Text(entry.qualityText)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(fmColor.opacity(0.7))
                                .italic()
                        }
                    }
                    .padding(.top, 10)

                    // 频率刻度盘
                    radioDialScreen(width: w - coverSize - 44, height: 42)
                        .padding(.top, 4)

                    // 歌曲信息
                    Text(song)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                        .padding(.top, 5)

                    Text(artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                        .padding(.top, 1)

                    Spacer(minLength: 2)

                    // 控制按钮
                    if !entry.isEmpty {
                        HStack(spacing: 12) {
                            radioKnob(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, isMain: false)
                            radioKnob(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 4, isMain: true)
                            radioKnob(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, isMain: false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 14)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 封面高度基于可用空间计算，预留顶部(40)+刻度盘(66)+歌曲信息(50)+格栅(16)+按钮(60)=232
            let coverH: CGFloat = min(h - 230, w * 0.5)
            let coverW: CGFloat = w - 40
            let btnSz: CGFloat = 36

            VStack(spacing: 0) {
                // 顶部：RADIO + 音质
                HStack {
                    Text("RADIO")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(fmColor)
                        .tracking(1.5)
                    Spacer()
                    if !entry.qualityText.isEmpty {
                        Text(entry.qualityText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(fmColor.opacity(0.7))
                            .italic()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                // 频率刻度盘
                radioDialScreen(width: w - 36, height: 58)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                // 凹陷封面框
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [bgBottom.opacity(0.5), bgBottom.opacity(0.35)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.04), Color.clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                )
                        )
                        .frame(width: coverW, height: coverH)

                    if let data = entry.coverImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverW - 10, height: coverH - 10)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "radio")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(textSecondary.opacity(0.4))
                    }
                }
                .padding(.top, 10)

                // 歌曲信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(song)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)

                    Text(artist)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.interpolate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer(minLength: 6)

                // 装饰扬声器格栅线
                HStack(spacing: 3) {
                    ForEach(0..<Int(w / 5), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(btnShadowColor.opacity(0.15))
                            .frame(width: 1, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                // 控制按钮
                if !entry.isEmpty {
                    HStack(spacing: 18) {
                        radioKnob(intent: PreviousTrackIntent(), icon: "backward.fill", size: btnSz, isMain: false)
                        radioKnob(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, size: btnSz + 8, isMain: true)
                        radioKnob(intent: NextTrackIntent(), icon: "forward.fill", size: btnSz, isMain: false)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - 凹陷频率刻度盘

    /// 模拟参考图中的凹陷屏幕：深色背景，频率数字在顶部，长刻度线贯穿，半透明指针
    private func radioDialScreen(width: CGFloat, height: CGFloat) -> some View {
        let frequencies = [88, 92, 96, 100, 104, 108]
        let totalTicks = 26 // 每个区间5格 × 5区间 + 首尾 = 26

        return ZStack {
            // 凹陷屏幕背景
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [dialScreenTop, dialScreenBg, dialScreenBg.opacity(0.95)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                // 内阴影效果 — 凹陷感
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(dialInnerShadow.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    // 顶部内阴影
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.06), Color.clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                )

            // 内容
            VStack(spacing: 0) {
                // 频率数字
                HStack(spacing: 0) {
                    ForEach(frequencies, id: \.self) { freq in
                        Text("\(freq)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(freqColor)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                Spacer(minLength: 2)

                // 刻度线区域
                ZStack(alignment: .bottom) {
                    // 刻度线
                    HStack(spacing: 0) {
                        ForEach(0..<totalTicks, id: \.self) { i in
                            let isMajor = i % 5 == 0
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(isMajor ? tickMajorColor : tickColor.opacity(0.6))
                                    .frame(width: isMajor ? 1.2 : 0.8, height: isMajor ? height * 0.48 : height * 0.32)
                            }
                            if i < totalTicks - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 10)

                    // 指针 — 半透明竖线
                    let needlePos = entry.isEmpty ? 0.5 : stableNeedlePosition()
                    Rectangle()
                        .fill(needleColor.opacity(0.7))
                        .frame(width: 2.5, height: height * 0.55)
                        .background(
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 6)
                                .blur(radius: 2)
                        )
                        .offset(x: (needlePos - 0.5) * (width - 28))
                }
                .padding(.bottom, 6)
            }
        }
        .frame(width: width, height: height)
        // 外阴影 — 凹陷感
        .shadow(color: Color.white.opacity(0.6), radius: 1, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: -1)
    }

    private func stableNeedlePosition() -> CGFloat {
        let hash = abs(entry.songName.hashValue)
        return CGFloat(hash % 70 + 15) / 100.0 // 0.15 ~ 0.85
    }

    // MARK: - 轻拟物按钮

    private func radioKnob<I: AppIntent>(intent: I, icon: String, size: CGFloat, isMain: Bool) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(isMain ? textPrimary.opacity(0.65) : btnIconColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [btnTopColor, btnBottomColor],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        // 柔和的底部投影 — 圆润凸起感
                        .shadow(color: btnShadowColor.opacity(0.5), radius: 2.5, x: 0, y: 2)
                        .shadow(color: Color.white.opacity(0.5), radius: 0.5, x: 0, y: -0.5)
                )
                // 淡淡的顶部高亮 — 圆润感
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .padding(2)
                        .allowsHitTesting(false)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}
