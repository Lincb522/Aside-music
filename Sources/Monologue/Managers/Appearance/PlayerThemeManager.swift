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
        if let theme = PlayerTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            // 已移除主题的旧存档统一迁移回经典。
            self.currentTheme = .classic
            UserDefaults.standard.set(PlayerTheme.classic.rawValue, forKey: AppConfig.StorageKeys.playerTheme)
        }
    }
    
    func setTheme(_ theme: PlayerTheme) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentTheme = theme
        }
    }
}
