import SwiftUI
import FFmpegSwiftSDK

/// Paw 播放器 — 黏土玩具语言：
/// 大封面像一块厚黏土浮在桌面上（播放/暂停呼吸缩放），
/// 按钮是能「按下去」的糖果色黏土块，进度条使用全局音纹组件的暖橙配色。
struct PawcelainPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var likeManager = LikeManager.shared

    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var showLyrics = false
    @State private var showMoreMenu = false
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false

    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("enableKaraoke") private var enableKaraoke: Bool = false

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            PetWhiteRootBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, DeviceLayout.headerTopPadding)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                if showLyrics {
                    lyricsStage
                        .padding(.horizontal, DeviceLayout.playerHorizontalPadding)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .center)))
                } else {
                    coverStage
                        .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .center)))
                }

                songInfoSection
                    .padding(.horizontal, DeviceLayout.playerHorizontalPadding + 6)
                    .padding(.top, showLyrics ? 14 : 0)

                Spacer(minLength: 10)

                progressSection
                    .padding(.horizontal, DeviceLayout.playerHorizontalPadding + 4)

                PlayerControlsBar(
                    contentColor: usesIllustratedBackground ? illustratedPrimaryText : PetWhiteStyle.ink,
                    secondaryColor: usesIllustratedBackground ? illustratedSecondaryText : PetWhiteStyle.inkSoft,
                    showSecondaryRow: true,
                    onShowPlaylist: { showPlaylist = true },
                    onShowComments: { showComments = true },
                    onShowEQ: { showEQSettings = true }
                )
                .padding(.horizontal, usesIllustratedBackground ? 14 : DeviceLayout.playerHorizontalPadding)
                .padding(.vertical, usesIllustratedBackground ? 10 : 0)
                .background {
                    playerReadabilityBackground(cornerRadius: PetWhiteStyle.cardRadius, opacity: 0.64)
                }
                .padding(.horizontal, usesIllustratedBackground ? DeviceLayout.playerHorizontalPadding : 0)
                .padding(.top, 16)

                Spacer(minLength: 0)
                    .frame(height: pawPlayerBottomPadding)
            }

            if showMoreMenu {
                PlayerMoreMenu(
                    isPresented: $showMoreMenu,
                    isDarkBackground: false,
                    onQuality: { showQualitySheet = true },
                    onEQ: { showEQSettings = true },
                    onTheme: { showThemePicker = true }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .monologueEdgeSwipeToDismiss()
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            PlaylistPopupView()
        }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact) {
            if let song = player.currentSong {
                SoundQualitySheet(
                    currentQuality: player.soundQuality,
                    currentQQQuality: player.qqMusicQuality,
                    isQQMusic: song.isQQMusic,
                    onSelectNetease: { quality in
                        player.switchQuality(quality)
                        showQualitySheet = false
                    },
                    onSelectQQ: { quality in
                        player.switchQQMusicQuality(quality)
                        showQualitySheet = false
                    },
                    songMid: song.qqMid,
                    songId: song.id,
                    isQishui: song.isQishui == true,
                    qishuiTrackId: song.qishuiTrackId,
                    onSelectQishui: { info in
                        player.switchQishuiQuality(info)
                        showQualitySheet = false
                    }
                )
            }
        }
        .monologueSheet(isPresented: $showEQSettings, preset: .large) {
            NavigationStack { EQSettingsView() }
        }
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
        .monologueSheet(isPresented: $showComments, preset: .large) {
            if let song = player.currentSong {
                CommentView(
                    resourceId: song.id,
                    resourceType: .song,
                    songName: song.name,
                    artistName: song.artistName,
                    coverUrl: song.coverUrl
                )
            }
        }
        .monologueSheet(isPresented: $showArtistDetail, preset: .detail) {
            if let song = player.currentSong {
                NavigationStack {
                    if song.isQQMusic, let mid = song.qqArtistMid {
                        QQMusicDetailView(detailType: .artist(mid: mid, name: song.artistName, coverUrl: nil))
                    } else if let artistId = song.ar?.first?.id {
                        ArtistDetailView(artistId: artistId)
                    }
                }
            }
        }
        .monologueSheet(isPresented: $showDownloadSheet, preset: .compact) {
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }
            }
        }
        .monologueSheet(isPresented: $likeManager.showPlaylistPicker, preset: .standard) {
            if let pendingSong = likeManager.pendingLikeSong {
                AddToPlaylistSheet(song: pendingSong)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            MonologueBackButton(style: .dismiss, isDarkBackground: false)

            Spacer(minLength: 8)

            Text(LocalizedStringKey("player_now_playing"))
                .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(usesIllustratedBackground ? illustratedSecondaryText : PetWhiteStyle.dogEar)
                .lineLimit(1)
                .padding(.horizontal, usesIllustratedBackground ? 10 : 0)
                .padding(.vertical, usesIllustratedBackground ? 5 : 0)
                .background {
                    playerReadabilityBackground(cornerRadius: 12, opacity: 0.6)
                }

            Spacer(minLength: 8)

            headerIconButton(icon: .more, isActive: showMoreMenu) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                    showMoreMenu.toggle()
                }
            }
        }
    }

    private func headerIconButton(
        icon: MonologueIcon.IconType,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            PetWhiteClayPuck(
                shape: Circle(),
                tint: isActive ? PetWhiteStyle.butter : PetWhiteStyle.surfaceRaised.opacity(usesIllustratedBackground ? 0.85 : 1),
                pressedLook: isActive
            )
            .frame(width: 38, height: 38)
            .overlay(
                PetWhitePackIcon(
                    icon: icon,
                    size: 19,
                    visualScale: 1,
                    fallbackColor: PetWhiteStyle.ink,
                    lineWidth: 1.8
                )
            )
        }
        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.88))
    }

    // MARK: - Cover stage

    private var coverStage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(PetWhiteStyle.surfaceRaised)

                if let song = player.currentSong {
                    CachedAsyncImage(url: song.coverUrl?.sized(800)) {
                        PetWhiteMascotMark(kind: .pair, size: coverSide * 0.34)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSide, height: coverSide)
                    .clipped()
                } else {
                    PetWhiteMascotMark(kind: .pair, size: coverSide * 0.38)
                }
            }
            .frame(width: coverSide, height: coverSide)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                // 黏土受光面：顶部柔白反光，让封面像嵌进黏土块里
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PetWhiteStyle.glazeHighlight.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
            // 新拟物双向阴影：黏土封面从桌面「挤」出来，播放时挤得更高
            .shadow(
                color: PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.05 : 0.95),
                radius: player.isPlaying ? 16 : 10,
                x: player.isPlaying ? -11 : -7,
                y: player.isPlaying ? -11 : -7
            )
            .shadow(
                color: PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.6 : (player.isPlaying ? 0.65 : 0.42)),
                radius: player.isPlaying ? 24 : 13,
                x: player.isPlaying ? 13 : 8,
                y: player.isPlaying ? 17 : 10
            )
            .scaleEffect(player.isPlaying ? 1 : 0.92)
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: player.isPlaying)
            .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .onTapGesture {
                toggleLyrics()
            }

            Spacer(minLength: 18)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lyrics stage

    private var lyricsStage: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let song = player.currentSong {
                    LyricsView(song: song, onBackgroundTap: {
                        toggleLyrics()
                    })
                } else {
                    VStack(spacing: 12) {
                        PetWhiteMascotMark(kind: .pair, size: 96)
                        Text(String(localized: "暂无播放内容"))
                            .font(PetWhiteStyle.titleFont(20, weight: .bold))
                            .foregroundStyle(PetWhiteStyle.ink)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.top, 6)

            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        enableKaraoke.toggle()
                    }
                } label: {
                    lyricsOptionLabel(
                        icon: .karaoke,
                        text: String(localized: "逐字"),
                        isActive: enableKaraoke,
                        tint: PetWhiteStyle.sky
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        showTranslation.toggle()
                    }
                } label: {
                    lyricsOptionLabel(
                        icon: .translate,
                        text: String(localized: "翻译"),
                        isActive: showTranslation,
                        tint: PetWhiteStyle.mint
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 10)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: PetWhiteStyle.cardRadius,
                elevated: false,
                tint: usesIllustratedBackground
                    ? PetWhiteStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.9 : 0.86)
                    : PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.butter
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous))
    }

    // MARK: - Song info

    private var songInfoSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(player.currentSong?.name ?? String(localized: "暂无播放内容"))
                    .monologuePlayerDisplayFont(
                        size: 23,
                        weight: .bold,
                        fallback: PetWhiteStyle.titleFont(23, weight: .bold)
                    )
                    .foregroundStyle(usesIllustratedBackground ? illustratedPrimaryText : PetWhiteStyle.ink)
                    .lineLimit(showLyrics ? 1 : 2)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)

                Button {
                    showArtistDetail = true
                } label: {
                    Text(player.currentSong?.artistName ?? String(localized: "先挑一首歌吧"))
                        .font(PetWhiteStyle.bodyFont(14))
                        .foregroundStyle(usesIllustratedBackground ? illustratedSecondaryText : PetWhiteStyle.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.plain)

                if !showLyrics {
                    HStack(spacing: 8) {
                        Button {
                            showQualitySheet = true
                        } label: {
                            HStack(spacing: 4) {
                                PetWhitePackIcon(icon: .soundQuality, size: 11, visualScale: 1, fallbackColor: PetWhiteStyle.dogEar, lineWidth: 1.5)
                                Text(player.qualityButtonText)
                                    .font(PetWhiteStyle.labelFont(10, weight: .semibold))
                            }
                            .foregroundStyle(PetWhiteStyle.dogEar)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(PetWhiteClayPuck(shape: Capsule(), tint: PetWhiteStyle.butter))
                        }
                        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.9))
                        .playerQualitySelectionAvailability()

                        if let info = player.streamInfo {
                            Text(streamInfoText(info))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(usesIllustratedBackground ? illustratedSecondaryText.opacity(0.85) : PetWhiteStyle.inkMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .padding(.top, 3)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            if let song = player.currentSong {
                pawLikeButton(song: song)
            }
        }
        .padding(.horizontal, usesIllustratedBackground ? 14 : 0)
        .padding(.vertical, usesIllustratedBackground ? 10 : 0)
        .background {
            playerReadabilityBackground(cornerRadius: PetWhiteStyle.cardRadius, opacity: 0.72)
        }
    }

    private func pawLikeButton(song: Song) -> some View {
        let isLiked = likeManager.isLiked(id: song.id, isQQMusic: song.isQQMusic)

        return Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            likeManager.toggleLike(songId: song.id, isQQMusic: song.isQQMusic, song: song)
        } label: {
            PetWhiteClayPuck(
                shape: Circle(),
                tint: isLiked ? PetWhiteStyle.blush : PetWhiteStyle.surfaceRaised,
                pressedLook: isLiked
            )
            .frame(width: 44, height: 44)
            .overlay(
                PetWhitePackIcon(
                    icon: isLiked ? .liked : .like,
                    size: 20,
                    visualScale: 1.04,
                    fallbackColor: PetWhiteStyle.ink,
                    lineWidth: 1.8
                )
                .scaleEffect(isLiked ? 1.06 : 1)
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isLiked)
        }
        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.85))
    }

    // MARK: - Progress

    private var progressSection: some View {
        let duration = timePublisher.duration
        let current = isDraggingSlider ? dragTimeValue : timePublisher.currentTime
        let progress = duration > 0 ? CGFloat(min(max(current / duration, 0), 1)) : 0

        return VStack(spacing: 7) {
            GlobalWaveformPlaybackProgressBar(
                progress: progress,
                isPlaying: player.isPlaying && !isDraggingSlider,
                color: usesIllustratedBackground ? illustratedPrimaryText : PetWhiteStyle.ink,
                trackOpacity: usesIllustratedBackground ? 0.22 : 0.15,
                fillColors: [PetWhiteStyle.dogOrange.opacity(0.85), PetWhiteStyle.dogEar],
                onSeek: { p in
                    isDraggingSlider = true
                    dragTimeValue = Double(p) * duration
                },
                onCommit: { p in
                    isDraggingSlider = false
                    player.seek(to: Double(p) * duration)
                }
            )
            .frame(height: 34)

            HStack {
                Text(formatPlayerTime(current))
                Spacer()
                Text(formatPlayerTime(duration))
            }
            .font(PetWhiteStyle.labelFont(10, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(usesIllustratedBackground ? illustratedSecondaryText : PetWhiteStyle.inkMuted)
        }
        .padding(.horizontal, usesIllustratedBackground ? 12 : 0)
        .padding(.vertical, usesIllustratedBackground ? 9 : 0)
        .background {
            playerReadabilityBackground(cornerRadius: PetWhiteStyle.compactRadius + 3, opacity: 0.62)
        }
    }

    // MARK: - Layout metrics

    private var coverSide: CGFloat {
        if DeviceLayout.isPad {
            return min(430, DeviceLayout.screenHeight * 0.4)
        }
        let widthBound = DeviceLayout.screenWidth - DeviceLayout.playerHorizontalPadding * 2 - 12
        let heightBound = DeviceLayout.screenHeight * 0.4
        return min(widthBound, heightBound)
    }

    private var pawPlayerBottomPadding: CGFloat {
        max(DeviceLayout.safeAreaBottom + 8, 22)
    }

    private var usesIllustratedBackground: Bool {
        settings.petWhiteUsesIllustratedBackground
    }

    private var illustratedPrimaryText: Color {
        colorScheme == .dark ? Color.white : PetWhiteStyle.ink
    }

    private var illustratedSecondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.76) : PetWhiteStyle.ink.opacity(0.78)
    }

    @ViewBuilder
    private func playerReadabilityBackground(cornerRadius: CGFloat, opacity: Double) -> some View {
        if usesIllustratedBackground {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill((colorScheme == .dark ? Color.black : PetWhiteStyle.surfaceRaised).opacity(opacity))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke((colorScheme == .dark ? Color.white : PetWhiteStyle.stroke).opacity(colorScheme == .dark ? 0.28 : 0.9), lineWidth: 1)
                )
                .shadow(color: PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 12, x: 0, y: 6)
        }
    }

    private func toggleLyrics() {
        guard player.currentSong != nil else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            showLyrics.toggle()
        }
    }

    private func lyricsOptionLabel(
        icon: MonologueIcon.IconType,
        text: String,
        isActive: Bool,
        tint: Color
    ) -> some View {
        HStack(spacing: 5) {
            lyricsToggleIcon(icon: icon, isActive: isActive)
            Text(text)
                .font(PetWhiteStyle.labelFont(10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(PetWhiteStyle.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            PetWhiteClayPuck(
                shape: Capsule(style: .continuous),
                tint: isActive ? tint : PetWhiteStyle.surfaceRaised.opacity(0.92),
                pressedLook: isActive
            )
        )
    }

    @ViewBuilder
    private func lyricsToggleIcon(icon: MonologueIcon.IconType, isActive: Bool) -> some View {
        if isActive, let assetName = selectedLyricsToggleAssetName(for: icon) {
            PetWhiteSelectedLyricToggleIcon(assetName: assetName, size: selectedLyricsToggleIconSize(for: icon))
        } else {
            PetWhitePackIcon(icon: icon, size: 13, visualScale: 1.04, lineWidth: 1.8)
        }
    }

    private func selectedLyricsToggleIconSize(for icon: MonologueIcon.IconType) -> CGFloat {
        switch icon {
        case .karaoke:
            return 21
        case .translate:
            return 20
        default:
            return 13
        }
    }

    private func selectedLyricsToggleAssetName(for icon: MonologueIcon.IconType) -> String? {
        switch icon {
        case .karaoke:
            return "karaokeSelected"
        case .translate:
            return "translateSelected"
        default:
            return nil
        }
    }

    private func formatPlayerTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(max(seconds, 0))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec {
            parts.append(codec.uppercased())
        }
        if let sampleRate = info.sampleRate {
            if sampleRate >= 1000 {
                let kilohertz = Double(sampleRate) / 1000.0
                parts.append(kilohertz == kilohertz.rounded() ? "\(Int(kilohertz))kHz" : String(format: "%.1fkHz", kilohertz))
            } else {
                parts.append("\(sampleRate)Hz")
            }
        }
        if let bitDepth = info.bitDepth, bitDepth > 0 {
            parts.append("\(bitDepth)bit")
        }
        if let channelCount = info.channelCount, channelCount > 2 {
            parts.append("\(channelCount)ch")
        }
        return parts.joined(separator: " / ")
    }
}
