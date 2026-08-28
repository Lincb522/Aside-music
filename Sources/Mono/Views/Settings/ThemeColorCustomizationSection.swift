import PhotosUI
import SwiftUI

struct ThemeColorCustomizationSection: View {
    let theme: GlobalThemeId
    @Binding var isExpanded: Bool
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var settings = SettingsManager.shared
    @State var activeColorPicker: ThemeColorPickerTarget?
    @State var backgroundPhotoItem: PhotosPickerItem?
    @State var darkBackgroundPhotoItem: PhotosPickerItem?
    @State var showSavePresetOptions = false

    var body: some View {
        let _ = settings.globalThemeRevision
        SettingsSection(title: String(localized: "主题颜色")) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(icon: .sparkle)
                            .monoIconPulseBloomArtwork("colorEngine")

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "自定义配色"))
                                .font(appearanceSettingsFont(15, weight: .medium))
                                .foregroundStyle(Color.monoTextPrimary)

                            Text(currentPresetSummary)
                                .font(appearanceSettingsFont(11, weight: .regular))
                                .foregroundStyle(Color.monoTextSecondary)
                        }

                        Spacer()

                        PetWhiteDisclosureChevron(isExpanded: isExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if theme == .petWhite {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    SettingsToggleRow(
                        icon: .sparkle,
                        title: String(localized: "Paw 插画"),
                        subtitle: String(localized: "切换为柔和插画风格"),
                        isOn: $settings.petWhiteUsesIllustratedBackground
                    )
                }

                SettingsDisclosureReveal(isExpanded: isExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        presetRail
                        saveCurrentPresetButton
                        restoreDefaultColorsButton

                        Divider().opacity(0.35)

                        if usesDarkAsideCustomization {
                            darkAccentEditor

                            Divider().opacity(0.35)

                            darkBackgroundEditor
                        } else {
                            colorRoleEditor(role: .accent)

                            Divider().opacity(0.35)

                            colorRoleEditor(role: .background)

                            if ThemeColorCustomization.supportsImageBackground(theme),
                               theme != .default
                            {
                                Divider().opacity(0.35)
                                darkBackgroundEditor
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .id(theme.rawValue)
        .monoSheet(
            item: $activeColorPicker,
            preset: .custom(
                height: .fixed(438),
                maxContentWidth: 620,
                cornerRadius: theme == .manga ? 3 : (theme == .minimalWhite ? MinimalWhiteStyle.chromeRadius : (theme == .muji ? 20 : 30))
            )
        ) { target in
            ThemeColorPickerSheet(
                theme: theme,
                target: target,
                color: binding(for: target)
            )
        }
    }

    var usesDarkAsideCustomization: Bool {
        theme == .default && colorScheme == .dark
    }

    var currentPresetSummary: String {
        if usesDarkAsideCustomization {
            return ThemeColorCustomization.selectedDarkPresetDisplayName(for: theme)
        }
        return ThemeColorCustomization.selectedPresetDisplayName(for: theme)
    }

    var restoreDefaultColorsButton: some View {
        let canRestore = usesDarkAsideCustomization
            ? ThemeColorCustomization.hasStoredDarkCustomization(for: theme)
            : ThemeColorCustomization.hasStoredCustomization(for: theme)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                if usesDarkAsideCustomization {
                    ThemeColorCustomization.resetDarkThemeColors(for: theme)
                } else if theme == .default {
                    ThemeColorCustomization.resetLightThemeColors(for: theme)
                } else {
                    ThemeColorCustomization.resetThemeColors(for: theme)
                }
            }
        } label: {
            HStack(spacing: 9) {
                MonoIcon(icon: .refresh, size: 11, color: canRestore ? themeSubtextColor : themeSubtextColor.opacity(0.54), lineWidth: 1.7)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(themeStrokeColor.opacity(canRestore ? 0.12 : 0.07)))

                Text(String(localized: "恢复默认配色"))
                    .font(appearanceSettingsFont(12, weight: .semibold))
                    .foregroundStyle(canRestore ? themeTextColor : themeSubtextColor.opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(fieldBackground)
            .opacity(canRestore ? 1 : 0.58)
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.985))
        .disabled(!canRestore)
    }

}
