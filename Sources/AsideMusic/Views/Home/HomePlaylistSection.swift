import SwiftUI

/// NCM 推荐歌单 — 方形封面横滑 + glass 底栏信息
/// 区别于 QQ 歌单的宽横幅风格，这里用正方形卡片 + 毛玻璃信息条
struct HomeNCMPlaylistSection: View {
    let playlists: [Playlist]
    var onViewAll: (() -> Void)? = nil
    let onTap: (Playlist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: NSLocalizedString("playlists_love", comment: ""),
                subtitle: NSLocalizedString("based_on_taste", comment: ""),
                action: onViewAll
            )

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Array(playlists.prefix(10).enumerated()), id: \.element.id) { idx, playlist in
                        Button(action: { onTap(playlist) }) {
                            playlistCard(playlist, index: idx)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.6)
                                .rotationEffect(.degrees(phase.isIdentity ? 0 : phase.value * -2))
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

    // MARK: - 卡片：正方形封面 + glass 底栏

    private func playlistCard(_ playlist: Playlist, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面区
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    Rectangle()
                        .fill(Color.asideSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 160, height: 160)
                .clipped()

                // 播放量角标
                if let count = playlist.playCount, count > 0 {
                    HStack(spacing: 3) {
                        AsideIcon(icon: .play, size: 7, color: .white)
                        Text(formatCount(count))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(light: .black.opacity(0.15), dark: .white.opacity(0.12))))
                    .glassEffect(.regular, in: .capsule)
                    .padding(10)
                }
            }
            .frame(width: 160, height: 160)

            // 底栏信息
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let count = playlist.trackCount {
                    Text("\(count) " + NSLocalizedString("songs_unit", comment: ""))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(light: .white, dark: Color(hex: "1C1C1E")))
        }
        .frame(width: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func formatCount(_ count: Int?) -> String {
        guard let count else { return "0" }
        let locale = Locale.current
        if locale.language.languageCode?.identifier == "zh" {
            if count >= 100_000_000 {
                return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100_000_000)
            } else if count >= 10_000 {
                return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10_000)
            }
        } else {
            if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
            else if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
            else if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        }
        return "\(count)"
    }
}
