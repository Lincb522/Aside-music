import SwiftUI

// MARK: - Mono TabBar

struct MonoTabBar: View {
    @Environment(\.floatingBarColorRevision) private var colorRevision
    @Binding var selectedIndex: Int
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @Namespace private var tabNS

    private let itemHeight: CGFloat = 48
    private let padding: CGFloat = 5

    private var selectedColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if PureWhiteStyle.isActive { return PureWhiteStyle.strokeInk }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        return MujiStyle.isActive ? MujiStyle.clay : .monoAccent
    }

    private var idleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
        if PureWhiteStyle.isActive { return PureWhiteStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkMuted }
        return MujiStyle.isActive ? MujiStyle.inkMuted : .monoTextSecondary.opacity(0.55)
    }

    private static let tabIcons: [(outline: MonoIcon.IconType, filled: MonoIcon.IconType)] = [
        (.home, .homeFilled),
        (.podcast, .podcastFilled),
        (.library, .libraryFilled),
        (.profile, .profileFilled),
    ]

    var body: some View {
        let _ = colorRevision

        HStack(spacing: 0) {
            tabButton(index: 0, label: NSLocalizedString(Tab.home.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 1, label: NSLocalizedString(Tab.podcast.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 2, label: NSLocalizedString(Tab.library.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
            tabButton(index: 3, label: NSLocalizedString(Tab.profile.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, padding)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func tabButton(index: Int, label: String) -> some View {
        let isSelected = selectedIndex == index
        let icons = Self.tabIcons[index]

        Button {
            HapticManager.shared.light()
            // 页面切换不走动画(避免 TabView 内容做弹簧过渡导致卡顿)
            selectedIndex = index
        } label: {
            VStack(spacing: 2) {
                tabIcon(icon: isSelected ? icons.filled : icons.outline, isSelected: isSelected)
                .contentTransition(.interpolate)
                .scaleEffect(isSelected ? 1.06 : 1.0)
                .offset(y: isSelected ? -1 : 0)
                .animation(MonoAnimation.tabSwitch, value: selectedIndex)

                Text(label)
                    .font(mangaOrMujiTabFont(isSelected: isSelected))
                    .foregroundColor(isSelected ? selectedColor : idleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: itemHeight, alignment: .center)
            .background {
                if isSelected {
                    Capsule()
                        .fill(mangaOrMujiHighlightColor)
                        .padding(.horizontal, 4)
                        .matchedGeometryEffect(id: "tabHighlight", in: tabNS)
                }
            }
            .animation(MonoAnimation.tabSwitch, value: selectedIndex)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tabIcon(icon: MonoIcon.IconType, isSelected: Bool) -> some View {
        if PetWhiteStyle.isActive {
            PetWhitePackIcon(
                icon: icon,
                size: 24,
                visualScale: isSelected ? 1.08 : 0.98,
                fallbackColor: isSelected ? selectedColor : idleColor,
                artworkContrastBackground: isSelected ? selectedContrastBackground : nil
            )
        } else {
            MonoIcon(
                icon: icon,
                size: 20,
                color: isSelected ? selectedColor : idleColor,
                artworkContrastBackground: isSelected ? selectedContrastBackground : nil
            )
        }
    }

    private var selectedContrastBackground: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.selectedFill }
        if PetWhiteStyle.isActive { return PetWhiteStyle.surfaceRaised }
        if PureWhiteStyle.isActive { return PureWhiteStyle.surfaceRaised }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.materialRaised }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.glassRaised }
        return Color.monoFloatingBarFill
    }

    private func mangaOrMujiTabFont(isSelected: Bool) -> Font {
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.labelFont(9, weight: isSelected ? .semibold : .regular)
        } else if MangaStyle.isActive {
            return MangaStyle.labelFont(9, weight: isSelected ? .black : .bold)
        } else if PetWhiteStyle.isActive {
            return PetWhiteStyle.labelFont(9, weight: isSelected ? .black : .bold)
        } else if PureWhiteStyle.isActive {
            return PureWhiteStyle.labelFont(9, weight: isSelected ? .black : .bold)
        } else if MujiStyle.isActive {
            return MujiStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        } else if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        } else if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        } else if LiquidGlassStyle.isActive {
            return LiquidGlassStyle.labelFont(9, weight: isSelected ? .semibold : .medium)
        }
        return .system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded)
    }

    private var mangaOrMujiHighlightColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.selectedFill }
        if MangaStyle.isActive { return MangaStyle.accentPink.opacity(0.15) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.mint.opacity(0.18) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.accent.opacity(0.18) }
        if MujiStyle.isActive { return MujiStyle.clay.opacity(0.1) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent.opacity(0.14) }
        if SequoiaStyle.isActive { return SequoiaStyle.accent.opacity(0.12) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.selectedWash.opacity(0.88) }
        return Color.monoAccent.opacity(0.12)
    }
}
