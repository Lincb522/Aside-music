//  GPU 歌词光学效果只读取原始音频，原始字形始终保持清晰。

import SwiftUI

extension View {
    func ariaLyricStageOptics(
        pulse: AriaAudioPulse.Snapshot,
        fallbackAccent: Color,
        gpuEnabled: Bool,
        isActive: Bool,
        reduceMotion: Bool,
        time: Double
    ) -> some View {
        modifier(
            AriaLyricStageOpticsModifier(
                pulse: pulse,
                fallbackAccent: fallbackAccent,
                gpuEnabled: gpuEnabled,
                isActive: isActive,
                reduceMotion: reduceMotion,
                time: time
            )
        )
    }
}

private struct AriaLyricStageOpticsModifier: ViewModifier {
    let pulse: AriaAudioPulse.Snapshot
    let fallbackAccent: Color
    let gpuEnabled: Bool
    let isActive: Bool
    let reduceMotion: Bool
    let time: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        let punch = isActive && !reduceMotion ? pulse.punch : 0
        let tension = isActive && !reduceMotion ? pulse.tension : 0
        let stageScale = 1 + tension * 0.012
        let verticalFocus = -tension * 1.4

        let gpuEnergy = min(1, max(pulse.rawEnergy, pulse.tension * 0.80))
        let gpuAmbience = min(1, 0.18 + pulse.mid * 0.28 + pulse.treble * 0.62)

        let needsTensionMotion = abs(tension) > 0.001
        let needsGPU = gpuEnabled && isActive

        if !needsGPU, !needsTensionMotion {
            content
        } else {
            content
                .scaleEffect(stageScale, anchor: .center)
                .offset(y: verticalFocus)
                .modifier(
                    AriaLyricGPUOpticsModifier(
                        tint: fallbackAccent,
                        energy: gpuEnergy,
                        ambience: gpuAmbience,
                        punch: punch,
                        time: reduceMotion ? 0 : time,
                        enabled: needsGPU
                    )
                )
        }
    }
}

private struct AriaLyricGPUOpticsModifier: ViewModifier {
    let tint: Color
    let energy: Double
    let ambience: Double
    let punch: Double
    let time: Double
    let enabled: Bool

    @ObservedObject private var performance = AriaPerformanceGovernor.shared

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled, performance.tier != .low, #available(iOS 17.0, *) {
            GeometryReader { proxy in
                content
                    .layerEffect(
                        ShaderLibrary.ariaLyricOptics(
                            .float2(CGSize(
                                width: max(proxy.size.width, 1),
                                height: max(proxy.size.height, 1)
                            )),
                            .float(Float(time)),
                            .float(Float(energy)),
                            .float(Float(ambience)),
                            .float(Float(punch)),
                            .color(tint)
                        ),
                        maxSampleOffset: CGSize(width: 8, height: 8)
                    )
            }
        } else {
            content
        }
    }
}
