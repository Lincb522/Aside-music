import UIKit
import SwiftUI

// MARK: - Basic Visual Effect Blur (UIKit)
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

// MARK: - Simple Blur Fallback
struct LiquidGlassBlur: View {
    var cornerRadius: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}

// MARK: - Aside Liquid Card
struct AsideLiquidCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content
    
    init(cornerRadius: CGFloat = 20, useMetal: Bool = false, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                LiquidGlassBlur(cornerRadius: cornerRadius)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - View Extensions
extension View {
    /// 毛玻璃背景
    func liquidGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(LiquidGlassBlur(cornerRadius: cornerRadius))
    }
    
    /// 液态玻璃样式（暂时回退到 SwiftUI material）
    func liquidGlassStyle(cornerRadius: CGFloat = 20, useMetal: Bool = false) -> some View {
        AsideLiquidCard(cornerRadius: cornerRadius) {
            self
        }
    }
}
