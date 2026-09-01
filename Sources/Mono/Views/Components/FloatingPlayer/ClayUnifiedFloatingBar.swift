import SwiftUI

struct ClayUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    var body: some View {
        VStack(spacing: 8) {
            if let song = player.currentSong {
                ClayMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom))
                    ))
            }

            ClayDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(ClaySurfaceBackground(cornerRadius: 27, tint: ClayStyle.cream.opacity(0.96), elevated: true))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                Circle().fill(ClayStyle.butter).frame(width: 8, height: 8)
                Circle().fill(ClayStyle.mint).frame(width: 8, height: 8)
                Circle().fill(ClayStyle.berry).frame(width: 8, height: 8)
            }
            .padding(.top, 11)
            .padding(.trailing, 18)
        }
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

struct ClayMiniPlayerStrip: View {
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
            HStack(spacing: DeviceLayout.usesExpandedLayout ? 10 : 6) {
                CachedAsyncImage(url: song.coverUrl, width: 40, height: 40) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(ClayStyle.creamPressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: ClayStyle.labelFont(13, weight: .bold),
                        color: ClayStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: ClayStyle.labelFont(11, weight: .medium),
                        color: ClayStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 6) {
                    clayControl(icon: player.isPlaying ? .pause : .play, tint: ClayStyle.accent) {
                        player.togglePlayPause()
                    }

                    clayControl(icon: .list, tint: ClayStyle.sky) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        clayControl(icon: .close, tint: ClayStyle.inkMuted, size: 9) {
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
                .frame(height: 2.4)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
        }
        .background(ClaySurfaceBackground(cornerRadius: 22, tint: ClayStyle.creamRaised.opacity(0.96), elevated: false, pressed: true, compact: true))
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func clayControl(icon: MonoIcon.IconType, tint: Color, size: CGFloat = 13, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: size, color: tint, lineWidth: 1.75)
                .frame(width: 32, height: 32)
                .background(ClaySurfaceBackground(cornerRadius: 14, tint: tint.opacity(0.13), elevated: true, compact: true))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
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

struct ClayDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private let tints: [Color] = [ClayStyle.accent, ClayStyle.mint, ClayStyle.sky, ClayStyle.grape]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                tabButton(tab: tab, index: index)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .frame(height: 48)
        .background(ClaySurfaceBackground(cornerRadius: 20, tint: ClayStyle.creamPressed.opacity(0.88), elevated: false, pressed: true, compact: true))
    }

    private func tabButton(tab: Tab, index: Int) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
        let tint = tints[index % tints.count]

        return Button {
            HapticManager.shared.light()
            withAnimation(MonoAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            HStack(spacing: isSelected ? 5 : 0) {
                MonoIcon(
                    icon: tab.icon,
                    size: isSelected ? 16 : 18,
                    color: isSelected ? ClayStyle.ink : ClayStyle.inkMuted,
                    lineWidth: isSelected ? 1.85 : 1.55,
                    artworkContrastBackground: isSelected ? tint : nil
                )

                if isSelected {
                    Text(label)
                        .font(ClayStyle.labelFont(9, weight: .bold))
                        .foregroundStyle(ClayStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(tint.opacity(0.68))
                        .matchedGeometryEffect(id: "clay-tab", in: selectionNS)
                        .shadow(color: tint.opacity(0.22), radius: 7, x: 0, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
