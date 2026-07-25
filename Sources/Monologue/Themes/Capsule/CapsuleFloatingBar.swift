import SwiftUI

// Capsule 主题的底部悬浮区域：迷你播放条 + Dock 式标签栏，共用玻璃胶囊质感。

/// 统一悬浮栏：上方迷你播放条（有曲目时）+ 下方标签切换 Dock。
struct CapsuleUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    var body: some View {
        VStack(spacing: 7) {
            if let song = player.currentSong {
                CapsuleMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
            }

            CapsuleDockTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(8)
        .background(
            CapsuleFloatingGlassSurface(
                cornerRadius: 31,
                tint: CapsuleStyle.surface,
                lightOpacity: 0.54,
                darkOpacity: 0.66,
                elevated: true
            )
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 5) {
                Capsule().fill(CapsuleStyle.accent).frame(width: 24, height: 6)
                Circle().fill(CapsuleStyle.cyan.opacity(0.82)).frame(width: 6, height: 6)
            }
            .padding(.leading, 22)
            .padding(.top, -3)
        }
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
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
        let tabs = Tab.allCases
        guard let currentIndex = tabs.firstIndex(of: currentTab) else { return }
        let nextIndex = currentIndex + direction
        guard tabs.indices.contains(nextIndex) else { return }

        withAnimation(MonologueAnimation.tabSwitch) {
            currentTab = tabs[nextIndex]
        }
    }
}

/// 迷你播放条：封面、滚动标题、播放/切歌控制，点击展开全屏播放器。
private struct CapsuleMiniPlayerStrip: View {
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
                CachedAsyncImage(url: song.coverUrl, width: 42, height: 42) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(CapsuleStyle.surfaceTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: CapsuleStyle.accent)
                            .frame(width: 14, height: 10)
                            .padding(3)
                            .background(CapsuleStyle.surfaceRaised, in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: CapsuleStyle.labelFont(14, weight: .bold),
                        color: CapsuleStyle.ink,
                        speed: 24
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: subtitleText,
                        font: CapsuleStyle.bodyFont(11, weight: .medium),
                        color: CapsuleStyle.inkMuted,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.22), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 7) {
                    control(icon: player.isPlaying ? .pause : .play, tint: CapsuleStyle.accent) {
                        player.togglePlayPause()
                    }

                    control(icon: .list, tint: CapsuleStyle.inkSoft) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        control(icon: .close, tint: CapsuleStyle.inkMuted, size: 9) {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.top, 7)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic { openPlayer() }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 11)
                .padding(.bottom, 1)
        }
        .background(
            CapsuleFloatingGlassSurface(
                cornerRadius: 23,
                tint: CapsuleStyle.surfaceRaised,
                lightOpacity: 0.38,
                darkOpacity: 0.54,
                elevated: false
            )
        )
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func control(
        icon: MonologueIcon.IconType,
        tint: Color,
        size: CGFloat = 14,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: size, color: tint, lineWidth: 1.8)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(icon == .play || icon == .pause ? 0.16 : 0.1)))
        }
        .buttonStyle(CapsulePressStyle())
    }

    private func openPlayer() {
        withAnimation(MonologueAnimation.playerTransition) {
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

/// Dock 式标签栏：选中项展开显示文字，其余仅显图标。
private struct CapsuleDockTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNamespace

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType, tint: Color)] = [
        (.home, .home, .homeFilled, CapsuleStyle.accent),
        (.podcast, .podcast, .podcastFilled, CapsuleStyle.mint),
        (.library, .library, .libraryFilled, CapsuleStyle.amber),
        (.profile, .profile, .profileFilled, CapsuleStyle.violet),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, outline: item.outline, filled: item.filled, tint: item.tint)
            }
        }
        .padding(4)
        .frame(height: 50)
        .background(
            CapsuleFloatingGlassCapsule(
                tint: CapsuleStyle.surfaceTint,
                lightOpacity: 0.34,
                darkOpacity: 0.48,
                elevated: false
            )
        )
    }

    private func tabButton(
        tab: Tab,
        outline: MonologueIcon.IconType,
        filled: MonologueIcon.IconType,
        tint: Color
    ) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            HStack(spacing: isSelected ? 6 : 0) {
                MonologueIcon(
                    icon: isSelected ? filled : outline,
                    size: isSelected ? 17 : 16,
                    color: isSelected ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.inkMuted,
                    lineWidth: isSelected ? 1.9 : 1.6
                )
                .frame(width: 24, height: 24)

                if isSelected {
                    Text(label)
                        .font(CapsuleStyle.labelFont(10, weight: .bold))
                        .foregroundStyle(CapsuleStyle.readableLabel(on: tint))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                if isSelected {
                    Capsule()
                        .fill(tint)
                        .matchedGeometryEffect(id: "capsuleDockSelection", in: selectionNamespace)
                        .shadow(color: tint.opacity(0.24), radius: 10, x: 0, y: 5)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension CapsuleStyle {
    static func readableLabel(on color: Color) -> Color {
        ThemeColorCustomization.readableForegroundColor(on: color, light: Color(hex: "111821"), dark: .white)
    }
}

/// 悬浮层玻璃背景（圆角矩形），以下为胶囊/圆形变体。
struct CapsuleFloatingGlassSurface: View {
    var cornerRadius: CGFloat
    var tint: Color = CapsuleStyle.surface
    var lightOpacity: Double = 0.56
    var darkOpacity: Double = 0.66
    var elevated = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? darkOpacity : lightOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.08 : 0.26),
                                CapsuleStyle.surfaceTint.opacity(colorScheme == .dark ? 0.06 : 0.16),
                                CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.04 : 0.035),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CapsuleStyle.hairline.opacity(elevated ? 0.78 : 0.5), lineWidth: elevated ? 1 : 0.8)
            )
            .shadow(color: CapsuleStyle.accent.opacity(elevated ? 0.11 : 0.05), radius: elevated ? 20 : 10, x: 0, y: elevated ? 9 : 4)
            .shadow(color: Color.black.opacity(elevated ? 0.09 : 0.04), radius: elevated ? 14 : 8, x: 0, y: elevated ? 8 : 4)
    }
}

struct CapsuleFloatingGlassCapsule: View {
    var tint: Color = CapsuleStyle.surfaceTint
    var lightOpacity: Double = 0.4
    var darkOpacity: Double = 0.5
    var elevated = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule()
            .fill(.regularMaterial)
            .overlay(
                Capsule()
                    .fill(tint.opacity(colorScheme == .dark ? darkOpacity : lightOpacity))
            )
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.07 : 0.24),
                                CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.04 : 0.035),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(CapsuleStyle.hairline.opacity(elevated ? 0.72 : 0.46), lineWidth: elevated ? 0.9 : 0.7)
            )
    }
}

struct CapsuleFloatingGlassCircle: View {
    var tint: Color = CapsuleStyle.surface
    var lightOpacity: Double = 0.42
    var darkOpacity: Double = 0.56
    var elevated = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Circle()
            .fill(.regularMaterial)
            .overlay(
                Circle()
                    .fill(tint.opacity(colorScheme == .dark ? darkOpacity : lightOpacity))
            )
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.08 : 0.26),
                                CapsuleStyle.surfaceTint.opacity(colorScheme == .dark ? 0.05 : 0.14),
                                CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.04 : 0.035),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(CapsuleStyle.hairline.opacity(elevated ? 0.74 : 0.48), lineWidth: elevated ? 0.85 : 0.65)
            )
            .shadow(color: CapsuleStyle.accent.opacity(elevated ? 0.12 : 0.05), radius: elevated ? 14 : 8, x: 0, y: elevated ? 7 : 4)
            .shadow(color: Color.black.opacity(elevated ? 0.08 : 0.035), radius: elevated ? 10 : 6, x: 0, y: elevated ? 6 : 3)
    }
}
