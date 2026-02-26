import UIKit

@MainActor
struct DeviceLayout {
    /// 获取当前设备的顶部安全区域高度
    static var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }
    
    /// 获取当前设备的底部安全区域高度
    static var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
    
    /// 是否为刘海屏设备
    static var hasNotch: Bool { safeAreaTop >= 47 }
    
    /// 动态计算顶部 Padding
    static var headerTopPadding: CGFloat {
        hasNotch ? 8 : 50
    }
    
    /// 播放器底部 Padding（考虑安全区域）
    static var playerBottomPadding: CGFloat {
        hasNotch ? 40 : 20
    }
    
    /// 播放器封面最大尺寸（屏幕宽度 - 两侧间距）
    static var playerArtworkMaxSize: CGFloat {
        let screenWidth: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            screenWidth = windowScene.screen.bounds.width
        } else {
            screenWidth = 375
        }
        return min(screenWidth - 64, 360)
    }
    
    /// 播放器水平内边距
    static let playerHorizontalPadding: CGFloat = 32
}
