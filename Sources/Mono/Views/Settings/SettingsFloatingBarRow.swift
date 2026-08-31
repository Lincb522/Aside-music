import SwiftUI

// MARK: - Header Reveal

struct SettingsHeaderReveal<Content: View>: View {
    let isExpanded: Bool
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var measuredHeight: CGFloat = 0

    private var targetHeight: CGFloat {
        isExpanded ? measuredHeight : 0
    }

    private var revealAnimation: Animation {
        if reduceMotion {
            return .linear(duration: 0.01)
        }
        return .easeInOut(duration: 0.22)
    }

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .opacity(isExpanded ? 1 : 0)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateMeasuredHeight(proxy.size.height) }
                        .onChange(of: proxy.size.height) { _, newValue in
                            updateMeasuredHeight(newValue)
                        }
                }
            }
            .frame(height: targetHeight, alignment: .top)
            .clipShape(Rectangle())
            .clipped()
            .contentShape(Rectangle())
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
            .animation(revealAnimation, value: isExpanded)
    }

    private func updateMeasuredHeight(_ height: CGFloat) {
        guard height > 0, abs(measuredHeight - height) > 0.5 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            measuredHeight = height
        }
    }
}

// MARK: - 悬浮栏样式选择行

struct SettingsFloatingBarRow: View {
    let icon: MonoIcon.IconType
    let title: String
    @Binding var selection: FloatingBarStyle
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    SettingsIconBadge(icon: icon)

                    Text(title)
                        .font(themedSettingsFont(16, weight: .medium))
                        .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (BentoStyle.isActive ? BentoStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoTextPrimary)))))))

                    Spacer(minLength: 12)

                    Text(selection.displayName)
                        .font(themedSettingsFont(13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectionPillBackground)
                        .foregroundColor(selectionPillForeground)

                    PetWhiteDisclosureChevron(
                        isExpanded: isExpanded,
                        size: 11,
                        color: MangaStyle.isActive ? MangaStyle.strokeInk : (MujiStyle.isActive ? MujiStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (BentoStyle.isActive ? BentoStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monoTextSecondary.opacity(0.8))))))),
                        lineWidth: 1.7
                    )
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .signalHoverExpansionDisabled()

            SettingsHeaderReveal(isExpanded: isExpanded) {
                Group {
                    if SignalStyle.isActive {
                        VStack(spacing: 0) {
                            ForEach(FloatingBarStyle.allCases) { style in
                                Button {
                                    selection = style
                                    isExpanded = false
                                } label: {
                                    SettingsFloatingBarOptionCard(
                                        style: style,
                                        isSelected: selection == style
                                    )
                                }
                                .buttonStyle(.plain)
                                .signalHoverExpansionDisabled()
                            }
                        }
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(SignalStyle.separator.opacity(0.74))
                                .frame(height: 0.65)
                        }
                    } else {
                        LazyVGrid(columns: optionColumns, spacing: 8) {
                            ForEach(FloatingBarStyle.allCases) { style in
                                Button {
                                    selection = style
                                    isExpanded = false
                                } label: {
                                    SettingsFloatingBarOptionCard(
                                        style: style,
                                        isSelected: selection == style
                                    )
                                }
                                .buttonStyle(.plain)
                                .signalHoverExpansionDisabled()
                            }
                        }
                    }
                }
                .padding(.top, SignalStyle.isActive ? 10 : 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var optionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
    }

    @ViewBuilder
    private var selectionPillBackground: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                .fill(MangaStyle.labelYellow.opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.4))
        } else if MujiStyle.isActive {
            Capsule()
                .fill(MujiStyle.clay.opacity(0.12))
                .overlay(Capsule().stroke(MujiStyle.hairline.opacity(0.52), lineWidth: 0.6))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true)
        } else if CapsuleStyle.isActive {
            Capsule()
                .fill(CapsuleStyle.accent.opacity(0.12))
                .overlay(Capsule().stroke(CapsuleStyle.accent.opacity(0.24), lineWidth: 0.7))
        } else if SequoiaStyle.isActive {
            Capsule()
                .fill(SequoiaStyle.selectedWash.opacity(0.86))
                .overlay(Capsule().stroke(SequoiaStyle.accent.opacity(0.2), lineWidth: 0.55))
        } else if SignalStyle.isActive {
            Color.clear
        } else if BentoStyle.isActive {
            Capsule()
                .fill(BentoStyle.tomato.opacity(0.14))
                .overlay(Capsule().stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65))
        } else {
            Capsule()
                .fill(Color.monoIconBackground.opacity(0.16))
        }
    }

    private var selectionPillForeground: Color {
        if MangaStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
        }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if BentoStyle.isActive { return BentoStyle.tomato }
        return .monoTextSecondary
    }
}

struct SettingsFloatingBarOptionCard: View {
    let style: FloatingBarStyle
    let isSelected: Bool

    var body: some View {
        if SignalStyle.isActive {
            signalOptionRow
        } else {
            optionCard
        }
    }

    private var optionCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                iconBadge
                Spacer()
                selectedMark
            }

            Text(style.displayName)
                .font(cardTitleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundColor(titleColor)

            Text(style.description)
                .font(themedSettingsFont(10.5, weight: .medium))
                .foregroundColor(descriptionColor)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    private var signalOptionRow: some View {
        HStack(spacing: 12) {
            MonoIcon(
                icon: style.iconType,
                size: 16,
                color: isSelected ? SignalStyle.accent : SignalStyle.inkSoft,
                lineWidth: 1.6
            )
            .frame(width: 28, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(style.displayName)
                    .font(SignalStyle.labelFont(13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? SignalStyle.ink : SignalStyle.inkSoft)
                    .lineLimit(1)

                Text(style.description)
                    .font(SignalStyle.labelFont(10.5, weight: .regular))
                    .foregroundStyle(SignalStyle.inkMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Circle()
                .fill(isSelected ? SignalStyle.accent : SignalStyle.separator)
                .frame(width: isSelected ? 6 : 4, height: isSelected ? 6 : 4)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
        .background(
            isSelected ? SignalStyle.accent.opacity(0.055) : Color.clear,
            in: RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.52))
                .frame(height: 0.65)
        }
        .contentShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))
    }

    private var cardRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if MujiStyle.isActive { return 11 }
        if BentoStyle.isActive { return 18 }
        if NeumorphicStyle.isActive { return 18 }
        if CapsuleStyle.isActive { return 20 }
        if SequoiaStyle.isActive { return 16 }
        if SignalStyle.isActive { return 18 }
        return 12
    }

    private var cardTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(13, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .semibold) }
        if BentoStyle.isActive { return BentoStyle.labelFont(13, weight: .heavy) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(13, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.labelFont(13, weight: .bold) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var titleColor: Color {
        if MangaStyle.isActive {
            return isSelected
                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk)
                : MangaStyle.ink
        }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.ink }
        if BentoStyle.isActive { return isSelected ? BentoStyle.onAccent : BentoStyle.ink }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return isSelected ? CapsuleStyle.onAccent : CapsuleStyle.ink }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.ink : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent : SignalStyle.ink }
        return isSelected ? .monoIconForeground : .monoTextPrimary
    }

    private var descriptionColor: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.inkSub : MangaStyle.inkSub.opacity(0.82) }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint.opacity(0.78) : MujiStyle.inkSoft }
        if BentoStyle.isActive { return isSelected ? BentoStyle.onAccent.opacity(0.76) : BentoStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return isSelected ? CapsuleStyle.onAccent.opacity(0.76) : CapsuleStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent.opacity(0.76) : SignalStyle.inkSoft }
        return isSelected ? Color.monoIconForeground.opacity(0.74) : .monoTextSecondary
    }

    private var iconColor: Color {
        if MangaStyle.isActive {
            return isSelected
                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk)
                : MangaStyle.inkSub
        }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.clay }
        if BentoStyle.isActive { return isSelected ? BentoStyle.onAccent : BentoStyle.tomato }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return isSelected ? CapsuleStyle.onAccent : CapsuleStyle.accent }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.accent : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent : SignalStyle.accent }
        return isSelected ? .monoIconForeground : .monoTextSecondary
    }

    private var selectedMarkColor: Color {
        if MangaStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk)
        }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if SignalStyle.isActive { return SignalStyle.onAccent }
        return .monoIconForeground
    }

    @ViewBuilder
    private var iconBadge: some View {
        if MangaStyle.isActive {
            // 去卡片化：图标直接排在选项面上，不再包底板
            MonoIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.8)
                .frame(width: 32, height: 32)
        } else if MujiStyle.isActive {
            MonoIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.45)
                .frame(width: 31, height: 31)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? MujiStyle.onTint.opacity(0.16) : MujiStyle.surfaceRaised.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? MujiStyle.onTint.opacity(0.28) : MujiStyle.hairline.opacity(0.44), lineWidth: 0.6)
                )
        } else if NeumorphicStyle.isActive {
            MonoIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.55)
                .frame(width: 32, height: 32)
                .background(NeumorphicSurfaceBackground(cornerRadius: 11, elevated: false, pressed: isSelected, lightweight: true))
        } else if CapsuleStyle.isActive {
            MonoIcon(icon: style.iconType, size: 16, color: iconColor, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? CapsuleStyle.onAccent.opacity(0.16) : CapsuleStyle.surfaceTint.opacity(0.74))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? CapsuleStyle.onAccent.opacity(0.28) : CapsuleStyle.separator.opacity(0.42), lineWidth: 0.7)
                        )
                )
        } else if SequoiaStyle.isActive {
            MonoIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.55)
                .frame(width: 32, height: 32)
                .background(
                    SequoiaSurfaceBackground(
                        cornerRadius: 11,
                        elevated: isSelected,
                        pressed: !isSelected,
                        fill: isSelected ? SequoiaStyle.selectedWash : SequoiaStyle.materialList,
                        role: isSelected ? .selected : .list
                    )
                )
        } else if SignalStyle.isActive {
            MonoIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.55)
                .frame(width: 32, height: 32)
                .background(SignalSurfaceBackground(cornerRadius: 11, elevated: false, pressed: isSelected, fill: isSelected ? SignalStyle.accent : SignalStyle.control))
        } else if BentoStyle.isActive {
            MonoIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isSelected ? BentoStyle.tomato.opacity(0.92) : BentoStyle.paperWarm.opacity(0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65)
                        )
                )
        } else {
            MonoIcon(icon: style.iconType, size: 18, color: iconColor, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.monoIconBackground.opacity(0.22) : Color.monoSeparator.opacity(0.38))
                )
        }
    }

    @ViewBuilder
    private var selectedMark: some View {
        if isSelected {
            MonoIcon(icon: .checkmark, size: 10, color: selectedMarkColor, lineWidth: 1.8)
                .frame(width: MangaStyle.isActive ? 21 : 20, height: MangaStyle.isActive ? 21 : 20)
                .background(selectedMarkBackground)
        } else {
            Circle()
                .fill(markEmptyFill)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var selectedMarkBackground: some View {
        if MangaStyle.isActive {
            Circle()
                .fill(MangaStyle.bubblePink)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.3))
        } else if MujiStyle.isActive {
            Circle()
                .fill(MujiStyle.tea)
        } else if NeumorphicStyle.isActive {
            Circle()
                .fill(NeumorphicStyle.accent)
        } else if CapsuleStyle.isActive {
            Circle()
                .fill(CapsuleStyle.accent)
        } else if SequoiaStyle.isActive {
            Circle()
                .fill(SequoiaStyle.accent)
        } else if SignalStyle.isActive {
            Circle()
                .fill(SignalStyle.accent)
        } else if BentoStyle.isActive {
            Circle()
                .fill(BentoStyle.tomato)
        } else {
            Circle()
                .fill(Color.monoIconBackground)
        }
    }

    private var markEmptyFill: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.18) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.45) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.65) }
        if CapsuleStyle.isActive { return CapsuleStyle.separator.opacity(0.72) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.86) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(0.72) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.82) }
        return .monoSeparator.opacity(0.8)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if MangaStyle.isActive {
            // 去卡片化：选中平涂色块，未选中仅细墨线
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? MangaStyle.labelYellow : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(isSelected ? 0 : 0.32), lineWidth: 1)
                )
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? MujiStyle.clay : MujiStyle.surface)
                .overlay(
                    MujiPaperTexture(opacity: isSelected ? 0.05 : 0.1)
                        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(isSelected ? MujiStyle.clay.opacity(0.28) : MujiStyle.hairline.opacity(0.5), lineWidth: 0.65)
                )
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                pressed: !isSelected,
                tint: isSelected ? NeumorphicStyle.surfaceRaised : NeumorphicStyle.surface,
                lightweight: true
            )
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                tint: isSelected ? CapsuleStyle.accent : CapsuleStyle.surface.opacity(0.9)
            )
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? SequoiaStyle.selectedWash : SequoiaStyle.materialList,
                role: isSelected ? .selected : .list
            )
        } else if SignalStyle.isActive {
            SignalSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? SignalStyle.accent : SignalStyle.control
            )
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? BentoStyle.tomato : BentoStyle.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(BentoStyle.hairline.opacity(isSelected ? 0.25 : 0.58), lineWidth: 0.7)
                )
        } else {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? Color.monoIconBackground : Color.monoSeparator.opacity(0.48))
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(Color.monoIconBackground.opacity(isSelected ? 0.24 : 0), lineWidth: 1)
                )
        }
    }
}

struct BentoSettingsTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        BentoBlock(fill: tint, foreground: BentoStyle.onAccent, radius: 24, padding: 13) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    MonoIcon(icon: icon, size: 18, color: BentoStyle.onAccent, lineWidth: 1.75)
                        .frame(width: 36, height: 36)
                        .background(BentoStyle.onAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Spacer(minLength: 8)

                    Text(value.uppercased())
                        .font(BentoStyle.labelFont(10, weight: .black))
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(BentoStyle.onAccent.opacity(0.88))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BentoStyle.onAccent.opacity(0.14), in: Capsule())
                }

                Text(title)
                    .font(BentoStyle.titleFont(15, weight: .heavy))
                    .foregroundStyle(BentoStyle.onAccent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 116)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct CapsuleSettingsTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                CapsuleIconBadge(icon: icon, tint: tint, size: 38)

                Spacer(minLength: 8)

                Text(value)
                    .font(CapsuleStyle.labelFont(10, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                            .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 0.7))
                    )
            }

            Text(title)
                .font(CapsuleStyle.titleFont(15, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Capsule()
                    .fill(tint.opacity(0.72))
                    .frame(width: 28, height: 6)
                Capsule()
                    .fill(CapsuleStyle.cyan.opacity(0.42))
                    .frame(width: 10, height: 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .padding(14)
        .background(CapsuleSurfaceBackground(cornerRadius: 26, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
