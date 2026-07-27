import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Vinyl turntable

struct VinylTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily
    let isDark: Bool

    init(entry: NowPlayingEntry, family: WidgetFamily, isDark: Bool = false) {
        self.entry = entry
        self.family = family
        self.isDark = isDark
    }

    private var accentColor: Color {
        entry.isEmpty ? Color(hex: "F5C62D") : entry.dominantColor
    }

    private var secondaryAccentColor: Color {
        entry.isEmpty ? Color(hex: "B47718") : entry.secondaryColor
    }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let recordDiameter = side * 0.80
            let tonearmScale = recordDiameter * 0.53
            let pivot = CGPoint(x: proxy.size.width * 0.91, y: proxy.size.height * 0.085)

            ZStack {
                VinylTurntableShell(cornerRadius: side * 0.18, isDark: isDark)

                VinylRecordView(
                    entry: entry,
                    diameter: recordDiameter,
                    accentColor: accentColor,
                    secondaryAccentColor: secondaryAccentColor,
                    referenceStyle: true
                )
                .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.465)

                VinylTonearmView(
                    scale: tonearmScale,
                    isActive: entry.isPlaying || entry.isLoading,
                    accentColor: accentColor
                )
                .frame(width: tonearmScale, height: tonearmScale)
                .position(
                    x: pivot.x - tonearmScale * 0.5,
                    y: pivot.y + tonearmScale * 0.5
                )

                Capsule(style: .continuous)
                    .fill(
                        isDark
                            ? Color.white.opacity(0.18)
                            : Color(hex: "D7D9D7").opacity(0.68)
                    )
                    .frame(width: side * 0.105, height: max(1, side * 0.012))
                    .position(x: proxy.size.width * 0.13, y: proxy.size.height * 0.77)

                TurntableKnob(entry: entry, diameter: side * 0.16, isDark: isDark)
                    .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.85)

                SpeakerGrille(spacing: side * 0.035, isDark: isDark)
                    .frame(width: side * 0.27, height: side * 0.13)
                    .position(x: proxy.size.width * 0.83, y: proxy.size.height * 0.85)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .widgetURL(URL(string: "mono://player"))
    }

    private var mediumLayout: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let recordDiameter = min(height * 0.91, proxy.size.width * 0.43)
            let tonearmScale = recordDiameter * 0.55
            let pivot = CGPoint(x: proxy.size.width * 0.48, y: height * 0.075)

            ZStack {
                VinylTurntableShell(cornerRadius: height * 0.18, isDark: isDark)

                VinylRecordView(
                    entry: entry,
                    diameter: recordDiameter,
                    accentColor: accentColor,
                    secondaryAccentColor: secondaryAccentColor,
                    referenceStyle: false
                )
                .position(x: proxy.size.width * 0.245, y: height * 0.50)

                VinylTonearmView(
                    scale: tonearmScale,
                    isActive: entry.isPlaying || entry.isLoading,
                    accentColor: accentColor
                )
                .frame(width: tonearmScale, height: tonearmScale)
                .position(
                    x: pivot.x - tonearmScale * 0.5,
                    y: pivot.y + tonearmScale * 0.5
                )

                VinylMediumConsole(entry: entry, accentColor: accentColor, isDark: isDark)
                    .frame(width: proxy.size.width * 0.43, height: height * 0.76)
                    .position(x: proxy.size.width * 0.755, y: height * 0.52)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .widgetURL(URL(string: "mono://player"))
    }

    private var largeLayout: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let recordDiameter = min(proxy.size.width * 0.68, proxy.size.height * 0.64)
            let tonearmScale = recordDiameter * 0.62
            let pivot = CGPoint(x: proxy.size.width * 0.86, y: proxy.size.height * 0.075)

            ZStack {
                VinylTurntableShell(cornerRadius: side * 0.105, isDark: isDark)

                VinylRecordView(
                    entry: entry,
                    diameter: recordDiameter,
                    accentColor: accentColor,
                    secondaryAccentColor: secondaryAccentColor,
                    referenceStyle: false
                )
                .position(x: proxy.size.width * 0.43, y: proxy.size.height * 0.38)

                VinylTonearmView(
                    scale: tonearmScale,
                    isActive: entry.isPlaying || entry.isLoading,
                    accentColor: accentColor
                )
                .frame(width: tonearmScale, height: tonearmScale)
                .position(
                    x: pivot.x - tonearmScale * 0.5,
                    y: pivot.y + tonearmScale * 0.5
                )

                SpeakerGrille(spacing: side * 0.025, isDark: isDark)
                    .frame(width: side * 0.17, height: side * 0.08)
                    .position(x: proxy.size.width * 0.87, y: proxy.size.height * 0.58)

                VinylLargeConsole(entry: entry, accentColor: accentColor, isDark: isDark)
                    .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.23)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.855)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .widgetURL(URL(string: "mono://player"))
    }
}

private struct VinylTurntableShell: View {
    let cornerRadius: CGFloat
    let isDark: Bool

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            ZStack {
                shape
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [
                                    Color(hex: "292A28"),
                                    Color(hex: "171816"),
                                    Color(hex: "0D0E0D")
                                ]
                                : [
                                    Color(hex: "FFFFFF"),
                                    Color(hex: "F8F8F6"),
                                    Color(hex: "F1F2F0")
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Canvas { context, size in
                    var x: CGFloat = 8
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [
                                    Color.white.opacity(isDark ? 0.07 : 0.42),
                                    isDark
                                        ? Color.black.opacity(0.20)
                                        : Color(hex: "DDE0DD").opacity(0.18),
                                    Color.white.opacity(isDark ? 0.025 : 0.08)
                                ]),
                                startPoint: CGPoint(x: x, y: 0),
                                endPoint: CGPoint(x: x, y: size.height)
                            ),
                            lineWidth: 2
                        )
                        x += 11
                    }
                }
                .opacity(0.45)
                .clipShape(shape)

                shape
                    .stroke(
                        LinearGradient(
                            colors: isDark
                                ? [
                                    Color.white.opacity(0.24),
                                    Color(hex: "464844"),
                                    Color.black.opacity(0.72)
                                ]
                                : [
                                    Color.white,
                                    Color(hex: "D8DAD8"),
                                    Color(hex: "F5F5F3")
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, proxy.size.width * 0.006)
                    )

                shape
                    .inset(by: max(2, proxy.size.width * 0.010))
                    .stroke(Color.white.opacity(isDark ? 0.08 : 0.92), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(isDark ? 0.44 : 0.16),
                radius: max(5, proxy.size.width * 0.025),
                x: 0,
                y: max(2, proxy.size.height * 0.018)
            )
        }
    }
}

private struct VinylRecordView: View {
    let entry: NowPlayingEntry
    let diameter: CGFloat
    let accentColor: Color
    let secondaryAccentColor: Color
    let referenceStyle: Bool

    private var discAnimationDuration: TimeInterval {
        min(2.0, max(0.1, entry.entryDisplayDuration) + 0.5)
    }

    private var discRotationAngle: Angle {
        guard !entry.isEmpty else { return .zero }
        let targetTime = max(0, entry.playbackCurrentTime)
            + (entry.isPlaying ? discAnimationDuration : 0)
        return .degrees(targetTime * 9)
    }

    private var discRotationAnimation: Animation {
        entry.isPlaying
            ? .linear(duration: discAnimationDuration)
            : .snappy(duration: 0.4)
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.23))
                .frame(width: diameter * 0.94, height: diameter * 0.18)
                .blur(radius: diameter * 0.045)
                .offset(y: diameter * 0.43)

            ZStack {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "252525"),
                                    Color(hex: "101010"),
                                    Color(hex: "050505"),
                                    Color(hex: "171717")
                                ],
                                center: .center,
                                startRadius: diameter * 0.10,
                                endRadius: diameter * 0.52
                            )
                        )

                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    accentColor.opacity(0.08),
                                    Color(hex: "E8B35C").opacity(0.24),
                                    Color.white.opacity(0.08),
                                    Color.clear,
                                    Color.black.opacity(0.22),
                                    Color.clear
                                ]),
                                center: .center,
                                angle: .degrees(-32)
                            )
                        )
                        .blendMode(.screen)

                    VinylGrooves()
                        .padding(diameter * 0.035)

                    VinylCenterLabel(
                        entry: entry,
                        diameter: diameter * 0.40,
                        accentColor: accentColor,
                        secondaryAccentColor: secondaryAccentColor
                    )
                }
                .rotationEffect(discRotationAngle)
                .animation(discRotationAnimation, value: discRotationAngle)

                if referenceStyle {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "D7A63F").opacity(0.42),
                                    Color(hex: "A77931").opacity(0.22),
                                    Color.clear,
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                }

                Circle()
                    .trim(from: 0.02, to: 0.41)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "F3C56D").opacity(0.88),
                                Color.white.opacity(0.22),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: max(1, diameter * 0.006), lineCap: .round)
                    )
                    .padding(diameter * 0.052)
                    .rotationEffect(.degrees(-35))

                Circle()
                    .stroke(
                        Color.black.opacity(0.82),
                        lineWidth: max(1, diameter * (referenceStyle ? 0.038 : 0.025))
                    )

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .padding(diameter * 0.018)

                Circle()
                    .fill(Color(hex: "EFE8D8"))
                    .frame(width: diameter * 0.052, height: diameter * 0.052)
                    .shadow(color: .black.opacity(0.24), radius: 1, y: 1)

                Circle()
                    .fill(Color(hex: "121212"))
                    .frame(width: diameter * 0.020, height: diameter * 0.020)
            }
            .frame(width: diameter, height: diameter)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct VinylGrooves: View {
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let innerRadius = side * 0.22
            let outerRadius = side * 0.49
            let ringCount = 34

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
                    with: .color(
                        index.isMultiple(of: 5)
                            ? Color(hex: "D39B47").opacity(0.16)
                            : Color.white.opacity(0.055)
                    ),
                    lineWidth: index.isMultiple(of: 5) ? 0.8 : 0.5
                )
            }
        }
    }
}

private struct VinylCenterLabel: View {
    let entry: NowPlayingEntry
    let diameter: CGFloat
    let accentColor: Color
    let secondaryAccentColor: Color

    var body: some View {
        ZStack {
            if let data = entry.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.98),
                                Color(hex: "F4C928"),
                                secondaryAccentColor.opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "music.note")
                    .font(.system(size: diameter * 0.28, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.54))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.20)
                        ],
                        center: .center,
                        startRadius: diameter * 0.08,
                        endRadius: diameter * 0.52
                    )
                )

            Circle()
                .stroke(Color.black.opacity(0.42), lineWidth: max(2, diameter * 0.055))

            Circle()
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                .padding(max(2, diameter * 0.035))
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct VinylTonearmView: View {
    let scale: CGFloat
    let isActive: Bool
    let accentColor: Color

    private var pivotDiameter: CGFloat { scale * 0.24 }
    private var armLength: CGFloat { scale * 0.78 }
    private var armThickness: CGFloat { scale * 0.105 }
    private var angle: Double { isActive ? -45 : -36 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            arm
                .rotationEffect(.degrees(angle), anchor: .trailing)
                .offset(x: -scale * 0.075, y: scale * 0.12)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: pivotDiameter * 1.12, height: pivotDiameter * 1.12)
                    .blur(radius: scale * 0.025)
                    .offset(y: scale * 0.018)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(hex: "E7E8E6"),
                                Color(hex: "C9CBC9")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: pivotDiameter, height: pivotDiameter)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: max(1, scale * 0.014))
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.70))
                            .frame(width: pivotDiameter * 0.52, height: pivotDiameter * 0.52)
                            .offset(x: -pivotDiameter * 0.12, y: -pivotDiameter * 0.12)
                    )
            }
        }
        .frame(width: scale, height: scale, alignment: .topTrailing)
    }

    private var arm: some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.14))
                .frame(width: armLength, height: armThickness * 0.72)
                .blur(radius: scale * 0.018)
                .offset(y: scale * 0.025)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(hex: "F2F2F0"),
                            Color(hex: "D5D6D4")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: armLength, height: armThickness)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.90), lineWidth: max(1, scale * 0.010))
                )

            RoundedRectangle(cornerRadius: armThickness * 0.44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(hex: "D5D6D3")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: scale * 0.22, height: armThickness * 1.42)
                .overlay(
                    Circle()
                        .fill(Color(hex: "FFD440"))
                        .frame(width: armThickness * 0.56, height: armThickness * 0.56)
                        .overlay(Circle().stroke(accentColor.opacity(0.38), lineWidth: 1))
                        .offset(x: -scale * 0.047)
                )
                .offset(x: -scale * 0.025)
        }
        .frame(width: armLength, height: armThickness * 1.55)
    }
}

private struct VinylMediumConsole: View {
    let entry: NowPlayingEntry
    let accentColor: Color
    let isDark: Bool

    private var songName: String {
        entry.isEmpty ? "未在播放" : entry.songName
    }

    private var artistName: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    private var sourceName: String {
        entry.sourceName.isEmpty ? entry.qualityText : entry.sourceName.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)

                Text(sourceName)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? Color.white.opacity(0.56) : Color(hex: "4A4B4A"))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if !entry.qualityText.isEmpty, sourceName != entry.qualityText {
                    Text(entry.qualityText)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isDark ? Color.white.opacity(0.32) : Color(hex: "8C8E8B"))
                }
            }

            Spacer(minLength: 6)

            Text(songName)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(isDark ? Color.white.opacity(0.94) : Color(hex: "151615"))
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(artistName)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(isDark ? Color.white.opacity(0.46) : Color(hex: "747673"))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, 3)

            Spacer(minLength: 6)

            if !entry.isEmpty {
                VinylTransportControls(
                    entry: entry,
                    diameter: 28,
                    foregroundColor: isDark ? Color.white.opacity(0.72) : Color(hex: "222322"),
                    prominentFill: accentColor
                )
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color(hex: "2A2B29"), Color(hex: "151614")]
                            : [Color.white.opacity(0.82), Color(hex: "ECEDEB").opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(isDark ? 0.10 : 0.96), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.28 : 0.08), radius: 7, y: 3)
        )
    }
}

private struct VinylLargeConsole: View {
    let entry: NowPlayingEntry
    let accentColor: Color
    let isDark: Bool

    private var progress: CGFloat {
        guard entry.playbackDuration > 0 else { return 0 }
        return CGFloat(min(1, max(0, entry.playbackCurrentTime / entry.playbackDuration)))
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if !entry.sourceName.isEmpty {
                    Text(entry.sourceName.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                }

                Text(entry.isEmpty ? "未在播放" : entry.songName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(entry.isEmpty ? "暂无歌曲信息" : entry.artistName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.isEmpty {
                VinylTransportControls(
                    entry: entry,
                    diameter: 36,
                    foregroundColor: Color.white.opacity(0.78),
                    prominentFill: accentColor
                )
            }
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color(hex: "1C1D1B"), Color(hex: "070807")]
                            : [Color(hex: "242523"), Color(hex: "111211")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.20), radius: 10, y: 5)
        )
        .overlay(alignment: .bottomLeading) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.10))
                    Capsule(style: .continuous)
                        .fill(accentColor.opacity(0.90))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 25)
            .padding(.bottom, 8)
        }
    }
}

private struct VinylTransportControls: View {
    let entry: NowPlayingEntry
    let diameter: CGFloat
    let foregroundColor: Color
    let prominentFill: Color

    var body: some View {
        HStack(spacing: diameter * 0.34) {
            Button(intent: PreviousTrackIntent()) {
                Image(systemName: "backward.fill")
                    .font(.system(size: diameter * 0.31, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(width: diameter * 0.76, height: diameter)
            }
            .buttonStyle(.plain)

            Button(intent: TogglePlaybackIntent()) {
                ZStack {
                    Circle()
                        .fill(prominentFill)
                    Image(systemName: entry.controlSymbolName)
                        .font(.system(size: diameter * 0.36, weight: .black))
                        .foregroundStyle(entry.coverIsDark ? Color.white : Color(hex: "141514"))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: diameter, height: diameter)
                .shadow(color: prominentFill.opacity(0.24), radius: 5, y: 2)
            }
            .buttonStyle(.plain)

            Button(intent: NextTrackIntent()) {
                Image(systemName: "forward.fill")
                    .font(.system(size: diameter * 0.31, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(width: diameter * 0.76, height: diameter)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TurntableKnob: View {
    let entry: NowPlayingEntry
    let diameter: CGFloat
    let isDark: Bool

    var body: some View {
        HStack(spacing: diameter * 0.34) {
            if entry.isEmpty {
                knob
            } else {
                Button(intent: TogglePlaybackIntent()) {
                    knob
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.isPlaying ? "暂停" : "播放")
            }

            plusMark
        }
        .frame(width: diameter * 2.0, height: diameter * 1.45, alignment: .leading)
    }

    private var knob: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(isDark ? 0.34 : 0.10))
                .frame(width: diameter * 1.08, height: diameter * 1.08)
                .blur(radius: diameter * 0.11)
                .offset(y: diameter * 0.10)

            Circle()
                .fill(
                    LinearGradient(
                        colors: isDark
                            ? [Color(hex: "4A4C48"), Color(hex: "292A28"), Color(hex: "111210")]
                            : [Color.white, Color(hex: "F1F1EF"), Color(hex: "DCDDDC")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .stroke(
                            isDark ? Color.white.opacity(0.14) : Color(hex: "D7D9D7"),
                            lineWidth: 1
                        )
                )

            Capsule(style: .continuous)
                .fill(isDark ? Color.white.opacity(0.32) : Color(hex: "C9CBC9"))
                .frame(width: max(1.5, diameter * 0.055), height: diameter * 0.25)
                .offset(y: -diameter * 0.27)
        }
        .frame(width: diameter, height: diameter)
    }

    private var plusMark: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(isDark ? Color.white.opacity(0.18) : Color(hex: "D4D6D4"))
                .frame(width: diameter * 0.52, height: max(1.5, diameter * 0.07))
            Capsule(style: .continuous)
                .fill(isDark ? Color.white.opacity(0.18) : Color(hex: "D4D6D4"))
                .frame(width: max(1.5, diameter * 0.07), height: diameter * 0.52)
        }
        .frame(width: diameter * 0.52, height: diameter * 0.52)
    }
}

private struct SpeakerGrille: View {
    let spacing: CGFloat
    let isDark: Bool

    var body: some View {
        Canvas { context, size in
            let columns = 4
            let rows = 3
            let dotDiameter = max(2, spacing * 0.36)
            let totalWidth = CGFloat(columns - 1) * spacing
            let totalHeight = CGFloat(rows - 1) * spacing
            let origin = CGPoint(
                x: (size.width - totalWidth) * 0.5,
                y: (size.height - totalHeight) * 0.5
            )

            for row in 0..<rows {
                for column in 0..<columns {
                    let center = CGPoint(
                        x: origin.x + CGFloat(column) * spacing,
                        y: origin.y + CGFloat(row) * spacing
                    )
                    let rect = CGRect(
                        x: center.x - dotDiameter * 0.5,
                        y: center.y - dotDiameter * 0.5,
                        width: dotDiameter,
                        height: dotDiameter
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(
                            isDark
                                ? Color.white.opacity(0.22)
                                : Color(hex: "BFC1BF").opacity(0.78)
                        )
                    )
                }
            }
        }
    }
}
