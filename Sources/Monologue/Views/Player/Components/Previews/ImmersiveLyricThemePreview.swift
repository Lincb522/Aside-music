import SwiftUI

struct ImmersiveLyricThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var offset1: CGFloat = 0
    @State private var offset2: CGFloat = 0
    @State private var highlightLine = 1

    var body: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? Color(hex: "1F1A2A") : Color(hex: "F8F5FF")
        let contentClr = isDark ? Color.white : Color.black
        
        return ZStack {
            bgColor
            
            // 背景弥散
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 80, height: 80)
                .blur(radius: 20)
                .offset(x: -30 + offset1, y: 30 + offset1)
            
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 60, height: 60)
                .blur(radius: 15)
                .offset(x: 40 - offset2, y: -20 + offset2)
            
            VStack {
                // 顶部信息
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.3)).frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Capsule().fill(contentClr.opacity(0.8)).frame(width: 25, height: 2.5)
                        Capsule().fill(contentClr.opacity(0.4)).frame(width: 15, height: 2)
                    }
                    Spacer()
                    Circle().fill(contentClr.opacity(0.6)).frame(width: 4, height: 4)
                }
                .padding(.top, 8)
                .padding(.horizontal, 10)
                
                Spacer()
                
                // 大字歌词
                VStack(alignment: .leading, spacing: 5) {
                    Capsule()
                        .fill(contentClr.opacity(highlightLine == 0 ? 0.9 : 0.15))
                        .frame(width: 50, height: highlightLine == 0 ? 5 : 4)
                        .animation(.easeInOut(duration: 0.5), value: highlightLine)
                    Capsule()
                        .fill(contentClr.opacity(highlightLine == 1 ? 0.9 : 0.15))
                        .frame(width: 70, height: highlightLine == 1 ? 5 : 4)
                        .animation(.easeInOut(duration: 0.5), value: highlightLine)
                    Capsule()
                        .fill(contentClr.opacity(highlightLine == 2 ? 0.9 : 0.15))
                        .frame(width: 40, height: highlightLine == 2 ? 5 : 4)
                        .animation(.easeInOut(duration: 0.5), value: highlightLine)
                }
                .padding(.leading, -20)
                
                Spacer()
                
                // 底部悬浮控制
                RoundedRectangle(cornerRadius: 4)
                    .fill(contentClr.opacity(0.08))
                    .frame(height: 16)
                    .overlay(
                        HStack(spacing: 8) {
                            Circle().fill(contentClr.opacity(0.5)).frame(width: 5, height: 5)
                            Circle().fill(contentClr.opacity(0.8)).frame(width: 8, height: 8)  // Play
                            Circle().fill(contentClr.opacity(0.5)).frame(width: 5, height: 5)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                offset1 = 15
            }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                offset2 = 10
            }
            
            let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                highlightLine = (highlightLine + 1) % 3
            }
            timer.fire()
        }
    }
}
