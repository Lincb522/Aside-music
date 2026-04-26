import SwiftUI

struct BreathingThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var breatheScale: CGFloat = 1.0
    @State private var breatheOpacity: Double = 0.4

    var body: some View {
        let bgColor = colorScheme == .dark ? Color.black : Color(hex: "FAFAFA")
        let glowColor = Color.cyan
        
        return ZStack {
            bgColor
            
            // 呼吸晕影
            Circle()
                .fill(glowColor.opacity(breatheOpacity))
                .frame(width: 60, height: 60)
                .blur(radius: 12)
                .scaleEffect(breatheScale)
            
            VStack(spacing: 8) {
                // 中心封面
                Circle()
                    .fill(bgColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().stroke(glowColor.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Circle().fill(glowColor.opacity(0.1)).frame(width: 16, height: 16)
                    )
                
                // 呼吸条
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(glowColor.opacity(i == 1 ? 0.8 : 0.4))
                            .frame(width: 12, height: 2)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breatheScale = 1.4
                breatheOpacity = 0.8
            }
        }
    }
}
