import SwiftUI
import UIKit

struct AsideAnimation {
    
    // MARK: - Standard Curves
    
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    static let easeOut = Animation.easeOut(duration: 0.25)
    
    /// 按钮按压专用 — 快速响应，无弹跳延迟
    static let buttonPress = Animation.easeOut(duration: 0.1)
}

// MARK: - 全局边缘滑动防误触管理器

/// 监听返回手势状态，在滑动期间抑制按钮点击
final class EdgeSwipeGuard {
    static let shared = EdgeSwipeGuard()
    
    /// 当前是否正在进行边缘滑动手势
    private(set) var isSwiping = false
    
    /// 滑动结束后的冷却保护
    private var cooldownWorkItem: DispatchWorkItem?
    
    private init() {}
    
    func beginSwipe() {
        cooldownWorkItem?.cancel()
        isSwiping = true
    }
    
    func endSwipe() {
        cooldownWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.isSwiping = false
        }
        cooldownWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }
}

// MARK: - Button Styles

/// A button style that scales down when pressed, with edge-swipe mistouch protection
struct AsideBouncingButtonStyle: ButtonStyle {
    
    var scale: CGFloat = 0.92
    var opacity: CGFloat = 0.85
    var enableHaptic: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        let isSwiping = EdgeSwipeGuard.shared.isSwiping
        let effectivePressed = configuration.isPressed && !isSwiping
        
        configuration.label
            .scaleEffect(effectivePressed ? scale : 1.0)
            .opacity(effectivePressed ? opacity : 1.0)
            .animation(AsideAnimation.buttonPress, value: effectivePressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && enableHaptic && !EdgeSwipeGuard.shared.isSwiping {
                    HapticManager.shared.light()
                }
            }
    }
}

// MARK: - Extensions

extension View {
    func asideBouncing() -> some View {
        self.buttonStyle(AsideBouncingButtonStyle())
    }
    
    /// 带触觉反馈的点击手势
    func onTapWithHaptic(
        _ style: HapticStyle = .light,
        perform action: @escaping () -> Void
    ) -> some View {
        self.onTapGesture {
            style.trigger()
            action()
        }
    }
}

/// 触觉反馈样式
@MainActor
enum HapticStyle {
    case light
    case medium
    case heavy
    case soft
    case selection
    case success
    case warning
    case error
    case none
    
    func trigger() {
        switch self {
        case .light: HapticManager.shared.light()
        case .medium: HapticManager.shared.medium()
        case .heavy: HapticManager.shared.heavy()
        case .soft: HapticManager.shared.soft()
        case .selection: HapticManager.shared.selection()
        case .success: HapticManager.shared.success()
        case .warning: HapticManager.shared.warning()
        case .error: HapticManager.shared.error()
        case .none: break
        }
    }
}
