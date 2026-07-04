import SwiftUI

/// 沉浸舞台的景深粒子层 — 用不同视差速率制造纵深：
/// - midDust：封面后方的中景漂尘（小亮点，中等视差）
/// - foregroundBokeh：镜头前的失焦光斑（大而虚，视差最强，像贴着镜头飘过）
/// 陀螺仪/镜头动时各层按深度比例移动，是空间感最直接的来源。
struct CinemaDepthDust: View {
    enum Preset {
        case midDust
        case foregroundBokeh
    }

    let pulse: CinemaAudioPulse
    let motion: CinemaMotionParallax?
    let preset: Preset
    var accent: Color = .white
    var isPlaying: Bool = true

    private struct Mote {
        let x: Double        // 0~1 归一化位置
        let y: Double
        let size: Double
        let alpha: Double
        let phase: Double
        let driftSpeed: Double
        let tint: Double     // 0=白 1=accent
    }

    private static func makeMotes(count: Int, sizeRange: ClosedRange<Double>, alphaRange: ClosedRange<Double>, seed: UInt64) -> [Mote] {
        var g = DustSeededRandom(seed: seed)
        return (0..<count).map { _ in
            Mote(
                x: g.next(),
                y: g.next(),
                size: sizeRange.lowerBound + g.next() * (sizeRange.upperBound - sizeRange.lowerBound),
                alpha: alphaRange.lowerBound + g.next() * (alphaRange.upperBound - alphaRange.lowerBound),
                phase: g.next() * .pi * 2,
                driftSpeed: 0.4 + g.next() * 0.9,
                tint: g.next()
            )
        }
    }

    private static let midMotes = makeMotes(count: 34, sizeRange: 1.4...3.6, alphaRange: 0.08...0.24, seed: 0xD057)
    private static let bokehMotes = makeMotes(count: 6, sizeRange: 18...44, alphaRange: 0.03...0.07, seed: 0xB0CE)

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: false)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let snap = pulse.snapshot()
                let tiltX = motion?.tiltX ?? 0
                let tiltY = motion?.tiltY ?? 0

                let motes: [Mote]
                let parallax: Double
                let breathe: Double
                switch preset {
                case .midDust:
                    motes = Self.midMotes
                    parallax = 46
                    breathe = 1 + snap.bass * 0.35 + snap.beatPulse * 0.5
                case .foregroundBokeh:
                    motes = Self.bokehMotes
                    parallax = 150
                    breathe = 1 + snap.beatPulse * 0.25
                }

                // 镜头慢速漂移与陀螺仪共同驱动（前景同向且更快 → 离观者近）
                let camX = sin(t * 0.21) * 0.5 + tiltX
                let camY = sin(t * 0.15 + 1.3) * 0.35 + tiltY

                for m in motes {
                    // 自身缓慢漂浮 + 镜头视差
                    var px = m.x + sin(t * 0.030 * m.driftSpeed + m.phase) * 0.05
                    var py = m.y + sin(t * 0.024 * m.driftSpeed + m.phase * 1.7) * 0.04
                    px = px.truncatingRemainder(dividingBy: 1); if px < 0 { px += 1 }
                    py = py.truncatingRemainder(dividingBy: 1); if py < 0 { py += 1 }

                    let x = px * Double(size.width) + camX * parallax
                    let y = py * Double(size.height) + camY * parallax * 0.7
                    let twinkle = 0.75 + 0.25 * sin(t * (0.8 + m.driftSpeed) + m.phase * 3)
                    let alpha = m.alpha * twinkle * breathe
                    let d = m.size * breathe
                    let rect = CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)

                    let color: Color = m.tint > 0.65 ? accent : .white
                    switch preset {
                    case .midDust:
                        context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                    case .foregroundBokeh:
                        // 失焦光斑：径向渐变模拟散景，无需真实 blur
                        let gradient = Gradient(stops: [
                            .init(color: color.opacity(alpha), location: 0),
                            .init(color: color.opacity(alpha * 0.4), location: 0.55),
                            .init(color: .clear, location: 1)
                        ])
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                gradient,
                                center: CGPoint(x: x, y: y),
                                startRadius: 0,
                                endRadius: d / 2
                            )
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DustSeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 100_000) / 100_000
    }
}
