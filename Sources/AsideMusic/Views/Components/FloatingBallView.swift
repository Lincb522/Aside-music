import SwiftUI

/// 悬浮球样式 - 黑胶唱片悬浮球 + 弹出式控制面板
struct FloatingBallView: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    
    // 控制面板状态
    @State private var isPanelOpen = false
    
    // 唱片旋转角度
    @State private var rotationAngle: Double = 0
    
    private let ballSize: CGFloat = 56
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 遮罩
                if isPanelOpen {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapWithHaptic(.soft) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
        .onAppear {
            startRotationIfNeeded()
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if isPlaying {
                startRotation()
            }
        }
    }
    
    // MARK: - 悬浮球
    
    private var floatingBall: some View {
        ZStack {
            // 进度环
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                .frame(width: ballSize, height: ballSize)
            
            let progress = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.asideAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: ballSize, height: ballSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
            
            // 黑胶唱片
            vinylDisc
                .frame(width: ballSize - 8, height: ballSize - 8)
                .rotationEffect(.degrees(rotationAngle))
        }
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: ballSize + 4, height: ballSize + 4)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .contentShape(Circle())
        .asideMultiGesture(
            onTap: {
                // 单击展开/收起面板
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 40)
                .padding(.horizontal, 8)
            
            // 播放控制
            playbackSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                        Circle()
                            .fill(currentTab == item.tab ? Color.asideAccent.opacity(0.15) : Color.clear)
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
    
    // MARK: - 旋转动画
    
    private func startRotationIfNeeded() {
        if player.isPlaying {
            startRotation()
        }
    }
    
    private func startRotation() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
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
