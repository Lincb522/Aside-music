import AppIntents
import SwiftUI
import WidgetKit

struct MangaTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let ink = Color(hex: "141416")
    private let paper = Color(hex: "F3F0E9")
    private let paperLight = Color(hex: "FCFBF7")
    private let gray = Color(hex: "757278")
    private let paleGray = Color(hex: "D9D6CF")

    private var song: String {
        entry.isEmpty ? "未在播放" : entry.songName
    }

    private var artist: String {
        entry.isEmpty ? "暂无歌曲信息" : entry.artistName
    }

    private var lyric: String {
        entry.lyricText
    }

    private func paperBackground(size: CGSize) -> some View {
        ZStack {
            paper

            Canvas { context, canvasSize in
                let gap: CGFloat = 10
                let radius: CGFloat = 0.7
                var row = 0
                var y: CGFloat = 5

                while y < canvasSize.height {
                    var x: CGFloat = row.isMultiple(of: 2) ? 5 : 10
                    while x < canvasSize.width {
                        context.fill(
                            Path(
                                ellipseIn: CGRect(
                                    x: x - radius,
                                    y: y - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                )
                            ),
                            with: .color(ink.opacity(0.095))
                        )
                        x += gap
                    }
                    row += 1
                    y += gap
                }
            }

            LinearGradient(
                colors: [Color.white.opacity(0.34), .clear, ink.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(width: size.width, height: size.height)
    }

    private func albumImage() -> some View {
        Group {
            if let data = entry.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .saturation(0)
                    .contrast(1.12)
            } else {
                ZStack {
                    paleGray
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(gray)
                }
            }
        }
    }

    private var artwork: some View {
        GeometryReader { proxy in
            albumImage()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .overlay(
            Canvas { context, size in
                let gap: CGFloat = 7
                var y: CGFloat = 3
                while y < size.height {
                    var x: CGFloat = 3
                    while x < size.width {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(ink.opacity(0.08))
                        )
                        x += gap
                    }
                    y += gap
                }
            }
        )
    }

    private func statusLabel(compact: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.system(size: compact ? 7 : 8, weight: .black))

            Text("NOW PLAYING")
                .font(.system(size: compact ? 7 : 8, weight: .black, design: .rounded))
                .tracking(compact ? 0.2 : 0.6)
                .lineLimit(1)
        }
        .foregroundStyle(paperLight)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(Rectangle().fill(ink))
    }

    @ViewBuilder
    private func metadata(compact: Bool = false, reversed: Bool = false) -> some View {
        HStack(spacing: compact ? 5 : 8) {
            if !entry.sourceName.isEmpty {
                Text(entry.sourceName.uppercased())
                    .font(.system(size: compact ? 7 : 8, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            if let bpm = entry.tempoBPM, bpm > 0 {
                Text("\(bpm) BPM")
                    .font(.system(size: compact ? 7 : 8, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .foregroundStyle(reversed ? paperLight.opacity(0.72) : gray)
    }

    private func qualityLabel(compact: Bool = false) -> some View {
        Group {
            if !entry.qualityText.isEmpty {
                Text(entry.qualityText)
                    .font(.system(size: compact ? 7 : 8, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, compact ? 6 : 8)
                    .padding(.vertical, compact ? 3 : 4)
                    .background(Rectangle().fill(paperLight))
                    .overlay(Rectangle().stroke(ink, lineWidth: 1.8))
            }
        }
    }

    private func controlButton(
        intent: some AppIntent,
        icon: String,
        side: CGFloat,
        primary: Bool
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: side * 0.4, weight: .black))
                .foregroundStyle(primary ? paperLight : ink)
                .frame(width: side, height: side)
                .background(Circle().fill(primary ? ink : paperLight))
                .overlay(Circle().stroke(ink, lineWidth: primary ? 2.8 : 2.2))
        }
        .buttonStyle(.plain)
    }

    private func controls(compact: Bool) -> some View {
        let secondarySide: CGFloat = compact ? 23 : 33
        let primarySide: CGFloat = compact ? 31 : 44

        return HStack(spacing: compact ? 6 : 10) {
            controlButton(
                intent: PreviousTrackIntent(),
                icon: "backward.fill",
                side: secondarySide,
                primary: false
            )
            controlButton(
                intent: TogglePlaybackIntent(),
                icon: entry.controlSymbolName,
                side: primarySide,
                primary: true
            )
            controlButton(
                intent: NextTrackIntent(),
                icon: "forward.fill",
                side: secondarySide,
                primary: false
            )
        }
    }

    private func playbackRow(compact: Bool, showsMetadata: Bool) -> some View {
        HStack(spacing: compact ? 7 : 12) {
            if entry.isEmpty {
                Image(systemName: "music.note")
                    .font(.system(size: compact ? 16 : 20, weight: .black))
                    .foregroundStyle(gray)
                    .frame(height: compact ? 31 : 44)
            } else {
                controls(compact: compact)
            }

            if showsMetadata {
                Spacer(minLength: 0)
                metadata(compact: compact)
            }
        }
    }

    // MARK: - Small

    private var smallWidget: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let artworkHeight = height * 0.46

            ZStack {
                paperBackground(size: geometry.size)

                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        artwork
                            .frame(width: width, height: artworkHeight)

                        statusLabel(compact: true)
                            .padding(8)
                    }
                    .frame(height: artworkHeight)
                    .clipped()

                    Rectangle()
                        .fill(ink)
                        .frame(height: 3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.48)

                        HStack(spacing: 6) {
                            Text(artist)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(gray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)

                            Spacer(minLength: 0)
                            qualityLabel(compact: true)
                        }

                        Rectangle()
                            .fill(ink.opacity(0.2))
                            .frame(height: 1)

                        playbackRow(compact: true, showsMetadata: false)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(paperLight.opacity(0.88))
                }

                ContainerRelativeShape()
                    .stroke(ink, lineWidth: 2)
            }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Medium

    private var mediumWidget: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let artworkWidth = width * 0.42

            ZStack {
                paperBackground(size: geometry.size)

                HStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        artwork
                            .frame(width: artworkWidth)

                        statusLabel(compact: true)
                            .padding(9)
                    }
                    .frame(width: artworkWidth)
                    .clipped()

                    Rectangle()
                        .fill(ink)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            metadata(compact: true)
                            Spacer(minLength: 0)
                            qualityLabel(compact: true)
                        }

                        Text(song)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.48)

                        Text(artist)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(gray)
                            .lineLimit(1)

                        Rectangle()
                            .fill(ink)
                            .frame(height: 2)

                        if !lyric.isEmpty {
                            Text(lyric)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(ink.opacity(0.78))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                        }

                        Spacer(minLength: 0)

                        playbackRow(compact: true, showsMetadata: false)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(paperLight.opacity(0.88))
                }

                ContainerRelativeShape()
                    .stroke(ink, lineWidth: 2)
            }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Large

    private var largeWidget: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let heroHeight = height * 0.58
            let artworkWidth = width * 0.54

            ZStack {
                paperBackground(size: geometry.size)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            artwork
                                .frame(width: artworkWidth, height: heroHeight)

                            statusLabel()
                                .padding(11)
                        }
                        .frame(width: artworkWidth, height: heroHeight)
                        .clipped()

                        Rectangle()
                            .fill(ink)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                metadata()
                                Spacer(minLength: 0)
                            }

                            Text(song)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                                .lineLimit(3)
                                .minimumScaleFactor(0.42)

                            Rectangle()
                                .fill(ink)
                                .frame(height: 3)

                            Text(artist)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(gray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)

                            Spacer(minLength: 0)
                            qualityLabel()
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, maxHeight: heroHeight, alignment: .topLeading)
                        .background(paperLight.opacity(0.9))
                    }
                    .frame(height: heroHeight)

                    Rectangle()
                        .fill(ink)
                        .frame(height: 3)

                    VStack(spacing: 8) {
                        if !lyric.isEmpty {
                            Text(lyric)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(ink.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.55)
                                .frame(maxWidth: .infinity)
                        }

                        Rectangle()
                            .fill(ink.opacity(0.18))
                            .frame(height: 1)

                        playbackRow(compact: false, showsMetadata: false)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxHeight: .infinity)
                    .background(paperLight.opacity(0.88))
                }

                ContainerRelativeShape()
                    .stroke(ink, lineWidth: 2)
            }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            largeWidget
        }
    }
}
