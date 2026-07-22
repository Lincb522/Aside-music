// PlaybackWave.swift
// Monologue Widget Extension

import WidgetKit
import SwiftUI

// MARK: - Playback Wave

struct PlaybackWave: View {
    let isActive: Bool
    let barCount: Int
    let color: Color
    let height: CGFloat
    var externalDate: Date?
    var externalTime: TimeInterval?

    var body: some View {
        if let time = externalTime {
            waveBody(time: time)
        } else if let date = externalDate {
            waveBody(time: date.timeIntervalSinceReferenceDate)
                .animation(.linear(duration: 0.5), value: date)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { context in
                waveBody(time: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    @ViewBuilder
    private func waveBody(time: TimeInterval) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: barHeight(for: i, time: time))
            }
        }
        .frame(height: height)
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        if !isActive {
            return 2.5
        }
        let phases: [Double] = [0.0, 1.8, 0.9, 2.7, 1.4, 3.2, 0.5, 2.3]
        let phase = phases[index % phases.count]
        let wave = sin(time * 12.0 + phase) * 0.5 + 0.5
        let minScale: CGFloat = 0.15
        return height * (minScale + CGFloat(wave) * (1.0 - minScale))
    }
}
