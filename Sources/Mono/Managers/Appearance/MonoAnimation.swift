import SwiftUI
import UIKit

struct MonoAnimation {
    
    // MARK: - Standard Curves
    
    /// 弹性动画 — 适合元素出现、弹入
    static let bouncy = Animation.spring(response: 0.32, dampingFraction: 0.72, blendDuration: 0)
    /// 平滑动画 — 适合大面积过渡、背景变化
    static let smooth = Animation.spring(response: 0.34, dampingFraction: 0.86, blendDuration: 0)
    /// 灵敏动画 — 适合 Tab 切换、小元素交互
    static let snappy = Animation.spring(response: 0.22, dampingFraction: 0.76, blendDuration: 0)
    /// 缓出 — 适合淡入淡出
    static let easeOut = Animation.easeOut(duration: 0.16)
    /// 按钮按压专用 — 快速响应，无弹跳延迟
    static let buttonPress = Animation.easeOut(duration: 0.08)
    
    // MARK: - Contextual Presets
    
    /// 页面/Tab 切换 — 快速但不突兀
    static let tabSwitch = Animation.spring(response: 0.18, dampingFraction: 0.95)
    /// 面板展开/收起 — 稍慢，有质感
    static let panelToggle = Animation.spring(response: 0.32, dampingFraction: 0.85)
    /// 浮动栏变形成迷你播放器、出入场
    static let floatingBar = Animation.spring(response: 0.26, dampingFraction: 0.92)
    /// 全屏播放器打开/关闭。使用接近临界阻尼的长一点曲线，避免浮栏、遮罩和
    /// 播放器容器分别到位时产生两段式跳变。
    static let playerTransition = Animation.spring(response: 0.40, dampingFraction: 0.92, blendDuration: 0.08)
    /// 微交互 — 图标高亮、颜色变化
    static let micro = Animation.easeOut(duration: 0.12)
    /// 内容淡入 — 列表项、卡片出现
    static let contentAppear = Animation.easeOut(duration: 0.16)
}

// MARK: - 全局边缘滑动防误触管理器

/// 监听返回手势状态，在滑动期间抑制按钮点击
final class EdgeSwipeGuard: @unchecked Sendable {
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
struct MonoBouncingButtonStyle: ButtonStyle {
    
    var scale: CGFloat = 0.92
    var opacity: CGFloat = 0.85
    var enableHaptic: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        let isSwiping = EdgeSwipeGuard.shared.isSwiping
        let effectivePressed = configuration.isPressed && !isSwiping
        
        configuration.label
            // SwiftUI 默认只命中实际绘制出的像素；列表行中的 Spacer 和透明
            // 留白因此经常无法点击。统一把按钮 label 的布局矩形作为命中区。
            .contentShape(Rectangle())
            .scaleEffect(effectivePressed ? scale : 1.0)
            .opacity(effectivePressed ? opacity : 1.0)
            .animation(MonoAnimation.buttonPress, value: effectivePressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && enableHaptic && !EdgeSwipeGuard.shared.isSwiping {
                    HapticManager.shared.light()
                }
            }
    }
}

// MARK: - Extensions

extension View {
    func monoBouncing() -> some View {
        self.buttonStyle(MonoBouncingButtonStyle())
    }
    
    /// 带触觉反馈的点击手势
    func onTapWithHaptic(
        _ style: HapticStyle = .light,
        perform action: @escaping () -> Void
    ) -> some View {
        self
            .contentShape(Rectangle())
            .onTapGesture {
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
