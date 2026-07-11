//
//  AriaStageBackground.swift
//  Monologue
//
//  Folia-inspired immersive stage:
//  blurred cover identity, audio-reactive light,
//  depth/readability veils, restrained film grain, and a final vignette.
//  Ambient motion can freeze without removing the stage's visual hierarchy.
//

import SwiftUI
import UIKit

// MARK: - 主题调色盘（folia Theme 的封面取色派生）

struct AriaPalette: Equatable {
    /// 舞台底色（深色压暗的主色）
    var background: Color
    /// 歌词基础色（近白的暖色）
    var primary: Color
    /// 次要色（几何漂浮体 / 字幕）
    var secondary: Color
    /// 强调色（激活词高亮 / 辉光 / 粒子）
    var accent: Color
    /// 封面提取的完整调色板，供背景光场共享。
    var ambient: [Color] = []
    /// 歌词高亮多色轮换：全部封面色规范化为可读的强调色，逐句换色。
    var accentCycle: [Color] = []

    /// 取第 index 句歌词的强调色；未提取到多色时退回单一 accent。
    func cycledAccent(_ index: Int) -> Color {
        guard !accentCycle.isEmpty else { return accent }
        let count = accentCycle.count
        return accentCycle[((index % count) + count) % count]
    }

    /// 派生「本句专属」调色板：仅替换 accent，白色主字与背景不变。
    func lineVariant(_ index: Int) -> AriaPalette {
        guard accentCycle.count > 1 else { return self }
        var copy = self
        copy.accent = cycledAccent(index)
        return copy
    }

    static let fallback = AriaPalette(
        background: Color(red: 0.07, green: 0.07, blue: 0.10),
        primary: Color(red: 0.96, green: 0.96, blue: 0.98),
        secondary: Color(red: 0.62, green: 0.64, blue: 0.72),
        accent: Color(red: 0.55, green: 0.72, blue: 1.0)
    )

    /// 从封面取色派生四色主题：新增颜色全部从当前封面动态派生，不写死 hex
    /// folia 的主题色都是高饱和精调色，这里做两层保护避免派生出泥色：
    /// 1. 灰度/低饱和封面 → 兜底到柔和蓝紫舞台色相
    /// 2. 主次色相过近 → 把次色相错开 45°，保证几何漂浮体和辉光有层次
    static func derive(dominant: Color, secondary: Color) -> AriaPalette {
        var dom = HSB(dominant)
        var sec = HSB(secondary)

        if dom.saturation < 0.10 {
            dom.hue = 0.68
            dom.saturation = 0.32
        }
        if sec.saturation < 0.10 {
            sec.hue = (dom.hue + 0.09).truncatingRemainder(dividingBy: 1)
            sec.saturation = 0.28
        }
        let rawGap = abs(dom.hue - sec.hue)
        if min(rawGap, 1 - rawGap) < 0.06 {
            sec.hue = (dom.hue + 0.125).truncatingRemainder(dividingBy: 1)
        }

        let background = HSB(
            hue: dom.hue,
            saturation: min(max(dom.saturation * 0.80, 0.24), 0.62),
            brightness: max(0.10, min(dom.brightness * 0.30, 0.16))
        ).color

        let accent = HSB(
            hue: dom.hue,
            saturation: min(max(dom.saturation * 1.35, 0.48), 0.95),
            brightness: max(dom.brightness, 0.80)
        ).color

        let secondaryColor = HSB(
            hue: sec.hue,
            saturation: min(max(sec.saturation * 0.90, 0.22), 0.58),
            brightness: max(min(sec.brightness * 1.15, 0.86), 0.62)
        ).color

        let primary = HSB(
            hue: dom.hue,
            saturation: min(dom.saturation * 0.12, 0.08),
            brightness: 0.98
        ).color

        return AriaPalette(
            background: background,
            primary: primary,
            secondary: secondaryColor,
            accent: accent,
            ambient: [dominant, secondary]
        )
    }

    static func derive(colors: [Color]) -> AriaPalette {
        guard let dominant = colors.first else { return .fallback }
        var palette = derive(
            dominant: dominant,
            secondary: colors.dropFirst().first ?? dominant
        )
        palette.ambient = colors

        if colors.count > 2 {
            var third = HSB(colors[2])
            third.saturation = min(max(third.saturation, 0.22), 0.62)
            third.brightness = min(max(third.brightness, 0.62), 0.88)
            palette.secondary = third.color
        }

        // 每个封面色都规范化成深底可读的强调色；灰色不产生色相，剔除。
        // 同色相（15° 内）去重，避免两句歌词看起来是同一种颜色。
        var cycle: [Color] = []
        var usedHues: [CGFloat] = []
        for color in colors {
            let hsb = HSB(color)
            guard hsb.saturation >= 0.10 else { continue }
            let hueGap = usedHues
                .map { min(abs($0 - hsb.hue), 1 - abs($0 - hsb.hue)) }
                .min() ?? 1
            guard hueGap > 1.0 / 24.0 else { continue }
            usedHues.append(hsb.hue)
            cycle.append(
                HSB(
                    hue: hsb.hue,
                    saturation: min(max(hsb.saturation * 1.35, 0.48), 0.95),
                    brightness: max(hsb.brightness, 0.80)
                ).color
            )
        }
        if cycle.count > 1 {
            palette.accentCycle = cycle
        }
        return palette
    }

    private struct HSB {
        var hue: CGFloat
        var saturation: CGFloat
        var brightness: CGFloat

        init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
            self.hue = hue
            self.saturation = saturation
            self.brightness = brightness
        }

        init(_ color: Color) {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            hue = h
            saturation = s
            brightness = b
        }

        var color: Color {
            Color(hue: hue, saturation: saturation, brightness: brightness)
        }
    }
}

// MARK: - 流体背景（FluidBackground.tsx）

struct AriaFluidBackground: View {
    let coverUrl: URL?
    let palette: AriaPalette
    /// shell backgroundOpacity：越高越暗（歌词可读性 ↔ 封面显色），folia 默认 0.75
    let backgroundOpacity: Double
    /// 歌词景深：拉大与歌词的对焦差 —— 封面更虚、更远、更沉。
    var depthIntensity: Double = 0

    var body: some View {
        GeometryReader { geo in
            let depth = pow(min(max(depthIntensity, 0), 1), 0.72)
            let themeVeilOpacity = min(
                max(backgroundOpacity * 0.78, 0.34) + depth * 0.07,
                0.82
            )

            ZStack {
                palette.background

                if let coverUrl {
                    // 模糊必须大到让封面暗部化成色雾：半径不足时，
                    // 高对比封面会在背景上留下成块的"脏影"轮廓。
                    CachedAsyncImage(url: coverUrl) {
                        palette.background
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .scaleEffect(1.52 + depth * 0.08)
                    .blur(radius: 64 + depth * 22)
                    .saturation(1.18 - depth * 0.14)
                    .contrast(0.88)
                    .brightness(-0.03 - depth * 0.05)
                    .opacity(0.86)
                } else {
                    palette.background
                }

                // 不再用 overlay 混合叠色：overlay 会重新拉高模糊封面的
                // 局部对比，把化开的暗部又显影成不规则脏斑。普通混合只做轻着色。
                LinearGradient(
                    colors: [
                        palette.secondary.opacity(0.10),
                        .clear
                    ],
                    startPoint: .bottomTrailing,
                    endPoint: .center
                )

                LinearGradient(
                    stops: [
                        .init(color: palette.accent.opacity(0.10), location: 0),
                        .init(color: palette.accent.opacity(0.025), location: 0.42),
                        .init(color: .clear, location: 0.76)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                palette.background.opacity(themeVeilOpacity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 几何漂浮背景（GeometricBackground.tsx）

/// 分频通道：折射 folia AudioBands → 图形缩放的映射
private enum AriaBandKey {
    case bass, lowMid, mid, vocal, treble
}

private enum AriaShapeType: CaseIterable {
    case circle, square, triangle, cross

    var bandKey: AriaBandKey {
        switch self {
        case .circle: return .bass
        case .square: return .lowMid
        case .triangle: return .mid
        case .cross: return .treble
        }
    }
}

private struct AriaShape {
    let type: AriaShapeType
    let x: Double          // 0~1 相对位置
    let y: Double
    let size: Double       // 40~140 pt
    let duration: Double   // 漂移周期 30~60s
    let delay: Double
    let opacity: Double    // 0.11~0.19
    let reverse: Bool
    let filled: Bool
    let initialRotation: Double
}

private struct AriaParticle {
    let size: Double
    let x: Double
    let y: Double
    let opacity: Double
    let duration: Double
    let delay: Double
}

/// 分频弹簧平滑（framer useSpring stiffness 300 / damping 30 的离散等价）
/// 引用类型：Canvas 逐帧推进内部状态，不触发 SwiftUI 重渲染
private final class AriaBandSprings {
    private var values: [AriaBandKey: (position: Double, velocity: Double)] = [:]
    private var lastTime: Double = 0

    /// 返回本帧时间步长并推进内部时钟
    func advance(to time: Double) -> Double {
        let dt = lastTime > 0 ? time - lastTime : 1.0 / 60.0
        lastTime = time
        return min(max(dt, 0.001), 0.05)
    }

    func step(target: Double, key: AriaBandKey, dt: Double) -> Double {
        var state = values[key] ?? (target, 0)
        let stiffness = 300.0
        let damping = 30.0
        let accel = stiffness * (target - state.position) - damping * state.velocity
        state.velocity += accel * dt
        state.position += state.velocity * dt
        values[key] = state
        return state.position
    }
}

struct AriaGeometricBackground: View {
    let pulse: CinemaAudioPulse
    let palette: AriaPalette
    let isPlaying: Bool
    let seed: Double

    @State private var springs = AriaBandSprings()
    /// 换曲淡入（folia GeometricLayer 0.6s fade）
    @State private var appeared = false
    /// 热度/省电自动降档：medium 24fps、low 20fps
    @ObservedObject private var perf = CinemaPerformanceGovernor.shared

    private var shapes: [AriaShape] {
        Self.buildShapes(seed: seed)
    }

    private var particles: [AriaParticle] {
        Self.buildParticles(seed: seed)
    }

    /// 漂浮体周期 30~60s，30fps 已远超视觉需求；发热/省电时继续降
    private var canvasFPS: Int {
        switch perf.tier {
        case .high: return 30
        case .medium: return 24
        case .low: return 20
        }
    }

    var body: some View {
        let shapes = self.shapes
        let particles = self.particles

        TimelineView(AppFrameRate.throttledTimeline(maximumFramesPerSecond: canvasFPS, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let dt = springs.advance(to: t)

                let snap = pulse.snapshot()
                // 五路分频：项目频谱只有 bass/mid/treble，按 folia 语义补 lowMid/vocal
                let rawBands: [AriaBandKey: Double] = [
                    .bass: snap.bass,
                    .lowMid: (snap.bass + snap.mid) * 0.5,
                    .mid: snap.mid,
                    .vocal: (snap.mid + snap.treble) * 0.5 + snap.energy * 0.2,
                    .treble: snap.treble
                ]
                var bandScales: [AriaBandKey: Double] = [:]
                for (key, value) in rawBands {
                    // folia 把频段字节 [10,200] 映射到 [0.95,1.45]
                    let target = 0.95 + min(max(value, 0), 1) * 0.5
                    bandScales[key] = isPlaying ? springs.step(target: target, key: key, dt: dt) : 1.0
                }

                for shape in shapes {
                    let cycle = (t + shape.delay) / shape.duration
                    // 漂移：y ±30 / x ±15 往返
                    let phase = cycle * 2 * .pi
                    let direction: Double = shape.reverse ? -1 : 1
                    let dy = direction * sin(phase) * 30
                    let dx = -direction * sin(phase) * 15
                    let rotation = shape.initialRotation + (isPlaying ? t.truncatingRemainder(dividingBy: shape.duration) / shape.duration * 360 : 0)
                    let scale = bandScales[shape.type.bandKey] ?? 1.0

                    let center = CGPoint(
                        x: shape.x * size.width + dx,
                        y: shape.y * size.height + dy
                    )
                    let side = shape.size * scale

                    var layer = context
                    layer.opacity = shape.opacity
                    layer.translateBy(x: center.x, y: center.y)
                    layer.rotate(by: .degrees(rotation))

                    let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
                    let path = Self.path(for: shape.type, in: rect)

                    if shape.filled || shape.type == .triangle || shape.type == .cross {
                        layer.fill(path, with: .color(palette.secondary))
                    } else {
                        layer.stroke(path, with: .color(palette.secondary), lineWidth: 1)
                    }
                }

                // 上升粒子：0 → -100pt 循环，透明度三角包络
                for particle in particles {
                    let progress = ((t + particle.delay) / particle.duration).truncatingRemainder(dividingBy: 1)
                    let rise = isPlaying ? progress * 100.0 : 0
                    let envelope = progress < 0.5 ? progress * 2 : (1 - progress) * 2
                    let alpha = particle.opacity * envelope

                    let rect = CGRect(
                        x: particle.x * size.width - particle.size / 2,
                        y: particle.y * size.height - rise - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    var layer = context
                    layer.opacity = alpha
                    layer.fill(Path(ellipseIn: rect), with: .color(palette.accent))
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) { appeared = true }
        }
        .allowsHitTesting(false)
    }

    private static func path(for type: AriaShapeType, in rect: CGRect) -> Path {
        switch type {
        case .circle:
            return Path(ellipseIn: rect)
        case .square:
            return Path(rect)
        case .triangle:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
            return path
        case .cross:
            // GeometricBackground.tsx 的十字/星芒 clip-path 多边形
            let points: [(Double, Double)] = [
                (0.20, 0.00), (0.00, 0.20), (0.30, 0.50), (0.00, 0.80),
                (0.20, 1.00), (0.50, 0.70), (0.80, 1.00), (1.00, 0.80),
                (0.70, 0.50), (1.00, 0.20), (0.80, 0.00), (0.50, 0.30)
            ]
            var path = Path()
            for (index, point) in points.enumerated() {
                let cg = CGPoint(
                    x: rect.minX + rect.width * point.0,
                    y: rect.minY + rect.height * point.1
                )
                if index == 0 { path.move(to: cg) } else { path.addLine(to: cg) }
            }
            path.closeSubpath()
            return path
        }
    }

    private static func buildShapes(seed: Double) -> [AriaShape] {
        let types = AriaShapeType.allCases
        return (0..<15).map { index in
            let base = seed + Double(index) * 7.13
            func rand(_ offset: Double) -> Double { AriaLyricEngine.seededRandom(base, offset) }
            return AriaShape(
                type: types[Int(rand(0) * Double(types.count)) % types.count],
                x: rand(1),
                y: rand(2),
                size: 40 + rand(3) * 100,
                duration: 30 + rand(4) * 30,
                delay: rand(5) * 5,
                opacity: 0.11 + rand(6) * 0.08,
                reverse: rand(7) > 0.5,
                filled: rand(8) < 0.3,
                initialRotation: rand(9) * 360
            )
        }
    }

    private static func buildParticles(seed: Double) -> [AriaParticle] {
        (0..<20).map { index in
            let base = seed + 100 + Double(index) * 3.77
            func rand(_ offset: Double) -> Double { AriaLyricEngine.seededRandom(base, offset) }
            return AriaParticle(
                size: rand(0) * 4 + 1,
                x: rand(1),
                y: rand(2),
                opacity: rand(3) * 0.3,
                duration: 15 + rand(4) * 20,
                delay: rand(5) * 10
            )
        }
    }
}

// MARK: - Folia atmosphere

/// A low-frequency light composition instead of decorative floating objects.
/// Cover-derived glows establish depth while two broad light ribbons respond
/// to the audio envelope. The layer is always present; disabling motion only
/// freezes its choreography.
private struct AriaFoliaAtmosphere: View {
    let pulse: CinemaAudioPulse
    let palette: AriaPalette
    let isPlaying: Bool
    let motionEnabled: Bool
    let seed: Double

    @ObservedObject private var performance = CinemaPerformanceGovernor.shared
    @State private var appeared = false

    private var timelineFPS: Int {
        switch performance.tier {
        case .high: return 15
        case .medium: return 12
        case .low: return 8
        }
    }

    var body: some View {
        TimelineView(
            AppFrameRate.throttledTimeline(
                maximumFramesPerSecond: timelineFPS,
                paused: !isPlaying || !motionEnabled
            )
        ) { timeline in
            Canvas(
                opaque: false,
                colorMode: .linear,
                rendersAsynchronously: true
            ) { context, size in
                let liveTime = timeline.date.timeIntervalSinceReferenceDate
                let time = motionEnabled && isPlaying ? liveTime : seed
                let phase = seed.truncatingRemainder(dividingBy: 360) / 57.2958
                let driftA = CGFloat(sin(time / 17 + phase))
                let driftB = CGFloat(cos(time / 23 + phase * 0.7))
                let snapshot = pulse.snapshot()
                let energy = isPlaying
                    ? min(max(snapshot.energy * 0.82 + snapshot.mid * 0.18, 0), 1)
                    : 0
                let ribbonLift = driftA * size.height * 0.025
                let lowerRibbonLift = driftB * size.height * 0.022
                var upperRibbon = Path()
                upperRibbon.move(to: CGPoint(x: -size.width * 0.08, y: size.height * 0.34))
                upperRibbon.addCurve(
                    to: CGPoint(x: size.width * 1.08, y: size.height * 0.48),
                    control1: CGPoint(
                        x: size.width * 0.26,
                        y: size.height * 0.18 + ribbonLift
                    ),
                    control2: CGPoint(
                        x: size.width * 0.72,
                        y: size.height * 0.60 - ribbonLift
                    )
                )

                var lowerRibbon = Path()
                lowerRibbon.move(to: CGPoint(x: -size.width * 0.06, y: size.height * 0.76))
                lowerRibbon.addCurve(
                    to: CGPoint(x: size.width * 1.06, y: size.height * 0.62),
                    control1: CGPoint(
                        x: size.width * 0.30,
                        y: size.height * 0.88 - lowerRibbonLift
                    ),
                    control2: CGPoint(
                        x: size.width * 0.68,
                        y: size.height * 0.48 + lowerRibbonLift
                    )
                )

                // 大气光雾：整幅解析渐变填充，无任何描边几何。
                // 之前的超宽描边曲线在急弯处内缘自我折叠，模糊后仍会露出
                // 锯齿状"撕纸"边，这里的渐变在数学上连续，不可能出现形状边缘。
                let fullRect = Path(CGRect(origin: .zero, size: size))
                let washCenterA = 0.40 + Double(driftA) * 0.06
                let washCenterB = 0.62 + Double(driftB) * 0.05

                var washContext = context
                washContext.blendMode = .screen
                washContext.fill(
                    fullRect,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(
                                color: palette.accent.opacity(0.045 + energy * 0.04),
                                location: max(0.02, washCenterA - 0.17)
                            ),
                            .init(
                                color: palette.accent.opacity(0.065 + energy * 0.05),
                                location: washCenterA
                            ),
                            .init(
                                color: palette.primary.opacity(0.02),
                                location: min(0.97, washCenterA + 0.19)
                            ),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )
                washContext.fill(
                    fullRect,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(
                                color: palette.secondary.opacity(0.035 + energy * 0.03),
                                location: max(0.02, washCenterB - 0.16)
                            ),
                            .init(
                                color: palette.secondary.opacity(0.05 + energy * 0.035),
                                location: washCenterB
                            ),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: CGPoint(x: 0, y: size.height),
                        endPoint: CGPoint(x: size.width, y: 0)
                    )
                )

                var ribbonContext = context
                ribbonContext.blendMode = .plusLighter
                ribbonContext.addFilter(.blur(radius: 12))
                ribbonContext.stroke(
                    upperRibbon,
                    with: .linearGradient(
                        Gradient(colors: [
                            .clear,
                            palette.accent.opacity(0.08 + energy * 0.05),
                            palette.primary.opacity(0.025),
                            .clear
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    lineWidth: 1.2 + CGFloat(energy) * 2.4
                )
                ribbonContext.stroke(
                    lowerRibbon,
                    with: .linearGradient(
                        Gradient(colors: [
                            .clear,
                            palette.secondary.opacity(0.065 + energy * 0.035),
                            palette.accent.opacity(0.03),
                            .clear
                        ]),
                        startPoint: CGPoint(x: 0, y: size.height),
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    lineWidth: 1 + CGFloat(energy) * 1.8
                )
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                appeared = true
            }
        }
        .allowsHitTesting(false)
    }

}

private struct AriaStageReadabilityVeil: View {
    var videoMode = false

    var body: some View {
        GeometryReader { proxy in
            let longestSide = max(proxy.size.width, proxy.size.height)

            ZStack {
                RadialGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.38),
                        .init(color: .black.opacity(videoMode ? 0.16 : 0.10), location: 0.72),
                        .init(color: .black.opacity(videoMode ? 0.42 : 0.30), location: 1)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: longestSide * 0.76
                )

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(videoMode ? 0.30 : 0.18), location: 0),
                        .init(color: .clear, location: 0.28),
                        .init(color: .clear, location: 0.67),
                        .init(color: .black.opacity(videoMode ? 0.44 : 0.28), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Fine static luminance variation breaks up large gradients without looking
/// like particles or a star field.
private struct AriaStageGrain: View {
    let seed: Double

    var body: some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, size in
            var grain = Path()
            for index in 0..<280 {
                let pointSeed = seed + Double(index) * 7.13
                let x = CGFloat(AriaLyricEngine.seededRandom(pointSeed, 1)) * size.width
                let y = CGFloat(AriaLyricEngine.seededRandom(pointSeed, 2)) * size.height
                let side = CGFloat(
                    0.45 + AriaLyricEngine.seededRandom(pointSeed, 3) * 0.75
                )
                grain.addRect(CGRect(x: x, y: y, width: side, height: side))
            }

            context.opacity = 0.035
            context.fill(grain, with: .color(.white))
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

// MARK: - 暗角（GeometricBackground.tsx VignetteOverlay）

struct AriaVignette: View {
    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.48),
                    .init(color: Color.black.opacity(0.16), location: 0.74),
                    .init(color: Color.black.opacity(0.48), location: 1)
                ],
                center: .center,
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.82
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 舞台外壳（VisualizerShell.tsx）

struct AriaStageShell: View {
    let coverUrl: URL?
    let palette: AriaPalette
    let pulse: CinemaAudioPulse
    let isPlaying: Bool
    let seed: Double
    let backgroundOpacity: Double
    /// Freezes ambient choreography while preserving the complete stage.
    let reduceMotion: Bool
    /// A bound video remains the primary background; only the readability and
    /// texture finishing layers are shared with the cover-driven stage.
    var videoURL: URL? = nil
    /// 歌词景深强度：以「背景更虚、更沉」表达对焦分离，不绘制任何形状化底衬。
    var depthIntensity: Double = 0

    var body: some View {
        let depth = pow(min(max(depthIntensity, 0), 1), 0.72)

        ZStack {
            if let videoURL {
                ImmersiveVideoBackground(url: videoURL, isActive: isPlaying)
                    .ignoresSafeArea()

                // 视频不逐帧模糊（代价过高），用均匀压暗表达景深，无边界即无伪影。
                Color.black.opacity(0.16 * depth)

                AriaStageReadabilityVeil(videoMode: true)
                AriaStageGrain(seed: seed)
            } else {
                AriaFluidBackground(
                    coverUrl: coverUrl,
                    palette: palette,
                    backgroundOpacity: backgroundOpacity,
                    depthIntensity: depthIntensity
                )

                AriaFoliaAtmosphere(
                    pulse: pulse,
                    palette: palette,
                    isPlaying: isPlaying,
                    motionEnabled: !reduceMotion,
                    seed: seed
                )
                // Rebuild on track changes so each album gets a stable scene.
                .id(seed)

                AriaStageReadabilityVeil()
                AriaStageGrain(seed: seed)
            }

            AriaVignette()
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: palette)
    }
}
