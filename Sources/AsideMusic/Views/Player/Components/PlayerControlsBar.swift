import SwiftUI

/// 播放器共享控制按钮栏
struct PlayerControlsBar: View {
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    
    var contentColor: Color = .asideTextPrimary
    var secondaryColor: Color = .asideTextSecondary
    var showSecondaryRow: Bool = true
    var onShowPlaylist: () -> Void = {}
    var onShowComments: () -> Void = {}
    var onShowEQ: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 16) {
            // 主控制行
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    AsideIcon(icon: player.mode.asideIcon, size: 22, color: secondaryColor)
                }
                .frame(width: 44)
                
                Spacer()
                
                Button(action: { player.previous() }) {
                    AsideIcon(icon: .previous, size: 32, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: player.currentSong?.id)
                
                Spacer()
                
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.asideGlassTint)
                            .frame(width: 72, height: 72)
                            .glassEffect(.regular, in: .circle)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.asideIconForeground))
                                .scaleEffect(1.2)
                        } else {
                            AsideIcon(icon: player.isPlaying ? .pause : .play, size: 32, color: .asideIconForeground)
                        }
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                .sensoryFeedback(.impact(weight: .medium), trigger: player.isPlaying)
                
                Spacer()
                
                Button(action: { player.next() }) {
                    AsideIcon(icon: .next, size: 32, color: contentColor)
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                Spacer()
                
                Button(action: onShowPlaylist) {
                    AsideIcon(icon: .list, size: 22, color: secondaryColor)
                }
                .frame(width: 44)
            }
            
            // 副控制行（评论 + 下载）
            if showSecondaryRow, let song = player.currentSong {
                HStack(spacing: 0) {
                    Button(action: onShowComments) {
                        AsideIcon(icon: .comment, size: 22, color: secondaryColor, lineWidth: 1.4)
                    }
                    .frame(width: 44)
                    
                    Spacer()
                    
                    Button {
                        if !downloadManager.isDownloaded(songId: song.id) {
                            if song.isQQMusic {
                                downloadManager.downloadQQ(song: song, quality: player.qqMusicQuality)
                            } else {
                                downloadManager.download(song: song, quality: player.soundQuality)
                            }
                        }
                    } label: {
                        AsideIcon(
                            icon: .playerDownload,
                            size: 22,
                            color: downloadManager.isDownloaded(songId: song.id) ? .asideTextSecondary : secondaryColor,
                            lineWidth: 1.4
                        )
                    }
                    .disabled(downloadManager.isDownloaded(songId: song.id))
                    .frame(width: 44)
                }
            }
        }
    }
}
