import SwiftUI

struct PlayingVisualizerView: View {
    let isAnimating: Bool
    let color: Color
    
    private let barCount = 3
    private let barWidth: CGFloat = 2.5
    private let barSpacing: CGFloat = 1.5
    private let maxHeight: CGFloat = 14
    private let minScale: CGFloat = 0.15
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.18, paused: !isAnimating)) { timeline in
            let phase = isAnimating ? timeline.date.timeIntervalSinceReferenceDate : 0
            
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let scale = isAnimating ? barScale(index: index, phase: phase) : minScale
                    
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(color)
                        .frame(width: barWidth, height: max(2, scale * maxHeight))
                        .animation(.easeInOut(duration: 0.22), value: scale)
                }
            }
            .frame(width: CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing, height: maxHeight, alignment: .bottom)
        }
    }
    
    private func barScale(index: Int, phase: Double) -> CGFloat {
        // 每根柱子用不同频率和相位的正弦波，模拟音乐节奏感
        let frequencies: [Double] = [2.8, 3.5, 2.2]
        let offsets: [Double] = [0, 1.2, 0.6]
        let freq = frequencies[index % frequencies.count]
        let offset = offsets[index % offsets.count]
        let raw = sin(phase * freq + offset)
        // 映射到 0.2 ~ 1.0
        return CGFloat(raw * 0.4 + 0.6)
    }
}
