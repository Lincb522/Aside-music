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

    // 配色 — 自适应深浅模式
    private var bgColor: Color {
        colorScheme == .dark ? Color(hex: "0B1A2B") : Color.white
    }
    private var waterTop: Color {
        colorScheme == .dark ? Color(hex: "1E6091") : Color(hex: "7DD3FC")
    }
    private var waterMid: Color {
        colorScheme == .dark ? Color(hex: "1A5276") : Color(hex: "38BDF8")
    }
    private var waterBot: Color {
        colorScheme == .dark ? Color(hex: "154360") : Color(hex: "0EA5E9")
    }
    private var bubbleColor: Color {
        colorScheme == .dark ? Color(hex: "2980B9") : Color(hex: "BAE6FD")
    }
    private var accentColor: Color {
        colorScheme == .dark ? Color(hex: "5DADE2") : Color(hex: "0EA5E9")
    }
    private var textPrimary: Color {
        colorScheme == .dark ? Color(hex: "E2E8F0") : Color(hex: "0F172A")
    }
    private var textMuted: Color {
        colorScheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B")
    }
    private var btnBgColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var progress: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(max((isDragging ? dragValue : player.currentTime) / player.duration, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let waterY = geo.size.height * (0.82 - progress * 0.65)
            ZStack {
                bgColor.ignoresSafeArea()

                // 水体 + 波浪
                cartoonWater(size: geo.size, waterY: waterY)
                    .allowsHitTesting(false)

                // 气泡
                cartoonBubbles(size: geo.size, waterY: waterY)
                    .allowsHitTesting(false)

                // 内容
                VStack(spacing: 0) {
                    topBar.padding(.top, DeviceLayout.headerTopPadding)

                    if showLyrics {
                        lyricsContent.transition(.opacity)
                    } else {
                        Spacer()
                        songInfoArea
                            .padding(.bottom, 24)
                        controls
                            .padding(.bottom, 12)
                        timeAndProgress(width: geo.size.width)
                            .padding(.bottom, DeviceLayout.playerBottomPadding)
                    }
                }

                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showLyrics)
        }
        .onAppear { loadLyricsIfNeeded() }
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

    /// 扁平化水体：两层圆润正弦波 + 渐变填充
    private func cartoonWater(size: CGSize, waterY: CGFloat) -> some View {
        TimelineView(.animation(paused: !player.isPlaying)) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
            Canvas { ctx, cs in
                // 后层波浪 — 大振幅慢速
                let backPath = wavePath(width: cs.width, height: cs.height,
                                        waterY: waterY, t: t,
                                        amp: 18, freq: 1.0, speed: 0.5, phase: 0)
                let backGrad = Gradient(colors: [waterMid.opacity(0.5), waterBot.opacity(0.7)])
                ctx.fill(backPath, with: .linearGradient(
                    backGrad,
                    startPoint: CGPoint(x: cs.width / 2, y: waterY),
                    endPoint: CGPoint(x: cs.width / 2, y: cs.height)
                ))

                // 前层波浪 — 小振幅快速
                let frontPath = wavePath(width: cs.width, height: cs.height,
                                         waterY: waterY + 8, t: t,
                                         amp: 12, freq: 1.6, speed: 0.8, phase: 1.5)
                let frontGrad = Gradient(colors: [waterTop.opacity(0.6), waterMid.opacity(0.5)])
                ctx.fill(frontPath, with: .linearGradient(
                    frontGrad,
                    startPoint: CGPoint(x: cs.width / 2, y: waterY),
                    endPoint: CGPoint(x: cs.width / 2, y: cs.height)
                ))

                // 水面高光线
                let hlPath = waveLinePath(width: cs.width, waterY: waterY, t: t,
                                          amp: 18, freq: 1.0, speed: 0.5, phase: 0)
                ctx.stroke(hlPath, with: .color(Color.white.opacity(0.35)), lineWidth: 2)
            }
        }
        .ignoresSafeArea()
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

    /// 柔和的卡通气泡 — 缓慢上浮，顶部渐隐底部渐显，无跳变
    private func cartoonBubbles(size: CGSize, waterY: CGFloat) -> some View {
        TimelineView(.animation(paused: !player.isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, cs in
                let count = 5
                let bottom = Double(cs.height + 20)
                let top = Double(waterY - 10)
                guard bottom > top else { return }
                let range = bottom - top

                for i in 0..<count {
                    let fi = Double(i)
                    // 极慢上浮，每个气泡不同周期
                    let period = 25.0 + fi * 8.0
                    let phase = fi * period / Double(count)
                    let cycleT = (t + phase).truncatingRemainder(dividingBy: period)
                    let normalizedPos = cycleT / period  // 0~1，0=底部 1=顶部

                    let cy = CGFloat(bottom - normalizedPos * range)

                    let baseX = cs.width * CGFloat(0.15 + fi * 0.16)
                    let wobble = sin(t * 0.25 + fi * 1.2) * 3
                    let cx = baseX + CGFloat(wobble)
                    let r = CGFloat(5 + fi * 1.2)

                    // 底部 10% 渐显，顶部 15% 渐隐
                    var alpha = 1.0
                    if normalizedPos < 0.1 {
                        alpha = normalizedPos / 0.1
                    } else if normalizedPos > 0.85 {
                        alpha = (1.0 - normalizedPos) / 0.15
                    }
                    alpha = max(alpha, 0)

                    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                    ctx.fill(Circle().path(in: rect), with: .color(bubbleColor.opacity(0.1 * alpha)))
                    ctx.stroke(Circle().path(in: rect), with: .color(bubbleColor.opacity(0.2 * alpha)), lineWidth: 0.8)

                    let hlR = r * 0.25
                    let hlRect = CGRect(x: cx - r * 0.3, y: cy - r * 0.35, width: hlR, height: hlR)
                    ctx.fill(Circle().path(in: hlRect), with: .color(Color.white.opacity(0.3 * alpha)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 顶栏

extension AquaPlayerLayout {

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                AsideIcon(icon: .close, size: 18, color: textPrimary)
                    .frame(width: 36, height: 36)
                    .background(btnBgColor)
                    .clipShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(btnBgColor))
            }
            .buttonStyle(AsideBouncingButtonStyle())

            if let info = player.streamInfo {
                Text(streamInfoText(info))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(textMuted)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.1)) { showMoreMenu.toggle() }
            }) {
                AsideIcon(icon: .more, size: 18, color: textPrimary)
                    .frame(width: 36, height: 36)
                    .background(btnBgColor)
                    .clipShape(Circle())
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
            // 歌名 — 超大字，居中，字间距拉开
            Text(player.currentSong?.name ?? "")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(textPrimary)
                .tracking(1)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            // 歌手 — 水色胶囊标签
            if let artist = player.currentSong?.artistName, !artist.isEmpty {
                Text(artist)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(accentColor.opacity(0.08))
                    )
            }
        }
        .padding(.horizontal, 32)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showLyrics = true
            }
        }
    }
}

// MARK: - 歌词

extension AquaPlayerLayout {

    private var lyricsContent: some View {
        ZStack {
            if let song = player.currentSong {
                LyricsView(song: song, onBackgroundTap: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showLyrics = false
                    }
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
                AsideIcon(icon: .previous, size: 20, color: textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放按钮 — 涟漪
            Button(action: {
                rippleTrigger.toggle()
                player.togglePlayPause()
            }) {
                ZStack {
                    // 涟漪圈
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                        .scaleEffect(rippleTrigger ? 1.6 : 1.0)
                        .opacity(rippleTrigger ? 0 : 0.4)
                        .animation(.easeOut(duration: 0.6), value: rippleTrigger)

                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 60, height: 60)
                        .overlay(Circle().stroke(accentColor.opacity(0.25), lineWidth: 1.5))

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: textPrimary))
                    } else {
                        AsideIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 24, color: textPrimary
                        )
                        .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 20, color: textPrimary)
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

// MARK: - 时间 + 进度

extension AquaPlayerLayout {

    private func timeAndProgress(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            // 进度条 — 圆角胶囊，水色填充
            GeometryReader { barGeo in
                let bw = barGeo.size.width
                let fillW = max(4, bw * progress)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(btnBgColor)
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [waterTop, waterMid],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillW, height: 4)

                    Circle()
                        .fill(colorScheme == .dark ? Color(hex: "1E293B") : Color.white)
                        .frame(width: isDragging ? 14 : 6, height: isDragging ? 14 : 6)
                        .shadow(color: accentColor.opacity(0.4), radius: 4)
                        .offset(x: max(0, fillW - 3))
                        .animation(.spring(response: 0.2), value: isDragging)
                }
                .contentShape(Rectangle().inset(by: -20))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            isDragging = true
                            dragValue = min(max(Double(v.location.x / bw), 0), 1) * player.duration
                        }
                        .onEnded { v in
                            isDragging = false
                            player.seek(to: min(max(Double(v.location.x / bw), 0), 1) * player.duration)
                        }
                )
            }
            .frame(height: 14)

            // 时间
            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(textMuted)
                Spacer()
                Text(formatTime(player.duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(textMuted.opacity(0.6))
            }
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
