import SwiftUI

/// 影院沉浸播放器的星河粒子舞台 — 复刻 Mineradio 银河背景的驱动方式。
/// 粒子亮度/尺寸/扩散由引擎输出的 uBass/uMid/uTreble/uBeat/uEnergy 驱动，
/// 整个舞台再叠加节拍镜头（radiusKick 变焦、phiKick 俯仰、rollKick 滚转）的 punch。
struct CinemaParticleStage: View {
    let pulse: CinemaAudioPulse
    var isPlaying: Bool
    var accent: Color = .white
    /// 陀螺仪视差：背景反向缓移（远景动得慢且反向 → 纵深）
    var motion: CinemaMotionParallax? = nil

    private struct Particle {
        let angle: Double
        let radius: Double       // 归一化轨道半径 0~1
        let orbitSpeed: Double
        let size: Double
        let baseAlpha: Double
        let phase: Double
        let tint: Double         // 0=白，1=accent
        let depth: Double        // 0=远景 1=近景（Mineradio 距离衰减语义）
    }

    private static let particles: [Particle] = {
        var generator = SeededRandom(seed: 0x51EA)
        return (0..<110).map { _ in
            Particle(
                angle: generator.next() * .pi * 2,
                radius: 0.12 + pow(generator.next(), 0.72) * 0.88,
                orbitSpeed: (generator.next() - 0.5) * 0.16,
                size: 0.8 + generator.next() * 2.6,
                baseAlpha: 0.10 + generator.next() * 0.45,
                phase: generator.next() * .pi * 2,
                tint: generator.next(),
                depth: generator.next()
            )
        }
    }()

    var body: some View {
        // 不播放时星河只做慢速漂移，30fps 足够；播放中才拉满
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: isPlaying ? 60 : 30, paused: false)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let snap = pulse.snapshot()

                // 节拍镜头：radiusKick 拉近镜头（放大舞台）、phiKick 俯仰位移、rollKick 滚转
                // 慢速反向漂移与前景封面舞台同频（0.21/0.15），形成背景远、封面近的视差纵深
                let zoom: Double = 1 + snap.radiusKick * 0.42
                let tiltX: Double = motion?.tiltX ?? 0
                let tiltY: Double = motion?.tiltY ?? 0
                let driftX: CGFloat = CGFloat(sin(t * 0.21) * -20 + tiltX * -30)
                let driftY: CGFloat = CGFloat(sin(t * 0.15 + 1.3) * -12 + tiltY * -20)
                let centerX: CGFloat = size.width / 2 + driftX
                let centerY: CGFloat = size.height * 0.44 + driftY + CGFloat(snap.phiKick) * size.height * 6
                let center = CGPoint(x: centerX, y: centerY)
                let roll: Double = snap.rollKick * 14
                let maxR: Double = Double(min(size.width, size.height)) * 0.62 * zoom

                // 中心辉光：bass 呼吸 + beatPulse 爆发 + lyricSun 副歌溢光
                let glowR: Double = maxR * (0.34 + snap.bass * 0.24 + snap.beatPulse * 0.22)
                let glowAlpha: Double = 0.04 + snap.bass * 0.09 + snap.beatPulse * 0.13 + snap.lyricSun * 0.10
                if glowAlpha > 0.045 {
                    let gradient = Gradient(stops: [
                        .init(color: accent.opacity(glowAlpha), location: 0),
                        .init(color: accent.opacity(glowAlpha * 0.35), location: 0.5),
                        .init(color: .clear, location: 1)
                    ])
                    let glowRC = CGFloat(glowR)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - glowRC, y: center.y - glowRC,
                            width: glowRC * 2, height: glowRC * 2)),
                        with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: glowRC)
                    )
                }

                let kickDrive: Double = snap.beatPulse + snap.punch * 0.6
                let alphaBoost: Double = 1 + snap.beatPulse * 0.9 + snap.treble * 0.5 + snap.mid * 0.3 + snap.energy * 0.2
                let sizeKick: Double = (snap.beatPulse + snap.punch * 0.5) * 0.5

                for p in Self.particles {
                    let angle: Double = p.angle + t * p.orbitSpeed + roll * 0.02
                    // bass 呼吸推动整体半径；beat + punch 向外冲击（外圈响应更强）
                    // 整体呼吸缩放（原版 breathe = 1 + sin(uTime*0.34+phase)*0.045）
                    let breathe: Double = 1 + sin(t * 0.34 + p.phase) * 0.045
                    let wobble: Double = sin(t * 0.5 + p.phase) * 0.02
                    let expansion: Double = (1 + snap.bass * 0.14 + kickDrive * 0.10 * p.radius) * breathe
                    let r: Double = (p.radius + wobble) * expansion * maxR

                    // 深度视差：近景星随镜头漂移动得更多（远景 0.3x，近景 1x）
                    let parallax: CGFloat = CGFloat(0.30 + p.depth * 0.70)
                    let x: CGFloat = center.x + CGFloat(cos(angle) * r) + driftX * (parallax - 1)
                    let y: CGFloat = center.y + CGFloat(sin(angle) * r * 0.86) + driftY * (parallax - 1)
                    guard x > -8, x < size.width + 8, y > -8, y < size.height + 8 else { continue }

                    // treble 驱动闪烁密度，mid 驱动整体底亮
                    let twinkleFreq: Double = 0.8 + p.tint * (1 + snap.treble * 2)
                    let twinklePhase: Double = t * twinkleFreq + p.phase * 3
                    let twinkle: Double = 0.5 + 0.5 * sin(twinklePhase)
                    // 距离衰减：远景更暗更小（原版 vA/gl_PointSize 随 dist 衰减）
                    let twinkleGain: Double = 0.50 + twinkle * 0.50
                    let depthGain: Double = 0.42 + p.depth * 0.58
                    var alpha: Double = p.baseAlpha * twinkleGain * depthGain
                    alpha *= alphaBoost
                    alpha = min(alpha, 0.9)

                    let depthSize: Double = 0.55 + p.depth * 0.75
                    let kickSize: Double = 1 + sizeKick * p.tint
                    let d: CGFloat = CGFloat(p.size * depthSize * kickSize)
                    let color: Color = p.tint > 0.72 ? accent.opacity(alpha) : Color.white.opacity(alpha)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 可复现的轻量随机数（避免每次进入布局粒子分布跳变）
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 100_000) / 100_000
    }
}
