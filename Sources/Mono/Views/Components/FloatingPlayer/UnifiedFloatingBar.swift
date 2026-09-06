import SwiftUI

// MARK: - Unified Floating Bar

struct UnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    private let player = FloatingBarPlaybackModel.shared
    @State private var currentSong = FloatingBarPlaybackModel.shared.currentSong
    @State private var isPlaying = FloatingBarPlaybackModel.shared.isPlaying
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var glassNS

    private var cornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.chromeRadius }
        return SignalStyle.isActive ? 18 : ((PetWhiteStyle.isActive || PureWhiteStyle.isActive) ? 24 : (MujiStyle.isActive ? 16 : 28))
    }

    var body: some View {
        Group {
            switch settings.globalThemeId {
            case .manga:
                defaultFloatingBar
            case .muji:
                MujiUnifiedFloatingBar(currentTab: $currentTab)
            case .neumorphic:
                NeumorphicUnifiedFloatingBar(currentTab: $currentTab)
            case .capsule:
                CapsuleUnifiedFloatingBar(currentTab: $currentTab)
            case .signal:
                SignalUnifiedFloatingBar(currentTab: $currentTab)
            case .clarity:
                ClarityDock(currentTab: $currentTab)
            case .petWhite:
                petWhiteFloatingBar
            case .minimalWhite:
                MinimalWhiteUnifiedDock(currentTab: $currentTab)
            case .default:
                defaultFloatingBar
            }
        }
        .onReceive(player.$currentSong.removeDuplicates()) { song in
            currentSong = song
        }
        .onReceive(player.$isPlaying.removeDuplicates()) { playing in
            isPlaying = playing
        }
    }

    @ViewBuilder
    private var defaultFloatingBar: some View {
        if settings.globalThemeId == .default {
            AsideUnifiedFloatingBar(
                currentTab: $currentTab,
                usesGlassChrome: settings.defaultThemeUsesLiquidGlassTabBar
            )
        } else {
            glassFloatingBar
        }
    }

    private var glassFloatingBar: some View {
        MonoGlassContainer(spacing: 0) {
            VStack(spacing: 0) {
                if let song = currentSong {
                    MiniPlayerSection(
                        song: song,
                        isPlaying: isPlaying,
                        togglePlayPause: { player.togglePlayPause() }
                    )
                    .swipeToSkip()
                    .monoGlassID("miniPlayer", in: glassNS)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
                }

                MonoTabBar(selectedIndex: Binding(
                    get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                    set: { currentTab = Tab.allCases[$0] }
                ))
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
                .monoGlassID("tabBar", in: glassNS)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(barBackground)
            .overlay(barStroke)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16), radius: 18, x: 0, y: 8)
            .monoGlass(cornerRadius: cornerRadius)
            .monoGlassID("floatingBar", in: glassNS)
        }
        .animation(MonoAnimation.floatingBar, value: currentSong != nil)
    }

    private var pureWhiteFloatingBar: some View {
        VStack(spacing: 3) {
            if let song = currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                ))
            }

            MonoTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            // 角落短线关掉：迷你播放器的封面（头部）与 Tab 栏尾部会和短线重叠
            PureWhiteSurfaceBackground(
                cornerRadius: cornerRadius,
                elevated: true,
                tint: PureWhiteStyle.surfaceRaised,
                showsCornerMarks: false
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: PureWhiteStyle.strokeInk.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 6, x: 0, y: 3)
        .animation(MonoAnimation.floatingBar, value: currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    private var minimalWhiteFloatingBar: some View {
        VStack(spacing: 0) {
            if let song = currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .transition(.opacity)

                Divider()
                    .overlay(MinimalWhiteStyle.hairline)
                    .padding(.horizontal, 10)
            }

            MonoTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: MinimalWhiteStyle.chromeRadius, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    private var petWhiteFloatingBar: some View {
        PetWhiteUnifiedFloatingBar(currentTab: $currentTab)
    }

    @ViewBuilder
    private var barBackground: some View {
        if MinimalWhiteStyle.isActive {
            MinimalWhiteSurfaceBackground(
                cornerRadius: cornerRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        } else if PetWhiteStyle.isActive {
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint,
                lineWidth: PetWhiteStyle.strokeWidth
            )
        } else if PureWhiteStyle.isActive {
            PureWhiteSurfaceBackground(
                cornerRadius: cornerRadius,
                elevated: true,
                tint: PureWhiteStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.94 : 0.99)
            )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.monoFloatingBarFill)
        }
    }

    @ViewBuilder
    private var barStroke: some View {
        if MinimalWhiteStyle.isActive || PetWhiteStyle.isActive || PureWhiteStyle.isActive {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12),
                    lineWidth: 0.75
                )
        }
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

// MARK: - Tab Enum Extension for Mono Icons

extension Tab {
    var monoIcon: MonoIcon.IconType {
        switch self {
        case .home: return .home
        case .podcast: return .podcast
        case .library: return .library
        case .profile: return .profile
        }
    }
}
