//
//  AppearanceSettingsView.swift
//  Monologue
//
//  外观与歌词设置子页面
//

import SwiftUI

private func appearanceSettingsFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
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
                LazyVStack(spacing: 20) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "settings_navigation_appearance_title"),
                        eyebrow: "STYLE",
                        icon: .sparkle
                    )

                    LazyVStack(spacing: 20) {
                        globalThemeSection
                        if ThemeColorCustomization.supports(settings.globalThemeId) {
                            themeColorCustomizationSection
                        }
                        appIconSection
                        layoutSection
                        contentExperienceSection
                        dynamicBackgroundSection
                        lyricSection
                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .iPadContentWidth(700)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            settings.enforceCoverBackgroundPolicyForCurrentTheme()
        }
    }

    // MARK: - 外观

    private var themeColorCustomizationSection: some View {
        ThemeColorCustomizationSection(
            theme: settings.globalThemeId,
            isExpanded: $isThemeColorExpanded
        )
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
        SettingsSection(title: String(localized: "settings_appearance_dynamic_background_section")) {
            VStack(spacing: 0) {
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
            }
        }
    }

    // MARK: - 全局主题

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
                                .foregroundColor(.monologueTextPrimary)

                            Text(settings.globalThemeId.displayName)
                                .font(appearanceSettingsFont(11, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        MonologueIcon(icon: .chevronRight, size: 11, color: .monologueTextSecondary.opacity(0.8), lineWidth: 1.7)
                            .rotationEffect(.degrees(isGlobalThemeExpanded ? -90 : 90))
                            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04), value: isGlobalThemeExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                SettingsDisclosureReveal(isExpanded: isGlobalThemeExpanded) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
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
                    }
                    .themeRenderScrollLayer()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func applyGlobalTheme(_ themeId: GlobalThemeId) {
        settings.globalThemeId = themeId

        if let suggestedPlayerTheme = suggestedPlayerTheme(for: themeId) {
            PlayerThemeManager.shared.setTheme(suggestedPlayerTheme)
        }
    }

    private func suggestedPlayerTheme(for themeId: GlobalThemeId) -> PlayerTheme? {
        switch themeId {
        case .neumorphic, .sequoia, .liquidGlass:
            return .classic
        case .default, .muji, .manga, .bento, .clay, .signal:
            return nil
        }
    }

    // MARK: - 歌词

    private var lyricSection: some View {
        SettingsSection(title: String(localized: "settings_lyrics")) {
            VStack(spacing: 0) {
                lyricColorModeRow

                if settings.lyricColorMode == "solid" {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricColorPickerRow(
                        title: String(localized: "settings_lyric_color"),
                        hex: $settings.lyricSolidColorHex
                    )
                }

                if settings.lyricColorMode == "gradient" {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricColorPickerRow(
                        title: String(localized: "settings_lyric_color_start"),
                        hex: $settings.lyricGradientStartHex
                    )

                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricColorPickerRow(
                        title: String(localized: "settings_lyric_color_end"),
                        hex: $settings.lyricGradientEndHex
                    )
                }

                if settings.lyricColorMode != "default" {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    lyricPreview
                }
            }
        }
    }

    // MARK: - Lyric Helpers

    private var lyricColorModeRow: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: .sparkle)

            Text(String(localized: "settings_lyric_color"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)

            Spacer()

            Picker("", selection: $settings.lyricColorMode) {
                Text(String(localized: "settings_lyric_color_mode_default")).tag("default")
                Text(String(localized: "settings_lyric_color_mode_solid")).tag("solid")
                Text(String(localized: "settings_lyric_color_mode_gradient")).tag("gradient")
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func lyricColorPickerRow(title: String, hex: Binding<String>) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: hex.wrappedValue))
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.monologueSeparator, lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)

            Spacer()

            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.toHex() }
            ), supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var lyricPreview: some View {
        VStack(spacing: 8) {
            if settings.lyricColorMode == "gradient" {
                Text(String(localized: "settings_lyric_preview"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: settings.lyricGradientStartHex),
                                Color(hex: settings.lyricGradientEndHex),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else if settings.lyricColorMode == "solid" {
                Text(String(localized: "settings_lyric_preview"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: settings.lyricSolidColorHex))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

private struct ThemeColorCustomizationSection: View {
    let theme: GlobalThemeId
    @Binding var isExpanded: Bool
    @ObservedObject private var settings = SettingsManager.shared
    @State private var activeColorPicker: ThemeColorPickerTarget?

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
                                .foregroundStyle(Color.monologueTextPrimary)

                            Text(currentPresetSummary)
                                .font(appearanceSettingsFont(11, weight: .regular))
                                .foregroundStyle(Color.monologueTextSecondary)
                        }

                        Spacer()

                        MonologueIcon(icon: .chevronRight, size: 11, color: Color.monologueTextSecondary.opacity(0.8), lineWidth: 1.7)
                            .rotationEffect(.degrees(isExpanded ? -90 : 90))
                            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04), value: isExpanded)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                SettingsDisclosureReveal(isExpanded: isExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        presetRail
                        saveCurrentPresetButton
                        restoreDefaultColorsButton

                        Divider().opacity(0.35)

                        colorRoleEditor(role: .accent)

                        Divider().opacity(0.35)

                        colorRoleEditor(role: .background)

                        if theme == .manga {
                            Divider().opacity(0.35)
                            mangaExtraEditor
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .id(theme.rawValue)
        .monologueSheet(
            item: $activeColorPicker,
            preset: .custom(
                height: .fixed(438),
                maxContentWidth: 620,
                cornerRadius: theme == .manga ? 22 : (theme == .muji ? 20 : 30)
            )
        ) { target in
            ThemeColorPickerSheet(
                theme: theme,
                target: target,
                color: binding(for: target)
            )
        }
    }

    private var currentPresetSummary: String {
        ThemeColorCustomization.selectedPresetDisplayName(for: theme)
    }

    private var restoreDefaultColorsButton: some View {
        let canRestore = ThemeColorCustomization.hasStoredCustomization(for: theme)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                ThemeColorCustomization.resetThemeColors(for: theme)
            }
        } label: {
            HStack(spacing: 9) {
                MonologueIcon(icon: .refresh, size: 11, color: canRestore ? themeSubtextColor : themeSubtextColor.opacity(0.54), lineWidth: 1.7)
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
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985))
        .disabled(!canRestore)
    }

    private var presetRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            presetGroup(
                title: String(localized: "预设"),
                presets: ThemeColorCustomization.builtInColorPresets(for: theme),
                allowsDelete: false
            )

            let customPresets = ThemeColorCustomization.customPresets(for: theme)
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
                    let isSelected = ThemeColorCustomization.isPresetSelected(preset, for: theme)
                    if allowsDelete {
                        HStack(spacing: 4) {
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    ThemeColorCustomization.applyPreset(preset, to: theme)
                                }
                            } label: {
                                presetChipLabel(preset: preset, isSelected: isSelected)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    ThemeColorCustomization.deleteSavedPreset(preset, for: theme)
                                }
                            } label: {
                                MonologueIcon(icon: .trash, size: 10.5, color: themeSubtextColor.opacity(0.82), lineWidth: 1.55)
                                    .frame(width: 30, height: 30)
                                    .background(deletePresetButtonBackground)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
                            .accessibilityLabel(String(localized: "删除方案"))
                        }
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                ThemeColorCustomization.applyPreset(preset, to: theme)
                            }
                        } label: {
                            presetChipLabel(preset: preset, isSelected: isSelected)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
            }
            .themeRenderScrollLayer()
            .padding(.vertical, 2)
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
                    Text(String(localized: "已存"))
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
        if theme == .manga {
            Circle()
                .fill(MangaStyle.bubbleWhite)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.1))
        } else if theme == .muji {
            Circle()
                .fill(MujiStyle.surface.opacity(0.78))
                .overlay(Circle().stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.65))
        } else if theme == .neumorphic {
            NeumorphicSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, lightweight: true)
        } else if theme == .sequoia {
            SequoiaSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, role: .list)
        } else if theme == .liquidGlass {
            LiquidGlassSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, role: .list)
        } else if theme == .clay {
            ClaySurfaceBackground(cornerRadius: 15, tint: ClayStyle.cream, elevated: false, pressed: true, compact: true)
        } else if theme == .signal {
            SignalSurfaceBackground(cornerRadius: 10, elevated: false, pressed: true, fill: SignalStyle.control)
        } else if theme == .bento {
            Circle()
                .fill(BentoStyle.surface)
                .overlay(Circle().stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65))
        } else {
            Circle()
                .fill(Color.monologueGlassTint)
                .overlay(Circle().stroke(Color.monologueSeparator.opacity(0.68), lineWidth: 0.65))
        }
    }

    private var saveCurrentPresetButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                ThemeColorCustomization.saveCurrentPreset(for: theme)
            }
        } label: {
            HStack(spacing: 9) {
                MonologueIcon(icon: .add, size: 10, color: savePresetIconColor, lineWidth: 1.8)
                    .frame(width: 23, height: 23)
                    .background(savePresetIconBackground)

                Text(String(localized: "保存当前方案"))
                    .font(appearanceSettingsFont(12, weight: .semibold))
                    .foregroundStyle(themeTextColor)

                Spacer(minLength: 6)

                let count = ThemeColorCustomization.savedPresets(for: theme).count
                if count > 0 {
                    Text(String(localized: "已保存 \(count)"))
                        .font(appearanceSettingsFont(10, weight: .medium))
                        .foregroundStyle(themeSubtextColor.opacity(0.78))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(savePresetButtonBackground)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985))
    }

    private func colorRoleEditor(role: ThemeCustomColorRole) -> some View {
        let usesSingleColor = role == .accent || (theme == .muji && role == .background)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(roleTitle(role))
                    .font(appearanceSettingsFont(13, weight: .semibold))
                    .foregroundStyle(themeTextColor)

                Spacer()

                if !usesSingleColor {
                    Picker("", selection: modeBinding(role)) {
                        ForEach(ThemeCustomColorMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 132)
                } else {
                    Text(String(localized: "单色"))
                        .font(appearanceSettingsFont(11, weight: .semibold))
                        .foregroundStyle(themeSubtextColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(themeStrokeColor.opacity(theme == .manga ? 0.12 : 0.16)))
                }
            }

            if !usesSingleColor && ThemeColorCustomization.mode(for: theme, role: role) == .gradient {
                backgroundGradientColorGrid(role: role)
                gradientStyleSelector(role: role)
            } else {
                colorPickerPill(
                    title: String(localized: "颜色"),
                    target: .role(role, suffix: "solid", title: String(localized: "颜色"), fallback: fallbackHex(role: role, suffix: "solid")),
                    binding: colorBinding(role: role, suffix: "solid", fallback: fallbackHex(role: role, suffix: "solid"))
                )
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var mangaExtraEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "漫画色块"))
                .font(appearanceSettingsFont(13, weight: .semibold))
                .foregroundStyle(themeTextColor)

            HStack(spacing: 10) {
                colorPickerPill(
                    title: String(localized: "A 标签/星星"),
                    target: .manga(suffix: "blockA", title: String(localized: "色块 A · 标签/星星"), fallback: "FFE067"),
                    binding: mangaColorBinding(suffix: "blockA", fallback: "FFE067")
                )
                colorPickerPill(
                    title: String(localized: "B 气泡/信息"),
                    target: .manga(suffix: "blockB", title: String(localized: "色块 B · 气泡/信息"), fallback: "58B9FF"),
                    binding: mangaColorBinding(suffix: "blockB", fallback: "58B9FF")
                )
            }

            HStack(spacing: 10) {
                colorPickerPill(
                    title: String(localized: "C 辅助/状态"),
                    target: .manga(suffix: "blockC", title: String(localized: "色块 C · 辅助/状态"), fallback: "8DE4B8"),
                    binding: mangaColorBinding(suffix: "blockC", fallback: "8DE4B8")
                )
                colorPickerPill(
                    title: String(localized: "描边/墨线"),
                    target: .manga(suffix: "stroke", title: String(localized: "描边 · 墨线"), fallback: "17151F"),
                    binding: mangaColorBinding(suffix: "stroke", fallback: "17151F")
                )
            }

            colorPickerPill(
                title: String(localized: "设置小图标"),
                target: .manga(suffix: "settingsIcon", title: String(localized: "设置项小图标"), fallback: "17151F"),
                binding: mangaColorBinding(suffix: "settingsIcon", fallback: "17151F")
            )
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

                MonologueIcon(icon: .chevronRight, size: 9, color: themeSubtextColor.opacity(0.72), lineWidth: 1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(fieldBackground)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985))
    }

    @ViewBuilder
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
        case (.muji, .accent, "end"): return "B56B4B"
        case (.muji, .accent, _): return "B56B4B"
        case (.muji, .background, "end"): return "F7F1E8"
        case (.muji, .background, _): return "F7F1E8"
        case (.neumorphic, .accent, "end"): return "4F8E86"
        case (.neumorphic, .accent, _): return "4F8E86"
        case (.neumorphic, .background, "end"): return "F2EEE8"
        case (.neumorphic, .background, _): return "E9EDF0"
        case (.sequoia, .accent, "end"): return "26AFCF"
        case (.sequoia, .accent, _): return "0A84FF"
        case (.sequoia, .background, "end"): return "E3EBF2"
        case (.sequoia, .background, _): return "F4F7FB"
        case (.liquidGlass, .accent, "end"): return "31D9E8"
        case (.liquidGlass, .accent, _): return "18A7FF"
        case (.liquidGlass, .background, "end"): return "F4F1FF"
        case (.liquidGlass, .background, _): return "F2F8FF"
        case (.clay, .accent, "end"): return "35BFE6"
        case (.clay, .accent, _): return "35BFE6"
        case (.clay, .background, "end"): return "DDF3FA"
        case (.clay, .background, _): return "F7EAD8"
        case (.signal, .accent, "end"): return "2F80ED"
        case (.signal, .accent, _): return "2F80ED"
        case (.signal, .background, "end"): return "F7F2EA"
        case (.signal, .background, _): return "EEF5F8"
        case (.manga, .accent, "end"): return "FF4F84"
        case (.manga, .accent, _): return "FF4F84"
        case (.manga, .background, "end"): return "E8F1FF"
        case (.manga, .background, _): return "FFF3D7"
        case (.bento, .accent, "end"): return "EB7E48"
        case (.bento, .accent, _): return "E54B3B"
        case (.bento, .background, "end"): return "EFE9DD"
        case (.bento, .background, _): return "F5F1EA"
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
                MonologueIcon(icon: .checkmark, size: 8.5, color: selectedPresetMarkColor, lineWidth: 1.8)
                    .frame(width: 17, height: 17)
                    .background(selectedPresetMarkBackground)
            }
        }
        .frame(width: 17, height: 17)
    }

    @ViewBuilder
    private func gradientStyleChipBackground(isSelected: Bool) -> some View {
        presetBackground(isSelected: isSelected)
    }

    @ViewBuilder
    private func presetBackground(isSelected: Bool) -> some View {
        if theme == .manga {
            Capsule()
                .fill(isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite)
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: isSelected ? 1.9 : 1.3))
                .shadow(color: isSelected ? MangaStyle.strokeInk.opacity(0.22) : .clear, radius: 0, x: 2, y: 2)
        } else if theme == .muji {
            Capsule()
                .fill(isSelected ? MujiStyle.clay.opacity(0.14) : MujiStyle.surface.opacity(0.78))
                .overlay(Capsule().stroke(isSelected ? MujiStyle.clay.opacity(0.42) : MujiStyle.hairline.opacity(0.48), lineWidth: isSelected ? 0.9 : 0.65))
                .overlay(MujiPaperTexture(opacity: isSelected ? 0.04 : 0.08).clipShape(Capsule()))
        } else if theme == .neumorphic {
            NeumorphicSurfaceBackground(cornerRadius: 18, elevated: isSelected, pressed: !isSelected, tint: isSelected ? NeumorphicStyle.accent.opacity(0.14) : nil, lightweight: true)
        } else if theme == .sequoia {
            SequoiaSurfaceBackground(cornerRadius: 18, elevated: isSelected, pressed: !isSelected, fill: isSelected ? SequoiaStyle.accent.opacity(0.14) : SequoiaStyle.glass)
        } else if theme == .liquidGlass {
            LiquidGlassSurfaceBackground(
                cornerRadius: 18,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? LiquidGlassStyle.accent.opacity(0.1) : nil,
                role: isSelected ? .selected : .list
            )
        } else if theme == .clay {
            ClaySurfaceBackground(cornerRadius: 18, tint: isSelected ? ClayStyle.accent.opacity(0.16) : ClayStyle.cream, elevated: isSelected, pressed: !isSelected, compact: true)
        } else if theme == .signal {
            SignalSurfaceBackground(cornerRadius: 10, elevated: isSelected, pressed: !isSelected, fill: isSelected ? SignalStyle.accent.opacity(0.16) : SignalStyle.control)
        } else if theme == .bento {
            Capsule()
                .fill(isSelected ? BentoStyle.tomato : BentoStyle.surface)
                .overlay(Capsule().stroke(BentoStyle.hairline.opacity(isSelected ? 0.25 : 0.58), lineWidth: isSelected ? 0.9 : 0.65))
        } else {
            Capsule()
                .fill(isSelected ? Color.monologueAccent.opacity(0.12) : Color.monologueGlassTint)
                .overlay(Capsule().stroke(isSelected ? Color.monologueAccent.opacity(0.32) : Color.monologueSeparator.opacity(0.72), lineWidth: isSelected ? 0.9 : 0.65))
        }
    }

    @ViewBuilder
    private var fieldBackground: some View {
        if theme == .manga {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MangaStyle.bubbleWhite)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.2))
        } else if theme == .muji {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.65))
        } else if theme == .neumorphic {
            NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true)
        } else if theme == .sequoia {
            SequoiaSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true)
        } else if theme == .liquidGlass {
            LiquidGlassSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, role: .list)
        } else if theme == .clay {
            ClaySurfaceBackground(cornerRadius: 14, tint: ClayStyle.cream, elevated: false, pressed: true, compact: true)
        } else if theme == .signal {
            SignalSurfaceBackground(cornerRadius: 10, elevated: false, pressed: true, fill: SignalStyle.control)
        } else if theme == .bento {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BentoStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.monologueGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.monologueSeparator.opacity(0.68), lineWidth: 0.65))
        }
    }

    private var themeTextColor: Color {
        if theme == .manga { return MangaStyle.ink }
        if theme == .muji { return MujiStyle.ink }
        if theme == .sequoia { return SequoiaStyle.ink }
        if theme == .liquidGlass { return LiquidGlassStyle.ink }
        if theme == .clay { return ClayStyle.ink }
        if theme == .default { return Color.monologueTextPrimary }
        if theme == .signal { return SignalStyle.ink }
        if theme == .bento { return BentoStyle.ink }
        return NeumorphicStyle.ink
    }

    private var themeSubtextColor: Color {
        if theme == .manga { return MangaStyle.inkSub }
        if theme == .muji { return MujiStyle.inkSoft }
        if theme == .sequoia { return SequoiaStyle.inkSoft }
        if theme == .liquidGlass { return LiquidGlassStyle.inkSoft }
        if theme == .clay { return ClayStyle.inkSoft }
        if theme == .default { return Color.monologueTextSecondary }
        if theme == .signal { return SignalStyle.inkSoft }
        if theme == .bento { return BentoStyle.inkSoft }
        return NeumorphicStyle.inkSoft
    }

    private var themeStrokeColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.hairline.opacity(0.54) }
        if theme == .sequoia { return SequoiaStyle.separator.opacity(0.74) }
        if theme == .liquidGlass { return LiquidGlassStyle.separator.opacity(0.78) }
        if theme == .clay { return ClayStyle.separator.opacity(0.62) }
        if theme == .default { return Color.monologueSeparator }
        if theme == .signal { return SignalStyle.separator.opacity(0.72) }
        if theme == .bento { return BentoStyle.hairline.opacity(0.64) }
        return NeumorphicStyle.separator.opacity(0.62)
    }

    private var selectedPresetTextColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.clay }
        if theme == .sequoia { return SequoiaStyle.accent }
        if theme == .liquidGlass { return LiquidGlassStyle.accent }
        if theme == .clay { return ClayStyle.accent }
        if theme == .default { return Color.monologueAccent }
        if theme == .signal { return SignalStyle.accent }
        if theme == .bento { return BentoStyle.onAccent }
        return NeumorphicStyle.accent
    }

    private var selectedPresetMarkColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.onTint }
        if theme == .sequoia { return Color.white }
        if theme == .liquidGlass { return LiquidGlassStyle.onAccent }
        if theme == .clay { return ClayStyle.accent }
        if theme == .default { return Color.monologueIconForeground }
        if theme == .signal { return SignalStyle.onAccent }
        if theme == .bento { return BentoStyle.onAccent }
        return Color(light: .white, dark: .black)
    }

    @ViewBuilder
    private var selectedPresetMarkBackground: some View {
        if theme == .manga {
            Circle()
                .fill(MangaStyle.bubblePink)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.2))
        } else if theme == .muji {
            Circle()
                .fill(MujiStyle.tea)
        } else if theme == .default {
            Circle()
                .fill(Color.monologueIconBackground)
        } else if theme == .sequoia {
            Circle()
                .fill(SequoiaStyle.accent)
        } else if theme == .liquidGlass {
            Circle()
                .fill(LiquidGlassStyle.accent)
        } else if theme == .clay {
            Circle()
                .fill(ClayStyle.butter.opacity(0.82))
        } else if theme == .signal {
            Circle()
                .fill(SignalStyle.accent)
        } else if theme == .bento {
            Circle()
                .fill(BentoStyle.tomato)
        } else {
            Circle()
                .fill(NeumorphicStyle.accent)
        }
    }

    private var savePresetIconColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.onTint }
        if theme == .sequoia { return Color.white }
        if theme == .liquidGlass { return LiquidGlassStyle.onAccent }
        if theme == .clay { return ClayStyle.accent }
        if theme == .default { return Color.monologueIconForeground }
        if theme == .signal { return SignalStyle.onAccent }
        if theme == .bento { return BentoStyle.onAccent }
        return Color(light: .white, dark: .black)
    }

    @ViewBuilder
    private var savePresetIconBackground: some View {
        if theme == .manga {
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
        } else if theme == .sequoia {
            Circle()
                .fill(SequoiaStyle.accent)
                .shadow(color: SequoiaStyle.accent.opacity(0.18), radius: 6, x: 0, y: 3)
        } else if theme == .liquidGlass {
            Circle()
                .fill(LiquidGlassStyle.accent)
                .shadow(color: LiquidGlassStyle.accent.opacity(0.22), radius: 7, x: 0, y: 4)
        } else if theme == .clay {
            Circle()
                .fill(ClayStyle.butter.opacity(0.86))
                .shadow(color: ClayStyle.accent.opacity(0.12), radius: 6, x: 0, y: 3)
        } else if theme == .signal {
            Circle()
                .fill(SignalStyle.accent)
                .shadow(color: Color.black.opacity(0.18), radius: 0, x: 2, y: 2)
        } else if theme == .bento {
            Circle()
                .fill(BentoStyle.tomato)
        } else {
            Circle()
                .fill(Color.monologueIconBackground)
        }
    }

    @ViewBuilder
    private var savePresetButtonBackground: some View {
        if theme == .manga {
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
        } else if theme == .sequoia {
            SequoiaSurfaceBackground(cornerRadius: 16, elevated: true, fill: SequoiaStyle.accent.opacity(0.08))
        } else if theme == .liquidGlass {
            LiquidGlassSurfaceBackground(cornerRadius: 16, elevated: true, fill: LiquidGlassStyle.accent.opacity(0.08), role: .chrome)
        } else if theme == .clay {
            ClaySurfaceBackground(cornerRadius: 16, tint: ClayStyle.accent.opacity(0.1), elevated: true, compact: true)
        } else if theme == .signal {
            SignalSurfaceBackground(cornerRadius: 13, elevated: true, fill: SignalStyle.device)
        } else if theme == .bento {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BentoStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65))
        } else {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.monologueGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.monologueSeparator.opacity(0.65), lineWidth: 0.65))
        }
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
                    .stroke(Color.monologueTextPrimary.opacity(0.12), lineWidth: 0.7)
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
                MonologueIcon(icon: .close, size: 13, color: closeIconColor, lineWidth: 1.8)
                    .frame(width: 34, height: 34)
                    .background(closeButtonBackground)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
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
            .shadow(color: previewShadowColor, radius: theme == .neumorphic ? 14 : (theme == .signal ? 16 : 8), x: 0, y: theme == .manga ? 3 : (theme == .signal ? 10 : 8))
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
                                MonologueIcon(icon: .checkmark, size: 10, color: selectedCheckColor, lineWidth: 1.9)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(selectedCheckBackground))
                            }
                        }
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
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

        if theme == .sequoia {
            return ["0A84FF", "26AFCF", "6E68E8", "2E9F73", "B9793B", "5D6B7B", "F4F7FB", "E3EBF2", "F7F9FB", "E5EBF1", "F7F6FD", "E3ECF5"]
        }

        if theme == .liquidGlass {
            return ["18A7FF", "31D9E8", "A074FF", "55D7A8", "FF8EC6", "D99A3B", "F2F8FF", "E8FBFF", "F4F1FF", "EFFAF3", "EEF7FF", "F8F2FF"]
        }

        if theme == .clay {
            return ["E97871", "F5A5C5", "A7DEC6", "A8C9F5", "FFE39B", "CDB4F6", "F6E8DD", "F1F5E9", "F3ECE5", "E8F0FA", "F8E8EA", "EFEAF7"]
        }

        if theme == .default {
            return ["4D6F95", "B66E57", "4D8196", "6A8368", "6E72A7", "9F7559", "F8FAFC", "E6EDF6", "FFF6EB", "EAF0FA", "EEF6FA", "E9F2EC"]
        }

        if theme == .signal {
            return ["2F80ED", "00A98F", "22C7E8", "E19A5E", "7F7BE8", "C8962C", "EEF5F8", "F7F2EA", "EDF8F5", "F8F2EA", "F1F2FC", "EDF3F7"]
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
        } else if theme == .default {
            Color.monologueSheetSurfaceBottom
        } else if theme == .sequoia {
            SequoiaRootBackdrop()
        } else if theme == .liquidGlass {
            LiquidGlassRootBackdrop()
        } else if theme == .clay {
            ClayStyle.base
        } else if theme == .signal {
            SignalStyle.base
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
        } else if theme == .default {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monologueGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.monologueSeparator.opacity(0.66), lineWidth: 0.7))
        } else if theme == .sequoia {
            SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true)
        } else if theme == .liquidGlass {
            LiquidGlassSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list)
        } else if theme == .clay {
            ClaySurfaceBackground(cornerRadius: 16, tint: ClayStyle.cream, elevated: false, pressed: true, compact: true)
        } else if theme == .signal {
            SignalSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, fill: SignalStyle.control)
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
        } else if theme == .default {
            Circle()
                .fill(Color.monologueGlassTint)
                .overlay(Circle().stroke(Color.monologueSeparator.opacity(0.66), lineWidth: 0.7))
        } else if theme == .sequoia {
            SequoiaSurfaceBackground(cornerRadius: 17, elevated: true)
        } else if theme == .liquidGlass {
            LiquidGlassSurfaceBackground(cornerRadius: 17, elevated: true, role: .chrome)
        } else if theme == .clay {
            ClaySurfaceBackground(cornerRadius: 17, tint: ClayStyle.cream, elevated: true, compact: true)
        } else if theme == .signal {
            SignalSurfaceBackground(cornerRadius: 17, elevated: true, fill: SignalStyle.control)
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
                colors: [.white.opacity(0.24), .clear, Color.monologueAccent.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if theme == .sequoia {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color.white.opacity(0.34), .clear, SequoiaStyle.accent.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                HStack(spacing: 5) {
                    Capsule().fill(SequoiaStyle.accent.opacity(0.52)).frame(width: 24, height: 5)
                    Capsule().fill(SequoiaStyle.aqua.opacity(0.34)).frame(width: 14, height: 5)
                    Capsule().fill(SequoiaStyle.separator).frame(width: 5, height: 5)
                }
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if theme == .liquidGlass {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        LiquidGlassStyle.highlight(ColorScheme.light).opacity(0.42),
                        .clear,
                        LiquidGlassStyle.accent.opacity(0.18),
                        LiquidGlassStyle.violet.opacity(0.1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LiquidGlassCausticField(opacity: 0.08)
                HStack(spacing: 5) {
                    Capsule().fill(LiquidGlassStyle.accent.opacity(0.58)).frame(width: 24, height: 5)
                    Capsule().fill(LiquidGlassStyle.cyan.opacity(0.38)).frame(width: 14, height: 5)
                    Capsule().fill(LiquidGlassStyle.violet.opacity(0.32)).frame(width: 5, height: 5)
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if theme == .clay {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [Color(hex: "F7EAD8"), Color(hex: "DDF3FA")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                HStack(spacing: 7) {
                    Circle().fill(ClayStyle.berry).frame(width: 18, height: 18)
                    Circle().fill(ClayStyle.grape).frame(width: 18, height: 18)
                    Circle().fill(ClayStyle.butter).frame(width: 18, height: 18)
                }
                .padding(11)
                .shadow(color: Color(hex: "B88F68").opacity(0.24), radius: 6, x: 2, y: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if theme == .signal {
            SignalGridTexture(opacity: 0.22, gap: 12)
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
        if theme == .manga { return MangaStyle.titleFont(19, weight: .black) }
        if theme == .muji { return MujiStyle.labelFont(18, weight: .semibold) }
        if theme == .default { return .system(size: 18, weight: .semibold, design: .rounded) }
        if theme == .sequoia { return SequoiaStyle.titleFont(18, weight: .semibold) }
        if theme == .liquidGlass { return LiquidGlassStyle.titleFont(18, weight: .semibold) }
        if theme == .clay { return ClayStyle.labelFont(18, weight: .bold) }
        if theme == .signal { return SignalStyle.labelFont(18, weight: .bold) }
        return NeumorphicStyle.labelFont(18, weight: .semibold)
    }

    private var labelFont: Font {
        if theme == .manga { return MangaStyle.labelFont(13, weight: .black) }
        if theme == .muji { return MujiStyle.labelFont(13, weight: .semibold) }
        if theme == .default { return .system(size: 13, weight: .semibold, design: .rounded) }
        if theme == .sequoia { return SequoiaStyle.labelFont(13, weight: .semibold) }
        if theme == .liquidGlass { return LiquidGlassStyle.labelFont(13, weight: .semibold) }
        if theme == .clay { return ClayStyle.labelFont(13, weight: .bold) }
        if theme == .signal { return SignalStyle.labelFont(13, weight: .semibold) }
        return NeumorphicStyle.labelFont(13, weight: .semibold)
    }

    private var titleColor: Color {
        if theme == .manga { return MangaStyle.ink }
        if theme == .muji { return MujiStyle.ink }
        if theme == .default { return Color.monologueTextPrimary }
        if theme == .sequoia { return SequoiaStyle.ink }
        if theme == .liquidGlass { return LiquidGlassStyle.ink }
        if theme == .clay { return ClayStyle.ink }
        if theme == .signal { return SignalStyle.ink }
        return NeumorphicStyle.ink
    }

    private var subtitleColor: Color {
        if theme == .manga { return MangaStyle.inkSub }
        if theme == .muji { return MujiStyle.inkSoft }
        if theme == .default { return Color.monologueTextSecondary }
        if theme == .sequoia { return SequoiaStyle.inkSoft }
        if theme == .liquidGlass { return LiquidGlassStyle.inkSoft }
        if theme == .clay { return ClayStyle.inkSoft }
        if theme == .signal { return SignalStyle.inkSoft }
        return NeumorphicStyle.inkSoft
    }

    private var closeIconColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.inkSoft }
        if theme == .default { return Color.monologueTextSecondary }
        if theme == .sequoia { return SequoiaStyle.inkSoft }
        if theme == .liquidGlass { return LiquidGlassStyle.inkSoft }
        if theme == .clay { return ClayStyle.inkSoft }
        if theme == .signal { return SignalStyle.inkSoft }
        return NeumorphicStyle.inkSoft
    }

    private var previewStrokeColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.hairline.opacity(0.55) }
        if theme == .default { return Color.monologueSeparator.opacity(0.72) }
        if theme == .sequoia { return SequoiaStyle.separator.opacity(0.78) }
        if theme == .liquidGlass { return LiquidGlassStyle.separator.opacity(0.82) }
        if theme == .clay { return ClayStyle.separator.opacity(0.58) }
        if theme == .signal { return SignalStyle.separator.opacity(0.72) }
        return NeumorphicStyle.separator.opacity(0.58)
    }

    private var selectedStrokeColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.clay }
        if theme == .default { return Color.monologueAccent }
        if theme == .sequoia { return SequoiaStyle.accent }
        if theme == .liquidGlass { return LiquidGlassStyle.accent }
        if theme == .clay { return ClayStyle.accent }
        if theme == .signal { return SignalStyle.accent }
        return NeumorphicStyle.accent
    }

    private var selectedCheckColor: Color {
        if theme == .manga { return MangaStyle.strokeInk }
        if theme == .muji { return MujiStyle.onTint }
        if theme == .default { return Color.monologueIconForeground }
        if theme == .sequoia { return Color.white }
        if theme == .liquidGlass { return LiquidGlassStyle.onAccent }
        if theme == .clay { return ClayStyle.accent }
        if theme == .signal { return SignalStyle.onAccent }
        return Color(light: .white, dark: .black)
    }

    private var selectedCheckBackground: Color {
        if theme == .manga { return MangaStyle.labelYellow }
        if theme == .muji { return MujiStyle.tea }
        if theme == .default { return Color.monologueIconBackground }
        if theme == .sequoia { return SequoiaStyle.accent }
        if theme == .liquidGlass { return LiquidGlassStyle.accent }
        if theme == .clay { return ClayStyle.butter }
        if theme == .signal { return SignalStyle.accent }
        return NeumorphicStyle.accent
    }

    private var previewShadowColor: Color {
        if theme == .manga { return MangaStyle.strokeInk.opacity(0.12) }
        if theme == .muji { return MujiStyle.ink.opacity(0.08) }
        if theme == .default { return Color.black.opacity(0.1) }
        if theme == .sequoia { return Color.black.opacity(0.14) }
        if theme == .liquidGlass { return LiquidGlassStyle.accent.opacity(0.16) }
        if theme == .clay { return Color.black.opacity(0.12) }
        if theme == .signal { return Color.black.opacity(0.18) }
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
                            .foregroundColor(.monologueTextPrimary)

                        Text(selectionSummary)
                            .font(appearanceSettingsFont(11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    MonologueIcon(icon: .chevronRight, size: 11, color: .monologueTextSecondary.opacity(0.8), lineWidth: 1.7)
                        .rotationEffect(.degrees(isExpanded ? -90 : 90))
                        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04), value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            SettingsDisclosureReveal(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AppBrandStyle.allCases) { style in
                                Button {
                                    onSelect(style)
                                } label: {
                                    AppBrandOptionCard(
                                        style: style,
                                        appearance: appearance,
                                        isSelected: selection == style
                                    )
                                    .frame(width: 104)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .themeRenderScrollLayer()

                    HStack(spacing: 8) {
                        ForEach(AppBrandAppearance.allCases) { item in
                            Button {
                                onSelectAppearance(item)
                            } label: {
                                Text(item.displayName)
                                    .font(appearanceSettingsFont(12, weight: appearance == item ? .semibold : .regular))
                                    .foregroundStyle(appearance == item ? Color.monologueIconForeground : Color.monologueTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(appearance == item ? Color.monologueIconBackground : Color.monologueSeparator.opacity(0.42))
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
                            .foregroundColor(.monologueTextPrimary)

                        Text(selection.displayName)
                            .font(appearanceSettingsFont(11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    MonologueIcon(icon: .chevronRight, size: 11, color: .monologueTextSecondary.opacity(0.8), lineWidth: 1.7)
                        .rotationEffect(.degrees(isExpanded ? -90 : 90))
                        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04), value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            SettingsDisclosureReveal(isExpanded: isExpanded) {
                HStack(spacing: 10) {
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
                .padding(.bottom, 12)
            }
        }
    }
}

private struct InterfaceIconSetOptionCard: View {
    let iconSet: AppInterfaceIconSet
    let isSelected: Bool

    private let samples: [MonologueIcon.IconType] = [
        .homeFilled,
        .search,
        .play,
        .profileFilled,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(samples.indices, id: \.self) { index in
                    Image(uiImage: iconSet.image(for: samples[index]))
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(previewIconColor)
                        .frame(width: 30, height: 30)
                        .background(previewIconBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }

            HStack(spacing: 6) {
                Text(iconSet.displayName)
                    .font(appearanceSettingsFont(12, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isSelected {
                    MonologueIcon(icon: .checkmark, size: 10, color: checkColor, lineWidth: 2)
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

    private var previewIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
    }

    private var previewIconBackground: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.labelYellow.opacity(0.85) : MangaStyle.paperCool.opacity(0.9) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(isSelected ? 0.88 : 0.58) }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.surfaceRaised : NeumorphicStyle.surfacePressed }
        return isSelected ? Color.monologueIconBackground.opacity(0.16) : Color.monologueSeparator.opacity(0.35)
    }

    private var titleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
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
        return .monologueAccent
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(backgroundFill)
    }

    private var backgroundFill: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.bubbleBlue.opacity(0.38) : MangaStyle.bubbleWhite.opacity(0.72) }
        if MujiStyle.isActive { return isSelected ? MujiStyle.paperWarm.opacity(0.82) : MujiStyle.surface.opacity(0.5) }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.surfaceRaised.opacity(0.92) : NeumorphicStyle.surface.opacity(0.6) }
        return isSelected ? Color.monologueIconBackground.opacity(0.12) : Color.monologueSeparator.opacity(0.28)
    }

    private var cardStroke: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.strokeInk : MangaStyle.strokeInk.opacity(0.22) }
        if MujiStyle.isActive { return isSelected ? MujiStyle.clay.opacity(0.5) : MujiStyle.hairline.opacity(0.32) }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent.opacity(0.45) : NeumorphicStyle.separator.opacity(0.32) }
        return isSelected ? Color.monologueAccent.opacity(0.42) : Color.clear
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
            return .easeOut(duration: 0.12)
        }
        return .interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04)
    }

    private var revealOffset: CGFloat {
        isExpanded || reduceMotion ? 0 : -10
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
            .offset(y: revealOffset)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SettingsDisclosureHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .frame(height: targetHeight, alignment: .top)
            .clipShape(Rectangle())
            .clipped()
            .onPreferenceChange(SettingsDisclosureHeightPreferenceKey.self) { height in
                updateMeasuredHeight(height)
            }
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

private struct SettingsDisclosureHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
                    .fill(Color.monologueAccent)
                    .frame(width: 20, height: 20)
                    .overlay(MonologueIcon(icon: .checkmark, size: 11, color: .white, lineWidth: 2.1))
                    .padding(7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.monologueIconBackground.opacity(0.14) : Color.monologueSeparator.opacity(0.38))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.monologueAccent.opacity(0.4) : Color.clear, lineWidth: 1.2)
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
