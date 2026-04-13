import SwiftUI
import FFmpegSwiftSDK

/// 经典播放器布局 - 完全还原原始 FullScreenPlayerView 布局，仅增加主题切换按钮
struct ClassicPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showLyrics = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false

    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = false

    private var contentColor: Color { .monologueTextPrimary }
    private var secondaryContentColor: Color { .monologueTextSecondary }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showLyrics {
                    Rectangle()
                        .fill(Color.monologueGlassTint)
                        .monologueGlass(cornerRadius: 16)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    headerView
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.bottom, 20)

                    ZStack {
                        artworkView(size: geometry.size.width - 64)
                            .opacity(showLyrics ? 0 : 1)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                            .gesture(
                                DragGesture()
                                    .onEnded { value in
                                        if value.translation.height > 100 { dismiss() }
                                    }
                            )

                        if let song = player.currentSong {
                            LyricsView(song: song, onBackgroundTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showLyrics.toggle()
                                }
                            })
                            .opacity(showLyrics ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }

                    Spacer()

                    // 底部区域 — spacing: 32 与原始一致
                    VStack(spacing: 32) {
                        ZStack(alignment: .leading) {
                            // 用 songInfoView 撑高度，保证切换歌词时不跳动
                            songInfoView.opacity(showLyrics ? 0 : 1)
                            lyricsModeSongInfo.opacity(showLyrics ? 1 : 0)
                        }
                        .animation(.easeInOut(duration: 0.25), value: showLyrics)

                        progressSection
                            .padding(.vertical, 8)

                        controlsView
                    }
                    .padding(.horizontal, DeviceLayout.playerHorizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, DeviceLayout.playerBottomSafePadding)
                }

                // 三点菜单浮层
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
        .onAppear { }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact){
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { quality in
                    player.switchQuality(quality)
                    showQualitySheet = false
                },
                onSelectQQ: { quality in
                    player.switchQQMusicQuality(quality)
                    showQualitySheet = false
                },
                songMid: player.currentSong?.qqMid,
                songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in player.switchQishuiQuality(info); showQualitySheet = false }
            )

        }
        .monologueSheet(isPresented: $showEQSettings, preset: .large){
            NavigationStack { EQSettingsView() }

        }
        .monologueSheet(isPresented: $showThemePicker, preset: .compact){
            PlayerThemePickerSheet()

        }
        .monologueSheet(isPresented: $showComments, preset: .large){
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
        .monologueSheet(isPresented: $showArtistDetail, preset: .detail){
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
        .monologueSheet(isPresented: $showDownloadSheet, preset: .compact){
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }

            }
        }
    }

    // MARK: - 子视图

    private var headerView: some View {
        HStack {
            MonologueBackButton(style: .dismiss, isDarkBackground: false)
                .contentShape(Circle())

            Spacer()

            VStack(spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.rounded(size: 12, weight: .medium))
                    .foregroundColor(secondaryContentColor)
                    .tracking(1)

                if let name = player.currentSong?.name {
                    MarqueeText(
                        text: name,
                        font: .rounded(size: 13, weight: .semibold),
                        color: secondaryContentColor,
                        speed: 30,
                        delayBeforeScroll: 2.0,
                        alignment: .center
                    )
                    .frame(maxWidth: 180)
                }

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryContentColor.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 三点菜单按钮
            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() } }) {
                ZStack {
                    Circle()
                        .fill(Color.monologueGlassTint)
                        .frame(width: 44, height: 44)
                        .monologueGlassCircle()
                    MonologueIcon(icon: .more, size: 22, color: contentColor)
                }
                .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    /// 封面视图 — 关键：内部 ZStack 带 .frame(maxHeight: .infinity) 让封面撑满中间区域
    private func artworkView(size: CGFloat) -> some View {
        let artSize = min(size, DeviceLayout.playerArtworkMaxSize)

        return ZStack {
            if let song = player.currentSong {
                ZStack {
                    CachedAsyncImage(url: song.coverUrl?.sized(800)) {
                        Color.gray.opacity(0.2)
                    }
                    .aspectRatio(contentMode: .fill)
                    
                    if let dynamicUrl = player.dynamicCoverUrl, !dynamicUrl.isEmpty {
                        DynamicCoverView(urlString: dynamicUrl, cornerRadius: 24)
                    }
                }
                .frame(width: artSize, height: artSize)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .monologueBackgroundExtension()
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: artSize, height: artSize)
                    .overlay(
                        MonologueIcon(icon: .musicNoteList, size: 80, color: .gray.opacity(0.3))
                    )
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var songInfoView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .font(.rounded(size: 26, weight: .bold))
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(.rounded(size: 18, weight: .medium))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(contentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(contentColor.opacity(0.5), lineWidth: 1)
                    )
            }

            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 26, activeColor: .red, inactiveColor: contentColor)
            } else {
                MonologueIcon(icon: .like, size: 26, color: contentColor)
            }
        }
    }

    private var lyricsModeSongInfo: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.name ?? "")
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "")
                        .font(.rounded(size: 14, weight: .medium))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: { withAnimation { enableKaraoke.toggle() } }) {
                MonologueIcon(icon: .karaoke, size: 20, color: enableKaraoke ? contentColor : secondaryContentColor.opacity(0.3))
                    .padding(8)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }

            Button(action: { withAnimation { showTranslation.toggle() } }) {
                MonologueIcon(icon: .translate, size: 20, color: showTranslation ? contentColor : secondaryContentColor.opacity(0.3))
                    .padding(8)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }

            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 22, activeColor: .red, inactiveColor: contentColor)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 4)
    }

    /// 进度条区域 — 柔和融入背景的波形进度条
    private var progressSection: some View {
        VStack(spacing: 6) {
            FullScreenPlayerView.WaveformProgressBar(
                currentTime: Binding(
                    get: { isDraggingSlider ? dragTimeValue : timePublisher.currentTime },
                    set: { _ in }
                ),
                duration: timePublisher.duration,
                color: contentColor.opacity(0.7),
                trackOpacity: 0.1,
                isAnimating: player.isPlaying,
                onSeek: { time in
                    isDraggingSlider = true
                    dragTimeValue = time
                },
                onCommit: { time in
                    isDraggingSlider = false
                    player.seek(to: time)
                }
            )
            .frame(height: 20)

            HStack {
                Text(formatTime(isDraggingSlider ? dragTimeValue : timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.rounded(size: 11, weight: .medium))
            .foregroundColor(secondaryContentColor.opacity(0.6))
            .monospacedDigit()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    /// 控制按钮 — 与原始完全一致
    private var controlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .frame(width: 44)

                Spacer()

                Button(action: { player.previous() }) {
                    MonologueIcon(icon: .previous, size: 32, color: contentColor)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.monologueGlassTint)
                            .frame(width: DeviceLayout.playerPlayButtonSize, height: DeviceLayout.playerPlayButtonSize)
                            .monologueGlassCircle()

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.monologueTextPrimary))
                                .scaleEffect(1.2)
                        } else {
                            MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 32, color: .monologueTextPrimary)
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))

                Spacer()

                Button(action: { player.next() }) {
                    MonologueIcon(icon: .next, size: 32, color: contentColor)
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                Spacer()

                Button(action: { showPlaylist = true }) {
                    MonologueIcon(icon: .list, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .frame(width: 44)
            }

            // 评论 + 下载
            if let song = player.currentSong {
                HStack(spacing: 0) {
                    Button { showComments = true } label: {
                        MonologueIcon(icon: .comment, size: 22, color: secondaryContentColor, lineWidth: 1.4)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .frame(width: 44)

                    Spacer()

                    Button {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            showDownloadSheet = true
                        }
                    } label: {
                        MonologueIcon(
                            icon: .playerDownload,
                            size: 22,
                            color: downloadManager.isDownloaded(songId: song.id) ? .monologueTextSecondary : secondaryContentColor,
                            lineWidth: 1.4
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .disabled(downloadManager.isDownloaded(songId: song.id))
                    .frame(width: 44)
                }
            }
        }
    }

    // MARK: - 辅助方法

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let khz = Double(sr) / 1000.0
                parts.append(khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz))
            } else { parts.append("\(sr)Hz") }
        }
        if let bd = info.bitDepth, bd > 0 { parts.append("\(bd)bit") }
        if let ch = info.channelCount, ch > 2 { parts.append("\(ch)ch") }
        return parts.joined(separator: " / ")
    }
}
