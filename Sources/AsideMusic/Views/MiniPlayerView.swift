import SwiftUI
import LiquidGlassEffect

struct MiniPlayerView: View {
    @ObservedObject var player = PlayerManager.shared
    @State private var showPlaylist = false
    
    var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CachedAsyncImage(url: song.coverUrl) {
                        Color.gray.opacity(0.3)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(.rounded(size: 16, weight: .bold))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            player.previous()
                        }) {
                            AsideIcon(icon: .previous, size: 16, color: .asideTextPrimary)
                        }
                        
                        Button(action: {
                            player.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.asideIconBackground)
                                    .frame(width: 44, height: 44)
                                
                                if player.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .asideIconForeground))
                                } else {
                                    AsideIcon(icon: player.isPlaying ? .pause : .play, size: 18, color: .asideIconForeground)
                                }
                            }
                        }
                        
                        Button(action: {
                            player.next()
                        }) {
                            AsideIcon(icon: .next, size: 16, color: .asideTextPrimary)
                        }
                        
                        Button(action: {
                            showPlaylist.toggle()
                        }) {
                            AsideIcon(icon: .list, size: 18, color: .asideTextPrimary)
                        }
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                        Capsule()
                            .fill(Color.asideIconBackground)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(16)
            .background {
                ZStack {
                    // 液态玻璃效果 - 使用较低帧率
                    LiquidGlassMetalView(cornerRadius: 24, backgroundCaptureFrameRate: 30)
                    
                    // 半透明叠加层
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.asideCardBackground.opacity(0.4))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .sheet(isPresented: $showPlaylist) {
                PlaylistPopupView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
