import SwiftUI

struct PixelThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var textBlink = true
    @State private var wavePhase = 0

    var body: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? Color(hex: "0a0a1a") : Color(hex: "e8eaf0")
        let pixelGreen = Color(hex: "00ff41")
        let gridColor = isDark ? pixelGreen.opacity(0.08) : Color.black.opacity(0.04)
        
        return ZStack {
            bgColor
            
            // 背景像素网格
            Canvas { ctx, size in
                let step: CGFloat = 8
                for row in 0...Int(size.height / step) {
                    for col in 0...Int(size.width / step) {
                        ctx.stroke(
                            Path(CGRect(x: CGFloat(col) * step, y: CGFloat(row) * step, width: step, height: step)),
                            with: .color(gridColor),
                            lineWidth: 0.5
                        )
                    }
                }
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 扫描线效果标题
                HStack(spacing: 2) {
                    // "PIXEL" 像素字
                    ForEach(["P","I","X","E","L"], id: \.self) { ch in
                        Text(ch)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(pixelGreen)
                    }
                }
                .shadow(color: pixelGreen.opacity(0.6), radius: 4, x: 0, y: 0)
                .opacity(textBlink ? 1.0 : 0.3)
                
                Spacer().frame(height: 8)
                
                // 像素化波形
                HStack(spacing: 2) {
                    let heights1: [CGFloat] = [4, 8, 12, 18, 14, 20, 10, 16, 22, 14, 8, 12, 6, 4]
                    let heights2: [CGFloat] = [8, 14, 20, 10, 16, 22, 14, 8, 12, 18, 14, 6, 12, 8]
                    let heights = wavePhase == 0 ? heights1 : heights2
                    
                    ForEach(0..<14, id: \.self) { i in
                        Rectangle()
                            .fill(pixelGreen.opacity(i < 6 ? 0.9 : 0.3))
                            .frame(width: 4, height: heights[i])
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: wavePhase)
                    }
                }
                
                Spacer().frame(height: 8)
                
                // 底部像素控制行
                HStack(spacing: 10) {
                    // 上一首
                    HStack(spacing: 0) {
                        Rectangle().fill(pixelGreen.opacity(0.5)).frame(width: 2, height: 8)
                        Path { p in p.move(to: .init(x: 8, y: 0)); p.addLine(to: .init(x: 0, y: 4)); p.addLine(to: .init(x: 8, y: 8)); p.closeSubpath() }
                        .fill(pixelGreen.opacity(0.5)).frame(width: 8, height: 8)
                    }
                    
                    // 播放
                    Rectangle()
                        .fill(pixelGreen)
                        .frame(width: 12, height: 12)
                        .shadow(color: pixelGreen.opacity(0.5), radius: 3)
                    
                    // 下一首
                    HStack(spacing: 0) {
                        Path { p in p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 8, y: 4)); p.addLine(to: .init(x: 0, y: 8)); p.closeSubpath() }
                        .fill(pixelGreen.opacity(0.5)).frame(width: 8, height: 8)
                        Rectangle().fill(pixelGreen.opacity(0.5)).frame(width: 2, height: 8)
                    }
                }
                
                Spacer().frame(height: 10)
            }
            
            // CRT 扫描线叠加
            VStack(spacing: 2) {
                ForEach(0..<65, id: \.self) { _ in
                    Rectangle().fill(Color.black.opacity(isDark ? 0.15 : 0.03)).frame(height: 1)
                    Spacer().frame(height: 1)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                textBlink.toggle()
                wavePhase = wavePhase == 0 ? 1 : 0
            }
            timer.fire()
        }
    }
}
