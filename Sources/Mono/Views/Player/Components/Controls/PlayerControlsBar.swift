import SwiftUI

/// 播放器共享控制按钮栏
struct PlayerControlsBar: View {
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showDownloadSheet = false
    
    var contentColor: Color = .monoTextPrimary
    var secondaryColor: Color = .monoTextSecondary
    var showSecondaryRow: Bool = true
    var onShowPlaylist: () -> Void = {}
    var onShowComments: () -> Void = {}
    var onShowEQ: () -> Void = {}
    
    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 16) {
            MonoGlassContainer(spacing: 12) {
                HStack(spacing: 0) {
                    Button(action: { player.switchMode() }) {
                        MonoIcon(icon: player.mode.monoIcon, size: 22, color: secondaryColor)
                    }
                    .frame(width: 44)

                    Spacer()

                    Button(action: { player.previous() }) {
                        MonoIcon(icon: .previous, size: 32, color: contentColor)
                            .frame(width: 44, height: 44)
                            .monoGlassCircle(interactive: true)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                    .compatImpactFeedback(weight: .light, trigger: player.currentSong?.id)

                    Spacer()

                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.accent : Color.monoGlassTint)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.onAccent : Color.monoIconForeground))
                                    .scaleEffect(1.2)
                            } else {
                                MonoIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 32,
                                    color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.onAccent : .monoIconForeground
                                )
                            }
                        }
                        .frame(width: DeviceLayout.playerPlayButtonSize, height: DeviceLayout.playerPlayButtonSize)
                        .monoGlassCircle(interactive: true)
                        .shadow(color: Color.black.opacity(MinimalWhiteStyle.isActive ? 0.08 : 0.2), radius: MinimalWhiteStyle.isActive ? 8 : 10, x: 0, y: MinimalWhiteStyle.isActive ? 3 : 5)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
                    .compatImpactFeedback(weight: .medium, trigger: player.isPlaying)

                    Spacer()

                    Button(action: { player.next() }) {
                        MonoIcon(icon: .next, size: 32, color: contentColor)
                            .frame(width: 44, height: 44)
                            .monoGlassCircle(interactive: true)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    Spacer()

                    Button(action: onShowPlaylist) {
                        MonoIcon(icon: .list, size: 22, color: secondaryColor)
                    }
                    .frame(width: 44)
                }
            }
            
            if showSecondaryRow, let song = player.currentSong {
                HStack(spacing: 0) {
                    Button(action: onShowComments) {
                        MonoIcon(icon: .comment, size: 22, color: secondaryColor, lineWidth: 1.4)
                    }
                    .frame(width: 44)
                    
                    Spacer()
                    
                    if AppConfig.Features.downloadEnabled {
                        // 下载按钮（下载功能暂时隐藏，后期恢复时打开 AppConfig.Features.downloadEnabled）
                        Button {
                            if !downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic) {
                                showDownloadSheet = true
                            }
                        } label: {
                            MonoIcon(
                                icon: .playerDownload,
                                size: 22,
                                color: downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic)
                                    ? .monoTextSecondary
                                    : secondaryColor,
                                lineWidth: 1.4
                            )
                        }
                        .disabled(downloadManager.isDownloaded(songId: song.id, isQQ: song.isQQMusic))
                        .frame(width: 44)
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
            }
        }
        .monoSheet(isPresented: $showDownloadSheet, preset: .compact){
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }

            }
        }
    }
}
