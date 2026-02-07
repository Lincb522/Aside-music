import SwiftUI
import Combine

/// 全局设置管理器
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - 外观设置
    
    /// 是否启用液态玻璃效果
    @AppStorage("liquidGlassEnabled") var liquidGlassEnabled: Bool = true {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// 主题模式: "system" 跟随系统, "light" 浅色, "dark" 深色
    @AppStorage("themeMode") var themeMode: String = "system" {
        didSet {
            objectWillChange.send()
            applyTheme()
        }
    }
    
    /// 实际生效的 ColorScheme，始终有明确值
    @Published var activeColorScheme: ColorScheme = .light
    
    /// 根据设置返回对应的 ColorScheme（用于 .preferredColorScheme 修饰符）
    var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // 跟随系统
        }
    }
    
    /// 应用主题到所有窗口（确保 fullScreenCover 等独立层级也能实时生效）
    func applyTheme() {
        let style: UIUserInterfaceStyle
        switch themeMode {
        case "light": style = .light
        case "dark": style = .dark
        default: style = .unspecified // 跟随系统
        }
        
        // 遍历所有窗口场景，强制刷新 overrideUserInterfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
        
        // 更新 activeColorScheme
        if style == .dark {
            activeColorScheme = .dark
        } else if style == .light {
            activeColorScheme = .light
        } else {
            // 跟随系统：读取当前系统实际值
            let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
            activeColorScheme = systemIsDark ? .dark : .light
        }
    }
    
    // MARK: - 播放设置
    
    /// 音质设置
    @AppStorage("soundQuality") var soundQuality: String = "standard"
    
    /// 自动播放下一首
    @AppStorage("autoPlayNext") var autoPlayNext: Bool = true
    
    /// 启用解灰（灰色歌曲自动匹配其他音源）
    @AppStorage("unblockEnabled") var unblockEnabled: Bool = true
    
    // MARK: - 缓存设置
    
    /// 最大缓存大小 (MB)
    @AppStorage("maxCacheSize") var maxCacheSize: Int = 500
    
    // MARK: - 其他设置
    
    /// 触感反馈
    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true
    
    private init() {
        // 启动时应用一次主题
        applyTheme()
    }
}
