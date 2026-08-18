import Foundation

/// 描述 3×3 像素动画帧分组的二维 Pattern。
///
/// 单元编号按从左到右、从上到下排列：
///
/// ```
/// 1 2 3
/// 4 5 6
/// 7 8 9
/// ```
public struct PixelPattern: Hashable, Sendable {
    /// 调用方传入并经过编号规范化的分组。
    public let groups: [[Int]]
    let playbackFrames: [PixelGridFrame]

    /// 创建 Pattern；非法编号与重复编号会在播放帧中移除。
    public init(_ groups: [[Int]]) {
        self.groups = groups
        playbackFrames = Self.compile(groups)
    }

    /// 按分组结构把 Pattern 编译成实际播放帧。
    public var frames: [[Int]] {
        playbackFrames.map(\.activeCellNumbers)
    }

    /// 默认的顺时针环形 Pattern。
    public static let clockwiseRing = Self([[1, 2, 3, 6, 9, 8, 7, 4]])

    private static func compile(_ groups: [[Int]]) -> [PixelGridFrame] {
        guard let first = groups.first else { return [] }

        // 只有一组时，组内的每个编号依次成为单独一帧。
        if groups.count == 1 {
            return first.map { PixelGridFrame(activeCellNumbers: [$0]) }
        }

        // 每组都只有一个编号时，合并为一帧，再补一帧全灭，
        // 从而得到整组闪烁的效果。
        let allSingles = groups.allSatisfy { $0.count == 1 }
        if allSingles {
            let merged = groups.compactMap(\.first)
            return [
                PixelGridFrame(activeCellNumbers: merged),
                .off,
            ]
        }

        // 其他输入已经直接描述了逐帧状态。
        return groups.map(PixelGridFrame.init(activeCellNumbers:))
    }
}
