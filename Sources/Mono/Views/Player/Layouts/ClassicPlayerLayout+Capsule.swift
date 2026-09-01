import SwiftUI
import FFmpegSwiftSDK

extension ClassicPlayerLayout {
    // MARK: - Capsule OS 播放器（重设计：单焦点、胶囊系统）
    // 设计语言:
    //   · 顶部单一胶囊条(返回 / 歌名 / 更多)
    //   · 大封面,纯净,无装饰色条、无旋转、无浮层按钮
    //   · 进度条平铺于封面下方,不放进额外玻璃卡
    //   · 5 枚等距小胶囊控件(质量/收藏/歌词/评论/下载)
    //   · 底部单一 Control Capsule(循环 / 上一首 / 大播放键 / 下一首 / 队列)
    func capsulePlayerContent(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 18

        return VStack(spacing: 0) {
            capsulePlayerTopBar
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 14)

            Group {
                if showLyrics {
                    capsuleLyricsStage(geometry: geometry)
                } else {
                    capsulePlaybackStage(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.44, dampingFraction: 0.88), value: showLyrics)

            capsuleControlDeck
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
        .themeRenderSceneLayer()
    }

    // MARK: - 顶部胶囊(单一条)

    var capsulePlayerTopBar: some View {
        HStack(spacing: 8) {
            capsuleTopButton(icon: .chevronLeft) {
                dismiss()
            }

            HStack(spacing: 8) {
                MonoIcon(
                    icon: player.isPlaying ? .musicNote : .play,
                    size: 13,
                    color: CapsuleStyle.accent,
                    lineWidth: 1.7
                )

                MarqueeText(
                    text: capsuleTopBarText,
                    font: CapsuleStyle.labelFont(12, weight: .semibold),
                    color: CapsuleStyle.ink,
                    speed: 28,
                    delayBeforeScroll: 1.8,
                    alignment: .center
                )
                .frame(height: 22)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(CapsuleStyle.surface.opacity(0.74))
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(
                Capsule().stroke(CapsuleStyle.hairline.opacity(0.68), lineWidth: 1)
            )

            capsuleTopButton(icon: .more) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            }
        }
    }

    var capsuleTopBarText: String {
        guard let song = player.currentSong else {
            return String(localized: "not_playing")
        }
        let artist = song.artistName.isEmpty ? "" : " · \(song.artistName)"
        return "\(song.name)\(artist)"
    }

    func capsuleTopButton(icon: MonoIcon.IconType, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 18, color: CapsuleStyle.ink, lineWidth: 1.75)
                .frame(width: 44, height: 44)
                .background(
                    Capsule()
                        .fill(CapsuleStyle.surface.opacity(0.74))
                        .background(.ultraThinMaterial, in: Capsule())
                )
                .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.68), lineWidth: 1))
        }
        .buttonStyle(CapsulePressStyle())
    }

    // MARK: - 播放阶段(封面 + 歌曲信息 + 快捷操作)

    func capsulePlaybackStage(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 18
        let availableWidth = geometry.size.width - horizontalPadding * 2
        // 单焦点:封面占据主要视觉重量
        let artSize = min(DeviceLayout.usesExpandedLayout ? 340 : 300, max(220, availableWidth * 0.78))

        return VStack(spacing: 22) {
            capsuleCleanArtwork(size: artSize)
                .onTapWithHaptic {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                        showLyrics.toggle()
                    }
                }

            VStack(spacing: 6) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .monoPlayerDisplayFont(
                        size: 24,
                        weight: .bold,
                        fallback: CapsuleStyle.titleFont(24, weight: .bold)
                    )
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(CapsuleStyle.bodyFont(14, weight: .semibold))
                        .foregroundStyle(CapsuleStyle.inkSoft)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                // 音质元数据
                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(CapsuleStyle.inkMuted.opacity(0.72))
                        .lineLimit(1)
                }
            }

            capsuleQuickActionRow
                .padding(.top, 2)
        }
        .padding(.horizontal, horizontalPadding)
    }

    @ViewBuilder
    func capsuleCleanArtwork(size: CGFloat) -> some View {
        let cornerRadius: CGFloat = 32

        ZStack {
            if let song = player.currentSong {
                ZStack {
                    CachedAsyncImage(url: song.coverUrl?.sized(800)) {
                        CapsuleStyle.surfaceTint
                    }
                    .aspectRatio(contentMode: .fill)

                    if let dynamicUrl = player.dynamicCoverUrl, !dynamicUrl.isEmpty {
                        DynamicCoverView(urlString: dynamicUrl, cornerRadius: cornerRadius)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CapsuleStyle.surfaceTint)
                    .overlay(
                        MonoIcon(icon: .musicNoteList, size: 58, color: CapsuleStyle.inkMuted.opacity(0.45), lineWidth: 1.5)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CapsuleStyle.hairline.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 34, x: 0, y: 20)
        .shadow(color: CapsuleStyle.accent.opacity(0.08), radius: 20, x: 0, y: 12)
        .scaleEffect(player.isPlaying ? 1 : 0.97)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: player.isPlaying)
    }

    // MARK: - 快捷操作栏(5 枚等距小胶囊)

    var capsuleQuickActionRow: some View {
        HStack(spacing: 10) {
            capsuleQualityChip
            capsuleLikeControl
            capsuleLyricsToggle
            capsuleCommentQuick
            if AppConfig.Features.downloadEnabled {
                // 下载按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
                capsuleDownloadQuick
            } else {
                // 沉浸模式按钮 — 占用原下载按钮的位置
                capsuleImmersiveQuick
            }
        }
    }

    var capsuleImmersiveQuick: some View {
        Button {
            ImmersiveModeController.shared.present()
        } label: {
            MonoIcon(icon: .immersive, size: 16, color: CapsuleStyle.mint, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        }
        .buttonStyle(CapsulePressStyle())
        .disabled(player.currentSong == nil)
        .opacity(player.currentSong == nil ? 0.4 : 1)
    }

    var capsuleQualityChip: some View {
        Button(action: { showQualitySheet = true }) {
            HStack(spacing: 6) {
                MonoIcon(icon: .soundQuality, size: 13, color: CapsuleStyle.accent, lineWidth: 1.7)
                Text(player.qualityButtonText)
                    .font(CapsuleStyle.labelFont(11, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
            .overlay(Capsule().stroke(CapsuleStyle.accent.opacity(0.22), lineWidth: 0.9))
        }
        .buttonStyle(CapsulePressStyle())
        .playerQualitySelectionAvailability()
    }

    @ViewBuilder
    var capsuleLikeControl: some View {
        if let song = player.currentSong {
            LikeButton(
                songId: song.id,
                isQQMusic: song.isQQMusic,
                song: song,
                size: 18,
                activeColor: CapsuleStyle.coral,
                inactiveColor: CapsuleStyle.inkSoft
            )
            .frame(width: 36, height: 36)
            .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        } else {
            MonoIcon(icon: .like, size: 17, color: CapsuleStyle.inkSoft, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        }
    }

    var capsuleLyricsToggle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                showLyrics.toggle()
            }
        }) {
            MonoIcon(
                icon: .karaoke,
                size: 15,
                color: showLyrics ? CapsuleStyle.onAccent : CapsuleStyle.accent,
                lineWidth: 1.6
            )
            .frame(width: 36, height: 36)
            .background(
                capsulePillBackground(
                    tint: showLyrics ? CapsuleStyle.accent : CapsuleStyle.surfaceRaised.opacity(0.78)
                )
            )
        }
        .buttonStyle(CapsulePressStyle())
    }

    @ViewBuilder
    var capsuleCommentQuick: some View {
        Button { showComments = true } label: {
            MonoIcon(icon: .comment, size: 16, color: CapsuleStyle.violet, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
        }
        .buttonStyle(CapsulePressStyle())
        .disabled(player.currentSong == nil)
        .opacity(player.currentSong == nil ? 0.4 : 1)
    }

    @ViewBuilder
    var capsuleDownloadQuick: some View {
        if let song = player.currentSong {
            let isDownloaded = downloadManager.isDownloaded(songId: song.id)

            Button {
                if !isDownloaded {
                    showDownloadSheet = true
                }
            } label: {
                MonoIcon(
                    icon: .playerDownload,
                    size: 16,
                    color: isDownloaded ? CapsuleStyle.inkMuted.opacity(0.6) : CapsuleStyle.mint,
                    lineWidth: 1.6
                )
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(isDownloaded ? 0.46 : 0.78)))
            }
            .buttonStyle(CapsulePressStyle())
            .disabled(isDownloaded)
            .opacity(isDownloaded ? 0.62 : 1)
        } else {
            MonoIcon(icon: .playerDownload, size: 16, color: CapsuleStyle.inkSoft, lineWidth: 1.6)
                .frame(width: 36, height: 36)
                .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.5)))
                .opacity(0.4)
        }
    }

    // MARK: - 歌词阶段

    func capsuleLyricsStage(geometry: GeometryProxy) -> some View {
        let horizontalPadding = DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 18
        let maxWidth = min(geometry.size.width - horizontalPadding * 2, DeviceLayout.usesExpandedLayout ? 660 : 480)

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                capsuleLyricsToggle

                Spacer(minLength: 0)

                if let song = player.currentSong {
                    LikeButton(
                        songId: song.id,
                        isQQMusic: song.isQQMusic,
                        song: song,
                        size: 20,
                        activeColor: CapsuleStyle.coral,
                        inactiveColor: CapsuleStyle.inkSoft
                    )
                    .frame(width: 36, height: 36)
                    .background(capsulePillBackground(tint: CapsuleStyle.surfaceRaised.opacity(0.78)))
                }
            }

            if let song = player.currentSong {
                LyricsView(song: song, onBackgroundTap: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showLyrics.toggle()
                    }
                })
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(capsuleGlassPanel(cornerRadius: 30, tint: CapsuleStyle.surface.opacity(0.76)))
            } else {
                Color.clear
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 底部控件舱(单一 Capsule Deck)

    var capsuleControlDeck: some View {
        VStack(spacing: 14) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, 6)
            }

            // 进度条(平铺,无玻璃外壳)
            capsuleProgressStrip

            // 主控胶囊:循环 / 上一 / 大播放 / 下一 / 队列
            capsuleTransportBar
        }
    }

    var capsuleProgressStrip: some View {
        PlaybackTimeReader { currentTime, duration in
            VStack(spacing: 6) {
                FullScreenPlayerView.WaveformProgressBar(
                    currentTime: Binding(
                        get: { isDraggingSlider ? dragTimeValue : currentTime },
                        set: { _ in }
                    ),
                    duration: duration,
                    color: CapsuleStyle.accent,
                    trackOpacity: 0.14,
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
                .frame(height: 26)

                HStack {
                    capsuleTimeChip(formatTime(isDraggingSlider ? dragTimeValue : currentTime), alignment: .leading)
                    Spacer(minLength: 12)
                    capsuleTimeChip(formatTime(duration), alignment: .trailing)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    func capsuleTimeChip(_ text: String, alignment: Alignment = .center) -> some View {
        Text(text)
            .font(CapsuleStyle.labelFont(11, weight: .semibold))
            .foregroundStyle(CapsuleStyle.inkMuted)
            .monospacedDigit()
            .lineLimit(1)
            .frame(minWidth: 44, alignment: alignment)
    }

    var capsuleTransportBar: some View {
        HStack(spacing: 10) {
            capsuleTransportSideButton(icon: player.mode.monoIcon, tint: CapsuleStyle.inkSoft) {
                player.switchMode()
            }

            capsuleTransportSideButton(icon: .previous, tint: CapsuleStyle.ink, iconSize: 20) {
                player.previous()
            }

            capsuleMainPlayButton

            capsuleTransportSideButton(icon: .next, tint: CapsuleStyle.ink, iconSize: 20) {
                player.next()
            }

            capsuleTransportSideButton(icon: .list, tint: CapsuleStyle.inkSoft) {
                showPlaylist = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(CapsuleStyle.surface.opacity(0.82))
                .background(.ultraThinMaterial, in: Capsule())
        )
        .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.64), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 12)
        .shadow(color: CapsuleStyle.accent.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    func capsuleTransportSideButton(
        icon: MonoIcon.IconType,
        tint: Color,
        iconSize: CGFloat = 18,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: iconSize, color: tint, lineWidth: 1.65)
                .frame(width: 44, height: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(CapsulePressStyle())
    }

    var capsuleMainPlayButton: some View {
        Button(action: { player.togglePlayPause() }) {
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.accent,
                                CapsuleStyle.accent.opacity(0.88),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 72, height: 52)
                    .overlay(Capsule().stroke(Color.white.opacity(0.38), lineWidth: 1))
                    .shadow(color: CapsuleStyle.accent.opacity(0.32), radius: 12, x: 0, y: 7)

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CapsuleStyle.onAccent))
                        .scaleEffect(1.05)
                } else {
                    MonoIcon(icon: player.isPlaying ? .pause : .play, size: 28, color: CapsuleStyle.onAccent, lineWidth: 1.8)
                }
            }
        }
        .buttonStyle(CapsulePressStyle())
        .scaleEffect(player.isPlaying ? 1 : 0.97)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: player.isPlaying)
    }

    // MARK: - 通用面板/胶囊背景

    func capsuleGlassPanel(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CapsuleStyle.hairline.opacity(0.68), lineWidth: 1)
            )
            .shadow(color: CapsuleStyle.accent.opacity(0.06), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 7)
    }

    func capsulePillBackground(tint: Color) -> some View {
        Capsule()
            .fill(tint)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(CapsuleStyle.hairline.opacity(0.6), lineWidth: 0.8))
    }

}
