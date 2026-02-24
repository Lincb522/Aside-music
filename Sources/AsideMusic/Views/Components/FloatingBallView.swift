import SwiftUI

/// 悬浮球样式 - 黑胶唱片悬浮球 + 弹出式控制面板
struct FloatingBallView: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    
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
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapWithHaptic(.soft) {
                            withAnimation(AsideAnimation.panelToggle) {
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
                .stroke(Color.asideTextPrimary.opacity(0.08), lineWidth: 2.5)
                .frame(width: ballSize, height: ballSize)
            
            let progress = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.asideAccent.opacity(0.6), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: ballSize, height: ballSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
            
            // 黑胶唱片
            TimelineView(.animation(paused: !player.isPlaying)) { timeline in
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
                .fill(Color.asideFloatingBarFill)
                .frame(width: ballSize + 4, height: ballSize + 4)
        )
        .glassEffect(.regular, in: .circle)
        .contentShape(Circle())
        .asideMultiGesture(
            onTap: {
                // 单击展开/收起面板
                withAnimation(AsideAnimation.panelToggle) {
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
                .fill(Color(hex: "1A1A1A"))
            
            // 沟槽
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .padding(5)
            Circle()
                .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
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
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 22, height: 22)
                    .overlay(
                        AsideIcon(icon: .musicNote, size: 10, color: .white.opacity(0.5))
                    )
            }
            
            // 中心孔
            Circle()
                .fill(Color(hex: "1A1A1A"))
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
                .fill(Color.asideSeparator.opacity(0.3))
                .frame(width: 0.5, height: 36)
                .padding(.horizontal, 8)
            
            // 播放控制
            playbackSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.trailing, 8)
    }
    
    // MARK: - Tab 切换区域
    
    private var tabSection: some View {
        let items: [(tab: Tab, icon: AsideIcon.IconType)] = [
            (.home, .home),
            (.podcast, .podcast),
            (.library, .library),
            (.profile, .profile)
        ]
        
        return HStack(spacing: 6) {
            ForEach(items, id: \.tab) { item in
                Button {
                    HapticManager.shared.light()
                    withAnimation(AsideAnimation.tabSwitch) {
                        currentTab = item.tab
                    }
                } label: {
                    AsideIcon(
                        icon: item.icon,
                        size: 18,
                        color: currentTab == item.tab ? .asideAccent : .asideTextSecondary
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        Group {
                            if currentTab == item.tab {
                                Circle()
                                    .fill(Color.asideFloatingBarFill)
                                    .glassEffect(Glass.regular.tint(Color.asideAccent.opacity(0.2)), in: .circle)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
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
                    .fill(Color.asideIconBackground)
                    .frame(width: 40, height: 40)
                
                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .asideIconForeground))
                        .scaleEffect(0.6)
                } else {
                    AsideIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 16,
                        color: .asideIconForeground
                    )
                }
            }
        }
        .buttonStyle(AsideBouncingButtonStyle())
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
}
