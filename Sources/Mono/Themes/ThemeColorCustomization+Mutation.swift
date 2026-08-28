import Foundation
import SwiftUI
import UIKit

extension ThemeColorCustomization {
    static func isPresetSelected(_ preset: ThemeColorPreset, for theme: GlobalThemeId) -> Bool {
        guard hasStoredCustomization(for: theme) else { return false }

        if let selectedPresetId = UserDefaults.standard.string(forKey: selectedPresetKey(theme)) {
            return preset.id == selectedPresetId && isPresetColorMatched(preset, for: theme)
        }

        return isPresetColorMatched(preset, for: theme)
    }

    static func isPresetColorMatched(_ preset: ThemeColorPreset, for theme: GlobalThemeId) -> Bool {
        guard supports(theme) else { return false }
        guard hasStoredAccent(for: theme), hasStoredBackground(for: theme) else { return false }
        guard mode(for: theme, role: .accent) == .solid else { return false }

        let presetBackgroundMode = preset.backgroundMode ?? (theme == .muji ? .solid : .gradient)
        guard mode(for: theme, role: .background) == presetBackgroundMode else { return false }
        guard gradientStyle(for: theme, role: .background) == preset.gradientStyle.normalized else { return false }

        let presetBackgroundHexes = preset.backgroundPaletteHexes
        let accentSolid = hex(theme, .accent, "solid", fallback: preset.accentStartHex)
        let backgroundSolid = hex(theme, .background, "solid", fallback: preset.backgroundStartHex)

        guard normalizedHex(accentSolid) == normalizedHex(preset.accentStartHex)
        else {
            return false
        }

        if presetBackgroundMode == .solid {
            guard normalizedHex(backgroundSolid) == normalizedHex(preset.backgroundStartHex) else { return false }
        } else {
            for (index, suffix) in backgroundGradientSuffixes.enumerated() {
                let expected = presetBackgroundHexes[index < presetBackgroundHexes.count ? index : presetBackgroundHexes.count - 1]
                let current = hex(theme, .background, suffix, fallback: expected)
                guard normalizedHex(current) == normalizedHex(expected) else {
                    return false
                }
            }
        }

        guard theme == .manga else { return true }

        if let value = preset.mangaBlockAHex, normalizedHex(storedMangaHex("blockA") ?? "") != normalizedHex(value) { return false }
        if let value = preset.mangaBlockBHex, normalizedHex(storedMangaHex("blockB") ?? "") != normalizedHex(value) { return false }
        if let value = preset.mangaBlockCHex, normalizedHex(storedMangaHex("blockC") ?? "") != normalizedHex(value) { return false }
        if let value = preset.mangaStrokeHex, normalizedHex(storedMangaHex("stroke") ?? "") != normalizedHex(value) { return false }
        if let value = preset.mangaSettingsIconHex, normalizedHex(storedMangaHex("settingsIcon") ?? "") != normalizedHex(value) { return false }

        return true
    }

    static func isDarkPresetSelected(_ preset: ThemeColorPreset, for theme: GlobalThemeId) -> Bool {
        guard hasStoredDarkCustomization(for: theme) else { return false }

        if let selectedPresetId = UserDefaults.standard.string(forKey: selectedDarkPresetKey(theme)) {
            return preset.id == selectedPresetId && isDarkPresetColorMatched(preset, for: theme)
        }

        return isDarkPresetColorMatched(preset, for: theme)
    }

    static func isDarkPresetColorMatched(
        _ preset: ThemeColorPreset,
        for theme: GlobalThemeId
    ) -> Bool {
        guard theme == .default, hasStoredDarkAccent(for: theme) else { return false }

        let backgroundMode = preset.backgroundMode ?? .gradient
        let expectedKind: ThemeDarkBackgroundKind = backgroundMode == .solid
            ? .solid
            : .gradient
        guard darkBackgroundKind(for: theme) == expectedKind else { return false }
        guard normalizedHex(darkAccentHex(for: theme)) == normalizedHex(preset.accentStartHex)
        else {
            return false
        }

        if backgroundMode == .solid {
            return normalizedHex(darkBackgroundSolidHex(for: theme))
                == normalizedHex(preset.backgroundStartHex)
        }

        guard darkBackgroundGradientStyle(for: theme) == preset.gradientStyle.normalized else {
            return false
        }

        let presetHexes = preset.backgroundPaletteHexes
        for (index, suffix) in darkBackgroundGradientSuffixes.enumerated() {
            let expected = presetHexes[
                index < presetHexes.count ? index : presetHexes.count - 1
            ]
            let current = hex(theme, .background, suffix, fallback: expected)
            guard normalizedHex(current) == normalizedHex(expected) else {
                return false
            }
        }

        return true
    }

    static func normalizedHex(_ value: String) -> String {
        value
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .uppercased()
    }

    @MainActor
    static func applyPreset(_ preset: ThemeColorPreset, to theme: GlobalThemeId) {
        let defaults = UserDefaults.standard
        defaults.set(ThemeCustomColorMode.solid.rawValue, forKey: key(theme, .accent, "mode"))
        defaults.set(preset.accentStartHex, forKey: key(theme, .accent, "start"))
        defaults.set(preset.accentStartHex, forKey: key(theme, .accent, "end"))
        defaults.set(preset.accentStartHex, forKey: key(theme, .accent, "solid"))
        defaults.set(ThemeCustomGradientStyle.diffuse.rawValue, forKey: key(theme, .accent, "gradientStyle"))

        let backgroundMode: ThemeCustomColorMode = preset.backgroundMode ?? (theme == .muji ? .solid : .gradient)
        defaults.set(backgroundMode.rawValue, forKey: key(theme, .background, "mode"))
        let backgroundPalette = preset.backgroundPaletteHexes
        for (index, suffix) in backgroundGradientSuffixes.enumerated() {
            let value = backgroundPalette[index < backgroundPalette.count ? index : backgroundPalette.count - 1]
            defaults.set(value, forKey: key(theme, .background, suffix))
        }
        defaults.set(preset.backgroundStartHex, forKey: key(theme, .background, "solid"))
        defaults.set(preset.gradientStyle.rawValue, forKey: key(theme, .background, "gradientStyle"))
        defaults.set(preset.id, forKey: selectedPresetKey(theme))

        if theme == .manga {
            if let value = preset.mangaBlockAHex { defaults.set(value, forKey: mangaKey("blockA")) }
            if let value = preset.mangaBlockBHex { defaults.set(value, forKey: mangaKey("blockB")) }
            if let value = preset.mangaBlockCHex { defaults.set(value, forKey: mangaKey("blockC")) }
            if let value = preset.mangaStrokeHex { defaults.set(value, forKey: mangaKey("stroke")) }
            if let value = preset.mangaSettingsIconHex { defaults.set(value, forKey: mangaKey("settingsIcon")) }
        }

        if let iconSetRaw = preset.iconSetRaw, let iconSet = AppInterfaceIconSet(rawValue: iconSetRaw) {
            SettingsManager.shared.interfaceIconSet = iconSet
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func applyDarkPreset(_ preset: ThemeColorPreset, to theme: GlobalThemeId) {
        guard theme == .default else { return }

        let defaults = UserDefaults.standard
        let backgroundMode = preset.backgroundMode ?? .gradient
        let backgroundKind: ThemeDarkBackgroundKind = backgroundMode == .solid
            ? .solid
            : .gradient
        let backgroundPalette = preset.backgroundPaletteHexes

        defaults.set(
            normalizedHex(preset.accentStartHex),
            forKey: key(theme, .accent, "darkSolid")
        )
        defaults.set(
            normalizedHex(preset.backgroundStartHex),
            forKey: key(theme, .background, "darkSolid")
        )
        for (index, suffix) in darkBackgroundGradientSuffixes.enumerated() {
            let value = backgroundPalette[
                index < backgroundPalette.count ? index : backgroundPalette.count - 1
            ]
            defaults.set(normalizedHex(value), forKey: key(theme, .background, suffix))
        }
        defaults.set(
            preset.gradientStyle.normalized.rawValue,
            forKey: key(theme, .background, "darkGradientStyle")
        )
        defaults.set(backgroundKind.rawValue, forKey: key(theme, .background, "darkKind"))
        defaults.set(preset.id, forKey: selectedDarkPresetKey(theme))

        if let iconSetRaw = preset.iconSetRaw,
           let iconSet = AppInterfaceIconSet(rawValue: iconSetRaw)
        {
            SettingsManager.shared.interfaceIconSet = iconSet
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func setMode(_ mode: ThemeCustomColorMode, for theme: GlobalThemeId, role: ThemeCustomColorRole) {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: key(theme, role, "mode"))
        defaults.removeObject(forKey: selectedPresetKey(theme))
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func setGradientStyle(_ style: ThemeCustomGradientStyle, for theme: GlobalThemeId, role: ThemeCustomColorRole) {
        let defaults = UserDefaults.standard
        defaults.set(style.rawValue, forKey: key(theme, role, "gradientStyle"))
        defaults.removeObject(forKey: selectedPresetKey(theme))
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func setHex(_ value: String, for theme: GlobalThemeId, role: ThemeCustomColorRole, suffix: String) {
        let defaults = UserDefaults.standard
        defaults.set(normalizedHex(value), forKey: key(theme, role, suffix))
        if suffix.hasPrefix("dark") {
            defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        } else {
            defaults.removeObject(forKey: selectedPresetKey(theme))
        }
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func setMangaHex(_ value: String, suffix: String) {
        let defaults = UserDefaults.standard
        defaults.set(normalizedHex(value), forKey: mangaKey(suffix))
        defaults.removeObject(forKey: selectedPresetKey(.manga))
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func resetBackground(for theme: GlobalThemeId) {
        let defaults = UserDefaults.standard
        removeBackgroundImageFile(for: theme)
        removeBackgroundImageFile(for: theme, dark: true)
        (["mode", "gradientStyle", "solid", "imageFile", "darkKind", "darkSolid", "darkGradientStyle", "darkImageFile"]
            + backgroundGradientSuffixes
            + darkBackgroundGradientSuffixes).forEach { suffix in
            defaults.removeObject(forKey: key(theme, .background, suffix))
        }
        defaults.removeObject(forKey: selectedPresetKey(theme))
        defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func resetThemeColors(for theme: GlobalThemeId) {
        guard supports(theme) else { return }

        let defaults = UserDefaults.standard
        removeBackgroundImageFile(for: theme)
        removeBackgroundImageFile(for: theme, dark: true)
        for role in ThemeCustomColorRole.allCases {
            (["mode", "gradientStyle", "solid", "imageFile", "darkKind", "darkSolid", "darkGradientStyle", "darkImageFile"]
                + backgroundGradientSuffixes
                + darkBackgroundGradientSuffixes).forEach { suffix in
                defaults.removeObject(forKey: key(theme, role, suffix))
            }
        }
        defaults.removeObject(forKey: selectedPresetKey(theme))
        defaults.removeObject(forKey: selectedDarkPresetKey(theme))

        if theme == .manga {
            for suffix in ["blockA", "blockB", "blockC", "stroke", "settingsIcon"] {
                defaults.removeObject(forKey: mangaKey(suffix))
            }
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func resetLightThemeColors(for theme: GlobalThemeId) {
        guard supports(theme) else { return }

        let defaults = UserDefaults.standard
        removeBackgroundImageFile(for: theme)
        for role in ThemeCustomColorRole.allCases {
            for suffix in ["mode", "gradientStyle", "solid", "imageFile"] + backgroundGradientSuffixes {
                defaults.removeObject(forKey: key(theme, role, suffix))
            }
        }
        defaults.removeObject(forKey: selectedPresetKey(theme))

        if theme == .manga {
            for suffix in ["blockA", "blockB", "blockC", "stroke", "settingsIcon"] {
                defaults.removeObject(forKey: mangaKey(suffix))
            }
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func resetDarkThemeColors(for theme: GlobalThemeId) {
        guard theme == .default else { return }

        let defaults = UserDefaults.standard
        removeBackgroundImageFile(for: theme, dark: true)
        defaults.removeObject(forKey: key(theme, .accent, "darkSolid"))
        (["darkKind", "darkSolid", "darkGradientStyle", "darkImageFile"]
            + darkBackgroundGradientSuffixes).forEach { suffix in
            defaults.removeObject(forKey: key(theme, .background, suffix))
        }
        defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func saveCurrentDarkPreset(
        for theme: GlobalThemeId,
        includingIconSet: Bool = false
    ) {
        guard theme == .default else { return }

        var presets = savedDarkPresets(for: theme)
        let existingNames = Set(presets.map(\.name))
        var nextIndex = presets.count + 1
        while existingNames.contains(L10n.format("theme_custom_profile_name_format", nextIndex)) {
            nextIndex += 1
        }
        presets.append(
            currentDarkPresetSnapshot(
                for: theme,
                name: L10n.format("theme_custom_profile_name_format", nextIndex),
                includingIconSet: includingIconSet
            )
        )

        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: savedDarkPresetsKey(theme))
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func deleteSavedDarkPreset(_ preset: ThemeColorPreset, for theme: GlobalThemeId) {
        guard theme == .default, preset.isCustom else { return }

        let presets = savedDarkPresets(for: theme).filter { $0.id != preset.id }
        let defaults = UserDefaults.standard

        if presets.isEmpty {
            defaults.removeObject(forKey: savedDarkPresetsKey(theme))
        } else if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: savedDarkPresetsKey(theme))
        }
        if defaults.string(forKey: selectedDarkPresetKey(theme)) == preset.id {
            defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    static func currentDarkPresetSnapshot(
        for theme: GlobalThemeId,
        name: String,
        includingIconSet: Bool = false
    ) -> ThemeColorPreset {
        let isGradient = darkBackgroundKind(for: theme) == .gradient
        let backgroundMode: ThemeCustomColorMode = isGradient ? .gradient : .solid
        let solid = darkBackgroundSolidHex(for: theme)
        let backgroundHexes = isGradient
            ? darkBackgroundGradientHexes(for: theme)
            : [solid]

        return ThemeColorPreset(
            id: "custom-\(theme.rawValue)-dark-\(UUID().uuidString)",
            name: name,
            accentStartHex: darkAccentHex(for: theme),
            accentEndHex: darkAccentHex(for: theme),
            backgroundMode: backgroundMode,
            backgroundStartHex: backgroundHexes.first ?? solid,
            backgroundEndHex: backgroundHexes.dropFirst().first ?? solid,
            backgroundHexes: backgroundHexes,
            gradientStyle: darkBackgroundGradientStyle(for: theme),
            iconSetRaw: includingIconSet ? AppInterfaceIconSet.selectedFromDefaults.rawValue : nil,
            isCustom: true
        )
    }

    @MainActor
    static func saveCurrentPreset(for theme: GlobalThemeId, includingIconSet: Bool = false) {
        guard supports(theme) else { return }

        var presets = savedPresets(for: theme)
        let existingNames = Set(presets.map(\.name))
        var nextIndex = presets.count + 1
        while existingNames.contains(L10n.format("theme_custom_profile_name_format", nextIndex)) {
            nextIndex += 1
        }
        presets.append(
            currentPresetSnapshot(
                for: theme,
                name: L10n.format("theme_custom_profile_name_format", nextIndex),
                includingIconSet: includingIconSet
            )
        )

        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: savedPresetsKey(theme))
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func deleteSavedPreset(_ preset: ThemeColorPreset, for theme: GlobalThemeId) {
        guard supports(theme), preset.isCustom else { return }

        let presets = savedPresets(for: theme).filter { $0.id != preset.id }
        let defaults = UserDefaults.standard

        if presets.isEmpty {
            defaults.removeObject(forKey: savedPresetsKey(theme))
        } else if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: savedPresetsKey(theme))
        }
        if defaults.string(forKey: selectedPresetKey(theme)) == preset.id {
            defaults.removeObject(forKey: selectedPresetKey(theme))
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    static func currentPresetSnapshot(for theme: GlobalThemeId, name: String, includingIconSet: Bool = false) -> ThemeColorPreset {
        // 背景图不进入配色方案，按其底色的单色模式快照
        let storedMode = mode(for: theme, role: .background)
        let backgroundMode: ThemeCustomColorMode = storedMode == .image ? .solid : storedMode
        let accentHex = hex(theme, .accent, "solid", fallback: defaultAccentHex(for: theme))
        let backgroundStart: String
        let backgroundEnd: String
        let backgroundHexes: [String]?

        if backgroundMode == .solid {
            let solid = hex(theme, .background, "solid", fallback: defaultBackgroundStartHex(for: theme))
            backgroundStart = solid
            backgroundEnd = solid
            backgroundHexes = [solid]
        } else {
            backgroundStart = hex(theme, .background, "start", fallback: defaultBackgroundStartHex(for: theme))
            backgroundEnd = hex(theme, .background, "end", fallback: defaultBackgroundEndHex(for: theme))
            backgroundHexes = backgroundGradientSuffixes.map { suffix in
                hex(theme, .background, suffix, fallback: defaultBackgroundStopHex(for: theme, suffix: suffix))
            }
        }

        return ThemeColorPreset(
            id: "custom-\(theme.rawValue)-\(UUID().uuidString)",
            name: name,
            accentStartHex: accentHex,
            accentEndHex: accentHex,
            backgroundMode: backgroundMode,
            backgroundStartHex: backgroundStart,
            backgroundEndHex: backgroundEnd,
            backgroundHexes: backgroundHexes,
            gradientStyle: gradientStyle(for: theme, role: .background),
            mangaBlockAHex: theme == .manga ? mangaHex("blockA", fallback: defaultMangaExtraHex("blockA")) : nil,
            mangaBlockBHex: theme == .manga ? mangaHex("blockB", fallback: defaultMangaExtraHex("blockB")) : nil,
            mangaBlockCHex: theme == .manga ? mangaHex("blockC", fallback: defaultMangaExtraHex("blockC")) : nil,
            mangaStrokeHex: theme == .manga ? mangaHex("stroke", fallback: defaultMangaExtraHex("stroke")) : nil,
            mangaSettingsIconHex: theme == .manga ? mangaHex("settingsIcon", fallback: defaultMangaExtraHex("settingsIcon")) : nil,
            iconSetRaw: includingIconSet ? AppInterfaceIconSet.selectedFromDefaults.rawValue : nil,
            isCustom: true
        )
    }
}
