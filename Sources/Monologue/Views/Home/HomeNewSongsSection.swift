import SwiftUI

/// QQ 新歌 — 大号 "NEW" shimmer 流光 + 横滑排行卡片
struct HomeNewSongsSection: View {
    let songs: [Song]
    let onPlay: (Song) -> Void

    @ObservedObject private var player = PlayerManager.shared
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text("NEW")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.monologueTextPrimary, .monologueTextPrimary.opacity(0.4), .monologueTextPrimary],
                            startPoint: UnitPoint(x: shimmerPhase, y: 0.5),
                            endPoint: UnitPoint(x: shimmerPhase + 0.6, y: 0.5)
                        )
                    )
                    .onAppear {
                        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                            shimmerPhase = 1.5
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("qq_new_songs", comment: ""))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text(NSLocalizedString("qq_new_songs_desc", comment: ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            // 横滑排行卡片
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(songs.prefix(8).enumerated()), id: \.element.id) { idx, song in
                        Button(action: { onPlay(song) }) {
                            rankedCard(song: song, rank: idx + 1)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * -6)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        }
    }

    private func rankedCard(song: Song, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面区
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: song.coverUrl) {
                    Rectangle()
                        .fill(Color.monologueSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.newSongCardSize, height: DeviceLayout.newSongCardSize)
                .clipped()
                
                // 正在播放 — 脉冲光圈
                .overlay {
                    if player.currentSong?.id == song.id {
                        PulseRingView(color: .white)
                    }
                }

                // 排名数字
                Text("\(rank)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .padding(.leading, 10)
                    .padding(.top, 8)

                // 播放指示器
                if player.currentSong?.id == song.id {
                    PlayingVisualizerView(isAnimating: player.isPlaying, color: .white)
                        .frame(width: 18)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: DeviceLayout.newSongCardSize, height: DeviceLayout.newSongCardSize)

            // 底部信息
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(player.currentSong?.id == song.id ? .monologueAccent : .monologueTextPrimary)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.monologueGlassTint)
            .monologueGlass(cornerRadius: 0)
        }
        .frame(width: DeviceLayout.newSongCardSize)
        .clipShape(RoundedRectangle(cornerRadius: DeviceLayout.isPad ? 24 : 20, style: .continuous))
    }
}
