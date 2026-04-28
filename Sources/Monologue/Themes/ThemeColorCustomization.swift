import Foundation
import SwiftUI

private struct ThemeCustomizationRevisionKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var themeCustomizationRevision: Int {
        get { self[ThemeCustomizationRevisionKey.self] }
        set { self[ThemeCustomizationRevisionKey.self] = newValue }
    }
}

enum ThemeCustomColorRole: String, CaseIterable, Identifiable {
    case accent
    case background

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .accent: return String(localized: "强调色")
        case .background: return String(localized: "背景色")
        }
    }
}

enum ThemeCustomColorMode: String, CaseIterable, Identifiable, Codable {
    case solid
    case gradient

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .solid: return String(localized: "单色")
        case .gradient: return String(localized: "渐变")
        }
    }
}

enum ThemeCustomGradientStyle: String, CaseIterable, Identifiable, Codable {
    case diffuse
    case diagonal
    case vertical
    case radial

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .diffuse: return String(localized: "弥散")
        case .diagonal: return String(localized: "斜向")
        case .vertical: return String(localized: "纵向")
        case .radial: return String(localized: "中心")
        }
    }

    var points: (start: UnitPoint, end: UnitPoint) {
        switch self {
        case .diffuse, .diagonal: return (.topLeading, .bottomTrailing)
        case .vertical: return (.top, .bottom)
        case .radial: return (.topTrailing, .bottomLeading)
        }
    }
}

struct ThemeColorPreset: Identifiable, Codable {
    let id: String
    let name: String
    let accentStartHex: String
    let accentEndHex: String
    let backgroundMode: ThemeCustomColorMode?
    let backgroundStartHex: String
    let backgroundEndHex: String
    let gradientStyle: ThemeCustomGradientStyle
    let mangaBlockAHex: String?
    let mangaBlockBHex: String?
    let mangaBlockCHex: String?
    let mangaStrokeHex: String?
    let mangaSettingsIconHex: String?
    let isCustom: Bool

    init(
        id: String,
        name: String,
        accentStartHex: String,
        accentEndHex: String,
        backgroundMode: ThemeCustomColorMode? = nil,
        backgroundStartHex: String,
        backgroundEndHex: String,
        gradientStyle: ThemeCustomGradientStyle = .diffuse,
        mangaBlockAHex: String? = nil,
        mangaBlockBHex: String? = nil,
        mangaBlockCHex: String? = nil,
        mangaStrokeHex: String? = nil,
        mangaSettingsIconHex: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.accentStartHex = accentStartHex
        self.accentEndHex = accentEndHex
        self.backgroundMode = backgroundMode
        self.backgroundStartHex = backgroundStartHex
        self.backgroundEndHex = backgroundEndHex
        self.gradientStyle = gradientStyle
        self.mangaBlockAHex = mangaBlockAHex
        self.mangaBlockBHex = mangaBlockBHex
        self.mangaBlockCHex = mangaBlockCHex
        self.mangaStrokeHex = mangaStrokeHex
        self.mangaSettingsIconHex = mangaSettingsIconHex
        self.isCustom = isCustom
    }
}

enum ThemeColorCustomization {
    static var customColorsEnabled: Bool {
        switch UserDefaults.standard.string(forKey: "themeMode") {
        case "dark":
            return false
        case "light":
            return true
        default:
            #if os(iOS)
                return UIScreen.main.traitCollection.userInterfaceStyle != .dark
            #else
                return true
            #endif
        }
    }

    static func supports(_ theme: GlobalThemeId) -> Bool {
        theme == .default || theme == .muji || theme == .manga || theme == .neumorphic
    }

    static func key(_ theme: GlobalThemeId, _ role: ThemeCustomColorRole, _ suffix: String) -> String {
        "themeColor.\(theme.rawValue).\(role.rawValue).\(suffix)"
    }

    static func mangaKey(_ suffix: String) -> String {
        "themeColor.manga.extra.\(suffix)"
    }

    static func savedPresetsKey(_ theme: GlobalThemeId) -> String {
        "themeColor.\(theme.rawValue).savedPresets"
    }

    static func mode(for theme: GlobalThemeId, role: ThemeCustomColorRole) -> ThemeCustomColorMode {
        if role == .accent || (theme == .muji && role == .background) {
            return .solid
        }

        let raw = UserDefaults.standard.string(forKey: key(theme, role, "mode"))
        return ThemeCustomColorMode(rawValue: raw ?? ThemeCustomColorMode.gradient.rawValue) ?? .gradient
    }

    static func gradientStyle(for theme: GlobalThemeId, role: ThemeCustomColorRole) -> ThemeCustomGradientStyle {
        let raw = UserDefaults.standard.string(forKey: key(theme, role, "gradientStyle"))
        return ThemeCustomGradientStyle(rawValue: raw ?? ThemeCustomGradientStyle.diffuse.rawValue) ?? .diffuse
    }

    static func hex(_ theme: GlobalThemeId, _ role: ThemeCustomColorRole, _ suffix: String, fallback: String) -> String {
        let stored = UserDefaults.standard.string(forKey: key(theme, role, suffix))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : fallback
    }

    static func storedHex(_ theme: GlobalThemeId, _ role: ThemeCustomColorRole, _ suffix: String) -> String? {
        let stored = UserDefaults.standard.string(forKey: key(theme, role, suffix))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored : nil
    }

    static func hasStoredAccent(for theme: GlobalThemeId) -> Bool {
        storedHex(theme, .accent, "solid") != nil
    }

    static func hasStoredBackground(for theme: GlobalThemeId) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: key(theme, .background, "mode")) != nil
            || defaults.string(forKey: key(theme, .background, "gradientStyle")) != nil
            || storedHex(theme, .background, "solid") != nil
            || storedHex(theme, .background, "start") != nil
            || storedHex(theme, .background, "end") != nil
    }

    static func usesCustomBackground(for theme: GlobalThemeId) -> Bool {
        customColorsEnabled && hasStoredBackground(for: theme)
    }

    static func mangaHex(_ suffix: String, fallback: String) -> String {
        let stored = UserDefaults.standard.string(forKey: mangaKey(suffix))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : fallback
    }

    static func defaultAccentHex(for theme: GlobalThemeId) -> String {
        switch theme {
        case .muji: return "B56B4B"
        case .neumorphic: return "4F8E86"
        case .manga: return "FF4F84"
        case .default: return "4D6F95"
        }
    }

    static func defaultBackgroundStartHex(for theme: GlobalThemeId) -> String {
        switch theme {
        case .muji: return "F7F1E8"
        case .neumorphic: return "E9EDF0"
        case .manga: return "FFF3D7"
        case .default: return "F8FAFC"
        }
    }

    static func defaultBackgroundEndHex(for theme: GlobalThemeId) -> String {
        switch theme {
        case .muji: return "F7F1E8"
        case .neumorphic: return "F2EEE8"
        case .manga: return "E8F1FF"
        case .default: return "E6EDF6"
        }
    }

    static func defaultMangaExtraHex(_ suffix: String) -> String {
        switch suffix {
        case "blockA": return "FFE067"
        case "blockB": return "58B9FF"
        case "blockC": return "8DE4B8"
        case "stroke", "settingsIcon": return "17151F"
        default: return "17151F"
        }
    }

    static func accentColor(for theme: GlobalThemeId, fallback: Color, fallbackHex _: String) -> Color {
        guard customColorsEnabled else { return fallback }
        guard let stored = storedHex(theme, .accent, "solid") else { return fallback }
        return Color(hex: stored)
    }

    static func accentGradientColors(for theme: GlobalThemeId, fallback: [Color], fallbackHexes: [String]) -> [Color] {
        guard customColorsEnabled else { return fallback }
        let solid = accentColor(for: theme, fallback: fallback.first ?? .accentColor, fallbackHex: fallbackHexes.first ?? "000000")
        return [solid, solid]
    }

    static func backgroundBase(for theme: GlobalThemeId, fallback: Color, fallbackHex _: String) -> Color {
        guard customColorsEnabled else { return fallback }
        let mode = mode(for: theme, role: .background)
        let suffix = mode == .solid ? "solid" : "start"
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
        let mode = mode(for: theme, role: .background)
        if mode == .solid {
            return [Color(hex: hex(theme, .background, "solid", fallback: fallbackHexes.first ?? "FFFFFF"))]
        }

        let first = hex(theme, .background, "start", fallback: fallbackHexes.first ?? "FFFFFF")
        let second = hex(theme, .background, "end", fallback: fallbackHexes.dropFirst().first ?? first)
        return [Color(hex: first), Color(hex: second)]
    }

    static func mangaExtraColor(suffix: String, lightFallback: String, darkFallback: String) -> Color {
        let light = customColorsEnabled ? mangaHex(suffix, fallback: lightFallback) : lightFallback
        return Color(light: Color(hex: light), dark: Color(hex: darkFallback))
    }

    static func presets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        builtInPresets(for: theme) + savedPresets(for: theme)
    }

    static func savedPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        guard supports(theme),
              let data = UserDefaults.standard.data(forKey: savedPresetsKey(theme)),
              let presets = try? JSONDecoder().decode([ThemeColorPreset].self, from: data)
        else {
            return []
        }
        return presets
    }

    private static func builtInPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        switch theme {
        case .muji:
            return [
                ThemeColorPreset(id: "muji-linen", name: "Linen", accentStartHex: "B56B4B", accentEndHex: "B56B4B", backgroundStartHex: "F7F1E8", backgroundEndHex: "F7F1E8"),
                ThemeColorPreset(id: "muji-tea", name: "Tea", accentStartHex: "78846B", accentEndHex: "78846B", backgroundStartHex: "F3EEE3", backgroundEndHex: "F3EEE3"),
                ThemeColorPreset(id: "muji-clay", name: "Clay", accentStartHex: "B96D55", accentEndHex: "B96D55", backgroundStartHex: "F4E8DC", backgroundEndHex: "F4E8DC"),
                ThemeColorPreset(id: "muji-rice", name: "Rice", accentStartHex: "9C7A53", accentEndHex: "9C7A53", backgroundStartHex: "FAF4E8", backgroundEndHex: "FAF4E8"),
                ThemeColorPreset(id: "muji-olive", name: "Olive", accentStartHex: "6F8064", accentEndHex: "6F8064", backgroundStartHex: "F1EFE4", backgroundEndHex: "F1EFE4"),
                ThemeColorPreset(id: "muji-indigo", name: "Indigo", accentStartHex: "56677A", accentEndHex: "56677A", backgroundStartHex: "F1F0EA", backgroundEndHex: "F1F0EA"),
            ]
        case .neumorphic:
            return [
                ThemeColorPreset(id: "neu-mint", name: "Soft Mint", accentStartHex: "4F8E86", accentEndHex: "7D9475", backgroundStartHex: "E9EDF0", backgroundEndHex: "F2EEE8"),
                ThemeColorPreset(id: "neu-dawn", name: "Dawn", accentStartHex: "C59A66", accentEndHex: "C65A58", backgroundStartHex: "EEE8E1", backgroundEndHex: "E7EDF0", gradientStyle: .diagonal),
                ThemeColorPreset(id: "neu-blue", name: "Quiet Blue", accentStartHex: "5E7FA4", accentEndHex: "7AB9B0", backgroundStartHex: "E8EDF4", backgroundEndHex: "F0F2F4", gradientStyle: .radial),
                ThemeColorPreset(id: "neu-sage", name: "Sage", accentStartHex: "6E8B70", accentEndHex: "96A874", backgroundStartHex: "E8EDE7", backgroundEndHex: "F4F0E8", gradientStyle: .diffuse),
                ThemeColorPreset(id: "neu-apricot", name: "Apricot", accentStartHex: "C27B5E", accentEndHex: "C8A361", backgroundStartHex: "F0E8DF", backgroundEndHex: "EDF1EC", gradientStyle: .vertical),
                ThemeColorPreset(id: "neu-lake", name: "Lake", accentStartHex: "4E8196", accentEndHex: "72A69B", backgroundStartHex: "E6EEF2", backgroundEndHex: "F2F0EA", gradientStyle: .diagonal),
            ]
        case .manga:
            return [
                ThemeColorPreset(id: "manga-pop", name: "Pop", accentStartHex: "FF4F84", accentEndHex: "FF4F84", backgroundStartHex: "FFF3D7", backgroundEndHex: "E8F1FF", mangaBlockAHex: "FFE067", mangaBlockBHex: "58B9FF", mangaBlockCHex: "8DE4B8", mangaStrokeHex: "3B3145", mangaSettingsIconHex: "17151F"),
                ThemeColorPreset(id: "manga-berry", name: "Berry", accentStartHex: "E65E8E", accentEndHex: "E65E8E", backgroundStartHex: "FFEAF0", backgroundEndHex: "F6F0FF", gradientStyle: .radial, mangaBlockAHex: "FFB4D2", mangaBlockBHex: "B391FF", mangaBlockCHex: "FFE7A3", mangaStrokeHex: "4B3A55", mangaSettingsIconHex: "2B2030"),
                ThemeColorPreset(id: "manga-soda", name: "Soda", accentStartHex: "4FA9FF", accentEndHex: "4FA9FF", backgroundStartHex: "EEF7FF", backgroundEndHex: "FFF1D8", gradientStyle: .diffuse, mangaBlockAHex: "70D7FF", mangaBlockBHex: "FFE36D", mangaBlockCHex: "FF9C7E", mangaStrokeHex: "344B5E", mangaSettingsIconHex: "172C3A"),
                ThemeColorPreset(id: "manga-peach", name: "Peach", accentStartHex: "FF7A6E", accentEndHex: "FF7A6E", backgroundStartHex: "FFF0DF", backgroundEndHex: "FFE9F1", gradientStyle: .vertical, mangaBlockAHex: "FFBC8D", mangaBlockBHex: "C7A7FF", mangaBlockCHex: "93D9B4", mangaStrokeHex: "5C4052", mangaSettingsIconHex: "2F222A"),
                ThemeColorPreset(id: "manga-lime", name: "Lime", accentStartHex: "7FBF5B", accentEndHex: "7FBF5B", backgroundStartHex: "F7F6D9", backgroundEndHex: "EAF7EC", gradientStyle: .diagonal, mangaBlockAHex: "B8E76F", mangaBlockBHex: "FFE890", mangaBlockCHex: "5ECFA6", mangaStrokeHex: "465F4D", mangaSettingsIconHex: "203428"),
                ThemeColorPreset(id: "manga-candy", name: "Candy", accentStartHex: "F06DA6", accentEndHex: "F06DA6", backgroundStartHex: "FFF0FA", backgroundEndHex: "EAF6FF", gradientStyle: .radial, mangaBlockAHex: "FFA6D9", mangaBlockBHex: "8FE7E1", mangaBlockCHex: "C9A8FF", mangaStrokeHex: "694E67", mangaSettingsIconHex: "302039"),
            ]
        case .default:
            return [
                ThemeColorPreset(id: "default-mist", name: "Mist", accentStartHex: "4D6F95", accentEndHex: "4D6F95", backgroundStartHex: "F8FAFC", backgroundEndHex: "E6EDF6", gradientStyle: .diffuse),
                ThemeColorPreset(id: "default-dawn", name: "Dawn", accentStartHex: "B66E57", accentEndHex: "B66E57", backgroundStartHex: "FFF6EB", backgroundEndHex: "EAF0FA", gradientStyle: .diagonal),
                ThemeColorPreset(id: "default-lake", name: "Lake", accentStartHex: "4D8196", accentEndHex: "4D8196", backgroundStartHex: "EEF6FA", backgroundEndHex: "E9F2EC", gradientStyle: .radial),
                ThemeColorPreset(id: "default-sage", name: "Sage", accentStartHex: "6A8368", accentEndHex: "6A8368", backgroundStartHex: "F5F7EF", backgroundEndHex: "E8EFE7", gradientStyle: .diffuse),
                ThemeColorPreset(id: "default-iris", name: "Iris", accentStartHex: "6E72A7", accentEndHex: "6E72A7", backgroundStartHex: "F6F4FB", backgroundEndHex: "E9EEF8", gradientStyle: .vertical),
                ThemeColorPreset(id: "default-clay", name: "Clay", accentStartHex: "9F7559", accentEndHex: "9F7559", backgroundStartHex: "F8F1EA", backgroundEndHex: "EAF0F3", gradientStyle: .diagonal),
            ]
        }
    }

    static func isPresetSelected(_ preset: ThemeColorPreset, for theme: GlobalThemeId) -> Bool {
        guard supports(theme) else { return false }
        guard mode(for: theme, role: .accent) == .solid else { return false }
        if theme == .default {
            guard hasStoredAccent(for: theme), hasStoredBackground(for: theme) else { return false }
        }

        let presetBackgroundMode = preset.backgroundMode ?? (theme == .muji ? .solid : .gradient)
        guard mode(for: theme, role: .background) == presetBackgroundMode else { return false }

        if presetBackgroundMode == .gradient {
            guard gradientStyle(for: theme, role: .background) == preset.gradientStyle else { return false }
        }

        let accentSolid = hex(theme, .accent, "solid", fallback: preset.accentStartHex)
        let backgroundStart = hex(theme, .background, "start", fallback: preset.backgroundStartHex)
        let backgroundEnd = hex(theme, .background, "end", fallback: preset.backgroundEndHex)
        let backgroundSolid = hex(theme, .background, "solid", fallback: preset.backgroundStartHex)

        guard normalizedHex(accentSolid) == normalizedHex(preset.accentStartHex)
        else {
            return false
        }

        if presetBackgroundMode == .solid {
            guard normalizedHex(backgroundSolid) == normalizedHex(preset.backgroundStartHex) else { return false }
        } else {
            guard normalizedHex(backgroundStart) == normalizedHex(preset.backgroundStartHex),
                  normalizedHex(backgroundEnd) == normalizedHex(preset.backgroundEndHex)
            else {
                return false
            }
        }

        guard theme == .manga else { return true }

        if let value = preset.mangaBlockAHex, normalizedHex(mangaHex("blockA", fallback: value)) != normalizedHex(value) { return false }
        if let value = preset.mangaBlockBHex, normalizedHex(mangaHex("blockB", fallback: value)) != normalizedHex(value) { return false }
        if let value = preset.mangaBlockCHex, normalizedHex(mangaHex("blockC", fallback: value)) != normalizedHex(value) { return false }
        if let value = preset.mangaStrokeHex, normalizedHex(mangaHex("stroke", fallback: value)) != normalizedHex(value) { return false }
        if let value = preset.mangaSettingsIconHex, normalizedHex(mangaHex("settingsIcon", fallback: value)) != normalizedHex(value) { return false }

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
        defaults.set(preset.backgroundStartHex, forKey: key(theme, .background, "start"))
        defaults.set(preset.backgroundEndHex, forKey: key(theme, .background, "end"))
        defaults.set(preset.backgroundStartHex, forKey: key(theme, .background, "solid"))
        defaults.set(preset.gradientStyle.rawValue, forKey: key(theme, .background, "gradientStyle"))

        if theme == .manga {
            if let value = preset.mangaBlockAHex { defaults.set(value, forKey: mangaKey("blockA")) }
            if let value = preset.mangaBlockBHex { defaults.set(value, forKey: mangaKey("blockB")) }
            if let value = preset.mangaBlockCHex { defaults.set(value, forKey: mangaKey("blockC")) }
            if let value = preset.mangaStrokeHex { defaults.set(value, forKey: mangaKey("stroke")) }
            if let value = preset.mangaSettingsIconHex { defaults.set(value, forKey: mangaKey("settingsIcon")) }
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func resetBackground(for theme: GlobalThemeId) {
        let defaults = UserDefaults.standard
        ["mode", "gradientStyle", "solid", "start", "end"].forEach { suffix in
            defaults.removeObject(forKey: key(theme, .background, suffix))
        }
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    static func saveCurrentPreset(for theme: GlobalThemeId) {
        guard supports(theme) else { return }

        var presets = savedPresets(for: theme)
        let nextIndex = presets.count + 1
        presets.append(currentPresetSnapshot(for: theme, name: String(localized: "方案 \(nextIndex)")))

        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: savedPresetsKey(theme))
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    static func currentPresetSnapshot(for theme: GlobalThemeId, name: String) -> ThemeColorPreset {
        let backgroundMode = mode(for: theme, role: .background)
        let accentHex = hex(theme, .accent, "solid", fallback: defaultAccentHex(for: theme))
        let backgroundStart: String
        let backgroundEnd: String

        if backgroundMode == .solid {
            let solid = hex(theme, .background, "solid", fallback: defaultBackgroundStartHex(for: theme))
            backgroundStart = solid
            backgroundEnd = solid
        } else {
            backgroundStart = hex(theme, .background, "start", fallback: defaultBackgroundStartHex(for: theme))
            backgroundEnd = hex(theme, .background, "end", fallback: defaultBackgroundEndHex(for: theme))
        }

        return ThemeColorPreset(
            id: "custom-\(theme.rawValue)-\(UUID().uuidString)",
            name: name,
            accentStartHex: accentHex,
            accentEndHex: accentHex,
            backgroundMode: backgroundMode,
            backgroundStartHex: backgroundStart,
            backgroundEndHex: backgroundEnd,
            gradientStyle: gradientStyle(for: theme, role: .background),
            mangaBlockAHex: theme == .manga ? mangaHex("blockA", fallback: defaultMangaExtraHex("blockA")) : nil,
            mangaBlockBHex: theme == .manga ? mangaHex("blockB", fallback: defaultMangaExtraHex("blockB")) : nil,
            mangaBlockCHex: theme == .manga ? mangaHex("blockC", fallback: defaultMangaExtraHex("blockC")) : nil,
            mangaStrokeHex: theme == .manga ? mangaHex("stroke", fallback: defaultMangaExtraHex("stroke")) : nil,
            mangaSettingsIconHex: theme == .manga ? mangaHex("settingsIcon", fallback: defaultMangaExtraHex("settingsIcon")) : nil,
            isCustom: true
        )
    }
}

struct ThemeCustomDiffuseBackground: View {
    let theme: GlobalThemeId
    let fallbackHexes: [String]
    var accentFallbackHexes: [String] = []
    var opacity: Double = 1

    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        let colors = ThemeColorCustomization.backgroundGradientColors(for: theme, fallbackHexes: fallbackHexes)
        let accentColors = ThemeColorCustomization.accentGradientColors(
            for: theme,
            fallback: accentFallbackHexes.map { Color(hex: $0) },
            fallbackHexes: accentFallbackHexes
        )
        let style = ThemeColorCustomization.gradientStyle(for: theme, role: .background)
        let points = style.points

        GeometryReader { proxy in
            ZStack {
                baseLayer(colors: colors, style: style, size: proxy.size, points: points)

                if theme != .muji {
                    accentLayer(colors: colors, accentColors: accentColors, style: style, size: proxy.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func baseLayer(colors: [Color], style: ThemeCustomGradientStyle, size: CGSize, points: (start: UnitPoint, end: UnitPoint)) -> some View {
        if colors.count == 1 {
            colors[0]
        } else if style == .radial {
            RadialGradient(
                colors: colors,
                center: .center,
                startRadius: max(size.width, size.height) * 0.04,
                endRadius: max(size.width, size.height) * 0.78
            )
        } else {
            LinearGradient(colors: colors, startPoint: points.start, endPoint: points.end)
        }
    }

    @ViewBuilder
    private func accentLayer(colors: [Color], accentColors: [Color], style: ThemeCustomGradientStyle, size: CGSize) -> some View {
        let firstAccent = accentColors.first ?? colors.first ?? .clear
        let secondAccent = accentColors.dropFirst().first ?? colors.last ?? firstAccent
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        Group {
            if style == .diffuse {
                Canvas(rendersAsynchronously: true) { context, _ in
                    drawGlow(context, center: CGPoint(x: width * 0.16, y: height * 0.12), radius: width * 0.58, color: firstAccent, opacity: 0.18 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.88, y: height * 0.36), radius: width * 0.52, color: secondAccent, opacity: 0.14 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.42, y: height * 0.86), radius: width * 0.62, color: colors.last ?? secondAccent, opacity: 0.12 * opacity)
                }
                .blur(radius: 44)
                .blendMode(.softLight)
            } else {
                LinearGradient(
                    colors: [
                        firstAccent.opacity(0.15 * opacity),
                        .clear,
                        secondAccent.opacity((style == .radial ? 0.2 : 0.12) * opacity),
                    ],
                    startPoint: style == .vertical ? .top : .topLeading,
                    endPoint: style == .vertical ? .bottom : .bottomTrailing
                )
                .blendMode(.softLight)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private func drawGlow(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), color.opacity(0)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}
