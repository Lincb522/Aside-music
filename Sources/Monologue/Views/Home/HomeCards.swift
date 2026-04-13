import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .tracking(-0.3)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }
            }
            Spacer()
            if let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("view_all"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 8, color: .monologueTextSecondary)
                    }
                    .foregroundColor(.monologueTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.monologueTextSecondary.opacity(0.06)))
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .padding(.bottom, 1)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }
}

// MARK: - Song Card

struct SongCard: View {
    let song: Song
    let onTap: () -> Void
    @ObservedObject private var player = PlayerManager.shared

    private var isCurrent: Bool { player.currentSong?.id == song.id }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.monologueSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: DeviceLayout.isPad ? 180 : 140, height: DeviceLayout.isPad ? 180 : 140)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if isCurrent {
                        PlayingVisualizerView(isAnimating: player.isPlaying, color: .white)
                            .frame(width: 16)
                            .padding(8)
                            .background(Circle().fill(.black.opacity(0.4)))
                            .padding(6)
                    }
                }
                .frame(width: DeviceLayout.isPad ? 180 : 140, height: DeviceLayout.isPad ? 180 : 140)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(isCurrent ? .monologueAccent : .monologueTextPrimary)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: DeviceLayout.isPad ? 180 : 140)
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }
}

// MARK: - Playlist Card

struct PlaylistVerticalCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.monologueSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 190 : 150, height: DeviceLayout.isPad ? 190 : 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let count = playlist.playCount, count > 0 {
                    HStack(spacing: 3) {
                        MonologueIcon(icon: .play, size: 7, color: .primary)
                        Text(formatCount(count))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.monologueGlassTint))
                    .monologueGlassCapsule()
                    .padding(8)
                }
            }
            .frame(width: DeviceLayout.isPad ? 190 : 150, height: DeviceLayout.isPad ? 190 : 150)

            Text(playlist.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: DeviceLayout.isPad ? 190 : 150, alignment: .leading)
                .frame(height: 34, alignment: .top)
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
