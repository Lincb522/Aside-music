import SwiftUI

struct SongListRow: View {
    
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
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
    
    /// 灰色条件：无版权歌曲始终灰色；VIP 限制的歌曲无 VIP Cookie 时灰色
    var isGrayed: Bool {
        if song.isNoCopyright { return true }
        if song.isVIPRestricted { return !APIService.shared.hasVIPCookie }
        return false
    }
    
    private struct Theme {
        static let text = Color.monologueTextPrimary
        static let secondaryText = Color.monologueTextSecondary
        static let accent = Color.monologueTextPrimary
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
    
    var body: some View {
        HStack(spacing: 10) {
            Button {
                onTap?()
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        if isSelecting {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? Theme.accent : Theme.secondaryText.opacity(0.4))
                        } else if isCurrent {
                            PlayingVisualizerView(isAnimating: player.isPlaying, color: Theme.accent)
                        } else {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.secondaryText.opacity(0.5))
                        }
                    }
                    .frame(width: 30)

                    CachedAsyncImage(url: song.coverUrl) {
                        Color.gray.opacity(0.1)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(isGrayed ? 0.4 : 1.0)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isGrayed ? Theme.secondaryText.opacity(0.4) : (isCurrent ? Theme.accent : Theme.text))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if song.isNoCopyright {
                                Text(String(localized: "song_no_copyright"))
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(Theme.accent, lineWidth: 0.5)
                                    )
                            }

                            HStack(spacing: 4) {
                                if song.isQQMusic {
                                    Text("QCM")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.green.opacity(0.8))
                                        )

                                    if let badge = song.qqMaxQuality?.badgeText {
                                        Text(badge)
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 2)
                                                    .stroke(Theme.accent, lineWidth: 0.5)
                                            )
                                    }
                                } else if song.isQishui {
                                    Text("QSM")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(red: 0.2, green: 0.9, blue: 0.4))
                                        )
                                    
                                    if let badge = song.qualityBadge {
                                        Text(badge)
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(Theme.accent)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 2)
                                                    .stroke(Theme.accent, lineWidth: 0.5)
                                            )
                                    }
                                } else if isLocalSong {
                                    Text("LOCAL")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.blue.opacity(0.75))
                                        )
                                } else {
                                    Text("NCM")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.red.opacity(0.8))
                                        )
                                    
                                    if let badge = song.qualityBadge {
                                        let maxQ = song.maxQuality
                                        if maxQ.isVIP || maxQ == .lossless || maxQ == .hires {
                                            Text(badge)
                                                .font(.system(size: maxQ.isBadgeChinese ? 7 : 8, weight: .bold))
                                                .foregroundColor(Theme.accent)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .stroke(Theme.accent, lineWidth: 0.5)
                                                )
                                        }
                                    }
                                }

                                Text("\(song.artistName)\(song.al?.name.isEmpty == false ? " - " + (song.al?.name ?? "") : "")")
                                    .font(.system(size: 13))
                                    .foregroundColor(isGrayed ? Theme.secondaryText.opacity(0.3) : Theme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }

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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent.opacity(0.05))
                    .monologueGlass(cornerRadius: 12)
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
            MonologueIcon(
                icon: icon,
                size: 13,
                color: isDisabled ? .monologueTextSecondary.opacity(0.45) : .monologueTextPrimary
            )
            .frame(width: 30, height: 30)
            .scaleEffect(isActive ? 1.08 : 1)
            .background(Color.monologueTextPrimary.opacity(isDisabled ? 0.04 : (isActive ? 0.12 : 0.07)))
            .overlay(
                Circle()
                    .stroke(Color.monologueTextPrimary.opacity(isActive ? 0.12 : 0), lineWidth: 1)
                    .scaleEffect(isActive ? 1.18 : 0.92)
            )
            .clipShape(Circle())
        }
        .buttonStyle(QuickActionButtonStyle())
        .disabled(isDisabled)
        .animation(.spring(response: 0.22, dampingFraction: 0.62), value: isActive)
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
            MonologueIcon(icon: action.badgeIcon, size: 10, color: .monologueTextPrimary)

            Text(action.badgeTitle)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.monologueTextPrimary.opacity(0.08))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.monologueTextPrimary.opacity(0.10), lineWidth: 1)
                )
        )
        .scaleEffect(isVisible ? 1 : 0.88)
        .opacity(isVisible ? 1 : 0)
        .offset(
            x: isVisible ? -10 : -2,
            y: isVisible ? -18 : (isExiting ? -30 : -6)
        )
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: feedbackPhase)
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
