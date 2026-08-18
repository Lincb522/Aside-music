//  外观与歌词设置子页面

import PhotosUI
import SwiftUI

private func appearanceSettingsFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
    if ClarityStyle.isActive {
        return ClarityStyle.body(size, weight: weight)
    }
    if MinimalWhiteStyle.isActive {
        return MinimalWhiteStyle.bodyFont(size, weight: weight)
    }
    if MangaStyle.isActive {
        return MangaStyle.comicFont(size, weight: weight == .regular ? .bold : weight)
    }
    if NeumorphicStyle.isActive {
        return NeumorphicStyle.labelFont(size, weight: weight)
    }
    if SignalStyle.isActive {
        return SignalStyle.labelFont(size, weight: weight)
    }
    if BentoStyle.isActive {
        return BentoStyle.labelFont(size, weight: weight == .bold ? .heavy : weight)
    }
    if MujiStyle.isActive {
        return MujiStyle.labelFont(size, weight: weight == .bold ? .semibold : weight)
    }
    return .system(size: size, weight: weight, design: .rounded)
}

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isGlobalThemeExpanded = false
    @State private var isAppBrandStyleExpanded = false
    @State private var isThemeColorExpanded = false

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                LazyVStack(spacing: SettingsPageLayout.sectionSpacing) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "settings_navigation_appearance_title"),
                        eyebrow: String(localized: "settings_eyebrow_appearance"),
                        icon: .playerTheme
                    )

                    LazyVStack(spacing: SettingsPageLayout.sectionSpacing) {
                        globalThemeSection
                        if ThemeColorCustomization.supports(settings.globalThemeId) {
                            themeColorCustomizationSection
                        }
                        appIconSection
                        layoutSection
                        contentExperienceSection
                        dynamicBackgroundSection
                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .padding(.bottom, 44)
                    .iPadContentWidth(SettingsPageLayout.contentWidth)
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: SettingsPageLayout.scrollCoordinateSpace)
            .themeRenderScrollLayer()
        }
        .asideSettingsDetailChrome(String(localized: "settings_navigation_appearance_title"))
        .onAppear {
            settings.enforceCoverBackgroundPolicyForCurrentTheme()
        }
    }

    // MARK: - 外观

    @ViewBuilder
    private var themeColorCustomizationSection: some View {
        // 漫画主题为固定黑白体系，不开放配色自定义
        if settings.globalThemeId != .manga {
            ThemeColorCustomizationSection(
                theme: settings.globalThemeId,
                isExpanded: $isThemeColorExpanded
            )
        }
    }

    private var appIconSection: some View {
        SettingsSection(title: String(localized: "settings_appearance_app_icon_section")) {
            VStack(spacing: 0) {
                SettingsAppBrandRow(
                    title: String(localized: "settings_app_brand_title"),
                    selection: settings.appBrandStyle,
                    appearance: settings.appBrandAppearance,
                    isExpanded: $isAppBrandStyleExpanded,
                    onSelect: { style in
                        Task {
                            await settings.selectAppBrandStyle(style)
                        }
                    },
                    onSelectAppearance: { appearance in
                        Task {
                            await settings.selectAppBrandAppearance(appearance)
                        }
                    }
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsInterfaceIconSetRow(
                    title: String(localized: "settings_interface_icon_set_title"),
                    selection: Binding(
                        get: { settings.interfaceIconSet },
                        set: { settings.interfaceIconSet = $0 }
                    )
                )
            }
        }
    }

    private var layoutSection: some View {
        SettingsSection(title: String(localized: "settings_appearance_layout_section")) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: .tabBar,
                    title: String(localized: "settings_system_tab_bar"),
                    subtitle: nil,
                    isOn: $settings.useSystemTabBar
                )

                if !settings.useSystemTabBar {
                    Divider()
                        .padding(.leading, 56)

                    SettingsFloatingBarRow(
                        icon: .layers,
                        title: String(localized: "settings_floating_bar"),
                        selection: Binding(
                            get: { settings.floatingBarStyle },
                            set: { settings.floatingBarStyle = $0 }
                        )
                    )

                    if settings.globalThemeId == .default {
                        Divider()
                            .padding(.leading, 56)

                        SettingsToggleRow(
                            icon: .sparkle,
                            title: String(localized: "settings_default_liquid_glass_tabbar"),
                            subtitle: nil,
                            isOn: $settings.defaultThemeUsesLiquidGlassTabBar
                        )
                    }
                }
            }
        }
    }

    private var contentExperienceSection: some View {
        SettingsSection(title: String(localized: "settings_appearance_content_feedback_section")) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: .hitokoto,
                    title: String(localized: "settings_hitokoto"),
                    subtitle: String(localized: "settings_hitokoto_desc"),
                    isOn: $settings.hitokotoEnabled
                )

                if settings.hitokotoEnabled {
                    Divider()
                        .padding(.leading, 56)

                    SettingsHitokotoTypeRow(
                        icon: .filter,
                        title: String(localized: "settings_hitokoto_type"),
                        selection: $settings.hitokotoType
                    )
                }

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .haptic,
                    title: String(localized: "settings_haptic"),
                    subtitle: String(localized: "settings_haptic_desc"),
                    isOn: $settings.hapticFeedback
                )
            }
        }
    }

    private var dynamicBackgroundSection: some View {
        let paletteAccent = GlobalThemeManager.shared.colors.accent

        return SettingsSection(title: String(localized: "settings_appearance_dynamic_background_section")) {
            VStack(spacing: 0) {
                if settings.globalThemeId == .default {
                    SettingsToggleRow(
                        icon: .sparkle,
                        title: String(localized: "settings_aside_fluid_background"),
                        subtitle: String(localized: "settings_aside_fluid_background_desc"),
                        isOn: $settings.asideMusicFluidBackgroundEnabled
                    )

                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)
                }

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_global"),
                    subtitle: String(localized: "settings_cover_bg_global_desc"),
                    isOn: $settings.coverBgGlobal,
                    isEnabled: !settings.locksCoverBackgroundSettings
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_playlist"),
                    subtitle: String(localized: "settings_cover_bg_playlist_desc"),
                    isOn: $settings.coverBgPlaylist,
                    isEnabled: !settings.locksCoverBackgroundSettings
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .layers,
                    title: String(localized: "settings_cover_bg_player"),
                    subtitle: String(localized: "settings_cover_bg_player_desc"),
                    isOn: $settings.coverBgPlayer,
                    isEnabled: !settings.locksCoverBackgroundSettings
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "color_engine_title"))
                        .font(appearanceSettingsFont(14, weight: .semibold))
                        .foregroundStyle(Color.monoTextPrimary)

                    UnifiedColorEngineSettingsControls(accent: paletteAccent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 全局主题

    private var globalThemePreviewColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: DeviceLayout.isPad ? 176 : 148, maximum: DeviceLayout.isPad ? 218 : 186),
                spacing: 12
            ),
        ]
    }

    private var globalThemeSection: some View {
        SettingsSection(title: String(localized: "settings_appearance_global_theme_section")) {
            VStack(spacing: 0) {
                Button {
                    isGlobalThemeExpanded.toggle()
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(icon: .playerTheme)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "settings_appearance_theme_style"))
                                .font(appearanceSettingsFont(15, weight: .medium))
                                .foregroundColor(.monoTextPrimary)

                            Text(settings.globalThemeId.displayName)
                                .font(appearanceSettingsFont(11, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        PetWhiteDisclosureChevron(isExpanded: isGlobalThemeExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                SettingsDisclosureReveal(isExpanded: isGlobalThemeExpanded) {
                    LazyVGrid(columns: globalThemePreviewColumns, spacing: 12) {
                        ForEach(GlobalThemeId.allCases) { themeId in
                            Button {
                                applyGlobalTheme(themeId)
                            } label: {
                                GlobalThemeOptionCard(
                                    themeId: themeId,
                                    isSelected: settings.globalThemeId == themeId
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func applyGlobalTheme(_ themeId: GlobalThemeId) {
        settings.selectGlobalTheme(themeId)

        if let suggestedPlayerTheme = suggestedPlayerTheme(for: themeId) {
            PlayerThemeManager.shared.setTheme(suggestedPlayerTheme)
        }
    }

    private func suggestedPlayerTheme(for themeId: GlobalThemeId) -> PlayerTheme? {
        switch themeId {
        case .neumorphic:
            return .neumorphic
        case .petWhite:
            return .classic
        case .capsule:
            return .classic
        case .clarity:
            return .clarity
        case .default, .muji, .manga, .minimalWhite:
            return nil
        }
    }

    // 歌词颜色设置已迁移到播放器右上角三点菜单 →「歌词外观」（MonoFontPicker.swift）
}

private struct ThemeColorCustomizationSection: View {
    let theme: GlobalThemeId
    @Binding var isExpanded: Bool
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared
    @State private var activeColorPicker: ThemeColorPickerTarget?
    @State private var backgroundPhotoItem: PhotosPickerItem?
    @State private var darkBackgroundPhotoItem: PhotosPickerItem?
    @State private var showSavePresetOptions = false

    var body: some View {
        let _ = settings.globalThemeRevision
        SettingsSection(title: String(localized: "主题颜色")) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(icon: .sparkle)

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
                cornerRadius: theme == .manga ? 22 : (theme == .minimalWhite ? MinimalWhiteStyle.chromeRadius : (theme == .muji ? 20 : 30))
            )
        ) { target in
            ThemeColorPickerSheet(
                theme: theme,
                target: target,
                color: binding(for: target)
            )
        }
    }

    private var usesDarkAsideCustomization: Bool {
        theme == .default && colorScheme == .dark
    }

    private var currentPresetSummary: String {
        if usesDarkAsideCustomization {
            return ThemeColorCustomization.selectedDarkPresetDisplayName(for: theme)
        }
        return ThemeColorCustomization.selectedPresetDisplayName(for: theme)
    }

    private var restoreDefaultColorsButton: some View {
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

    private var presetRail: some View {
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

    private func presetGroup(title: String, presets: [ThemeColorPreset], allowsDelete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(appearanceSettingsFont(10.5, weight: .semibold))
                .foregroundStyle(themeSubtextColor.opacity(0.78))
                .textCase(.uppercase)
                .lineLimit(1)

            presetScrollRow(presets: presets, allowsDelete: allowsDelete)
        }
    }

    private func presetScrollRow(presets: [ThemeColorPreset], allowsDelete: Bool) -> some View {
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

    private func applyPreset(_ preset: ThemeColorPreset) {
        if usesDarkAsideCustomization {
            ThemeColorCustomization.applyDarkPreset(preset, to: theme)
        } else {
            ThemeColorCustomization.applyPreset(preset, to: theme)
        }
    }

    private func deletePreset(_ preset: ThemeColorPreset) {
        if usesDarkAsideCustomization {
            ThemeColorCustomization.deleteSavedDarkPreset(preset, for: theme)
        } else {
            ThemeColorCustomization.deleteSavedPreset(preset, for: theme)
        }
    }

    private func presetChipLabel(preset: ThemeColorPreset, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            ThemeColorPresetPreviewSwatch(
                theme: theme,
                preset: preset,
                cornerRadius: theme == .manga ? 8 : 10
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
    private var deletePresetButtonBackground: some View {
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

    private var saveCurrentPresetButton: some View {
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

    private func colorRoleEditor(role: ThemeCustomColorRole) -> some View {
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

    private var darkAccentEditor: some View {
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

    // MARK: - 背景图（壁纸式铺满）

    private func backgroundImageEditor(dark: Bool) -> some View {
        let photoItemBinding = dark ? $darkBackgroundPhotoItem : $backgroundPhotoItem

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PhotosPicker(selection: photoItemBinding, matching: .images, photoLibrary: .shared()) {
                    ThemeBackgroundImagePickerLabel(theme: theme, dark: dark)
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.985))

                if ThemeColorCustomization.hasBackgroundImage(for: theme, dark: dark) {
                    Button {
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
        .onChange(of: photoItemBinding.wrappedValue) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        ThemeColorCustomization.setBackgroundImageData(data, for: theme, dark: dark)
                    }
                }
                photoItemBinding.wrappedValue = nil
            }
        }
    }

    // MARK: - 夜间背景（默认主题）

    private var darkBackgroundEditor: some View {
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

    private var darkSolidSwatchRow: some View {
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

    private var darkBackgroundKindBinding: Binding<ThemeDarkBackgroundKind> {
        Binding(
            get: { ThemeColorCustomization.darkBackgroundKind(for: theme) },
            set: { kind in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    ThemeColorCustomization.setDarkBackgroundKind(kind, for: theme)
                }
            }
        )
    }

    private var darkBackgroundGradientColorGrid: some View {
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

    private func darkGradientColorPill(suffix: String, title: String) -> some View {
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

    private var darkGradientStyleSelector: some View {
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

    private func backgroundGradientColorGrid(role: ThemeCustomColorRole) -> some View {
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

    private func gradientColorPill(role: ThemeCustomColorRole, suffix: String, title: String) -> some View {
        colorPickerPill(
            title: title,
            target: .role(role, suffix: suffix, title: title, fallback: fallbackHex(role: role, suffix: suffix)),
            binding: colorBinding(role: role, suffix: suffix, fallback: fallbackHex(role: role, suffix: suffix))
        )
    }

    private func gradientStyleSelector(role: ThemeCustomColorRole) -> some View {
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

    private func colorPickerPill(title: String, target: ThemeColorPickerTarget, binding: Binding<Color>) -> some View {
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

    private func colorSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(themeStrokeColor, lineWidth: theme == .manga ? 1.2 : 0.7))
    }

    private func modeBinding(_ role: ThemeCustomColorRole) -> Binding<ThemeCustomColorMode> {
        Binding(
            get: { ThemeColorCustomization.mode(for: theme, role: role) },
            set: { mode in
                ThemeColorCustomization.setMode(mode, for: theme, role: role)
            }
        )
    }

    private func gradientStyleBinding(_ role: ThemeCustomColorRole) -> Binding<ThemeCustomGradientStyle> {
        Binding(
            get: { ThemeColorCustomization.gradientStyle(for: theme, role: role) },
            set: { style in
                ThemeColorCustomization.setGradientStyle(style, for: theme, role: role)
            }
        )
    }

    private func colorBinding(role: ThemeCustomColorRole, suffix: String, fallback: String) -> Binding<Color> {
        Binding(
            get: {
                Color(hex: ThemeColorCustomization.hex(theme, role, suffix, fallback: fallback))
            },
            set: { color in
                ThemeColorCustomization.setHex(color.toHex(), for: theme, role: role, suffix: suffix)
            }
        )
    }

    private func mangaColorBinding(suffix: String, fallback: String) -> Binding<Color> {
        Binding(
            get: { Color(hex: ThemeColorCustomization.mangaHex(suffix, fallback: fallback)) },
            set: { color in
                ThemeColorCustomization.setMangaHex(color.toHex(), suffix: suffix)
            }
        )
    }

    private func binding(for target: ThemeColorPickerTarget) -> Binding<Color> {
        if target.isMangaExtra {
            return mangaColorBinding(suffix: target.suffix, fallback: target.fallback)
        }

        return colorBinding(
            role: target.role ?? .accent,
            suffix: target.suffix,
            fallback: target.fallback
        )
    }

    private func fallbackHex(role: ThemeCustomColorRole, suffix: String) -> String {
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
        case (.petWhite, .accent, "end"): return "8FDCD5"
        case (.petWhite, .accent, _): return "F6A93B"
        case (.petWhite, .background, "end"): return "F6FAFA"
        case (.petWhite, .background, _): return "FFFFFF"
        case (.clarity, .accent, "end"): return "2478D8"
        case (.clarity, .accent, _): return "2478D8"
        case (.clarity, .background, "end"): return "EAF0F2"
        case (.clarity, .background, _): return "EEF2F3"
        case (.manga, .accent, "end"): return "FF4F84"
        case (.manga, .accent, _): return "FF4F84"
        case (.manga, .background, "end"): return "E8F1FF"
        case (.manga, .background, _): return "FFF3D7"
        case (.default, .accent, "end"): return "4D6F95"
        case (.default, .accent, _): return "4D6F95"
        case (.default, .background, "end"): return "E6EDF6"
        case (.default, .background, _): return "F8FAFC"
        }
    }

    private func roleTitle(_ role: ThemeCustomColorRole) -> String {
        if theme == .manga && role == .accent {
            return String(localized: "强调色（按钮/选中）")
        }
        return role.displayName
    }

    private func selectedPresetMark(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                MonoIcon(icon: .checkmark, size: 8.5, color: selectedPresetMarkColor, lineWidth: 1.8)
                    .frame(width: 17, height: 17)
                    .background(selectedPresetMarkBackground)
            }
        }
        .frame(width: 17, height: 17)
    }

    private func gradientStyleChipBackground(isSelected: Bool) -> some View {
        presetBackground(isSelected: isSelected)
    }

    @ViewBuilder
    private func presetBackground(isSelected: Bool) -> some View {
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
    private var fieldBackground: some View {
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

    private var themeTextColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.ink }
        if theme == .manga { return MangaStyle.ink }
        if theme == .muji { return MujiStyle.ink }
        if theme == .capsule { return CapsuleStyle.ink }
        if theme == .clarity { return ClarityStyle.ink }
        if theme == .default { return Color.monoTextPrimary }
        return NeumorphicStyle.ink
    }

    private var themeSubtextColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.inkMuted }
        if theme == .manga { return MangaStyle.inkSub }
        if theme == .muji { return MujiStyle.inkSoft }
        if theme == .capsule { return CapsuleStyle.inkSoft }
        if theme == .clarity { return ClarityStyle.inkSoft }
        if theme == .default { return Color.monoTextSecondary }
        return NeumorphicStyle.inkSoft
    }

    private var themeStrokeColor: Color {
        if theme == .minimalWhite { return MinimalWhiteStyle.hairline }
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.hairline.opacity(0.54) }
        if theme == .capsule { return CapsuleStyle.separator.opacity(0.64) }
        if theme == .clarity { return ClarityStyle.separator }
        if theme == .default { return Color.monoSeparator }
        return NeumorphicStyle.separator.opacity(0.62)
    }

    private var selectedPresetTextColor: Color {
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

    private var selectedPresetMarkColor: Color {
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
    private var selectedPresetMarkBackground: some View {
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

    private var savePresetIconColor: Color {
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
    private var savePresetIconBackground: some View {
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
    private var savePresetButtonBackground: some View {
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

/// PhotosPicker 的标签闭包是 nonisolated 的，初始化只保存可发送的值。
private struct ThemeBackgroundImagePickerLabel: View {
    let theme: GlobalThemeId
    let dark: Bool

    nonisolated init(theme: GlobalThemeId, dark: Bool = false) {
        self.theme = theme
        self.dark = dark
    }

    var body: some View {
        let image = ThemeColorCustomization.backgroundImage(for: theme, dark: dark)

        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.monoGlassTint)
                        .overlay(
                            MonoIcon(icon: .album, size: 14, color: .monoTextSecondary, lineWidth: 1.5)
                        )
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.monoSeparator.opacity(0.7), lineWidth: 0.7)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(image == nil ? String(localized: "选择背景图") : String(localized: "更换背景图"))
                    .font(appearanceSettingsFont(12, weight: .semibold))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)

                Text(String(localized: "从相册选取"))
                    .font(appearanceSettingsFont(9.5, weight: .regular))
                    .foregroundStyle(Color.monoTextSecondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            MonoIcon(icon: .chevronRight, size: 9, color: Color.monoTextSecondary.opacity(0.72), lineWidth: 1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.monoGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.monoSeparator.opacity(0.68), lineWidth: 0.65))
        )
    }
}

private struct ThemeColorPresetPreviewSwatch: View {
    let theme: GlobalThemeId
    let preset: ThemeColorPreset
    var cornerRadius: CGFloat

    var body: some View {
        if theme == .manga {
            mangaSwatch
        } else {
            ThemeColorPreviewSwatch(
                colors: preset.backgroundPaletteHexes.map { Color(hex: $0) },
                cornerRadius: cornerRadius
            )
        }
    }

    private var mangaSwatch: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let stroke = Color(hex: preset.mangaStrokeHex ?? "17151F")
            let accent = Color(hex: preset.accentStartHex)
            let blockA = Color(hex: preset.mangaBlockAHex ?? "FFE067")
            let blockB = Color(hex: preset.mangaBlockBHex ?? "58B9FF")
            let blockC = Color(hex: preset.mangaBlockCHex ?? "8DE4B8")

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: preset.backgroundPaletteHexes.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(blockA)
                    .frame(width: size.width * 0.32, height: size.width * 0.32)
                    .overlay(Circle().stroke(stroke, lineWidth: 1.1))
                    .position(x: size.width * 0.32, y: size.height * 0.34)

                RoundedRectangle(cornerRadius: size.width * 0.1, style: .continuous)
                    .fill(blockB)
                    .frame(width: size.width * 0.38, height: size.height * 0.21)
                    .overlay(RoundedRectangle(cornerRadius: size.width * 0.1, style: .continuous).stroke(stroke, lineWidth: 1))
                    .position(x: size.width * 0.67, y: size.height * 0.38)

                RoundedRectangle(cornerRadius: size.width * 0.08, style: .continuous)
                    .fill(blockC)
                    .frame(width: size.width * 0.42, height: size.height * 0.18)
                    .overlay(RoundedRectangle(cornerRadius: size.width * 0.08, style: .continuous).stroke(stroke, lineWidth: 1))
                    .position(x: size.width * 0.4, y: size.height * 0.72)

                Circle()
                    .fill(accent)
                    .frame(width: size.width * 0.18, height: size.width * 0.18)
                    .overlay(Circle().stroke(stroke, lineWidth: 0.9))
                    .position(x: size.width * 0.76, y: size.height * 0.72)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1.35)
            )
        }
    }
}

private struct ThemeColorPreviewSwatch: View {
    let colors: [Color]
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 0.7)
            )
    }
}

private struct ThemeColorPickerTarget: Identifiable {
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

private struct ThemeColorPickerSheet: View {
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
                return ["3B3145", "4B3A55", "344B5E", "6E5475", "5F5650", "48645C", "83576A", "526483", "6D6A45", "7C5A49", "5F6F7C", "735E87"]
            }
            return ["FF4F84", "FFE067", "58B9FF", "8DE4B8", "FF8CB4", "F8D957", "B7D8FF", "BDE9B8", "FFF3D7", "E8F1FF", "FFEAF0", "EEF7FF"]
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

private struct SettingsAppBrandRow: View {
    let title: String
    let selection: AppBrandStyle
    let appearance: AppBrandAppearance
    @Binding var isExpanded: Bool
    let onSelect: (AppBrandStyle) -> Void
    let onSelectAppearance: (AppBrandAppearance) -> Void

    private var brandPreviewColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 104, maximum: 148), spacing: 10)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(icon: .sparkle)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(appearanceSettingsFont(15, weight: .medium))
                            .foregroundColor(.monoTextPrimary)

                        Text(selectionSummary)
                            .font(appearanceSettingsFont(11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    PetWhiteDisclosureChevron(isExpanded: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            SettingsDisclosureReveal(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: brandPreviewColumns, spacing: 10) {
                        ForEach(AppBrandStyle.allCases) { style in
                            Button {
                                onSelect(style)
                            } label: {
                                AppBrandOptionCard(
                                    style: style,
                                    appearance: appearance,
                                    isSelected: selection == style
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(AppBrandAppearance.allCases) { item in
                            Button {
                                onSelectAppearance(item)
                            } label: {
                                Text(item.displayName)
                                    .font(appearanceSettingsFont(12, weight: appearance == item ? .semibold : .regular))
                                    .foregroundStyle(appearance == item ? Color.monoIconForeground : Color.monoTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(appearance == item ? Color.monoIconBackground : Color.monoSeparator.opacity(0.42))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }

    private var selectionSummary: String {
        let name = selection.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? appearance.displayName : "\(name) · \(appearance.displayName)"
    }
}

private struct SettingsInterfaceIconSetRow: View {
    let title: String
    @Binding var selection: AppInterfaceIconSet
    @State private var isExpanded = false
    @AppStorage(AppInterfaceIconSet.zappiconStyleKey) private var zappiconStyleRaw: String = ZappiconIconStyle.light.rawValue
    @AppStorage(AppInterfaceIconSet.solarStyleKey) private var solarStyleRaw: String = SolarIconStyle.line.rawValue

    private var iconSetPreviewColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 118, maximum: 168), spacing: 8)]
    }

    private var zappiconStyle: ZappiconIconStyle {
        ZappiconIconStyle(rawValue: zappiconStyleRaw) ?? .light
    }

    private var solarStyle: SolarIconStyle {
        SolarIconStyle(rawValue: solarStyleRaw) ?? .line
    }

    private var subtitle: String {
        switch selection {
        case .zappicon:
            return "\(selection.displayName) · \(zappiconStyle.displayName)"
        case .solar:
            return "\(selection.displayName) · \(solarStyle.displayName)"
        default:
            return selection.displayName
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(icon: .gridSquare)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(appearanceSettingsFont(15, weight: .medium))
                            .foregroundColor(.monoTextPrimary)

                        Text(subtitle)
                            .font(appearanceSettingsFont(11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    PetWhiteDisclosureChevron(isExpanded: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            SettingsDisclosureReveal(isExpanded: isExpanded) {
                VStack(spacing: 10) {
                    LazyVGrid(columns: iconSetPreviewColumns, spacing: 8) {
                        ForEach(AppInterfaceIconSet.allCases) { iconSet in
                            Button {
                                selection = iconSet
                            } label: {
                                InterfaceIconSetOptionCard(
                                    iconSet: iconSet,
                                    isSelected: selection == iconSet
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)

                    // Zappicon 风格选择
                    if selection == .zappicon {
                        IconStylePicker(
                            label: "风格",
                            items: ZappiconIconStyle.allCases,
                            selected: zappiconStyle,
                            onSelect: { style in
                                zappiconStyleRaw = style.rawValue
                                AppInterfaceIconSet.setZappiconStyle(style)
                            }
                        )
                        .padding(.horizontal, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Solar 风格选择
                    if selection == .solar {
                        IconStylePicker(
                            label: "风格",
                            items: SolarIconStyle.allCases,
                            selected: solarStyle,
                            onSelect: { style in
                                solarStyleRaw = style.rawValue
                                AppInterfaceIconSet.setSolarStyle(style)
                            }
                        )
                        .padding(.horizontal, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.bottom, 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selection)
            }
        }
    }
}

/// 通用图标风格选择器（Zappicon / Solar 共用）
private struct IconStylePicker<Item: Identifiable & CaseIterable & Hashable>: View where Item.AllCases: RandomAccessCollection {
    let label: String
    let items: Item.AllCases
    let selected: Item
    let onSelect: (Item) -> Void
    let displayName: (Item) -> String

    @Environment(\.colorScheme) private var colorScheme

    private var styleColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 66, maximum: 118), spacing: 6)]
    }

    init(label: String, items: Item.AllCases, selected: Item, onSelect: @escaping (Item) -> Void) where Item: RawRepresentable, Item.RawValue == String {
        self.label = label
        self.items = items
        self.selected = selected
        self.onSelect = onSelect
        // 通过协议获取 displayName
        displayName = { item in
            if let z = item as? ZappiconIconStyle { return z.displayName }
            if let s = item as? SolarIconStyle { return s.displayName }
            return "\(item)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(appearanceSettingsFont(11, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)

            LazyVGrid(columns: styleColumns, spacing: 6) {
                ForEach(Array(items), id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(displayName(item))
                            .font(appearanceSettingsFont(11, weight: selected == item ? .bold : .medium))
                            .foregroundColor(selected == item ? .monoTextPrimary : .monoTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                if selected == item {
                                    Capsule().fill(Color.monoTextPrimary.opacity(colorScheme == .dark ? 0.15 : 0.1))
                                } else {
                                    Capsule().stroke(Color.monoTextSecondary.opacity(0.3), lineWidth: 0.6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct InterfaceIconSetOptionCard: View {
    let iconSet: AppInterfaceIconSet
    let isSelected: Bool

    private let samples: [MonoIcon.IconType] = [
        .homeFilled,
        .play,
        .profileFilled,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(samples.indices, id: \.self) { index in
                    previewIcon(samples[index])
                }
            }

            HStack(spacing: 6) {
                Text(iconSet.displayName)
                    .font(appearanceSettingsFont(12, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isSelected {
                    MonoIcon(icon: .checkmark, size: 10, color: checkColor, lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .background(checkBackground, in: Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(cardStroke, lineWidth: isSelected ? 1.4 : 0.8)
        }
    }

    @ViewBuilder
    private func previewIcon(_ icon: MonoIcon.IconType) -> some View {
        if iconSet.usesOriginalArtwork {
            Image(uiImage: iconSet.image(for: icon))
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: previewIconSize, height: previewIconSize)
                .scaleEffect(originalArtworkScale(for: icon))
                .frame(width: 26, height: 26)
                .background(previewIconBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(uiImage: iconSet.image(for: icon))
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: previewIconSize, height: previewIconSize)
                .foregroundStyle(previewIconColor)
                .frame(width: 26, height: 26)
                .background(previewIconBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private var previewIconSize: CGFloat {
        switch iconSet {
        case .iconExport, .doodlePop, .pawPrint, .dotDogSnake, .minimalWhiteIcons:
            return 18
        case .blobIcons:
            return 17
        case .hicon, .sfSymbols, .zappicon, .lucide, .solar:
            return 15
        }
    }

    private func originalArtworkScale(for icon: MonoIcon.IconType) -> CGFloat {
        switch iconSet {
        case .minimalWhiteIcons:
            return 1.02
        case .doodlePop, .pawPrint, .dotDogSnake:
            switch icon {
            case .karaoke:
                return 1.18
            case .translate:
                return 1.12
            default:
                return 1.08
            }
        case .iconExport:
            return 1.08
        case .hicon, .sfSymbols, .zappicon, .lucide, .solar, .blobIcons:
            return 1
        }
    }

    private var previewIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monoTextPrimary
    }

    private var previewIconBackground: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.labelYellow.opacity(0.85) : MangaStyle.paperCool.opacity(0.9) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(isSelected ? 0.88 : 0.58) }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.surfaceRaised : NeumorphicStyle.surfacePressed }
        return isSelected ? Color.monoIconBackground.opacity(0.16) : Color.monoSeparator.opacity(0.35)
    }

    private var titleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monoTextPrimary
    }

    private var checkColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return .white
    }

    private var checkBackground: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        return .monoAccent
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(backgroundFill)
    }

    private var backgroundFill: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.bubbleBlue.opacity(0.38) : MangaStyle.bubbleWhite.opacity(0.72) }
        if MujiStyle.isActive { return isSelected ? MujiStyle.surfaceRaised.opacity(0.82) : MujiStyle.surface.opacity(0.5) }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.surfaceRaised.opacity(0.92) : NeumorphicStyle.surface.opacity(0.6) }
        return isSelected ? Color.monoIconBackground.opacity(0.12) : Color.monoSeparator.opacity(0.28)
    }

    private var cardStroke: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.strokeInk : MangaStyle.strokeInk.opacity(0.22) }
        if MujiStyle.isActive { return isSelected ? MujiStyle.clay.opacity(0.5) : MujiStyle.hairline.opacity(0.32) }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent.opacity(0.45) : NeumorphicStyle.separator.opacity(0.32) }
        return isSelected ? Color.monoAccent.opacity(0.42) : Color.clear
    }
}

private struct SettingsDisclosureReveal<Content: View>: View {
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

private struct AppBrandOptionCard: View {
    let style: AppBrandStyle
    let appearance: AppBrandAppearance
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(previewBackground)
                .frame(height: 94)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(previewStrokeColor, lineWidth: 1)
                }
                .overlay {
                    Image(style.previewAssetName(for: appearance))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(appearance == .dark ? 0.26 : 0.12), radius: 10, x: 0, y: 4)
                }

            if isSelected {
                Circle()
                    .fill(Color.monoAccent)
                    .frame(width: 20, height: 20)
                    .overlay(MonoIcon(icon: .checkmark, size: 11, color: .monoAccentForeground, lineWidth: 2.1))
                    .padding(7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.monoIconBackground.opacity(0.14) : Color.monoSeparator.opacity(0.38))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.monoAccent.opacity(0.4) : Color.clear, lineWidth: 1.2)
        }
    }

    private var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: style.previewBackgroundColor(for: appearance)),
                Color(hex: style.previewBackgroundColor(for: appearance)).opacity(0.92),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var previewStrokeColor: Color {
        appearance == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.42)
    }
}
