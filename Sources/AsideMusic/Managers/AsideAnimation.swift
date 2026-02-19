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

// MARK: - Button Styles

/// A button style that scales down when pressed
struct AsideBouncingButtonStyle: ButtonStyle {
    
    var scale: CGFloat = 0.92
    var opacity: CGFloat = 0.85
    var enableHaptic: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(AsideAnimation.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && enableHaptic {
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
