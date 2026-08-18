import SwiftUI
import FFmpegSwiftSDK

/// 极简布局 - 大封面 + 歌词沉浸（参考 Apple Music 歌词视图风格）
struct MinimalPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared

    @StateObject private var colorExtractor = CoverColorExtractor()
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false
    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?

    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var isCoverBright: Bool { !colorExtractor.isDark }
    /// 只在歌词区域和整组背景色都明确偏亮时切黑字，保留中亮度封面的白色歌词。
    private var usesDarkLyricContent: Bool {
        guard colorScheme == .light else { return false }
        let backgrounds = [colorExtractor.dominantColor, colorExtractor.secondaryColor]
        let contrasts = backgrounds.map { background in
            (
                white: ThemeColorCustomization.contrastRatio(between: .white, and: background),
                black: ThemeColorCustomization.contrastRatio(between: .black, and: background)
            )
        }
        let lyricRegionIsVeryBright = colorExtractor.lyricRegionLuminance >= 0.78
        let whiteIsWeakAcrossPalette = contrasts.allSatisfy { $0.white < 2.2 }
        let blackClearlyWinsAcrossPalette = contrasts.allSatisfy {
            $0.black > $0.white * 1.5
        }
        return lyricRegionIsVeryBright
            && whiteIsWeakAcrossPalette
            && blackClearlyWinsAcrossPalette
    }
    private var contentColor: Color { usesDarkLyricContent ? .black : .white }
    private var secondaryColor: Color { usesDarkLyricContent ? .black.opacity(0.7) : .white.opacity(0.7) }
    private var mutedColor: Color { usesDarkLyricContent ? .black.opacity(0.3) : .white.opacity(0.3) }
    private var headerIconColor: Color { isCoverBright ? .black : .white }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { geo in
            let coverH = geo.size.width * 1.05
            let sw = geo.size.width
            ZStack(alignment: .topLeading) {
                blurredBackground(screenWidth: sw)
                    .frame(width: sw)
                    .ignoresSafeArea()

                coverImage(screenWidth: sw, coverHeight: coverH)
                    .frame(width: sw)
                    .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                    Spacer()
                        .frame(height: coverH - 60)

                lyricsWaterfall
                    .frame(maxHeight: .infinity)
                }
                .frame(width: sw)

                coverInfoOverlay(screenWidth: sw, coverHeight: coverH)
                    .frame(width: sw)
                    .ignoresSafeArea(edges: .top)

                VStack {
                    headerBar
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .opacity(isCoverBright && colorScheme == .light ? 0.85 : 1.0)
                    Spacer()
                }
                .environment(\.colorScheme, isCoverBright ? .light : .dark)

            if showMoreMenu {
                PlayerMoreMenu(
                    isPresented: $showMoreMenu,
                        onQuality: { showQualitySheet = true },
                    onEQ: { showEQSettings = true },
                    onTheme: { showThemePicker = true }
                )
            }
        }
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }

        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker){
            PlayerThemePickerSheet()

        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard){
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectQQ: { q in player.switchQQMusicQuality(q); showQualitySheet = false },
                songMid: player.currentSong?.qqMid,
                songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in player.switchQishuiQuality(info); showQualitySheet = false }
            )

        }
        .monoSheet(isPresented: $showArtistDetail, preset: .detail){
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
        .monoSheet(isPresented: $showDownloadSheet, preset: .compact){
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }

            }
        }
    }
}

// MARK: - 顶栏（半透明浮在封面上）
extension MinimalPlayerLayout {

    var headerBar: some View {
        MonoGlassContainer {
        HStack {
            Button(action: { dismiss() }) {
                    MonoIcon(icon: .back, size: 20, color: headerIconColor)
                }
                .monoGlassButtonStyle()
                .compatCircleButtonBorderShape()

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            }) {
                    MonoIcon(icon: .more, size: 20, color: headerIconColor)
                }
                .monoGlassButtonStyle()
                .compatCircleButtonBorderShape()
            }
            .padding(.horizontal, DeviceLayout.isPad ? 28 : 20)
        }
    }
}

// MARK: - 弥散背景（取色 + 封面模糊弥散）
extension MinimalPlayerLayout {

    func blurredBackground(screenWidth: CGFloat) -> some View {
                ZStack {
            LinearGradient(
                colors: [
                    colorExtractor.dominantColor,
                    colorExtractor.secondaryColor,
                    colorExtractor.dominantColor.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let song = player.currentSong, let url = song.coverUrl?.sized(200) {
                CachedAsyncImage(url: url) {
                    Color.clear
                }
                .aspectRatio(contentMode: .fill)
                .blur(radius: 90)
                .scaleEffect(1.5)
                .opacity(0.6)
            }

            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05)
        }
        .onAppear {
            colorExtractor.extract(from: player.currentSong?.coverUrl?.absoluteString)
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            colorExtractor.extract(from: player.currentSong?.coverUrl?.absoluteString)
        }
    }
}

// MARK: - 封面图（底部弥散模糊，自然融入背景）
extension MinimalPlayerLayout {

    func coverImage(screenWidth: CGFloat, coverHeight: CGFloat) -> some View {
        ZStack {
            coverContent(screenWidth: screenWidth, coverHeight: coverHeight)

            coverContent(screenWidth: screenWidth, coverHeight: coverHeight)
                .blur(radius: 40)
                .mask(
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: coverHeight * 0.5)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.5), location: 0.35),
                                .init(color: .black, location: 0.7),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
        }
        .mask(
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: coverHeight * 0.55)
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.5), location: 0.4),
                        .init(color: .black.opacity(0.15), location: 0.75),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
    }

    @ViewBuilder
    private func coverContent(screenWidth: CGFloat, coverHeight: CGFloat) -> some View {
        if let song = player.currentSong, let url = song.coverUrl?.sized(800) {
            ZStack {
                CachedAsyncImage(url: url) {
                    Rectangle()
                        .fill(Color.monoTextSecondary.opacity(0.08))
                }
                .aspectRatio(contentMode: .fill)
                
                if let dynamicUrl = player.dynamicCoverUrl, !dynamicUrl.isEmpty {
                    DynamicCoverView(urlString: dynamicUrl, cornerRadius: 0)
                }
            }
            .frame(width: screenWidth, height: coverHeight)
            .clipped()
        } else {
            Rectangle()
                .fill(Color.monoTextSecondary.opacity(0.08))
                .frame(width: screenWidth, height: coverHeight)
                .overlay(
                    MonoIcon(icon: .musicNote, size: 60, color: .monoTextSecondary.opacity(0.2), lineWidth: 1.2)
                )
        }
    }
}

// MARK: - 封面上的信息 + 控件浮层
extension MinimalPlayerLayout {

    func coverInfoOverlay(screenWidth: CGFloat, coverHeight: CGFloat) -> some View {
        VStack {
            Spacer()
                .frame(height: coverHeight - 54)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.currentSong?.name ?? "")
                        .monoPlayerDisplayFont(
                            size: 20,
                            weight: .bold,
                            fallback: .system(size: 20, weight: .bold, design: .rounded)
                        )
                        .foregroundColor(contentColor)
                        .lineLimit(2)

                    Button { showArtistDetail = true } label: {
                        Text(player.currentSong?.artistName ?? "")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryColor)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                HStack(spacing: 18) {
                    Button(action: { player.previous() }) {
                        MonoIcon(icon: .previous, size: 18, color: contentColor, lineWidth: 1.8)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    Button(action: { player.togglePlayPause() }) {
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: contentColor))
                                .frame(width: 28, height: 28)
                        } else {
                            MonoIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 24,
                                color: contentColor,
                                lineWidth: 2
                            )
                        }
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    Button(action: { player.next() }) {
                        MonoIcon(icon: .next, size: 18, color: contentColor, lineWidth: 1.8)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    if let song = player.currentSong {
                        LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 20, activeColor: .red, inactiveColor: contentColor)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            // 下载能力开启时仅保留下载；评论与沉浸入口不占用极简主题画面。
            if AppConfig.Features.downloadEnabled, let song = player.currentSong {
                HStack {
                    Spacer()
                    Button {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            showDownloadSheet = true
                        }
                    } label: {
                        MonoIcon(
                            icon: .playerDownload,
                            size: 22,
                            color: downloadManager.isDownloaded(songId: song.id) ? .monoTextSecondary : secondaryColor,
                            lineWidth: 1.4
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                    .disabled(downloadManager.isDownloaded(songId: song.id))
                    .frame(width: 44)
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            Spacer()
        }
    }
}

// MARK: - 歌词瀑布流
extension MinimalPlayerLayout {

    var lyricsWaterfall: some View {
        Group {
            if lyricVM.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: contentColor))
                    Spacer()
                }
            } else if !lyricVM.hasLyrics {
                VStack {
                    Spacer()
                    Text("lyrics_no_lyrics")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(mutedColor)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Color.clear.frame(height: 20)

                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.element.id) { index, line in
                                let isCurrent = index == lyricVM.currentLineIndex
                                let distance = abs(index - lyricVM.currentLineIndex)
                                let karaokeWords = LyricKaraokeTimeline.resolvedWords(for: line)

                                Button(action: { player.seek(to: line.time) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if isCurrent && enableKaraoke && !karaokeWords.isEmpty {
                                            MinimalKaraokeLine(
                                                words: karaokeWords,
                                                contentColor: contentColor,
                                                isPlaying: player.isPlaying
                                            )
                                        } else {
                                            Text(line.text.monoLyricDisplayText)
                                                .font(
                                                    MonoPlayerFont.activeFont(
                                                        size: isCurrent ? 28 : 16,
                                                        weight: isCurrent ? .heavy : .medium,
                                                        fallback: .system(
                                                            size: isCurrent ? 28 : 16,
                                                            weight: isCurrent ? .heavy : .medium,
                                                            design: .rounded
                                                        )
                                                    )
                                                )
                                                .foregroundColor(isCurrent ? contentColor : contentColor.opacity(0.3))
                                        }

                                        if showTranslation, let trans = line.translation, !trans.isEmpty {
                                            Text(trans.monoLyricDisplayText)
                                                .font(
                                                    MonoPlayerFont.activeFont(
                                                        size: isCurrent ? 15 : 12,
                                                        weight: .regular,
                                                        fallback: .system(
                                                            size: isCurrent ? 15 : 12,
                                                            weight: .regular,
                                                            design: .rounded
                                                        )
                                                    )
                                                )
                                                .foregroundColor(isCurrent ? contentColor.opacity(0.6) : contentColor.opacity(0.15))
                                        }
                                    }
                                    .blur(radius: isCurrent ? 0 : min(CGFloat(distance) * 1.0, 3))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: lyricVM.currentLineIndex)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(index)
                            }

                            Color.clear.frame(height: 80)
                        }
                        .padding(.horizontal, DeviceLayout.isPad ? 36 : 28)
                    }
                    .scrollIndicators(.hidden)
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            isUserScrolling = true
                            resetScrollTimer()
                        }
                    )
                    .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                        if !isUserScrolling {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        isUserScrolling = false
                        proxy.monoRestoreLyricPosition(isCancelled: { isUserScrolling }) {
                            lyricVM.currentLineIndex
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.4), location: 0.06),
                            .init(color: .black, location: 0.15),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    func resetScrollTimer() {
        userScrollTimer?.invalidate()
        userScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { isUserScrolling = false }
            }
        }
    }
}

/// 极简歌词主题只让当前行订阅高频时间轴，避免整张播放器随进度重绘。
private struct MinimalKaraokeLine: View {
    let words: [LyricWord]
    let contentColor: Color
    let isPlaying: Bool

    @AppStorage(KaraokeWordStyle.storageKey) private var karaokeStyleRaw = KaraokeWordStyle.defaultStyle.rawValue

    var body: some View {
        TimelineView(AppFrameRate.throttledTimeline(
            maximumFramesPerSecond: 60,
            paused: !isPlaying
        )) { _ in
            let player = PlayerManager.shared
            let currentTime = LyricKaraokeTimeline.playbackTime(
                streamPlayerTime: player.streamPlayer.currentTime,
                publishedTime: PlaybackTimePublisher.shared.currentTime,
                isAppleMusic: player.currentSong?.isAppleMusic == true,
                appleMusicPlayerTime: player.appleMusicPlayback.renderingPlaybackTime
            )
            let style = KaraokeWordStyle.resolve(karaokeStyleRaw)

            FlowLayout(spacing: 0) {
                ForEach(words) { word in
                    MinimalKaraokeWord(
                        word: word,
                        currentTime: currentTime,
                        contentColor: contentColor,
                        style: style
                    )
                }
            }
        }
    }
}

/// 极简布局专用卡拉OK逐字视图
private struct MinimalKaraokeWord: View {
    let word: LyricWord
    let currentTime: TimeInterval
    let contentColor: Color
    let style: KaraokeWordStyle

    var body: some View {
        KaraokeStyledWordView(
            text: word.text.monoLyricDisplayText,
            progress: calculateProgress(),
            font: MonoPlayerFont.activeFont(
                size: 28,
                weight: .heavy,
                fallback: .system(size: 28, weight: .heavy, design: .rounded)
            ),
            style: style,
            inactiveColor: contentColor.opacity(0.25),
            activeColor: contentColor
        )
    }

    func calculateProgress() -> CGFloat {
        guard word.duration > 0 else { return currentTime >= word.startTime ? 1 : 0 }
        if currentTime < word.startTime { return 0 }
        if currentTime >= word.startTime + word.duration { return 1 }
        return min(max(CGFloat((currentTime - word.startTime) / word.duration), 0), 1)
    }
}

// MARK: - 辅助
extension MinimalPlayerLayout {

    func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let khz = Double(sr) / 1000.0
                parts.append(khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz))
            } else { parts.append("\(sr)Hz") }
        }
        if let bd = info.bitDepth, bd > 0 { parts.append("\(bd)bit") }
        return parts.joined(separator: " · ")
    }
}
