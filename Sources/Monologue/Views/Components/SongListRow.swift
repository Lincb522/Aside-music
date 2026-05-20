import SwiftUI

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
        playback.currentSongId == song.id
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
        static let text = Color.monologueTextPrimary
        static let secondaryText = Color.monologueTextSecondary
        static var accent: Color {
            MangaStyle.isActive
                ? MangaStyle.accentPink
                : (PetWhiteStyle.isActive
                    ? PetWhiteStyle.dogOrange
                    : (MujiStyle.isActive
                        ? MujiStyle.clay
                        : (NeumorphicStyle.isActive
                            ? NeumorphicStyle.accent
                            : (CapsuleStyle.isActive
                                ? CapsuleStyle.accent
                                : (SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monologueTextPrimary)))))
        }
    }

    private enum QuickAction: Hashable {
        case like
        case addToQueue
        case download

        var badgeIcon: MonologueIcon.IconType {
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

    private var localBrandColor: Color {
        MusicSource.local.themedBadgeColor
    }

    private var quickActionButtonSize: CGFloat {
        if MangaStyle.isActive { return 32 }
        if PetWhiteStyle.isActive { return 26 }
        if MujiStyle.isActive { return 31 }
        if NeumorphicStyle.isActive { return 32 }
        if CapsuleStyle.isActive { return 31 }
        if SequoiaStyle.isActive { return 32 }
        return 30
    }

    private var quickActionButtonCornerRadius: CGFloat {
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
            if MangaStyle.isActive { return MangaStyle.accentPink }
            if PetWhiteStyle.isActive { return PetWhiteStyle.blush }
            if MujiStyle.isActive { return Color.red.opacity(0.86) }
            if NeumorphicStyle.isActive { return Color.red.opacity(0.88) }
            if CapsuleStyle.isActive { return Color.red.opacity(0.86) }
            if SequoiaStyle.isActive { return Color.red.opacity(0.88) }
            return .red
        case .addToQueue:
            if MangaStyle.isActive { return MangaStyle.labelYellow }
            if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
            if MujiStyle.isActive { return MujiStyle.clay }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            if CapsuleStyle.isActive { return CapsuleStyle.amber }
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            return Color.monologueTextPrimary
        case .download:
            if MangaStyle.isActive { return MangaStyle.decoBlue }
            if PetWhiteStyle.isActive { return PetWhiteStyle.sky }
            if MujiStyle.isActive { return MujiStyle.indigo }
            if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
            if CapsuleStyle.isActive { return CapsuleStyle.cyan }
            if SequoiaStyle.isActive { return SequoiaStyle.aqua }
            return Color.monologueTextPrimary
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
                return PetWhiteStyle.stroke.opacity(isDisabled ? 0.34 : 0.72)
            }
            return Theme.secondaryText.opacity(isDisabled ? 0.34 : 0.62)
        }
        if MangaStyle.isActive {
            return MangaStyle.strokeInk.opacity(isDisabled ? 0.34 : 1)
        }
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.stroke.opacity(isDisabled ? 0.34 : 1)
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
        return isDisabled ? .monologueTextSecondary.opacity(0.45) : .monologueTextPrimary
    }

    private var rowCornerRadius: CGFloat {
        if MangaStyle.isActive { return 2 }
        if PetWhiteStyle.isActive { return 21 }
        if MujiStyle.isActive { return 10 }
        if NeumorphicStyle.isActive { return 18 }
        if CapsuleStyle.isActive { return 19 }
        if SequoiaStyle.isActive { return 17 }
        return 12
    }

    private var coverCornerRadius: CGFloat {
        if MangaStyle.isActive { return 2 }
        if PetWhiteStyle.isActive { return 14 }
        if MujiStyle.isActive { return 6 }
        if NeumorphicStyle.isActive { return 14 }
        if CapsuleStyle.isActive { return 14 }
        if SequoiaStyle.isActive { return 13 }
        return 12
    }

    private var rowCoverSize: CGFloat {
        if MangaStyle.isActive { return 47 }
        if PetWhiteStyle.isActive { return 44 }
        if MujiStyle.isActive { return 46 }
        if NeumorphicStyle.isActive { return 47 }
        if CapsuleStyle.isActive { return 46 }
        return 48
    }

    private var rowContentSpacing: CGFloat {
        if MangaStyle.isActive { return 9 }
        if PetWhiteStyle.isActive { return 7 }
        if MujiStyle.isActive { return 9 }
        if CapsuleStyle.isActive { return 9 }
        return 10
    }

    private var rowHorizontalPadding: CGFloat {
        if let horizontalPadding = horizontalPadding { return horizontalPadding }
        if MangaStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        if PetWhiteStyle.isActive { return DeviceLayout.viewHorizontalPadding }
        if MujiStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        if NeumorphicStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        if CapsuleStyle.isActive { return max(DeviceLayout.viewHorizontalPadding - 2, 14) }
        return DeviceLayout.viewHorizontalPadding
    }

    private var rowIndexWidth: CGFloat {
        if MangaStyle.isActive { return 15 }
        if PetWhiteStyle.isActive { return 18 }
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
                            MonologueSymbolIcon(
                                name: isSelected ? "checkmark.circle.fill" : "circle",
                                size: 18,
                                color: isSelected ? CapsuleStyle.accent : CapsuleStyle.inkMuted.opacity(0.46)
                            )
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
                            .fill(isCurrent ? CapsuleStyle.accent : CapsuleStyle.surfaceTint.opacity(0.54))
                    )

                    CachedAsyncImage(url: song.coverUrl, width: coverSize, height: coverSize) {
                        CapsuleStyle.surfaceTint.opacity(0.72)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(isCurrent ? CapsuleStyle.accent.opacity(0.46) : CapsuleStyle.separator.opacity(0.42), lineWidth: 0.7)
                    )
                    .overlay {
                        if isCurrent && !isSelecting {
                            ZStack {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.black.opacity(0.35))
                                PlayingVisualizerView(isAnimating: playback.isPlaying, color: .white)
                                    .scaleEffect(0.82)
                            }
                        }
                    }
                    .opacity(isGrayed ? 0.4 : 1.0)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(song.name)
                            .font(CapsuleStyle.bodyFont(15.5, weight: isCurrent ? .bold : .semibold))
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
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985, opacity: 0.88))
            .disabled(onTap == nil)

            if !isSelecting {
                quickActionCluster(spacing: 6)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background {
            if isCurrent {
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
                                    MonologueSymbolIcon(
                                        name: isSelected ? "checkmark.circle.fill" : "circle",
                                        size: 18,
                                        color: isSelected ? Theme.accent : Theme.secondaryText.opacity(0.4)
                                    )
                                } else {
                                    Text(String(format: "%02d", index + 1))
                                        .font(indexFont)
                                        .foregroundColor(isCurrent ? Theme.accent : Theme.secondaryText.opacity(0.4))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                            }
                            .frame(width: rowIndexWidth)

                            CachedAsyncImage(url: song.coverUrl, width: coverSize, height: coverSize) {
                                Color.gray.opacity(0.1)
                            }
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
                                }
                            }
                            .overlay {
                                if isCurrent && !isSelecting {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                                            .fill(Color.black.opacity(0.35))
                                        PlayingVisualizerView(isAnimating: playback.isPlaying, color: .white)
                                            .scaleEffect(0.85)
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
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98, opacity: 0.8))
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
                    } else if isCurrent {
                        currentRowBackground
                    }
                }
                .padding(.horizontal, PetWhiteStyle.isActive ? rowHorizontalPadding : 0)
                .padding(.vertical, PetWhiteStyle.isActive ? 5 : 0)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            
            if !isLocalSong {
                // 下载选项
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
            
            if !isLocalSong {
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
            
            if !isLocalSong {
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
            
            if !isLocalSong {
                // 详情 — 分源处理
                Button {
                    onDetailTap?(song)
                } label: {
                    Label(LocalizedStringKey("action_details"), systemImage: "info.circle")
                }
            }
            
            if !isLocalSong {
                Divider()
                
                // 复制播放链接（获取真实 URL → 后端生成短码 → 复制短链接）
                Button {
                    Task {
                        do {
                            let result = try await APIService.shared.fetchSongUrl(id: song.id, level: "jymaster").async()
                            guard !result.url.isEmpty else { return }
                            let shortLink = try await APIService.shortenPlayUrl(result.url).async()
                            await MainActor.run {
                                UIPasteboard.general.string = shortLink
                            }
                        } catch {
                            AppLogger.error("复制播放链接失败: \(error)")
                        }
                    }
                } label: {
                    Label(String(localized: "song_copy_link"), systemImage: "link")
                }
            }
        }
        .themeRenderRowLayer()
        .monologueSheet(isPresented: $showAddToPlaylist, preset: .standard){
            AddToPlaylistSheet(song: song)
        }
        .monologueSheet(isPresented: likePlaylistPickerBinding, preset: .standard) {
            if let pendingSong = likeManager.pendingLikeSong {
                AddToPlaylistSheet(song: pendingSong)
            }
        }
        // qcm歌手详情页（使用 sheet 避免 lazy 容器中 navigationDestination 警告）
        .monologueSheet(isPresented: $showQQArtistDetail, preset: .detail){
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
        .monologueSheet(isPresented: $showQQAlbumDetail, preset: .detail){
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
        if MangaStyle.isActive {
            ZStack(alignment: .leading) {
                MangaCardBackground(cornerRadius: rowCornerRadius, elevated: true, tint: MangaStyle.labelYellow.opacity(0.54))

                Capsule()
                    .fill(MangaStyle.accentPink)
                    .frame(width: 5, height: 30)
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 4)
        } else if MujiStyle.isActive {
            ZStack(alignment: .leading) {
                MujiPaperCardBackground(cornerRadius: rowCornerRadius, elevated: true)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MujiStyle.clay)
                    .frame(width: 3, height: 24)
                    .padding(.leading, 8)
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
                    .monologueGlass(cornerRadius: rowCornerRadius)

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
        if isCurrent {
            petWhiteCurrentRowBackground
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
                .frame(width: 5, height: 30)
                .padding(.leading, 8)
        }
    }

    private var songInfoVerticalSpacing: CGFloat {
        if MangaStyle.isActive { return 3.5 }
        if PetWhiteStyle.isActive { return 5 }
        if MujiStyle.isActive { return 3 }
        if NeumorphicStyle.isActive { return 3.5 }
        if CapsuleStyle.isActive { return 3.5 }
        if SequoiaStyle.isActive { return 3.5 }
        return 3
    }

    private var indexFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(13, weight: .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(11, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(11.5, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .medium) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var songTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(16, weight: isCurrent ? .bold : .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(15.5, weight: isCurrent ? .black : .bold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(15, weight: isCurrent ? .medium : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(15, weight: isCurrent ? .semibold : .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(15, weight: isCurrent ? .bold : .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: isCurrent ? .semibold : .medium) }
        return .system(size: 16, weight: isCurrent ? .bold : .medium)
    }

    private var songTitleColor: Color {
        if isGrayed { return Theme.secondaryText.opacity(0.4) }
        if isCurrent { return Theme.accent }
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
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return Theme.secondaryText
    }

    private var songBadgeRailSpacing: CGFloat {
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
        HStack(spacing: songBadgeRailSpacing) {
            if song.isNoCopyright {
                songMetaBadge(String(localized: "song_no_copyright"), color: Theme.accent, fontSize: 7)
            }

            if song.isQQMusic {
                songMetaBadge("QCM", color: qcmBrandColor)

                if let badge = song.qqMaxQuality?.badgeText {
                    songMetaBadge(badge, color: qcmBrandColor)
                }
            } else if song.isQishui {
                songMetaBadge("QSM", color: qsmBrandColor)

                if let badge = song.qualityBadge {
                    songMetaBadge(badge, color: qsmBrandColor)
                }
            } else if isLocalSong {
                songMetaBadge("LOCAL", color: localBrandColor)
            } else if let radioName = song.podcastRadioName {
                songMetaBadge(radioName.uppercased(), color: ncmBrandColor, maxWidth: 92)
            } else {
                songMetaBadge("NCM", color: ncmBrandColor)

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

    private func songMetaBadge(_ text: String, color: Color, fontSize: CGFloat = 8, maxWidth: CGFloat? = nil) -> some View {
        return Text(text)
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

    private func songMetaBadgeFont(fontSize: CGFloat) -> Font {
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
        if MangaStyle.isActive { return 5.5 }
        if PetWhiteStyle.isActive { return 6 }
        if MujiStyle.isActive { return 5 }
        if NeumorphicStyle.isActive { return 5.5 }
        if CapsuleStyle.isActive { return 5.5 }
        if SequoiaStyle.isActive { return 6 }
        return 4
    }

    private var songMetaBadgeVerticalPadding: CGFloat {
        if MangaStyle.isActive { return 2 }
        if PetWhiteStyle.isActive { return 2.5 }
        if MujiStyle.isActive { return 1.5 }
        if NeumorphicStyle.isActive { return 2 }
        if CapsuleStyle.isActive { return 2 }
        if SequoiaStyle.isActive { return 2.2 }
        return 1
    }

    private var songMetaBadgeCornerRadius: CGFloat {
        if MangaStyle.isActive { return 6 }
        if PetWhiteStyle.isActive { return 8 }
        if MujiStyle.isActive { return 5 }
        if NeumorphicStyle.isActive { return 6 }
        if CapsuleStyle.isActive { return 7 }
        if SequoiaStyle.isActive { return 7 }
        return 2
    }

    private func songMetaBadgeForeground(_ color: Color) -> Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.stroke }
        if CapsuleStyle.isActive { return color }
        return MangaStyle.isActive ? MangaStyle.ink : color
    }

    @ViewBuilder
    private func songMetaBadgeBackground(_ color: Color) -> some View {
        if NeumorphicStyle.isActive {
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
        if MangaStyle.isActive {
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
        icon: MonologueIcon.IconType,
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

            if !isLocalSong {
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
                    && likeManager.pendingLikeSong?.isQQMusic == song.isQQMusic
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
        icon: MonologueIcon.IconType,
        kind: QuickAction,
        isDisabled: Bool,
        isActive: Bool
    ) -> some View {
        let tint = quickActionTint(for: kind)
        let size = quickActionButtonSize
        let radius = quickActionButtonCornerRadius
        let iconColor = quickActionIconColor(kind: kind, isDisabled: isDisabled)

        if MangaStyle.isActive {
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

                MonologueIcon(icon: icon, size: 14, color: iconColor, lineWidth: 1.9)
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

                MonologueIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.5)
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

                MonologueIcon(icon: icon, size: 13.5, color: iconColor, lineWidth: 1.7)
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

                MonologueIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.55)
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

                MonologueIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.58)
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

                MonologueIcon(icon: icon, size: 13, color: iconColor, lineWidth: 1.58)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.06 : 1)
        } else {
            MonologueIcon(
                icon: icon,
                size: 13,
                color: iconColor
            )
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.08 : 1)
            .background(Color.monologueTextPrimary.opacity(isDisabled ? 0.04 : (isActive ? 0.12 : 0.07)))
            .overlay(
                Circle()
                    .stroke(Color.monologueTextPrimary.opacity(isActive ? 0.12 : 0), lineWidth: 1)
                    .scaleEffect(isActive ? 1.18 : 0.92)
            )
            .clipShape(Circle())
        }
    }

    private func downloadSong() {
        guard !song.isLocal else { return }
        rowDownloads.download(song: song)
    }

    private func quickActionFeedbackBadge(for action: QuickAction) -> some View {
        let isVisible = feedbackPhase == 1
        let isExiting = feedbackPhase == 2

        return HStack(spacing: 5) {
            MonologueIcon(icon: action.badgeIcon, size: 10, color: quickActionFeedbackForeground(for: action))

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
        if MangaStyle.isActive { return MangaStyle.comicFont(10, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(10, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(10, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(10, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(10, weight: .semibold) }
        return .system(size: 10, weight: .semibold, design: .rounded)
    }

    private func quickActionFeedbackForeground(for action: QuickAction) -> Color {
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
        return .monologueTextPrimary
    }

    @ViewBuilder
    private func quickActionFeedbackBackground(for action: QuickAction) -> some View {
        let tint = quickActionTint(for: action)

        if MangaStyle.isActive {
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
                .fill(Color.monologueTextPrimary.opacity(0.08))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.monologueTextPrimary.opacity(0.10), lineWidth: 1)
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
