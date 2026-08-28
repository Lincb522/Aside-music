import PhotosUI
import SwiftUI

struct ThemeColorPickerTarget: Identifiable {
    let id: String
    let title: String
    let role: ThemeCustomColorRole?
    let suffix: String
    let fallback: String
    let isMangaExtra: Bool

    static func role(_ role: ThemeCustomColorRole, suffix: String, title: String, fallback: String) -> ThemeColorPickerTarget {
        ThemeColorPickerTarget(
            id: "\(role.rawValue)-\(suffix)",
            title: "\(role.displayName) · \(title)",
            role: role,
            suffix: suffix,
            fallback: fallback,
            isMangaExtra: false
        )
    }

    static func manga(suffix: String, title: String, fallback: String) -> ThemeColorPickerTarget {
        ThemeColorPickerTarget(
            id: "manga-\(suffix)",
            title: title,
            role: nil,
            suffix: suffix,
            fallback: fallback,
            isMangaExtra: true
        )
    }
}

struct ThemeColorPickerSheet: View {
    let theme: GlobalThemeId
    let target: ThemeColorPickerTarget
    @Binding var color: Color

    @Environment(\.dismiss) private var dismiss
    @State private var hexInput = ""

    var body: some View {
        ZStack {
            sheetBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header
                previewCard
                pickerRow
                hexRow
                quickPalette
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 18)
        }
        .onAppear {
            hexInput = color.toHex()
        }
        .onChange(of: color.toHex()) { _, newValue in
            if sanitizedHex(hexInput) != newValue {
                hexInput = newValue
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(target.title)
                .font(titleFont)
                .foregroundStyle(titleColor)

            Spacer()

            Button {
                dismiss()
            } label: {
                MonoIcon(icon: .close, size: 13, color: closeIconColor, lineWidth: 1.8)
                    .frame(width: 34, height: 34)
                    .background(closeButtonBackground)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
    }

    private var previewCard: some View {
        RoundedRectangle(cornerRadius: theme == .manga ? 18 : 20, style: .continuous)
            .fill(color)
            .frame(height: 96)
            .overlay(previewDecor)
            .overlay(
                RoundedRectangle(cornerRadius: theme == .manga ? 18 : 20, style: .continuous)
                    .stroke(previewStrokeColor, lineWidth: theme == .manga ? 2 : 0.9)
            )
            .shadow(color: previewShadowColor, radius: theme == .neumorphic ? 14 : 8, x: 0, y: theme == .manga ? 3 : 8)
    }

    private var pickerRow: some View {
        ColorPicker(selection: $color, supportsOpacity: false) {
            Text(String(localized: "颜色"))
                .font(labelFont)
                .foregroundStyle(subtitleColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(rowBackground)
    }

    private var hexRow: some View {
        HStack(spacing: 10) {
            Text("#")
                .font(labelFont)
                .foregroundStyle(subtitleColor.opacity(0.78))

            TextField("HEX", text: $hexInput)
                .font(appearanceSettingsFont(14, weight: .semibold))
                .foregroundStyle(titleColor)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .onChange(of: hexInput) { _, newValue in
                    let value = sanitizedHex(newValue)
                    if value.count == 6, value != color.toHex() {
                        color = Color(hex: value)
                    }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(rowBackground)
    }

    private var quickPalette: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
            ForEach(quickHexes, id: \.self) { hex in
                let selected = ThemeColorCustomization.normalizedHex(hex) == ThemeColorCustomization.normalizedHex(color.toHex())
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        color = Color(hex: hex)
                        hexInput = ThemeColorCustomization.normalizedHex(hex)
                    }
                } label: {
                    RoundedRectangle(cornerRadius: theme == .manga ? 9 : 11, style: .continuous)
                        .fill(Color(hex: hex))
                        .frame(height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme == .manga ? 9 : 11, style: .continuous)
                                .stroke(selected ? selectedStrokeColor : previewStrokeColor.opacity(0.46), lineWidth: selected ? (theme == .manga ? 2.2 : 1.8) : 0.8)
                        )
                        .overlay(alignment: .center) {
                            if selected {
                                MonoIcon(icon: .checkmark, size: 10, color: selectedCheckColor, lineWidth: 1.9)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(selectedCheckBackground))
                            }
                        }
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            }
        }
    }

    private func sanitizedHex(_ value: String) -> String {
        String(value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).prefix(6)).uppercased()
    }

    private var quickHexes: [String] {
        if theme == .manga {
            if target.suffix == "stroke" {
                return ["071E34", "102C46", "173B58", "234C68", "F3E9D8", "E8DECD", "124BFF", "0B39BF", "FF4B0A", "C93400", "DBF400", "A6BB00"]
            }
            return ["DBF400", "124BFF", "FF4B0A", "071E34", "F3E9D8", "E8DECD", "A6BB00", "0B39BF", "C93400", "102C46", "FFF8EB", "DED3C1"]
        }

        if theme == .muji {
            return ["B56B4B", "D8B56D", "78846B", "56677A", "B96D55", "CFA66F", "F7F1E8", "EFE5D6", "F3EEE3", "E4E8D9", "F4E8DC", "EAD9C8"]
        }

        if theme == .minimalWhite {
            return ["111114", "3F3F46", "73737C", "DEDEE3", "EFEFF2", "F6F6F7", "FFFFFF", "FBFBFC", "F8FAFC", "F3F4F6", "EEF2F7", "E5E7EB"]
        }

        if theme == .default {
            return ["4D6F95", "B66E57", "4D8196", "6A8368", "6E72A7", "9F7559", "F8FAFC", "E6EDF6", "FFF6EB", "EAF0FA", "EEF6FA", "E9F2EC"]
        }

        return ["4F8E86", "7D9475", "C59A66", "C65A58", "5E7FA4", "7AB9B0", "E9EDF0", "F2EEE8", "EEE8E1", "E7EDF0", "E8EDF4", "F0F2F4"]
    }

    @ViewBuilder
    private var sheetBackground: some View {
        if theme == .manga {
            ZStack {
                MangaStyle.paper
                MangaDotsTexture(opacity: 0.035, gap: 18)
            }
        } else if theme == .muji {
            ZStack {
                MujiStyle.paper
                MujiPaperTexture(opacity: 0.09)
            }
        } else if theme == .minimalWhite {
            MinimalWhiteRootBackdrop()
        } else if theme == .default {
            Color.monoSheetSurfaceBottom
        } else {
            NeumorphicStyle.base
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if theme == .manga {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(MangaStyle.bubbleWhite)
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.7))
                .shadow(color: MangaStyle.strokeInk.opacity(0.16), radius: 0, x: 2, y: 2)
        } else if theme == .muji {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.82))
                .overlay(MujiPaperTexture(opacity: 0.07).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MujiStyle.hairline.opacity(0.48), lineWidth: 0.65))
        } else if theme == .minimalWhite {
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.cardRadius,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        } else if theme == .default {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monoGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.monoSeparator.opacity(0.66), lineWidth: 0.7))
        } else {
            NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
        }
    }

    @ViewBuilder
    private var closeButtonBackground: some View {
        if theme == .manga {
            Circle()
                .fill(MangaStyle.bubbleWhite)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.4))
        } else if theme == .muji {
            Circle()
                .fill(MujiStyle.surface.opacity(0.86))
                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
        } else if theme == .minimalWhite {
            MinimalWhiteCircleBackground(elevated: true)
        } else if theme == .default {
            Circle()
                .fill(Color.monoGlassTint)
                .overlay(Circle().stroke(Color.monoSeparator.opacity(0.66), lineWidth: 0.7))
        } else {
            NeumorphicSurfaceBackground(cornerRadius: 17, elevated: true, lightweight: true)
        }
    }

    @ViewBuilder
    private var previewDecor: some View {
        if theme == .manga {
            HStack {
                Circle().fill(MangaStyle.bubbleWhite.opacity(0.45)).frame(width: 52, height: 52)
                Spacer()
                MangaDotsTexture(opacity: 0.06, gap: 12).frame(width: 90)
            }
            .padding(12)
            .blendMode(.softLight)
        } else if theme == .muji {
            MujiPaperTexture(opacity: 0.1)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if theme == .default {
            LinearGradient(
                colors: [.white.opacity(0.24), .clear, Color.monoAccent.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            LinearGradient(
                colors: [.white.opacity(0.32), .clear, .black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var titleFont: Font {
        if theme == .minimalWhite { return MinimalWhiteStyle.titleFont(18, weight: .semibold) }
        if theme == .manga { return MangaStyle.titleFont(19, weight: .black) }
        if theme == .muji { return MujiStyle.labelFont(18, weight: .semibold) }
        if theme == .default { return .system(size: 18, weight: .semibold, design: .rounded) }
        return NeumorphicStyle.labelFont(18, weight: .semibold)
    }

    private var labelFont: Font {
        if theme == .minimalWhite { return MinimalWhiteStyle.labelFont(13, weight: .medium) }
        if theme == .manga { return MangaStyle.labelFont(13, weight: .black) }
        if theme == .muji { return MujiStyle.labelFont(13, weight: .semibold) }
        if theme == .default { return .system(size: 13, weight: .semibold, design: .rounded) }
        return NeumorphicStyle.labelFont(13, weight: .semibold)
    }

    private var titleColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.ink }
        if theme == .manga { return MangaStyle.ink }
        if theme == .muji { return MujiStyle.ink }
        if theme == .default { return Color.monoTextPrimary }
        return NeumorphicStyle.ink
    }

    private var subtitleColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.inkMuted }
        if theme == .manga { return MangaStyle.inkSub }
        if theme == .muji { return MujiStyle.inkSoft }
        if theme == .default { return Color.monoTextSecondary }
        return NeumorphicStyle.inkSoft
    }

    private var closeIconColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.inkMuted }
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.inkSoft }
        if theme == .default { return Color.monoTextSecondary }
        return NeumorphicStyle.inkSoft
    }

    private var previewStrokeColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.hairline }
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.hairline.opacity(0.55) }
        if theme == .default { return Color.monoSeparator.opacity(0.72) }
        return NeumorphicStyle.separator.opacity(0.58)
    }

    private var selectedStrokeColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.ink }
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.clay }
        if theme == .default { return Color.monoAccent }
        return NeumorphicStyle.accent
    }

    private var selectedCheckColor: Color {
        if theme == .minimalWhite {
            return MinimalWhiteStyle.onAccent
        }
        if theme == .manga {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
        }
        if theme == .muji {
            return ThemeColorCustomization.readableForegroundColor(on: MujiStyle.tea, light: MujiStyle.ink, dark: Color(hex: "FFF8EF"))
        }
        return ThemeColorCustomization.accentForegroundColor(for: theme)
    }

    private var selectedCheckBackground: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.ink }
        if theme == .manga { return MangaStyle.labelYellow }
        if theme == .muji { return MujiStyle.tea }
        if theme == .default { return Color.monoIconBackground }
        return NeumorphicStyle.accent
    }

    private var previewShadowColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.ink.opacity(0.035) }
        if theme == .manga { return MangaStyle.strokeInk.opacity(0.12) }
        if theme == .muji { return MujiStyle.ink.opacity(0.08) }
        if theme == .default { return Color.black.opacity(0.1) }
        return NeumorphicStyle.darkShadow(.light, intensity: 0.42)
    }
}
