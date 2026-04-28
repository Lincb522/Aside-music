import SwiftUI

enum PlatformBadgePalette {
    static func color(for source: MusicSource) -> Color {
        if MangaStyle.isActive {
            switch source {
            case .netease:
                return MangaStyle.accentPink
            case .qqmusic:
                return Color(light: Color(hex: "B98300"), dark: Color(hex: "E0C157"))
            case .qishui:
                return Color(light: Color(hex: "2E754E"), dark: Color(hex: "74B98A"))
            case .local:
                return MangaStyle.decoBlue
            }
        }

        if MujiStyle.isActive {
            switch source {
            case .netease:
                return Color(light: Color(hex: "B86E7B"), dark: Color(hex: "D99AAA"))
            case .qqmusic:
                return Color(light: Color(hex: "A97800"), dark: MujiStyle.straw)
            case .qishui:
                return Color(light: Color(hex: "4F744A"), dark: Color(hex: "91AA82"))
            case .local:
                return MujiStyle.indigo
            }
        }

        if NeumorphicStyle.isActive {
            switch source {
            case .netease:
                return Color(light: Color(hex: "C96E83"), dark: Color(hex: "EAA0B1"))
            case .qqmusic:
                return Color(light: Color(hex: "B08434"), dark: Color(hex: "D9B66A"))
            case .qishui:
                return Color(light: Color(hex: "527F61"), dark: Color(hex: "92C59D"))
            case .local:
                return NeumorphicStyle.accent
            }
        }

        switch source {
        case .netease:
            return Color(light: Color(hex: "E5537A"), dark: Color(hex: "F08AA8"))
        case .qqmusic:
            return Color(light: Color(hex: "B68100"), dark: Color(hex: "F0CC58"))
        case .qishui:
            return Color(light: Color(hex: "2F714F"), dark: Color(hex: "82BC91"))
        case .local:
            return Color(light: Color(hex: "3A7BD5"), dark: Color(hex: "7FB2FF"))
        }
    }
}

extension MusicSource {
    var themedBadgeColor: Color {
        PlatformBadgePalette.color(for: self)
    }
}

struct PlatformBadgeLabel: View {
    let text: String
    let source: MusicSource
    var fontSize: CGFloat = 11

    var body: some View {
        let tint = source.themedBadgeColor

        Text(text)
            .font(badgeFont)
            .foregroundColor(badgeForeground(tint))
            .tracking(badgeTracking)
            .padding(.horizontal, badgeHorizontalPadding)
            .padding(.vertical, badgeVerticalPadding)
            .background {
                badgeBackground(tint)
            }
            .overlay {
                badgeStroke(tint)
            }
    }

    private var badgeFont: Font {
        if MangaStyle.isActive {
            return MangaStyle.labelFont(fontSize, weight: .black)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(fontSize, weight: .semibold)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(fontSize, weight: .semibold)
        }
        return .system(size: fontSize, weight: .semibold, design: .rounded)
    }

    private var badgeTracking: CGFloat {
        MujiStyle.isActive ? 0.6 : 0
    }

    private var badgeHorizontalPadding: CGFloat {
        MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 8 : 7)
    }

    private var badgeVerticalPadding: CGFloat {
        MangaStyle.isActive ? 3.5 : 3
    }

    private var badgeCornerRadius: CGFloat {
        MangaStyle.isActive ? 7 : (MujiStyle.isActive ? 6 : (NeumorphicStyle.isActive ? 8 : 4))
    }

    private func badgeForeground(_ tint: Color) -> Color {
        if MangaStyle.isActive {
            return MangaStyle.ink
        }
        return tint
    }

    @ViewBuilder
    private func badgeBackground(_ tint: Color) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: badgeCornerRadius,
                elevated: false,
                pressed: true,
                tint: tint.opacity(0.12)
            )
        } else {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .fill(tint.opacity(MangaStyle.isActive ? 0.22 : (MujiStyle.isActive ? 0.10 : 0.12)))
        }
    }

    @ViewBuilder
    private func badgeStroke(_ tint: Color) -> some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.34), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 0.6)
        } else {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.72), lineWidth: 0.6)
        }
    }
}
