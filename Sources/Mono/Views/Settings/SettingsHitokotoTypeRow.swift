import SwiftUI

// MARK: - 一言类型选择行

struct SettingsHitokotoTypeRow: View {
    let icon: MonoIcon.IconType
    let title: String
    @Binding var selection: String
    @State private var isExpanded = false

    private static let types: [(key: String, label: String)] = [
        ("", String(localized: "随机")),
        ("i", String(localized: "诗词")),
        ("d", String(localized: "文学")),
        ("k", String(localized: "哲学")),
        ("h", String(localized: "影视")),
        ("j", "ncm"),
        ("a", String(localized: "动画")),
        ("c", String(localized: "游戏")),
        ("e", String(localized: "原创")),
        ("l", String(localized: "抖机灵")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    SettingsIconBadge(icon: icon)

                    Text(title)
                        .font(themedSettingsFont(16, weight: .medium))
                        .foregroundColor(themedSettingsPrimaryColor())

                    Spacer()

                    Text(Self.types.first { $0.key == selection }?.label ?? String(localized: "随机"))
                        .font(themedSettingsFont(14, weight: .medium))
                        .foregroundStyle(activeSummaryColor)

                    PetWhiteDisclosureChevron(
                        isExpanded: isExpanded,
                        size: 11,
                        color: themedSettingsSecondaryColor(),
                        lineWidth: 1.7
                    )
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            SettingsHeaderReveal(isExpanded: isExpanded) {
                SettingsHitokotoFlowLayout(spacing: 8) {
                    ForEach(Self.types, id: \.key) { type in
                        Button {
                            selection = type.key
                            isExpanded = false
                        } label: {
                            hitokotoTypeChip(label: type.label, selected: selection == type.key)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var activeSummaryColor: Color {
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if BentoStyle.isActive { return BentoStyle.tomato }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        return .secondary
    }

    private func hitokotoTypeChip(label: String, selected: Bool) -> some View {
        Text(label)
            .font(themedSettingsFont(13, weight: selected ? .semibold : .medium))
            .lineLimit(1)
            .padding(.horizontal, chipHorizontalPadding)
            .padding(.vertical, chipVerticalPadding)
            .foregroundColor(chipForeground(selected: selected))
            .background(chipBackground(selected: selected))
            .contentShape(MangaStyle.isActive ? AnyShape(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)) : AnyShape(Capsule()))
    }

    private var chipHorizontalPadding: CGFloat {
        MangaStyle.isActive ? 13 : (BentoStyle.isActive ? 13 : 12)
    }

    private var chipVerticalPadding: CGFloat {
        NeumorphicStyle.isActive ? 7 : (BentoStyle.isActive ? 7 : 6)
    }

    @ViewBuilder
    private func chipBackground(selected: Bool) -> some View {
        if MangaStyle.isActive {
            // 去卡片化筛选签：选中实色小章，未选中细墨线轮廓
            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                .fill(selected ? MangaStyle.labelYellow : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(selected ? 0 : 0.35), lineWidth: 1)
                )
        } else if MujiStyle.isActive {
            Capsule()
                .fill(selected ? MujiStyle.clay.opacity(0.15) : MujiStyle.surface.opacity(0.76))
                .overlay(Capsule().stroke(selected ? MujiStyle.clay.opacity(0.42) : MujiStyle.hairline.opacity(0.44), lineWidth: 0.65))
                .overlay(MujiPaperTexture(opacity: selected ? 0.04 : 0.08).clipShape(Capsule()))
        } else if BentoStyle.isActive {
            Capsule()
                .fill(selected ? BentoStyle.tomato : BentoStyle.surface)
                .overlay(Capsule().stroke(BentoStyle.hairline.opacity(selected ? 0.3 : 0.58), lineWidth: 0.65))
        } else if CapsuleStyle.isActive {
            Capsule()
                .fill(selected ? CapsuleStyle.accent : CapsuleStyle.surfaceRaised.opacity(0.78))
                .overlay(Capsule().stroke(selected ? Color.white.opacity(0.34) : CapsuleStyle.separator.opacity(0.46), lineWidth: 0.7))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 15,
                elevated: selected,
                pressed: !selected,
                tint: selected ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface,
                lightweight: true
            )
        } else if SequoiaStyle.isActive {
            Capsule()
                .fill(selected ? SequoiaStyle.selectedWash.opacity(0.88) : SequoiaStyle.materialList.opacity(0.72))
                .overlay(Capsule().stroke(selected ? SequoiaStyle.accent.opacity(0.22) : SequoiaStyle.separator.opacity(0.82), lineWidth: 0.55))
        } else if SignalStyle.isActive {
            SignalSurfaceBackground(
                cornerRadius: 15,
                elevated: selected,
                pressed: !selected,
                fill: selected ? SignalStyle.accent : SignalStyle.control
            )
        } else {
            Capsule()
                .fill(selected ? Color.monoIconBackground : Color.monoSeparator.opacity(0.6))
        }
    }

    private func chipForeground(selected: Bool) -> Color {
        if MangaStyle.isActive {
            return selected
                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
                : MangaStyle.inkSub
        }
        if MujiStyle.isActive { return selected ? MujiStyle.clay : MujiStyle.inkSoft }
        if BentoStyle.isActive { return selected ? BentoStyle.onAccent : BentoStyle.inkSoft }
        if CapsuleStyle.isActive { return selected ? CapsuleStyle.onAccent : CapsuleStyle.inkSoft }
        if NeumorphicStyle.isActive { return selected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return selected ? SequoiaStyle.accent : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return selected ? SignalStyle.onAccent : SignalStyle.inkSoft }
        return selected ? Color.monoIconForeground : Color.monoTextSecondary
    }
}

struct LiquidGlassSettingsTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                LiquidGlassIconBadge(icon: icon, tint: tint, size: 38)

                Spacer(minLength: 8)

                Text(value)
                    .font(LiquidGlassStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                            .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 0.55))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(LiquidGlassStyle.titleFont(16, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 5) {
                    Capsule()
                        .fill(tint.opacity(0.58))
                        .frame(width: 28, height: 4)
                    Capsule()
                        .fill(LiquidGlassStyle.luminousEdge.opacity(0.46))
                        .frame(width: 10, height: 4)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.1),
                            Color.clear,
                            LiquidGlassStyle.cyan.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
    }
}

struct SettingsHitokotoFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
