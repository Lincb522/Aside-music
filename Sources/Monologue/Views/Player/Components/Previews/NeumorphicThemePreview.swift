import SwiftUI

struct NeumorphicThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var progress: CGFloat = 0.3

    var body: some View {
        let bgColor = colorScheme == .dark ? Color(hex: "2D2D30") : Color(hex: "E8E8EC")
        
        return ZStack {
            bgColor
            
            VStack(spacing: 10) {
                // 凸起的圆形封面 (模拟轻微转动)
                Circle()
                    .fill(bgColor)
                    .frame(width: 50, height: 50)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.15), radius: 6, x: 4, y: 4)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.05) : .white.opacity(0.7), radius: 6, x: -4, y: -4)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                    )
                    .rotationEffect(.degrees(isPressed ? 10 : -10))
                
                // 凹陷的进度条 (模拟进度加载)
                RoundedRectangle(cornerRadius: 3)
                    .fill(bgColor)
                    .frame(width: 70, height: 6)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.15), radius: 2, x: 2, y: 2)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.05) : .white.opacity(0.7), radius: 2, x: -2, y: -2)
                    .overlay(
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                                .frame(width: 70 * progress, height: 4)
                            Spacer()
                        }
                        .padding(.horizontal, 1)
                    )
                
                // 播放按钮 (模拟按压)
                Circle()
                    .fill(bgColor)
                    .frame(width: 24, height: 24)
                    .shadow(color: colorScheme == .dark ? .black.opacity(isPressed ? 0.2 : 0.5) : .black.opacity(isPressed ? 0.05 : 0.15), radius: isPressed ? 1 : 3, x: isPressed ? 1 : 2, y: isPressed ? 1 : 2)
                    .shadow(color: colorScheme == .dark ? .white.opacity(isPressed ? 0.02 : 0.05) : .white.opacity(isPressed ? 0.3 : 0.7), radius: isPressed ? 1 : 3, x: isPressed ? -1 : -2, y: isPressed ? -1 : -2)
                    .overlay(
                        MonologueIcon(icon: .play, size: 10, color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPressed = true
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                progress = 0.9
            }
        }
    }
}
