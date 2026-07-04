import SwiftUI

/// 播放器主题管理器
@MainActor
final class PlayerThemeManager: ObservableObject {
    static let shared = PlayerThemeManager()
    
    @Published var currentTheme: PlayerTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: AppConfig.StorageKeys.playerTheme)
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playerTheme) ?? ""
        if let theme = PlayerTheme(rawValue: saved), theme != .cinema {
            self.currentTheme = theme
        } else {
            // 影院已从主题体系移出（改为沉浸模式入口），旧存档迁移回经典
            self.currentTheme = .classic
        }
    }
    
    func setTheme(_ theme: PlayerTheme) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentTheme = theme
        }
    }
}
