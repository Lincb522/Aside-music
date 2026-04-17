import SwiftUI

/// 极简模式的 MiniPlayer（同一容器内左滑显示 Tab，右滑回播放器）
struct MinimalMiniPlayer: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared
    @State private var showPlaylist = false
    
    @State private var showingTabs = false

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return player.currentSong?.artistName ?? NSLocalizedString("select_song_to_play", comment: String(localized: "选择歌曲开始播放"))
    }
    
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
        .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.monologueFloatingBarFill)
        )
        .monologueGlass(cornerRadius: 18)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    let threshold: CGFloat = 15
                    let maxTabSwitchDistance: CGFloat = 44
                    // 只处理水平滑动（宽度大于高度的 1.5 倍）
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }

                    // 迷你播放器可见时，较长的横滑交给切歌手势处理
                    if player.currentSong != nil && !showingTabs,
                       abs(value.translation.width) > maxTabSwitchDistance {
                        return
                    }
                    
                    withAnimation(MonologueAnimation.panelToggle) {
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
        .animation(MonologueAnimation.panelToggle, value: showingTabs)
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
            
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: player.currentSong?.name ?? NSLocalizedString("not_playing", comment: String(localized: "未在播放")),
                    font: .system(size: 13, weight: .semibold, design: .rounded),
                    color: .monologueTextPrimary,
                    speed: 25
                )
                .frame(height: 16)
                
                Text(subtitleText)
                    .font(.rounded(size: 11, weight: .medium))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
            }
            
            Spacer(minLength: 4)
            
            // 控制按钮
            HStack(spacing: 10) {
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.monologueIconBackground)
                            .frame(width: 34, height: 34)
                        
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .monologueIconForeground))
                                .scaleEffect(0.55)
                        } else {
                            MonologueIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 14,
                                color: .monologueIconForeground
                            )
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Button(action: { showPlaylist.toggle() }) {
                    MonologueIcon(icon: .list, size: 16, color: .monologueTextPrimary.opacity(0.7))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
        .swipeToSkip()
        .onTapWithHaptic {
            if player.currentSong != nil {
                openPlayer()
            }
        }
        .sheet(isPresented: $showPlaylist) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                PlaylistPopupView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - 默认黑胶封面
    
    private var defaultVinylCover: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "1A1A1A"))
            
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                .padding(4)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .padding(8)
            
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 14, height: 14)
                .overlay(
                    MonologueIcon(icon: .musicNote, size: 8, color: .white.opacity(0.6))
                )
        }
    }
    
    // MARK: - Tab 选择器内容
    
    private var tabSelectorContent: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        MonologueIcon(
                            icon: tab.monologueIcon,
                            size: 18,
                            color: currentTab == tab ? .monologueAccent : .monologueTextSecondary.opacity(0.4)
                        )
                        Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                            .font(.system(size: 9, weight: currentTab == tab ? .semibold : .medium))
                            .foregroundColor(currentTab == tab ? .monologueAccent : .monologueTextSecondary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
    }
    
    private func openPlayer() {
        withAnimation(MonologueAnimation.playerTransition) {
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
