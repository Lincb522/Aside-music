import SwiftUI

struct AquaThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var waveOffset: CGFloat = 0
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.5

    var body: some View {
        let isDark = colorScheme == .dark
        
        return ZStack {
            // 水面渐变背景
            LinearGradient(
                colors: isDark
                    ? [Color(hex: "0B1A2B"), Color(hex: "154360"), Color(hex: "1A5276")]
                    : [.white, Color(hex: "D6EAF8"), Color(hex: "85C1E9")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 涟漪动画
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 40, height: 40)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
            
            // 中心波纹发光点
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 50, height: 50)
                .blur(radius: 8)
                .overlay(
                    // 封面占位
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.white.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            MonologueIcon(icon: .musicNote, size: 14, color: isDark ? .black.opacity(0.4) : .blue.opacity(0.3))
                        )
                )
            
            // 底部波浪线
            VStack {
                Spacer()
                Path { p in
                    p.move(to: .init(x: 0, y: 15))
                    p.addCurve(to: .init(x: 50, y: 15), control1: .init(x: 15, y: 5), control2: .init(x: 35, y: 25))
                    p.addCurve(to: .init(x: 100, y: 15), control1: .init(x: 65, y: 5), control2: .init(x: 85, y: 25))
                    p.addLine(to: .init(x: 100, y: 30))
                    p.addLine(to: .init(x: 0, y: 30))
                    p.closeSubpath()
                }
                .fill(Color.white.opacity(0.15))
                .frame(height: 30)
                .offset(x: waveOffset)
            }
        }
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                waveOffset = -50
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                rippleScale = 2.5
                rippleOpacity = 0
            }
        }
    }
}
