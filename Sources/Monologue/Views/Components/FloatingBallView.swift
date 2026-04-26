import SwiftUI

/// 悬浮球样式 - 黑胶唱片悬浮球 + 弹出式控制面板
struct FloatingBallView: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    
    // 控制面板状态
    @State private var isPanelOpen = false
    
    // 唱片旋转角度
    @State private var rotationAngle: Double = 0
    @State private var lastTickDate: Date? = nil
    
    private let ballSize: CGFloat = 56
    
    var body: some View {
        GeometryReader { geometry in
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
            TimelineView(.animation(minimumInterval: 0.033, paused: !player.isPlaying)) { timeline in
                vinylDisc
                    .frame(width: ballSize - 8, height: ballSize - 8)
                    .rotationEffect(.degrees(rotationAngle))
                    .onChange(of: timeline.date) { oldDate, newDate in
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
        .background(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .fill(ThemedPageStyle.isActive ? Color.clear : Color.monologueFloatingBarFill.opacity(0.06))
        )
        .monologueGlass(cornerRadius: panelCornerRadius)
        .padding(.trailing, 8)
    }
    
    // MARK: - Tab 切换区域
    
    private var tabSection: some View {
        let items: [(tab: Tab, icon: MonologueIcon.IconType)] = [
            (.home, .home),
            (.podcast, .podcast),
            (.library, .library),
            (.profile, .profile)
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
        case .podcast(let radioId):
            NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioId)
        case .normal:
            NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
        }
    }

    private var panelCornerRadius: CGFloat {
        MangaStyle.isActive ? 18 : 20
    }

    private var panelScrimColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.24) }
        if MujiStyle.isActive { return MujiStyle.ink.opacity(0.16) }
        return Color.black.opacity(0.3)
    }

    private var progressLineWidth: CGFloat {
        MangaStyle.isActive ? 3 : 2.5
    }

    private var progressTrackColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.18) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.5) }
        return Color.monologueTextPrimary.opacity(0.08)
    }

    private var progressFill: some ShapeStyle {
        if MangaStyle.isActive {
            return AnyShapeStyle(LinearGradient(colors: [MangaStyle.accentPink, MangaStyle.labelYellow], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if MujiStyle.isActive {
            return AnyShapeStyle(MujiStyle.accentGradient)
        }
        return AnyShapeStyle(Color.monologueAccent.opacity(0.6))
    }

    private var vinylBaseFill: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.ink.opacity(0.82) }
        return Color(hex: "1A1A1A")
    }

    private var vinylGrooveColor: Color {
        if MangaStyle.isActive { return MangaStyle.onStrokeInk.opacity(0.12) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.2) }
        return Color.white.opacity(0.06)
    }

    private var emptyCoverFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if MujiStyle.isActive { return MujiStyle.paperWarm }
        return Color.gray.opacity(0.3)
    }

    private var emptyCoverIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        return Color.white.opacity(0.5)
    }

    private var panelDividerColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.28) }
        if MujiStyle.isActive { return MujiStyle.separator.opacity(0.72) }
        return Color.monologueSeparator.opacity(0.3)
    }

    private var playControlFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if MujiStyle.isActive { return MujiStyle.paperWarm.opacity(0.76) }
        return .monologueIconBackground
    }

    private var playControlForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.ink }
        return .monologueIconForeground
    }

    @ViewBuilder
    private var playControlStroke: some View {
        if MangaStyle.isActive {
            Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.6)
        } else if MujiStyle.isActive {
            Circle().stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
        }
    }

    private func tabForeground(_ tab: Tab, isSelected: Bool) -> Color {
        guard isSelected else {
            if MangaStyle.isActive { return MangaStyle.inkMuted }
            if MujiStyle.isActive { return MujiStyle.inkMuted }
            return .monologueTextSecondary
        }

        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return mujiTabTint(tab) }
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
}
