import SwiftUI

/// 全局主题引擎管理器
/// 负责持久化当前选中的全局主题，并提供 Token 快捷访问
@MainActor
final class GlobalThemeManager: ObservableObject {
    static let shared = GlobalThemeManager()

    // MARK: - 当前主题

    @Published var currentThemeId: GlobalThemeId {
        didSet {
            UserDefaults.standard.set(currentThemeId.rawValue, forKey: GlobalThemeId.storageKey)
            _cachedProvider = nil
            tokenRevision &+= 1
        }
    }

    /// 主题 token 刷新版本。配色变更时即使主题 ID 不变，也要让读取全局 token 的视图重新计算。
    @Published var tokenRevision: Int = 0

    /// 当前主题的 Provider 实例
    var current: GlobalThemeProvider {
        let _ = tokenRevision
        if let cached = _cachedProvider { return cached }
        let provider = Self.makeProvider(for: currentThemeId)
        _cachedProvider = provider
        return provider
    }

    func provider(for id: GlobalThemeId) -> GlobalThemeProvider {
        Self.makeProvider(for: id)
    }

    // MARK: - Token 快捷访问

    var colors: GlobalColorPalette {
        UnifiedColorEngine.shared.isStarted
            ? UnifiedColorEngine.shared.colors
            : current.colorPalette
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

    private var _cachedProvider: GlobalThemeProvider?

    private init() {
        let raw = UserDefaults.standard.string(forKey: GlobalThemeId.storageKey)
        currentThemeId = GlobalThemeId.resolvedStoredTheme(raw)
        if raw != Optional(currentThemeId.rawValue) {
            UserDefaults.standard.set(currentThemeId.rawValue, forKey: GlobalThemeId.storageKey)
        }
    }

    // MARK: - 主题工厂

    private static func makeProvider(for id: GlobalThemeId) -> GlobalThemeProvider {
        switch id {
        case .default: return DefaultThemeProvider()
        case .muji: return MujiThemeProvider()
        case .manga: return DefaultThemeProvider()
        case .neumorphic: return NeumorphicThemeProvider()
        case .capsule: return CapsuleThemeProvider()
        case .petWhite: return PetWhiteThemeProvider()
        case .minimalWhite: return MinimalWhiteThemeProvider()
        case .clarity: return ClarityThemeProvider()
        }
    }

    // MARK: - 切换

    func switchTheme(to id: GlobalThemeId) {
        let resolved = id == .manga ? GlobalThemeId.appDefault : id
        guard resolved != currentThemeId else { return }
        currentThemeId = resolved
    }

    func refreshCurrentThemeTokens() {
        _cachedProvider = nil
        tokenRevision &+= 1
    }

}
