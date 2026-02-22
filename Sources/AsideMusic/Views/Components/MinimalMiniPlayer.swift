import SwiftUI

/// 极简模式的 MiniPlayer（同一容器内左滑显示 Tab，右滑回播放器）
struct MinimalMiniPlayer: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @State private var showPlaylist = false
    
    // 当前显示模式：false = 迷你播放器，true = Tab 选择器
    @State private var showingTabs = false
    
    var body: some View {
        ZStack {
            if player.currentSong != nil {
                // 有歌曲时：迷你播放器 / Tab 选择器切换
                miniPlayerContent
                    .opacity(showingTabs ? 0 : 1)
                    .offset(x: showingTabs ? -50 : 0)
                
                tabSelectorContent
                    .opacity(showingTabs ? 1 : 0)
                    .offset(x: showingTabs ? 0 : 50)
            } else {
                // 无歌曲时：只显示 Tab 选择器
                tabSelectorContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let threshold: CGFloat = 30
                    // 只处理水平滑动
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    
                    withAnimation(AsideAnimation.panelToggle) {
                        if value.translation.width < -threshold {
                            // 左滑显示 Tab
                            showingTabs = true
                        } else if value.translation.width > threshold {
                            // 右滑显示播放器
                            showingTabs = false
                        }
                    }
                }
        )
        .animation(AsideAnimation.panelToggle, value: showingTabs)
    }
    
    // MARK: - 迷你播放器内容
    
    private var miniPlayerContent: some View {
        HStack(spacing: 10) {
            // 封面
            Group {
                if let song = player.currentSong {
                    CachedAsyncImage(url: song.coverUrl) {
                        defaultVinylCover
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    defaultVinylCover
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if player.playSource == .fm {
                    sourceIndicator(icon: .fm)
                } else if player.isPlayingPodcast {
                    sourceIndicator(icon: .radio)
                }
            }
            
            // 歌曲信息 - 使用跑马灯
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: player.currentSong?.name ?? NSLocalizedString("not_playing", comment: "未在播放"),
                    font: .system(size: 13, weight: .semibold, design: .rounded),
                    color: .asideTextPrimary,
                    speed: 25
                )
                .frame(height: 16)
                
                Text(player.currentSong?.artistName ?? NSLocalizedString("select_song_to_play", comment: "选择歌曲开始播放"))
                    .font(.rounded(size: 11, weight: .medium))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            // 控制按钮
            HStack(spacing: 10) {
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.asideIconBackground)
                            .frame(width: 34, height: 34)
                        
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .asideIconForeground))
                                .scaleEffect(0.55)
                        } else {
                            AsideIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 14,
                                color: .asideIconForeground
                            )
                        }
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                Button(action: { showPlaylist.toggle() }) {
                    AsideIcon(icon: .list, size: 16, color: .asideTextPrimary.opacity(0.7))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
        .onTapWithHaptic {
            if player.currentSong != nil {
                openPlayer()
            }
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - 默认黑胶封面
    
    private var defaultVinylCover: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "1A1A1A"))
            
            // 沟槽
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                .padding(4)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .padding(8)
            
            // 中心
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 14, height: 14)
                .overlay(
                    AsideIcon(icon: .musicNote, size: 8, color: .white.opacity(0.6))
                )
        }
    }
    
    // MARK: - Tab 选择器内容
    
    private var tabSelectorContent: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(AsideAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        AsideIcon(
                            icon: tab.asideIcon,
                            size: 18,
                            color: currentTab == tab ? .asideAccent : .asideTextSecondary.opacity(0.4)
                        )
                        Text(NSLocalizedString(tab.titleKey, comment: ""))
                            .font(.system(size: 9, weight: currentTab == tab ? .semibold : .medium))
                            .foregroundColor(currentTab == tab ? .asideAccent : .asideTextSecondary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 玻璃背景
    
    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.asideGlassOverlay)
        }
    }
    
    // MARK: - 辅助方法
    
    private func sourceIndicator(icon: AsideIcon.IconType) -> some View {
        AsideIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
    }
    
    private func openPlayer() {
        withAnimation(AsideAnimation.playerTransition) {
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
