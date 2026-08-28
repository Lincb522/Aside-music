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
        return Color.monoTextPrimary
    }

    private var secondaryTextColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        return Color.monoTextSecondary
    }

    private var controlFillColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.accent }
        if PetWhiteStyle.isActive { return PetWhiteStyle.accent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash }
        return Color.monoIconBackground
    }

    private var controlForegroundColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if PetWhiteStyle.isActive { return PetWhiteStyle.onAccent }
        if PureWhiteStyle.isActive { return PureWhiteStyle.onAccent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        return Color.monoIconForeground
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
                                MonoIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 14,
                                    color: controlForegroundColor
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    Button(action: { showPlaylist.toggle() }) {
                        miniControlIcon(icon: .list, size: 16, color: primaryTextColor.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonoAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            miniControlIcon(icon: .close, size: 10, color: secondaryTextColor)
                                .frame(width: 28, height: 28)
                                .background(primaryTextColor.opacity(0.08))
                                .clipShape(Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
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

            ProgressBarView()
                .frame(height: 2.5)
                .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
                .padding(.bottom, 4)
        }
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

    private var minimalWhiteBody: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonoIcon(icon: .musicNote, size: 22, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5))
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
                        MonoIcon(icon: .list, size: 15, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.65)
                            .frame(width: 34, height: 34)
                            .background(MinimalWhiteCircleBackground(elevated: false))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

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
                                MonoIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 15,
                                    color: MinimalWhiteStyle.onAccent,
                                    lineWidth: 1.8
                                )
                            }
                        }
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonoAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonoIcon(icon: .close, size: 12, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6)
                                .frame(width: 32, height: 32)
                                .background(MinimalWhiteCircleBackground(elevated: false))
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
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
            MonoIcon(icon: .fm, size: 14, color: MinimalWhiteStyle.ink, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .background(MinimalWhiteCircleBackground(elevated: false))
                .offset(x: 5, y: 5)
        } else if player.isPlayingPodcast {
            MonoIcon(icon: .radio, size: 14, color: MinimalWhiteStyle.ink, lineWidth: 1.5)
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
                        .overlay(MonoIcon(icon: .musicNote, size: 20, color: PureWhiteStyle.inkMuted, lineWidth: 1.6))
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
                        MonoIcon(icon: .list, size: 14, color: PureWhiteStyle.inkSoft, lineWidth: 1.7)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(PureWhiteStyle.surfaceRaised)
                                    .overlay(Circle().stroke(PureWhiteStyle.separator, lineWidth: 1))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

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
                                MonoIcon(
                                    icon: isPlaying ? .pause : .play,
                                    size: 15,
                                    color: PureWhiteStyle.onAccent,
                                    lineWidth: 1.8
                                )
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

                    if !isPlaying {
                        Button(action: {
                            withAnimation(MonoAnimation.floatingBar) {
                                player.dismissMiniPlayerPreservingQueue()
                            }
                        }) {
                            MonoIcon(icon: .close, size: 11, color: PureWhiteStyle.inkMuted, lineWidth: 1.6)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(PureWhiteStyle.surfaceTint)
                                        .overlay(Circle().stroke(PureWhiteStyle.separator, lineWidth: 1))
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
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
            MonoIcon(
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

    /// 播放来源角标
    @ViewBuilder
    private func sourceIndicator(icon: MonoIcon.IconType) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(icon: icon, size: 18, visualScale: 1.06, fallbackColor: .white, lineWidth: 1.6)
        } else {
            MonoIcon(icon: icon, size: 12, color: .white, lineWidth: 1.6)
        }
    }

    @ViewBuilder
    private func miniControlIcon(icon: MonoIcon.IconType, size: CGFloat, color: Color) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(icon: icon, size: max(size + 7, 18), visualScale: 1.06, fallbackColor: color)
        } else {
            MonoIcon(icon: icon, size: size, color: color)
        }
    }
}
