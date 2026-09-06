import PhotosUI
import SwiftUI

extension ThemeColorCustomizationSection {
    // MARK: - 背景图（壁纸式铺满）

    func backgroundImageEditor(dark: Bool) -> some View {
        let photoItemBinding = dark ? $darkBackgroundPhotoItem : $backgroundPhotoItem

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PhotosPicker(selection: photoItemBinding, matching: .images, photoLibrary: .shared()) {
                    ThemeBackgroundImagePickerLabel(theme: theme, dark: dark)
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.985))

                if ThemeColorCustomization.hasBackgroundImage(for: theme, dark: dark) {
                    Button {
                        photoItemBinding.wrappedValue = nil
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            ThemeColorCustomization.clearBackgroundImage(for: theme, dark: dark)
                        }
                    } label: {
                        MonoIcon(icon: .trash, size: 12, color: themeSubtextColor.opacity(0.85), lineWidth: 1.6)
                            .frame(width: 38, height: 38)
                            .background(deletePresetButtonBackground)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
                    .accessibilityLabel(String(localized: "移除背景图"))
                }
            }

            Text(String(localized: "图片将像系统壁纸一样缩放铺满屏幕"))
                .font(appearanceSettingsFont(10.5, weight: .regular))
                .foregroundStyle(themeSubtextColor.opacity(0.72))
        }
        .task(id: photoItemBinding.wrappedValue) {
            guard let item = photoItemBinding.wrappedValue, !Task.isCancelled else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                guard !Task.isCancelled, photoItemBinding.wrappedValue == item else { return }
                await ThemeColorCustomization.setBackgroundImageData(data, for: theme, dark: dark) {
                    photoItemBinding.wrappedValue == item && settings.globalThemeId == theme
                }
            }
            guard !Task.isCancelled, photoItemBinding.wrappedValue == item else { return }
            photoItemBinding.wrappedValue = nil
        }
    }

    // MARK: - 夜间背景（默认主题）

    var darkBackgroundEditor: some View {
        let kind = ThemeColorCustomization.darkBackgroundKind(for: theme)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "夜间背景"))
                    .font(appearanceSettingsFont(13, weight: .semibold))
                    .foregroundStyle(themeTextColor)

                Spacer()

                Picker("", selection: darkBackgroundKindBinding) {
                    ForEach(ThemeDarkBackgroundKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 232)
            }

            switch kind {
            case .solid:
                darkSolidSwatchRow
                colorPickerPill(
                    title: String(localized: "夜间纯色"),
                    target: .role(.background, suffix: "darkSolid", title: String(localized: "夜间纯色"), fallback: ThemeColorCustomization.defaultDarkBackgroundSolidHex),
                    binding: colorBinding(role: .background, suffix: "darkSolid", fallback: ThemeColorCustomization.defaultDarkBackgroundSolidHex)
                )
            case .gradient:
                darkBackgroundGradientColorGrid
                darkGradientStyleSelector
            case .image:
                backgroundImageEditor(dark: true)
            case .standard:
                Text(String(localized: "夜间模式使用主题默认深色背景"))
                    .font(appearanceSettingsFont(10.5, weight: .regular))
                    .foregroundStyle(themeSubtextColor.opacity(0.72))
            }
        }
    }

    var darkSolidSwatchRow: some View {
        let swatches: [(name: String, hex: String)] = [
            (String(localized: "纯黑"), "000000"),
            (String(localized: "碳黑"), "0B0B0D"),
            (String(localized: "暗夜蓝"), "070B14"),
            (String(localized: "深灰"), "141418"),
        ]
        let currentHex = ThemeColorCustomization.normalizedHex(
            ThemeColorCustomization.darkBackgroundSolidHex(for: theme)
        )

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(swatches, id: \.hex) { swatch in
                    let isSelected = currentHex == ThemeColorCustomization.normalizedHex(swatch.hex)
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            ThemeColorCustomization.setHex(swatch.hex, for: theme, role: .background, suffix: "darkSolid")
                        }
                    } label: {
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(hex: swatch.hex))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(themeStrokeColor, lineWidth: 0.7)
                                )

                            Text(swatch.name)
                                .font(appearanceSettingsFont(11.5, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? selectedPresetTextColor : themeTextColor)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(presetBackground(isSelected: isSelected))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(.vertical, 1)
        }
    }

    var darkBackgroundKindBinding: Binding<ThemeDarkBackgroundKind> {
        Binding(
            get: { ThemeColorCustomization.darkBackgroundKind(for: theme) },
            set: { kind in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    ThemeColorCustomization.setDarkBackgroundKind(kind, for: theme)
                }
            }
        )
    }

    var darkBackgroundGradientColorGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                darkGradientColorPill(suffix: "darkStart", title: String(localized: "颜色 1"))
                darkGradientColorPill(suffix: "darkEnd", title: String(localized: "颜色 2"))
            }

            HStack(spacing: 10) {
                darkGradientColorPill(suffix: "darkStop3", title: String(localized: "颜色 3"))
                darkGradientColorPill(suffix: "darkStop4", title: String(localized: "颜色 4"))
            }
        }
    }

    func darkGradientColorPill(suffix: String, title: String) -> some View {
        let fallback = ThemeColorCustomization.defaultDarkBackgroundStopHex(suffix)
        return colorPickerPill(
            title: title,
            target: .role(
                .background,
                suffix: suffix,
                title: title,
                fallback: fallback
            ),
            binding: colorBinding(
                role: .background,
                suffix: suffix,
                fallback: fallback
            )
        )
    }

    var darkGradientStyleSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "渐变方式"))
                .font(appearanceSettingsFont(11, weight: .semibold))
                .foregroundStyle(themeSubtextColor.opacity(0.82))
                .lineLimit(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ThemeCustomGradientStyle.allCases) { style in
                        let isSelected = ThemeColorCustomization.darkBackgroundGradientStyle(
                            for: theme
                        ) == style
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                ThemeColorCustomization.setDarkBackgroundGradientStyle(
                                    style,
                                    for: theme
                                )
                            }
                        } label: {
                            Text(style.displayName)
                                .font(
                                    appearanceSettingsFont(
                                        11.5,
                                        weight: isSelected ? .bold : .semibold
                                    )
                                )
                                .foregroundStyle(
                                    isSelected ? selectedPresetTextColor : themeTextColor
                                )
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(
                                    gradientStyleChipBackground(isSelected: isSelected)
                                )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    func backgroundGradientColorGrid(role: ThemeCustomColorRole) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                gradientColorPill(role: role, suffix: "start", title: String(localized: "颜色 1"))
                gradientColorPill(role: role, suffix: "end", title: String(localized: "颜色 2"))
            }

            HStack(spacing: 10) {
                gradientColorPill(role: role, suffix: "stop3", title: String(localized: "颜色 3"))
                gradientColorPill(role: role, suffix: "stop4", title: String(localized: "颜色 4"))
            }
        }
    }

    func gradientColorPill(role: ThemeCustomColorRole, suffix: String, title: String) -> some View {
        colorPickerPill(
            title: title,
            target: .role(role, suffix: suffix, title: title, fallback: fallbackHex(role: role, suffix: suffix)),
            binding: colorBinding(role: role, suffix: suffix, fallback: fallbackHex(role: role, suffix: suffix))
        )
    }

    func gradientStyleSelector(role: ThemeCustomColorRole) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "渐变方式"))
                .font(appearanceSettingsFont(11, weight: .semibold))
                .foregroundStyle(themeSubtextColor.opacity(0.82))
                .lineLimit(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ThemeCustomGradientStyle.allCases) { style in
                        let isSelected = ThemeColorCustomization.gradientStyle(for: theme, role: role) == style
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                ThemeColorCustomization.setGradientStyle(style, for: theme, role: role)
                            }
                        } label: {
                            Text(style.displayName)
                                .font(appearanceSettingsFont(11.5, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? selectedPresetTextColor : themeTextColor)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(gradientStyleChipBackground(isSelected: isSelected))
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

}
