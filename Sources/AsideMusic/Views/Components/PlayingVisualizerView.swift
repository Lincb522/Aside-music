import SwiftUI

/// 播放状态指示器 — 迷你音纹波形条
struct PlayingVisualizerView: View {
    let isAnimating: Bool
    let color: Color
    
    private let barCount = 5
    private let barSpacing: CGFloat = 1.5
    private let barWidth: CGFloat = 2
    private let maxHeight: CGFloat = 14
    private let minHeight: CGFloat = 3
    
    @State private var phases: [Double] = []
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06, paused: !isAnimating)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let offset = index < phases.count ? phases[index] : Double(index)
                    let h = isAnimating
                        ? barHeight(index: index, time: time, phaseOffset: offset)
                        : minHeight
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: barWidth, height: h)
                        .animation(.easeInOut(duration: 0.15), value: h)
                }
            }
            .frame(
                width: CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing,
                height: maxHeight
            )
        }
        .onAppear { generatePhases() }
    }
    
    private func barHeight(index: Int, time: Double, phaseOffset: Double) -> CGFloat {
        // 每根条用不同频率和相位，产生错落感
        let freq = 2.5 + Double(index) * 0.6
        let wave = sin(time * freq + phaseOffset)
        // 映射到 0~1 范围
        let normalized = (wave + 1.0) / 2.0
        // 加一点随机抖动让更自然
        let jitter = sin(time * 7.3 + Double(index) * 2.1) * 0.1
        let amp = min(max(normalized + jitter, 0.15), 1.0)
        return minHeight + CGFloat(amp) * (maxHeight - minHeight)
    }
    
    private func generatePhases() {
        phases = (0..<barCount).map { _ in Double.random(in: 0...(.pi * 2)) }
    }
}
