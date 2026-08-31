import Combine
import SwiftUI

extension PodcastView {
    // MARK: - 分类标签

    var categoriesSection: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                NavigationLink(value: PodcastDestination.categoryBrowse) {
                    if MinimalWhiteStyle.isActive {
                        minimalWhiteCategoryPill(
                            title: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            selected: true
                        )
                    } else if MangaStyle.isActive {
                        HStack(spacing: 6) {
                            MonoIcon(icon: .gridSquare, size: 15, color: MangaStyle.onStrokeInk, lineWidth: 1.8)
                            Text(String(localized: "podcast_all"))
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
                    } else if PetWhiteStyle.isActive {
                        petWhiteCategoryPill(
                            title: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            tint: PetWhiteStyle.dogOrange,
                            selected: true
                        )
                    } else if MujiStyle.isActive {
                        MujiActionPill(
                            title: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            selected: true,
                            tint: MujiStyle.clay
                        )
                    } else if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: String(localized: "podcast_all"),
                            tint: NeumorphicStyle.accent,
                            icon: .gridSquare,
                            selected: true
                        )
                    } else if SignalStyle.isActive {
                        SignalPill(
                            text: String(localized: "podcast_all"),
                            tint: SignalStyle.accent,
                            icon: .gridSquare,
                            selected: true
                        )
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(
                            text: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            tint: SequoiaStyle.accent,
                            selected: true
                        )
                    } else if LiquidGlassStyle.isActive {
                        LiquidGlassPill(
                            text: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            tint: LiquidGlassStyle.violet,
                            selected: true
                        )
                    } else {
                        HStack(spacing: 6) {
                            MonoIcon(icon: .gridSquare, size: 14, color: .monoTextPrimary, lineWidth: 1.6)
                            Text("podcast_all")
                                .font(.rounded(size: 12.5, weight: .bold))
                                .foregroundColor(.monoTextPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(Color.monoTextPrimary.opacity(0.34), lineWidth: 0.9))
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle())

                ForEach(viewModel.categories) { cat in
                    NavigationLink(value: PodcastDestination.category(cat)) {
                        if MinimalWhiteStyle.isActive {
                            minimalWhiteCategoryPill(
                                title: cat.name,
                                icon: cat.monoIconType
                            )
                        } else if MangaStyle.isActive {
                            HStack(spacing: 6) {
                                MonoIcon(icon: cat.monoIconType, size: 16, color: MangaStyle.ink, lineWidth: 1.8)
                                Text(cat.name)
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
                        } else if PetWhiteStyle.isActive {
                            petWhiteCategoryPill(
                                title: cat.name,
                                icon: cat.monoIconType,
                                tint: PetWhiteStyle.mint
                            )
                        } else if MujiStyle.isActive {
                            MujiActionPill(
                                title: cat.name,
                                icon: cat.monoIconType,
                                tint: MujiStyle.tea
                            )
                        } else if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: cat.name,
                            tint: NeumorphicStyle.sage,
                            icon: cat.monoIconType
                        )
                    } else if SignalStyle.isActive {
                        SignalPill(
                            text: cat.name,
                            tint: SignalStyle.olive,
                            icon: cat.monoIconType
                        )
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(
                            text: cat.name,
                            icon: cat.monoIconType,
                            tint: SequoiaStyle.aqua
                        )
                    } else if LiquidGlassStyle.isActive {
                        LiquidGlassPill(
                            text: cat.name,
                            icon: cat.monoIconType,
                            tint: LiquidGlassStyle.cyan
                        )
                    } else {
                        HStack(spacing: 6) {
                            MonoIcon(icon: cat.monoIconType, size: 14, color: .monoTextSecondary.opacity(0.9), lineWidth: 1.5)
                                Text(cat.name)
                                    .font(.rounded(size: 12.5, weight: .semibold))
                                    .foregroundColor(.monoTextPrimary.opacity(0.85))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .overlay(Capsule().stroke(Color.monoSeparator.opacity(0.95), lineWidth: 0.8))
                        }
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
        DeviceLayout.isPad ? 170 : 130
    }

    var broadcastCardSize: CGFloat {
        DeviceLayout.isPad ? 160 : 120
    }

}
