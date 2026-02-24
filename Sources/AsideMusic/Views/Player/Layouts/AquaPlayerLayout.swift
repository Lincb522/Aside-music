import SwiftUI
import FFmpegSwiftSDK

/// 水韵播放器 — 动画风格，纯色背景 + 卡通水波 + 圆润气泡
/// 没有封面，整个界面是一杯水的动画表现
/// 水位 = 播放进度，气泡随音乐上浮
struct AquaPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
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
    @State private var showLyrics = false
    @State private var rippleTrigger = false

    /// 文道泡泡体 — 与水韵卡通气泡风格高度契合
    private let bubbleFont = "WDPPT"

    // 纯正的动画风配色（高饱和、无通透感）
    private var bgColor: Color {
        // 背景改为极浅的蓝，而不是突兀的纯白（亮色模式），深色模式下为深藏青色
        colorScheme == .dark ? Color(hex: "081020") : Color(hex: "E0F2FE")
    }
    private var waterBack: Color {
        colorScheme == .dark ? Color(hex: "1E3A8A") : Color(hex: "60A5FA") // 深海蓝
    }
    private var waterMid: Color {
        colorScheme == .dark ? Color(hex: "2563EB") : Color(hex: "3B82F6") // 明亮蓝
    }
    private var waterFront: Color {
        colorScheme == .dark ? Color(hex: "3B82F6") : Color(hex: "0EA5E9") // 浅水蓝
    }
    private var bubbleColor: Color {
        Color.white.opacity(0.4) // 半透明白框气泡
    }
    private var accentColor: Color {
        colorScheme == .dark ? Color(hex: "60A5FA") : Color(hex: "2563EB")
    }
    private var textPrimary: Color {
        colorScheme == .dark ? Color.white : Color(hex: "0F172A")
    }
    private var textMuted: Color {
        colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B")
    }
    private var btnBgColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    // 气泡破裂特效存储池
    @State private var poppedBubbles: [UUID: CGPoint] = [:]
    // 文字呼吸浮动动效
    @State private var textFloatOffset: CGFloat = 0

    private var progress: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(max((isDragging ? dragValue : player.currentTime) / player.duration, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            // 水位计算：根据不包含安全区的核心内容高度的比例
            let ratio = CGFloat(0.80 - progress * 0.50)
            
            ZStack {
                // 1. 全屏卡通背景层
                ZStack {
                    bgColor
                    cartoonWater(waterRatio: ratio)
                        .allowsHitTesting(false)
                    
                    cartoonBubbles(waterRatio: ratio)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()

                // 2. 界面内容层 (受制于安全区)
                VStack(spacing: 0) {
                    topBar.padding(.top, DeviceLayout.headerTopPadding)

                    // 歌曲信息和歌词完全整合在中间
                    VStack(spacing: 16) {
                        songInfoArea
                            .padding(.top, 24)
                        
                        lyricsContent
                    }

                    Spacer()

                    controls
                        .padding(.bottom, DeviceLayout.playerBottomPadding + 20)
                }
                
                // 更多菜单浮层
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showLyrics)
        .fontDesign(nil) // 重置全局 .rounded，让泡泡体自定义字体生效
        }
        .onAppear { 
            loadLyricsIfNeeded() 
            // 启动文字呼吸漂浮动画
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                textFloatOffset = -8
            }
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

    private func loadLyricsIfNeeded() {
        if let song = player.currentSong, lyricVM.currentSongId != song.id {
            if song.isQQMusic, let mid = song.qqMid {
                lyricVM.fetchQQLyrics(mid: mid, songId: song.id)
            } else {
                lyricVM.fetchLyrics(for: song.id)
            }
        }
    }
}

// MARK: - 卡通水体

extension AquaPlayerLayout {

    /// 纯正卡通水体：三层波浪，纯色填充，无渐变，带高光轮廓描边
    private func cartoonWater(waterRatio: CGFloat) -> some View {
        TimelineView(.animation(paused: !player.isPlaying)) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
            Canvas { ctx, cs in
                let waterY = cs.height * waterRatio
                
                // --------- 最底层波浪 (Back) ---------
                let backPath = wavePath(width: cs.width, height: cs.height,
                                        waterY: waterY - 10, t: t,
                                        amp: 24, freq: 0.8, speed: 0.4, phase: 0)
                ctx.fill(backPath, with: .color(waterBack))
                
                // --------- 中间层波浪 (Mid) ---------
                let midPath = wavePath(width: cs.width, height: cs.height,
                                       waterY: waterY + 5, t: t,
                                       amp: 18, freq: 1.2, speed: 0.7, phase: 2)
                ctx.fill(midPath, with: .color(waterMid))
                
                // --------- 最前层波浪 (Front) ---------
                let frontPath = wavePath(width: cs.width, height: cs.height,
                                         waterY: waterY + 15, t: t,
                                         amp: 14, freq: 1.5, speed: 1.0, phase: 1)
                ctx.fill(frontPath, with: .color(waterFront))

                // 卡通轮廓高光（实线细描边），增强 2D 动画感
                let frontHighlight = waveLinePath(width: cs.width, waterY: waterY + 15, t: t,
                                                  amp: 14, freq: 1.5, speed: 1.0, phase: 1)
                ctx.stroke(frontHighlight, with: .color(.white.opacity(0.6)), lineWidth: 3)
                
                let midHighlight = waveLinePath(width: cs.width, waterY: waterY + 5, t: t,
                                                  amp: 18, freq: 1.2, speed: 0.7, phase: 2)
                ctx.stroke(midHighlight, with: .color(.white.opacity(0.3)), lineWidth: 2)
            }
        }
        .drawingGroup() // 开启抗锯齿
    }

    private func wavePath(width: CGFloat, height: CGFloat, waterY: CGFloat,
                           t: CGFloat, amp: CGFloat, freq: CGFloat,
                           speed: CGFloat, phase: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: height))
        for x in stride(from: CGFloat(0), through: width, by: 4) {
            let n = x / width
            let y = waterY + sin(n * .pi * 2 * freq + t * speed + phase) * amp
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }

    private func waveLinePath(width: CGFloat, waterY: CGFloat, t: CGFloat,
                               amp: CGFloat, freq: CGFloat,
                               speed: CGFloat, phase: CGFloat) -> Path {
        var path = Path()
        var started = false
        for x in stride(from: CGFloat(0), through: width, by: 4) {
            let n = x / width
            let y = waterY + sin(n * .pi * 2 * freq + t * speed + phase) * amp
            if !started { path.move(to: CGPoint(x: x, y: y)); started = true }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

// MARK: - 卡通气泡

extension AquaPlayerLayout {

    /// 卡通气泡 — 实体描边，侧边月牙高光，破裂特效
    private func cartoonBubbles(waterRatio: CGFloat) -> some View {
        TimelineView(.animation(paused: !player.isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, cs in
                let waterY = cs.height * waterRatio
                let count = 8
                let bottom = Double(cs.height + 40)
                let top = Double(waterY)
                guard bottom > top else { return }
                let range = bottom - top

                for i in 0..<count {
                    let fi = Double(i)
                    // 上浮周期
                    let period = 15.0 + fi * 6.0
                    let phase = fi * period / Double(count)
                    let cycleT = (t + phase).truncatingRemainder(dividingBy: period)
                    let normalizedPos = cycleT / period 
                    
                    // 动态弹跳上浮 (水流中之字形摆动)
                    let cy = CGFloat(bottom - normalizedPos * range)
                    let baseX = cs.width * CGFloat(0.1 + fi * 0.12)
                    let wobble = sin(t * 1.5 + fi * 2.0) * (20.0 + fi * 2.0)
                    let cx = baseX + CGFloat(wobble)
                    
                    // 随着上升水压减小气泡变大
                    let r = CGFloat(4 + fi * 1.5) + CGFloat(normalizedPos * 4.0)

                    // 如果快到水面了，触发破裂效果 (隐藏实体并画放射线)
                    if normalizedPos > 0.95 {
                        let popScale = CGFloat((normalizedPos - 0.95) / 0.05) // 0 to 1
                        ctx.stroke(Circle().path(in: CGRect(x: cx - r * (1 + popScale), y: cy - r * (1 + popScale), width: r * 2 * (1 + popScale), height: r * 2 * (1 + popScale))), with: .color(bubbleColor.opacity(1.0 - popScale)), lineWidth: 2)
                        continue
                    }

                    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                    
                    // 气泡轮廓 (实色实心白点或空心圆，完全扁平无光泽)
                    ctx.stroke(Circle().path(in: rect), with: .color(bubbleColor), lineWidth: 2)
                }
            }
        }
        .ignoresSafeArea()
        .drawingGroup() // 开启抗锯齿
    }
}

// MARK: - 顶栏

extension AquaPlayerLayout {

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                AsideIcon(icon: .close, size: 18, color: textPrimary)
                    .frame(width: 36, height: 36)
                    .asideGlassCircle()
                    .contentShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.custom(bubbleFont, size: 11))
                    .foregroundColor(textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .asideGlass(cornerRadius: 15)
                    .contentShape(Capsule())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            if let info = player.streamInfo {
                Text(streamInfoText(info))
                    .font(.custom(bubbleFont, size: 10))
                    .foregroundColor(textMuted)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
            }) {
                AsideIcon(icon: .more, size: 18, color: textPrimary)
                    .frame(width: 36, height: 36)
                    .asideGlassCircle()
                    .contentShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - 歌曲信息

extension AquaPlayerLayout {

    private var songInfoArea: some View {
        VStack(spacing: 16) {
            // 歌名 — 泡泡体，与水韵卡通风格一致
            Text(player.currentSong?.name ?? "")
                .font(.custom(bubbleFont, size: 34))
                .foregroundColor(textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            // 歌手 — 卡通贴纸感标签（泡泡体）
            if let artist = player.currentSong?.artistName, !artist.isEmpty {
                HStack(spacing: 6) {
                    AsideIcon(icon: .sparkle, size: 14, color: .white)
                    Text(artist)
                        .font(.custom(bubbleFont, size: 15))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(accentColor)
                )
            }
        }
        .padding(.horizontal, 32)
        .offset(y: textFloatOffset)
        .contentShape(Rectangle())
    }
}

// MARK: - 歌词

extension AquaPlayerLayout {

    private var lyricsContent: some View {
        ZStack {
            if let song = player.currentSong {
                LyricsView(song: song, onBackgroundTap: {
                    // 歌词页面已整合，无需点击退出
                })
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 控制

extension AquaPlayerLayout {

    private var controls: some View {
        HStack(spacing: 0) {
            Button(action: { player.switchMode() }) {
                AsideIcon(icon: player.mode.asideIcon, size: 18, color: textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 22, color: textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放按钮 — Q弹物理拉伸
            Button(action: {
                // 触发极速 Q 弹反馈（夸张的形变）
                withAnimation(.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0)) {
                    rippleTrigger = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        rippleTrigger = false
                    }
                }
                player.togglePlayPause()
            }) {
                ZStack {
                    // 圆润的卡通色块，去除描边圈
                    Circle()
                        .fill(accentColor)
                        .frame(width: 64, height: 64)
                        // Q 弹形变动画
                        .scaleEffect(rippleTrigger ? 0.8 : 1.0)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        AsideIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 26, color: .white
                        )
                        .offset(x: player.isPlaying ? 0 : 2)
                        .scaleEffect(rippleTrigger ? 0.8 : 1.0)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle()) // 重点：去除默认点击框高亮，完全接管动画
            
            Spacer()

            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 22, color: textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Button(action: { showPlaylist = true }) {
                AsideIcon(icon: .list, size: 18, color: textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - 辅助

extension AquaPlayerLayout {

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
        return parts.joined(separator: " · ")
    }
}
