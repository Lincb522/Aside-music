import SwiftUI

struct NeumorphicUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                NeumorphicMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
            }

            NeumorphicDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(NeumorphicGlassSurfaceBackground(cornerRadius: 32, elevated: true))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? NeumorphicStyle.lightShadow(colorScheme, intensity: 0.9)
                        : NeumorphicStyle.darkShadow(colorScheme, intensity: 0.38),
                    lineWidth: 0.8
                )
                .padding(0.5)
        )
        .shadow(color: NeumorphicStyle.darkShadow(colorScheme, intensity: colorScheme == .dark ? 0.60 : 0.42), radius: 22, x: 0, y: 12)
        .animation(MonoAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonoAnimation.tabSwitch, value: currentTab)
        .themeRenderInteractiveLayer()
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

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonoAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

struct NeumorphicMiniPlayerStrip: View {
    let song: Song
    @State private var showPlaylist = false
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    private var subtitleText: String {
        if let text = player.lyricLineText {
            return text
        }
        return song.artistName
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: true))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.65), lineWidth: 0.8))
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                            .frame(width: 14, height: 10)
                            .padding(3)
                            .background(NeumorphicStyle.surfaceRaised.opacity(0.9), in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: NeumorphicStyle.labelFont(13, weight: .semibold),
                        color: NeumorphicStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: NeumorphicStyle.labelFont(11, weight: .regular),
                        color: NeumorphicStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 7) {
                    neumorphicControl(icon: player.isPlaying ? .pause : .play, tint: .white, filled: true) {
                        player.togglePlayPause()
                    }

                    neumorphicControl(icon: .list, tint: NeumorphicStyle.inkSoft) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        neumorphicControl(icon: .close, tint: NeumorphicStyle.inkMuted, size: 9) {
                            withAnimation(MonoAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic { openPlayer() }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 26,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfaceRaised.opacity(0.66),
                lightweight: true
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.44), lineWidth: 0.7)
        )
        .padding(.bottom, 7)
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func neumorphicControl(
        icon: MonoIcon.IconType,
        tint: Color,
        size: CGFloat = 14,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: size, color: tint, lineWidth: 1.7)
                .frame(width: 38, height: 38)
                .background {
                    if filled {
                        Circle()
                            .fill(NeumorphicStyle.steel.opacity(0.94))
                            .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: 0.8))
                            .shadow(color: NeumorphicStyle.steel.opacity(0.24), radius: 10, x: 0, y: 5)
                    } else {
                        NeumorphicSurfaceBackground(cornerRadius: 15, elevated: true, lightweight: true)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
    }

    private func openPlayer() {
        withAnimation(MonoAnimation.playerTransition) {
            switch player.playSource {
            case .fm:
                NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
            case let .podcast(radioId):
                NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioId)
            case .normal:
                NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
            }
        }
    }
}

struct NeumorphicDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonoIcon.IconType, filled: MonoIcon.IconType)] = [
        (.home, .home, .homeFilled),
        (.podcast, .podcast, .podcastFilled),
        (.library, .library, .libraryFilled),
        (.profile, .profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, index: index, outline: item.outline, filled: item.filled)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(height: 62)
        .background(NeumorphicSurfaceBackground(cornerRadius: 27, elevated: false, pressed: true, lightweight: true))
    }

    private func tabButton(tab: Tab, index: Int, outline: MonoIcon.IconType, filled: MonoIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
        let tint = tabTint(index)

        return Button {
            HapticManager.shared.light()
            withAnimation(MonoAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                MonoIcon(
                    icon: isSelected ? filled : outline,
                    size: isSelected ? 19 : 18,
                    color: isSelected ? tint : NeumorphicStyle.inkMuted,
                    lineWidth: isSelected ? 1.8 : 1.5
                )
                .frame(width: 24, height: 22)

                Text(label)
                    .font(NeumorphicStyle.labelFont(10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? NeumorphicStyle.ink : NeumorphicStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, tint: NeumorphicStyle.surfaceRaised.opacity(0.86), lightweight: true))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .matchedGeometryEffect(id: "neumorphicTabSelection", in: selectionNS)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return NeumorphicStyle.accent
        case 1: return NeumorphicStyle.sage
        case 2: return NeumorphicStyle.warm
        default: return NeumorphicStyle.red
        }
    }
}
