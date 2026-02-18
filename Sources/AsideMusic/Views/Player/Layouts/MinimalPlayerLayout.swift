import SwiftUI
import FFmpegSwiftSDK

/// 极简布局 - 歌词瀑布流 + 打字机风格 + 当前行放大/其他行模糊
struct MinimalPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var cursorOpacity: Double = 1.0
    @State private var titleOffset: CGFloat = 0
    @State private var isAppeared = false
    @State private var songChangeId: String = ""
    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?

    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = true

    private var contentColor: Color { .asideTextPrimary }
    private var secondaryColor: Color { .asideTextSecondary }
    private var mutedColor: Color { .asideTextSecondary.opacity(0.4) }

    var body: some View {
        ZStack {
            AsideBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, DeviceLayout.headerTopPadding)

                // 歌词瀑布流区域
                lyricsWaterfall
                    .frame(maxHeight: .infinity)

                // 歌曲信息（进度条上方）
                typographySection
                    .padding(.horizontal, 36)
                    .padding(.bottom, 16)

                // 进度条
                minimalProgress
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)

                // 控制按钮
                controlsSection
                    .padding(.horizontal, 36)
                    .padding(.bottom, DeviceLayout.playerBottomPadding)
            }

            if showMoreMenu {
                PlayerMoreMenu(
                    isPresented: $showMoreMenu,
                    onEQ: { showEQSettings = true },
                    onTheme: { showThemePicker = true }
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { isAppeared = true }
            startCursorBlink()
            songChangeId = player.currentSong?.id.description ?? ""
            // 确保歌词已加载
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                if song.isQQMusic, let mid = song.qqMid {
                    lyricVM.fetchQQLyrics(mid: mid, songId: song.id)
                } else {
                    lyricVM.fetchLyrics(for: song.id)
                }
            }
        }
        .onChange(of: player.currentSong?.id) { _, newId in
            animateSongChange(newId: newId?.description ?? "")
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
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
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentKugouQuality: player.kugouQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectKugou: { q in player.switchKugouQuality(q); showQualitySheet = false },
                onSelectQQ: { q in player.switchQQMusicQuality(q); showQualitySheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showComments) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                           songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }
}

// MARK: - 顶栏
extension MinimalPlayerLayout {

    var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 40, height: 40)
                    AsideIcon(icon: .back, size: 16, color: contentColor)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 极简时间显示
            Text(currentTimeString())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(mutedColor)
                .tracking(1)

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 40, height: 40)
                    AsideIcon(icon: .more, size: 18, color: contentColor)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
    }

    func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

// MARK: - 歌词瀑布流（当前行放大，其他行缩小+模糊）
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
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            // 顶部留白
                            Color.clear.frame(height: 120)

                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.element.id) { index, line in
                                let isCurrent = index == lyricVM.currentLineIndex
                                // 距离当前行的距离，用于计算模糊程度
                                let distance = abs(index - lyricVM.currentLineIndex)

                                Button(action: { player.seek(to: line.time) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        // 歌词文本
                                        if isCurrent && enableKaraoke && !line.words.isEmpty {
                                            // 当前行：卡拉OK 逐字高亮
                                            FlowLayout(spacing: 0) {
                                                ForEach(line.words) { word in
                                                    MinimalKaraokeWord(
                                                        word: word,
                                                        currentTime: player.currentTime,
                                                        contentColor: contentColor
                                                    )
                                                }
                                            }
                                        } else {
                                            Text(line.text)
                                                .font(.system(
                                                    size: isCurrent ? 32 : 16,
                                                    weight: isCurrent ? .heavy : .medium,
                                                    design: .rounded
                                                ))
                                                .foregroundColor(isCurrent ? contentColor : contentColor.opacity(0.35))
                                        }

                                        // 翻译
                                        if showTranslation, let trans = line.translation, !trans.isEmpty {
                                            Text(trans)
                                                .font(.system(
                                                    size: isCurrent ? 16 : 12,
                                                    weight: .regular,
                                                    design: .rounded
                                                ))
                                                .foregroundColor(isCurrent ? contentColor.opacity(0.7) : contentColor.opacity(0.2))
                                        }
                                    }
                                    .blur(radius: isCurrent ? 0 : min(CGFloat(distance) * 1.2, 4))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: lyricVM.currentLineIndex)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(index)
                            }

                            // 底部留白
                            Color.clear.frame(height: 80)
                        }
                        .padding(.horizontal, 36)
                    }
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
                        // 视图出现时立即跳转到当前行（切换主题时需要）
                        isUserScrolling = false
                        proxy.scrollTo(lyricVM.currentLineIndex, anchor: .center)
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.88),
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
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .foregroundColor(contentColor.opacity(0.25))
            .overlay(
                GeometryReader { geo in
                    Text(word.text)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(contentColor)
                        .frame(width: geo.size.width * progress, alignment: .leading)
                        .clipped()
                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: progress)
                }
            )
            .fixedSize(horizontal: true, vertical: false)
    }

    func calculateProgress() -> CGFloat {
        if currentTime < word.startTime { return 0 }
        if currentTime >= word.startTime + word.duration { return 1 }
        return CGFloat((currentTime - word.startTime) / word.duration)
    }
}

// MARK: - 歌曲信息（进度条上方，保持打字机效果）
extension MinimalPlayerLayout {

    var typographySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 歌曲名 + 呼吸光标
            HStack(alignment: .bottom, spacing: 0) {
                Text(player.currentSong?.name ?? "")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                    .offset(x: titleOffset)

                // 呼吸光标
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(contentColor)
                    .frame(width: 2.5, height: 22)
                    .opacity(cursorOpacity)
                    .padding(.leading, 3)
                    .padding(.bottom, 2)
            }
            .padding(.bottom, 6)

            // 歌手名 + 音质
            HStack(spacing: 12) {
                Text(player.currentSong?.artistName ?? "")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryColor)
                    .lineLimit(1)

                Button(action: { showQualitySheet = true }) {
                    Text(player.qualityButtonText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(mutedColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(mutedColor, lineWidth: 0.5)
                        )
                }

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(mutedColor)
                        .lineLimit(1)
                }

                Spacer()

                if let songId = player.currentSong?.id {
                    LikeButton(songId: songId, size: 20, activeColor: .red, inactiveColor: secondaryColor)
                }
            }
        }
        .opacity(isAppeared ? 1 : 0)
    }
}

// MARK: - 极简进度条
extension MinimalPlayerLayout {

    var minimalProgress: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let progress = player.duration > 0
                    ? (isDragging ? dragValue : player.currentTime) / player.duration
                    : 0

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(contentColor.opacity(0.08))
                        .frame(height: 2)

                    Rectangle()
                        .fill(contentColor.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: 2)

                    if isDragging {
                        Circle()
                            .fill(contentColor)
                            .frame(width: 10, height: 10)
                            .offset(x: geo.size.width * CGFloat(min(max(progress, 0), 1)) - 5)
                    }
                }
                .contentShape(Rectangle().inset(by: -10))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            dragValue = p * player.duration
                        }
                        .onEnded { value in
                            isDragging = false
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            player.seek(to: p * player.duration)
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                Spacer()
                Text("-" + formatTime(max(0, player.duration - (isDragging ? dragValue : player.currentTime))))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(mutedColor)
        }
    }
}

// MARK: - 控制按钮
extension MinimalPlayerLayout {

    var controlsSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    AsideIcon(icon: player.mode.asideIcon, size: 20, color: secondaryColor)
                }
                .frame(width: 40)

                Spacer()

                Button(action: { player.previous() }) {
                    AsideIcon(icon: .previous, size: 28, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())

                Spacer()

                Button(action: { player.togglePlayPause() }) {
                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: contentColor))
                            .scaleEffect(1.3)
                            .frame(width: 56, height: 56)
                    } else {
                        AsideIcon(icon: player.isPlaying ? .pause : .play, size: 44, color: contentColor)
                            .frame(width: 56, height: 56)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))

                Spacer()

                Button(action: { player.next() }) {
                    AsideIcon(icon: .next, size: 28, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())

                Spacer()

                Button(action: { showPlaylist = true }) {
                    AsideIcon(icon: .list, size: 20, color: secondaryColor)
                }
                .frame(width: 40)
            }

            if let song = player.currentSong {
                HStack(spacing: 0) {
                    Button(action: { showComments = true }) {
                        AsideIcon(icon: .comment, size: 20, color: secondaryColor, lineWidth: 1.4)
                    }
                    .frame(width: 40)

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
                            size: 20,
                            color: downloadManager.isDownloaded(songId: song.id) ? mutedColor : secondaryColor,
                            lineWidth: 1.4
                        )
                    }
                    .disabled(downloadManager.isDownloaded(songId: song.id))
                    .frame(width: 40)
                }
            }
        }
    }
}

// MARK: - 动画辅助
extension MinimalPlayerLayout {

    func startCursorBlink() {
        withAnimation(
            .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
        ) {
            cursorOpacity = 0.2
        }
    }

    func animateSongChange(newId: String) {
        withAnimation(.easeIn(duration: 0.15)) {
            titleOffset = -20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            titleOffset = 20
            songChangeId = newId
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                titleOffset = 0
            }
        }
    }

    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

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
