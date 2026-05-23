import SwiftUI

// MARK: - Subviews for Performance

struct MiniPlayerSection: View {
    let song: Song
    let isPlaying: Bool
    let togglePlayPause: () -> Void
    @State private var showPlaylist = false
    @ObservedObject var player = FloatingBarPlaybackModel.shared

    private var subtitleText: String {
        if let text = player.lyricLineText {
            return text
        }
        return song.artistName
    }

    private var primaryTextColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        return Color.monologueTextPrimary
    }

    private var secondaryTextColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        return Color.monologueTextSecondary
    }

    private var controlFillColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.accent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash }
        return Color.monologueIconBackground
    }

    private var controlForegroundColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.onAccent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.onAccent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        return Color.monologueIconForeground
    }

    private var titleFont: Font {
        if MangaStyle.isActive {
            return MangaStyle.bodyFont(13, weight: .bold)
        }
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.bodyFont(13, weight: .black)
        }
        if PureWhiteStyle.isActive {
            return PureWhiteStyle.bodyFont(13, weight: .black)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(13, weight: .semibold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(13, weight: .semibold)
        }
        if LiquidGlassStyle.isActive {
            return LiquidGlassStyle.labelFont(13, weight: .semibold)
        }
        return MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var subtitleFont: Font {
        if MangaStyle.isActive {
            return MangaStyle.bodyFont(11, weight: .medium)
        }
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.bodyFont(11, weight: .semibold)
        }
        if PureWhiteStyle.isActive {
            return PureWhiteStyle.bodyFont(11, weight: .semibold)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(11, weight: .regular)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(11, weight: .regular)
        }
        if LiquidGlassStyle.isActive {
            return LiquidGlassStyle.labelFont(11, weight: .regular)
        }
        return MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .rounded(size: 11, weight: .medium)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: (PetWhiteStyle.isActive || PureWhiteStyle.isActive) ? 10 : (LiquidGlassStyle.isActive ? 12 : (MujiStyle.isActive ? 5 : 8)), style: .continuous))
                .overlay {
                    if PetWhiteStyle.isActive {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PetWhiteStyle.stroke, lineWidth: 1.6)
                    } else if PureWhiteStyle.isActive {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PureWhiteStyle.strokeInk, lineWidth: 1.4)
                    } else if MujiStyle.isActive {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
                    } else if LiquidGlassStyle.isActive {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.34), lineWidth: 0.6)
                    }
                }
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
                        color: primaryTextColor,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: subtitleFont,
                        color: secondaryTextColor,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                // 控制按钮
                HStack(spacing: 10) {
                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(controlFillColor)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if PetWhiteStyle.isActive {
                                        Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.6)
                                    } else if PureWhiteStyle.isActive {
                                        Circle().stroke(PureWhiteStyle.strokeInk, lineWidth: 1.4)
                                    } else if MujiStyle.isActive {
                                        Circle().stroke(MujiStyle.hairline.opacity(0.32), lineWidth: 0.6)
                                    } else if NeumorphicStyle.isActive {
                                        Circle().stroke(NeumorphicStyle.lightShadow(.light, intensity: 0.4), lineWidth: 0.7)
                                    }
                                }

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: controlForegroundColor))
                                    .scaleEffect(0.6)
                            } else if PetWhiteStyle.isActive {
                                PetWhitePackIcon(icon: isPlaying ? .pause : .play, size: 22, visualScale: 1.08)
                            } else {
                                MonologueIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 14,
                                    color: controlForegroundColor
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        miniControlIcon(icon: .list, size: 16, color: primaryTextColor.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            miniControlIcon(icon: .close, size: 10, color: secondaryTextColor)
                                .frame(width: 28, height: 28)
                                .background(primaryTextColor.opacity(0.08))
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
            .padding(.top, 10)
            .padding(.bottom, 6)
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
                .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
                .padding(.bottom, 4)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    /// 播放来源角标
    @ViewBuilder
    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(icon: icon, size: 18, visualScale: 1.06, fallbackColor: .white, lineWidth: 1.6)
        } else {
            MonologueIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
        }
    }

    @ViewBuilder
    private func miniControlIcon(icon: MonologueIcon.IconType, size: CGFloat, color: Color) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(icon: icon, size: max(size + 7, 18), visualScale: 1.06, fallbackColor: color)
        } else {
            MonologueIcon(icon: icon, size: size, color: color)
        }
    }
}

struct ProgressBarView: View {
    var height: CGFloat = 3
    var minFillWidth: CGFloat = 5

    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    var body: some View {
        GlobalPlaybackProgressBar(
            progress: CGFloat(timePublisher.progress),
            height: height,
            minFillWidth: minFillWidth,
            trackColor: trackColor,
            strokeColor: strokeColor,
            fillColors: progressFillColors
        )
    }

    private var trackColor: Color {
        if MangaStyle.isActive {
            return MangaStyle.separator.opacity(0.6)
        } else if PetWhiteStyle.isActive {
            return PetWhiteStyle.stroke.opacity(0.16)
        } else if PureWhiteStyle.isActive {
            return PureWhiteStyle.separator.opacity(0.7)
        } else if MujiStyle.isActive {
            return MujiStyle.separator.opacity(0.55)
        } else if NeumorphicStyle.isActive {
            return NeumorphicStyle.surfacePressed.opacity(0.9)
        } else if SequoiaStyle.isActive {
            return SequoiaStyle.separator.opacity(0.58)
        } else if LiquidGlassStyle.isActive {
            return LiquidGlassStyle.separator.opacity(0.72)
        } else if SignalStyle.isActive {
            return SignalStyle.separator.opacity(0.52)
        } else if CapsuleStyle.isActive {
            return CapsuleStyle.separator.opacity(0.58)
        }
        return Color.monologueTextPrimary.opacity(0.06)
    }

    private var strokeColor: Color? {
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.surfaceRaised.opacity(0.78)
        }
        return nil
    }

    private var progressFillColors: [Color] {
        if MangaStyle.isActive {
            return [MangaStyle.accentPink, MangaStyle.labelYellow]
        } else if PetWhiteStyle.isActive {
            return [PetWhiteStyle.dogOrange, PetWhiteStyle.dogEar, PetWhiteStyle.blush.opacity(0.94)]
        } else if PureWhiteStyle.isActive {
            return [PureWhiteStyle.accent, PureWhiteStyle.paperBlue, PureWhiteStyle.inkSoft.opacity(0.42)]
        } else if MujiStyle.isActive {
            return [MujiStyle.clay, MujiStyle.indigo.opacity(0.86)]
        } else if NeumorphicStyle.isActive {
            return [NeumorphicStyle.accent, NeumorphicStyle.sage]
        } else if SequoiaStyle.isActive {
            return [SequoiaStyle.accent, SequoiaStyle.aqua]
        } else if LiquidGlassStyle.isActive {
            return [LiquidGlassStyle.accent, LiquidGlassStyle.cyan, LiquidGlassStyle.violet]
        } else if SignalStyle.isActive {
            return [SignalStyle.accent, SignalStyle.mint]
        } else if CapsuleStyle.isActive {
            return CapsuleStyle.accentGradient
        }
        return [Color.monologueAccent.opacity(0.62), Color.monologueAccent.opacity(0.92)]
    }
}

// MARK: - Monologue TabBar

struct MonologueTabBar: View {
    @Binding var selectedIndex: Int
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var tabNS

    private let itemHeight: CGFloat = 48
    private let padding: CGFloat = 5

    private var selectedColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.stroke }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        return MujiStyle.isActive ? MujiStyle.clay : .monologueTextPrimary
    }

    private var idleColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkMuted }
        return MujiStyle.isActive ? MujiStyle.inkMuted : .monologueTextPrimary.opacity(0.35)
    }

    private static let tabIcons: [(outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, label: NSLocalizedString(Tab.home.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 1, label: NSLocalizedString(Tab.podcast.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 2, label: NSLocalizedString(Tab.library.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 3, label: NSLocalizedString(Tab.profile.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, padding)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func tabButton(index: Int, label: String) -> some View {
        let isSelected = selectedIndex == index
        let icons = Self.tabIcons[index]

        Button {
            HapticManager.shared.light()
            // 页面切换不走动画(避免 TabView 内容做弹簧过渡导致卡顿)
            selectedIndex = index
        } label: {
            VStack(spacing: 2) {
                tabIcon(icon: isSelected ? icons.filled : icons.outline, isSelected: isSelected)
                .contentTransition(.interpolate)
                .scaleEffect(isSelected ? 1.06 : 1.0)
                .offset(y: isSelected ? -1 : 0)
                .animation(MonologueAnimation.tabSwitch, value: selectedIndex)

                Text(label)
                    .font(mangaOrMujiTabFont(isSelected: isSelected))
                    .foregroundColor(isSelected ? selectedColor : idleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: itemHeight, alignment: .center)
            .background {
                if isSelected {
                    Capsule()
                        .fill(mangaOrMujiHighlightColor)
                        .padding(.horizontal, 4)
                        .matchedGeometryEffect(id: "tabHighlight", in: tabNS)
                }
            }
            .animation(MonologueAnimation.tabSwitch, value: selectedIndex)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabIcon(icon: MonologueIcon.IconType, isSelected: Bool) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(
                icon: icon,
                size: 24,
                visualScale: isSelected ? 1.08 : 0.98,
                fallbackColor: isSelected ? selectedColor : idleColor
            )
        } else {
            MonologueIcon(
                icon: icon,
                size: 19,
                color: isSelected ? selectedColor : idleColor
            )
        }
    }

    private func mangaOrMujiTabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive {
            return MangaStyle.labelFont(9, weight: isSelected ? .black : .bold)
        } else if PetWhiteStyle.isActive {
            return PetWhiteStyle.labelFont(9, weight: isSelected ? .black : .bold)
        } else if PureWhiteStyle.isActive {
            return PureWhiteStyle.labelFont(9, weight: isSelected ? .black : .bold)
        } else if MujiStyle.isActive {
            return MujiStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        } else if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        } else if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        } else if LiquidGlassStyle.isActive {
            return LiquidGlassStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        }
        return .system(size: 10, weight: isSelected ? .semibold : .medium)
    }

    private var mangaOrMujiHighlightColor: Color {
        if MangaStyle.isActive { return MangaStyle.accentPink.opacity(0.15) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.mint.opacity(0.18) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent.opacity(0.18) }
        if MujiStyle.isActive { return MujiStyle.clay.opacity(0.1) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent.opacity(0.14) }
        if SequoiaStyle.isActive { return SequoiaStyle.accent.opacity(0.12) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash.opacity(0.88) }
        return Color.monologueTextPrimary.opacity(0.1)
    }
}

// MARK: - Unified Floating Bar

struct UnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var glassNS

    private var cornerRadius: CGFloat {
        return SignalStyle.isActive ? 18 : ((PetWhiteStyle.isActive || PureWhiteStyle.isActive) ? 24 : (MujiStyle.isActive ? 16 : 28))
    }

    var body: some View {
        switch settings.globalThemeId {
        case .manga:
            MangaUnifiedFloatingBar(currentTab: $currentTab)
        case .muji:
            MujiUnifiedFloatingBar(currentTab: $currentTab)
        case .neumorphic:
            NeumorphicUnifiedFloatingBar(currentTab: $currentTab)
        case .capsule:
            CapsuleUnifiedFloatingBar(currentTab: $currentTab)
        case .petWhite:
            petWhiteFloatingBar
        case .pureWhite:
            pureWhiteFloatingBar
        case .material3Expressive, .bento, .sequoia, .liquidGlass, .clay, .signal, .default:
            defaultFloatingBar
        }
    }

    @ViewBuilder
    private var defaultFloatingBar: some View {
        if settings.globalThemeId == .default && !settings.defaultThemeUsesLiquidGlassTabBar {
            frostedFloatingBar
        } else {
            glassFloatingBar
        }
    }

    private var frostedFloatingBar: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                ))
            }

            MonologueTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(frostedBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .compositingGroup()
        .shadow(color: Color.monologueAccent.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 24, x: 0, y: 4)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.18), radius: 18, x: 0, y: 10)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    private var glassFloatingBar: some View {
        MonologueGlassContainer(spacing: 0) {
            VStack(spacing: 0) {
                if let song = player.currentSong {
                    MiniPlayerSection(
                        song: song,
                        isPlaying: player.isPlaying,
                        togglePlayPause: { player.togglePlayPause() }
                    )
                    .swipeToSkip()
                    .monologueGlassID("miniPlayer", in: glassNS)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
                }

                MonologueTabBar(selectedIndex: Binding(
                    get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                    set: { currentTab = Tab.allCases[$0] }
                ))
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
                .monologueGlassID("tabBar", in: glassNS)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(barBackground)
            .overlay(barStroke)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16), radius: 18, x: 0, y: 8)
            .monologueGlass(cornerRadius: cornerRadius)
            .monologueGlassID("floatingBar", in: glassNS)
        }
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
    }

    private var pureWhiteFloatingBar: some View {
        VStack(spacing: 3) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                ))
            }

            MonologueTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            PureWhiteSurfaceBackground(
                cornerRadius: cornerRadius,
                elevated: true,
                tint: PureWhiteStyle.surfaceRaised
            )
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 5) {
                Capsule().fill(PureWhiteStyle.accent).frame(width: 34, height: 4)
                Capsule().fill(PureWhiteStyle.separator).frame(width: 18, height: 4)
                Capsule().fill(PureWhiteStyle.paperBlue.opacity(0.72)).frame(width: 22, height: 4)
            }
            .frame(width: 84, height: 8)
            .padding(.leading, 20)
            .padding(.top, 9)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: PureWhiteStyle.strokeInk.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 6, x: 0, y: 3)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    private var petWhiteFloatingBar: some View {
        PetWhiteUnifiedFloatingBar(currentTab: $currentTab)
    }

    @ViewBuilder
    private var barBackground: some View {
        if PetWhiteStyle.isActive {
            PetWhiteSurfaceBackground(
                cornerRadius: cornerRadius,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint
            )
        } else if PureWhiteStyle.isActive {
            PureWhiteSurfaceBackground(
                cornerRadius: cornerRadius,
                elevated: true,
                tint: PureWhiteStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.94 : 0.99)
            )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.monologueFloatingBarFill)
        }
    }

    @ViewBuilder
    private var frostedBarBackground: some View {
        // 底层:超薄毛玻璃
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            // 中层:带色调的半透明填充(浅色偏暖白,深色偏深灰蓝)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color(hex: "1A1E2E").opacity(0.62)
                            : Color(hex: "FFFFFF").opacity(0.58)
                    )
            }
            // 顶层:对角线微妙渐变(给悬浮栏一点"呼吸感")
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [
                                    Color.monologueAccent.opacity(0.06),
                                    Color.clear,
                                    Color(hex: "2A3F5F").opacity(0.08),
                                ]
                                : [
                                    Color.monologueAccent.opacity(0.05),
                                    Color.clear,
                                    Color(hex: "B8C8E0").opacity(0.12),
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            // 内边缘高光(上边缘亮,下边缘暗,营造立体)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.62),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.18),
                                Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            }
    }

    @ViewBuilder
    private var barStroke: some View {
        if PetWhiteStyle.isActive || PureWhiteStyle.isActive {
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
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct PetWhiteUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    var body: some View {
        VStack(spacing: 7) {
            if let song = player.currentSong {
                PetWhiteUnifiedNowPlayingTicket(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom))
                    ))
            }

            PetWhiteUnifiedTabPawDock(currentTab: $currentTab)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(PetWhiteStyle.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.7)
                )
                .overlay(alignment: .topTrailing) {
                    PetWhiteFloatingMascotDot(
                        filled: player.currentSong != nil,
                        tint: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                        size: 20
                    )
                    .offset(x: -18, y: -9)
                }
        }
        .shadow(color: PetWhiteStyle.stroke.opacity(0.12), radius: 0, x: 0, y: 4)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }
}

private struct PetWhiteUnifiedNowPlayingTicket: View {
    let song: Song
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @State private var showPlaylist = false

    private var subtitleText: String {
        player.lyricLineText ?? song.artistName
    }

    var body: some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: song.coverUrl, width: 42, height: 42) {
                PetWhiteMascotMark(kind: .pair, size: 24)
                    .frame(width: 42, height: 42)
                    .background(PetWhiteStyle.butter)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.5)
            )
            .overlay(alignment: .bottomTrailing) {
                PetWhiteFloatingMascotDot(
                    filled: true,
                    tint: player.isPlayingPodcast ? PetWhiteStyle.sky : PetWhiteStyle.mint,
                    size: 15
                )
                .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: song.name,
                    font: PetWhiteStyle.bodyFont(13, weight: .black),
                    color: PetWhiteStyle.ink,
                    speed: 25
                )
                .frame(height: 16)

                MarqueeText(
                    text: subtitleText,
                    font: PetWhiteStyle.bodyFont(11, weight: .semibold),
                    color: PetWhiteStyle.inkSoft,
                    speed: 22
                )
                .frame(height: 13)
            }
            .swipeSkipTextMotion()

            Spacer(minLength: 6)

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.5))

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: PetWhiteStyle.onAccent))
                            .scaleEffect(0.58)
                    } else {
                        PetWhitePackIcon(icon: player.isPlaying ? .pause : .play, size: 22, visualScale: 1.08)
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

            Button(action: { showPlaylist.toggle() }) {
                PetWhitePackIcon(icon: .list, size: 22, visualScale: 1.04, fallbackColor: PetWhiteStyle.stroke)
                    .frame(width: 32, height: 32)
                    .background(PetWhiteStyle.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(PetWhiteStyle.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

            if !player.isPlaying {
                Button {
                    withAnimation(MonologueAnimation.floatingBar) {
                        player.dismissMiniPlayerPreservingQueue()
                    }
                } label: {
                    PetWhitePackIcon(icon: .close, size: 18, visualScale: 1.04, fallbackColor: PetWhiteStyle.inkMuted)
                        .frame(width: 30, height: 30)
                        .background(PetWhiteStyle.surfacePressed)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(PetWhiteStyle.separator, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background {
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 22,
                    bottomLeading: 22,
                    bottomTrailing: 16,
                    topTrailing: 28
                ),
                style: .continuous
            )
            .fill(PetWhiteStyle.surfaceRaised)
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 22,
                        bottomLeading: 22,
                        bottomTrailing: 16,
                        topTrailing: 28
                    ),
                    style: .continuous
                )
                .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
            )
            .overlay(alignment: .bottomLeading) {
                ProgressBarView(height: 4, minFillWidth: 7)
                    .frame(height: 4)
                    .padding(.leading, 58)
                    .padding(.trailing, 82)
                    .offset(y: -3)
            }
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

private struct PetWhiteUnifiedTabPawDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    VStack(spacing: 3) {
                        PetWhitePackIcon(
                            icon: selected ? tab.icon : tab.monologueIcon,
                            size: selected ? 18 : 16,
                            visualScale: 1,
                            fallbackColor: selected ? PetWhiteStyle.stroke : PetWhiteStyle.inkMuted,
                            lineWidth: 1.45
                        )

                        Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                            .font(PetWhiteStyle.labelFont(9, weight: selected ? .black : .bold))
                            .foregroundColor(selected ? PetWhiteStyle.stroke : PetWhiteStyle.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(tabTint(tab).opacity(0.88))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.3)
                                )
                                .overlay(alignment: .topTrailing) {
                                    Circle()
                                        .fill(PetWhiteStyle.surfaceRaised)
                                        .frame(width: 7, height: 7)
                                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                                        .offset(x: -7, y: 6)
                                }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PetWhiteStyle.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PetWhiteStyle.separator, lineWidth: 1.1)
                )
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

private struct SequoiaUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .background(
                    SequoiaGlassBand(
                        tint: player.isPlaying ? SequoiaStyle.accent : SequoiaStyle.graphite,
                        cornerRadius: 20
                    )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.975, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.975, anchor: .bottom))
                ))
            }

            MonologueTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(tabSwipeGesture)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(SequoiaStyle.materialList.opacity(colorScheme == .dark ? 0.72 : 0.56))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(SequoiaStyle.separator, lineWidth: 0.55)
                    )
            )
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(SequoiaSurfaceBackground(cornerRadius: 25, elevated: true, role: .floating))
        .overlay(alignment: .top) {
            Capsule()
                .fill(SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.22 : 0.7))
                .frame(width: 48, height: 3)
                .offset(y: 5)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.18 : 0.52),
                            SequoiaStyle.separator.opacity(0.78),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.65
                )
        )
        .shadow(color: SequoiaStyle.shadow(colorScheme, elevated: true), radius: 18, x: 0, y: 9)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
        .themeRenderInteractiveLayer()
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                switchTab(direction: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct LiquidGlassUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .background(
                    LiquidGlassPrismBand(
                        tint: player.isPlaying ? LiquidGlassStyle.accent : LiquidGlassStyle.inkMuted,
                        cornerRadius: 21
                    )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.975, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.975, anchor: .bottom))
                ))
            }

            MonologueTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(tabSwipeGesture)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LiquidGlassStyle.glassList.opacity(colorScheme == .dark ? 0.72 : 0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.18 : 0.46), lineWidth: 0.6)
                    )
            )
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 27, elevated: true, role: .floating))
        .overlay(alignment: .top) {
            LiquidGlassHairline(tint: LiquidGlassStyle.accent.opacity(colorScheme == .dark ? 0.28 : 0.5))
                .frame(width: 72)
                .offset(y: 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.2 : 0.58),
                            LiquidGlassStyle.separator.opacity(0.82),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        )
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
        .themeRenderInteractiveLayer()
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                switchTab(direction: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct ClayUnifiedFloatingBar: View {
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
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct ClayMiniPlayerStrip: View {
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
                            withAnimation(MonologueAnimation.floatingBar) {
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
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func clayControl(icon: MonologueIcon.IconType, tint: Color, size: CGFloat = 13, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: size, color: tint, lineWidth: 1.75)
                .frame(width: 32, height: 32)
                .background(ClaySurfaceBackground(cornerRadius: 14, tint: tint.opacity(0.13), elevated: true, compact: true))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
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

private struct ClayDedicatedTabBar: View {
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
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            HStack(spacing: isSelected ? 5 : 0) {
                MonologueIcon(
                    icon: tab.icon,
                    size: isSelected ? 16 : 18,
                    color: isSelected ? ClayStyle.ink : ClayStyle.inkMuted,
                    lineWidth: isSelected ? 1.85 : 1.55
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

private struct SignalUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    var body: some View {
        VStack(spacing: 8) {
            if let song = player.currentSong {
                SignalMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom))
                    ))
            }

            SignalDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(SignalSurfaceBackground(cornerRadius: 24, elevated: true, fill: SignalStyle.paper.opacity(0.96)))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.62), lineWidth: 0.75)
                .padding(0.5)
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(LinearGradient(colors: [SignalStyle.accent.opacity(0.74), SignalStyle.mint.opacity(0.46)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 56, height: 4)
                .padding(.top, 10)
                .padding(.leading, 18)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
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
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct SignalMiniPlayerStrip: View {
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
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SignalStyle.controlPressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.62), lineWidth: 0.65)
                )

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: SignalStyle.labelFont(13, weight: .bold),
                        color: SignalStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: SignalStyle.labelFont(11, weight: .medium),
                        color: SignalStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 6) {
                    signalControl(icon: player.isPlaying ? .pause : .play, tint: SignalStyle.accent) {
                        player.togglePlayPause()
                    }

                    signalControl(icon: .list, tint: SignalStyle.inkSoft) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        signalControl(icon: .close, tint: SignalStyle.inkMuted, size: 9) {
                            withAnimation(MonologueAnimation.floatingBar) {
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
                .frame(height: 2.3)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
        .background(SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.screen.opacity(0.78)))
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func signalControl(
        icon: MonologueIcon.IconType,
        tint: Color,
        size: CGFloat = 14,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: size, color: tint, lineWidth: 1.75)
                .frame(width: 32, height: 32)
                .background(SignalSurfaceBackground(cornerRadius: 12, elevated: true, fill: SignalStyle.surfaceRaised))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
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

private struct SignalDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .home, .homeFilled),
        (.podcast, .podcast, .podcastFilled),
        (.library, .library, .libraryFilled),
        (.profile, .profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, index: index, outline: item.outline, filled: item.filled)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .frame(height: 48)
        .background(SignalSurfaceBackground(cornerRadius: 19, elevated: false, pressed: true, fill: SignalStyle.controlPressed))
    }

    private func tabButton(tab: Tab, index: Int, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
        let tint = tabTint(index)

        return Button {
            HapticManager.shared.light()
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            HStack(spacing: isSelected ? 5 : 0) {
                MonologueIcon(
                    icon: isSelected ? filled : outline,
                    size: isSelected ? 16 : 18,
                    color: isSelected ? SignalStyle.onAccent : SignalStyle.inkMuted,
                    lineWidth: isSelected ? 1.9 : 1.55
                )

                if isSelected {
                    Text(label)
                        .font(SignalStyle.labelFont(9, weight: .bold))
                        .foregroundStyle(SignalStyle.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint, SignalStyle.mint.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .matchedGeometryEffect(id: "signal-tab", in: selectionNS)
                        .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return SignalStyle.accent
        case 1: return SignalStyle.mint
        case 2: return SignalStyle.lavender
        default: return SignalStyle.clay
        }
    }
}

private struct MujiUnifiedFloatingBar: View {
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

                Rectangle()
                    .fill(MujiStyle.separator.opacity(0.76))
                    .frame(height: 0.6)
                    .padding(.horizontal, 12)
            }

            MujiDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(MujiPaperCardBackground(cornerRadius: 18, elevated: true))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(colorScheme == .dark ? MujiStyle.hairline.opacity(0.56) : Color.black.opacity(0.1), lineWidth: 0.75)
                .padding(0.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.13), radius: 16, x: 0, y: 7)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
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
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct NeumorphicUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                NeumorphicMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
            }

            NeumorphicDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(NeumorphicGlassSurfaceBackground(cornerRadius: 32, elevated: true))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? NeumorphicStyle.lightShadow(colorScheme, intensity: 0.9)
                        : NeumorphicStyle.darkShadow(colorScheme, intensity: 0.38),
                    lineWidth: 0.8
                )
                .padding(0.5)
        )
        .shadow(color: NeumorphicStyle.darkShadow(colorScheme, intensity: colorScheme == .dark ? 0.60 : 0.42), radius: 22, x: 0, y: 12)
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
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }

        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct NeumorphicMiniPlayerStrip: View {
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: true))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.65), lineWidth: 0.8))
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                            .frame(width: 14, height: 10)
                            .padding(3)
                            .background(NeumorphicStyle.surfaceRaised.opacity(0.9), in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: NeumorphicStyle.labelFont(13, weight: .semibold),
                        color: NeumorphicStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: NeumorphicStyle.labelFont(11, weight: .regular),
                        color: NeumorphicStyle.inkSoft,
                        speed: 22
                    )
                    .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 7) {
                    neumorphicControl(icon: player.isPlaying ? .pause : .play, tint: .white, filled: true) {
                        player.togglePlayPause()
                    }

                    neumorphicControl(icon: .list, tint: NeumorphicStyle.inkSoft) {
                        showPlaylist.toggle()
                    }

                    if !player.isPlaying {
                        neumorphicControl(icon: .close, tint: NeumorphicStyle.inkMuted, size: 9) {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic { openPlayer() }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 26,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfaceRaised.opacity(0.66),
                lightweight: true
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.44), lineWidth: 0.7)
        )
        .padding(.bottom, 7)
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func neumorphicControl(
        icon: MonologueIcon.IconType,
        tint: Color,
        size: CGFloat = 14,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: size, color: tint, lineWidth: 1.7)
                .frame(width: 38, height: 38)
                .background {
                    if filled {
                        Circle()
                            .fill(NeumorphicStyle.steel.opacity(0.94))
                            .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: 0.8))
                            .shadow(color: NeumorphicStyle.steel.opacity(0.24), radius: 10, x: 0, y: 5)
                    } else {
                        NeumorphicSurfaceBackground(cornerRadius: 15, elevated: true, lightweight: true)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
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

private struct NeumorphicDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
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
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(height: 62)
        .background(NeumorphicSurfaceBackground(cornerRadius: 27, elevated: false, pressed: true, lightweight: true))
    }

    private func tabButton(tab: Tab, index: Int, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")
        let tint = tabTint(index)

        return Button {
            HapticManager.shared.light()
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                MonologueIcon(
                    icon: isSelected ? filled : outline,
                    size: isSelected ? 19 : 18,
                    color: isSelected ? tint : NeumorphicStyle.inkMuted,
                    lineWidth: isSelected ? 1.8 : 1.5
                )
                .frame(width: 24, height: 22)

                Text(label)
                    .font(NeumorphicStyle.labelFont(10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? NeumorphicStyle.ink : NeumorphicStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, tint: NeumorphicStyle.surfaceRaised.opacity(0.86), lightweight: true))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .matchedGeometryEffect(id: "neumorphicTabSelection", in: selectionNS)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return NeumorphicStyle.accent
        case 1: return NeumorphicStyle.sage
        case 2: return NeumorphicStyle.warm
        default: return NeumorphicStyle.red
        }
    }
}

private struct MujiMiniPlayerStrip: View {
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
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(MujiStyle.separator.opacity(0.45))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.52), lineWidth: 0.6)
                )
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
                        font: MujiStyle.labelFont(13, weight: .semibold),
                        color: MujiStyle.ink,
                        speed: 25
                    )
                    .frame(height: 16)

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
                                .fill(MujiStyle.surfaceRaised.opacity(0.72))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MujiStyle.clay))
                                    .scaleEffect(0.55)
                            } else {
                                MonologueIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 14,
                                    color: MujiStyle.ink,
                                    lineWidth: 1.7
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 16, color: MujiStyle.inkSoft, lineWidth: 1.6)
                            .frame(width: 34, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    if !player.isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.6)
                                .frame(width: 28, height: 28)
                                .background(MujiStyle.ink.opacity(0.06), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
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
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func sourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 10, color: MujiStyle.onTint, lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .background(MujiStyle.ink.opacity(0.52), in: Circle())
            .padding(3)
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

private struct MujiDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
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

    private func tabButton(tab: Tab, index: Int, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    MonologueIcon(
                        icon: isSelected ? filled : outline,
                        size: 18,
                        color: isSelected ? MujiStyle.ink : MujiStyle.inkMuted,
                        lineWidth: isSelected ? 1.8 : 1.55
                    )
                    .frame(width: 28, height: 22)

                    if isSelected {
                        Circle()
                            .fill(tabTint(index))
                            .frame(width: 4.5, height: 4.5)
                            .offset(x: 3, y: -1)
                    }
                }

                Text(label)
                    .font(MujiStyle.labelFont(9, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? MujiStyle.ink : MujiStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MujiStyle.surface.opacity(0.78))
                        .overlay(
                            MujiPaperTexture(opacity: 0.08)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(MujiStyle.hairline.opacity(0.38), lineWidth: 0.6)
                        )
                        .matchedGeometryEffect(id: "mujiTabSelection", in: selectionNS)
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(tabTint(index).opacity(0.78))
                        .frame(width: 18, height: 2)
                        .padding(.bottom, 3)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return MujiStyle.clay
        case 1: return MujiStyle.tea
        case 2: return MujiStyle.indigo
        default: return MujiStyle.straw
        }
    }
}

// MARK: - 漫画风专用浮动栏

private struct MangaUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MangaMiniPlayerStrip(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
                    ))
            }

            MangaDedicatedTabBar(currentTab: $currentTab)
                .contentShape(Rectangle())
                .simultaneousGesture(tabSwipeGesture)
        }
        .padding(.horizontal, 7)
        .padding(.top, player.currentSong == nil ? 6 : 4)
        .padding(.bottom, 6)
        .background(mangaFloatingShell)
        .overlay(alignment: .topLeading) {
            Text("COMIC DOCK")
                .font(MangaStyle.labelFont(7, weight: .black))
                .foregroundStyle(MangaStyle.strokeInk)
                .tracking(0.6)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(MangaStyle.labelYellow, in: Capsule())
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.0))
                .rotationEffect(.degrees(-5))
                .offset(x: 16, y: -8)
        }
        .overlay(alignment: .bottomTrailing) {
            MangaSectionMark(kind: .star, tint: MangaStyle.decoBlue, size: 14)
                .offset(x: -14, y: 6)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.36 : 0.16), radius: 14, x: 0, y: 7)
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
    }

    private var mangaFloatingShell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(MangaStyle.strokeInk)
                .offset(x: 3, y: 3)

            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            MangaStyle.bubbleWhite,
                            MangaStyle.paperWarm.opacity(0.92),
                            MangaStyle.paperCool.opacity(0.72),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MangaDotsTexture(opacity: 0.026, gap: 11)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

            HStack(spacing: 0) {
                MangaStyle.accentPink.frame(width: 6)
                MangaStyle.labelYellow.frame(width: 6)
                MangaStyle.decoBlue.frame(width: 6)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 1.7)
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
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

private struct MangaMiniPlayerStrip: View {
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
            HStack(spacing: 8) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(MangaStyle.paperCool)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                )
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 1.1, y: 1.1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        MangaNowPlayingIndicator(isAnimating: true)
                            .scaleEffect(0.54, anchor: .bottomTrailing)
                            .padding(2)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if player.playSource == .fm {
                        mangaSourceIndicator(icon: .fm)
                    } else if player.isPlayingPodcast {
                        mangaSourceIndicator(icon: .radio)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: MangaStyle.bodyFont(12, weight: .bold),
                        color: MangaStyle.ink,
                        speed: 25
                    )
                    .frame(height: 15)

                    MarqueeText(
                        text: subtitleText,
                        font: MangaStyle.bodyFont(10, weight: .medium),
                        color: MangaStyle.inkSub,
                        speed: 22
                    )
                    .frame(height: 13)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 6) {
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(MangaStyle.labelYellow)
                                .frame(width: 29, height: 29)
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                                .frame(width: 29, height: 29)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MangaStyle.accentPink))
                                    .scaleEffect(0.55)
                            } else {
                                MonologueIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 13,
                                    color: MangaStyle.strokeInk,
                                    lineWidth: 1.8
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(MangaStyle.strokeInk)
                                .frame(width: 29, height: 29)
                                .offset(x: 1.1, y: 1.1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    // 列表
                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 14, color: MangaStyle.inkSub, lineWidth: 1.8)
                            .frame(width: 29, height: 29)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    // 关闭
                    if !player.isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 10, color: MangaStyle.inkMuted, lineWidth: 1.8)
                                .frame(width: 25, height: 25)
                                .background(MangaStyle.strokeInk.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 0.9))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 7)
            .padding(.top, 4)
            .padding(.bottom, 3)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
                        openPlayer()
                    }
            }

            ProgressBarView()
                .frame(height: 2)
                .padding(.horizontal, 7)
                .padding(.bottom, 3)
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func mangaSourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 10, color: MangaStyle.onStrokeInk, lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .background(MangaStyle.strokeInk.opacity(0.86), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1))
            .padding(3)
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

private struct MangaDedicatedTabBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
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
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(height: 48)
    }

    private func tabButton(tab: Tab, index: Int, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType) -> some View {
        let isSelected = currentTab == tab
        let label = NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: "")

        return Button {
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                currentTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    MonologueIcon(
                        icon: isSelected ? filled : outline,
                        size: isSelected ? 17 : 15.5,
                        color: isSelected ? selectedForeground(index) : MangaStyle.inkMuted,
                        lineWidth: isSelected ? 1.8 : 1.45
                    )
                    .frame(width: 26, height: 19)
                    .scaleEffect(isSelected ? 1.05 : 1)

                    if isSelected {
                        MangaSectionMark(
                            kind: index == 3 ? .heart : .star,
                            tint: MangaStyle.bubbleWhite,
                            size: 11,
                            foreground: MangaStyle.ink
                        )
                        .offset(x: 13, y: -6)
                    }
                }

                Text(label)
                    .font(MangaStyle.labelFont(9, weight: isSelected ? .black : .bold))
                    .foregroundStyle(isSelected ? selectedForeground(index) : MangaStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 39)
            .background {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(MangaStyle.strokeInk)
                            .offset(x: 1.1, y: 1.1)

                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(tabTint(index).opacity(0.82))

                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: 1.35)
                    }
                    .matchedGeometryEffect(id: "mangaTabSelection", in: selectionNS)
                }
            }
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(selectedForeground(index))
                        .frame(width: 15, height: 2)
                        .padding(.bottom, 3)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return MangaStyle.labelYellow
        case 1: return MangaStyle.bubbleBlue
        case 2: return MangaStyle.mint
        default: return MangaStyle.bubblePink
        }
    }

    private func selectedForeground(_ index: Int) -> Color {
        switch index {
        case 0, 2: return MangaStyle.strokeInk
        default: return MangaStyle.ink
        }
    }
}

// MARK: - Tab Enum Extension for Monologue Icons

extension Tab {
    var monologueIcon: MonologueIcon.IconType {
        switch self {
        case .home: return .home
        case .podcast: return .podcast
        case .library: return .library
        case .profile: return .profile
        }
    }
}
