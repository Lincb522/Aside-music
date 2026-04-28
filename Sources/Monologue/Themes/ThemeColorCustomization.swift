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

enum ThemeCustomColorMode: String, CaseIterable, Identifiable {
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

enum ThemeCustomGradientStyle: String, CaseIterable, Identifiable {
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

struct ThemeColorPreset: Identifiable {
    let id: String
    let name: String
    let accentStartHex: String
    let accentEndHex: String
    let backgroundStartHex: String
    let backgroundEndHex: String
    let gradientStyle: ThemeCustomGradientStyle
    let mangaBlockAHex: String?
    let mangaBlockBHex: String?
    let mangaBlockCHex: String?
    let mangaStrokeHex: String?

    init(
        id: String,
        name: String,
        accentStartHex: String,
        accentEndHex: String,
        backgroundStartHex: String,
        backgroundEndHex: String,
        gradientStyle: ThemeCustomGradientStyle = .diffuse,
        mangaBlockAHex: String? = nil,
        mangaBlockBHex: String? = nil,
        mangaBlockCHex: String? = nil,
        mangaStrokeHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.accentStartHex = accentStartHex
        self.accentEndHex = accentEndHex
        self.backgroundStartHex = backgroundStartHex
        self.backgroundEndHex = backgroundEndHex
        self.gradientStyle = gradientStyle
        self.mangaBlockAHex = mangaBlockAHex
        self.mangaBlockBHex = mangaBlockBHex
        self.mangaBlockCHex = mangaBlockCHex
        self.mangaStrokeHex = mangaStrokeHex
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
        theme == .muji || theme == .manga || theme == .neumorphic
    }

    static func key(_ theme: GlobalThemeId, _ role: ThemeCustomColorRole, _ suffix: String) -> String {
        "themeColor.\(theme.rawValue).\(role.rawValue).\(suffix)"
    }

    static func mangaKey(_ suffix: String) -> String {
        "themeColor.manga.extra.\(suffix)"
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

    static func mangaHex(_ suffix: String, fallback: String) -> String {
        let stored = UserDefaults.standard.string(forKey: mangaKey(suffix))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored?.isEmpty == false ? stored! : fallback
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
                ThemeColorPreset(id: "manga-pop", name: "Pop", accentStartHex: "FF4F84", accentEndHex: "FF4F84", backgroundStartHex: "FFF3D7", backgroundEndHex: "E8F1FF", mangaBlockAHex: "FFE067", mangaBlockBHex: "58B9FF", mangaBlockCHex: "8DE4B8", mangaStrokeHex: "3B3145"),
                ThemeColorPreset(id: "manga-berry", name: "Berry", accentStartHex: "E65E8E", accentEndHex: "E65E8E", backgroundStartHex: "FFEAF0", backgroundEndHex: "F6F0FF", gradientStyle: .radial, mangaBlockAHex: "F8D957", mangaBlockBHex: "B7D8FF", mangaBlockCHex: "BDE9B8", mangaStrokeHex: "4B3A55"),
                ThemeColorPreset(id: "manga-soda", name: "Soda", accentStartHex: "4FA9FF", accentEndHex: "4FA9FF", backgroundStartHex: "EEF7FF", backgroundEndHex: "FFF1D8", gradientStyle: .diffuse, mangaBlockAHex: "FFE06A", mangaBlockBHex: "79C8FF", mangaBlockCHex: "94E2BC", mangaStrokeHex: "344B5E"),
                ThemeColorPreset(id: "manga-peach", name: "Peach", accentStartHex: "FF7A6E", accentEndHex: "FF7A6E", backgroundStartHex: "FFF0DF", backgroundEndHex: "FFE9F1", gradientStyle: .vertical, mangaBlockAHex: "FFD86B", mangaBlockBHex: "9AD7FF", mangaBlockCHex: "A8E7C0", mangaStrokeHex: "5C4052"),
                ThemeColorPreset(id: "manga-lime", name: "Lime", accentStartHex: "7FBF5B", accentEndHex: "7FBF5B", backgroundStartHex: "F7F6D9", backgroundEndHex: "EAF7EC", gradientStyle: .diagonal, mangaBlockAHex: "F6E56F", mangaBlockBHex: "8BCBFF", mangaBlockCHex: "92E3A7", mangaStrokeHex: "465F4D"),
                ThemeColorPreset(id: "manga-candy", name: "Candy", accentStartHex: "F06DA6", accentEndHex: "F06DA6", backgroundStartHex: "FFF0FA", backgroundEndHex: "EAF6FF", gradientStyle: .radial, mangaBlockAHex: "FFE47A", mangaBlockBHex: "98D9FF", mangaBlockCHex: "B2E9CF", mangaStrokeHex: "694E67"),
            ]
        case .default:
            return []
        }
    }

    static func isPresetSelected(_ preset: ThemeColorPreset, for theme: GlobalThemeId) -> Bool {
        guard supports(theme) else { return false }
        guard mode(for: theme, role: .accent) == .solid else { return false }

        if theme == .muji {
            guard mode(for: theme, role: .background) == .solid else { return false }
        } else {
            guard mode(for: theme, role: .background) == .gradient else { return false }
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

        if theme == .muji {
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

        let backgroundMode: ThemeCustomColorMode = theme == .muji ? .solid : .gradient
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
        }

        SettingsManager.shared.notifyThemeCustomizationChanged()
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

        if style == .diffuse {
            Canvas { context, _ in
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
