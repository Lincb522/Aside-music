import SwiftUI

struct SongListRow: View {
    @ObservedObject var player = PlayerManager.shared // Observe player state
    let song: Song
    let index: Int
    var onArtistTap: ((Int) -> Void)? = nil  // 可选的歌手点击回调
    var onDetailTap: ((Song) -> Void)? = nil // 可选的详情点击回调
    
    // Computed property to determine if this row is currently playing
    var isCurrent: Bool {
        player.currentSong?.id == song.id
    }
    
    // Theme Reference (Internal)
    private struct Theme {
        static let text = Color.black
        static let secondaryText = Color.gray
        static let accent = Color.black
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Index or Playing Visualizer
            ZStack {
                if isCurrent {
                    PlayingVisualizerView(isAnimating: player.isPlaying, color: Theme.accent)
                } else {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.secondaryText.opacity(0.5))
                }
            }
            .frame(width: 30) // Fixed width alignment
            
            // Cover
            CachedAsyncImage(url: song.coverUrl) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 48, height: 48)
            .cornerRadius(12)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(song.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(song.isUnavailable && !SettingsManager.shared.unblockEnabled ? Theme.text.opacity(0.4) : (isCurrent ? Theme.accent : Theme.text))
                    .lineLimit(1)
                
                // Artist & Badges
                HStack(spacing: 6) {
                    // 无版权标识
                    if song.isUnavailable && !SettingsManager.shared.unblockEnabled {
                        Text("无版权")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Theme.secondaryText.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Theme.secondaryText.opacity(0.4), lineWidth: 0.5)
                            )
                    } else if isCurrent && player.isCurrentSongUnblocked {
                        // 当前播放的解灰歌曲统一显示"解灰"
                        Text("解灰")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Theme.accent, lineWidth: 0.5)
                            )
                    } else if song.isUnavailable && SettingsManager.shared.unblockEnabled {
                        // 未播放的无版权歌曲，解灰开启时显示"解灰"
                        Text("解灰")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Theme.accent, lineWidth: 0.5)
                            )
                    } else if let badge = song.qualityBadge {
                        let maxQuality = song.maxQuality
                        // Only show if VIP or special quality
                        if maxQuality.isVIP || maxQuality == .lossless || maxQuality == .hires {
                            Text(badge)
                                .font(.system(size: maxQuality.isBadgeChinese ? 7 : 8, weight: .bold)) // Smaller font for Chinese
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
                        .foregroundColor(song.isUnavailable && !SettingsManager.shared.unblockEnabled ? Theme.secondaryText.opacity(0.5) : Theme.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            

        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            isCurrent ? Theme.accent.opacity(0.05) : Color.clear
        )
        .contentShape(Rectangle())
        // 内置上下文菜单 - 长按显示
        .contextMenu {
            // 下一首播放
            Button {
                PlayerManager.shared.playNext(song: song)
            } label: {
                Label(LocalizedStringKey("action_play_next"), systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            // 加入队列
            Button {
                PlayerManager.shared.addToQueue(song: song)
            } label: {
                Label(LocalizedStringKey("action_add_to_queue"), systemImage: "text.append")
            }
            
            Divider()
            
            // 歌手详情 (如果有回调)
            if let artistId = song.ar?.first?.id, let onArtistTap = onArtistTap {
                Button {
                    onArtistTap(artistId)
                } label: {
                    Label(LocalizedStringKey("action_artist"), systemImage: "person.circle")
                }
            }
            
            // 歌曲详情 (如果有回调)
            if let onDetailTap = onDetailTap {
                Button {
                    onDetailTap(song)
                } label: {
                    Label(LocalizedStringKey("action_details"), systemImage: "info.circle")
                }
            }
        }
    }
}

// Extension to wrap SongListRow in a Button for easy usage
extension SongListRow {
    func asButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98, opacity: 0.8))
    }
}
