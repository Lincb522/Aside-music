import Combine
import QQMusicKit
import SwiftUI

struct PetWhiteProfileMetricPill: View {
    let value: String
    let label: String
    let icon: MonoIcon.IconType
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            PetWhiteClayPuck(shape: Circle(), tint: tint)
                .frame(width: 30, height: 30)
                .overlay(
                    PetWhitePackIcon(icon: icon, size: 14, visualScale: 1.02, lineWidth: 1.6)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(PetWhiteStyle.titleFont(15, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(label)
                    .font(PetWhiteStyle.labelFont(9.5))
                    .foregroundStyle(PetWhiteStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: PetWhiteStyle.compactRadius,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
    }
}

struct PetWhiteProfileActionTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                PetWhiteClayPuck(shape: Circle(), tint: tint)
                    .frame(width: 36, height: 36)
                    .overlay(
                        PetWhitePackIcon(icon: icon, size: 17, visualScale: 1.04, lineWidth: 1.7)
                    )

                Spacer(minLength: 8)

                PetWhitePackIcon(icon: .chevronRight, size: 14, visualScale: 1.02, fallbackColor: PetWhiteStyle.inkMuted)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PetWhiteStyle.bodyFont(14, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(value)
                    .font(PetWhiteStyle.labelFont(11))
                    .foregroundStyle(PetWhiteStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(14)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: PetWhiteStyle.cardRadius,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous))
    }
}

// MARK: - Menu Row
