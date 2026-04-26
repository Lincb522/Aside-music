import SwiftUI

struct VinylThemePreview: View {
    @State private var recordRotation: Double = 0
    @State private var armRotation: Double = -25

    var body: some View {
        ZStack {
            Color(hex: "F5F5F5")

            ZStack {
                // 唱片
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "2A2A2A"), Color(hex: "1A1A1A"), Color(hex: "222222")],
                            center: .center,
                            startRadius: 8,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                // 沟槽
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: 50, height: 50)
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                    .frame(width: 36, height: 36)
                
                // 光泽（用于显示旋转效果）
                AngularGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.1), .clear, .white.opacity(0.1), .clear]),
                    center: .center
                )
                .mask(Circle().frame(width: 70, height: 70))

                // 中心
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "555555"), Color(hex: "444444")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color(hex: "1A1A1A"))
                    .frame(width: 6, height: 6)
            }
            .rotationEffect(.degrees(recordRotation))
            .offset(x: -5, y: -5)

            // 唱臂示意
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "E0E0E0"), Color(hex: "C0C0C0")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 3, height: 40)
                .rotationEffect(.degrees(armRotation), anchor: .top)
                .offset(x: 30, y: -30)
        }
        .onAppear {
            // 唱臂放下
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                armRotation = -8
            }
            // 唱片开始旋转
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false).delay(0.4)) {
                recordRotation = 360
            }
        }
    }
}
