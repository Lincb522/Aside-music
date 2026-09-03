import SwiftUI
import FFmpegSwiftSDK

extension ClassicPlayerLayout {
    var qualityButton: some View {
        Button(action: { showQualitySheet = true }) {
            Text(player.qualityButtonText)
                .font(.system(size: 10, weight: isThemedClassic ? .bold : .heavy, design: isThemedClassic ? .default : .rounded))
                .tracking(isThemedClassic ? 0 : 0.5)
                .foregroundColor(qualityBadgeForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(qualityBadgeBackground)
                .overlay(
                    // aside 编辑部风格：极细描边胶囊
                    RoundedRectangle(cornerRadius: isThemedClassic ? 5 : 20)
                        .stroke(qualityBadgeStroke, lineWidth: usesMangaStyle ? 1.4 : 0.8)
                )
        }
        .buttonStyle(.plain)
        .playerQualitySelectionAvailability()
    }

    @ViewBuilder
    var classicThemeBackdrop: some View {
        if usesMinimalWhiteStyle {
            MinimalWhiteRootBackdrop()
                .ignoresSafeArea()
        } else if usesMangaStyle {
            ZStack {
                MangaRootBackdrop()
                MangaDotsTexture(opacity: colorScheme == .dark ? 0.03 : 0.045, gap: 15)
            }
            .ignoresSafeArea()
        } else if usesMujiStyle {
            MujiRootBackdrop()
                .ignoresSafeArea()
        } else if usesNeumorphicStyle {
            ThemeRenderBackdrop(theme: .neumorphic)
                .ignoresSafeArea()
        } else if usesCapsuleStyle {
            ThemeRenderBackdrop(theme: .capsule)
                .ignoresSafeArea()
        } else if usesSequoiaStyle {
            ThemeRenderBackdrop(theme: .default)
                .ignoresSafeArea()
        } else if usesClayStyle {
            ClayRootBackdrop()
                .ignoresSafeArea()
        }
    }

    var headerView: some View {
        HStack {
            classicDismissButton

            Spacer()

            VStack(spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(classicBodyFont(12, weight: usesMangaStyle ? .black : .medium))
                    .foregroundColor(secondaryContentColor)
                    .tracking(1)

                if let name = player.currentSong?.name {
                    MarqueeText(
                        text: name,
                        font: classicBodyFont(13, weight: .semibold),
                        color: secondaryContentColor,
                        speed: 30,
                        delayBeforeScroll: 2.0,
                        alignment: .center
                    )
                    .frame(maxWidth: 180)
                }

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: usesMangaStyle ? .black : .medium, design: .monospaced))
                        .foregroundColor(secondaryContentColor.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 三点菜单按钮
            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { showMoreMenu.toggle() } }) {
                ZStack {
                    if usesNeumorphicStyle {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                            .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true))
                    } else if usesCapsuleStyle {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(CapsuleStyle.surfaceRaised)
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(CapsuleStyle.hairline.opacity(0.7), lineWidth: 0.8)
                            )
                            .shadow(color: CapsuleStyle.accent.opacity(0.08), radius: 10, x: 0, y: 5)
                    } else if usesMinimalWhiteStyle {
                        MinimalWhiteCircleBackground(elevated: true)
                            .frame(width: 44, height: 44)
                    } else if usesSequoiaStyle {
                        Circle()
                            .fill(SequoiaStyle.materialRaised.opacity(0.82))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(SequoiaStyle.separator.opacity(0.72), lineWidth: 0.55))
                    } else if usesClayStyle {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                            .background(ClaySurfaceBackground(cornerRadius: 22, tint: ClayStyle.cream, elevated: true, compact: true))
                    } else if usesMujiStyle {
                        Circle()
                            .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.1))
                            .frame(width: 44, height: 44)
                    } else {
                        Circle()
                            .fill(Color.monoGlassTint)
                            .frame(width: 44, height: 44)
                            .monoGlassCircle()
                    }
                    MonoIcon(icon: .more, size: 22, color: contentColor)
                }
                .contentShape(Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    /// 封面视图 — 关键：内部 ZStack 带 .frame(maxHeight: .infinity) 让封面撑满中间区域
    func artworkView(size: CGFloat) -> some View {
        let artSize = min(size, DeviceLayout.playerArtworkMaxSize)

        return artworkTile(size: artSize)
            .frame(maxHeight: .infinity)
    }

    func artworkTile(size: CGFloat) -> some View {
        let cornerRadius = classicArtworkCornerRadius

        return classicArtworkFrame(
            ZStack {
                if let song = player.currentSong {
                    CachedAsyncImage(
                        url: song.coverUrl?.sized(800),
                        width: size,
                        height: size
                    ) {
                            usesMinimalWhiteStyle ? MinimalWhiteStyle.controlGlassFill : (usesMangaStyle ? MangaStyle.paperCool : (usesMujiStyle ? MujiStyle.surfaceRaised : (usesNeumorphicStyle ? NeumorphicStyle.surfacePressed : (usesCapsuleStyle ? CapsuleStyle.surfaceTint : (usesSequoiaStyle ? SequoiaStyle.materialPressed : (usesClayStyle ? ClayStyle.creamPressed : Color.gray.opacity(0.2)))))))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()

                    if let dynamicUrl = player.dynamicCoverUrl, !dynamicUrl.isEmpty {
                        DynamicCoverView(urlString: dynamicUrl, cornerRadius: cornerRadius)
                            .frame(width: size, height: size)
                            .clipped()
                    }
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(usesMinimalWhiteStyle ? MinimalWhiteStyle.controlGlassFill : (usesMangaStyle ? MangaStyle.paperCool : (usesMujiStyle ? MujiStyle.surfaceRaised : (usesNeumorphicStyle ? NeumorphicStyle.surfacePressed : (usesCapsuleStyle ? CapsuleStyle.surfaceTint : (usesSequoiaStyle ? SequoiaStyle.materialPressed : (usesClayStyle ? ClayStyle.creamPressed : Color.gray.opacity(0.1))))))))
                        .overlay(
                            MonoIcon(icon: .musicNoteList, size: 80, color: secondaryContentColor.opacity(0.32))
                        )
                }
            }
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if player.currentSong != nil {
                    AIEqualizerArtworkStatusView(
                        accent: asideCoverAccent,
                        isDarkArtwork: asideCoverColors.isDark
                    )
                    .padding(max(10, min(15, size * 0.038)))
                    .zIndex(1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)),
            cornerRadius: cornerRadius
        )
    }

    @ViewBuilder
    func classicArtworkFrame<Content: View>(_ content: Content, cornerRadius: CGFloat) -> some View {
        if usesMinimalWhiteStyle {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )
                .shadow(color: MinimalWhiteStyle.ink.opacity(0.045), radius: 10, x: 0, y: 4)
        } else if usesMangaStyle {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth + 0.6)
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 5, y: 5)
                )
                .rotationEffect(.degrees(-1.6))
        } else if usesMujiStyle {
            // Muji 手帖：杏色水洗底纸错位衬托 + 极柔投影，像贴在手帖上的照片
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .fill(MujiStyle.wash(MujiStyle.tea, strength: 1.35))
                        .offset(x: 12, y: 14)
                )
                .shadow(color: MujiStyle.ink.opacity(0.1), radius: 22, x: 0, y: 10)
        } else if usesNeumorphicStyle {
            content
                .padding(10)
                .background(NeumorphicSurfaceBackground(cornerRadius: cornerRadius + 12, elevated: true, tint: NeumorphicStyle.surfaceRaised))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 12, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
                )
        } else if usesCapsuleStyle {
            content
                .padding(9)
                .background(CapsuleSurfaceBackground(cornerRadius: cornerRadius + 12, elevated: true, tint: CapsuleStyle.surfaceRaised))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 12, style: .continuous)
                        .stroke(CapsuleStyle.accent.opacity(0.16), lineWidth: 0.9)
                )
        } else if usesSequoiaStyle {
            content
                .padding(9)
                .background(SequoiaSurfaceBackground(cornerRadius: cornerRadius + 11, elevated: true, role: .chrome))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 11, style: .continuous)
                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.52), lineWidth: 0.65)
                )
        } else if usesClayStyle {
            content
                .padding(10)
                .background(ClaySurfaceBackground(cornerRadius: cornerRadius + 14, tint: ClayStyle.creamRaised, elevated: true))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 14, style: .continuous)
                        .stroke(ClayStyle.separator.opacity(0.34), lineWidth: 0.8)
                )
        } else if isThemedClassic {
            content
                .monoBackgroundExtension()
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        } else {
            content
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.16),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(contentColor.opacity(0.1), lineWidth: 0.7)
                )
        }
    }

    var songInfoView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .monoPlayerDisplayFont(
                        size: 26,
                        weight: .bold,
                        fallback: classicTitleFont(26, weight: .bold)
                    )
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(classicBodyFont(18, weight: .medium))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: { showQualitySheet = true }) {
                Text(player.qualityButtonText)
                    .font(.system(size: 10, weight: isThemedClassic ? .bold : .heavy, design: isThemedClassic ? .default : .rounded))
                    .tracking(isThemedClassic ? 0 : 0.5)
                    .foregroundColor(qualityBadgeForeground)
                    .padding(.horizontal, isThemedClassic ? 6 : 7)
                    .padding(.vertical, 3)
                    .background(qualityBadgeBackground)
                    .overlay(
                        // aside 编辑部风格：极细描边胶囊
                        RoundedRectangle(cornerRadius: isThemedClassic ? 4 : 20)
                            .stroke(qualityBadgeStroke, lineWidth: usesMangaStyle ? 1.4 : 0.8)
                    )
            }
            .playerQualitySelectionAvailability()

            if let song = player.currentSong {
                LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 26, activeColor: .red, inactiveColor: contentColor)
            } else {
                MonoIcon(icon: .like, size: 26, color: contentColor)
            }
        }
        .padding(.horizontal, isThemedClassic ? 14 : 0)
        .padding(.vertical, isThemedClassic ? 12 : 0)
        .background {
            classicInfoBackground
        }
    }

    @ViewBuilder
    var classicInfoBackground: some View {
        if usesMangaStyle {
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 2, elevated: true, tint: MangaStyle.bubbleWhite)
        } else if usesNeumorphicStyle {
            NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
        } else if usesCapsuleStyle {
            CapsuleSurfaceBackground(cornerRadius: 20, elevated: true, tint: CapsuleStyle.surfaceRaised)
        } else if usesSequoiaStyle {
            SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, role: .chrome)
        } else if usesClayStyle {
            ClaySurfaceBackground(cornerRadius: 18, tint: ClayStyle.cream.opacity(0.94), elevated: true, compact: true)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    var qualityBadgeBackground: some View {
        if usesMinimalWhiteStyle {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(MinimalWhiteStyle.controlGlassFill)
        } else if usesMangaStyle {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(MangaStyle.labelYellow)
        } else if usesMujiStyle {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.2))
        } else if usesNeumorphicStyle {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(NeumorphicStyle.surfaceRaised)
        } else if usesCapsuleStyle {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CapsuleStyle.surfaceRaised)
        } else if usesSequoiaStyle {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(SequoiaStyle.selectedWash.opacity(0.86))
        } else if usesClayStyle {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ClayStyle.butter.opacity(0.28))
        } else {
            Color.clear
        }
    }

    var qualityBadgeStroke: Color {
        if usesMinimalWhiteStyle { return MinimalWhiteStyle.hairline }
        if usesMangaStyle { return MangaStyle.strokeInk }
        if usesMujiStyle { return Color.clear }
        if usesNeumorphicStyle { return NeumorphicStyle.separator }
        if usesCapsuleStyle { return CapsuleStyle.accent.opacity(0.2) }
        if usesSequoiaStyle { return SequoiaStyle.accent.opacity(0.24) }
        if usesClayStyle { return ClayStyle.accent.opacity(0.28) }
        return contentColor.opacity(0.34)
    }

    var qualityBadgeForeground: Color {
        if usesMangaStyle { return MangaStyle.strokeInk }
        if usesMujiStyle { return MujiStyle.clay }
        if usesCapsuleStyle { return CapsuleStyle.accent }
        if usesSequoiaStyle { return SequoiaStyle.accent }
        if usesClayStyle { return ClayStyle.accent }
        return contentColor
    }

    var lyricsModeSongInfo: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentSong?.name ?? "")
                    .monoPlayerDisplayFont(
                        size: 20,
                        weight: .bold,
                        fallback: classicTitleFont(20, weight: .bold)
                    )
                    .foregroundColor(contentColor)
                    .lineLimit(1)
                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "")
                        .font(classicBodyFont(14, weight: .medium))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let song = player.currentSong {
                LikeButton(
                    songId: song.id,
                    isQQMusic: song.isQQMusic,
                    song: song,
                    size: 22,
                    activeColor: .red,
                    inactiveColor: contentColor
                )
                .background(contentColor.opacity(0.05))
                .clipShape(Circle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, isThemedClassic ? 8 : 0)
    }

    /// 进度条区域 — 柔和融入背景的波形进度条
    var progressSection: some View {
        PlaybackTimeReader { currentTime, duration in
            VStack(spacing: 6) {
                FullScreenPlayerView.WaveformProgressBar(
                    currentTime: Binding(
                        get: { isDraggingSlider ? dragTimeValue : currentTime },
                        set: { _ in }
                    ),
                    duration: duration,
                    color: progressColor,
                    trackOpacity: 0.1,
                    isAnimating: player.isPlaying,
                    onSeek: { time in
                        isDraggingSlider = true
                        dragTimeValue = time
                    },
                    onCommit: { time in
                        isDraggingSlider = false
                        player.seek(to: time)
                    }
                )
                .frame(height: 28)

                HStack {
                    Text(formatTime(isDraggingSlider ? dragTimeValue : currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(classicBodyFont(11, weight: .medium))
                .foregroundColor(secondaryContentColor.opacity(0.6))
                .monospacedDigit()
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
    }

    @ViewBuilder
    var classicPlayButtonBackground: some View {
        let size = DeviceLayout.playerPlayButtonSize

        if usesMinimalWhiteStyle {
            Circle()
                .fill(MinimalWhiteStyle.accent)
                .frame(width: size, height: size)
        } else if usesMangaStyle {
            Circle()
                .fill(MangaStyle.labelYellow)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                .background(
                    Circle()
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 3.5, y: 3.5)
                )
        } else if usesMujiStyle {
            Circle()
                .fill(MujiStyle.clay)
                .frame(width: size, height: size)
                .shadow(color: MujiStyle.clay.opacity(0.32), radius: 16, x: 0, y: 8)
        } else if usesNeumorphicStyle {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .background(NeumorphicSurfaceBackground(cornerRadius: size / 2, elevated: true))
        } else if usesCapsuleStyle {
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .fill(CapsuleStyle.accent)
                .frame(width: size, height: size)
                .shadow(color: CapsuleStyle.accent.opacity(0.24), radius: 12, x: 0, y: 7)
        } else if usesSequoiaStyle {
            Circle()
                .fill(SequoiaStyle.accent)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)
                )
                .shadow(color: SequoiaStyle.accent.opacity(0.22), radius: 12, x: 0, y: 6)
        } else if usesClayStyle {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .background(ClaySurfaceBackground(cornerRadius: size / 2, tint: ClayStyle.cream, elevated: true))
                .overlay(Circle().fill(ClayStyle.accent.opacity(0.12)).padding(8))
        } else {
            Circle()
                .fill(Color.monoGlassTint)
                .frame(width: size, height: size)
                .monoGlassCircle()
        }
    }

    var classicPlayIconColor: Color {
        if usesMinimalWhiteStyle { return MinimalWhiteStyle.onAccent }
        if usesMangaStyle { return MangaStyle.strokeInk }
        if usesMujiStyle { return MujiStyle.onTint }
        if usesNeumorphicStyle { return NeumorphicStyle.accent }
        if usesCapsuleStyle { return CapsuleStyle.onAccent }
        if usesSequoiaStyle { return SequoiaStyle.onAccent }
        if usesClayStyle { return ClayStyle.accent }
        return contentColor
    }

    /// 控制按钮 — 与原始完全一致
    var controlsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    MonoIcon(icon: player.mode.monoIcon, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .frame(width: 44)

                Spacer()

                Button(action: { player.previous() }) {
                    MonoIcon(icon: .previous, size: 32, color: contentColor)
                }
                .buttonStyle(MonoBouncingButtonStyle())

                Spacer()

                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        classicPlayButtonBackground

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: classicPlayIconColor))
                                .scaleEffect(1.2)
                        } else {
                            MonoIcon(icon: player.isPlaying ? .pause : .play, size: 32, color: classicPlayIconColor)
                        }
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))

                Spacer()

                Button(action: { player.next() }) {
                    MonoIcon(icon: .next, size: 32, color: contentColor)
                }
                .buttonStyle(MonoBouncingButtonStyle())

                Spacer()

                Button(action: { showPlaylist = true }) {
                    MonoIcon(icon: .list, size: 22, color: secondaryContentColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle())
                .frame(width: 44)
            }

            if let song = player.currentSong {
                HStack(spacing: 0) {
                    Button { showComments = true } label: {
                        MonoIcon(icon: .comment, size: 22, color: secondaryContentColor, lineWidth: 1.4)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                    .frame(width: 44)

                    Spacer()

                    if AppConfig.Features.downloadEnabled {
                        // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                        Button {
                            if !downloadManager.isDownloaded(songId: song.id) {
                                showDownloadSheet = true
                            }
                        } label: {
                            MonoIcon(
                                icon: .playerDownload,
                                size: 22,
                                color: downloadManager.isDownloaded(songId: song.id) ? .monoTextSecondary : secondaryContentColor,
                                lineWidth: 1.4
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                        .disabled(downloadManager.isDownloaded(songId: song.id))
                        .frame(width: 44)
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
            }
        }
    }

}
