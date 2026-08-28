import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

extension ScrollableLibraryExperience {
    func icon(for tab: LibraryViewModel.LibraryTab) -> MonoIcon.IconType {
        switch tab {
        case .my: return PetWhiteStyle.isActive ? .library : .libraryFilled
        case .square: return .gridSquare
        case .artists: return .personCircle
        case .charts: return .chart
        }
    }

    func tint(for tab: LibraryViewModel.LibraryTab) -> Color {
        switch tab {
        case .my: return defaultAccent
        case .square: return secondaryAccent
        case .artists: return tertiaryAccent
        case .charts: return quaternaryAccent
        }
    }

    func tint(for column: MyLibraryColumn) -> Color {
        switch column {
        case .localPlaylists: return defaultAccent
        case .ncmPlaylists: return MusicSource.netease.themedBadgeColor
        case .qcmPlaylists: return MusicSource.qqmusic.themedBadgeColor
        case .kcmPlaylists: return MusicSource.kugou.themedBadgeColor
        case .appleMusic: return MusicSource.appleMusic.themedBadgeColor
        case .localPodcasts: return tertiaryAccent
        case .ncmPodcasts: return secondaryAccent
        }
    }

    var primaryText: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    var secondaryText: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        return .monoTextSecondary
    }

    var defaultAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if MujiStyle.isActive { return MujiStyle.tea }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        return .monoAccent
    }

    var secondaryAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.cyan }
        if PetWhiteStyle.isActive { return PetWhiteStyle.mint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
        if SignalStyle.isActive { return SignalStyle.olive }
        if MujiStyle.isActive { return MujiStyle.clay }
        if SequoiaStyle.isActive { return SequoiaStyle.aqua }
        if CapsuleStyle.isActive { return CapsuleStyle.cyan }
        return .monoAccentBlue
    }

    var tertiaryAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.mint }
        if PetWhiteStyle.isActive { return PetWhiteStyle.sky }
        if NeumorphicStyle.isActive { return NeumorphicStyle.warm }
        if SignalStyle.isActive { return SignalStyle.rust }
        if MujiStyle.isActive { return MujiStyle.indigo }
        if SequoiaStyle.isActive { return SequoiaStyle.green }
        if CapsuleStyle.isActive { return CapsuleStyle.mint }
        return .monoAccentGreen
    }

    var quaternaryAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.violet }
        if PetWhiteStyle.isActive { return PetWhiteStyle.butter }
        if NeumorphicStyle.isActive { return NeumorphicStyle.red }
        if SignalStyle.isActive { return SignalStyle.red }
        if MujiStyle.isActive { return MujiStyle.red }
        if SequoiaStyle.isActive { return SequoiaStyle.violet }
        if CapsuleStyle.isActive { return CapsuleStyle.violet }
        return .monoAccentRed
    }

    var selectedChipText: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        return MujiStyle.isActive ? MujiStyle.onTint : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoIconForeground)))
    }

    var tabCornerRadius: CGFloat {
        if LiquidGlassStyle.isActive { return 17 }
        if PetWhiteStyle.isActive { return 16 }
        return NeumorphicStyle.isActive ? 15 : (SignalStyle.isActive ? 16 : (MujiStyle.isActive ? 8 : (SequoiaStyle.isActive ? 14 : 14)))
    }

    func tabFont(selected: Bool) -> Font {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(12, weight: selected ? .black : .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        return .system(size: 13, weight: selected ? .bold : .medium, design: .rounded)
    }

    func chipFont(selected: Bool) -> Font {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(12, weight: selected ? .black : .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        return .system(size: 13, weight: selected ? .semibold : .medium, design: .rounded)
    }

    func tabForeground(selected: Bool) -> Color {
        selected ? selectedChipText : secondaryText
    }

    func tabBackground(selected: Bool, tint: Color) -> some View {
        Group {
            if LiquidGlassStyle.isActive {
                LiquidGlassSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.16) : nil, role: selected ? .selected : .list)
            } else if PetWhiteStyle.isActive {
                PetWhiteDockSelectionBackground(tint: tint, isSelected: selected, cornerRadius: tabCornerRadius)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, tint: selected ? tint.opacity(0.15) : NeumorphicStyle.surface, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.16) : SignalStyle.control)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? SequoiaStyle.selectedWash : SequoiaStyle.materialList, role: selected ? .selected : .list)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
                    .fill(selected ? AnyShapeStyle(MujiStyle.clay) : AnyShapeStyle(MujiStyle.wash(MujiStyle.clay, strength: 0.75)))
            } else {
                RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
                    .fill(selected ? Color.monoIconBackground : Color.monoGlassTint)
            }
        }
    }

    func chipBackground(selected: Bool, tint: Color, capsule: Bool) -> some View {
        Group {
            if MinimalWhiteStyle.isActive {
                if capsule {
                    MinimalWhiteCapsuleBackground(elevated: selected, selected: selected)
                } else {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.compactRadius,
                        elevated: selected,
                        tint: selected ? MinimalWhiteStyle.selectedFill.opacity(0.92) : MinimalWhiteStyle.glassFill
                    )
                }
            } else if LiquidGlassStyle.isActive {
                LiquidGlassSurfaceBackground(cornerRadius: capsule ? 18 : 15, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.15) : nil, role: selected ? .selected : .list)
            } else if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(cornerRadius: capsule ? 18 : 15, elevated: selected, tint: selected ? tint.opacity(0.86) : PetWhiteStyle.surfaceRaised, accent: tint)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: capsule ? 18 : 15, elevated: selected, pressed: !selected, tint: selected ? tint.opacity(0.16) : NeumorphicStyle.surface, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: capsule ? 12 : 10, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.18) : SignalStyle.control)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: capsule ? 18 : 13, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.13) : SequoiaStyle.materialList, role: selected ? .selected : .list)
            } else if CapsuleStyle.isActive {
                let radius: CGFloat = capsule ? 18 : 15
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(selected ? tint : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(selected ? Color.clear : CapsuleStyle.separator.opacity(0.5), lineWidth: 0.9)
                    )
            } else if MujiStyle.isActive {
                let shape = RoundedRectangle(cornerRadius: capsule ? 18 : 12, style: .continuous)
                shape
                    .fill(selected ? AnyShapeStyle(MujiStyle.clay) : AnyShapeStyle(MujiStyle.wash(MujiStyle.clay, strength: 0.75)))
            } else if capsule {
                Capsule().fill(selected ? Color.monoIconBackground : Color.monoGlassTint)
            } else {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? Color.monoIconBackground : Color.monoGlassTint)
            }
        }
    }

    func panelBackground(cornerRadius: CGFloat) -> some View {
        Group {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: min(max(cornerRadius, MinimalWhiteStyle.compactRadius), MinimalWhiteStyle.chromeRadius),
                    elevated: true,
                    tint: MinimalWhiteStyle.glassFill
                )
            } else if LiquidGlassStyle.isActive {
                LiquidGlassSurfaceBackground(cornerRadius: min(cornerRadius, 24), elevated: true, role: .chrome)
            } else if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(cornerRadius: min(max(cornerRadius, 16), 24), elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: activeTabTint)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: cornerRadius, elevated: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: min(cornerRadius, 18), elevated: true, fill: SignalStyle.device)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: min(cornerRadius, 20), elevated: true, role: .chrome)
            } else if CapsuleStyle.isActive {
                RoundedRectangle(cornerRadius: min(max(cornerRadius, 16), 26), style: .continuous)
                    .fill(CapsuleStyle.surface.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: min(max(cornerRadius, 16), 26), style: .continuous)
                            .stroke(CapsuleStyle.separator.opacity(0.45), lineWidth: 0.8)
                    )
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.8))
            } else {
                Color.clear.monoGlass(cornerRadius: cornerRadius)
            }
        }
    }
}
