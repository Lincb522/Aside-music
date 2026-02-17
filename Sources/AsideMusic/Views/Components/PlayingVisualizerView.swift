import SwiftUI

/// 播放状态指示器 — 迷你音纹波形条，风格与 FM WaveformProgressBar 一致
struct PlayingVisualizerView: View {
    let isAnimating: Bool
    let color: Color
    
    private let barCount = 5
    private let barSpacing: CGFloat = 1.5
    private let barWidth: CGFloat = 2
    private let maxHeight: CGFloat = 14
    private let minHeight: CGFloat = 3
    
    @State private var amplitudes: [CGFloat] = []
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !isAnimating)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 2
            
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let baseAmp = index < amplitudes.count ? amplitudes[index] : 0.5
                    let h = isAnimating
                        ? barHeight(index: index, baseAmplitude: baseAmp, phase: phase)
                        : minHeight
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: barWidth, height: h)
                        .animation(.easeInOut(duration: 0.12), value: h)
                }
            }
            .frame(
                width: CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing,
                height: maxHeight
            )
        }
        .onAppear { generateAmplitudes() }
    }
    
    private func barHeight(index: Int, baseAmplitude: CGFloat, phase: Double) -> CGFloat {
        let wave = sin(Double(index) * 0.8 + phase)
        let dynamic = 1.0 + CGFloat(wave) * 0.4
        let amp = min(max(baseAmplitude * dynamic, 0), 1)
        return minHeight + amp * (maxHeight - minHeight)
    }
    
    private func generateAmplitudes() {
        amplitudes = (0..<barCount).map { index in
            let norm = Double(index) / Double(barCount - 1)
            let envelope = sin(norm * .pi)
            let rand = Double.random(in: 0.4...1.0)
            return CGFloat(envelope * rand)
        }
    }
}
