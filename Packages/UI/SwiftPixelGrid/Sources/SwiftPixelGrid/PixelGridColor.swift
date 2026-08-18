import Foundation
import SwiftUI

/// 提供 12 个命名颜色，以及 `#RGB`、`#RRGGBB` 自定义颜色。
public enum PixelGridColor: Hashable, Sendable {
    /// 青色。
    case cyan
    /// 品红色。
    case magenta
    /// 黄色。
    case yellow
    /// 绿色。
    case green
    /// 橙色。
    case orange
    /// 蓝色。
    case blue
    /// 红色。
    case red
    /// 紫色。
    case purple
    /// 白色。
    case white
    /// 蓝绿色。
    case teal
    /// 粉色。
    case pink
    /// 亮绿色。
    case lime
    /// 以 `0xRRGGBB` 表示的自定义颜色。
    case hex(UInt32)

    /// 所有内置命名颜色，不包含自定义十六进制颜色。
    public static let namedColors: [Self] = [
        .cyan, .magenta, .yellow, .green, .orange, .blue,
        .red, .purple, .white, .teal, .pink, .lime,
    ]

    /// 从 `#RGB` 或 `#RRGGBB` 字符串创建自定义颜色。
    public init(hex: String) throws {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.first == "#" else {
            throw PixelGridColorError.invalidHex(hex)
        }

        let digits = String(value.dropFirst())
        let expanded: String
        switch digits.count {
        case 3:
            expanded = digits.map { "\($0)\($0)" }.joined()
        case 6:
            expanded = digits
        default:
            throw PixelGridColorError.invalidHex(hex)
        }

        guard let raw = UInt32(expanded, radix: 16) else {
            throw PixelGridColorError.invalidHex(hex)
        }
        self = .hex(raw)
    }
}

/// 解析自定义颜色时可能出现的错误。
public enum PixelGridColorError: Error, Equatable, Sendable {
    /// 输入不是受支持的十六进制格式。
    case invalidHex(String)
}

struct PixelGridPalette: Hashable, Sendable {
    let off: OKLabColor
    let on: OKLabColor
    let glow: OKLabColor

    var offColor: Color { off.swiftUIColor }
    var onColor: Color { on.swiftUIColor }
    var glowColor: Color { glow.swiftUIColor }

    static let defaultCyan = Self(
        off: .init(oklch: .init(lightness: 0.35, chroma: 0.04, hue: 195, alpha: 0.5)),
        on: .init(oklch: .init(lightness: 0.85, chroma: 0.15, hue: 195, alpha: 1)),
        glow: .init(oklch: .init(lightness: 0.75, chroma: 0.18, hue: 195, alpha: 0.8))
    )
}

extension PixelGridColor {
    var palette: PixelGridPalette {
        switch self {
        case .cyan:
            Self.cyanPalette
        case .magenta:
            Self.magentaPalette
        case .yellow:
            Self.yellowPalette
        case .green:
            Self.greenPalette
        case .orange:
            Self.orangePalette
        case .blue:
            Self.bluePalette
        case .red:
            Self.redPalette
        case .purple:
            Self.purplePalette
        case .white:
            Self.whitePalette
        case .teal:
            Self.tealPalette
        case .pink:
            Self.pinkPalette
        case .lime:
            Self.limePalette
        case .hex(let raw):
            customHexPalette(raw)
        }
    }

    // 命名色板是常量，缓存后可避免动画每帧重复进行三角函数转换。
    private static let cyanPalette = namedPalette(
        0.40, 0.08, 195, 0.4, 0.90, 0.20, 195, 0.80, 0.25, 195, 0.9
    )
    private static let magentaPalette = namedPalette(
        0.40, 0.08, 330, 0.4, 0.85, 0.25, 330, 0.75, 0.30, 330, 0.9
    )
    private static let yellowPalette = namedPalette(
        0.50, 0.08, 90, 0.4, 0.95, 0.20, 90, 0.90, 0.25, 90, 0.9
    )
    private static let greenPalette = namedPalette(
        0.40, 0.08, 145, 0.4, 0.90, 0.25, 145, 0.80, 0.30, 145, 0.9
    )
    private static let orangePalette = namedPalette(
        0.45, 0.08, 50, 0.4, 0.85, 0.22, 50, 0.75, 0.28, 50, 0.9
    )
    private static let bluePalette = namedPalette(
        0.40, 0.08, 260, 0.4, 0.80, 0.22, 260, 0.70, 0.28, 260, 0.9
    )
    private static let redPalette = namedPalette(
        0.40, 0.08, 25, 0.4, 0.70, 0.25, 25, 0.60, 0.30, 25, 0.9
    )
    private static let purplePalette = namedPalette(
        0.40, 0.08, 300, 0.4, 0.75, 0.22, 300, 0.65, 0.28, 300, 0.9
    )
    private static let whitePalette = namedPalette(
        0.50, 0, 0, 0.3, 0.98, 0, 0, 0.95, 0, 0, 0.8
    )
    private static let tealPalette = namedPalette(
        0.40, 0.08, 175, 0.4, 0.82, 0.18, 175, 0.72, 0.24, 175, 0.9
    )
    private static let pinkPalette = namedPalette(
        0.45, 0.08, 350, 0.4, 0.80, 0.20, 350, 0.70, 0.26, 350, 0.9
    )
    private static let limePalette = namedPalette(
        0.45, 0.08, 120, 0.4, 0.88, 0.22, 120, 0.80, 0.28, 120, 0.9
    )

    private static func namedPalette(
        _ offL: Double, _ offC: Double, _ offH: Double, _ offAlpha: Double,
        _ onL: Double, _ onC: Double, _ onH: Double,
        _ glowL: Double, _ glowC: Double, _ glowH: Double, _ glowAlpha: Double
    ) -> PixelGridPalette {
        PixelGridPalette(
            off: .init(oklch: .init(lightness: offL, chroma: offC, hue: offH, alpha: offAlpha)),
            on: .init(oklch: .init(lightness: onL, chroma: onC, hue: onH, alpha: 1)),
            glow: .init(oklch: .init(lightness: glowL, chroma: glowC, hue: glowH, alpha: glowAlpha))
        )
    }

    private func customHexPalette(_ raw: UInt32) -> PixelGridPalette {
        let red = Double((raw >> 16) & 0xFF) / 255
        let green = Double((raw >> 8) & 0xFF) / 255
        let blue = Double(raw & 0xFF) / 255
        let base = OKLabColor(sRGBRed: red, green: green, blue: blue, alpha: 1)
        let polar = base.oklch

        // 关闭色保留原色 25% 的亮度和色度。
        let off = OKLabColor(
            oklch: .init(
                lightness: polar.lightness * 0.25,
                chroma: polar.chroma * 0.25,
                hue: polar.hue,
                alpha: 1
            )
        )

        // 光晕保留原色分量，并将不透明度降为 60%。
        let glow = OKLabColor(
            lightness: base.lightness,
            a: base.a,
            b: base.b,
            alpha: 0.6
        )

        return PixelGridPalette(off: off, on: base, glow: glow)
    }
}

struct OKLCHColor: Hashable, Sendable {
    let lightness: Double
    let chroma: Double
    let hue: Double
    let alpha: Double
}

struct OKLabColor: Hashable, Sendable {
    let lightness: Double
    let a: Double
    let b: Double
    let alpha: Double

    init(lightness: Double, a: Double, b: Double, alpha: Double) {
        self.lightness = lightness
        self.a = a
        self.b = b
        self.alpha = alpha
    }

    init(oklch: OKLCHColor) {
        let radians = oklch.hue * .pi / 180
        self.init(
            lightness: oklch.lightness,
            a: oklch.chroma * cos(radians),
            b: oklch.chroma * sin(radians),
            alpha: oklch.alpha
        )
    }

    init(sRGBRed red: Double, green: Double, blue: Double, alpha: Double) {
        let r = Self.sRGBToLinear(red)
        let g = Self.sRGBToLinear(green)
        let b = Self.sRGBToLinear(blue)

        let l = 0.412_221_470_8 * r + 0.536_332_536_3 * g + 0.051_445_992_9 * b
        let m = 0.211_903_498_2 * r + 0.680_699_545_1 * g + 0.107_396_956_6 * b
        let s = 0.088_302_461_9 * r + 0.281_718_837_6 * g + 0.629_978_700_5 * b

        let lRoot = cbrt(l)
        let mRoot = cbrt(m)
        let sRoot = cbrt(s)

        self.init(
            lightness: 0.210_454_255_3 * lRoot + 0.793_617_785 * mRoot - 0.004_072_046_8 * sRoot,
            a: 1.977_998_495_1 * lRoot - 2.428_592_205 * mRoot + 0.450_593_709_9 * sRoot,
            b: 0.025_904_037_1 * lRoot + 0.782_771_766_2 * mRoot - 0.808_675_766 * sRoot,
            alpha: alpha
        )
    }

    var oklch: OKLCHColor {
        var hue = atan2(b, a) * 180 / .pi
        if hue < 0 { hue += 360 }
        return .init(
            lightness: lightness,
            chroma: hypot(a, b),
            hue: hue,
            alpha: alpha
        )
    }

    var swiftUIColor: Color {
        let components = sRGBComponents
        return Color(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: alpha
        )
    }

    var sRGBComponents: (red: Double, green: Double, blue: Double) {
        let lRoot = lightness + 0.396_337_777_4 * a + 0.215_803_757_3 * b
        let mRoot = lightness - 0.105_561_345_8 * a - 0.063_854_172_8 * b
        let sRoot = lightness - 0.089_484_177_5 * a - 1.291_485_548 * b

        let l = lRoot * lRoot * lRoot
        let m = mRoot * mRoot * mRoot
        let s = sRoot * sRoot * sRoot

        let linearRed = 4.076_741_662_1 * l - 3.307_711_591_3 * m + 0.230_969_929_2 * s
        let linearGreen = -1.268_438_004_6 * l + 2.609_757_401_1 * m - 0.341_319_396_5 * s
        let linearBlue = -0.004_196_086_3 * l - 0.703_418_614_7 * m + 1.707_614_701 * s

        // OKLCH 转换为编码后的 sRGB，超出色域的通道裁剪到 0...1。
        return (
            Self.linearToSRGB(linearRed),
            Self.linearToSRGB(linearGreen),
            Self.linearToSRGB(linearBlue)
        )
    }

    static func interpolate(from: Self, to: Self, progress: Double) -> Self {
        let amount = min(max(progress, 0), 1)
        let alpha = from.alpha + (to.alpha - from.alpha) * amount

        // 在 OKLab 矩形空间内使用预乘 Alpha 插值。
        guard alpha > .ulpOfOne else {
            return .init(lightness: 0, a: 0, b: 0, alpha: 0)
        }

        let fromWeight = 1 - amount
        let toWeight = amount
        return .init(
            lightness: (from.lightness * from.alpha * fromWeight
                + to.lightness * to.alpha * toWeight) / alpha,
            a: (from.a * from.alpha * fromWeight + to.a * to.alpha * toWeight) / alpha,
            b: (from.b * from.alpha * fromWeight + to.b * to.alpha * toWeight) / alpha,
            alpha: alpha
        )
    }

    private static func sRGBToLinear(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ value: Double) -> Double {
        let encoded =
            value <= 0.003_130_8
            ? 12.92 * value
            : 1.055 * pow(value, 1 / 2.4) - 0.055
        return min(max(encoded, 0), 1)
    }
}
