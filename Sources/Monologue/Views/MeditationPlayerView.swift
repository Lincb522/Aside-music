import Combine
import Foundation
import SwiftUI
import HiconIcons

struct MeditationPlayerView: View {
    let source: MeditationPlaybackSource
    let radio: RadioStation

    @StateObject private var viewModel: MeditationPlayerViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showTimerSheet = false
    @State private var isScrubbing = false
    @State private var scrubbedTime: Double = 0
    @StateObject private var meditationTimer = MeditationTimerController()
    #if os(iOS)
    @State private var previousScreenBrightness: CGFloat?
    private static let meditationTargetBrightness: CGFloat = 0.18
    #endif

    init(radio: RadioStation) {
        self.source = .radio(radio)
        self.radio = radio
        _viewModel = StateObject(wrappedValue: MeditationPlayerViewModel(radio: radio))
    }

    init(source: MeditationPlaybackSource) {
        self.source = source
        self.radio = source.radio
        _viewModel = StateObject(wrappedValue: MeditationPlayerViewModel(source: source))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MeditationImmersiveBackground(
                    isPlaying: viewModel.isMeditationPlaying,
                    coverURL: viewModel.currentCoverURL?.sized(500)
                )
                    .ignoresSafeArea()

                if viewModel.programs.isEmpty && viewModel.errorMessage == nil {
                    loadingState(size: proxy.size)
                } else if let errorMessage = viewModel.errorMessage, viewModel.programs.isEmpty {
                    errorState(errorMessage, size: proxy.size)
                } else {
                    playerStage(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
        .onAppear {
            applyMeditationBrightness()
        }
        .task {
            await viewModel.loadAndStartIfNeeded()
        }
        .onChange(of: player.currentSong?.id) { _, newSongID in
            meditationTimer.handleSongChange(newSongID)
        }
        .onChange(of: timePublisher.currentTime) { _, currentTime in
            meditationTimer.handlePlaybackProgress(
                currentTime: currentTime,
                duration: timePublisher.duration
            )
        }
        .onDisappear {
            meditationTimer.cancel()
            restoreMeditationBrightness()
        }
        .monologueSheet(isPresented: $showTimerSheet, preset: .compact) {
            MeditationTimerSheet(
                timer: meditationTimer,
                onTimerFinished: stopMeditationAudio
            )
        }
    }

    private func playerStage(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let compactHeight = size.height < 720
        let horizontalPadding = DeviceLayout.viewHorizontalPadding + 10

        return VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding + 2)
                .padding(.top, max(safeAreaInsets.top + 8, DeviceLayout.headerTopPadding))

            Spacer(minLength: compactHeight ? 14 : 26)

            meditationCore(size: coreSize(for: size))
                .padding(.horizontal, horizontalPadding)

            nowPlayingSection
                .padding(.horizontal, horizontalPadding)
                .padding(.top, compactHeight ? 24 : 34)

            progressSection
                .padding(.horizontal, horizontalPadding)
                .padding(.top, compactHeight ? 18 : 24)

            controlsSection
                .padding(.top, compactHeight ? 18 : 26)

            Spacer(minLength: max(safeAreaInsets.bottom + (compactHeight ? 14 : 22), 30))
        }
        .frame(width: size.width, height: size.height)
    }

    private func loadingState(size: CGSize) -> some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding)

            Spacer()

            MeditationPlayerLoadingGlyph(tint: meditationMist, foreground: .white.opacity(0.9), size: 62)

            Spacer()
        }
        .frame(width: size.width, height: size.height)
    }

    private func errorState(_ message: String, size: CGSize) -> some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding)

            Spacer()

            VStack(spacing: 14) {
                MeditationHicon(image: Hicon.dangerTriangle, size: 36, color: .white.opacity(0.68))

                Text(String(localized: "meditation_player_load_failed"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button {
                    Task { await viewModel.retry() }
                } label: {
                    Text(String(localized: "meditation_player_retry"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "081312"))
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                        .background(meditationMist, in: Capsule())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            }
            .padding(.horizontal, 34)

            Spacer()
        }
        .frame(width: size.width, height: size.height)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                exitMeditation()
            } label: {
                HStack(spacing: 8) {
                    MeditationHicon(image: Hicon.close, size: 13, color: .white.opacity(0.9))
                    Text(String(localized: "meditation_player_exit"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(topButtonBackground)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

            Spacer(minLength: 10)

            Button {
                showTimerSheet = true
            } label: {
                HStack(spacing: 7) {
                    MeditationHicon(image: Hicon.timeCircle1, size: 14, color: timerAccentColor)
                    Text(timerStatusText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(topButtonBackground)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
    }

    private func meditationCore(size: CGFloat) -> some View {
        MeditationImmersiveCore(
            size: size,
            isPlaying: viewModel.isMeditationPlaying,
            isLoading: viewModel.isMeditationLoading,
            coverURL: viewModel.currentCoverURL?.sized(700),
            tint: meditationMist,
            secondaryTint: meditationAurora,
            glowTint: meditationTide
        )
        .contentShape(Circle())
        .onTapGesture {
            viewModel.togglePlayPause()
        }
        .accessibilityLabel(Text(viewModel.currentTitle))
        .accessibilityAddTraits(.isButton)
    }

    private var nowPlayingSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentTitle)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .shadow(color: Color.black.opacity(0.36), radius: 16, x: 0, y: 8)

            Text(viewModel.currentSubtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
                .lineLimit(1)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            progressBar

            HStack {
                Text(formatTime(displayedCurrentTime))
                Spacer()
                Text(formatTime(displayedDuration))
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.58))
            .monospacedDigit()
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progressWidth = width * playbackProgress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [meditationMist, meditationTide, meditationAurora],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth, height: 5)

                Circle()
                    .fill(.white)
                    .frame(width: 13, height: 13)
                    .shadow(color: meditationTide.opacity(0.52), radius: 9, x: 0, y: 0)
                    .offset(x: max(progressWidth - 6.5, -1))
                    .opacity(displayedDuration > 0 ? 1 : 0)
            }
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard displayedDuration > 0 else { return }
                        isScrubbing = true
                        let percent = min(max(value.location.x / width, 0), 1)
                        scrubbedTime = Double(percent) * displayedDuration
                    }
                    .onEnded { value in
                        guard displayedDuration > 0 else { return }
                        let percent = min(max(value.location.x / width, 0), 1)
                        let target = Double(percent) * displayedDuration
                        player.seek(to: target)
                        scrubbedTime = target
                        isScrubbing = false
                    }
            )
        }
        .frame(height: 24)
    }

    private var controlsSection: some View {
        HStack(spacing: 14) {
            controlButton(image: Hicon.previous, size: 18) {
                viewModel.previousTrack()
            }

            controlButton(image: Hicon.backward10Seconds, size: 20) {
                viewModel.seekBackward()
            }

            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, meditationMist, meditationTide],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: meditationTide.opacity(0.32), radius: 20, x: 0, y: 10)
                        .shadow(color: Color.white.opacity(0.16), radius: 14, x: 0, y: -4)

                    if viewModel.isMeditationLoading {
                        MeditationPlayerLoadingGlyph(
                            tint: Color(hex: "081312"),
                            foreground: Color(hex: "081312"),
                            size: 34
                        )
                    } else {
                        MeditationHicon(
                            image: viewModel.isMeditationPlaying ? Hicon.pause : Hicon.play,
                            size: 28,
                            color: Color(hex: "081312")
                        )
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))

            controlButton(image: Hicon.forward10Seconds, size: 20) {
                viewModel.seekForward()
            }

            controlButton(image: Hicon.next, size: 18) {
                viewModel.nextTrack()
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 14)
        )
    }

    private func controlButton(image: UIImage, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MeditationHicon(image: image, size: size, color: .white.opacity(0.86))
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
    }

    private var topButtonBackground: some View {
        Capsule()
            .fill(Color.white.opacity(0.11))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
    }

    private var playbackProgress: CGFloat {
        guard displayedDuration > 0 else { return 0 }
        return min(max(CGFloat(displayedCurrentTime / displayedDuration), 0), 1)
    }

    private var displayedCurrentTime: Double {
        guard viewModel.isOwnContent else { return 0 }
        return isScrubbing ? scrubbedTime : timePublisher.currentTime
    }

    private var displayedDuration: Double {
        guard viewModel.isOwnContent else { return 0 }
        return timePublisher.duration
    }

    private var hasActiveTimer: Bool {
        meditationTimer.isActive
    }

    private var timerStatusText: String {
        if meditationTimer.stopAfterCurrentTrack {
            return String(localized: "meditation_timer_pending")
        }
        if let remaining = meditationTimer.remaining {
            return formatTime(remaining)
        }
        return String(localized: "meditation_player_timer")
    }

    private var timerAccentColor: Color {
        hasActiveTimer ? meditationGold : meditationMist
    }

    private var meditationMist: Color {
        Color(hex: "DDF8EF")
    }

    private var meditationTide: Color {
        Color(hex: "78D8C6")
    }

    private var meditationAurora: Color {
        Color(hex: "A9A8FF")
    }

    private var meditationGold: Color {
        Color(hex: "F4D58D")
    }

    private func coreSize(for size: CGSize) -> CGFloat {
        let heightFactor: CGFloat = size.height < 620 ? 0.34 : 0.40
        let maximum: CGFloat = size.height < 620 ? 260 : 332
        return min(size.width * 0.72, size.height * heightFactor, maximum)
    }

    private func exitMeditation() {
        meditationTimer.cancel()
        stopMeditationAudio()
        dismiss()
    }

    private func stopMeditationAudio() {
        guard viewModel.isOwnContent else { return }
        player.stopPodcastPlaybackRestoringMusicContext()
    }

    private func applyMeditationBrightness() {
        #if os(iOS)
        guard previousScreenBrightness == nil else { return }
        let currentBrightness = UIScreen.main.brightness
        previousScreenBrightness = currentBrightness
        UIScreen.main.brightness = min(currentBrightness, Self.meditationTargetBrightness)
        #endif
    }

    private func restoreMeditationBrightness() {
        #if os(iOS)
        guard let previousScreenBrightness else { return }
        UIScreen.main.brightness = previousScreenBrightness
        self.previousScreenBrightness = nil
        #endif
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

@MainActor
private final class MeditationTimerController: ObservableObject {
    @Published private(set) var remaining: TimeInterval?
    @Published private(set) var configuredMinutes: Int?
    @Published private(set) var stopAfterCurrentTrack = false

    private var deadline: Date?
    private var timer: Timer?
    private var trackedSongID: Int?
    private var onFinish: (() -> Void)?

    var isActive: Bool {
        remaining != nil || stopAfterCurrentTrack
    }

    func start(minutes: Int, onFinish: @escaping () -> Void) {
        cancel()
        let total = TimeInterval(minutes * 60)
        deadline = Date().addingTimeInterval(total)
        remaining = total
        configuredMinutes = minutes
        self.onFinish = onFinish

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func activateStopAfterCurrentTrack(currentSongID: Int?, onFinish: @escaping () -> Void) {
        cancel()
        stopAfterCurrentTrack = true
        trackedSongID = currentSongID
        self.onFinish = onFinish
    }

    func handleSongChange(_ songID: Int?) {
        guard stopAfterCurrentTrack, let songID else { return }

        if let trackedSongID, trackedSongID != songID {
            finish()
        } else {
            trackedSongID = songID
        }
    }

    func handlePlaybackProgress(currentTime: Double, duration: Double) {
        guard stopAfterCurrentTrack, duration > 0 else { return }
        guard currentTime >= max(duration - 0.5, 0) else { return }
        finish()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        deadline = nil
        remaining = nil
        configuredMinutes = nil
        stopAfterCurrentTrack = false
        trackedSongID = nil
        onFinish = nil
    }

    private func tick() {
        guard let deadline else { return }

        let nextRemaining = deadline.timeIntervalSinceNow
        if nextRemaining <= 0 {
            finish()
        } else {
            remaining = nextRemaining.rounded(.up)
        }
    }

    private func finish() {
        let finishAction = onFinish
        cancel()
        finishAction?()
    }
}

private struct MeditationTimerSheet: View {
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject var timer: MeditationTimerController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    let onTimerFinished: () -> Void

    private let presets = [10, 20, 30, 60]
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text(String(localized: "meditation_player_timer_title"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                } label: {
                    MeditationHicon(image: Hicon.close, size: 14, color: .white.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.09), in: Circle())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(presets, id: \.self) { minutes in
                    timerButton(
                        title: String(format: String(localized: "meditation_timer_minutes"), minutes),
                        isActive: timer.configuredMinutes == minutes
                    ) {
                        timer.start(minutes: minutes, onFinish: onTimerFinished)
                    }
                }

                timerButton(
                    title: String(localized: "meditation_timer_pending"),
                    isActive: timer.stopAfterCurrentTrack
                ) {
                    timer.activateStopAfterCurrentTrack(
                        currentSongID: player.currentSong?.id,
                        onFinish: onTimerFinished
                    )
                }

                timerButton(
                    title: String(localized: "meditation_timer_off"),
                    isActive: !hasActiveTimer,
                    isDestructive: hasActiveTimer
                ) {
                    timer.cancel()
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .background(MeditationTimerBackground().ignoresSafeArea())
    }

    private var hasActiveTimer: Bool {
        timer.isActive
    }

    private func timerButton(
        title: String,
        isActive: Bool,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? Color(hex: "0E1B17") : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isActive
                        ? (isDestructive ? Color.white.opacity(0.88) : Color(hex: "DDF8EF"))
                        : Color.white.opacity(isDestructive ? 0.07 : 0.10),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(isActive ? 0 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }
}

private struct MeditationHicon: View {
    let image: UIImage
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(uiImage: image)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

private struct MeditationPlayerLoadingGlyph: View {
    let tint: Color
    let foreground: Color
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .trim(from: 0.12 + CGFloat(index) * 0.05, to: 0.72)
                        .stroke(
                            tint.opacity(0.78 - Double(index) * 0.17),
                            style: StrokeStyle(lineWidth: max(1.2, size * 0.055 - CGFloat(index) * 0.35), lineCap: .round)
                        )
                        .frame(
                            width: size - CGFloat(index) * size * 0.22,
                            height: size - CGFloat(index) * size * 0.22
                        )
                        .rotationEffect(.degrees(phase * (76 + Double(index) * 21) + Double(index) * 56))
                }

                Circle()
                    .fill(foreground.opacity(0.12))
                    .frame(width: size * 0.34, height: size * 0.34)
                    .scaleEffect(reduceMotion ? 1 : 0.86 + CGFloat((sin(phase * 2.8) + 1) * 0.08))
            }
            .frame(width: size, height: size)
        }
    }
}

private struct MeditationImmersiveBackground: View {
    let isPlaying: Bool
    let coverURL: URL?

    var body: some View {
        GeometryReader { proxy in
            TimelineView(AppFrameRate.animationTimeline(paused: !isPlaying)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    Color(hex: "020409")

                    coverBackdrop(size: proxy.size)

                    LinearGradient(
                        colors: [
                            Color(hex: "081018").opacity(0.96),
                            Color(hex: "071512").opacity(0.94),
                            Color(hex: "030509")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    MeditationQuietLightField(size: proxy.size, phase: phase, isPlaying: isPlaying)

                    VStack(spacing: 0) {
                        Spacer()
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(hex: "071915").opacity(0.28),
                                Color.black.opacity(0.62)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: proxy.size.height * 0.42)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    @ViewBuilder
    private func coverBackdrop(size: CGSize) -> some View {
        if let coverURL {
            CachedAsyncImage(url: coverURL, width: size.width, height: size.height) {
                Color.clear
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .saturation(0.74)
            .contrast(1.06)
            .blur(radius: 46)
            .scaleEffect(1.20)
            .opacity(0.30)
        }
    }
}

private struct MeditationTimerBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "05080D")
            LinearGradient(
                colors: [
                    Color(hex: "101827"),
                    Color(hex: "061916"),
                    Color(hex: "030509")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct MeditationQuietLightField: View {
    let size: CGSize
    let phase: TimeInterval
    let isPlaying: Bool

    var body: some View {
        let drift = isPlaying ? CGFloat(sin(phase * 0.10)) : 0
        let slowDrift = isPlaying ? CGFloat(cos(phase * 0.08)) : 0

        return ZStack {
            RadialGradient(
                colors: [
                    Color(hex: "8BD8C7").opacity(0.30),
                    Color(hex: "8BD8C7").opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: size.width * 0.62
            )
            .frame(width: size.width * 1.10, height: size.width * 1.10)
            .offset(x: size.width * (-0.24 + drift * 0.04), y: -size.height * 0.22)
            .blur(radius: 24)

            RadialGradient(
                colors: [
                    Color(hex: "B8B4FF").opacity(0.22),
                    Color(hex: "B8B4FF").opacity(0.06),
                    Color.clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: size.width * 0.58
            )
            .frame(width: size.width * 1.18, height: size.width * 1.18)
            .offset(x: size.width * (0.24 + slowDrift * 0.035), y: size.height * 0.04)
            .blur(radius: 30)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .blendMode(.screen)
    }
}

private struct MeditationImmersiveCore: View {
    let size: CGFloat
    let isPlaying: Bool
    let isLoading: Bool
    let coverURL: URL?
    let tint: Color
    let secondaryTint: Color
    let glowTint: Color

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(paused: !isPlaying && !isLoading)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                MeditationPortalAura(
                    size: size,
                    phase: phase,
                    isPlaying: isPlaying,
                    tint: tint,
                    secondaryTint: secondaryTint,
                    glowTint: glowTint
                )

                MeditationPortalArtwork(
                    size: size * 0.78,
                    phase: phase,
                    coverURL: coverURL,
                    tint: tint,
                    glowTint: glowTint
                )

                MeditationCenterGlyph(
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                    tint: tint
                )
            }
            .frame(width: size, height: size)
        }
    }
}

private struct MeditationPortalAura: View {
    let size: CGFloat
    let phase: TimeInterval
    let isPlaying: Bool
    let tint: Color
    let secondaryTint: Color
    let glowTint: Color

    var body: some View {
        let pulse = isPlaying ? CGFloat(1 + sin(phase * 0.52) * 0.018) : 1

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            glowTint.opacity(0.30),
                            secondaryTint.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: size * 0.58
                    )
                )
                .frame(width: size * 0.94, height: size * 0.94)
                .scaleEffect(pulse)
                .blur(radius: 18)

            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
                .frame(width: size * 0.82, height: size * 0.82)

            RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
                .stroke(secondaryTint.opacity(0.10), lineWidth: 1)
                .frame(width: size * 0.98, height: size * 0.98)
        }
    }
}

private struct MeditationPortalArtwork: View {
    let size: CGFloat
    let phase: TimeInterval
    let coverURL: URL?
    let tint: Color
    let glowTint: Color

    var body: some View {
        ZStack {
            baseFill

            coverLayer

            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            MeditationPortalWater(phase: phase, tint: tint, glowTint: glowTint)
                .padding(.horizontal, size * 0.09)
                .offset(y: size * 0.18)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: glowTint.opacity(0.30), radius: size * 0.15, x: 0, y: size * 0.06)
        .shadow(color: Color.black.opacity(0.42), radius: size * 0.16, x: 0, y: size * 0.10)
    }

    private var baseFill: some View {
        LinearGradient(
            colors: [
                Color(hex: "17302D"),
                Color(hex: "0D141D"),
                Color(hex: "05070B")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var coverLayer: some View {
        if let coverURL {
            CachedAsyncImage(url: coverURL, width: size, height: size) {
                baseFill
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .saturation(0.76)
            .contrast(1.06)
            .overlay(Color(hex: "04100F").opacity(0.22))
        }
    }
}

private struct MeditationPortalWater: View {
    let phase: TimeInterval
    let tint: Color
    let glowTint: Color

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                MeditationWaveLine(
                    phase: phase * (0.18 + Double(index) * 0.02) + Double(index) * 0.8,
                    amplitude: 3.0 + CGFloat(index) * 0.65,
                    frequency: 1.4 + Double(index) * 0.24
                )
                .stroke(
                    index.isMultiple(of: 2) ? tint.opacity(0.34) : glowTint.opacity(0.28),
                    style: StrokeStyle(lineWidth: index == 0 ? 1.4 : 1.0, lineCap: .round)
                )
                .frame(height: 16)
            }
        }
        .blur(radius: 0.15)
    }
}

private struct MeditationCenterGlyph: View {
    let isPlaying: Bool
    let isLoading: Bool
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "04100F").opacity(0.66))
                .frame(width: 68, height: 68)
                .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.26), radius: 14, x: 0, y: 8)

            if isLoading {
                MeditationPlayerLoadingGlyph(tint: tint, foreground: tint, size: 34)
            } else {
                MeditationHicon(
                    image: isPlaying ? Hicon.pause : Hicon.play,
                    size: 25,
                    color: .white.opacity(0.95)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
        }
    }
}

private struct MeditationWaveLine: Shape {
    var phase: TimeInterval
    let amplitude: CGFloat
    let frequency: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))

        for step in 0...48 {
            let fraction = CGFloat(step) / 48
            let x = rect.width * fraction
            let wave = sin(Double(fraction) * .pi * 2 * frequency + phase) * Double(amplitude)
            path.addLine(to: CGPoint(x: x, y: rect.midY + CGFloat(wave)))
        }

        return path
    }
}
