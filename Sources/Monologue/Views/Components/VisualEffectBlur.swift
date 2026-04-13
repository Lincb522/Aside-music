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
                .fill(useFloatingBarFill ? Color.monologueFloatingBarFill : Color.monologueGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(useFloatingBarFill ? Color.monologueFloatingBarFill : Color.monologueMilk)
                )
        }
    }
}

// MARK: - Monologue Liquid Card（iOS 26 原生 glassEffect，低版本 fallback）
struct MonologueLiquidCard<Content: View>: View {
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
                                .fill(Color.monologueMilk)
                        )
                )
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Monologue 统一液态玻璃效果（iOS 26+: glassEffect，低版本: ultraThinMaterial）
    @ViewBuilder
    func monologueGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.monologueMilk)
                    )
            )
        }
    }
    
    /// 圆形液态玻璃效果
    @ViewBuilder
    func monologueGlassCircle() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .circle)
        } else {
            self.background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.monologueMilk))
            )
        }
    }
    
    /// 胶囊形液态玻璃效果
    @ViewBuilder
    func monologueGlassCapsule() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Color.monologueMilk))
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
                            .fill(Color.monologueMilk)
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
                            .fill(Color.monologueMilk)
                    )
            )
        }
    }

    /// 无圆角矩形液态玻璃效果
    @ViewBuilder
    func monologueGlassPlainRect() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect)
        } else {
            self.background(Rectangle().fill(.ultraThinMaterial))
        }
    }

    /// 染色液态玻璃效果
    @ViewBuilder
    func monologueGlassTinted(_ tint: Color) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(Glass.regular.tint(tint), in: .circle)
        } else {
            self.background(Circle().fill(.ultraThinMaterial).overlay(Circle().fill(tint.opacity(0.3))))
        }
    }

    /// 条件液态玻璃效果
    @ViewBuilder
    func monologueGlassConditional(isActive: Bool, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(isActive ? .regular : .clear, in: .rect(cornerRadius: cornerRadius))
        } else if isActive {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.monologueMilk))
            )
        } else {
            self
        }
    }

    /// 条件液态玻璃 (identity vs regular)
    @ViewBuilder
    func monologueGlassIdentityOrRegular(isIdentity: Bool, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(isIdentity ? .identity : .regular, in: .rect(cornerRadius: cornerRadius))
        } else if !isIdentity {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.monologueMilk))
            )
        } else {
            self
        }
    }

    /// backgroundExtensionEffect 兼容
    @ViewBuilder
    func monologueBackgroundExtension() -> some View {
        if #available(iOS 26, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
    }

    /// glassEffectID 兼容（低版本 no-op）
    @ViewBuilder
    func monologueGlassID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    /// buttonStyle(.glass) 兼容
    @ViewBuilder
    func monologueGlassButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.plain)
        }
    }
}

// MARK: - onScrollGeometryChange 兼容
struct MonologueScrollGeometryModifier: ViewModifier {
    @Binding var scrollOffset: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    min(geometry.contentOffset.y + geometry.contentInsets.top, 0)
                } action: { _, offset in
                    scrollOffset = offset
                }
        } else {
            content
        }
    }
}

extension View {
    func monologueScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        modifier(MonologueScrollGeometryModifier(scrollOffset: offset))
    }
}

// MARK: - GlassEffectContainer 兼容
struct MonologueGlassContainer<Content: View>: View {
    let spacing: CGFloat?
    let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            if let spacing {
                GlassEffectContainer(spacing: spacing) { content }
            } else {
                GlassEffectContainer { content }
            }
        } else {
            content
        }
    }
}

// MARK: - Shape 扩展：兼容 glassEffect 的 fill
extension Shape {
    @ViewBuilder
    func fillWithGlass(_ color: Color = .monologueGlassTint, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.fill(color).glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            ZStack {
                self.fill(.ultraThinMaterial)
                self.fill(color)
            }
        }
    }

    @ViewBuilder
    func fillWithGlassCircle(_ color: Color = .monologueGlassTint) -> some View {
        if #available(iOS 26, *) {
            self.fill(color).glassEffect(.regular, in: .circle)
        } else {
            ZStack {
                self.fill(.ultraThinMaterial)
                self.fill(color)
            }
        }
    }

    @ViewBuilder
    func fillWithGlassCapsule(_ color: Color = .monologueGlassTint) -> some View {
        if #available(iOS 26, *) {
            self.fill(color).glassEffect(.regular, in: .capsule)
        } else {
            ZStack {
                self.fill(.ultraThinMaterial)
                self.fill(color)
            }
        }
    }
}
