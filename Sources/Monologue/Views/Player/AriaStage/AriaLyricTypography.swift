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
                Self.drawCore(
                    in: context,
                    size: size,
                    density: normalizedDensity,
                    dotScale: clampedSize,
                    time: time,
                    moves: moves
                )
            case .halo:
                Self.drawHalo(
                    in: context,
                    size: size,
                    density: normalizedDensity,
                    dotScale: clampedSize,
                    time: time,
                    moves: moves,
                    palette: palette
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

    private static func sheetKey(
        size: CGSize,
        density: CGFloat,
        dotScale: CGFloat,
        moves: Bool
    ) -> String {
        let width = (size.width * 2).rounded() / 2
        let height = (size.height * 2).rounded() / 2
        return "\(width)x\(height)|\(Int(density * 1_000))|\(Int(dotScale * 1_000))|\(moves ? 1 : 0)"
    }

    // MARK: 主体点阵（几何逐尺寸缓存）

    /// 同一相位桶里的点每帧闪烁值完全相同 → 整组一条 Path 预构建，
    /// 每帧只算组级 sin 后按亮度整批填充。
    private struct CoreTwinkleGroup {
        var path = Path()
        let speed: Double
        let phase: Double
    }

    private struct CoreSheet {
        /// moves == true：按（速度档 × 相位桶）分组的点阵
        let groups: [CoreTwinkleGroup]
        /// moves == false：闪烁值静止，直接按亮度桶预分好
        let staticBuckets: [Path]
    }

    private enum CoreSheetCache {
        static let lock = NSLock()
        nonisolated(unsafe) static var storage: [String: CoreSheet] = [:]
    }

    private static let coreBucketCount = 5
    /// 相位量化桶数：628 个原始相位压到 63 桶，最大误差 ±0.05rad，
    /// 对 5 档亮度分桶的观感零影响，但让点数从上万收敛到 ≤441 组
    private static let corePhaseBuckets = 63

    private static func coreSheet(
        size: CGSize,
        density: CGFloat,
        dotScale: CGFloat,
        moves: Bool
    ) -> CoreSheet {
        let key = sheetKey(size: size, density: density, dotScale: dotScale, moves: moves)

        CoreSheetCache.lock.lock()
        if let cached = CoreSheetCache.storage[key] {
            CoreSheetCache.lock.unlock()
            return cached
        }
        CoreSheetCache.lock.unlock()

        var spacing = 5.4 - density * 2.4
        let estimatedCount = max((size.width / spacing) * (size.height / spacing), 1)
        if estimatedCount > 14_000 {
            spacing *= sqrt(estimatedCount / 14_000)
        }

        let radius = spacing * min(0.30 + 0.11 * dotScale, 0.47)

        // 速度 7 档 × 相位 63 桶
        var groupPaths = [Path](repeating: Path(), count: 7 * corePhaseBuckets)
        var staticBuckets = [Path](repeating: Path(), count: coreBucketCount)

        var row = 0
        var y = spacing * 0.5
        while y < size.height + spacing {
            var column = 0
            var x = spacing * 0.5
            while x < size.width + spacing {
                let hash = hashValue(column: column, row: row)
                let jitterX = CGFloat(hash % 1_000) / 1_000 - 0.5
                let jitterY = CGFloat((hash / 1_000) % 1_000) / 1_000 - 0.5

                let dotRadius = radius * (0.80 + CGFloat((hash / 10_000) % 100) / 500)
                let centerX = x + jitterX * spacing * 0.34
                let centerY = y + jitterY * spacing * 0.34
                let rect = CGRect(
                    x: centerX - dotRadius,
                    y: centerY - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )

                if moves {
                    let speedIndex = hash % 7
                    let phaseBucket = ((hash / 97) % 628) / 10
                    groupPaths[speedIndex * corePhaseBuckets + phaseBucket].addEllipse(in: rect)
                } else {
                    let twinkle = Double((hash / 41) % 200) / 100 - 1
                    let level = min(
                        coreBucketCount - 1,
                        max(0, Int((twinkle * 0.5 + 0.5) * Double(coreBucketCount)))
                    )
                    staticBuckets[level].addEllipse(in: rect)
                }

                column += 1
                x += spacing
            }
            row += 1
            y += spacing
        }

        var groups: [CoreTwinkleGroup] = []
        if moves {
            groups.reserveCapacity(7 * corePhaseBuckets)
            for speedIndex in 0..<7 {
                for phaseBucket in 0..<corePhaseBuckets {
                    let path = groupPaths[speedIndex * corePhaseBuckets + phaseBucket]
                    guard !path.isEmpty else { continue }
                    groups.append(
                        CoreTwinkleGroup(
                            path: path,
                            speed: 1.2 + Double(speedIndex) * 0.3,
                            phase: Double(phaseBucket) / 10 + 0.05
                        )
                    )
                }
            }
        }

        let sheet = CoreSheet(groups: groups, staticBuckets: staticBuckets)

        CoreSheetCache.lock.lock()
        if CoreSheetCache.storage.count >= 8 {
            CoreSheetCache.storage.removeAll(keepingCapacity: true)
        }
        CoreSheetCache.storage[key] = sheet
        CoreSheetCache.lock.unlock()
        return sheet
    }

    /// 点阵密到能覆盖笔画（间距 3~5pt），可读性由此保证；
    /// 粒子感来自逐点明暗闪烁 —— 几何预构建后每帧只剩组级正弦 + 整批填充。
    private static func drawCore(
        in context: GraphicsContext,
        size: CGSize,
        density: CGFloat,
        dotScale: CGFloat,
        time: Double,
        moves: Bool
    ) {
        let sheet = coreSheet(size: size, density: density, dotScale: dotScale, moves: moves)

        if moves {
            for group in sheet.groups {
                let twinkle = sin(time * group.speed + group.phase)
                let level = min(
                    coreBucketCount - 1,
                    max(0, Int((twinkle * 0.5 + 0.5) * Double(coreBucketCount)))
                )
                let alpha = 0.42 + 0.145 * Double(level)
                context.fill(group.path, with: .color(.white.opacity(alpha)))
            }
        } else {
            for (level, path) in sheet.staticBuckets.enumerated() where !path.isEmpty {
                let alpha = 0.42 + 0.145 * Double(level)
                context.fill(path, with: .color(.white.opacity(alpha)))
            }
        }
    }

    // MARK: 字缘星尘（静态参数逐尺寸缓存）

    private struct HaloDot {
        let baseX: CGFloat
        let baseY: CGFloat
        let radiusFactor: CGFloat
        let phase: Double
        let speed: Double
        let driftXSpeed: Double
        let driftYSpeed: Double
        let driftXAmp: CGFloat
        let driftYAmp: CGFloat
        /// -1 表示主色，否则为 cycledAccent 的索引
        let accentIndex: Int
        let staticTwinkle: Double
    }

    private enum HaloSheetCache {
        static let lock = NSLock()
        nonisolated(unsafe) static var storage: [String: [HaloDot]] = [:]
    }

    private static func haloDots(
        size: CGSize,
        density: CGFloat,
        dotScale: CGFloat
    ) -> [HaloDot] {
        let key = sheetKey(size: size, density: density, dotScale: dotScale, moves: true)

        HaloSheetCache.lock.lock()
        if let cached = HaloSheetCache.storage[key] {
            HaloSheetCache.lock.unlock()
            return cached
        }
        HaloSheetCache.lock.unlock()

        var spacing = 14.0 - density * 4.0
        let estimatedCount = max((size.width / spacing) * (size.height / spacing), 1)
        if estimatedCount > 2_600 {
            spacing *= sqrt(estimatedCount / 2_600)
        }

        var dots: [HaloDot] = []
        var row = 0
        var y = spacing * 0.5
        while y < size.height + spacing {
            var column = 0
            var x = spacing * 0.5
            while x < size.width + spacing {
                let hash = hashValue(column: column, row: row)
                let jitterX = CGFloat(hash % 1_000) / 1_000 - 0.5
                let jitterY = CGFloat((hash / 1_000) % 1_000) / 1_000 - 0.5

                dots.append(
                    HaloDot(
                        baseX: x + jitterX * spacing * 0.6,
                        baseY: y + jitterY * spacing * 0.6,
                        radiusFactor: 0.62 + CGFloat((hash / 10_000) % 100) / 210,
                        phase: Double((hash / 97) % 628) / 100,
                        speed: 0.8 + Double(hash % 9) * 0.22,
                        driftXSpeed: 0.5 + Double(hash % 5) * 0.11,
                        driftYSpeed: 0.42 + Double((hash / 7) % 5) * 0.09,
                        driftXAmp: spacing * 0.36,
                        driftYAmp: spacing * 0.30,
                        accentIndex: hash.isMultiple(of: 3) ? hash / 3 : -1,
                        staticTwinkle: Double((hash / 41) % 200) / 100 - 1
                    )
                )

                column += 1
                x += spacing
            }
            row += 1
            y += spacing
        }

        HaloSheetCache.lock.lock()
        if HaloSheetCache.storage.count >= 16 {
            HaloSheetCache.storage.removeAll(keepingCapacity: true)
        }
        HaloSheetCache.storage[key] = dots
        HaloSheetCache.lock.unlock()
        return dots
    }

    /// 字缘星尘：数量少、颗粒大、会漂移，负责"粒子从字里飘出来"的观感。
    /// 位置随时间漂移必须逐帧重建路径，但按（颜色 × 亮度档）合批后
    /// 填充调用从每点一次收敛到每帧几十次。
    private static func drawHalo(
        in context: GraphicsContext,
        size: CGSize,
        density: CGFloat,
        dotScale: CGFloat,
        time: Double,
        moves: Bool,
        palette: AriaPalette
    ) {
        let dots = haloDots(size: size, density: density, dotScale: dotScale)
        let baseRadius = 0.9 + dotScale * 0.8
        /// 亮度 41 档（步长 ~0.013），肉眼不可分但可合批
        let alphaLevels = 40

        var haloContext = context
        haloContext.blendMode = .plusLighter

        // 颜色槽预先按调色板轮换数取模，保证与逐点直取 cycledAccent 完全同色
        let cycleCount = max(palette.accentCycle.count, 1)

        // key = 颜色槽 × 亮度档
        var batches: [Int: Path] = [:]

        for dot in dots {
            let twinkle: Double
            var centerX = dot.baseX
            var centerY = dot.baseY
            if moves {
                twinkle = sin(time * dot.speed + dot.phase)
                centerX += CGFloat(sin(time * dot.driftXSpeed + dot.phase)) * dot.driftXAmp
                centerY += CGFloat(cos(time * dot.driftYSpeed + dot.phase)) * dot.driftYAmp
            } else {
                twinkle = dot.staticTwinkle
            }

            let normalized = 0.5 + 0.5 * twinkle
            let level = min(alphaLevels, max(0, Int(normalized * Double(alphaLevels) + 0.5)))
            let radius = baseRadius
                * dot.radiusFactor
                * (1 + CGFloat(twinkle) * 0.16)

            let colorSlot = dot.accentIndex < 0
                ? 0
                : 1 + ((dot.accentIndex % cycleCount) + cycleCount) % cycleCount
            let batchKey = colorSlot * (alphaLevels + 1) + level

            batches[batchKey, default: Path()].addEllipse(
                in: CGRect(
                    x: centerX - radius,
                    y: centerY - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
        }

        for (batchKey, path) in batches {
            let level = batchKey % (alphaLevels + 1)
            let colorSlot = batchKey / (alphaLevels + 1)
            let alpha = 0.26 + 0.52 * Double(level) / Double(alphaLevels)
            let color = colorSlot == 0
                ? palette.primary
                : palette.cycledAccent(colorSlot - 1)
            haloContext.fill(path, with: .color(color.opacity(alpha)))
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
