import Foundation
import SwiftUI
import UIKit

struct ThemeCustomizationRevisionKey: EnvironmentKey {
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

/// 默认主题夜间模式的背景类型（与浅色自定义背景相互独立）
enum ThemeDarkBackgroundKind: String, CaseIterable, Identifiable {
    case standard
    case solid
    case gradient
    case image

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .standard: return String(localized: "默认")
        case .solid: return String(localized: "纯色")
        case .gradient: return String(localized: "渐变")
        case .image: return String(localized: "背景图")
        }
    }
}

enum ThemeCustomColorMode: String, CaseIterable, Identifiable, Codable {
    case solid
    case gradient
    case image

    /// 「背景图」仅默认主题的背景角色开放，不进入通用模式列表。
    static var allCases: [ThemeCustomColorMode] {
        [.solid, .gradient]
    }

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .solid: return String(localized: "单色")
        case .gradient: return String(localized: "渐变")
        case .image: return String(localized: "背景图")
        }
    }
}

enum ThemeCustomGradientStyle: String, CaseIterable, Identifiable, Codable {
    case linear
    case radial
    case conic
    case mesh
    case diffuse
    // Legacy values kept for saved user data from earlier builds.
    case diagonal
    case vertical

    static var allCases: [ThemeCustomGradientStyle] {
        [.linear, .radial, .conic, .mesh, .diffuse]
    }

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .linear, .diagonal, .vertical:
            return String(localized: "线性渐变")
        case .radial:
            return String(localized: "径向渐变")
        case .conic:
            return String(localized: "锥形（角度）渐变")
        case .mesh:
            return String(localized: "Mesh 渐变")
        case .diffuse:
            return String(localized: "弥散渐变")
        }
    }

    var normalized: ThemeCustomGradientStyle {
        switch self {
        case .diagonal, .vertical:
            return .linear
        default:
            return self
        }
    }

    var points: (start: UnitPoint, end: UnitPoint) {
        switch self {
        case .diffuse, .linear, .diagonal, .mesh, .conic: return (.topLeading, .bottomTrailing)
        case .vertical: return (.top, .bottom)
        case .radial: return (.topTrailing, .bottomLeading)
        }
    }
}

/// 一套可持久化的主题配色方案，包含通用渐变、主题专用颜色与可选图标包。
struct ThemeColorPreset: Identifiable, Codable {
    let id: String
    let name: String
    let accentStartHex: String
    let accentEndHex: String
    let backgroundMode: ThemeCustomColorMode?
    let backgroundStartHex: String
    let backgroundEndHex: String
    let backgroundHexes: [String]?
    let gradientStyle: ThemeCustomGradientStyle
    let mangaBlockAHex: String?
    let mangaBlockBHex: String?
    let mangaBlockCHex: String?
    let mangaStrokeHex: String?
    let mangaSettingsIconHex: String?
    /// 保存方案时一并记录的界面图标包（可选，旧数据为 nil）。
    let iconSetRaw: String?
    let isCustom: Bool

    init(
        id: String,
        name: String,
        accentStartHex: String,
        accentEndHex: String,
        backgroundMode: ThemeCustomColorMode? = nil,
        backgroundStartHex: String,
        backgroundEndHex: String,
        backgroundHexes: [String]? = nil,
        gradientStyle: ThemeCustomGradientStyle = .diffuse,
        mangaBlockAHex: String? = nil,
        mangaBlockBHex: String? = nil,
        mangaBlockCHex: String? = nil,
        mangaStrokeHex: String? = nil,
        mangaSettingsIconHex: String? = nil,
        iconSetRaw: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.accentStartHex = accentStartHex
        self.accentEndHex = accentEndHex
        self.backgroundMode = backgroundMode
        self.backgroundStartHex = backgroundStartHex
        self.backgroundEndHex = backgroundEndHex
        self.backgroundHexes = backgroundHexes
        self.gradientStyle = gradientStyle
        self.mangaBlockAHex = mangaBlockAHex
        self.mangaBlockBHex = mangaBlockBHex
        self.mangaBlockCHex = mangaBlockCHex
        self.mangaStrokeHex = mangaStrokeHex
        self.mangaSettingsIconHex = mangaSettingsIconHex
        self.iconSetRaw = iconSetRaw
        self.isCustom = isCustom
    }

    var backgroundPaletteHexes: [String] {
        let palette = backgroundHexes?
            .map { ThemeColorCustomization.normalizedHex($0) }
            .filter { !$0.isEmpty } ?? []
        return palette.isEmpty ? [backgroundStartHex, backgroundEndHex] : palette
    }
}

enum ThemeColorCustomization {
    static var isDarkAppearanceActive: Bool {
        !customColorsEnabled
    }

    static var customColorsEnabled: Bool {
        switch UserDefaults.standard.string(forKey: "themeMode") {
        case "dark":
            return false
        case "light":
            return true
        default:
            return UserDefaults.standard.string(forKey: "themeResolvedColorScheme") != "dark"
        }
    }

    static func supports(_ theme: GlobalThemeId) -> Bool {
        theme.supportsColorCustomization
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

    static func selectedPresetKey(_ theme: GlobalThemeId) -> String {
        "themeColor.\(theme.rawValue).selectedPreset"
    }

    static func savedDarkPresetsKey(_ theme: GlobalThemeId) -> String {
        "themeColor.\(theme.rawValue).savedDarkPresets"
    }

    static func selectedDarkPresetKey(_ theme: GlobalThemeId) -> String {
        "themeColor.\(theme.rawValue).selectedDarkPreset"
    }

    static let backgroundGradientSuffixes = ["start", "end", "stop3", "stop4"]
    static let darkBackgroundGradientSuffixes = ["darkStart", "darkEnd", "darkStop3", "darkStop4"]
    static let defaultCatPawPresetId = "default-cat-paw"

    static func usesDefaultCatPawPreset() -> Bool {
        selectedPreset(for: .default)?.id == defaultCatPawPresetId
    }

    static func mode(for theme: GlobalThemeId, role: ThemeCustomColorRole) -> ThemeCustomColorMode {
        if role == .accent || (theme == .muji && role == .background) {
            return .solid
        }

        let raw = UserDefaults.standard.string(forKey: key(theme, role, "mode"))
        let mode = ThemeCustomColorMode(rawValue: raw ?? ThemeCustomColorMode.gradient.rawValue) ?? .gradient
        if mode == .image && !supportsImageBackground(theme) {
            return .gradient
        }
        return mode
    }

    static func gradientStyle(for theme: GlobalThemeId, role: ThemeCustomColorRole) -> ThemeCustomGradientStyle {
        let raw = UserDefaults.standard.string(forKey: key(theme, role, "gradientStyle"))
        return (ThemeCustomGradientStyle(rawValue: raw ?? ThemeCustomGradientStyle.diffuse.rawValue) ?? .diffuse).normalized
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

    static func hasStoredDarkAccent(for theme: GlobalThemeId) -> Bool {
        storedHex(theme, .accent, "darkSolid") != nil
    }

    static func hasStoredBackground(for theme: GlobalThemeId) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: key(theme, .background, "mode")) != nil
            || defaults.string(forKey: key(theme, .background, "gradientStyle")) != nil
            || storedHex(theme, .background, "solid") != nil
            || backgroundGradientSuffixes.contains { storedHex(theme, .background, $0) != nil }
    }

    static func hasStoredCustomization(for theme: GlobalThemeId) -> Bool {
        guard supports(theme) else { return false }

        let defaults = UserDefaults.standard
        let hasRoleCustomization = ThemeCustomColorRole.allCases.contains { role in
            (["mode", "gradientStyle", "solid"] + backgroundGradientSuffixes).contains { suffix in
                defaults.object(forKey: key(theme, role, suffix)) != nil
            }
        }

        if hasRoleCustomization {
            return true
        }

        guard theme == .manga else { return false }
        return ["blockA", "blockB", "blockC", "stroke", "settingsIcon"].contains { suffix in
            defaults.object(forKey: mangaKey(suffix)) != nil
        }
    }

    static func hasStoredDarkCustomization(for theme: GlobalThemeId) -> Bool {
        guard theme == .default else { return false }

        let defaults = UserDefaults.standard
        return hasStoredDarkAccent(for: theme)
            || defaults.object(forKey: key(theme, .background, "darkKind")) != nil
            || defaults.object(forKey: key(theme, .background, "darkSolid")) != nil
            || defaults.object(forKey: key(theme, .background, "darkGradientStyle")) != nil
            || defaults.object(forKey: key(theme, .background, "darkImageFile")) != nil
            || darkBackgroundGradientSuffixes.contains { suffix in
                defaults.object(forKey: key(theme, .background, suffix)) != nil
            }
    }

    static func usesCustomBackground(for theme: GlobalThemeId) -> Bool {
        customColorsEnabled && hasStoredBackground(for: theme)
    }

    @MainActor
    static var backgroundImageCache: [String: UIImage] = [:]
    @MainActor
    static var didRegisterMemoryResource = false

    static let defaultDarkAccentHex = "FFFFFF"
    static let defaultDarkBackgroundSolidHex = "000000"

    static let builtInDarkPresets: [ThemeColorPreset] = [
        ThemeColorPreset(
            id: "default-dark-graphite",
            name: "Graphite",
            accentStartHex: "F4F4F5",
            accentEndHex: "F4F4F5",
            backgroundMode: .solid,
            backgroundStartHex: "0A0B0E",
            backgroundEndHex: "0A0B0E",
            backgroundHexes: ["0A0B0E"]
        ),
        ThemeColorPreset(
            id: "default-dark-cobalt",
            name: "Cobalt",
            accentStartHex: "82A8FF",
            accentEndHex: "82A8FF",
            backgroundMode: .gradient,
            backgroundStartHex: "080B16",
            backgroundEndHex: "101B38",
            backgroundHexes: ["080B16", "101B38", "0B1327", "080A10"],
            gradientStyle: .linear
        ),
        ThemeColorPreset(
            id: "default-dark-aubergine",
            name: "Aubergine",
            accentStartHex: "D295F7",
            accentEndHex: "D295F7",
            backgroundMode: .gradient,
            backgroundStartHex: "0E0A14",
            backgroundEndHex: "24102B",
            backgroundHexes: ["0E0A14", "24102B", "151022", "09080D"],
            gradientStyle: .radial
        ),
        ThemeColorPreset(
            id: "default-dark-deep-sea",
            name: "Deep Sea",
            accentStartHex: "63D5D0",
            accentEndHex: "63D5D0",
            backgroundMode: .gradient,
            backgroundStartHex: "061013",
            backgroundEndHex: "08272B",
            backgroundHexes: ["061013", "08272B", "0B1B27", "05090C"],
            gradientStyle: .diffuse
        ),
        ThemeColorPreset(
            id: "default-dark-ember",
            name: "Ember",
            accentStartHex: "FF927A",
            accentEndHex: "FF927A",
            backgroundMode: .gradient,
            backgroundStartHex: "130A08",
            backgroundEndHex: "341711",
            backgroundHexes: ["130A08", "341711", "1E0D12", "09090B"],
            gradientStyle: .conic
        ),
        ThemeColorPreset(
            id: "default-dark-forest",
            name: "Forest",
            accentStartHex: "7DD6A7",
            accentEndHex: "7DD6A7",
            backgroundMode: .gradient,
            backgroundStartHex: "07100C",
            backgroundEndHex: "10281C",
            backgroundHexes: ["07100C", "10281C", "0A1815", "0A0C0B"],
            gradientStyle: .mesh
        ),
        ThemeColorPreset(
            id: "default-dark-indigo",
            name: "Indigo",
            accentStartHex: "9CA5FF",
            accentEndHex: "9CA5FF",
            backgroundMode: .gradient,
            backgroundStartHex: "080915",
            backgroundEndHex: "181744",
            backgroundHexes: ["080915", "181744", "101C36", "08090E"],
            gradientStyle: .diffuse
        ),
        ThemeColorPreset(
            id: "default-dark-wine",
            name: "Wine",
            accentStartHex: "F08BAA",
            accentEndHex: "F08BAA",
            backgroundMode: .gradient,
            backgroundStartHex: "10090D",
            backgroundEndHex: "32101B",
            backgroundHexes: ["10090D", "32101B", "1B0E19", "09080B"],
            gradientStyle: .radial
        ),
        ThemeColorPreset(
            id: "default-dark-pulse-bloom",
            name: "Pulse Bloom",
            accentStartHex: "8D7CFF",
            accentEndHex: "8D7CFF",
            backgroundMode: .gradient,
            backgroundStartHex: "1B1730",
            backgroundEndHex: "261F48",
            backgroundHexes: ["1B1730", "261F48", "15112D", "0B0915"],
            gradientStyle: .radial
        ),
    ]
}
