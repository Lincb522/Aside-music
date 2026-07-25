import Foundation
import SwiftUI

// MARK: - 动画取样

/// 由时间戳计算无状态动画值，保证 Widget 时间线切换前后视觉连续。
struct WidgetAnimation {
    static func spectrumBar(index: Int, maxBars: Int, date: Date, speed: Double = 1.0, amplitude: Double = 1.0) -> CGFloat {
        let time = date.timeIntervalSinceReferenceDate * speed * 2.0
        let phase = Double(index) * 0.4
        let sin1 = sin(time + phase)
        let sin2 = sin(time * 1.5 - phase * 0.5)
        let normalized = (sin1 + sin2 + 2.0) / 4.0
        return CGFloat(min(max(normalized * amplitude, 0.1), 1.0))
    }

    static func signalBars(index: Int, count: Int, date: Date) -> Bool {
        let time = date.timeIntervalSinceReferenceDate * 3.0
        let activeBars = Int((sin(time) + 1.0) / 2.0 * Double(count))
        return index <= activeBars
    }

    static func ledPulse(date: Date, speed: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 4.0
        return (sin(time) + 1.0) / 2.0
    }

    static func cursorBlink(date: Date) -> Double {
        let time = date.timeIntervalSinceReferenceDate * 2.0
        return sin(time) > 0 ? 1.0 : 0.0
    }

    static func sweepAngle(date: Date, speed: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed
        return (time.truncatingRemainder(dividingBy: 2.0)) * .pi
    }

    static func wobble(date: Date, speed: Double = 1.0, amount: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 3.0
        return sin(time) * amount
    }

    static func bounce(date: Date, speed: Double = 1.0, height: Double = 5.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 4.0
        return abs(sin(time)) * height
    }

    static func breathe(date: Date, speed: Double = 1.0, min: Double = 0.5, max: Double = 1.0) -> Double {
        let time = date.timeIntervalSinceReferenceDate * speed * 2.0
        return min + (max - min) * ((sin(time) + 1.0) / 2.0)
    }
}
