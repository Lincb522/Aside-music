import SwiftUI
import LiquidGlass

// MARK: - 返回按钮组件
struct AsideBackButton: View {
    enum Style {
        case back   // < 返回
        case dismiss // 下拉关闭
    }

    var style: Style = .back
    var isDarkBackground: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(action: {
            dismiss()
        }) {
            ZStack {
                Circle()
                    .fill(isDarkBackground ? Color.white.opacity(0.2) : Color.asideSeparator)
                    .frame(width: 40, height: 40)

                AsideIcon(
                    icon: style == .back ? .back : .chevronRight,
                    size: 20,
                    color: isDarkBackground ? .white : .asideTextPrimary
                )
                .rotationEffect(style == .dismiss ? .degrees(90) : .zero)
            }
            .contentShape(Circle())
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }
}

// MARK: - 弥散背景组件
struct AsideBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // 第一层：纯色底
            (colorScheme == .dark ? Color(hex: "050507") : Color(hex: "F7F7FA"))
                .ignoresSafeArea()

            // 第二层：弥散光斑（多层叠加，模拟高端音乐 App 的弥散渐变）
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Canvas { context, size in
                    if colorScheme == .dark {
                        // ── 深色模式：深邃的多层弥散（高饱和度） ──

                        // 左上 — 靛蓝光晕（大范围、高不透明度）
                        let topLeft = Path(ellipseIn: CGRect(
                            x: -w * 0.25, y: -h * 0.2,
                            width: w * 1.1, height: h * 0.7
                        ))
                        context.fill(topLeft, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "1A2D4A").opacity(1.0),
                                Color(hex: "0D1B2A").opacity(0.5),
                                Color(hex: "0D1B2A").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.15, y: h * 0.1),
                            startRadius: 0,
                            endRadius: w * 0.7
                        ))

                        // 右上 — 深青色光晕
                        let topRight = Path(ellipseIn: CGRect(
                            x: w * 0.35, y: -h * 0.15,
                            width: w * 0.9, height: h * 0.6
                        ))
                        context.fill(topRight, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "0F2B33").opacity(0.9),
                                Color(hex: "0A1A1F").opacity(0.4),
                                Color(hex: "0A1A1F").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.82, y: h * 0.08),
                            startRadius: 0,
                            endRadius: w * 0.6
                        ))

                        // 中部 — 暖琥珀色呼吸点（增加层次和温度）
                        let mid = Path(ellipseIn: CGRect(
                            x: w * 0.0, y: h * 0.25,
                            width: w * 0.8, height: h * 0.5
                        ))
                        context.fill(mid, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "2A1F10").opacity(0.7),
                                Color(hex: "1A1410").opacity(0.3),
                                Color(hex: "1A1410").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.35, y: h * 0.45),
                            startRadius: 0,
                            endRadius: w * 0.5
                        ))

                        // 右下 — 深紫色光晕（增加色彩丰富度）
                        let rightBottom = Path(ellipseIn: CGRect(
                            x: w * 0.4, y: h * 0.4,
                            width: w * 0.7, height: h * 0.5
                        ))
                        context.fill(rightBottom, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "1A0F2E").opacity(0.6),
                                Color(hex: "1A0F2E").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.7, y: h * 0.6),
                            startRadius: 0,
                            endRadius: w * 0.45
                        ))

                        // 底部 — 深色收底渐变
                        let bottom = Path(ellipseIn: CGRect(
                            x: -w * 0.05, y: h * 0.5,
                            width: w * 1.1, height: h * 0.6
                        ))
                        context.fill(bottom, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "0C0E14").opacity(0.8),
                                Color(hex: "0C0E14").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.5, y: h * 0.78),
                            startRadius: 0,
                            endRadius: w * 0.65
                        ))

                    } else {
                        // ── 浅色模式：柔和的奶油弥散（更明显） ──

                        // 左上 — 暖米色光晕
                        let topLeft = Path(ellipseIn: CGRect(
                            x: -w * 0.2, y: -h * 0.15,
                            width: w * 1.0, height: h * 0.65
                        ))
                        context.fill(topLeft, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "DDD3C7").opacity(0.85),
                                Color(hex: "E6DFD8").opacity(0.4),
                                Color(hex: "E6DFD8").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.12, y: h * 0.08),
                            startRadius: 0,
                            endRadius: w * 0.6
                        ))

                        // 右上 — 淡蓝灰光晕
                        let topRight = Path(ellipseIn: CGRect(
                            x: w * 0.3, y: -h * 0.1,
                            width: w * 0.85, height: h * 0.6
                        ))
                        context.fill(topRight, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "C8D4E4").opacity(0.75),
                                Color(hex: "D8E0EA").opacity(0.35),
                                Color(hex: "D8E0EA").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.8, y: h * 0.06),
                            startRadius: 0,
                            endRadius: w * 0.55
                        ))

                        // 中部 — 淡玫瑰暖色（增加温度感）
                        let mid = Path(ellipseIn: CGRect(
                            x: w * 0.05, y: h * 0.2,
                            width: w * 0.7, height: h * 0.45
                        ))
                        context.fill(mid, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "E5D5CA").opacity(0.65),
                                Color(hex: "EDE5DF").opacity(0.3),
                                Color(hex: "EDE5DF").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.4, y: h * 0.4),
                            startRadius: 0,
                            endRadius: w * 0.45
                        ))

                        // 底部 — 奶油色收底
                        let bottom = Path(ellipseIn: CGRect(
                            x: w * 0.0, y: h * 0.45,
                            width: w * 1.0, height: h * 0.6
                        ))
                        context.fill(bottom, with: .radialGradient(
                            Gradient(colors: [
                                Color(hex: "E8DFD4").opacity(0.7),
                                Color(hex: "F0EBE4").opacity(0.3),
                                Color(hex: "F0EBE4").opacity(0)
                            ]),
                            center: CGPoint(x: w * 0.5, y: h * 0.72),
                            startRadius: 0,
                            endRadius: w * 0.6
                        ))
                    }
                }
                .blur(radius: 60)
                .frame(width: w, height: h)
            }
            .ignoresSafeArea()

            // 第三层：极淡噪点纹理（增加质感）
            Canvas { context, size in
                for _ in 0..<150 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let r = CGFloat.random(in: 0.5...1.8)
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r))
                    context.fill(dot, with: .color(.primary.opacity(Double.random(in: 0.015...0.04))))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 第四层：极淡毛玻璃统一色调（降低遮盖，让弥散更透出来）
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.05 : 0.08)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Liquid Glass 叠加层
struct LiquidGlassOverlay: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(0.3)
    }
}

// MARK: - Liquid Glass 卡片（Metal 渲染）
struct AsideLiquidGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let useMetal: Bool
    let content: Content

    init(
        cornerRadius: CGFloat = 20,
        useMetal: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.useMetal = useMetal
        self.content = content()
    }

    var body: some View {
        content
            .background(
                Group {
                    if useMetal {
                        Color.clear
                            .liquidGlassBackground(cornerRadius: cornerRadius, blurScale: 0.3, tintColor: UIColor.white.withAlphaComponent(0.05))
                    } else {
                        SwiftUIGlassBackground(cornerRadius: cornerRadius)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
}

// MARK: - SwiftUI 毛玻璃回退方案
struct SwiftUIGlassBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.4))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
        }
    }
}

// MARK: - View 修饰器
extension View {
    func asideBackground() -> some View {
        self.background(AsideBackground())
    }
}
