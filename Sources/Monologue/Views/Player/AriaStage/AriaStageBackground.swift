//
//  AriaStageBackground.swift
//  Monologue
//
//  全新沉浸模式的背景舞台 —— 从零复刻 folia-major 的 VisualizerShell 分层：
//  1. AriaFluidBackground（FluidBackground.tsx）：封面 40px 模糊铺满 + 主/次色对角渐变叠加
//  2. 主题底色层：backgroundColor 以 0.75 透明度压在流体层之上，保证歌词可读
//  3. AriaGeometricBackground（GeometricBackground.tsx）：15 个几何漂浮体（圆/方/三角/十字）
//     按分频能量弹簧缩放（圆→bass、方→lowMid、三角→mid、十字→treble）+ 20 颗上升粒子
//  4. AriaVignette：径向暗角，把视线聚拢到舞台中央
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

        return AriaPalette(background: background, primary: primary, secondary: secondaryColor, accent: accent)
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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let coverUrl {
                    // 封面模糊铺满：blur(40px) + scale(1.5)
                    CachedAsyncImage(url: coverUrl) {
                        palette.background
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: 40)
                    .scaleEffect(1.5)
                } else {
                    palette.background.opacity(0.8)
                }

                // 对角渐变（primary → 透明 → secondary），overlay 混合提亮质感
                LinearGradient(
                    colors: [palette.primary, .clear, palette.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.4)
                .blendMode(.overlay)

                // 三团径向色晕（folia iOS 路径的 radial washes）：给纯模糊封面补上色彩纵深
                ZStack {
                    RadialGradient(
                        colors: [palette.accent.opacity(0.33), .clear],
                        center: UnitPoint(x: 0.2, y: 0.2),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.42
                    )
                    RadialGradient(
                        colors: [palette.secondary.opacity(0.31), .clear],
                        center: UnitPoint(x: 0.8, y: 0.28),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.44
                    )
                    RadialGradient(
                        colors: [palette.primary.opacity(0.16), .clear],
                        center: UnitPoint(x: 0.5, y: 0.78),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.52
                    )
                }
                .opacity(0.5)

                // 主题底色压暗层（shell backgroundOpacity）
                palette.background.opacity(min(max(backgroundOpacity, 0.45), 0.95))
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

    private var shapes: [AriaShape] {
        Self.buildShapes(seed: seed)
    }

    private var particles: [AriaParticle] {
        Self.buildParticles(seed: seed)
    }

    var body: some View {
        let shapes = self.shapes
        let particles = self.particles

        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 60, paused: false)) { timeline in
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

// MARK: - 暗角（GeometricBackground.tsx VignetteOverlay）

struct AriaVignette: View {
    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.4),
                    .init(color: Color.black.opacity(0.6), location: 1)
                ],
                center: .center,
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.72
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
    /// staticMode 语义：关掉重资源几何层，保留底色 / 流体 / 歌词
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            AriaFluidBackground(
                coverUrl: coverUrl,
                palette: palette,
                backgroundOpacity: backgroundOpacity
            )

            if !reduceMotion {
                AriaGeometricBackground(
                    pulse: pulse,
                    palette: palette,
                    isPlaying: isPlaying,
                    seed: seed
                )
                // 换曲重建几何布局并重新淡入
                .id(seed)
            }

            AriaVignette()
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: palette)
    }
}
