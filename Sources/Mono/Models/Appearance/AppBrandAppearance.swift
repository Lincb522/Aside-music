import Foundation

/// 品牌素材的明暗外观选择，与 `AppBrandStyle` 组合决定具体资源。
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
