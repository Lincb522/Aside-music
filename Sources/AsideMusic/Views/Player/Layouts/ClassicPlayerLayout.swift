import SwiftUI
import FFmpegSwiftSDK

/// 经典播放器布局 - 完全还原原始 FullScreenPlayerView 布局，仅增加主题切换按钮
struct ClassicPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
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

    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = true

    private var contentColor: Color { .asideTextPrimary }
    private var secondaryContentColor: Color { .asideTextSecondary }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()

                if showLyrics {
                    Rectangle()
                        .fill(.ultraThinMaterial)
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
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }

                    Spacer()

                    // 底部区域 — spacing: 32 与原始一致
                    VStack(spacing: 32) {
                        if !showLyrics {
                            songInfoView
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            lyricsModeSongInfo
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        progressSection
                            .padding(.vertical, 8)

                        controlsView
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
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
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // 预加载歌词，确保切换到歌词视图时已准备好
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                lyricVM.fetchLyrics(for: song.id)
            }
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentKugouQuality: player.kugouQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { quality in
                    player.switchQuality(quality)
                    showQualitySheet = false
                },
                onSelectKugou: { quality in
                    player.switchKugouQuality(quality)
                    showQualitySheet = false
                },
                onSelectQQ: { quality in
                    player.switchQQMusicQuality(quality)
                    showQualitySheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEQSettings) {
            NavigationStack { EQSettingsView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showThemePicker) {
            PlayerThemePickerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showComments) {
            if let song = player.currentSong {
                CommentView(
                    resourceId: song.id,
                    resourceType: .song,
                    songName: song.name,
                    artistName: song.artistName,
                    coverUrl: song.coverUrl
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - 子视图

    private var headerView: some View {
        HStack {
            AsideBackButton(style: .dismiss, isDarkBackground: false)

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
                        delayBeforeScroll: 2.0
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
                        .fill(contentColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    AsideIcon(icon: .more, size: 20, color: contentColor)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
    }

    /// 封面视图 — 关键：内部 ZStack 带 .frame(maxHeight: .infinity) 让封面撑满中间区域
    private func artworkView(size: CGFloat) -> some View {
        let artSize = min(size, 360)

        return ZStack {
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.gray.opacity(0.2)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: artSize, height: artSize)
                .cornerRadius(24)
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
                        AsideIcon(icon: .musicNoteList, size: 80, color: .gray.opacity(0.3))
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

                Text(player.currentSong?.artistName ?? "Unknown Artist")
                    .font(.rounded(size: 18, weight: .medium))
                    .foregroundColor(secondaryContentColor)
                    .lineLimit(1)
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

            if let songId = player.currentSong?.id {
                LikeButton(songId: songId, size: 26, activeColor: .red, inactiveColor: contentColor)
            } else {
                AsideIcon(icon: .like, size: 26, color: contentColor)
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
                Text(player.currentSong?.artistName ?? "")
                    .font(.rounded(size: 14, weight: .medium))
                    .foregroundColor(secondaryContentColor)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { withAnimation { enableKaraoke.toggle() } }) {
                AsideIcon(icon: .karaoke, size: 20, color: enableKaraoke ? contentColor : secondaryContentColor.opacity(0.3))
                    .padding(8)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }

            Button(action: { withAnimation { showTranslation.toggle() } }) {
                AsideIcon(icon: .translate, size: 20, color: showTranslation ? contentColor : secondaryContentColor.opacity(0.3))
                    .padding(8)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }

            if let songId = player.currentSong?.id {
                LikeButton(songId: songId, size: 22, activeColor: .red, inactiveColor: contentColor)
                    .padding(8)
                    .background(contentColor.opacity(0.05))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 4)
    }

    /// 进度条区域 — 与原始完全一致，使用波形进度条
    private var progressSection: some View {
        VStack(spacing: 6) {
            FullScreenPlayerView.WaveformProgressBar(
                currentTime: Binding(
                    get: { isDraggingSlider ? dragTimeValue : player.currentTime },
                    set: { _ in }
                ),
                duration: player.duration,
                color: contentColor,
                isAnimating: player.isPlaying,
                chorusStart: player.chorusStartTime,
                chorusEnd: player.chorusEndTime,
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
                Text(formatTime(isDraggingSlider ? dragTimeValue : player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.rounded(size: 11, weight: .medium))
            .foregroundColor(secondaryContentColor)
            .monospacedDigit()
        }
        .padding(.horizontal, 24)
    }

    /// 控制按钮 — 与原始完全一致
    private var controlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    AsideIcon(icon: player.mode.asideIcon, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
                .frame(width: 44)

                Spacer()

                Button(action: { player.previous() }) {
                    AsideIcon(icon: .previous, size: 32, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())

                Spacer()

                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.asideIconBackground)
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.asideIconForeground))
                                .scaleEffect(1.2)
                        } else {
                            AsideIcon(icon: player.isPlaying ? .pause : .play, size: 32, color: .asideIconForeground)
                        }
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))

                Spacer()

                Button(action: { player.next() }) {
                    AsideIcon(icon: .next, size: 32, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())

                Spacer()

                Button(action: { showPlaylist = true }) {
                    AsideIcon(icon: .list, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
                .frame(width: 44)
            }

            // 评论 + 下载
            if let song = player.currentSong {
                HStack(spacing: 0) {
                    Button { showComments = true } label: {
                        AsideIcon(icon: .comment, size: 22, color: secondaryContentColor, lineWidth: 1.4)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .frame(width: 44)

                    Spacer()

                    Button {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            if song.isQQMusic {
                                downloadManager.downloadQQ(song: song, quality: player.qqMusicQuality)
                            } else {
                                downloadManager.download(song: song, quality: player.soundQuality)
                            }
                        }
                    } label: {
                        AsideIcon(
                            icon: .playerDownload,
                            size: 22,
                            color: downloadManager.isDownloaded(songId: song.id) ? .asideTextSecondary : secondaryContentColor,
                            lineWidth: 1.4
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
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
