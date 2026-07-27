// Generators.swift
// Mono — material3-expressive-theme spec, Task 15
//
// 暴露用于 Property-Based Testing 的随机生成器。
// 对齐 requirements.md §Correctness Properties 与 design.md §Testing Strategy
// 中对"随机输入"类型的描述。
//
// 本文件不声明 XCTest 测试用例,仅提供工具 API。

import Foundation
import SwiftUI
@testable import Mono

// MARK: - GlobalThemeIdGen

public enum GlobalThemeIdGen {
    /// 从 `GlobalThemeId.allCases` 中均匀采样。
    /// 用于 Property 1 / 3 / 4 / 9 / 13 等测试。
    public static func any(using rng: inout SeededRNG) -> GlobalThemeId {
        let cases = GlobalThemeId.allCases
        let idx = Int(rng.next() % UInt64(cases.count))
        return cases[idx]
    }

    /// 采样出与 `exclude` 不同的 id;若 allCases 只剩一个元素则返回该元素。
    public static func anyExcept(_ exclude: GlobalThemeId, using rng: inout SeededRNG) -> GlobalThemeId {
        let pool = GlobalThemeId.allCases.filter { $0 != exclude }
        guard !pool.isEmpty else { return exclude }
        let idx = Int(rng.next() % UInt64(pool.count))
        return pool[idx]
    }
}

// MARK: - HexStringGen

public enum HexStringGen {
    private static let hexAlphabet: [Character] = Array("0123456789abcdef")
    private static let hexAlphabetUpper: [Character] = Array("0123456789ABCDEF")

    /// 生成 6 位十六进制字符串(不含 "#" 前缀)。
    /// 用于 Property 8(accent / background 自定义 round-trip)。
    public static func sixDigit(using rng: inout SeededRNG, uppercase: Bool = false) -> String {
        let alpha = uppercase ? hexAlphabetUpper : hexAlphabet
        var chars = [Character]()
        chars.reserveCapacity(6)
        for _ in 0..<6 {
            let idx = Int(rng.next() % UInt64(alpha.count))
            chars.append(alpha[idx])
        }
        return String(chars)
    }

    /// 生成 [3, 6, 8] 三种长度之一的 hex 字符串(测试边界容错)。
    public static func variableLength(using rng: inout SeededRNG) -> String {
        let lengths: [Int] = [3, 6, 8]
        let pick = lengths[Int(rng.next() % UInt64(lengths.count))]
        var chars = [Character]()
        chars.reserveCapacity(pick)
        for _ in 0..<pick {
            let idx = Int(rng.next() % UInt64(hexAlphabet.count))
            chars.append(hexAlphabet[idx])
        }
        return String(chars)
    }
}

// MARK: - AsciiStringGen

public enum AsciiStringGen {

    /// 生成任意 ASCII 字符串(可见字符 0x20 ~ 0x7E),长度 ∈ [0, maxLen]。
    /// 用于 Property 2(非法 rawValue 错误回落)。
    public static func any(using rng: inout SeededRNG, maxLen: Int = 24) -> String {
        let length = Int(rng.next() % UInt64(max(1, maxLen + 1)))
        var scalars = [Unicode.Scalar]()
        scalars.reserveCapacity(length)
        for _ in 0..<length {
            let byte = UInt8(rng.next() % UInt64(0x7E - 0x20 + 1)) + 0x20
            if let s = Unicode.Scalar(UInt32(byte)) {
                scalars.append(s)
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// 生成保证不与 GlobalThemeId allCases 任一 rawValue 相等的 ASCII 字符串。
    /// 用于 Property 2 的反例采样。
    public static func anyNotMatchingGlobalThemeId(using rng: inout SeededRNG, maxLen: Int = 24) -> String {
        let banned = Set(GlobalThemeId.allCases.map { $0.rawValue })
            .union(["bento", "sequoia", "liquidGlass", "clay", "signal"])
        // 最多尝试 32 次生成,若仍命中则在末尾追加 "!" 强制区分
        for _ in 0..<32 {
            let s = any(using: &rng, maxLen: maxLen)
            if !banned.contains(s) { return s }
        }
        return "__invalid_\(rng.next())__"
    }
}

// MARK: - IntGen

public enum IntGen {

    /// 生成闭区间 [lo, hi] 内的整数。
    /// 用于 Property 3(重复次数)/ Property 14(elevation 边界 ∈ [-100, 100])。
    public static func range(_ lo: Int, _ hi: Int, using rng: inout SeededRNG) -> Int {
        precondition(lo <= hi, "IntGen.range 要求 lo <= hi")
        let span = UInt64(hi - lo + 1)
        let r = Int(rng.next() % span)
        return lo + r
    }

    /// 生成小范围非负整数 [0, hi]。
    public static func nonNegative(upTo hi: Int, using rng: inout SeededRNG) -> Int {
        range(0, hi, using: &rng)
    }
}

// MARK: - BoolGen

public enum BoolGen {
    /// 均匀采样 Bool。用于 Property 12(按压 scale 边界)。
    public static func any(using rng: inout SeededRNG) -> Bool {
        (rng.next() & 1) == 1
    }

    /// 生成长度为 n 的 [Bool]。用于 Property 12 对"跨帧状态序列"的测试。
    public static func sequence(length: Int, using rng: inout SeededRNG) -> [Bool] {
        precondition(length >= 0)
        return (0..<length).map { _ in any(using: &rng) }
    }
}

// MARK: - ColorSchemeGen

public enum ColorSchemeGen {
    private static let all: [ColorScheme] = [.light, .dark]

    /// 均匀采样 ColorScheme。用于 Property 6 / 7 / 11 等 Light×Dark 枚举。
    public static func any(using rng: inout SeededRNG) -> ColorScheme {
        all[Int(rng.next() & 1)]
    }

    /// 返回全量 [.light, .dark] 枚举(供双 scheme 遍历使用)。
    public static var allCases: [ColorScheme] { all }
}
