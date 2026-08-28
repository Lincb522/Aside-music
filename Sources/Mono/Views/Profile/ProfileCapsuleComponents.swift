import Combine
import QQMusicKit
import SwiftUI

struct CapsuleProfileMetricTile: View {
    let value: String
    let label: String
    let tint: Color
    let icon: MonoIcon.IconType

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                CapsuleIconBadge(icon: icon, tint: tint, size: 32)

                Spacer(minLength: 4)

                Capsule()
                    .fill(tint.opacity(0.72))
                    .frame(width: 24, height: 7)
            }

            Text(value)
                .font(CapsuleStyle.titleFont(18, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(CapsuleStyle.labelFont(9.5, weight: .semibold))
                .foregroundStyle(CapsuleStyle.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(12)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 22,
                elevated: true,
                tint: CapsuleStyle.surfaceRaised.opacity(0.92)
            )
        )
    }
}

struct CapsuleProfilePortalTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                CapsuleIconBadge(icon: icon, tint: tint, size: 38)

                Spacer(minLength: 8)

                Text(value)
                    .font(CapsuleStyle.labelFont(9.5, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                    )
            }

            Text(title)
                .font(CapsuleStyle.titleFont(15, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 114, alignment: .topLeading)
        .padding(14)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 26,
                elevated: true,
                tint: CapsuleStyle.surface.opacity(0.94)
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct CapsuleProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 118, height: 92) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(CapsuleStyle.surfaceTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 118, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.9), lineWidth: 1)
                )

                ZStack {
                    Capsule()
                        .fill(isPlaying ? CapsuleStyle.accent : CapsuleStyle.surfaceRaised)
                        .frame(width: 42, height: 32)
                        .shadow(color: CapsuleStyle.accent.opacity(isPlaying ? 0.18 : 0.05), radius: 8, x: 0, y: 4)

                    if isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: CapsuleStyle.readableLabel(on: CapsuleStyle.accent))
                            .frame(width: 17, height: 13)
                    } else {
                        MonoIcon(icon: .play, size: 12, color: CapsuleStyle.accent, lineWidth: 1.8)
                    }
                }
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(CapsuleStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(CapsuleStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(CapsuleStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 118, alignment: .leading)
        }
        .padding(10)
        .background(CapsuleSurfaceBackground(cornerRadius: 28, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
