import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Typewriter Theme (打字机)

struct TypewriterWidgetTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    // Aesthetic Palette
    private var metal: Color { Color(hex: "3C342E") }
    private var metalDark: Color { Color(hex: "28221D") }
    private var paper: Color { Color(hex: "DED0B6") }
    private var paperEdge: Color { Color(hex: "C5B79E") }
    private var ink: Color { Color(hex: "221A14") }
    private var inkFaded: Color { Color(hex: "6D5E50") }
    private var ribbon: Color { Color(hex: "A44E38") }
    private var keyFace: Color { Color(hex: "F0E8D8") }
    private var keyRim: Color { Color(hex: "6A5E52") }
    private var keyText: Color { Color(hex: "2C2218") }

    private var displaySong: String { entry.isEmpty ? "INSERT RECORD" : entry.songName }
    private var displayArtist: String { entry.isEmpty ? "等待歌曲开始播放…" : entry.artistName }

    // MARK: - Typewriter Stamp View
    @ViewBuilder
    private func stampCover(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "DCC8A0"), Color(hex: "B89060")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            if let data = entry.coverImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.84, height: size * 0.84)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
            } else {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(ink.opacity(0.4))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .rotationEffect(.degrees(3))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
    }

    // MARK: - Animated Typing Cursor
    private var typingCursor: some View {
        TimelineView(.animation(minimumInterval: 0.45)) { timeline in
            let isVisible = Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            Text("▌")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(ribbon)
                .opacity(!entry.isEmpty && entry.isPlaying && isVisible ? 1.0 : (!entry.isEmpty && entry.isPlaying ? 0.2 : 0))
        }
    }

    // MARK: - Keycap Constructor
    private func keyButton(icon: String, size: CGFloat, intent: any AppIntent) -> some View {
        Button(intent: intent) {
            ZStack {
                // Key Rim
                Circle()
                    .fill(
                        LinearGradient(colors: [keyRim, keyRim.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size, height: size)
                // Key Face
                Circle()
                    .fill(
                        LinearGradient(colors: [keyFace, keyFace.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size - 5, height: size - 5)
                // Symbol
                Image(systemName: icon)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(keyText)
            }
            .contentShape(Circle())
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
    }

    private func playKeyButton(size: CGFloat) -> some View {
        Button(intent: TogglePlaybackIntent()) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [ribbon, ribbon.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

                Image(systemName: entry.controlSymbolName)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(keyFace)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Circle())
            .shadow(color: Color.black.opacity(0.35), radius: 2.5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Body
    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge: largeLayout
        default: smallLayout
        }
    }

    // MARK: - Small Layout (Paper & Stamp)
    private var smallLayout: some View {
        GeometryReader { _ in
            ZStack {
                paper.ignoresSafeArea()

                // Paper watermark lines
                VStack(spacing: 20) {
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                    Divider().background(inkFaded.opacity(0.12))
                }
                .padding(.top, 20)

                // Margin Line
                HStack {
                    Rectangle()
                        .fill(ribbon.opacity(0.28))
                        .frame(width: 1.5)
                        .padding(.leading, 18)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(!entry.isEmpty && entry.isPlaying ? ribbon : inkFaded.opacity(0.4))
                                .frame(width: 5, height: 5)
                            Text(!entry.isEmpty && entry.isPlaying ? "TYPING" : "READY")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(inkFaded)
                                .tracking(1)
                        }
                        Spacer()
                        stampCover(size: 45)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 0) {
                            Text(displaySong)
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .foregroundColor(ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                            typingCursor
                        }

                        Text(displayArtist)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(inkFaded)
                            .lineLimit(1)
                    }
                }
                .padding(14)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium Layout (Deck + Paper)
    private var mediumLayout: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Base background for medium is the paper sticking out
                paper.ignoresSafeArea()

                // Paper lines
                VStack(spacing: 22) {
                    Divider().background(inkFaded.opacity(0.15))
                    Divider().background(inkFaded.opacity(0.15))
                    Divider().background(inkFaded.opacity(0.15))
                }
                .padding(.top, 26)

                // Margin line
                HStack {
                    Rectangle()
                        .fill(ribbon.opacity(0.28))
                        .frame(width: 1.5)
                        .padding(.leading, 22)
                    Spacer()
                }

                // Top Paper Content
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(!entry.isEmpty && entry.isPlaying ? ribbon : inkFaded.opacity(0.4))
                                    .frame(width: 6, height: 6)
                                Text(!entry.isEmpty && entry.isPlaying ? "TYPING" : "READY")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(inkFaded)
                                    .tracking(2)
                            }

                            HStack(spacing: 0) {
                                Text(displaySong.uppercased())
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                typingCursor
                            }

                            Text(displayArtist)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(inkFaded)
                                .lineLimit(1)
                        }
                        Spacer()
                        stampCover(size: 50)
                            .offset(y: -4)
                    }
                    Spacer()
                }
                .padding(.top, 14)
                .padding(.horizontal, 16)

                // Bottom Metal Deck Base
                let deckHeight = geo.size.height * 0.45
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: -2)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )

                    // Deck Content
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ROLLING")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(keyFace.opacity(0.5))
                                .tracking(1)

                            if !entry.qualityText.isEmpty {
                                Text(entry.qualityText)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }

                        Spacer()

                        // Mechanical Controls
                        if !entry.isEmpty {
                            HStack(spacing: 12) {
                                UITargetedButton(icon: "backward.fill", size: 36, intent: PreviousTrackIntent())
                                playUITargetedButton(size: 46)
                                UITargetedButton(icon: "forward.fill", size: 36, intent: NextTrackIntent())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: deckHeight)
                }
                .frame(height: deckHeight)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // Helper explicitly wrapping button creation
    private func UITargetedButton(icon: String, size: CGFloat, intent: any AppIntent) -> some View {
        return keyButton(icon: icon, size: size, intent: intent)
    }
    private func playUITargetedButton(size: CGFloat) -> some View {
        return playKeyButton(size: size)
    }

    // MARK: - Large Layout (Full Typewriter)
    private var largeLayout: some View {
        GeometryReader { geo in
            ZStack {
                metalDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Roller Bar
                    ZStack {
                        Capsule()
                            .fill(LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom))
                            .frame(width: geo.size.width * 0.85, height: 12)
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)

                        HStack {
                            Circle().fill(metal).frame(width: 18)
                            Spacer()
                            Circle().fill(metal).frame(width: 18)
                        }
                        .frame(width: geo.size.width * 0.9)
                        .overlay(Circle().stroke(Color.white.opacity(0.2)), alignment: .leading)
                        .overlay(Circle().stroke(Color.white.opacity(0.2)), alignment: .trailing)
                    }
                    .padding(.top, 10)
                    .zIndex(2)

                    // Paper Area
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(paper)
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(paperEdge, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)

                        // Margins and lines
                        VStack(spacing: 24) {
                            ForEach(0..<10, id: \.self) { _ in Divider().background(inkFaded.opacity(0.15)) }
                        }.padding(.top, 24)

                        HStack {
                            Rectangle().fill(ribbon.opacity(0.28)).frame(width: 1.5).padding(.leading, 24)
                            Spacer()
                        }

                        // Content
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Circle()
                                            .fill(!entry.isEmpty && entry.isPlaying ? ribbon : inkFaded.opacity(0.4))
                                            .frame(width: 6, height: 6)
                                        Text(!entry.isEmpty && entry.isPlaying ? "TYPING" : "READY")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(inkFaded)
                                            .tracking(2)
                                    }
                                    Text(displaySong)
                                        .font(.system(size: 24, weight: .bold, design: .serif))
                                        .foregroundColor(ink)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.5)
                                    Text(displayArtist)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(inkFaded)
                                }
                                Spacer()
                                stampCover(size: 58)
                            }

                            Rectangle().fill(ink.opacity(0.1)).frame(height: 1)

                            // Mock typing section for latest lyric
                            if !entry.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    let lyric = entry.lyricText.isEmpty ? "INSTRUMENTAL TRACK" : entry.lyricText
                                    HStack(alignment: .top, spacing: 0) {
                                        Text(lyric.uppercased())
                                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                            .foregroundColor(ink)
                                            .lineLimit(3)
                                        typingCursor
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 36)
                    }
                    .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.55)
                    .offset(y: -6)
                    .zIndex(1)

                    // Bottom Deck
                    VStack {
                        Spacer()
                        // Metal base
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom))
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)

                            HStack(spacing: 16) {
                                if !entry.isEmpty {
                                    UITargetedButton(icon: "backward.fill", size: 40, intent: PreviousTrackIntent())
                                    playUITargetedButton(size: 56)
                                    UITargetedButton(icon: "forward.fill", size: 40, intent: NextTrackIntent())
                                }
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height * 0.28)
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: -4)
                    }
                    .zIndex(3)
                }
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
}
