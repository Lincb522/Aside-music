import SwiftUI

struct SongListRow: View {
    
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var unavailableSongs = UnavailableSongsManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    let song: Song
    let index: Int
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var onArtistTap: ((Int) -> Void)? = nil
    var onDetailTap: ((Song) -> Void)? = nil
    var onAlbumTap: ((Int) -> Void)? = nil
    var onTap: (() -> Void)? = nil
    
    @State private var showAddToPlaylist = false
    @State private var activeQuickAction: QuickAction?
    @State private var feedbackAction: QuickAction?
    @State private var feedbackPhase: Int = 0
    
    // qcm详情页导航状态
    @State private var showQQArtistDetail = false
    @State private var showQQAlbumDetail = false
    
    var isCurrent: Bool {
        player.currentSong?.id == song.id
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
                : (MujiStyle.isActive
                    ? MujiStyle.clay
                    : (NeumorphicStyle.isActive
                        ? NeumorphicStyle.accent
                        : (SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monologueTextPrimary)))
        }
    }

    private enum QuickAction: Hashable {
        case addToQueue
        case download

        var badgeIcon: MonologueIcon.IconType {
            switch self {
            case .addToQueue:
                return .musicNoteList
            case .download:
                return .download
            }
        }

        var badgeTitle: String {
            switch self {
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
        downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic)
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
        if MujiStyle.isActive { return 31 }
        if NeumorphicStyle.isActive { return 32 }
        if SequoiaStyle.isActive { return 32 }
        return 30
    }

    private var quickActionButtonCornerRadius: CGFloat {
        if MangaStyle.isActive { return 11 }
        if MujiStyle.isActive { return 10 }
        if NeumorphicStyle.isActive { return 13 }
        if SequoiaStyle.isActive { return 12 }
        return quickActionButtonSize / 2
    }

    private func quickActionTint(for kind: QuickAction) -> Color {
        switch kind {
        case .addToQueue:
            if MangaStyle.isActive { return MangaStyle.labelYellow }
            if MujiStyle.isActive { return MujiStyle.clay }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            return Color.monologueTextPrimary
        case .download:
            if MangaStyle.isActive { return MangaStyle.decoBlue }
            if MujiStyle.isActive { return MujiStyle.indigo }
            if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
            if SequoiaStyle.isActive { return SequoiaStyle.aqua }
            return Color.monologueTextPrimary
        }
    }

    private func quickActionIconColor(kind: QuickAction, isDisabled: Bool) -> Color {
        if MangaStyle.isActive {
            return MangaStyle.strokeInk.opacity(isDisabled ? 0.34 : 1)
        }
        if MujiStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.34 : 0.95)
        }
        if NeumorphicStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.36 : 1)
        }
        if SequoiaStyle.isActive {
            return quickActionTint(for: kind).opacity(isDisabled ? 0.34 : 0.96)
        }
        return isDisabled ? .monologueTextSecondary.opacity(0.45) : .monologueTextPrimary
    }

    private var rowCornerRadius: CGFloat {
        if MangaStyle.isActive { return 2 }
        if MujiStyle.isActive { return 10 }
        if NeumorphicStyle.isActive { return 18 }
        if SequoiaStyle.isActive { return 17 }
        return 12
    }

    private var coverCornerRadius: CGFloat {
        if MangaStyle.isActive { return 2 }
        if MujiStyle.isActive { return 6 }
        if NeumorphicStyle.isActive { return 14 }
        if SequoiaStyle.isActive { return 13 }
        return 12
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        HStack(spacing: 12) {
            Button {
                onTap?()
            } label: {
                HStack(spacing: 10) {
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
                    .frame(width: 16)

                    CachedAsyncImage(url: song.coverUrl, width: 48, height: 48) {
                        Color.gray.opacity(0.1)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
                    .overlay {
                        if MangaStyle.isActive {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                        } else if MujiStyle.isActive {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
                        } else if NeumorphicStyle.isActive {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(NeumorphicStyle.separator.opacity(0.38), lineWidth: 0.6)
                        } else if SequoiaStyle.isActive {
                            RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                                .stroke(SequoiaStyle.luminousSeparator.opacity(0.42), lineWidth: 0.55)
                        }
                    }
                    .overlay {
                        if isCurrent && !isSelecting {
                            ZStack {
                                Color.black.opacity(0.35)
                                PlayingVisualizerView(isAnimating: player.isPlaying, color: .white)
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
                            .layoutPriority(2)

                        Text(songArtistAlbumText)
                            .font(songArtistAlbumFont)
                            .foregroundColor(songArtistAlbumColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)

                        songBadgeRail
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98, opacity: 0.8))
            .disabled(onTap == nil)

            if !isSelecting {
                HStack(spacing: 8) {
                    quickActionButton(icon: .add, kind: .addToQueue, isDisabled: false) {
                        player.addToQueue(song: song)
                    }

                    if !isLocalSong {
                        quickActionButton(icon: .download, kind: .download, isDisabled: isDownloaded) {
                            downloadSong()
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let feedbackAction {
                        quickActionFeedbackBadge(for: feedbackAction)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 8)
        .background {
            if isCurrent {
                if SequoiaStyle.isActive {
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
                } else {
                    ZStack(alignment: .leading) {
                        // 主体渐变玻璃态
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

                        // 左侧微光描边
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

                        // 呼吸发光指示条
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.accent)
                            .frame(width: 3.5, height: 20)
                            .shadow(color: Theme.accent.opacity(0.6), radius: 4, x: 0, y: 0)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                PlayerManager.shared.playNext(song: song)
            } label: {
                Label(LocalizedStringKey("action_play_next"), systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                PlayerManager.shared.addToQueue(song: song)
            } label: {
                Label(LocalizedStringKey("action_add_to_queue"), systemImage: "text.append")
            }
            
            Divider()
            
            if !isLocalSong {
                // 下载选项
                if downloadManager.isDownloaded(songId: song.id) {
                    Button(role: .destructive) {
                        downloadManager.deleteDownload(songId: song.id, isQQ: song.isQQMusic)
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

    private var songInfoVerticalSpacing: CGFloat {
        if MangaStyle.isActive { return 3.5 }
        if MujiStyle.isActive { return 3 }
        if NeumorphicStyle.isActive { return 3.5 }
        if SequoiaStyle.isActive { return 3.5 }
        return 3
    }

    private var indexFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .medium) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var songTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(16, weight: isCurrent ? .bold : .medium) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(15, weight: isCurrent ? .medium : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(15, weight: isCurrent ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: isCurrent ? .semibold : .medium) }
        return .system(size: 16, weight: isCurrent ? .bold : .medium)
    }

    private var songTitleColor: Color {
        if isGrayed { return Theme.secondaryText.opacity(0.4) }
        if isCurrent { return Theme.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
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
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: .medium)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(12, weight: .regular)
        }
        return .system(size: 13)
    }

    private var songArtistAlbumColor: Color {
        if isGrayed { return Theme.secondaryText.opacity(0.3) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return Theme.secondaryText
    }

    private var songBadgeRailSpacing: CGFloat {
        if MangaStyle.isActive { return 5 }
        if MujiStyle.isActive { return 4 }
        if NeumorphicStyle.isActive { return 5 }
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
        if MujiStyle.isActive {
            return MujiStyle.labelFont(max(fontSize + 0.5, 8), weight: .semibold)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(max(fontSize + 0.5, 8), weight: .semibold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(max(fontSize + 0.5, 8), weight: .semibold)
        }
        return .system(size: fontSize, weight: .bold, design: .rounded)
    }

    private var songMetaBadgeHorizontalPadding: CGFloat {
        if MangaStyle.isActive { return 5.5 }
        if MujiStyle.isActive { return 5 }
        if NeumorphicStyle.isActive { return 5.5 }
        if SequoiaStyle.isActive { return 6 }
        return 4
    }

    private var songMetaBadgeVerticalPadding: CGFloat {
        if MangaStyle.isActive { return 2 }
        if MujiStyle.isActive { return 1.5 }
        if NeumorphicStyle.isActive { return 2 }
        if SequoiaStyle.isActive { return 2.2 }
        return 1
    }

    private var songMetaBadgeCornerRadius: CGFloat {
        if MangaStyle.isActive { return 6 }
        if MujiStyle.isActive { return 5 }
        if NeumorphicStyle.isActive { return 6 }
        if SequoiaStyle.isActive { return 7 }
        return 2
    }

    private func songMetaBadgeForeground(_ color: Color) -> Color {
        MangaStyle.isActive ? MangaStyle.ink : color
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
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.32), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: songMetaBadgeCornerRadius, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
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
        if song.isQishui {
            downloadManager.downloadQishui(song: song, quality: SettingsManager.shared.defaultQishuiPlaybackQuality)
        } else if song.isQQMusic {
            downloadManager.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
        } else {
            downloadManager.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
        }
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
