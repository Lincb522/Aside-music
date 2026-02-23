import SwiftUI

// MARK: - Subviews for Performance
struct MiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = PlayerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 封面 - 增大尺寸，圆角更精致
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }
                
                // 歌曲信息 - 使用跑马灯避免长标题截断
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.name,
                        font: .system(size: 13, weight: .semibold, design: .rounded),
                        color: .asideTextPrimary,
                        speed: 25
                    )
                    .frame(height: 16)
                    
                    Text(song.artistName)
                        .font(.rounded(size: 11, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                
                // 控制按钮
                HStack(spacing: 10) {
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
                                AsideIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 14,
                                    color: .asideIconForeground
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    Button(action: { showPlaylist.toggle() }) {
                        AsideIcon(icon: .list, size: 16, color: .asideTextPrimary.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    if !isPlaying {
                        Button(action: {
                            withAnimation(AsideAnimation.floatingBar) {
                                player.stopAndClear()
                            }
                        }) {
                            AsideIcon(icon: .close, size: 10, color: .asideTextSecondary)
                                .frame(width: 28, height: 28)
                                .background(Color.gray.opacity(0.08))
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
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
            
            ProgressBarView()
                .frame(height: 2.5)
                .padding(.horizontal, 14)
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
        AsideIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
    }
}

struct ProgressBarView: View {
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 轨道 - 更柔和的背景
                Capsule()
                    .fill(Color.asideTextPrimary.opacity(0.06))
                    .frame(height: 2.5)
                
                // 进度 - 使用强调色，更细腻
                let progress = timePublisher.progress
                Capsule()
                    .fill(Color.asideAccent.opacity(0.5))
                    .frame(width: max(geometry.size.width * CGFloat(progress), 0), height: 2.5)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
    }
}

// MARK: - Aside TabBar
struct AsideTabBar: View {
    @Binding var selectedIndex: Int
    @Namespace private var tabNS
    
    private let itemWidth: CGFloat = 64
    private let itemHeight: CGFloat = 42
    private let padding: CGFloat = 4
    
    var body: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, icon: .home, label: NSLocalizedString("tabbar_home", comment: ""))
            tabButton(index: 1, icon: .podcast, label: NSLocalizedString("tabbar_podcast", comment: ""))
            tabButton(index: 2, icon: .library, label: NSLocalizedString("tabbar_library", comment: ""))
            tabButton(index: 3, icon: .profile, label: NSLocalizedString("tabbar_profile", comment: ""))
        }
        .padding(.vertical, padding)
    }
    
    @ViewBuilder
    private func tabButton(index: Int, icon: AsideIcon.IconType, label: String) -> some View {
        let isSelected = selectedIndex == index
        Button {
            HapticManager.shared.light()
            withAnimation(AsideAnimation.tabSwitch) {
                selectedIndex = index
            }
        } label: {
            VStack(spacing: 2) {
                AsideIcon(
                    icon: icon,
                    size: 18,
                    color: isSelected ? .asideTextPrimary : .asideTextPrimary.opacity(0.35)
                )
                
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .asideTextPrimary : .asideTextPrimary.opacity(0.35))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: itemWidth, height: itemHeight)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.asideTextPrimary.opacity(0.1))
                        .matchedGeometryEffect(id: "tabHighlight", in: tabNS)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unified Floating Bar
struct UnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                ))
            }
            
            AsideTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .animation(AsideAnimation.floatingBar, value: player.currentSong != nil)
        .animation(AsideAnimation.tabSwitch, value: currentTab)
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
            withAnimation(AsideAnimation.tabSwitch) {
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
