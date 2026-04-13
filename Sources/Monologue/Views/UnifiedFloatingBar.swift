import SwiftUI

// MARK: - Subviews for Performance
struct MiniPlayerSection: View {
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
                .frame(width: 36, height: 36)
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
                        speed: 25
                    )
                    .frame(height: 16)
                    
                    Text(subtitleText)
                        .font(.rounded(size: 11, weight: .medium))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                
                // 控制按钮
                HStack(spacing: 10) {
                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(Color.monologueIconBackground)
                                .frame(width: 32, height: 32)
                            
                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .monologueIconForeground))
                                    .scaleEffect(0.6)
                            } else {
                                MonologueIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 14,
                                    color: .monologueIconForeground
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    
                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 16, color: .monologueTextPrimary.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
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
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
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
                .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
                .padding(.bottom, 4)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
    }

    /// 播放来源角标
    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
    }
}

struct ProgressBarView: View {
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 轨道 - 更柔和的背景
                Capsule()
                    .fill(Color.monologueTextPrimary.opacity(0.06))
                    .frame(height: 2.5)
                
                // 进度 - 使用强调色，更细腻
                let progress = timePublisher.progress
                Capsule()
                    .fill(Color.monologueAccent.opacity(0.5))
                    .frame(width: max(geometry.size.width * CGFloat(progress), 0), height: 2.5)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
    }
}

// MARK: - Tab Icon Animation Values

private struct TabIconAnimValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
    var offsetY: CGFloat = 0.0
}

// MARK: - Monologue TabBar
struct MonologueTabBar: View {
    @Binding var selectedIndex: Int
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var tabNS
    @State private var animTrigger: Int = -1
    
    private let itemHeight: CGFloat = 42
    private let padding: CGFloat = 4
    
    private static let tabIcons: [(outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, label: NSLocalizedString(Tab.home.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 1, label: NSLocalizedString(Tab.podcast.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 2, label: NSLocalizedString(Tab.library.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 3, label: NSLocalizedString(Tab.profile.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
        }
        .padding(.vertical, padding)
        .padding(.horizontal, 8)
    }
    
    @ViewBuilder
    private func tabButton(index: Int, label: String) -> some View {
        let isSelected = selectedIndex == index
        let icons = Self.tabIcons[index]
        
        Button {
            HapticManager.shared.light()
            animTrigger = index
            withAnimation(MonologueAnimation.tabSwitch) {
                selectedIndex = index
            }
        } label: {
            VStack(spacing: 2) {
                KeyframeAnimator(initialValue: TabIconAnimValues(), trigger: animTrigger == index ? animTrigger : -1) { values in
                    MonologueIcon(
                        icon: isSelected ? icons.filled : icons.outline,
                        size: 18,
                        color: isSelected ? .monologueTextPrimary : .monologueTextPrimary.opacity(0.35)
                    )
                    .contentTransition(.interpolate)
                    .scaleEffect(values.scale)
                    .rotationEffect(.degrees(values.rotation))
                    .offset(y: values.offsetY)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.3, duration: 0.15, spring: .bouncy)
                        SpringKeyframe(0.88, duration: 0.1, spring: .bouncy)
                        SpringKeyframe(1.0, duration: 0.18, spring: .smooth)
                    }
                    KeyframeTrack(\.rotation) {
                        SpringKeyframe(-10, duration: 0.1, spring: .snappy)
                        SpringKeyframe(7, duration: 0.1, spring: .snappy)
                        SpringKeyframe(-3, duration: 0.08, spring: .snappy)
                        SpringKeyframe(0, duration: 0.12, spring: .smooth)
                    }
                    KeyframeTrack(\.offsetY) {
                        SpringKeyframe(-4, duration: 0.12, spring: .bouncy)
                        SpringKeyframe(1, duration: 0.08, spring: .bouncy)
                        SpringKeyframe(0, duration: 0.12, spring: .smooth)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
                
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .monologueTextPrimary : .monologueTextPrimary.opacity(0.35))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: 64, height: itemHeight)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.monologueTextPrimary.opacity(0.1))
                        .padding(.horizontal, 4)
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
    @Namespace private var glassNS
    
    var body: some View {
        MonologueGlassContainer(spacing: 0) {
            VStack(spacing: 0) {
                if let song = player.currentSong {
                    MiniPlayerSection(
                        song: song,
                        isPlaying: player.isPlaying,
                        togglePlayPause: { player.togglePlayPause() }
                    )
                    .swipeToSkip()
                    .monologueGlassID("miniPlayer", in: glassNS)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
                }
                
                MonologueTabBar(selectedIndex: Binding(
                    get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                    set: { currentTab = Tab.allCases[$0] }
                ))
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
                .monologueGlassID("tabBar", in: glassNS)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.monologueFloatingBarFill)
            )
            .monologueGlass(cornerRadius: 22)
            .monologueGlassID("floatingBar", in: glassNS)
        }
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < 0 {
                    switchTab(direction: 1)
                } else if value.translation.width > 0 {
                    switchTab(direction: -1)
                }
            }
    }
    
    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        
        let nextIndex = currentIndex + direction
        
        if nextIndex >= 0 && nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

// MARK: - Tab Enum Extension for Monologue Icons
extension Tab {
    var monologueIcon: MonologueIcon.IconType {
        switch self {
        case .home: return .home
        case .podcast: return .podcast
        case .library: return .library
        case .profile: return .profile
        }
    }
}
