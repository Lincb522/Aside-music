import SwiftUI

/// 经典风格的统一悬浮栏（MiniPlayer + TabBar 合一的低矮 Dock）
struct ClassicFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var dockHorizontalPadding: CGFloat {
        0
    }

    private var dockBottomPadding: CGFloat {
        0
    }

    private var dockBottomSafeAreaPadding: CGFloat {
        let safeArea = max(DeviceLayout.safeAreaBottom, 0)
        guard safeArea > 0 else { return 0 }
        return min(safeArea * 0.46, DeviceLayout.isPad ? 14 : 16)
    }

    private var miniPlayerHorizontalPadding: CGFloat {
        DeviceLayout.isPad ? 38 : 16
    }

    private var dockCornerRadius: CGFloat {
        switch settings.globalThemeId {
        case .manga:
            return 25
        case .minimalWhite:
            return 24
        case .pureWhite:
            return 24
        case .petWhite:
            return 24
        case .muji:
            return 24
        case .neumorphic:
            return 28
        case .capsule:
            return 30
        case .sequoia, .liquidGlass:
            return 29
        case .clay, .signal:
            return 26
        case .default, .bento, .material3Expressive:
            return 28
        }
    }

    private var dockShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: dockCornerRadius,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: dockCornerRadius
            ),
            style: .continuous
        )
    }

    private var dockShadowColor: Color {
        switch settings.globalThemeId {
        case .manga:
            return MangaStyle.strokeInk.opacity(colorScheme == .dark ? 0.28 : 0.18)
        case .minimalWhite:
            return MinimalWhiteStyle.ink.opacity(0.075)
        case .pureWhite:
            return PureWhiteStyle.strokeInk.opacity(colorScheme == .dark ? 0.14 : 0.08)
        case .petWhite:
            return PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.28 : 0.08)
        case .muji:
            return MujiStyle.ink.opacity(colorScheme == .dark ? 0.20 : 0.10)
        case .neumorphic:
            return NeumorphicStyle.darkShadow(colorScheme, intensity: 0.55)
        case .capsule:
            return CapsuleStyle.accent.opacity(colorScheme == .dark ? 0.18 : 0.13)
        case .sequoia:
            return SequoiaStyle.shadow(colorScheme, elevated: true)
        case .liquidGlass:
            return LiquidGlassStyle.shadow(colorScheme, elevated: true)
        case .clay:
            return ClayStyle.ink.opacity(colorScheme == .dark ? 0.20 : 0.12)
        case .signal:
            return SignalStyle.ink.opacity(colorScheme == .dark ? 0.22 : 0.14)
        case .default, .bento, .material3Expressive:
            return Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
        }
    }

    private var internalSeparatorColor: Color {
        switch settings.globalThemeId {
        case .manga:
            return MangaStyle.strokeInk.opacity(0.18)
        case .minimalWhite:
            return MinimalWhiteStyle.hairline
        case .pureWhite:
            return PureWhiteStyle.separator.opacity(0.86)
        case .petWhite:
            return PetWhiteStyle.separator.opacity(0.86)
        case .muji:
            return MujiStyle.separator.opacity(colorScheme == .dark ? 0.38 : 0.28)
        case .neumorphic:
            return NeumorphicStyle.separator.opacity(colorScheme == .dark ? 0.46 : 0.34)
        case .capsule:
            return CapsuleStyle.separator.opacity(colorScheme == .dark ? 0.40 : 0.30)
        case .sequoia:
            return SequoiaStyle.separator.opacity(colorScheme == .dark ? 0.42 : 0.30)
        case .liquidGlass:
            return LiquidGlassStyle.separator.opacity(colorScheme == .dark ? 0.42 : 0.30)
        case .clay:
            return ClayStyle.separator.opacity(colorScheme == .dark ? 0.42 : 0.30)
        case .signal:
            return SignalStyle.separator.opacity(colorScheme == .dark ? 0.44 : 0.32)
        case .default, .bento, .material3Expressive:
            return Color.monologueSeparator.opacity(colorScheme == .dark ? 0.32 : 0.22)
        }
    }

    var body: some View {
        if settings.globalThemeId == .petWhite {
            PetWhiteClassicCushionDock(currentTab: $currentTab)
        } else if settings.globalThemeId == .minimalWhite {
            MinimalWhiteClassicDock(currentTab: $currentTab)
        } else if settings.globalThemeId == .default {
            AsideClassicDock(currentTab: $currentTab)
        } else {
            classicBody
        }
    }

    private var classicBody: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                if let song = player.currentSong {
                    ClassicMiniPlayerSection(
                        song: song,
                        isPlaying: player.isPlaying,
                        togglePlayPause: { player.togglePlayPause() }
                    )
                    .swipeToSkip()
                    .padding(.horizontal, miniPlayerHorizontalPadding)
                    .padding(.bottom, 3)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))

                    ProgressBarView()
                        .frame(height: 2)
                        .padding(.horizontal, DeviceLayout.isPad ? 26 : 17)
                        .padding(.bottom, 4)
                        .opacity(progressOpacity)
                        .transition(.opacity)

                    Capsule(style: .continuous)
                        .fill(internalSeparatorColor)
                        .frame(height: 0.7)
                        .padding(.horizontal, DeviceLayout.isPad ? 26 : 17)
                }

                ClassicTabBarSection(currentTab: $currentTab)
            }
            .id(settings.globalThemeId)
            .padding(.top, player.currentSong == nil ? 4 : 5)
            .padding(.bottom, 1 + dockBottomSafeAreaPadding)
            .background { dockBackground }
            .overlay(dockStroke)
            .overlay(alignment: .topLeading) { dockAccentRail }
            .clipShape(dockShape)
            .shadow(color: dockShadowColor, radius: dockShadowRadius, x: 0, y: dockShadowY)
            .padding(.horizontal, dockHorizontalPadding)
            .padding(.bottom, dockBottomPadding)
            .themeRenderInteractiveLayer()
        }
        .padding(.bottom, 0)
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    @ViewBuilder
    private var dockBackground: some View {
        let shape = dockShape
        switch settings.globalThemeId {
        case .manga:
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            MangaStyle.bubbleWhite.opacity(colorScheme == .dark ? 0.78 : 0.92),
                            MangaStyle.paperWarm.opacity(colorScheme == .dark ? 0.72 : 0.88),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(MangaDotsTexture(opacity: colorScheme == .dark ? 0.02 : 0.028, gap: 12).clipShape(shape))
        case .minimalWhite:
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(MinimalWhiteStyle.glassStrongFill))
                .overlay(shape.stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth))
        case .pureWhite:
            shape
                .fill(PureWhiteStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.95 : 0.99))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.06 : 0.86),
                            PureWhiteStyle.paperBlue.opacity(colorScheme == .dark ? 0.04 : 0.1),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                )
                .overlay(
                    shape.stroke(PureWhiteStyle.separator.opacity(colorScheme == .dark ? 0.72 : 0.96), lineWidth: 1)
                )
        case .petWhite:
            PetWhiteFrostedFloatingSurface(
                shape: shape,
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint,
                lineWidth: PetWhiteStyle.strokeWidth
            )
            .overlay(
                LinearGradient(
                    colors: [
                        PetWhiteStyle.mint.opacity(colorScheme == .dark ? 0.10 : 0.18),
                        Color.clear,
                        PetWhiteStyle.butter.opacity(colorScheme == .dark ? 0.10 : 0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            )
        case .muji:
            shape
                .fill(.thinMaterial)
                .overlay(shape.fill(MujiStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.72 : 0.62)))
                .overlay(MujiPaperTexture(opacity: 0.055).clipShape(shape))
        case .neumorphic:
            shape
                .fill(NeumorphicStyle.surface.opacity(colorScheme == .dark ? 0.94 : 0.90))
                .overlay(NeumorphicReliefTexture(opacity: colorScheme == .dark ? 0.025 : 0.035).clipShape(shape))
        case .capsule:
            shape
                .fill(.regularMaterial)
                .overlay(
                    shape.fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.surface.opacity(colorScheme == .dark ? 0.58 : 0.50),
                                CapsuleStyle.surfaceTint.opacity(colorScheme == .dark ? 0.42 : 0.36),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
        case .sequoia:
            shape
                .fill(.thinMaterial)
                .overlay(shape.fill(SequoiaStyle.materialFloating.opacity(colorScheme == .dark ? 0.78 : 0.58)))
        case .liquidGlass:
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(LiquidGlassStyle.glassFloating.opacity(colorScheme == .dark ? 0.78 : 0.58)))
        case .clay:
            shape
                .fill(ClayStyle.cream.opacity(colorScheme == .dark ? 0.92 : 0.86))
        case .signal:
            shape
                .fill(SignalStyle.device.opacity(colorScheme == .dark ? 0.92 : 0.86))
        case .bento:
            shape
                .fill(BentoStyle.surface.opacity(colorScheme == .dark ? 0.90 : 0.84))
        case .default, .material3Expressive:
            shape
                .fill(settings.defaultThemeUsesLiquidGlassTabBar ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial))
                .overlay(
                    shape.fill(
                        settings.defaultThemeUsesLiquidGlassTabBar
                            ? Color.monologueFloatingBarFill.opacity(colorScheme == .dark ? 0.58 : 0.50)
                            : (colorScheme == .dark ? Color(hex: "1C1C1E").opacity(0.58) : Color.white.opacity(0.52))
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.06 : 0.24),
                            Color.clear,
                            Color.monologueAccent.opacity(colorScheme == .dark ? 0.04 : 0.035),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                )
        }
    }

    @ViewBuilder
    private var dockStroke: some View {
        dockShape
            .strokeBorder(dockStrokeColor, lineWidth: dockStrokeWidth)
            .background {
                if settings.globalThemeId == .manga {
                    dockShape
                        .stroke(MangaStyle.strokeInk.opacity(0.18), lineWidth: 2.2)
                        .offset(y: 2)
                } else if settings.globalThemeId == .minimalWhite {
                    dockShape
                        .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
                } else if settings.globalThemeId == .pureWhite {
                    dockShape
                        .stroke(PureWhiteStyle.separator.opacity(colorScheme == .dark ? 0.6 : 0.86), lineWidth: 1)
                } else if settings.globalThemeId == .petWhite {
                    dockShape
                        .stroke(PetWhiteStyle.separator.opacity(colorScheme == .dark ? 0.6 : 0.86), lineWidth: 1)
                }
            }
            .overlay {
                dockShape
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.24), lineWidth: 0.5)
                    .blendMode(.plusLighter)
            }
    }

    private var dockStrokeColor: Color {
        switch settings.globalThemeId {
        case .manga:
            return MangaStyle.strokeInk.opacity(0.72)
        case .minimalWhite:
            return MinimalWhiteStyle.separator
        case .pureWhite:
            return PureWhiteStyle.separator.opacity(colorScheme == .dark ? 0.64 : 0.86)
        case .petWhite:
            return PetWhiteStyle.separator.opacity(colorScheme == .dark ? 0.64 : 0.86)
        case .muji:
            return MujiStyle.hairline.opacity(colorScheme == .dark ? 0.34 : 0.42)
        case .neumorphic:
            return NeumorphicStyle.separator.opacity(colorScheme == .dark ? 0.40 : 0.34)
        case .capsule:
            return CapsuleStyle.hairline.opacity(colorScheme == .dark ? 0.52 : 0.66)
        case .sequoia:
            return SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.28 : 0.44)
        case .liquidGlass:
            return LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.28 : 0.46)
        case .clay:
            return ClayStyle.separator.opacity(colorScheme == .dark ? 0.34 : 0.42)
        case .signal:
            return SignalStyle.separator.opacity(colorScheme == .dark ? 0.38 : 0.46)
        case .default, .bento, .material3Expressive:
            return Color.white.opacity(colorScheme == .dark ? 0.12 : 0.52)
        }
    }

    private var dockStrokeWidth: CGFloat {
        if settings.globalThemeId == .manga { return 1.4 }
        if settings.globalThemeId == .minimalWhite { return MinimalWhiteStyle.strokeWidth }
        if settings.globalThemeId == .pureWhite || settings.globalThemeId == .petWhite { return 1.0 }
        return 0.85
    }

    @ViewBuilder
    private var dockAccentRail: some View {
        switch settings.globalThemeId {
        case .manga:
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5).fill(MangaStyle.accentPink)
                RoundedRectangle(cornerRadius: 1.5).fill(MangaStyle.strokeInk.opacity(0.85))
                RoundedRectangle(cornerRadius: 1.5).fill(MangaStyle.mint.opacity(0.9))
            }
            .frame(width: 82, height: 5)
            .padding(.leading, 18)
            .padding(.top, 6)
        case .minimalWhite:
            EmptyView()
        case .pureWhite:
            HStack(spacing: 6) {
                Capsule()
                    .fill(PureWhiteStyle.accent)
                    .frame(width: 34, height: 4)
                Capsule()
                    .fill(PureWhiteStyle.separator)
                    .frame(width: 18, height: 4)
                Capsule()
                    .fill(PureWhiteStyle.paperBlue.opacity(0.72))
                    .frame(width: 22, height: 4)
            }
            .frame(width: 84, height: 8)
            .padding(.leading, 18)
            .padding(.top, 7)
        case .petWhite:
            EmptyView()
        case .capsule:
            HStack(spacing: 5) {
                Capsule().fill(CapsuleStyle.accent)
                Circle().fill(CapsuleStyle.cyan)
                Circle().fill(CapsuleStyle.violet)
            }
            .frame(width: 72, height: 5)
            .padding(.leading, 22)
            .padding(.top, 7)
        case .muji:
            Capsule()
                .fill(MujiStyle.clay.opacity(0.38))
                .frame(width: 54, height: 3)
                .padding(.leading, 22)
                .padding(.top, 8)
        case .neumorphic:
            Capsule()
                .fill(NeumorphicStyle.accent.opacity(0.22))
                .frame(width: 56, height: 3)
                .padding(.leading, 22)
                .padding(.top, 8)
        case .default:
            Capsule()
                .fill(Color.monologueAccent.opacity(colorScheme == .dark ? 0.44 : 0.28))
                .frame(width: 58, height: 3)
                .padding(.leading, 22)
                .padding(.top, 8)
        default:
            EmptyView()
        }
    }

    private var progressOpacity: Double {
        switch settings.globalThemeId {
        case .manga:
            return 0.78
        case .minimalWhite:
            return 0.8
        case .pureWhite:
            return 0.76
        case .petWhite:
            return 0.76
        case .capsule, .neumorphic:
            return 0.72
        default:
            return 0.64
        }
    }

    private var dockShadowRadius: CGFloat {
        switch settings.globalThemeId {
        case .manga:
            return 0
        case .minimalWhite:
            return 4
        case .pureWhite:
            return 6
        case .petWhite:
            return 6
        case .neumorphic:
            return 14
        case .capsule, .sequoia, .liquidGlass:
            return 13
        default:
            return 11
        }
    }

    private var dockShadowY: CGFloat {
        settings.globalThemeId == .manga ? -1 : ((settings.globalThemeId == .minimalWhite || settings.globalThemeId == .pureWhite || settings.globalThemeId == .petWhite) ? 0 : -3)
    }
}

private struct MinimalWhiteClassicDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    private var bottomInset: CGFloat {
        let safeArea = max(DeviceLayout.safeAreaBottom, 0)
        return min(safeArea * 0.42, DeviceLayout.isPad ? 12 : 15)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 9) {
                if let song = player.currentSong {
                    MinimalWhiteClassicNowPlaying(song: song)
                        .swipeToSkip()
                        .padding(.horizontal, DeviceLayout.isPad ? 36 : 16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                }

                MinimalWhiteClassicTabRail(currentTab: $currentTab)
                    .padding(.horizontal, DeviceLayout.isPad ? 38 : 18)
            }
            .padding(.top, player.currentSong == nil ? 10 : 11)
            .padding(.bottom, 10 + bottomInset)
            .background {
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 28,
                        bottomLeading: 0,
                        bottomTrailing: 0,
                        topTrailing: 28
                    ),
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
                .overlay(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28),
                        style: .continuous
                    )
                    .fill(Color.white.opacity(0.92))
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(MinimalWhiteStyle.separator)
                        .frame(height: MinimalWhiteStyle.strokeWidth)
                }
                .shadow(color: MinimalWhiteStyle.ink.opacity(0.055), radius: 10, x: 0, y: -2)
            }
            .themeRenderInteractiveLayer()
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }
}

private struct MinimalWhiteClassicNowPlaying: View {
    let song: Song
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @State private var showPlaylist = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl, width: 36, height: 36) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth))

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(text: song.name, font: MinimalWhiteStyle.bodyFont(13, weight: .semibold), color: MinimalWhiteStyle.ink, speed: 24)
                        .frame(height: 16)
                    MarqueeText(text: player.lyricLineText ?? song.artistName, font: MinimalWhiteStyle.labelFont(11, weight: .regular), color: MinimalWhiteStyle.inkMuted, speed: 22)
                        .frame(height: 14)
                }
                .swipeSkipTextMotion()

                Spacer(minLength: 6)

                Button(action: { player.togglePlayPause() }) {
                    MonologueIcon(
                        icon: player.isPlaying ? .pause : .play,
                        size: 13,
                        color: MinimalWhiteStyle.ink,
                        lineWidth: 1.8
                    )
                    .frame(width: 32, height: 32)
                    .background(MinimalWhiteCircleBackground(selected: true))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                Button(action: { showPlaylist.toggle() }) {
                    MonologueIcon(icon: .list, size: 14, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.7)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }
            .contentShape(Rectangle())
            .onTapWithHaptic { openPlayer() }

            ProgressBarView(height: 2, minFillWidth: 5)
                .frame(height: 2)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: 17,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
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

private struct MinimalWhiteClassicTabRail: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    VStack(spacing: 5) {
                        Capsule(style: .continuous)
                            .fill(selected ? MinimalWhiteStyle.ink : Color.clear)
                            .frame(width: 18, height: 2)

                        MonologueIcon(
                            icon: selected ? tab.icon : tab.monologueIcon,
                            size: 18,
                            color: selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted,
                            lineWidth: 1.7
                        )

                        Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                            .font(MinimalWhiteStyle.labelFont(10, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PetWhiteClassicCushionDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    private var bottomInset: CGFloat {
        min(max(DeviceLayout.safeAreaBottom, 0) * 0.38, DeviceLayout.isPad ? 12 : 14)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                if let song = player.currentSong {
                    PetWhiteClassicNowPlayingChip(song: song)
                        .swipeToSkip()
                        .padding(.horizontal, DeviceLayout.isPad ? 28 : 14)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom))
                        ))
                }

                PetWhiteClassicTabRail(currentTab: $currentTab)
                    .padding(.horizontal, DeviceLayout.isPad ? 30 : 16)
            }
            .padding(.top, 10)
            .padding(.bottom, 10 + bottomInset)
            .background {
                PetWhiteFrostedFloatingSurface(
                    shape: UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: 34,
                            bottomLeading: 0,
                            bottomTrailing: 0,
                            topTrailing: 34
                        ),
                        style: .continuous
                    ),
                    tint: PetWhiteStyle.paper,
                    accent: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                    lineWidth: 1.8
                )
                .overlay(alignment: .topLeading) {
                    PetWhitePetPetIcon(size: 38)
                        .padding(.leading, 24)
                        .offset(y: -18)
                }
            }
            .themeRenderInteractiveLayer()
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }
}

private struct PetWhiteClassicNowPlayingChip: View {
    let song: Song
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @State private var showPlaylist = false

    private var subtitleText: String {
        player.lyricLineText ?? song.artistName
    }

    var body: some View {
        HStack(spacing: 10) {
            PetWhiteSpinningCoverDisc(
                coverURL: song.coverUrl,
                size: 34,
                isPlaying: player.isPlaying,
                strokeWidth: 1.4
            )

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: song.name,
                    font: PetWhiteStyle.bodyFont(13, weight: .black),
                    color: PetWhiteStyle.ink,
                    speed: 25,
                    alignment: .leading
                )
                .frame(height: 17)

                MarqueeText(
                    text: subtitleText,
                    font: PetWhiteStyle.bodyFont(11, weight: .semibold),
                    color: PetWhiteStyle.inkSoft,
                    speed: 22,
                    alignment: .leading
                )
                .frame(height: 14)
            }
            .swipeSkipTextMotion()

            Spacer(minLength: 4)

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint)
                        .frame(width: 42, height: 32)
                        .overlay(Capsule(style: .continuous).stroke(PetWhiteStyle.stroke, lineWidth: 1))

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: PetWhiteStyle.onAccent))
                            .scaleEffect(0.55)
                    } else {
                        PetWhitePackIcon(icon: player.isPlaying ? .pause : .play, size: 21, visualScale: 1.08)
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

            Button(action: { showPlaylist.toggle() }) {
                PetWhitePackIcon(icon: .list, size: 21, visualScale: 1.04, fallbackColor: PetWhiteStyle.ink)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

            if !player.isPlaying {
                Button {
                    withAnimation(MonologueAnimation.floatingBar) {
                        player.dismissMiniPlayerPreservingQueue()
                    }
                } label: {
                    PetWhitePackIcon(icon: .close, size: 16, visualScale: 1, fallbackColor: PetWhiteStyle.inkMuted, lineWidth: 1.6)
                        .frame(width: 28, height: 28)
                        .background(PetWhiteStyle.surfacePressed, in: Circle())
                        .overlay(Circle().stroke(PetWhiteStyle.separator, lineWidth: 1))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background {
            PetWhiteFrostedFloatingSurface(
                shape: Capsule(style: .continuous),
                tint: PetWhiteStyle.surfaceRaised,
                accent: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                strokeColor: PetWhiteStyle.separator,
                lineWidth: 1.1,
                elevated: false
            )
                .overlay(alignment: .bottomLeading) {
                    ProgressBarView(height: 4, minFillWidth: 7)
                        .frame(height: 4)
                        .padding(.leading, 55)
                        .padding(.trailing, player.isPlaying ? 88 : 120)
                        .offset(y: -3)
                }
        }
        .contentShape(Capsule(style: .continuous))
        .onTapWithHaptic { openPlayer() }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
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

private struct PetWhiteClassicTabRail: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    HStack(spacing: 6) {
                        PetWhitePackIcon(
                            icon: selected ? tab.icon : tab.monologueIcon,
                            size: selected ? 18 : 16,
                            visualScale: 1,
                            fallbackColor: selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted,
                            lineWidth: 1.45
                        )

                        if selected {
                            Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                                .font(PetWhiteStyle.labelFont(10, weight: .black))
                                .foregroundColor(PetWhiteStyle.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .frame(maxWidth: selected ? 120 : 48, minHeight: 42)
                    .background {
                        if selected {
                            PetWhiteClayPuck(
                                shape: Capsule(style: .continuous),
                                tint: tabTint(tab),
                                pressedLook: true
                            )
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.9))
            }
        }
    }

    private func tabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return PetWhiteStyle.dogOrange
        case .podcast: return PetWhiteStyle.mint
        case .library: return PetWhiteStyle.butter
        case .profile: return PetWhiteStyle.blush.opacity(0.88)
        }
    }
}

private struct PureWhiteDockSelectionBackground: View {
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(PureWhiteStyle.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.16 : 0.24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(PureWhiteStyle.separator.opacity(colorScheme == .dark ? 0.66 : 0.96), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(PureWhiteStyle.accent)
                    .frame(width: 4, height: 20)
                    .padding(.leading, 7)
            }
    }
}

// MARK: - 经典 MiniPlayer 部分

private struct ClassicMiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var subtitleText: String {
        if let text = player.lyricLineText {
            return text
        }
        return song.artistName
    }

    private var coverCornerRadius: CGFloat {
        if CapsuleStyle.isActive { return 13 }
        if PetWhiteStyle.isActive { return 10 }
        if PureWhiteStyle.isActive { return 10 }
        return MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 7 : (NeumorphicStyle.isActive ? 10 : ((SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? 11 : 9)))
    }

    private var coverSize: CGFloat {
        if CapsuleStyle.isActive { return 34 }
        return (SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? 34 : 33
    }

    private var playControlSize: CGFloat {
        if CapsuleStyle.isActive { return 31 }
        return (SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? 31 : 30
    }

    private var sectionHorizontalPadding: CGFloat {
        if CapsuleStyle.isActive { return DeviceLayout.isPad ? 24 : 16 }
        return (SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? (DeviceLayout.isPad ? 24 : 16) : (DeviceLayout.isPad ? 22 : 15)
    }

    private var miniPillCornerRadius: CGFloat {
        if MangaStyle.isActive { return 23 }
        if PetWhiteStyle.isActive { return 22 }
        if PureWhiteStyle.isActive { return 22 }
        if CapsuleStyle.isActive { return 25 }
        return 24
    }

    var body: some View {
        HStack(spacing: 9) {
            CachedAsyncImage(url: song.coverUrl, width: coverSize, height: coverSize) {
                RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                    .fill(coverPlaceholderFill)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: coverSize, height: coverSize)
            .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
            .overlay(coverStroke)
            .overlay(alignment: .bottomTrailing) {
                if player.playSource == .fm {
                    sourceIndicator(icon: .fm)
                        .offset(x: 4, y: 4)
                } else if player.isPlayingPodcast {
                    sourceIndicator(icon: .radio)
                        .offset(x: 4, y: 4)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
            .onTapWithHaptic { openPlayer() }

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: song.name,
                    font: titleFont,
                    color: titleColor,
                    speed: 25,
                    alignment: .leading
                )
                .frame(height: 17)

                MarqueeText(
                    text: subtitleText,
                    font: subtitleFont,
                    color: subtitleColor,
                    speed: 22,
                    alignment: .leading
                )
                .frame(height: 14)
                    .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .swipeSkipTextMotion()
            .contentShape(Rectangle())
            .onTapWithHaptic { openPlayer() }

            HStack(spacing: 8) {
                Button(action: togglePlayPause) {
                    ZStack {
                        Circle()
                            .fill(controlFill)
                            .frame(width: playControlSize, height: playControlSize)
                            .overlay(controlStroke)

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: controlForeground))
                                .scaleEffect(0.52)
                        } else if PetWhiteStyle.isActive {
                            PetWhitePackIcon(icon: isPlaying ? .pause : .play, size: 20, visualScale: 1.08)
                        } else {
                            MonologueIcon(
                                icon: isPlaying ? .pause : .play,
                                size: 13,
                                color: controlForeground
                            )
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                Button(action: { showPlaylist.toggle() }) {
                    classicBarIcon(icon: .list, size: 15, color: titleColor.opacity(0.70), lineWidth: 1.7)
                        .frame(width: 28, height: 28)
                        .background(secondaryControlFill)
                        .clipShape(Circle())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                if !isPlaying {
                    Button(action: {
                        withAnimation(MonologueAnimation.floatingBar) {
                            player.dismissMiniPlayerPreservingQueue()
                        }
                    }) {
                        classicBarIcon(icon: .close, size: 9.5, color: subtitleColor, lineWidth: 1.6)
                            .frame(width: 25, height: 25)
                            .background(closeFill)
                            .clipShape(Circle())
                            .overlay(closeStroke)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .zIndex(1)
        }
        .frame(minHeight: 39)
        .padding(.horizontal, sectionHorizontalPadding)
        .padding(.top, 3)
        .padding(.bottom, 3)
        .background { miniPillBackground }
        .overlay(miniPillStroke)
        .clipShape(RoundedRectangle(cornerRadius: miniPillCornerRadius, style: .continuous))
        .shadow(color: miniPillShadowColor, radius: miniPillShadowRadius, x: 0, y: miniPillShadowY)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapWithHaptic { openPlayer() }
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
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

    @ViewBuilder
    private var miniPillBackground: some View {
        let shape = RoundedRectangle(cornerRadius: miniPillCornerRadius, style: .continuous)
        if MangaStyle.isActive {
            shape
                .fill(MangaStyle.bubbleWhite.opacity(colorScheme == .dark ? 0.66 : 0.82))
                .overlay(MangaDotsTexture(opacity: colorScheme == .dark ? 0.018 : 0.024, gap: 10).clipShape(shape))
        } else if MinimalWhiteStyle.isActive {
            MinimalWhiteSurfaceBackground(
                cornerRadius: miniPillCornerRadius,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        } else if PureWhiteStyle.isActive {
            PureWhiteSurfaceBackground(
                cornerRadius: miniPillCornerRadius,
                elevated: true,
                tint: PureWhiteStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.90 : 0.99)
            )
        } else if PetWhiteStyle.isActive {
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: miniPillCornerRadius, style: .continuous),
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint,
                lineWidth: PetWhiteStyle.fineStrokeWidth
            )
        } else if MujiStyle.isActive {
            shape
                .fill(.thinMaterial)
                .overlay(shape.fill(MujiStyle.paper.opacity(colorScheme == .dark ? 0.50 : 0.58)))
                .overlay(MujiPaperTexture(opacity: 0.035).clipShape(shape))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: miniPillCornerRadius,
                elevated: true,
                tint: NeumorphicStyle.surface.opacity(colorScheme == .dark ? 0.94 : 0.92),
                lightweight: true
            )
        } else if CapsuleStyle.isActive {
            shape
                .fill(.regularMaterial)
                .overlay(shape.fill(CapsuleStyle.surface.opacity(colorScheme == .dark ? 0.54 : 0.48)))
        } else if SequoiaStyle.isActive {
            shape
                .fill(.thinMaterial)
                .overlay(shape.fill(SequoiaStyle.materialFloating.opacity(colorScheme == .dark ? 0.70 : 0.48)))
        } else if LiquidGlassStyle.isActive {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(LiquidGlassStyle.glassFloating.opacity(colorScheme == .dark ? 0.72 : 0.48)))
        } else if ClayStyle.isActive {
            shape
                .fill(ClayStyle.cream.opacity(colorScheme == .dark ? 0.86 : 0.78))
        } else if BentoStyle.isActive {
            shape
                .fill(BentoStyle.surface.opacity(colorScheme == .dark ? 0.84 : 0.78))
        } else {
            shape
                .fill(settings.defaultThemeUsesLiquidGlassTabBar ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial))
                .overlay(
                    shape.fill(
                        settings.defaultThemeUsesLiquidGlassTabBar
                            ? Color.monologueFloatingBarFill.opacity(colorScheme == .dark ? 0.56 : 0.46)
                            : (colorScheme == .dark ? Color(hex: "1C1C1E").opacity(0.54) : Color.white.opacity(0.52))
                    )
                )
        }
    }

    @ViewBuilder
    private var miniPillStroke: some View {
        RoundedRectangle(cornerRadius: miniPillCornerRadius, style: .continuous)
            .stroke(miniPillStrokeColor, lineWidth: (MangaStyle.isActive || PureWhiteStyle.isActive || PetWhiteStyle.isActive) ? 1.2 : 0.7)
    }

    private var miniPillStrokeColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.72) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.hairline }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk.opacity(colorScheme == .dark ? 0.58 : 0.78) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.stroke }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(colorScheme == .dark ? 0.30 : 0.36) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.36) }
        if CapsuleStyle.isActive { return CapsuleStyle.hairline.opacity(0.54) }
        if SequoiaStyle.isActive { return SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.24 : 0.42) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.26 : 0.44) }
        if ClayStyle.isActive { return ClayStyle.separator.opacity(0.32) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.32) }
        return Color.white.opacity(colorScheme == .dark ? 0.10 : 0.42)
    }

    private var miniPillShadowColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(colorScheme == .dark ? 0.20 : 0.12) }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink.opacity(0.04) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk.opacity(colorScheme == .dark ? 0.20 : 0.12) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.26 : 0.09) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.darkShadow(colorScheme, intensity: 0.35) }
        return Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08)
    }

    private var miniPillShadowRadius: CGFloat {
        if PetWhiteStyle.isActive { return 10 }
        return (MangaStyle.isActive || MinimalWhiteStyle.isActive || PureWhiteStyle.isActive) ? 0 : 11
    }

    private var miniPillShadowY: CGFloat {
        MangaStyle.isActive ? 2 : ((PureWhiteStyle.isActive || PetWhiteStyle.isActive) ? 4 : 5)
    }

    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        classicBarIcon(icon: icon, size: 12, color: sourceIndicatorForeground, lineWidth: 1.6)
            .frame(width: 18, height: 18)
            .background(controlFill)
            .clipShape(Circle())
            .overlay(Circle().stroke(controlForeground.opacity(0.18), lineWidth: 0.5))
    }

    @ViewBuilder
    private func classicBarIcon(icon: MonologueIcon.IconType, size: CGFloat, color: Color, lineWidth: CGFloat) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(icon: icon, size: max(size + 6, 17), visualScale: 1.05, fallbackColor: color, lineWidth: lineWidth)
        } else {
            MonologueIcon(icon: icon, size: size, color: color, lineWidth: lineWidth)
        }
    }

    private var titleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(13, weight: .medium) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(13, weight: .black) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.bodyFont(13, weight: .black) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(13, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(13, weight: .bold) }
        if ClayStyle.isActive { return ClayStyle.labelFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .semibold) }
        if BentoStyle.isActive { return BentoStyle.bodyFont(13, weight: .heavy) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var subtitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(11, weight: .regular) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(11, weight: .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(11, weight: .semibold) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.bodyFont(11, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .regular) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(11, weight: .regular) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(11, weight: .medium) }
        if ClayStyle.isActive { return ClayStyle.labelFont(11, weight: .medium) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        if BentoStyle.isActive { return BentoStyle.labelFont(11, weight: .semibold) }
        return .rounded(size: 11, weight: .medium)
    }

    private var titleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        if ClayStyle.isActive { return ClayStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if BentoStyle.isActive { return BentoStyle.ink }
        return .monologueTextPrimary
    }

    private var subtitleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if ClayStyle.isActive { return ClayStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var coverPlaceholderFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlFill }
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if PetWhiteStyle.isActive { return PetWhiteStyle.surfacePressed }
        if PureWhiteStyle.isActive { return PureWhiteStyle.surfaceTint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.84) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.glassPressed }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceTint }
        if ClayStyle.isActive { return ClayStyle.creamPressed }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised.opacity(0.74) }
        if BentoStyle.isActive { return BentoStyle.buckwheat.opacity(0.5) }
        return Color.gray.opacity(0.15)
    }

    @ViewBuilder
    private var coverStroke: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 1.6)
        } else if PetWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(PetWhiteStyle.stroke, lineWidth: 1)
        } else if PureWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(PureWhiteStyle.separator, lineWidth: 1)
        } else if MinimalWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.55), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(SequoiaStyle.luminousSeparator.opacity(0.42), lineWidth: 0.6)
        } else if LiquidGlassStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(LiquidGlassStyle.luminousEdge.opacity(0.38), lineWidth: 0.6)
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(CapsuleStyle.hairline.opacity(0.8), lineWidth: 0.8)
        } else if ClayStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(ClayStyle.separator.opacity(0.5), lineWidth: 0.7)
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(BentoStyle.hairline.opacity(0.5), lineWidth: 0.7)
        }
    }

    private var controlFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if ClayStyle.isActive { return ClayStyle.butter.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised.opacity(0.76) }
        if BentoStyle.isActive { return BentoStyle.tomato }
        return .monologueIconBackground
    }

    private var secondaryControlFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.08) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.surfacePressed }
        if PureWhiteStyle.isActive { return PureWhiteStyle.surfaceTint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.55) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.64) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.glassList.opacity(0.64) }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceTint.opacity(0.68) }
        if ClayStyle.isActive { return ClayStyle.creamPressed.opacity(0.58) }
        if MujiStyle.isActive { return MujiStyle.ink.opacity(0.055) }
        if BentoStyle.isActive { return BentoStyle.ink.opacity(0.06) }
        return Color.monologueTextPrimary.opacity(0.07)
    }

    private var controlForeground: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if PetWhiteStyle.isActive { return PetWhiteStyle.onAccent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.onAccent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        if ClayStyle.isActive { return ClayStyle.accent }
        if MujiStyle.isActive { return MujiStyle.ink }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        return .monologueIconForeground
    }

    @ViewBuilder
    private var controlStroke: some View {
        if MangaStyle.isActive {
            Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.5)
        } else if PetWhiteStyle.isActive {
            Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1)
        } else if PureWhiteStyle.isActive {
            Circle().stroke(PureWhiteStyle.strokeInk, lineWidth: 1.5)
        } else if MinimalWhiteStyle.isActive {
            Circle().stroke(MinimalWhiteStyle.ink, lineWidth: 0)
        } else if MujiStyle.isActive {
            Circle().stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            Circle().stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            Circle().stroke(SequoiaStyle.accent.opacity(0.22), lineWidth: 0.65)
        } else if LiquidGlassStyle.isActive {
            Circle().stroke(LiquidGlassStyle.luminousEdge.opacity(0.38), lineWidth: 0.65)
        } else if CapsuleStyle.isActive {
            Circle().stroke(CapsuleStyle.hairline.opacity(0.88), lineWidth: 0.8)
        } else if ClayStyle.isActive {
            Circle().stroke(ClayStyle.separator.opacity(0.42), lineWidth: 0.7)
        } else if BentoStyle.isActive {
            Circle().stroke(BentoStyle.tomato.opacity(0.0), lineWidth: 0)
        }
    }

    private var closeFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.12) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink.opacity(0.08) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk.opacity(0.10) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.72) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.84) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.glassList.opacity(0.84) }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceTint.opacity(0.74) }
        if ClayStyle.isActive { return ClayStyle.creamPressed.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.ink.opacity(0.06) }
        if BentoStyle.isActive { return BentoStyle.ink.opacity(0.06) }
        return Color.monologueTextPrimary.opacity(0.08)
    }

    @ViewBuilder
    private var closeStroke: some View {
        if MangaStyle.isActive {
            Circle().stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1)
        } else if PetWhiteStyle.isActive {
            Circle().stroke(PetWhiteStyle.stroke.opacity(0.68), lineWidth: 1)
        } else if PureWhiteStyle.isActive {
            Circle().stroke(PureWhiteStyle.strokeInk.opacity(0.68), lineWidth: 1)
        } else if MujiStyle.isActive {
            Circle().stroke(MujiStyle.hairline.opacity(0.3), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            Circle().stroke(NeumorphicStyle.separator.opacity(0.45), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            Circle().stroke(SequoiaStyle.separator.opacity(0.7), lineWidth: 0.55)
        } else if LiquidGlassStyle.isActive {
            Circle().stroke(LiquidGlassStyle.separator.opacity(0.7), lineWidth: 0.55)
        } else if CapsuleStyle.isActive {
            Circle().stroke(CapsuleStyle.separator.opacity(0.58), lineWidth: 0.7)
        } else if ClayStyle.isActive {
            Circle().stroke(ClayStyle.separator.opacity(0.38), lineWidth: 0.7)
        } else if BentoStyle.isActive {
            Circle().stroke(BentoStyle.hairline.opacity(0.0), lineWidth: 0)
        }
    }

    private var sourceIndicatorForeground: Color {
        if MangaStyle.isActive { return MangaStyle.onStrokeInk }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.onAccent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.onAccent }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        if ClayStyle.isActive { return ClayStyle.ink }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        return .white
    }
}

// MARK: - 经典 TabBar 部分

private struct ClassicTabBarSection: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace

    private static let tabIcons: [(outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]

    private var tabIconSize: CGFloat {
        (MangaStyle.isActive || PureWhiteStyle.isActive || PetWhiteStyle.isActive) ? 17 : 16
    }

    private var tabItemMinHeight: CGFloat {
        DeviceLayout.isPad ? 43 : 39
    }

    private var tabItemVerticalPadding: CGFloat {
        0
    }

    private var sectionBottomPadding: CGFloat {
        0
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< Self.tabIcons.count, id: \.self) { index in
                let tab = Tab.allCases[index]
                let isSelected = currentTab == tab
                let icons = Self.tabIcons[index]
                let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

                Button {
                    HapticManager.shared.light()
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        classicTabIcon(
                            icon: isSelected ? icons.filled : icons.outline,
                            size: tabIconSize,
                            color: tabForeground(index, isSelected: isSelected)
                        )
                        .contentTransition(.interpolate)
                        .scaleEffect(isSelected ? 1.04 : 0.96)
                        .offset(y: isSelected ? -0.5 : 0)

                        Text(label)
                            .font(tabFont(isSelected: isSelected))
                            .foregroundColor(tabForeground(index, isSelected: isSelected))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, minHeight: tabItemMinHeight, alignment: .center)
                    .padding(.vertical, tabItemVerticalPadding)
                    .background {
                        if isSelected {
                            tabSelectionBackground(index)
                                .matchedGeometryEffect(id: "classicDockSelection", in: selectionNamespace)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 1)
        .padding(.bottom, sectionBottomPadding)
    }

    private func tabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive {
            return MangaStyle.labelFont(9.5, weight: isSelected ? .black : .bold)
        }
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.labelFont(9.5, weight: isSelected ? .black : .bold)
        }
        if PureWhiteStyle.isActive {
            return PureWhiteStyle.labelFont(9.5, weight: isSelected ? .black : .bold)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(9.5, weight: isSelected ? .semibold : .medium)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(9.5, weight: isSelected ? .semibold : .medium)
        }
        if LiquidGlassStyle.isActive {
            return LiquidGlassStyle.labelFont(9.5, weight: isSelected ? .semibold : .medium)
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.labelFont(9.5, weight: isSelected ? .bold : .semibold)
        }
        if ClayStyle.isActive {
            return ClayStyle.labelFont(9.5, weight: isSelected ? .bold : .semibold)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(9.5, weight: isSelected ? .semibold : .medium)
        }
        if BentoStyle.isActive {
            return BentoStyle.labelFont(9.5, weight: isSelected ? .heavy : .semibold)
        }
        return .system(size: 9.5, weight: isSelected ? .bold : .medium, design: .rounded)
    }

    private func tabForeground(_ index: Int, isSelected: Bool) -> Color {
        guard isSelected else {
            if MangaStyle.isActive { return MangaStyle.inkMuted }
            if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
            if PureWhiteStyle.isActive { return PureWhiteStyle.inkMuted }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
            if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
            if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkMuted }
            if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
            if ClayStyle.isActive { return ClayStyle.inkMuted }
            if MujiStyle.isActive { return MujiStyle.inkMuted }
            if BentoStyle.isActive { return BentoStyle.inkMuted }
            return .monologueTextSecondary.opacity(0.55)
        }

        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk }
        if NeumorphicStyle.isActive { return neumorphicTabTint(index) }
        if SequoiaStyle.isActive { return sequoiaTabTint(index) }
        if LiquidGlassStyle.isActive { return liquidGlassTabTint(index) }
        if CapsuleStyle.isActive { return CapsuleStyle.readableLabel(on: capsuleTabTint(index)) }
        if ClayStyle.isActive { return clayTabTint(index) }
        if MujiStyle.isActive { return MujiStyle.ink }
        if BentoStyle.isActive { return bentoTabTint(index) == BentoStyle.mustard ? BentoStyle.ink : BentoStyle.onAccent }
        return .monologueAccent
    }

    @ViewBuilder
    private func tabSelectionBackground(_ index: Int) -> some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(mangaTabTint(index).opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(0.82), lineWidth: 1.1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(MangaStyle.bubbleWhite)
                        .frame(width: 5, height: 5)
                        .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 0.8))
                        .padding(6)
                }
                .padding(.horizontal, 3)
        } else if PureWhiteStyle.isActive {
            PureWhiteDockSelectionBackground(tint: pureWhiteTabTint(index))
                .padding(.horizontal, 3)
        } else if PetWhiteStyle.isActive {
            PetWhiteDockSelectionBackground(tint: petWhiteTabTint(index))
                .padding(.horizontal, 3)
        } else if MujiStyle.isActive {
            // Muji：只留一条陶土下划短线
            VStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(MujiStyle.clay)
                    .frame(width: 20, height: 1.6)
            }
            .padding(.bottom, 3)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(NeumorphicStyle.accent.opacity(0.12))
                .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true).padding(.horizontal, 3))
                .padding(.horizontal, 4)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(sequoiaTabTint(index).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(sequoiaTabTint(index).opacity(0.2), lineWidth: 0.55)
                )
                .background(
                    SequoiaSurfaceBackground(
                        cornerRadius: 17,
                        elevated: false,
                        fill: sequoiaTabTint(index).opacity(0.08),
                        role: .selected
                    )
                    .padding(.horizontal, 3)
                )
                .padding(.horizontal, 4)
        } else if LiquidGlassStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(liquidGlassTabTint(index).opacity(0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(liquidGlassTabTint(index).opacity(0.22), lineWidth: 0.55)
                )
                .background(
                    LiquidGlassSurfaceBackground(
                        cornerRadius: 17,
                        elevated: false,
                        pressed: true,
                        fill: liquidGlassTabTint(index).opacity(0.08),
                        role: .selected
                    )
                    .padding(.horizontal, 3)
                )
                .padding(.horizontal, 4)
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(capsuleTabTint(index).opacity(colorScheme == .dark ? 0.86 : 0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.76), lineWidth: 0.8)
                )
                .shadow(color: capsuleTabTint(index).opacity(0.12), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 4)
        } else if ClayStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(clayTabTint(index).opacity(0.22))
                .background(ClaySurfaceBackground(cornerRadius: 17, tint: clayTabTint(index).opacity(0.12), elevated: false, pressed: true, compact: true).padding(.horizontal, 3))
                .padding(.horizontal, 4)
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(bentoTabTint(index))
                .padding(.horizontal, 4)
        } else {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.monologueAccent.opacity(colorScheme == .dark ? 0.16 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.monologueAccent.opacity(colorScheme == .dark ? 0.30 : 0.22), lineWidth: 0.7)
                )
                .padding(.horizontal, 4)
        }
    }

    private func mangaTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return MangaStyle.labelYellow
        case 1: return MangaStyle.bubbleBlue
        case 2: return MangaStyle.mint
        default: return MangaStyle.bubblePink
        }
    }

    private func pureWhiteTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return PureWhiteStyle.accent
        case 1: return PureWhiteStyle.paperBlue
        case 2: return PureWhiteStyle.inkSoft.opacity(0.72)
        default: return PureWhiteStyle.separator
        }
    }

    @ViewBuilder
    private func classicTabIcon(icon: MonologueIcon.IconType, size: CGFloat, color: Color) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(icon: icon, size: 16, visualScale: 1, fallbackColor: color, lineWidth: 1.45)
        } else {
            MonologueIcon(icon: icon, size: size, color: color)
        }
    }

    private func petWhiteTabTint(_ index: Int) -> Color {
        PetWhiteStyle.tabTint(index)
    }

    private func bentoTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return BentoStyle.tomato
        case 1: return BentoStyle.nori
        case 2: return BentoStyle.matcha
        default: return BentoStyle.mustard
        }
    }

    private func capsuleTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return CapsuleStyle.accent
        case 1: return CapsuleStyle.mint
        case 2: return CapsuleStyle.amber
        default: return CapsuleStyle.violet
        }
    }

    private func neumorphicTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return NeumorphicStyle.accent
        case 1: return NeumorphicStyle.warm
        case 2: return NeumorphicStyle.sage
        default: return NeumorphicStyle.red
        }
    }

    private func sequoiaTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return SequoiaStyle.accent
        case 1: return SequoiaStyle.violet
        case 2: return SequoiaStyle.aqua
        default: return SequoiaStyle.green
        }
    }

    private func liquidGlassTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return LiquidGlassStyle.accent
        case 1: return LiquidGlassStyle.violet
        case 2: return LiquidGlassStyle.mint
        default: return LiquidGlassStyle.pink
        }
    }

    private func clayTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return ClayStyle.accent
        case 1: return ClayStyle.mint
        case 2: return ClayStyle.sky
        default: return ClayStyle.grape
        }
    }
}

// MARK: - Aside 经典贴底 Dock（顶边阅读进度 + 发丝线分层）

private struct AsideClassicDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    private let topRadius: CGFloat = 30

    private var bottomInset: CGFloat {
        let safeArea = max(DeviceLayout.safeAreaBottom, 0)
        guard safeArea > 0 else { return 0 }
        return min(safeArea * 0.46, DeviceLayout.isPad ? 14 : 16)
    }

    private var dockShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: topRadius,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: topRadius
            ),
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                if player.currentSong != nil {
                    // 顶边阅读进度：贴着 Dock 上缘的一根强调色细线
                    ProgressBarView(height: 2, minFillWidth: 6)
                        .padding(.horizontal, topRadius - 8)
                        .padding(.top, 7)
                        .transition(.opacity)
                }

                if let song = player.currentSong {
                    AsideClassicNowPlayingRow(song: song)
                        .swipeToSkip()
                        .padding(.horizontal, DeviceLayout.isPad ? 34 : 18)
                        .padding(.top, 6)
                        .padding(.bottom, 9)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))

                    Rectangle()
                        .fill(Color.monologueTextPrimary.opacity(0.07))
                        .frame(height: 0.7)
                        .padding(.horizontal, DeviceLayout.isPad ? 30 : 16)
                }

                AsideClassicTabRail(currentTab: $currentTab)
                    .padding(.horizontal, DeviceLayout.isPad ? 26 : 10)
                    .padding(.top, player.currentSong == nil ? 9 : 4)
            }
            .padding(.bottom, 2 + bottomInset)
            .background(dockBackground)
            .overlay(alignment: .top) {
                dockShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.13 : 0.62),
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10),
                                Color.clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            }
            .clipShape(dockShape)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.10), radius: 14, x: 0, y: -4)
            .themeRenderInteractiveLayer()
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    private var dockBackground: some View {
        dockShape
            .fill(.ultraThinMaterial)
            .overlay(
                dockShape.fill(
                    colorScheme == .dark
                        ? Color(hex: "141721").opacity(0.72)
                        : Color.white.opacity(0.72)
                )
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.045 : 0.30),
                        Color.clear,
                        Color.monologueAccent.opacity(colorScheme == .dark ? 0.04 : 0.025),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(dockShape)
            )
    }
}

private struct AsideClassicNowPlayingRow: View {
    let song: Song
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @State private var showPlaylist = false

    private var subtitleText: String {
        player.lyricLineText ?? song.artistName
    }

    var body: some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: song.coverUrl, width: 38, height: 38) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.monologueTextPrimary.opacity(0.06))
                    .overlay(MonologueIcon(icon: .musicNote, size: 14, color: .monologueTextSecondary.opacity(0.6), lineWidth: 1.5))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.monologueTextPrimary.opacity(0.1), lineWidth: 0.7)
            )
            .overlay(alignment: .bottomTrailing) {
                if player.playSource == .fm {
                    sourceBadge(icon: .fm)
                } else if player.isPlayingPodcast {
                    sourceBadge(icon: .radio)
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

                MarqueeText(
                    text: subtitleText,
                    font: .system(size: 10.5, weight: .medium, design: .rounded),
                    color: .monologueTextSecondary.opacity(0.9),
                    speed: 22,
                    alignment: .leading
                )
                .frame(height: 13)
                .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .swipeSkipTextMotion()

            HStack(spacing: 8) {
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.monologueAccent)
                            .frame(width: 33, height: 33)

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .monologueAccentForeground))
                                .scaleEffect(0.5)
                        } else {
                            MonologueIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 13,
                                color: .monologueAccentForeground,
                                lineWidth: 1.8
                            )
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.93))

                Button(action: { showPlaylist.toggle() }) {
                    MonologueIcon(icon: .list, size: 14, color: .monologueTextPrimary.opacity(0.66), lineWidth: 1.7)
                        .frame(width: 30, height: 30)
                        .background(Circle().strokeBorder(Color.monologueTextPrimary.opacity(0.13), lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.93))

                if !player.isPlaying {
                    Button {
                        withAnimation(MonologueAnimation.floatingBar) {
                            player.dismissMiniPlayerPreservingQueue()
                        }
                    } label: {
                        MonologueIcon(icon: .close, size: 9.5, color: .monologueTextSecondary, lineWidth: 1.6)
                            .frame(width: 26, height: 26)
                            .background(Color.monologueTextPrimary.opacity(0.07), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.93))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .zIndex(1)
        }
        .contentShape(Rectangle())
        .onTapWithHaptic { openPlayer() }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func sourceBadge(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 9, color: .monologueAccentForeground, lineWidth: 1.6)
            .frame(width: 16, height: 16)
            .background(Color.monologueAccent, in: Circle())
            .overlay(Circle().stroke(Color(light: .white, dark: Color(hex: "141721")).opacity(0.9), lineWidth: 1.3))
            .offset(x: 4, y: 4)
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

private struct AsideClassicTabRail: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var dotNS

    private static let tabIcons: [(outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Tab.allCases.enumerated()), id: \.element) { index, tab in
                tabButton(index: index, tab: tab)
            }
        }
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    private func tabButton(index: Int, tab: Tab) -> some View {
        let selected = currentTab == tab
        let icons = Self.tabIcons[index]
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            currentTab = tab
        } label: {
            VStack(spacing: 3) {
                MonologueIcon(
                    icon: selected ? icons.filled : icons.outline,
                    size: 18,
                    color: selected ? .monologueTextPrimary : .monologueTextSecondary.opacity(0.55),
                    lineWidth: 1.7
                )
                .scaleEffect(selected ? 1.05 : 1.0)

                Text(label)
                    .font(.system(size: 9.5, weight: selected ? .bold : .medium, design: .rounded))
                    .foregroundColor(selected ? .monologueTextPrimary : .monologueTextSecondary.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                // 脚注圆点：滑动的选中标记
                ZStack {
                    Circle().fill(Color.clear).frame(width: 4, height: 4)
                    if selected {
                        Circle()
                            .fill(Color.monologueAccent)
                            .frame(width: 4, height: 4)
                            .matchedGeometryEffect(id: "asideClassicDot", in: dotNS)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: DeviceLayout.isPad ? 48 : 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
