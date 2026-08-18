import Foundation

/// 按固定时间间隔播放 `PixelPattern` 的离散帧引擎。
///
/// 引擎只负责把时间映射为九个像素的开关状态，不依赖 SwiftUI，
/// 因而可以被 Canvas 和普通视图渲染器共同使用。
public struct PixelPatternEngine: Hashable, Sendable {
    /// 每个离散目标帧的持续时间。
    public let frameDuration: TimeInterval

    /// 相邻目标帧之间的 SwiftUI 插值时长。
    public let transitionDuration: TimeInterval
    private let playbackFrames: [PixelGridFrame]

    /// 规范化后的播放帧。
    public var frames: [[Int]] {
        playbackFrames.map(\.activeCellNumbers)
    }

    /// 创建固定间隔的 Pattern 时间引擎。
    public init(
        pattern: PixelPattern,
        frameDuration: TimeInterval = 0.1,
        transitionDuration: TimeInterval = 0.08
    ) {
        playbackFrames = pattern.playbackFrames
        let normalizedFrameDuration = Self.normalizedDuration(frameDuration)
        self.frameDuration = normalizedFrameDuration
        self.transitionDuration = Self.normalizedTransitionDuration(
            transitionDuration
        )
    }

    /// 返回指定时间对应的帧下标；空 pattern 返回 `nil`。
    public func frameIndex(at elapsedTime: TimeInterval) -> Int? {
        guard !playbackFrames.isEmpty else { return nil }
        guard elapsedTime.isFinite else { return 0 }

        let cycleDuration = frameDuration * Double(playbackFrames.count)
        let remainder = elapsedTime.truncatingRemainder(
            dividingBy: cycleDuration
        )
        let cycleTime =
            remainder >= 0
            ? remainder
            : remainder + cycleDuration

        return min(
            Int(cycleTime / frameDuration),
            playbackFrames.count - 1
        )
    }

    /// 返回指定时间点亮的 1...9 单元编号。
    public func activeCells(
        at elapsedTime: TimeInterval,
        isAnimating: Bool = true,
        reduceMotion: Bool = false
    ) -> [Int] {
        resolvedFrame(
            at: elapsedTime,
            isAnimating: isAnimating,
            reduceMotion: reduceMotion
        ).activeCellNumbers
    }

    /// 生成渲染器可以直接使用的九个目标亮度值。
    ///
    /// Pattern 引擎只负责输出 0 或 1；帧间亮度由 SwiftUI 动画插值。
    public func intensities(
        at elapsedTime: TimeInterval,
        isAnimating: Bool = true,
        reduceMotion: Bool = false
    ) -> [Double] {
        resolvedFrame(
            at: elapsedTime,
            isAnimating: isAnimating,
            reduceMotion: reduceMotion
        ).intensities
    }

    func frame(at elapsedTime: TimeInterval) -> PixelGridFrame {
        guard let index = frameIndex(at: elapsedTime) else {
            return .off
        }
        return playbackFrames[index]
    }

    var reducedMotionFrame: PixelGridFrame {
        PixelGridFrame(
            activeCellNumbers: playbackFrames.flatMap(\.activeCellNumbers)
        )
    }

    private func resolvedFrame(
        at elapsedTime: TimeInterval,
        isAnimating: Bool,
        reduceMotion: Bool
    ) -> PixelGridFrame {
        PixelGridPlayback.pattern(self).frame(
            at: elapsedTime,
            state: PixelGridPlaybackState(
                isAnimating: isAnimating,
                reduceMotion: reduceMotion
            )
        )
    }

    private static func normalizedDuration(
        _ duration: TimeInterval
    ) -> TimeInterval {
        guard duration.isFinite, duration > 0 else {
            return 1.0 / 120
        }
        return max(duration, 1.0 / 120)
    }

    private static func normalizedTransitionDuration(
        _ duration: TimeInterval
    ) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return 0 }
        return duration
    }
}
