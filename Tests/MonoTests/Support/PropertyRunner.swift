// PropertyRunner.swift
// Mono — material3-expressive-theme spec, Task 15
//
// 手写 Property-Based Testing 运行器。不引入 SwiftCheck 等外部依赖,
// 保持 Package.swift 零外部测试依赖。
//
// 设计要点:
//   * 默认 100 轮随机迭代(对应 requirements §9 与 design.md §Testing Strategy)。
//   * 可重放:使用显式种子(seed)初始化 PRNG,失败时打印 seed 便于复现。
//   * 简单 shrinking:对 Int / Bool 做二分/取反式反例最小化,其它类型跳过 shrink。
//   * 本文件**不**声明任何 XCTestCase 子类或 @Test 用例,仅提供工具 API。

import Foundation
import XCTest

// MARK: - 可种子化的伪随机发生器

/// 线性同余生成器 + splitmix64 常数,足以覆盖 PBT 需求。
/// 对齐 requirements.md Property 1~14 对"随机输入"的描述。
public struct SeededRNG: RandomNumberGenerator {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        // 避免 state == 0 导致所有输出为 0
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        // splitmix64 变种
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z &>> 31)
    }
}

// MARK: - 失败报告

public struct PropertyFailure<Input>: Error, CustomStringConvertible {
    public let seed: UInt64
    public let iteration: Int
    public let originalCounterexample: Input
    public let shrunkCounterexample: Input
    public let reason: String

    public var description: String {
        """
        [PropertyRunner] 属性失败
          seed: \(seed)
          iteration: \(iteration)
          原始反例: \(originalCounterexample)
          最小化反例: \(shrunkCounterexample)
          reason: \(reason)
        """
    }
}

// MARK: - PropertyRunner

public enum PropertyRunner {

    /// 默认迭代轮数(requirements.md §Correctness Properties 要求 ≥ 100 次)。
    public static let defaultIterations: Int = 100

    /// 默认最大 shrink 次数,防止退化到无限循环。
    public static let defaultMaxShrinkSteps: Int = 64

    /// 运行一次 Property 测试。
    /// - Parameters:
    ///   - name: 属性名,用于失败日志(建议填 "Property N: …")。
    ///   - iterations: 随机轮数,默认 100。
    ///   - seed: 起始种子。nil 时使用 `UInt64.random(in:)` 生成,失败时会打印。
    ///   - file / line: XCTFail 定位用。
    ///   - gen: 生成器闭包,接受 inout RNG,返回测试输入。
    ///   - shrink: 针对反例进行单步收缩,返回更小的候选集合(空数组表示无法继续收缩)。
    ///   - check: 属性判定,返回 nil 表示通过;返回字符串表示失败原因。
    public static func check<Input>(
        _ name: String,
        iterations: Int = PropertyRunner.defaultIterations,
        seed: UInt64? = nil,
        file: StaticString = #filePath,
        line: UInt = #line,
        gen: (inout SeededRNG) -> Input,
        shrink: (Input) -> [Input] = { _ in [] },
        check: (Input) -> String?
    ) {
        let chosenSeed = seed ?? UInt64.random(in: 1...UInt64.max)
        var rng = SeededRNG(seed: chosenSeed)

        for iteration in 0..<iterations {
            let input = gen(&rng)
            if let reason = check(input) {
                let shrunk = shrinkCounterexample(
                    from: input,
                    shrink: shrink,
                    check: check,
                    maxSteps: PropertyRunner.defaultMaxShrinkSteps
                )
                let failure = PropertyFailure<Input>(
                    seed: chosenSeed,
                    iteration: iteration,
                    originalCounterexample: input,
                    shrunkCounterexample: shrunk.input,
                    reason: shrunk.reason ?? reason
                )
                XCTFail("\(name)\n\(failure.description)", file: file, line: line)
                return
            }
        }
    }

    // MARK: - Shrink 逻辑

    private static func shrinkCounterexample<Input>(
        from initial: Input,
        shrink: (Input) -> [Input],
        check: (Input) -> String?,
        maxSteps: Int
    ) -> (input: Input, reason: String?) {
        var current = initial
        var currentReason: String? = nil
        var step = 0
        while step < maxSteps {
            let candidates = shrink(current)
            guard let smaller = candidates.first(where: { check($0) != nil }) else {
                break
            }
            currentReason = check(smaller)
            current = smaller
            step += 1
        }
        return (current, currentReason)
    }
}

// MARK: - 内置 shrinker:Int / Bool

public enum Shrinkers {

    /// 对 Int 做简单二分收缩。
    /// 规则:
    ///   * 0 无法继续收缩。
    ///   * 负数先尝试取绝对值(绝对值更小);否则尝试 n/2, n-1(并保留符号)。
    public static func shrinkInt(_ n: Int) -> [Int] {
        if n == 0 { return [] }
        var candidates: [Int] = []
        if n < 0 {
            candidates.append(-n)
        }
        let half = n / 2
        if half != n { candidates.append(half) }
        if n > 0 {
            candidates.append(n - 1)
        } else if n < 0 {
            candidates.append(n + 1)
        }
        // 去重保持顺序
        var seen = Set<Int>()
        return candidates.filter { c in
            guard !seen.contains(c), abs(c) < abs(n) || (c == 0 && n != 0) else { return false }
            seen.insert(c)
            return true
        }
    }

    /// 对 Bool 做收缩:true → [false],false 无法再小。
    public static func shrinkBool(_ b: Bool) -> [Bool] {
        b ? [false] : []
    }

    /// 对 Int 数组做简单收缩(元素个数减半或去掉首/尾元素)。
    public static func shrinkIntArray(_ xs: [Int]) -> [[Int]] {
        if xs.isEmpty { return [] }
        var out: [[Int]] = []
        if xs.count > 1 {
            out.append(Array(xs.dropFirst()))
            out.append(Array(xs.dropLast()))
            out.append(Array(xs.prefix(xs.count / 2)))
        }
        // 归零一个元素以趋近最小反例
        for i in 0..<xs.count where xs[i] != 0 {
            var copy = xs
            copy[i] = 0
            out.append(copy)
            break
        }
        return out
    }
}
