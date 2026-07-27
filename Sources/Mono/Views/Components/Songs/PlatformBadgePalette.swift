import SwiftUI

enum PlatformBadgePalette {
    static func color(for source: MusicSource) -> Color {
        if MangaStyle.isActive {
            // 黑白漫画体系：平台徽章以墨/灰阶区分，不用色相
            switch source {
            case .netease:
                return MangaComicPalette.ink
            case .qqmusic:
                return MangaComicPalette.toneDeep
            case .qishui:
                return MangaComicPalette.toneMid
            case .kugou:
                return MangaComicPalette.inkSoft
            case .appleMusic:
                return MangaComicPalette.toneMid
            case .local:
                return MangaComicPalette.inkSoft
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
            case .kugou:
                return Color(light: Color(hex: "3C7899"), dark: Color(hex: "82B8D0"))
            case .appleMusic:
                return Color(light: Color(hex: "B95061"), dark: Color(hex: "E58A97"))
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
            case .kugou:
                return Color(light: Color(hex: "3D7C9E"), dark: Color(hex: "84C2DE"))
            case .appleMusic:
                return Color(light: Color(hex: "C65F76"), dark: Color(hex: "EC91A3"))
            case .local:
                return NeumorphicStyle.accent
            }
        }

        if CapsuleStyle.isActive {
            switch source {
            case .netease:
                return CapsuleStyle.coral
            case .qqmusic:
                return CapsuleStyle.amber
            case .qishui:
                return CapsuleStyle.mint
            case .kugou:
                return CapsuleStyle.accent
            case .appleMusic:
                return CapsuleStyle.coral
            case .local:
                return CapsuleStyle.accent
            }
        }

        if ClayStyle.isActive {
            switch source {
            case .netease:
                return Color(light: Color(hex: "D96888"), dark: Color(hex: "F49AB3"))
            case .qqmusic:
                return Color(light: Color(hex: "C58A2B"), dark: Color(hex: "F0C76A"))
            case .qishui:
                return Color(light: Color(hex: "5D996E"), dark: Color(hex: "9AD0A6"))
            case .kugou:
                return Color(light: Color(hex: "428DB5"), dark: Color(hex: "8CCBE8"))
            case .appleMusic:
                return Color(light: Color(hex: "D96888"), dark: Color(hex: "F59AAD"))
            case .local:
                return ClayStyle.sky
            }
        }

        if SequoiaStyle.isActive {
            switch source {
            case .netease:
                return Color(light: Color(hex: "D94D52"), dark: Color(hex: "FF7278"))
            case .qqmusic:
                return SequoiaStyle.yellow
            case .qishui:
                return SequoiaStyle.green
            case .kugou:
                return SequoiaStyle.aqua
            case .appleMusic:
                return Color(light: Color(hex: "D94D67"), dark: Color(hex: "FF7D91"))
            case .local:
                return SequoiaStyle.aqua
            }
        }

        switch source {
        case .netease:
            return Color(light: Color(hex: "E5537A"), dark: Color(hex: "F08AA8"))
        case .qqmusic:
            return Color(light: Color(hex: "B68100"), dark: Color(hex: "F0CC58"))
        case .qishui:
            return Color(light: Color(hex: "2F714F"), dark: Color(hex: "82BC91"))
        case .kugou:
            return Color(light: Color(hex: "2684C7"), dark: Color(hex: "76BCE8"))
        case .appleMusic:
            return Color(light: Color(hex: "E84C68"), dark: Color(hex: "FF8295"))
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
    @ObservedObject private var settings = SettingsManager.shared

    /// aside 默认主题（编辑部风格分支）
    private var isAsideTheme: Bool {
        GlobalThemeId.persistedOrDefault == .default
    }

    var body: some View {
        let _ = settings.globalThemeRevision
        let tint = source.themedBadgeColor

        if isAsideTheme {
            // aside 编辑部风格：平台色圆点 + 字距小字，去框去底
            HStack(spacing: 4.5) {
                Circle()
                    .fill(tint)
                    .frame(width: max(fontSize * 0.42, 4), height: max(fontSize * 0.42, 4))

                Text(text)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .tracking(0.7)
                    .foregroundColor(Color.monoTextSecondary.opacity(0.78))
            }
        } else {
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
        if CapsuleStyle.isActive {
            return CapsuleStyle.labelFont(fontSize, weight: .bold)
        }
        if ClayStyle.isActive {
            return ClayStyle.labelFont(fontSize, weight: .bold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(fontSize, weight: .semibold)
        }
        return .system(size: fontSize, weight: .semibold, design: .rounded)
    }

    private var badgeTracking: CGFloat {
        MujiStyle.isActive ? 0.6 : 0
    }

    private var badgeHorizontalPadding: CGFloat {
        MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 8 : (CapsuleStyle.isActive ? 8 : (ClayStyle.isActive ? 8 : (SequoiaStyle.isActive ? 8 : 7))))
    }

    private var badgeVerticalPadding: CGFloat {
        MangaStyle.isActive ? 3.5 : (SequoiaStyle.isActive ? 3.5 : 3)
    }

    private var badgeCornerRadius: CGFloat {
        MangaStyle.isActive ? 7 : (MujiStyle.isActive ? 6 : (NeumorphicStyle.isActive ? 8 : (CapsuleStyle.isActive ? 9 : (ClayStyle.isActive ? 8 : (SequoiaStyle.isActive ? 9 : 4)))))
    }

    private func badgeForeground(_ tint: Color) -> Color {
        if MangaStyle.isActive {
            return MangaStyle.ink
        }
        if SequoiaStyle.isActive {
            return tint
        }
        if CapsuleStyle.isActive {
            return tint
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
        } else if ClayStyle.isActive {
            ClaySurfaceBackground(
                cornerRadius: badgeCornerRadius,
                tint: tint.opacity(0.12),
                elevated: false,
                pressed: true,
                compact: true
            )
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(
                cornerRadius: badgeCornerRadius,
                elevated: false,
                tint: tint.opacity(0.10)
            )
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: badgeCornerRadius,
                elevated: false,
                pressed: true,
                fill: tint.opacity(0.1),
                role: .selected
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
        } else if ClayStyle.isActive {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 0.6)
        } else if CapsuleStyle.isActive {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 0.55)
        } else {
            RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.72), lineWidth: 0.6)
        }
    }
}
