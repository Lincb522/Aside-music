import SwiftUI

/// THESIS: six navigation instruments, not six skins on one mini-player template.
/// Each style gives playback and the four primary destinations a different, legible spatial model.
enum SignatureFloatingBarKind: String, CaseIterable {
    case vinylNeedle
    case cassette
    case orbit
    case waveform
    case filmstrip
    case studioMeter

    init(style: FloatingBarStyle) {
        switch style {
        case .vinylNeedle: self = .vinylNeedle
        case .cassette: self = .cassette
        case .orbit: self = .orbit
        case .waveform: self = .waveform
        case .filmstrip: self = .filmstrip
        case .studioMeter: self = .studioMeter
        default: self = .vinylNeedle
        }
    }

    var activeHeight: CGFloat {
        switch self {
        case .vinylNeedle: return 126
        case .cassette: return 102
        case .orbit: return 112
        case .waveform: return 126
        case .filmstrip: return 148
        case .studioMeter: return 138
        }
    }
}

@MainActor
struct SignatureFloatingBar: View {
    @Environment(\.floatingBarColorRevision) private var colorRevision
    @Binding var currentTab: Tab
    let kind: SignatureFloatingBarKind

    private let player = FloatingBarPlaybackModel.shared
    @State private var currentSong = FloatingBarPlaybackModel.shared.currentSong
    @State private var isPlaying = FloatingBarPlaybackModel.shared.isPlaying
    @State private var isLoading = FloatingBarPlaybackModel.shared.isLoading
    private let playbackTime = PlaybackTimePublisher.shared
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var coverColors = CoverColorExtractor(minimumColorCount: 6)
    @State private var spectrum = SignatureSpectrumModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var showPlaylist = false
    @State private var isScrubbing = false
    @State private var scrubTarget = 0.0
    @State private var scrubDisplay = 0.0
    @State private var holdsSeek = false
    @State private var scrubGeneration = 0
    @State private var isVisible = false

    private var artworkURL: String? {
        currentSong?.coverUrl?.sized(360).absoluteString
    }

    private var palette: [Color] {
        let colors = coverColors.palette
        if colors.count >= 5 { return colors }
        return [
            coverColors.dominantColor,
            coverColors.secondaryColor,
            Color.monoAccent,
            coverColors.dominantColor.opacity(0.72),
            coverColors.secondaryColor.opacity(0.78),
        ]
    }

    private var liveProgress: Double {
        guard playbackTime.duration.isFinite,
              playbackTime.duration > 0,
              playbackTime.currentTime.isFinite else { return 0 }
        return min(max(playbackTime.currentTime / playbackTime.duration, 0), 1)
    }

    private var scrubProgressOverride: Double? {
        (isScrubbing || holdsSeek) ? scrubDisplay : nil
    }

    private var isAnimating: Bool {
        isVisible && isPlaying && !reduceMotion && scenePhase == .active && !isScrubbing
    }

    private var seed: Double {
        guard let song = currentSong else { return 0.41 }
        let folded = abs(song.id &* 31 &+ song.name.hashValue &* 7)
        return Double(folded % 997) / 997.0
    }

    var body: some View {
        let _ = colorRevision

        Group {
            if let song = currentSong {
                activeDock(song)
                    .frame(height: kind.activeHeight)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                emptyDock
                    .frame(height: 66)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: currentSong?.id)
        .onReceive(player.$currentSong) { currentSong = $0 }
        .onReceive(player.$isPlaying.removeDuplicates()) { isPlaying = $0 }
        .onReceive(player.$isLoading.removeDuplicates()) { isLoading = $0 }
        .onAppear {
            isVisible = true
            coverColors.extract(from: artworkURL)
            updateSpectrumSampling()
        }
        .onChange(of: artworkURL) { _, url in
            cancelScrub()
            coverColors.extract(from: url)
        }
        .onChange(of: isPlaying) { _, _ in updateSpectrumSampling() }
        .onChange(of: reduceMotion) { _, _ in updateSpectrumSampling() }
        .onChange(of: kind) { _, _ in updateSpectrumSampling() }
        .onChange(of: scenePhase) { _, _ in updateSpectrumSampling() }
        .onReceive(playbackTime.$currentTime.removeDuplicates()) { time in
            guard holdsSeek, playbackTime.duration > 0 else { return }
            if abs(time / playbackTime.duration - scrubDisplay) < 0.014 {
                holdsSeek = false
            }
        }
        .onDisappear {
            isVisible = false
            cancelScrub()
            spectrum.stop()
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    @ViewBuilder
    private func activeDock(_ song: Song) -> some View {
        switch kind {
        case .vinylNeedle: vinylDock(song)
        case .cassette: cassetteDock(song)
        case .orbit: orbitDock(song)
        case .waveform: waveformDock(song)
        case .filmstrip: filmDock(song)
        case .studioMeter: meterDock(song)
        }
    }

    @ViewBuilder
    private var emptyDock: some View {
        switch kind {
        case .vinylNeedle:
            HStack(spacing: 6) {
                VinylRecord(song: nil, progress: 0, isPlaying: false, reduceMotion: true)
                    .frame(width: 52, height: 52)
                vinylTabs(compact: true)
            }
            .padding(7)
            .background(surface(VinylConsoleShape(), fill: vinylSurface))
            .shadow(color: Color.black.opacity(0.16), radius: 8, y: 5)
        case .cassette:
            cassetteTabs
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(surface(RoundedRectangle(cornerRadius: 16, style: .continuous), fill: cassetteSurface))
                .shadow(color: Color.black.opacity(0.14), radius: 6, y: 4)
        case .orbit:
            orbitTabs
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(orbitBackdrop(cornerRadius: 18))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 7, y: 4)
        case .waveform:
            waveformCompactTabs
                .padding(8)
                .background(surface(RoundedRectangle(cornerRadius: 14, style: .continuous), fill: waveformSurface))
                .shadow(color: Color.black.opacity(0.14), radius: 7, y: 4)
        case .filmstrip:
            filmTabs
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(surface(RoundedRectangle(cornerRadius: 10, style: .continuous), fill: filmSurface))
                .overlay(FilmPerforations().allowsHitTesting(false))
        case .studioMeter:
            meterCompactTabs
                .padding(8)
                .background(surface(MeterRackShape(), fill: meterSurface))
                .shadow(color: Color.black.opacity(0.15), radius: 6, y: 4)
        }
    }

    // MARK: Vinyl console

    private func vinylDock(_ song: Song) -> some View {
        HStack(spacing: 0) {
            FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                VinylRecord(
                    song: song,
                    progress: progress,
                    isPlaying: isAnimating,
                    reduceMotion: reduceMotion
                )
            }
            .frame(width: 108, height: 108)
            .offset(x: -5)
            .contentShape(Circle())
            .onTapWithHaptic { openPlayer() }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    songIdentity(song, titleSize: 14, subtitleSize: 10.5)
                    transportButton(icon: isPlaying ? .pause : .play, diameter: 34) {
                        player.togglePlayPause()
                    }
                    queueButton(diameter: 30)
                }

                GeometryReader { proxy in
                    FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                        VinylGrooveProgress(progress: progress, accent: palette[0])
                    }
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(width: proxy.size.width))
                }
                .frame(height: 12)

                vinylTabs(compact: false)
            }
            .padding(.trailing, 12)
            .padding(.vertical, 11)
        }
        .background(surface(VinylConsoleShape(), fill: vinylSurface))
        .overlay {
            FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                VinylTonearm(progress: progress)
            }
            .padding(.leading, 84)
            .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.18), radius: 8, y: 6)
    }

    private func vinylTabs(compact: Bool) -> some View {
        HStack(spacing: compact ? 4 : 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    VStack(spacing: 3) {
                        MonoIcon(
                            icon: tab.icon,
                            size: compact ? 16 : 15,
                            color: selected ? Color.monoTextPrimary : Color.monoTextSecondary,
                            lineWidth: selected ? 1.9 : 1.5,
                            forceTemplateRendering: true,
                            artworkContrastBackground: selected ? vinylSurface : nil
                        )
                        Circle()
                            .fill(selected ? palette[0] : Color.clear)
                            .frame(width: 3.5, height: 3.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? 42 : 34)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.monoTextPrimary.opacity(colorScheme == .dark ? 0.08 : 0.055))
                        }
                    }
                }
                .buttonStyle(SignaturePressStyle())
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    // MARK: Cassette deck

    private func cassetteDock(_ song: Song) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                    CassetteWindow(
                        song: song,
                        progress: progress,
                        isPlaying: isAnimating,
                        reduceMotion: reduceMotion,
                        accent: palette[0]
                    )
                }
                .frame(width: 78, height: 46)
                .contentShape(Rectangle())
                .onTapWithHaptic { openPlayer() }

                VStack(alignment: .leading, spacing: 4) {
                    songIdentity(song, titleSize: 13, subtitleSize: 9.5, color: cassetteInk)
                    GeometryReader { proxy in
                        FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                            CassetteCounterProgress(progress: progress, accent: palette[0])
                        }
                        .contentShape(Rectangle())
                        .gesture(scrubGesture(width: proxy.size.width))
                    }
                    .frame(height: 9)
                }

                HStack(spacing: 3) {
                    transportButton(icon: isPlaying ? .pause : .play, diameter: 30, ink: cassetteInk) {
                        player.togglePlayPause()
                    }
                    queueButton(diameter: 25, ink: cassetteInk)
                }
            }
            .padding(.horizontal, 9)
            .padding(.top, 7)

            cassetteTabs
                .padding(.horizontal, 9)
                .padding(.bottom, 5)
        }
        .background(surface(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: cassetteSurface))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.16), radius: 7, y: 5)
    }

    private var cassetteTabs: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    VStack(spacing: 2) {
                        MonoIcon(
                            icon: tab.icon,
                            size: 13,
                            color: selected ? cassetteInk : cassetteInk.opacity(0.52),
                            lineWidth: selected ? 1.9 : 1.5,
                            forceTemplateRendering: true,
                            artworkContrastBackground: selected ? cassetteSurface : nil
                        )
                        Capsule()
                            .fill(selected ? palette[0].opacity(0.82) : Color.clear)
                            .frame(width: 13, height: 1.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 27)
                    .foregroundStyle(cassetteInk)
                    .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? palette[0].opacity(0.18) : Color.clear)
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(selected ? palette[0].opacity(0.72) : cassetteInk.opacity(0.12))
                            .frame(height: selected ? 1.5 : 0.5)
                    }
                }
                .buttonStyle(SignaturePressStyle(scale: 0.965, yOffset: 1.5))
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    // MARK: Orbital constellation

    private func orbitDock(_ song: Song) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                    OrbitArtwork(
                        song: song,
                        progress: progress,
                        palette: palette,
                        isPlaying: isAnimating,
                        reduceMotion: reduceMotion
                    )
                }
                .frame(width: 62, height: 62)
                .contentShape(Circle())
                .onTapWithHaptic { openPlayer() }
                .shadow(color: palette[0].opacity(0.28), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 5) {
                    songIdentity(song, titleSize: 13.5, subtitleSize: 10, color: orbitInk)
                    GeometryReader { proxy in
                        FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                            OrbitArcProgress(progress: progress, accent: palette[0])
                        }
                        .contentShape(Rectangle())
                        .gesture(scrubGesture(width: proxy.size.width))
                    }
                    .frame(height: 12)
                }
                .padding(.horizontal, 11)
                .frame(height: 58)
                .background(surface(RoundedRectangle(cornerRadius: 14, style: .continuous), fill: orbitSurface))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 6, y: 3)

                VStack(spacing: 2) {
                    transportButton(icon: isPlaying ? .pause : .play, diameter: 34, ink: orbitInk) {
                        player.togglePlayPause()
                    }
                    queueButton(diameter: 26, ink: orbitInk)
                }
            }
            .padding(.horizontal, 5)

            orbitTabs
                .padding(.horizontal, 14)
        }
        .background(orbitBackdrop(cornerRadius: 20))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 8, y: 5)
    }

    private var orbitTabs: some View {
        HStack(alignment: .center, spacing: 9) {
            ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    ZStack {
                        if selected {
                            Circle()
                                .fill(palette[index % palette.count].opacity(0.88))
                        } else {
                            surface(Circle(), fill: orbitSurface)
                        }
                        Circle()
                            .stroke(selected ? Color.white.opacity(0.38) : orbitInk.opacity(0.12), lineWidth: 0.7)
                        MonoIcon(
                            icon: tab.icon,
                            size: selected ? 15 : 14,
                            color: selected ? orbitSelectedInk : orbitInk.opacity(0.55),
                            lineWidth: selected ? 1.9 : 1.45,
                            forceTemplateRendering: true,
                            artworkContrastBackground: selected
                                ? palette[index % palette.count]
                                : nil
                        )
                    }
                    .frame(width: selected ? 37 : 33, height: selected ? 37 : 33)
                    .shadow(color: selected ? palette[index % palette.count].opacity(0.30) : Color.black.opacity(0.08), radius: 4, y: 2)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .offset(y: index.isMultiple(of: 2) ? 1.5 : -1.5)
                }
                .buttonStyle(SignaturePressStyle(scale: 0.93))
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    private func orbitBackdrop(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            surface(shape, fill: orbitSurface)

            LinearGradient(
                colors: [
                    palette[1].opacity(colorScheme == .dark ? 0.16 : 0.11),
                    Color.clear,
                    palette[0].opacity(colorScheme == .dark ? 0.13 : 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)
        }
        .overlay {
            shape.stroke(
                Color.white.opacity(colorScheme == .dark ? 0.11 : 0.34),
                lineWidth: 0.7
            )
        }
    }

    // MARK: Oscilloscope

    private func waveformDock(_ song: Song) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    songIdentity(song, titleSize: 14, subtitleSize: 10.5)
                    transportButton(icon: isPlaying ? .pause : .play, diameter: 34) { player.togglePlayPause() }
                    queueButton(diameter: 29)
                }

                GeometryReader { proxy in
                    SignatureSpectrumReader(model: spectrum) { bands, _ in
                        FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                            OscilloscopeDisplay(
                                bands: bands,
                                progress: progress,
                                palette: palette,
                                seed: seed,
                                isPlaying: isAnimating,
                                reduceMotion: reduceMotion
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(width: proxy.size.width))
                }
                .frame(height: 53)
            }
            .padding(.leading, 13)
            .padding(.trailing, 10)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)

            waveformTabs
                .frame(width: 116)
                .padding(.trailing, 10)
                .padding(.vertical, 10)
        }
        .background(surface(RoundedRectangle(cornerRadius: 14, style: .continuous), fill: waveformSurface))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.monoTextSecondary.opacity(0.13), lineWidth: 0.7)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 7, y: 5)
    }

    private var waveformCompactTabs: some View {
        HStack(spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    MonoIcon(
                        icon: tab.icon,
                        size: 16,
                        color: selected ? waveformSelectedInk : Color.monoTextSecondary,
                        lineWidth: selected ? 1.9 : 1.45,
                        forceTemplateRendering: true,
                        artworkContrastBackground: selected ? palette[0] : nil
                    )
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selected ? palette[0].opacity(0.78) : Color.monoTextPrimary.opacity(0.045))
                    }
                }
                .buttonStyle(SignaturePressStyle(scale: 0.95))
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    private var waveformTabs: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    VStack(spacing: 3) {
                        MonoIcon(
                            icon: tab.icon,
                            size: 14,
                            color: selected ? waveformSelectedInk : Color.monoTextSecondary,
                            lineWidth: selected ? 1.9 : 1.45,
                            forceTemplateRendering: true,
                            artworkContrastBackground: selected ? palette[0] : nil
                        )
                        if selected {
                            WaveformSelectionGlyph(color: waveformSelectedInk)
                                .frame(width: 20, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 43)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selected ? palette[0].opacity(0.78) : Color.monoTextPrimary.opacity(0.045))
                    }
                }
                .buttonStyle(SignaturePressStyle(scale: 0.95))
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    // MARK: Film transport

    private func filmDock(_ song: Song) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 11) {
                FilmArtwork(song: song)
                    .frame(width: 78, height: 58)
                    .contentShape(Rectangle())
                    .onTapWithHaptic { openPlayer() }

                VStack(alignment: .leading, spacing: 6) {
                    songIdentity(song, titleSize: 14, subtitleSize: 10.5, color: filmInk)
                    FloatingBarProgressReader { _, time, duration in
                        HStack(spacing: 6) {
                            Text(timecode(time))
                            Rectangle().fill(filmInk.opacity(0.16)).frame(height: 1)
                            Text("−\(timecode(max(duration - time, 0)))")
                        }
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(filmInk.opacity(0.64))
                    }

                    GeometryReader { proxy in
                        FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                            FilmTimeline(progress: progress, accent: palette[0])
                        }
                        .contentShape(Rectangle())
                        .gesture(scrubGesture(width: proxy.size.width))
                    }
                    .frame(height: 11)
                }

                VStack(spacing: 6) {
                    transportButton(icon: isPlaying ? .pause : .play, diameter: 34, ink: filmInk) { player.togglePlayPause() }
                    queueButton(diameter: 29, ink: filmInk)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            filmTabs
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(surface(RoundedRectangle(cornerRadius: 10, style: .continuous), fill: filmSurface))
        .overlay(FilmPerforations().foregroundStyle(filmInk.opacity(0.14)).allowsHitTesting(false))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.17), radius: 7, y: 5)
    }

    private var filmTabs: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    HStack(spacing: 4) {
                        MonoIcon(
                            icon: tab.icon,
                            size: 13,
                            color: selected ? filmSelectedInk : filmInk.opacity(0.52),
                            lineWidth: selected ? 1.9 : 1.45,
                            forceTemplateRendering: true,
                            artworkContrastBackground: selected ? filmInk : nil
                        )
                        if selected {
                            Text(String(localized: String.LocalizationValue(tab.titleKey())))
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(selected ? filmInk.opacity(0.88) : filmInk.opacity(0.055))
                    }
                }
                .buttonStyle(SignaturePressStyle(scale: 0.965))
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    // MARK: Studio meter rack

    private func meterDock(_ song: Song) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    songIdentity(song, titleSize: 13.5, subtitleSize: 9.5, color: meterInk, design: .monospaced)
                    FloatingBarProgressReader { _, time, _ in
                        Text(timecode(time))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(meterInk.opacity(0.64))
                    }
                }

                GeometryReader { proxy in
                    SignatureSpectrumReader(model: spectrum) { _, energy in
                        FloatingBarProgressReader(progressOverride: scrubProgressOverride) { progress, _, _ in
                            DualVUMeter(
                                energy: energy,
                                progress: progress,
                                accent: palette[0],
                                ink: meterInk,
                                isPlaying: isAnimating,
                                reduceMotion: reduceMotion
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(width: proxy.size.width))
                }
                .frame(height: 65)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    transportButton(icon: isPlaying ? .pause : .play, diameter: 34, ink: meterInk) { player.togglePlayPause() }
                    queueButton(diameter: 29, ink: meterInk)
                }
                meterTabs
            }
            .frame(width: 122)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(surface(MeterRackShape(), fill: meterSurface))
        .overlay(MeterHardware(ink: meterInk).allowsHitTesting(false))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.31 : 0.16), radius: 6, y: 5)
    }

    private var meterCompactTabs: some View {
        HStack(spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    MonoIcon(
                        icon: tab.icon,
                        size: 16,
                        color: selected ? meterSelectedInk : meterInk.opacity(0.55),
                        lineWidth: selected ? 1.9 : 1.45,
                        forceTemplateRendering: true,
                        artworkContrastBackground: selected ? palette[0] : nil
                    )
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background {
                        MeterKeyShape()
                            .fill(selected ? palette[0].opacity(0.78) : meterInk.opacity(0.07))
                    }
                }
                .buttonStyle(SignaturePressStyle(scale: 0.96, yOffset: 1))
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    private var meterTabs: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                Button { selectTab(tab) } label: {
                    MonoIcon(
                        icon: tab.icon,
                        size: 14,
                        color: selected ? meterSelectedInk : meterInk.opacity(0.55),
                        lineWidth: selected ? 1.9 : 1.45,
                        forceTemplateRendering: true,
                        artworkContrastBackground: selected ? palette[0] : nil
                    )
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background {
                        MeterKeyShape()
                            .fill(selected ? palette[0].opacity(0.78) : meterInk.opacity(0.07))
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(selected ? Color.white.opacity(0.34) : meterInk.opacity(0.08))
                            .frame(height: 1)
                    }
                }
                .buttonStyle(SignaturePressStyle(scale: 0.96, yOffset: 1))
                .accessibilityLabel(tabLabel(tab))
            }
        }
    }

    // MARK: Shared behavior, not shared composition

    private func songIdentity(
        _ song: Song,
        titleSize: CGFloat,
        subtitleSize: CGFloat,
        color: Color = .monoTextPrimary,
        design: Font.Design = .rounded
    ) -> some View {
        VStack(alignment: .leading, spacing: 2.5) {
            MarqueeText(
                text: song.name,
                font: .system(size: titleSize, weight: .semibold, design: design),
                color: color,
                speed: 24
            )
            FloatingBarLyricReader { lineText in
                MarqueeText(
                    text: lineText ?? song.artistName,
                    font: .system(size: subtitleSize, weight: .medium, design: design),
                    color: color.opacity(0.58),
                    speed: 22
                )
                .contentTransition(.interpolate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .swipeSkipTextMotion()
        .contentShape(Rectangle())
        .onTapWithHaptic { openPlayer() }
        .swipeToSkip()
    }

    private func transportButton(
        icon: MonoIcon.IconType,
        diameter: CGFloat,
        ink: Color = .monoTextPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            Group {
                if (icon == .play || icon == .pause), isLoading {
                    ProgressView().tint(ink).scaleEffect(0.68)
                } else {
                    MonoIcon(
                        icon: icon,
                        size: icon == .play || icon == .pause ? 14 : 12,
                        color: ink,
                        lineWidth: 1.8,
                        forceTemplateRendering: true
                    )
                }
            }
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(ink.opacity(0.075)))
            .contentShape(Circle())
        }
        .buttonStyle(SignaturePressStyle(scale: 0.90))
    }

    private func queueButton(diameter: CGFloat, ink: Color = .monoTextPrimary) -> some View {
        Button {
            HapticManager.shared.light()
            showPlaylist = true
        } label: {
            MonoIcon(icon: .list, size: 14, color: ink.opacity(0.68), lineWidth: 1.7, forceTemplateRendering: true)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(SignaturePressStyle(scale: 0.90))
        .accessibilityLabel(String(localized: "player_queue"))
    }

    @ViewBuilder
    private func surface<S: Shape>(_ shape: S, fill: Color) -> some View {
        if settings.defaultThemeUsesLiquidGlassTabBar {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(fill.opacity(colorScheme == .dark ? 0.58 : 0.46)))
                .themeRenderSurfaceLayer()
        } else {
            shape.fill(fill)
        }
    }

    private func selectTab(_ tab: Tab) {
        guard currentTab != tab else { return }
        HapticManager.shared.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84)) {
            currentTab = tab
        }
    }

    private func tabLabel(_ tab: Tab) -> String {
        String(localized: String.LocalizationValue(tab.titleKey()))
    }

    private func openPlayer() {
        withAnimation(MonoAnimation.playerTransition) {
            switch player.playSource {
            case .fm:
                NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
            case let .podcast(radioID):
                NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioID)
            case .normal:
                NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
            }
        }
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .local)
            .onChanged { value in
                guard playbackTime.duration.isFinite,
                      playbackTime.duration > 0,
                      width > 1 else { return }
                if !isScrubbing {
                    scrubGeneration += 1
                    holdsSeek = false
                    isScrubbing = true
                    scrubDisplay = liveProgress
                    scrubTarget = liveProgress
                    HapticManager.shared.selection()
                }
                let target = min(max(Double(value.location.x / width), 0), 1)
                scrubTarget = target
                scrubDisplay = target
            }
            .onEnded { _ in commitScrub() }
    }

    private func commitScrub() {
        guard isScrubbing, playbackTime.duration > 0 else {
            isScrubbing = false
            return
        }
        let generation = scrubGeneration
        let committed = min(max(scrubTarget, 0), 1)
        isScrubbing = false
        holdsSeek = true
        scrubDisplay = committed
        player.seek(to: committed * playbackTime.duration)
        HapticManager.shared.soft()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard scrubGeneration == generation else { return }
            holdsSeek = false
        }
    }

    private func cancelScrub() {
        scrubGeneration += 1
        isScrubbing = false
        holdsSeek = false
    }

    private func updateSpectrumSampling() {
        let needsSpectrum = (kind == .waveform || kind == .studioMeter)
            && isVisible
            && scenePhase == .active
            && isPlaying
            && !reduceMotion
        needsSpectrum ? spectrum.start() : spectrum.stop()
    }

    private func timecode(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var vinylSurface: Color {
        colorScheme == .dark ? Color(red: 0.075, green: 0.076, blue: 0.082) : Color(red: 0.945, green: 0.94, blue: 0.925)
    }

    private var cassetteSurface: Color {
        colorScheme == .dark ? Color(red: 0.105, green: 0.095, blue: 0.075) : Color(red: 0.91, green: 0.86, blue: 0.72)
    }

    private var orbitSurface: Color {
        colorScheme == .dark ? Color(red: 0.03, green: 0.035, blue: 0.075) : Color(red: 0.915, green: 0.935, blue: 0.985)
    }

    private var waveformSurface: Color {
        colorScheme == .dark ? Color(red: 0.045, green: 0.055, blue: 0.052) : Color(red: 0.93, green: 0.95, blue: 0.94)
    }

    private var filmSurface: Color {
        colorScheme == .dark ? Color(red: 0.075, green: 0.067, blue: 0.055) : Color(red: 0.935, green: 0.89, blue: 0.75)
    }

    private var meterSurface: Color {
        colorScheme == .dark ? Color(red: 0.105, green: 0.11, blue: 0.115) : Color(red: 0.76, green: 0.78, blue: 0.79)
    }

    private var cassetteInk: Color { colorScheme == .dark ? .white : .black }
    private var orbitInk: Color { colorScheme == .dark ? .white : .black }
    private var orbitSelectedInk: Color { coverColors.contentColor }
    private var waveformSelectedInk: Color { coverColors.contentColor }
    private var filmInk: Color { colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.88) }
    private var filmSelectedInk: Color { colorScheme == .dark ? .black : .white }
    private var meterInk: Color { colorScheme == .dark ? Color.white.opacity(0.90) : Color.black.opacity(0.82) }
    private var meterSelectedInk: Color { coverColors.contentColor }
}

// MARK: - Artwork and instrument displays

private struct VinylRecord: View {
    @Environment(\.floatingBarColorRevision) private var colorRevision
    let song: Song?
    let progress: Double
    let isPlaying: Bool
    let reduceMotion: Bool

    var body: some View {
        let _ = colorRevision

        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: !isPlaying || reduceMotion)) { timeline in
            let rotation = isPlaying && !reduceMotion
                ? timeline.date.timeIntervalSinceReferenceDate * 24
                : progress * 360
            ZStack {
                Circle().fill(Color.black.opacity(0.95))
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .stroke(Color.white.opacity(0.05 + Double(index) * 0.008), lineWidth: 0.5)
                        .padding(CGFloat(index) * 5 + 3)
                }
                if let song {
                    CachedAsyncImage(url: song.coverUrl?.sized(220)) {
                        Circle().fill(Color.white.opacity(0.10))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Circle().fill(Color.monoAccent.opacity(0.46)).frame(width: 34, height: 34)
                }
                Circle().fill(Color.white.opacity(0.88)).frame(width: 5, height: 5)
            }
            .rotationEffect(.degrees(rotation))
        }
        .padding(4)
    }
}

private struct VinylTonearm: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let start = CGPoint(x: proxy.size.width - 30, y: 13)
            let end = CGPoint(x: 40 + CGFloat(progress) * 20, y: proxy.size.height * 0.58)
            Canvas { context, _ in
                context.fill(Path(ellipseIn: CGRect(x: start.x - 7, y: start.y - 7, width: 14, height: 14)), with: .color(Color.monoTextSecondary.opacity(0.20)))
                var arm = Path()
                arm.move(to: start)
                arm.addLine(to: CGPoint(x: start.x - 22, y: 30))
                arm.addLine(to: end)
                context.stroke(arm, with: .linearGradient(Gradient(colors: [.white.opacity(0.70), .gray.opacity(0.65)]), startPoint: start, endPoint: end), lineWidth: 2.2)
                context.fill(RoundedRectangle(cornerRadius: 1).path(in: CGRect(x: end.x - 4, y: end.y - 2, width: 8, height: 5)), with: .color(Color.monoTextPrimary.opacity(0.78)))
            }
        }
    }
}

private struct VinylGrooveProgress: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.monoTextSecondary.opacity(0.12)).frame(height: 2)
                Capsule().fill(accent.opacity(0.72)).frame(width: width * CGFloat(progress), height: 2)
                Circle()
                    .fill(Color.monoTextPrimary.opacity(0.88))
                    .frame(width: 6, height: 6)
                    .offset(x: max(0, width * CGFloat(progress) - 3))
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct CassetteWindow: View {
    let song: Song
    let progress: Double
    let isPlaying: Bool
    let reduceMotion: Bool
    let accent: Color

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 24, paused: !isPlaying || reduceMotion)) { timeline in
            let angle = isPlaying && !reduceMotion
                ? timeline.date.timeIntervalSinceReferenceDate * 120
                : progress * 720
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.74))
                CachedAsyncImage(url: song.coverUrl?.sized(240)) {
                    Color.clear
                }
                .aspectRatio(contentMode: .fill)
                .opacity(0.22)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                HStack(spacing: 27) {
                    CassetteReel(angle: angle, radius: 11 + CGFloat(1 - progress) * 4)
                    CassetteReel(angle: angle, radius: 11 + CGFloat(progress) * 4)
                }
                .overlay {
                    Capsule().fill(accent.opacity(0.35)).frame(width: 58, height: 1.3)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.22), lineWidth: 0.8))
        }
    }
}

private struct CassetteReel: View {
    let angle: Double
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.72)).frame(width: radius * 2, height: radius * 2)
            Circle().stroke(Color.white.opacity(0.55), lineWidth: 1).frame(width: 19, height: 19)
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 2, height: 7)
                    .offset(y: -5)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
            Circle().fill(Color.black.opacity(0.70)).frame(width: 5, height: 5)
        }
        .rotationEffect(.degrees(angle))
    }
}

private struct CassetteCounterProgress: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let count = max(Int(proxy.size.width / 7), 8)
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    let active = Double(index) / Double(max(count - 1, 1)) <= progress
                    Rectangle()
                        .fill(active ? accent.opacity(0.68) : Color.monoTextSecondary.opacity(0.12))
                        .frame(maxWidth: .infinity, minHeight: index.isMultiple(of: 5) ? 6 : 3, maxHeight: index.isMultiple(of: 5) ? 6 : 3)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct OrbitArtwork: View {
    let song: Song
    let progress: Double
    let palette: [Color]
    let isPlaying: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 24, paused: !isPlaying || reduceMotion)) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate * 14
            ZStack {
                Circle()
                    .fill(palette[0].opacity(0.13))
                CachedAsyncImage(url: song.coverUrl?.sized(220)) {
                    Circle().fill(Color.monoSeparator.opacity(0.22))
                }
                .aspectRatio(contentMode: .fill)
                .clipShape(Circle())
                .padding(6)
                Circle()
                    .stroke(palette[1].opacity(0.22), lineWidth: 1)
                    .padding(1)
                Circle()
                    .trim(from: 0, to: max(progress, 0.018))
                    .stroke(
                        AngularGradient(colors: [palette[0], palette[1], palette[0]], center: .center),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(1)
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 5, height: 5)
                    .offset(y: -30)
                    .rotationEffect(.degrees(angle))
                    .shadow(color: palette[0].opacity(0.55), radius: 3)
            }
        }
    }
}

private struct OrbitArcProgress: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.monoTextSecondary.opacity(0.09)).frame(height: 1)
                Capsule().fill(accent.opacity(0.62)).frame(width: width * CGFloat(progress), height: 1.5)
                Circle().fill(Color.white.opacity(0.90)).frame(width: 5, height: 5).offset(x: max(0, width * CGFloat(progress) - 2.5))
                    .shadow(color: accent.opacity(0.65), radius: 3)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct OscilloscopeDisplay: View {
    let bands: [Double]
    let progress: Double
    let palette: [Color]
    let seed: Double
    let isPlaying: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: !isPlaying || reduceMotion)) { timeline in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                context.fill(RoundedRectangle(cornerRadius: 7).path(in: CGRect(origin: .zero, size: size)), with: .color(Color.black.opacity(0.72)))
                for line in 1..<4 {
                    let y = size.height * CGFloat(line) / 4
                    var grid = Path()
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(grid, with: .color(Color.white.opacity(0.045)), lineWidth: 0.5)
                }
                let count = max(Int(size.width / 4), 30)
                let time = timeline.date.timeIntervalSinceReferenceDate
                var trace = Path()
                for index in 0..<count {
                    let ratio = Double(index) / Double(max(count - 1, 1))
                    let synthetic = sin(ratio * 28 + time * 3.5 + seed * 5) * cos(ratio * 9 - time * 1.7)
                    let live = bands.isEmpty ? abs(synthetic) : bands[index % bands.count]
                    let amplitude = CGFloat((live * 0.78 + abs(synthetic) * 0.22) * 0.82)
                    let x = CGFloat(ratio) * size.width
                    let direction = synthetic >= 0 ? 1.0 : -1.0
                    let y = size.height / 2 + CGFloat(direction) * amplitude * size.height * 0.40
                    if index == 0 { trace.move(to: CGPoint(x: x, y: y)) }
                    else { trace.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(trace, with: .linearGradient(Gradient(colors: palette.prefix(4).map { $0.opacity(0.92) }), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                let scanX = size.width * CGFloat(progress)
                var scan = Path()
                scan.move(to: CGPoint(x: scanX, y: 4))
                scan.addLine(to: CGPoint(x: scanX, y: size.height - 4))
                context.stroke(scan, with: .color(Color.white.opacity(0.68)), lineWidth: 0.8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct WaveformSelectionGlyph: View {
    let color: Color
    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach([2.0, 5.0, 3.0, 5.0, 2.0], id: \.self) { height in
                Capsule().fill(color.opacity(0.86)).frame(width: 1.5, height: height)
            }
        }
    }
}

private struct FilmArtwork: View {
    let song: Song
    var body: some View {
        CachedAsyncImage(url: song.coverUrl?.sized(320)) {
            Color.black.opacity(0.18)
        }
        .aspectRatio(contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.22), lineWidth: 0.7))
    }
}

private struct FilmTimeline: View {
    let progress: Double
    let accent: Color
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.monoTextSecondary.opacity(0.14)).frame(height: 2)
                Rectangle().fill(accent.opacity(0.78)).frame(width: width * CGFloat(progress), height: 2)
                Rectangle().fill(Color.white.opacity(0.92)).frame(width: 2, height: 8).offset(x: max(0, width * CGFloat(progress) - 1))
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct DualVUMeter: View {
    let energy: Double
    let progress: Double
    let accent: Color
    let ink: Color
    let isPlaying: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 24, paused: !isPlaying || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 7) {
                meter(channel: 0, time: time)
                meter(channel: 1, time: time)
            }
        }
    }

    private func meter(channel: Int, time: Double) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let live = energy > 0.002 ? energy : (isPlaying ? 0.34 + sin(time * (4.2 + Double(channel) * 0.35)) * 0.16 : 0.16)
            let deflection = min(max(live * 0.72 + progress * 0.16 + Double(channel) * 0.03, 0.05), 0.94)
            Canvas { context, _ in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(RoundedRectangle(cornerRadius: 5).path(in: rect), with: .color(Color.black.opacity(0.12)))
                for index in 0..<11 {
                    let ratio = CGFloat(index) / 10
                    let x = 7 + ratio * (size.width - 14)
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: 6))
                    tick.addLine(to: CGPoint(x: x, y: index.isMultiple(of: 2) ? 13 : 10))
                    context.stroke(tick, with: .color(index >= 8 ? Color.red.opacity(0.50) : ink.opacity(0.30)), lineWidth: 0.7)
                }
                let targetX = 7 + CGFloat(deflection) * (size.width - 14)
                var needle = Path()
                needle.move(to: CGPoint(x: size.width / 2, y: size.height - 5))
                needle.addLine(to: CGPoint(x: targetX, y: 9))
                context.stroke(needle, with: .color(accent.opacity(0.88)), lineWidth: 1.2)
                context.fill(Path(ellipseIn: CGRect(x: size.width / 2 - 2.5, y: size.height - 7.5, width: 5, height: 5)), with: .color(ink.opacity(0.82)))
            }
        }
    }
}

// MARK: - Geometry and hardware

private struct VinylConsoleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.height * 0.46
        var path = Path()
        path.move(to: CGPoint(x: radius, y: 1))
        path.addLine(to: CGPoint(x: rect.maxX - 13, y: 1))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 1, y: 13), control: CGPoint(x: rect.maxX - 1, y: 1))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - 13))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 13, y: rect.maxY - 1), control: CGPoint(x: rect.maxX - 1, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: radius, y: rect.maxY - 1))
        path.addCurve(to: CGPoint(x: radius, y: 1), control1: CGPoint(x: -9, y: rect.maxY - 1), control2: CGPoint(x: -9, y: 1))
        path.closeSubpath()
        return path
    }
}


private struct FilmPerforations: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for y in [CGFloat(5), size.height - 9] {
                    var x: CGFloat = 12
                    while x < size.width - 10 {
                        let rect = CGRect(x: x, y: y, width: 8, height: 3.5)
                        context.fill(RoundedRectangle(cornerRadius: 0.7).path(in: rect), with: .color(Color.primary.opacity(0.13)))
                        x += 17
                    }
                }
            }
        }
    }
}

private struct MeterRackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = 7
        var path = Path()
        path.move(to: CGPoint(x: cut, y: 1))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: 1))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: cut))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: cut, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: 1, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: 1, y: cut))
        path.closeSubpath()
        return path
    }
}

private struct MeterKeyShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3)
    }
}

private struct MeterHardware: View {
    let ink: Color
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for index in 1..<9 {
                    let y = CGFloat(index) * size.height / 9
                    var line = Path(); line.move(to: CGPoint(x: 10, y: y)); line.addLine(to: CGPoint(x: size.width-10, y: y))
                    context.stroke(line, with: .color(index.isMultiple(of: 2) ? Color.white.opacity(0.025) : Color.black.opacity(0.025)), lineWidth: 0.5)
                }
                for point in [CGPoint(x: 8, y: 8), CGPoint(x: size.width-8, y: 8), CGPoint(x: 8, y: size.height-8), CGPoint(x: size.width-8, y: size.height-8)] {
                    context.fill(Path(ellipseIn: CGRect(x: point.x-1.8, y: point.y-1.8, width: 3.6, height: 3.6)), with: .color(ink.opacity(0.25)))
                }
            }
        }
    }
}

private struct SignaturePressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var yOffset: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .offset(y: configuration.isPressed ? yOffset : 0)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.spring(response: 0.20, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private struct SignatureSpectrumReader<Content: View>: View {
    @ObservedObject var model: SignatureSpectrumModel
    @ViewBuilder var content: ([Double], Double) -> Content

    var body: some View {
        content(model.bands, model.energy)
    }
}

// MARK: - Low-cadence analyzer

@MainActor
private final class SignatureSpectrumModel: ObservableObject {
    @Published private(set) var bands: [Double] = []
    @Published private(set) var energy = 0.0
    private var observerToken: UUID?

    func start() {
        guard observerToken == nil else { return }
        observerToken = PlayerManager.shared.spectrumAnalyzer.addAnalysisObserver(minimumInterval: 1.0 / 20.0) { [weak self] magnitudes, _, rms in
            let condensed = Self.condense(magnitudes, count: 28)
            let normalizedEnergy = min(max(Double(rms) * 5.2, 0), 1)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.bands.count == condensed.count {
                    self.bands = zip(self.bands, condensed).map { previous, next in
                        previous + (next - previous) * (next > previous ? 0.58 : 0.22)
                    }
                } else {
                    self.bands = condensed
                }
                self.energy += (normalizedEnergy - self.energy) * (normalizedEnergy > self.energy ? 0.54 : 0.18)
            }
        }
    }

    func stop() {
        guard let observerToken else { return }
        PlayerManager.shared.spectrumAnalyzer.removeAnalysisObserver(observerToken)
        self.observerToken = nil
        bands = []
        energy = 0
    }

    nonisolated private static func condense(_ values: [Float], count: Int) -> [Double] {
        guard !values.isEmpty, count > 0 else { return [] }
        var result = Array(repeating: 0.0, count: count)
        for band in 0..<count {
            let lowerRatio = pow(Double(band) / Double(count), 1.65)
            let upperRatio = pow(Double(band + 1) / Double(count), 1.65)
            let lower = min(max(Int(lowerRatio * Double(values.count)), 0), values.count - 1)
            let upper = min(max(Int(upperRatio * Double(values.count)), lower + 1), values.count)
            var peak = 0.0
            var sum = 0.0
            for index in lower..<upper {
                let value = min(max(Double(values[index]), 0), 1)
                peak = max(peak, value)
                sum += value
            }
            let average = sum / Double(max(upper - lower, 1))
            result[band] = min(1, sqrt(peak * 0.68 + average * 0.32) * 1.12)
        }
        return result
    }
}
