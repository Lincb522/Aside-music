import SwiftUI

/// 播放器主题管理器
@MainActor @Observable
final class PlayerThemeManager {
    static let shared = PlayerThemeManager()
    
    var currentTheme: PlayerTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: AppConfig.StorageKeys.playerTheme)
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: AppConfig.StorageKeys.playerTheme) ?? ""
        self.currentTheme = PlayerTheme(rawValue: saved) ?? .classic
    }
    
    func setTheme(_ theme: PlayerTheme) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentTheme = theme
        }
    }
}
