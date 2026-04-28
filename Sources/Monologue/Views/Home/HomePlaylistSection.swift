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
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.6)
                                .rotationEffect(.degrees(phase.isIdentity ? 0 : phase.value * -2))
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

    // MARK: - 卡片：叠层封面 + glass 信息栏

    private var cardSize: CGFloat { DeviceLayout.playlistCardSize }

    private func playlistCard(_ playlist: Playlist, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    Rectangle()
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: cardSize, height: cardSize)
                .clipped()

                if let count = playlist.playCount, count > 0 {
                    HStack(spacing: 3) {
                        MonologueIcon(icon: .play, size: 7, color: .white)
                        Text(formatCount(count))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(light: .black.opacity(0.15), dark: .white.opacity(0.12))))
                    .modifier(PlaylistCountSurfaceModifier())
                    .padding(10)
                }
            }
            .frame(width: cardSize, height: cardSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: DeviceLayout.isPad ? 15 : 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: DeviceLayout.isPad ? 42 : 36, alignment: .top)

                Text(playlist.trackCount.map { "\($0) " + NSLocalizedString("songs_unit", comment: "") } ?? " ")
                    .font(.system(size: DeviceLayout.isPad ? 12 : 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: cardSize, alignment: .leading)
            .background(NeumorphicStyle.isActive ? NeumorphicStyle.surfaceRaised.opacity(0.74) : Color.monologueGlassTint)
            .modifier(PlaylistCardInfoSurfaceModifier())
        }
        .frame(width: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: DeviceLayout.isPad ? 24 : 20, style: .continuous))
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: DeviceLayout.isPad ? 24 : 20, elevated: true)
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

private struct PlaylistCountSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if NeumorphicStyle.isActive {
            content
                .foregroundStyle(NeumorphicStyle.ink)
                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true))
        } else {
            content.monologueGlassCapsule()
        }
    }
}

private struct PlaylistCardInfoSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if NeumorphicStyle.isActive {
            content
        } else {
            content.monologueGlass(cornerRadius: 0)
        }
    }
}
