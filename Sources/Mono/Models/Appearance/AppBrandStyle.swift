import Foundation

/// App 品牌风格（Logo/图标套装），每种风格提供浅/深两套素材与配色。
/// 注：`musicCatColor` 为隐藏彩蛋款，不在设置页展示文案（displayName 为空）。
enum AppBrandStyle: String, CaseIterable, Identifiable {
    case mono
    case aurora
    case musicCat
    case paw
    case pawMono
    case musicCatColor

    var id: String { rawValue }

    /// 自定义的设置页展示顺序（非声明顺序）。
    static var allCases: [AppBrandStyle] {
        [.paw, .aurora, .musicCat, .mono, .pawMono, .musicCatColor]
    }

    var displayName: String {
        switch self {
        case .mono:
            return String(localized: "settings_app_brand_mono")
        case .aurora:
            return String(localized: "settings_app_brand_aurora")
        case .musicCat:
            return String(localized: "settings_app_brand_music_cat")
        case .musicCatColor:
            return ""
        case .paw:
            return String(localized: "settings_app_brand_paw")
        case .pawMono:
            return String(localized: "settings_app_brand_paw_mono")
        }
    }

    var detailText: String {
        switch self {
        case .mono:
            return String(localized: "settings_app_brand_mono_desc")
        case .aurora:
            return String(localized: "settings_app_brand_aurora_desc")
        case .musicCat:
            return String(localized: "settings_app_brand_music_cat_desc")
        case .musicCatColor:
            return ""
        case .paw:
            return String(localized: "settings_app_brand_paw_desc")
        case .pawMono:
            return String(localized: "settings_app_brand_paw_mono_desc")
        }
    }

    func logoAssetName(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.mono, .light):
            return "MonoLogoLight"
        case (.mono, .dark):
            return "MonoLogoDark"
        case (.aurora, .light):
            return "AuroraLogoLight"
        case (.aurora, .dark):
            return "AuroraLogoDark"
        case (.musicCat, .light):
            return "MusicCatLogoLight"
        case (.musicCat, .dark):
            return "MusicCatLogoDark"
        case (.musicCatColor, .light):
            return "MusicCatColorLogoLight"
        case (.musicCatColor, .dark):
            return "MusicCatColorLogoDark"
        case (.paw, .light):
            return "PawLogoLight"
        case (.paw, .dark):
            return "PawLogoDark"
        case (.pawMono, .light):
            return "PawMonoLogoLight"
        case (.pawMono, .dark):
            return "PawMonoLogoDark"
        }
    }

    func previewAssetName(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.mono, .light):
            return "MonoPreviewLight"
        case (.mono, .dark):
            return "MonoPreviewDark"
        case (.aurora, .light):
            return "AuroraPreviewLight"
        case (.aurora, .dark):
            return "AuroraPreviewDark"
        case (.musicCat, .light):
            return "MusicCatPreviewLight"
        case (.musicCat, .dark):
            return "MusicCatPreviewDark"
        case (.musicCatColor, .light):
            return "MusicCatColorPreviewLight"
        case (.musicCatColor, .dark):
            return "MusicCatColorPreviewDark"
        case (.paw, .light):
            return "PawPreviewLight"
        case (.paw, .dark):
            return "PawPreviewDark"
        case (.pawMono, .light):
            return "PawMonoPreviewLight"
        case (.pawMono, .dark):
            return "PawMonoPreviewDark"
        }
    }

    /// 对应的备选 App 图标名；返回 nil 表示使用主图标。
    func alternateIconName(for appearance: AppBrandAppearance) -> String? {
        switch (self, appearance) {
        case (.mono, .light):
            return "AppIcon"
        case (.mono, .dark):
            return "MonoDarkAppIcon"
        case (.aurora, .light):
            return "AuroraAppIcon"
        case (.aurora, .dark):
            return "AuroraDarkAppIcon"
        case (.musicCat, .light):
            return "MusicCatAppIcon"
        case (.musicCat, .dark):
            return "MusicCatDarkAppIcon"
        case (.musicCatColor, .light):
            return "MusicCatColorAppIcon"
        case (.musicCatColor, .dark):
            return "MusicCatColorDarkAppIcon"
        case (.paw, .light):
            return nil
        case (.paw, .dark):
            return "PawDarkAppIcon"
        case (.pawMono, .light):
            return "PawMonoAppIcon"
        case (.pawMono, .dark):
            return "PawMonoDarkAppIcon"
        }
    }

    /// 设置页预览卡片的背景色（hex）。
    func previewBackgroundColor(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.mono, .light):
            return "F3F0E9"
        case (.mono, .dark):
            return "141417"
        case (.aurora, .light):
            return "F4F4F5"
        case (.aurora, .dark):
            return "111827"
        case (.musicCat, .light):
            return "FFFFFF"
        case (.musicCat, .dark):
            return "08080A"
        case (.musicCatColor, .light):
            return "F7E7C6"
        case (.musicCatColor, .dark):
            return "071425"
        case (.paw, .light):
            return "F8B70F"
        case (.paw, .dark):
            return "081225"
        case (.pawMono, .light):
            return "F8F8F6"
        case (.pawMono, .dark):
            return "030303"
        }
    }

    /// Logo 底板渐变色（hex，从上到下）。
    func logoPlateColors(for appearance: AppBrandAppearance) -> [String] {
        switch (self, appearance) {
        case (.mono, .light):
            return ["FFFFFF", "E8EDF6"]
        case (.mono, .dark):
            return ["21242C", "12151C"]
        case (.aurora, .light):
            return ["FFFFFF", "EEF2F8"]
        case (.aurora, .dark):
            return ["1A2234", "0E1524"]
        case (.musicCat, .light):
            return ["FFFFFF", "F4F4F4"]
        case (.musicCat, .dark):
            return ["141414", "050506"]
        case (.musicCatColor, .light):
            return ["FFF5D9", "E4F7FA"]
        case (.musicCatColor, .dark):
            return ["0C2435", "030815"]
        case (.paw, .light):
            return ["FFE07A", "F6A70A"]
        case (.paw, .dark):
            return ["14213B", "030A19"]
        case (.pawMono, .light):
            return ["FFFFFF", "EEF2F8"]
        case (.pawMono, .dark):
            return ["171717", "020202"]
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

    /// Logo 周围光晕颜色（hex）。
    func logoGlowColor(for appearance: AppBrandAppearance) -> String {
        switch (self, appearance) {
        case (.mono, .light):
            return "FFFFFF"
        case (.mono, .dark):
            return "7186B5"
        case (.aurora, .light):
            return "FFFFFF"
        case (.aurora, .dark):
            return "7C90FF"
        case (.musicCat, .light):
            return "FFFFFF"
        case (.musicCat, .dark):
            return "F4F1E8"
        case (.musicCatColor, .light):
            return "A9E8F0"
        case (.musicCatColor, .dark):
            return "4FC0D0"
        case (.paw, .light):
            return "FFCC4A"
        case (.paw, .dark):
            return "F8F6F1"
        case (.pawMono, .light):
            return "FFFFFF"
        case (.pawMono, .dark):
            return "FFFFFF"
        }
    }
}
