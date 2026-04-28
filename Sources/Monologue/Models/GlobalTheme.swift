import SwiftUI

// MARK: - 全局主题 ID

/// 全局主题枚举 — 控制整个 App 的视觉风格与布局结构
/// 与 PlayerTheme（播放器内部 17 种布局）完全独立，互不影响
enum GlobalThemeId: String, CaseIterable, Codable, Identifiable {
    case `default`     // 默认 — 当前 App 的原始样貌
    case muji          // 无印良品 — 极简暖色纸质感、大量留白
    case manga         // 漫画风 — 粗描边、硬阴影、网点背景
    case neumorphic    // 新拟物 — 柔和凸起、凹陷控件、低对比实体感

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:   return String(localized: "默认")
        case .muji:      return String(localized: "无印良品")
        case .manga:     return String(localized: "漫画风")
        case .neumorphic: return String(localized: "新拟物")
        }
    }

    var description: String {
        switch self {
        case .default:   return String(localized: "Monologue 原始设计风格")
        case .muji:      return String(localized: "极简纸质感，温暖呼吸感")
        case .manga:     return String(localized: "粗线描边，网点气泡，漫画世界")
        case .neumorphic: return String(localized: "柔软凸起与凹陷控件，安静的实体触感")
        }
    }

    var iconType: MonologueIcon.IconType {
        switch self {
        case .default:   return .playerTheme
        case .muji:      return .catLife
        case .manga:     return .catBook
        case .neumorphic: return .layers
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
