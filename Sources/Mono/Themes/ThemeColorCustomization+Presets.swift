import Foundation
import SwiftUI
import UIKit

extension ThemeColorCustomization {
    static func presets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        builtInPresets(for: theme) + savedPresets(for: theme)
    }

    static func builtInColorPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        builtInPresets(for: theme)
    }

    static func customPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        savedPresets(for: theme)
    }

    static func selectedPreset(for theme: GlobalThemeId) -> ThemeColorPreset? {
        guard hasStoredCustomization(for: theme) else { return nil }

        let allPresets = presets(for: theme)
        if let selectedPresetId = UserDefaults.standard.string(forKey: selectedPresetKey(theme)),
           let selectedPreset = allPresets.first(where: { $0.id == selectedPresetId }),
           isPresetColorMatched(selectedPreset, for: theme)
        {
            return selectedPreset
        }

        return allPresets.first { isPresetColorMatched($0, for: theme) }
    }

    static func selectedPresetDisplayName(for theme: GlobalThemeId) -> String {
        if let preset = selectedPreset(for: theme) {
            return preset.name
        }
        return hasStoredCustomization(for: theme) ? String(localized: "common_custom") : String(localized: "默认配色")
    }

    static func savedPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        guard supports(theme) else { return [] }
        let key = savedPresetsKey(theme)
        return ThemeColorPresetDecodeCache.shared.presets(
            forKey: key,
            data: UserDefaults.standard.data(forKey: key)
        )
    }

    static func builtInDarkColorPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        guard theme == .default else { return [] }
        return builtInDarkPresets
    }

    static func customDarkPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        savedDarkPresets(for: theme)
    }

    static func darkPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        builtInDarkColorPresets(for: theme) + savedDarkPresets(for: theme)
    }

    static func selectedDarkPreset(for theme: GlobalThemeId) -> ThemeColorPreset? {
        guard hasStoredDarkCustomization(for: theme) else { return nil }

        let allPresets = darkPresets(for: theme)
        if let selectedPresetId = UserDefaults.standard.string(forKey: selectedDarkPresetKey(theme)),
           let selectedPreset = allPresets.first(where: { $0.id == selectedPresetId }),
           isDarkPresetColorMatched(selectedPreset, for: theme)
        {
            return selectedPreset
        }

        return allPresets.first { isDarkPresetColorMatched($0, for: theme) }
    }

    static func selectedDarkPresetDisplayName(for theme: GlobalThemeId) -> String {
        if let preset = selectedDarkPreset(for: theme) {
            return preset.name
        }
        return hasStoredDarkCustomization(for: theme)
            ? String(localized: "common_custom")
            : String(localized: "默认配色")
    }

    static func savedDarkPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        guard theme == .default else { return [] }
        let key = savedDarkPresetsKey(theme)
        return ThemeColorPresetDecodeCache.shared.presets(
            forKey: key,
            data: UserDefaults.standard.data(forKey: key)
        )
    }

}

// Compare the stored payload so local edits, deletion, and cloud restore invalidate
// decoded presets through the same path. The key space is limited to theme modes.
private final class ThemeColorPresetDecodeCache: @unchecked Sendable {
    static let shared = ThemeColorPresetDecodeCache()
    private let lock = NSLock()
    private var entries: [String: (data: Data, presets: [ThemeColorPreset])] = [:]

    func presets(forKey key: String, data: Data?) -> [ThemeColorPreset] {
        lock.lock()
        defer { lock.unlock() }
        guard let data else {
            entries.removeValue(forKey: key)
            return []
        }
        if let entry = entries[key], entry.data == data {
            return entry.presets
        }
        let presets = (try? JSONDecoder().decode([ThemeColorPreset].self, from: data)) ?? []
        entries[key] = (data, presets)
        return presets
    }
}
