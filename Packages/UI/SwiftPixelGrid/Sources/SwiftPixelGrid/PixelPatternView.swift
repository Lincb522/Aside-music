import SwiftUI

/// 使用九个普通 SwiftUI 子视图绘制的 Pattern 动画。
///
/// 如果需要连续延迟动画或更高效的 Canvas 渲染，请使用 ``PixelGrid``。
public struct PixelPatternView: View {
    private let brightness: Int
    private let bloom: PixelGridBloom
    private let color: Color
    private let cornerRadius: CGFloat
    private let rotation: CGFloat
    private let tileSize: CGFloat
    private let pixelSize: CGFloat
    private let spacing: CGFloat
    private let isAnimating: Bool
    private let playback: PixelGridPlayback
    private let accessibilityText: String

    /// 创建使用九个原生 SwiftUI 子视图绘制的 Pattern 动画。
    public init(
        brightness: Int = 1,
        bloom: PixelGridBloom = .disabled,
        color: Color = .cyan,
        cornerRadius: CGFloat = 0,
        rotation: CGFloat = 0,
        tileSize: CGFloat = 64,
        pixelSize: CGFloat = 10,
        spacing: CGFloat = 0,
        frameDuration: TimeInterval = 0.1,
        transitionDuration: TimeInterval = 0.25,
        pattern: PixelPattern = .clockwiseRing,
        isAnimating: Bool = true,
        accessibilityLabel: String = "Loading"
    ) {
        self.brightness = max(brightness, 0)
        self.bloom = bloom
        self.color = color
        self.cornerRadius = max(cornerRadius, 0)
        self.rotation = rotation
        self.tileSize = max(tileSize, 0)
        self.pixelSize = max(pixelSize, 0)
        self.spacing = spacing
        self.playback = .pattern(
            PixelPatternEngine(
                pattern: pattern,
                frameDuration: frameDuration,
                transitionDuration: transitionDuration
            )
        )
        self.isAnimating = isAnimating
        self.accessibilityText = accessibilityLabel
    }

    public var body: some View {
        PixelGridPlaybackTimeline(
            playback: playback,
            isAnimating: isAnimating
        ) { sample in
            VStack(spacing: spacing) {
                ForEach(PixelGridFrame.Cell.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(row, id: \.self) { cell in
                            PixelCell(
                                isOn: sample.frame.isActive(cell),
                                size: pixelSize,
                                color: color,
                                cornerRadius: cornerRadius,
                                brightness: brightness,
                                bloom: bloom
                            )
                            .rotationEffect(.degrees(rotation))
                        }
                    }
                }
            }
            .animation(
                viewAnimation(for: sample),
                value: sample.frame
            )
        }
        .frame(width: tileSize, height: tileSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(Text(isAnimating ? "Animating" : "Stopped"))
    }

    private func viewAnimation(
        for sample: PixelGridPlaybackSample
    ) -> Animation? {
        guard sample.allowsMotion,
            let duration = sample.transitionDuration
        else {
            return nil
        }
        return .smooth(duration: duration)
    }
}

private struct PixelCell: View {
    private static let baseOpacity = 0.16

    let isOn: Bool
    let size: CGFloat
    let color: Color
    let cornerRadius: CGFloat
    let brightness: Int
    let bloom: PixelGridBloom

    var body: some View {
        let isLit = isOn && brightness > 0
        let brightnessLevel = min(Double(brightness), 6)
        let innerGlowOpacity = min(0.26 + 0.08 * brightnessLevel, 0.74)
        let outerGlowOpacity = min(0.12 + 0.06 * brightnessLevel, 0.48)
        let shape = RoundedRectangle(
            cornerRadius: min(cornerRadius, size / 2),
            style: .continuous
        )

        shape
            .fill(color.opacity(Self.baseOpacity))
            .overlay {
                shape
                    .fill(color)
                    .opacity(isLit ? 1 : 0)
            }
            .frame(width: size, height: size)
            // 单个纯色形状负责本体，避免重复矩形在抗锯齿边缘累积成描边。
            .shadow(
                color: isLit ? color.opacity(innerGlowOpacity) : .clear,
                radius: size,
                x: 0,
                y: 0
            )
            .shadow(
                color: isLit ? color.opacity(outerGlowOpacity) : .clear,
                radius: size * 2,
                x: 0,
                y: 0
            )
            .shadow(
                color: isLit && bloom.isEnabled
                    ? color.opacity(bloom.intensity)
                    : .clear,
                radius: bloom.amount ?? 0,
                x: 0,
                y: 0
            )
    }
}
