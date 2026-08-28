import Combine
import QQMusicKit
import SwiftUI

struct NeumorphicProfileMetricTile: View {
    let value: String
    let label: String
    let tint: Color
    let icon: MonoIcon.IconType

    var body: some View {
        HStack(spacing: 8) {
            MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.55)
                .frame(width: 28, height: 28)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 10,
                        elevated: false,
                        pressed: true,
                        tint: tint.opacity(0.16),
                        lightweight: true
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(NeumorphicStyle.titleFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(label)
                    .font(NeumorphicStyle.labelFont(8.5, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: true, lightweight: true))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.28), lineWidth: 0.7)
        }
    }
}

struct NeumorphicProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 118, height: 94) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 118, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                }

                ZStack {
                    Circle()
                        .fill(NeumorphicStyle.surfaceRaised)
                        .frame(width: 32, height: 32)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true, lightweight: true))
                        .clipShape(Circle())

                    if isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                            .frame(width: 16, height: 13)
                    } else {
                        MonoIcon(icon: .play, size: 11, color: NeumorphicStyle.accent, lineWidth: 1.7)
                    }
                }
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(NeumorphicStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(NeumorphicStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 118, alignment: .leading)
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct NeumorphicProfileShortcutTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                MonoIcon(icon: icon, size: 17, color: tint, lineWidth: 1.55)
                    .frame(width: 38, height: 38)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 14,
                            elevated: false,
                            pressed: true,
                            tint: tint.opacity(0.15),
                            lightweight: true
                        )
                    )

                Spacer(minLength: 8)

                MonoIcon(icon: .chevronRight, size: 12, color: NeumorphicStyle.inkMuted, lineWidth: 1.6)
                    .frame(width: 28, height: 28)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 10, elevated: false, pressed: true, lightweight: true))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(NeumorphicStyle.labelFont(14, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Text(value)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(14)
        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.28), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
