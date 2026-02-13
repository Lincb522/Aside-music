import SwiftUI
import FFmpegSwiftSDK

struct FullScreenPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared

    @State private var isDraggingSlider = false
    @State private var dragTimeValue: Double = 0
    @State private var showPlaylist = false
    @State private var showActionSheet = false
    @State private var showQualitySheet = false
    @State private var showLyrics = false
    @State private var showImmersivePlayer = false
    @State private var showComments = false

    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = true

    private let spacing: CGFloat = 24

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
                                        if value.translation.height > 100 {
                                            dismiss()
                                        }
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

                    VStack(spacing: 32) {
                        if !showLyrics {
                            songInfoView
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
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

                                Button(action: {
                                    withAnimation { enableKaraoke.toggle() }
                                }) {
                                    AsideIcon(icon: .karaoke, size: 20, color: enableKaraoke ? contentColor : secondaryContentColor.opacity(0.3))
                                        .padding(8)
                                        .background(contentColor.opacity(0.05))
                                        .clipShape(Circle())
                                }

                                Button(action: {
                                    withAnimation { showTranslation.toggle() }
                                }) {
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
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        progressSection
                            .padding(.vertical, 8)

                        controlsView
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                player.isTabBarHidden = true
            }
        }
        .onDisappear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    player.isTabBarHidden = false
                }
            }
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentKugouQuality: player.kugouQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                onSelectNetease: { quality in
                    player.switchQuality(quality)
                    showQualitySheet = false
                },
                onSelectKugou: { quality in
                    player.switchKugouQuality(quality)
                    showQualitySheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("更多操作", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("沉浸模式") { showImmersivePlayer = true }
            Button("查看评论") { showComments = true }
            Button("取消", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showImmersivePlayer) {
            ImmersivePlayerView()
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

    // MARK: - Subviews

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
                    Text(name)
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryContentColor.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: {
                showActionSheet = true
            }) {
                AsideIcon(icon: .more, size: 20, color: contentColor)
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .frame(width: 44, height: 44)
            .background(contentColor.opacity(0.1))
            .clipShape(Circle())
        }
        .padding(.horizontal, 24)
    }

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

            VStack(spacing: 2) {
                Button(action: {
                    showQualitySheet = true
                }) {
                    Text(player.soundQuality.buttonText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(contentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(contentColor.opacity(0.5), lineWidth: 1)
                        )
                }
            }

            if let songId = player.currentSong?.id {
                LikeButton(songId: songId, size: 26, activeColor: .red, inactiveColor: contentColor)
            } else {
                AsideIcon(icon: .like, size: 26, color: contentColor)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            WaveformProgressBar(
                currentTime: Binding(
                    get: { isDraggingSlider ? dragTimeValue : player.currentTime },
                    set: { _ in }
                ),
                duration: player.duration,
                color: contentColor,
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

    // MARK: - Waveform Component

    struct WaveformProgressBar: View {
        @Binding var currentTime: Double
        let duration: Double
        var color: Color = .asideTextPrimary
        var isAnimating: Bool = true
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void

        let barCount = 60
        let barSpacing: CGFloat = 2
        let minHeight: CGFloat = 3

        @State private var amplitudes: [CGFloat] = []

        var body: some View {
            TimelineView(.animation(minimumInterval: 0.12, paused: !isAnimating)) { timeline in
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let barWidth = (totalWidth - (CGFloat(barCount - 1) * barSpacing)) / CGFloat(barCount)
                    let progress = duration > 0 ? currentTime / duration : 0
                    let phase = isAnimating ? timeline.date.timeIntervalSinceReferenceDate * 1.8 : 0

                    HStack(alignment: .center, spacing: barSpacing) {
                        ForEach(0..<barCount, id: \.self) { index in
                            let barProgress = Double(index) / Double(barCount - 1)
                            let isPlayed = barProgress <= progress
                            let baseAmplitude = index < amplitudes.count ? amplitudes[index] : 0.5

                            let height = barHeight(
                                index: index,
                                isPlayed: isPlayed,
                                base: baseAmplitude,
                                phase: phase,
                                maxH: geometry.size.height
                            )

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(isPlayed ? color : color.opacity(0.2))
                                .frame(width: max(2, barWidth), height: height)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let p = min(max(value.location.x / totalWidth, 0), 1)
                                onSeek(p * duration)
                            }
                            .onEnded { value in
                                let p = min(max(value.location.x / totalWidth, 0), 1)
                                onCommit(p * duration)
                            }
                    )
                }
            }
            .onAppear { generateAmplitudes() }
            .onChange(of: duration) { generateAmplitudes() }
        }

        private func barHeight(index: Int, isPlayed: Bool, base: CGFloat, phase: Double, maxH: CGFloat) -> CGFloat {
            var factor: CGFloat = 1.0
            if isPlayed {
                let wave = sin(Double(index) * 0.6 + phase)
                factor = 1.0 + CGFloat(wave) * 0.25
            }
            let amp = min(max(base * factor, 0), 1.0)
            return minHeight + amp * (maxH - minHeight)
        }

        private func generateAmplitudes() {
            amplitudes = (0..<barCount).map { index in
                let n = Double(index) / Double(barCount - 1)
                let envelope = sin(n * .pi)
                let random = Double.random(in: 0.25...1.0)
                return CGFloat(envelope * random)
            }
        }
    }

    private var controlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    AsideIcon(icon: player.mode.asideIcon, size: 22, color: secondaryContentColor)
                }
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
                }
                .frame(width: 44)
            }

            // 下载按钮 & 评论按钮
            if let song = player.currentSong {
                HStack(spacing: 0) {
                    // 评论按钮
                    Button {
                        showComments = true
                    } label: {
                        AsideIcon(
                            icon: .comment,
                            size: 22,
                            color: secondaryContentColor,
                            lineWidth: 1.4
                        )
                    }
                    .frame(width: 44)
                    
                    Spacer()
                    
                    // 下载按钮
                    Button {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            downloadManager.download(song: song, quality: player.soundQuality)
                        }
                    } label: {
                        AsideIcon(
                            icon: .playerDownload,
                            size: 22,
                            color: downloadManager.isDownloaded(songId: song.id) ? .asideTextSecondary : secondaryContentColor,
                            lineWidth: 1.4
                        )
                    }
                    .disabled(downloadManager.isDownloaded(songId: song.id))
                    .frame(width: 44)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }

        let totalSeconds = Int(seconds)
        let min = totalSeconds / 60
        let sec = totalSeconds % 60
        return String(format: "%d:%02d", min, sec)
    }

    /// 格式化流信息文本（如 "Hi-Res · FLAC / 192kHz / 24bit"）
    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec {
            parts.append(codec.uppercased())
        }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let khz = Double(sr) / 1000.0
                if khz == khz.rounded() {
                    parts.append("\(Int(khz))kHz")
                } else {
                    parts.append(String(format: "%.1fkHz", khz))
                }
            } else {
                parts.append("\(sr)Hz")
            }
        }
        if let bd = info.bitDepth, bd > 0 {
            parts.append("\(bd)bit")
        }
        if let ch = info.channelCount, ch > 2 {
            parts.append("\(ch)ch")
        }
        return parts.joined(separator: " / ")
    }
}
