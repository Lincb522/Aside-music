import SwiftUI

struct TypewriterThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var carriageOffset: CGFloat = 0

    var body: some View {
        let deskTop = colorScheme == .dark ? Color(hex: "2B1F18") : Color(hex: "9A7653")
        let deskBottom = colorScheme == .dark ? Color(hex: "1B1410") : Color(hex: "6E533B")
        let paperColor = colorScheme == .dark ? Color(hex: "E7D8BE") : Color(hex: "FFF8EB")
        let inkColor = colorScheme == .dark ? Color(hex: "2A211A") : Color(hex: "3B2D23")
        let machineColor = colorScheme == .dark ? Color(hex: "3A302A") : Color(hex: "5B493D")
        let keyColor = colorScheme == .dark ? Color(hex: "56473E") : Color(hex: "F0E4D4")

        return ZStack {
            LinearGradient(
                colors: [deskTop, deskBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                // 滑架与纸张
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(machineColor.opacity(0.9))
                        .frame(width: 76, height: 10)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
                        )
                        .offset(y: 4)
                        .zIndex(2)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(paperColor)
                        .frame(width: 86, height: 64)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 5) {
                                Capsule().fill(inkColor.opacity(0.55)).frame(width: 34, height: 3)
                                Capsule().fill(inkColor.opacity(0.8)).frame(width: 48, height: 4)
                                Capsule().fill(Color(hex: "B14A31").opacity(0.5)).frame(height: 1.5).padding(.top, 3)
                                Capsule().fill(inkColor.opacity(0.22)).frame(width: 58, height: 2)
                                Capsule().fill(inkColor.opacity(0.16)).frame(width: 50, height: 2)
                            }
                            .padding(.top, 10)
                            .padding(.leading, 10)
                        }
                        .overlay(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    LinearGradient(colors: [Color(hex: "D9C4A0"), Color(hex: "B9925D")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 18, height: 18)
                                .padding(9)
                        }
                        .zIndex(1)
                }
                .offset(x: carriageOffset)
                
                // 键盘区
                RoundedRectangle(cornerRadius: 12)
                    .fill(machineColor)
                    .frame(width: 98, height: 32)
                    .overlay(
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                ForEach(0..<5, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 4).fill(keyColor).frame(width: 12, height: 8)
                                }
                            }
                            RoundedRectangle(cornerRadius: 5).fill(keyColor).frame(width: 46, height: 9)
                        }
                        .padding(.top, 6)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    .offset(y: -6)
                    .zIndex(3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                carriageOffset = -15
            }
        }
    }
}
