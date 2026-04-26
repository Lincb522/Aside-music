import SwiftUI

struct ClassicThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPlaying = false
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(hex: "1A1A1E")
            } else {
                Color(hex: "F0F0F2")
            }

            VStack(spacing: 8) {
                // 封面
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(hex: "3A3A3E"), Color(hex: "2A2A2E")]
                                : [Color(hex: "D8D8DC"), Color(hex: "C8C8CC")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        MonologueIcon(icon: .musicNote, size: 18, color: colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.15))
                    )
                    .scaleEffect(isPlaying ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPlaying)

                // 进度条与控件
                VStack(spacing: 4) {
                    // 进度条
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.monologueTextSecondary.opacity(0.2))
                            .frame(width: 70, height: 2)
                        Capsule().fill(colorScheme == .dark ? Color.white : Color.black)
                            .frame(width: 70 * progress, height: 2)
                    }

                    // 底部控制按钮
                    HStack(spacing: 8) {
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 6, height: 6)
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
                        Circle()
                            .fill(colorScheme == .dark ? Color.white : Color.black)
                            .frame(width: 16, height: 16)
                            .scaleEffect(isPlaying ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5).repeatForever(autoreverses: true), value: isPlaying)
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
            }
        }
        .onAppear {
            isPlaying = true
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                progress = 1.0
            }
        }
    }
}
