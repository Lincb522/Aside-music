import PhotosUI
import SwiftUI

extension ThemeColorCustomizationSection {
    func colorPickerPill(title: String, target: ThemeColorPickerTarget, binding: Binding<Color>) -> some View {
        Button {
            activeColorPicker = target
        } label: {
            HStack(spacing: 8) {
                colorSwatch(binding.wrappedValue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(appearanceSettingsFont(12, weight: .medium))
                        .foregroundStyle(themeSubtextColor)
                        .lineLimit(1)

                    Text("#\(binding.wrappedValue.toHex())")
                        .font(appearanceSettingsFont(9, weight: .regular))
                        .foregroundStyle(themeSubtextColor.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                MonoIcon(icon: .chevronRight, size: 9, color: themeSubtextColor.opacity(0.72), lineWidth: 1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(fieldBackground)
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.985))
    }

    func colorSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(themeStrokeColor, lineWidth: theme == .manga ? 1.2 : 0.7))
    }

    func modeBinding(_ role: ThemeCustomColorRole) -> Binding<ThemeCustomColorMode> {
        Binding(
            get: { ThemeColorCustomization.mode(for: theme, role: role) },
            set: { mode in
                ThemeColorCustomization.setMode(mode, for: theme, role: role)
            }
        )
    }

    func gradientStyleBinding(_ role: ThemeCustomColorRole) -> Binding<ThemeCustomGradientStyle> {
        Binding(
            get: { ThemeColorCustomization.gradientStyle(for: theme, role: role) },
            set: { style in
                ThemeColorCustomization.setGradientStyle(style, for: theme, role: role)
            }
        )
    }

    func colorBinding(role: ThemeCustomColorRole, suffix: String, fallback: String) -> Binding<Color> {
        Binding(
            get: {
                Color(hex: ThemeColorCustomization.hex(theme, role, suffix, fallback: fallback))
            },
            set: { color in
                ThemeColorCustomization.setHex(color.toHex(), for: theme, role: role, suffix: suffix)
            }
        )
    }

    func mangaColorBinding(suffix: String, fallback: String) -> Binding<Color> {
        Binding(
            get: { Color(hex: ThemeColorCustomization.mangaHex(suffix, fallback: fallback)) },
            set: { color in
                ThemeColorCustomization.setMangaHex(color.toHex(), suffix: suffix)
            }
        )
    }

    func binding(for target: ThemeColorPickerTarget) -> Binding<Color> {
        if target.isMangaExtra {
            return mangaColorBinding(suffix: target.suffix, fallback: target.fallback)
        }

        return colorBinding(
            role: target.role ?? .accent,
            suffix: target.suffix,
            fallback: target.fallback
        )
    }

    func fallbackHex(role: ThemeCustomColorRole, suffix: String) -> String {
        if role == .background {
            return ThemeColorCustomization.defaultBackgroundStopHex(for: theme, suffix: suffix)
        }

        switch (theme, role, suffix) {
        case (.minimalWhite, .accent, _): return "18181B"
        case (.minimalWhite, .background, _): return "FFFFFF"
        case (.muji, .accent, "end"): return "B56B4B"
        case (.muji, .accent, _): return "B56B4B"
        case (.muji, .background, "end"): return "F7F1E8"
        case (.muji, .background, _): return "F7F1E8"
        case (.neumorphic, .accent, "end"): return "4F8E86"
        case (.neumorphic, .accent, _): return "4F8E86"
        case (.neumorphic, .background, "end"): return "F2EEE8"
        case (.neumorphic, .background, _): return "E9EDF0"
        case (.capsule, .accent, "end"): return "3867FF"
        case (.capsule, .accent, _): return "3867FF"
        case (.capsule, .background, "end"): return "EAF1FF"
        case (.capsule, .background, _): return "F6F8FF"
        case (.signal, .accent, "end"): return "20D96D"
        case (.signal, .accent, _): return "49FF8A"
        case (.signal, .background, "end"): return "061009"
        case (.signal, .background, _): return "020604"
        case (.petWhite, .accent, "end"): return "8FDCD5"
        case (.petWhite, .accent, _): return "F6A93B"
        case (.petWhite, .background, "end"): return "F6FAFA"
        case (.petWhite, .background, _): return "FFFFFF"
        case (.clarity, .accent, "end"): return "2478D8"
        case (.clarity, .accent, _): return "2478D8"
        case (.clarity, .background, "end"): return "EAF0F2"
        case (.clarity, .background, _): return "EEF2F3"
        case (.manga, .accent, "end"): return "124BFF"
        case (.manga, .accent, _): return "DBF400"
        case (.manga, .background, "end"): return "E8DECD"
        case (.manga, .background, _): return "F3E9D8"
        case (.default, .accent, "end"): return "4D6F95"
        case (.default, .accent, _): return "4D6F95"
        case (.default, .background, "end"): return "E6EDF6"
        case (.default, .background, _): return "F8FAFC"
        }
    }

    func roleTitle(_ role: ThemeCustomColorRole) -> String {
        if theme == .manga && role == .accent {
            return String(localized: "强调色（计时/选中）")
        }
        return role.displayName
    }

    func selectedPresetMark(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                MonoIcon(icon: .checkmark, size: 8.5, color: selectedPresetMarkColor, lineWidth: 1.8)
                    .frame(width: 17, height: 17)
                    .background(selectedPresetMarkBackground)
            }
        }
        .frame(width: 17, height: 17)
    }

    func gradientStyleChipBackground(isSelected: Bool) -> some View {
        presetBackground(isSelected: isSelected)
    }

    @ViewBuilder
    func presetBackground(isSelected: Bool) -> some View {
        if theme == .minimalWhite {
            MinimalWhiteCapsuleBackground(elevated: isSelected, selected: isSelected)
        } else if theme == .manga {
            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                .fill(isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite)
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: isSelected ? 1.9 : 1.3))
                .shadow(color: isSelected ? MangaStyle.strokeInk.opacity(0.22) : .clear, radius: 0, x: 2, y: 2)
        } else if theme == .muji {
            Capsule()
                .fill(isSelected ? MujiStyle.clay.opacity(0.14) : MujiStyle.surface.opacity(0.78))
                .overlay(Capsule().stroke(isSelected ? MujiStyle.clay.opacity(0.42) : MujiStyle.hairline.opacity(0.48), lineWidth: isSelected ? 0.9 : 0.65))
                .overlay(MujiPaperTexture(opacity: isSelected ? 0.04 : 0.08).clipShape(Capsule()))
        } else if theme == .neumorphic {
            NeumorphicSurfaceBackground(cornerRadius: 18, elevated: isSelected, pressed: !isSelected, tint: isSelected ? NeumorphicStyle.accent.opacity(0.14) : nil, lightweight: true)
        } else if theme == .capsule {
            Capsule()
                .fill(isSelected ? CapsuleStyle.accent.opacity(0.16) : CapsuleStyle.surfaceRaised.opacity(0.82))
                .overlay(Capsule().stroke(isSelected ? CapsuleStyle.accent.opacity(0.38) : CapsuleStyle.separator.opacity(0.5), lineWidth: isSelected ? 0.9 : 0.65))
        } else if theme == .clarity {
            ClarityMembrane(shape: Capsule(), strength: isSelected ? .strong : .quiet, selected: isSelected)
        } else {
            Capsule()
                .fill(isSelected ? Color.monoAccent.opacity(0.12) : Color.monoGlassTint)
                .overlay(Capsule().stroke(isSelected ? Color.monoAccent.opacity(0.32) : Color.monoSeparator.opacity(0.72), lineWidth: isSelected ? 0.9 : 0.65))
        }
    }

    @ViewBuilder
    var fieldBackground: some View {
        if theme == .minimalWhite {
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.compactRadius,
                elevated: false,
                tint: MinimalWhiteStyle.controlGlassFill
            )
        } else if theme == .manga {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MangaStyle.bubbleWhite)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.2))
        } else if theme == .muji {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.65))
        } else if theme == .neumorphic {
            NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true)
        } else if theme == .capsule {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CapsuleStyle.surfaceRaised.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CapsuleStyle.separator.opacity(0.48), lineWidth: 0.65))
        } else if theme == .clarity {
            ClarityMembrane(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), strength: .quiet)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.monoGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.monoSeparator.opacity(0.68), lineWidth: 0.65))
        }
    }

    var themeTextColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.ink }
        if theme == .manga { return MangaStyle.ink }
        if theme == .muji { return MujiStyle.ink }
        if theme == .capsule { return CapsuleStyle.ink }
        if theme == .clarity { return ClarityStyle.ink }
        if theme == .default { return Color.monoTextPrimary }
        return NeumorphicStyle.ink
    }

    var themeSubtextColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.inkMuted }
        if theme == .manga { return MangaStyle.inkSub }
        if theme == .muji { return MujiStyle.inkSoft }
        if theme == .capsule { return CapsuleStyle.inkSoft }
        if theme == .clarity { return ClarityStyle.inkSoft }
        if theme == .default { return Color.monoTextSecondary }
        return NeumorphicStyle.inkSoft
    }

    var themeStrokeColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.hairline }
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.hairline.opacity(0.54) }
        if theme == .capsule { return CapsuleStyle.separator.opacity(0.64) }
        if theme == .clarity { return ClarityStyle.separator }
        if theme == .default { return Color.monoSeparator }
        return NeumorphicStyle.separator.opacity(0.62)
    }

    var selectedPresetTextColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.ink }
        if theme == .manga {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
        }
        if theme == .muji { return MujiStyle.clay }
        if theme == .capsule { return CapsuleStyle.accent }
        if theme == .clarity { return ClarityStyle.ink }
        if theme == .default { return Color.monoAccent }
        return NeumorphicStyle.accent
    }

    var selectedPresetMarkColor: Color {
        if theme == .minimalWhite {
            return MinimalWhiteStyle.onAccent
        }
        if theme == .manga {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.bubblePink, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
        }
        if theme == .muji {
            return ThemeColorCustomization.readableForegroundColor(on: MujiStyle.tea, light: MujiStyle.ink, dark: Color(hex: "FFF8EF"))
        }
        if theme == .clarity {
            return ClarityStyle.onSelection
        }
        return ThemeColorCustomization.accentForegroundColor(for: theme)
    }

    @ViewBuilder
    var selectedPresetMarkBackground: some View {
        if theme == .minimalWhite {
            Circle()
                .fill(MinimalWhiteStyle.ink)
        } else if theme == .manga {
            Circle()
                .fill(MangaStyle.bubblePink)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.2))
        } else if theme == .muji {
            Circle()
                .fill(MujiStyle.tea)
        } else if theme == .default {
            Circle()
                .fill(Color.monoIconBackground)
        } else if theme == .capsule {
            Circle()
                .fill(CapsuleStyle.accent)
        } else if theme == .clarity {
            Circle()
                .fill(ClarityStyle.selection)
        } else {
            Circle()
                .fill(NeumorphicStyle.accent)
        }
    }

    var savePresetIconColor: Color {
        if theme == .minimalWhite {
            return MinimalWhiteStyle.onAccent
        }
        if theme == .manga {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
        }
        if theme == .clarity {
            return ClarityStyle.onSelection
        }
        return ThemeColorCustomization.accentForegroundColor(for: theme)
    }

    @ViewBuilder
    var savePresetIconBackground: some View {
        if theme == .minimalWhite {
            Circle()
                .fill(MinimalWhiteStyle.ink)
        } else if theme == .manga {
            Circle()
                .fill(MangaStyle.labelYellow)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.1))
        } else if theme == .muji {
            Circle()
                .fill(MujiStyle.clay.opacity(0.82))
        } else if theme == .neumorphic {
            Circle()
                .fill(NeumorphicStyle.accent)
                .shadow(color: NeumorphicStyle.accent.opacity(0.18), radius: 5, x: 0, y: 3)
        } else if theme == .capsule {
            Circle()
                .fill(CapsuleStyle.accent)
                .shadow(color: CapsuleStyle.accent.opacity(0.16), radius: 6, x: 0, y: 3)
        } else if theme == .clarity {
            Circle()
                .fill(ClarityStyle.selection)
                .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
        } else {
            Circle()
                .fill(Color.monoIconBackground)
        }
    }

    @ViewBuilder
    var savePresetButtonBackground: some View {
        if theme == .minimalWhite {
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.compactRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassFill
            )
        } else if theme == .manga {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(MangaStyle.bubbleWhite)
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.25))
                .shadow(color: MangaStyle.strokeInk.opacity(0.12), radius: 0, x: 2, y: 2)
        } else if theme == .muji {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.74))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.65))
                .overlay(MujiPaperTexture(opacity: 0.065).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous)))
        } else if theme == .neumorphic {
            NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true, pressed: false, tint: NeumorphicStyle.accent.opacity(0.08), lightweight: true)
        } else if theme == .capsule {
            CapsuleSurfaceBackground(cornerRadius: 16, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.86))
        } else if theme == .clarity {
            ClaritySurfaceBackground(cornerRadius: 16, elevated: true)
        } else {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.monoGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.monoSeparator.opacity(0.65), lineWidth: 0.65))
        }
    }
}
