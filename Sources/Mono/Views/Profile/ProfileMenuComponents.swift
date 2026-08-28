import Combine
import QQMusicKit
import SwiftUI

struct ProfileMenuRow: View {
    let icon: MonoIcon.IconType
    let title: String
    var trailingText: String? = nil
    var petWhiteAssetName: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            profileMenuIcon

            Text(title)
                .font(MangaStyle.isActive ? MangaStyle.comicFont(15, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(15, weight: .regular) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(15, weight: .bold) : (SignalStyle.isActive ? SignalStyle.labelFont(15, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded))))))
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : .monoTextPrimary)))

            Spacer()

            if let text = trailingText {
                Text(text)
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(13, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .regular) : .system(size: 13, weight: .regular, design: .rounded))))))
                    .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : .monoTextSecondary)))
            }
            if PetWhiteStyle.isActive {
                PetWhitePackIcon(icon: .chevronRight, size: 13, visualScale: 1.04)
                    .foregroundStyle(PetWhiteStyle.inkMuted)
            } else {
                MonoIcon(icon: .chevronRight, size: 13, color: CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : .monoTextSecondary.opacity(0.4)))
            }
        }
        .padding(.horizontal, PetWhiteStyle.isActive ? 14 : (CapsuleStyle.isActive ? 14 : 18))
        .padding(.vertical, CapsuleStyle.isActive ? 12 : 14)
        .background {
            if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(
                    cornerRadius: 18,
                    elevated: false,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: PetWhiteStyle.mint
                )
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 22, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.78))
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var profileMenuIcon: some View {
        if MangaStyle.isActive {
            MonoIcon(
                icon: icon,
                size: 15,
                color: ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk),
                lineWidth: 1.8
            )
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).fill(MangaStyle.labelYellow))
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.6))
                .background(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 1.8, y: 1.8))
        } else if PetWhiteStyle.isActive {
            if let petWhiteAssetName {
                petWhiteAssetBadge(assetName: petWhiteAssetName, tint: PetWhiteStyle.sky, size: 36)
            } else {
                PetWhiteIconBadge(icon: icon, tint: icon == .settings ? PetWhiteStyle.mint : PetWhiteStyle.sky, size: 36)
            }
        } else if MujiStyle.isActive {
            Circle()
                .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.25))
                .frame(width: 31, height: 31)
                .overlay(MonoIcon(icon: icon, size: 14, color: MujiStyle.clay, lineWidth: 1.5))
        } else if NeumorphicStyle.isActive {
            NeumorphicIconBadge(icon: icon, tint: NeumorphicStyle.accent, size: 32)
        } else if CapsuleStyle.isActive {
            CapsuleIconBadge(icon: icon, tint: CapsuleStyle.accent, size: 34)
        } else if SignalStyle.isActive {
            SignalIconBadge(icon: icon, tint: SignalStyle.accent, size: 32)
        } else {
            MonoIcon(icon: icon, size: 18, color: .monoTextPrimary)
                .frame(width: 28, height: 28)
        }
    }

    private func petWhiteAssetBadge(assetName: String, tint: Color, size: CGFloat) -> some View {
        PetWhiteClayPuck(
            shape: RoundedRectangle(cornerRadius: max(13, size * 0.34), style: .continuous),
            tint: tint
        )
        .frame(width: size, height: size)
        .overlay(
            PetWhiteSelectedLyricToggleIcon(assetName: assetName, size: size * 0.66)
        )
    }
}

struct QuickActionCard: View {
    let icon: MonoIcon.IconType
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 10) {
                MonoIcon(icon: icon, size: 22, color: .monoTextPrimary)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .monoGlass(cornerRadius: 20)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
    }
}

// MARK: - Profile Menu Item (kept for backward compatibility)

struct ProfileMenuItem: View {
    let icon: MonoIcon.IconType
    let title: String
    var trailing: TrailingType = .chevron
    var action: (() -> Void)? = nil

    enum TrailingType {
        case chevron
        case text(String)
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                MonoIcon(icon: icon, size: 20, color: .monoTextPrimary)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.monoTextPrimary)

                Spacer()

                switch trailing {
                case .chevron:
                    MonoIcon(icon: .chevronRight, size: 14, color: .monoTextSecondary.opacity(0.5))
                case let .text(value):
                    Text(value)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                    MonoIcon(icon: .chevronRight, size: 14, color: .monoTextSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
    }
}
