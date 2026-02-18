import SwiftUI
import LiquidGlassEffect

// MARK: - Subviews for Performance
struct MiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = PlayerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                CachedAsyncImage(url: song.coverUrl) {
                    Color.gray.opacity(0.3)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .cornerRadius(6)
                .overlay {
                    // 播放来源小图标（居中覆盖在封面上）
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.rounded(size: 12, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(song.artistName)
                            .font(.rounded(size: 10, weight: .medium))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(Color.asideIconBackground)
                                .frame(width: 32, height: 32)
                            
                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .asideIconForeground))
                                    .scaleEffect(0.6)
                            } else {
                                if isPlaying {
                                    AsideIcon(icon: .pause, size: 14, color: .asideIconForeground)
                                } else {
                                    AsideIcon(icon: .play, size: 14, color: .asideIconForeground)
                                }
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    Button(action: { showPlaylist.toggle() }) {
                        AsideIcon(icon: .list, size: 16, color: .asideTextPrimary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    if !isPlaying {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                player.stopAndClear()
                            }
                        }) {
                            AsideIcon(icon: .close, size: 12, color: .gray)
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                // 防止按钮区域被 onTapGesture 吞掉
                .zIndex(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background {
                // 用背景区域接收点击，避免 contentShape + onTapGesture 覆盖子按钮
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
            }
            
            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    /// 播放来源角标
    private func sourceIndicator(icon: AsideIcon.IconType) -> some View {
        AsideIcon(icon: icon, size: 14, color: Color(red: 1, green: 1, blue: 1), lineWidth: 1.8)
    }
}

struct ProgressBarView: View {
    @ObservedObject var player = PlayerManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 3)
                
                // 限制进度在 0...1 范围内，防止超出
                let rawProgress = player.duration > 0 ? player.currentTime / player.duration : 0
                let progress = min(max(rawProgress, 0), 1)
                Capsule()
                    .fill(Color.asideIconBackground)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 3)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
    }
}

// MARK: - Aside TabBar (使用 LiquidGlassEffect 风格)
struct AsideTabBar: View {
    @Binding var selectedIndex: Int
    @ObservedObject private var settings = SettingsManager.shared
    
    /// 每个 tab 的宽度
    private let itemWidth: CGFloat = 64
    /// 每个 tab 的高度
    private let itemHeight: CGFloat = 44
    /// 气泡宽度
    private let bubbleWidth: CGFloat = 56
    /// 内边距
    private let padding: CGFloat = 6
    
    private let items: [(icon: AsideIcon.IconType, label: String)] = [
        (.home, NSLocalizedString("tabbar_home", comment: "")),
        (.podcast, NSLocalizedString("tabbar_podcast", comment: "")),
        (.library, NSLocalizedString("tabbar_library", comment: "")),
        (.profile, NSLocalizedString("tabbar_profile", comment: ""))
    ]
    
    /// 计算气泡的水平偏移量
    private var bubbleOffset: CGFloat {
        let totalWidth = CGFloat(items.count) * itemWidth
        let startX = -totalWidth / 2 + itemWidth / 2
        return startX + CGFloat(selectedIndex) * itemWidth
    }
    
    var body: some View {
        ZStack {
            // 单一气泡 - 通过位置动画移动，避免闪烁
            Group {
                if settings.liquidGlassEnabled {
                    LiquidGlassContainer(config: .thumb(), cornerRadius: 16) {
                        Color.clear
                            .frame(width: bubbleWidth, height: itemHeight)
                    }
                } else {
                    // 原生毛玻璃气泡
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .frame(width: bubbleWidth, height: itemHeight)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
            }
            .offset(x: bubbleOffset)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedIndex)
            
            HStack(spacing: 0) {
                ForEach(0..<items.count, id: \.self) { index in
                    AsideTabItemView(
                        icon: items[index].icon,
                        label: items[index].label,
                        isSelected: selectedIndex == index
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            selectedIndex = index
                        }
                    }
                    .frame(width: itemWidth, height: itemHeight)
                }
            }
        }
        .padding(.vertical, padding)
    }
}

// MARK: - Tab Item View (复用 LiquidGlassEffect 风格)
private struct AsideTabItemView: View {
    let icon: AsideIcon.IconType
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 2) {
                AsideIcon(icon: icon, size: 20, color: isSelected ? .asideTextPrimary : .asideTextPrimary.opacity(0.4))
                    .scaleEffect(isSelected ? 1.05 : 0.95)
                
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .asideTextPrimary : .asideTextPrimary.opacity(0.4))
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }
}

// MARK: - Unified Floating Bar
struct UnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
                ))
            }
            
            // 使用新的 AsideTabBar
            AsideTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
        }
        .background {
            // 根据设置选择液态玻璃或原生毛玻璃
            if settings.liquidGlassEnabled {
                // 使用 .liquidGlass 修饰器
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.asideCardBackground.opacity(0.4))
                    .liquidGlass(config: .regular, cornerRadius: 20, backgroundCaptureFrameRate: 30)
            } else {
                // 原生毛玻璃效果
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.2), value: player.currentSong != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentTab)
        .animation(.easeInOut(duration: 0.3), value: settings.liquidGlassEnabled)
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    
                    if value.translation.width < 0 {
                        switchTab(direction: 1)
                    } else if value.translation.width > 0 {
                        switchTab(direction: -1)
                    }
                }
        )
    }
    
    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        
        let nextIndex = currentIndex + direction
        
        if nextIndex >= 0 && nextIndex < allTabs.count {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

// MARK: - Tab Enum Extension for Aside Icons
extension Tab {
    var asideIcon: AsideIcon.IconType {
        switch self {
        case .home: return .home
        case .podcast: return .podcast
        case .library: return .library
        case .profile: return .profile
        }
    }
}
