// MujiWCAGContrastTests.swift
// Mono — muji-theme-redesign spec, Task 1.3
//
// Property 1: WCAG 对比度合规性
// 验证所有前景/背景色对的对比度满足 WCAG AA 标准
// 正文文字 >= 4.5:1，大文字 >= 3:1
//
// **Validates: Requirements 1.5**

import XCTest
import SwiftUI
@testable import Mono

// MARK: - 颜色对定义

/// 前景/背景色对，附带用途描述和文字类型
private struct ColorPair {
    let foreground: Color
    let background: Color
    let foregroundName: String
    let backgroundName: String
    /// true = 大文字（>= 18pt 或 14pt bold），阈值 3:1
    /// false = 正文文字，阈值 4.5:1
    let isLargeText: Bool

    var minimumRatio: Double { isLargeText ? 3.0 : 4.5 }
    var textType: String { isLargeText ? "大文字" : "正文" }
}

// MARK: - 测试用例

/// Feature: muji-theme-redesign, Property 1: WCAG 对比度合规性
final class MujiWCAGContrastTests: XCTestCase {

    // ── 所有需要验证的前景/背景色对 ──
    // 根据设计文档：
    //   ink 用于主文字（正文），inkSoft 用于副文字（正文），
    //   inkMuted 用于辅助文字（通常为大文字/标注），clay 用于强调色（大文字/按钮）
    private static let colorPairs: [ColorPair] = [
        // ink（主文字）在各背景上 — 正文文字，阈值 4.5:1
        ColorPair(foreground: MujiStyle.ink, background: MujiStyle.paper,
                  foregroundName: "ink", backgroundName: "paper", isLargeText: false),
        ColorPair(foreground: MujiStyle.ink, background: MujiStyle.surface,
                  foregroundName: "ink", backgroundName: "surface", isLargeText: false),
        ColorPair(foreground: MujiStyle.ink, background: MujiStyle.surfaceRaised,
                  foregroundName: "ink", backgroundName: "surfaceRaised", isLargeText: false),

        // inkSoft（副文字）在各背景上 — 正文文字，阈值 4.5:1
        ColorPair(foreground: MujiStyle.inkSoft, background: MujiStyle.paper,
                  foregroundName: "inkSoft", backgroundName: "paper", isLargeText: false),
        ColorPair(foreground: MujiStyle.inkSoft, background: MujiStyle.surface,
                  foregroundName: "inkSoft", backgroundName: "surface", isLargeText: false),
        ColorPair(foreground: MujiStyle.inkSoft, background: MujiStyle.surfaceRaised,
                  foregroundName: "inkSoft", backgroundName: "surfaceRaised", isLargeText: false),

        // inkMuted（辅助/标注文字）在各背景上 — 大文字，阈值 3:1
        ColorPair(foreground: MujiStyle.inkMuted, background: MujiStyle.paper,
                  foregroundName: "inkMuted", backgroundName: "paper", isLargeText: true),
        ColorPair(foreground: MujiStyle.inkMuted, background: MujiStyle.surface,
                  foregroundName: "inkMuted", backgroundName: "surface", isLargeText: true),
        ColorPair(foreground: MujiStyle.inkMuted, background: MujiStyle.surfaceRaised,
                  foregroundName: "inkMuted", backgroundName: "surfaceRaised", isLargeText: true),

        // clay（强调色）在各背景上 — 大文字（按钮/标签），阈值 3:1
        ColorPair(foreground: MujiStyle.clay, background: MujiStyle.paper,
                  foregroundName: "clay", backgroundName: "paper", isLargeText: true),
        ColorPair(foreground: MujiStyle.clay, background: MujiStyle.surface,
                  foregroundName: "clay", backgroundName: "surface", isLargeText: true),
        ColorPair(foreground: MujiStyle.clay, background: MujiStyle.surfaceRaised,
                  foregroundName: "clay", backgroundName: "surfaceRaised", isLargeText: true),
    ]

    // ── 确定性遍历测试：浅色模式 ──

    /// 验证所有前景/背景色对在浅色模式下满足 WCAG AA 对比度
    func testWCAGContrastLightMode() {
        let scheme: ColorScheme = .light

        for pair in Self.colorPairs {
            let ratio = contrastRatio(pair.foreground, pair.background, in: scheme)
            XCTAssertGreaterThanOrEqual(
                ratio, pair.minimumRatio,
                """
                WCAG AA 对比度不足 [浅色模式]
                前景: \(pair.foregroundName), 背景: \(pair.backgroundName)
                类型: \(pair.textType), 最低要求: \(pair.minimumRatio):1
                实际对比度: \(String(format: "%.2f", ratio)):1
                """
            )
        }
    }

    // ── 确定性遍历测试：深色模式 ──

    /// 验证所有前景/背景色对在深色模式下满足 WCAG AA 对比度
    func testWCAGContrastDarkMode() {
        let scheme: ColorScheme = .dark

        for pair in Self.colorPairs {
            let ratio = contrastRatio(pair.foreground, pair.background, in: scheme)
            XCTAssertGreaterThanOrEqual(
                ratio, pair.minimumRatio,
                """
                WCAG AA 对比度不足 [深色模式]
                前景: \(pair.foregroundName), 背景: \(pair.backgroundName)
                类型: \(pair.textType), 最低要求: \(pair.minimumRatio):1
                实际对比度: \(String(format: "%.2f", ratio)):1
                """
            )
        }
    }

    // ── Property 1: 属性测试（随机采样 100 次） ──

    /// 使用 PropertyRunner 进行 100 次随机迭代验证 WCAG 对比度合规性
    /// 随机选择色对和 ColorScheme 组合，验证对比度满足阈值
    func testWCAGContrastPropertyBased() {
        PropertyRunner.check(
            "Property 1: WCAG 对比度合规性",
            iterations: 100
        ) { rng -> (Int, ColorScheme) in
            // 随机选择一个色对索引
            let pairIndex = Int(rng.next() % UInt64(MujiWCAGContrastTests.colorPairs.count))
            // 随机选择 ColorScheme
            let scheme = ColorSchemeGen.any(using: &rng)
            return (pairIndex, scheme)
        } shrink: { input in
            // 尝试收缩色对索引（更小的索引 = 更基础的色对）
            let (idx, scheme) = input
            var candidates: [(Int, ColorScheme)] = []
            if idx > 0 {
                candidates.append((idx - 1, scheme))
                candidates.append((0, scheme))
            }
            return candidates
        } check: { input in
            let (pairIndex, scheme) = input
            let pair = MujiWCAGContrastTests.colorPairs[pairIndex]
            let ratio = contrastRatio(pair.foreground, pair.background, in: scheme)
            if ratio < pair.minimumRatio {
                return """
                    WCAG AA 对比度不足 [\(scheme == .light ? "浅色" : "深色")模式]
                    前景: \(pair.foregroundName), 背景: \(pair.backgroundName)
                    类型: \(pair.textType), 最低要求: \(pair.minimumRatio):1
                    实际对比度: \(String(format: "%.2f", ratio)):1
                    """
            }
            return nil
        }
    }
}
