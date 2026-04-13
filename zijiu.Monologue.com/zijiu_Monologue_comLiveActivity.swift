import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

private let liveActivityAppGroupID = "group.zijiu.Monologue.com"

struct zijiu_Monologue_comLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            VinylLockScreenActivityView(state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        }
    }
}

private struct VinylLockScreenActivityView: View {
    let state: LyricsActivityAttributes.ContentState

    private let accentColor = Color(hex: "FF8A5B")
    private let accentSecondaryColor = Color(hex: "FFD166")
    private let mintAccent = Color(hex: "77E6B6")

    private var shouldAnimate: Bool {
        state.isPlaying
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !shouldAnimate)) { context in
            let animationDate = shouldAnimate ? context.date : state.updatedAt

            GeometryReader { geo in
                let recordSize = min(geo.size.height * 0.78, geo.size.width * 0.28)
                let deckSize = recordSize + 18

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "06070B"),
                                    Color(hex: "10131A"),
                                    Color(hex: "05060A")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .fill(accentColor.opacity(0.24))
                        .frame(width: geo.size.height * 1.15, height: geo.size.height * 1.15)
                        .blur(radius: 42)
                        .offset(x: geo.size.width * 0.24, y: -geo.size.height * 0.22)

                    Circle()
                        .fill(mintAccent.opacity(0.10))
                        .frame(width: geo.size.height * 0.72, height: geo.size.height * 0.72)
                        .blur(radius: 28)
                        .offset(x: -geo.size.width * 0.24, y: geo.size.height * 0.20)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)

                    HStack(spacing: 16) {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .frame(width: deckSize + 10, height: deckSize + 10)

                            Circle()
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                                .frame(width: recordSize * 1.12, height: recordSize * 1.12)

                            LiveActivityVinylRecord(
                                state: state,
                                size: recordSize,
                                accentColor: accentColor,
                                accentSecondaryColor: accentSecondaryColor,
                                animationDate: animationDate
                            )

                            LiveActivityTonearmView(
                                size: recordSize,
                                isActive: state.isPlaying || state.isLoading,
                                accentColor: accentColor
                            )
                            .frame(width: recordSize, height: recordSize)
                            .offset(x: recordSize * 0.01, y: recordSize * 0.02)
                        }
                        .frame(width: deckSize + 10, height: deckSize + 10)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                activityBadge(state.source, accent: accentColor, filled: false)

                                if !state.quality.isEmpty {
                                    activityBadge(state.quality, accent: accentSecondaryColor, filled: true)
                                }

                                Spacer(minLength: 6)

                                Label(state.playbackLabel, systemImage: state.playbackIconName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.82))
                            }

                            Text(state.title)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(state.artist)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(1)

                                if !state.album.isEmpty {
                                    Text(state.album)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.52))
                                        .lineLimit(1)
                                }
                            }

                            Text(state.displayLyric)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let nextLyric = state.nextLyric, !nextLyric.isEmpty {
                                Text(nextLyric)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.50))
                                    .lineLimit(1)
                            }

                            HStack(spacing: 8) {
                                LiveActivityPlaybackWave(
                                    isActive: state.isPlaying,
                                    barCount: 4,
                                    color: accentColor.opacity(0.95),
                                    height: 13,
                                    sampleTime: animationDate.timeIntervalSinceReferenceDate
                                )
                                .frame(width: 18)

                                Text(state.elapsedText(at: animationDate))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)

                                Text("/")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.36))

                                Text(state.durationText)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.58))

                                Spacer(minLength: 8)

                                if !state.source.isEmpty {
                                    Text(state.source)
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(accentColor.opacity(0.96))
                                }
                            }

                            GeometryReader { progressGeo in
                                let progress = state.progressValue(at: animationDate)

                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 5)

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    accentColor,
                                                    accentSecondaryColor
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(10, progressGeo.size.width * progress), height: 5)
                                        .shadow(color: accentColor.opacity(0.34), radius: 10)
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func activityBadge(_ title: String, accent: Color, filled: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(filled ? Color.black.opacity(0.84) : Color.white.opacity(0.92))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? accent.opacity(0.94) : Color.white.opacity(0.06))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(filled ? accent.opacity(0.18) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

private struct LiveActivityVinylRecord: View {
    let state: LyricsActivityAttributes.ContentState
    let size: CGFloat
    let accentColor: Color
    let accentSecondaryColor: Color
    let animationDate: Date

    private let spinDegreesPerSecond: Double = 198

    private func spinAngle(at date: Date) -> Angle {
        let degrees = date.timeIntervalSinceReferenceDate * spinDegreesPerSecond
        return .degrees(degrees.truncatingRemainder(dividingBy: 360))
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.20))
                .frame(width: size * 0.90, height: size * 0.24)
                .blur(radius: size * 0.08)
                .offset(y: size * 0.40)

            Ellipse()
                .fill(Color.black.opacity(0.30))
                .frame(width: size * 0.62, height: size * 0.11)
                .blur(radius: size * 0.045)
                .offset(y: size * 0.43)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "343943"),
                                Color(hex: "15181E")
                            ],
                            center: .center,
                            startRadius: size * 0.36,
                            endRadius: size * 0.52
                        )
                    )

                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: size * 0.008)
                    .frame(width: size * 0.985, height: size * 0.985)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "2B3038"),
                                Color(hex: "14171D"),
                                Color(hex: "0B0D11")
                            ],
                            center: .center,
                            startRadius: size * 0.08,
                            endRadius: size * 0.48
                        )
                    )
                    .frame(width: size * 0.94, height: size * 0.94)

                LiveActivityVinylGrooves()
                    .padding(size * 0.11)
                    .frame(width: size * 0.94, height: size * 0.94)

                Circle()
                    .trim(from: 0.10, to: 0.31)
                    .stroke(
                        accentColor.opacity(0.46),
                        style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round)
                    )
                    .frame(width: size * 0.76, height: size * 0.76)
                    .rotationEffect(.degrees(18))
                    .blur(radius: 0.2)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .white.opacity(0.24),
                                .clear,
                                .white.opacity(0.10),
                                .clear,
                                .white.opacity(0.16),
                                .clear
                            ],
                            center: .center
                        ),
                        lineWidth: size * 0.022
                    )
                    .frame(width: size * 0.92, height: size * 0.92)

                LiveActivityVinylLabel(
                    state: state,
                    size: size * 0.42,
                    accentColor: accentColor,
                    accentSecondaryColor: accentSecondaryColor
                )

                Circle()
                    .fill(Color(hex: "F3E3D2").opacity(0.94))
                    .frame(width: size * 0.050, height: size * 0.050)

                Circle()
                    .fill(Color.black.opacity(0.86))
                    .frame(width: size * 0.020, height: size * 0.020)
            }
            .frame(width: size, height: size)
            .rotationEffect(spinAngle(at: animationDate))
        }
        .frame(width: size, height: size)
    }
}

private struct LiveActivityVinylGrooves: View {
    var body: some View {
        Canvas { context, canvasSize in
            let minSide = min(canvasSize.width, canvasSize.height)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let innerRadius = minSide * 0.18
            let outerRadius = minSide * 0.49
            let ringCount = 24

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
                    with: .color(.white.opacity(0.14 - Double(progress) * 0.08)),
                    lineWidth: progress < 0.5 ? 0.5 : 0.75
                )
            }
        }
    }
}

private struct LiveActivityVinylLabel: View {
    let state: LyricsActivityAttributes.ContentState
    let size: CGFloat
    let accentColor: Color
    let accentSecondaryColor: Color

    @State private var coverImage: UIImage?

    var body: some View {
        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.92, height: size * 0.92)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        .clear,
                                        Color.black.opacity(0.14),
                                        Color.black.opacity(0.28)
                                    ],
                                    center: .center,
                                    startRadius: size * 0.02,
                                    endRadius: size * 0.48
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.96),
                                accentSecondaryColor.opacity(0.86),
                                accentColor.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack(spacing: 3) {
                            Text(state.source.isEmpty ? "ASIDE" : state.source)
                                .font(.system(size: size * 0.10, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.72))
                                .lineLimit(1)

                            Text(state.title)
                                .font(.system(size: size * 0.072, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.64))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, size * 0.12)
                        }
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .frame(width: size, height: size)
        .task(id: "\(state.title)|\(state.artist)") {
            coverImage = loadSharedCoverImage()
        }
    }

    private func loadSharedCoverImage() -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: liveActivityAppGroupID
        ) else {
            return nil
        }

        let fileURL = containerURL.appendingPathComponent("widget_cover.jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}

private struct LiveActivityTonearmView: View {
    let size: CGFloat
    let isActive: Bool
    let accentColor: Color

    private var pivotDiameter: CGFloat { size * 0.115 }
    private var armLength: CGFloat { size * 0.49 }
    private var armThickness: CGFloat { size * 0.040 }
    private var restingAngle: Double { 18.0 }
    private var activeAngle: Double { -7.0 }

    private var angle: Double {
        isActive ? activeAngle : restingAngle
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "6C7480"),
                            Color(hex: "343A43")
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

            ZStack(alignment: .trailing) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .frame(width: armLength * 0.96, height: armThickness * 0.60)
                    .blur(radius: size * 0.008)
                    .offset(x: -size * 0.03, y: size * 0.012)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "D9DDE4"),
                                Color(hex: "7B828D"),
                                Color(hex: "C3C8D1")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: armLength, height: armThickness)

                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .frame(width: size * 0.25, height: size * 0.012)
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
            .offset(x: -size * 0.03, y: size * 0.058)
        }
        .frame(width: size, height: size, alignment: .topTrailing)
    }
}

private struct LiveActivityPlaybackWave: View {
    let isActive: Bool
    let barCount: Int
    let color: Color
    let height: CGFloat
    let sampleTime: TimeInterval

    private let phaseOffsets: [Double] = [0.0, 0.9, 1.7, 2.6, 3.4, 4.1]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: barHeight(for: index))
            }
        }
        .frame(height: height)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isActive else { return 2.5 }

        let primary = sin(sampleTime * (3.4 + Double(index) * 0.34) + phaseOffsets[index % phaseOffsets.count])
        let secondary = cos(sampleTime * (2.1 + Double(index) * 0.21) + phaseOffsets[(index + 2) % phaseOffsets.count])
        let amplitude = min(max(0.58 + primary * 0.24 + secondary * 0.16, 0.22), 1.0)
        return max(2.5, height * amplitude)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension LyricsActivityAttributes {
    fileprivate static var preview: LyricsActivityAttributes {
        LyricsActivityAttributes(songID: "preview-song-id")
    }
}

extension LyricsActivityAttributes.ContentState {
    fileprivate var displayLyric: String {
        let trimmed = lyric.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? title : trimmed
    }

    fileprivate var playbackIconName: String {
        switch playbackState {
        case .loading:
            return "hourglass"
        case .playing:
            return "waveform"
        case .paused, .idle:
            return "pause.circle.fill"
        }
    }

    fileprivate var playbackLabel: String {
        switch playbackState {
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

    fileprivate func progressValue(at date: Date) -> CGFloat {
        guard duration > 0 else { return CGFloat(max(0, min(progress, 1))) }
        let elapsed = elapsedValue(at: date)
        return CGFloat(max(0, min(elapsed / duration, 1)))
    }

    fileprivate func elapsedValue(at date: Date) -> Double {
        let delta = isPlaying ? max(0, date.timeIntervalSince(updatedAt)) : 0
        let current = elapsedTime + delta
        guard duration > 0 else { return max(0, current) }
        return max(0, min(duration, current))
    }

    fileprivate func elapsedText(at date: Date) -> String {
        timeString(elapsedValue(at: date))
    }

    fileprivate var durationText: String {
        timeString(duration)
    }

    private func timeString(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded(.down)))
        let minutes = seconds / 60
        let remain = seconds % 60
        return String(format: "%d:%02d", minutes, remain)
    }

    fileprivate static var previewPlaying: Self {
        .init(
            title: "你是我写了一半的情书",
            artist: "Monologue",
            album: "夜幕唱片集",
            source: "QQ MUSIC",
            quality: "SQ",
            lyric: "你是我写了一半的情书，用尽温柔也舍不得停住",
            nextLyric: "风吹过的时候，连回忆都变得发亮",
            playbackState: .playing,
            progress: 0.46,
            elapsedTime: 96,
            duration: 208,
            updatedAt: .now
        )
    }

    fileprivate static var previewPaused: Self {
        .init(
            title: "夜色温柔",
            artist: "Monologue",
            album: "午夜电台",
            source: "NETEASE",
            quality: "HQ",
            lyric: "如果晚风记得，那就把想念吹回我身边",
            nextLyric: "城市灯火慢慢亮起，像你没说出口的答案",
            playbackState: .paused,
            progress: 0.73,
            elapsedTime: 154,
            duration: 211,
            updatedAt: .now
        )
    }
}

#Preview("Notification", as: .content, using: LyricsActivityAttributes.preview) {
    zijiu_Monologue_comLiveActivity()
} contentStates: {
    LyricsActivityAttributes.ContentState.previewPlaying
    LyricsActivityAttributes.ContentState.previewPaused
}
