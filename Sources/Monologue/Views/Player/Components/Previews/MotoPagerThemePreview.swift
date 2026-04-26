import SwiftUI

struct MotoPagerThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var printOffset: CGFloat = 10
    @State private var lineOpacities: [Double] = [0, 0, 0]

    var body: some View {
        let bgColor = colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F5F0E8")
        let textColor = colorScheme == .dark ? Color.white.opacity(0.8) : Color(hex: "333333")
        
        return ZStack {
            bgColor
            
            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                
                // 模拟小票打印文字
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(textColor.opacity((i == 1 ? 0.6 : 0.2) * lineOpacities[i]))
                        .frame(width: CGFloat([55, 70, 40][i]), height: i == 1 ? 4 : 2.5)
                }
                
                Spacer().frame(height: 6)
                
                // 锯齿边缘
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { _ in
                        Triangle()
                            .fill(textColor.opacity(0.15))
                            .frame(width: 6, height: 4)
                    }
                }
                
                Spacer().frame(height: 4)
            }
            .offset(y: printOffset)
            .padding(.horizontal, 12)
        }
        .clipped()
        .onAppear {
            let timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                // Reset
                printOffset = 10
                lineOpacities = [0, 0, 0]
                
                // Print lines
                withAnimation(.linear(duration: 0.2).delay(0.2)) { lineOpacities[0] = 1.0; printOffset = 6 }
                withAnimation(.linear(duration: 0.2).delay(0.6)) { lineOpacities[1] = 1.0; printOffset = 2 }
                withAnimation(.linear(duration: 0.2).delay(1.0)) { lineOpacities[2] = 1.0; printOffset = -2 }
            }
            timer.fire()
        }
    }
}
