//  民谣主题 — 诗集与打字信件 (Typewriter Letter)
//  非常规布局：歌词像打字机一样逐行在信纸上打印出来，历史记录保留，未唱到的不显示。

import SwiftUI

struct FolkPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject var downloadStatus = DownloadedSongStatusModel.shared

    // MARK: - Colors (Typewriter / Letter Theme)
    private var paperBg: Color { colorScheme == .dark ? Color(hex: "1F1D1B") : Color(hex: "F4EBE0") }
    private var inkDark: Color { colorScheme == .dark ? Color(hex: "D5CEC4") : Color(hex: "2A2520") }
    private var inkFaded: Color { colorScheme == .dark ? Color(hex: "8A8075") : Color(hex: "8A8075") }
    private var redStamp: Color { colorScheme == .dark ? Color(hex: "AE4138") : Color(hex: "BE4A41") }
    private var tapeColor: Color { colorScheme == .dark ? Color(hex: "3A352F") : Color(hex: "E6D5B8") }
    private var lineBlue: Color { colorScheme == .dark ? Color(hex: "343946") : Color(hex: "B0BBD4") }

    // MARK: - State
    @State private var isAppeared = false
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showComments = false
    @State private var showArtistDetail = false
    @State private var showDownloadSheet = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                // 信纸背景
                folkBackground(size: size)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶栏（类似信纸顶部）
                    topBar
                        .padding(.top, DeviceLayout.playerHeaderTopPadding)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // 寄信人/邮戳区域（封面与信息）
                    letterHeader
                        .padding(.horizontal, 24)

                    // 信件正文（打字机歌词，核心非常规布局）
                    typewriterLyricsArea(size: size)
                        .padding(.top, 24)
                        .padding(.horizontal, 8)

                    Spacer(minLength: 0)

                    // 签名处与控制区
                    controlArea(geo: geo)
                        .padding(.bottom, 24)
                }
                .frame(width: size.width, height: size.height, alignment: .center)
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        anchorFrame: anchorFrame,
                        isDarkBackground: false,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .frame(width: size.width, height: size.height, alignment: .center)
            .opacity(isAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { isAppeared = true }
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            PlaylistPopupView()
        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard) {
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
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }
        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker) {
            PlayerThemePickerSheet()
        }
        .monoSheet(isPresented: $showComments, preset: .large) {
            if let song = player.currentSong {
                CommentView(song: song)
            }
        }
        .monoSheet(isPresented: $showArtistDetail, preset: .detail) {
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
        .monoSheet(isPresented: $showDownloadSheet, preset: .compact) {
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) { showDownloadSheet = false }
            }
        }
    }
}

// MARK: - Components

extension FolkPlayerLayout {

    func folkBackground(size: CGSize) -> some View {
        ZStack {
            paperBg

            // 信纸横纹与纸张质感
            Canvas { context, sz in
                // 噪点模糊
                context.addFilter(.blur(radius: 0.3))
                
                // 绘制极弱的信纸横线
                let lineSpacing: CGFloat = 36
                for y in stride(from: lineSpacing, to: sz.height, by: lineSpacing) {
                    let path = Path { p in
                        p.move(to: CGPoint(x: 20, y: y))
                        p.addLine(to: CGPoint(x: sz.width - 20, y: y))
                    }
                    // 线条有断续感
                    context.stroke(path, with: .color(lineBlue.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
                }
            }
            
            // 边缘做旧暗角
            LinearGradient(colors: [inkDark.opacity(0.08), .clear, .clear, inkDark.opacity(0.12)], startPoint: .top, endPoint: .bottom)
        }
    }

    var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                MonoIcon(icon: .close, size: 16, color: inkDark)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(MonoBouncingButtonStyle())

            Spacer()

            // 日期戳图章
            VStack(spacing: 2) {
                Text(Date().formatted(.dateTime.year().month().day()))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(redStamp.opacity(0.8))
                Text("FOLK POETRY")
                    .font(.system(size: 8, weight: .heavy, design: .serif))
                    .tracking(2)
                    .foregroundStyle(inkDark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(redStamp.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                    .rotationEffect(.degrees(-1))
            )

            Spacer()

            Button(action: { showMoreMenu.toggle() }) {
                MonoIcon(icon: .more, size: 16, color: inkDark)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .playerMoreMenuAnchor()
        }
    }

    var letterHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            // 左侧：相片夹带（专辑封面）
            FolkAdaptiveCover(
                url: player.currentSong?.coverUrl?.sized(200),
                dynamicURL: player.dynamicCoverUrl,
                placeholderColor: paperBg,
                placeholderIconColor: inkFaded.opacity(0.3),
                tapeColor: tapeColor,
                shadowColor: inkDark.opacity(0.1)
            )
            .id("\(player.currentSong?.coverUrl?.absoluteString ?? "")|\(player.dynamicCoverUrl ?? "")")

            // 右侧：打字机标签信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Title:")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(redStamp)
                    Text(player.currentSong?.name ?? "Unknown Track")
                        .monoPlayerDisplayFont(
                            size: 16,
                            weight: .bold,
                            fallback: .system(size: 16, weight: .bold, design: .serif)
                        )
                        .foregroundColor(inkDark)
                        .lineLimit(nil)
                }

                HStack(spacing: 8) {
                    Text("Voice:")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(inkFaded)
                    Button { showArtistDetail = true } label: {
                        Text(player.currentSong?.artistName ?? "Unknown Artist")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(inkFaded)
                            .lineLimit(nil)
                    }
                    .buttonStyle(.plain)
                }
                
                // 音质标签
                Button { showQualitySheet = true } label: {
                    Text(player.qualityButtonText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(inkDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Rectangle().stroke(inkDark, lineWidth: 1))
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .playerQualitySelectionAvailability()
                .padding(.top, 2)
            }
            Spacer()
            
            if let song = player.currentSong {
                folkLikeButton(song: song)
            }
        }
    }

    func typewriterLyricsArea(size: CGSize) -> some View {
        Group {
            if lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            Color.clear.frame(height: 8)

                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.element.id) { index, line in
                                if !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    let isCurrent = index == lyricVM.currentLineIndex
                                    
                                    // 核心：只显示已播放和正在播放的歌词（打字信件效果）
                                    if index <= lyricVM.currentLineIndex {
                                        HStack(alignment: .top, spacing: 12) {
                                            // 前置破折号作为引用
                                            Text("-")
                                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                .foregroundColor(isCurrent ? redStamp : inkFaded.opacity(0.5))
                                                .offset(y: 2)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(line.text.monoLyricDisplayText)
                                                    .font(
                                                        MonoPlayerFont.activeFont(
                                                            size: isCurrent ? 18 : 16,
                                                            weight: isCurrent ? .bold : .medium,
                                                            fallback: .system(
                                                                size: isCurrent ? 18 : 16,
                                                                weight: isCurrent ? .bold : .medium,
                                                                design: .monospaced
                                                            )
                                                        )
                                                    )
                                                    .foregroundColor(isCurrent ? inkDark : inkFaded)
                                                    .lineLimit(nil)
                                                    .multilineTextAlignment(.leading)

                                                if let trans = line.translation, !trans.isEmpty {
                                                    Text(trans.monoLyricDisplayText)
                                                        .font(
                                                            MonoPlayerFont.activeFont(
                                                                size: 12,
                                                                weight: .regular,
                                                                fallback: .system(
                                                                    size: 12,
                                                                    weight: .regular,
                                                                    design: .monospaced
                                                                )
                                                            )
                                                        )
                                                        .foregroundColor(isCurrent ? inkFaded : inkFaded.opacity(0.5))
                                                        .multilineTextAlignment(.leading)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 16)
                                        .id(index)
                                        .onTapWithHaptic { player.seek(to: line.time) }
                                        // 新歌词像盖章一样出现
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                            removal: .opacity
                                        ))
                                    }
                                }
                            }
                            
                            // 底部留白保证能滚动到底
                            Color.clear.frame(height: 80)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            // 始终滚动到底部新出现的一行，但不要贴紧底边，留出阅读空间
                            proxy.scrollTo(newIndex, anchor: UnitPoint(x: 0.5, y: 0.65))
                        }
                    }
                    .onAppear {
                        proxy.monoRestoreLyricPosition(anchor: UnitPoint(x: 0.5, y: 0.65)) { lyricVM.currentLineIndex }
                    }
                }
                // 顶部文字渐隐遮罩
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.1),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                // 无歌词纯净信纸
                VStack {
                    Spacer()
                    MonoSemanticIcon(
                        semantic: .instrumentalLyrics,
                        fallback: .musicNote,
                        size: 32,
                        color: inkFaded.opacity(0.4)
                    )
                        .padding(.bottom, 8)
                    Text("Dear listener,\nInstrumental track playing.")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(inkFaded)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    func controlArea(geo: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            // 签字笔横线进度条
            folkProgressBar

            // 底栏控制
            HStack(spacing: 0) {
                // 左侧辅助功能
                HStack(spacing: 16) {
                    Button(action: { player.switchMode() }) {
                        MonoIcon(icon: player.mode.monoIcon, size: 16, color: inkFaded)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                    
                    Button { showComments = true } label: {
                        MonoIcon(icon: .comment, size: 16, color: inkFaded)
                            .frame(width: 36, height: 36)
                    }
                    
                    if let song = player.currentSong {
                        if AppConfig.Features.downloadEnabled {
                            // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                            Button {
                                if !downloadStatus.isDownloaded(song: song) { showDownloadSheet = true }
                            } label: {
                                MonoIcon(icon: .download, size: 16, color: downloadStatus.isDownloaded(song: song) ? inkFaded.opacity(0.3) : inkFaded)
                                    .frame(width: 36, height: 36)
                            }
                            .disabled(downloadStatus.isDownloaded(song: song))
                        }
                    }
                }
                
                Spacer()

                // 主控（旧式打字机按键风格）
                HStack(spacing: 12) {
                    Button(action: { player.previous() }) {
                        MonoIcon(icon: .previous, size: 16, color: inkDark)
                            .frame(width: 44, height: 44)
                            .background(Circle().stroke(inkFaded.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(inkDark)
                                .frame(width: 56, height: 56)

                            MonoIcon(icon: player.isPlaying ? .pause : .play, size: 22, color: paperBg)
                        }
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    Button(action: { player.next() }) {
                        MonoIcon(icon: .next, size: 16, color: inkDark)
                            .frame(width: 44, height: 44)
                            .background(Circle().stroke(inkFaded.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                }
                
                Spacer()
                
                Button(action: { showPlaylist = true }) {
                    MonoIcon(icon: .list, size: 16, color: inkFaded)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }
        }
        .padding(.horizontal, 24)
    }

    var folkProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { barGeo in
                let progress = timePublisher.duration > 0
                    ? min(max(timePublisher.currentTime / timePublisher.duration, 0), 1)
                    : 0.0

                ZStack(alignment: .leading) {
                    // 底轨：极细的虚线
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundColor(inkFaded.opacity(0.3))
                        .frame(height: 1)

                    // 进度：实线，像笔划过
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1.5))
                        .foregroundColor(inkDark)
                        .frame(width: max(1, barGeo.size.width * CGFloat(progress)), height: 1)

                    // 笔尖或墨水滴
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: -4))
                        p.addLine(to: CGPoint(x: 4, y: 4))
                        p.addLine(to: CGPoint(x: -4, y: 4))
                        p.closeSubpath()
                    }
                    .fill(inkDark)
                    .offset(x: max(0, barGeo.size.width * CGFloat(progress) - 2), y: 0)
                }
                .contentShape(Rectangle().inset(by: -14))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = min(max(value.location.x / barGeo.size.width, 0), 1)
                            player.seek(to: p * timePublisher.duration)
                        }
                )
            }
            .frame(height: 10)

            // 时间文本（打字机字体）
            HStack {
                Text(formatTime(timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(inkFaded)
        }
        .padding(.horizontal, 24)
    }

    func folkLikeButton(song: Song) -> some View {
        let isLiked = LikeManager.shared.isLiked(id: song.id, source: song.musicSource)
        return Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            LikeManager.shared.toggleLike(songId: song.id, isQQMusic: song.isQQMusic, song: song)
        } label: {
            // 图章邮戳风格红心
            ZStack {
                Circle()
                    .stroke(isLiked ? redStamp : inkFaded.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [isLiked ? 100 : 3, 3]))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(isLiked ? 0 : 45))
                    
                MonoIcon(icon: isLiked ? .liked : .like, size: 16, color: isLiked ? redStamp : inkFaded)
            }
        }
        .buttonStyle(MonoBouncingButtonStyle())
    }

    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// 信笺相框以封面真实比例排版，横图、竖图都不会被塞进固定正方形外壳。
private struct FolkAdaptiveCover: View {
    let url: URL?
    let dynamicURL: String?
    let placeholderColor: Color
    let placeholderIconColor: Color
    let tapeColor: Color
    let shadowColor: Color

    @StateObject private var loader = ImageLoader()

    private let maximumSide: CGFloat = 70

    private var artworkSize: CGSize {
        guard let image = loader.image,
              image.size.width > 0,
              image.size.height > 0 else {
            return CGSize(width: maximumSide, height: maximumSide)
        }

        let ratio = image.size.width / image.size.height
        if ratio >= 1 {
            return CGSize(width: maximumSide, height: maximumSide / ratio)
        }
        return CGSize(width: maximumSide * ratio, height: maximumSide)
    }

    var body: some View {
        ZStack {
            Group {
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ZStack {
                        placeholderColor
                        MonoIcon(icon: .musicNote, size: 24, color: placeholderIconColor)
                    }
                }
            }

            if let dynamicURL, !dynamicURL.isEmpty {
                DynamicCoverView(urlString: dynamicURL, cornerRadius: 0)
            }
        }
        .frame(width: artworkSize.width, height: artworkSize.height)
        .clipped()
        .padding(4)
        .background(Color.white)
        .shadow(color: shadowColor, radius: 3, x: 1, y: 2)
        .rotationEffect(.degrees(-3))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(tapeColor.opacity(0.8))
                .frame(width: 30, height: 12)
                .rotationEffect(.degrees(-10))
                .offset(y: -6)
        }
        .onAppear {
            if let url {
                loader.load(url: url, maxSize: maximumSide)
            }
        }
    }
}

// 直线绘制辅助
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}
