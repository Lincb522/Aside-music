import SwiftUI

/// 每日推荐 — 宽幅横卡横滑，封面全覆盖 + 底部渐变叠文字
struct HomeDailySection: View {
    let songs: [Song]
    let onViewAll: () -> Void
    let onPlay: (Song) -> Void

    @ObservedObject private var player = PlayerManager.shared
    @State private var animatedCount: Int = 0
    @State private var countAnimated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(songs.prefix(15).enumerated()), id: \.element.id) { idx, song in
                        Button(action: { onPlay(song) }) {
                            dailySongCard(song, rank: idx + 1)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey("made_for_you"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .tracking(-0.3)

                HStack(spacing: 0) {
                    Text("\(animatedCount)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .contentTransition(.numericText(countsDown: false))

                    Text(" " + NSLocalizedString("fresh_tunes_daily", comment: ""))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            }

            Spacer()

            Button(action: onViewAll) {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("view_all"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    AsideIcon(icon: .chevronRight, size: 9, color: .asideTextSecondary)
                }
                .foregroundColor(.asideTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.asideTextSecondary.opacity(0.08)))
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 20)
        .onAppear {
            guard !countAnimated else { return }
            countAnimated = true
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animatedCount = songs.count
            }
        }
    }

    // MARK: - Song Card

    @Environment(\.colorScheme) private var colorScheme

    private let cardWidth: CGFloat = 120

    private func dailySongCard(_ song: Song, rank: Int) -> some View {
        let isCurrent = player.currentSong?.id == song.id
        let isPlaying = isCurrent && player.isPlaying

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: song.coverUrl) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.asideSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardWidth)
                .clipped()

                // 排名角标
                Text("\(rank)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(light: .black.opacity(0.15), dark: .white.opacity(0.12))))
                    .glassEffect(.regular, in: .rect(cornerRadius: 7))
                    .padding(6)

                // 正在播放指示
                if isCurrent {
                    PlayingVisualizerView(isAnimating: isPlaying, color: .white)
                        .frame(width: 20, height: 16)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: cardWidth, height: cardWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isCurrent ? .asideAccent : .asideTextSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: cardWidth, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 脉冲光圈动画（正在播放的封面）

struct PulseRingView: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(pulse ? 0 : 0.5), lineWidth: pulse ? 6 : 2)
            .scaleEffect(pulse ? 1.08 : 1.0)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
    }
}
