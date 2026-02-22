import UIKit

public extension UIView {

    /// 添加液态玻璃背景效果
    @discardableResult
    func addLiquidGlassBackground(
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(interval: 0.2),
        blurScale: CGFloat = 0.5,
        tintColor: UIColor = .gray.withAlphaComponent(0.2)
    ) -> LiquidGlassUIView {
        let glassView = LiquidGlassUIView(
            cornerRadius: cornerRadius,
            updateMode: updateMode,
            blurScale: blurScale,
            tintColor: tintColor
        )
        glassView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(glassView, at: 0)
        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        return glassView
    }

    /// 移除所有液态玻璃背景
    func removeLiquidGlassBackgrounds() {
        subviews.compactMap { $0 as? LiquidGlassUIView }.forEach { $0.removeFromSuperview() }
    }

    /// 获取第一个液态玻璃背景视图
    var liquidGlassBackground: LiquidGlassUIView? {
        subviews.first { $0 is LiquidGlassUIView } as? LiquidGlassUIView
    }
}
