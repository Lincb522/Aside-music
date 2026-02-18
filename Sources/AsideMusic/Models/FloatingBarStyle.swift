import Foundation

/// 悬浮栏样式枚举
enum FloatingBarStyle: String, Codable, CaseIterable, Identifiable {
    case unified     // 统一悬浮栏 - MiniPlayer + TabBar 合一
    case classic     // 经典模式 - 贴底不悬浮
    case minimal     // 极简模式 - 仅 MiniPlayer，无 TabBar（手势切换页面）
    case floatingBall // 悬浮球 - 黑胶唱片悬浮球 + 抽屉式 Tab
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .unified:      return NSLocalizedString("floating_bar_unified", comment: "")
        case .classic:      return NSLocalizedString("floating_bar_classic", comment: "")
        case .minimal:      return NSLocalizedString("floating_bar_minimal", comment: "")
        case .floatingBall: return NSLocalizedString("floating_bar_ball", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .unified:      return NSLocalizedString("floating_bar_unified_desc", comment: "")
        case .classic:      return NSLocalizedString("floating_bar_classic_desc", comment: "")
        case .minimal:      return NSLocalizedString("floating_bar_minimal_desc", comment: "")
        case .floatingBall: return NSLocalizedString("floating_bar_ball_desc", comment: "")
        }
    }
    
    var iconType: AsideIcon.IconType {
        switch self {
        case .unified:      return .layers
        case .classic:      return .tabBar
        case .minimal:      return .minimalBar
        case .floatingBall: return .floatingBall
        }
    }
}
