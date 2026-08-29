import SwiftUI

struct ConsolePlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var time = PlaybackTimePublisher.shared

    @State private var showsLyrics = false
    @State private var showsQueue = false
    @State private var showsQuality = false
    @State private var showsMore = false
    @State private var showsEQ = false
    @State private var showsTheme = false
    @State private var isSeeking = false
    @State private var seekTime = 0.0

    var body: some View {
        GeometryReader { proxy in
            let metrics = ConsolePlayerMetrics(
                size: proxy.size,
                safeArea: proxy.safeAreaInsets,
                headerTopPadding: DeviceLayout.headerTopPadding
            )

            ZStack {
                SignalRootBackdrop()

                VStack(spacing: 0) {
                    toolbar
                        .padding(.top, metrics.topInset)
                        .padding(.bottom, metrics.toolbarBottomInset)

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
        .preferredColorScheme(.dark)
        .compatFontDesign(nil)
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            PlaylistPopupView()
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

private extension ConsolePlayerLayout {
    var toolbar: some View {
        HStack(spacing: 10) {
            consoleButton(icon: .back, label: String(localized: "返回")) {
                dismiss()
            }

            HStack(spacing: 8) {
                SignalBreathingIndicator(size: 7)

                Text(queuePositionText)
                    .font(SignalStyle.monoFont(10, weight: .bold))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .monospacedDigit()
            }

            Spacer(minLength: 6)

            Button {
                showsQuality = true
            } label: {
                Text(player.qualityButtonText)
                    .font(SignalStyle.monoFont(10, weight: .bold))
                    .foregroundStyle(SignalStyle.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(SignalSurfaceBackground(cornerRadius: 9, elevated: false, pressed: true, fill: SignalStyle.control))
            }
            .buttonStyle(ConsolePlayerPressStyle())
            .playerQualitySelectionAvailability()

            consoleButton(icon: .more, label: String(localized: "更多")) {
                showsMore = true
            }
        }
    }

    func portraitContent(metrics: ConsolePlayerMetrics) -> some View {
        VStack(spacing: 0) {
            playbackStage(size: metrics.stageSize)

            songInformation(compact: metrics.isCompact)
                .padding(.top, metrics.informationTopInset)

            progressSection(compact: metrics.isCompact)
                .padding(.top, metrics.progressTopInset)

            Spacer(minLength: metrics.minimumSpacer)

            transportControls(compact: metrics.isCompact)
        }
    }

    func wideContent(metrics: ConsolePlayerMetrics) -> some View {
        HStack(spacing: metrics.wideGap) {
            playbackStage(size: metrics.stageSize)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                songInformation(compact: false)
                progressSection(compact: false)
                    .padding(.top, 24)
                transportControls(compact: false)
                    .padding(.top, 30)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension ConsolePlayerLayout {
    func playbackStage(size: CGFloat) -> some View {
        ZStack {
            SignalScreenBackground(cornerRadius: 16)

            if showsLyrics, let song = player.currentSong {
                LyricsView(
                    song: song,
                    onBackgroundTap: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                            showsLyrics = false
                        }
                    },
                    adaptivePrimaryColor: SignalStyle.ink,
                    adaptiveSecondaryColor: SignalStyle.inkSoft,
                    enforcesAdaptiveContrast: true
                )
                .environment(\.colorScheme, .dark)
                .padding(10)
            } else {
                artwork(size: size)
                    .onTapWithHaptic {
                        guard player.currentSong != nil else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                            showsLyrics = true
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.78), lineWidth: 0.9)
        }
        .overlay(alignment: .topLeading) {
            playbackState
                .padding(13)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 22, y: 10)
    }

    func artwork(size: CGFloat) -> some View {
        ZStack {
            SignalStyle.screen

            if let song = player.currentSong {
                CachedAsyncImage(
                    url: song.coverUrl?.sized(1000),
                    width: size,
                    height: size
                ) {
                    consoleArtworkPlaceholder
                }
                .aspectRatio(contentMode: .fill)

                if let dynamicURL = player.dynamicCoverUrl, !dynamicURL.isEmpty {
                    DynamicCoverView(urlString: dynamicURL, cornerRadius: 0)
                }
            } else {
                consoleArtworkPlaceholder
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.08), Color.black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )

        }
        .frame(width: size, height: size)
        .clipped()
    }

    var consoleArtworkPlaceholder: some View {
        ZStack {
            SignalStyle.screen
            SignalIconBadge(icon: .musicNote, tint: SignalStyle.accent, size: 70)
        }
    }

    var playbackState: some View {
        HStack(spacing: 7) {
            SignalBreathingIndicator(size: 7)

            Text(player.isPlaying ? String(localized: "正在播放") : String(localized: "已暂停"))
                .font(SignalStyle.labelFont(10, weight: .medium))
                .foregroundStyle(SignalStyle.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 27)
        .background(SignalStyle.screen.opacity(0.82), in: Capsule())
        .overlay(Capsule().stroke(SignalStyle.separator.opacity(0.76), lineWidth: 0.7))
    }
}

private extension ConsolePlayerLayout {
    func songInformation(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 7) {
            Text(player.currentSong?.name ?? String(localized: "暂无歌曲"))
                .monoPlayerDisplayFont(
                    size: compact ? 21 : 25,
                    weight: .bold,
                    fallback: SignalStyle.titleFont(compact ? 21 : 25, weight: .bold)
                )
                .foregroundStyle(SignalStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 8) {
                Text(player.currentSong?.artistName ?? "—")
                    .font(SignalStyle.bodyFont(compact ? 12 : 14, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)

                if let album = player.currentSong?.al?.name, !album.isEmpty {
                    Circle()
                        .fill(SignalStyle.inkMuted.opacity(0.62))
                        .frame(width: 3, height: 3)

                    Text(album)
                        .font(SignalStyle.labelFont(compact ? 10 : 12, weight: .medium))
                        .foregroundStyle(SignalStyle.inkMuted)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func progressSection(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 9) {
            ConsoleSegmentedProgress(
                progress: displayProgress,
                isEnabled: validDuration > 0,
                onChanged: { ratio in
                    isSeeking = true
                    seekTime = ratio * validDuration
                },
                onEnded: { ratio in
                    let target = ratio * validDuration
                    seekTime = target
                    isSeeking = false
                    player.seek(to: target)
                }
            )
            .frame(height: compact ? 25 : 30)

            HStack {
                Text(formatTime(isSeeking ? seekTime : validCurrentTime))
                Spacer()
                Text(formatTime(validDuration))
            }
            .font(SignalStyle.monoFont(10, weight: .semibold))
            .foregroundStyle(SignalStyle.inkMuted)
            .monospacedDigit()
        }
    }

    func transportControls(compact: Bool) -> some View {
        let sideSize: CGFloat = compact ? 40 : 46
        let playSize: CGFloat = compact ? 64 : 74

        return HStack(spacing: 0) {
            transportButton(icon: player.mode.monoIcon, size: sideSize, iconSize: 16, label: player.mode.displayName) {
                player.switchMode()
            }

            Spacer(minLength: 7)

            transportButton(icon: .previous, size: sideSize, iconSize: 22, label: String(localized: "上一首")) {
                player.previous()
            }

            Spacer(minLength: 7)

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(SignalStyle.accent)
                        .shadow(color: Color.black.opacity(0.28), radius: 10, y: 5)

                    if player.isLoading {
                        ProgressView()
                            .tint(SignalStyle.onAccent)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: compact ? 25 : 29,
                            color: SignalStyle.onAccent,
                            lineWidth: 2
                        )
                    }
                }
                .frame(width: playSize, height: playSize)
            }
            .buttonStyle(ConsolePlayerPressStyle(scale: 0.9))
            .accessibilityLabel(player.isPlaying ? String(localized: "暂停") : String(localized: "播放"))

            Spacer(minLength: 7)

            transportButton(icon: .next, size: sideSize, iconSize: 22, label: String(localized: "playback_next_track")) {
                player.next()
            }

            Spacer(minLength: 7)

            transportButton(icon: .list, size: sideSize, iconSize: 17, label: String(localized: "player_queue")) {
                showsQueue = true
            }
        }
        .frame(maxWidth: .infinity)
    }

    func transportButton(
        icon: MonoIcon.IconType,
        size: CGFloat,
        iconSize: CGFloat,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                SignalSurfaceBackground(cornerRadius: 10, elevated: false, pressed: true, fill: SignalStyle.control)
                MonoIcon(icon: icon, size: iconSize, color: SignalStyle.ink, lineWidth: 1.75)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(ConsolePlayerPressStyle())
        .accessibilityLabel(label)
    }

    func consoleButton(icon: MonoIcon.IconType, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                SignalSurfaceBackground(cornerRadius: 9, elevated: false, pressed: true, fill: SignalStyle.control)
                MonoIcon(icon: icon, size: 17, color: SignalStyle.ink, lineWidth: 1.75)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(ConsolePlayerPressStyle())
        .accessibilityLabel(label)
    }
}

private extension ConsolePlayerLayout {
    var validDuration: Double {
        let value = time.duration
        return value.isFinite && value > 0 ? value : 0
    }

    var validCurrentTime: Double {
        let value = time.currentTime
        return value.isFinite ? max(value, 0) : 0
    }

    var displayProgress: Double {
        guard validDuration > 0 else { return 0 }
        let value = isSeeking ? seekTime : validCurrentTime
        return min(max(value / validDuration, 0), 1)
    }

    var queuePositionText: String {
        let queue = player.currentContextList.filter { $0.podcastRadioId == nil }
        guard let current = player.currentSong,
              let index = queue.firstIndex(where: { $0.id == current.id }) else {
            return "00 / 00"
        }
        return String(format: "%02d / %02d", index + 1, queue.count)
    }

    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
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
}

private struct ConsolePlayerMetrics {
    let size: CGSize
    let safeArea: EdgeInsets
    let headerTopPadding: CGFloat

    var usesWideLayout: Bool { size.width >= 720 && size.width > size.height }
    var isCompact: Bool { !usesWideLayout && size.height < 730 }
    var maximumWidth: CGFloat { usesWideLayout ? min(size.width, 1120) : min(size.width, 560) }
    var horizontalInset: CGFloat { usesWideLayout ? 30 : (size.width < 380 ? 15 : 20) }
    var topInset: CGFloat { max(safeArea.top + 5, headerTopPadding) }
    var toolbarBottomInset: CGFloat { isCompact ? 7 : 12 }
    var bottomInset: CGFloat { max(safeArea.bottom, isCompact ? 5 : 10) }

    var stageSize: CGFloat {
        if usesWideLayout {
            return min(size.height * 0.67, size.width * 0.43, 470)
        }
        let widthLimit = size.width - horizontalInset * 2
        return min(widthLimit, size.height * (isCompact ? 0.39 : 0.43), 390)
    }

    var informationTopInset: CGFloat { isCompact ? 10 : 18 }
    var progressTopInset: CGFloat { isCompact ? 8 : 18 }
    var minimumSpacer: CGFloat { isCompact ? 7 : 14 }
    var wideGap: CGFloat { min(max(size.width * 0.055, 30), 72) }
}

private struct ConsoleSegmentedProgress: View {
    let progress: Double
    let isEnabled: Bool
    let onChanged: (Double) -> Void
    let onEnded: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let ratio = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SignalStyle.inkMuted.opacity(0.22))

                Capsule()
                    .fill(SignalStyle.accent)
                    .frame(width: proxy.size.width * ratio)

                Circle()
                    .fill(SignalStyle.ink)
                    .frame(width: 10, height: 10)
                    .offset(x: max(0, min(proxy.size.width - 10, proxy.size.width * ratio - 5)))
                    .opacity(isEnabled ? 1 : 0)
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled, proxy.size.width > 0 else { return }
                        onChanged(min(max(value.location.x / proxy.size.width, 0), 1))
                    }
                    .onEnded { value in
                        guard isEnabled, proxy.size.width > 0 else { return }
                        onEnded(min(max(value.location.x / proxy.size.width, 0), 1))
                    }
            )
        }
    }
}

private struct ConsolePlayerPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
