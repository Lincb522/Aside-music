import SwiftUI
import LiquidGlassEffect

// Shared Back Button Component
struct AsideBackButton: View {
    enum Style {
        case back // < Back
        case dismiss // X or Down Arrow
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

// MARK: - Liquid Glass Background with Metal Shader
struct AsideBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Layer 1: Base color - 确保覆盖整个屏幕包括安全区域
            (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                .ignoresSafeArea()
            
            // Layer 2: Diffused color blobs
            GeometryReader { geo in
                Canvas { context, size in
                    if colorScheme == .dark {
                        // 深色模式 - 低饱和度暗色光斑
                        let purple = Color(hex: "2A1A3A")
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: -size.width * 0.3,
                                y: -size.height * 0.15,
                                width: size.width * 1.0,
                                height: size.height * 0.6
                            )),
                            with: .color(purple.opacity(0.6))
                        )
                        
                        let blue = Color(hex: "0D1B2A")
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: size.width * 0.4,
                                y: -size.height * 0.1,
                                width: size.width * 0.8,
                                height: size.height * 0.5
                            )),
                            with: .color(blue.opacity(0.5))
                        )
                        
                        let warm = Color(hex: "1A1210")
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: -size.width * 0.1,
                                y: size.height * 0.5,
                                width: size.width * 1.2,
                                height: size.height * 0.6
                            )),
                            with: .color(warm.opacity(0.5))
                        )
                    } else {
                        // 浅色模式 - 原有的柔和光斑
                        let pink = Color(hex: "E8D0E8")
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: -size.width * 0.3,
                                y: -size.height * 0.15,
                                width: size.width * 1.0,
                                height: size.height * 0.6
                            )),
                            with: .color(pink.opacity(0.5))
                        )
                        
                        let blue = Color(hex: "D0E4F5")
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: size.width * 0.4,
                                y: -size.height * 0.1,
                                width: size.width * 0.8,
                                height: size.height * 0.5
                            )),
                            with: .color(blue.opacity(0.45))
                        )
                        
                        let warm = Color(hex: "F8E4D0")
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: -size.width * 0.1,
                                y: size.height * 0.5,
                                width: size.width * 1.2,
                                height: size.height * 0.6
                            )),
                            with: .color(warm.opacity(0.4))
                        )
                        
                        let green = Color(hex: "D5EBE0")
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: -size.width * 0.2,
                                y: size.height * 0.3,
                                width: size.width * 0.7,
                                height: size.height * 0.5
                            )),
                            with: .color(green.opacity(0.35))
                        )
                    }
                }
                .blur(radius: 80)
            }
            .ignoresSafeArea()
            
            // Layer 3: Frosted glass overlay
            LiquidGlassOverlay()
                .ignoresSafeArea()
        }
    }
}

// MARK: - Liquid Glass Overlay
struct LiquidGlassOverlay: View {
    var body: some View {
        // 只保留轻微的毛玻璃模糊效果，去除所有白色叠加
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(0.3)
    }
}

// MARK: - Liquid Glass Card (Metal-powered)
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
                        // Metal shader version (使用 LiquidGlassEffect 库)
                        // 背景组件使用较低帧率，静态场景会自动冻结
                        LiquidGlassMetalView(cornerRadius: cornerRadius, backgroundCaptureFrameRate: 20)
                    } else {
                        // SwiftUI fallback
                        SwiftUIGlassBackground(cornerRadius: cornerRadius)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
}

// MARK: - SwiftUI Fallback Glass
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

// MARK: - View Modifiers
extension View {
    func asideBackground() -> some View {
        self.background(AsideBackground())
    }
}
