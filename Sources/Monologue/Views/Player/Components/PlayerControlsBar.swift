import SwiftUI

/// 播放器共享控制按钮栏
struct PlayerControlsBar: View {
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showDownloadSheet = false
    
    var contentColor: Color = .monologueTextPrimary
    var secondaryColor: Color = .monologueTextSecondary
    var showSecondaryRow: Bool = true
    var onShowPlaylist: () -> Void = {}
    var onShowComments: () -> Void = {}
    var onShowEQ: () -> Void = {}
    
    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button(action: { player.switchMode() }) {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 22, color: secondaryColor)
                }
                .frame(width: 44)
                
                Spacer()
                
                Button(action: { player.previous() }) {
                    MonologueIcon(icon: .previous, size: 32, color: contentColor)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: player.currentSong?.id)
                
                Spacer()
                
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.monologueGlassTint)
                            .frame(width: DeviceLayout.playerPlayButtonSize, height: DeviceLayout.playerPlayButtonSize)
                            .monologueGlassCircle()
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.monologueIconForeground))
                                .scaleEffect(1.2)
                        } else {
                            MonologueIcon(icon: player.isPlaying ? .pause : .play, size: 32, color: .monologueIconForeground)
                        }
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
                .sensoryFeedback(.impact(weight: .medium), trigger: player.isPlaying)
                
                Spacer()
                
                Button(action: { player.next() }) {
                    MonologueIcon(icon: .next, size: 32, color: contentColor)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                
                Spacer()
                
                Button(action: onShowPlaylist) {
                    MonologueIcon(icon: .list, size: 22, color: secondaryColor)
                }
                .frame(width: 44)
            }
            
            if showSecondaryRow, let song = player.currentSong {
                HStack(spacing: 0) {
                    Button(action: onShowComments) {
                        MonologueIcon(icon: .comment, size: 22, color: secondaryColor, lineWidth: 1.4)
                    }
                    .frame(width: 44)
                    
                    Spacer()
                    
                    Button {
                        if !downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic) {
                            showDownloadSheet = true
                        }
                    } label: {
                        MonologueIcon(
                            icon: .playerDownload,
                            size: 22,
                            color: downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic)
                                ? .monologueTextSecondary
                                : secondaryColor,
                            lineWidth: 1.4
                        )
                    }
                    .disabled(downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic))
                    .frame(width: 44)
                }
            }
        }
        .monologueSheet(isPresented: $showDownloadSheet, preset: .compact){
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }

            }
        }
    }
}
