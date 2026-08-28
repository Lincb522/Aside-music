import Foundation
import SwiftUI
import UIKit

extension ThemeColorCustomization {
    static func makeCloudSnapshot() -> CloudThemeCustomizationSnapshot? {
        let entries = GlobalThemeId.allCases.compactMap { theme -> CloudThemeCustomizationEntry? in
            guard supports(theme) else { return nil }

            let currentLight = hasStoredCustomization(for: theme)
                ? stableCloudPreset(
                    currentPresetSnapshot(
                        for: theme,
                        name: String(localized: "common_custom"),
                        includingIconSet: true
                    ),
                    id: "cloud-current-\(theme.rawValue)-light"
                )
                : nil
            let currentDark = theme == .default && hasStoredDarkCustomization(for: theme)
                ? stableCloudPreset(
                    currentDarkPresetSnapshot(
                        for: theme,
                        name: String(localized: "common_custom"),
                        includingIconSet: true
                    ),
                    id: "cloud-current-\(theme.rawValue)-dark"
                )
                : nil

            return CloudThemeCustomizationEntry(
                theme: theme,
                currentLight: currentLight,
                savedLight: savedPresets(for: theme),
                currentDark: currentDark,
                savedDark: savedDarkPresets(for: theme)
            )
        }

        guard entries.contains(where: {
            $0.currentLight != nil
                || !$0.savedLight.isEmpty
                || $0.currentDark != nil
                || !$0.savedDark.isEmpty
        }) else {
            return nil
        }
        return CloudThemeCustomizationSnapshot(entries: entries)
    }

    static func stableCloudPreset(
        _ preset: ThemeColorPreset,
        id: String
    ) -> ThemeColorPreset {
        ThemeColorPreset(
            id: id,
            name: preset.name,
            accentStartHex: preset.accentStartHex,
            accentEndHex: preset.accentEndHex,
            backgroundMode: preset.backgroundMode,
            backgroundStartHex: preset.backgroundStartHex,
            backgroundEndHex: preset.backgroundEndHex,
            backgroundHexes: preset.backgroundHexes,
            gradientStyle: preset.gradientStyle,
            mangaBlockAHex: preset.mangaBlockAHex,
            mangaBlockBHex: preset.mangaBlockBHex,
            mangaBlockCHex: preset.mangaBlockCHex,
            mangaStrokeHex: preset.mangaStrokeHex,
            mangaSettingsIconHex: preset.mangaSettingsIconHex,
            iconSetRaw: preset.iconSetRaw,
            isCustom: true
        )
    }

    @MainActor
    static func restoreCloudSnapshot(
        _ snapshot: CloudThemeCustomizationSnapshot,
        replacingLocal: Bool = false
    ) {
        let defaults = UserDefaults.standard

        for entry in snapshot.entries where supports(entry.theme) {
            let lightPresets = replacingLocal
                ? entry.savedLight
                : mergedCloudPresets(local: savedPresets(for: entry.theme), remote: entry.savedLight)
            if lightPresets.isEmpty {
                defaults.removeObject(forKey: savedPresetsKey(entry.theme))
            } else if let data = try? JSONEncoder().encode(lightPresets) {
                defaults.set(data, forKey: savedPresetsKey(entry.theme))
            }

            if let currentLight = entry.currentLight {
                applyPreset(currentLight, to: entry.theme)
            } else if replacingLocal {
                resetLightThemeColors(for: entry.theme)
            }

            guard entry.theme == .default else { continue }
            let darkPresets = replacingLocal
                ? entry.savedDark
                : mergedCloudPresets(local: savedDarkPresets(for: entry.theme), remote: entry.savedDark)
            if darkPresets.isEmpty {
                defaults.removeObject(forKey: savedDarkPresetsKey(entry.theme))
            } else if let data = try? JSONEncoder().encode(darkPresets) {
                defaults.set(data, forKey: savedDarkPresetsKey(entry.theme))
            }

            if let currentDark = entry.currentDark {
                applyDarkPreset(currentDark, to: entry.theme)
            } else if replacingLocal {
                resetDarkThemeColors(for: entry.theme)
            }
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    static func mergedCloudPresets(
        local: [ThemeColorPreset],
        remote: [ThemeColorPreset]
    ) -> [ThemeColorPreset] {
        var orderedIDs: [String] = []
        var values: [String: ThemeColorPreset] = [:]
        for preset in local + remote {
            if values[preset.id] == nil { orderedIDs.append(preset.id) }
            values[preset.id] = preset
        }
        return orderedIDs.compactMap { values[$0] }
    }

}
