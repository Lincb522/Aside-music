import SwiftUI
import FFmpegSwiftSDK

extension ClassicPlayerLayout {
    func neumorphicPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 8)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    neumorphicListeningConsole(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showLyrics)

            neumorphicTransportConsole
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 14)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
        .themeRenderSceneLayer()
    }

    func neumorphicListeningConsole(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18
        let availableWidth = geometry.size.width - horizontalPadding * 2
        let artSize = min(DeviceLayout.isPad ? 220 : 168, max(132, availableWidth * 0.42))

        return VStack(spacing: 12) {
            neumorphicArtworkStage(artSize: artSize)
        }
        .padding(.horizontal, horizontalPadding)
    }

    func neumorphicArtworkStage(artSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                neumorphicQualityChip

                Spacer(minLength: 12)

                neumorphicPlaybackMark
            }

            HStack(alignment: .center, spacing: 16) {
                artworkTile(size: artSize)
                    .frame(width: artSize, height: artSize)
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }

                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(player.currentSong?.name ?? "Unknown Song")
                            .monoPlayerDisplayFont(
                                size: 24,
                                weight: .semibold,
                                fallback: NeumorphicStyle.titleFont(24, weight: .semibold)
                            )
                            .foregroundStyle(NeumorphicStyle.ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.74)

                        Button { showArtistDetail = true } label: {
                            Text(player.currentSong?.artistName ?? "Unknown Artist")
                                .font(NeumorphicStyle.bodyFont(14, weight: .medium))
                                .foregroundStyle(NeumorphicStyle.inkSoft)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                    }

                    neumorphicStatusDeck

                    HStack(spacing: 10) {
                        neumorphicLikeControl
                        neumorphicLyricsToggle
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 32,
                elevated: true,
                tint: NeumorphicStyle.surfaceRaised
            )
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Capsule().fill(NeumorphicStyle.accent.opacity(0.5)).frame(width: 24, height: 6)
                Capsule().fill(NeumorphicStyle.sage.opacity(0.34)).frame(width: 12, height: 6)
            }
            .padding(.leading, 26)
            .padding(.top, 12)
        }
    }

    var neumorphicStatusDeck: some View {
        HStack(spacing: 8) {
            neumorphicMiniMeter

            VStack(alignment: .leading, spacing: 5) {
                Capsule()
                    .fill(NeumorphicStyle.accent.opacity(player.isPlaying ? 0.76 : 0.34))
                    .frame(width: player.isPlaying ? 58 : 36, height: 6)
                Capsule()
                    .fill(NeumorphicStyle.separator.opacity(0.55))
                    .frame(width: 78, height: 5)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 16,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: player.isPlaying)
    }

    var neumorphicQualityChip: some View {
        Button(action: { showQualitySheet = true }) {
            HStack(spacing: 7) {
                MonoIcon(icon: .headphones, size: 12, color: NeumorphicStyle.warm, lineWidth: 1.5)
                Text(player.qualityButtonText)
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: false,
                    pressed: true,
                    tint: NeumorphicStyle.surfacePressed,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
        .playerQualitySelectionAvailability()
    }

    @ViewBuilder
    var neumorphicLikeControl: some View {
        if let song = player.currentSong {
            LikeButton(
                songId: song.id,
                isQQMusic: song.isQQMusic,
                song: song,
                size: 23,
                activeColor: NeumorphicStyle.red,
                inactiveColor: NeumorphicStyle.inkSoft
            )
            .frame(width: 42, height: 42)
            .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: true, lightweight: true))
        } else {
            MonoIcon(icon: .like, size: 22, color: NeumorphicStyle.inkSoft, lineWidth: 1.5)
                .frame(width: 42, height: 42)
                .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: true, lightweight: true))
        }
    }

    var neumorphicPlaybackMark: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(NeumorphicStyle.accent.opacity(player.isPlaying ? 0.92 : 0.42))
                .frame(width: player.isPlaying ? 22 : 10, height: 7)
            Capsule()
                .fill(NeumorphicStyle.sage.opacity(player.isPlaying ? 0.72 : 0.34))
                .frame(width: player.isPlaying ? 12 : 18, height: 7)
            Capsule()
                .fill(NeumorphicStyle.warm.opacity(player.isPlaying ? 0.68 : 0.3))
                .frame(width: player.isPlaying ? 8 : 12, height: 7)
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 15,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: player.isPlaying)
    }

    var neumorphicLyricsToggle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                showLyrics.toggle()
            }
        }) {
            MonoIcon(
                icon: .karaoke,
                size: 17,
                color: showLyrics ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft,
                lineWidth: 1.5
            )
            .frame(width: 42, height: 42)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: !showLyrics,
                    pressed: showLyrics,
                    tint: showLyrics ? NeumorphicStyle.accent.opacity(0.14) : NeumorphicStyle.surfaceRaised,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
    }

    var neumorphicMiniMeter: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? NeumorphicStyle.accent.opacity(0.72) : NeumorphicStyle.sage.opacity(0.52))
                    .frame(width: 4, height: player.isPlaying ? CGFloat(9 + (index % 3) * 5) : 8)
            }
        }
        .frame(width: 36, height: 30)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 12,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: player.isPlaying)
    }

    var neumorphicTransportConsole: some View {
        VStack(spacing: 14) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, 10)
            }

            neumorphicProgressChannel

            neumorphicTransportControls

            if let song = player.currentSong {
                neumorphicUtilityRail(song: song)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(NeumorphicSurfaceBackground(cornerRadius: 31, elevated: true, tint: NeumorphicStyle.surface))
        .overlay(alignment: .top) {
            Capsule()
                .fill(NeumorphicStyle.lightShadow(colorScheme, intensity: 0.34))
                .frame(width: 62, height: 4)
                .offset(y: 9)
        }
    }

    var neumorphicProgressChannel: some View {
        PlaybackTimeReader { currentTime, duration in
            VStack(spacing: 7) {
                FullScreenPlayerView.WaveformProgressBar(
                    currentTime: Binding(
                        get: { isDraggingSlider ? dragTimeValue : currentTime },
                        set: { _ in }
                    ),
                    duration: duration,
                    color: NeumorphicStyle.accent,
                    trackOpacity: 0.12,
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
                .font(NeumorphicStyle.labelFont(11, weight: .medium))
                .foregroundColor(NeumorphicStyle.inkMuted)
                .monospacedDigit()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 20,
                    elevated: false,
                    pressed: true,
                    tint: NeumorphicStyle.surfacePressed,
                    lightweight: true
                )
            )
        }
    }

    var neumorphicTransportControls: some View {
        HStack(spacing: 8) {
            neumorphicIconButton(icon: player.mode.monoIcon, diameter: 40, iconSize: 20, tint: NeumorphicStyle.inkSoft) {
                player.switchMode()
            }

            HStack(spacing: 6) {
                neumorphicIconButton(icon: .previous, diameter: 44, iconSize: 24, tint: NeumorphicStyle.ink) {
                    player.previous()
                }

                neumorphicMainPlayButton

                neumorphicIconButton(icon: .next, diameter: 44, iconSize: 24, tint: NeumorphicStyle.ink) {
                    player.next()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 6)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 31,
                    elevated: false,
                    pressed: true,
                    tint: NeumorphicStyle.surfacePressed,
                    lightweight: true
                )
            )

            neumorphicIconButton(icon: .list, diameter: 40, iconSize: 20, tint: NeumorphicStyle.inkSoft) {
                showPlaylist = true
            }
        }
        .frame(maxWidth: .infinity)
    }

    var neumorphicMainPlayButton: some View {
        Button(action: { player.togglePlayPause() }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 64, height: 64)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 32,
                            elevated: true,
                            tint: NeumorphicStyle.accent.opacity(player.isPlaying ? 0.22 : 0.16)
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        NeumorphicStyle.lightShadow(colorScheme, intensity: 0.58),
                                        NeumorphicStyle.accent.opacity(0.32),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .padding(5)
                    )

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: NeumorphicStyle.accent))
                        .scaleEffect(1.08)
                } else {
                    MonoIcon(icon: player.isPlaying ? .pause : .play, size: 30, color: NeumorphicStyle.accent, lineWidth: 1.6)
                }
            }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        .scaleEffect(player.isPlaying ? 1 : 0.97)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: player.isPlaying)
    }

    func neumorphicIconButton(
        icon: MonoIcon.IconType,
        diameter: CGFloat,
        iconSize: CGFloat,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: iconSize, color: tint, lineWidth: 1.5)
                .frame(width: diameter, height: diameter)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: diameter / 2,
                        elevated: true,
                        tint: NeumorphicStyle.surfaceRaised,
                        lightweight: true
                    )
                )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
    }

    func neumorphicUtilityRail(song: Song) -> some View {
        HStack(spacing: 12) {
            neumorphicUtilityButton(icon: .comment, tint: NeumorphicStyle.sage) {
                showComments = true
            }

            if AppConfig.Features.downloadEnabled {
                // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                neumorphicDownloadButton(song: song)
            } else {
                // 沉浸模式按钮 — 占用原下载按钮的位置
                neumorphicUtilityButton(icon: .immersive, tint: NeumorphicStyle.warm) {
                    ImmersiveModeController.shared.present()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 20,
                elevated: false,
                pressed: true,
                tint: NeumorphicStyle.surfacePressed,
                lightweight: true
            )
        )
    }

    func neumorphicUtilityButton(
        icon: MonoIcon.IconType,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 21, color: tint, lineWidth: 1.45)
                .frame(width: 42, height: 42)
                .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true, lightweight: true))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
    }

    func neumorphicDownloadButton(song: Song) -> some View {
        let isDownloaded = downloadManager.isDownloaded(songId: song.id)

        return Button {
            if !isDownloaded {
                showDownloadSheet = true
            }
        } label: {
            MonoIcon(
                icon: .playerDownload,
                size: 21,
                color: isDownloaded ? NeumorphicStyle.inkMuted.opacity(0.58) : NeumorphicStyle.warm,
                lineWidth: 1.45
            )
            .frame(width: 42, height: 42)
            .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: !isDownloaded, pressed: isDownloaded, lightweight: true))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        .disabled(isDownloaded)
        .opacity(isDownloaded ? 0.62 : 1)
    }

}
