import SwiftUI

/// Clarity player: one artwork stage and one continuous control membrane.
/// Playback mode, quality, sound center and queue remain first-class controls.
struct ClarityPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var player = PlayerManager.shared

    @State private var showsQueue = false
    @State private var showsQuality = false
    @State private var showsMore = false
    @State private var showsEQ = false
    @State private var showsTheme = false
    @State private var showsLyrics = false

    var body: some View {
        GeometryReader { proxy in
            let metrics = ClarityPlayerMetrics(size: proxy.size)

            ZStack {
                ClarityPlayerBackdrop()

                VStack(spacing: 0) {
                    toolbar

                    if metrics.usesWideLayout {
                        wideContent(metrics: metrics)
                    } else {
                        portraitContent(metrics: metrics)
                    }
                }
                .frame(maxWidth: metrics.maximumContentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, metrics.horizontalInset)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 6))

                if showsLyrics, let song = player.currentSong {
                    lyricStage(song: song, metrics: metrics)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        .zIndex(10)
                }

                if showsMore {
                    PlayerMoreMenu(
                        isPresented: $showsMore,
                        onQuality: { showsQuality = true },
                        onEQ: { showsEQ = true },
                        onTheme: { showsTheme = true }
                    )
                }
            }
        }
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            PlaylistPopupView()
        }
        .monoSheet(isPresented: $showsQuality, preset: .standard) {
            qualitySheet
        }
        .fullScreenCover(isPresented: $showsEQ) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showsTheme, preset: .standard) {
            PlayerThemePickerSheet()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            ClarityCircleButton(icon: .back, size: 42) { dismiss() }

            Spacer(minLength: 8)

            Text(String(localized: "now_playing"))
                .font(ClarityStyle.body(11.5, weight: .semibold))
                .foregroundStyle(ClarityStyle.inkSoft)
                .lineLimit(1)

            Spacer(minLength: 8)

            ClarityCircleButton(icon: .more, size: 42) { showsMore = true }
        }
        .padding(.horizontal, 2)
        .frame(height: 48)
    }

    private func portraitContent(metrics: ClarityPlayerMetrics) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: metrics.compact ? 6 : 14)

            artwork(size: metrics.artworkSize)

            trackIdentity(centered: true, compact: metrics.compact)
                .padding(.top, metrics.compact ? 11 : 17)
                .padding(.horizontal, 12)

            Spacer(minLength: metrics.compact ? 8 : 16)

            playbackDeck(compact: metrics.compact)
        }
        .frame(maxHeight: .infinity)
    }

    private func wideContent(metrics: ClarityPlayerMetrics) -> some View {
        HStack(spacing: 40) {
            artwork(size: metrics.artworkSize)
                .frame(maxWidth: .infinity)

            VStack(spacing: 18) {
                trackIdentity(centered: false, compact: metrics.compact)
                playbackDeck(compact: metrics.compact)
            }
            .frame(width: min(430, metrics.maximumContentWidth * 0.48))
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 14)
    }

    private func artwork(size: CGFloat) -> some View {
        ClarityArtwork(
            url: player.currentSong?.coverUrl,
            size: size,
            radius: min(38, size * 0.12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: min(38, size * 0.12), style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1.1)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 28, y: 16)
    }

    private func trackIdentity(centered: Bool, compact: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: compact ? 4 : 6) {
            Text(player.currentSong?.name ?? String(localized: "not_playing"))
                .font(ClarityStyle.title(compact ? 22 : 27, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
                .multilineTextAlignment(centered ? .center : .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(player.currentSong?.artistName ?? "")
                .font(ClarityStyle.body(compact ? 12.5 : 14, weight: .medium))
                .foregroundStyle(ClarityStyle.inkSoft)
                .lineLimit(1)

            ClarityCurrentLyricButton(centered: centered, action: presentLyrics)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    private func playbackDeck(compact: Bool) -> some View {
        VStack(spacing: 0) {
            ClarityPlaybackProgress()
                .padding(.horizontal, compact ? 18 : 22)
                .padding(.top, compact ? 12 : 16)

            transportControls(compact: compact)
                .padding(.horizontal, compact ? 18 : 24)
                .padding(.top, compact ? 2 : 5)
                .padding(.bottom, compact ? 5 : 8)

            Rectangle()
                .fill(ClarityStyle.line)
                .frame(height: 1)
                .padding(.horizontal, 18)

            utilityControls
                .padding(.horizontal, 10)
                .padding(.vertical, compact ? 6 : 9)
        }
        .background {
            ClarityMembrane(
                shape: RoundedRectangle(cornerRadius: compact ? 28 : 34, style: .continuous),
                strength: .strong
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 28 : 34, style: .continuous))
    }

    private func transportControls(compact: Bool) -> some View {
        HStack(spacing: 0) {
            Button { player.previous() } label: {
                transportIcon(.previous, size: 21)
            }

            Spacer(minLength: 20)

            Button { player.togglePlayPause() } label: {
                MonoIcon(
                    icon: player.isPlaying ? .pause : .play,
                    size: compact ? 22 : 24,
                    color: ClarityStyle.onSelection,
                    lineWidth: 1.8
                )
                .frame(width: compact ? 58 : 64, height: compact ? 58 : 64)
                .background(Circle().fill(ClarityStyle.selection))
                .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
            }

            Spacer(minLength: 20)

            Button { player.next() } label: {
                transportIcon(.next, size: 21)
            }
        }
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity)
        .buttonStyle(ClarityPressStyle())
    }

    private var utilityControls: some View {
        HStack(spacing: 0) {
            utilityButton(
                icon: modeIcon,
                title: player.mode.displayName,
                accessibilityLabel: player.mode.displayName
            ) {
                player.switchMode()
            }

            qualityButton

            utilityButton(
                icon: .musicNoteList,
                title: String(localized: "settings_lyrics"),
                accessibilityLabel: String(localized: "settings_lyrics"),
                action: presentLyrics
            )

            utilityButton(
                icon: .audioWave,
                title: String(localized: "eq_equalizer"),
                accessibilityLabel: String(localized: "mono_audio_center_title")
            ) {
                showsEQ = true
            }

            utilityButton(
                icon: .list,
                title: String(localized: "player_queue"),
                accessibilityLabel: String(localized: "player_queue")
            ) {
                showsQueue = true
            }
        }
    }

    private func lyricStage(song: Song, metrics: ClarityPlayerMetrics) -> some View {
        ZStack {
            // Reuse the single player backdrop underneath. The previous version
            // rendered a second full-screen Canvas and a second 54pt blurred
            // cover while lyrics were open, doubling the most expensive layers.
            LinearGradient(
                colors: [
                    ClarityStyle.base.opacity(0.84),
                    ClarityStyle.base.opacity(0.94),
                    ClarityStyle.base,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings_lyrics"))
                            .font(ClarityStyle.title(20, weight: .semibold))
                            .foregroundStyle(ClarityStyle.ink)
                        Text(song.name)
                            .font(ClarityStyle.body(11.5, weight: .medium))
                            .foregroundStyle(ClarityStyle.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    ClarityCircleButton(icon: .close, size: 42, action: dismissLyrics)
                }
                .padding(.horizontal, 4)

                LyricsView(
                    song: song,
                    onBackgroundTap: nil,
                    adaptivePrimaryColor: ClarityStyle.ink,
                    adaptiveSecondaryColor: ClarityStyle.inkSoft,
                    enforcesAdaptiveContrast: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    ClarityMembrane(
                        shape: RoundedRectangle(cornerRadius: 32, style: .continuous),
                        strength: .strong
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .frame(maxWidth: metrics.maximumContentWidth)
            .padding(.horizontal, metrics.horizontalInset)
            .padding(.vertical, 10)
        }
    }

    private func presentLyrics() {
        guard player.currentSong != nil else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88)) {
            showsLyrics = true
        }
    }

    private func dismissLyrics() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) {
            showsLyrics = false
        }
    }

    private var qualityButton: some View {
        Button { showsQuality = true } label: {
            utilityLabel(icon: .soundQuality, title: player.qualityButtonText)
        }
        .buttonStyle(ClarityPressStyle())
        .playerQualitySelectionAvailability()
        .accessibilityLabel(String(localized: "quality_title"))
    }

    private func utilityButton(
        icon: MonoIcon.IconType,
        title: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            utilityLabel(icon: icon, title: title)
        }
        .buttonStyle(ClarityPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private func utilityLabel(icon: MonoIcon.IconType, title: String) -> some View {
        VStack(spacing: 4) {
            MonoIcon(icon: icon, size: 16, color: ClarityStyle.ink, lineWidth: 1.5)
                .frame(width: 28, height: 25)
            Text(title)
                .font(ClarityStyle.body(8.5, weight: .medium))
                .foregroundStyle(ClarityStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .contentShape(Rectangle())
    }

    private var modeIcon: MonoIcon.IconType {
        switch player.mode {
        case .sequence: return .repeatMode
        case .loopSingle: return .repeatOne
        case .shuffle: return .shuffle
        }
    }

    private func transportIcon(_ icon: MonoIcon.IconType, size: CGFloat) -> some View {
        MonoIcon(icon: icon, size: size, color: ClarityStyle.ink, lineWidth: 1.6)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }

    private var qualitySheet: some View {
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

/// The cover wash is deliberately isolated from the playback clock. A progress
/// tick now invalidates only `ClarityPlaybackProgress`, never this full-screen
/// blur/Canvas subtree.
private struct ClarityPlayerBackdrop: View {
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ClarityBackdrop(context: .player)

                if settings.coverBgPlayer, let cover = player.currentSong?.coverUrl {
                    CachedAsyncImage(
                        // A 54pt blur contains no visible 1200px detail. Decode a
                        // compact source and let the compositor scale the static
                        // texture, reducing decode, upload and memory pressure.
                        url: cover.sized(512),
                        width: 240,
                        height: 240
                    ) {
                        Color.clear
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height * 0.72)
                    .clipped()
                    .blur(radius: 54, opaque: true)
                    .scaleEffect(1.28)
                    .saturation(0.58)
                    .opacity(0.40)
                    .offset(y: -proxy.size.height * 0.16)
                }

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        ClarityStyle.base.opacity(0.22),
                        ClarityStyle.base.opacity(0.86),
                        ClarityStyle.base,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Lyrics advance independently of the rest of the player so line changes do
/// not rebuild the artwork, controls or material surfaces.
private struct ClarityCurrentLyricButton: View {
    @ObservedObject private var lyric = LyricViewModel.shared

    let centered: Bool
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if let line = lyric.currentLineText, !line.isEmpty {
            Button(action: action) {
                HStack(spacing: 6) {
                    Text(line)
                        .lineLimit(1)
                    MonoIcon(icon: .chevronRight, size: 9, color: ClarityStyle.inkFaint, lineWidth: 1.3)
                }
                .font(ClarityStyle.body(10.5, weight: .medium))
                .foregroundStyle(ClarityStyle.inkFaint)
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.top, 1)
            }
            .buttonStyle(ClarityPressStyle())
            .accessibilityLabel(String(localized: "settings_lyrics"))
        }
    }
}

/// High-frequency playback time is scoped to this small leaf view. This keeps
/// the visual quality intact while avoiding a full player body update on every
/// clock publication.
private struct ClarityPlaybackProgress: View {
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var time = PlaybackTimePublisher.shared

    @State private var isSeeking = false
    @State private var seekTime = 0.0

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { proxy in
                let duration = max(time.duration, 0)
                let shown = isSeeking ? seekTime : time.currentTime
                let value = duration > 0 ? min(max(shown / duration, 0), 1) : 0

                ZStack(alignment: .leading) {
                    Capsule().fill(ClarityStyle.line).frame(height: 4)
                    Capsule()
                        .fill(ClarityStyle.accent)
                        .frame(width: max(4, proxy.size.width * value), height: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard duration > 0 else { return }
                            isSeeking = true
                            seekTime = min(max(gesture.location.x / max(proxy.size.width, 1), 0), 1) * duration
                        }
                        .onEnded { _ in
                            guard duration > 0 else {
                                isSeeking = false
                                return
                            }
                            player.seek(to: seekTime)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 18)

            HStack {
                Text(format(isSeeking ? seekTime : time.currentTime))
                Spacer()
                Text("−" + format(max(time.duration - (isSeeking ? seekTime : time.currentTime), 0)))
            }
            .font(ClarityStyle.body(9.5, weight: .medium))
            .foregroundStyle(ClarityStyle.inkFaint)
        }
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

private struct ClarityPlayerMetrics {
    let size: CGSize

    var compact: Bool {
        size.height < 720
    }

    var usesWideLayout: Bool {
        size.width > 680 && size.width > size.height * 0.94
    }

    var horizontalInset: CGFloat {
        size.width > 700 ? 28 : 14
    }

    var maximumContentWidth: CGFloat {
        usesWideLayout ? 920 : 680
    }

    var artworkSize: CGFloat {
        if usesWideLayout {
            return max(210, min(size.height * 0.58, size.width * 0.42, 390))
        }

        let widthBound = min(size.width - horizontalInset * 2 - 48, 330)
        let heightRatio: CGFloat = compact ? 0.31 : 0.38
        return max(190, min(widthBound, size.height * heightRatio))
    }
}
