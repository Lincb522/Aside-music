// ContrastRatio.swift
// Mono — material3-expressive-theme spec, Task 15
//
// 按 WCAG 2.1 相对亮度公式计算两种颜色的对比度。
// 用于 Property 6(requirements.md §7.1~7.4)的 Light / Dark 对比度断言。
//
// 本文件不声明 XCTest 测试用例,仅提供纯函数工具 API。
//
// 实现参考(鉴于 WCAG 的公式为工业标准,这里不引入外部库):
//   sRGB → linear:   c' = c/12.92, if c <= 0.03928
//                    c' = ((c + 0.055) / 1.055)^2.4, otherwise
//   相对亮度 L:       L  = 0.2126 R' + 0.7152 G' + 0.0722 B'
//   对比度:           ratio = (L1 + 0.05) / (L2 + 0.05),其中 L1 ≥ L2

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 公共 API

/// 计算两种颜色在指定 ColorScheme 下的 WCAG 对比度。
/// - Parameters:
///   - fg: 前景色(文字色)
///   - bg: 背景色
///   - scheme: Light / Dark,用于解析 `Color(light:dark:)` 的动态色
/// - Returns: 对比度,取值 >= 1.0(WCAG AA 正文要求 >= 4.5)
public func contrastRatio(_ fg: Color, _ bg: Color, in scheme: ColorScheme) -> Double {
    let l1 = relativeLuminance(of: fg, in: scheme)
    let l2 = relativeLuminance(of: bg, in: scheme)
    let (hi, lo) = l1 >= l2 ? (l1, l2) : (l2, l1)
    return (hi + 0.05) / (lo + 0.05)
}

/// 公开暴露相对亮度(便于 Property 7 / 11 等测试直接比较明度差)。
public func relativeLuminance(of color: Color, in scheme: ColorScheme) -> Double {
    let (r, g, b) = sRGBComponents(of: color, in: scheme)
    let rl = linearize(r)
    let gl = linearize(g)
    let bl = linearize(b)
    return 0.2126 * rl + 0.7152 * gl + 0.0722 * bl
}

/// 公开暴露 sRGB 三通道分量(0...1),便于断言 Light 与 Dark 下 hex 不相等。
public func sRGBComponents(of color: Color, in scheme: ColorScheme) -> (r: Double, g: Double, b: Double) {
    #if canImport(UIKit)
    let uiColor = UIColor(color)
    let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
    let resolved = uiColor.resolvedColor(with: traits)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
    return (Double(r), Double(g), Double(b))
    #elseif canImport(AppKit)
    let nsColor = NSColor(color)
    let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    var components: (Double, Double, Double) = (0, 0, 0)
    if let appearance {
        appearance.performAsCurrentDrawingAppearance {
            let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
            components = (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
        }
    } else {
        let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        components = (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
    }
    return (components.0, components.1, components.2)
    #else
    return (0, 0, 0)
    #endif
}

/// sRGB 分量转换为 hex 字符串(6 位大写),便于 Property 7 做 Light / Dark 差异性断言。
public func hexDescription(of color: Color, in scheme: ColorScheme) -> String {
    let (r, g, b) = sRGBComponents(of: color, in: scheme)
    return String(
        format: "%02X%02X%02X",
        Int((r * 255).rounded()),
        Int((g * 255).rounded()),
        Int((b * 255).rounded())
    )
}

// MARK: - 内部:sRGB → linear

@inline(__always)
private func linearize(_ component: Double) -> Double {
    let c = max(0.0, min(1.0, component))
    if c <= 0.039_28 {
        return c / 12.92
    } else {
        return pow((c + 0.055) / 1.055, 2.4)
    }
}
