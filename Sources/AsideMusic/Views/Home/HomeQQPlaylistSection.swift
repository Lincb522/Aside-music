import SwiftUI

/// QQ 推荐歌单 — 宽封面横滑，每张卡片带底部渐变叠层标题
/// 视觉上区别于 NCM 歌单的 2x2 网格卡片
struct HomeQQPlaylistSection: View {
    let playlists: [Playlist]
    let onTap: (Playlist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题行
            HStack(alignment: .center, spacing: 8) {
                // 可选：QQ 品牌色小圆点
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text(LocalizedStringKey("QQ音乐·推荐歌单"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .tracking(-0.3)
            }
            .padding(.horizontal, 20)

            // 宽封面横滑
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(playlists.prefix(8)) { playlist in
                        Button(action: { onTap(playlist) }) {
                            widePlaylistCard(playlist)
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
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

    private func widePlaylistCard(_ playlist: Playlist) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.asideSeparator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 220, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // 悬浮在底部的毛玻璃胶囊层
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                if let count = playlist.playCount, count > 0 {
                    HStack(spacing: 3) {
                        AsideIcon(icon: .play, size: 8, color: .asideTextSecondary)
                        Text(formatCount(count))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .asideGlass(cornerRadius: 16)
            .padding(8) // 让胶囊层内敛并悬浮
        }
        .frame(width: 220, height: 140)
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
