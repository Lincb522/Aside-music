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
        }
    }

    /// 当前主题的 Provider 实例
    var current: GlobalThemeProvider {
        if let cached = _cachedProvider { return cached }
        let provider = Self.makeProvider(for: currentThemeId)
        _cachedProvider = provider
        return provider
    }

    // MARK: - Token 快捷访问

    var colors: GlobalColorPalette { current.colorPalette }
    var typography: GlobalTypography { current.typography }
    var shapes: GlobalShapeLanguage { current.shapeLanguage }
    var icons: GlobalIconStyle { current.iconStyle }
    var animations: GlobalAnimationStyle { current.animationStyle }

    // MARK: - 是否为默认主题

    var isDefault: Bool { currentThemeId == .default }

    // MARK: - 初始化

    @ObservationIgnored
    private var _cachedProvider: GlobalThemeProvider?

    private init() {
        let raw = UserDefaults.standard.string(forKey: "globalThemeId") ?? GlobalThemeId.default.rawValue
        self.currentThemeId = GlobalThemeId(rawValue: raw) ?? .default
    }

    // MARK: - 主题工厂

    private static func makeProvider(for id: GlobalThemeId) -> GlobalThemeProvider {
        switch id {
        case .default:   return DefaultThemeProvider()
        case .muji:      return MujiThemeProvider()
        case .manga:     return MangaThemeProvider()
        }
    }

    // MARK: - 切换

    func switchTheme(to id: GlobalThemeId) {
        guard id != currentThemeId else { return }
        currentThemeId = id
    }
}
