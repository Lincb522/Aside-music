import SwiftUI

// MARK: - 全局主题 ID

/// 全局主题枚举 — 控制整个 App 的视觉风格与布局结构
/// 与 PlayerTheme（播放器内部 17 种布局）完全独立，互不影响
enum GlobalThemeId: String, CaseIterable, Codable, Identifiable, Sendable {
    case `default`     // 经典 Aside — 原本的默认主题，保留 rawValue/文件名用于兼容
    case muji          // 无印良品 — 极简暖色纸质感、大量留白
    case manga         // 漫画风 — 粗描边、硬阴影、网点背景
    case neumorphic    // 新拟物 — 柔和凸起、凹陷控件、低对比实体感
    case capsule       // Capsule OS — 胶囊模块化系统界面
    case petWhite      // Paw · 黏土玩具 — 厚圆角黏土块、马卡龙糖果色、squishy 按压（可选主题）
    case minimalWhite  // 纯白极简 — 纯白表面、轻分隔、克制层级

    var id: String { rawValue }

    /// 当前新安装默认主题是经典 Aside（`.default`）；Paw 等为可选主题。
    static let appDefault: GlobalThemeId = .default
    static let storageKey = "globalThemeId"
    private static let removedRawValues: Set<String> = [
        "doodlePop",
        "pureWhite",
        "material3Expressive",
        "bento",
        "sequoia",
        "liquidGlass",
        "clay",
        "signal"
    ]

    static var persistedOrDefault: GlobalThemeId {
        resolvedStoredTheme(UserDefaults.standard.string(forKey: storageKey))
    }

    static func resolvedStoredTheme(_ raw: String?) -> GlobalThemeId {
        guard let raw, !removedRawValues.contains(raw) else { return appDefault }
        return GlobalThemeId(rawValue: raw) ?? appDefault
    }

    var displayName: String {
        switch self {
        case .default:
            return String(localized: "global_theme_classic_name")
        case .muji:
            return String(localized: "无印良品")
        case .manga:
            return String(localized: "漫画风")
        case .neumorphic:
            return String(localized: "新拟物")
        case .capsule:
            return "Capsule OS"
        case .petWhite:
            return String(localized: "global_theme_pet_white_name")
        case .minimalWhite:
            return String(localized: "global_theme_minimal_white_name")
        }
    }

    var description: String {
        switch self {
        case .default:
            return String(localized: "global_theme_classic_description")
        case .muji:
            return String(localized: "极简纸质感，温暖呼吸感")
        case .manga:
            return String(localized: "粗线描边，网点气泡，漫画世界")
        case .neumorphic:
            return String(localized: "柔软凸起与凹陷控件，安静的实体触感")
        case .capsule:
            return String(localized: "胶囊模块化音乐系统")
        case .petWhite:
            return String(localized: "global_theme_pet_white_description")
        case .minimalWhite:
            return ""
        }
    }

    var iconType: MonoIcon.IconType {
        switch self {
        case .default:
            return .playerTheme
        case .muji:
            return .catLife
        case .manga:
            return .catBook
        case .neumorphic:
            return .layers
        case .capsule:
            return .layers
        case .petWhite:
            return .catLife
        case .minimalWhite:
            return .sparkle
        }
    }
}

// MARK: - 全局主题协议

/// 每个全局主题包必须实现此协议
/// 提供视觉 Token + 页面布局工厂
@MainActor
protocol GlobalThemeProvider {
    /// 主题 ID
    var id: GlobalThemeId { get }

    // ── 视觉 Token ──
    var colorPalette: GlobalColorPalette { get }
    var typography: GlobalTypography { get }
    var shapeLanguage: GlobalShapeLanguage { get }
    var iconStyle: GlobalIconStyle { get }
    var animationStyle: GlobalAnimationStyle { get }

    // ── 布局工厂 ──
    // 每个页面的布局由主题决定
    // Default 主题直接返回现有视图，其他主题返回自定义视图

    @ViewBuilder func makeHomeView() -> AnyView
    @ViewBuilder func makePodcastView() -> AnyView
    @ViewBuilder func makeSearchView() -> AnyView
    @ViewBuilder func makeLibraryView() -> AnyView
    @ViewBuilder func makeProfileView() -> AnyView

    // 本地模式页面
    @ViewBuilder func makeLocalHomeView() -> AnyView
    @ViewBuilder func makeLocalMusicView() -> AnyView
    @ViewBuilder func makeLocalLibraryView() -> AnyView
    @ViewBuilder func makeLocalProfileView() -> AnyView

    /// 可选：主题推荐的默认播放器主题（nil = 不干预）
    var suggestedPlayerTheme: PlayerTheme? { get }
}

// MARK: - 协议默认实现

extension GlobalThemeProvider {
    /// 默认不推荐播放器主题
    var suggestedPlayerTheme: PlayerTheme? { nil }

    func makePodcastView() -> AnyView { AnyView(PodcastView()) }

    // 本地模式默认同在线模式（多数主题不需要区分）
    func makeLocalHomeView() -> AnyView { makeHomeView() }
    func makeLocalMusicView() -> AnyView { makeLibraryView() }
    func makeLocalLibraryView() -> AnyView { makeLibraryView() }
    func makeLocalProfileView() -> AnyView { makeProfileView() }
}
