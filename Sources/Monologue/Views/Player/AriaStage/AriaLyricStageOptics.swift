//
//  AriaLyricStageOptics.swift
//  Monologue
//
//  GPU 舞台与 AI 舞台导演共同作用于歌词的光学完成层。
//  原始字形始终保持清晰，只在边缘、光晕和整体呼吸上响应舞台参数。
//

import SwiftUI

extension View {
    func ariaLyricStageOptics(
        pulse: AriaAudioPulse.Snapshot,
        cue: MonoStageCue?,
        fallbackAccent: Color,
        gpuEnabled: Bool,
        directorEnabled: Bool,
        isActive: Bool,
        reduceMotion: Bool,
        time: Double
    ) -> some View {
        modifier(
            AriaLyricStageOpticsModifier(
                pulse: pulse,
                cue: cue,
                fallbackAccent: fallbackAccent,
                gpuEnabled: gpuEnabled,
                directorEnabled: directorEnabled,
                isActive: isActive,
                reduceMotion: reduceMotion,
                time: time
            )
        )
    }
}

private struct AriaLyricStageOpticsModifier: ViewModifier {
    let pulse: AriaAudioPulse.Snapshot
    let cue: MonoStageCue?
    let fallbackAccent: Color
    let gpuEnabled: Bool
    let directorEnabled: Bool
    let isActive: Bool
    let reduceMotion: Bool
    let time: Double

    private var resolvedEnergy: Double {
        let directed = directorEnabled && cue != nil
            ? max(pulse.energy, (cue?.energy ?? 0) * 0.76)
            : pulse.energy
        return min(1, max(directed, pulse.tension * 0.94))
    }

    private var resolvedAmbience: Double {
        let directed = directorEnabled && cue != nil
            ? max(pulse.ambience, cue?.ambience ?? 0)
            : 0.24
        return min(1, max(directed, pulse.tension * 0.72))
    }

    private var directorColor: Color {
        guard directorEnabled, let cue else { return fallbackAccent }
        let tone = AriaDirectorMoodTone.tone(for: cue.mood, energy: cue.energy)
        return Color(
            hue: tone.hue,
            saturation: tone.saturation,
            brightness: 0.98
        )
    }

    func body(content: Content) -> some View {
        let energy = isActive ? resolvedEnergy : 0
        let ambience = isActive ? resolvedAmbience : 0
        let punch = isActive && !reduceMotion ? pulse.punch : 0
        let tension = isActive && !reduceMotion ? pulse.tension : 0
        let baseScale = directorEnabled
            ? 0.994 + energy * 0.014 + punch * 0.006
            : 1
        let stageScale = baseScale + tension * 0.018
        let verticalFocus = (directorEnabled ? (0.5 - energy) * 3.5 : 0) - tension * 1.8
        let glowOpacity = directorEnabled || tension > 0.001
            ? 0.14 + ambience * 0.22 + energy * 0.08 + tension * 0.12
            : 0

        content
            .scaleEffect(stageScale, anchor: .center)
            .offset(y: verticalFocus)
            .brightness(directorEnabled ? (energy - 0.5) * 0.035 : 0)
            .shadow(
                color: directorColor.opacity(glowOpacity),
                radius: 7 + ambience * 13 + tension * 8,
                x: 0,
                y: 1
            )
            .modifier(
                AriaLyricGPUOpticsModifier(
                    tint: directorColor,
                    energy: energy,
                    ambience: ambience,
                    punch: punch,
                    time: reduceMotion ? 0 : time,
                    enabled: gpuEnabled && isActive
                )
            )
            .animation(.easeInOut(duration: 1.15), value: cue?.mood)
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
