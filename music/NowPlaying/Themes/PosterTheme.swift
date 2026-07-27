import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Poster Theme (海报)

struct PosterWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private var displaySong: String { entry.isEmpty ? "Not Playing" : entry.songName }
    private var displayArtist: String { entry.isEmpty ? "Mono" : entry.artistName }
    private var displayLyric: String { entry.lyricText.isEmpty ? "" : entry.lyricText }

    @ViewBuilder
    private func coverFill(width: CGFloat, height: CGFloat) -> some View {
        if let data = entry.coverImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } else {
            Color(hex: "0A0A0C")
                .frame(width: width, height: height)
        }
    }

    private var qualityBadge: some View {
        Group {
            if !entry.qualityText.isEmpty {
                Text(entry.qualityText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        GeometryReader { geo in
        ZStack {
            coverFill(width: geo.size.width, height: geo.size.height)

            LinearGradient(
                colors: [.black.opacity(0.3), .clear, .black.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Text(displayArtist.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(displaySong)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)

                    Text(displayArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

                if !entry.isEmpty {
                    HStack(spacing: 14) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill").font(.system(size: 12))
                        }.buttonStyle(.plain)
                        Button(intent: TogglePlaybackIntent()) {
                            Image(systemName: entry.controlSymbolName).font(.system(size: 16, weight: .bold))
                                .contentTransition(.symbolEffect(.replace))
                        }.buttonStyle(.plain)
                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill").font(.system(size: 12))
                        }.buttonStyle(.plain)
                    }
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
            }
        }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            ZStack {
                coverFill(width: geo.size.width, height: geo.size.height)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.3), .black.opacity(0.8)],
                    startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                VStack {
                    Spacer()

                    HStack(alignment: .bottom, spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            qualityBadge

                            if !displayLyric.isEmpty {
                                Text(displayLyric)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .italic()
                                    .minimumScaleFactor(0.7)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }

                            Text(displaySong)
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.65)
                                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)

                            Text(displayArtist)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        }

                        Spacer(minLength: 12)

                        if !entry.isEmpty {
                            VStack(spacing: 6) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill").font(.system(size: 11))
                                        .frame(width: 30, height: 30)
                                        .background(Color.white.opacity(0.15), in: Circle())
                                }.buttonStyle(.plain)
                                Button(intent: TogglePlaybackIntent()) {
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 16, weight: .bold))
                                        .contentTransition(.symbolEffect(.replace))
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial, in: Circle())
                                }.buttonStyle(.plain)
                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill").font(.system(size: 11))
                                        .frame(width: 30, height: 30)
                                        .background(Color.white.opacity(0.15), in: Circle())
                                }.buttonStyle(.plain)
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .widgetURL(URL(string: "mono://player"))
    }

    // MARK: - Large

    private var largeLayout: some View {
        GeometryReader { geo in
        ZStack {
            coverFill(width: geo.size.width, height: geo.size.height)

            LinearGradient(
                colors: [.black.opacity(0.15), .clear, .clear, .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    qualityBadge
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()

                if !displayLyric.isEmpty {
                    Text("~ \(displayLyric) ~")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                Text(displaySong)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 20)

                Text(displayArtist)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 20)
                    .padding(.top, 3)

                if !entry.albumName.isEmpty {
                    Text(entry.albumName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 20)
                        .padding(.top, 1)
                }

                if !entry.isEmpty {
                    HStack(spacing: 24) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill").font(.system(size: 18))
                        }.buttonStyle(.plain)
                        Button(intent: TogglePlaybackIntent()) {
                            Image(systemName: entry.controlSymbolName)
                                .font(.system(size: 26, weight: .bold))
                                .contentTransition(.symbolEffect(.replace))
                        }.buttonStyle(.plain)
                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill").font(.system(size: 18))
                        }.buttonStyle(.plain)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(entry.sourceName.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                            Text(entry.playModeText)
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        }
        .widgetURL(URL(string: "mono://player"))
    }
}
