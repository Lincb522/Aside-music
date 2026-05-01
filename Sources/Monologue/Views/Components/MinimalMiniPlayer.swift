import SwiftUI

/// 极简模式的 MiniPlayer（同一容器内左滑显示 Tab，右滑回播放器）
struct MinimalMiniPlayer: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPlaylist = false

    @State private var showingTabs = false

    private var shellCornerRadius: CGFloat {
        if MangaStyle.isActive { return 20 }
        if NeumorphicStyle.isActive { return 22 }
        if SequoiaStyle.isActive { return 24 }
        if MaterialStyle.isActive { return 24 }
        if MujiStyle.isActive { return 16 }
        return 18
    }

    private var shellHorizontalPadding: CGFloat {
        if MangaStyle.isActive { return DeviceLayout.isPad ? 16 : 10 }
        if SequoiaStyle.isActive { return DeviceLayout.isPad ? 20 : 12 }
        if MaterialStyle.isActive { return DeviceLayout.isPad ? 20 : 12 }
        return DeviceLayout.isPad ? 20 : 14
    }

    private var shellVerticalPadding: CGFloat {
        if MangaStyle.isActive { return 7 }
        if SequoiaStyle.isActive { return 9 }
        if MaterialStyle.isActive { return 9 }
        return 10
    }

    private var miniContentSpacing: CGFloat {
        MangaStyle.isActive ? 8 : 10
    }

    private var artworkSize: CGFloat {
        MangaStyle.isActive ? 34 : (SequoiaStyle.isActive ? 38 : 40)
    }

    private var artworkCornerRadius: CGFloat {
        MangaStyle.isActive ? 8 : (SequoiaStyle.isActive ? 11 : 10)
    }

    private var transportSpacing: CGFloat {
        MangaStyle.isActive ? 5 : 6
    }

    private var compactControlWidth: CGFloat {
        MangaStyle.isActive ? 27 : 30
    }

    private var compactControlHeight: CGFloat {
        MangaStyle.isActive ? 30 : 34
    }

    private var playButtonSize: CGFloat {
        MangaStyle.isActive ? 30 : 34
    }

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return player.currentSong?.artistName ?? NSLocalizedString("select_song_to_play", comment: String(localized: "选择歌曲开始播放"))
    }

    var body: some View {
        let _ = settings.globalThemeRevision

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
        .monologueGlass(cornerRadius: shellCornerRadius)
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
                            .animation(MonologueAnimation.micro, value: showingTabs)
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
            } else if MaterialStyle.isActive {
                RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                    .stroke(MaterialStyle.outlineStrong.opacity(0.45), lineWidth: 0.8)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 4) {
                            Circle().fill(MaterialStyle.primary).frame(width: 6, height: 6)
                            Circle().fill(MaterialStyle.tertiary.opacity(0.7)).frame(width: 6, height: 6)
                        }
                        .padding(.leading, 17)
                        .padding(.top, 7)
                    }
            }
        }
        .shadow(
            color: SequoiaStyle.isActive
                ? SequoiaStyle.shadow(colorScheme, elevated: true)
                : (MaterialStyle.isActive ? MaterialStyle.elevationShadow(colorScheme, level: 2) : .clear),
            radius: SequoiaStyle.isActive ? 17 : (MaterialStyle.isActive ? 16 : 0),
            x: 0,
            y: SequoiaStyle.isActive ? 8 : (MaterialStyle.isActive ? 7 : 0)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(panelSwitchGesture)
        .animation(MonologueAnimation.panelToggle, value: showingTabs)
        .themeRenderInteractiveLayer()
    }

    @ViewBuilder
    private var shellBackground: some View {
        if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: shellCornerRadius, elevated: true, role: .floating)
        } else if MaterialStyle.isActive {
            MaterialSurfaceBackground(cornerRadius: shellCornerRadius, elevated: true, role: .floating)
        } else {
            RoundedRectangle(cornerRadius: shellCornerRadius, style: .continuous)
                .fill(ThemedPageStyle.isActive ? Color.clear : Color.monologueFloatingBarFill)
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
                    withAnimation(MonologueAnimation.panelToggle) {
                        showingTabs = true
                    }
                    return
                }

                guard value.translation.width > threshold else { return }
                withAnimation(MonologueAnimation.panelToggle) {
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
                    text: player.currentSong?.name ?? NSLocalizedString("not_playing", comment: String(localized: "未在播放")),
                    font: titleFont,
                    color: titleColor,
                    speed: 25
                )
                .frame(height: 16)

                Text(subtitleText)
                    .font(subtitleFont)
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.25), value: lyricVM.currentLineIndex)
            }

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
                        } else {
                            MonologueIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: MangaStyle.isActive ? 13 : 14,
                                color: controlForeground
                            )
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                transportButton(icon: .next, accessibilityLabel: NSLocalizedString("playback_next_track", comment: "")) {
                    player.next()
                }

                Button(action: { showPlaylist.toggle() }) {
                    MonologueIcon(icon: .list, size: MangaStyle.isActive ? 14 : 15, color: transportControlColor, lineWidth: 1.7)
                        .frame(width: compactControlWidth, height: compactControlHeight)
                        .background(compactControlBackground)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
        .onTapWithHaptic {
            if player.currentSong != nil {
                openPlayer()
            }
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
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
            if MangaStyle.isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MangaStyle.paperCool)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.35))

                MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 15, foreground: MangaStyle.strokeInk)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(MujiStyle.paperWarm)
                    .overlay(MujiPaperTexture(opacity: 0.1).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))

                MonologueIcon(icon: .musicNote, size: 13, color: MujiStyle.inkSoft, lineWidth: 1.5)
            } else if NeumorphicStyle.isActive {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 11, elevated: false, pressed: true, lightweight: true))

                Circle()
                    .stroke(NeumorphicStyle.accent.opacity(0.32), lineWidth: 1)
                    .padding(8)

                MonologueIcon(icon: .musicNote, size: 13, color: NeumorphicStyle.accent, lineWidth: 1.6)
            } else if SequoiaStyle.isActive {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(SequoiaStyle.materialPressed.opacity(0.8))
                    .background(SequoiaSurfaceBackground(cornerRadius: 11, elevated: false, pressed: true, role: .list))

                Circle()
                    .stroke(SequoiaStyle.aqua.opacity(0.24), lineWidth: 0.8)
                    .padding(8)

                MonologueIcon(icon: .musicNote, size: 13, color: SequoiaStyle.accent, lineWidth: 1.55)
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
                        MonologueIcon(icon: .musicNote, size: 8, color: .white.opacity(0.6))
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
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        MonologueIcon(
                            icon: tab.monologueIcon,
                            size: MangaStyle.isActive ? 16 : 18,
                            color: tabForeground(tab, selected: currentTab == tab)
                        )
                        Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                            .font(tabFont(selected: currentTab == tab))
                            .foregroundColor(tabForeground(tab, selected: currentTab == tab))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MangaStyle.isActive ? 3 : 5)
                    .background {
                        if ThemedPageStyle.isActive && currentTab == tab {
                            tabSelectionBackground(tab)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }

    // MARK: - 辅助方法

    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 12, color: sourceIndicatorForeground, lineWidth: 1.6)
    }

    private func transportButton(
        icon: MonologueIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            MonologueIcon(icon: icon, size: MangaStyle.isActive ? 13 : 14, color: transportControlColor, lineWidth: 1.7)
                .frame(width: compactControlWidth, height: compactControlHeight)
                .background(compactControlBackground)
                .contentShape(Rectangle())
        }
        .buttonStyle(MonologueBouncingButtonStyle())
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var titleFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .semibold) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var subtitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(10, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .regular) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        return .rounded(size: 11, weight: .medium)
    }

    private var titleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        return .monologueTextPrimary
    }

    private var subtitleColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var controlFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MujiStyle.isActive { return MujiStyle.paperWarm.opacity(0.78) }
        return .monologueIconBackground
    }

    private var controlForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if MujiStyle.isActive { return MujiStyle.ink }
        return .monologueIconForeground
    }

    private var transportControlColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        return titleColor.opacity(0.72)
    }

    @ViewBuilder
    private var compactControlBackground: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(MangaStyle.bubbleWhite.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(0.42), lineWidth: 1.1)
                )
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.54))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.28), lineWidth: 0.6)
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
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var controlStroke: some View {
        if MangaStyle.isActive {
            Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.6)
        } else if MujiStyle.isActive {
            Circle().stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            Circle().stroke(NeumorphicStyle.separator.opacity(0.52), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            Circle().stroke(SequoiaStyle.luminousSeparator.opacity(0.5), lineWidth: 0.55)
        }
    }

    private var sourceIndicatorForeground: Color {
        if MangaStyle.isActive { return MangaStyle.onStrokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if MujiStyle.isActive { return MujiStyle.onTint }
        return .white
    }

    private func tabFont(selected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(9, weight: selected ? .black : .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(9, weight: selected ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(9, weight: selected ? .semibold : .medium) }
        if MujiStyle.isActive { return MujiStyle.labelFont(9, weight: selected ? .semibold : .medium) }
        return .system(size: 9, weight: selected ? .semibold : .medium)
    }

    private func tabForeground(_ tab: Tab, selected: Bool) -> Color {
        guard selected else {
            if MangaStyle.isActive { return MangaStyle.inkMuted }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
            if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
            if MujiStyle.isActive { return MujiStyle.inkMuted }
            return .monologueTextSecondary.opacity(0.4)
        }

        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return neumorphicTabTint(tab) }
        if SequoiaStyle.isActive { return sequoiaTabTint(tab) }
        if MujiStyle.isActive { return mujiTabTint(tab) }
        return .monologueAccent
    }

    @ViewBuilder
    private func tabSelectionBackground(_ tab: Tab) -> some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(mangaTabTint(tab).opacity(0.86))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.2))
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.74))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.34), lineWidth: 0.6))
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(neumorphicTabTint(tab).opacity(0.16))
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true))
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(sequoiaTabTint(tab).opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(sequoiaTabTint(tab).opacity(0.2), lineWidth: 0.55))
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

    private func mujiTabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return MujiStyle.clay
        case .podcast: return MujiStyle.tea
        case .library: return MujiStyle.indigo
        case .profile: return MujiStyle.straw
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
