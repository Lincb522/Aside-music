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
        case .default, .bento:
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
        case .default, .bento:
            return Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
        }
    }

    private var internalSeparatorColor: Color {
        switch settings.globalThemeId {
        case .manga:
            return MangaStyle.strokeInk.opacity(0.18)
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
        case .default, .bento:
            return Color.monologueSeparator.opacity(colorScheme == .dark ? 0.32 : 0.22)
        }
    }

    var body: some View {
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
        case .default:
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
                }
            }
            .overlay {
                dockShape
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.34), lineWidth: 0.6)
                    .blendMode(.plusLighter)
            }
    }

    private var dockStrokeColor: Color {
        switch settings.globalThemeId {
        case .manga:
            return MangaStyle.strokeInk.opacity(0.72)
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
        case .default, .bento:
            return Color.white.opacity(colorScheme == .dark ? 0.12 : 0.52)
        }
    }

    private var dockStrokeWidth: CGFloat {
        settings.globalThemeId == .manga ? 1.4 : 0.85
    }

    @ViewBuilder
    private var dockAccentRail: some View {
        switch settings.globalThemeId {
        case .manga:
            HStack(spacing: 4) {
                Capsule().fill(MangaStyle.accentPink)
                Capsule().fill(MangaStyle.labelYellow)
                Capsule().fill(MangaStyle.decoBlue)
            }
            .frame(width: 82, height: 5)
            .padding(.leading, 18)
            .padding(.top, 6)
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
        case .neumorphic:
            return 14
        case .capsule, .sequoia, .liquidGlass:
            return 13
        default:
            return 11
        }
    }

    private var dockShadowY: CGFloat {
        settings.globalThemeId == .manga ? -1 : -3
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
                .frame(height: 15)

                MarqueeText(
                    text: subtitleText,
                    font: subtitleFont,
                    color: subtitleColor,
                    speed: 22,
                    alignment: .leading
                )
                .frame(height: 13)
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
                    MonologueIcon(icon: .list, size: 15, color: titleColor.opacity(0.70))
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
                        MonologueIcon(icon: .close, size: 9.5, color: subtitleColor)
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
            .stroke(miniPillStrokeColor, lineWidth: MangaStyle.isActive ? 1.2 : 0.7)
    }

    private var miniPillStrokeColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.72) }
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
        if NeumorphicStyle.isActive { return NeumorphicStyle.darkShadow(colorScheme, intensity: 0.35) }
        return Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08)
    }

    private var miniPillShadowRadius: CGFloat {
        MangaStyle.isActive ? 0 : 11
    }

    private var miniPillShadowY: CGFloat {
        MangaStyle.isActive ? 2 : 5
    }

    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 12, color: sourceIndicatorForeground, lineWidth: 1.6)
            .frame(width: 18, height: 18)
            .background(controlFill)
            .clipShape(Circle())
            .overlay(Circle().stroke(controlForeground.opacity(0.18), lineWidth: 0.5))
    }

    private var titleFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
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
        if MangaStyle.isActive { return MangaStyle.bodyFont(11, weight: .medium) }
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
        if MangaStyle.isActive { return MangaStyle.ink }
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
        if MangaStyle.isActive { return MangaStyle.inkSub }
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
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.84) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.glassPressed }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceTint }
        if ClayStyle.isActive { return ClayStyle.creamPressed }
        if MujiStyle.isActive { return MujiStyle.paperWarm.opacity(0.74) }
        if BentoStyle.isActive { return BentoStyle.buckwheat.opacity(0.5) }
        return Color.gray.opacity(0.15)
    }

    @ViewBuilder
    private var coverStroke: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 1.6)
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
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if ClayStyle.isActive { return ClayStyle.butter.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.paperWarm.opacity(0.76) }
        if BentoStyle.isActive { return BentoStyle.tomato }
        return .monologueIconBackground
    }

    private var secondaryControlFill: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.08) }
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
        if MangaStyle.isActive { return MangaStyle.strokeInk }
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
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.12) }
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
        MangaStyle.isActive ? 17 : 16
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
                        MonologueIcon(
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
        return .system(size: 9.5, weight: isSelected ? .semibold : .medium)
    }

    private func tabForeground(_ index: Int, isSelected: Bool) -> Color {
        guard isSelected else {
            if MangaStyle.isActive { return MangaStyle.inkMuted }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
            if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
            if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkMuted }
            if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
            if ClayStyle.isActive { return ClayStyle.inkMuted }
            if MujiStyle.isActive { return MujiStyle.inkMuted }
            if BentoStyle.isActive { return BentoStyle.inkMuted }
            return .monologueTextPrimary.opacity(0.35)
        }

        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return neumorphicTabTint(index) }
        if SequoiaStyle.isActive { return sequoiaTabTint(index) }
        if LiquidGlassStyle.isActive { return liquidGlassTabTint(index) }
        if CapsuleStyle.isActive { return CapsuleStyle.readableLabel(on: capsuleTabTint(index)) }
        if ClayStyle.isActive { return clayTabTint(index) }
        if MujiStyle.isActive { return mujiTabTint(index) }
        if BentoStyle.isActive { return bentoTabTint(index) == BentoStyle.mustard ? BentoStyle.ink : BentoStyle.onAccent }
        return .monologueTextPrimary
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
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MujiStyle.paperWarm.opacity(colorScheme == .dark ? 0.22 : 0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.32), lineWidth: 0.6)
                )
                .padding(.horizontal, 4)
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
                .fill(Color.monologueTextPrimary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.34), lineWidth: 0.6)
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

    private func mujiTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return MujiStyle.clay
        case 1: return MujiStyle.tea
        case 2: return MujiStyle.indigo
        default: return MujiStyle.straw
        }
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
