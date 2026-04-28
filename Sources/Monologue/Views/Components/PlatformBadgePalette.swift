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
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 6 : 4, style: .continuous)
                    .fill(tint.opacity(MangaStyle.isActive ? 0.16 : (NeumorphicStyle.isActive ? 0.13 : 0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 6 : 4, style: .continuous)
                    .stroke(tint.opacity(NeumorphicStyle.isActive ? 0.42 : 0.72), lineWidth: 0.6)
            )
    }
}
