import SwiftUI
import LiquidGlassEffect

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
            (colorScheme == .dark ? Color(hex: "0A0A0C") : Color(hex: "F5F5F7"))
                .ignoresSafeArea()

            // 第二层：弥散光斑
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    if colorScheme == .dark {
                        // ── 深色模式：中性深灰蓝，无紫色 ──

                        // 左上 — 深灰蓝
                        RadialGradient(
                            colors: [
                                Color(hex: "131720").opacity(0.7),
                                Color(hex: "131720").opacity(0)
                            ],
                            center: .init(x: 0.15, y: 0.08),
                            startRadius: 0,
                            endRadius: w * 0.75
                        )

                        // 右上 — 深青灰
                        RadialGradient(
                            colors: [
                                Color(hex: "0F1A1E").opacity(0.5),
                                Color(hex: "0F1A1E").opacity(0)
                            ],
                            center: .init(x: 0.85, y: 0.1),
                            startRadius: 0,
                            endRadius: w * 0.6
                        )

                        // 中下 — 深暖灰收底
                        RadialGradient(
                            colors: [
                                Color(hex: "14120F").opacity(0.5),
                                Color(hex: "14120F").opacity(0)
                            ],
                            center: .init(x: 0.5, y: 0.7),
                            startRadius: 0,
                            endRadius: w * 0.7
                        )

                    } else {
                        // ── 浅色模式：暖灰米色，无紫色 ──

                        // 左上 — 淡暖灰
                        RadialGradient(
                            colors: [
                                Color(hex: "E8E4E0").opacity(0.5),
                                Color(hex: "E8E4E0").opacity(0)
                            ],
                            center: .init(x: 0.1, y: 0.05),
                            startRadius: 0,
                            endRadius: w * 0.7
                        )

                        // 右上 — 极淡蓝灰
                        RadialGradient(
                            colors: [
                                Color(hex: "DEE4EC").opacity(0.4),
                                Color(hex: "DEE4EC").opacity(0)
                            ],
                            center: .init(x: 0.85, y: 0.0),
                            startRadius: 0,
                            endRadius: w * 0.6
                        )

                        // 中下 — 奶油米色收底
                        RadialGradient(
                            colors: [
                                Color(hex: "F0ECE6").opacity(0.4),
                                Color(hex: "F0ECE6").opacity(0)
                            ],
                            center: .init(x: 0.5, y: 0.6),
                            startRadius: 0,
                            endRadius: w * 0.7
                        )
                    }
                }
                .frame(width: w, height: h)
                .blur(radius: 70)
            }
            .ignoresSafeArea()

            // 第三层：极淡毛玻璃统一色调
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.15 : 0.2)
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
                        LiquidGlassMetalView(cornerRadius: cornerRadius, backgroundCaptureFrameRate: 20)
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
