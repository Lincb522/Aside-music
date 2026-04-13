import Foundation

enum AppBrandStyle: String, CaseIterable, Identifiable {
    case monologue
    case aurora

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monologue:
            return String(localized: "settings_app_brand_monologue")
        case .aurora:
            return String(localized: "settings_app_brand_aurora")
        }
    }

    var detailText: String {
        switch self {
        case .monologue:
            return String(localized: "settings_app_brand_monologue_desc")
        case .aurora:
            return String(localized: "settings_app_brand_aurora_desc")
        }
    }

    func logoAssetName(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.monologue, .light):
            return "MonologueLogoLight"
        case (.monologue, .dark):
            return "MonologueLogoDark"
        case (.aurora, .light):
            return "AuroraLogoLight"
        case (.aurora, .dark):
            return "AuroraLogoDark"
        }
    }

    func previewAssetName(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.monologue, .light):
            return "MonologuePreviewLight"
        case (.monologue, .dark):
            return "MonologuePreviewDark"
        case (.aurora, .light):
            return "AuroraPreviewLight"
        case (.aurora, .dark):
            return "AuroraPreviewDark"
        }
    }

    func alternateIconName(for appearance: AppBrandAppearance) -> String? {
        switch (self, appearance) {
        case (.monologue, .light):
            return nil
        case (.monologue, .dark):
            return "MonologueDarkAppIcon"
        case (.aurora, .light):
            return "AuroraAppIcon"
        case (.aurora, .dark):
            return "AuroraDarkAppIcon"
        }
    }

    func previewBackgroundColor(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.monologue, .light):
            return "F3F0E9"
        case (.monologue, .dark):
            return "141417"
        case (.aurora, .light):
            return "F4F4F5"
        case (.aurora, .dark):
            return "111827"
        }
    }

    func logoPlateColors(for appearance: AppBrandAppearance) -> [String] {
        switch (self, appearance) {
        case (.monologue, .light):
            return ["FFFFFF", "E8EDF6"]
        case (.monologue, .dark):
            return ["21242C", "12151C"]
        case (.aurora, .light):
            return ["FFFFFF", "EEF2F8"]
        case (.aurora, .dark):
            return ["1A2234", "0E1524"]
        }
    }

    func logoPlateStrokeOpacity(for appearance: AppBrandAppearance) -> Double {
        switch appearance {
        case .light:
            return 0.4
        case .dark:
            return 0.14
        }
    }

    func logoGlowColor(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.monologue, .light):
            return "FFFFFF"
        case (.monologue, .dark):
            return "7186B5"
        case (.aurora, .light):
            return "FFFFFF"
        case (.aurora, .dark):
            return "7C90FF"
        }
    }
}
