import class RiveRuntime.RiveViewModel
import SwiftUI

/// THESIS: the player is a touch-reactive vector instrument, not album art stacked over a control card.
/// The Rive state machine is the visible playback surface: the outer rings react to touch while the
/// center control morphs between play and pause. Native SwiftUI retains media data, seeking, sheets,
/// accessibility and device adaptation.
@MainActor
struct RiveMotionPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var playbackTime = PlaybackTimePublisher.shared
    @ObservedObject private var floatingPlayback = FloatingBarPlaybackModel.shared
    @StateObject private var colors = CoverColorExtractor(minimumColorCount: 5)
    @StateObject private var rive = RiveMotionAnimationModel()

    @State private var showsLyrics = false
    @State private var showsQueue = false
    @State private var showsQuality = false
    @State private var showsMore = false
    @State private var showsEQ = false
    @State private var showsTheme = false
    @State private var isSeeking = false
    @State private var seekTime = 0.0

    private var artworkURL: String? {
        player.currentSong?.coverUrl?.sized(480).absoluteString
    }

    private var palette: [Color] {
        let extracted = colors.palette
        guard extracted.count >= 3 else {
            return [Color(hex: "7CEBFF"), Color(hex: "A88BFF"), Color(hex: "FF80BC")]
        }
        return [extracted[0], extracted[extracted.count / 2], extracted[extracted.count - 1]]
    }

    private var accent: Color { palette[0] }
    private var secondaryAccent: Color { palette[1] }
    private var tertiaryAccent: Color { palette[2] }

    var body: some View {
        GeometryReader { proxy in
            let metrics = RiveMotionMetrics(
                size: proxy.size,
                safeArea: proxy.safeAreaInsets,
                headerTopPadding: DeviceLayout.headerTopPadding,
                isPad: DeviceLayout.isPad
            )

            ZStack {
                backdrop

                VStack(spacing: 0) {
                    toolbar
                        .padding(.top, metrics.headerTopInset)

                    if metrics.usesWideLayout {
                        wideContent(metrics: metrics)
                    } else {
                        portraitContent(metrics: metrics)
                    }
                }
                .frame(maxWidth: metrics.maximumWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, metrics.horizontalInset)
                .padding(.bottom, metrics.bottomInset)

                if showsMore {
                    PlayerMoreMenu(
                        isPresented: $showsMore,
                        isDarkBackground: true,
                        onQuality: { showsQuality = true },
                        onEQ: { showsEQ = true },
                        onTheme: { showsTheme = true }
                    )
                }
            }
        }
        .compatFontDesign(nil)
        .onAppear {
            refreshPalette()
            synchronizeRive()
        }
        .onChange(of: artworkURL) { _, _ in refreshPalette() }
        .onChange(of: player.isPlaying) { _, _ in synchronizeRive() }
        .onChange(of: reduceMotion) { _, _ in synchronizeRive() }
        .onChange(of: scenePhase) { _, _ in synchronizeRive() }
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            player.playSource.isPodcast ? AnyView(PodcastPlaylistPopupView()) : AnyView(PlaylistPopupView())
        }
        .monoSheet(isPresented: $showsQuality, preset: .standard) {
            qualitySheet
        }
        .fullScreenCover(isPresented: $showsEQ) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showsTheme, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
    }
}

// MARK: - Composition

private extension RiveMotionPlayerLayout {
    func portraitContent(metrics: RiveMotionMetrics) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: metrics.stageTopSpacing)

            motionStage(size: metrics.stageSize)

            Spacer(minLength: metrics.consoleTopSpacing)

            playerConsole(compact: metrics.isCompact)
                .frame(maxWidth: 540)
        }
    }

    func wideContent(metrics: RiveMotionMetrics) -> some View {
        HStack(spacing: metrics.wideGap) {
            motionStage(size: metrics.stageSize)

            playerConsole(compact: false)
                .frame(maxWidth: metrics.consoleWidth)
        }
        .frame(maxHeight: .infinity)
    }

    var toolbar: some View {
        HStack(spacing: 10) {
            riveIconButton(icon: .back, label: String(localized: "返回")) {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "矢量律动"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.88))

                Text(player.currentSong?.al?.name.nilIfEmpty ?? String(localized: "player_now_playing"))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                showsQuality = true
            } label: {
                Text(player.qualityButtonText)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.075), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.11), lineWidth: 0.7))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            .playerQualitySelectionAvailability()

            riveIconButton(icon: .more, label: String(localized: "更多")) {
                showsMore = true
            }
        }
    }

    func motionStage(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.22), secondaryAccent.opacity(0.07), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.56
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 12)
                .allowsHitTesting(false)

            if let rings = rive.rings {
                rings.view()
                    .frame(width: size, height: size)
                    .opacity(showsLyrics ? 0.30 : 0.78)
                    .blendMode(.screen)
                    .contentShape(Circle())
                    .accessibilityLabel(String(localized: "矢量律动"))
            } else {
                fallbackRings(size: size)
            }

            if showsLyrics, let song = player.currentSong {
                LyricsView(
                    song: song,
                    onBackgroundTap: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
                            showsLyrics = false
                        }
                    },
                    adaptivePrimaryColor: .white,
                    adaptiveSecondaryColor: .white.opacity(0.58),
                    enforcesAdaptiveContrast: true
                )
                .frame(width: size * 0.68, height: size * 0.68)
                .clipShape(Circle())
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                artworkCore(size: size * 0.46)
                    .onTapWithHaptic {
                        guard player.currentSong != nil else { return }
                        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
                            showsLyrics = true
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: size, height: size)
    }

    func artworkCore(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.24))
                .frame(width: size + 18, height: size + 18)
                .blur(radius: 8)

            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl?.sized(720)) {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .overlay(MonoIcon(icon: .musicNoteList, size: 36, color: .white.opacity(0.5)))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: palette + [accent],
                                center: .center
                            ),
                            lineWidth: 2.2
                        )
                }
                .shadow(color: accent.opacity(0.32), radius: 24, y: 10)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: size, height: size)
                    .overlay(MonoIcon(icon: .musicNoteList, size: 36, color: .white.opacity(0.5)))
            }
        }
    }

    func fallbackRings(size: CGFloat) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(
                        AngularGradient(colors: palette + [accent], center: .center),
                        style: StrokeStyle(lineWidth: 1.5 + CGFloat(index) * 0.3, lineCap: .round)
                    )
                    .frame(
                        width: size * (0.50 + CGFloat(index) * 0.12),
                        height: size * (0.50 + CGFloat(index) * 0.12)
                    )
                    .opacity(0.8 - Double(index) * 0.12)
            }
        }
        .allowsHitTesting(false)
    }

    func playerConsole(compact: Bool) -> some View {
        VStack(spacing: compact ? 11 : 15) {
            songIdentity(compact: compact)
            progressSection
            transportControls(compact: compact)
            actionRail
        }
    }

    func songIdentity(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.name ?? String(localized: "暂无歌曲"))
                    .monoPlayerDisplayFont(
                        size: compact ? 22 : 25,
                        weight: .semibold,
                        fallback: .system(size: compact ? 22 : 25, weight: .semibold, design: .rounded)
                    )
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(floatingPlayback.lyricLineText ?? player.currentSong?.artistName ?? String(localized: "search_unknown_artist"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .lineLimit(1)
                    .contentTransition(.interpolate)
            }

            Spacer(minLength: 4)

            if let song = player.currentSong {
                LikeButton(
                    songId: song.id,
                    isQQMusic: song.isQQMusic,
                    song: song,
                    size: 21,
                    activeColor: Color(hex: "FF7FAB"),
                    inactiveColor: .white.opacity(0.86)
                )
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.075), in: Circle())
            }
        }
    }

    var progressSection: some View {
        VStack(spacing: 5) {
            progressRail

            HStack {
                Text(riveFormatTime(isSeeking ? seekTime : validCurrentTime))
                Spacer()
                Text(riveFormatTime(validDuration))
            }
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.43))
            .monospacedDigit()
        }
    }

    var progressRail: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let duration = validDuration
            let current = isSeeking ? seekTime : validCurrentTime
            let fraction = duration > 0 ? min(max(current / duration, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, secondaryAccent, tertiaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width * fraction, fraction > 0 ? 4 : 0), height: 3)
                    .shadow(color: secondaryAccent.opacity(0.32), radius: 5)

                if duration > 0 {
                    Circle()
                        .fill(Color.white)
                        .frame(width: isSeeking ? 13 : 8, height: isSeeking ? 13 : 8)
                        .shadow(color: accent.opacity(0.52), radius: 6)
                        .offset(x: min(max(width * fraction - (isSeeking ? 6.5 : 4), 0), width - (isSeeking ? 13 : 8)))
                }
            }
            .frame(height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(seekGesture(width: width, duration: duration))
        }
        .frame(height: 24)
        .animation(reduceMotion || isSeeking ? nil : .linear(duration: 0.14), value: validCurrentTime)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "播放进度"))
    }

    func transportControls(compact: Bool) -> some View {
        HStack(spacing: compact ? 28 : 36) {
            riveTransportButton(icon: .previous, size: 22, label: String(localized: "上一首")) {
                player.previous()
            }

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.94))
                    Circle()
                        .stroke(
                            AngularGradient(colors: palette + [accent], center: .center),
                            lineWidth: 1.4
                        )

                    if player.isLoading {
                        ProgressView().tint(Color(hex: "171526"))
                    } else if let playPause = rive.playPause {
                        playPause.view()
                            .frame(width: compact ? 52 : 58, height: compact ? 52 : 58)
                            .allowsHitTesting(false)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 24,
                            color: Color(hex: "171526"),
                            lineWidth: 2
                        )
                    }
                }
                .frame(width: compact ? 66 : 74, height: compact ? 66 : 74)
                .shadow(color: accent.opacity(0.24), radius: 16, y: 8)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
            .accessibilityLabel(player.isPlaying ? String(localized: "暂停") : String(localized: "action_play"))

            riveTransportButton(icon: .next, size: 22, label: String(localized: "playback_next_track")) {
                player.next()
            }
        }
    }

    var actionRail: some View {
        HStack {
            riveActionButton(icon: player.mode.monoIcon, label: player.mode.displayName) {
                player.switchMode()
            }

            Spacer()

            riveActionButton(icon: .musicNoteList, label: String(localized: "歌词"), active: showsLyrics) {
                guard player.currentSong != nil else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)) {
                    showsLyrics.toggle()
                }
            }

            Spacer()

            riveActionButton(icon: .list, label: String(localized: "player_queue")) {
                showsQueue = true
            }
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - Controls

private extension RiveMotionPlayerLayout {
    func riveIconButton(icon: MonoIcon.IconType, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 16, color: .white.opacity(0.88), lineWidth: 1.7)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.075), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.6))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        .accessibilityLabel(label)
    }

    func riveTransportButton(
        icon: MonoIcon.IconType,
        size: CGFloat,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: size, color: .white.opacity(0.88), lineWidth: 1.9)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.86))
        .accessibilityLabel(label)
    }

    func riveActionButton(
        icon: MonoIcon.IconType,
        label: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                MonoIcon(
                    icon: icon,
                    size: 15,
                    color: active ? accent : .white.opacity(0.66),
                    lineWidth: active ? 1.9 : 1.6
                )
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(active ? Color.white.opacity(0.92) : Color.white.opacity(0.42))
                    .lineLimit(1)
            }
            .frame(minWidth: 62, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    func seekGesture(width: CGFloat, duration: Double) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard duration > 0 else { return }
                isSeeking = true
                seekTime = Double(min(max(value.location.x / width, 0), 1)) * duration
            }
            .onEnded { value in
                guard duration > 0 else {
                    isSeeking = false
                    return
                }
                let target = Double(min(max(value.location.x / width, 0), 1)) * duration
                seekTime = target
                isSeeking = false
                player.seek(to: target)
            }
    }
}

// MARK: - State and sheets

private extension RiveMotionPlayerLayout {
    var validDuration: Double {
        playbackTime.duration.isFinite && playbackTime.duration > 0 ? playbackTime.duration : 0
    }

    var validCurrentTime: Double {
        playbackTime.currentTime.isFinite ? max(playbackTime.currentTime, 0) : 0
    }

    func refreshPalette() {
        colors.extract(from: artworkURL)
    }

    func synchronizeRive() {
        rive.synchronize(
            isPlaying: player.isPlaying,
            shouldAnimate: scenePhase == .active && !reduceMotion
        )
    }

    var qualitySheet: some View {
        SoundQualitySheet(
            currentQuality: player.soundQuality,
            currentQQQuality: player.qqMusicQuality,
            isQQMusic: player.currentSong?.isQQMusic == true,
            onSelectNetease: { quality in
                player.switchQuality(quality)
                showsQuality = false
            },
            onSelectQQ: { quality in
                player.switchQQMusicQuality(quality)
                showsQuality = false
            },
            songMid: player.currentSong?.qqMid,
            songId: player.currentSong?.id,
            isQishui: player.currentSong?.isQishui == true,
            qishuiTrackId: player.currentSong?.qishuiTrackId,
            onSelectQishui: { info in
                player.switchQishuiQuality(info)
                showsQuality = false
            }
        )
    }

    var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "090915"), Color(hex: "15142B"), Color(hex: "080811")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.25))
                .frame(width: 430, height: 430)
                .blur(radius: 110)
                .offset(x: -160, y: -250)

            Circle()
                .fill(secondaryAccent.opacity(0.22))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: 180, y: 80)

            Circle()
                .fill(tertiaryAccent.opacity(0.13))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -120, y: 360)

            LinearGradient(
                colors: [.white.opacity(0.035), .clear, .black.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: colors.resolvedURL)
    }
}

// MARK: - Rive runtime state

@MainActor
private final class RiveMotionAnimationModel: ObservableObject {
    let playPause: RiveViewModel?
    let rings: RiveViewModel?

    init() {
        if Bundle.main.url(forResource: "play_pause", withExtension: "riv") != nil {
            playPause = RiveViewModel(
                fileName: "play_pause",
                stateMachineName: "State Machine 1",
                fit: .contain,
                alignment: .center,
                autoPlay: true,
                loadCdn: false
            )
        } else {
            playPause = nil
        }

        if Bundle.main.url(forResource: "interactive_rings", withExtension: "riv") != nil {
            let model = RiveViewModel(
                fileName: "interactive_rings",
                stateMachineName: "State Machine 1",
                fit: .contain,
                alignment: .center,
                autoPlay: true,
                loadCdn: false
            )
            model.forwardsListenerEvents = true
            rings = model
        } else {
            rings = nil
        }
    }

    func synchronize(isPlaying: Bool, shouldAnimate: Bool) {
        playPause?.setPreferredFramesPerSecond(preferredFramesPerSecond: shouldAnimate ? 60 : 30)
        playPause?.setInput("Play", value: isPlaying)

        rings?.setPreferredFramesPerSecond(preferredFramesPerSecond: shouldAnimate ? 60 : 30)
        // Keep the touch state machine alive while the player is visible, even when audio is paused.
        // Playback state still drives the dedicated play/pause state machine above.
        if shouldAnimate {
            rings?.play()
        } else {
            rings?.pause()
        }
    }
}

private struct RiveMotionMetrics {
    let size: CGSize
    let safeArea: EdgeInsets
    let headerTopPadding: CGFloat
    let isPad: Bool

    var usesWideLayout: Bool {
        size.width >= 680 && size.width > size.height
    }

    var isCompact: Bool {
        !usesWideLayout && size.height < 740
    }

    var maximumWidth: CGFloat {
        usesWideLayout ? min(size.width, 1120) : min(size.width, 620)
    }

    var horizontalInset: CGFloat {
        usesWideLayout ? 30 : (isCompact ? 16 : 20)
    }

    var headerTopInset: CGFloat {
        max(headerTopPadding, safeArea.top + 4)
    }

    var bottomInset: CGFloat {
        max(safeArea.bottom + 8, usesWideLayout ? 12 : 18)
    }

    var stageSize: CGFloat {
        if usesWideLayout {
            return min(size.height - headerTopInset - bottomInset - 62, size.width * 0.42, isPad ? 470 : 400)
        }
        let widthLimit = size.width - horizontalInset * 2
        return min(widthLimit, size.height * (isCompact ? 0.38 : 0.43), isPad ? 460 : 410)
    }

    var stageTopSpacing: CGFloat { isCompact ? 2 : 8 }
    var consoleTopSpacing: CGFloat { isCompact ? 2 : 10 }
    var wideGap: CGFloat { isPad ? 54 : 34 }
    var consoleWidth: CGFloat { min(size.width * 0.43, 500) }
}

private func riveFormatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    return String(format: "%d:%02d", total / 60, total % 60)
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
