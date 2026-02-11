import UIKit
import SwiftUI
import LiquidGlassEffect

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

// MARK: - Aside Liquid Glass Card (本地版本，支持 fallback)
struct AsideLiquidCard<Content: View>: View {
    let cornerRadius: CGFloat
    let useMetal: Bool
    let content: Content
    
    init(cornerRadius: CGFloat = 20, useMetal: Bool = true, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.useMetal = useMetal
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                if useMetal {
                    // 使用新的 .liquidGlass 修饰器
                    Color.clear
                        .liquidGlass(config: .regular, cornerRadius: cornerRadius)
                } else {
                    LiquidGlassBlur(cornerRadius: cornerRadius)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - View Extensions
extension View {
    /// 毛玻璃背景（非 Metal）
    func liquidGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(LiquidGlassBlur(cornerRadius: cornerRadius))
    }
    
    /// Metal 液态玻璃背景（使用新 API）
    func liquidGlassMetal(cornerRadius: CGFloat = 20) -> some View {
        self.liquidGlass(config: .regular, cornerRadius: cornerRadius)
    }
    
    /// 液态玻璃样式（支持 Metal/非 Metal 切换）
    func liquidGlassStyle(cornerRadius: CGFloat = 20, useMetal: Bool = true) -> some View {
        AsideLiquidCard(cornerRadius: cornerRadius, useMetal: useMetal) {
            self
        }
    }
}
