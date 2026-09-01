import SwiftUI

// MARK: - Aside 统一悬浮栏（墨水药丸 + 发丝线编辑风）

struct AsideUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    let usesGlassChrome: Bool
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                AsideNowPlayingRow(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))

                AsideBarHairline()
                    .padding(.horizontal, 16)
            }

            AsideInkPillTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 7)
        .padding(.top, player.currentSong == nil ? 6 : 3)
        .padding(.bottom, 6)
        .background(chrome)
        .modifier(AsideBarGlassModifier(enabled: usesGlassChrome, cornerRadius: cornerRadius))
        .compositingGroup()
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.14), radius: 20, x: 0, y: 10)
        .animation(MonoAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    @ViewBuilder
    private var chrome: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if usesGlassChrome {
            shape
                .fill(Color.monoFloatingBarFill)
                .overlay(shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.40), lineWidth: 0.6))
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(
                        colorScheme == .dark
                            ? Color(hex: "15171E").opacity(0.66)
                            : Color.white.opacity(0.64)
                    )
                )
                .overlay(
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.30),
                                Color.clear,
                                Color.monoAccent.opacity(colorScheme == .dark ? 0.05 : 0.03),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.66),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.16),
                                Color.black.opacity(colorScheme == .dark ? 0.14 : 0.05),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
                )
                .clipShape(shape)
        }
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let allTabs = Tab.allCases
                guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
                let nextIndex = currentIndex + (value.translation.width < 0 ? 1 : -1)
                if nextIndex >= 0, nextIndex < allTabs.count {
                    withAnimation(MonoAnimation.tabSwitch) {
                        currentTab = allTabs[nextIndex]
                    }
                }
            }
    }
}

/// iOS 26 液态玻璃开关：仅在启用时叠加 glassEffect
struct AsideBarGlassModifier: ViewModifier {
    let enabled: Bool
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.monoGlass(cornerRadius: cornerRadius)
        } else {
            content
        }
    }
}

struct AsideBarHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.monoTextPrimary.opacity(0.08))
            .frame(height: 0.7)
    }
}

// MARK: - Aside 正在播放行

struct AsideNowPlayingRow: View {
    let song: Song
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPlaylist = false

    private var subtitleText: String {
        player.lyricLineText ?? song.artistName
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 11) {
                cover

                VStack(alignment: .leading, spacing: 2.5) {
                    MarqueeText(
                        text: song.name,
                        font: .system(size: 13.5, weight: .semibold, design: .rounded),
                        color: .monoTextPrimary,
                        speed: 25
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: subtitleText,
                        font: .system(size: 11, weight: .medium, design: .rounded),
                        color: .monoTextSecondary.opacity(0.9),
                        speed: 22
                    )
                    .frame(height: 14)
                    .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                controls
            }
            .contentShape(Rectangle())
            .onTapWithHaptic { openPlayer() }

            ProgressBarView(height: 2, minFillWidth: 4)
                .padding(.leading, 54)
                .padding(.trailing, 1)
        }
        .padding(.horizontal, 11)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private var cover: some View {
        CachedAsyncImage(url: song.coverUrl, width: 43, height: 43) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.monoTextPrimary.opacity(0.06))
                .overlay(MonoIcon(icon: .musicNote, size: 15, color: .monoTextSecondary.opacity(0.6), lineWidth: 1.5))
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: 43, height: 43)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.monoTextPrimary.opacity(0.1), lineWidth: 0.7)
        )
        .overlay(alignment: .bottomTrailing) {
            if player.playSource == .fm {
                sourceBadge(icon: .fm)
            } else if player.isPlayingPodcast {
                sourceBadge(icon: .radio)
            }
        }
    }

    private func sourceBadge(icon: MonoIcon.IconType) -> some View {
        MonoIcon(icon: icon, size: 10, color: .monoAccentForeground, lineWidth: 1.6)
            .frame(width: 18, height: 18)
            .background(Color.monoAccent, in: Circle())
            .overlay(Circle().stroke(Color(light: .white, dark: Color(hex: "15171E")).opacity(0.9), lineWidth: 1.4))
            .offset(x: 5, y: 5)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.monoAccent)
                        .frame(width: 37, height: 37)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .monoAccentForeground))
                            .scaleEffect(0.56)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 14,
                            color: .monoAccentForeground,
                            lineWidth: 1.8
                        )
                    }
                }
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.93))

            Button(action: { showPlaylist.toggle() }) {
                MonoIcon(icon: .list, size: 15, color: .monoTextPrimary.opacity(0.68), lineWidth: 1.7)
                    .frame(width: 33, height: 33)
                    .background(
                        Circle().strokeBorder(Color.monoTextPrimary.opacity(0.13), lineWidth: 1)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.93))

            if !player.isPlaying {
                Button {
                    withAnimation(MonoAnimation.floatingBar) {
                        player.dismissMiniPlayerPreservingQueue()
                    }
                } label: {
                    MonoIcon(icon: .close, size: 10, color: .monoTextSecondary, lineWidth: 1.6)
                        .frame(width: 28, height: 28)
                        .background(Color.monoTextPrimary.opacity(0.07), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.93))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .zIndex(1)
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

// MARK: - Aside 墨水药丸 Tab 栏

struct AsideInkPillTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
        .animation(MonoAnimation.tabSwitch, value: currentTab)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let selected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            // 页面切换不走动画（避免 TabView 内容做弹簧过渡导致卡顿）
            currentTab = tab
        } label: {
            HStack(spacing: 6) {
                MonoIcon(
                    icon: selected ? tab.icon : tab.monoIcon,
                    size: 18,
                    color: selected ? .monoAccentForeground : .monoTextSecondary.opacity(0.62),
                    lineWidth: 1.7,
                    artworkContrastBackground: selected ? .monoAccent : nil
                )

                if selected {
                    Text(label)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.monoAccentForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 132)
            .frame(height: 42)
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(Color.monoAccent)
                        .matchedGeometryEffect(id: "asideInkPill", in: pillNS)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
