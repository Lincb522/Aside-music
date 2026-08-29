import SwiftUI

private struct SongRowLoadingIndicator: View {
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            AppFrameRate.animationTimeline(
                maximumFramesPerSecond: 24,
                paused: reduceMotion
            )
        ) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 0.9) / 0.9

            ZStack {
                Circle()
                    .stroke(color.opacity(0.22), lineWidth: 1.8)

                Circle()
                    .trim(from: 0.08, to: 0.66)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(reduceMotion ? -54 : phase * 360 - 54))
            }
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
}

struct SongListRow: View {
    
    @ObservedObject private var playback = SongRowPlaybackModel.shared
    @ObservedObject private var rowDownloads = SongRowDownloadModel.shared
    @ObservedObject var unavailableSongs = UnavailableSongsManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var likeManager = LikeManager.shared
    let song: Song
    let index: Int
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var onArtistTap: ((Int) -> Void)? = nil
    var onDetailTap: ((Song) -> Void)? = nil
    var onAlbumTap: ((Int) -> Void)? = nil
    var onTap: (() -> Void)? = nil
    var horizontalPadding: CGFloat? = nil
    
    @State private var showAddToPlaylist = false
    @State private var activeQuickAction: QuickAction?
    @State private var feedbackAction: QuickAction?
    @State private var feedbackPhase: Int = 0
    
    // qcm详情页导航状态
    @State private var showQQArtistDetail = false
    @State private var showQQAlbumDetail = false
    
    var isCurrent: Bool {
        playback.isCurrent(song: song)
    }

    private var isLoadingPlayback: Bool {
        playback.isLoading(song: song)
    }

    private var isPlaybackEmphasized: Bool {
        isCurrent || isLoadingPlayback
    }

    /// aside 默认主题（编辑部风格分支）
    private var isAsideTheme: Bool {
        GlobalThemeId.persistedOrDefault == .default
    }
    
    /// 灰色条件：
    /// - 无版权歌曲始终灰色
    /// - VIP 限制歌曲无 VIP Cookie 时灰色
    /// - 未购买的数字专辑直接灰色（VIP 也不能解锁，需单独购买）
    /// - 运行时记录的播放失败（兜底全失败）也显示灰色
    var isGrayed: Bool {
        if song.isNoCopyright { return true }
        if song.isVIPRestricted { return !APIService.shared.hasVIPCookie }
        if song.isUnpurchasedDigitalAlbum { return true }
        if unavailableSongs.isUnavailable(song: song) { return true }
        return false
    }
    
    private struct Theme {
        static let text = Color.monoTextPrimary
        static let secondaryText = Color.monoTextSecondary
        static var accent: Color {
            if SignalStyle.isActive { return SignalStyle.accent }
            if MangaStyle.isActive { return MangaStyle.accentPink }
            if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
            if MujiStyle.isActive { return MujiStyle.clay }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            if CapsuleStyle.isActive { return CapsuleStyle.accent }
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            return Color.monoTextPrimary
        }
    }

    private enum QuickAction: Hashable {
        case like
        case addToQueue
        case download

        var badgeIcon: MonoIcon.IconType {
            switch self {
            case .like:
                return .liked
            case .addToQueue:
                return .musicNoteList
            case .download:
                return .download
            }
        }

        var badgeTitle: String {
            switch self {
            case .like:
                return String(localized: "喜欢")
            case .addToQueue:
                return String(localized: "queue_added_short")
            case .download:
                return String(localized: "download_added_short")
            }
        }
    }

    private struct ShortLinkPayload {
        let playUrl: String
        let qqQualityRaw: String?
        let qishuiQualityRaw: String?
    }

    private struct QuickActionButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.88 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
        }
    }

    private var isDownloaded: Bool {
        rowDownloads.isDownloaded(song: song)
    }

    private var isLiked: Bool {
        likeManager.isLiked(id: song.id, isQQMusic: song.isQQMusic)
    }

    private var isLocalSong: Bool {
        song.isLocal
    }
    
    private var ncmBrandColor: Color {
        MusicSource.netease.themedBadgeColor
    }
    
    private var qcmBrandColor: Color {
        MusicSource.qqmusic.themedBadgeColor
    }
    
    private var qsmBrandColor: Color {
        MusicSource.qishui.themedBadgeColor
    }

    private var kcmBrandColor: Color {
        MusicSource.kugou.themedBadgeColor
    }

    private var appleMusicBrandColor: Color {
        MusicSource.appleMusic.themedBadgeColor
    }

    private var localBrandColor: Color {
        MusicSource.local.themedBadgeColor
    }

    private var quickActionButtonSize: CGFloat {
        if SignalStyle.isActive { return 31 }
        if MangaStyle.isActive { return 32 }
        if PetWhiteStyle.isActive { return 26 }
        if MujiStyle.isActive { return 31 }
        if NeumorphicStyle.isActive { return 32 }
        if CapsuleStyle.isActive { return 31 }
        if SequoiaStyle.isActive { return 32 }
        return 30
    }

    private var quickActionButtonCornerRadius: CGFloat {
        if SignalStyle.isActive { return 9 }
        if MangaStyle.isActive { return 11 }
        if PetWhiteStyle.isActive { return 11 }
        if MujiStyle.isActive { return 10 }
        if NeumorphicStyle.isActive { return 13 }
        if CapsuleStyle.isActive { return 13 }
        if SequoiaStyle.isActive { return 12 }
        return quickActionButtonSize / 2
    }

    private func quickActionTint(for kind: QuickAction) -> Color {
        switch kind {
        case .like:
            if SignalStyle.isActive { return SignalStyle.red }
            if MangaStyle.isActive { return MangaStyle.accentPink }
            if PetWhiteStyle.isActive { return PetWhiteStyle.blush }
            if MujiStyle.isActive { return Color.red.opacity(0.86) }
            if NeumorphicStyle.isActive { return Color.red.opacity(0.88) }
            if CapsuleStyle.isActive { return Color.red.opacity(0.86) }
            if SequoiaStyle.isActive { return Color.red.opacity(0.88) }
            return .red
        case .addToQueue:
            if SignalStyle.isActive { return SignalStyle.accent }
            if MangaStyle.isActive { return MangaStyle.labelYellow }
            if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
            if MujiStyle.isActive { return MujiStyle.clay }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            if CapsuleStyle.isActive { return CapsuleStyle.amber }
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            return Color.monoTextPrimary
        case .download:
            if SignalStyle.isActive { return SignalStyle.aqua }
            if MangaStyle.isActive { return MangaStyle.decoBlue }
            if PetWhiteStyle.isActive { return PetWhiteStyle.sky }
            if MujiStyle.isActive { return MujiStyle.indigo }
            if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
            if CapsuleStyle.isActive { return CapsuleStyle.cyan }
            if SequoiaStyle.isActive { return SequoiaStyle.aqua }
            return Color.monoTextPrimary
        }
    }

    private func quickActionIconColor(kind: QuickAction, isDisabled: Bool) -> Color {
        if kind == .like {
            if isLiked {
                return quickActionTint(for: kind).opacity(isDisabled ? 0.34 : 1)
            }
            if MangaStyle.isActive {
                return MangaStyle.strokeInk.opacity(isDisabled ? 0.34 : 0.72)
            }
            if PetWhiteStyle.isActive {
                return PetWhiteStyle.ink.opacity(isDisabled ? 0.34 : 0.72)
            }
            if SignalStyle.isActive {
                return SignalStyle.inkSoft.opacity(isDisabled ? 0.34 : 0.74)
            }
            return Theme.secondaryText.opacity(isDisabled ? 0.34 : 0.62)
        }
        if SignalStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.34 : 0.96)
        }
        if MangaStyle.isActive {
            return MangaStyle.strokeInk.opacity(isDisabled ? 0.34 : 1)
        }
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.ink.opacity(isDisabled ? 0.34 : 1)
        }
        if MujiStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.34 : 0.95)
        }
        if NeumorphicStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.36 : 1)
        }
        if CapsuleStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.36 : 1)
        }
        if SequoiaStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.34 : 0.96)
        }
        return isDisabled ? .monoTextSecondary.opacity(0.45) : .monoTextPrimary
    }

    private var rowCornerRadius: CGFloat {
        if SignalStyle.isActive { return 10 }
        if MangaStyle.isActive { return 2 }
        if PetWhiteStyle.isActive { return 21 }
        if MujiStyle.isActive { return 10 }
        if NeumorphicStyle.isActive { return 18 }
        if CapsuleStyle.isActive { return 19 }
        if SequoiaStyle.isActive { return 17 }
        return 12
    }

    private var coverCornerRadius: CGFloat {
        if SignalStyle.isActive { return 8 }
        if MangaStyle.isActive { return 2 }
        if PetWhiteStyle.isActive { return 14 }
        if MujiStyle.isActive { return 6 }
        if NeumorphicStyle.isActive { return 14 }
        if CapsuleStyle.isActive { return 14 }
        if SequoiaStyle.isActive { return 13 }
        return 12
    }

    private var rowCoverSize: CGFloat {
        if SignalStyle.isActive { return 46 }
        if MangaStyle.isActive { return 47 }
        if PetWhiteStyle.isActive { return 44 }
        if MujiStyle.isActive { return 46 }
        if NeumorphicStyle.isActive { return 47 }
        if CapsuleStyle.isActive { return 46 }
        return 48
    }

    private var rowCoverURL: URL? {
        song.coverUrl?.sized(180)
    }

    private var rowContentSpacing: CGFloat {
        if SignalStyle.isActive { return 9 }
        if MangaStyle.isActive { return 9 }
        if PetWhiteStyle.isActive { return 7 }
        if MujiStyle.isActive { return 9 }
        if CapsuleStyle.isActive { return 9 }
        return 10
    }

    private var rowHorizontalPadding: CGFloat {
        if let horizontalPadding = horizontalPadding {
            // 纯白极简列表以 0 边距嵌入卡片，行内容需要最小内边距，
            // 否则序号会顶在当前播放高亮的圆角边缘上
            if MinimalWhiteStyle.isActive { return max(horizontalPadding, 10) }
            return horizontalPadding
        }
        if MangaStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        if SignalStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        if PetWhiteStyle.isActive { return DeviceLayout.viewHorizontalPadding }
        if MujiStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        if NeumorphicStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        if CapsuleStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        return DeviceLayout.viewHorizontalPadding
    }

    private var rowIndexWidth: CGFloat {
        if SignalStyle.isActive { return 19 }
        if MangaStyle.isActive { return 15 }
        if PetWhiteStyle.isActive { return 22 }
        if MujiStyle.isActive { return 14 }
        if CapsuleStyle.isActive { return 14 }
        return 16
    }

    private func capsuleSongResultRow(coverSize: CGFloat) -> some View {
        HStack(spacing: 10) {
            Button {
                onTap?()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        if isSelecting {
                            MonoSymbolIcon(
                                name: isSelected ? "checkmark.circle.fill" : "circle",
                                size: 18,
                                color: isSelected ? CapsuleStyle.accent : CapsuleStyle.inkMuted.opacity(0.46)
                            )
                        } else if isLoadingPlayback {
                            SongRowLoadingIndicator(color: CapsuleStyle.accent)
                        } else {
                            Text(String(format: "%02d", index + 1))
                                .font(CapsuleStyle.labelFont(10.5, weight: .black))
                                .foregroundStyle(isCurrent ? CapsuleStyle.onAccent : CapsuleStyle.inkMuted)
                                .monospacedDigit()
                        }
                    }
                    .frame(width: 34, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(isCurrent ? CapsuleStyle.accent : (isLoadingPlayback ? CapsuleStyle.accent.opacity(0.14) : CapsuleStyle.surfaceTint.opacity(0.54)))
                    )

                    CachedAsyncImage(
                        url: rowCoverURL,
                        width: coverSize,
                        height: coverSize,
                        placeholder: { CapsuleStyle.surfaceTint.opacity(0.72) },
                        transition: .identity
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(isPlaybackEmphasized ? CapsuleStyle.accent.opacity(0.46) : CapsuleStyle.separator.opacity(0.42), lineWidth: 0.7)
                    )
                    .overlay {
                        if isPlaybackEmphasized && !isSelecting {
                            ZStack {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.black.opacity(0.35))
                                if isLoadingPlayback {
                                    SongRowLoadingIndicator(color: .white)
                                } else {
                                    PlayingVisualizerView(isAnimating: playback.isPlaying, color: .white)
                                        .scaleEffect(0.82)
                                }
                            }
                        }
                    }
                    .opacity(isGrayed ? 0.4 : 1.0)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(song.name)
                            .font(CapsuleStyle.bodyFont(15.5, weight: isPlaybackEmphasized ? .bold : .semibold))
                            .foregroundStyle(CapsuleStyle.ink)
                            .lineLimit(1)
                            .layoutPriority(3)

                        Text(songArtistAlbumText)
                            .font(CapsuleStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(CapsuleStyle.inkSoft)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(2)

                        songBadgeRail
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.985, opacity: 0.88))
            .disabled(onTap == nil)

            if !isSelecting {
                quickActionCluster(spacing: 6)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background {
            if isPlaybackEmphasized {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CapsuleStyle.accent.opacity(0.16),
                                CapsuleStyle.cyan.opacity(0.08),
                                CapsuleStyle.surfaceRaised.opacity(0.7),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 2)
                    .opacity(isLoadingPlayback ? 0.72 : 1)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CapsuleStyle.separator.opacity(0.38))
                .frame(height: 0.7)
                .padding(.leading, 104)
                .padding(.trailing, 10)
        }
        .contentShape(Rectangle())
    }

    var body: some View {
        let _ = settings.globalThemeRevision
        let coverSize = rowCoverSize

        Group {
            if CapsuleStyle.isActive {
                capsuleSongResultRow(coverSize: coverSize)
            } else {
                HStack(spacing: PetWhiteStyle.isActive ? 6 : 12) {
                    Button {
                        onTap?()
                    } label: {
                        HStack(spacing: rowContentSpacing) {
                            ZStack {
                                if isSelecting {
                                    MonoSymbolIcon(
                                        name: isSelected ? "checkmark.circle.fill" : "circle",
                                        size: 18,
                                        color: isSelected ? Theme.accent : Theme.secondaryText.opacity(0.4)
                                    )
                                } else if isAsideTheme && isLoadingPlayback {
                                    SongRowLoadingIndicator(color: .monoAccent)
                                        .frame(width: 16, height: 16)
                                } else if isAsideTheme && isCurrent {
                                    // aside：正在播放时序号位换成律动条，避免高亮元素压住序号
                                    PlayingVisualizerView(isAnimating: playback.isPlaying, color: .monoAccent)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Text(String(format: "%02d", index + 1))
                                        .font(indexFont)
                                        .foregroundColor(isPlaybackEmphasized ? Theme.accent : Theme.secondaryText.opacity(0.4))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                            }
                            .frame(width: rowIndexWidth)

                            CachedAsyncImage(
                                url: rowCoverURL,
                                width: coverSize,
                                height: coverSize,
                                placeholder: { Color.gray.opacity(0.1) },
                                transition: .identity
                            )
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize, height: coverSize)
                            .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
                            .overlay {
                                if MangaStyle.isActive {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                                } else if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
                                } else if PetWhiteStyle.isActive {
                                    RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                                        .stroke(PetWhiteStyle.stroke.opacity(0.72), lineWidth: 1.4)
                                } else if NeumorphicStyle.isActive {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(NeumorphicStyle.separator.opacity(0.38), lineWidth: 0.6)
                                } else if CapsuleStyle.isActive {
                                    RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                                        .stroke(CapsuleStyle.separator.opacity(0.42), lineWidth: 0.65)
                                } else if SequoiaStyle.isActive {
                                    RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.42), lineWidth: 0.55)
                                } else if SignalStyle.isActive {
                                    RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                                        .stroke(isPlaybackEmphasized ? SignalStyle.accent.opacity(0.34) : SignalStyle.separator.opacity(0.72), lineWidth: 0.8)
                                }
                            }
                            .overlay {
                                // aside 的播放标记已移到序号位，封面不再压暗
                                if isPlaybackEmphasized && !isSelecting && !isAsideTheme {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                                            .fill(Color.black.opacity(0.35))
                                        if isLoadingPlayback {
                                            SongRowLoadingIndicator(color: .white)
                                        } else {
                                            PlayingVisualizerView(isAnimating: playback.isPlaying, color: .white)
                                                .scaleEffect(0.85)
                                        }
                                    }
                                }
                            }
                            .opacity(isGrayed ? 0.4 : 1.0)

                            VStack(alignment: .leading, spacing: songInfoVerticalSpacing) {
                                Text(song.name)
                                    .font(songTitleFont)
                                    .foregroundColor(songTitleColor)
                                    .lineLimit(1)
                                    .layoutPriority(3)

                                Text(songArtistAlbumText)
                                    .font(songArtistAlbumFont)
                                    .foregroundColor(songArtistAlbumColor)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .layoutPriority(2)

                                songBadgeRail
                                    .layoutPriority(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(2)

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.98, opacity: 0.8))
                    .disabled(onTap == nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(PetWhiteStyle.isActive ? 3 : 0)

                    if !isSelecting {
                        quickActionCluster(spacing: PetWhiteStyle.isActive ? 5 : 8)
                    }
                }
                .padding(.horizontal, PetWhiteStyle.isActive ? 6 : rowHorizontalPadding)
                .padding(.vertical, PetWhiteStyle.isActive ? 10 : 8)
                .background {
                    if PetWhiteStyle.isActive {
                        petWhiteRowBackground
                    } else if isPlaybackEmphasized {
                        currentRowBackground
                            .opacity(isLoadingPlayback ? 0.72 : 1)
                    } else if SignalStyle.isActive {
                        SignalSurfaceBackground(
                            cornerRadius: rowCornerRadius,
                            elevated: false,
                            pressed: true,
                            fill: SignalStyle.screen.opacity(0.72)
                        )
                        .padding(.horizontal, 5)
                    }
                }
                .padding(.horizontal, PetWhiteStyle.isActive ? rowHorizontalPadding : 0)
                .padding(.vertical, PetWhiteStyle.isActive ? 5 : 0)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            SongArtworkFallbackRegistry.shared.register([song])
        }
        .contextMenu {
            Button {
                playback.playNext(song: song)
            } label: {
                Label(LocalizedStringKey("action_play_next"), systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                playback.addToQueue(song: song)
            } label: {
                Label(LocalizedStringKey("action_add_to_queue"), systemImage: "text.append")
            }
            
            Divider()
            
            // 下载选项（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
            if AppConfig.Features.downloadEnabled,
               !isLocalSong,
               !song.isAppleMusic {
                if rowDownloads.isDownloaded(songId: song.id) {
                    Button(role: .destructive) {
                        rowDownloads.deleteDownload(song: song)
                    } label: {
                        Label(String(localized: "song_delete_download"), systemImage: "trash")
                    }
                } else {
                    Button {
                        downloadSong()
                    } label: {
                        Label(String(localized: "song_download"), systemImage: "arrow.down.circle")
                    }
                }
            }
            
            // 添加到本地歌单
            Button {
                showAddToPlaylist = true
            } label: {
                Label(String(localized: "song_add_to_playlist"), systemImage: "text.badge.plus")
            }
            
            Divider()
            
            if !isLocalSong, !song.isAppleMusic {
                // 歌手 — 分源处理
                if song.isQQMusic {
                    // qcm 歌曲：跳转到 qcm 歌手详情页
                    if let artistMid = song.qqArtistMid, !artistMid.isEmpty,
                       song.ar?.first?.name != nil {
                        Button {
                            showQQArtistDetail = true
                        } label: {
                            Label(LocalizedStringKey("action_artist"), systemImage: "person.circle")
                        }
                    }
                } else {
                    // ncm 歌曲：跳转到 ncm 歌手详情页
                    if let artistId = song.ar?.first?.id {
                        Button {
                            onArtistTap?(artistId)
                        } label: {
                            Label(LocalizedStringKey("action_artist"), systemImage: "person.circle")
                        }
                    }
                }
            }
            
            if !isLocalSong, !song.isAppleMusic {
                // 专辑 — 分源处理
                if song.isQQMusic {
                    // qcm 歌曲：跳转到 qcm 专辑详情页
                    if let albumMid = song.qqAlbumMid, !albumMid.isEmpty {
                        Button {
                            showQQAlbumDetail = true
                        } label: {
                            Label(String(localized: "song_view_album"), systemImage: "square.stack")
                        }
                    }
                } else {
                    // ncm 歌曲：跳转到 ncm 专辑详情页
                    if let albumId = song.al?.id, albumId > 0 {
                        Button {
                            onAlbumTap?(albumId)
                        } label: {
                            Label(String(localized: "song_view_album"), systemImage: "square.stack")
                        }
                    }
                }
            }
            
            if !isLocalSong, !song.isAppleMusic {
                // 详情 — 分源处理
                Button {
                    onDetailTap?(song)
                } label: {
                    Label(LocalizedStringKey("action_details"), systemImage: "info.circle")
                }
            }
            
            if !isLocalSong, !song.isAppleMusic {
                Divider()
                
                Button {
                    copyShortPlayLink()
                } label: {
                    Label(String(localized: "song_copy_link"), systemImage: "link")
                }
            }
        }
        .themeRenderRowLayer()
        .monoSheet(isPresented: $showAddToPlaylist, preset: .standard){
            AddToPlaylistSheet(song: song)
        }
        .monoSheet(isPresented: likePlaylistPickerBinding, preset: .standard) {
            if let pendingSong = likeManager.pendingLikeSong {
                AddToPlaylistSheet(song: pendingSong)
            }
        }
        // qcm歌手详情页（使用 sheet 避免 lazy 容器中 navigationDestination 警告）
        .monoSheet(isPresented: $showQQArtistDetail, preset: .detail){
            if let artistMid = song.qqArtistMid, let artistName = song.ar?.first?.name {
                NavigationStack {
                    QQMusicDetailView(detailType: .artist(
                        mid: artistMid,
                        name: artistName,
                        coverUrl: nil
                    ))
                }
            }
        }
        // qcm专辑详情页
        .monoSheet(isPresented: $showQQAlbumDetail, preset: .detail){
            if let albumMid = song.qqAlbumMid {
                NavigationStack {
                    QQMusicDetailView(detailType: .album(
                        mid: albumMid,
                        name: song.al?.name ?? "",
                        coverUrl: song.al?.picUrl,
                        artistName: song.artistName
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private var currentRowBackground: some View {
        if SignalStyle.isActive {
            ZStack(alignment: .leading) {
                SignalSurfaceBackground(
                    cornerRadius: rowCornerRadius,
                    elevated: false,
                    pressed: true,
                    fill: SignalStyle.control
                )

                Circle()
                    .fill(SignalStyle.accent)
                    .frame(width: 5, height: 5)
                    .padding(.leading, 9)
            }
            .padding(.horizontal, 5)
        } else if MangaStyle.isActive {
            // 周刊印刷:朱红浅网点底 + 左侧墨条书签
            ZStack(alignment: .leading) {
                MangaCardBackground(cornerRadius: rowCornerRadius, elevated: true, tint: MangaStyle.bubblePink)

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(MangaStyle.accentPink)
                    .frame(width: 5, height: 30)
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 4)
        } else if MujiStyle.isActive {
            // Muji：不抬卡片，仅左侧一道陶土墨线 + 极淡纸色晕染
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(MujiStyle.clay.opacity(0.06))

                Rectangle()
                    .fill(MujiStyle.clay)
                    .frame(width: 2)
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 5)
        } else if NeumorphicStyle.isActive {
            ZStack(alignment: .leading) {
                NeumorphicSurfaceBackground(
                    cornerRadius: rowCornerRadius,
                    elevated: false,
                    pressed: true,
                    tint: Theme.accent.opacity(0.13),
                    lightweight: true
                )

                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 4, height: 24)
                    .padding(.leading, 7)
            }
            .padding(.horizontal, 5)
        } else if CapsuleStyle.isActive {
            ZStack(alignment: .leading) {
                CapsuleSurfaceBackground(
                    cornerRadius: rowCornerRadius,
                    elevated: true,
                    tint: CapsuleStyle.surfaceRaised
                )

                LinearGradient(
                    colors: [
                        Theme.accent.opacity(0.14),
                        CapsuleStyle.cyan.opacity(0.08),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous))

                Capsule()
                    .fill(LinearGradient(colors: CapsuleStyle.accentGradient, startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: 26)
                    .padding(.leading, 7)
            }
            .padding(.horizontal, 5)
        } else if SequoiaStyle.isActive {
            ZStack(alignment: .leading) {
                SequoiaSurfaceBackground(
                    cornerRadius: rowCornerRadius,
                    elevated: false,
                    fill: Theme.accent.opacity(0.075),
                    role: .selected
                )

                LinearGradient(
                    colors: [
                        Theme.accent.opacity(0.14),
                        SequoiaStyle.aqua.opacity(0.055),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous))

                Capsule()
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 3.5, height: 24)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 5, x: 0, y: 0)
            }
            .padding(.horizontal, 5)
        } else if PetWhiteStyle.isActive {
            petWhiteCurrentRowBackground
        } else if MinimalWhiteStyle.isActive {
            // 纯白极简：列表行以零边距嵌在卡片里，高亮必须与内容同宽、
            // 且不加左侧强调条（会压在序号上）——用整行淡色选中面 + 细描边
            RoundedRectangle(cornerRadius: MinimalWhiteStyle.compactRadius, style: .continuous)
                .fill(MinimalWhiteStyle.selectedFill.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: MinimalWhiteStyle.compactRadius, style: .continuous)
                        .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
                )
                .padding(.horizontal, 3)
        } else if isAsideTheme {
            // aside 编辑部风格：淡强调色水洗 + 贴边竖标，与播放队列弹层同语言，
            // 不再用玻璃渐变和辉光条，也不会贴到序号位
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
                    .fill(Color.monoAccent.opacity(0.07))

                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 24)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 8)
        } else {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.accent.opacity(0.12),
                                Theme.accent.opacity(0.01)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .monoGlass(cornerRadius: rowCornerRadius)

                RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Theme.accent.opacity(0.35),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.5
                    )

                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 3.5, height: 20)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 4, x: 0, y: 0)
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var petWhiteRowBackground: some View {
        if isPlaybackEmphasized {
            petWhiteCurrentRowBackground
                .opacity(isLoadingPlayback ? 0.72 : 1)
        } else {
            PetWhiteSurfaceBackground(
                cornerRadius: rowCornerRadius,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised.opacity(0.82),
                accent: PetWhiteStyle.mint
            )
        }
    }

    private var petWhiteCurrentRowBackground: some View {
        ZStack(alignment: .leading) {
            PetWhiteSurfaceBackground(
                cornerRadius: rowCornerRadius,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.butter
            )

            LinearGradient(
                colors: [
                    PetWhiteStyle.butter.opacity(0.55),
                    PetWhiteStyle.mint.opacity(0.20),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous))

            Capsule()
                .fill(PetWhiteStyle.dogOrange)
                .frame(width: 3.5, height: 24)
                .padding(.leading, 2)
        }
    }

    private var songInfoVerticalSpacing: CGFloat {
        if SignalStyle.isActive { return 3.5 }
        if MangaStyle.isActive { return 3.5 }
        if PetWhiteStyle.isActive { return 5 }
        if MujiStyle.isActive { return 3 }
        if NeumorphicStyle.isActive { return 3.5 }
        if CapsuleStyle.isActive { return 3.5 }
        if SequoiaStyle.isActive { return 3.5 }
        return 3
    }

    private var indexFont: Font {
        if SignalStyle.isActive { return SignalStyle.monoFont(11, weight: .semibold) }
        if MangaStyle.isActive { return MangaStyle.comicFont(13, weight: .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(11, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(11.5, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .medium) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var songTitleFont: Font {
        if SignalStyle.isActive { return SignalStyle.bodyFont(15, weight: isPlaybackEmphasized ? .bold : .semibold) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(16, weight: isPlaybackEmphasized ? .black : .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(15.5, weight: isPlaybackEmphasized ? .black : .bold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(15, weight: isPlaybackEmphasized ? .medium : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(15, weight: isPlaybackEmphasized ? .semibold : .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(15, weight: isPlaybackEmphasized ? .bold : .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: isPlaybackEmphasized ? .semibold : .medium) }
        return .system(size: 16, weight: isPlaybackEmphasized ? .bold : .medium)
    }

    private var songTitleColor: Color {
        if isGrayed { return Theme.secondaryText.opacity(0.4) }
        if isPlaybackEmphasized { return Theme.accent }
        if SignalStyle.isActive { return SignalStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return Theme.text
    }

    private var songArtistAlbumText: String {
        let albumName = song.al?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !albumName.isEmpty else { return song.artistName }
        return "\(song.artistName) · \(albumName)"
    }

    private var songArtistAlbumFont: Font {
        if SignalStyle.isActive {
            return SignalStyle.labelFont(11, weight: .medium)
        }
        if MangaStyle.isActive {
            return MangaStyle.comicFont(12, weight: .medium)
        }
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.labelFont(12, weight: .semibold)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: .medium)
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.labelFont(12, weight: .medium)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(12, weight: .regular)
        }
        return .system(size: 13)
    }

    private var songArtistAlbumColor: Color {
        if isGrayed { return Theme.secondaryText.opacity(0.3) }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return Theme.secondaryText
    }

    private var songBadgeRailSpacing: CGFloat {
        if SignalStyle.isActive { return 5 }
        if MangaStyle.isActive { return 5 }
        if PetWhiteStyle.isActive { return 5 }
        if MujiStyle.isActive { return 4 }
        if NeumorphicStyle.isActive { return 5 }
        if CapsuleStyle.isActive { return 5 }
        if SequoiaStyle.isActive { return 5 }
        return 4
    }

    @ViewBuilder
    private var songBadgeRail: some View {
        HStack(spacing: isAsideTheme ? 6 : songBadgeRailSpacing) {
            if song.isNoCopyright {
                songMetaBadge(String(localized: "song_no_copyright"), color: Theme.accent, fontSize: 7)
            }

            if song.isQQMusic {
                songMetaBadge("QCM", color: qcmBrandColor, kind: .platform)

                if let badge = song.qqMaxQuality?.badgeText {
                    songMetaBadge(badge, color: qcmBrandColor)
                }
            } else if song.isKugou {
                songMetaBadge("KCM", color: kcmBrandColor, kind: .platform)

                if let badge = song.qualityBadge {
                    songMetaBadge(badge, color: kcmBrandColor)
                }
            } else if song.isQishui {
                songMetaBadge("QSM", color: qsmBrandColor, kind: .platform)

                if let badge = song.qualityBadge {
                    songMetaBadge(badge, color: qsmBrandColor)
                }
            } else if song.isAppleMusic {
                songMetaBadge("AM", color: appleMusicBrandColor, kind: .platform)
            } else if isLocalSong {
                songMetaBadge("LOCAL", color: localBrandColor, kind: .platform)
            } else if let radioName = song.podcastRadioName {
                songMetaBadge(radioName.uppercased(), color: ncmBrandColor, maxWidth: 92, kind: .platform)
            } else {
                songMetaBadge("NCM", color: ncmBrandColor, kind: .platform)

                if let badge = song.qualityBadge {
                    let maxQ = song.maxQuality
                    if maxQ.isVIP || maxQ == .lossless || maxQ == .hires {
                        songMetaBadge(badge, color: ncmBrandColor, fontSize: maxQ.isBadgeChinese ? 7 : 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private enum MetaBadgeKind {
        case platform
        case quality
    }

    @ViewBuilder
    private func songMetaBadge(
        _ text: String,
        color: Color,
        fontSize: CGFloat = 8,
        maxWidth: CGFloat? = nil,
        kind: MetaBadgeKind = .quality
    ) -> some View {
        if isAsideTheme {
            asideMetaBadge(text, color: color, maxWidth: maxWidth, kind: kind)
        } else {
            Text(text)
                .font(songMetaBadgeFont(fontSize: fontSize))
                .foregroundColor(songMetaBadgeForeground(color))
                .lineLimit(1)
                .truncationMode(.tail)
                .tracking(MujiStyle.isActive ? 0.35 : 0)
                .padding(.horizontal, songMetaBadgeHorizontalPadding)
                .padding(.vertical, songMetaBadgeVerticalPadding)
                .frame(maxWidth: maxWidth, alignment: .leading)
                .background {
                    songMetaBadgeBackground(color)
                }
                .overlay {
                    songMetaBadgeStroke(color)
                }
        }
    }

    /// aside 编辑部风格：平台标识 = 平台色圆点 + 字距小字（去框），
    /// 音质标识 = 极细描边胶囊（去底色填充）
    @ViewBuilder
    private func asideMetaBadge(
        _ text: String,
        color: Color,
        maxWidth: CGFloat?,
        kind: MetaBadgeKind
    ) -> some View {
        switch kind {
        case .platform:
            HStack(spacing: 3.5) {
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)

                Text(text)
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(0.7)
                    .foregroundColor(Theme.secondaryText.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: maxWidth, alignment: .leading)

        case .quality:
            Text(text)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundColor(color.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 5.5)
                .padding(.vertical, 1.5)
                .overlay(Capsule().stroke(color.opacity(0.34), lineWidth: 0.8))
                .frame(maxWidth: maxWidth, alignment: .leading)
        }
    }

    private func songMetaBadgeFont(fontSize: CGFloat) -> Font {
        if SignalStyle.isActive {
            return SignalStyle.monoFont(max(fontSize + 0.5, 8), weight: .bold)
        }
        if MangaStyle.isActive {
            return MangaStyle.labelFont(max(fontSize + 1, 8), weight: .black)
        }
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.labelFont(max(fontSize + 1, 8), weight: .black)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(max(fontSize + 0.5, 8), weight: .semibold)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(max(fontSize + 0.5, 8), weight: .semibold)
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.labelFont(max(fontSize + 0.5, 8), weight: .bold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(max(fontSize + 0.5, 8), weight: .semibold)
        }
        return .system(size: fontSize, weight: .bold, design: .rounded)
    }

    private var songMetaBadgeHorizontalPadding: CGFloat {
        if SignalStyle.isActive { return 5.5 }
        if MangaStyle.isActive { return 5.5 }
        if PetWhiteStyle.isActive { return 6 }
        if MujiStyle.isActive { return 5 }
        if NeumorphicStyle.isActive { return 5.5 }
        if CapsuleStyle.isActive { return 5.5 }
        if SequoiaStyle.isActive { return 6 }
        return 4
    }

    private var songMetaBadgeVerticalPadding: CGFloat {
        if SignalStyle.isActive { return 2 }
        if MangaStyle.isActive { return 2 }
        if PetWhiteStyle.isActive { return 2.5 }
        if MujiStyle.isActive { return 1.5 }
        if NeumorphicStyle.isActive { return 2 }
        if CapsuleStyle.isActive { return 2 }
        if SequoiaStyle.isActive { return 2.2 }
        return 1
    }

    private var songMetaBadgeCornerRadius: CGFloat {
        if SignalStyle.isActive { return 5 }
        if MangaStyle.isActive { return 6 }
        if PetWhiteStyle.isActive { return 8 }
        if MujiStyle.isActive { return 5 }
        if NeumorphicStyle.isActive { return 6 }
        if CapsuleStyle.isActive { return 7 }
        if SequoiaStyle.isActive { return 7 }
        return 2
    }

    private func songMetaBadgeForeground(_ color: Color) -> Color {
        if SignalStyle.isActive { return color }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if CapsuleStyle.isActive { return color }
        return MangaStyle.isActive ? MangaStyle.ink : color
    }

    @ViewBuilder
    private func songMetaBadgeBackground(_ color: Color) -> some View {
        if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .fill(color.opacity(0.1))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: songMetaBadgeCornerRadius,
                elevated: false,
                pressed: true,
                tint: color.opacity(0.12),
                lightweight: true
            )
        } else if PetWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .fill(color.opacity(0.14))
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(
                cornerRadius: songMetaBadgeCornerRadius,
                elevated: false,
                tint: color.opacity(0.10)
            )
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: songMetaBadgeCornerRadius,
                elevated: false,
                pressed: true,
                fill: color.opacity(0.095),
                role: .selected
            )
        } else {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .fill(color.opacity(MangaStyle.isActive ? 0.22 : (MujiStyle.isActive ? 0.10 : 0.11)))
        }
    }

    @ViewBuilder
    private func songMetaBadgeStroke(_ color: Color) -> some View {
        if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.34), lineWidth: 0.65)
        } else if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
        } else if PetWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.34), lineWidth: 0.8)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.32), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.24), lineWidth: 0.65)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.24), lineWidth: 0.55)
        } else {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color, lineWidth: 0.5)
        }
    }

    private func quickActionButton(
        icon: MonoIcon.IconType,
        kind: QuickAction,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isActive = activeQuickAction == kind

        return Button {
            guard !isDisabled else { return }
            animateQuickAction(kind)
            action()
        } label: {
            quickActionButtonChrome(
                icon: icon,
                kind: kind,
                isDisabled: isDisabled,
                isActive: isActive
            )
        }
        .buttonStyle(QuickActionButtonStyle())
        .disabled(isDisabled)
        .animation(.spring(response: 0.22, dampingFraction: 0.62), value: isActive)
    }

    private func quickActionCluster(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            likeQuickActionButton

            quickActionButton(icon: .add, kind: .addToQueue, isDisabled: false) {
                playback.addToQueue(song: song)
            }

            // 下载快捷按钮（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
            if AppConfig.Features.downloadEnabled,
               !isLocalSong,
               !song.isAppleMusic {
                quickActionButton(icon: .download, kind: .download, isDisabled: isDownloaded) {
                    downloadSong()
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .overlay(alignment: .topTrailing) {
            if let feedbackAction {
                quickActionFeedbackBadge(for: feedbackAction)
                    .allowsHitTesting(false)
            }
        }
    }

    private var likeQuickActionButton: some View {
        Button {
            likeManager.toggleLike(songId: song.id, isQQMusic: song.isQQMusic, song: song)
        } label: {
            quickActionButtonChrome(
                icon: isLiked ? .liked : .like,
                kind: .like,
                isDisabled: false,
                isActive: isLiked
            )
        }
        .buttonStyle(QuickActionButtonStyle())
        .animation(.spring(response: 0.22, dampingFraction: 0.62), value: isLiked)
    }

    private var likePlaylistPickerBinding: Binding<Bool> {
        Binding(
            get: {
                likeManager.showPlaylistPicker
                    && likeManager.pendingLikeSong?.id == song.id
                    && likeManager.pendingLikeSong?.musicSource == song.musicSource
            },
            set: { isPresented in
                if !isPresented {
                    likeManager.showPlaylistPicker = false
                    likeManager.pendingLikeSong = nil
                }
            }
        )
    }

    @ViewBuilder
    private func quickActionButtonChrome(
        icon: MonoIcon.IconType,
        kind: QuickAction,
        isDisabled: Bool,
        isActive: Bool
    ) -> some View {
        let tint = quickActionTint(for: kind)
        let size = quickActionButtonSize
        let radius = quickActionButtonCornerRadius
        let iconColor = quickActionIconColor(kind: kind, isDisabled: isDisabled)

        if SignalStyle.isActive {
            ZStack {
                SignalSurfaceBackground(
                    cornerRadius: radius,
                    elevated: isActive && !isDisabled,
                    pressed: !isActive,
                    fill: isActive ? tint.opacity(0.16) : SignalStyle.control
                )

                MonoIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.65)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.06 : 1)
        } else if MangaStyle.isActive {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(MangaStyle.strokeInk.opacity(isDisabled ? 0.15 : 0.84))
                    .offset(x: 2.2, y: 2.2)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isDisabled ? MangaStyle.bubbleWhite.opacity(0.54) : tint.opacity(isActive ? 0.95 : 0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(MangaStyle.strokeInk.opacity(isDisabled ? 0.34 : 0.72), lineWidth: MangaStyle.fineStrokeWidth)
                    )

                MonoIcon(icon: icon, size: 14, color: iconColor, lineWidth: 1.9)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.08 : 1)
        } else if MujiStyle.isActive {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isActive ? tint.opacity(0.16) : MujiStyle.surfaceRaised.opacity(isDisabled ? 0.54 : 0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(tint.opacity(isActive ? 0.42 : (isDisabled ? 0.14 : 0.22)), lineWidth: 0.7)
                    )

                MonoIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.5)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.06 : 1)
        } else if PetWhiteStyle.isActive {
            ZStack {
                PetWhiteSurfaceBackground(
                    cornerRadius: radius,
                    elevated: isActive && !isDisabled,
                    tint: isActive ? tint.opacity(0.28) : PetWhiteStyle.surfaceRaised,
                    accent: tint
                )

                MonoIcon(icon: icon, size: 13.5, color: iconColor, lineWidth: 1.7)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.07 : 1)
        } else if NeumorphicStyle.isActive {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.clear)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: radius,
                            elevated: isActive && !isDisabled,
                            pressed: !isActive,
                            tint: tint.opacity(isDisabled ? 0.08 : (isActive ? 0.22 : 0.12)),
                            lightweight: true
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

                MonoIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.55)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.06 : 1)
        } else if CapsuleStyle.isActive {
            ZStack {
                CapsuleSurfaceBackground(
                    cornerRadius: radius,
                    elevated: isActive && !isDisabled,
                    tint: CapsuleStyle.surfaceRaised
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(tint.opacity(isActive ? 0.34 : 0.18), lineWidth: 0.75)
                )

                MonoIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.58)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.06 : 1)
        } else if SequoiaStyle.isActive {
            ZStack {
                SequoiaSurfaceBackground(
                    cornerRadius: radius,
                    elevated: isActive && !isDisabled,
                    pressed: !isActive,
                    fill: tint.opacity(isDisabled ? 0.045 : (isActive ? 0.18 : 0.08)),
                    role: .selected
                )

                MonoIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.58)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.06 : 1)
        } else {
            MonoIcon(
                icon: icon,
                size: 13,
                color: iconColor
            )
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.08 : 1)
            .background(Color.monoTextPrimary.opacity(isDisabled ? 0.04 : (isActive ? 0.12 : 0.07)))
            .overlay(
                Circle()
                    .stroke(Color.monoTextPrimary.opacity(isActive ? 0.12 : 0), lineWidth: 1)
                    .scaleEffect(isActive ? 1.18 : 0.92)
            )
            .clipShape(Circle())
        }
    }

    private func downloadSong() {
        guard !song.isLocal else { return }
        rowDownloads.download(song: song)
    }

    private func copyShortPlayLink() {
        Task {
            do {
                let payload = try await playUrlForShortLink()
                guard !payload.playUrl.isEmpty else { return }
                let shortLink = try await APIService.shortenPlayUrl(
                    payload.playUrl,
                    song: song,
                    source: song.musicSource,
                    qqQualityRaw: payload.qqQualityRaw,
                    qishuiQualityRaw: payload.qishuiQualityRaw
                ).async()
                await MainActor.run {
                    UIPasteboard.general.string = shortLink
                }
            } catch {
                AppLogger.error("复制播放链接失败: \(error)")
            }
        }
    }

    private func playUrlForShortLink() async throws -> ShortLinkPayload {
        if song.isQishui, let trackId = song.qishuiTrackId {
            let quality = SettingsManager.shared.defaultQishuiPlaybackQuality
            let playUrl = APIService.qishuiProxyPlayURL(
                trackId: trackId,
                quality: quality
            )
            return ShortLinkPayload(playUrl: playUrl, qqQualityRaw: nil, qishuiQualityRaw: quality)
        } else if song.isQishui {
            throw APIService.PlaybackError.unavailable
        }

        if song.isQQMusic, let mid = song.qqMid, !mid.isEmpty {
            let result = try await APIService.shared.fetchQQSongUrl(
                mid: mid,
                quality: PlayerManager.shared.qqMusicQuality
            ).async()
            return ShortLinkPayload(
                playUrl: result.url,
                qqQualityRaw: result.actualQQQuality?.rawValue ?? PlayerManager.shared.qqMusicQuality.rawValue,
                qishuiQualityRaw: nil
            )
        } else if song.isQQMusic {
            throw APIService.PlaybackError.unavailable
        }

        let result = try await APIService.shared.fetchSongUrl(id: song.id, level: "jymaster").async()
        return ShortLinkPayload(playUrl: result.url, qqQualityRaw: nil, qishuiQualityRaw: nil)
    }

    private func quickActionFeedbackBadge(for action: QuickAction) -> some View {
        let isVisible = feedbackPhase == 1
        let isExiting = feedbackPhase == 2

        return HStack(spacing: 5) {
            MonoIcon(icon: action.badgeIcon, size: 10, color: quickActionFeedbackForeground(for: action))

            Text(action.badgeTitle)
                .font(quickActionFeedbackFont)
                .foregroundColor(quickActionFeedbackForeground(for: action))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background { quickActionFeedbackBackground(for: action) }
        .scaleEffect(isVisible ? 1 : 0.88)
        .opacity(isVisible ? 1 : 0)
        .offset(
            x: isVisible ? -10 : -2,
            y: isVisible ? -18 : (isExiting ? -30 : -6)
        )
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: feedbackPhase)
    }

    private var quickActionFeedbackFont: Font {
        if SignalStyle.isActive { return SignalStyle.labelFont(10, weight: .bold) }
        if MangaStyle.isActive { return MangaStyle.comicFont(10, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(10, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(10, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(10, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(10, weight: .semibold) }
        return .system(size: 10, weight: .semibold, design: .rounded)
    }

    private func quickActionFeedbackForeground(for action: QuickAction) -> Color {
        if SignalStyle.isActive { return SignalStyle.ink }
        if MangaStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(
                on: quickActionTint(for: action),
                light: MangaStyle.strokeInk,
                dark: MangaStyle.onStrokeInk
            )
        }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    @ViewBuilder
    private func quickActionFeedbackBackground(for action: QuickAction) -> some View {
        let tint = quickActionTint(for: action)

        if SignalStyle.isActive {
            Capsule(style: .continuous)
                .fill(SignalStyle.surfaceRaised.opacity(0.98))
                .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.38), lineWidth: 0.7))
                .shadow(color: tint.opacity(0.16), radius: 8)
        } else if MangaStyle.isActive {
            ZStack {
                Capsule(style: .continuous)
                    .fill(MangaStyle.strokeInk.opacity(0.78))
                    .offset(x: 1.4, y: 1.4)

                Capsule(style: .continuous)
                    .fill(tint.opacity(0.82))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(MangaStyle.strokeInk.opacity(0.68), lineWidth: MangaStyle.fineStrokeWidth)
                    )
            }
        } else if MujiStyle.isActive {
            Capsule(style: .continuous)
                .fill(MujiStyle.surfaceRaised.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(0.26), lineWidth: 0.7)
                )
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.clear)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 13,
                        elevated: true,
                        tint: tint.opacity(0.14),
                        lightweight: true
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(
                cornerRadius: 13,
                elevated: true,
                tint: CapsuleStyle.surfaceRaised
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 0.7)
            )
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: 13,
                elevated: true,
                fill: tint.opacity(0.12),
                role: .floating
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(tint.opacity(0.2), lineWidth: 0.55)
            )
        } else {
            Capsule(style: .continuous)
                .fill(Color.monoTextPrimary.opacity(0.08))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.monoTextPrimary.opacity(0.10), lineWidth: 1)
                )
        }
    }

    private func animateQuickAction(_ kind: QuickAction) {
        withAnimation(.spring(response: 0.16, dampingFraction: 0.58)) {
            activeQuickAction = kind
        }

        feedbackAction = kind
        feedbackPhase = 0

        Task { @MainActor in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                feedbackPhase = 1
            }

            try? await Task.sleep(nanoseconds: 380_000_000)
            guard feedbackAction == kind else { return }

            withAnimation(.easeOut(duration: 0.18)) {
                feedbackPhase = 2
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard activeQuickAction == kind else { return }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                activeQuickAction = nil
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 620_000_000)
            guard feedbackAction == kind else { return }
            feedbackAction = nil
            feedbackPhase = 0
        }
    }
}
