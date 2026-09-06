import SwiftUI

/// 极简模式的 MiniPlayer（同一容器内左滑显示 Tab，右滑回播放器）
struct MinimalMiniPlayer: View {
    @Environment(\.floatingBarColorRevision) private var colorRevision
    @Binding var currentTab: Tab
    @ObservedObject var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPlaylist = false

    @State private var showingTabs = false
    @Namespace private var asidePillNS

    private var shellCornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 18 }
        if MangaStyle.isActive { return 20 }
        if PetWhiteStyle.isActive { return 22 }
        if NeumorphicStyle.isActive { return 22 }
        if SequoiaStyle.isActive { return 24 }
        if LiquidGlassStyle.isActive { return 24 }
        if CapsuleStyle.isActive { return 26 }
        if MujiStyle.isActive { return 16 }
        if BentoStyle.isActive { return 22 }
        return 18
    }

    private var shellHorizontalPadding: CGFloat {
        if MinimalWhiteStyle.isActive { return 10 }
        if MangaStyle.isActive { return DeviceLayout.usesExpandedLayout ? 16 : 10 }
        if PetWhiteStyle.isActive { return DeviceLayout.usesExpandedLayout ? 18 : 12 }
        if SequoiaStyle.isActive { return DeviceLayout.usesExpandedLayout ? 20 : 12 }
        if LiquidGlassStyle.isActive { return DeviceLayout.usesExpandedLayout ? 20 : 12 }
        if CapsuleStyle.isActive { return DeviceLayout.usesExpandedLayout ? 18 : 12 }
        return DeviceLayout.usesExpandedLayout ? 20 : 14
    }

    private var shellVerticalPadding: CGFloat {
        if MinimalWhiteStyle.isActive { return 8 }
        if MangaStyle.isActive { return 7 }
        if PetWhiteStyle.isActive { return 8 }
        if SequoiaStyle.isActive { return 9 }
        if LiquidGlassStyle.isActive { return 9 }
        if CapsuleStyle.isActive { return 8 }
        return 10
    }

    private var miniContentSpacing: CGFloat {
        PetWhiteStyle.isActive ? 9 : (CapsuleStyle.isActive ? 9 : (MangaStyle.isActive ? 8 : 10))
    }

    private var artworkSize: CGFloat {
        PetWhiteStyle.isActive ? 38 : (CapsuleStyle.isActive ? 38 : (MangaStyle.isActive ? 34 : ((SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? 38 : 40)))
    }

    private var artworkCornerRadius: CGFloat {
        return PetWhiteStyle.isActive ? 10 : (CapsuleStyle.isActive ? 14 : (MangaStyle.isActive ? 8 : ((SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? 11 : 10)))
    }

    private var transportSpacing: CGFloat {
        MangaStyle.isActive ? 5 : 6
    }

    private var compactControlWidth: CGFloat {
        PetWhiteStyle.isActive ? 32 : (CapsuleStyle.isActive ? 32 : (MangaStyle.isActive ? 27 : 30))
    }

    private var compactControlHeight: CGFloat {
        PetWhiteStyle.isActive ? 34 : (CapsuleStyle.isActive ? 34 : (MangaStyle.isActive ? 30 : 34))
    }

    private var playButtonSize: CGFloat {
        PetWhiteStyle.isActive ? 34 : (CapsuleStyle.isActive ? 34 : (MangaStyle.isActive ? 30 : 34))
    }

    private func subtitleText(for lineText: String?) -> String {
        if let text = lineText {
            return text
        }
        return player.currentSong?.artistName ?? NSLocalizedString("select_song_to_play", comment: String(localized: "选择歌曲开始播放"))
    }

    var body: some View {
        let _ = colorRevision

        let _ = settings.globalThemeRevision

        if MinimalWhiteStyle.isActive {
            minimalWhiteBody
        } else if PetWhiteStyle.isActive {
            PetWhiteMinimalBowPlayer(currentTab: $currentTab)
        } else if settings.globalThemeId == .default {
            asideBody
        } else {
            defaultBody
        }
    }

    // MARK: - Aside 印章胶囊（封面进度环 + 墨水药丸）

    private var asideBody: some View {
        HStack(spacing: 9) {
            Button {
                HapticManager.shared.light()
                withAnimation(MonoAnimation.panelToggle) {
                    showingTabs.toggle()
                }
            } label: {
                asideCoverSignet
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

            if showingTabs || player.currentSong == nil {
                asideTabPills
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            } else {
                asideNowPlayingSegment
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .padding(.vertical, 7)
        .background(asideShellBackground)
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.14 : 0.62),
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.14),
                            Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .compositingGroup()
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.12), radius: 16, x: 0, y: 8)
        .contentShape(Capsule(style: .continuous))
        .simultaneousGesture(panelSwitchGesture)
        .animation(MonoAnimation.panelToggle, value: showingTabs)
        .themeRenderInteractiveLayer()
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    @ViewBuilder
    private var asideShellBackground: some View {
        let shape = Capsule(style: .continuous)
        if settings.defaultThemeUsesLiquidGlassTabBar {
            shape
                .fill(Color.monoFloatingBarFill)
                .monoGlassCapsule()
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
        }
    }

    private var asideCoverSignet: some View {
        ZStack {
            AsideMiniProgressRing(size: 46, lineWidth: 2.2)

            Group {
                if let song = player.currentSong {
                    CachedAsyncImage(url: song.coverUrl, width: 38, height: 38) {
                        asideCoverPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    asideCoverPlaceholder
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.monoTextPrimary.opacity(0.1), lineWidth: 0.7))
        }
        .frame(width: 46, height: 46)
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(showingTabs ? Color.monoAccent : Color(light: .white, dark: Color(hex: "1C1F29")))
                .frame(width: 11, height: 11)
                .overlay(Circle().strokeBorder(Color.monoTextPrimary.opacity(0.16), lineWidth: 0.8))
                .offset(x: 1, y: 1)
        }
    }

    private var asideCoverPlaceholder: some View {
        Circle()
            .fill(Color.monoTextPrimary.opacity(0.07))
            .overlay(MonoIcon(icon: .musicNote, size: 14, color: .monoTextSecondary.opacity(0.62), lineWidth: 1.5))
    }

    private var asideNowPlayingSegment: some View {
        HStack(spacing: 7) {
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: player.currentSong?.name ?? NSLocalizedString("not_playing", comment: String(localized: "not_playing")),
                    font: .system(size: 13, weight: .semibold, design: .rounded),
                    color: .monoTextPrimary,
                    speed: 25
                )
                .frame(height: 16)

                FloatingBarLyricReader { lineText in
                    MarqueeText(
                        text: subtitleText(for: lineText),
                        font: .system(size: 10.5, weight: .medium, design: .rounded),
                        color: .monoTextSecondary.opacity(0.9),
                        speed: 22
                    )
                    .frame(height: 13)
                    .animation(.easeInOut(duration: 0.25), value: lineText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .swipeSkipTextMotion()
            .contentShape(Rectangle())
            .onTapWithHaptic {
                if player.currentSong != nil {
                    openPlayer()
                }
            }

            asideGhostButton(icon: .previous, accessibilityLabel: String(localized: "上一首")) {
                player.previous()
            }

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.monoAccent)
                        .frame(width: 34, height: 34)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .monoAccentForeground))
                            .scaleEffect(0.52)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 13,
                            color: .monoAccentForeground,
                            lineWidth: 1.8
                        )
                    }
                }
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.93))

            asideGhostButton(icon: .next, accessibilityLabel: NSLocalizedString("playback_next_track", comment: "")) {
                player.next()
            }

            Button(action: { showPlaylist.toggle() }) {
                MonoIcon(icon: .list, size: 14, color: .monoTextPrimary.opacity(0.66), lineWidth: 1.7)
                    .frame(width: 28, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.93))
        }
    }

    private func asideGhostButton(
        icon: MonoIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            MonoIcon(icon: icon, size: 13, color: .monoTextPrimary.opacity(0.62), lineWidth: 1.7)
                .frame(width: 26, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var asideTabPills: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let selected = currentTab == tab
                let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

                Button {
                    HapticManager.shared.light()
                    withAnimation(MonoAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        MonoIcon(
                            icon: selected ? tab.icon : tab.monoIcon,
                            size: 17,
                            color: selected ? .monoAccentForeground : .monoTextSecondary.opacity(0.62),
                            lineWidth: 1.7,
                            artworkContrastBackground: selected ? .monoAccent : nil
                        )

                        if selected {
                            Text(label)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.monoAccentForeground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: 116)
                    .frame(height: 38)
                    .background {
                        if selected {
                            Capsule(style: .continuous)
                                .fill(Color.monoAccent)
                                .matchedGeometryEffect(id: "asideMinimalPill", in: asidePillNS)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(label))
            }
        }
        .animation(MonoAnimation.tabSwitch, value: currentTab)
    }

    private var minimalWhiteBody: some View {
        HStack(spacing: 8) {
            Button {
                HapticManager.shared.light()
                withAnimation(MonoAnimation.panelToggle) {
                    showingTabs.toggle()
                }
            } label: {
                minimalWhiteCoverToggle
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

            if showingTabs || player.currentSong == nil {
                minimalWhiteTabCapsule
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            } else {
                minimalWhiteNowPlayingCapsule
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .padding(.vertical, 7)
        .background(MinimalWhiteCapsuleBackground(elevated: true))
        .overlay(Capsule(style: .continuous).stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth))
        .contentShape(Capsule(style: .continuous))
        .simultaneousGesture(panelSwitchGesture)
        .animation(.easeInOut(duration: 0.18), value: showingTabs)
        .themeRenderInteractiveLayer()
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private var minimalWhiteCoverToggle: some View {
        Group {
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl, width: 42, height: 42) {
                    defaultVinylCover
                }
                .aspectRatio(contentMode: .fill)
            } else {
                defaultVinylCover
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
        )
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(showingTabs ? MinimalWhiteStyle.ink : MinimalWhiteStyle.surface)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth))
                .offset(x: 2, y: 2)
        }
    }

    private var minimalWhiteNowPlayingCapsule: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: player.currentSong?.name ?? NSLocalizedString("not_playing", comment: ""),
                    font: MinimalWhiteStyle.bodyFont(13, weight: .semibold),
                    color: MinimalWhiteStyle.ink,
                    speed: 24
                )
                .frame(height: 16)

                FloatingBarLyricReader { lineText in
                    MarqueeText(
                        text: subtitleText(for: lineText),
                        font: MinimalWhiteStyle.labelFont(11, weight: .regular),
                        color: MinimalWhiteStyle.inkMuted,
                        speed: 22
                    )
                    .frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .swipeSkipTextMotion()
            .onTapWithHaptic {
                if player.currentSong != nil {
                    openPlayer()
                }
            }

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(MinimalWhiteStyle.ink)
                        .frame(width: 34, height: 34)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: MinimalWhiteStyle.onAccent))
                            .scaleEffect(0.55)
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 14,
                            color: MinimalWhiteStyle.onAccent,
                            lineWidth: 1.8
                        )
                    }
                }
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

            Button(action: { showPlaylist.toggle() }) {
                MonoIcon(icon: .list, size: 15, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.7)
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
    }

    private var minimalWhiteTabCapsule: some View {
        HStack(spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonoAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    MonoIcon(
                        icon: selected ? tab.icon : tab.monoIcon,
                        size: 17,
                        color: selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted,
                        lineWidth: 1.7,
                        artworkContrastBackground: selected ? MinimalWhiteStyle.selectedFill : nil
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background {
                        if selected {
                            Capsule(style: .continuous)
                                .fill(MinimalWhiteStyle.selectedFill)
                                .overlay(Capsule(style: .continuous).stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth))
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var defaultBody: some View {
        ZStack {
            if player.currentSong != nil {
                // 有歌曲时：迷你播放器 / Tab 选择器切换
                miniPlayerContent
                    .opacity(showingTabs ? 0 : 1)
                    .offset(x: showingTabs ? -50 : 0)

                tabSelectorContent
                    .opacity(showingTabs ? 1 : 0)
                    .offset(x: showingTabs ? 0 : 50)
            } else {
                // 无歌曲时：只显示 Tab 选择器
                tabSelectorContent
            }
        }
        .padding(.horizontal, shellHorizontalPadding)
        .padding(.vertical, shellVerticalPadding)
        .background(shellBackground)
        .monoFloatingChromeGlass(cornerRadius: shellCornerRadius)
        .overlay {
            if MangaStyle.isActive {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: 1.6)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 0) {
                            MangaStyle.labelYellow.frame(width: 28, height: 4)
                            MangaStyle.accentPink.frame(width: 20, height: 4)
                            MangaStyle.decoBlue.frame(width: 24, height: 4)
                        }
                        .clipShape(Capsule())
                        .offset(x: 15, y: 6)
                    }
                        .overlay(alignment: .bottomTrailing) {
                            MangaSectionMark(kind: showingTabs ? .star : .heart, tint: showingTabs ? MangaStyle.decoBlue : MangaStyle.bubblePink, size: 12)
                                .offset(x: -14, y: -4)
                        }
            } else if PetWhiteStyle.isActive {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1)
            } else if SequoiaStyle.isActive {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.2 : 0.58),
                                SequoiaStyle.separator.opacity(0.72),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.65
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill((showingTabs ? SequoiaStyle.aqua : SequoiaStyle.accent).opacity(0.68))
                            .frame(width: showingTabs ? 42 : 30, height: 3)
                            .offset(y: 5)
                            .animation(MonoAnimation.micro, value: showingTabs)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(showingTabs ? SequoiaStyle.inkMuted.opacity(0.35) : SequoiaStyle.accent)
                                .frame(width: 5, height: 5)
                            Circle()
                                .fill(showingTabs ? SequoiaStyle.aqua : SequoiaStyle.inkMuted.opacity(0.35))
                                .frame(width: 5, height: 5)
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, 7)
                    }
            } else if LiquidGlassStyle.isActive {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.2 : 0.58),
                                LiquidGlassStyle.separator.opacity(0.72),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.65
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill((showingTabs ? LiquidGlassStyle.violet : LiquidGlassStyle.accent).opacity(0.68))
                            .frame(width: showingTabs ? 42 : 30, height: 3)
                            .offset(y: 5)
                            .animation(MonoAnimation.micro, value: showingTabs)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(showingTabs ? LiquidGlassStyle.inkMuted.opacity(0.35) : LiquidGlassStyle.accent)
                                .frame(width: 5, height: 5)
                            Circle()
                                .fill(showingTabs ? LiquidGlassStyle.violet : LiquidGlassStyle.inkMuted.opacity(0.35))
                                .frame(width: 5, height: 5)
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, 7)
                    }
            } else if BentoStyle.isActive {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .stroke(BentoStyle.ink.opacity(0.08), lineWidth: 1)
                    .overlay(alignment: .top) {
                        HStack(spacing: 0) {
                            BentoStyle.tomato.frame(width: 22, height: 4)
                            BentoStyle.matcha.frame(width: 14, height: 4)
                            BentoStyle.mustard.frame(width: 18, height: 4)
                        }
                        .clipShape(Capsule())
                        .offset(y: 6)
                    }
            } else if CapsuleStyle.isActive {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .stroke(CapsuleStyle.hairline.opacity(0.84), lineWidth: 0.9)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 5) {
                            Capsule()
                                .fill(LinearGradient(colors: CapsuleStyle.accentGradient, startPoint: .leading, endPoint: .trailing))
                                .frame(width: showingTabs ? 42 : 30, height: 4)
                            Circle()
                                .fill(showingTabs ? CapsuleStyle.violet : CapsuleStyle.cyan)
                                .frame(width: 5, height: 5)
                        }
                        .padding(.leading, 16)
                        .padding(.top, 6)
                        .animation(MonoAnimation.micro, value: showingTabs)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(showingTabs ? CapsuleStyle.inkMuted.opacity(0.32) : CapsuleStyle.accent)
                                .frame(width: 5, height: 5)
                            Circle()
                                .fill(showingTabs ? CapsuleStyle.violet : CapsuleStyle.inkMuted.opacity(0.32))
                                .frame(width: 5, height: 5)
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, 7)
                    }
            }
        }
        .shadow(
            color: SequoiaStyle.isActive ? SequoiaStyle.shadow(colorScheme, elevated: true) : (LiquidGlassStyle.isActive ? LiquidGlassStyle.shadow(colorScheme, elevated: true) : .clear),
            radius: (SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? 17 : 0,
            x: 0,
            y: (SequoiaStyle.isActive || LiquidGlassStyle.isActive) ? 8 : 0
        )
        .contentShape(Rectangle())
        .simultaneousGesture(panelSwitchGesture)
        .animation(MonoAnimation.panelToggle, value: showingTabs)
        .themeRenderInteractiveLayer()
    }

    @ViewBuilder
    private var shellBackground: some View {
        if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: shellCornerRadius, elevated: true, role: .floating)
        } else if PetWhiteStyle.isActive {
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous),
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint,
                lineWidth: PetWhiteStyle.strokeWidth
            )
            .overlay(
                LinearGradient(
                    colors: [
                        PetWhiteStyle.mint.opacity(colorScheme == .dark ? 0.08 : 0.16),
                        Color.clear,
                        PetWhiteStyle.sky.opacity(colorScheme == .dark ? 0.08 : 0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous))
            )
        } else if LiquidGlassStyle.isActive {
            LiquidGlassSurfaceBackground(cornerRadius: shellCornerRadius, elevated: true, role: .floating)
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                .fill(BentoStyle.surface)
                .shadow(color: BentoStyle.ink.opacity(0.06), radius: 12, x: 0, y: 4)
        } else if CapsuleStyle.isActive {
            CapsuleFloatingGlassSurface(
                cornerRadius: shellCornerRadius,
                tint: CapsuleStyle.surface,
                lightOpacity: 0.46,
                darkOpacity: 0.62,
                elevated: true
            )
        } else {
            if !ThemedPageStyle.isActive && settings.defaultThemeUsesLiquidGlassTabBar {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .fill(Color.monoFloatingBarFill)
                    .monoGlass(cornerRadius: shellCornerRadius)
            } else {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .fill(ThemedPageStyle.isActive ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.regularMaterial))
                    .overlay {
                        if !ThemedPageStyle.isActive {
                            RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                                .fill(colorScheme == .dark ? Color(hex: "1C1C1E").opacity(0.48) : Color.white.opacity(0.5))
                        }
                    }
                    .overlay {
                        if !ThemedPageStyle.isActive {
                            RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.045 : 0.24),
                                            Color.white.opacity(colorScheme == .dark ? 0.015 : 0.08),
                                            Color.monoAccent.opacity(colorScheme == .dark ? 0.035 : 0.03),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
            }
        }
    }

    private var panelSwitchGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .onEnded { value in
                guard player.currentSong != nil else { return }
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }

                let threshold: CGFloat = 15

                if !showingTabs {
                    guard value.translation.width < -threshold else { return }
                    withAnimation(MonoAnimation.panelToggle) {
                        showingTabs = true
                    }
                    return
                }

                guard value.translation.width > threshold else { return }
                withAnimation(MonoAnimation.panelToggle) {
                    showingTabs = false
                }
            }
    }

    // MARK: - 迷你播放器内容

    private var miniPlayerContent: some View {
        HStack(spacing: miniContentSpacing) {
            // 封面
            Group {
                if let song = player.currentSong {
                    CachedAsyncImage(url: song.coverUrl, width: artworkSize, height: artworkSize) {
                        defaultVinylCover
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    defaultVinylCover
                }
            }
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous))
            .overlay {
                if player.playSource == .fm {
                    sourceIndicator(icon: .fm)
                } else if player.isPlayingPodcast {
                    sourceIndicator(icon: .radio)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(
                    text: player.currentSong?.name ?? NSLocalizedString("not_playing", comment: String(localized: "not_playing")),
                    font: titleFont,
                    color: titleColor,
                    speed: 25
                )
                .frame(height: 16)

                FloatingBarLyricReader { lineText in
                    MarqueeText(
                        text: subtitleText(for: lineText),
                        font: subtitleFont,
                        color: subtitleColor,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: lineText)
                }
            }
            .swipeSkipTextMotion()

            Spacer(minLength: 4)

            // 控制按钮
            HStack(spacing: transportSpacing) {
                transportButton(icon: .previous, accessibilityLabel: String(localized: "上一首")) {
                    player.previous()
                }

                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(controlFill)
                            .frame(width: playButtonSize, height: playButtonSize)
                            .overlay(controlStroke)

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: controlForeground))
                                .scaleEffect(0.55)
                        } else if PetWhiteStyle.isActive {
                            PetWhitePackIcon(icon: player.isPlaying ? .pause : .play, size: 21, visualScale: 1.08)
                        } else {
                            MonoIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: MangaStyle.isActive ? 13 : 14,
                                color: controlForeground
                            )
                        }
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle())

                transportButton(icon: .next, accessibilityLabel: NSLocalizedString("playback_next_track", comment: "")) {
                    player.next()
                }

                Button(action: { showPlaylist.toggle() }) {
                    miniPlayerIcon(icon: .list, size: MangaStyle.isActive ? 14 : 15, color: transportControlColor, lineWidth: 1.7)
                        .frame(width: compactControlWidth, height: compactControlHeight)
                        .background(compactControlBackground)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }
        }
        .onTapWithHaptic {
            if player.currentSong != nil {
                openPlayer()
            }
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    // MARK: - 默认黑胶封面

    private var defaultVinylCover: some View {
        ZStack {
            if MinimalWhiteStyle.isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MinimalWhiteStyle.controlGlassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                    )

                MonoIcon(icon: .musicNote, size: 13, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5)
            } else if MangaStyle.isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MangaStyle.paperCool)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.35))

                MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 15)
            } else if PetWhiteStyle.isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PetWhiteStyle.surfaceRaised)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(PetWhiteStyle.stroke, lineWidth: 1))

                MonoIcon(icon: .musicNote, size: 14, color: PetWhiteStyle.inkMuted, lineWidth: 1.6)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(MujiStyle.surfaceRaised)
                    .overlay(MujiPaperTexture(opacity: 0.1).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))

                MonoIcon(icon: .musicNote, size: 13, color: MujiStyle.inkSoft, lineWidth: 1.5)
            } else if BentoStyle.isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(BentoStyle.tomato)
                MonoIcon(icon: .musicNote, size: 14, color: BentoStyle.onAccent, lineWidth: 1.8)
            } else if CapsuleStyle.isActive {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CapsuleStyle.surfaceTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(CapsuleStyle.hairline.opacity(0.72), lineWidth: 0.8)
                    )
                Circle()
                    .stroke(CapsuleStyle.accent.opacity(0.28), lineWidth: 1)
                    .padding(8)
                MonoIcon(icon: .musicNote, size: 13, color: CapsuleStyle.accent, lineWidth: 1.6)
            } else if NeumorphicStyle.isActive {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 11, elevated: false, pressed: true, lightweight: true))

                Circle()
                    .stroke(NeumorphicStyle.accent.opacity(0.32), lineWidth: 1)
                    .padding(8)

                MonoIcon(icon: .musicNote, size: 13, color: NeumorphicStyle.accent, lineWidth: 1.6)
            } else if SequoiaStyle.isActive {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(SequoiaStyle.materialPressed.opacity(0.8))
                    .background(SequoiaSurfaceBackground(cornerRadius: 11, elevated: false, pressed: true, role: .list))

                Circle()
                    .stroke(SequoiaStyle.aqua.opacity(0.24), lineWidth: 0.8)
                    .padding(8)

                MonoIcon(icon: .musicNote, size: 13, color: SequoiaStyle.accent, lineWidth: 1.55)
            } else if LiquidGlassStyle.isActive {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LiquidGlassStyle.glassPressed)
                    .background(LiquidGlassSurfaceBackground(cornerRadius: 11, elevated: false, pressed: true, role: .list))

                Circle()
                    .stroke(LiquidGlassStyle.cyan.opacity(0.26), lineWidth: 0.8)
                    .padding(8)

                MonoIcon(icon: .musicNote, size: 13, color: LiquidGlassStyle.accent, lineWidth: 1.55)
            } else {
                Circle()
                    .fill(Color(hex: "1A1A1A"))

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    .padding(4)
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    .padding(8)

                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .overlay(
                        MonoIcon(icon: .musicNote, size: 8, color: .white.opacity(0.6))
                    )
            }
        }
    }

    // MARK: - Tab 选择器内容

    private var tabSelectorContent: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonoAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    VStack(spacing: 3) {
                        tabSelectorIcon(tab: tab, selected: selected)
                        Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                            .font(tabFont(selected: selected))
                            .foregroundColor(tabForeground(tab, selected: selected))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PetWhiteStyle.isActive ? 4 : (MangaStyle.isActive ? 3 : 5))
                    .background {
                        if ThemedPageStyle.isActive && selected {
                            tabSelectionBackground(tab)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }
        }
    }

    // MARK: - 辅助方法

    @ViewBuilder
    private func tabSelectorIcon(tab: Tab, selected: Bool) -> some View {
        let icon = selected ? tab.icon : tab.monoIcon
        let color = tabForeground(tab, selected: selected)

        if PetWhiteStyle.isActive {
            PetWhitePackIcon(
                icon: icon,
                size: selected ? 16 : 15,
                visualScale: 1,
                fallbackColor: color,
                lineWidth: 1.45,
                artworkContrastBackground: selected ? tabArtworkContrastBackground(tab) : nil
            )
        } else {
            miniPlayerIcon(
                icon: icon,
                size: MangaStyle.isActive ? 16 : 18,
                color: color,
                lineWidth: 1.7,
                artworkContrastBackground: selected ? tabArtworkContrastBackground(tab) : nil
            )
        }
    }

    @ViewBuilder
    private func sourceIndicator(icon: MonoIcon.IconType) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(icon: icon, size: 18, visualScale: 1.04, fallbackColor: sourceIndicatorForeground, lineWidth: 1.6)
        } else {
            MonoIcon(icon: icon, size: 12, color: sourceIndicatorForeground, lineWidth: 1.6)
        }
    }

    private func transportButton(
        icon: MonoIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            miniPlayerIcon(icon: icon, size: MangaStyle.isActive ? 13 : 14, color: transportControlColor, lineWidth: 1.7)
                .frame(width: compactControlWidth, height: compactControlHeight)
                .background(compactControlBackground)
                .contentShape(Rectangle())
        }
        .buttonStyle(MonoBouncingButtonStyle())
        .accessibilityLabel(Text(accessibilityLabel))
    }

    @ViewBuilder
    private func miniPlayerIcon(
        icon: MonoIcon.IconType,
        size: CGFloat,
        color: Color,
        lineWidth: CGFloat,
        artworkContrastBackground: Color? = nil
    ) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(
                icon: icon,
                size: max(size + 6, 18),
                visualScale: 1.05,
                fallbackColor: color,
                lineWidth: lineWidth,
                artworkContrastBackground: artworkContrastBackground
            )
        } else {
            MonoIcon(
                icon: icon,
                size: size,
                color: color,
                lineWidth: lineWidth,
                artworkContrastBackground: artworkContrastBackground
            )
        }
    }

    private func tabArtworkContrastBackground(_ tab: Tab) -> Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.selectedFill }
        if MangaStyle.isActive { return mangaTabTint(tab) }
        if PetWhiteStyle.isActive { return petWhiteTabTint(tab) }
        if BentoStyle.isActive { return bentoTabTint(tab) }
        if CapsuleStyle.isActive { return capsuleTabTint(tab) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.materialRaised }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.glassRaised }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        return Color.monoFloatingBarFill
    }

    private var titleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(13, weight: .semibold) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(13, weight: .black) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(13, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(13.5, weight: .medium) }
        if BentoStyle.isActive { return BentoStyle.bodyFont(13, weight: .heavy) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var subtitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(11, weight: .regular) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(10, weight: .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(11, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .regular) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(11, weight: .regular) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(11, weight: .medium) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        if BentoStyle.isActive { return BentoStyle.labelFont(11, weight: .semibold) }
        return .rounded(size: 11, weight: .medium)
    }

    private var titleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if BentoStyle.isActive { return BentoStyle.ink }
        return .monoTextPrimary
    }

    private var subtitleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkSoft }
        return .monoTextSecondary
    }

    private var controlFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.accent }
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if MujiStyle.isActive { return Color.clear }
        if BentoStyle.isActive { return BentoStyle.tomato }
        return .monoIconBackground
    }

    private var controlForeground: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if MangaStyle.isActive { return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.onAccent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.onAccent }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        if MujiStyle.isActive { return MujiStyle.ink }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        return .monoIconForeground
    }

    private var transportControlColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkSoft }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkSoft }
        return titleColor.opacity(0.72)
    }

    @ViewBuilder
    private var compactControlBackground: some View {
        if MinimalWhiteStyle.isActive {
            MinimalWhiteSurfaceBackground(
                cornerRadius: 10,
                elevated: false,
                tint: MinimalWhiteStyle.controlGlassFill
            )
        } else if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                .fill(MangaStyle.bubbleWhite.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(0.42), lineWidth: 1.1)
                )
        } else if PetWhiteStyle.isActive {
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint,
                strokeColor: PetWhiteStyle.separator.opacity(0.86),
                lineWidth: 1,
                elevated: false
            )
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.6), lineWidth: 0.7)
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BentoStyle.surface.opacity(0.65))
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CapsuleStyle.surfaceTint.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(CapsuleStyle.separator.opacity(0.5), lineWidth: 0.7)
                )
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NeumorphicStyle.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.42), lineWidth: 0.7)
                )
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SequoiaStyle.materialList.opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.7), lineWidth: 0.55)
                )
        } else if LiquidGlassStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LiquidGlassStyle.glassList.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LiquidGlassStyle.luminousEdge.opacity(0.28), lineWidth: 0.55)
                )
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var controlStroke: some View {
        if MinimalWhiteStyle.isActive {
            Circle().stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
        } else if MangaStyle.isActive {
            Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.6)
        } else if PetWhiteStyle.isActive {
            Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1)
        } else if MujiStyle.isActive {
            Circle().stroke(MujiStyle.hairline.opacity(0.78), lineWidth: 0.8)
        } else if BentoStyle.isActive {
            Circle().stroke(BentoStyle.tomato.opacity(0.0), lineWidth: 0)
        } else if NeumorphicStyle.isActive {
            Circle().stroke(NeumorphicStyle.separator.opacity(0.52), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            Circle().stroke(SequoiaStyle.luminousSeparator.opacity(0.5), lineWidth: 0.55)
        } else if LiquidGlassStyle.isActive {
            Circle().stroke(LiquidGlassStyle.luminousEdge.opacity(0.38), lineWidth: 0.55)
        } else if CapsuleStyle.isActive {
            Circle().stroke(CapsuleStyle.hairline.opacity(0.82), lineWidth: 0.75)
        }
    }

    private var sourceIndicatorForeground: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.onStrokeInk }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.onAccent }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        return .white
    }

    private func tabFont(selected: Bool) -> Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(9, weight: selected ? .semibold : .regular) }
        if MangaStyle.isActive { return MangaStyle.labelFont(9, weight: selected ? .black : .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(9, weight: selected ? .black : .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(9, weight: selected ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(9, weight: selected ? .semibold : .medium) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(9, weight: selected ? .semibold : .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(9, weight: selected ? .bold : .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(9, weight: selected ? .semibold : .medium) }
        if BentoStyle.isActive { return BentoStyle.labelFont(9, weight: selected ? .heavy : .semibold) }
        return .system(size: 9, weight: selected ? .semibold : .medium)
    }

    private func tabForeground(_ tab: Tab, selected: Bool) -> Color {
        guard selected else {
            if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
            if MangaStyle.isActive { return MangaStyle.inkMuted }
            if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
            if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
            if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkMuted }
            if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
            if MujiStyle.isActive { return MujiStyle.inkMuted }
            if BentoStyle.isActive { return BentoStyle.inkMuted }
            return .monoTextSecondary.opacity(0.4)
        }

        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if NeumorphicStyle.isActive { return neumorphicTabTint(tab) }
        if SequoiaStyle.isActive { return sequoiaTabTint(tab) }
        if LiquidGlassStyle.isActive { return liquidGlassTabTint(tab) }
        if CapsuleStyle.isActive { return CapsuleStyle.readableLabel(on: capsuleTabTint(tab)) }
        if MujiStyle.isActive { return MujiStyle.ink }
        if BentoStyle.isActive { return bentoTabTint(tab) }
        return .monoAccent
    }

    @ViewBuilder
    private func tabSelectionBackground(_ tab: Tab) -> some View {
        if MinimalWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MinimalWhiteStyle.selectedFill.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
                )
        } else if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(mangaTabTint(tab).opacity(0.86))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.2))
        } else if PetWhiteStyle.isActive {
            PetWhiteDockSelectionBackground(tint: petWhiteTabTint(tab))
                .padding(.horizontal, 3)
        } else if MujiStyle.isActive {
            // Muji：陶土下划短线
            VStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(MujiStyle.clay)
                    .frame(width: 18, height: 1.5)
            }
            .padding(.bottom, 2)
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bentoTabTint(tab))
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(capsuleTabTint(tab))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.72), lineWidth: 0.75)
                )
                .shadow(color: capsuleTabTint(tab).opacity(0.14), radius: 8, x: 0, y: 4)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(neumorphicTabTint(tab).opacity(0.16))
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true))
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(sequoiaTabTint(tab).opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(sequoiaTabTint(tab).opacity(0.2), lineWidth: 0.55))
        } else if LiquidGlassStyle.isActive {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(liquidGlassTabTint(tab).opacity(0.15))
                .background(LiquidGlassSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, fill: liquidGlassTabTint(tab).opacity(0.08), role: .selected))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(liquidGlassTabTint(tab).opacity(0.2), lineWidth: 0.55))
        }
    }

    private func mangaTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return MangaStyle.labelYellow
        case .podcast: return MangaStyle.bubbleBlue
        case .library: return MangaStyle.mint
        case .profile: return MangaStyle.bubblePink
        }
    }

    private func petWhiteTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return PetWhiteStyle.dogOrange
        case .podcast: return PetWhiteStyle.mint
        case .library: return PetWhiteStyle.butter
        case .profile: return PetWhiteStyle.blush
        }
    }

    private func bentoTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return BentoStyle.tomato
        case .podcast: return BentoStyle.nori
        case .library: return BentoStyle.matcha
        case .profile: return BentoStyle.mustard
        }
    }

    private func capsuleTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return CapsuleStyle.accent
        case .podcast: return CapsuleStyle.mint
        case .library: return CapsuleStyle.amber
        case .profile: return CapsuleStyle.violet
        }
    }

    private func neumorphicTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return NeumorphicStyle.accent
        case .podcast: return NeumorphicStyle.warm
        case .library: return NeumorphicStyle.sage
        case .profile: return NeumorphicStyle.red
        }
    }

    private func sequoiaTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return SequoiaStyle.accent
        case .podcast: return SequoiaStyle.aqua
        case .library: return SequoiaStyle.green
        case .profile: return SequoiaStyle.violet
        }
    }

    private func liquidGlassTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return LiquidGlassStyle.accent
        case .podcast: return LiquidGlassStyle.violet
        case .library: return LiquidGlassStyle.mint
        case .profile: return LiquidGlassStyle.pink
        }
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

/// 环绕封面的播放进度环（aside 极简模式）
private struct AsideMiniProgressRing: View {
    @Environment(\.floatingBarColorRevision) private var colorRevision
    let size: CGFloat
    let lineWidth: CGFloat

    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    private var progress: CGFloat {
        guard timePublisher.duration > 0 else { return 0 }
        return CGFloat(min(max(timePublisher.currentTime / timePublisher.duration, 0), 1))
    }

    var body: some View {
        let _ = colorRevision

        ZStack {
            Circle()
                .stroke(Color.monoTextPrimary.opacity(0.09), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.monoAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
        }
        .frame(width: size, height: size)
    }
}

private struct PetWhiteMinimalBowPlayer: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @State private var showTabs = false
    @State private var showPlaylist = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                HapticManager.shared.light()
                withAnimation(MonoAnimation.panelToggle) {
                    showTabs.toggle()
                }
            } label: {
                petWhiteCoverToggle
                    .swipeToSkip()
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

            if showTabs || player.currentSong == nil {
                tabBowSegment
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            } else {
                nowPlayingBowSegment
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background {
            PetWhiteFrostedFloatingSurface(
                shape: Capsule(style: .continuous),
                tint: PetWhiteStyle.paper,
                accent: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                lineWidth: 1.7
            )
        }
        .overlay(alignment: .top) {
            PetWhiteFloatingBowTie()
                .offset(y: -9)
        }
        .contentShape(Capsule(style: .continuous))
        .simultaneousGesture(panelSwitchGesture)
        .animation(MonoAnimation.panelToggle, value: showTabs)
        .animation(MonoAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private var petWhiteCoverToggle: some View {
        PetWhiteSpinningCoverDisc(
            coverURL: player.currentSong?.coverUrl,
            size: 42,
            isPlaying: player.isPlaying,
            strokeWidth: 1.5
        )
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(showTabs ? PetWhiteStyle.mint : PetWhiteStyle.butter)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                .offset(x: 1, y: 1)
        }
    }

    private var nowPlayingBowSegment: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                MarqueeText(
                    text: player.currentSong?.name ?? NSLocalizedString("not_playing", comment: String(localized: "not_playing")),
                    font: PetWhiteStyle.bodyFont(13, weight: .black),
                    color: PetWhiteStyle.ink,
                    speed: 25
                )
                .frame(height: 16)

                FloatingBarLyricReader { lineText in
                    MarqueeText(
                        text: subtitleText(for: lineText),
                        font: PetWhiteStyle.bodyFont(11, weight: .semibold),
                        color: PetWhiteStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 13)
                }
            }
            .frame(minWidth: 88, maxWidth: .infinity, alignment: .leading)
            .swipeSkipTextMotion()
            .onTapWithHaptic { openPlayer() }

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: PetWhiteStyle.onAccent))
                            .scaleEffect(0.55)
                    } else {
                        PetWhitePackIcon(icon: player.isPlaying ? .pause : .play, size: 21, visualScale: 1.08)
                    }
                }
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

            Button(action: { showPlaylist.toggle() }) {
                PetWhitePackIcon(icon: .list, size: 21, visualScale: 1.04, fallbackColor: PetWhiteStyle.ink)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .frame(maxWidth: DeviceLayout.usesExpandedLayout ? 440 : 320)
        .overlay(alignment: .bottomLeading) {
            ProgressBarView(height: 4, minFillWidth: 7)
                .frame(height: 4)
                .padding(.trailing, 76)
                .offset(y: 5)
        }
    }

    private var tabBowSegment: some View {
        HStack(spacing: 7) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonoAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    VStack(spacing: 2) {
                        PetWhitePackIcon(
                            icon: selected ? tab.icon : tab.monoIcon,
                            size: selected ? 18 : 16,
                            visualScale: 1,
                            fallbackColor: selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted,
                            lineWidth: 1.45,
                            artworkContrastBackground: selected ? tabTint(tab) : nil
                        )

                        if selected {
                            Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                                .font(PetWhiteStyle.labelFont(9, weight: .black))
                                .foregroundColor(PetWhiteStyle.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .frame(width: selected ? 66 : 42, height: 42)
                    .background {
                        if selected {
                            PetWhiteClayPuck(
                                shape: Capsule(style: .continuous),
                                tint: tabTint(tab),
                                pressedLook: true
                            )
                        }
                    }
                }
                .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.9))
            }
        }
    }

    private func subtitleText(for lineText: String?) -> String {
        if let text = lineText {
            return text
        }
        return player.currentSong?.artistName ?? NSLocalizedString("select_song_to_play", comment: String(localized: "选择歌曲开始播放"))
    }

    private var panelSwitchGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                guard player.currentSong != nil else { return }
                guard showTabs else { return }

                withAnimation(MonoAnimation.panelToggle) {
                    showTabs = value.translation.width <= 0
                }
            }
    }

    private func openPlayer() {
        guard player.currentSong != nil else { return }

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

    private func tabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return PetWhiteStyle.dogOrange
        case .podcast: return PetWhiteStyle.mint
        case .library: return PetWhiteStyle.butter
        case .profile: return PetWhiteStyle.blush.opacity(0.88)
        }
    }
}
