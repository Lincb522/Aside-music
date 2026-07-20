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
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        return Color.monologueTextPrimary
    }

    private var secondaryTextColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        return Color.monologueTextSecondary
    }

    private var controlFillColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.accent }
        if PetWhiteStyle.isActive { return PetWhiteStyle.accent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash }
        return Color.monologueIconBackground
    }

    private var controlForegroundColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if PetWhiteStyle.isActive { return PetWhiteStyle.onAccent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.onAccent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        return Color.monologueIconForeground
    }

    private var titleFont: Font {
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.bodyFont(13, weight: .semibold)
        }
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
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.bodyFont(11, weight: .regular)
        }
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
        Group {
            if MinimalWhiteStyle.isActive {
                minimalWhiteBody
            } else if PureWhiteStyle.isActive {
                pureWhiteBody
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        CachedAsyncImage(url: song.coverUrl) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.gray.opacity(0.15))
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: MinimalWhiteStyle.isActive ? 7 : ((PetWhiteStyle.isActive || PureWhiteStyle.isActive) ? 10 : (LiquidGlassStyle.isActive ? 12 : (MujiStyle.isActive ? 5 : 8))), style: .continuous))
                        .overlay {
                            if MinimalWhiteStyle.isActive {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
                            } else if PetWhiteStyle.isActive {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(PetWhiteStyle.stroke, lineWidth: 1)
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
                                    if MinimalWhiteStyle.isActive {
                                        Circle().stroke(MinimalWhiteStyle.accent, lineWidth: 1)
                                    } else if PetWhiteStyle.isActive {
                                        Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1)
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

    private var minimalWhiteBody: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonologueIcon(icon: .musicNote, size: 22, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
                )
                .overlay(alignment: .bottomTrailing) {
                    minimalWhiteSourceBadge
                }

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: MinimalWhiteStyle.bodyFont(14, weight: .semibold),
                        color: MinimalWhiteStyle.ink,
                        speed: 25
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: subtitleText,
                        font: MinimalWhiteStyle.labelFont(11, weight: .regular),
                        color: MinimalWhiteStyle.inkMuted,
                        speed: 22
                    )
                    .frame(height: 14)
                    .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 7) {
                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 15, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.65)
                            .frame(width: 34, height: 34)
                            .background(MinimalWhiteCircleBackground(elevated: false))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(MinimalWhiteStyle.ink)
                                .frame(width: 38, height: 38)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MinimalWhiteStyle.onAccent))
                                    .scaleEffect(0.58)
                            } else {
                                MonologueIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 15,
                                    color: MinimalWhiteStyle.onAccent,
                                    lineWidth: 1.8
                                )
                            }
                        }
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 12, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6)
                                .frame(width: 32, height: 32)
                                .background(MinimalWhiteCircleBackground(elevated: false))
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            ProgressBarView(height: 2, minFillWidth: 4)
                .padding(.leading, 60)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, DeviceLayout.isPad ? 18 : 12)
        .padding(.top, 11)
        .padding(.bottom, 10)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapWithHaptic {
                    openCurrentPlayer()
                }
        }
    }

    @ViewBuilder
    private var minimalWhiteSourceBadge: some View {
        if player.playSource == .fm {
            MonologueIcon(icon: .fm, size: 14, color: MinimalWhiteStyle.ink, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .background(MinimalWhiteCircleBackground(elevated: false))
                .offset(x: 5, y: 5)
        } else if player.isPlayingPodcast {
            MonologueIcon(icon: .radio, size: 14, color: MinimalWhiteStyle.ink, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .background(MinimalWhiteCircleBackground(elevated: false))
                .offset(x: 5, y: 5)
        }
    }

    // MARK: - PureWhite 印刷风迷你播放器

    private var pureWhiteBody: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PureWhiteStyle.surfaceTint)
                        .overlay(MonologueIcon(icon: .musicNote, size: 20, color: PureWhiteStyle.inkMuted, lineWidth: 1.6))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PureWhiteStyle.separator, lineWidth: 1)
                )
                .shadow(color: PureWhiteStyle.strokeInk.opacity(0.10), radius: 0, x: 0, y: 2)
                .overlay(alignment: .bottomTrailing) {
                    pureWhiteSourceBadge
                }

                HStack(spacing: 9) {
                    Capsule(style: .continuous)
                        .fill(PureWhiteStyle.accent)
                        .frame(width: 3, height: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        MarqueeText(
                            text: song.name,
                            font: PureWhiteStyle.bodyFont(13, weight: .black),
                            color: PureWhiteStyle.ink,
                            speed: 25
                        )
                        .frame(height: 16)

                        MarqueeText(
                            text: subtitleText,
                            font: PureWhiteStyle.bodyFont(11, weight: .semibold),
                            color: PureWhiteStyle.inkSoft,
                            speed: 22
                        )
                        .frame(height: 14)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 8) {
                    Button(action: { showPlaylist.toggle() }) {
                        MonologueIcon(icon: .list, size: 14, color: PureWhiteStyle.inkSoft, lineWidth: 1.7)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(PureWhiteStyle.surfaceRaised)
                                    .overlay(Circle().stroke(PureWhiteStyle.separator, lineWidth: 1))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(PureWhiteStyle.accent)
                                .frame(width: 38, height: 38)
                                .shadow(color: PureWhiteStyle.strokeInk.opacity(0.14), radius: 0, x: 0, y: 2)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: PureWhiteStyle.onAccent))
                                    .scaleEffect(0.58)
                            } else {
                                MonologueIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 15,
                                    color: PureWhiteStyle.onAccent,
                                    lineWidth: 1.8
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonologueIcon(icon: .close, size: 11, color: PureWhiteStyle.inkMuted, lineWidth: 1.6)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(PureWhiteStyle.surfaceTint)
                                        .overlay(Circle().stroke(PureWhiteStyle.separator, lineWidth: 1))
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .zIndex(1)
            }
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapWithHaptic {
                        openCurrentPlayer()
                    }
            }

            ProgressBarView(height: 2.5, minFillWidth: 4)
                .padding(.leading, 58)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, DeviceLayout.isPad ? 12 : 6)
        .padding(.top, 11)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var pureWhiteSourceBadge: some View {
        if player.playSource == .fm || player.isPlayingPodcast {
            MonologueIcon(
                icon: player.playSource == .fm ? .fm : .radio,
                size: 12,
                color: PureWhiteStyle.ink,
                lineWidth: 1.5
            )
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(PureWhiteStyle.surfaceRaised)
                    .overlay(Circle().stroke(PureWhiteStyle.separator, lineWidth: 1))
            )
            .offset(x: 5, y: 5)
        }
    }

    private func openCurrentPlayer() {
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
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.separator
        } else if MangaStyle.isActive {
            return MangaStyle.separator.opacity(0.6)
        } else if PetWhiteStyle.isActive {
            return PetWhiteStyle.ink.opacity(0.12)
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
        if MinimalWhiteStyle.isActive {
            return [MinimalWhiteStyle.accent, MinimalWhiteStyle.accent]
        } else if MangaStyle.isActive {
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
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        return MujiStyle.isActive ? MujiStyle.clay : .monologueAccent
    }

    private var idleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkMuted }
        return MujiStyle.isActive ? MujiStyle.inkMuted : .monologueTextSecondary.opacity(0.55)
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
                size: 20,
                color: isSelected ? selectedColor : idleColor
            )
        }
    }

    private func mangaOrMujiTabFont(isSelected: Bool) -> Font {
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.labelFont(9, weight: isSelected ? .semibold : .regular)
        } else if MangaStyle.isActive {
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
        return .system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded)
    }

    private var mangaOrMujiHighlightColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.selectedFill }
        if MangaStyle.isActive { return MangaStyle.accentPink.opacity(0.15) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.mint.opacity(0.18) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent.opacity(0.18) }
        if MujiStyle.isActive { return MujiStyle.clay.opacity(0.1) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent.opacity(0.14) }
        if SequoiaStyle.isActive { return SequoiaStyle.accent.opacity(0.12) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash.opacity(0.88) }
        return Color.monologueAccent.opacity(0.12)
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
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.chromeRadius }
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
        case .minimalWhite:
            MinimalWhiteUnifiedDock(currentTab: $currentTab)
        case .default:
            defaultFloatingBar
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
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    private var minimalWhiteFloatingBar: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .transition(.opacity)

                Divider()
                    .overlay(MinimalWhiteStyle.hairline)
                    .padding(.horizontal, 10)
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
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: MinimalWhiteStyle.chromeRadius, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: player.currentSong != nil)
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
                .fill(Color.monologueFloatingBarFill)
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
            withAnimation(MonologueAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}

// MARK: - Aside 统一悬浮栏（墨水药丸 + 发丝线编辑风）

private struct AsideUnifiedFloatingBar: View {
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
        .animation(MonologueAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }

    @ViewBuilder
    private var chrome: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if usesGlassChrome {
            shape
                .fill(Color.monologueFloatingBarFill)
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
                                Color.monologueAccent.opacity(colorScheme == .dark ? 0.05 : 0.03),
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
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = allTabs[nextIndex]
                    }
                }
            }
    }
}

/// iOS 26 液态玻璃开关：仅在启用时叠加 glassEffect
private struct AsideBarGlassModifier: ViewModifier {
    let enabled: Bool
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.monologueGlass(cornerRadius: cornerRadius)
        } else {
            content
        }
    }
}

private struct AsideBarHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.monologueTextPrimary.opacity(0.08))
            .frame(height: 0.7)
    }
}

// MARK: - Aside 正在播放行

private struct AsideNowPlayingRow: View {
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
                        color: .monologueTextPrimary,
                        speed: 25
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: subtitleText,
                        font: .system(size: 11, weight: .medium, design: .rounded),
                        color: .monologueTextSecondary.opacity(0.9),
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
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
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
                .fill(Color.monologueTextPrimary.opacity(0.06))
                .overlay(MonologueIcon(icon: .musicNote, size: 15, color: .monologueTextSecondary.opacity(0.6), lineWidth: 1.5))
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: 43, height: 43)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.monologueTextPrimary.opacity(0.1), lineWidth: 0.7)
        )
        .overlay(alignment: .bottomTrailing) {
            if player.playSource == .fm {
                sourceBadge(icon: .fm)
            } else if player.isPlayingPodcast {
                sourceBadge(icon: .radio)
            }
        }
    }

    private func sourceBadge(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 10, color: .monologueAccentForeground, lineWidth: 1.6)
            .frame(width: 18, height: 18)
            .background(Color.monologueAccent, in: Circle())
            .overlay(Circle().stroke(Color(light: .white, dark: Color(hex: "15171E")).opacity(0.9), lineWidth: 1.4))
            .offset(x: 5, y: 5)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.monologueAccent)
                        .frame(width: 37, height: 37)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .monologueAccentForeground))
                            .scaleEffect(0.56)
                    } else {
                        MonologueIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 14,
                            color: .monologueAccentForeground,
                            lineWidth: 1.8
                        )
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.93))

            Button(action: { showPlaylist.toggle() }) {
                MonologueIcon(icon: .list, size: 15, color: .monologueTextPrimary.opacity(0.68), lineWidth: 1.7)
                    .frame(width: 33, height: 33)
                    .background(
                        Circle().strokeBorder(Color.monologueTextPrimary.opacity(0.13), lineWidth: 1)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.93))

            if !player.isPlaying {
                Button {
                    withAnimation(MonologueAnimation.floatingBar) {
                        player.dismissMiniPlayerPreservingQueue()
                    }
                } label: {
                    MonologueIcon(icon: .close, size: 10, color: .monologueTextSecondary, lineWidth: 1.6)
                        .frame(width: 28, height: 28)
                        .background(Color.monologueTextPrimary.opacity(0.07), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.93))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .zIndex(1)
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

// MARK: - Aside 墨水药丸 Tab 栏

private struct AsideInkPillTabBar: View {
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
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
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
                MonologueIcon(
                    icon: selected ? tab.icon : tab.monologueIcon,
                    size: 18,
                    color: selected ? .monologueAccentForeground : .monologueTextSecondary.opacity(0.62),
                    lineWidth: 1.7
                )

                if selected {
                    Text(label)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueAccentForeground)
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
                        .fill(Color.monologueAccent)
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

private struct MinimalWhiteUnifiedDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @State private var showPlaylist = false
    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 8) {
            if let song = player.currentSong {
                nowPlayingStrip(song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
            }

            tabRail
        }
        .padding(8)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
        )
        .animation(.easeOut(duration: 0.18), value: player.currentSong != nil)
        .animation(MonologueAnimation.tabSwitch, value: currentTab)
        .themeRenderInteractiveLayer()
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func nowPlayingStrip(_ song: Song) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 11) {
                CachedAsyncImage(url: song.coverUrl, width: 42, height: 42) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: MinimalWhiteStyle.bodyFont(14, weight: .semibold),
                        color: MinimalWhiteStyle.ink,
                        speed: 24
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: player.lyricLineText ?? song.artistName,
                        font: MinimalWhiteStyle.labelFont(11, weight: .regular),
                        color: MinimalWhiteStyle.inkMuted,
                        speed: 22
                    )
                    .frame(height: 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(MinimalWhiteStyle.ink)
                            .frame(width: 34, height: 34)

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: MinimalWhiteStyle.onAccent))
                                .scaleEffect(0.58)
                        } else {
                            MonologueIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 14,
                                color: MinimalWhiteStyle.onAccent,
                                lineWidth: 1.8
                            )
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

                Button(action: { showPlaylist.toggle() }) {
                    MonologueIcon(icon: .list, size: 15, color: MinimalWhiteStyle.inkSoft, lineWidth: 1.7)
                        .frame(width: 34, height: 34)
                        .background(MinimalWhiteCircleBackground())
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }
            .contentShape(Rectangle())
            .onTapWithHaptic { openPlayer() }

            ProgressBarView(height: 2, minFillWidth: 5)
                .frame(height: 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: 18,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        )
    }

    private var tabRail: some View {
        HStack(spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonologueAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    HStack(spacing: 6) {
                        MonologueIcon(
                            icon: selected ? tab.icon : tab.monologueIcon,
                            size: selected ? 17 : 16,
                            color: selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted,
                            lineWidth: 1.7
                        )

                        if selected {
                            Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                                .font(MinimalWhiteStyle.labelFont(11, weight: .semibold))
                                .foregroundStyle(MinimalWhiteStyle.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                    .frame(maxWidth: selected ? 118 : 52, minHeight: 42)
                    .background {
                        if selected {
                            Capsule(style: .continuous)
                                .fill(MinimalWhiteStyle.selectedFill)
                                .overlay(Capsule(style: .continuous).stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth))
                                .matchedGeometryEffect(id: "minimalWhiteUnifiedTab", in: tabNamespace)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(3)
        .background(Capsule(style: .continuous).fill(MinimalWhiteStyle.controlGlassFill))
        .overlay(Capsule(style: .continuous).stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth))
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
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius + 4, style: .continuous),
                tint: PetWhiteStyle.paper,
                accent: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                lineWidth: 1
            )
        }
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(PetWhiteStyle.stroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: song.name,
                    font: PetWhiteStyle.bodyFont(13, weight: .semibold),
                    color: PetWhiteStyle.ink,
                    speed: 25
                )
                .frame(height: 16)

                MarqueeText(
                    text: subtitleText,
                    font: PetWhiteStyle.bodyFont(11),
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
                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))

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
                PetWhitePackIcon(icon: .list, size: 22, visualScale: 1.04, fallbackColor: PetWhiteStyle.ink)
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
            PetWhiteFrostedFloatingSurface(
                shape: UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 22,
                        bottomLeading: 22,
                        bottomTrailing: 16,
                        topTrailing: 28
                    ),
                    style: .continuous
                ),
                tint: PetWhiteStyle.surfaceRaised,
                accent: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                lineWidth: 1.4
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
                            fallbackColor: selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted,
                            lineWidth: 1.45
                        )

                        Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                            .font(PetWhiteStyle.labelFont(9, weight: selected ? .black : .bold))
                            .foregroundColor(selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        if selected {
                            PetWhiteClayPuck(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                tint: tabTint(tab),
                                pressedLook: true
                            )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.9))
            }
        }
        .padding(5)
        .background {
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint,
                strokeColor: PetWhiteStyle.separator,
                lineWidth: 1.1,
                elevated: false
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
                                MonologueIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 14,
                                    color: MujiStyle.clay,
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
                MonologueIcon(
                    icon: isSelected ? filled : outline,
                    size: 18,
                    color: isSelected ? MujiStyle.clay : MujiStyle.inkMuted,
                    lineWidth: isSelected ? 1.8 : 1.55
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

// MARK: - 漫画风专用浮动栏

private struct MangaUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 3) {
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
                .overlay(alignment: .topTrailing) {
                    MangaComicLightningShape()
                        .fill(MangaComicPalette.red)
                        .overlay(MangaComicLightningShape().stroke(MangaComicPalette.ink, lineWidth: 1.3))
                        .frame(width: 18, height: 24)
                        .rotationEffect(.degrees(15))
                        .offset(x: -10, y: -11)
                        .allowsHitTesting(false)
                }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .shadow(color: MangaComicPalette.ink.opacity(colorScheme == .dark ? 0.48 : 0.22), radius: 0, x: 4, y: 5)
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

/// 漫画分格面板：暖白底 + 网点 + 厚墨框 + 硬墨影（迷你条与底栏共用）
private func mangaPanelShell(cornerRadius: CGFloat) -> some View {
    let shape = MangaComicPanelShape(corner: cornerRadius)

    return ZStack {
        shape
            .fill(MangaComicPalette.ink)
            .offset(x: 4, y: 4)

        shape.fill(MangaComicPalette.paper)

        MangaComicPaperTexture(opacity: 0.1)
            .clipShape(shape)

        shape.stroke(MangaComicPalette.ink, lineWidth: 3)

        shape
            .stroke(MangaComicPalette.ink, lineWidth: 1)
            .padding(5)
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
            HStack(spacing: 7) {
                CachedAsyncImage(url: song.coverUrl) {
                    MangaComicPalette.violet
                        .overlay(MangaComicHalftone(color: MangaComicPalette.whiteInk, opacity: 0.08, gap: 7))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(MangaComicPanelShape(corner: 8))
                .overlay(MangaComicPanelShape(corner: 8).stroke(MangaComicPalette.ink, lineWidth: 2.2))
                .background(MangaComicPanelShape(corner: 8).fill(MangaComicPalette.red).offset(x: 2.5, y: 2.5))
                .overlay(alignment: .bottomTrailing) {
                    if player.isPlaying {
                        MangaNowPlayingIndicator(isAnimating: true)
                            .scaleEffect(0.62, anchor: .bottomTrailing)
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

                VStack(alignment: .leading, spacing: 5) {
                    MarqueeText(
                        text: song.name,
                        font: MangaComicPalette.headlineFont(13),
                        color: MangaComicPalette.ink,
                        speed: 25
                    )
                    .frame(height: 16)

                    MarqueeText(
                        text: subtitleText,
                        font: MangaComicPalette.bodyFont(10, weight: .bold),
                        color: MangaComicPalette.mutedInk,
                        speed: 22
                    )
                    .frame(height: 13)
                        .animation(.easeInOut(duration: 0.25), value: player.lyricLineText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                HStack(spacing: 7) {
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            MangaComicRoundControl(
                                icon: player.isPlaying ? .pause : .play,
                                fill: MangaComicPalette.red,
                                foreground: MangaComicPalette.whiteInk,
                                size: 40
                            )

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MangaComicPalette.whiteInk))
                                    .scaleEffect(0.62)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MangaComicPressButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        MangaComicRoundControl(
                            icon: .list,
                            fill: MangaComicPalette.paper,
                            foreground: MangaComicPalette.ink,
                            size: 32
                        )
                    }
                    .buttonStyle(MangaComicPressButtonStyle())

                    if !player.isPlaying {
                        Button(action: {
                            withAnimation(MonologueAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MangaComicRoundControl(
                                icon: .close,
                                fill: MangaComicPalette.paper,
                                foreground: MangaComicPalette.ink,
                                size: 32
                            )
                        }
                        .buttonStyle(MangaComicPressButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 5)
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
                .padding(.horizontal, 10)
                .padding(.bottom, 3)
        }
        .background(mangaPanelShell(cornerRadius: 12))
        .monologueSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func mangaSourceIndicator(icon: MonologueIcon.IconType) -> some View {
        MonologueIcon(icon: icon, size: 10, color: MangaComicPalette.whiteInk, lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .background(MangaComicPalette.ink.opacity(0.9), in: MangaComicCutCornerShape(cut: 4))
            .overlay(MangaComicCutCornerShape(cut: 4).stroke(MangaComicPalette.ink, lineWidth: 1))
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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Namespace private var selectionNS

    private static let tabs: [(tab: Tab, outline: MonologueIcon.IconType, filled: MonologueIcon.IconType)] = [
        (.home, .home, .homeFilled),
        (.podcast, .podcast, .podcastFilled),
        (.library, .library, .libraryFilled),
        (.profile, .profile, .profileFilled),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< Self.tabs.count, id: \.self) { index in
                let item = Self.tabs[index]
                tabButton(tab: item.tab, index: index, outline: item.outline, filled: item.filled)
            }
        }
        .padding(3)
        .frame(height: verticalSizeClass == .compact ? 52 : 60)
        .background(mangaPanelShell(cornerRadius: 12))
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
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    MonologueIcon(
                        icon: isSelected ? filled : outline,
                        size: 20,
                        color: isSelected ? MangaComicPalette.whiteInk : MangaComicPalette.ink,
                        lineWidth: isSelected ? 2.2 : 1.9
                    )

                    if isSelected {
                        MangaComicFourPointStar()
                            .fill(MangaComicPalette.gold)
                            .overlay(MangaComicFourPointStar().stroke(MangaComicPalette.ink, lineWidth: 1.1))
                            .frame(width: 11, height: 11)
                            .offset(x: 9, y: -6)
                    }
                }
                .frame(width: 32, height: 24)

                Text(label)
                    .font(MangaComicPalette.headlineFont(11))
                    .foregroundStyle(isSelected ? MangaComicPalette.whiteInk : MangaComicPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: verticalSizeClass == .compact ? 46 : 52)
            .background {
                if isSelected {
                    MangaComicCutCornerShape(cut: 8)
                        .fill(MangaComicPalette.red)
                        .overlay {
                            MangaComicHalftone(
                                color: MangaComicPalette.ink,
                                opacity: 0.08,
                                gap: 7
                            )
                            .clipShape(MangaComicCutCornerShape(cut: 8))
                        }
                        .overlay {
                            MangaComicCutCornerShape(cut: 8)
                                .stroke(MangaComicPalette.ink, lineWidth: 2.4)
                        }
                        .matchedGeometryEffect(id: "mangaTabSelection", in: selectionNS)
                }
            }
            .contentShape(MangaComicCutCornerShape(cut: 8))
        }
        .buttonStyle(MangaComicPressButtonStyle())
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
