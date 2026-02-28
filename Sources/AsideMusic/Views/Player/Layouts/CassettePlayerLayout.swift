import SwiftUI
import FFmpegSwiftSDK

/// 磁带播放器 — 复古拟物风，Canvas 手绘磁带机体 + 暖色调怀旧氛围
/// 设计理念：真实磁带机的扁平化演绎，保留机械质感但去除多余阴影
struct CassettePlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    @State private var showPlaylist = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var bounceTrigger = false
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    // MARK: - 复古暖色调色板

    private var bgColor: Color {
        colorScheme == .dark ? Color(hex: "1A1714") : Color(hex: "F5F0E8")
    }

    /// 磁带外壳 — 米白/深灰
    private var shellColor: Color {
        colorScheme == .dark ? Color(hex: "2C2824") : Color(hex: "FAFAF5")
    }

    /// 贴纸底色 — 复古牛皮纸
    private var labelColor: Color {
        colorScheme == .dark ? Color(hex: "3D3530") : Color(hex: "F0E6D3")
    }

    /// 观景窗底色
    private var windowColor: Color {
        colorScheme == .dark ? Color(hex: "151210") : Color(hex: "E8E0D4")
    }

    /// 磁带卷轴颜色
    private var reelColor: Color {
        colorScheme == .dark ? Color(hex: "0D0B09") : Color(hex: "2C2420")
    }

    /// 强调色 — 复古橙红
    private var accentColor: Color {
        colorScheme == .dark ? Color(hex: "E8734A") : Color(hex: "D4603A")
    }

    private var textPrimary: Color {
        colorScheme == .dark ? Color(hex: "F0E6D3") : Color(hex: "2C2420")
    }

    private var textMuted: Color {
        colorScheme == .dark ? Color(hex: "8C7E6E") : Color(hex: "8C7E6E")
    }

    /// 描边色
    private var strokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    // 播放进度
    private var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max((isDragging ? dragValue : player.currentTime) / player.duration, 0), 1)
    }

    // MARK: - 主体

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AsideBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, DeviceLayout.headerTopPadding)

                    Spacer().frame(height: 16)

                    // 磁带机体
                    cassetteBody(width: geo.size.width - 48)
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 20)

                    // 歌曲信息
                    songInfoArea

                    // 进度条
                    progressBar(width: geo.size.width - 64)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                    // 歌词
                    lyricsContent

                    Spacer()

                    // 控制栏
                    controls
                        .padding(.bottom, DeviceLayout.playerBottomPadding + 16)
                }

                // 更多菜单
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        isDarkBackground: colorScheme == .dark,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
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
        // 歌词由 PlayerManager 统一管理
    }
}


// MARK: - 磁带机体 Canvas 绘制

extension CassettePlayerLayout {

    private func cassetteBody(width: CGFloat) -> some View {
        let height = width * 0.58

        return TimelineView(.animation(paused: !player.isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let isPlaying = player.isPlaying

            Canvas { ctx, size in
                let w = size.width
                let h = size.height

                // ── 1. 外壳 ──
                drawShell(ctx: &ctx, w: w, h: h)

                // ── 2. 贴纸区域 ──
                let labelRect = drawLabel(ctx: &ctx, w: w, h: h)

                // ── 3. 观景窗 ──
                let winRect = drawWindow(ctx: &ctx, w: w, h: h, labelRect: labelRect)

                // ── 4. 磁带卷轴 + 齿轮 ──
                drawReels(ctx: &ctx, winRect: winRect, t: t, isPlaying: isPlaying)

                // ── 5. 底部导带槽 ──
                drawGuideSlot(ctx: &ctx, w: w, h: h)
            }
        }
        .frame(height: height)
        .drawingGroup()
    }

    /// 外壳：圆角矩形 + 底部梯形凸起 + 螺丝
    private func drawShell(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let corner: CGFloat = 10
        let cutW: CGFloat = 18
        let cutH: CGFloat = 10

        var shell = Path()
        shell.move(to: CGPoint(x: corner, y: 0))
        shell.addLine(to: CGPoint(x: w - corner, y: 0))
        shell.addQuadCurve(to: CGPoint(x: w, y: corner), control: CGPoint(x: w, y: 0))
        shell.addLine(to: CGPoint(x: w, y: h - corner))
        shell.addQuadCurve(to: CGPoint(x: w - corner, y: h), control: CGPoint(x: w, y: h))
        // 底部梯形
        shell.addLine(to: CGPoint(x: w - cutW, y: h))
        shell.addLine(to: CGPoint(x: w - cutW - 8, y: h - cutH))
        shell.addLine(to: CGPoint(x: cutW + 8, y: h - cutH))
        shell.addLine(to: CGPoint(x: cutW, y: h))
        shell.addLine(to: CGPoint(x: corner, y: h))
        shell.addQuadCurve(to: CGPoint(x: 0, y: h - corner), control: CGPoint(x: 0, y: h))
        shell.addLine(to: CGPoint(x: 0, y: corner))
        shell.addQuadCurve(to: CGPoint(x: corner, y: 0), control: CGPoint(x: 0, y: 0))

        ctx.fill(shell, with: .color(shellColor))
        ctx.stroke(shell, with: .color(strokeColor), lineWidth: 1.5)

        // 螺丝 — 四角小圆 + 十字刻痕
        let screwR: CGFloat = 4
        let offset: CGFloat = 14
        let screwColor = colorScheme == .dark ? Color(hex: "4A4440") : Color(hex: "C8C0B4")
        let slotColor = colorScheme == .dark ? Color(hex: "1A1714") : Color(hex: "9C9488")

        for pt in [CGPoint(x: offset, y: offset),
                    CGPoint(x: w - offset, y: offset),
                    CGPoint(x: offset, y: h - offset - 4),
                    CGPoint(x: w - offset, y: h - offset - 4)] {
            let rect = CGRect(x: pt.x - screwR, y: pt.y - screwR, width: screwR * 2, height: screwR * 2)
            ctx.fill(Circle().path(in: rect), with: .color(screwColor))
            ctx.stroke(Circle().path(in: rect), with: .color(slotColor.opacity(0.5)), lineWidth: 0.5)
            // 十字槽
            var cross = Path()
            cross.move(to: CGPoint(x: pt.x - 2.5, y: pt.y))
            cross.addLine(to: CGPoint(x: pt.x + 2.5, y: pt.y))
            cross.move(to: CGPoint(x: pt.x, y: pt.y - 2.5))
            cross.addLine(to: CGPoint(x: pt.x, y: pt.y + 2.5))
            ctx.stroke(cross, with: .color(slotColor), lineWidth: 1)
        }

        // 防擦除卡口
        let tabColor = colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
        ctx.fill(RoundedRectangle(cornerRadius: 1.5).path(in: CGRect(x: w * 0.14, y: 3, width: 16, height: 6)), with: .color(tabColor))
        ctx.fill(RoundedRectangle(cornerRadius: 1.5).path(in: CGRect(x: w * 0.86 - 16, y: 3, width: 16, height: 6)), with: .color(tabColor))
    }

    /// 贴纸：复古牛皮纸底 + 彩色条纹 + SIDE A 文字
    @discardableResult
    private func drawLabel(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) -> CGRect {
        let labelW = w * 0.80
        let labelH = h * 0.58
        let rect = CGRect(x: (w - labelW) / 2, y: h * 0.14, width: labelW, height: labelH)

        let path = RoundedRectangle(cornerRadius: 5).path(in: rect)
        ctx.fill(path, with: .color(labelColor))
        ctx.stroke(path, with: .color(strokeColor), lineWidth: 1)

        // 三色条纹 — 复古红/橙/黄
        let stripeH: CGFloat = 4.5
        let stripeX = rect.minX + 10
        let stripeW = labelW - 20
        let stripeY = rect.minY + 14
        let stripes: [(Color, CGFloat)] = [
            (Color(hex: "C0392B"), 0),
            (Color(hex: "D35400"), stripeH),
            (Color(hex: "D4A017"), stripeH * 2),
        ]
        for (color, dy) in stripes {
            ctx.fill(Path(CGRect(x: stripeX, y: stripeY + dy, width: stripeW, height: stripeH)), with: .color(color))
        }

        // SIDE A 文字
        let sideText = ctx.resolve(
            Text("SIDE A")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? Color(hex: "8C7E6E") : Color(hex: "6B5E50"))
        )
        ctx.draw(sideText, at: CGPoint(x: stripeX + 2, y: stripeY + stripeH * 3 + 14), anchor: .leading)

        // 歌名（如果有）
        if let name = player.currentSong?.name {
            let displayName = name.count > 20 ? String(name.prefix(20)) + "..." : name
            let nameText = ctx.resolve(
                Text(displayName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color(hex: "6B5E50") : Color(hex: "8C7E6E"))
            )
            ctx.draw(nameText, at: CGPoint(x: rect.maxX - 10, y: stripeY + stripeH * 3 + 14), anchor: .trailing)
        }

        return rect
    }

    /// 观景窗：透明窗 + 水平扫描线
    @discardableResult
    private func drawWindow(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, labelRect: CGRect) -> CGRect {
        let winW = labelRect.width * 0.52
        let winH = labelRect.height * 0.42
        let rect = CGRect(
            x: (w - winW) / 2,
            y: labelRect.minY + (labelRect.height - winH) / 2 + 12,
            width: winW, height: winH
        )

        let path = RoundedRectangle(cornerRadius: 5).path(in: rect)
        ctx.fill(path, with: .color(windowColor))

        // 扫描线纹理
        ctx.clip(to: path)
        for y in stride(from: rect.minY, to: rect.maxY, by: 2.5) {
            var line = Path()
            line.move(to: CGPoint(x: rect.minX, y: y))
            line.addLine(to: CGPoint(x: rect.maxX, y: y))
            ctx.stroke(line, with: .color(colorScheme == .dark ? .white.opacity(0.03) : .black.opacity(0.04)), lineWidth: 0.5)
        }

        return rect
    }

    /// 磁带卷轴 + 齿轮转动
    private func drawReels(ctx: inout GraphicsContext, winRect: CGRect, t: Double, isPlaying: Bool) {
        let leftCenter = CGPoint(x: winRect.minX + winRect.width * 0.22, y: winRect.midY)
        let rightCenter = CGPoint(x: winRect.maxX - winRect.width * 0.22, y: winRect.midY)
        let hubR: CGFloat = winRect.height * 0.32
        let maxTapeR: CGFloat = winRect.width * 0.42

        let maxArea = Double.pi * (pow(Double(maxTapeR), 2) - pow(Double(hubR), 2))
        let leftArea = maxArea * (1.0 - progress)
        let rightArea = maxArea * progress
        let leftTapeR = CGFloat(sqrt(leftArea / .pi + Double(hubR * hubR)))
        let rightTapeR = CGFloat(sqrt(rightArea / .pi + Double(hubR * hubR)))

        // 磁带卷
        for (center, tapeR) in [(leftCenter, leftTapeR), (rightCenter, rightTapeR)] {
            let tapeRect = CGRect(x: center.x - tapeR, y: center.y - tapeR, width: tapeR * 2, height: tapeR * 2)
            ctx.fill(Circle().path(in: tapeRect), with: .color(reelColor))
            // 磁带纹理环
            if tapeR > hubR + 4 {
                let midR = (hubR + tapeR) / 2
                ctx.stroke(Circle().path(in: CGRect(x: center.x - midR, y: center.y - midR, width: midR * 2, height: midR * 2)),
                          with: .color(colorScheme == .dark ? .white.opacity(0.04) : .white.opacity(0.08)), lineWidth: 0.5)
            }
        }

        // 过带线
        let passY = winRect.maxY - 3
        var passLine = Path()
        passLine.move(to: CGPoint(x: leftCenter.x, y: passY))
        passLine.addLine(to: CGPoint(x: rightCenter.x, y: passY))
        ctx.stroke(passLine, with: .color(reelColor), lineWidth: 1.5)

        // 齿轮
        let rotAngle = isPlaying ? t * -2.5 : 0
        let hubColor = colorScheme == .dark ? Color(hex: "3D3530") : Color.white
        let spokeColor = colorScheme == .dark ? Color.black.opacity(0.5) : Color(hex: "C8C0B4")

        for center in [leftCenter, rightCenter] {
            let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
            ctx.fill(Circle().path(in: hubRect), with: .color(hubColor))
            ctx.stroke(Circle().path(in: hubRect), with: .color(strokeColor), lineWidth: 1)

            // 6 辐条
            var spokes = Path()
            let innerR: CGFloat = 4
            let outerR = hubR - 3
            for i in 0..<6 {
                let rad = Double(i) * .pi / 3.0 + rotAngle
                spokes.move(to: CGPoint(x: center.x + CGFloat(cos(rad)) * innerR, y: center.y + CGFloat(sin(rad)) * innerR))
                spokes.addLine(to: CGPoint(x: center.x + CGFloat(cos(rad)) * outerR, y: center.y + CGFloat(sin(rad)) * outerR))
            }
            ctx.stroke(spokes, with: .color(spokeColor), lineWidth: 2)

            // 中心孔
            ctx.fill(Circle().path(in: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(windowColor))

            // 6 齿轮点
            for i in 0..<6 {
                let rad = Double(i) * .pi / 3.0 + rotAngle
                let dotR: CGFloat = 1.5
                ctx.fill(Circle().path(in: CGRect(
                    x: center.x + CGFloat(cos(rad)) * 6 - dotR,
                    y: center.y + CGFloat(sin(rad)) * 6 - dotR,
                    width: dotR * 2, height: dotR * 2
                )), with: .color(spokeColor))
            }
        }
    }

    /// 底部导带槽
    private func drawGuideSlot(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let slotY = h - 18
        let slotColor = colorScheme == .dark ? Color(hex: "1A1714") : Color(hex: "D4CCC0")
        // 三个导带柱
        let positions: [CGFloat] = [w * 0.28, w * 0.5, w * 0.72]
        for x in positions {
            ctx.fill(Circle().path(in: CGRect(x: x - 3, y: slotY - 3, width: 6, height: 6)), with: .color(slotColor))
        }
        // 连接线
        var line = Path()
        line.move(to: CGPoint(x: positions.first! - 1, y: slotY))
        line.addLine(to: CGPoint(x: positions.last! + 1, y: slotY))
        ctx.stroke(line, with: .color(slotColor.opacity(0.5)), lineWidth: 1)
    }
}


// MARK: - 顶栏

extension CassettePlayerLayout {

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                AsideIcon(icon: .close, size: 18, color: textPrimary)
                    .frame(width: 40, height: 40)
                    .background(shellColor)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(strokeColor, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 音质标签
            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .asideGlass(cornerRadius: 15)
                    .overlay(Capsule().stroke(strokeColor, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            if let info = player.streamInfo {
                Text(streamInfoText(info))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(textMuted.opacity(0.7))
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() }
            }) {
                AsideIcon(icon: .more, size: 18, color: textPrimary)
                    .frame(width: 40, height: 40)
                    .background(shellColor)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(strokeColor, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - 歌曲信息

extension CassettePlayerLayout {

    private var songInfoArea: some View {
        VStack(spacing: 8) {
            Text(player.currentSong?.name ?? "")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let artist = player.currentSong?.artistName, !artist.isEmpty {
                Text(artist)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(textMuted)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - 进度条

extension CassettePlayerLayout {

    private func progressBar(width: CGFloat) -> some View {
        VStack(spacing: 6) {
            // 进度滑块 — 复古风格细线
            GeometryReader { geo in
                let barW = geo.size.width
                ZStack(alignment: .leading) {
                    // 底轨
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                        .frame(height: 3)

                    // 已播放
                    Capsule()
                        .fill(accentColor)
                        .frame(width: barW * CGFloat(progress), height: 3)

                    // 拖拽手柄
                    Circle()
                        .fill(accentColor)
                        .frame(width: isDragging ? 14 : 8, height: isDragging ? 14 : 8)
                        .offset(x: barW * CGFloat(progress) - (isDragging ? 7 : 4))
                        .animation(.spring(response: 0.2), value: isDragging)
                }
                .contentShape(Rectangle().inset(by: -16))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let ratio = max(0, min(1, Double(value.location.x / barW)))
                            dragValue = ratio * player.duration
                        }
                        .onEnded { value in
                            let ratio = max(0, min(1, Double(value.location.x / barW)))
                            let target = ratio * player.duration
                            player.seek(to: target)
                            isDragging = false
                        }
                )
            }
            .frame(height: 14)

            // 时间标签
            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(textMuted)
                Spacer()
                Text(formatTime(player.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(textMuted)
            }
        }
    }
}

// MARK: - 歌词

extension CassettePlayerLayout {

    private var lyricsContent: some View {
        ZStack {
            if let song = player.currentSong {
                LyricsView(song: song, onBackgroundTap: {})
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 控制栏

extension CassettePlayerLayout {

    private var controls: some View {
        HStack(spacing: 0) {
            // 播放模式
            Button(action: { player.switchMode() }) {
                AsideIcon(icon: player.mode.asideIcon, size: 18, color: textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 上一首
            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 22, color: textPrimary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放/暂停 — 复古圆形按钮
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { bounceTrigger = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounceTrigger = false }
                }
                player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 64, height: 64)
                        .overlay(Circle().stroke(accentColor.opacity(0.3), lineWidth: 3).scaleEffect(1.15))
                        .scaleEffect(bounceTrigger ? 0.85 : 1.0)

                    if player.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        AsideIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 26, color: .white
                        )
                        .offset(x: player.isPlaying ? 0 : 2)
                        .scaleEffect(bounceTrigger ? 0.85 : 1.0)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // 下一首
            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 22, color: textPrimary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放列表
            Button(action: { showPlaylist = true }) {
                AsideIcon(icon: .list, size: 18, color: textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - 辅助

extension CassettePlayerLayout {

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
        return parts.joined(separator: " · ")
    }
}
