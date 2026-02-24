import UIKit
import SwiftUI

// MARK: - Basic Visual Effect Blur (UIKit 兼容)
@available(*, deprecated, message: "使用 .glassEffect() 替代")
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    var cornerRadius: CGFloat = 0
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
        uiView.layer.cornerRadius = cornerRadius
    }
}

// MARK: - Liquid Glass 背景（iOS 26 原生）
struct LiquidGlassBlur: View {
    var cornerRadius: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Aside Liquid Card（iOS 26 原生 glassEffect）
struct AsideLiquidCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content
    
    init(cornerRadius: CGFloat = 20, useMetal: Bool = false, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - View Extensions
extension View {
    /// Aside 统一液态玻璃效果（iOS 26 原生）
    /// 替代之前的 .ultraThinMaterial + asideGlassOverlay 组合
    func asideGlass(cornerRadius: CGFloat = 16) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
    
    /// 圆形液态玻璃效果
    func asideGlassCircle() -> some View {
        self.glassEffect(.regular, in: .circle)
    }
    
    /// 毛玻璃背景（兼容旧调用）
    func liquidGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
    
    /// 液态玻璃样式（兼容旧调用）
    func liquidGlassStyle(cornerRadius: CGFloat = 20, useMetal: Bool = false) -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
