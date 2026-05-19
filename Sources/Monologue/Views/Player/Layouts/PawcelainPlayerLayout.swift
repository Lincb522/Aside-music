import SwiftUI
import FFmpegSwiftSDK

struct PawcelainPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var settings = SettingsManager.shared

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
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        stageCard
                            .padding(.horizontal, DeviceLayout.playerHorizontalPadding)

                        songMetaCard
                            .padding(.horizontal, DeviceLayout.playerHorizontalPadding)

                        PlayerProgressSection(
                            isDragging: $isDraggingSlider,
                            dragValue: $dragTimeValue,
                            contentColor: PetWhiteStyle.ink,
                            secondaryColor: PetWhiteStyle.inkSoft,
                            useWaveform: true
                        )
                        .padding(.horizontal, DeviceLayout.playerHorizontalPadding)

                        PlayerControlsBar(
                            contentColor: PetWhiteStyle.ink,
                            secondaryColor: PetWhiteStyle.inkSoft,
                            onShowPlaylist: { showPlaylist = true },
                            onShowComments: { showComments = true },
                            onShowEQ: { showEQSettings = true }
                        )
                        .padding(.horizontal, DeviceLayout.playerHorizontalPadding)

                        Spacer(minLength: 6)
                    }
                    .padding(.bottom, DeviceLayout.playerBottomSafePadding + 12)
                }
                .themeRenderScrollLayer()
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
                    isUnblocked: player.isCurrentSongUnblocked,
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
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            MonologueBackButton(style: .dismiss, isDarkBackground: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(PetWhiteStyle.labelFont(11, weight: .black))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .tracking(1)

                Text(player.currentSong?.name ?? String(localized: "暂无播放内容"))
                    .font(PetWhiteStyle.bodyFont(13, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PetWhiteStyle.inkSoft.opacity(0.72))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            headerIconButton(
                icon: showLyrics ? .musicNote : .karaoke,
                tint: showLyrics ? PetWhiteStyle.butter : PetWhiteStyle.sky,
                isActive: showLyrics
            ) {
                toggleLyrics()
            }

            headerIconButton(icon: .more, tint: PetWhiteStyle.mint, isActive: showMoreMenu) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                    showMoreMenu.toggle()
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    @ViewBuilder
    private var stageCard: some View {
        if showLyrics {
            lyricsCard
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        } else {
            coverCard
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var coverCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(PetWhiteStyle.surfaceRaised)
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)

                if let song = player.currentSong {
                    CachedAsyncImage(url: song.coverUrl?.sized(800)) {
                        PetWhiteMascotMark(kind: .pair, size: 90)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                } else {
                    PetWhiteMascotMark(kind: .pair, size: 108)
                }
            }
            .frame(height: min(geometryAwareCoverHeight, 420))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .onTapGesture {
                if player.currentSong != nil {
                    toggleLyrics()
                }
            }

            HStack(spacing: 12) {
                PetWhiteIconBadge(icon: .musicNoteList, tint: PetWhiteStyle.butter, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(player.currentSong?.name ?? String(localized: "暂无播放内容"))
                        .font(PetWhiteStyle.titleFont(22, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Button {
                        showArtistDetail = true
                    } label: {
                        Text(player.currentSong?.artistName ?? String(localized: "先挑一首歌吧"))
                            .font(PetWhiteStyle.bodyFont(14, weight: .semibold))
                            .foregroundStyle(PetWhiteStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 8)

                Button {
                    showQualitySheet = true
                } label: {
                    HStack(spacing: 5) {
                        PetWhitePackIcon(icon: .soundQuality, size: 14, visualScale: 1.04)
                        Text(player.qualityButtonText)
                            .font(PetWhiteStyle.labelFont(11, weight: .black))
                    }
                    .foregroundStyle(PetWhiteStyle.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PetWhiteStyle.mint, in: Capsule())
                    .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .background(PetWhiteSurfaceBackground(cornerRadius: 34, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
    }

    private var lyricsCard: some View {
        ZStack(alignment: .top) {
            if let song = player.currentSong {
                LyricsView(song: song, onBackgroundTap: {
                    toggleLyrics()
                })
                .padding(.top, 10)
            } else {
                VStack(spacing: 12) {
                    PetWhiteMascotMark(kind: .pair, size: 96)
                    Text(String(localized: "暂无播放内容"))
                        .font(PetWhiteStyle.titleFont(20, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                    Text(String(localized: "先挑一首歌吧"))
                        .font(PetWhiteStyle.bodyFont(13, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 8) {
                PetWhitePill(text: String(localized: "歌词"), tint: PetWhiteStyle.butter)

                Spacer()

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
            .padding(12)
        }
        .frame(height: min(geometryAwareCoverHeight, 420))
        .background(PetWhiteSurfaceBackground(cornerRadius: 34, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.butter))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(PetWhiteStyle.stroke, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var songMetaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PetWhitePill(text: player.mode.displayName.uppercased(), tint: PetWhiteStyle.sky)

                if player.isPlayingPodcast {
                    PetWhitePill(text: String(localized: "podcast"), tint: PetWhiteStyle.butter)
                }

                if player.currentSong?.isQQMusic == true {
                    PetWhitePill(text: "QQ", tint: PetWhiteStyle.blush.opacity(0.72))
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                playerActionButton(
                    icon: showLyrics ? .musicNote : .karaoke,
                    title: showLyrics ? String(localized: "封面") : String(localized: "歌词"),
                    tint: showLyrics ? PetWhiteStyle.butter : PetWhiteStyle.sky,
                    isActive: showLyrics
                ) {
                    toggleLyrics()
                }

                playerActionButton(
                    icon: .soundQuality,
                    title: player.qualityButtonText,
                    tint: PetWhiteStyle.mint,
                    isActive: false
                ) {
                    showQualitySheet = true
                }

                playerActionButton(
                    icon: .translate,
                    title: String(localized: "翻译"),
                    tint: PetWhiteStyle.blush.opacity(0.76),
                    isActive: showTranslation
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showTranslation.toggle()
                    }
                }
            }
        }
        .padding(14)
        .background(PetWhiteSurfaceBackground(cornerRadius: 24, elevated: false, tint: PetWhiteStyle.surfacePressed, accent: PetWhiteStyle.sky))
    }

    private var geometryAwareCoverHeight: CGFloat {
        DeviceLayout.isPad ? 420 : 320
    }

    private func toggleLyrics() {
        guard player.currentSong != nil else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            showLyrics.toggle()
        }
    }

    private func headerIconButton(
        icon: MonologueIcon.IconType,
        tint: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isActive ? tint : PetWhiteStyle.surfaceRaised)
                .frame(width: 42, height: 42)
                .overlay(
                    PetWhitePackIcon(
                        icon: icon,
                        size: 22,
                        visualScale: icon == .more ? 0.98 : 1.06,
                        fallbackColor: PetWhiteStyle.stroke,
                        lineWidth: 2
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
    }

    private func playerActionButton(
        icon: MonologueIcon.IconType,
        title: String,
        tint: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                PetWhitePackIcon(icon: icon, size: 15, visualScale: 1.04, lineWidth: 1.9)
                Text(title)
                    .font(PetWhiteStyle.labelFont(11, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .foregroundStyle(PetWhiteStyle.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isActive ? tint : PetWhiteStyle.surfaceRaised, in: Capsule())
            .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }

    private func lyricsOptionLabel(
        icon: MonologueIcon.IconType,
        text: String,
        isActive: Bool,
        tint: Color
    ) -> some View {
        HStack(spacing: 5) {
            PetWhitePackIcon(icon: icon, size: 13, visualScale: 1.04, lineWidth: 1.8)
            Text(text)
                .font(PetWhiteStyle.labelFont(10, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(PetWhiteStyle.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(isActive ? tint : PetWhiteStyle.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: 1))
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
