import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum CoverPaletteMode: String, CaseIterable, Identifiable, Sendable {
    case adaptive
    case random

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adaptive:
            return String(localized: "智能取色")
        case .random:
            return String(localized: "随机取色")
        }
    }
}

@MainActor
final class CoverPalettePreferences: ObservableObject {
    static let shared = CoverPalettePreferences()

    @Published var colorCount: Int {
        didSet {
            let clamped = min(max(colorCount, 2), 6)
            if colorCount != clamped {
                colorCount = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: "coverPalette.colorCount")
        }
    }

    @Published var mode: CoverPaletteMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "coverPalette.mode")
        }
    }

    @Published private(set) var randomSeed: Int {
        didSet {
            UserDefaults.standard.set(randomSeed, forKey: "coverPalette.randomSeed")
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedCount = defaults.object(forKey: "coverPalette.colorCount") as? Int ?? 4
        colorCount = min(max(storedCount, 2), 6)
        mode = CoverPaletteMode(
            rawValue: defaults.string(forKey: "coverPalette.mode") ?? ""
        ) ?? .adaptive
        randomSeed = defaults.integer(forKey: "coverPalette.randomSeed")
    }

    func reshuffle() {
        randomSeed = randomSeed &+ 1
    }
}

/// 从封面图片提取可在背景、歌词、播放器和主题氛围间共享的多色调色板。
@MainActor
final class CoverColorExtractor: ObservableObject {
    @Published var palette: [Color] = [.gray, .gray.opacity(0.6)]
    @Published var dominantColor: Color = .gray
    @Published var secondaryColor: Color = .gray.opacity(0.6)
    @Published var isDark = true
    @Published var isTopDark = true
    @Published var luminance: CGFloat = 0.3
    @Published var lyricRegionLuminance: CGFloat = 0.3

    private let preferences = CoverPalettePreferences.shared
    private var lastURL: String?
    private var requestIdentity = ""
    private var cancellables = Set<AnyCancellable>()

    init() {
        Publishers.CombineLatest3(
            preferences.$colorCount.removeDuplicates(),
            preferences.$mode.removeDuplicates(),
            preferences.$randomSeed.removeDuplicates()
        )
        .dropFirst()
        .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self, let lastURL else { return }
            extract(from: lastURL, force: true)
        }
        .store(in: &cancellables)
    }

    /// 从 URL 异步提取颜色。重复 URL 会复用已显示结果，配置变化时强制刷新。
    func extract(from urlString: String?, force: Bool = false) {
        guard let urlString, !urlString.isEmpty else {
            reset()
            return
        }
        guard force || urlString != lastURL else { return }
        guard let url = URL(string: urlString) else { return }

        lastURL = urlString
        let colorCount = preferences.colorCount
        let mode = preferences.mode
        let randomSeed = preferences.randomSeed
        let sourceSeed = Self.stableSeed(urlString)
        let identity = "\(urlString)|\(colorCount)|\(mode.rawValue)|\(randomSeed)"
        requestIdentity = identity

        Task {
            guard let image = await ImageLoadCoordinator.shared.loadImage(
                url: url,
                maxSize: 160
            ) else {
                return
            }

            let colors = await Task.detached(priority: .userInitiated) {
                image.extractColors(
                    count: colorCount,
                    mode: mode,
                    randomSeed: randomSeed,
                    sourceSeed: sourceSeed
                )
            }.value

            guard requestIdentity == identity else { return }
            withAnimation(.easeOut(duration: 0.45)) {
                palette = colors.palette
                dominantColor = colors.dominant
                secondaryColor = colors.secondary
                isDark = colors.isDark
                isTopDark = colors.isTopDark
                luminance = colors.luminance
                lyricRegionLuminance = colors.lyricRegionLuminance
            }
        }
    }

    func reset() {
        lastURL = nil
        requestIdentity = ""
        palette = [.gray, .gray.opacity(0.6)]
        dominantColor = .gray
        secondaryColor = .gray.opacity(0.6)
        isDark = true
        isTopDark = true
        luminance = 0.3
        lyricRegionLuminance = 0.3
    }

    private static func stableSeed(_ value: String) -> Int {
        value.utf8.reduce(2_166_136_261) { partial, byte in
            (partial ^ Int(byte)) &* 16_777_619
        }
    }
}

struct DynamicCoverPaletteLayer: View {
    let colors: [Color]
    var opacity: Double = 1

    var body: some View {
        GeometryReader { proxy in
            let longSide = max(proxy.size.width, proxy.size.height)
            let anchors: [UnitPoint] = [
                .init(x: 0.14, y: 0.12),
                .init(x: 0.86, y: 0.2),
                .init(x: 0.22, y: 0.82),
                .init(x: 0.78, y: 0.76),
                .center,
                .init(x: 0.52, y: 0.16)
            ]

            ZStack {
                ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { index, color in
                    RadialGradient(
                        colors: [
                            color.opacity((index == 0 ? 0.34 : 0.24) * opacity),
                            color.opacity(0.07 * opacity),
                            .clear
                        ],
                        center: anchors[index % anchors.count],
                        startRadius: 0,
                        endRadius: longSide * (index == 0 ? 0.64 : 0.5)
                    )
                    .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct CoverPaletteSettingsControls: View {
    @ObservedObject private var preferences = CoverPalettePreferences.shared

    let accent: Color
    var darkStyle = true

    private var primary: Color {
        darkStyle ? .white : .monoTextPrimary
    }

    private var secondary: Color {
        darkStyle ? .white.opacity(0.5) : .monoTextSecondary
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                ForEach(CoverPaletteMode.allCases) { mode in
                    modeButton(mode)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text(String(localized: "提取颜色数量"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primary.opacity(0.8))
                    Spacer()
                    Text("\(preferences.colorCount)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(secondary)
                }

                HStack(spacing: 6) {
                    ForEach(2...6, id: \.self) { count in
                        Button {
                            preferences.colorCount = count
                        } label: {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    preferences.colorCount == count
                                        ? Color.white
                                        : secondary
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            preferences.colorCount == count
                                                ? accent.opacity(0.82)
                                                : primary.opacity(darkStyle ? 0.05 : 0.04)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(String(localized: "提取颜色数量")) \(count)"
                        )
                        .accessibilityAddTraits(
                            preferences.colorCount == count ? .isSelected : []
                        )
                    }
                }
            }

            if preferences.mode == .random {
                Button {
                    preferences.reshuffle()
                } label: {
                    HStack(spacing: 8) {
                        MonoIcon(icon: .refresh, size: 14, color: accent)
                        Text(String(localized: "重新随机"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primary.opacity(0.84))
                        Spacer()
                    }
                    .frame(height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func modeButton(_ mode: CoverPaletteMode) -> some View {
        let selected = preferences.mode == mode

        return Button {
            preferences.mode = mode
        } label: {
            Text(mode.label)
                .font(.system(size: 11, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? primary : secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            selected
                                ? accent.opacity(darkStyle ? 0.18 : 0.12)
                                : primary.opacity(darkStyle ? 0.035 : 0.025)
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            selected ? accent.opacity(0.5) : primary.opacity(0.06),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - UIImage 颜色提取

extension UIImage {
    struct ExtractedColors: @unchecked Sendable {
        let palette: [Color]
        let dominant: Color
        let secondary: Color
        let isDark: Bool
        let isTopDark: Bool
        let luminance: CGFloat
        let lyricRegionLuminance: CGFloat
    }

    func extractColors(
        count: Int = 4,
        mode: CoverPaletteMode = .adaptive,
        randomSeed: Int = 0,
        sourceSeed: Int = 0
    ) -> ExtractedColors {
        extractWithCoreImage(
            count: min(max(count, 2), 6),
            mode: mode,
            randomSeed: randomSeed,
            sourceSeed: sourceSeed
        )
    }

    private struct RGBComponents {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat

        var luminance: CGFloat {
            0.2126 * r + 0.7152 * g + 0.0722 * b
        }

        var saturation: CGFloat {
            let maximum = max(r, g, b)
            guard maximum > 0 else { return 0 }
            return (maximum - min(r, g, b)) / maximum
        }

        var color: Color {
            Color(red: r, green: g, blue: b)
        }
    }

    private struct ColorBucket {
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0
        var score: Double = 0
        var count: Double = 0

        var average: RGBComponents {
            let divisor = max(count, 1)
            return RGBComponents(
                r: CGFloat(red / divisor),
                g: CGFloat(green / divisor),
                b: CGFloat(blue / divisor)
            )
        }
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private static let paletteContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: true
    ])

    private func extractWithCoreImage(
        count: Int,
        mode: CoverPaletteMode,
        randomSeed: Int,
        sourceSeed: Int
    ) -> ExtractedColors {
        guard let cgImage else {
            let fallback = Self.fallbackPalette(count: count, seed: sourceSeed)
            return ExtractedColors(
                palette: fallback.map(\.color),
                dominant: fallback[0].color,
                secondary: fallback[1].color,
                isDark: true,
                isTopDark: true,
                luminance: 0.3,
                lyricRegionLuminance: 0.3
            )
        }

        let ciImage = CIImage(cgImage: cgImage)
        let context = Self.paletteContext
        let extent = ciImage.extent
        let width = extent.width
        let height = extent.height

        let center = areaAverageColor(
            ciImage: ciImage,
            rect: CGRect(
                x: extent.minX + width * 0.15,
                y: extent.minY + height * 0.15,
                width: width * 0.7,
                height: height * 0.7
            ),
            context: context
        )
        let top = areaAverageColor(
            ciImage: ciImage,
            rect: CGRect(
                x: extent.minX + width * 0.1,
                y: extent.minY + height * 0.8,
                width: width * 0.8,
                height: height * 0.15
            ),
            context: context
        )
        // Core Image 的坐标原点位于左下角。歌词主要落在播放器背景的中下部，
        // 单独采样这里，避免封面上方的脸部、天空等亮色把整页歌词误判为黑字。
        let lyricRegion = areaAverageColor(
            ciImage: ciImage,
            rect: CGRect(
                x: extent.minX + width * 0.08,
                y: extent.minY + height * 0.05,
                width: width * 0.84,
                height: height * 0.5
            ),
            context: context
        )

        var extracted = quantizedPalette(
            ciImage: ciImage,
            context: context,
            count: count,
            mode: mode,
            seed: sourceSeed ^ randomSeed
        )
        if extracted.isEmpty {
            extracted = Self.fallbackPalette(count: count, seed: sourceSeed)
        }
        while extracted.count < count {
            extracted.append(
                Self.derivedVariant(
                    from: extracted[extracted.count % max(extracted.count, 1)],
                    index: extracted.count,
                    count: count
                )
            )
        }

        let polished = extracted.prefix(count).enumerated().map { index, color in
            Self.polish(color, saturationBoost: index == 0 ? 1.22 : 1.12)
        }
        let palette = polished.map(\.color)
        let luminance = center.luminance

        return ExtractedColors(
            palette: palette,
            dominant: palette.first ?? .gray,
            secondary: palette.dropFirst().first ?? palette.first ?? .gray,
            isDark: luminance < 0.5,
            isTopDark: top.luminance < 0.5,
            luminance: luminance,
            lyricRegionLuminance: lyricRegion.luminance
        )
    }

    private func quantizedPalette(
        ciImage: CIImage,
        context: CIContext,
        count: Int,
        mode: CoverPaletteMode,
        seed: Int
    ) -> [RGBComponents] {
        let side = 40
        let normalized = ciImage.transformed(
            by: CGAffineTransform(
                translationX: -ciImage.extent.minX,
                y: -ciImage.extent.minY
            )
        )
        let scaled = normalized.transformed(
            by: CGAffineTransform(
                scaleX: CGFloat(side) / max(ciImage.extent.width, 1),
                y: CGFloat(side) / max(ciImage.extent.height, 1)
            )
        )

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        context.render(
            scaled,
            toBitmap: &pixels,
            rowBytes: side * 4,
            bounds: CGRect(x: 0, y: 0, width: side, height: side),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var buckets: [Int: ColorBucket] = [:]
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            guard pixels[offset + 3] > 160 else { continue }

            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let saturation = maximum > 0 ? (maximum - minimum) / maximum : 0
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722

            guard luminance > 0.035, luminance < 0.985 else { continue }

            let key = (Int(pixels[offset]) >> 4) << 8
                | (Int(pixels[offset + 1]) >> 4) << 4
                | (Int(pixels[offset + 2]) >> 4)
            let weight = 0.72 + saturation * 1.35 + min(luminance, 0.72) * 0.26
            var bucket = buckets[key, default: ColorBucket()]
            bucket.red += red * weight
            bucket.green += green * weight
            bucket.blue += blue * weight
            bucket.score += weight
            bucket.count += weight
            buckets[key] = bucket
        }

        var candidates = buckets.values
            .sorted { $0.score > $1.score }
            .prefix(36)
            .map(\.average)

        if mode == .random {
            var generator = SeededGenerator(
                state: UInt64(bitPattern: Int64(seed == 0 ? 1 : seed))
            )
            candidates.shuffle(using: &generator)
        }

        guard let first = candidates.first else { return [] }
        var selected = [first]
        var remaining = Array(candidates.dropFirst())

        while selected.count < count, !remaining.isEmpty {
            let scored = remaining.enumerated().map { index, candidate in
                let distance = selected.map {
                    Self.colorDistance(candidate, $0)
                }.min() ?? 0
                let saturationBonus = Double(candidate.saturation) * 0.12
                let randomBias = mode == .random
                    ? Double((index * 37 + seed).magnitude % 101) / 1000
                    : 0
                return (index, distance + saturationBonus + randomBias)
            }
            guard let winner = scored.max(by: { $0.1 < $1.1 }) else { break }
            selected.append(remaining.remove(at: winner.0))
        }

        return selected
    }

    private func areaAverageColor(
        ciImage: CIImage,
        rect: CGRect,
        context: CIContext
    ) -> RGBComponents {
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = rect

        guard let outputImage = filter.outputImage else {
            return RGBComponents(r: 0.5, g: 0.5, b: 0.5)
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return RGBComponents(
            r: CGFloat(pixel[0]) / 255,
            g: CGFloat(pixel[1]) / 255,
            b: CGFloat(pixel[2]) / 255
        )
    }

    private static func colorDistance(
        _ lhs: RGBComponents,
        _ rhs: RGBComponents
    ) -> Double {
        let red = Double(lhs.r - rhs.r)
        let green = Double(lhs.g - rhs.g)
        let blue = Double(lhs.b - rhs.b)
        return sqrt(red * red * 0.3 + green * green * 0.59 + blue * blue * 0.11)
    }

    private static func polish(
        _ color: RGBComponents,
        saturationBoost: CGFloat
    ) -> RGBComponents {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        UIColor(red: color.r, green: color.g, blue: color.b, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        return Self.rgb(
            hue: hue,
            saturation: min(max(saturation * saturationBoost, 0.12), 0.92),
            brightness: min(max(brightness, 0.34), 0.92)
        )
    }

    private static func derivedVariant(
        from color: RGBComponents,
        index: Int,
        count: Int
    ) -> RGBComponents {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        UIColor(red: color.r, green: color.g, blue: color.b, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let shift = CGFloat(index) / CGFloat(max(count, 1)) * 0.42
        return rgb(
            hue: (hue + shift).truncatingRemainder(dividingBy: 1),
            saturation: min(max(saturation, 0.28), 0.8),
            brightness: min(max(brightness, 0.46), 0.88)
        )
    }

    private static func fallbackPalette(
        count: Int,
        seed: Int
    ) -> [RGBComponents] {
        let baseHue = CGFloat(abs(seed % 360)) / 360
        return (0..<count).map { index in
            rgb(
                hue: (baseHue + CGFloat(index) * 0.115).truncatingRemainder(dividingBy: 1),
                saturation: 0.34 + CGFloat(index % 2) * 0.08,
                brightness: 0.68 + CGFloat(index % 3) * 0.07
            )
        }
    }

    private static func rgb(
        hue: CGFloat,
        saturation: CGFloat,
        brightness: CGFloat
    ) -> RGBComponents {
        let color = UIColor(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            alpha: 1
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return RGBComponents(r: red, g: green, b: blue)
    }
}
