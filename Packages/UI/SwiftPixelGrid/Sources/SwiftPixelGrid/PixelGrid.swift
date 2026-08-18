import SwiftUI

/// 使用 Canvas 绘制的 3×3 像素动画。
public struct PixelGrid: View {
    private let appearance: PixelGridAppearance
    private let bloom: PixelGridBloom
    private let cornerRadius: CGFloat
    private let isAnimating: Bool
    private let playback: PixelGridPlayback
    private let scale: CGFloat
    private let accessibilityText: String

    /// 使用连续延迟动画创建 Canvas 像素网格。
    public init(
        animation: PixelGridAnimation = PixelGridPreset.waveLeftToRight.animation,
        bloom: PixelGridBloom = .disabled,
        cornerRadius: CGFloat = 0,
        isAnimating: Bool = true,
        scale: CGFloat = 1,
        accessibilityLabel: String = "Loading"
    ) {
        self.init(
            appearance: animation.appearance,
            bloom: bloom,
            cornerRadius: cornerRadius,
            isAnimating: isAnimating,
            playback: .delay(PixelDelayEngine(animation: animation)),
            scale: scale,
            accessibilityLabel: accessibilityLabel
        )
    }

    /// 使用内置预设创建 Canvas 像素网格。
    public init(
        preset: PixelGridPreset,
        bloom: PixelGridBloom = .disabled,
        cornerRadius: CGFloat = 0,
        isAnimating: Bool = true,
        scale: CGFloat = 1,
        accessibilityLabel: String = "Loading"
    ) {
        self.init(
            animation: preset.animation,
            bloom: bloom,
            cornerRadius: cornerRadius,
            isAnimating: isAnimating,
            scale: scale,
            accessibilityLabel: accessibilityLabel
        )
    }

    /// 使用 Pattern 离散帧引擎驱动同一套 Canvas 渲染器。
    public init(
        pattern: PixelPattern,
        frameDuration: TimeInterval = 0.1,
        transitionDuration: TimeInterval = 0.08,
        color: PixelGridColor = .cyan,
        colors: [PixelGridColor]? = nil,
        bloom: PixelGridBloom = .disabled,
        cornerRadius: CGFloat = 0,
        isAnimating: Bool = true,
        scale: CGFloat = 1,
        accessibilityLabel: String = "Loading"
    ) {
        self.init(
            appearance: PixelGridAppearance(
                color: color,
                colors: colors
            ),
            bloom: bloom,
            cornerRadius: cornerRadius,
            isAnimating: isAnimating,
            playback: .pattern(
                PixelPatternEngine(
                    pattern: pattern,
                    frameDuration: frameDuration,
                    transitionDuration: transitionDuration
                )
            ),
            scale: scale,
            accessibilityLabel: accessibilityLabel
        )
    }

    private init(
        appearance: PixelGridAppearance,
        bloom: PixelGridBloom,
        cornerRadius: CGFloat,
        isAnimating: Bool,
        playback: PixelGridPlayback,
        scale: CGFloat,
        accessibilityLabel: String
    ) {
        self.appearance = appearance
        self.bloom = bloom
        self.cornerRadius = min(max(cornerRadius, 0), 1.5)
        self.isAnimating = isAnimating
        self.playback = playback
        self.scale = max(scale, 0.1)
        self.accessibilityText = accessibilityLabel
    }

    public var body: some View {
        PixelGridPlaybackTimeline(
            playback: playback,
            isAnimating: isAnimating
        ) { sample in
            PixelGridCanvas(
                appearance: appearance,
                frame: sample.frame,
                bloom: bloom,
                cornerRadius: cornerRadius,
                scale: scale
            )
            .animation(
                canvasAnimation(for: sample),
                value: sample.frame
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(Text(isAnimating ? "Animating" : "Stopped"))
    }

    private func canvasAnimation(
        for sample: PixelGridPlaybackSample
    ) -> Animation? {
        guard sample.allowsMotion,
            let duration = sample.transitionDuration
        else {
            return nil
        }
        return .easeOut(duration: duration)
    }
}

/// Canvas 与普通视图渲染器共享的额外柔光配置。
public struct PixelGridBloom: Hashable, Sendable {
    /// 柔光半径；关闭时为 `nil`。
    public let amount: CGFloat?

    /// 柔光不透明度，范围为 `0...1`。
    public let intensity: Double

    /// 关闭额外柔光。
    public static let disabled = Self(amount: nil, intensity: 0)

    /// 标准柔光配置。
    public static let standard = Self(amount: 2, intensity: 0.28)

    /// 当前配置是否会绘制额外柔光。
    public var isEnabled: Bool {
        amount != nil && intensity > 0
    }

    /// 创建柔光配置；非法半径或零强度会转换为 ``disabled``。
    public init(amount: CGFloat, intensity: Double = 0.28) {
        let normalizedIntensity = min(max(intensity, 0), 1)
        if amount > 0 && amount.isFinite && normalizedIntensity > 0 {
            self.amount = amount
            self.intensity = normalizedIntensity
        } else {
            self.amount = nil
            self.intensity = 0
        }
    }

    private init(amount: CGFloat?, intensity: Double) {
        self.amount = amount
        self.intensity = intensity
    }
}

// Swift 6.1 尚不支持带全局 Actor 的协议遵循语法，延后隔离检查以兼容 Xcode 16。
private struct PixelGridCanvas: View, @preconcurrency Animatable {
    private static let cellSize: CGFloat = 3
    private static let cellStep: CGFloat = 4
    private static let innerGlowRadius: CGFloat = 3
    private static let outerGlowRadius: CGFloat = 6

    let appearance: PixelGridAppearance
    var frame: PixelGridFrame
    let bloom: PixelGridBloom
    let cornerRadius: CGFloat
    let scale: CGFloat

    var animatableData: PixelGridFrame {
        get { frame }
        set { frame = newValue }
    }

    var body: some View {
        let gridSize = 11 * scale
        let effectExtent =
            max(
                Self.outerGlowRadius,
                (bloom.amount ?? 0) * 3
            ) * scale
        let canvasSize = gridSize + effectExtent * 2

        Color.clear
            .frame(width: gridSize, height: gridSize)
            .overlay {
                // 网格很小，同步提交可避免异步 Canvas 合帧造成动画节奏不均。
                Canvas(
                    opaque: false,
                    colorMode: .nonLinear,
                    rendersAsynchronously: false
                ) { context, _ in
                    let origin = CGPoint(x: effectExtent, y: effectExtent)
                    drawGrid(context: &context, origin: origin)
                }
                .frame(width: canvasSize, height: canvasSize)
            }
    }

    private func drawGrid(context: inout GraphicsContext, origin: CGPoint) {
        // 先集中绘制全部光晕，避免后绘制单元的阴影盖住先绘制单元的本体，
        // 从而在某些边缘形成类似描边的不均匀亮边。
        for cell in PixelGridFrame.Cell.allCases {
            let path = cellPath(at: cell, origin: origin)
            let palette = appearance.palette(at: cell)
            let intensity = frame.intensity(at: cell)

            guard intensity > 0 else { continue }

            // 基础微光始终保留，额外 Bloom 只负责增强柔光。
            drawHighlight(
                context: &context,
                path: path,
                color: palette.glowColor.opacity(0.55 * intensity),
                radius: Self.innerGlowRadius * scale
            )
            drawHighlight(
                context: &context,
                path: path,
                color: palette.glowColor.opacity(0.28 * intensity),
                radius: Self.outerGlowRadius * scale
            )

            if let amount = bloom.amount {
                // Bloom 是常驻微光之外的额外柔光增强。
                drawHighlight(
                    context: &context,
                    path: path,
                    color: palette.glowColor.opacity(bloom.intensity * intensity),
                    radius: amount * scale
                )
            }
        }

        // 暗色底层始终存在，让动画看起来是在同一组像素上逐格点亮。
        for cell in PixelGridFrame.Cell.allCases {
            let path = cellPath(at: cell, origin: origin)
            let palette = appearance.palette(at: cell)
            context.fill(
                path,
                with: .color(palette.offColor)
            )
        }

        // 点亮层只改变不透明度，本体始终使用同一个 on 色，避免过渡过程中
        // 因颜色插值或阴影覆盖而出现色心与边缘不一致。
        for cell in PixelGridFrame.Cell.allCases {
            let intensity = frame.intensity(at: cell)
            guard intensity > 0 else { continue }

            context.fill(
                cellPath(at: cell, origin: origin),
                with: .color(
                    appearance.palette(at: cell).onColor.opacity(intensity)
                )
            )
        }
    }

    private func cellPath(
        at cell: PixelGridFrame.Cell,
        origin: CGPoint
    ) -> Path {
        let rect = CGRect(
            x: origin.x + CGFloat(cell.column) * Self.cellStep * scale,
            y: origin.y + CGFloat(cell.row) * Self.cellStep * scale,
            width: Self.cellSize * scale,
            height: Self.cellSize * scale
        )
        guard cornerRadius > 0 else {
            return Path(rect)
        }
        return Path(
            roundedRect: rect,
            cornerRadius: cornerRadius * scale
        )
    }

    private func drawHighlight(
        context: inout GraphicsContext,
        path: Path,
        color: Color,
        radius: CGFloat
    ) {
        context.drawLayer { highlightContext in
            highlightContext.blendMode = .screen
            highlightContext.addFilter(
                .shadow(
                    color: color,
                    radius: radius,
                    options: .shadowOnly
                ),
                options: .linearColor
            )
            highlightContext.fill(path, with: .color(.white))
        }
    }

}
