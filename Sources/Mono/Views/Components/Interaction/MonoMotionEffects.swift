import SwiftUI

/// Mono 的短时交互动效组件。这里只承载由真实状态触发的动画；持续视觉效果
/// 仍由对应播放器/背景组件负责，避免普通列表因为动画而保持高频刷新。
enum MonoMotionEffects {
    static let selection = Animation.spring(response: 0.24, dampingFraction: 0.76)
    static let completion = Animation.spring(response: 0.34, dampingFraction: 0.66)
    static let stateChange = Animation.spring(response: 0.30, dampingFraction: 0.88)
}

private struct MonoCompletionValues {
    var scale: CGFloat = 1
    var verticalScale: CGFloat = 1
    var offsetY: CGFloat = 0
    var rotation: Angle = .zero
}

@available(iOS 17.0, *)
private struct MonoCompletionKeyframeModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: MonoCompletionValues(),
            trigger: trigger
        ) { view, value in
            view
                .scaleEffect(value.scale)
                .scaleEffect(y: value.verticalScale)
                .offset(y: value.offsetY)
                .rotationEffect(value.rotation)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(0.90, duration: 0.07)
                SpringKeyframe(1.18, duration: 0.18, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.24, spring: .smooth)
            }
            KeyframeTrack(\.verticalScale) {
                LinearKeyframe(0.82, duration: 0.07)
                SpringKeyframe(1.08, duration: 0.16, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.26, spring: .smooth)
            }
            KeyframeTrack(\.offsetY) {
                LinearKeyframe(1.5, duration: 0.07)
                SpringKeyframe(-2.5, duration: 0.17, spring: .snappy)
                SpringKeyframe(0, duration: 0.25, spring: .smooth)
            }
            KeyframeTrack(\.rotation) {
                LinearKeyframe(.degrees(-5), duration: 0.07)
                SpringKeyframe(.degrees(3), duration: 0.16, spring: .snappy)
                SpringKeyframe(.zero, duration: 0.26, spring: .smooth)
            }
        }
    }
}

private struct MonoCompletionFallbackModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @State private var expanded = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(expanded ? 1.14 : 1)
            .onChange(of: trigger) { _, _ in
                withAnimation(MonoMotionEffects.completion) {
                    expanded = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        expanded = false
                    }
                }
            }
    }
}

extension View {
    /// 收藏、加入歌单、Agent 完成等一次性状态变化使用同一套物理节奏。
    @ViewBuilder
    func monoCompletionMotion<Trigger: Equatable>(
        trigger: Trigger,
        reduceMotion: Bool = false
    ) -> some View {
        if reduceMotion {
            self
        } else if #available(iOS 17.0, *) {
            modifier(MonoCompletionKeyframeModifier(trigger: trigger))
        } else {
            modifier(MonoCompletionFallbackModifier(trigger: trigger))
        }
    }

}

/// 只在任务真正运行时刷新波面；progress 为 nil 表示服务端未提供可量化进度，
/// 此时显示明确的“不定进度”流动，而不是伪造百分比。
struct MonoLiquidProgressBar: View {
    let progress: Double?
    var tint: Color = .monoAccent
    var secondaryTint: Color? = nil
    var isActive = true
    var height: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isComplete: Bool {
        (progress ?? 0) >= 0.999
    }

    var body: some View {
        TimelineView(
            AppFrameRate.animationTimeline(
                maximumFramesPerSecond: 30,
                paused: reduceMotion || scenePhase != .active || !isActive || isComplete
            )
        ) { context in
            GeometryReader { proxy in
                let phase = reduceMotion
                    ? 0
                    : context.date.timeIntervalSinceReferenceDate * 2.4
                let resolvedProgress = visibleProgress(at: context.date)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))

                    MonoLiquidProgressShape(
                        progress: resolvedProgress,
                        phase: phase
                    )
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.82), secondaryTint ?? tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(Capsule(style: .continuous))

                    if resolvedProgress > 0.03 {
                        MonoLiquidProgressShape(
                            progress: resolvedProgress,
                            phase: phase + 1.7,
                            amplitudeScale: 0.44
                        )
                        .stroke(Color.white.opacity(0.32), lineWidth: max(0.6, height * 0.08))
                        .clipShape(Capsule(style: .continuous))
                    }
                }
                .animation(
                    reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.92),
                    value: progress
                )
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(accessibilityProgress)
    }

    private func visibleProgress(at date: Date) -> Double {
        if let progress {
            return min(max(progress, 0), 1)
        }
        guard isActive else { return 0 }
        let cycle = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 1.55) / 1.55
        return 0.18 + cycle * 0.64
    }

    private var accessibilityProgress: String {
        guard let progress else { return String(localized: "正在处理") }
        return "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
    }
}

private struct MonoLiquidProgressShape: Shape {
    let progress: Double
    let phase: Double
    var amplitudeScale: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let clamped = CGFloat(min(max(progress, 0), 1))
        let front = rect.width * clamped
        let amplitude = min(max(rect.height * 0.28, 1.2), 5) * amplitudeScale
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: max(front - amplitude, 0), y: rect.minY))

        let steps = max(Int(rect.height.rounded(.up)), 8)
        for step in 0...steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            let y = rect.minY + fraction * rect.height
            let envelope = sin(fraction * .pi)
            let broad = sin(Double(fraction) * .pi * 2.15 + phase) * Double(amplitude)
            let detail = sin(Double(fraction) * .pi * 5.2 - phase * 0.72)
                * Double(amplitude * 0.34 * envelope)
            let x = min(max(front + CGFloat(broad + detail), 0), rect.width)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

enum MonoStatusKind: Equatable {
    case idle
    case active
    case scanned
    case success
    case failed
}

/// 登录、同步和 Agent 状态共用的紧凑状态标记。
struct MonoStatusBeacon: View {
    let kind: MonoStatusKind
    var tint: Color = .monoAccent
    var size: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if kind == .active || kind == .scanned {
                Circle()
                    .stroke(tint.opacity(0.26), lineWidth: 1.2)
                    .frame(width: size * 1.75, height: size * 1.75)
                    .compatBlink(dimOpacity: reduceMotion ? 1 : 0.35, duration: 0.72)
            }

            Circle()
                .fill(resolvedColor)
                .frame(width: size, height: size)
                .overlay {
                    if kind == .success {
                        MonoIcon(icon: .checkmark, size: size * 0.54, color: .white, lineWidth: 2)
                    }
                }
                .monoCompletionMotion(trigger: kind, reduceMotion: reduceMotion)
        }
        .frame(width: size * 1.8, height: size * 1.8)
    }

    private var resolvedColor: Color {
        switch kind {
        case .idle: return Color.monoTextSecondary.opacity(0.52)
        case .active, .scanned: return tint
        case .success: return .green
        case .failed: return .red
        }
    }
}

struct MonoCompletionMark: View {
    let trigger: Int
    var tint: Color = .green
    var size: CGFloat = 58

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: size, height: size)
            Circle()
                .stroke(tint.opacity(0.28), lineWidth: 1)
                .frame(width: size, height: size)
            MonoIcon(icon: .checkmark, size: size * 0.38, color: tint, lineWidth: 2.4)
        }
        .monoCompletionMotion(trigger: trigger, reduceMotion: reduceMotion)
        .accessibilityHidden(true)
    }
}

/// 短时粒子环，只在 trigger 变化后的约 0.5 秒存在，不持有常驻时间轴。
struct MonoCompletionBurst: View {
    let trigger: Int
    var tint: Color = .green
    var radius: CGFloat = 22
    var particleCount = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var visible = false
    @State private var generation = 0

    var body: some View {
        ZStack {
            ForEach(0..<max(particleCount, 1), id: \.self) { index in
                Circle()
                    .fill(tint.opacity(0.72))
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: expanded ? -radius : -(radius * 0.35))
                    .rotationEffect(.degrees(Double(index) * (360 / Double(max(particleCount, 1)))))
            }
        }
        .opacity(visible ? (expanded ? 0 : 1) : 0)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            generation += 1
            let currentGeneration = generation
            expanded = false
            visible = true
            withAnimation(.easeOut(duration: 0.46)) {
                expanded = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard generation == currentGeneration else { return }
                visible = false
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
