import SwiftUI
import FFmpegSwiftSDK

extension ClassicPlayerLayout {
    // MARK: - 子视图

    @ViewBuilder
    func asideDefaultPlayerContent(geometry: GeometryProxy) -> some View {
        let usesWideLayout = geometry.size.width >= 560 && geometry.size.width > geometry.size.height

        if (DeviceLayout.usesExpandedLayout && geometry.size.width >= 760) || usesWideLayout {
            asideWidePlayerContent(geometry: geometry)
        } else {
            asidePhonePlayerContent(geometry: geometry)
        }
    }

    func asidePhonePlayerContent(geometry: GeometryProxy) -> some View {
        let compactHeight = geometry.size.height < 740
        let horizontalPadding: CGFloat = compactHeight ? 22 : 24
        let widthBound = max(190, geometry.size.width - horizontalPadding * 2)
        let heightBound = geometry.size.height * (compactHeight ? 0.35 : 0.41)
        let asideArtworkMaxSize: CGFloat = DeviceLayout.usesExpandedLayout ? 480 : 380
        let artworkSize = min(asideArtworkMaxSize, min(widthBound, heightBound))
        let sectionSpacing: CGFloat = compactHeight ? 12 : 18

        return VStack(spacing: 0) {
            asideHeaderView
                .padding(.top, DeviceLayout.headerTopPadding)

            Spacer(minLength: compactHeight ? 6 : 14)

            asidePlaybackStage(size: artworkSize)

            Spacer(minLength: compactHeight ? 9 : 16)

            VStack(spacing: sectionSpacing) {
                asideTrackSummary
                asideProgressSection
                asideTransportBar
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, max(DeviceLayout.safeAreaBottom + 10, compactHeight ? 18 : 26))
        }
    }

    func asideWidePlayerContent(geometry: GeometryProxy) -> some View {
        let isCompactWide = !DeviceLayout.usesExpandedLayout
        let horizontalPadding: CGFloat = isCompactWide ? 28 : 54
        let columnSpacing: CGFloat = isCompactWide ? 28 : 52
        let artworkSize = min(
            isCompactWide ? 320 : 500,
            min(
                geometry.size.width * (isCompactWide ? 0.36 : 0.46),
                geometry.size.height * (isCompactWide ? 0.64 : 0.58)
            )
        )

        return VStack(spacing: 0) {
            asideHeaderView
                .padding(.top, DeviceLayout.headerTopPadding)

            HStack(spacing: columnSpacing) {
                asidePlaybackStage(size: artworkSize)

                VStack(spacing: isCompactWide ? 16 : 24) {
                    asideTrackSummary
                    asideProgressSection
                    asideTransportBar
                }
                .frame(maxWidth: 470)
            }
            .frame(maxWidth: 1080, maxHeight: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(
                .bottom,
                max(DeviceLayout.safeAreaBottom + (isCompactWide ? 6 : 18), isCompactWide ? 12 : 34)
            )
        }
    }

    var asideHeaderView: some View {
        HStack(spacing: 12) {
            classicDismissButton

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    .foregroundColor(contentColor)

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 190)

            Spacer(minLength: 0)

            asideHeaderIconButton(
                icon: .more,
                accessibilityLabel: String(localized: "player_more_title")
            ) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    showMoreMenu.toggle()
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    @ViewBuilder
    func asidePlaybackStage(size: CGFloat) -> some View {
        if showLyrics, let song = player.currentSong {
            LyricsView(song: song, onBackgroundTap: {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    showLyrics = false
                }
            })
            .frame(width: size, height: size)
            .transition(.opacity)
        } else {
            artworkTile(size: size)
                .contentShape(RoundedRectangle(cornerRadius: classicArtworkCornerRadius, style: .continuous))
                .onTapWithHaptic {
                    guard player.currentSong != nil else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        showLyrics = true
                    }
                }
                .accessibilityLabel(String(localized: "settings_lyrics"))
                .accessibilityAddTraits(.isButton)
                .accessibilityHidden(player.currentSong == nil)
                .frame(width: size, height: size)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 100 { dismiss() }
                        }
                )
                .transition(.opacity)
        }
    }

    @ViewBuilder
    var asideTrackSummary: some View {
        if showLyrics, player.currentSong != nil {
            lyricsModeSongInfo
        } else {
            asideTrackInfo
        }
    }

    var asideTrackInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(player.currentSong?.name ?? "")
                    .monoPlayerDisplayFont(
                        size: 27,
                        weight: .semibold,
                        fallback: .system(size: 27, weight: .semibold, design: .default)
                    )
                    .foregroundColor(contentColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 4)

                if let song = player.currentSong {
                    LikeButton(
                        songId: song.id,
                        isQQMusic: song.isQQMusic,
                        song: song,
                        size: 23,
                        activeColor: .red,
                        inactiveColor: contentColor
                    )
                    .frame(width: 44, height: 44)
                }
            }

            HStack(spacing: 8) {
                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? String(localized: "search_unknown_artist"))
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundColor(secondaryContentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .disabled(player.currentSong == nil)

                Spacer(minLength: 6)

                asideQualityButton

                if player.currentSong != nil {
                    asideInlineIconButton(
                        icon: .comment,
                        accessibilityLabel: String(localized: "comment_title")
                    ) {
                        showComments = true
                    }
                }

                if AppConfig.Features.downloadEnabled, let song = player.currentSong {
                    let isDownloaded = downloadManager.isDownloaded(songId: song.id)

                    asideInlineIconButton(
                        icon: .playerDownload,
                        accessibilityLabel: String(localized: "song_download")
                    ) {
                        if !isDownloaded {
                            showDownloadSheet = true
                        }
                    }
                    .disabled(isDownloaded)
                    .opacity(isDownloaded ? 0.46 : 1)
                }
            }
        }
    }

    var asideProgressSection: some View {
        PlaybackTimeReader { currentTime, duration in
            VStack(spacing: 4) {
                asideProgressRail(currentTime: currentTime, duration: duration)

                HStack {
                    Text(formatTime(isDraggingSlider ? dragTimeValue : currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundColor(secondaryContentColor)
                .monospacedDigit()
            }
        }
    }

    func asideProgressRail(currentTime: Double, duration publishedDuration: Double) -> some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let rawDuration = publishedDuration
            let duration = rawDuration.isFinite && rawDuration > 0 ? rawDuration : 0
            let rawDisplayedTime = isDraggingSlider ? dragTimeValue : currentTime
            let displayedTime = rawDisplayedTime.isFinite ? rawDisplayedTime : 0
            let progress = duration > 0 ? min(max(displayedTime / duration, 0), 1) : 0
            let progressX = width * CGFloat(progress)
            let railHeight: CGFloat = isDraggingSlider ? 6 : 4
            let thumbSize: CGFloat = isDraggingSlider ? 14 : 8
            let thumbOffset = min(
                max(progressX - thumbSize / 2, 0),
                max(width - thumbSize, 0)
            )

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(contentColor.opacity(colorScheme == .dark ? 0.18 : 0.1))
                    .frame(height: 4)

                if progress > 0 {
                    Capsule(style: .continuous)
                        .fill(asideCoverAccent)
                        .frame(
                            width: max(progressX, railHeight),
                            height: railHeight
                        )
                }

                if duration > 0 {
                    if isDraggingSlider {
                        Circle()
                            .fill(asideCoverAccent.opacity(0.16))
                            .frame(width: 26, height: 26)
                            .offset(x: thumbOffset - 6)
                    }

                    Circle()
                        .fill(asideCoverAccent)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12),
                            radius: isDraggingSlider ? 3 : 1.5,
                            y: 1
                        )
                        .offset(x: thumbOffset)
                }
            }
            .frame(width: width, height: geometry.size.height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        isDraggingSlider = true
                        let ratio = min(max(value.location.x / width, 0), 1)
                        dragTimeValue = Double(ratio) * duration
                    }
                    .onEnded { value in
                        guard duration > 0 else {
                            isDraggingSlider = false
                            return
                        }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        let target = Double(ratio) * duration
                        dragTimeValue = target
                        isDraggingSlider = false
                        player.seek(to: target)
                    }
            )
        }
        .frame(height: 28)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isDraggingSlider)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "播放进度"))
        .accessibilityValue(
            "\(formatTime(isDraggingSlider ? dragTimeValue : currentTime)) / \(formatTime(publishedDuration))"
        )
        .accessibilityAdjustableAction { direction in
            let duration = publishedDuration
            guard duration.isFinite, duration > 0 else { return }
            let rawCurrent = isDraggingSlider ? dragTimeValue : currentTime
            let current = rawCurrent.isFinite ? rawCurrent : 0
            let step = max(5, min(15, duration * 0.01))

            switch direction {
            case .increment:
                player.seek(to: min(current + step, duration))
            case .decrement:
                player.seek(to: max(current - step, 0))
            @unknown default:
                break
            }
        }
    }

    var asideTransportBar: some View {
        let playButtonSize: CGFloat = DeviceLayout.usesExpandedLayout ? 72 : 68

        return HStack(spacing: 0) {
            asideTransportIconButton(
                icon: player.mode.monoIcon,
                accessibilityLabel: player.mode.displayName
            ) {
                player.switchMode()
            }

            Spacer(minLength: 0)

            Button(action: { player.previous() }) {
                MonoIcon(icon: .previous, size: 29, color: contentColor)
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "上一首"))

            Spacer(minLength: 0)

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(asideCoverAccent)
                        .shadow(
                            color: asideCoverAccent.opacity(colorScheme == .dark ? 0.18 : 0.24),
                            radius: 7,
                            y: 4
                        )

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: asideCoverAccentForeground)
                            )
                    } else {
                        MonoIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 29,
                            color: asideCoverAccentForeground
                        )
                    }
                }
                .frame(width: playButtonSize, height: playButtonSize)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            .accessibilityLabel(
                player.isPlaying
                    ? String(localized: "暂停")
                    : String(localized: "action_play")
            )

            Spacer(minLength: 0)

            Button(action: { player.next() }) {
                MonoIcon(icon: .next, size: 29, color: contentColor)
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .accessibilityLabel(String(localized: "playback_next_track"))

            Spacer(minLength: 0)

            asideTransportIconButton(
                icon: .list,
                accessibilityLabel: String(localized: "player_queue")
            ) {
                showPlaylist = true
            }
        }
    }

    func refreshAsideCoverAccent() {
        guard !isThemedClassic else { return }
        asideCoverColors.extract(
            from: player.currentSong?.coverUrl?.sized(300).absoluteString
        )
    }

    func asideHeaderIconButton(
        icon: MonoIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 20, color: contentColor)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

    var asideQualityButton: some View {
        Button(action: { showQualitySheet = true }) {
            Text(player.qualityButtonText)
                .font(.system(size: 9.5, weight: .semibold, design: .default))
                .tracking(0.2)
                .foregroundColor(contentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(contentColor.opacity(0.045))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(contentColor.opacity(0.16), lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .playerQualitySelectionAvailability()
    }

    func asideInlineIconButton(
        icon: MonoIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 18, color: secondaryContentColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(contentColor.opacity(0.055))
                )
                .contentShape(Circle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

    func asideTransportIconButton(
        icon: MonoIcon.IconType,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 19, color: secondaryContentColor)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

}
