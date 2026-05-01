import SwiftUI

/// 经典风格的统一悬浮栏（MiniPlayer + TabBar 合一，贴底不悬浮）
struct ClassicFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var dividerColor: Color {
        if settings.globalThemeId == .manga { return MangaStyle.strokeInk.opacity(0.82) }
        if settings.globalThemeId == .muji { return MujiStyle.separator.opacity(0.82) }
        if settings.globalThemeId == .neumorphic { return NeumorphicStyle.separator.opacity(0.68) }
        if settings.globalThemeId == .sequoia { return SequoiaStyle.separator.opacity(0.92) }
        if settings.globalThemeId == .material { return MaterialStyle.outline.opacity(0.9) }
        if settings.globalThemeId == .clay { return ClayStyle.separator.opacity(0.72) }
        if settings.globalThemeId == .signal { return SignalStyle.separator.opacity(0.84) }
        return Color.monologueSeparator.opacity(0.3)
    }

    private var dividerHeight: CGFloat {
        if settings.globalThemeId == .sequoia { return 0.6 }
        if settings.globalThemeId == .material { return 0.75 }
        return settings.globalThemeId == .manga ? 1.4 : ((settings.globalThemeId == .neumorphic || settings.globalThemeId == .clay || settings.globalThemeId == .signal) ? 0.8 : 0.5)
    }

    private var bottomSink: CGFloat {
        DeviceLayout.isPad ? 3 : 4
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // MiniPlayer 部分
                if let song = player.currentSong {
                    ClassicMiniPlayerSection(
                        song: song,
                        isPlaying: player.isPlaying,
                        togglePlayPause: { player.togglePlayPause() }
                    )
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))

                    // 分隔线 - 更柔和
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: dividerHeight)
                        .padding(.horizontal, DeviceLayout.isPad ? 24 : 16)
                }

                // TabBar 部分
                ClassicTabBarSection(currentTab: $currentTab)
            }
            .id(settings.globalThemeId)
            .background {
                barBackground
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: dividerHeight)

                    if settings.globalThemeId == .sequoia {
                        Capsule()
                            .fill(SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.2 : 0.68))
                            .frame(width: 52, height: 3)
                            .offset(y: 6)
                    }
                }
            }
            .offset(y: bottomSink)
            .padding(.bottom, -bottomSink)
            .themeRenderInteractiveLayer()
        }
        .padding(.bottom, 0)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    @ViewBuilder
    private var barBackground: some View {
        if settings.globalThemeId == .manga {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(MangaStyle.strokeInk)
                    .offset(y: -4)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [MangaStyle.bubbleWhite, MangaStyle.paperWarm.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(MangaDotsTexture(opacity: 0.028, gap: 12))

                HStack(spacing: 0) {
                    MangaStyle.labelYellow.frame(width: 90)
                    MangaStyle.accentPink.frame(width: 48)
                    MangaStyle.decoBlue.frame(width: 58)
                    Spacer()
                    MangaStyle.mint.frame(width: 70)
                }
                .frame(height: 7)

                Rectangle()
                    .fill(MangaStyle.strokeInk)
                    .frame(height: 2.4)
                    .offset(y: 7)

                HStack {
                    MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow, size: 17)
                    Spacer()
                    MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 17)
                }
                .padding(.horizontal, 24)
                .offset(y: -8)
            }
            .shadow(color: MangaStyle.strokeInk.opacity(0.16), radius: 0, x: 0, y: -4)
        } else if settings.globalThemeId == .muji {
            Rectangle()
                .fill(MujiStyle.surfaceRaised)
                .overlay(MujiPaperTexture(opacity: 0.08))
        } else if settings.globalThemeId == .neumorphic {
            Rectangle()
                .fill(NeumorphicStyle.surface)
                .overlay(NeumorphicReliefTexture(opacity: 0.045))
        } else if settings.globalThemeId == .sequoia {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)

                Rectangle()
                    .fill(SequoiaStyle.materialFloating.opacity(colorScheme == .dark ? 0.9 : 0.78))

                LinearGradient(
                    colors: [
                        SequoiaStyle.highlight(colorScheme).opacity(colorScheme == .dark ? 0.08 : 0.42),
                        .clear,
                        SequoiaStyle.accent.opacity(colorScheme == .dark ? 0.055 : 0.035),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.16 : 0.52))
                    .frame(height: 0.65)
            }
            .shadow(color: SequoiaStyle.shadow(colorScheme, elevated: true), radius: 16, x: 0, y: -6)
        } else if settings.globalThemeId == .material {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(MaterialStyle.surfaceContainerHigh.opacity(colorScheme == .dark ? 0.94 : 0.98))

                LinearGradient(
                    colors: [
                        MaterialStyle.primary.opacity(colorScheme == .dark ? 0.12 : 0.07),
                        .clear,
                        MaterialStyle.tertiary.opacity(colorScheme == .dark ? 0.08 : 0.055),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(MaterialStyle.primary.opacity(0.42))
                    .frame(height: 3)
            }
            .shadow(color: MaterialStyle.elevationShadow(colorScheme, level: 2), radius: 14, x: 0, y: -5)
        } else if settings.globalThemeId == .clay {
            Rectangle()
                .fill(ClayStyle.cream)
                .overlay(alignment: .top) {
                    HStack(spacing: 0) {
                        ClayStyle.accent.opacity(0.72).frame(width: 64, height: 4)
                        ClayStyle.butter.opacity(0.8).frame(width: 52, height: 4)
                        ClayStyle.mint.opacity(0.76).frame(width: 58, height: 4)
                        Spacer()
                        ClayStyle.sky.opacity(0.7).frame(width: 70, height: 4)
                    }
                }
        } else if settings.globalThemeId == .signal {
            Rectangle()
                .fill(SignalStyle.device)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(SignalStyle.accent)
                        .frame(height: 3)
                }
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.74))

                Rectangle()
                    .fill(Color.monologueFloatingBarFill.opacity(colorScheme == .dark ? 0.78 : 0.48))
            }
        }
    }
}

// MARK: - 经典 MiniPlayer 部分

private struct ClassicMiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var lyricVM = LyricViewModel.shared

    private var subtitleText: String {
        if !player.isPlayingPodcast, lyricVM.hasLyrics, let text = lyricVM.currentLineText {
            return text
        }
        return song.artistName
    }

    private var coverCornerRadius: CGFloat {
        MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 6 : (NeumorphicStyle.isActive ? 9 : (SequoiaStyle.isActive ? 11 : 8)))
    }

    private var coverSize: CGFloat {
        SequoiaStyle.isActive ? 42 : 38
    }

    private var playControlSize: CGFloat {
        SequoiaStyle.isActive ? 36 : 34
    }

    private var sectionHorizontalPadding: CGFloat {
        SequoiaStyle.isActive ? (DeviceLayout.isPad ? 26 : 18) : (DeviceLayout.isPad ? 24 : 16)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl, width: coverSize, height: coverSize) {
                    RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                        .fill(coverPlaceholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: coverSize, height: coverSize)
                .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
                .overlay(coverStroke)
                .overlay {
                    if player.playSource == .fm {
                        sourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        sourceIndicator(icon: .radio)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: song.name,
                        font: titleFont,
                        color: titleColor,
                        speed: 25,
                        alignment: .leading
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
                HStack(spacing: 12) {
                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(controlFill)
                                .frame(width: playControlSize, height: playControlSize)
                                .overlay(controlStroke)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: controlForeground))
                                    .scaleEffect(0.55)
                            } else {
                                MonologueIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 14,
                                    color: controlForeground
                                )
                            }
                        }
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 16, color: titleColor.opacity(0.72))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 10, color: subtitleColor)
                                .frame(width: 28, height: 28)
                                .background(closeFill)
                                .clipShape(Circle())
                                .overlay(closeStroke)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .padding(.horizontal, sectionHorizontalPadding)
            .padding(.top, SequoiaStyle.isActive ? 11 : 10)
            .padding(.bottom, SequoiaStyle.isActive ? 8 : 7)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
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

            ProgressBarView()
                .frame(height: 2.5)
                .padding(.horizontal, DeviceLayout.isPad ? 32 : 24)
                .padding(.bottom, 5)
                .opacity(0.6)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 12, color: sourceIndicatorForeground, lineWidth: 1.6)
    }

    private var titleFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        if ClayStyle.isActive { return ClayStyle.labelFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .semibold) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var subtitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(11, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .regular) }
        if ClayStyle.isActive { return ClayStyle.labelFont(11, weight: .medium) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        return .rounded(size: 11, weight: .medium)
    }

    private var titleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if ClayStyle.isActive { return ClayStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        return .monologueTextPrimary
    }

    private var subtitleColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if ClayStyle.isActive { return ClayStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var coverPlaceholderFill: Color {
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.84) }
        if ClayStyle.isActive { return ClayStyle.creamPressed }
        if MujiStyle.isActive { return MujiStyle.paperWarm.opacity(0.74) }
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
        } else if ClayStyle.isActive {
            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                .stroke(ClayStyle.separator.opacity(0.5), lineWidth: 0.7)
        }
    }

    private var controlFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if ClayStyle.isActive { return ClayStyle.butter.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.paperWarm.opacity(0.76) }
        return .monologueIconBackground
    }

    private var controlForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if ClayStyle.isActive { return ClayStyle.accent }
        if MujiStyle.isActive { return MujiStyle.ink }
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
        } else if ClayStyle.isActive {
            Circle().stroke(ClayStyle.separator.opacity(0.42), lineWidth: 0.7)
        }
    }

    private var closeFill: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.12) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.72) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.84) }
        if ClayStyle.isActive { return ClayStyle.creamPressed.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.ink.opacity(0.06) }
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
        } else if ClayStyle.isActive {
            Circle().stroke(ClayStyle.separator.opacity(0.38), lineWidth: 0.7)
        }
    }

    private var sourceIndicatorForeground: Color {
        if MangaStyle.isActive { return MangaStyle.onStrokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if ClayStyle.isActive { return ClayStyle.ink }
        if MujiStyle.isActive { return MujiStyle.onTint }
        return .white
    }
}

// MARK: - Classic Tab Icon Animation Values

private struct ClassicTabAnimValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0.0
    var offsetY: CGFloat = 0.0
}

// MARK: - 经典 TabBar 部分（带 outline/filled 切换 + 微动画）

private struct ClassicTabBarSection: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @State private var animTrigger: Int = -1

    private static let tabIcons: [(outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< Self.tabIcons.count, id: \.self) { index in
                let tab = Tab.allCases[index]
                let isSelected = currentTab == tab
                let icons = Self.tabIcons[index]
                let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

                Button {
                    HapticManager.shared.light()
                    animTrigger = index
                    withAnimation(MonologueAnimation.micro) {
                        currentTab = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        KeyframeAnimator(initialValue: ClassicTabAnimValues(), trigger: animTrigger == index ? animTrigger : -1) { values in
                            MonologueIcon(
                                icon: isSelected ? icons.filled : icons.outline,
                                size: 20,
                                color: tabForeground(index, isSelected: isSelected)
                            )
                            .contentTransition(.interpolate)
                            .scaleEffect(values.scale)
                            .rotationEffect(.degrees(values.rotation))
                            .offset(y: values.offsetY)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                SpringKeyframe(1.25, duration: 0.15, spring: .bouncy)
                                SpringKeyframe(0.9, duration: 0.1, spring: .bouncy)
                                SpringKeyframe(1.0, duration: 0.15, spring: .smooth)
                            }
                            KeyframeTrack(\.rotation) {
                                SpringKeyframe(-8, duration: 0.1, spring: .snappy)
                                SpringKeyframe(5, duration: 0.1, spring: .snappy)
                                SpringKeyframe(0, duration: 0.12, spring: .smooth)
                            }
                            KeyframeTrack(\.offsetY) {
                                SpringKeyframe(-3, duration: 0.12, spring: .bouncy)
                                SpringKeyframe(0, duration: 0.12, spring: .smooth)
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)

                        Text(label)
                            .font(tabFont(isSelected: isSelected))
                            .foregroundColor(tabForeground(index, isSelected: isSelected))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
                    .padding(.vertical, 6)
                    .background {
                        if ThemedPageStyle.isActive && isSelected {
                            tabSelectionBackground(index)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private func tabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive {
            return MangaStyle.labelFont(10, weight: isSelected ? .black : .bold)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(10, weight: isSelected ? .semibold : .medium)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(10, weight: isSelected ? .semibold : .medium)
        }
        if ClayStyle.isActive {
            return ClayStyle.labelFont(10, weight: isSelected ? .bold : .semibold)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(10, weight: isSelected ? .semibold : .medium)
        }
        return .system(size: 10, weight: isSelected ? .semibold : .medium)
    }

    private func tabForeground(_ index: Int, isSelected: Bool) -> Color {
        guard isSelected else {
            if MangaStyle.isActive { return MangaStyle.inkMuted }
            if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
            if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
            if ClayStyle.isActive { return ClayStyle.inkMuted }
            if MujiStyle.isActive { return MujiStyle.inkMuted }
            return .monologueTextPrimary.opacity(0.35)
        }

        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return neumorphicTabTint(index) }
        if SequoiaStyle.isActive { return sequoiaTabTint(index) }
        if ClayStyle.isActive { return clayTabTint(index) }
        if MujiStyle.isActive { return mujiTabTint(index) }
        return .monologueTextPrimary
    }

    @ViewBuilder
    private func tabSelectionBackground(_ index: Int) -> some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(mangaTabTint(index).opacity(0.86))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.4))
                .padding(.horizontal, 4)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.32), lineWidth: 0.6))
                .padding(.horizontal, 5)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NeumorphicStyle.accent.opacity(0.12))
                .background(NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true).padding(.horizontal, 4))
                .padding(.horizontal, 5)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(sequoiaTabTint(index).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(sequoiaTabTint(index).opacity(0.2), lineWidth: 0.55)
                )
                .background(
                    SequoiaSurfaceBackground(
                        cornerRadius: 15,
                        elevated: false,
                        fill: sequoiaTabTint(index).opacity(0.08),
                        role: .selected
                    )
                    .padding(.horizontal, 4)
                )
                .padding(.horizontal, 5)
        } else if ClayStyle.isActive {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(clayTabTint(index).opacity(0.22))
                .background(ClaySurfaceBackground(cornerRadius: 14, tint: clayTabTint(index).opacity(0.12), elevated: false, pressed: true, compact: true).padding(.horizontal, 4))
                .padding(.horizontal, 5)
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

    private func clayTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return ClayStyle.accent
        case 1: return ClayStyle.mint
        case 2: return ClayStyle.sky
        default: return ClayStyle.grape
        }
    }
}
