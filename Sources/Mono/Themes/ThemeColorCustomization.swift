import Foundation
import SwiftUI
import UIKit

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
        theme == .default || theme == .muji || theme == .manga || theme == .neumorphic || theme == .capsule || theme == .petWhite || theme == .clarity
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

    // MARK: - 背景图（壁纸式铺满）

    /// 目前仅默认主题支持自定义背景图。
    static func supportsImageBackground(_ theme: GlobalThemeId) -> Bool {
        theme == .default
    }

    @MainActor
    private static var backgroundImageCache: [String: UIImage] = [:]
    @MainActor
    private static var didRegisterMemoryResource = false

    @MainActor
    static func installMemoryManagement() {
        guard !didRegisterMemoryResource else { return }
        didRegisterMemoryResource = true
        MonoMemoryEngine.shared.registerResource(
            id: "cache.theme-background",
            priority: .recreatable,
            budgetWeight: 0.05,
            minimumBudgetBytes: 4 * 1024 * 1024,
            applyBudget: { _ in },
            trim: { context in
                guard context.level >= .background else { return .none }
                let bytes = backgroundImageCache.values.reduce(0) { partial, image in
                    partial + (image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
                }
                let count = backgroundImageCache.count
                backgroundImageCache.removeAll(keepingCapacity: false)
                return .init(
                    releasedItemCount: count,
                    estimatedReleasedBytes: bytes,
                    preservedItemCount: 0
                )
            },
            measureUsage: {
                .init(
                    itemCount: backgroundImageCache.count,
                    estimatedBytes: backgroundImageCache.values.reduce(0) { partial, image in
                        partial + (image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
                    }
                )
            }
        )
    }

    private static func backgroundImageDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ThemeBackgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func backgroundImageFileKeySuffix(dark: Bool) -> String {
        dark ? "darkImageFile" : "imageFile"
    }

    static func backgroundImageFileName(for theme: GlobalThemeId, dark: Bool = false) -> String? {
        let stored = UserDefaults.standard.string(forKey: key(theme, .background, backgroundImageFileKeySuffix(dark: dark)))
        return stored?.isEmpty == false ? stored : nil
    }

    static func backgroundImageURL(for theme: GlobalThemeId, dark: Bool = false) -> URL? {
        guard let fileName = backgroundImageFileName(for: theme, dark: dark) else { return nil }
        let url = backgroundImageDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func hasBackgroundImage(for theme: GlobalThemeId, dark: Bool = false) -> Bool {
        backgroundImageURL(for: theme, dark: dark) != nil
    }

    static func usesImageBackground(for theme: GlobalThemeId) -> Bool {
        customColorsEnabled
            && supportsImageBackground(theme)
            && mode(for: theme, role: .background) == .image
            && hasBackgroundImage(for: theme)
    }

    /// 加载壁纸背景图；参考系统壁纸，整张图缩放填满屏幕显示。
    @MainActor
    static func backgroundImage(for theme: GlobalThemeId, dark: Bool = false) -> UIImage? {
        installMemoryManagement()
        guard let url = backgroundImageURL(for: theme, dark: dark) else { return nil }

        let cacheKey = url.lastPathComponent
        if let cached = backgroundImageCache[cacheKey] {
            return cached
        }

        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        backgroundImageCache[cacheKey] = image
        return image
    }

    @MainActor
    @discardableResult
    static func setBackgroundImageData(_ data: Data, for theme: GlobalThemeId, dark: Bool = false) -> Bool {
        installMemoryManagement()
        guard supportsImageBackground(theme), let raw = UIImage(data: data) else { return false }

        // 压缩上限取设备屏幕像素长边（不低于 2048px），保证壁纸清晰的同时避免超大图占用过多磁盘与内存
        let screenLongestPixel = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
        let maxPixel: CGFloat = max(2048, screenLongestPixel)
        let pixelWidth = raw.size.width * raw.scale
        let pixelHeight = raw.size.height * raw.scale
        let ratio = min(1, maxPixel / max(pixelWidth, pixelHeight))
        let targetSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            raw.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let output = resized.pngData() else { return false }

        removeBackgroundImageFile(for: theme, dark: dark)

        let fileName = "\(theme.rawValue)-bg\(dark ? "-dark" : "")-\(UUID().uuidString).png"
        let url = backgroundImageDirectory().appendingPathComponent(fileName)
        do {
            try output.write(to: url)
        } catch {
            return false
        }

        let defaults = UserDefaults.standard
        defaults.set(fileName, forKey: key(theme, .background, backgroundImageFileKeySuffix(dark: dark)))
        if dark {
            defaults.set(ThemeDarkBackgroundKind.image.rawValue, forKey: key(theme, .background, "darkKind"))
            defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        } else {
            defaults.set(ThemeCustomColorMode.image.rawValue, forKey: key(theme, .background, "mode"))
            defaults.removeObject(forKey: selectedPresetKey(theme))
        }
        SettingsManager.shared.notifyThemeCustomizationChanged()
        return true
    }

    @MainActor
    static func clearBackgroundImage(for theme: GlobalThemeId, dark: Bool = false) {
        removeBackgroundImageFile(for: theme, dark: dark)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key(theme, .background, backgroundImageFileKeySuffix(dark: dark)))
        if dark {
            if darkBackgroundKind(for: theme) == .image {
                defaults.removeObject(forKey: key(theme, .background, "darkKind"))
            }
            defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        } else {
            if mode(for: theme, role: .background) == .image {
                defaults.removeObject(forKey: key(theme, .background, "mode"))
            }
            defaults.removeObject(forKey: selectedPresetKey(theme))
        }
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    @MainActor
    private static func removeBackgroundImageFile(for theme: GlobalThemeId, dark: Bool = false) {
        if let fileName = backgroundImageFileName(for: theme, dark: dark) {
            backgroundImageCache.removeValue(forKey: fileName)
            let url = backgroundImageDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - 夜间背景（默认主题）

    static let defaultDarkAccentHex = "FFFFFF"
    static let defaultDarkBackgroundSolidHex = "000000"

    /// 夜间背景与浅色自定义背景独立存储；不受 `customColorsEnabled`（深色禁用自定义配色）限制。
    static func darkBackgroundKind(for theme: GlobalThemeId) -> ThemeDarkBackgroundKind {
        guard supportsImageBackground(theme) else { return .standard }
        let raw = UserDefaults.standard.string(forKey: key(theme, .background, "darkKind"))
        return ThemeDarkBackgroundKind(rawValue: raw ?? "") ?? .standard
    }

    @MainActor
    static func setDarkBackgroundKind(_ kind: ThemeDarkBackgroundKind, for theme: GlobalThemeId) {
        let defaults = UserDefaults.standard
        defaults.set(kind.rawValue, forKey: key(theme, .background, "darkKind"))
        defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    static func darkAccentHex(for theme: GlobalThemeId) -> String {
        hex(theme, .accent, "darkSolid", fallback: defaultDarkAccentHex)
    }

    static func darkBackgroundSolidHex(for theme: GlobalThemeId) -> String {
        hex(theme, .background, "darkSolid", fallback: defaultDarkBackgroundSolidHex)
    }

    static func darkBackgroundGradientStyle(for theme: GlobalThemeId) -> ThemeCustomGradientStyle {
        let raw = UserDefaults.standard.string(
            forKey: key(theme, .background, "darkGradientStyle")
        )
        return (
            ThemeCustomGradientStyle(rawValue: raw ?? ThemeCustomGradientStyle.diffuse.rawValue)
                ?? .diffuse
        ).normalized
    }

    static func defaultDarkBackgroundStopHex(_ suffix: String) -> String {
        switch suffix {
        case "darkEnd": return "151822"
        case "darkStop3": return "0E1623"
        case "darkStop4": return "090A0F"
        default: return "08090D"
        }
    }

    static func darkBackgroundGradientHexes(for theme: GlobalThemeId) -> [String] {
        darkBackgroundGradientSuffixes.map { suffix in
            normalizedHex(
                hex(
                    theme,
                    .background,
                    suffix,
                    fallback: defaultDarkBackgroundStopHex(suffix)
                )
            )
        }
    }

    static func darkBackgroundGradientColors(for theme: GlobalThemeId) -> [Color] {
        darkBackgroundGradientHexes(for: theme).map { Color(hex: $0) }
    }

    @MainActor
    static func setDarkBackgroundGradientStyle(
        _ style: ThemeCustomGradientStyle,
        for theme: GlobalThemeId
    ) {
        let defaults = UserDefaults.standard
        defaults.set(
            style.normalized.rawValue,
            forKey: key(theme, .background, "darkGradientStyle")
        )
        defaults.removeObject(forKey: selectedDarkPresetKey(theme))
        SettingsManager.shared.notifyThemeCustomizationChanged()
    }

    static func usesDarkSolidBackground(for theme: GlobalThemeId) -> Bool {
        darkBackgroundKind(for: theme) == .solid
    }

    static func usesDarkGradientBackground(for theme: GlobalThemeId) -> Bool {
        darkBackgroundKind(for: theme) == .gradient
    }

    static func usesDarkImageBackground(for theme: GlobalThemeId) -> Bool {
        darkBackgroundKind(for: theme) == .image && hasBackgroundImage(for: theme, dark: true)
    }

    static func readableForegroundColor(
        on fill: Color,
        light: Color = Color(hex: "111821"),
        dark: Color = Color.white,
        threshold: CGFloat = 0.58
    ) -> Color {
        let darkTextContrast = contrastRatio(between: light, and: fill)
        let lightTextContrast = contrastRatio(between: dark, and: fill)

        // 强调色上的浅色文字只要仍达到大字号/图标所需的 3:1，就优先保留；
        // 只有确实看不清时才切深色，避免中亮度强调色被过早判成黑字。
        if lightTextContrast >= 3 {
            return dark
        }
        if darkTextContrast != lightTextContrast {
            return darkTextContrast > lightTextContrast ? light : dark
        }
        return resolvedLuminance(of: fill) >= threshold ? light : dark
    }

    /// Resolves dynamic colors against the appearance used by the target view.
    /// This is required by views that deliberately override the app color scheme.
    static func readableForegroundColor(
        on fill: Color,
        colorScheme: ColorScheme,
        light: Color = Color(hex: "111821"),
        dark: Color = Color.white,
        threshold: CGFloat = 0.58
    ) -> Color {
        let interfaceStyle: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let darkTextContrast = contrastRatio(
            between: light,
            and: fill,
            interfaceStyle: interfaceStyle
        )
        let lightTextContrast = contrastRatio(
            between: dark,
            and: fill,
            interfaceStyle: interfaceStyle
        )

        if lightTextContrast >= 3 {
            return dark
        }
        if darkTextContrast != lightTextContrast {
            return darkTextContrast > lightTextContrast ? light : dark
        }
        return resolvedLuminance(of: fill, interfaceStyle: interfaceStyle) >= threshold ? light : dark
    }

    static func contrastRatio(between foreground: Color, and background: Color) -> CGFloat {
        contrastRatio(between: foreground, and: background, interfaceStyle: nil)
    }

    private static func contrastRatio(
        between foreground: Color,
        and background: Color,
        interfaceStyle: UIUserInterfaceStyle?
    ) -> CGFloat {
        let backgroundRGBA = resolvedRGBA(of: background, interfaceStyle: interfaceStyle)
        let foregroundRGBA = resolvedRGBA(of: foreground, interfaceStyle: interfaceStyle)
        let opaqueBackground = composite(backgroundRGBA, over: RGBA(red: 1, green: 1, blue: 1, alpha: 1))
        let compositedForeground = composite(foregroundRGBA, over: opaqueBackground)
        let foregroundLuminance = relativeLuminance(of: compositedForeground)
        let backgroundLuminance = relativeLuminance(of: opaqueBackground)
        return (max(foregroundLuminance, backgroundLuminance) + 0.05)
            / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    static func isLightColor(_ color: Color, threshold: CGFloat = 0.58) -> Bool {
        resolvedLuminance(of: color) >= threshold
    }

    static func visibleTintColor(_ tint: Color, darkFallback: Color, lightThreshold: CGFloat = 0.72) -> Color {
        guard customColorsEnabled else { return tint }
        return isLightColor(tint, threshold: lightThreshold) ? darkFallback : tint
    }

    private static func resolvedLuminance(of color: Color) -> CGFloat {
        resolvedLuminance(of: color, interfaceStyle: nil)
    }

    private static func resolvedLuminance(
        of color: Color,
        interfaceStyle: UIUserInterfaceStyle?
    ) -> CGFloat {
        let rgba = resolvedRGBA(of: color, interfaceStyle: interfaceStyle)
        let compositedRed = rgba.red * rgba.alpha + (1 - rgba.alpha)
        let compositedGreen = rgba.green * rgba.alpha + (1 - rgba.alpha)
        let compositedBlue = rgba.blue * rgba.alpha + (1 - rgba.alpha)
        return 0.299 * compositedRed + 0.587 * compositedGreen + 0.114 * compositedBlue
    }

    private struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    private static func resolvedRGBA(
        of color: Color,
        interfaceStyle: UIUserInterfaceStyle?
    ) -> RGBA {
        let sourceColor = UIColor(color)
        let uiColor: UIColor
        if let interfaceStyle {
            uiColor = sourceColor.resolvedColor(
                with: UITraitCollection(userInterfaceStyle: interfaceStyle)
            )
        } else {
            uiColor = sourceColor
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return RGBA(red: 1, green: 1, blue: 1, alpha: 1)
        }
        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func composite(_ foreground: RGBA, over background: RGBA) -> RGBA {
        let alpha = foreground.alpha + background.alpha * (1 - foreground.alpha)
        guard alpha > 0 else { return RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
        return RGBA(
            red: (foreground.red * foreground.alpha + background.red * background.alpha * (1 - foreground.alpha)) / alpha,
            green: (foreground.green * foreground.alpha + background.green * background.alpha * (1 - foreground.alpha)) / alpha,
            blue: (foreground.blue * foreground.alpha + background.blue * background.alpha * (1 - foreground.alpha)) / alpha,
            alpha: alpha
        )
    }

    private static func relativeLuminance(of color: RGBA) -> CGFloat {
        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(color.red)
            + 0.7152 * linearize(color.green)
            + 0.0722 * linearize(color.blue)
    }

    static func mangaHex(_ suffix: String, fallback: String) -> String {
        let stored = UserDefaults.standard.string(forKey: mangaKey(suffix))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : fallback
    }

    private static func storedMangaHex(_ suffix: String) -> String? {
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
        guard supports(theme),
              let data = UserDefaults.standard.data(forKey: savedPresetsKey(theme)),
              let presets = try? JSONDecoder().decode([ThemeColorPreset].self, from: data)
        else {
            return []
        }
        return presets
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
        guard theme == .default,
              let data = UserDefaults.standard.data(forKey: savedDarkPresetsKey(theme)),
              let presets = try? JSONDecoder().decode([ThemeColorPreset].self, from: data)
        else {
            return []
        }
        return presets
    }

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

    private static func stableCloudPreset(
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

    private static func mergedCloudPresets(
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

    private static let builtInDarkPresets: [ThemeColorPreset] = [
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

    private static func builtInPresets(for theme: GlobalThemeId) -> [ThemeColorPreset] {
        switch theme {
        case .minimalWhite:
            return []
        case .clarity:
            return [
                ThemeColorPreset(id: "clarity-air", name: "Air", accentStartHex: "2478D8", accentEndHex: "2478D8", backgroundStartHex: "F8F8F7", backgroundEndHex: "EDF1F2", backgroundHexes: ["F8F8F7", "EDF1F2", "F1EAF7", "E7F5F5"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "clarity-pearl", name: "Pearl", accentStartHex: "57636D", accentEndHex: "57636D", backgroundStartHex: "FBFBF9", backgroundEndHex: "EFF1F1", backgroundHexes: ["FBFBF9", "EFF1F1", "F4F0EC", "EDF3F4"], gradientStyle: .linear),
                ThemeColorPreset(id: "clarity-aurora", name: "Aurora", accentStartHex: "238F91", accentEndHex: "238F91", backgroundStartHex: "F4FBFA", backgroundEndHex: "EAF3F7", backgroundHexes: ["F4FBFA", "EAF3F7", "EAEAF8", "E5F6F0"], gradientStyle: .mesh),
                ThemeColorPreset(id: "clarity-lavender", name: "Lavender", accentStartHex: "7066A6", accentEndHex: "7066A6", backgroundStartHex: "F8F6FC", backgroundEndHex: "ECEFF7", backgroundHexes: ["F8F6FC", "ECEFF7", "F2EAF8", "E8F4F5"], gradientStyle: .radial),
                ThemeColorPreset(id: "clarity-peach-ice", name: "Peach Ice", accentStartHex: "B76E61", accentEndHex: "B76E61", backgroundStartHex: "FFF8F5", backgroundEndHex: "EDF3F5", backgroundHexes: ["FFF8F5", "EDF3F5", "FBE9E5", "EAF5F2"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "clarity-sage", name: "Sage Mist", accentStartHex: "5D8274", accentEndHex: "5D8274", backgroundStartHex: "F5F9F6", backgroundEndHex: "EBF1EF", backgroundHexes: ["F5F9F6", "EBF1EF", "EEF2E8", "E7F4F3"], gradientStyle: .mesh),
                ThemeColorPreset(id: "clarity-sky", name: "Clear Sky", accentStartHex: "347CAD", accentEndHex: "347CAD", backgroundStartHex: "F5FAFD", backgroundEndHex: "E8F1F7", backgroundHexes: ["F5FAFD", "E8F1F7", "EDF4FB", "E7F8F7"], gradientStyle: .linear),
                ThemeColorPreset(id: "clarity-rose", name: "Rose Quartz", accentStartHex: "A96378", accentEndHex: "A96378", backgroundStartHex: "FFF7FA", backgroundEndHex: "EEF1F6", backgroundHexes: ["FFF7FA", "EEF1F6", "F8E9EF", "ECF5F3"], gradientStyle: .radial),
                ThemeColorPreset(id: "clarity-champagne", name: "Champagne", accentStartHex: "9A763F", accentEndHex: "9A763F", backgroundStartHex: "FCF9F2", backgroundEndHex: "EEF1F2", backgroundHexes: ["FCF9F2", "EEF1F2", "F7EEDC", "ECF4F0"], gradientStyle: .conic),
                ThemeColorPreset(id: "clarity-glacier", name: "Glacier", accentStartHex: "397F8E", accentEndHex: "397F8E", backgroundStartHex: "F4FBFC", backgroundEndHex: "E8F0F4", backgroundHexes: ["F4FBFC", "E8F0F4", "E7F5F7", "EDF0FA"], gradientStyle: .mesh),
                ThemeColorPreset(id: "clarity-silver", name: "Silver", accentStartHex: "606B76", accentEndHex: "606B76", backgroundStartHex: "F7F8F9", backgroundEndHex: "E9EDF0", backgroundHexes: ["F7F8F9", "E9EDF0", "F0F1F5", "EAF1F1"], gradientStyle: .linear),
                ThemeColorPreset(id: "clarity-moon-milk", name: "Moon Milk", accentStartHex: "826C8D", accentEndHex: "826C8D", backgroundStartHex: "FAF8FA", backgroundEndHex: "EEF0F2", backgroundHexes: ["FAF8FA", "EEF0F2", "F3EBF1", "EDF5F2"], gradientStyle: .diffuse),
            ]
        case .muji:
            return [
                ThemeColorPreset(id: "muji-linen", name: "Linen", accentStartHex: "B56B4B", accentEndHex: "B56B4B", backgroundStartHex: "F7F1E8", backgroundEndHex: "F7F1E8"),
                ThemeColorPreset(id: "muji-tea", name: "Tea", accentStartHex: "78846B", accentEndHex: "78846B", backgroundStartHex: "F3EEE3", backgroundEndHex: "F3EEE3"),
                ThemeColorPreset(id: "muji-clay", name: "Clay", accentStartHex: "B96D55", accentEndHex: "B96D55", backgroundStartHex: "F4E8DC", backgroundEndHex: "F4E8DC"),
                ThemeColorPreset(id: "muji-rice", name: "Rice", accentStartHex: "9C7A53", accentEndHex: "9C7A53", backgroundStartHex: "FAF4E8", backgroundEndHex: "FAF4E8"),
                ThemeColorPreset(id: "muji-olive", name: "Olive", accentStartHex: "6F8064", accentEndHex: "6F8064", backgroundStartHex: "F1EFE4", backgroundEndHex: "F1EFE4"),
                ThemeColorPreset(id: "muji-indigo", name: "Indigo", accentStartHex: "56677A", accentEndHex: "56677A", backgroundStartHex: "F1F0EA", backgroundEndHex: "F1F0EA"),
                ThemeColorPreset(id: "muji-ash", name: "Ash", accentStartHex: "7B776C", accentEndHex: "7B776C", backgroundStartHex: "F2F0EA", backgroundEndHex: "F2F0EA"),
                ThemeColorPreset(id: "muji-oat", name: "Oat", accentStartHex: "A9855F", accentEndHex: "A9855F", backgroundStartHex: "F8EFE2", backgroundEndHex: "F8EFE2"),
                ThemeColorPreset(id: "muji-moss", name: "Moss", accentStartHex: "69795F", accentEndHex: "69795F", backgroundStartHex: "EFF1E8", backgroundEndHex: "EFF1E8"),
                ThemeColorPreset(id: "muji-sumi", name: "Sumi", accentStartHex: "5F6561", accentEndHex: "5F6561", backgroundStartHex: "F1EEE6", backgroundEndHex: "F1EEE6"),
                ThemeColorPreset(id: "muji-ume", name: "Ume", accentStartHex: "A65D62", accentEndHex: "A65D62", backgroundStartHex: "F8ECE8", backgroundEndHex: "F8ECE8"),
                ThemeColorPreset(id: "muji-wheat", name: "Wheat", accentStartHex: "B48A52", accentEndHex: "B48A52", backgroundStartHex: "F7F0DD", backgroundEndHex: "F7F0DD"),
            ]
        case .neumorphic:
            return [
                ThemeColorPreset(id: "neu-mint", name: "Soft Mint", accentStartHex: "4F8E86", accentEndHex: "7D9475", backgroundStartHex: "E9EDF0", backgroundEndHex: "F2EEE8", backgroundHexes: ["E9EDF0", "F2EEE8", "E4ECE7", "EEF0F5"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "neu-dawn", name: "Dawn", accentStartHex: "C59A66", accentEndHex: "C65A58", backgroundStartHex: "EEE8E1", backgroundEndHex: "E7EDF0", backgroundHexes: ["EEE8E1", "E7EDF0", "F1E4D8", "E9EEF2"], gradientStyle: .linear),
                ThemeColorPreset(id: "neu-blue", name: "Quiet Blue", accentStartHex: "5E7FA4", accentEndHex: "7AB9B0", backgroundStartHex: "E8EDF4", backgroundEndHex: "F0F2F4", backgroundHexes: ["E8EDF4", "F0F2F4", "E3F0EF", "EEF4F7"], gradientStyle: .radial),
                ThemeColorPreset(id: "neu-sage", name: "Sage", accentStartHex: "6E8B70", accentEndHex: "96A874", backgroundStartHex: "E8EDE7", backgroundEndHex: "F4F0E8", backgroundHexes: ["E8EDE7", "F4F0E8", "EAF3E3", "F0ECE2"], gradientStyle: .mesh),
                ThemeColorPreset(id: "neu-apricot", name: "Apricot", accentStartHex: "C27B5E", accentEndHex: "C8A361", backgroundStartHex: "F0E8DF", backgroundEndHex: "EDF1EC", backgroundHexes: ["F0E8DF", "EDF1EC", "F4E3D8", "E8EEF1"], gradientStyle: .linear),
                ThemeColorPreset(id: "neu-lake", name: "Lake", accentStartHex: "4E8196", accentEndHex: "72A69B", backgroundStartHex: "E6EEF2", backgroundEndHex: "F2F0EA", backgroundHexes: ["E6EEF2", "F2F0EA", "DFECEB", "ECF3F5"], gradientStyle: .conic),
                ThemeColorPreset(id: "neu-milk", name: "Milk", accentStartHex: "8C7A65", accentEndHex: "8C7A65", backgroundStartHex: "F1EEE9", backgroundEndHex: "E8EDF1", backgroundHexes: ["F1EEE9", "E8EDF1", "F5F0E7", "E6ECEA"], gradientStyle: .mesh),
                ThemeColorPreset(id: "neu-rose", name: "Rose", accentStartHex: "A86E77", accentEndHex: "A86E77", backgroundStartHex: "F2E7E8", backgroundEndHex: "ECEFF3", backgroundHexes: ["F2E7E8", "ECEFF3", "F4DFE6", "E8EEF2"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "neu-celadon", name: "Celadon", accentStartHex: "5F8F78", accentEndHex: "5F8F78", backgroundStartHex: "E5EFEA", backgroundEndHex: "F2F0E7", backgroundHexes: ["E5EFEA", "F2F0E7", "DDEBE4", "EDF3F0"], gradientStyle: .radial),
                ThemeColorPreset(id: "neu-lilac", name: "Lilac", accentStartHex: "7B79A8", accentEndHex: "7B79A8", backgroundStartHex: "ECEAF4", backgroundEndHex: "E8EFF2", backgroundHexes: ["ECEAF4", "E8EFF2", "F3E8F1", "E4EEF4"], gradientStyle: .conic),
            ]
        case .capsule:
            return [
                ThemeColorPreset(id: "capsule-system", name: "System Blue", accentStartHex: "3867FF", accentEndHex: "3867FF", backgroundStartHex: "F6F8FF", backgroundEndHex: "EAF1FF", backgroundHexes: ["F6F8FF", "EAF1FF", "F8F2FF", "EDF9FF"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "capsule-mint", name: "Mint Dock", accentStartHex: "1AAE9F", accentEndHex: "1AAE9F", backgroundStartHex: "F3FBF8", backgroundEndHex: "EAF5FF", backgroundHexes: ["F3FBF8", "EAF5FF", "F7F3FF", "E9FAF4"], gradientStyle: .mesh),
                ThemeColorPreset(id: "capsule-coral", name: "Coral Pulse", accentStartHex: "EF6B73", accentEndHex: "EF6B73", backgroundStartHex: "FFF5F5", backgroundEndHex: "EEF5FF", backgroundHexes: ["FFF5F5", "EEF5FF", "FFF1E8", "F3F6FF"], gradientStyle: .radial),
                ThemeColorPreset(id: "capsule-lilac", name: "Lilac OS", accentStartHex: "7D6DFF", accentEndHex: "7D6DFF", backgroundStartHex: "F7F4FF", backgroundEndHex: "EAF6FF", backgroundHexes: ["F7F4FF", "EAF6FF", "FFF1FA", "EFFAF6"], gradientStyle: .conic),
                ThemeColorPreset(id: "capsule-sun", name: "Soft Sun", accentStartHex: "D89B2C", accentEndHex: "D89B2C", backgroundStartHex: "FFF8EA", backgroundEndHex: "EAF3FF", backgroundHexes: ["FFF8EA", "EAF3FF", "F7F0FF", "EDF9F2"], gradientStyle: .linear),
                ThemeColorPreset(id: "capsule-sky", name: "Sky Rail", accentStartHex: "2F8FE8", accentEndHex: "2F8FE8", backgroundStartHex: "F2F9FF", backgroundEndHex: "EEF3FF", backgroundHexes: ["F2F9FF", "EEF3FF", "E7FBFF", "F6F2FF"], gradientStyle: .mesh),
                ThemeColorPreset(id: "capsule-rose", name: "Rose Link", accentStartHex: "D75B8A", accentEndHex: "D75B8A", backgroundStartHex: "FFF3F8", backgroundEndHex: "EDF4FF", backgroundHexes: ["FFF3F8", "EDF4FF", "FFF0E6", "EFFAF5"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "capsule-sage", name: "Sage Grid", accentStartHex: "5C8B73", accentEndHex: "5C8B73", backgroundStartHex: "F4FAF4", backgroundEndHex: "EAF2FF", backgroundHexes: ["F4FAF4", "EAF2FF", "F6F1E8", "EDF7F1"], gradientStyle: .radial),
            ]
        case .petWhite:
            return [
                ThemeColorPreset(id: "petwhite-puppy", name: "Puppy", accentStartHex: "F6A93B", accentEndHex: "F6A93B", backgroundStartHex: "FFFFFF", backgroundEndHex: "F7F8FA", backgroundHexes: ["FFFFFF", "F7F8FA", "FFF5E1", "DDF5EE"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "petwhite-cat", name: "Cat", accentStartHex: "111111", accentEndHex: "111111", backgroundStartHex: "FFFFFF", backgroundEndHex: "F4F6F8", backgroundHexes: ["FFFFFF", "F4F6F8", "F0ECFF", "EEF4FF"], gradientStyle: .linear),
                ThemeColorPreset(id: "petwhite-mint", name: "Mint", accentStartHex: "30A98B", accentEndHex: "30A98B", backgroundStartHex: "FFFFFF", backgroundEndHex: "F5FAF8", backgroundHexes: ["FFFFFF", "F5FAF8", "F7F0FF", "FFF0E6"], gradientStyle: .radial),
                ThemeColorPreset(id: "petwhite-butter", name: "Butter", accentStartHex: "E39F23", accentEndHex: "E39F23", backgroundStartHex: "FFFFFF", backgroundEndHex: "FFF9EA", backgroundHexes: ["FFFFFF", "FFF9EA", "F7F5EE", "DDF5EE"], gradientStyle: .conic),
                ThemeColorPreset(id: "petwhite-sky", name: "Sky", accentStartHex: "3B82F6", accentEndHex: "3B82F6", backgroundStartHex: "FFFFFF", backgroundEndHex: "EEF4FF", backgroundHexes: ["FFFFFF", "EEF4FF", "F6F8FA", "F0ECFF"], gradientStyle: .mesh),
            ]
        case .manga:
            return [
                ThemeColorPreset(id: "manga-pop", name: "Pop", accentStartHex: "FF4F84", accentEndHex: "FF4F84", backgroundStartHex: "FFF3D7", backgroundEndHex: "E8F1FF", backgroundHexes: ["FFF3D7", "E8F1FF", "FFEAF4", "F8F6DE"], gradientStyle: .diffuse, mangaBlockAHex: "FFE067", mangaBlockBHex: "58B9FF", mangaBlockCHex: "8DE4B8", mangaStrokeHex: "3B3145", mangaSettingsIconHex: "17151F"),
                ThemeColorPreset(id: "manga-berry", name: "Berry", accentStartHex: "E65E8E", accentEndHex: "E65E8E", backgroundStartHex: "FFEAF0", backgroundEndHex: "F6F0FF", backgroundHexes: ["FFEAF0", "F6F0FF", "FFF0D9", "EAF7FF"], gradientStyle: .radial, mangaBlockAHex: "FFB4D2", mangaBlockBHex: "B391FF", mangaBlockCHex: "FFE7A3", mangaStrokeHex: "4B3A55", mangaSettingsIconHex: "2B2030"),
                ThemeColorPreset(id: "manga-soda", name: "Soda", accentStartHex: "4FA9FF", accentEndHex: "4FA9FF", backgroundStartHex: "EEF7FF", backgroundEndHex: "FFF1D8", backgroundHexes: ["EEF7FF", "FFF1D8", "E8FFF8", "FFECEF"], gradientStyle: .diffuse, mangaBlockAHex: "70D7FF", mangaBlockBHex: "FFE36D", mangaBlockCHex: "FF9C7E", mangaStrokeHex: "344B5E", mangaSettingsIconHex: "172C3A"),
                ThemeColorPreset(id: "manga-peach", name: "Peach", accentStartHex: "FF7A6E", accentEndHex: "FF7A6E", backgroundStartHex: "FFF0DF", backgroundEndHex: "FFE9F1", backgroundHexes: ["FFF0DF", "FFE9F1", "F0F7FF", "FFF7D8"], gradientStyle: .linear, mangaBlockAHex: "FFBC8D", mangaBlockBHex: "C7A7FF", mangaBlockCHex: "93D9B4", mangaStrokeHex: "5C4052", mangaSettingsIconHex: "2F222A"),
                ThemeColorPreset(id: "manga-lime", name: "Lime", accentStartHex: "7FBF5B", accentEndHex: "7FBF5B", backgroundStartHex: "F7F6D9", backgroundEndHex: "EAF7EC", backgroundHexes: ["F7F6D9", "EAF7EC", "FFF3CF", "E5F4FF"], gradientStyle: .mesh, mangaBlockAHex: "B8E76F", mangaBlockBHex: "FFE890", mangaBlockCHex: "5ECFA6", mangaStrokeHex: "465F4D", mangaSettingsIconHex: "203428"),
                ThemeColorPreset(id: "manga-candy", name: "Candy", accentStartHex: "F06DA6", accentEndHex: "F06DA6", backgroundStartHex: "FFF0FA", backgroundEndHex: "EAF6FF", backgroundHexes: ["FFF0FA", "EAF6FF", "FFF8D7", "F1EDFF"], gradientStyle: .radial, mangaBlockAHex: "FFA6D9", mangaBlockBHex: "8FE7E1", mangaBlockCHex: "C9A8FF", mangaStrokeHex: "694E67", mangaSettingsIconHex: "302039"),
                ThemeColorPreset(id: "manga-hero", name: "Hero", accentStartHex: "E94D5F", accentEndHex: "E94D5F", backgroundStartHex: "FFF2D8", backgroundEndHex: "E9F2FF", backgroundHexes: ["FFF2D8", "E9F2FF", "FFE5E7", "EAF9E6"], gradientStyle: .conic, mangaBlockAHex: "FFDB56", mangaBlockBHex: "6BCBFF", mangaBlockCHex: "FF7A7A", mangaStrokeHex: "423647", mangaSettingsIconHex: "201B25"),
                ThemeColorPreset(id: "manga-nightpop", name: "Night Pop", accentStartHex: "8C6CFF", accentEndHex: "8C6CFF", backgroundStartHex: "F4F0FF", backgroundEndHex: "EAF7FF", backgroundHexes: ["F4F0FF", "EAF7FF", "FFEFF9", "FFF7D9"], gradientStyle: .mesh, mangaBlockAHex: "B79AFF", mangaBlockBHex: "69D7FF", mangaBlockCHex: "FFDA69", mangaStrokeHex: "3F3862", mangaSettingsIconHex: "1F1B34"),
                ThemeColorPreset(id: "manga-melon", name: "Melon", accentStartHex: "55B77B", accentEndHex: "55B77B", backgroundStartHex: "F1F9DD", backgroundEndHex: "EAF7F0", backgroundHexes: ["F1F9DD", "EAF7F0", "FFF0D3", "EAF4FF"], gradientStyle: .diffuse, mangaBlockAHex: "C7EB65", mangaBlockBHex: "82D8B2", mangaBlockCHex: "FFBD79", mangaStrokeHex: "3D5845", mangaSettingsIconHex: "1F3327"),
                ThemeColorPreset(id: "manga-bubblegum", name: "Bubble", accentStartHex: "FF6FAF", accentEndHex: "FF6FAF", backgroundStartHex: "FFF0FB", backgroundEndHex: "F0F6FF", backgroundHexes: ["FFF0FB", "F0F6FF", "FFEADB", "EFFFF8"], gradientStyle: .conic, mangaBlockAHex: "FFA6D6", mangaBlockBHex: "9DE7FF", mangaBlockCHex: "FFE46E", mangaStrokeHex: "62435E", mangaSettingsIconHex: "302033"),
            ]
        case .default:
            return [
                ThemeColorPreset(id: "default-mist", name: "Mist", accentStartHex: "4D6F95", accentEndHex: "4D6F95", backgroundStartHex: "F8FAFC", backgroundEndHex: "E6EDF6", backgroundHexes: ["F8FAFC", "E6EDF6", "EEF4EE", "F6F1EA"], gradientStyle: .diffuse),
                ThemeColorPreset(id: defaultCatPawPresetId, name: "Cat Paw", accentStartHex: "FF9B83", accentEndHex: "FF9B83", backgroundStartHex: "FFF7EC", backgroundEndHex: "FFE7D8", backgroundHexes: ["FFF7EC", "FFE7D8", "F2F8EF", "EAF4FF"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "default-dawn", name: "Dawn", accentStartHex: "B66E57", accentEndHex: "B66E57", backgroundStartHex: "FFF6EB", backgroundEndHex: "EAF0FA", backgroundHexes: ["FFF6EB", "EAF0FA", "FFEAE2", "EEF8F5"], gradientStyle: .linear),
                ThemeColorPreset(id: "default-lake", name: "Lake", accentStartHex: "4D8196", accentEndHex: "4D8196", backgroundStartHex: "EEF6FA", backgroundEndHex: "E9F2EC", backgroundHexes: ["EEF6FA", "E9F2EC", "F7F5EC", "E6F1F8"], gradientStyle: .radial),
                ThemeColorPreset(id: "default-sage", name: "Sage", accentStartHex: "6A8368", accentEndHex: "6A8368", backgroundStartHex: "F5F7EF", backgroundEndHex: "E8EFE7", backgroundHexes: ["F5F7EF", "E8EFE7", "F7F1E7", "EEF4F0"], gradientStyle: .diffuse),
                ThemeColorPreset(id: "default-iris", name: "Iris", accentStartHex: "6E72A7", accentEndHex: "6E72A7", backgroundStartHex: "F6F4FB", backgroundEndHex: "E9EEF8", backgroundHexes: ["F6F4FB", "E9EEF8", "F4ECF8", "EEF7FA"], gradientStyle: .mesh),
                ThemeColorPreset(id: "default-clay", name: "Clay", accentStartHex: "9F7559", accentEndHex: "9F7559", backgroundStartHex: "F8F1EA", backgroundEndHex: "EAF0F3", backgroundHexes: ["F8F1EA", "EAF0F3", "F4E8DD", "EEF5EF"], gradientStyle: .conic),
                ThemeColorPreset(id: "default-sky", name: "Sky", accentStartHex: "497FAF", accentEndHex: "497FAF", backgroundStartHex: "F1F7FD", backgroundEndHex: "E9F1F7", backgroundHexes: ["F1F7FD", "E9F1F7", "F7F6EE", "EAF8F4"], gradientStyle: .linear),
                ThemeColorPreset(id: "default-plum", name: "Plum", accentStartHex: "8E668A", accentEndHex: "8E668A", backgroundStartHex: "F8F2F8", backgroundEndHex: "EAF0F6", backgroundHexes: ["F8F2F8", "EAF0F6", "F6EAEF", "EEF7F5"], gradientStyle: .radial),
                ThemeColorPreset(id: "default-cedar", name: "Cedar", accentStartHex: "547760", accentEndHex: "547760", backgroundStartHex: "F3F6EF", backgroundEndHex: "E7EFEA", backgroundHexes: ["F3F6EF", "E7EFEA", "F7F1E5", "ECF3F5"], gradientStyle: .mesh),
                ThemeColorPreset(id: "default-amber", name: "Amber", accentStartHex: "A9793E", accentEndHex: "A9793E", backgroundStartHex: "FFF7E8", backgroundEndHex: "EAF1F4", backgroundHexes: ["FFF7E8", "EAF1F4", "F6EBD8", "EEF8F4"], gradientStyle: .diffuse),
            ]
        }
    }

    static func isPresetSelected(_ preset: ThemeColorPreset, for theme: GlobalThemeId) -> Bool {
        guard hasStoredCustomization(for: theme) else { return false }

        if let selectedPresetId = UserDefaults.standard.string(forKey: selectedPresetKey(theme)) {
            return preset.id == selectedPresetId && isPresetColorMatched(preset, for: theme)
        }

        return isPresetColorMatched(preset, for: theme)
    }

    private static func isPresetColorMatched(_ preset: ThemeColorPreset, for theme: GlobalThemeId) -> Bool {
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

    private static func isDarkPresetColorMatched(
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

struct ThemeCustomDiffuseBackground: View {
    let theme: GlobalThemeId
    let fallbackHexes: [String]
    var accentFallbackHexes: [String] = []
    var opacity: Double = 1
    var colorsOverride: [Color]? = nil
    var accentColorsOverride: [Color]? = nil
    var gradientStyleOverride: ThemeCustomGradientStyle? = nil

    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        let colors = colorsOverride
            ?? ThemeColorCustomization.backgroundGradientColors(
                for: theme,
                fallbackHexes: fallbackHexes
            )
        let accentColors = accentColorsOverride
            ?? ThemeColorCustomization.accentGradientColors(
                for: theme,
                fallback: accentFallbackHexes.map { Color(hex: $0) },
                fallbackHexes: accentFallbackHexes
            )
        let style = gradientStyleOverride
            ?? ThemeColorCustomization.gradientStyle(for: theme, role: .background)
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
        } else if style == .conic {
            AngularGradient(
                gradient: Gradient(colors: colors + [colors.first ?? .clear]),
                center: .center,
                angle: .degrees(-35)
            )
        } else if style == .mesh {
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas(rendersAsynchronously: true) { context, _ in
                    let width = max(size.width, 1)
                    let height = max(size.height, 1)
                    drawGlow(context, center: CGPoint(x: width * 0.18, y: height * 0.16), radius: width * 0.52, color: colors.first ?? .clear, opacity: 0.24 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.82, y: height * 0.22), radius: width * 0.48, color: colors.dropFirst().first ?? colors.first ?? .clear, opacity: 0.2 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.28, y: height * 0.82), radius: width * 0.56, color: colors.dropFirst(2).first ?? colors.last ?? .clear, opacity: 0.18 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.9, y: height * 0.78), radius: width * 0.5, color: colors.dropFirst(3).first ?? colors.last ?? .clear, opacity: 0.16 * opacity)
                }
                .blur(radius: 38)
                .blendMode(.softLight)
            }
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
            if style == .diffuse && theme != .neumorphic {
                Canvas(rendersAsynchronously: true) { context, _ in
                    drawGlow(context, center: CGPoint(x: width * 0.16, y: height * 0.12), radius: width * 0.58, color: firstAccent, opacity: 0.18 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.88, y: height * 0.36), radius: width * 0.52, color: secondAccent, opacity: 0.14 * opacity)
                    drawGlow(context, center: CGPoint(x: width * 0.42, y: height * 0.86), radius: width * 0.62, color: colors.last ?? secondAccent, opacity: 0.12 * opacity)
                }
                .blur(radius: 44)
                .blendMode(.softLight)
            } else if theme == .neumorphic {
                LinearGradient(
                    colors: [
                        firstAccent.opacity(0.12 * opacity),
                        .clear,
                        secondAccent.opacity(0.1 * opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        firstAccent.opacity(0.15 * opacity),
                        .clear,
                        secondAccent.opacity((style == .radial || style == .conic || style == .mesh ? 0.2 : 0.12) * opacity),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
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
