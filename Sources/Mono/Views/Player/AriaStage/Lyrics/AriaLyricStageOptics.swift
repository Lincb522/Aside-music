//  GPU 舞台与 AI 舞台编排各自完成歌词光学效果：GPU 只读取原始音频，
//  AI 只读取分幕脚本。原始字形始终保持清晰。

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

    private var directorEnergy: Double {
        guard directorEnabled, let cue else { return 0 }
        return min(1, max(0, cue.energy))
    }

    private var directorAmbience: Double {
        guard directorEnabled, let cue else { return 0 }
        return min(1, max(0, cue.ambience))
    }

    private var lyricLift: Double {
        guard directorEnabled, let cue else { return 0 }
        return min(1, max(0, cue.lyricLift))
    }

    private var directorColor: Color {
        guard directorEnabled, let cue else { return fallbackAccent }
        let tone = AriaDirectorMoodTone.tone(for: cue)
        return Color(
            hue: tone.hue,
            saturation: tone.saturation,
            brightness: 0.98
        )
    }

    func body(content: Content) -> some View {
        let energy = isActive ? directorEnergy : 0
        let ambience = isActive ? directorAmbience : 0
        let emphasis = isActive ? lyricLift : 0
        let scriptedBloom = isActive && directorEnabled ? min(1, max(0, cue?.bloom ?? 0)) : 0
        let scriptedMotion = isActive && !reduceMotion && directorEnabled
            ? min(1, max(0, cue?.motion ?? 0))
            : 0
        let punch = isActive && !reduceMotion ? pulse.punch : 0
        let tension = isActive && !reduceMotion ? pulse.tension : 0
        let baseScale = directorEnabled
            ? 0.996 + emphasis * 0.016 + scriptedMotion * 0.004
            : 1
        let stageScale = baseScale + tension * 0.012
        let verticalFocus = (directorEnabled ? (0.52 - emphasis) * 3.0 : 0) - tension * 1.4
        let glowOpacity = directorEnabled
            ? 0.08 + energy * 0.06 + ambience * 0.13 + emphasis * 0.16 + scriptedBloom * 0.14
            : 0

        // GPU 着色只读取原始音频；AI 编排不能改变其折射强度和色相。
        let gpuEnergy = min(1, max(pulse.rawEnergy, pulse.tension * 0.80))
        let gpuAmbience = min(1, 0.18 + pulse.mid * 0.28 + pulse.treble * 0.62)

        content
            .scaleEffect(stageScale, anchor: .center)
            .offset(y: verticalFocus)
            .brightness(directorEnabled ? (emphasis - 0.5) * 0.020 + (energy - 0.5) * 0.010 : 0)
            .shadow(
                color: directorColor.opacity(glowOpacity),
                radius: 6 + scriptedBloom * 16 + ambience * 7,
                x: 0,
                y: 1
            )
            .modifier(
                AriaLyricGPUOpticsModifier(
                    tint: fallbackAccent,
                    energy: gpuEnergy,
                    ambience: gpuAmbience,
                    punch: punch,
                    time: reduceMotion ? 0 : time,
                    enabled: gpuEnabled && isActive
                )
            )
            .animation(.easeInOut(duration: 1.15), value: cue?.role)
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
