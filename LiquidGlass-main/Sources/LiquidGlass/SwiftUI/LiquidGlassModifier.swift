import SwiftUI

/// 液态玻璃背景修饰器
public struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let updateMode: SnapshotUpdateMode
    let blurScale: CGFloat
    let tintColor: UIColor

    public func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassView(
                    cornerRadius: cornerRadius,
                    updateMode: updateMode,
                    blurScale: blurScale,
                    tintColor: tintColor
                )
            )
    }
}

public extension View {
    /// 添加液态玻璃背景效果
    func liquidGlassBackground(
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(),
        blurScale: CGFloat = 0.3,
        tintColor: UIColor = .white.withAlphaComponent(0.1)
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                cornerRadius: cornerRadius,
                updateMode: updateMode,
                blurScale: blurScale,
                tintColor: tintColor
            )
        )
    }
}
