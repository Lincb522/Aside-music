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
            .cornerRadius(12)
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
                            Text("已解灰")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Theme.accent, lineWidth: 0.5)
                                )
                        } else {
                            Text("无版权")
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
                    
                    Text("\(song.artistName)\(song.al?.name.isEmpty == false ? " - " + (song.al?.name ?? "") : "")")
                        .font(.system(size: 13))
                        .foregroundColor(isGrayed ? Theme.secondaryText.opacity(0.3) : Theme.secondaryText)
                        .lineLimit(1)
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
                    Label("删除下载", systemImage: "trash")
                }
            } else {
                Button {
                    downloadManager.download(song: song, quality: player.soundQuality)
                } label: {
                    Label("下载", systemImage: "arrow.down.circle")
                }
            }
            
            Divider()
            
            if let artistId = song.ar?.first?.id {
                Button {
                    onArtistTap?(artistId)
                } label: {
                    Label(LocalizedStringKey("action_artist"), systemImage: "person.circle")
                }
            }
            
            if let albumId = song.al?.id, albumId > 0 {
                Button {
                    onAlbumTap?(albumId)
                } label: {
                    Label("查看专辑", systemImage: "square.stack")
                }
            }
            
            Button {
                onDetailTap?(song)
            } label: {
                Label(LocalizedStringKey("action_details"), systemImage: "info.circle")
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
                    title: "无版权",
                    message: "该歌曲暂无版权，开启「解灰」功能后可尝试从第三方源获取播放链接",
                    primaryButtonTitle: "去开启",
                    secondaryButtonTitle: "取消",
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
