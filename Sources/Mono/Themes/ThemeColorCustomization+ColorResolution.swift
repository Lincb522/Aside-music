import Foundation
import SwiftUI
import UIKit

extension ThemeColorCustomization {
    static func mangaHex(_ suffix: String, fallback: String) -> String {
        let stored = UserDefaults.standard.string(forKey: mangaKey(suffix))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : fallback
    }

    static func storedMangaHex(_ suffix: String) -> String? {
        let stored = UserDefaults.standard.string(forKey: mangaKey(suffix))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored : nil
    }

    static func defaultAccentHex(for theme: GlobalThemeId) -> String {
        switch theme {
        case .minimalWhite: return "18181B"
        case .muji: return "B56B4B"
        case .neumorphic: return "4F8E86"
        case .capsule: return "3867FF"
        case .petWhite: return "F6A93B"
        case .clarity: return "2478D8"
        case .manga: return "FF4F84"
        case .default: return "4D6F95"
        }
    }

    static func defaultBackgroundStartHex(for theme: GlobalThemeId) -> String {
        switch theme {
        case .minimalWhite: return "FFFFFF"
        case .muji: return "F7F1E8"
        case .neumorphic: return "E9EDF0"
        case .capsule: return "F6F8FF"
        case .petWhite: return "FFFFFF"
        case .clarity: return "EEF2F3"
        case .manga: return "F3E9D8"
        case .default: return "F8FAFC"
        }
    }

    static func defaultBackgroundEndHex(for theme: GlobalThemeId) -> String {
        switch theme {
        case .minimalWhite: return "FFFFFF"
        case .muji: return "F7F1E8"
        case .neumorphic: return "F2EEE8"
        case .capsule: return "EAF1FF"
        case .petWhite: return "FFFFFF"
        case .clarity: return "EAF0F2"
        case .manga: return "E8DECD"
        case .default: return "E6EDF6"
        }
    }

    static func defaultBackgroundStopHex(for theme: GlobalThemeId, suffix: String) -> String {
        switch suffix {
        case "start":
            return defaultBackgroundStartHex(for: theme)
        case "end":
            return defaultBackgroundEndHex(for: theme)
        case "stop3":
            switch theme {
            case .minimalWhite: return "FFFFFF"
            case .muji: return "F4EBDD"
            case .neumorphic: return "E4ECE7"
            case .capsule: return "F8F2FF"
            case .petWhite: return "FFF7DE"
            case .clarity: return "F1EAF7"
            case .manga: return "FFF8EB"
            case .default: return "EEF4EE"
            }
        case "stop4":
            switch theme {
            case .minimalWhite: return "FFFFFF"
            case .muji: return "FAF4E8"
            case .neumorphic: return "EEF0F5"
            case .capsule: return "EDF9FF"
            case .petWhite: return "EFFAF5"
            case .clarity: return "E7F5F5"
            case .manga: return "DED3C1"
            case .default: return "F6F1EA"
            }
        default:
            return defaultBackgroundEndHex(for: theme)
        }
    }

    static func defaultMangaExtraHex(_ suffix: String) -> String {
        switch suffix {
        case "blockA": return "DBF400"
        case "blockB": return "124BFF"
        case "blockC": return "FF4B0A"
        case "stroke", "settingsIcon": return "071E34"
        default: return "071E34"
        }
    }

    static func accentColor(for theme: GlobalThemeId, fallback: Color, fallbackHex _: String) -> Color {
        if theme == .default, isDarkAppearanceActive {
            guard let stored = storedHex(theme, .accent, "darkSolid") else { return fallback }
            return Color(hex: stored)
        }

        guard customColorsEnabled else { return fallback }
        guard let stored = storedHex(theme, .accent, "solid") else { return fallback }
        return Color(hex: stored)
    }

    static func accentForegroundColor(for theme: GlobalThemeId, fallbackHex: String? = nil) -> Color {
        let accent = accentColor(
            for: theme,
            fallback: Color(hex: fallbackHex ?? defaultAccentHex(for: theme)),
            fallbackHex: fallbackHex ?? defaultAccentHex(for: theme)
        )

        switch theme {
        case .minimalWhite:
            return readableForegroundColor(on: accent, light: MinimalWhiteStyle.ink, dark: .white)
        case .manga:
            return readableForegroundColor(on: accent, light: Color(hex: "071E34"), dark: Color(hex: "F3E9D8"))
        case .muji:
            return readableForegroundColor(on: accent, light: Color(hex: "211A15"), dark: Color(hex: "FFF8EF"))
        case .neumorphic:
            return readableForegroundColor(on: accent, light: Color(hex: "172026"), dark: .white)
        case .capsule:
            return readableForegroundColor(on: accent, light: Color(hex: "101A2A"), dark: .white)
        case .petWhite:
            return readableForegroundColor(on: accent, light: Color(hex: "111111"), dark: .white)
        case .clarity:
            return readableForegroundColor(on: accent, light: Color(hex: "0D1722"), dark: .white)
        case .default:
            return readableForegroundColor(on: accent, light: Color(hex: "111821"), dark: .white)
        }
    }

    static func accentGradientColors(for theme: GlobalThemeId, fallback: [Color], fallbackHexes: [String]) -> [Color] {
        guard customColorsEnabled else { return fallback }
        let solid = accentColor(for: theme, fallback: fallback.first ?? .accentColor, fallbackHex: fallbackHexes.first ?? "000000")
        return [solid, solid]
    }

    static func backgroundBase(for theme: GlobalThemeId, fallback: Color, fallbackHex _: String) -> Color {
        guard customColorsEnabled else { return fallback }
        let mode = mode(for: theme, role: .background)
        let suffix = mode == .gradient ? "start" : "solid"
        guard let stored = storedHex(theme, .background, suffix) else { return fallback }
        return Color(hex: stored)
    }

    static func backgroundGradientColors(for theme: GlobalThemeId, fallbackHexes: [String]) -> [Color] {
        if theme == .muji {
            let fallback = fallbackHexes.first ?? "F7F1E8"
            guard customColorsEnabled else {
                return [Color(hex: fallback)]
            }
            return [Color(hex: hex(theme, .background, "solid", fallback: fallback))]
        }

        guard customColorsEnabled else {
            return fallbackHexes.map { Color(hex: $0) }
        }

        return configuredBackgroundGradientColors(for: theme, fallbackHexes: fallbackHexes)
    }

    /// Resolves the stored background palette without applying the global
    /// light-appearance gate. Themes that adapt a user's palette into their
    /// own dark material can use this while preserving dark-mode contrast.
    static func configuredBackgroundGradientColors(for theme: GlobalThemeId, fallbackHexes: [String]) -> [Color] {
        let mode = mode(for: theme, role: .background)
        if mode == .solid || mode == .image {
            return [Color(hex: hex(theme, .background, "solid", fallback: fallbackHexes.first ?? "FFFFFF"))]
        }

        return backgroundGradientHexes(for: theme, fallbackHexes: fallbackHexes).map { Color(hex: $0) }
    }

    static func backgroundGradientHexes(for theme: GlobalThemeId, fallbackHexes: [String]) -> [String] {
        let suffixes = hasStoredBackground(for: theme) || fallbackHexes.count > 2
            ? backgroundGradientSuffixes
            : ["start", "end"]
        return suffixes.enumerated().compactMap { index, suffix in
            let fallback = index < fallbackHexes.count ? fallbackHexes[index] : defaultBackgroundStopHex(for: theme, suffix: suffix)
            if let stored = storedHex(theme, .background, suffix) {
                return normalizedHex(stored)
            }
            return normalizedHex(fallback)
        }
    }

    static func mangaExtraColor(suffix: String, lightFallback: String, darkFallback: String) -> Color {
        let light = customColorsEnabled ? mangaHex(suffix, fallback: lightFallback) : lightFallback
        return Color(light: Color(hex: light), dark: Color(hex: darkFallback))
    }

}
