import SwiftUI

/// 经典风格的统一悬浮栏（MiniPlayer + TabBar 合一，贴底不悬浮）
struct ClassicFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    
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
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    
                    // 分隔线 - 更柔和
                    Rectangle()
                        .fill(Color.monologueSeparator.opacity(0.3))
                        .frame(height: 0.5)
                        .padding(.horizontal, DeviceLayout.isPad ? 24 : 16)
                }
                
                // TabBar 部分
                ClassicTabBarSection(currentTab: $currentTab)
            }
            .background {
                Rectangle()
                    .fill(Color.monologueFloatingBarFill)
                    .monologueGlassPlainRect()
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.monologueSeparator.opacity(0.3))
                    .frame(height: 0.5)
            }
        }
        .padding(.bottom, 0)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }
}

// MARK: - 经典 MiniPlayer 部分
private struct ClassicMiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    private var subtitleText: String {
        if lyricVM.hasLyrics, !lyricVM.lyrics.isEmpty {
            return lyricVM.lyrics[lyricVM.currentLineIndex].text
        }
        return song.artistName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.name,
                        font: .system(size: 13, weight: .semibold, design: .rounded),
                        color: .monologueTextPrimary,
                        speed: 25,
                        alignment: .leading
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
                HStack(spacing: 12) {
                    Button(action: togglePlayPause) {
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
                                    icon: isPlaying ? .pause : .play,
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
                    
                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.stopAndClear()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 10, color: .monologueTextSecondary)
                                .frame(width: 28, height: 28)
                                .background(Color.monologueTextPrimary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .padding(.horizontal, DeviceLayout.isPad ? 24 : 16)
            .padding(.vertical, 10)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
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
            
            ProgressBarView()
                .frame(height: 2.5)
                .padding(.horizontal, DeviceLayout.isPad ? 32 : 24)
                .padding(.bottom, 4)
                .opacity(0.6)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
    }

    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
    }
}

// MARK: - Classic Tab Icon Animation Values

private struct ClassicTabAnimValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
    var offsetY: CGFloat = 0.0
}

// MARK: - 经典 TabBar 部分（带 outline/filled 切换 + 微动画）
private struct ClassicTabBarSection: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @State private var animTrigger: Int = -1

    private static let tabIcons: [(outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.tabIcons.count, id: \.self) { index in
                let tab = Tab.allCases[index]
                let isSelected = currentTab == tab
                let icons = Self.tabIcons[index]
                let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
                
                Button {
                    HapticManager.shared.light()
                    animTrigger = index
                    withAnimation(MonologueAnimation.micro) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        KeyframeAnimator(initialValue: ClassicTabAnimValues(), trigger: animTrigger == index ? animTrigger : -1) { values in
                            MonologueIcon(
                                icon: isSelected ? icons.filled : icons.outline,
                                size: 20,
                                color: isSelected ? .monologueTextPrimary : .monologueTextPrimary.opacity(0.35)
                            )
                            .contentTransition(.interpolate)
                            .scaleEffect(values.scale)
                            .rotationEffect(.degrees(values.rotation))
                            .offset(y: values.offsetY)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                SpringKeyframe(1.25, duration: 0.15, spring: .bouncy)
                                SpringKeyframe(0.9, duration: 0.1, spring: .bouncy)
                                SpringKeyframe(1.0, duration: 0.15, spring: .smooth)
                            }
                            KeyframeTrack(\.rotation) {
                                SpringKeyframe(-8, duration: 0.1, spring: .snappy)
                                SpringKeyframe(5, duration: 0.1, spring: .snappy)
                                SpringKeyframe(0, duration: 0.12, spring: .smooth)
                            }
                            KeyframeTrack(\.offsetY) {
                                SpringKeyframe(-3, duration: 0.12, spring: .bouncy)
                                SpringKeyframe(0, duration: 0.12, spring: .smooth)
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
                        
                        Text(label)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .monologueTextPrimary : .monologueTextPrimary.opacity(0.35))
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
