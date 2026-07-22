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
            MonologueGlassContainer(spacing: 12) {
                HStack(spacing: 0) {
                    Button(action: { player.switchMode() }) {
                        MonologueIcon(icon: player.mode.monologueIcon, size: 22, color: secondaryColor)
                    }
                    .frame(width: 44)

                    Spacer()

                    Button(action: { player.previous() }) {
                        MonologueIcon(icon: .previous, size: 32, color: contentColor)
                            .frame(width: 44, height: 44)
                            .monologueGlassCircle(interactive: true)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .compatImpactFeedback(weight: .light, trigger: player.currentSong?.id)

                    Spacer()

                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.accent : Color.monologueGlassTint)

                            if player.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.onAccent : Color.monologueIconForeground))
                                    .scaleEffect(1.2)
                            } else {
                                MonologueIcon(
                                    icon: player.isPlaying ? .pause : .play,
                                    size: 32,
                                    color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.onAccent : .monologueIconForeground
                                )
                            }
                        }
                        .frame(width: DeviceLayout.playerPlayButtonSize, height: DeviceLayout.playerPlayButtonSize)
                        .monologueGlassCircle(interactive: true)
                        .shadow(color: Color.black.opacity(MinimalWhiteStyle.isActive ? 0.08 : 0.2), radius: MinimalWhiteStyle.isActive ? 8 : 10, x: 0, y: MinimalWhiteStyle.isActive ? 3 : 5)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
                    .compatImpactFeedback(weight: .medium, trigger: player.isPlaying)

                    Spacer()

                    Button(action: { player.next() }) {
                        MonologueIcon(icon: .next, size: 32, color: contentColor)
                            .frame(width: 44, height: 44)
                            .monologueGlassCircle(interactive: true)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

                    Spacer()

                    Button(action: onShowPlaylist) {
                        MonologueIcon(icon: .list, size: 22, color: secondaryColor)
                    }
                    .frame(width: 44)
                }
            }
            
            if showSecondaryRow, let song = player.currentSong {
                HStack(spacing: 0) {
                    Button(action: onShowComments) {
                        MonologueIcon(icon: .comment, size: 22, color: secondaryColor, lineWidth: 1.4)
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
                    } else {
                        // 沉浸模式按钮 — 下载隐藏期间占用原下载按钮的位置
                        Button {
                            ImmersiveModeController.shared.present()
                        } label: {
                            MonologueIcon(icon: .immersive, size: 22, color: secondaryColor, lineWidth: 1.4)
                        }
                        .frame(width: 44)
                    }
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
