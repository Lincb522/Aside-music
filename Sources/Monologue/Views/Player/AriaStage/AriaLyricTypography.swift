//
//  AriaLyricTypography.swift
//  Monologue
//
//  Stage-wide lyric material treatments. The particle renderer draws a stable
//  capped dot field and clips it with the composed lyric layer.
//

import SwiftUI

enum AriaLyricMaterialStyle: String, CaseIterable {
    case solid
    case particle
    case glass
    case neon
    case prism

    var label: String {
        switch self {
        case .solid:
            return String(localized: "原色")
        case .particle:
            return String(localized: "粒子")
        case .glass:
            return String(localized: "毛玻璃")
        case .neon:
            return String(localized: "霓虹")
        case .prism:
            return String(localized: "棱镜")
        }
    }

    static func resolveStored(_ rawValue: String) -> AriaLyricMaterialStyle {
        AriaLyricMaterialStyle(rawValue: rawValue) ?? .solid
    }
}

struct AriaLyricTypographyConfiguration: Equatable {
    var style: AriaLyricMaterialStyle
    var opacity: Double
    var glowStrength: Double
    var particleDensity: Double
    var particleSize: Double
    var particleMotion: Bool
    var glassIntensity: Double

    static let standard = AriaLyricTypographyConfiguration(
        style: .solid,
        opacity: 1,
        glowStrength: 0,
        particleDensity: 0.58,
        particleSize: 1.15,
        particleMotion: true,
        glassIntensity: 0.64
    )
}

extension View {
    func ariaLyricTypography(
        configuration: AriaLyricTypographyConfiguration,
        palette: AriaPalette,
        time: Double
    ) -> some View {
        modifier(
            AriaLyricTypographyModifier(
                configuration: configuration,
                palette: palette,
                time: time
            )
        )
    }
}

private struct AriaLyricTypographyModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let configuration: AriaLyricTypographyConfiguration
    let palette: AriaPalette
    let time: Double

    func body(content: Content) -> some View {
        let glow = min(max(configuration.glowStrength, 0), 1)

        styledContent(content)
            .opacity(min(max(configuration.opacity, 0.12), 1))
            .shadow(
                color: palette.accent.opacity(glow * 0.88),
                radius: 1 + CGFloat(glow) * 6
            )
            .shadow(
                color: palette.accent.opacity(glow * 0.46),
                radius: 5 + CGFloat(glow) * 20
            )
            .shadow(
                color: palette.primary.opacity(glow * 0.22),
                radius: 14 + CGFloat(glow) * 34
            )
    }

    @ViewBuilder
    private func styledContent(_ content: Content) -> some View {
        switch configuration.style {
        case .solid:
            content

        case .particle:
            ZStack {
                // 笔画连续性垫底：粒子间隙处仍能辨认字形
                content
                    .opacity(0.08)

                // 星尘晕：稀疏彩色光点贴着字缘漂浮，
                // 模糊蒙版让光点越出字形边界并自然衰减。
                AriaLyricParticleField(
                    palette: palette,
                    density: configuration.particleDensity,
                    particleSize: configuration.particleSize,
                    time: time,
                    moves: configuration.particleMotion && !reduceMotion,
                    layer: .halo
                )
                .mask {
                    content.blur(radius: 10)
                }
                .blendMode(.plusLighter)

                // 主体：用点阵蒙版把原字"打成"粒子 ——
                // 字形与逐词高亮动画完整保留，每颗点独立闪烁。
                content
                    .mask {
                        AriaLyricParticleField(
                            palette: palette,
                            density: configuration.particleDensity,
                            particleSize: configuration.particleSize,
                            time: time,
                            moves: configuration.particleMotion && !reduceMotion,
                            layer: .core
                        )
                    }
            }
            .compositingGroup()

        case .glass:
            let intensity = min(max(configuration.glassIntensity, 0), 1)

            ZStack {
                content
                    .opacity(0.08 + intensity * 0.1)

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.44 + intensity * 0.46)
                    .mask {
                        content
                    }

                LinearGradient(
                    colors: [
                        .white.opacity(0.82),
                        palette.primary.opacity(0.3),
                        palette.accent.opacity(0.54)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.26 + intensity * 0.44)
                .mask {
                    content
                }
                .blendMode(.screen)

                content
                    .opacity(0.08 + intensity * 0.12)
                    .offset(y: -0.6)
            }
            .compositingGroup()
            .shadow(
                color: .white.opacity(0.12 + intensity * 0.16),
                radius: 2 + CGFloat(intensity) * 5,
                y: -1
            )

        case .neon:
            content
                .saturation(1.22)
                .contrast(1.06)
                .shadow(color: palette.accent.opacity(0.38), radius: 7)
                .shadow(color: palette.accent.opacity(0.16), radius: 18)

        case .prism:
            ZStack {
                content
                    .colorMultiply(Color.cyan.opacity(0.9))
                    .offset(x: -1.8, y: 0.4)
                    .blendMode(.screen)

                content
                    .colorMultiply(Color.pink.opacity(0.88))
                    .offset(x: 1.8, y: -0.4)
                    .blendMode(.screen)

                content
                    .opacity(0.82)
            }
            .compositingGroup()
        }
    }
}

private struct AriaLyricParticleField: View {
    enum FieldLayer {
        /// 点阵蒙版：白点冲出原字，字形与词动画保留
        case core
        /// 字缘星尘：稀疏彩色光点，漂浮 + 闪烁
        case halo
    }

    let palette: AriaPalette
    let density: Double
    let particleSize: Double
    let time: Double
    let moves: Bool
    let layer: FieldLayer

    var body: some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, size in
            guard size.width > 1, size.height > 1 else { return }

            let normalizedDensity = CGFloat(min(max(density, 0), 1))
            let clampedSize = CGFloat(min(max(particleSize, 0.55), 2.4))

            switch layer {
            case .core:
                drawCore(
                    in: context,
                    size: size,
                    density: normalizedDensity,
                    dotScale: clampedSize
                )
            case .halo:
                drawHalo(
                    in: context,
                    size: size,
                    density: normalizedDensity,
                    dotScale: clampedSize
                )
            }
        }
        .allowsHitTesting(false)
    }

    private static func hashValue(column: Int, row: Int) -> Int {
        abs(
            (column &* 73_856_093)
                ^ (row &* 19_349_663)
                ^ ((column + row) &* 83_492_791)
        )
    }

    /// 点阵密到能覆盖笔画（间距 3~5pt），可读性由此保证；
    /// 粒子感来自逐点明暗闪烁 —— 按亮度分桶后整批填充，避免上万次单点绘制。
    private func drawCore(
        in context: GraphicsContext,
        size: CGSize,
        density: CGFloat,
        dotScale: CGFloat
    ) {
        var spacing = 5.4 - density * 2.4
        let estimatedCount = max((size.width / spacing) * (size.height / spacing), 1)
        if estimatedCount > 14_000 {
            spacing *= sqrt(estimatedCount / 14_000)
        }

        let radius = spacing * min(0.30 + 0.11 * dotScale, 0.47)
        let bucketCount = 5
        var buckets = [Path](repeating: Path(), count: bucketCount)

        var row = 0
        var y = spacing * 0.5
        while y < size.height + spacing {
            var column = 0
            var x = spacing * 0.5
            while x < size.width + spacing {
                let hash = Self.hashValue(column: column, row: row)
                let jitterX = CGFloat(hash % 1_000) / 1_000 - 0.5
                let jitterY = CGFloat((hash / 1_000) % 1_000) / 1_000 - 0.5

                let twinkle: Double
                if moves {
                    let phase = Double((hash / 97) % 628) / 100
                    let speed = 1.2 + Double(hash % 7) * 0.3
                    twinkle = sin(time * speed + phase)
                } else {
                    twinkle = Double((hash / 41) % 200) / 100 - 1
                }
                let level = min(
                    bucketCount - 1,
                    max(0, Int((twinkle * 0.5 + 0.5) * Double(bucketCount)))
                )

                let dotRadius = radius * (0.80 + CGFloat((hash / 10_000) % 100) / 500)
                let centerX = x + jitterX * spacing * 0.34
                let centerY = y + jitterY * spacing * 0.34
                buckets[level].addEllipse(
                    in: CGRect(
                        x: centerX - dotRadius,
                        y: centerY - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                )

                column += 1
                x += spacing
            }
            row += 1
            y += spacing
        }

        for (level, path) in buckets.enumerated() where !path.isEmpty {
            let alpha = 0.42 + 0.145 * Double(level)
            context.fill(path, with: .color(.white.opacity(alpha)))
        }
    }

    /// 字缘星尘：数量少、颗粒大、会漂移，负责"粒子从字里飘出来"的观感。
    private func drawHalo(
        in context: GraphicsContext,
        size: CGSize,
        density: CGFloat,
        dotScale: CGFloat
    ) {
        var spacing = 14.0 - density * 4.0
        let estimatedCount = max((size.width / spacing) * (size.height / spacing), 1)
        if estimatedCount > 2_600 {
            spacing *= sqrt(estimatedCount / 2_600)
        }

        let baseRadius = 0.9 + dotScale * 0.8
        var haloContext = context
        haloContext.blendMode = .plusLighter

        var row = 0
        var y = spacing * 0.5
        while y < size.height + spacing {
            var column = 0
            var x = spacing * 0.5
            while x < size.width + spacing {
                let hash = Self.hashValue(column: column, row: row)
                let jitterX = CGFloat(hash % 1_000) / 1_000 - 0.5
                let jitterY = CGFloat((hash / 1_000) % 1_000) / 1_000 - 0.5

                let twinkle: Double
                var driftX: CGFloat = 0
                var driftY: CGFloat = 0
                if moves {
                    let phase = Double((hash / 97) % 628) / 100
                    let speed = 0.8 + Double(hash % 9) * 0.22
                    twinkle = sin(time * speed + phase)
                    driftX = CGFloat(sin(time * (0.5 + Double(hash % 5) * 0.11) + phase))
                        * spacing * 0.36
                    driftY = CGFloat(cos(time * (0.42 + Double((hash / 7) % 5) * 0.09) + phase))
                        * spacing * 0.30
                } else {
                    twinkle = Double((hash / 41) % 200) / 100 - 1
                }

                let alpha = 0.26 + 0.52 * (0.5 + 0.5 * twinkle)
                let radius = baseRadius
                    * (0.62 + CGFloat((hash / 10_000) % 100) / 210)
                    * (1 + CGFloat(twinkle) * 0.16)

                let centerX = x + jitterX * spacing * 0.6 + driftX
                let centerY = y + jitterY * spacing * 0.6 + driftY
                let color = hash.isMultiple(of: 3)
                    ? palette.cycledAccent(hash / 3)
                    : palette.primary

                haloContext.fill(
                    Path(ellipseIn: CGRect(
                        x: centerX - radius,
                        y: centerY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(color.opacity(alpha))
                )

                column += 1
                x += spacing
            }
            row += 1
            y += spacing
        }
    }
}

struct AriaLyricTypographyPreview: View {
    let text: String
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let configuration: AriaLyricTypographyConfiguration
    let palette: AriaPalette

    var body: some View {
        Text(text)
            .font(fontChoice.font(size: fontSize, weight: .bold))
            .foregroundStyle(palette.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ariaLyricTypography(
                configuration: configuration,
                palette: palette,
                time: 0
            )
    }
}
