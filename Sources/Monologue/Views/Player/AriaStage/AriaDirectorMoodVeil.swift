//
//  AriaDirectorMoodVeil.swift
//  Monologue
//
//  Mono Stage Director 的可见输出层。导演脚本不只改变背景亮度，
//  还会按分幕基调改变整幅舞台的色温、地平线底光与空间雾感。
//

import SwiftUI

/// 独立推进导演提示，避免把 AI 分幕绑定到某一种歌词 TimelineView。
/// 视频背景、纯音乐、暂停后恢复与切换歌词效果时都走同一条更新链路。
@MainActor
struct AriaDirectorCueDriver: View {
    let pulse: AriaAudioPulse
    let enabled: Bool

    @ObservedObject private var director = MonoStageDirector.shared
    @ObservedObject private var playbackTime = PlaybackTimePublisher.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: playbackTime.currentTime, initial: true) { _, time in
                applyCue(at: time)
            }
            .onChange(of: director.phase) { _, _ in
                applyCue(at: playbackTime.currentTime)
            }
            .onChange(of: enabled) { _, _ in
                applyCue(at: playbackTime.currentTime)
            }
            .onDisappear {
                pulse.setDirectorCue(energy: nil, ambience: nil)
            }
    }

    private func applyCue(at time: Double) {
        guard enabled, let cue = director.cue(at: time) else {
            pulse.setDirectorCue(energy: nil, ambience: nil)
            return
        }
        pulse.setDirectorCue(energy: cue.energy, ambience: cue.ambience)
    }
}

/// 覆盖封面与视频背景的分幕光幕。无脚本时保持完全透明。
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
            let tone = AriaDirectorMoodTone.tone(for: cue.mood, energy: cue.energy)
            let accent = Color(
                hue: tone.hue,
                saturation: tone.saturation,
                brightness: 0.96
            )
            let companion = Color(
                hue: wrappedHue(tone.hue + tone.companionOffset),
                saturation: max(0.22, tone.saturation * 0.72),
                brightness: 0.90
            )
            let energy = min(max(cue.energy, 0), 1)
            let ambience = min(max(cue.ambience, 0), 1)
            let longSide = max(size.width, size.height)

            ZStack {
                // 极薄的镜头色温，保留封面与视频原本的层次。
                LinearGradient(
                    stops: [
                        .init(color: accent.opacity(0.035 + energy * 0.04), location: 0),
                        .init(color: companion.opacity(0.025 + ambience * 0.045), location: 0.52),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 两束舞台光从上方收向歌词中心，分幕变化时色温整体切换。
                directorBeam(
                    color: accent,
                    size: size,
                    leading: true,
                    strength: 0.10 + energy * 0.13
                )
                directorBeam(
                    color: companion,
                    size: size,
                    leading: false,
                    strength: 0.065 + ambience * 0.12
                )

                // 歌词区域的主光场，与歌词光学层使用同一分幕色。
                RadialGradient(
                    stops: [
                        .init(color: accent.opacity(0.08 + energy * 0.15), location: 0),
                        .init(color: companion.opacity(0.03 + ambience * 0.075), location: 0.46),
                        .init(color: .clear, location: 1)
                    ],
                    center: UnitPoint(x: tone.focusX, y: 0.58),
                    startRadius: 0,
                    endRadius: longSide * CGFloat(0.52 + ambience * 0.16)
                )

                // 地平线底光是 ambience 的明确落点，不再整屏泛白。
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.67),
                        .init(color: companion.opacity(0.04 + ambience * 0.10), location: 0.86),
                        .init(color: accent.opacity(0.075 + ambience * 0.13 + energy * 0.045), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .blendMode(.screen)
            .opacity(isPlaying ? 1 : 0.72)
        }
    }

    private func directorBeam(
        color: Color,
        size: CGSize,
        leading: Bool,
        strength: Double
    ) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, color, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(
                width: max(90, size.width * 0.18),
                height: size.height * 1.28
            )
            .rotationEffect(.degrees(leading ? -18 : 18), anchor: .top)
            .offset(
                x: CGFloat(leading ? -1 : 1) * size.width * 0.23,
                y: -size.height * 0.18
            )
            .blur(radius: 30)
            .mask(
                LinearGradient(
                    colors: [.white.opacity(0.94), .white.opacity(0.62), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(strength)
    }

    private func wrappedHue(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
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
}
