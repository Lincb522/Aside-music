import Combine
import QQMusicKit
import SwiftUI

struct MujiProfileLedgerRow: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 13) {
            MonoIcon(icon: icon, size: 15, color: tint, lineWidth: 1.4)
                .frame(width: 22, alignment: .leading)

            Text(title)
                .font(MujiStyle.bodyFont(15, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(value)
                .font(MujiStyle.labelFont(10, weight: .semibold))
                .foregroundStyle(MujiStyle.inkMuted)
                .tracking(1.1)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            MonoIcon(icon: .chevronRight, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.4)
        }
        .padding(.vertical, 13.5)
        .contentShape(Rectangle())
    }

    private var tint: Color {
        switch icon {
        case .cloud:
            return MujiStyle.tea
        case .download:
            return MujiStyle.indigo
        case .storage:
            return MujiStyle.straw
        default:
            return MujiStyle.clay
        }
    }
}

struct MujiProfileDivider: View {
    var body: some View {
        MujiListDivider()
            .padding(.leading, 35)
    }
}

extension View {
    @ViewBuilder
    func themedProfileSurface(cornerRadius: CGFloat, mangaTint: Color = MangaStyle.bubbleWhite) -> some View {
        if MangaStyle.isActive {
            background(MangaCardBackground(cornerRadius: cornerRadius, elevated: true, tint: mangaTint))
        } else if PetWhiteStyle.isActive {
            background(
                PetWhiteSurfaceBackground(
                    cornerRadius: cornerRadius,
                    elevated: true,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: PetWhiteStyle.mint
                )
            )
        } else if MujiStyle.isActive {
            // Muji：清新水洗底，柔圆角不描边
            background(
                RoundedRectangle(cornerRadius: max(cornerRadius, MujiStyle.cardRadius), style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
            )
        } else if NeumorphicStyle.isActive {
            background(NeumorphicSurfaceBackground(cornerRadius: cornerRadius, elevated: true, lightweight: true))
        } else if CapsuleStyle.isActive {
            background(CapsuleSurfaceBackground(cornerRadius: min(max(cornerRadius, 22), 30), elevated: true, tint: CapsuleStyle.surface.opacity(0.94)))
        } else if SignalStyle.isActive {
            background(SignalSurfaceBackground(cornerRadius: min(max(cornerRadius, 18), 28), elevated: true, fill: SignalStyle.device))
        } else if SequoiaStyle.isActive {
            background(SequoiaSurfaceBackground(cornerRadius: min(max(cornerRadius, 16), 22), elevated: true, role: .chrome))
        } else if LiquidGlassStyle.isActive {
            background(LiquidGlassSurfaceBackground(cornerRadius: min(max(cornerRadius, 18), 28), elevated: true, role: .chrome))
        } else {
            monoGlass(cornerRadius: cornerRadius)
        }
    }
}
