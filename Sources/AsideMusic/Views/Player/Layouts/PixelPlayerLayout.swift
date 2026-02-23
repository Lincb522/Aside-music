import SwiftUI
import FFmpegSwiftSDK

/// 像素风格播放器 — 8-bit 复古游戏机界面
/// 增强版：CRT 暗角、RGB 子像素偏移、像素频谱、打字机歌词、游戏化 HUD
struct PixelPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    
    @State private var isAppeared = false
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showComments = false
    @State private var showLyrics = false
    @State private var blinkOn = true
    @State private var spectrumLevels: [CGFloat] = Array(repeating: 0, count: 16)
    
    // MARK: - 像素配色
    private var bgDark: Color { Color(hex: "0f0f23") }
    private var bgLight: Color { Color(hex: "d8dbe2") }
    private var bg: Color { colorScheme == .dark ? bgDark : bgLight }
    private var screenBg: Color { colorScheme == .dark ? Color(hex: "1a1a2e") : Color(hex: "c8ccd4") }
    private var pixelGreen: Color { Color(hex: "00ff41") }
    private var pixelCyan: Color { Color(hex: "00d4ff") }
    private var pixelYellow: Color { Color(hex: "ffff00") }
    private var pixelRed: Color { Color(hex: "ff0040") }
    private var pixelOrange: Color { Color(hex: "ff8800") }
    private var fg: Color { colorScheme == .dark ? pixelGreen : Color(hex: "1a1a2e") }
    private var fgDim: Color { fg.opacity(0.4) }
    private var accent: Color { colorScheme == .dark ? pixelCyan : Color(hex: "0066cc") }
    private let pixelFont = "HYPixel-11px-U"
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                AsideBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topBar.padding(.top, DeviceLayout.headerTopPadding)
                    crtScreen(geo: geo)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                    Spacer(minLength: 4)
                    controlPad
                        .padding(.horizontal, 12)
                        .padding(.bottom, DeviceLayout.playerBottomPadding)
                }
                
                // CRT 扫描线 + 暗角
                scanlineOverlay.ignoresSafeArea().allowsHitTesting(false)
                crtVignette.ignoresSafeArea().allowsHitTesting(false)
                
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .opacity(isAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { isAppeared = true }
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                if song.isQQMusic, let mid = song.qqMid {
                    lyricVM.fetchQQLyrics(mid: mid, songId: song.id)
                } else { lyricVM.fetchLyrics(for: song.id) }
            }
            startBlink()
            startSpectrumAnimation()
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality, currentKugouQuality: player.kugouQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectKugou: { q in player.switchKugouQuality(q); showQualitySheet = false },
                onSelectQQ: { q in player.switchQQMusicQuality(q); showQualitySheet = false }
            ).presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEQSettings) {
            NavigationStack { EQSettingsView() }.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showThemePicker) {
            PlayerThemePickerSheet().presentationDetents([.medium]).presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showComments) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                           songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
                .presentationDetents([.large]).presentationDragIndicator(.hidden)
            }
        }
    }
    
    private func startBlink() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                blinkOn.toggle()
            }
        }
    }
    
    /// 模拟像素频谱动画
    private func startSpectrumAnimation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                if player.isPlaying {
                    withAnimation(.linear(duration: 0.1)) {
                        for i in 0..<spectrumLevels.count {
                            let base = CGFloat.random(in: 0.1...0.9)
                            // 中间频段更高
                            let center = CGFloat(spectrumLevels.count) / 2
                            let dist = abs(CGFloat(i) - center) / center
                            spectrumLevels[i] = base * (1.0 - dist * 0.4)
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        for i in 0..<spectrumLevels.count {
                            spectrumLevels[i] = max(spectrumLevels[i] - 0.15, 0)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 顶栏
extension PixelPlayerLayout {
    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                pixelButton(icon: .chevronRight, rotation: 90)
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.custom(pixelFont, size: 14))
                    .foregroundColor(fg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .asideGlass(cornerRadius: 0)
                    .overlay(Rectangle().stroke(fg.opacity(0.5), lineWidth: 2))
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            if let info = player.streamInfo {
                Text(streamInfoText(info))
                    .font(.custom(pixelFont, size: 10))
                    .foregroundColor(fgDim)
            }
            
            Spacer()
            
            Button(action: { withAnimation { showMoreMenu.toggle() } }) {
                pixelButton(icon: .more)
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
    
    private func pixelButton(icon: AsideIcon.IconType, rotation: Double = 0) -> some View {
        Color.clear
            .frame(width: 36, height: 36)
            .asideGlass(cornerRadius: 0)
            .overlay(Rectangle().stroke(fg.opacity(0.5), lineWidth: 2))
            .overlay(
                AsideIcon(icon: icon, size: 16, color: fg)
                    .rotationEffect(.degrees(rotation))
            )
            .contentShape(Rectangle())
    }
}

// MARK: - CRT 屏幕
extension PixelPlayerLayout {
    private func crtScreen(geo: GeometryProxy) -> some View {
        let screenW = geo.size.width - 24
        
        return VStack(spacing: 0) {
            if showLyrics {
                lyricsScreen(width: screenW)
            } else {
                mainScreen(width: screenW)
            }
        }
        .background(screenBg)
        .overlay(
            ZStack {
                // 外框 — 像素双层边框
                Rectangle().stroke(fg.opacity(0.7), lineWidth: 3)
                Rectangle().stroke(fg.opacity(0.15), lineWidth: 1).padding(4)
                // 四角高光点
                cornerDots
            }
        )
        .clipShape(Rectangle())
    }
    
    /// 四角像素高光点
    private var cornerDots: some View {
        GeometryReader { geo in
            let s: CGFloat = 4
            let inset: CGFloat = 6
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(fg.opacity(0.5))
                    .frame(width: s, height: s)
                    .position(
                        x: i % 2 == 0 ? inset : geo.size.width - inset,
                        y: i < 2 ? inset : geo.size.height - inset
                    )
            }
        }
    }
    
    // MARK: 主屏幕
    private func mainScreen(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            statusBar(width: width)
            
            pixelArtwork(width: width)
                .onTapWithHaptic {
                    withAnimation(.easeInOut(duration: 0.1)) { showLyrics = true }
                }
            
            // 像素频谱
            pixelSpectrum(width: width - 24)
                .padding(.horizontal, 12)
            
            songInfoBar
            
            pixelProgressBar(width: width - 24)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            
            timeDisplay.padding(.bottom, 6)
        }
    }
    
    /// 游戏化状态栏 HUD
    private func statusBar(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // 播放状态
            HStack(spacing: 4) {
                Rectangle()
                    .fill(player.isPlaying ? pixelGreen : pixelRed)
                    .frame(width: 6, height: 6)
                Text(player.isPlaying ? "PLAY" : "STOP")
                    .font(.custom(pixelFont, size: 10))
                    .foregroundColor(fg)
            }
            
            Spacer()
            
            // 播放模式
            Text(modeText)
                .font(.custom(pixelFont, size: 10))
                .foregroundColor(accent)
            
            Spacer()
            
            // LV + EXP 条
            HStack(spacing: 4) {
                Text("LV\(levelValue)")
                    .font(.custom(pixelFont, size: 10))
                    .foregroundColor(pixelYellow)
                
                // EXP 小条 — 用播放进度
                HStack(spacing: 1) {
                    ForEach(0..<6, id: \.self) { i in
                        Rectangle()
                            .fill(i < expFilled ? pixelYellow : fg.opacity(0.12))
                            .frame(width: 4, height: 6)
                    }
                }
            }
            
            Spacer()
            
            // HP
            HStack(spacing: 3) {
                Circle()
                    .fill(blinkOn && player.isPlaying ? pixelRed : pixelRed.opacity(0.2))
                    .frame(width: 5, height: 5)
                Text("HP:\(hpValue)")
                    .font(.custom(pixelFont, size: 10))
                    .foregroundColor(fg)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(fg.opacity(0.08))
    }
    
    private var modeText: String {
        switch player.mode {
        case .sequence: return "SEQ"
        case .loopSingle: return "RPT"
        case .shuffle: return "RND"
        }
    }
    
    private var hpValue: String {
        let hp = player.duration > 0 ? Int((1 - player.currentTime / player.duration) * 99) + 1 : 99
        return String(format: "%02d", max(1, min(99, hp)))
    }
    
    /// LV 值 — 根据播放时长模拟
    private var levelValue: Int {
        min(99, max(1, Int(player.currentTime / 30) + 1))
    }
    
    /// EXP 填充格数
    private var expFilled: Int {
        guard player.duration > 0 else { return 0 }
        return Int((player.currentTime / player.duration) * 6)
    }
    
    /// 像素化封面 + RGB 子像素偏移
    private func pixelArtwork(width: CGFloat) -> some View {
        let artSize = min(width - 40, 200.0)
        
        return ZStack {
            if let url = player.currentSong?.coverUrl {
                PixelatedImageView(
                    url: url.sized(500),
                    pixelScale: 6,
                    size: artSize
                )
            } else {
                pixelPlaceholder(size: artSize)
            }
            
            // 像素网格叠加
            pixelGrid(size: artSize)
                .allowsHitTesting(false)
        }
        .frame(width: artSize, height: artSize)
        .overlay(Rectangle().stroke(fg.opacity(0.3), lineWidth: 2))
        .padding(.vertical, 8)
    }
    
    /// 像素网格
    private func pixelGrid(size: CGFloat) -> some View {
        Canvas { ctx, canvasSize in
            let step: CGFloat = 4
            for y in stride(from: 0, to: canvasSize.height, by: step) {
                ctx.fill(
                    Path(CGRect(x: 0, y: y + step - 1, width: canvasSize.width, height: 0.5)),
                    with: .color(Color.black.opacity(0.15))
                )
            }
            for x in stride(from: 0, to: canvasSize.width, by: step) {
                ctx.fill(
                    Path(CGRect(x: x + step - 1, y: 0, width: 0.5, height: canvasSize.height)),
                    with: .color(Color.black.opacity(0.1))
                )
            }
        }
        .frame(width: size, height: size)
    }
    
    private func pixelPlaceholder(size: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(screenBg)
            // 像素音符图案
            Canvas { ctx, canvasSize in
                let s: CGFloat = 8
                let cx = canvasSize.width / 2
                let cy = canvasSize.height / 2
                // 简单的像素音符
                let blocks: [(CGFloat, CGFloat)] = [
                    (0, 0), (0, -1), (0, -2), (0, -3), (0, -4),
                    (1, -4), (2, -4), (2, -3),
                    (-1, 0), (-1, 1), (0, 1)
                ]
                for (bx, by) in blocks {
                    ctx.fill(
                        Path(CGRect(x: cx + bx * s, y: cy + by * s, width: s, height: s)),
                        with: .color(fg.opacity(0.2))
                    )
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
    
    /// 像素频谱可视化
    private func pixelSpectrum(width: CGFloat) -> some View {
        let barCount = spectrumLevels.count
        let barW = (width - CGFloat(barCount - 1) * 2) / CGFloat(barCount)
        let maxH: CGFloat = 24
        
        return HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let level = spectrumLevels[i]
                let h = max(2, level * maxH)
                // 颜色根据高度变化：低=绿 中=黄 高=红
                let barColor: Color = level > 0.75 ? pixelRed : (level > 0.5 ? pixelOrange : fg)
                
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(barColor)
                        .frame(width: barW, height: h)
                }
                .frame(height: maxH)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// 歌曲信息
    private var songInfoBar: some View {
        VStack(spacing: 4) {
            MarqueeText(
                text: player.currentSong?.name ?? "NO DATA",
                font: .custom(pixelFont, size: 18),
                color: fg,
                speed: 30,
                alignment: .center
            )
            .frame(height: 24)
            
            Text(player.currentSong?.artistName ?? "UNKNOWN")
                .font(.custom(pixelFont, size: 12))
                .foregroundColor(accent)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
    }
    
    /// 像素进度条 — 方块填充 + 闪烁指示器
    private func pixelProgressBar(width: CGFloat) -> some View {
        let totalBlocks = 20
        let progress = player.duration > 0
            ? (isDragging ? dragValue : player.currentTime) / player.duration
            : 0
        let filledBlocks = Int(progress * Double(totalBlocks))
        
        return GeometryReader { barGeo in
            HStack(spacing: 2) {
                ForEach(0..<totalBlocks, id: \.self) { i in
                    let isFilled = i < filledBlocks
                    let isCurrent = i == filledBlocks && filledBlocks < totalBlocks
                    
                    Rectangle()
                        .fill(
                            isFilled ? fg :
                            (isCurrent && blinkOn ? fg.opacity(0.6) : fg.opacity(0.1))
                        )
                        .frame(height: 10)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragValue = min(max(value.location.x / barGeo.size.width, 0), 1) * player.duration
                    }
                    .onEnded { value in
                        isDragging = false
                        player.seek(to: min(max(value.location.x / barGeo.size.width, 0), 1) * player.duration)
                    }
            )
        }
        .frame(height: 10)
    }
    
    private var timeDisplay: some View {
        HStack {
            Text(formatTime(isDragging ? dragValue : player.currentTime))
                .font(.custom(pixelFont, size: 14))
                .foregroundColor(fg)
            Spacer()
            Text(formatTime(player.duration))
                .font(.custom(pixelFont, size: 14))
                .foregroundColor(fgDim)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - 歌词屏幕
extension PixelPlayerLayout {
    private func lyricsScreen(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 歌词顶栏
            HStack {
                HStack(spacing: 4) {
                    Rectangle().fill(accent).frame(width: 6, height: 6)
                    Text("LYRICS")
                        .font(.custom(pixelFont, size: 14))
                        .foregroundColor(accent)
                }
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) { showLyrics = false }
                }) {
                    HStack(spacing: 4) {
                        Text("[ESC]")
                            .font(.custom(pixelFont, size: 10))
                            .foregroundColor(fgDim)
                        Text("BACK")
                            .font(.custom(pixelFont, size: 12))
                            .foregroundColor(fg)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(fg.opacity(0.1))
                    .overlay(Rectangle().stroke(fg.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fg.opacity(0.08))
            
            // 分隔线 — 像素虚线
            HStack(spacing: 3) {
                ForEach(0..<Int(width / 6), id: \.self) { _ in
                    Rectangle().fill(fg.opacity(0.2)).frame(width: 3, height: 1)
                }
            }
            
            // 歌词内容
            if lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            Color.clear.frame(height: 20)
                            ForEach(Array(lyricVM.lyrics.enumerated()), id: \.offset) { index, line in
                                let isCurrent = index == lyricVM.currentLineIndex
                                let isPast = index < lyricVM.currentLineIndex
                                
                                HStack(spacing: 0) {
                                    // 行号
                                    Text(String(format: "%02d", index + 1))
                                        .font(.custom(pixelFont, size: 9))
                                        .foregroundColor(fg.opacity(0.15))
                                        .frame(width: 20, alignment: .trailing)
                                    
                                    // 指示符
                                    Text(isCurrent ? (blinkOn ? "> " : "  ") : "  ")
                                        .font(.custom(pixelFont, size: 16))
                                        .foregroundColor(accent)
                                        .frame(width: 20)
                                    
                                    Text(line.text)
                                        .font(.custom(pixelFont, size: isCurrent ? 16 : 13))
                                        .foregroundColor(
                                            isCurrent ? fg :
                                            (isPast ? fgDim : fg.opacity(0.25))
                                        )
                                        .multilineTextAlignment(.leading)
                                        .shadow(
                                            color: isCurrent ? fg.opacity(0.3) : .clear,
                                            radius: isCurrent ? 4 : 0
                                        )
                                    Spacer()
                                }
                                .id(index)
                                .onTapWithHaptic { player.seek(to: line.time) }
                            }
                            Color.clear.frame(height: 60)
                        }
                        .padding(.horizontal, 8)
                    }
                    .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                        withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                    }
                    .onAppear {
                        proxy.scrollTo(lyricVM.currentLineIndex, anchor: .center)
                    }
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Text("NO LYRICS DATA")
                        .font(.custom(pixelFont, size: 16))
                        .foregroundColor(fgDim)
                    Text("TAP TO GO BACK")
                        .font(.custom(pixelFont, size: 11))
                        .foregroundColor(fgDim.opacity(0.5))
                }
                .onTapWithHaptic {
                    withAnimation(.easeInOut(duration: 0.1)) { showLyrics = false }
                }
                Spacer()
            }
            
            // 底部频谱 + 进度
            pixelSpectrum(width: width - 24)
                .padding(.horizontal, 12)
            pixelProgressBar(width: width - 24)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 控制面板
extension PixelPlayerLayout {
    private var controlPad: some View {
        VStack(spacing: 10) {
            // 主控制行
            HStack(spacing: 20) {
                Button(action: { player.previous() }) {
                    pixelControlButton {
                        AsideIcon(icon: .previous, size: 20, color: fg)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                // 播放/暂停 — 大按钮，带像素阴影
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        // 阴影层
                        Rectangle()
                            .fill(fg.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .offset(x: 3, y: 3)
                        // 外框
                        Rectangle()
                            .fill(fg)
                            .frame(width: 60, height: 60)
                        // 内框
                        Rectangle()
                            .fill(screenBg)
                            .frame(width: 54, height: 54)
                        
                        if player.isLoading {
                            // 像素加载动画
                            HStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { i in
                                    Rectangle()
                                        .fill(fg.opacity(blinkOn && i % 2 == 0 ? 1 : 0.3))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        } else {
                            AsideIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 26, color: fg
                            )
                            .offset(x: player.isPlaying ? 0 : 2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                Button(action: { player.next() }) {
                    pixelControlButton {
                        AsideIcon(icon: .next, size: 20, color: fg)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            
            // 功能行
            HStack(spacing: 0) {
                funcButton(icon: player.mode.asideIcon) { player.switchMode() }
                Spacer()
                if let song = player.currentSong {
                    LikeButton(songId: song.id, isQQMusic: song.isQQMusic, size: 16, activeColor: pixelRed, inactiveColor: fg)
                        .frame(width: 40, height: 36)
                }
                Spacer()
                funcButton(icon: .comment) { showComments = true }
                Spacer()
                if let song = player.currentSong {
                    funcButton(
                        icon: .playerDownload,
                        tint: downloadManager.isDownloaded(songId: song.id) ? accent : fg
                    ) {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            if song.isQQMusic {
                                downloadManager.downloadQQ(song: song, quality: player.qqMusicQuality)
                            } else {
                                downloadManager.download(song: song, quality: player.soundQuality)
                            }
                        }
                    }
                }
                Spacer()
                funcButton(icon: .list) { showPlaylist = true }
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(
            ZStack {
                // 像素阴影
                Rectangle()
                    .fill(fg.opacity(0.1))
                    .offset(x: 3, y: 3)
                Rectangle()
                    .fill(screenBg.opacity(0.6))
                    .overlay(Rectangle().stroke(fg.opacity(0.3), lineWidth: 2))
            }
        )
    }
    
    private func pixelControlButton<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            // 像素阴影
            Rectangle()
                .fill(fg.opacity(0.15))
                .frame(width: 44, height: 44)
                .offset(x: 2, y: 2)
            Rectangle()
                .fill(fg.opacity(0.1))
                .frame(width: 44, height: 44)
            Rectangle()
                .stroke(fg.opacity(0.4), lineWidth: 2)
                .frame(width: 44, height: 44)
            content()
        }
        .contentShape(Rectangle())
    }
    
    private func funcButton(icon: AsideIcon.IconType, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(fg.opacity(0.05))
                    .frame(width: 40, height: 36)
                    .offset(x: 1, y: 1)
                AsideIcon(icon: icon, size: 16, color: tint ?? fg, lineWidth: 1.5)
                    .frame(width: 40, height: 36)
                    .background(fg.opacity(0.08))
                    .overlay(Rectangle().stroke(fg.opacity(0.2), lineWidth: 1))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }
}

// MARK: - CRT 效果
extension PixelPlayerLayout {
    /// 扫描线
    private var scanlineOverlay: some View {
        Canvas { ctx, size in
            let lineSpacing: CGFloat = 3
            for y in stride(from: 0, to: size.height, by: lineSpacing) {
                ctx.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(Color.black.opacity(colorScheme == .dark ? 0.07 : 0.025))
                )
            }
        }
    }
    
    /// CRT 暗角效果
    private var crtVignette: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.clear,
                Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08)
            ],
            center: .center,
            startRadius: 200,
            endRadius: 500
        )
    }
}

// MARK: - 辅助
extension PixelPlayerLayout {
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
        return parts.joined(separator: " ")
    }
}
