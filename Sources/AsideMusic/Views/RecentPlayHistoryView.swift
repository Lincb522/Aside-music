import SwiftUI

/// 最近播放 - 完整列表页
struct RecentPlayHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playerManager = PlayerManager.shared
    
    let songs: [Song]
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 导航栏
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.asideMilk)
                                .frame(width: 40, height: 40)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                            AsideIcon(icon: .back, size: 16, color: .asideTextPrimary)
                        }
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(LocalizedStringKey("profile_recently_played"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Text(String(format: String(localized: "profile_recent_count"), songs.count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    
                    Spacer()

                    // 全部播放按钮
                    Button(action: {
                        if let first = songs.first {
                            playerManager.play(song: first, in: songs)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.asideMilk)
                                .frame(width: 40, height: 40)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                            AsideIcon(icon: .play, size: 16, color: .asideTextPrimary)
                        }
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // 歌曲列表
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            SongListRow(
                                song: song,
                                index: index,
                                onArtistTap: nil,
                                onDetailTap: nil,
                                onAlbumTap: nil
                            )
                            .asButton {
                                playerManager.play(song: song, in: songs)
                            }
                        }
                    }
                    
                    Color.clear.frame(height: 120)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
