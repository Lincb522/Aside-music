import Foundation
import SwiftUI
import UIKit

extension ThemeColorCustomization {
    // MARK: - 夜间背景（默认主题）


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
        darkBackgroundKind(for: theme) == .image
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

    static func contrastRatio(
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

    static func resolvedLuminance(of color: Color) -> CGFloat {
        resolvedLuminance(of: color, interfaceStyle: nil)
    }

    static func resolvedLuminance(
        of color: Color,
        interfaceStyle: UIUserInterfaceStyle?
    ) -> CGFloat {
        let rgba = resolvedRGBA(of: color, interfaceStyle: interfaceStyle)
        let compositedRed = rgba.red * rgba.alpha + (1 - rgba.alpha)
        let compositedGreen = rgba.green * rgba.alpha + (1 - rgba.alpha)
        let compositedBlue = rgba.blue * rgba.alpha + (1 - rgba.alpha)
        return 0.299 * compositedRed + 0.587 * compositedGreen + 0.114 * compositedBlue
    }

    struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    static func resolvedRGBA(
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

    static func composite(_ foreground: RGBA, over background: RGBA) -> RGBA {
        let alpha = foreground.alpha + background.alpha * (1 - foreground.alpha)
        guard alpha > 0 else { return RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
        return RGBA(
            red: (foreground.red * foreground.alpha + background.red * background.alpha * (1 - foreground.alpha)) / alpha,
            green: (foreground.green * foreground.alpha + background.green * background.alpha * (1 - foreground.alpha)) / alpha,
            blue: (foreground.blue * foreground.alpha + background.blue * background.alpha * (1 - foreground.alpha)) / alpha,
            alpha: alpha
        )
    }

    static func relativeLuminance(of color: RGBA) -> CGFloat {
        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(color.red)
            + 0.7152 * linearize(color.green)
            + 0.0722 * linearize(color.blue)
    }

}
