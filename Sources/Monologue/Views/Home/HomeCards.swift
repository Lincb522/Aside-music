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
                    .font(sectionTitleFont)
                    .foregroundColor(SignalStyle.isActive ? SignalStyle.ink : .monologueTextPrimary)
                    .tracking(MujiStyle.isActive ? 0.5 : 0)
                if let subtitle {
                    Text(subtitle)
                        .font(sectionSubtitleFont)
                        .foregroundColor(SignalStyle.isActive ? SignalStyle.inkSoft : .monologueTextSecondary)
                }
            }
            Spacer()
            if let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("view_all"))
                            .font(sectionActionFont)
                        MonologueIcon(icon: .chevronRight, size: 8, color: .monologueTextSecondary)
                    }
                    .foregroundColor(.monologueTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(actionBackground)
                    .overlay(Capsule().stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(0.45) : Color.clear, lineWidth: 0.6))
                }
                .buttonStyle(MonologueBouncingButtonStyle())
                .padding(.bottom, 1)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
    }

    private var sectionTitleFont: Font {
        if MujiStyle.isActive { return MujiStyle.titleFont(20, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(20, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.titleFont(20, weight: .bold) }
        return .system(size: 22, weight: .heavy, design: .rounded)
    }

    private var sectionSubtitleFont: Font {
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: .medium) }
        return .system(size: 12, weight: .semibold, design: .rounded)
    }

    private var sectionActionFont: Font {
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.labelFont(11, weight: .bold) }
        return .system(size: 11, weight: .bold, design: .rounded)
    }

    private var actionBackground: some View {
        Group {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
            } else {
                Capsule().fill(MujiStyle.isActive ? MujiStyle.surfaceRaised : Color.monologueTextSecondary.opacity(0.06))
            }
        }
    }
}

// MARK: - Song Card

struct SongCard: View {
    let song: Song
    let onTap: () -> Void
    @ObservedObject private var playback = SongRowPlaybackModel.shared

    private var isCurrent: Bool { playback.currentSongId == song.id }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: MujiStyle.isActive ? 6 : 18, style: .continuous)
                            .fill(Color.monologueSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: DeviceLayout.isPad ? 180 : 140, height: DeviceLayout.isPad ? 180 : 140)
                    .clipShape(RoundedRectangle(cornerRadius: MujiStyle.isActive ? 6 : 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: MujiStyle.isActive ? 6 : 18, style: .continuous).stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(0.45) : Color.clear, lineWidth: 0.6))

                    if isCurrent {
                        PlayingVisualizerView(isAnimating: playback.isPlaying, color: .white)
                            .frame(width: 16)
                            .padding(8)
                            .background(Circle().fill(.black.opacity(0.4)))
                            .padding(6)
                    }
                }
                .frame(width: DeviceLayout.isPad ? 180 : 140, height: DeviceLayout.isPad ? 180 : 140)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : .system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(isCurrent ? .monologueAccent : .monologueTextPrimary)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded))
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
                    RoundedRectangle(cornerRadius: MujiStyle.isActive ? 6 : 18, style: .continuous)
                        .fill(Color.monologueSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 190 : 150, height: DeviceLayout.isPad ? 190 : 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MujiStyle.isActive ? 6 : 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MujiStyle.isActive ? 6 : 18, style: .continuous).stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(0.45) : Color.clear, lineWidth: 0.6))

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
                .font(MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : .system(size: 13, weight: .semibold, design: .rounded))
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
