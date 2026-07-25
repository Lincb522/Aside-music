//  Mono AI 舞台编排的独立可见输出层。编排脚本只控制自己的灯光、
//  色温与空间辉光，不向 GPU 着色传递参数。

import SwiftUI

/// 覆盖封面与视频背景的分幕灯光。无脚本时保持完全透明。
@MainActor
struct AriaDirectorMoodVeil: View {
    let isPlaying: Bool

    @ObservedObject private var director = MonoStageDirector.shared
    @ObservedObject private var playbackTime = PlaybackTimePublisher.shared

    var body: some View {
        let cue = director.cue(at: playbackTime.currentTime)

        GeometryReader { proxy in
            veil(for: cue, size: proxy.size)
        }
        .animation(.easeInOut(duration: 1.45), value: cue?.mood)
        .animation(.easeInOut(duration: 0.75), value: director.phase)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func veil(for cue: MonoStageCue?, size: CGSize) -> some View {
        if let cue {
            let tone = AriaDirectorMoodTone.tone(for: cue)
            let accent = Color(
                hue: tone.hue,
                saturation: tone.saturation,
                brightness: 0.96
            )
            let companion = Color(
                hue: AriaDirectorMoodTone.wrappedHue(tone.hue + tone.companionOffset),
                saturation: max(0.30, tone.saturation * 0.82),
                brightness: 0.94
            )
            let echo = Color(
                hue: AriaDirectorMoodTone.wrappedHue(tone.hue - tone.companionOffset * 0.72),
                saturation: max(0.24, tone.saturation * 0.64),
                brightness: 0.84
            )
            let energy = min(max(cue.energy, 0), 1)
            let ambience = min(max(cue.ambience, 0), 1)
            let motion = min(max(cue.motion, 0), 1)
            let bloom = min(max(cue.bloom, 0), 1)
            let longSide = max(size.width, size.height)

            ZStack {
                // 三色镜头底调：每幕形成明确色彩关系，但不盖住封面细节。
                LinearGradient(
                    stops: [
                        .init(color: echo.opacity(0.025 + ambience * 0.045), location: 0),
                        .init(color: accent.opacity(0.030 + energy * 0.055), location: 0.48),
                        .init(color: companion.opacity(0.018 + bloom * 0.052), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 主光跟随编排焦点；能量决定密度，辉光与能量互不替代。
                RadialGradient(
                    stops: [
                        .init(color: accent.opacity(0.12 + energy * 0.16 + bloom * 0.05), location: 0),
                        .init(color: companion.opacity(0.035 + ambience * 0.07), location: 0.42),
                        .init(color: .clear, location: 1)
                    ],
                    center: UnitPoint(x: tone.focusX, y: 0.46 - motion * 0.035),
                    startRadius: 0,
                    endRadius: longSide * CGFloat(0.34 + bloom * 0.24)
                )

                // 两束侧光组成独立灯架。motion 只改变开合，不产生持续抖动。
                directorBeam(
                    color: accent,
                    size: size,
                    leading: true,
                    focusX: tone.focusX,
                    motion: motion,
                    bloom: bloom,
                    strength: 0.075 + energy * 0.15
                )
                directorBeam(
                    color: companion,
                    size: size,
                    leading: false,
                    focusX: tone.focusX,
                    motion: motion,
                    bloom: bloom,
                    strength: 0.055 + ambience * 0.10 + bloom * 0.06
                )

                // 舞台中轴的空气辉光；安静段也能有空间，不必硬抬能量。
                RadialGradient(
                    stops: [
                        .init(color: echo.opacity(0.055 + bloom * 0.12), location: 0),
                        .init(color: accent.opacity(0.022 + ambience * 0.065), location: 0.52),
                        .init(color: .clear, location: 1)
                    ],
                    center: UnitPoint(x: 1 - tone.focusX * 0.42, y: 0.62),
                    startRadius: 0,
                    endRadius: longSide * CGFloat(0.30 + ambience * 0.28)
                )

                // 地平线收束整幕色彩，不绘制可辨认的几何装饰。
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.63),
                        .init(color: companion.opacity(0.025 + ambience * 0.085), location: 0.82),
                        .init(color: accent.opacity(0.065 + bloom * 0.14 + energy * 0.04), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blendMode(.screen)
            .opacity(isPlaying ? 1 : 0.72)
            .animation(.easeInOut(duration: 1.15), value: cue.role)
        }
    }

    private func directorBeam(
        color: Color,
        size: CGSize,
        leading: Bool,
        focusX: Double,
        motion: Double,
        bloom: Double,
        strength: Double
    ) -> some View {
        let direction = leading ? -1.0 : 1.0
        let spread = 0.15 + motion * 0.13
        let focusOffset = (focusX - 0.5) * 0.48

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, color, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(
                width: max(96, size.width * CGFloat(0.18 + motion * 0.10 + bloom * 0.04)),
                height: size.height * 1.28
            )
            .rotationEffect(
                .degrees(direction * (11 + motion * 15)),
                anchor: .top
            )
            .offset(
                x: size.width * CGFloat(focusOffset + direction * spread),
                y: -size.height * 0.18
            )
            .mask(
                LinearGradient(
                    colors: [.white.opacity(0.94), .white.opacity(0.62), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(strength)
    }
}

/// mood（中文自由词）映射为镜头色相。未命中时按能量从冷蓝滑向暖橙，
/// 因此 Agent 返回新的基调词也不会退化为同一种颜色。
enum AriaDirectorMoodTone {
    struct Tone {
        let hue: Double
        let saturation: Double
        let companionOffset: Double
        let focusX: Double
    }

    static func tone(for cue: MonoStageCue) -> Tone {
        let base = tone(for: cue.mood, energy: cue.energy)
        let scriptedFocus = (min(1, max(-1, cue.focus)) + 1) * 0.5
        return Tone(
            hue: wrappedHue(base.hue + cue.colorShift * 0.075),
            saturation: min(0.90, max(0.38, base.saturation + abs(cue.colorShift) * 0.08)),
            companionOffset: base.companionOffset + cue.colorShift * 0.018,
            focusX: min(0.78, max(0.22, base.focusX * 0.32 + scriptedFocus * 0.68))
        )
    }

    static func tone(for mood: String, energy: Double) -> Tone {
        let table: [(keywords: [String], tone: Tone)] = [
            (["炽热", "燃", "烈", "沸", "狂", "高燃", "怒"], Tone(hue: 0.020, saturation: 0.82, companionOffset: 0.075, focusX: 0.58)),
            (["释放", "爆发", "高潮", "盛放", "辉煌"], Tone(hue: 0.095, saturation: 0.76, companionOffset: -0.065, focusX: 0.52)),
            (["蓄势", "推进", "紧张", "临界", "压抑", "暗涌"], Tone(hue: 0.865, saturation: 0.61, companionOffset: 0.085, focusX: 0.42)),
            (["梦境", "梦", "幻", "迷离", "朦胧", "缥缈"], Tone(hue: 0.745, saturation: 0.58, companionOffset: -0.125, focusX: 0.56)),
            (["沉静", "静", "夜", "低语", "呢喃", "沉思"], Tone(hue: 0.605, saturation: 0.56, companionOffset: 0.085, focusX: 0.46)),
            (["回望", "怀旧", "追忆", "温柔", "暖", "眷恋"], Tone(hue: 0.075, saturation: 0.50, companionOffset: 0.055, focusX: 0.43)),
            (["告别", "离别", "哀", "泪", "伤", "孤独"], Tone(hue: 0.535, saturation: 0.47, companionOffset: 0.095, focusX: 0.40)),
            (["希望", "晨", "光", "晴", "自由", "远方"], Tone(hue: 0.445, saturation: 0.54, companionOffset: 0.115, focusX: 0.60))
        ]
        for entry in table where entry.keywords.contains(where: { mood.contains($0) }) {
            return entry.tone
        }

        let normalizedEnergy = min(max(energy, 0), 1)
        return Tone(
            hue: 0.62 - normalizedEnergy * 0.575,
            saturation: 0.56,
            companionOffset: normalizedEnergy > 0.62 ? 0.065 : 0.10,
            focusX: 0.5
        )
    }

    static func wrappedHue(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }
}
