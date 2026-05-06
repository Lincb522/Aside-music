import SwiftUI

/// 悬浮球样式 - 黑胶唱片悬浮球 + 弹出式控制面板
struct FloatingBallView: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    /// 控制面板状态
    @State private var isPanelOpen = false

    // 唱片旋转角度
    @State private var rotationAngle: Double = 0
    @State private var lastTickDate: Date? = nil

    private var ballSize: CGFloat {
        SequoiaStyle.isActive ? 60 : 56
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { _ in
            ZStack {
                // 遮罩
                if isPanelOpen {
                    panelScrimColor
                        .ignoresSafeArea()
                        .onTapWithHaptic(.soft) {
                            withAnimation(MonologueAnimation.panelToggle) {
                                isPanelOpen = false
                            }
                        }
                        .transition(.opacity)
                }

                // 悬浮球固定在右下角
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        HStack(spacing: 0) {
                            // 弹出的控制面板（从悬浮球左边展开）
                            if isPanelOpen {
                                controlPanel
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity),
                                        removal: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity)
                                    ))
                            }

                            // 悬浮球
                            floatingBall
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                        .themeRenderInteractiveLayer()
                    }
                }
            }
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if !isPlaying {
                lastTickDate = nil
            }
        }
    }

    // MARK: - 悬浮球

    private var floatingBall: some View {
        ZStack {
            // 进度环 - 轨道更柔和
            Circle()
                .stroke(progressTrackColor, lineWidth: progressLineWidth)
                .frame(width: ballSize, height: ballSize)

            let progress = timePublisher.duration > 0 ? min(max(timePublisher.currentTime / timePublisher.duration, 0), 1) : 0
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(progressFill, style: StrokeStyle(lineWidth: progressLineWidth, lineCap: .round))
                .frame(width: ballSize, height: ballSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            // 黑胶唱片
            TimelineView(AppFrameRate.animationTimeline(paused: !player.isPlaying)) { timeline in
                vinylDisc
                    .frame(width: ballSize - 8, height: ballSize - 8)
                    .rotationEffect(.degrees(rotationAngle))
                    .onChange(of: timeline.date) { _, newDate in
                        guard player.isPlaying else {
                            lastTickDate = nil
                            return
                        }
                        if let last = lastTickDate {
                            let dt = newDate.timeIntervalSince(last)
                            rotationAngle += dt * 45.0
                        }
                        lastTickDate = newDate
                    }
            }
        }
        .background(
            Circle()
                .fill(ThemedPageStyle.isActive ? Color.clear : Color.monologueFloatingBarFill)
                .frame(width: ballSize + 4, height: ballSize + 4)
        )
        .monologueGlassCircle()
        .overlay {
            if MangaStyle.isActive {
                Circle()
                    .stroke(MangaStyle.strokeInk, lineWidth: 2.2)
                    .frame(width: ballSize + 4, height: ballSize + 4)
                    .overlay(alignment: .topTrailing) {
                        MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 15)
                            .offset(x: 1, y: -3)
                    }
                    .shadow(color: MangaStyle.strokeInk.opacity(0.4), radius: 0, x: 3, y: 3)
            } else if SequoiaStyle.isActive {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.28 : 0.62),
                                SequoiaStyle.separator.opacity(0.68),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
                    .frame(width: ballSize + 4, height: ballSize + 4)
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(SequoiaStyle.highlight(colorScheme).opacity(colorScheme == .dark ? 0.08 : 0.5))
                            .frame(width: 16, height: 16)
                            .blur(radius: 6)
                            .offset(x: 10, y: 8)
                    }
                    .shadow(color: SequoiaStyle.shadow(colorScheme, elevated: true), radius: 16, x: 0, y: 7)
            } else if BentoStyle.isActive {
                Circle()
                    .stroke(BentoStyle.tomato, lineWidth: 2.4)
                    .frame(width: ballSize + 4, height: ballSize + 4)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(BentoStyle.mustard)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(BentoStyle.paper, lineWidth: 1.5))
                            .offset(x: 1, y: -1)
                    }
                    .shadow(color: BentoStyle.ink.opacity(0.18), radius: 10, x: 0, y: 5)
            }
        }
        .contentShape(Circle())
        .monologueMultiGesture(
            onTap: {
                // 单击展开/收起面板
                withAnimation(MonologueAnimation.panelToggle) {
                    isPanelOpen.toggle()
                }
            },
            onDoubleTap: {
                // 双击播放/暂停
                player.togglePlayPause()
            },
            onLongPress: {
                // 长按打开全屏播放器
                openPlayer()
            }
        )
    }

    // MARK: - 黑胶唱片

    private var vinylDisc: some View {
        ZStack {
            // 唱片底色
            Circle()
                .fill(vinylBaseFill)

            // 沟槽
            Circle()
                .stroke(vinylGrooveColor.opacity(0.7), lineWidth: 0.5)
                .padding(5)
            Circle()
                .stroke(vinylGrooveColor.opacity(0.45), lineWidth: 0.5)
                .padding(9)

            // 封面
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl) {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 22, height: 22)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(emptyCoverFill)
                    .frame(width: 22, height: 22)
                    .overlay(
                        MonologueIcon(icon: .musicNote, size: 10, color: emptyCoverIconColor)
                    )
            }

            // 中心孔
            Circle()
                .fill(vinylBaseFill)
                .frame(width: 5, height: 5)
        }
    }

    // MARK: - 控制面板

    private var controlPanel: some View {
        HStack(spacing: 0) {
            // Tab 切换
            tabSection

            // 分隔线 - 更柔和
            Rectangle()
                .fill(panelDividerColor)
                .frame(width: 0.5, height: 36)
                .padding(.horizontal, 8)

            // 播放控制
            playbackSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(panelBackground)
        .monologueGlass(cornerRadius: panelCornerRadius)
        .overlay {
            if MangaStyle.isActive {
                RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: 2)
                    .overlay(alignment: .topLeading) {
                        Capsule()
                            .fill(MangaStyle.accentPink)
                            .frame(width: 46, height: 5)
                            .offset(x: 16, y: 7)
                    }
            } else if SequoiaStyle.isActive {
                RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.18 : 0.5),
                                SequoiaStyle.separator.opacity(0.76),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.65
                    )
                    .overlay(alignment: .topLeading) {
                        Capsule()
                            .fill(SequoiaStyle.accent.opacity(0.64))
                            .frame(width: 42, height: 3)
                            .offset(x: 18, y: 7)
                    }
            } else if BentoStyle.isActive {
                RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                    .stroke(BentoStyle.ink.opacity(0.08), lineWidth: 1)
                    .overlay(alignment: .top) {
                        HStack(spacing: 0) {
                            BentoStyle.tomato.frame(width: 18, height: 4)
                            BentoStyle.matcha.frame(width: 12, height: 4)
                            BentoStyle.mustard.frame(width: 14, height: 4)
                        }
                        .clipShape(Capsule())
                        .offset(y: 6)
                    }
            }
        }
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: panelCornerRadius, elevated: true, role: .floating)
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .fill(BentoStyle.surface)
                .shadow(color: BentoStyle.ink.opacity(0.08), radius: 14, x: 0, y: 6)
        } else {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .fill(ThemedPageStyle.isActive ? Color.clear : Color.monologueFloatingBarFill.opacity(0.06))
        }
    }

    // MARK: - Tab 切换区域

    private var tabSection: some View {
        let items: [(tab: Tab, icon: MonologueIcon.IconType)] = [
            (.home, .home),
            (.podcast, .podcast),
            (.library, .library),
            (.profile, .profile),
        ]

        return HStack(spacing: 6) {
            ForEach(items, id: \.tab) { item in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = item.tab
                    }
                    // 切换 Tab 后自动收起面板
                    withAnimation(MonologueAnimation.panelToggle) {
                        isPanelOpen = false
                    }
                } label: {
                    MonologueIcon(
                        icon: item.icon,
                        size: 18,
                        color: tabForeground(item.tab, isSelected: currentTab == item.tab)
                    )
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                    .background {
                        if currentTab == item.tab {
                            tabSelectionBackground(item.tab)
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }

    // MARK: - 播放控制区域

    private var playbackSection: some View {
        // 播放/暂停
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(playControlFill)
                    .frame(width: 40, height: 40)
                    .overlay(playControlStroke)

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: playControlForeground))
                        .scaleEffect(0.6)
                } else {
                    MonologueIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 16,
                        color: playControlForeground
                    )
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    // MARK: - 打开播放器

    private func openPlayer() {
        switch player.playSource {
        case .fm:
            NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
        case let .podcast(radioId):
            NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioId)
        case .normal:
            NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
        }
    }

    private var panelCornerRadius: CGFloat {
        MangaStyle.isActive ? 22 : (NeumorphicStyle.isActive ? 24 : (SequoiaStyle.isActive ? 24 : 20))
    }

    private var panelScrimColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.24) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink.opacity(0.18) }
        if SequoiaStyle.isActive { return Color.black.opacity(colorScheme == .dark ? 0.2 : 0.12) }
        if MujiStyle.isActive { return MujiStyle.ink.opacity(0.16) }
        if BentoStyle.isActive { return BentoStyle.ink.opacity(0.18) }
        return Color.black.opacity(0.3)
    }

    private var progressLineWidth: CGFloat {
        MangaStyle.isActive ? 3 : (NeumorphicStyle.isActive ? 3 : (SequoiaStyle.isActive ? 2.8 : 2.5))
    }

    private var progressTrackColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.18) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.62) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.5) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.6) }
        return Color.monologueTextPrimary.opacity(0.08)
    }

    private var progressFill: some ShapeStyle {
        if MangaStyle.isActive {
            return AnyShapeStyle(LinearGradient(colors: [MangaStyle.accentPink, MangaStyle.labelYellow], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if MujiStyle.isActive {
            return AnyShapeStyle(MujiStyle.accentGradient)
        }
        if BentoStyle.isActive {
            return AnyShapeStyle(LinearGradient(colors: [BentoStyle.tomato, BentoStyle.mustard], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if NeumorphicStyle.isActive {
            return AnyShapeStyle(LinearGradient(colors: [NeumorphicStyle.accent, NeumorphicStyle.sage], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if SequoiaStyle.isActive {
            return AnyShapeStyle(SequoiaStyle.accentGradient)
        }
        return AnyShapeStyle(Color.monologueAccent.opacity(0.6))
    }

    private var vinylBaseFill: Color {
        if MangaStyle.isActive { return MangaStyle.bubbleWhite }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.95) }
        if MujiStyle.isActive { return MujiStyle.ink.opacity(0.82) }
        if BentoStyle.isActive { return BentoStyle.ink.opacity(0.85) }
        return Color(hex: "1A1A1A")
    }

    private var vinylGrooveColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.42) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent.opacity(0.18) }
        if SequoiaStyle.isActive { return SequoiaStyle.luminousSeparator.opacity(0.28) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.2) }
        if BentoStyle.isActive { return BentoStyle.surface.opacity(0.2) }
        return Color.white.opacity(0.06)
    }

    private var emptyCoverFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if MujiStyle.isActive { return MujiStyle.paperWarm }
        if BentoStyle.isActive { return BentoStyle.surface }
        return Color.gray.opacity(0.3)
    }

    private var emptyCoverIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkSoft }
        return Color.white.opacity(0.5)
    }

    private var panelDividerColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.28) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.58) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.separator.opacity(0.72) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.5) }
        return Color.monologueSeparator.opacity(0.3)
    }

    private var playControlFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if MujiStyle.isActive { return MujiStyle.paperWarm.opacity(0.76) }
        if BentoStyle.isActive { return BentoStyle.tomato }
        return .monologueIconBackground
    }

    private var playControlForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MujiStyle.isActive { return MujiStyle.ink }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        return .monologueIconForeground
    }

    @ViewBuilder
    private var playControlStroke: some View {
        if MangaStyle.isActive {
            Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.6)
        } else if MujiStyle.isActive {
            Circle().stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            Circle().stroke(NeumorphicStyle.separator.opacity(0.52), lineWidth: 0.8)
        } else if SequoiaStyle.isActive {
            Circle().stroke(SequoiaStyle.accent.opacity(0.22), lineWidth: 0.65)
        } else if BentoStyle.isActive {
            Circle().stroke(BentoStyle.tomato.opacity(0.0), lineWidth: 0)
        }
    }

    private func tabForeground(_ tab: Tab, isSelected: Bool) -> Color {
        guard isSelected else {
            if MangaStyle.isActive { return MangaStyle.inkMuted }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
            if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
            if MujiStyle.isActive { return MujiStyle.inkMuted }
            if BentoStyle.isActive { return BentoStyle.inkMuted }
            return .monologueTextSecondary
        }

        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return neumorphicTabTint(tab) }
        if SequoiaStyle.isActive { return sequoiaTabTint(tab) }
        if MujiStyle.isActive { return mujiTabTint(tab) }
        if BentoStyle.isActive { return bentoTabTint(tab) }
        return .monologueAccent
    }

    @ViewBuilder
    private func tabSelectionBackground(_ tab: Tab) -> some View {
        if MangaStyle.isActive {
            Circle()
                .fill(mangaTabTint(tab).opacity(0.88))
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.5))
        } else if MujiStyle.isActive {
            Circle()
                .fill(MujiStyle.surface.opacity(0.78))
                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.6))
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(bentoTabTint(tab))
        } else if NeumorphicStyle.isActive {
            Circle()
                .fill(neumorphicTabTint(tab).opacity(0.16))
                .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
        } else if SequoiaStyle.isActive {
            Circle()
                .fill(sequoiaTabTint(tab).opacity(0.13))
                .background(
                    SequoiaSurfaceBackground(
                        cornerRadius: 18,
                        elevated: false,
                        fill: sequoiaTabTint(tab).opacity(0.08),
                        role: .selected
                    )
                )
                .overlay(Circle().stroke(sequoiaTabTint(tab).opacity(0.22), lineWidth: 0.55))
        } else {
            Circle()
                .fill(Color.monologueFloatingBarFill)
                .monologueGlassTinted(Color.monologueAccent.opacity(0.2))
        }
    }

    private func mangaTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return MangaStyle.labelYellow
        case .podcast: return MangaStyle.bubbleBlue
        case .library: return MangaStyle.mint
        case .profile: return MangaStyle.bubblePink
        }
    }

    private func mujiTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return MujiStyle.clay
        case .podcast: return MujiStyle.tea
        case .library: return MujiStyle.indigo
        case .profile: return MujiStyle.straw
        }
    }

    private func bentoTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return BentoStyle.tomato
        case .podcast: return BentoStyle.nori
        case .library: return BentoStyle.matcha
        case .profile: return BentoStyle.mustard
        }
    }

    private func neumorphicTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return NeumorphicStyle.accent
        case .podcast: return NeumorphicStyle.warm
        case .library: return NeumorphicStyle.sage
        case .profile: return NeumorphicStyle.red
        }
    }

    private func sequoiaTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return SequoiaStyle.accent
        case .podcast: return SequoiaStyle.violet
        case .library: return SequoiaStyle.aqua
        case .profile: return SequoiaStyle.green
        }
    }
}
