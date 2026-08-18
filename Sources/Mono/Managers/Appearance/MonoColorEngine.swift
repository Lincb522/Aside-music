import CoreImage
import Foundation
import SwiftUI
import UIKit

/// Mono 全局取色引擎。
///
/// 所有封面、播放器、歌词、流体背景和小组件都通过同一个六色基准结果取色。
/// 引擎负责 URL 任务去重、结果缓存、内存治理和感知色彩聚类，避免不同页面
/// 对同一张封面重复下载、重复计算或得到互相冲突的主色。
@MainActor
final class MonoColorEngine {
    static let shared = MonoColorEngine()

    struct Snapshot: Sendable {
        let cachedPaletteCount: Int
        let inFlightRequestCount: Int
        let completedExtractionCount: Int
        let cacheHitCount: Int
    }

    struct Configuration: Equatable, Sendable {
        let colorCount: Int
        let mode: CoverPaletteMode
        let randomSeed: Int
    }

    private struct CacheKey: Hashable, Sendable {
        let artworkIdentity: String
        let mode: CoverPaletteMode
        let randomSeed: Int
    }

    private struct CacheEntry {
        let colors: UIImage.ExtractedColors
        var lastAccess: UInt64
    }

    private nonisolated static let canonicalColorCount = 6
    private var cache: [CacheKey: CacheEntry] = [:]
    private var inFlight: [CacheKey: Task<UIImage.ExtractedColors?, Never>] = [:]
    private var accessSequence: UInt64 = 0
    private var cacheLimit = 180
    private var completedExtractionCount = 0
    private var cacheHitCount = 0

    private init() {
        MonoMemoryEngine.shared.registerResource(
            id: "engine.color.palette-cache",
            priority: .recreatable,
            budgetWeight: 0.015,
            minimumBudgetBytes: 256 * 1_024,
            applyBudget: { [weak self] bytes in
                self?.cacheLimit = min(420, max(48, bytes / 2_048))
                self?.trimCacheIfNeeded()
            },
            trim: { [weak self] context in
                self?.trim(for: context) ?? .none
            },
            measureUsage: { [weak self] in
                guard let self else { return .unknown }
                return .init(
                    itemCount: self.cache.count,
                    estimatedBytes: self.cache.count * 2_048
                )
            }
        )
    }

    var configuration: Configuration {
        let preferences = CoverPalettePreferences.shared
        return Configuration(
            colorCount: preferences.colorCount,
            mode: preferences.mode,
            randomSeed: preferences.randomSeed
        )
    }

    func setColorCount(_ count: Int) {
        CoverPalettePreferences.shared.colorCount = count
    }

    func setMode(_ mode: CoverPaletteMode) {
        CoverPalettePreferences.shared.mode = mode
    }

    func reshuffle() {
        CoverPalettePreferences.shared.reshuffle()
    }

    func configuredColors(
        for urlString: String,
        minimumCount: Int = 2
    ) async -> UIImage.ExtractedColors? {
        let configuration = configuration
        return await colors(
            for: urlString,
            count: max(configuration.colorCount, minimumCount),
            mode: configuration.mode,
            randomSeed: configuration.randomSeed
        )
    }

    func colors(
        for urlString: String,
        count: Int,
        mode: CoverPaletteMode,
        randomSeed: Int
    ) async -> UIImage.ExtractedColors? {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return nil }
        let key = CacheKey(
            artworkIdentity: Self.cacheIdentity(for: url),
            mode: mode,
            randomSeed: randomSeed
        )

        if var entry = cache[key] {
            accessSequence &+= 1
            entry.lastAccess = accessSequence
            cache[key] = entry
            cacheHitCount &+= 1
            return entry.colors.limited(to: count)
        }

        if let task = inFlight[key] {
            return await task.value?.limited(to: count)
        }

        let sourceSeed = Self.stableSeed(key.artworkIdentity) ^ randomSeed
        let task = Task<UIImage.ExtractedColors?, Never> {
            guard let image = await ImageLoadCoordinator.shared.loadImage(
                url: url,
                maxSize: 192
            ) else { return nil }

            do {
                return try await MonoComputeScheduler.shared.withPermit(.userInitiated) {
                    await Task.detached(priority: .userInitiated) {
                        MonoColorAnalyzer.analyze(
                            image: image,
                            count: Self.canonicalColorCount,
                            mode: mode,
                            seed: sourceSeed
                        )
                    }.value
                }
            } catch {
                return nil
            }
        }
        inFlight[key] = task

        let result = await task.value
        inFlight[key] = nil
        guard let result else { return nil }

        accessSequence &+= 1
        cache[key] = CacheEntry(colors: result, lastAccess: accessSequence)
        completedExtractionCount &+= 1
        trimCacheIfNeeded()
        return result.limited(to: count)
    }

    func invalidateAll() {
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll(keepingCapacity: false)
        cache.removeAll(keepingCapacity: false)
    }

    func diagnosticSnapshot() -> Snapshot {
        Snapshot(
            cachedPaletteCount: cache.count,
            inFlightRequestCount: inFlight.count,
            completedExtractionCount: completedExtractionCount,
            cacheHitCount: cacheHitCount
        )
    }

    /// 已经持有 UIImage 的调用（锁屏封面、离线文件）也必须走同一分析核心。
    nonisolated static func analyze(
        image: UIImage,
        count: Int = 6,
        mode: CoverPaletteMode = .adaptive,
        randomSeed: Int = 0,
        sourceSeed: Int = 0
    ) -> UIImage.ExtractedColors {
        MonoColorAnalyzer.analyze(
            image: image,
            count: min(max(count, 2), canonicalColorCount),
            mode: mode,
            seed: sourceSeed ^ randomSeed
        )
    }

    private func trimCacheIfNeeded() {
        guard cache.count > cacheLimit else { return }
        let survivors = cache
            .sorted { $0.value.lastAccess > $1.value.lastAccess }
            .prefix(cacheLimit)
        cache = Dictionary(uniqueKeysWithValues: survivors.map { ($0.key, $0.value) })
    }

    private func trim(
        for context: MonoMemoryEngine.TrimContext
    ) -> MonoMemoryEngine.TrimResult {
        let before = cache.count
        switch context.level {
        case .routine:
            trimCacheIfNeeded()
        case .background:
            retainMostRecent(max(32, cacheLimit / 2))
        case .warning, .critical:
            retainMostRecent(context.level == .warning ? 16 : 0)
        }
        let released = max(0, before - cache.count)
        return .init(
            releasedItemCount: released,
            estimatedReleasedBytes: released * 2_048,
            preservedItemCount: cache.count
        )
    }

    private func retainMostRecent(_ count: Int) {
        guard count > 0 else {
            cache.removeAll(keepingCapacity: false)
            return
        }
        let survivors = cache
            .sorted { $0.value.lastAccess > $1.value.lastAccess }
            .prefix(count)
        cache = Dictionary(uniqueKeysWithValues: survivors.map { ($0.key, $0.value) })
    }

    private nonisolated static func cacheIdentity(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        let sizeKeys: Set<String> = [
            "param", "size", "width", "height", "w", "h", "thumbnail",
            "imageview", "imagemogr2"
        ]
        components.queryItems = components.queryItems?.filter {
            !sizeKeys.contains($0.name.lowercased())
        }
        var identity = components.string ?? url.absoluteString
        let host = url.host?.lowercased() ?? ""
        if host.contains("gtimg.cn") {
            identity = identity.replacingOccurrences(
                of: #"R\d+x\d+"#,
                with: "R{size}",
                options: .regularExpression
            )
        }
        if host.hasSuffix(".kugou.com") || host.contains("qpic.cn") {
            identity = identity.replacingOccurrences(
                of: #"/(?:100|120|150|160|180|240|300|400|480|500|600|640|800|1000)(?=[/?&]|$)"#,
                with: "/{size}",
                options: .regularExpression
            )
        }
        if host == "music-file.y.qq.com" {
            identity = identity.replacingOccurrences(
                of: #"/w/\d+/h/\d+"#,
                with: "/w/{size}/h/{size}",
                options: .regularExpression
            )
        }
        return identity
    }

    private nonisolated static func stableSeed(_ value: String) -> Int {
        value.utf8.reduce(2_166_136_261) { partial, byte in
            (partial ^ Int(byte)) &* 16_777_619
        }
    }
}

// MARK: - Unified result and compatibility API

extension UIImage {
    struct ExtractedColors: @unchecked Sendable {
        let palette: [Color]
        let dominant: Color
        let secondary: Color
        let isDark: Bool
        let isTopDark: Bool
        let luminance: CGFloat
        let lyricRegionLuminance: CGFloat
        let foreground: Color
        let secondaryForeground: Color
        let lyricForeground: Color
        let lyricSecondaryForeground: Color
        let isLyricRegionDark: Bool

        func limited(to requestedCount: Int) -> ExtractedColors {
            let count = min(max(requestedCount, 2), 6)
            var limited = Array(palette.prefix(count))
            while limited.count < count {
                limited.append(limited.last ?? dominant)
            }
            return ExtractedColors(
                palette: limited,
                dominant: limited.first ?? dominant,
                secondary: limited.dropFirst().first ?? limited.first ?? secondary,
                isDark: isDark,
                isTopDark: isTopDark,
                luminance: luminance,
                lyricRegionLuminance: lyricRegionLuminance,
                foreground: foreground,
                secondaryForeground: secondaryForeground,
                lyricForeground: lyricForeground,
                lyricSecondaryForeground: lyricSecondaryForeground,
                isLyricRegionDark: isLyricRegionDark
            )
        }
    }

    /// 兼容已经持有 UIImage 的旧调用；对外仍通过统一颜色引擎入口。
    func extractColors(
        count: Int = 4,
        mode: CoverPaletteMode = .adaptive,
        randomSeed: Int = 0,
        sourceSeed: Int = 0
    ) -> ExtractedColors {
        UnifiedColorEngine.analyzeArtwork(
            image: self,
            count: count,
            mode: mode,
            randomSeed: randomSeed,
            sourceSeed: sourceSeed
        )
    }
}

// MARK: - Perceptual analyzer

private enum MonoColorAnalyzer {
    private static let sampleSide = 72
    private static let clusterCount = 10
    private static let iterationCount = 10
    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: true,
        .workingColorSpace: sRGB,
        .outputColorSpace: sRGB
    ])

    private struct RGB: Sendable {
        var red: Double
        var green: Double
        var blue: Double

        var color: Color {
            Color(red: red, green: green, blue: blue)
        }

        var relativeLuminance: Double {
            0.2126 * Self.linear(red)
                + 0.7152 * Self.linear(green)
                + 0.0722 * Self.linear(blue)
        }

        var lab: Lab {
            let r = Self.linear(red)
            let g = Self.linear(green)
            let b = Self.linear(blue)
            let x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
            let y = (r * 0.2126729 + g * 0.7151522 + b * 0.0721750)
            let z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883
            let fx = Self.labPivot(x)
            let fy = Self.labPivot(y)
            let fz = Self.labPivot(z)
            return Lab(
                lightness: 116 * fy - 16,
                a: 500 * (fx - fy),
                b: 200 * (fy - fz)
            )
        }

        static func from(lab: Lab) -> RGB {
            let fy = (lab.lightness + 16) / 116
            let fx = fy + lab.a / 500
            let fz = fy - lab.b / 200
            let x = 0.95047 * inverseLabPivot(fx)
            let y = inverseLabPivot(fy)
            let z = 1.08883 * inverseLabPivot(fz)
            let linearRed = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
            let linearGreen = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
            let linearBlue = x * 0.0556434 + y * -0.2040259 + z * 1.0572252
            return RGB(
                red: gamma(linearRed),
                green: gamma(linearGreen),
                blue: gamma(linearBlue)
            )
        }

        private static func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        private static func gamma(_ value: Double) -> Double {
            let clamped = min(max(value, 0), 1)
            return clamped <= 0.0031308
                ? clamped * 12.92
                : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        }

        private static func labPivot(_ value: Double) -> Double {
            value > 0.008856 ? pow(value, 1 / 3) : 7.787 * value + 16 / 116
        }

        private static func inverseLabPivot(_ value: Double) -> Double {
            let cube = value * value * value
            return cube > 0.008856 ? cube : (value - 16 / 116) / 7.787
        }
    }

    private struct Lab: Sendable {
        var lightness: Double
        var a: Double
        var b: Double

        var chroma: Double { hypot(a, b) }

        func distanceSquared(to other: Lab) -> Double {
            let dl = lightness - other.lightness
            let da = a - other.a
            let db = b - other.b
            return dl * dl + da * da + db * db
        }
    }

    private struct Pixel: Sendable {
        let rgb: RGB
        let lab: Lab
        let x: Double
        let y: Double
        let weight: Double
    }

    private struct Cluster: Sendable {
        let lab: Lab
        let weight: Double
        let score: Double
    }

    private struct SurfaceMetrics: Sendable {
        let luminance: Double
        let perceptualLightness: Double
        let darkShare: Double
    }

    nonisolated static func analyze(
        image: UIImage,
        count: Int,
        mode: CoverPaletteMode,
        seed: Int
    ) -> UIImage.ExtractedColors {
        let targetCount = min(max(count, 2), 6)
        let pixels = sampledPixels(from: image)
        guard !pixels.isEmpty else { return fallback(count: targetCount, seed: seed) }

        let fullLuminance = regionLuminance(
            pixels,
            xRange: 0.10...0.90,
            yRange: 0.10...0.90
        )
        let topLuminance = regionLuminance(
            pixels,
            xRange: 0.06...0.94,
            yRange: 0.74...1.00
        )
        let lyricLuminance = regionLuminance(
            pixels,
            xRange: 0.06...0.94,
            yRange: 0.04...0.58
        )

        let clusters = kMeans(pixels: pixels, seed: seed)
        var selected = selectPalette(
            clusters: clusters,
            count: targetCount,
            mode: mode,
            seed: seed
        )
        if selected.isEmpty { return fallback(count: targetCount, seed: seed) }
        while selected.count < targetCount {
            selected.append(selected[selected.count % max(selected.count, 1)])
        }

        let palette = selected.prefix(targetCount).map { RGB.from(lab: $0.lab).color }
        let dominant = palette.first ?? .gray
        let secondary = palette.dropFirst().first ?? dominant
        let paletteMetrics = surfaceMetrics(for: Array(selected.prefix(targetCount)))
        let surfaceLuminance = paletteMetrics.luminance * 0.84 + fullLuminance * 0.16
        let usesLightForeground = prefersLightForeground(
            luminance: surfaceLuminance,
            perceptualLightness: paletteMetrics.perceptualLightness,
            darkShare: paletteMetrics.darkShare
        )
        let lyricUsesLightForeground = prefersLightForeground(luminance: lyricLuminance)
        let foreground: Color = usesLightForeground ? .white : .black
        let lyricForeground: Color = lyricUsesLightForeground ? .white : .black
        return UIImage.ExtractedColors(
            palette: palette,
            dominant: dominant,
            secondary: secondary,
            isDark: usesLightForeground,
            isTopDark: prefersLightForeground(luminance: topLuminance),
            luminance: CGFloat(fullLuminance),
            lyricRegionLuminance: CGFloat(lyricLuminance),
            foreground: foreground,
            secondaryForeground: foreground.opacity(0.68),
            lyricForeground: lyricForeground,
            lyricSecondaryForeground: lyricForeground.opacity(0.62),
            isLyricRegionDark: lyricUsesLightForeground
        )
    }

    private nonisolated static func sampledPixels(from image: UIImage) -> [Pixel] {
        guard let input = CIImage(
            image: image,
            options: [.applyOrientationProperty: true]
        ) else { return [] }

        let extent = input.extent
        guard extent.width > 0, extent.height > 0 else { return [] }
        let translated = input.transformed(
            by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
        )
        let scaled = translated.transformed(
            by: CGAffineTransform(
                scaleX: CGFloat(sampleSide) / extent.width,
                y: CGFloat(sampleSide) / extent.height
            )
        )

        var bytes = [UInt8](repeating: 0, count: sampleSide * sampleSide * 4)
        context.render(
            scaled,
            toBitmap: &bytes,
            rowBytes: sampleSide * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSide, height: sampleSide),
            format: .RGBA8,
            colorSpace: sRGB
        )

        var result: [Pixel] = []
        result.reserveCapacity(sampleSide * sampleSide)
        for yIndex in 0..<sampleSide {
            for xIndex in 0..<sampleSide {
                let offset = (yIndex * sampleSide + xIndex) * 4
                let alpha = Double(bytes[offset + 3]) / 255
                guard alpha > 0.58 else { continue }

                let rgb = RGB(
                    red: Double(bytes[offset]) / 255,
                    green: Double(bytes[offset + 1]) / 255,
                    blue: Double(bytes[offset + 2]) / 255
                )
                let lab = rgb.lab
                let x = (Double(xIndex) + 0.5) / Double(sampleSide)
                let y = (Double(yIndex) + 0.5) / Double(sampleSide)
                let edgeDistance = min(x, 1 - x, y, 1 - y)
                let edgeWeight = edgeDistance < 0.055 ? 0.52 : 1.0
                let centerDistance = hypot(x - 0.5, y - 0.5) / 0.7071
                let spatialWeight = 0.78 + (1 - min(centerDistance, 1)) * 0.22
                let chromaWeight = 0.90 + min(lab.chroma / 100, 1) * 0.18
                let extremeWeight: Double
                if lab.lightness < 3 || lab.lightness > 98 {
                    extremeWeight = 0.44
                } else if lab.lightness < 8 || lab.lightness > 95 {
                    extremeWeight = 0.72
                } else {
                    extremeWeight = 1
                }
                result.append(
                    Pixel(
                        rgb: rgb,
                        lab: lab,
                        x: x,
                        y: y,
                        weight: alpha * edgeWeight * spatialWeight * chromaWeight * extremeWeight
                    )
                )
            }
        }
        return result
    }

    private nonisolated static func kMeans(pixels: [Pixel], seed: Int) -> [Cluster] {
        let desired = min(clusterCount, max(2, pixels.count))
        var centers: [Lab] = []
        centers.reserveCapacity(desired)

        let totalWeight = pixels.reduce(0) { $0 + $1.weight }
        let mean = Lab(
            lightness: pixels.reduce(0) { $0 + $1.lab.lightness * $1.weight } / max(totalWeight, 0.0001),
            a: pixels.reduce(0) { $0 + $1.lab.a * $1.weight } / max(totalWeight, 0.0001),
            b: pixels.reduce(0) { $0 + $1.lab.b * $1.weight } / max(totalWeight, 0.0001)
        )
        let first = pixels.min {
            $0.lab.distanceSquared(to: mean) < $1.lab.distanceSquared(to: mean)
        }?.lab ?? pixels[0].lab
        centers.append(first)

        while centers.count < desired {
            let candidate = pixels.max { lhs, rhs in
                initializationScore(lhs, centers: centers, seed: seed)
                    < initializationScore(rhs, centers: centers, seed: seed)
            }
            guard let candidate else { break }
            if centers.contains(where: { $0.distanceSquared(to: candidate.lab) < 1 }) { break }
            centers.append(candidate.lab)
        }

        var assignments = [Int](repeating: 0, count: pixels.count)
        for _ in 0..<iterationCount {
            for index in pixels.indices {
                assignments[index] = centers.indices.min {
                    pixels[index].lab.distanceSquared(to: centers[$0])
                        < pixels[index].lab.distanceSquared(to: centers[$1])
                } ?? 0
            }

            var lightness = [Double](repeating: 0, count: centers.count)
            var a = [Double](repeating: 0, count: centers.count)
            var b = [Double](repeating: 0, count: centers.count)
            var weights = [Double](repeating: 0, count: centers.count)
            for index in pixels.indices {
                let cluster = assignments[index]
                let weight = pixels[index].weight
                lightness[cluster] += pixels[index].lab.lightness * weight
                a[cluster] += pixels[index].lab.a * weight
                b[cluster] += pixels[index].lab.b * weight
                weights[cluster] += weight
            }
            for index in centers.indices where weights[index] > 0.0001 {
                centers[index] = Lab(
                    lightness: lightness[index] / weights[index],
                    a: a[index] / weights[index],
                    b: b[index] / weights[index]
                )
            }
        }

        var weights = [Double](repeating: 0, count: centers.count)
        for index in pixels.indices {
            weights[assignments[index]] += pixels[index].weight
        }
        let sum = max(weights.reduce(0, +), 0.0001)
        return centers.indices.compactMap { index in
            let population = weights[index] / sum
            guard population >= 0.004 else { return nil }
            let center = centers[index]
            let chromaBonus = 0.90 + min(center.chroma / 90, 1) * 0.28
            let lightnessPenalty: Double
            if center.lightness < 5 || center.lightness > 97 {
                lightnessPenalty = 0.55
            } else if center.lightness < 12 || center.lightness > 92 {
                lightnessPenalty = 0.78
            } else {
                lightnessPenalty = 1
            }
            return Cluster(
                lab: center,
                weight: population,
                score: population * chromaBonus * lightnessPenalty
            )
        }
        .sorted { $0.score > $1.score }
    }

    private nonisolated static func initializationScore(
        _ pixel: Pixel,
        centers: [Lab],
        seed: Int
    ) -> Double {
        let distance = centers.map { pixel.lab.distanceSquared(to: $0) }.min() ?? 0
        let jitter = Double(abs((Int(pixel.x * 10_000) * 31 + Int(pixel.y * 10_000) * 17 + seed) % 97)) / 9_700
        return distance * pixel.weight * (1 + jitter)
    }

    private nonisolated static func selectPalette(
        clusters: [Cluster],
        count: Int,
        mode: CoverPaletteMode,
        seed: Int
    ) -> [Cluster] {
        guard let first = clusters.first else { return [] }
        var selected = [first]
        var remaining = Array(clusters.dropFirst())

        if mode == .random, !remaining.isEmpty {
            let rotation = abs(seed) % remaining.count
            remaining = Array(remaining[rotation...]) + Array(remaining[..<rotation])
        }

        while selected.count < count, !remaining.isEmpty {
            let highestScore = max(clusters.first?.score ?? 1, 0.0001)
            let winner = remaining.indices.max { lhs, rhs in
                diversityScore(remaining[lhs], selected: selected, highestScore: highestScore)
                    < diversityScore(remaining[rhs], selected: selected, highestScore: highestScore)
            } ?? 0
            selected.append(remaining.remove(at: winner))
        }
        return selected
    }

    private nonisolated static func diversityScore(
        _ cluster: Cluster,
        selected: [Cluster],
        highestScore: Double
    ) -> Double {
        let minimumDistance = selected.map {
            sqrt(cluster.lab.distanceSquared(to: $0.lab))
        }.min() ?? 0
        let diversity = min(minimumDistance / 85, 1)
        let relevance = min(cluster.score / highestScore, 1)
        return relevance * 0.58 + diversity * 0.42
    }

    private nonisolated static func regionLuminance(
        _ pixels: [Pixel],
        xRange: ClosedRange<Double>,
        yRange: ClosedRange<Double>
    ) -> Double {
        var sum = 0.0
        var weight = 0.0
        for pixel in pixels where xRange.contains(pixel.x) && yRange.contains(pixel.y) {
            sum += pixel.rgb.relativeLuminance * pixel.weight
            weight += pixel.weight
        }
        return weight > 0 ? min(max(sum / weight, 0), 1) : 0.3
    }

    private nonisolated static func prefersLightForeground(luminance: Double) -> Bool {
        // UI 感知上的“深色”范围比纯 WCAG 黑白二选一的交点更宽。
        // 中深色封面若仍选黑字，虽有理论对比度，实际叠加模糊与流体后会明显发糊。
        luminance <= 0.34
    }

    private nonisolated static func prefersLightForeground(
        luminance: Double,
        perceptualLightness: Double,
        darkShare: Double
    ) -> Bool {
        if luminance <= 0.30 || perceptualLightness <= 0.56 {
            return true
        }
        if luminance >= 0.48 || perceptualLightness >= 0.72 {
            return false
        }
        if darkShare >= 0.58, luminance < 0.43 {
            return true
        }

        let darknessScore = (1 - luminance) * 0.48
            + (1 - perceptualLightness) * 0.42
            + darkShare * 0.10
        return darknessScore >= 0.51
    }

    private nonisolated static func surfaceMetrics(
        for clusters: [Cluster]
    ) -> SurfaceMetrics {
        guard !clusters.isEmpty else {
            return SurfaceMetrics(luminance: 0.3, perceptualLightness: 0.5, darkShare: 1)
        }

        var luminance = 0.0
        var lightness = 0.0
        var darkWeight = 0.0
        var totalWeight = 0.0
        for (index, cluster) in clusters.enumerated() {
            // 主色略加权，但仍保留多色流体中其他颜色对可读性的影响。
            let weight = index == 0 ? 1.45 : 1.0
            let normalizedLightness = min(max(cluster.lab.lightness / 100, 0), 1)
            luminance += RGB.from(lab: cluster.lab).relativeLuminance * weight
            lightness += normalizedLightness * weight
            if normalizedLightness < 0.60 {
                darkWeight += weight
            }
            totalWeight += weight
        }

        return SurfaceMetrics(
            luminance: min(max(luminance / totalWeight, 0), 1),
            perceptualLightness: min(max(lightness / totalWeight, 0), 1),
            darkShare: min(max(darkWeight / totalWeight, 0), 1)
        )
    }

    private nonisolated static func fallback(
        count: Int,
        seed: Int
    ) -> UIImage.ExtractedColors {
        let hue = Double(abs(seed % 360)) / 360
        let colors = (0..<count).map { index -> Color in
            let uiColor = UIColor(
                hue: CGFloat((hue + Double(index) * 0.11).truncatingRemainder(dividingBy: 1)),
                saturation: 0.34,
                brightness: 0.72,
                alpha: 1
            )
            return Color(uiColor)
        }
        return UIImage.ExtractedColors(
            palette: colors,
            dominant: colors.first ?? .gray,
            secondary: colors.dropFirst().first ?? colors.first ?? .gray,
            isDark: true,
            isTopDark: true,
            luminance: 0.3,
            lyricRegionLuminance: 0.3,
            foreground: .white,
            secondaryForeground: .white.opacity(0.68),
            lyricForeground: .white,
            lyricSecondaryForeground: .white.opacity(0.62),
            isLyricRegionDark: true
        )
    }
}
