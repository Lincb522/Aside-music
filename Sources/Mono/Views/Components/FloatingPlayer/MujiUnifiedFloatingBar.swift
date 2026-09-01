import SwiftUI

struct MujiUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MujiMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .bottom))
                    ))

                MujiListDivider()
                    .padding(.horizontal, 12)
            }

            MujiDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(MujiPaperCardBackground(cornerRadius: 22, elevated: true))
        .shadow(color: MujiStyle.ink.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 15, x: 0, y: 6)
        .animation(MonoAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonoAnimation.tabSwitch, value: currentTab)
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

struct MujiMiniPlayerStrip: View {
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
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(MujiStyle.wash(MujiStyle.clay))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        MujiNowPlayingIndicator(isAnimating: true)
                            .scaleEffect(0.68, anchor: .bottomTrailing)
                            .padding(3)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: MujiStyle.bodyFont(13.5, weight: .medium),
                        color: MujiStyle.ink,
                        speed: 25
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: subtitleText,
                        font: MujiStyle.labelFont(11, weight: .regular),
                        color: MujiStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 8) {
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.35))
                                .frame(width: 32, height: 32)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MujiStyle.clay))
                                    .scaleEffect(0.55)
                            } else {
                                MonoIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 14,
                                    color: MujiStyle.clay,
                                    lineWidth: 1.7
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        MonoIcon(icon: .list, size: 16, color: MujiStyle.inkSoft, lineWidth: 1.6)
                            .frame(width: 34, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    if !player.isPlaying {
                        Button(action: {
                            withAnimation(MonoAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonoIcon(icon: .close, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.6)
                                .frame(width: 28, height: 28)
                                .background(MujiStyle.ink.opacity(0.06), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
                        openPlayer()
                    }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
                .opacity(0.82)
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func sourceIndicator(icon: MonoIcon.IconType) -> some View {
        MonoIcon(icon: icon, size: 10, color: MujiStyle.onTint, lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .background(MujiStyle.ink.opacity(0.52), in: Circle())
            .padding(3)
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

struct MujiDedicatedTabBar: View {
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
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(height: 52)
    }

    private func tabButton(tab: Tab, index: Int, outline: MonoIcon.IconType, filled: MonoIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            withAnimation(MonoAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                MonoIcon(
                    icon: isSelected ? filled : outline,
                    size: 18,
                    color: isSelected ? MujiStyle.clay : MujiStyle.inkMuted,
                    lineWidth: isSelected ? 1.8 : 1.55,
                    artworkContrastBackground: isSelected ? MujiStyle.surfaceRaised : nil
                )
                .frame(width: 28, height: 22)

                Text(label)
                    .font(MujiStyle.labelFont(9, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? MujiStyle.clay : MujiStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.2))
                        .matchedGeometryEffect(id: "mujiTabSelection", in: selectionNS)
                        .padding(.horizontal, 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
