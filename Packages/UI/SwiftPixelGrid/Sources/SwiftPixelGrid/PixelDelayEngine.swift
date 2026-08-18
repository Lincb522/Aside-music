import Foundation

/// 根据九个像素的独立延迟计算连续亮度。
public struct PixelDelayEngine: Hashable, Sendable {
    static let transitionDuration: TimeInterval = 0.3
    static let fadeOutPadding: TimeInterval = 0.05

    /// 引擎使用的动画配置。
    public let animation: PixelGridAnimation

    /// 创建一个连续延迟动画引擎。
    public init(animation: PixelGridAnimation) {
        self.animation = animation
    }

    var maximumDelay: TimeInterval {
        animation.delays.max() ?? 0
    }

    var holdTime: TimeInterval {
        maximumDelay + animation.duration
    }

    var cycleDuration: TimeInterval {
        2 * (maximumDelay + animation.duration) + Self.fadeOutPadding
    }

    func frame(at elapsedTime: TimeInterval) -> PixelGridFrame {
        PixelGridFrame(
            intensities: animation.delays.map {
                intensity(at: max(0, elapsedTime), delay: $0)
            }
        )
    }

    /// 返回指定时间的九格连续亮度，取值范围为 `0...1`。
    public func intensities(
        at elapsedTime: TimeInterval,
        isAnimating: Bool = true,
        reduceMotion: Bool = false
    ) -> [Double] {
        PixelGridPlayback.delay(self).frame(
            at: elapsedTime,
            state: PixelGridPlaybackState(
                isAnimating: isAnimating,
                reduceMotion: reduceMotion
            )
        ).intensities
    }

    func intensity(
        at elapsedTime: TimeInterval,
        delay: TimeInterval
    ) -> Double {
        let localTime = positiveRemainder(
            elapsedTime - delay,
            modulus: cycleDuration
        )

        if localTime < holdTime {
            guard localTime < Self.transitionDuration else { return 1 }
            return CubicEaseOut.value(at: localTime / Self.transitionDuration)
        }

        let fadeOutTime = localTime - holdTime
        guard fadeOutTime < Self.transitionDuration else { return 0 }
        return 1 - CubicEaseOut.value(at: fadeOutTime / Self.transitionDuration)
    }

    private func positiveRemainder(_ value: Double, modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

/// 三次贝塞尔缓出曲线 `cubic-bezier(0, 0, 0.58, 1)`。
enum CubicEaseOut {
    static func value(at progress: Double) -> Double {
        let x = min(max(progress, 0), 1)
        if x == 0 || x == 1 { return x }

        var parameter = x
        for _ in 0..<8 {
            let error = curveX(parameter) - x
            let slope = curveXSlope(parameter)
            if abs(error) < 1e-7 { return curveY(parameter) }
            if abs(slope) < 1e-7 { break }
            parameter -= error / slope
        }

        var lower = 0.0
        var upper = 1.0
        parameter = x
        for _ in 0..<24 {
            let current = curveX(parameter)
            if abs(current - x) < 1e-7 { break }
            if current < x {
                lower = parameter
            } else {
                upper = parameter
            }
            parameter = (lower + upper) / 2
        }
        return curveY(parameter)
    }

    private static func curveX(_ t: Double) -> Double {
        let inverse = 1 - t
        return 3 * inverse * t * t * 0.58 + t * t * t
    }

    private static func curveY(_ t: Double) -> Double {
        let inverse = 1 - t
        return 3 * inverse * t * t + t * t * t
    }

    private static func curveXSlope(_ t: Double) -> Double {
        3 * 1.16 * t + 3 * (1 - 1.74) * t * t
    }
}
