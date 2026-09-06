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
            let metrics = ConsolePlayerMetrics(size: proxy.size)

            ZStack {
                SignalRootBackdrop()

                VStack(spacing: 0) {
                    toolbar
                        .padding(.top, DeviceLayout.playerHeaderTopPadding)
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
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showsMore {
                    PlayerMoreMenu(
                        isPresented: $showsMore,
                        anchorFrame: anchorFrame,
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

            Spacer(minLength: 10)

            Button {
                showsQuality = true
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(SignalStyle.accent)
                        .frame(width: 4, height: 4)

                    Text(player.qualityButtonText)
                        .font(SignalStyle.monoFont(9, weight: .semibold))
                        .foregroundStyle(SignalStyle.inkSoft)
                        .lineLimit(1)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(ConsolePlayerPressStyle())
            .playerQualitySelectionAvailability()

            consoleButton(icon: .more, label: String(localized: "更多")) {
                showsMore = true
            }
            .playerMoreMenuAnchor()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.62))
                .frame(height: 0.65)
        }
    }

    func portraitContent(metrics: ConsolePlayerMetrics) -> some View {
        VStack(spacing: 0) {
            playbackStatus
                .padding(.top, metrics.isCompact ? 7 : 10)
                .padding(.bottom, metrics.isCompact ? 7 : 10)

            mediaPlane(size: metrics.artworkSize)

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
            VStack(spacing: 0) {
                playbackStatus
                    .padding(.bottom, 10)
                mediaPlane(size: metrics.artworkSize)
            }

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                songInformation(compact: false)
                progressSection(compact: false)
                    .padding(.top, 22)
                transportControls(compact: false)
                    .padding(.top, 28)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension ConsolePlayerLayout {
    var playbackStatus: some View {
        HStack(spacing: 8) {
            SignalBreathingIndicator(size: 6)

            Text(player.isPlaying ? String(localized: "正在播放") : String(localized: "已暂停"))
                .font(SignalStyle.monoFont(9, weight: .semibold))
                .foregroundStyle(SignalStyle.inkSoft)
                .lineLimit(1)

            SignalLevelMeter(
                activeCount: player.isPlaying ? 7 : 2,
                barCount: 9,
                tint: player.isPlaying ? SignalStyle.accent : SignalStyle.inkMuted,
                height: 15
            )

            Spacer(minLength: 8)

            Text(queuePositionText)
                .font(SignalStyle.monoFont(9, weight: .semibold))
                .foregroundStyle(SignalStyle.inkMuted)
                .monospacedDigit()
        }
        .frame(height: 18)
    }

    @ViewBuilder
    func mediaPlane(size: CGFloat) -> some View {
        ZStack {
            if showsLyrics, let song = player.currentSong {
                SignalStyle.screen

                LyricsView(
                    song: song,
                    onBackgroundTap: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            showsLyrics = false
                        }
                    },
                    adaptivePrimaryColor: SignalStyle.ink,
                    adaptiveSecondaryColor: SignalStyle.inkSoft,
                    enforcesAdaptiveContrast: true
                )
                .environment(\.colorScheme, .dark)
                .padding(8)
            } else {
                artwork(size: size)
                    .onTapWithHaptic {
                        guard player.currentSong != nil else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            showsLyrics = true
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.7))
                .frame(height: 0.65)
        }
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
                colors: [.clear, Color.black.opacity(0.04), Color.black.opacity(0.38)],
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
            MonoIcon(icon: .musicNote, size: 44, color: SignalStyle.accent, lineWidth: 1.5)
        }
    }
}

private extension ConsolePlayerLayout {
    func songInformation(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 7) {
            Text(player.currentSong?.name ?? String(localized: "暂无歌曲"))
                .monoPlayerDisplayFont(
                    size: compact ? 22 : 27,
                    weight: .semibold,
                    fallback: SignalStyle.titleFont(compact ? 22 : 27, weight: .semibold)
                )
                .foregroundStyle(SignalStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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
                        .font(SignalStyle.labelFont(compact ? 10 : 12, weight: .regular))
                        .foregroundStyle(SignalStyle.inkMuted)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func progressSection(compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 7) {
            ConsoleLinearProgress(
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
            .frame(height: compact ? 20 : 24)

            HStack {
                Text(formatTime(isSeeking ? seekTime : validCurrentTime))
                Spacer()
                Text(formatTime(validDuration))
            }
            .font(SignalStyle.monoFont(9, weight: .medium))
            .foregroundStyle(SignalStyle.inkMuted)
            .monospacedDigit()
        }
    }

    func transportControls(compact: Bool) -> some View {
        let sideSize: CGFloat = compact ? 40 : 46
        let playSize: CGFloat = compact ? 58 : 68

        return HStack(spacing: 0) {
            transportButton(icon: player.mode.monoIcon, size: sideSize, iconSize: 16, tint: SignalStyle.inkSoft, label: player.mode.displayName) {
                player.switchMode()
            }

            Spacer(minLength: 7)

            transportButton(icon: .previous, size: sideSize, iconSize: 22, tint: SignalStyle.ink, label: String(localized: "上一首")) {
                player.previous()
            }

            Spacer(minLength: 9)

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    ConsolePlayerBreathingRing(
                        isActive: player.isPlaying,
                        diameter: playSize
                    )

                    Circle()
                        .fill(SignalStyle.accent)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.7)
                        }
                        .shadow(color: SignalStyle.accent.opacity(player.isPlaying ? 0.24 : 0.12), radius: 14)

                    if player.isLoading {
                        ProgressView()
                            .tint(SignalStyle.onAccent)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: compact ? 23 : 27,
                            color: SignalStyle.onAccent,
                            lineWidth: 2
                        )
                    }
                }
                .frame(width: playSize, height: playSize)
            }
            .buttonStyle(ConsolePlayerPressStyle(scale: 0.9))
            .accessibilityLabel(player.isPlaying ? String(localized: "暂停") : String(localized: "播放"))

            Spacer(minLength: 9)

            transportButton(icon: .next, size: sideSize, iconSize: 22, tint: SignalStyle.ink, label: String(localized: "playback_next_track")) {
                player.next()
            }

            Spacer(minLength: 7)

            transportButton(icon: .list, size: sideSize, iconSize: 17, tint: SignalStyle.inkSoft, label: String(localized: "player_queue")) {
                showsQueue = true
            }
        }
        .frame(maxWidth: .infinity)
    }

    func transportButton(
        icon: MonoIcon.IconType,
        size: CGFloat,
        iconSize: CGFloat,
        tint: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: iconSize, color: tint, lineWidth: 1.75)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(ConsolePlayerPressStyle())
        .accessibilityLabel(label)
    }

    func consoleButton(icon: MonoIcon.IconType, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 17, color: SignalStyle.ink, lineWidth: 1.75)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ConsolePlayerPressStyle())
        .accessibilityLabel(label)
    }
}

private struct ConsolePlayerBreathingRing: View {
    let isActive: Bool
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(SignalStyle.accent.opacity(expanded ? 0.08 : 0.44), lineWidth: 1.2)
                .scaleEffect(expanded ? 1.28 : 1.03)

            Circle()
                .fill(SignalStyle.accent.opacity(expanded ? 0.018 : 0.1))
                .blur(radius: expanded ? 13 : 5)
                .scaleEffect(expanded ? 1.42 : 1.02)
        }
        .frame(width: diameter, height: diameter)
        .opacity(isActive ? 1 : 0.24)
        .animation(
            isActive && !reduceMotion
                ? .easeInOut(duration: 2.15).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2),
            value: expanded
        )
        .onAppear {
            expanded = isActive && !reduceMotion
        }
        .onChange(of: isActive) { active in
            expanded = active && !reduceMotion
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

    var usesWideLayout: Bool { size.width >= 720 && size.width > size.height }
    var isCompact: Bool { !usesWideLayout && size.height < 730 }
    var maximumWidth: CGFloat { usesWideLayout ? min(size.width, 1120) : min(size.width, 560) }
    var horizontalInset: CGFloat { usesWideLayout ? 30 : (size.width < 380 ? 15 : 20) }
    var toolbarBottomInset: CGFloat { isCompact ? 3 : 5 }
    var bottomInset: CGFloat { isCompact ? 3 : 6 }

    var artworkSize: CGFloat {
        if usesWideLayout {
            return min(size.height * 0.64, size.width * 0.43, 470)
        }
        let widthLimit = size.width - horizontalInset * 2
        return min(widthLimit, size.height * (isCompact ? 0.36 : 0.42), 410)
    }

    var informationTopInset: CGFloat { isCompact ? 10 : 16 }
    var progressTopInset: CGFloat { isCompact ? 8 : 15 }
    var minimumSpacer: CGFloat { isCompact ? 4 : 10 }
    var wideGap: CGFloat { min(max(size.width * 0.055, 30), 72) }
}

private struct ConsoleLinearProgress: View {
    let progress: Double
    let isEnabled: Bool
    let onChanged: (Double) -> Void
    let onEnded: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let ratio = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.74))
                    .frame(height: 1)

                Rectangle()
                    .fill(SignalStyle.accent)
                    .frame(width: proxy.size.width * ratio, height: 1.5)

                Circle()
                    .fill(SignalStyle.ink)
                    .frame(width: 7, height: 7)
                    .offset(x: max(0, min(proxy.size.width - 7, proxy.size.width * ratio - 3.5)))
                    .opacity(isEnabled ? 1 : 0)
            }
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
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
