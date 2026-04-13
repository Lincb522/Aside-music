import Foundation

enum AppBrandAppearance: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light:
            return String(localized: "settings_app_brand_appearance_light")
        case .dark:
            return String(localized: "settings_app_brand_appearance_dark")
        }
    }

    var detailText: String {
        switch self {
        case .light:
            return String(localized: "settings_app_brand_appearance_light_desc")
        case .dark:
            return String(localized: "settings_app_brand_appearance_dark_desc")
        }
    }
}
