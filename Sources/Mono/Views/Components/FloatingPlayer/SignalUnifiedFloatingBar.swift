import SwiftUI

struct SignalUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    var body: some View {
        VStack(spacing: 8) {
            if let song = player.currentSong {
                SignalMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom))
                    ))
            }

            SignalDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(SignalSurfaceBackground(cornerRadius: 24, elevated: true, fill: SignalStyle.paper.opacity(0.96)))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.62), lineWidth: 0.75)
                .padding(0.5)
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(LinearGradient(colors: [SignalStyle.accent.opacity(0.74), SignalStyle.mint.opacity(0.46)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 56, height: 4)
                .padding(.top, 10)
                .padding(.leading, 18)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
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

struct SignalMiniPlayerStrip: View {
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
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SignalStyle.controlPressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.62), lineWidth: 0.65)
                )

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: SignalStyle.labelFont(13, weight: .bold),
                        color: SignalStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: SignalStyle.labelFont(11, weight: .medium),
                        color: SignalStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 6) {
                    signalControl(icon: player.isPlaying ? .pause : .play, tint: SignalStyle.accent) {
                        player.togglePlayPause()
                    }

                    signalControl(icon: .list, tint: SignalStyle.inkSoft) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        signalControl(icon: .close, tint: SignalStyle.inkMuted, size: 9) {
                            withAnimation(MonoAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic { openPlayer() }
            }

            ProgressBarView()
                .frame(height: 2.3)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
        .background(SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.screen.opacity(0.78)))
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func signalControl(
        icon: MonoIcon.IconType,
        tint: Color,
        size: CGFloat = 14,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: size, color: tint, lineWidth: 1.75)
                .frame(width: 32, height: 32)
                .background(SignalSurfaceBackground(cornerRadius: 12, elevated: true, fill: SignalStyle.surfaceRaised))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

struct SignalDedicatedTabBar: View {
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
        HStack(spacing: 5) {
            ForEach(0 ..< Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, index: index, outline: item.outline, filled: item.filled)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .frame(height: 48)
        .background(SignalSurfaceBackground(cornerRadius: 19, elevated: false, pressed: true, fill: SignalStyle.controlPressed))
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
            HStack(spacing: isSelected ? 5 : 0) {
                MonoIcon(
                    icon: isSelected ? filled : outline,
                    size: isSelected ? 16 : 18,
                    color: isSelected ? SignalStyle.onAccent : SignalStyle.inkMuted,
                    lineWidth: isSelected ? 1.9 : 1.55
                )

                if isSelected {
                    Text(label)
                        .font(SignalStyle.labelFont(9, weight: .bold))
                        .foregroundStyle(SignalStyle.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint, SignalStyle.mint.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "signal-tab", in: selectionNS)
                        .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return SignalStyle.accent
        case 1: return SignalStyle.mint
        case 2: return SignalStyle.lavender
        default: return SignalStyle.clay
        }
    }
}
