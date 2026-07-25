import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Manga Theme (日漫風)

private struct MangaStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let r = rect.width / 2
        let sides = 5
        let angle = -CGFloat.pi / 2
        for i in 0..<sides * 2 {
            let radius = i.isMultiple(of: 2) ? r : r * 0.45
            let theta = angle + CGFloat(i) * .pi / CGFloat(sides)
            let pt = CGPoint(x: center.x + radius * cos(theta), y: center.y + radius * sin(theta))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

private struct MangaSparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w/2, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: h/2), control: CGPoint(x: w/2, y: h/2))
        path.addQuadCurve(to: CGPoint(x: w/2, y: h), control: CGPoint(x: w/2, y: h/2))
        path.addQuadCurve(to: CGPoint(x: 0, y: h/2), control: CGPoint(x: w/2, y: h/2))
        path.addQuadCurve(to: CGPoint(x: w/2, y: 0), control: CGPoint(x: w/2, y: h/2))
        return path
    }
}

private struct MangaHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w/2, y: h * 0.25))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.3), control1: CGPoint(x: w * 0.25, y: -0.15 * h), control2: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: w/2, y: h * 0.95), control1: CGPoint(x: 0, y: h * 0.7), control2: CGPoint(x: w * 0.25, y: h * 0.85))
        path.addCurve(to: CGPoint(x: w, y: h * 0.3), control1: CGPoint(x: w * 0.75, y: h * 0.85), control2: CGPoint(x: w, y: h * 0.7))
        path.addCurve(to: CGPoint(x: w/2, y: h * 0.25), control1: CGPoint(x: w, y: 0), control2: CGPoint(x: w * 0.75, y: -0.15 * h))
        return path
    }
}

private struct MangaChatBubbleShape: Shape {
    var cornerRadius: CGFloat = 16
    var tailSize: CGFloat = 8
    var tailOffset: CGFloat = 34

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let bl = CGPoint(x: rect.minX + tailSize, y: rect.maxY)
        let tl = CGPoint(x: rect.minX + tailSize, y: rect.minY)

        path.move(to: CGPoint(x: tl.x + cornerRadius, y: tl.y))
        path.addLine(to: CGPoint(x: tr.x - cornerRadius, y: tr.y))
        path.addArc(center: CGPoint(x: tr.x - cornerRadius, y: tr.y + cornerRadius), radius: cornerRadius, startAngle: .degrees(-90), endAngle: .zero, clockwise: false)
        path.addLine(to: CGPoint(x: br.x, y: br.y - cornerRadius))
        path.addArc(center: CGPoint(x: br.x - cornerRadius, y: br.y - cornerRadius), radius: cornerRadius, startAngle: .zero, endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bl.x + cornerRadius, y: bl.y))
        path.addArc(center: CGPoint(x: bl.x + cornerRadius, y: bl.y - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        path.addLine(to: CGPoint(x: tl.x, y: tl.y + tailOffset + tailSize))
        path.addLine(to: CGPoint(x: rect.minX, y: tl.y + tailOffset + tailSize / 2))
        path.addLine(to: CGPoint(x: tl.x, y: tl.y + tailOffset))

        path.addLine(to: CGPoint(x: tl.x, y: tl.y + cornerRadius))
        path.addArc(center: CGPoint(x: tl.x + cornerRadius, y: tl.y + cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        return path
    }
}

private struct MangaMicroAnimator: ViewModifier {
    var type: AnimationType

    enum AnimationType {
        case pulse
        case twinkle
        case wobble
        case float
    }

    private var period: TimeInterval {
        switch type {
        case .pulse:
            return 1.6
        case .twinkle:
            return 2.4
        case .wobble:
            return 4.0
        case .float:
            return 3.0
        }
    }

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = phaseValue(for: timeline.date)
            animated(content: content, phase: phase)
        }
    }

    @ViewBuilder
    private func animated(content: Content, phase: CGFloat) -> some View {
        switch type {
        case .pulse:
            content.scaleEffect(1.0 + 0.15 * phase)
        case .twinkle:
            content
                .scaleEffect(0.85 + 0.25 * phase)
                .opacity(0.6 + 0.4 * phase)
        case .wobble:
            content.rotationEffect(.degrees(-6 + 12 * Double(phase)))
        case .float:
            content.offset(y: 3 - 6 * phase)
        }
    }

    private func phaseValue(for date: Date) -> CGFloat {
        let raw = date.timeIntervalSinceReferenceDate / period
        let wave = (sin(raw * .pi * 2.0) + 1.0) * 0.5
        return CGFloat(wave)
    }
}

struct MangaTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let ink = Color(hex: "2D2D3A")
    private let inkSub = Color(hex: "8888A0")
    private let accentPink = Color(hex: "FF8FAB")
    private let labelYellow = Color(hex: "FFE4B5")
    private let decoBlue = Color(hex: "B8D4F0")

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    private var song: String { entry.isEmpty ? "未在播放" : entry.songName }
    private var artist: String { entry.isEmpty ? "暂无歌曲信息" : entry.artistName }
    private var lyric: String { entry.lyricText }

    private var bgColors: [Color] {
        [Color(hex: "E8F4FD"), Color(hex: "FDE8F0"), Color(hex: "FFF8EC")]
    }

    private var extractedPlayBtn: Color {
        guard entry.dominantRGB.count == 3, !entry.isEmpty else { return Color(hex: "5E5A53") }
        return Color(red: Double(entry.dominantRGB[0]), green: Double(entry.dominantRGB[1]), blue: Double(entry.dominantRGB[2]))
    }

    private func mangaCanvasBackdrop(size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, sz in
                let gap: CGFloat = 16
                let dotR: CGFloat = 1.0
                var y: CGFloat = gap/2
                var isEven = true
                while y < sz.height + gap {
                    var x: CGFloat = isEven ? gap/2 : gap
                    while x < sz.width + gap {
                        let rect = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.12)))
                        x += gap
                    }
                    y += gap
                    isEven.toggle()
                }
            }
        }
    }

    private func coverView(side: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let d = entry.coverImageData, let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        labelYellow.opacity(0.4)
                        Image(systemName: "music.note")
                            .font(.system(size: side * 0.28, weight: .medium))
                            .foregroundStyle(inkSub.opacity(0.45))
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .stroke(ink, lineWidth: 3)
            )
            .background(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .fill(ink)
                    .offset(x: 4, y: 4)
            )

            if !entry.qualityText.isEmpty {
                Text(entry.qualityText)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(labelYellow))
                    .overlay(Capsule().stroke(ink, lineWidth: 2.5))
                    .background(Capsule().fill(ink).offset(x: 2.5, y: 2.5))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 12, y: -4)
            }
        }
    }

    private var nowPlayingHeader: some View {
        HStack(spacing: 3) {
            Image(systemName: "music.note")
                .font(.system(size: 8, weight: .black))
            Text("NOW PLAYING")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(labelYellow))
        .overlay(Capsule().stroke(ink, lineWidth: 2.5))
        .background(Capsule().fill(ink).offset(x: 2.5, y: 2.5))
    }

    private func mangaBubble<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.leading, 20)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MangaChatBubbleShape().fill(Color.white))
            .overlay(MangaChatBubbleShape().stroke(ink, lineWidth: 3.5))
            .background(MangaChatBubbleShape().fill(ink).offset(x: 4.5, y: 4.5))
    }

    private enum MediaBtnStyle {
        case normal
        case play
    }

    private func mediaButton(intent: some AppIntent, icon: String, w: CGFloat, h: CGFloat, style: MediaBtnStyle) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: min(w, h) * 0.45, weight: .black))
                .foregroundStyle(style == .play ? Color.white : ink)
                .frame(width: w, height: h)
                .background(
                    RoundedRectangle(cornerRadius: min(w, h) * 0.35, style: .continuous)
                        .fill(style == .play ? extractedPlayBtn : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: min(w, h) * 0.35, style: .continuous)
                        .stroke(ink, lineWidth: 3)
                )
                .background(
                    RoundedRectangle(cornerRadius: min(w, h) * 0.35, style: .continuous)
                        .fill(ink)
                        .offset(x: 3, y: 3)
                )
        }
        .buttonStyle(.plain)
    }

    private var bpmFooter: some View {
        Group {
            if let b = entry.tempoBPM, b > 0 {
                HStack(spacing: 2) {
                    Text("\(b)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(inkSub.opacity(0.8))

                    ZStack {
                        MangaHeartShape().fill(accentPink)
                        MangaHeartShape().stroke(ink, lineWidth: 1.5)
                    }
                    .frame(width: 9, height: 8)
                    .offset(y: -1)
                    .modifier(MangaMicroAnimator(type: .pulse))

                    Text("bpm")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(inkSub.opacity(0.8))
                }
            } else {
                ZStack {
                    MangaHeartShape().fill(accentPink)
                    MangaHeartShape().stroke(ink, lineWidth: 1.5)
                }
                .frame(width: 12, height: 10)
            }
        }
    }

    // MARK: - Small

    private var smallWidget: some View {
        GeometryReader { g in
            let coverSide = max(g.size.width * 0.46, 60)

            ZStack {
                mangaCanvasBackdrop(size: g.size)

                // 漫画风背景点缀装饰
                ZStack {
                    ZStack {
                        MangaSparkleShape().fill(accentPink)
                        MangaSparkleShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(10))
                    .modifier(MangaMicroAnimator(type: .twinkle))
                    .position(x: 20, y: 26) // Hugging top-left of cover

                    ZStack {
                        MangaStarShape().fill(labelYellow)
                        MangaStarShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(20))
                    .modifier(MangaMicroAnimator(type: .wobble))
                    .position(x: g.size.width - 24, y: 20)

                    ZStack {
                        Circle().fill(Color(hex: "CEF09D")) // Lime green dot
                        Circle().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 8, height: 8)
                    .modifier(MangaMicroAnimator(type: .float))
                    .position(x: 26, y: g.size.height - 24)

                    ZStack {
                        MangaHeartShape().fill(accentPink)
                        MangaHeartShape().stroke(ink, lineWidth: 1.5)
                    }
                    .frame(width: 14, height: 12)
                    .rotationEffect(.degrees(-15))
                    .modifier(MangaMicroAnimator(type: .pulse))
                    .position(x: g.size.width - 20, y: g.size.height - 24)
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    HStack(alignment: .center, spacing: 10) {
                        coverView(side: coverSide)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(song)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                                .lineLimit(3)
                                .minimumScaleFactor(0.4)

                            Text(artist)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(inkSub)
                                .lineLimit(2)
                                .minimumScaleFactor(0.4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)

                    Spacer(minLength: 14)

                    if !entry.isEmpty {
                        HStack(spacing: 6) {
                            mediaButton(intent: PreviousTrackIntent(), icon: "backward.fill", w: 26, h: 22, style: .normal)
                            mediaButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, w: 32, h: 36, style: .play)
                            mediaButton(intent: NextTrackIntent(), icon: "forward.fill", w: 26, h: 22, style: .normal)
                        }
                        .padding(.bottom, 16)
                    } else {
                        Spacer().frame(height: 16)
                    }
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumWidget: some View {
        GeometryReader { g in
            ZStack {
                mangaCanvasBackdrop(size: g.size)

                // Widget outer comic border
                ContainerRelativeShape()
                    .stroke(ink, lineWidth: 2)

                // Background decorations
                ZStack {
                    ZStack {
                        MangaSparkleShape().fill(accentPink)
                        MangaSparkleShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(10))
                    .modifier(MangaMicroAnimator(type: .twinkle))
                    .position(x: 14, y: 14)

                    ZStack {
                        MangaStarShape().fill(labelYellow)
                        MangaStarShape().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(20))
                    .modifier(MangaMicroAnimator(type: .wobble))
                    .position(x: g.size.width - 20, y: 16)

                    ZStack {
                        Circle().fill(Color(hex: "CEF09D"))
                        Circle().stroke(ink, lineWidth: 2)
                    }
                    .frame(width: 6, height: 6)
                    .modifier(MangaMicroAnimator(type: .float))
                    .position(x: 24, y: g.size.height - 18)
                }
                .allowsHitTesting(false)

                ZStack(alignment: .top) {
                    HStack(alignment: .center, spacing: 14) { // Reverted back to .center for layout symmetry
                        coverView(side: 104) // Much larger cover taking full height

                        // Right column layout
                        VStack(alignment: .leading, spacing: 10) { // Increased spacing to detach play controls from bubble
                            mangaBubble {
                                VStack(alignment: .leading, spacing: 2) {
                                    Spacer().frame(height: 10) // Internal top buffer for the overlay header

                                    Text(song)
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(ink)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.4)

                                    Text(artist)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(inkSub)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)

                                    if !lyric.isEmpty {
                                        Rectangle()
                                            .fill(ink.opacity(0.12))
                                            .frame(height: 1)
                                            .padding(.vertical, 2)

                                        Text(lyric)
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(ink.opacity(0.8))
                                            .lineLimit(4) // Cap at 4 lines so the engine can bound and scale the text instead of discarding it out of bounds
                                            .minimumScaleFactor(0.5) // Gracefully scale down text size if it fills up the entire layout height
                                    }
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                nowPlayingHeader
                                    .alignmentGuide(.top) { d in d[VerticalAlignment.center] }
                                    .offset(x: 24, y: 0)
                            }
                            // Extra space below the bubble to accommodate play controls tightly

                            if !entry.isEmpty {
                                HStack(spacing: 6) {
                                    mediaButton(intent: PreviousTrackIntent(), icon: "backward.fill", w: 26, h: 22, style: .normal)
                                    mediaButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, w: 32, h: 32, style: .play)
                                    mediaButton(intent: NextTrackIntent(), icon: "forward.fill", w: 26, h: 22, style: .normal)
                                }
                                .padding(.leading, 8) // Align perfectly flush with the bubble's square edge (bypassing the tail width)
                                .padding(.bottom, 8) // Minimized padding to push bubble downward
                            } else {
                                Spacer().frame(height: 32)
                            }
                        }
                        .padding(.top, 24) // Give room for header popping out of top bounds
                    }
                    .frame(maxHeight: .infinity) // Force HStack to capture total fixed widget height, preventing cover from moving when content grows
                    .padding(.horizontal, 16)

                    // BPM Footer overlaid globally bottom right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            bpmFooter
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large

    private var largeWidget: some View {
        GeometryReader { g in
            let coverSide = min(min(g.size.width, g.size.height) * 0.48, 148)

            ZStack {
                mangaCanvasBackdrop(size: g.size)

                VStack {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundStyle(decoBlue.opacity(0.45))
                        Spacer()
                    }
                    .padding(14)
                    Spacer()
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        nowPlayingHeader
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)

                    Spacer(minLength: 8)

                    coverView(side: coverSide)

                    Text(song)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    Text(artist)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(inkSub)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    if !lyric.isEmpty {
                        Text(lyric)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(ink.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, 22)
                            .padding(.top, 10)
                    }

                    Spacer(minLength: 8)

                    if !entry.isEmpty {
                        HStack(spacing: 10) {
                            mediaButton(intent: PreviousTrackIntent(), icon: "backward.fill", w: 42, h: 34, style: .normal)
                            mediaButton(intent: TogglePlaybackIntent(), icon: entry.controlSymbolName, w: 50, h: 50, style: .play)
                            mediaButton(intent: NextTrackIntent(), icon: "forward.fill", w: 42, h: 34, style: .normal)
                        }
                        .padding(.bottom, 8)
                    }

                    HStack {
                        if !entry.sourceName.isEmpty {
                            Text(entry.sourceName.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(inkSub.opacity(0.65))
                        }
                        Spacer()
                        bpmFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    var body: some View {
        switch family {
        case .systemSmall:  smallWidget
        case .systemMedium: mediumWidget
        default:            largeWidget
        }
    }
}
