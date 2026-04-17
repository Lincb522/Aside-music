//
//  CosmosPlayerLayout.swift
//  Monologue
//
//  卡通宇宙主题 — 漫画风 + 漂浮宇航员 + 气泡歌词 + 火箭按钮。
//
//  灵感：
//   - 背景：深紫到深蓝渐变星空，散落星星、小行星，半透明卡通月亮。
//   - 主视觉：中左位置绘制一个卡通宇航员，随音乐轻微漂浮。
//     - 宇航员头盔为圆，内嵌歌曲封面作为"头盔里的世界"。
//     - 背包管伸向天线，天线顶端有小心心/音乐符号。
//   - 歌词：从宇航员旁边飘出漫画对话气泡，当前行气泡放大。
//   - 控件：播放/暂停为巨大的红色卡通火箭按钮；上一首下一首是左右小太空舱。
//

import SwiftUI

struct CosmosPlayerLayout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject var downloadManager = DownloadManager.shared

    // MARK: - Palette
    private var bgTop: Color { Color(hex: "1A1B3E") }
    private var bgMid: Color { Color(hex: "2D1E58") }
    private var bgBottom: Color { Color(hex: "4A2978") }
    private var accent: Color { Color(hex: "FF4A6B") }      // 火箭/高亮
    private var cream: Color { Color(hex: "FFF2D1") }        // 月亮/气泡边
    private var ink: Color { Color(hex: "2D2D3A") }
    private var pastel: Color { Color(hex: "A6D8FF") }       // 宇航员头盔蓝
    private var suit: Color { Color.white }
    private var bubbleBg: Color { Color.white.opacity(0.96) }
    private var line: Color { Color.black.opacity(0.85) }

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
                cosmosBackground(size: size)
                    .ignoresSafeArea()

                // 1. 顶栏（返回 + 落款）
                topBar(size: size)

                // 2. 宇航员（随播放状态漂浮）
                astronaut(size: size)

                // 3. 漫画歌词气泡
                lyricBubbles(size: size)

                // 4. 底部控件：火箭 + 太空舱 + 星际追踪进度
                bottomControls(size: size)

                // 5. 右上喜欢心
                if let song = player.currentSong {
                    likeHeart(song: song)
                        .position(x: size.width - 42, y: 62)
                }

                // 6. 更多菜单
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        isDarkBackground: true,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                    .frame(width: size.width, height: size.height, alignment: .center)
                }
            }
            .opacity(isAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { isAppeared = true }
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) { PlaylistPopupView() }
        .monologueSheet(isPresented: $showQualitySheet, preset: .compact) {
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
        .monologueSheet(isPresented: $showEQSettings, preset: .large) {
            NavigationStack { EQSettingsView() }
        }
        .monologueSheet(isPresented: $showThemePicker, preset: .compact) { PlayerThemePickerSheet() }
        .monologueSheet(isPresented: $showComments, preset: .large) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                            songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
            }
        }
        .monologueSheet(isPresented: $showArtistDetail, preset: .detail) {
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
        .monologueSheet(isPresented: $showDownloadSheet, preset: .compact) {
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) { showDownloadSheet = false }
            }
        }
    }
}

// MARK: - Background

extension CosmosPlayerLayout {

    func cosmosBackground(size: CGSize) -> some View {
        ZStack {
            // 简洁深紫背景（两段渐变）
            LinearGradient(
                colors: [bgTop, bgMid, bgBottom],
                startPoint: .top, endPoint: .bottom
            )

            // 点阵式小星星（Canvas 静态 + 少量闪烁）
            starfieldCanvas(size: size)
                .allowsHitTesting(false)

            // 简洁流星（拖尾纯色，偶尔划过）
            shootingStarsLayer(size: size)
                .allowsHitTesting(false)

            // 卡通漂浮装饰
            CosmosFloatingDecorations(size: size).equatable()
                .allowsHitTesting(false)
        }
    }

    /// 简单星点：圆点 + 零星十字星，偶尔闪烁
    @ViewBuilder
    private func starfieldCanvas(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { context, sz in
                var rng = CosmosSeed(seed: 0xC05_A1EC)

                // 基础星点
                let count = Int(sz.width * sz.height / 3800)
                for _ in 0..<count {
                    let x = rng.next(0...sz.width)
                    let y = rng.next(0...sz.height)
                    let r = rng.next(0.6...1.8)
                    let alpha = rng.next(0.45...0.9)
                    let rect = CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(.white.opacity(alpha)))
                }

                // 十字闪光：少量 5 颗，卡通四角星样式
                for i in 0..<5 {
                    let cx = rng.next(0...sz.width)
                    let cy = rng.next(0...sz.height * 0.8)
                    let phase = Double(i) * 1.3
                    let pulse = 0.55 + 0.45 * sin(t * 2.0 + phase)
                    let len: CGFloat = 6 + CGFloat(i % 2) * 2

                    var p = Path()
                    p.move(to: CGPoint(x: cx - len, y: cy))
                    p.addLine(to: CGPoint(x: cx + len, y: cy))
                    p.move(to: CGPoint(x: cx, y: cy - len))
                    p.addLine(to: CGPoint(x: cx, y: cy + len))
                    context.stroke(p,
                                   with: .color(.white.opacity(0.9 * pulse)),
                                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
            }
        }
    }

    /// 简单流星（纯白线条 + 点，卡通风）
    @ViewBuilder
    private func shootingStarsLayer(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { context, sz in
                for i in 0..<2 {
                    let period: Double = 7.5
                    let phase = Double(i) * 3.8
                    let cycle = (t.truncatingRemainder(dividingBy: period) + phase)
                        .truncatingRemainder(dividingBy: period)
                    let progress = CGFloat(cycle / period)

                    let visibleStart: CGFloat = 0.1
                    let visibleEnd: CGFloat = 0.7
                    guard progress > visibleStart, progress < visibleEnd else { continue }
                    let local = (progress - visibleStart) / (visibleEnd - visibleStart)
                    let alpha = sin(Double(local) * .pi) * 0.85

                    let startX = sz.width * (1.1 + CGFloat(i) * 0.1)
                    let startY = sz.height * (0.02 + CGFloat(i) * 0.1)
                    let endX = sz.width * (-0.1)
                    let endY = sz.height * (0.48 + CGFloat(i) * 0.1)
                    let x = startX + (endX - startX) * local
                    let y = startY + (endY - startY) * local

                    let tailLen: CGFloat = 100
                    let dx = endX - startX
                    let dy = endY - startY
                    let norm = max(sqrt(dx * dx + dy * dy), 1)
                    let ux = dx / norm
                    let uy = dy / norm
                    let tailStart = CGPoint(x: x - ux * tailLen, y: y - uy * tailLen)
                    let tailEnd = CGPoint(x: x, y: y)

                    var path = Path()
                    path.move(to: tailStart)
                    path.addLine(to: tailEnd)
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [.white.opacity(0), .white.opacity(alpha)]),
                            startPoint: tailStart,
                            endPoint: tailEnd
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )

                    // 流星头：小圆点
                    let headRect = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
                    context.fill(Path(ellipseIn: headRect),
                                 with: .color(.white.opacity(alpha)))
                }
            }
        }
    }
}

// MARK: - Top bar

extension CosmosPlayerLayout {
    @ViewBuilder
    func topBar(size: CGSize) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .top) {
                Button {
                    dismiss()
                } label: {
                    cartoonCircle(icon: .close, color: .white.opacity(0.9), size: 36)
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)

                Spacer()

                VStack(spacing: 2) {
                    Text("COSMIC RADIO")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(cream.opacity(0.95))
                    Text(player.currentSong?.name ?? "— Lost in Space —")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: accent.opacity(0.6), radius: 4)
                    Button {
                        showArtistDetail = true
                    } label: {
                        Text(player.currentSong?.artistName ?? "Unknown Pilot")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(pastel)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 220)

                Spacer()

                Button {
                    showMoreMenu.toggle()
                } label: {
                    cartoonCircle(icon: .more, color: .white.opacity(0.9), size: 36)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
            }
            .padding(.top, 50)
        }
        .frame(maxWidth: size.width, maxHeight: size.height, alignment: .top)
    }

    /// 卡通圆角按钮（黑色描边 + 内阴影，漫画风）
    @ViewBuilder
    private func cartoonCircle(icon: MonologueIcon.IconType, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .overlay(Circle().stroke(line, lineWidth: 1.8))
                .shadow(color: .black.opacity(0.35), radius: 3, x: 1, y: 2)
            MonologueIcon(icon: icon, size: size * 0.42, color: ink)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Astronaut

extension CosmosPlayerLayout {
    @ViewBuilder
    func astronaut(size: CGSize) -> some View {
        let floatAmount: CGFloat = player.isPlaying ? 10 : 3
        let center = CGPoint(x: size.width * 0.32, y: size.height * 0.42)

        TimelineView(.animation(minimumInterval: 0.033)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let dy = CGFloat(sin(t * 0.9)) * floatAmount
            let dx = CGFloat(cos(t * 0.6)) * 3
            let rot = CGFloat(sin(t * 0.7)) * 4

            ZStack {
                // 宇航员下方柔光阴影（伴随浮动同步缩放）
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.black.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 4, endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 18)
                    .scaleEffect(CGFloat(1 + sin(t * 0.9) * 0.08))
                    .opacity(0.55)
                    .offset(y: 132 - dy * 0.3)

                AstronautView(
                    helmetImageURL: player.currentSong?.coverUrl?.sized(400),
                    suit: suit,
                    helmet: pastel,
                    accent: accent,
                    lineColor: line,
                    cream: cream,
                    time: t
                )
                .frame(width: 200, height: 250)
                .rotationEffect(.degrees(Double(rot)))
                .offset(x: dx, y: dy)
            }
            .position(x: center.x, y: center.y)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Lyrics bubbles

extension CosmosPlayerLayout {
    @ViewBuilder
    func lyricBubbles(size: CGSize) -> some View {
        if lyricVM.hasLyrics && !lyricVM.lyrics.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 10) {
                        Color.clear.frame(height: 4)

                        ForEach(Array(lyricVM.lyrics.enumerated()), id: \.element.id) { index, line in
                            let isCurrent = index == lyricVM.currentLineIndex
                            let isPast = index < lyricVM.currentLineIndex
                            if !line.text.trimmingCharacters(in: .whitespaces).isEmpty {
                                lyricBubble(line: line, isCurrent: isCurrent, isPast: isPast)
                                    .id(index)
                                    .onTapGesture { player.seek(to: line.time) }
                            }
                        }

                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 20)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.1),
                            .init(color: .black, location: 0.9),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size.width * 0.62, height: size.height * 0.45)
                .position(x: size.width * 0.66, y: size.height * 0.42)
                .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(lyricVM.currentLineIndex, anchor: .center)
                }
            }
        } else {
            // 无词：显示"Transmission lost"气泡
            HStack(spacing: 4) {
                bubbleShape(text: "Transmission lost…", isCurrent: true)
            }
            .frame(width: size.width * 0.62)
            .position(x: size.width * 0.66, y: size.height * 0.42)
        }
    }

    @ViewBuilder
    private func lyricBubble(line: LyricLine, isCurrent: Bool, isPast: Bool) -> some View {
        bubbleShape(
            text: line.text,
            isCurrent: isCurrent,
            subtitle: line.translation,
            faded: isPast && !isCurrent
        )
        .scaleEffect(isCurrent ? 1.0 : 0.9)
        .opacity(isCurrent ? 1.0 : (isPast ? 0.7 : 0.55))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCurrent)
    }

    @ViewBuilder
    private func bubbleShape(text: String,
                             isCurrent: Bool,
                             subtitle: String? = nil,
                             faded: Bool = false) -> some View {
        let fillColor: Color = {
            if isCurrent { return cream }
            if faded { return Color.white.opacity(0.25) }
            return Color.white.opacity(0.75)
        }()

        VStack(alignment: .leading, spacing: 3) {
            Text(text)
                .font(.system(size: isCurrent ? 17 : 14,
                              weight: isCurrent ? .heavy : .semibold,
                              design: .rounded))
                .foregroundStyle(ink)
                .multilineTextAlignment(.leading)
            if let sub = subtitle, !sub.isEmpty, isCurrent {
                Text(sub)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.65))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            BubbleShape()
                .fill(fillColor)
        )
        .overlay(
            BubbleShape()
                .stroke(line, lineWidth: 1.6)
        )
        .shadow(color: .black.opacity(0.35), radius: 2, x: 2, y: 3)
    }
}

// MARK: - Bottom controls

extension CosmosPlayerLayout {
    @ViewBuilder
    func bottomControls(size: CGSize) -> some View {
        VStack(spacing: 16) {
            // 进度条：太空轨道 + 小飞船 thumb
            spaceTrackProgressBar(width: size.width - 48)
                .frame(height: 26)

            // 主控：左太空舱 / 火箭 / 右太空舱
            HStack(spacing: 24) {
                capsuleButton(icon: .previous) { player.previous() }

                rocketButton(size: 82)

                capsuleButton(icon: .next) { player.next() }
            }
            .frame(maxWidth: .infinity)

            // 副控：播放模式 / 列表 / 评论 / 下载
            HStack(spacing: 22) {
                miniButton(icon: modeIcon) { player.switchMode() }
                miniButton(icon: .comment) { showComments = true }
                if let song = player.currentSong {
                    miniButton(
                        icon: .download,
                        disabled: downloadManager.isDownloaded(songId: song.id)
                    ) {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            showDownloadSheet = true
                        }
                    }
                }
                miniButton(icon: .list) { showPlaylist = true }
                miniButton(icon: .soundQuality) { showQualitySheet = true }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var modeIcon: MonologueIcon.IconType {
        switch player.mode {
        case .sequence:    return .repeatMode
        case .loopSingle:  return .repeatOne
        case .shuffle:     return .shuffle
        }
    }

    @ViewBuilder
    private func capsuleButton(icon: MonologueIcon.IconType, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .overlay(Capsule().stroke(line, lineWidth: 1.8))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 2)
                MonologueIcon(icon: icon, size: 16, color: ink)
            }
            .frame(width: 56, height: 36)
        }
        .buttonStyle(CartoonPressStyle())
    }

    @ViewBuilder
    private func miniButton(icon: MonologueIcon.IconType,
                            disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(disabled ? Color.white.opacity(0.25) : Color.white.opacity(0.9))
                    .overlay(Circle().stroke(line, lineWidth: 1.4))
                    .shadow(color: .black.opacity(0.25), radius: 1.5, x: 1, y: 1.5)
                MonologueIcon(icon: icon, size: 14, color: disabled ? ink.opacity(0.5) : ink)
            }
            .frame(width: 36, height: 36)
        }
        .disabled(disabled)
        .buttonStyle(CartoonPressStyle())
    }

    @ViewBuilder
    private func rocketButton(size: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            player.togglePlayPause()
        } label: {
            RocketShape(isPlaying: player.isPlaying, bodyColor: accent, windowColor: pastel, lineColor: line, cream: cream)
                .frame(width: size, height: size * 1.1)
                .shadow(color: accent.opacity(0.6), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(CartoonPressStyle(strong: true))
    }

    /// 太空轨道 + 小火箭 thumb
    @ViewBuilder
    private func spaceTrackProgressBar(width: CGFloat) -> some View {
        let duration = timePublisher.duration
        let progress = duration > 0 ? CGFloat(min(max(timePublisher.currentTime / duration, 0), 1)) : 0

        ZStack(alignment: .leading) {
            // 轨道：虚线椭圆（卡通简洁）
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1.3, dash: [4, 3]))
                )
                .frame(height: 22)

            // 已行进：粉红色纯色（粗描边）
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(line, lineWidth: 1.6)
                )
                .frame(width: max(0, width * progress), height: 22)

            // 卡通 thumb：奶油色圆 + 粉色心形 + 粗描边
            ZStack {
                Circle()
                    .fill(cream)
                    .overlay(Circle().stroke(line, lineWidth: 1.8))
                    .frame(width: 26, height: 26)

                HeartShape()
                    .fill(accent)
                    .overlay(HeartShape().stroke(line, lineWidth: 1))
                    .frame(width: 11, height: 10)
            }
            .offset(x: max(0, width * progress - 13))
        }
        .frame(width: width)
        .contentShape(Rectangle().inset(by: -10))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let p = min(max(value.location.x / width, 0), 1)
                    player.seek(to: p * duration)
                }
        )
        .overlay(alignment: .bottom) {
            HStack {
                Text(formatTime(timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(cream.opacity(0.8))
            .padding(.horizontal, 4)
            .offset(y: 18)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Like heart

extension CosmosPlayerLayout {
    @ViewBuilder
    func likeHeart(song: Song) -> some View {
        let isLiked = LikeManager.shared.isLiked(id: song.id, isQQMusic: song.isQQMusic)
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            LikeManager.shared.toggleLike(songId: song.id, isQQMusic: song.isQQMusic, song: song)
        } label: {
            ZStack {
                MonologueIcon(
                    icon: isLiked ? .liked : .like,
                    size: 22,
                    color: isLiked ? accent : cream
                )
                .shadow(color: isLiked ? accent.opacity(0.6) : .black.opacity(0.2), radius: 3)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(CartoonPressStyle())
    }
}

// MARK: - Press style

private struct CartoonPressStyle: ButtonStyle {
    var strong: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (strong ? 0.88 : 0.92) : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -3 : 0))
            .animation(.spring(response: 0.22, dampingFraction: 0.5),
                       value: configuration.isPressed)
    }
}

// MARK: - Astronaut (cartoon sticker style)

/// 卡通贴纸风宇航员：粗描边、纯色块、可爱大头。
private struct AstronautView: View {
    let helmetImageURL: URL?
    let suit: Color            // 宇航服身体纯色（白色）
    let helmet: Color          // 面罩纯色
    let accent: Color          // 高亮色（粉红）
    let lineColor: Color       // 描边色
    let cream: Color           // 奶油黄
    var time: TimeInterval = 0

    // 大头 / 小身体的比例
    private let helmetRatio: CGFloat = 0.82
    // 粗描边宽度
    private let stroke: CGFloat = 2.8

    // 卡通色板
    private let suitShadow = Color(hex: "D8DEE8")   // 宇航服阴影色（平涂、非渐变）
    private let gloveColor = Color(hex: "FF79A8")
    private let bootColor = Color(hex: "1D1A2E")
    private let backpackColor = Color(hex: "FFD66B")
    private let pink = Color(hex: "FF79A8")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let breathe = 1 + CGFloat(sin(time * 1.6)) * 0.015
            let armSwing = CGFloat(sin(time * 1.3)) * 3

            ZStack {
                // 背包（在身体后面）
                backpack(w: w, h: h)

                // 氧气管（手绘曲线）
                oxygenTube(w: w, h: h)

                // 身体（圆滚滚宇航服）
                suitTorso(w: w, h: h)

                // 左右胳膊
                arm(w: w, h: h, side: .left, swing: armSwing)
                arm(w: w, h: h, side: .right, swing: -armSwing)

                // 两条悬空小腿
                legs(w: w, h: h)

                // 大头盔
                helmetView(w: w, h: h)

                // 心心天线
                antennaView(w: w, h: h)
            }
            .scaleEffect(breathe)
        }
    }

    enum Side { case left, right }

    // MARK: Backpack

    @ViewBuilder
    private func backpack(w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backpackColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(lineColor, lineWidth: stroke)
            )
            .frame(width: w * 0.5, height: h * 0.3)
            .overlay(
                // 两个圆形氧气表盘
                HStack(spacing: 6) {
                    dial(color: pink)
                    dial(color: Color(hex: "7EE7C3"))
                }
            )
            .offset(y: h * 0.06)
    }

    @ViewBuilder
    private func dial(color: Color) -> some View {
        ZStack {
            Circle().fill(color)
                .overlay(Circle().stroke(lineColor, lineWidth: 1.8))
                .frame(width: 14, height: 14)
            Circle().fill(Color.white).frame(width: 3, height: 3)
        }
    }

    @ViewBuilder
    private func oxygenTube(w: CGFloat, h: CGFloat) -> some View {
        // 从背包左上方绕到头盔颈部的软管（手绘曲线）
        Path { p in
            p.move(to: CGPoint(x: w * 0.28, y: h * 0.08))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.42, y: h * -0.04),
                control: CGPoint(x: w * 0.22, y: h * -0.05)
            )
        }
        .stroke(lineColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
        .overlay(
            Path { p in
                p.move(to: CGPoint(x: w * 0.28, y: h * 0.08))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.42, y: h * -0.04),
                    control: CGPoint(x: w * 0.22, y: h * -0.05)
                )
            }
            .stroke(Color(hex: "D8DEE8"), style: StrokeStyle(lineWidth: stroke - 1.6, lineCap: .round))
        )
    }

    // MARK: Body

    @ViewBuilder
    private func suitTorso(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // 身体主体（像小茶壶）
            RoundedRectangle(cornerRadius: w * 0.28, style: .continuous)
                .fill(suit)
                .overlay(
                    RoundedRectangle(cornerRadius: w * 0.28)
                        .stroke(lineColor, lineWidth: stroke)
                )
                .frame(width: w * 0.62, height: h * 0.36)
                .offset(y: h * 0.14)

            // 身体左侧阴影月牙（卡通平涂）
            RoundedRectangle(cornerRadius: w * 0.28, style: .continuous)
                .fill(suitShadow)
                .frame(width: w * 0.16, height: h * 0.3)
                .offset(x: w * 0.2, y: h * 0.14)
                .mask(
                    RoundedRectangle(cornerRadius: w * 0.28, style: .continuous)
                        .frame(width: w * 0.62, height: h * 0.36)
                        .offset(y: h * 0.14)
                )

            // 腰带（粉色一条）
            Capsule()
                .fill(pink)
                .overlay(Capsule().stroke(lineColor, lineWidth: stroke - 1.2))
                .frame(width: w * 0.62, height: 8)
                .offset(y: h * 0.22)

            // 胸前控制器：一个黄色圆 + 三个小灯
            ZStack {
                Circle().fill(Color(hex: "FFE37A"))
                    .overlay(Circle().stroke(lineColor, lineWidth: stroke - 1))
                    .frame(width: w * 0.16, height: w * 0.16)
                HStack(spacing: 3) {
                    Circle().fill(pink).frame(width: 4, height: 4)
                    Circle().fill(Color(hex: "7EE7C3")).frame(width: 4, height: 4)
                    Circle().fill(Color(hex: "B8E5FF")).frame(width: 4, height: 4)
                }
            }
            .offset(y: h * 0.12)
        }
    }

    // MARK: Arms

    @ViewBuilder
    private func arm(w: CGFloat, h: CGFloat, side: Side, swing: CGFloat) -> some View {
        let xSign: CGFloat = side == .left ? -1 : 1
        ZStack {
            // 上臂（胶囊）
            Capsule()
                .fill(suit)
                .overlay(Capsule().stroke(lineColor, lineWidth: stroke))
                .frame(width: w * 0.14, height: h * 0.2)

            // 手套（粉红圆）
            Circle()
                .fill(gloveColor)
                .overlay(Circle().stroke(lineColor, lineWidth: stroke - 0.8))
                .frame(width: w * 0.14, height: w * 0.14)
                .offset(y: h * 0.1)
        }
        .rotationEffect(.degrees(Double(xSign * 14 + swing)), anchor: .top)
        .offset(x: xSign * w * 0.32, y: h * 0.14)
    }

    // MARK: Legs

    @ViewBuilder
    private func legs(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: w * 0.06) {
            legShape(w: w, h: h)
            legShape(w: w, h: h)
        }
        .offset(y: h * 0.38)
    }

    @ViewBuilder
    private func legShape(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: -2) {
            Capsule()
                .fill(suit)
                .overlay(Capsule().stroke(lineColor, lineWidth: stroke))
                .frame(width: w * 0.14, height: h * 0.12)
            // 黑色大靴子
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(bootColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(lineColor, lineWidth: stroke - 0.8)
                )
                .frame(width: w * 0.18, height: h * 0.06)
        }
    }

    // MARK: Helmet (big)

    @ViewBuilder
    private func helmetView(w: CGFloat, h: CGFloat) -> some View {
        let helmetSize = w * helmetRatio

        ZStack {
            // 外壳（粗描边白色）
            Circle()
                .fill(suit)
                .overlay(Circle().stroke(lineColor, lineWidth: stroke))
                .frame(width: helmetSize, height: helmetSize)

            // 领圈（卡通黑色小环，连接身体）
            Capsule()
                .fill(bootColor)
                .overlay(Capsule().stroke(lineColor, lineWidth: stroke - 1))
                .frame(width: w * 0.36, height: 8)
                .offset(y: helmetSize * 0.48)

            // 面罩（圆玻璃）
            Circle()
                .fill(helmet)
                .overlay(Circle().stroke(lineColor, lineWidth: stroke - 0.6))
                .frame(width: helmetSize * 0.78, height: helmetSize * 0.78)

            // 封面镶嵌（保留用户封面，作为"头盔里的世界"）
            if let url = helmetImageURL {
                CachedAsyncImage(url: url) {
                    Color.clear
                }
                .aspectRatio(1, contentMode: .fill)
                .frame(width: helmetSize * 0.74, height: helmetSize * 0.74)
                .clipShape(Circle())
                .opacity(0.88)
            }

            // 可爱小眼睛（睁闭眨眼）
            let blink = sin(time * 0.8) > 0.95
            HStack(spacing: helmetSize * 0.14) {
                astroEye(open: !blink)
                    .frame(width: helmetSize * 0.08, height: helmetSize * 0.12)
                astroEye(open: !blink)
                    .frame(width: helmetSize * 0.08, height: helmetSize * 0.12)
            }
            .offset(y: -helmetSize * 0.04)

            // 腮红（两团粉圆）
            HStack(spacing: helmetSize * 0.42) {
                Circle().fill(pink.opacity(0.7))
                    .frame(width: helmetSize * 0.09, height: helmetSize * 0.09)
                Circle().fill(pink.opacity(0.7))
                    .frame(width: helmetSize * 0.09, height: helmetSize * 0.09)
            }
            .offset(y: helmetSize * 0.08)

            // 微笑嘴（大弧）
            astroSmile()
                .frame(width: helmetSize * 0.2, height: helmetSize * 0.1)
                .offset(y: helmetSize * 0.14)

            // 两道卡通月牙高光
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: helmetSize * 0.07, height: helmetSize * 0.18)
                .rotationEffect(.degrees(-20))
                .offset(x: -helmetSize * 0.22, y: -helmetSize * 0.18)
            Capsule()
                .fill(Color.white.opacity(0.55))
                .frame(width: helmetSize * 0.04, height: helmetSize * 0.1)
                .rotationEffect(.degrees(-20))
                .offset(x: -helmetSize * 0.14, y: -helmetSize * 0.24)
        }
        .offset(y: -h * 0.2)
    }

    @ViewBuilder
    private func astroEye(open: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if open {
                ZStack {
                    Capsule().fill(lineColor).frame(width: w, height: h)
                    Circle().fill(Color.white)
                        .frame(width: w * 0.45, height: w * 0.45)
                        .offset(x: -w * 0.1, y: -h * 0.2)
                }
            } else {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.8))
                    p.addQuadCurve(
                        to: CGPoint(x: w, y: h * 0.8),
                        control: CGPoint(x: w / 2, y: -h * 0.3)
                    )
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
            }
        }
    }

    @ViewBuilder
    private func astroSmile() -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.1))
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h * 0.1),
                    control: CGPoint(x: w / 2, y: h * 1.3)
                )
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
        }
    }

    // MARK: Antenna

    @ViewBuilder
    private func antennaView(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            HeartShape()
                .fill(accent)
                .overlay(HeartShape().stroke(lineColor, lineWidth: 1.8))
                .frame(width: w * 0.14, height: w * 0.12)
                .rotationEffect(.degrees(sin(time * 1.3) * 10))
            Rectangle()
                .fill(lineColor)
                .frame(width: 2, height: w * 0.1)
        }
        .offset(y: -h * 0.52)
    }
}

// MARK: - Rocket shape (cartoon sticker style)

private struct RocketShape: View {
    let isPlaying: Bool
    let bodyColor: Color
    let windowColor: Color
    let lineColor: Color
    let cream: Color

    private let stroke: CGFloat = 2.6
    private var bellyWhite: Color { Color(hex: "FFE6EC") }  // 腹白色（卡通平涂）
    private var flameYellow: Color { Color(hex: "FFE37A") }
    private var flameOrange: Color { Color(hex: "FFB56B") }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 火焰（播放时）— 两层纯色 + 描边，卡通"抖动"
                if isPlaying {
                    TimelineView(.animation(minimumInterval: 0.08)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        let flicker = 0.9 + sin(t * 12) * 0.1
                        let wobble = CGFloat(sin(t * 8)) * 2
                        ZStack {
                            // 外层橙色火焰
                            FlameShape()
                                .fill(flameOrange)
                                .overlay(FlameShape().stroke(lineColor, lineWidth: stroke - 1))
                                .frame(width: w * 0.48 * CGFloat(flicker),
                                       height: h * 0.42 * CGFloat(flicker))
                                .offset(x: wobble, y: h * 0.48)

                            // 中层黄色
                            FlameShape()
                                .fill(flameYellow)
                                .frame(width: w * 0.32 * CGFloat(flicker),
                                       height: h * 0.32 * CGFloat(flicker))
                                .offset(x: wobble * 0.5, y: h * 0.47)

                            // 小烟雾小圆圈飘落
                            ForEach(0..<3, id: \.self) { i in
                                let local = (t + Double(i) * 0.6)
                                    .truncatingRemainder(dividingBy: 1.8) / 1.8
                                let p = CGFloat(local)
                                Circle()
                                    .stroke(Color.white.opacity(0.6 * (1 - Double(p))),
                                            lineWidth: 1.5)
                                    .frame(width: 10 + p * 8, height: 10 + p * 8)
                                    .offset(x: CGFloat([-1, 1, 0][i]) * 14,
                                            y: h * 0.55 + p * 30)
                            }
                        }
                    }
                }

                // 火箭主体（纯色 + 粗描边）
                RoundedRectangle(cornerRadius: w * 0.28, style: .continuous)
                    .fill(bodyColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.28)
                            .stroke(lineColor, lineWidth: stroke)
                    )
                    .frame(width: w * 0.64, height: h * 0.72)

                // 腹白（卡通平涂月牙）
                RoundedRectangle(cornerRadius: w * 0.2, style: .continuous)
                    .fill(bellyWhite)
                    .frame(width: w * 0.42, height: h * 0.4)
                    .offset(x: -w * 0.06, y: h * 0.12)
                    .mask(
                        RoundedRectangle(cornerRadius: w * 0.28, style: .continuous)
                            .frame(width: w * 0.64, height: h * 0.72)
                    )

                // 火箭鼻锥（纯色三角）
                RocketNose()
                    .fill(bodyColor)
                    .overlay(RocketNose().stroke(lineColor, lineWidth: stroke))
                    .frame(width: w * 0.64, height: h * 0.3)
                    .offset(y: -h * 0.36)

                // 腰线（奶油黄色，粗）
                Capsule()
                    .fill(cream)
                    .overlay(Capsule().stroke(lineColor, lineWidth: stroke - 0.8))
                    .frame(width: w * 0.64, height: 8)
                    .offset(y: h * 0.11)

                // 舷窗（纯色 + 卡通高光）
                ZStack {
                    Circle()
                        .fill(windowColor)
                        .overlay(Circle().stroke(lineColor, lineWidth: stroke - 0.4))
                        .frame(width: w * 0.32, height: w * 0.32)
                    // 卡通月牙高光
                    Capsule()
                        .fill(Color.white)
                        .frame(width: w * 0.07, height: w * 0.12)
                        .rotationEffect(.degrees(-25))
                        .offset(x: -w * 0.07, y: -w * 0.07)
                }
                .offset(y: -h * 0.06)

                // 按钮（暂停/播放符号）— 纯白、粗黑描边
                Group {
                    if isPlaying {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(lineColor, lineWidth: 1))
                                .frame(width: 6, height: 18)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(lineColor, lineWidth: 1))
                                .frame(width: 6, height: 18)
                        }
                    } else {
                        Triangle()
                            .fill(Color.white)
                            .overlay(Triangle().stroke(lineColor, lineWidth: 1.2))
                            .frame(width: 16, height: 18)
                            .offset(x: 2)
                    }
                }
                .offset(y: h * 0.22)

                // 侧翼（纯色）
                RocketFin()
                    .fill(bodyColor)
                    .overlay(RocketFin().stroke(lineColor, lineWidth: stroke))
                    .frame(width: w * 0.24, height: h * 0.24)
                    .offset(x: -w * 0.32, y: h * 0.24)

                RocketFin()
                    .fill(bodyColor)
                    .overlay(RocketFin().stroke(lineColor, lineWidth: stroke))
                    .frame(width: w * 0.24, height: h * 0.24)
                    .scaleEffect(x: -1)
                    .offset(x: w * 0.32, y: h * 0.24)

                // 鼻锥尖处小星（装饰）
                FourPointedStar()
                    .fill(cream)
                    .overlay(FourPointedStar().stroke(lineColor, lineWidth: 1.2))
                    .frame(width: 10, height: 10)
                    .offset(x: w * 0.18, y: -h * 0.45)
            }
        }
    }
}

// MARK: - Shapes

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 14
        var p = Path(roundedRect: rect.insetBy(dx: 0, dy: 4), cornerRadius: radius)
        // 左下小尖角，指向宇航员
        let tailStart = CGPoint(x: rect.minX + 24, y: rect.maxY - 4)
        p.move(to: tailStart)
        p.addLine(to: CGPoint(x: rect.minX + 12, y: rect.maxY + 4))
        p.addLine(to: CGPoint(x: rect.minX + 38, y: rect.maxY - 4))
        p.closeSubpath()
        return p
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                   control1: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.midY),
                   control2: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + 8))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.2))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + 8),
                   control2: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

private struct RocketNose: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.1)
        )
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.1)
        )
        p.closeSubpath()
        return p
    }
}

private struct RocketFin: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Floating decorations

/// 纯色卡通贴纸风装饰：粗黑描边 + 平涂色块 + 可爱表情。
private struct CosmosFloatingDecorations: View, @preconcurrency Equatable {
    let size: CGSize

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.size == rhs.size
    }

    // 卡通色板（纯色，非渐变）
    private let stroke = Color(hex: "1D1A2E")
    private let saturnBody = Color(hex: "F3A65A")
    private let saturnBelly = Color(hex: "FFD49A")
    private let saturnRing = Color(hex: "FFE37A")
    private let moonBody = Color(hex: "FFF2D1")
    private let moonCrater = Color(hex: "E5C88A")
    private let ufoBody = Color(hex: "7EE7C3")
    private let ufoDome = Color(hex: "FFB5D8")
    private let asteroidBody = Color(hex: "B79E87")
    private let asteroidDark = Color(hex: "8E7356")
    private let starYellow = Color(hex: "FFE37A")
    private let pink = Color(hex: "FF79A8")

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate

            ZStack {
                // 左上：胖胖土星
                saturn(t: t)
                    .frame(width: 100, height: 70)
                    .rotationEffect(.degrees(sin(t * 0.35) * 3))
                    .offset(y: sin(t * 0.6) * 5)
                    .position(x: size.width * 0.17, y: size.height * 0.15)

                // 右上：粉色小行星
                tinyPlanet(color: pink, eyesPhase: t + 0.5)
                    .frame(width: 48, height: 48)
                    .offset(y: sin(t * 0.7 + 1.1) * 4)
                    .position(x: size.width * 0.86, y: size.height * 0.13)

                // 右中：笑脸月亮
                moonFace(t: t)
                    .frame(width: 84, height: 84)
                    .offset(y: sin(t * 0.4) * 4)
                    .position(x: size.width * 0.86, y: size.height * 0.36)

                // 右下：飞碟 UFO（带腮红和感叹号）
                ufo(t: t)
                    .frame(width: 100, height: 70)
                    .offset(x: sin(t * 0.6) * 6, y: cos(t * 0.45) * 3)
                    .position(x: size.width * 0.78, y: size.height * 0.7)

                // 左下：滚动小行星（有表情）
                asteroid(t: t)
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(t * 10))
                    .offset(y: sin(t * 0.9 + 2) * 3)
                    .position(x: size.width * 0.10, y: size.height * 0.66)

                // 零散闪星
                cartoonStar(color: starYellow, phase: t)
                    .frame(width: 28, height: 28)
                    .position(x: size.width * 0.06, y: size.height * 0.45)

                cartoonStar(color: Color(hex: "B8E5FF"), phase: t + 2.3)
                    .frame(width: 20, height: 20)
                    .position(x: size.width * 0.72, y: size.height * 0.08)

                cartoonStar(color: pink, phase: t + 1.1)
                    .frame(width: 16, height: 16)
                    .position(x: size.width * 0.55, y: size.height * 0.9)

                // 右上角小爱心
                cartoonHeart(color: pink)
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(sin(t) * 12))
                    .position(x: size.width * 0.94, y: size.height * 0.22)
            }
        }
    }

    // MARK: - Saturn

    /// 卡通土星：圆肚子 + 平涂光环 + 粉腮红 + 闭眼睡觉
    @ViewBuilder
    private func saturn(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let D: CGFloat = h * 0.78

            ZStack {
                // 光环后半段（粗描边，纯色）
                Capsule(style: .continuous)
                    .stroke(stroke, lineWidth: 2.5)
                    .background(
                        Capsule().fill(saturnRing)
                            .padding(2.5)
                    )
                    .frame(width: w * 0.96, height: 10)
                    .rotationEffect(.degrees(-14))
                    .mask(
                        Rectangle()
                            .frame(width: w, height: 8)
                            .offset(y: -8)
                    )

                // 星球主体（正圆 + 粗描边）
                ZStack {
                    Circle().fill(saturnBody)
                        .frame(width: D, height: D)
                        .overlay(
                            Circle().stroke(stroke, lineWidth: 2.5)
                        )

                    // 肚子亮色月牙（卡通腹白）
                    Circle()
                        .fill(saturnBelly)
                        .frame(width: D * 0.75, height: D * 0.75)
                        .offset(x: -D * 0.05, y: D * 0.12)
                        .mask(
                            Circle().frame(width: D, height: D)
                        )

                    // 腮红（两团粉圆）
                    HStack(spacing: D * 0.34) {
                        Circle().fill(pink.opacity(0.7))
                            .frame(width: D * 0.14, height: D * 0.14)
                        Circle().fill(pink.opacity(0.7))
                            .frame(width: D * 0.14, height: D * 0.14)
                    }
                    .offset(y: D * 0.04)

                    // 闭眼（两条弧线）
                    HStack(spacing: D * 0.25) {
                        eyeClosed().frame(width: D * 0.12, height: D * 0.06)
                        eyeClosed().frame(width: D * 0.12, height: D * 0.06)
                    }
                    .offset(y: -D * 0.08)

                    // z z 小气泡（睡觉）
                    Text("z")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(stroke)
                        .rotationEffect(.degrees(15))
                        .opacity(0.6 + 0.4 * sin(t * 2))
                        .offset(x: D * 0.35, y: -D * 0.36)
                }

                // 光环前半段（覆盖在星球前）
                Capsule(style: .continuous)
                    .stroke(stroke, lineWidth: 2.5)
                    .background(
                        Capsule().fill(saturnRing)
                            .padding(2.5)
                    )
                    .frame(width: w * 0.96, height: 10)
                    .rotationEffect(.degrees(-14))
                    .mask(
                        Rectangle()
                            .frame(width: w, height: 8)
                            .offset(y: 8)
                    )
            }
            .frame(width: w, height: h)
        }
    }

    /// 小行星（小脸 + 眨眼）
    @ViewBuilder
    private func tinyPlanet(color: Color, eyesPhase: TimeInterval) -> some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let blink = sin(eyesPhase * 0.8) > 0.95

            ZStack {
                Circle().fill(color)
                    .overlay(Circle().stroke(stroke, lineWidth: 2.2))
                    .frame(width: s * 0.9, height: s * 0.9)

                // 腹白月牙
                Circle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: s * 0.65, height: s * 0.65)
                    .offset(x: -s * 0.03, y: s * 0.12)
                    .mask(Circle().frame(width: s * 0.9, height: s * 0.9))

                // 小眼睛
                HStack(spacing: s * 0.14) {
                    eye(open: !blink).frame(width: s * 0.09, height: s * 0.12)
                    eye(open: !blink).frame(width: s * 0.09, height: s * 0.12)
                }
                .offset(y: -s * 0.04)

                // 微笑小嘴
                smile().frame(width: s * 0.22, height: s * 0.08)
                    .offset(y: s * 0.1)

                // 腮红
                HStack(spacing: s * 0.32) {
                    Circle().fill(pink.opacity(0.7)).frame(width: s * 0.1, height: s * 0.1)
                    Circle().fill(pink.opacity(0.7)).frame(width: s * 0.1, height: s * 0.1)
                }
                .offset(y: s * 0.04)
            }
        }
    }

    // MARK: - Moon face

    @ViewBuilder
    private func moonFace(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let blink = sin(t * 0.6) > 0.93

            ZStack {
                // 月亮主体
                Circle().fill(moonBody)
                    .frame(width: s * 0.88, height: s * 0.88)
                    .overlay(Circle().stroke(stroke, lineWidth: 2.3))

                // 陨石坑（平涂圆）
                craterDot(relX: -0.22, relY: 0.08, rel: 0.16)
                    .frame(width: s, height: s)
                craterDot(relX: 0.18, relY: -0.14, rel: 0.12)
                    .frame(width: s, height: s)
                craterDot(relX: 0.08, relY: 0.22, rel: 0.09)
                    .frame(width: s, height: s)

                // 月亮的脸（睫毛 + 嘴）
                HStack(spacing: s * 0.15) {
                    eye(open: !blink).frame(width: s * 0.08, height: s * 0.12)
                    eye(open: !blink).frame(width: s * 0.08, height: s * 0.12)
                }
                .offset(x: s * 0.1, y: -s * 0.02)

                // 腮红
                Circle().fill(pink.opacity(0.6))
                    .frame(width: s * 0.12, height: s * 0.12)
                    .offset(x: s * 0.3, y: s * 0.05)

                // 微笑
                smile().frame(width: s * 0.18, height: s * 0.08)
                    .offset(x: s * 0.15, y: s * 0.14)
            }
        }
    }

    @ViewBuilder
    private func craterDot(relX: CGFloat, relY: CGFloat, rel: CGFloat) -> some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            Circle().fill(moonCrater)
                .overlay(Circle().stroke(stroke.opacity(0.7), lineWidth: 1.2))
                .frame(width: s * rel, height: s * rel)
                .offset(x: s * relX, y: s * relY)
        }
    }

    // MARK: - UFO

    @ViewBuilder
    private func ufo(t: TimeInterval) -> some View {
        let blink = 0.4 + 0.6 * sin(t * 4)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 穹顶（粉色半圆）
                Path { p in
                    let rect = CGRect(x: w * 0.28, y: h * 0.12, width: w * 0.44, height: h * 0.5)
                    p.addArc(
                        center: CGPoint(x: rect.midX, y: rect.maxY),
                        radius: rect.width / 2,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                    p.closeSubpath()
                }
                .fill(ufoDome)
                .overlay(
                    Path { p in
                        let rect = CGRect(x: w * 0.28, y: h * 0.12, width: w * 0.44, height: h * 0.5)
                        p.addArc(
                            center: CGPoint(x: rect.midX, y: rect.maxY),
                            radius: rect.width / 2,
                            startAngle: .degrees(180),
                            endAngle: .degrees(0),
                            clockwise: false
                        )
                    }
                    .stroke(stroke, lineWidth: 2.3)
                )

                // 穹顶高光（小白弧）
                Path { p in
                    p.move(to: CGPoint(x: w * 0.35, y: h * 0.35))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.4, y: h * 0.22),
                        control: CGPoint(x: w * 0.34, y: h * 0.26)
                    )
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // 碟身（宽椭圆）
                Ellipse()
                    .fill(ufoBody)
                    .overlay(Ellipse().stroke(stroke, lineWidth: 2.4))
                    .frame(width: w * 0.92, height: h * 0.28)
                    .offset(y: h * 0.05)

                // 碟身四个彩色灯
                HStack(spacing: w * 0.12) {
                    lightDot(color: Color(hex: "FFE37A"), blink: blink)
                    lightDot(color: pink, blink: 1 - blink)
                    lightDot(color: Color(hex: "B8E5FF"), blink: blink)
                    lightDot(color: Color(hex: "FFE37A"), blink: 1 - blink)
                }
                .offset(y: h * 0.18)

                // 外星人小脸（穹顶里）
                HStack(spacing: w * 0.05) {
                    eye(open: true).frame(width: w * 0.06, height: w * 0.07)
                    eye(open: true).frame(width: w * 0.06, height: w * 0.07)
                }
                .offset(y: -h * 0.08)

                smile().frame(width: w * 0.09, height: w * 0.04)
                    .offset(y: h * 0.02)
            }
        }
    }

    @ViewBuilder
    private func lightDot(color: Color, blink: Double) -> some View {
        Circle()
            .fill(color)
            .overlay(Circle().stroke(stroke, lineWidth: 1.3))
            .frame(width: 8, height: 8)
            .opacity(0.55 + 0.45 * blink)
    }

    // MARK: - Asteroid

    @ViewBuilder
    private func asteroid(t: TimeInterval) -> some View {
        let blink = sin(t * 1.5) > 0.92
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // 不规则多边形 — 近似圆但有点"石头"感
                AsteroidBlob()
                    .fill(asteroidBody)
                    .overlay(AsteroidBlob().stroke(stroke, lineWidth: 2.2))
                    .frame(width: s, height: s)

                // 深色斑
                Circle()
                    .fill(asteroidDark)
                    .overlay(Circle().stroke(stroke.opacity(0.7), lineWidth: 1))
                    .frame(width: s * 0.22, height: s * 0.22)
                    .offset(x: -s * 0.18, y: -s * 0.1)
                Circle()
                    .fill(asteroidDark)
                    .overlay(Circle().stroke(stroke.opacity(0.7), lineWidth: 1))
                    .frame(width: s * 0.14, height: s * 0.14)
                    .offset(x: s * 0.2, y: s * 0.18)

                // 小眼睛
                HStack(spacing: s * 0.13) {
                    eye(open: !blink).frame(width: s * 0.09, height: s * 0.12)
                    eye(open: !blink).frame(width: s * 0.09, height: s * 0.12)
                }
                .offset(y: -s * 0.02)

                // 吐舌头小嘴
                tongueSmile().frame(width: s * 0.18, height: s * 0.12)
                    .offset(y: s * 0.1)
            }
        }
    }

    // MARK: - Stars / heart

    /// 纯色四角星 + 小白中心（无渐变，无模糊）
    @ViewBuilder
    private func cartoonStar(color: Color, phase t: TimeInterval) -> some View {
        let pulse = 0.82 + 0.18 * sin(t * 2.2)
        ZStack {
            FourPointedStar()
                .fill(color)
                .overlay(FourPointedStar().stroke(stroke, lineWidth: 1.6))

            // 中心小白点
            Circle().fill(Color.white)
                .frame(width: 4, height: 4)
        }
        .scaleEffect(CGFloat(pulse))
    }

    @ViewBuilder
    private func cartoonHeart(color: Color) -> some View {
        HeartShape()
            .fill(color)
            .overlay(HeartShape().stroke(stroke, lineWidth: 1.6))
    }

    // MARK: - Face building blocks

    /// 睁眼：黑色椭圆 + 小白点高光
    @ViewBuilder
    private func eye(open: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if open {
                ZStack {
                    Capsule().fill(stroke)
                        .frame(width: w, height: h)
                    Circle().fill(Color.white)
                        .frame(width: w * 0.4, height: w * 0.4)
                        .offset(x: -w * 0.12, y: -h * 0.18)
                }
            } else {
                eyeClosed()
            }
        }
    }

    /// 闭眼 / 眯眼：一条粗弧
    @ViewBuilder
    private func eyeClosed() -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.8))
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h * 0.8),
                    control: CGPoint(x: w / 2, y: -h * 0.4)
                )
            }
            .stroke(stroke, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    @ViewBuilder
    private func smile() -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.1))
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h * 0.1),
                    control: CGPoint(x: w / 2, y: h * 1.4)
                )
            }
            .stroke(stroke, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// 吐舌头小嘴
    @ViewBuilder
    private func tongueSmile() -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.1))
                    p.addQuadCurve(
                        to: CGPoint(x: w, y: h * 0.1),
                        control: CGPoint(x: w / 2, y: h * 1.4)
                    )
                }
                .stroke(stroke, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // 粉色小舌头
                Ellipse()
                    .fill(pink)
                    .overlay(Ellipse().stroke(stroke, lineWidth: 1.2))
                    .frame(width: w * 0.35, height: h * 0.4)
                    .offset(x: w * 0.1, y: h * 0.55)
                    .mask(
                        Rectangle()
                            .frame(width: w, height: h * 0.8)
                            .offset(y: h * 0.3)
                    )
            }
        }
    }
}

/// 不规则椭圆 blob（小石头形状）
private struct AsteroidBlob: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2

        // 8 个带扰动的控制点
        let steps = 8
        var points: [CGPoint] = []
        for i in 0..<steps {
            let angle = Double(i) / Double(steps) * 2 * .pi
            // 周期性起伏：避免真随机（确定)
            let bump: CGFloat = 0.88 + 0.14 * CGFloat(sin(angle * 2))
            let x = cx + rx * bump * CGFloat(cos(angle))
            let y = cy + ry * bump * CGFloat(sin(angle))
            points.append(CGPoint(x: x, y: y))
        }

        p.move(to: points[0])
        for i in 0..<points.count {
            let cur = points[i]
            let next = points[(i + 1) % points.count]
            let mid = CGPoint(x: (cur.x + next.x) / 2, y: (cur.y + next.y) / 2)
            p.addQuadCurve(to: mid, control: cur)
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Extra cartoon shapes (no emoji)

/// 卡通心形
private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.25))
        // 左半圆
        p.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.35),
            control1: CGPoint(x: rect.midX - w * 0.25, y: rect.minY - h * 0.1),
            control2: CGPoint(x: rect.minX, y: rect.minY - h * 0.05)
        )
        // 左下到底
        p.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.7),
            control2: CGPoint(x: rect.midX - w * 0.12, y: rect.maxY - h * 0.05)
        )
        // 右下到右
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.35),
            control1: CGPoint(x: rect.midX + w * 0.12, y: rect.maxY - h * 0.05),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.7)
        )
        // 右半圆
        p.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + h * 0.25),
            control1: CGPoint(x: rect.maxX, y: rect.minY - h * 0.05),
            control2: CGPoint(x: rect.midX + w * 0.25, y: rect.minY - h * 0.1)
        )
        p.closeSubpath()
        return p
    }
}

/// 四角星（漫画风闪光）
private struct FourPointedStar: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let R = min(rect.width, rect.height) / 2
        let r = R * 0.4
        let points: [CGPoint] = [
            CGPoint(x: cx,     y: cy - R),    // 上
            CGPoint(x: cx + r, y: cy - r),
            CGPoint(x: cx + R, y: cy),        // 右
            CGPoint(x: cx + r, y: cy + r),
            CGPoint(x: cx,     y: cy + R),    // 下
            CGPoint(x: cx - r, y: cy + r),
            CGPoint(x: cx - R, y: cy),        // 左
            CGPoint(x: cx - r, y: cy - r)
        ]
        p.move(to: points[0])
        for i in 1..<points.count {
            p.addLine(to: points[i])
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Seeded RNG for stars

struct CosmosSeed {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEAD_BEEF : seed }

    mutating func next(_ range: ClosedRange<CGFloat>) -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z &>> 31
        let u = CGFloat(Double(z >> 11) / Double(1 << 53))
        return range.lowerBound + u * (range.upperBound - range.lowerBound)
    }
}
