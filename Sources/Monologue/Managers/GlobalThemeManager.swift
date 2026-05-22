import SwiftUI

/// 全局主题引擎管理器
/// 负责持久化当前选中的全局主题，并提供 Token 快捷访问
@Observable
@MainActor
final class GlobalThemeManager {
    static let shared = GlobalThemeManager()

    // MARK: - 当前主题

    var currentThemeId: GlobalThemeId {
        didSet {
            UserDefaults.standard.set(currentThemeId.rawValue, forKey: "globalThemeId")
            _cachedProvider = nil
            tokenRevision &+= 1
        }
    }

    /// 主题 token 刷新版本。配色变更时即使主题 ID 不变，也要让读取全局 token 的视图重新计算。
    var tokenRevision: Int = 0

    /// 当前主题的 Provider 实例
    var current: GlobalThemeProvider {
        let _ = tokenRevision
        if let cached = _cachedProvider { return cached }
        let provider = Self.makeProvider(for: currentThemeId)
        _cachedProvider = provider
        return provider
    }

    func provider(for id: GlobalThemeId) -> GlobalThemeProvider {
        Self.makeProvider(for: Self.resolveRemovedTheme(id))
    }

    // MARK: - Token 快捷访问

    var colors: GlobalColorPalette {
        current.colorPalette
    }

    var typography: GlobalTypography {
        current.typography
    }

    var shapes: GlobalShapeLanguage {
        current.shapeLanguage
    }

    var icons: GlobalIconStyle {
        current.iconStyle
    }

    var animations: GlobalAnimationStyle {
        current.animationStyle
    }

    // MARK: - 是否为当前新安装默认主题

    var isDefault: Bool {
        currentThemeId == GlobalThemeId.appDefault
    }

    // MARK: - 初始化

    @ObservationIgnored
    private var _cachedProvider: GlobalThemeProvider?

    private init() {
        let raw = UserDefaults.standard.string(forKey: "globalThemeId") ?? GlobalThemeId.appDefault.rawValue
        let restored = Self.resolveStoredTheme(raw)
        currentThemeId = Self.resolveRemovedTheme(restored)
        if currentThemeId.rawValue != raw {
            UserDefaults.standard.set(currentThemeId.rawValue, forKey: "globalThemeId")
        }
    }

    // MARK: - 主题工厂

    private static func makeProvider(for id: GlobalThemeId) -> GlobalThemeProvider {
        switch id {
        case .default: return DefaultThemeProvider()
        case .muji: return MujiThemeProvider()
        case .manga: return MangaThemeProvider()
        case .neumorphic: return NeumorphicThemeProvider()
        case .capsule: return CapsuleThemeProvider()
        case .petWhite: return PetWhiteThemeProvider()
        case .pureWhite: return DefaultThemeProvider()
        case .material3Expressive: return DefaultThemeProvider()
        case .bento: return DefaultThemeProvider()
        case .sequoia: return DefaultThemeProvider()
        case .liquidGlass: return DefaultThemeProvider()
        case .clay: return DefaultThemeProvider()
        case .signal: return DefaultThemeProvider()
        }
    }

    // MARK: - 切换

    func switchTheme(to id: GlobalThemeId) {
        let resolvedId = Self.resolveRemovedTheme(id)
        guard resolvedId != currentThemeId else { return }
        currentThemeId = resolvedId
    }

    func refreshCurrentThemeTokens() {
        _cachedProvider = nil
        tokenRevision &+= 1
    }

    private static func resolveRemovedTheme(_ id: GlobalThemeId) -> GlobalThemeId {
        switch id {
        case .pureWhite, .bento, .clay, .signal, .liquidGlass, .sequoia, .material3Expressive:
            return .default
        default:
            return id
        }
    }

    private static func resolveStoredTheme(_ raw: String) -> GlobalThemeId {
        if raw == "doodlePop" { return .default }
        return GlobalThemeId(rawValue: raw) ?? .appDefault
    }
}
