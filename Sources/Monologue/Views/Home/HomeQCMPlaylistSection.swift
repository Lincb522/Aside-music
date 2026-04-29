import SwiftUI

/// QQ 推荐歌单 — 宽封面横滑，每张卡片带底部渐变叠层标题
/// 视觉上区别于 NCM 歌单的 2x2 网格卡片
struct HomeQQPlaylistSection: View {
    let playlists: [Playlist]
    var onViewAll: (() -> Void)? = nil
    let onTap: (Playlist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 7) {
                        Circle()
                            .fill(NeumorphicStyle.isActive ? NeumorphicStyle.sage : Color.green)
                            .frame(width: 7, height: 7)

                        Text(LocalizedStringKey("qq_recommend_playlists"))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                            .tracking(NeumorphicStyle.isActive ? 0 : -0.3)
                    }

                    Text(NSLocalizedString("qq_recommend_playlists_desc", comment: ""))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }
                Spacer()
                
                if let onViewAll {
                    Button(action: onViewAll) {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey("view_all"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            MonologueIcon(icon: .chevronRight, size: 9, color: .monologueTextSecondary, lineWidth: 1.6)
                        }
                        .foregroundColor(.monologueTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true)
                            } else {
                                Capsule().fill(Color.monologueGlassTint)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            // 宽封面横滑
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(playlists.prefix(8)) { playlist in
                        Button(action: { onTap(playlist) }) {
                            widePlaylistCard(playlist)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        }
    }

    private var qqW: CGFloat { DeviceLayout.qqCardWidth }
    private var qqH: CGFloat { DeviceLayout.qqCardHeight }

    private func widePlaylistCard(_ playlist: Playlist) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: qqW, height: qqH)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // 悬浮在底部的毛玻璃胶囊层
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                if let count = playlist.playCount, count > 0 {
                    HStack(spacing: 3) {
                        MonologueIcon(icon: .play, size: 8, color: .monologueTextSecondary)
                        Text(formatCount(count))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                }
            }
            .modifier(QQPlaylistInfoSurfaceModifier())
            .padding(8) // 让胶囊层内敛并悬浮
        }
        .frame(width: qqW, height: qqH)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true)
            }
        }
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

private struct QQPlaylistInfoSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if NeumorphicStyle.isActive {
            content
        } else {
            content.monologueGlass(cornerRadius: 16)
        }
    }
}
