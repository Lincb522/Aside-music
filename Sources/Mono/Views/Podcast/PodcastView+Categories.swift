import Combine
import SwiftUI

extension PodcastView {
    // MARK: - 分类标签

    var categoriesSection: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                NavigationLink(value: PodcastDestination.categoryBrowse) {
                    categoryBrowsePill
                }
                .buttonStyle(MonoBouncingButtonStyle())

                ForEach(viewModel.categories) { cat in
                    NavigationLink(value: PodcastDestination.category(cat)) {
                        categoryPill(for: cat)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                    .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.93)
                            .opacity(phase.isIdentity ? 1 : 0.5)
                    }
                }
            }
            .compatScrollTargetLayout()
            .padding(.horizontal, padH)
        }
        .compatViewAlignedScrollBehavior(limitNever: true)
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    private var categoryBrowsePill: AnyView {
        let title = String(localized: "podcast_all")

        if MinimalWhiteStyle.isActive {
            return AnyView(
                minimalWhiteCategoryPill(
                    title: title,
                    icon: .gridSquare,
                    selected: true
                )
            )
        }
        if MangaStyle.isActive {
            return AnyView(
                HStack(spacing: 6) {
                    MonoIcon(icon: .gridSquare, size: 15, color: MangaStyle.onStrokeInk, lineWidth: 1.8)
                    Text(title)
                        .font(MangaStyle.labelFont(12, weight: .black))
                        .tracking(0.6)
                }
                .foregroundStyle(MangaStyle.onStrokeInk)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MangaStyle.strokeInk))
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(MangaStyle.accentPink)
                        .offset(x: 2.2, y: 2.2)
                )
            )
        }
        if PetWhiteStyle.isActive {
            return AnyView(
                petWhiteCategoryPill(
                    title: title,
                    icon: .gridSquare,
                    tint: PetWhiteStyle.dogOrange,
                    selected: true
                )
            )
        }
        if MujiStyle.isActive {
            return AnyView(
                MujiActionPill(
                    title: title,
                    icon: .gridSquare,
                    selected: true,
                    tint: MujiStyle.clay
                )
            )
        }
        if NeumorphicStyle.isActive {
            return AnyView(
                NeumorphicPill(
                    text: title,
                    tint: NeumorphicStyle.accent,
                    icon: .gridSquare,
                    selected: true
                )
            )
        }
        if SignalStyle.isActive {
            return AnyView(
                SignalPill(
                    text: title,
                    tint: SignalStyle.accent,
                    icon: .gridSquare,
                    selected: true
                )
            )
        }
        if SequoiaStyle.isActive {
            return AnyView(
                SequoiaPill(
                    text: title,
                    icon: .gridSquare,
                    tint: SequoiaStyle.accent,
                    selected: true
                )
            )
        }
        if LiquidGlassStyle.isActive {
            return AnyView(
                LiquidGlassPill(
                    text: title,
                    icon: .gridSquare,
                    tint: LiquidGlassStyle.violet,
                    selected: true
                )
            )
        }
        return AnyView(
            HStack(spacing: 6) {
                MonoIcon(icon: .gridSquare, size: 14, color: .monoTextPrimary, lineWidth: 1.6)
                Text("podcast_all")
                    .font(.rounded(size: 12.5, weight: .bold))
                    .foregroundColor(.monoTextPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .overlay(Capsule().stroke(Color.monoTextPrimary.opacity(0.34), lineWidth: 0.9))
        )
    }

    private func categoryPill(for category: RadioCategory) -> AnyView {
        if MinimalWhiteStyle.isActive {
            return AnyView(
                minimalWhiteCategoryPill(
                    title: category.name,
                    icon: category.monoIconType
                )
            )
        }
        if MangaStyle.isActive {
            return AnyView(
                HStack(spacing: 6) {
                    MonoIcon(icon: category.monoIconType, size: 16, color: MangaStyle.ink, lineWidth: 1.8)
                    Text(category.name)
                        .font(MangaStyle.labelFont(12, weight: .bold))
                }
                .foregroundStyle(MangaStyle.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .fill(MangaStyle.bubbleWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                )
            )
        }
        if PetWhiteStyle.isActive {
            return AnyView(
                petWhiteCategoryPill(
                    title: category.name,
                    icon: category.monoIconType,
                    tint: PetWhiteStyle.mint
                )
            )
        }
        if MujiStyle.isActive {
            return AnyView(
                MujiActionPill(
                    title: category.name,
                    icon: category.monoIconType,
                    tint: MujiStyle.tea
                )
            )
        }
        if NeumorphicStyle.isActive {
            return AnyView(
                NeumorphicPill(
                    text: category.name,
                    tint: NeumorphicStyle.sage,
                    icon: category.monoIconType
                )
            )
        }
        if SignalStyle.isActive {
            return AnyView(
                SignalPill(
                    text: category.name,
                    tint: SignalStyle.olive,
                    icon: category.monoIconType
                )
            )
        }
        if SequoiaStyle.isActive {
            return AnyView(
                SequoiaPill(
                    text: category.name,
                    icon: category.monoIconType,
                    tint: SequoiaStyle.aqua
                )
            )
        }
        if LiquidGlassStyle.isActive {
            return AnyView(
                LiquidGlassPill(
                    text: category.name,
                    icon: category.monoIconType,
                    tint: LiquidGlassStyle.cyan
                )
            )
        }
        return AnyView(
            HStack(spacing: 6) {
                MonoIcon(icon: category.monoIconType, size: 14, color: .monoTextSecondary.opacity(0.9), lineWidth: 1.5)
                Text(category.name)
                    .font(.rounded(size: 12.5, weight: .semibold))
                    .foregroundColor(.monoTextPrimary.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .overlay(Capsule().stroke(Color.monoSeparator.opacity(0.95), lineWidth: 0.8))
        )
    }

    func minimalWhiteCategoryPill(
        title: String,
        icon: MonoIcon.IconType,
        selected: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            MonoIcon(
                icon: icon,
                size: 15,
                color: selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkSoft,
                lineWidth: 1.6
            )

            Text(title)
                .font(MinimalWhiteStyle.labelFont(12, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkSoft)
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(MinimalWhiteCapsuleBackground(elevated: false, selected: selected))
    }

    func petWhiteCategoryPill(
        title: String,
        icon: MonoIcon.IconType,
        tint: Color,
        selected: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            PetWhitePackIcon(icon: icon, size: selected ? 17 : 16, visualScale: 1.04)

            Text(title)
                .font(PetWhiteStyle.labelFont(12, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            PetWhiteClayPuck(
                shape: Capsule(style: .continuous),
                tint: selected ? tint : PetWhiteStyle.surfaceRaised,
                pressedLook: selected
            )
        )
    }

    // MARK: - 布局常量

    /// aside 默认主题（无任何 ThemedPageStyle 主题激活）
    var isAside: Bool {
        !ThemedPageStyle.isActive
    }

    var padH: CGFloat {
        DeviceLayout.viewHorizontalPadding
    }

    var compactCardSize: CGFloat {
        DeviceLayout.usesExpandedLayout ? 170 : 130
    }

    var broadcastCardSize: CGFloat {
        DeviceLayout.usesExpandedLayout ? 160 : 120
    }

}
