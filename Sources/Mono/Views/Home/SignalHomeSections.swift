import SwiftUI

struct SignalHomeHero: View {
    let banners: [Banner]
    let onTap: (Banner) -> Void

    @State private var selection = 0

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $selection) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    Button(action: { onTap(banner) }) {
                        HomeBannerArtwork(
                            url: banner.imageUrl,
                            cornerRadius: SignalStyle.cardRadius,
                            placeholder: { SignalStyle.controlPressed }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.78)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)
                        }
                        .overlay(alignment: .bottomLeading) {
                            HStack(alignment: .bottom, spacing: 12) {
                                if let title = banner.typeTitle, !title.isEmpty {
                                    Text(title)
                                        .font(SignalStyle.bodyFont(16, weight: .semibold))
                                        .foregroundStyle(Color.white)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)

                                Text(String(format: "%02d / %02d", index + 1, banners.count))
                                    .font(SignalStyle.monoFont(9, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.72))
                                    .monospacedDigit()
                            }
                            .padding(15)
                        }
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.988))
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: DeviceLayout.bannerHeight)

            if banners.count > 1 {
                HStack(spacing: 4) {
                    ForEach(banners.indices, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index == selection ? SignalStyle.accent : SignalStyle.inkMuted.opacity(0.32))
                            .frame(width: index == selection ? 24 : 5, height: 2)
                            .animation(.easeOut(duration: 0.18), value: selection)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(
            .horizontal,
            DeviceLayout.homeHorizontalPadding + (DeviceLayout.usesExpandedLayout ? 12 : 8)
        )
    }
}

struct SignalHomeSongSection: View {
    let title: String
    let songs: [Song]
    let onViewAll: () -> Void
    let onPlay: (Song) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var playback = SongRowPlaybackModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SignalHomeSectionHeader(title: title, count: songs.count, action: onViewAll)
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(songs.prefix(8).enumerated()), id: \.element.id) { index, song in
                        songArtwork(song, index: index)
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func songArtwork(_ song: Song, index: Int) -> some View {
        let size = tileSize(index: index)
        let isCurrent = playback.currentSongId == song.id

        return Button(action: { onPlay(song) }) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: song.coverUrl?.sized(640), width: size, height: size) {
                    SignalStyle.controlPressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(SignalStyle.bodyFont(index == 0 ? 16 : 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(song.artistName)
                        .font(SignalStyle.labelFont(index == 0 ? 11 : 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(index == 0 ? 14 : 11)

                if isCurrent {
                    PlayingVisualizerView(isAnimating: playback.isPlaying, color: SignalStyle.accent)
                        .frame(width: 22, height: 14)
                        .padding(index == 0 ? 14 : 11)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.975))
        .accessibilityLabel("\(song.name), \(song.artistName)")
    }

    private func tileSize(index: Int) -> CGFloat {
        if horizontalSizeClass == .regular {
            return index == 0 ? 270 : 190
        }
        return index == 0 ? 220 : 158
    }
}

struct SignalHomePlaylistSection: View {
    let title: String
    let playlists: [Playlist]
    let onViewAll: () -> Void
    let onTap: (Playlist) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SignalHomeSectionHeader(title: title, count: playlists.count, action: onViewAll)
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(playlists.prefix(8).enumerated()), id: \.element.id) { index, playlist in
                        playlistArtwork(playlist, index: index)
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func playlistArtwork(_ playlist: Playlist, index: Int) -> some View {
        let width = tileWidth(index: index)
        let height = tileHeight(index: index)

        return Button(action: { onTap(playlist) }) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(720), width: width, height: height) {
                    SignalStyle.controlPressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)

                LinearGradient(
                    colors: [Color.black.opacity(0.02), Color.black.opacity(0.16), Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.sourceShortName.uppercased())
                        .font(SignalStyle.monoFont(8.5, weight: .semibold))
                        .foregroundStyle(SignalStyle.accent)

                    Text(playlist.name)
                        .font(SignalStyle.bodyFont(index == 0 ? 17 : 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(index == 0 ? 3 : 2)
                        .multilineTextAlignment(.leading)

                    if let count = playlist.trackCount {
                        Text("\(count) \(String(localized: "songs_unit"))")
                            .font(SignalStyle.monoFont(8.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.62))
                            .monospacedDigit()
                    }
                }
                .padding(index == 0 ? 15 : 11)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: SignalStyle.cardRadius, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.975))
        .accessibilityLabel(playlist.name)
    }

    private func tileWidth(index: Int) -> CGFloat {
        if horizontalSizeClass == .regular {
            return index == 0 ? 300 : 210
        }
        return index == 0 ? 232 : 164
    }

    private func tileHeight(index: Int) -> CGFloat {
        if horizontalSizeClass == .regular {
            return index == 0 ? 230 : 210
        }
        return index == 0 ? 184 : 174
    }
}

struct SignalHomeSectionHeader: View {
    let title: String
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(title)
                    .font(SignalStyle.titleFont(22, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)

                Text(String(format: "%02d", count))
                    .font(SignalStyle.monoFont(9, weight: .medium))
                    .foregroundStyle(SignalStyle.inkMuted)
                    .monospacedDigit()

                Spacer(minLength: 8)

                MonoIcon(icon: .chevronRight, size: 10, color: SignalStyle.inkMuted, lineWidth: 1.6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
