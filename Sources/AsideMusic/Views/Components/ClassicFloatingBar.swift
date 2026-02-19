import SwiftUI
import LiquidGlassEffect

/// 经典风格的统一悬浮栏（MiniPlayer + TabBar 合一，贴底不悬浮）
struct ClassicFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // MiniPlayer 部分
                if let song = player.currentSong {
                    ClassicMiniPlayerSection(
                        song: song,
                        isPlaying: player.isPlaying,
                        togglePlayPause: { player.togglePlayPause() }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    
                    Divider()
                }
                
                // TabBar 部分
                ClassicTabBarSection(currentTab: $currentTab)
            }
            .background {
                if settings.liquidGlassEnabled {
                    Rectangle()
                        .fill(Color.asideCardBackground.opacity(0.6))
                        .liquidGlass(config: .regular, cornerRadius: 0, backgroundCaptureFrameRate: 30)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.asideSeparator.opacity(0.5))
                    .frame(height: 0.5)
            }
        }
        .padding(.bottom, 0) // 贴底，不留边距
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.currentSong != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentTab)
    }
}

// MARK: - 经典 MiniPlayer 部分
private struct ClassicMiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = PlayerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 封面
                CachedAsyncImage(url: song.coverUrl) {
                    Color.gray.opacity(0.3)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .cornerRadius(6)
                .overlay {
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }
                
                // 歌曲信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.rounded(size: 11, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 控制按钮
                HStack(spacing: 14) {
                    Button(action: togglePlayPause) {
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
                                    icon: isPlaying ? .pause : .play,
                                    size: 14,
                                    color: .asideIconForeground
                                )
                            }
                        }
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    Button(action: { showPlaylist.toggle() }) {
                        AsideIcon(icon: .list, size: 16, color: .asideTextPrimary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    if !isPlaying {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                player.stopAndClear()
                            }
                        }) {
                            AsideIcon(icon: .close, size: 10, color: .gray)
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
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
            
            // 进度条
            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func sourceIndicator(icon: AsideIcon.IconType) -> some View {
        AsideIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
    }
}

// MARK: - 经典 TabBar 部分（无气泡动画，直接高亮）
private struct ClassicTabBarSection: View {
    @Binding var currentTab: Tab
    
    private let items: [(icon: AsideIcon.IconType, label: String)] = [
        (.home, NSLocalizedString("tabbar_home", comment: "")),
        (.podcast, NSLocalizedString("tabbar_podcast", comment: "")),
        (.library, NSLocalizedString("tabbar_library", comment: "")),
        (.profile, NSLocalizedString("tabbar_profile", comment: ""))
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                let tab = Tab.allCases[index]
                let isSelected = currentTab == tab
                
                Button {
                    HapticManager.shared.light()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        AsideIcon(
                            icon: items[index].icon,
                            size: 22,
                            color: isSelected ? .asideTextPrimary : .asideTextPrimary.opacity(0.4)
                        )
                        
                        Text(items[index].label)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .asideTextPrimary : .asideTextPrimary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }
}
