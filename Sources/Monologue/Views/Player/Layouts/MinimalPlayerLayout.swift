import SwiftUI
import FFmpegSwiftSDK

/// 极简布局 - 大封面 + 歌词沉浸（参考 Apple Music 歌词视图风格）
struct MinimalPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared

    @State private var colorExtractor = CoverColorExtractor()
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
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
    /// 控件/歌词仅在封面特别白时才切深色（亮度 > 0.75）
    private var isVeryBright: Bool { colorExtractor.luminance > 0.75 }
    private var contentColor: Color { isVeryBright ? .black : .white }
    private var secondaryColor: Color { isVeryBright ? .black.opacity(0.7) : .white.opacity(0.7) }
    private var mutedColor: Color { isVeryBright ? .black.opacity(0.3) : .white.opacity(0.3) }
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
        .monologueSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
        .monologueSheet(isPresented: $showEQSettings, preset: .large){
            NavigationStack { EQSettingsView() }

        }
        .monologueSheet(isPresented: $showThemePicker, preset: .themePicker){
            PlayerThemePickerSheet()

        }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact){
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
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
        .monologueSheet(isPresented: $showComments, preset: .large){
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                           songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)

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
}

// MARK: - 顶栏（半透明浮在封面上）
extension MinimalPlayerLayout {

    var headerBar: some View {
        MonologueGlassContainer {
        HStack {
            Button(action: { dismiss() }) {
                    MonologueIcon(icon: .back, size: 20, color: headerIconColor)
                }
                .monologueGlassButtonStyle()
                .buttonBorderShape(.circle)

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            }) {
                    MonologueIcon(icon: .more, size: 20, color: headerIconColor)
                }
                .monologueGlassButtonStyle()
                .buttonBorderShape(.circle)
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
                        .fill(Color.monologueTextSecondary.opacity(0.08))
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
                .fill(Color.monologueTextSecondary.opacity(0.08))
                .frame(width: screenWidth, height: coverHeight)
                .overlay(
                    MonologueIcon(icon: .musicNote, size: 60, color: .monologueTextSecondary.opacity(0.2), lineWidth: 1.2)
                )
        }
    }
}

// MARK: - 封面上的信息 + 控件浮层
extension MinimalPlayerLayout {

    func coverInfoOverlay(screenWidth: CGFloat, coverHeight: CGFloat) -> some View {
        VStack {
            Spacer()
                .frame(height: coverHeight - 70)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.currentSong?.name ?? "")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
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
                        MonologueIcon(icon: .previous, size: 18, color: contentColor, lineWidth: 1.8)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Button(action: { player.togglePlayPause() }) {
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: contentColor))
                                .frame(width: 28, height: 28)
                        } else {
                            MonologueIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 24,
                                color: contentColor,
                                lineWidth: 2
                            )
                        }
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Button(action: { player.next() }) {
                        MonologueIcon(icon: .next, size: 18, color: contentColor, lineWidth: 1.8)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    if let song = player.currentSong {
                        LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 20, activeColor: .red, inactiveColor: contentColor)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            // 评论 + 下载
            if let song = player.currentSong {
                HStack(spacing: 0) {
                    Button { showComments = true } label: {
                        MonologueIcon(icon: .comment, size: 22, color: secondaryColor, lineWidth: 1.4)
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
                            color: downloadManager.isDownloaded(songId: song.id) ? .monologueTextSecondary : secondaryColor,
                            lineWidth: 1.4
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
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

                                Button(action: { player.seek(to: line.time) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if isCurrent && enableKaraoke && !line.words.isEmpty {
                                            FlowLayout(spacing: 0) {
                                                ForEach(line.words) { word in
                                                    MinimalKaraokeWord(
                                                        word: word,
                                                        currentTime: timePublisher.currentTime,
                                                        contentColor: contentColor
                                                    )
                                                }
                                            }
                                        } else {
                                            Text(line.text)
                                                .font(.system(
                                                    size: isCurrent ? 28 : 16,
                                                    weight: isCurrent ? .heavy : .medium,
                                                    design: .rounded
                                                ))
                                                .foregroundColor(isCurrent ? contentColor : contentColor.opacity(0.3))
                                        }

                                        if showTranslation, let trans = line.translation, !trans.isEmpty {
                                            Text(trans)
                                                .font(.system(
                                                    size: isCurrent ? 15 : 12,
                                                    weight: .regular,
                                                    design: .rounded
                                                ))
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
                        proxy.scrollTo(lyricVM.currentLineIndex, anchor: .center)
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

/// 极简布局专用卡拉OK逐字视图
private struct MinimalKaraokeWord: View {
    let word: LyricWord
    let currentTime: TimeInterval
    let contentColor: Color

    var body: some View {
        let progress = calculateProgress()

        Text(word.text)
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .foregroundColor(contentColor.opacity(0.25))
            .overlay(
                GeometryReader { geo in
                    Text(word.text)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(contentColor)
                        .frame(width: geo.size.width * progress, alignment: .leading)
                        .clipped()
                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: progress)
                }
            )
            .fixedSize(horizontal: true, vertical: false)
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
