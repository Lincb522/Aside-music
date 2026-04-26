import SwiftUI

struct CardThemePreview: View {
    @State private var isFloating = false

    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [.pink.opacity(0.5), .purple.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 白色卡片
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.9))
                .padding(10)
                .shadow(color: .black.opacity(isFloating ? 0.2 : 0.1), radius: isFloating ? 8 : 4, y: isFloating ? 8 : 4)
                .offset(y: isFloating ? -4 : 4)
                .overlay(
                    VStack(spacing: 6) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .scaleEffect(isFloating ? 1.05 : 1.0)
                        Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 3)
                        Capsule().fill(Color.gray.opacity(0.2)).frame(width: 30, height: 2)
                    }
                    .offset(y: isFloating ? -4 : 4)
                )
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isFloating)
        }
        .onAppear {
            isFloating = true
        }
    }
}
