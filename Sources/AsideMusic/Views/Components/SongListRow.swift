import SwiftUI

struct SongListRow: View {
    
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    let song: Song
    let index: Int
    var onArtistTap: ((Int) -> Void)? = nil
    var onDetailTap: ((Song) -> Void)? = nil
    var onAlbumTap: ((Int) -> Void)? = nil
    
    @State private var showAddToPlaylist = false
    
    // QQ 音乐详情页导航状态
    @State private var showQQArtistDetail = false
    @State private var showQQAlbumDetail = false
    
    var isCurrent: Bool {
        player.currentSong?.id == song.id
    }
    
    /// 解灰关闭时，无版权歌曲显示为灰色
    var isGrayed: Bool {
        !settings.unblockEnabled && song.isUnavailable
    }
    
    private struct Theme {
        static let text = Color.asideTextPrimary
        static let secondaryText = Color.asideTextSecondary
        static let accent = Color.asideTextPrimary
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if isCurrent {
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
                    // 音质标识位置：无版权歌曲显示状态标签，正常歌曲显示音质
                    if song.isUnavailable {
                        if settings.unblockEnabled {
                            Text(String(localized: "song_unblocked"))
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Theme.accent, lineWidth: 0.5)
                                )
                        } else {
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
                    } else if let badge = song.qualityBadge {
                        let maxQuality = song.maxQuality
                        if maxQuality.isVIP || maxQuality == .lossless || maxQuality == .hires {
                            Text(badge)
                                .font(.system(size: maxQuality.isBadgeChinese ? 7 : 8, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Theme.accent, lineWidth: 0.5)
                                )
                        }
                    }
                    
                    HStack(spacing: 4) {
                        // QQ 音乐来源标识 + 音质标识
                        if song.isQQMusic {
                            Text("QQ")
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
                        }
                        
                        Text("\(song.artistName)\(song.al?.name.isEmpty == false ? " - " + (song.al?.name ?? "") : "")")
                            .font(.system(size: 13))
                            .foregroundColor(isGrayed ? Theme.secondaryText.opacity(0.3) : Theme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 已下载标识
            if downloadManager.isDownloaded(songId: song.id) {
                AsideIcon(icon: .download, size: 14, color: .asideTextSecondary, lineWidth: 1.4)
                    .padding(.trailing, 2)
            }

        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            isCurrent ? Theme.accent.opacity(0.05) : Color.clear
        )
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
            
            // 下载选项
            if downloadManager.isDownloaded(songId: song.id) {
                Button(role: .destructive) {
                    downloadManager.deleteDownload(songId: song.id)
                } label: {
                    Label(String(localized: "song_delete_download"), systemImage: "trash")
                }
            } else {
                Button {
                    if song.isQQMusic {
                        downloadManager.downloadQQ(song: song, quality: player.qqMusicQuality)
                    } else {
                        downloadManager.download(song: song, quality: player.soundQuality)
                    }
                } label: {
                    Label(String(localized: "song_download"), systemImage: "arrow.down.circle")
                }
            }
            
            // 添加到本地歌单
            Button {
                showAddToPlaylist = true
            } label: {
                Label(String(localized: "song_add_to_playlist"), systemImage: "text.badge.plus")
            }
            
            Divider()
            
            // 歌手 — 分源处理
            if song.isQQMusic {
                // QQ 音乐歌曲：跳转到 QQ 歌手详情页
                if let artistMid = song.qqArtistMid, !artistMid.isEmpty,
                   let artistName = song.ar?.first?.name {
                    Button {
                        showQQArtistDetail = true
                    } label: {
                        Label(LocalizedStringKey("action_artist"), systemImage: "person.circle")
                    }
                }
            } else {
                // 网易云歌曲：跳转到网易云歌手详情页
                if let artistId = song.ar?.first?.id {
                    Button {
                        onArtistTap?(artistId)
                    } label: {
                        Label(LocalizedStringKey("action_artist"), systemImage: "person.circle")
                    }
                }
            }
            
            // 专辑 — 分源处理
            if song.isQQMusic {
                // QQ 音乐歌曲：跳转到 QQ 专辑详情页
                if let albumMid = song.qqAlbumMid, !albumMid.isEmpty {
                    Button {
                        showQQAlbumDetail = true
                    } label: {
                        Label(String(localized: "song_view_album"), systemImage: "square.stack")
                    }
                }
            } else {
                // 网易云歌曲：跳转到网易云专辑详情页
                if let albumId = song.al?.id, albumId > 0 {
                    Button {
                        onAlbumTap?(albumId)
                    } label: {
                        Label(String(localized: "song_view_album"), systemImage: "square.stack")
                    }
                }
            }
            
            // 详情 — 分源处理
            if song.isQQMusic {
                // QQ 音乐歌曲：跳转到 QQ 歌曲详情页（暂时复用 SongDetailView，已做分源处理）
                Button {
                    onDetailTap?(song)
                } label: {
                    Label(LocalizedStringKey("action_details"), systemImage: "info.circle")
                }
            } else {
                // 网易云歌曲：跳转到网易云歌曲详情页
                Button {
                    onDetailTap?(song)
                } label: {
                    Label(LocalizedStringKey("action_details"), systemImage: "info.circle")
                }
            }
            
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
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(song: song)
        }
        // QQ 音乐歌手详情页（使用 sheet 避免 lazy 容器中 navigationDestination 警告）
        .sheet(isPresented: $showQQArtistDetail) {
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
        // QQ 音乐专辑详情页
        .sheet(isPresented: $showQQAlbumDetail) {
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
}

extension SongListRow {
    func asButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            // 解灰关闭时，无版权歌曲点击弹窗引导
            if isGrayed {
                AlertManager.shared.show(
                    title: String(localized: "song_no_copyright_title"),
                    message: String(localized: "song_no_copyright_message"),
                    primaryButtonTitle: String(localized: "song_enable_unblock"),
                    secondaryButtonTitle: String(localized: "cancel"),
                    primaryAction: {
                        SettingsManager.shared.unblockEnabled = true
                        APIService.shared.setUnblockEnabled(true)
                        AlertManager.shared.dismiss()
                        // 开启后自动播放
                        action()
                    },
                    secondaryAction: {
                        AlertManager.shared.dismiss()
                    }
                )
            } else {
                action()
            }
        }) {
            self
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98, opacity: 0.8))
    }
}
