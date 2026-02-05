import UIKit

struct DeviceLayout {
    /// 获取当前设备的顶部安全区域高度
    static var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }
    
    /// 动态计算顶部 Padding
    /// 基于实际安全区域高度智能适配：
    /// - 刘海屏 (safeTop ≈ 47-59): 安全区域已经足够，只需要很小的额外间距
    /// - 非刘海屏 (safeTop ≈ 20): 需要更多间距以保持视觉平衡
    static var headerTopPadding: CGFloat {
        let safeTop = safeAreaTop
        
        // 刘海屏设备 safeAreaTop 通常 >= 47
        // 非刘海屏设备 safeAreaTop 通常 ≈ 20 (状态栏高度)
        if safeTop >= 47 {
            return 8  // 刘海屏设备：只需微小间距
        } else {
            return 50 // 非刘海屏设备 (如 SE)：保持视觉平衡
        }
    }
}
