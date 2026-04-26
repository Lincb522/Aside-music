import SwiftUI

struct MangaChatThemePreview: View {
    @State private var bubble1Scale: CGFloat = 0.01
    @State private var bubble2Scale: CGFloat = 0.01

    var body: some View {
        let ink = Color(hex: "2D2D3A")
        let inkSub = Color(hex: "8888A0")
        let pinkBg = Color(hex: "FFE8F0")
        let blueBg = Color(hex: "E8F0FF")
        let yellowLabel = Color(hex: "FFE4B5")

        return ZStack {
            // 漫画网点渐变背景
            LinearGradient(
                colors: [Color(hex: "FFF8EC"), Color(hex: "FDE8F0"), Color(hex: "E8F4FD")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 网点
            Canvas { context, sz in
                let gap: CGFloat = 10
                let dotR: CGFloat = 0.6
                var y: CGFloat = gap / 2
                var isEven = true
                while y < sz.height + gap {
                    var x: CGFloat = isEven ? gap / 2 : gap
                    while x < sz.width + gap {
                        let rect = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.08)))
                        x += gap
                    }
                    y += gap
                    isEven.toggle()
                }
            }

            VStack(spacing: 6) {
                // CHAT 标签
                HStack(spacing: 2) {
                    MonologueIcon(icon: .comment, size: 7, color: ink, lineWidth: 1.4)
                    Text("CHAT")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(yellowLabel))
                .overlay(Capsule().stroke(ink, lineWidth: 1.5))
                .background(Capsule().fill(ink).offset(x: 1.5, y: 1.5))

                // 左侧气泡
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(yellowLabel.opacity(0.5))
                        .frame(width: 14, height: 14)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(ink, lineWidth: 1.2))

                    VStack(alignment: .leading, spacing: 1) {
                        Capsule().fill(ink.opacity(0.7)).frame(width: 46, height: 3)
                        Capsule().fill(inkSub.opacity(0.4)).frame(width: 28, height: 2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(pinkBg))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(ink, lineWidth: 1.5))
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ink).offset(x: 1.5, y: 1.5))
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .scaleEffect(bubble1Scale, anchor: .bottomLeading)
                .opacity(bubble1Scale > 0.1 ? 1 : 0)

                // 右侧气泡
                HStack(spacing: 4) {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Capsule().fill(ink.opacity(0.7)).frame(width: 38, height: 3)
                        Capsule().fill(inkSub.opacity(0.4)).frame(width: 22, height: 2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(blueBg))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(ink, lineWidth: 1.5))
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ink).offset(x: -1.5, y: 1.5))

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: "B8D4F0").opacity(0.5))
                        .frame(width: 14, height: 14)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(ink, lineWidth: 1.2))
                }
                .padding(.horizontal, 10)
                .scaleEffect(bubble2Scale, anchor: .bottomTrailing)
                .opacity(bubble2Scale > 0.1 ? 1 : 0)
            }
        }
        .clipped()
        .onAppear {
            let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                bubble1Scale = 0.01
                bubble2Scale = 0.01
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { bubble1Scale = 1.0 }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.8)) { bubble2Scale = 1.0 }
            }
            timer.fire()
        }
    }
}
