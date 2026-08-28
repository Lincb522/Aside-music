import PhotosUI
import SwiftUI

extension ThemeColorCustomizationSection {
    var presetRail: some View {
        let builtInPresets = usesDarkAsideCustomization
            ? ThemeColorCustomization.builtInDarkColorPresets(for: theme)
            : ThemeColorCustomization.builtInColorPresets(for: theme)
        let customPresets = usesDarkAsideCustomization
            ? ThemeColorCustomization.customDarkPresets(for: theme)
            : ThemeColorCustomization.customPresets(for: theme)

        return VStack(alignment: .leading, spacing: 12) {
            presetGroup(
                title: String(localized: "预设"),
                presets: builtInPresets,
                allowsDelete: false
            )

            if !customPresets.isEmpty {
                presetGroup(
                    title: String(localized: "自定义方案"),
                    presets: customPresets,
                    allowsDelete: true
                )
            }
        }
    }

    func presetGroup(title: String, presets: [ThemeColorPreset], allowsDelete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(appearanceSettingsFont(10.5, weight: .semibold))
                .foregroundStyle(themeSubtextColor.opacity(0.78))
                .textCase(.uppercase)
                .lineLimit(1)

            presetScrollRow(presets: presets, allowsDelete: allowsDelete)
        }
    }

    func presetScrollRow(presets: [ThemeColorPreset], allowsDelete: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    let isSelected = usesDarkAsideCustomization
                        ? ThemeColorCustomization.isDarkPresetSelected(preset, for: theme)
                        : ThemeColorCustomization.isPresetSelected(preset, for: theme)
                    if allowsDelete {
                        HStack(spacing: 4) {
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    applyPreset(preset)
                                }
                            } label: {
                                presetChipLabel(preset: preset, isSelected: isSelected)
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))

                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    deletePreset(preset)
                                }
                            } label: {
                                MonoIcon(icon: .trash, size: 10.5, color: themeSubtextColor.opacity(0.82), lineWidth: 1.55)
                                    .frame(width: 30, height: 30)
                                    .background(deletePresetButtonBackground)
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
                            .accessibilityLabel(String(localized: "ai_lab_delete"))
                        }
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                applyPreset(preset)
                            }
                        } label: {
                            presetChipLabel(preset: preset, isSelected: isSelected)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    }
                }
            }
            .themeRenderScrollLayer()
            .padding(.vertical, 2)
        }
    }

    func applyPreset(_ preset: ThemeColorPreset) {
        if usesDarkAsideCustomization {
            ThemeColorCustomization.applyDarkPreset(preset, to: theme)
        } else {
            ThemeColorCustomization.applyPreset(preset, to: theme)
        }
    }

    func deletePreset(_ preset: ThemeColorPreset) {
        if usesDarkAsideCustomization {
            ThemeColorCustomization.deleteSavedDarkPreset(preset, for: theme)
        } else {
            ThemeColorCustomization.deleteSavedPreset(preset, for: theme)
        }
    }

    func presetChipLabel(preset: ThemeColorPreset, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            ThemeColorPresetPreviewSwatch(
                theme: theme,
                preset: preset,
                cornerRadius: theme == .manga ? 2 : 10
            )
            .frame(width: isSelected ? 31 : 28, height: isSelected ? 31 : 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .font(appearanceSettingsFont(12, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? selectedPresetTextColor : themeTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.88)
                    .allowsTightening(true)

                if preset.isCustom {
                    Text(preset.iconSetRaw == nil ? String(localized: "已存") : String(localized: "已存 · 含图标包"))
                        .font(appearanceSettingsFont(8.5, weight: .semibold))
                        .foregroundStyle(themeSubtextColor.opacity(0.72))
                        .textCase(.uppercase)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 44, maxWidth: 104, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)

            selectedPresetMark(isSelected: isSelected)
        }
        .padding(.horizontal, isSelected ? 11 : 10)
        .padding(.vertical, 8)
        .background(presetBackground(isSelected: isSelected))
        .scaleEffect(isSelected ? 1.015 : 1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    var deletePresetButtonBackground: some View {
        if theme == .minimalWhite {
            MinimalWhiteCircleBackground()
        } else if theme == .manga {
            Circle()
                .fill(MangaStyle.bubbleWhite)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.1))
        } else if theme == .muji {
            Circle()
                .fill(MujiStyle.surface.opacity(0.78))
                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.65))
        } else if theme == .neumorphic {
            NeumorphicSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, lightweight: true)
        } else if theme == .capsule {
            Circle()
                .fill(CapsuleStyle.surfaceRaised.opacity(0.8))
                .overlay(Circle().stroke(CapsuleStyle.separator.opacity(0.5), lineWidth: 0.65))
        } else {
            Circle()
                .fill(Color.monoGlassTint)
                .overlay(Circle().stroke(Color.monoSeparator.opacity(0.68), lineWidth: 0.65))
        }
    }

    var saveCurrentPresetButton: some View {
        Button {
            showSavePresetOptions = true
        } label: {
            HStack(spacing: 9) {
                MonoIcon(icon: .add, size: 10, color: savePresetIconColor, lineWidth: 1.8)
                    .frame(width: 23, height: 23)
                    .background(savePresetIconBackground)

                Text(String(localized: "保存当前方案"))
                    .font(appearanceSettingsFont(12, weight: .semibold))
                    .foregroundStyle(themeTextColor)

                Spacer(minLength: 6)

                let count = usesDarkAsideCustomization
                    ? ThemeColorCustomization.savedDarkPresets(for: theme).count
                    : ThemeColorCustomization.savedPresets(for: theme).count
                if count > 0 {
                    Text(L10n.format("appearance_saved_count_format", count))
                        .font(appearanceSettingsFont(10, weight: .medium))
                        .foregroundStyle(themeSubtextColor.opacity(0.78))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(savePresetButtonBackground)
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.985))
        .confirmationDialog(
            String(localized: "保存当前方案"),
            isPresented: $showSavePresetOptions,
            titleVisibility: .visible
        ) {
            Button(String(localized: "仅保存配色")) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    if usesDarkAsideCustomization {
                        ThemeColorCustomization.saveCurrentDarkPreset(for: theme)
                    } else {
                        ThemeColorCustomization.saveCurrentPreset(for: theme)
                    }
                }
            }
            Button(L10n.format(
                "appearance_save_colors_icon_format",
                SettingsManager.shared.interfaceIconSet.displayName
            )) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    if usesDarkAsideCustomization {
                        ThemeColorCustomization.saveCurrentDarkPreset(
                            for: theme,
                            includingIconSet: true
                        )
                    } else {
                        ThemeColorCustomization.saveCurrentPreset(
                            for: theme,
                            includingIconSet: true
                        )
                    }
                }
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "选择是否将当前界面图标包一并保存到方案中"))
        }
    }

    func colorRoleEditor(role: ThemeCustomColorRole) -> some View {
        let usesSingleColor = role == .accent || (theme == .muji && role == .background)
        let allowsImage = role == .background && ThemeColorCustomization.supportsImageBackground(theme)
        let modeOptions: [ThemeCustomColorMode] = allowsImage
            ? [.solid, .gradient, .image]
            : ThemeCustomColorMode.allCases
        let currentMode = ThemeColorCustomization.mode(for: theme, role: role)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(roleTitle(role))
                    .font(appearanceSettingsFont(13, weight: .semibold))
                    .foregroundStyle(themeTextColor)

                Spacer()

                if !usesSingleColor {
                    Picker("", selection: modeBinding(role)) {
                        ForEach(modeOptions) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: allowsImage ? 196 : 132)
                } else {
                    Text(String(localized: "单色"))
                        .font(appearanceSettingsFont(11, weight: .semibold))
                        .foregroundStyle(themeSubtextColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(themeStrokeColor.opacity(theme == .manga ? 0.12 : 0.16)))
                }
            }

            if !usesSingleColor && currentMode == .gradient {
                backgroundGradientColorGrid(role: role)
                gradientStyleSelector(role: role)
            } else if allowsImage && currentMode == .image {
                backgroundImageEditor(dark: false)
            } else {
                colorPickerPill(
                    title: String(localized: "颜色"),
                    target: .role(role, suffix: "solid", title: String(localized: "颜色"), fallback: fallbackHex(role: role, suffix: "solid")),
                    binding: colorBinding(role: role, suffix: "solid", fallback: fallbackHex(role: role, suffix: "solid"))
                )
            }
        }
    }

    var darkAccentEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "强调色"))
                    .font(appearanceSettingsFont(13, weight: .semibold))
                    .foregroundStyle(themeTextColor)

                Spacer()

                Text(String(localized: "单色"))
                    .font(appearanceSettingsFont(11, weight: .semibold))
                    .foregroundStyle(themeSubtextColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(themeStrokeColor.opacity(0.16)))
            }

            colorPickerPill(
                title: String(localized: "颜色"),
                target: .role(
                    .accent,
                    suffix: "darkSolid",
                    title: String(localized: "颜色"),
                    fallback: ThemeColorCustomization.defaultDarkAccentHex
                ),
                binding: colorBinding(
                    role: .accent,
                    suffix: "darkSolid",
                    fallback: ThemeColorCustomization.defaultDarkAccentHex
                )
            )
        }
    }

}
