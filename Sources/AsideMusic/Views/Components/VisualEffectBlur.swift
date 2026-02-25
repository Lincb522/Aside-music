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

// MARK: - Liquid Glass 背景（iOS 26 原生，低版本 fallback ultraThinMaterial）
struct LiquidGlassBlur: View {
    var cornerRadius: CGFloat = 0
    var useFloatingBarFill: Bool = false
    
    var body: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(useFloatingBarFill ? Color.asideFloatingBarFill : Color.asideGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(useFloatingBarFill ? Color.asideFloatingBarFill : Color.asideMilk)
                )
        }
    }
}

// MARK: - Aside Liquid Card（iOS 26 原生 glassEffect，低版本 fallback）
struct AsideLiquidCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content
    
    init(cornerRadius: CGFloat = 20, useMetal: Bool = false, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.asideMilk)
                        )
                )
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Aside 统一液态玻璃效果（iOS 26+: glassEffect，低版本: ultraThinMaterial）
    @ViewBuilder
    func asideGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.asideMilk)
                    )
            )
        }
    }
    
    /// 圆形液态玻璃效果
    @ViewBuilder
    func asideGlassCircle() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .circle)
        } else {
            self.background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.asideMilk))
            )
        }
    }
    
    /// 胶囊形液态玻璃效果
    @ViewBuilder
    func asideGlassCapsule() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Color.asideMilk))
            )
        }
    }
    
    /// 毛玻璃背景（兼容旧调用）
    @ViewBuilder
    func liquidGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.asideMilk)
                    )
            )
        }
    }
    
    /// 液态玻璃样式（兼容旧调用）
    @ViewBuilder
    func liquidGlassStyle(cornerRadius: CGFloat = 20, useMetal: Bool = false) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.asideMilk)
                    )
            )
        }
    }
}

// MARK: - Shape 扩展：兼容 glassEffect 的 fill
extension Shape {
    /// Shape.fill(color).asideGlass(shape) — 低版本 fallback 到 material + 颜色叠加
    @ViewBuilder
    func fillWithGlass(_ color: Color = .asideGlassTint, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.fill(color).glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            ZStack {
                self.fill(.ultraThinMaterial)
                self.fill(color)
            }
        }
    }
    
    /// Shape.fill(color).glassEffect(.regular, in: .circle) 的兼容版
    @ViewBuilder
    func fillWithGlassCircle(_ color: Color = .asideGlassTint) -> some View {
        if #available(iOS 26, *) {
            self.fill(color).glassEffect(.regular, in: .circle)
        } else {
            ZStack {
                self.fill(.ultraThinMaterial)
                self.fill(color)
            }
        }
    }
}
