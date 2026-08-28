import Combine
import QQMusicKit
import SwiftUI

struct LiquidGlassProfileLensShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let width = rect.width
        let height = rect.height

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + width * 0.12, y: rect.minY + height * 0.05))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.88, y: rect.minY + height * 0.02),
            control1: CGPoint(x: rect.minX + width * 0.32, y: rect.minY - height * 0.02),
            control2: CGPoint(x: rect.minX + width * 0.64, y: rect.minY + height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.98, y: rect.minY + height * 0.72),
            control1: CGPoint(x: rect.maxX + width * 0.02, y: rect.minY + height * 0.12),
            control2: CGPoint(x: rect.maxX - width * 0.02, y: rect.minY + height * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.62, y: rect.minY + height * 0.98),
            control1: CGPoint(x: rect.maxX - width * 0.04, y: rect.maxY + height * 0.03),
            control2: CGPoint(x: rect.minX + width * 0.78, y: rect.maxY - height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.04, y: rect.minY + height * 0.78),
            control1: CGPoint(x: rect.minX + width * 0.35, y: rect.maxY + height * 0.02),
            control2: CGPoint(x: rect.minX - width * 0.02, y: rect.maxY - height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.12, y: rect.minY + height * 0.05),
            control1: CGPoint(x: rect.minX + width * 0.0, y: rect.minY + height * 0.52),
            control2: CGPoint(x: rect.minX - width * 0.01, y: rect.minY + height * 0.16)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> LiquidGlassProfileLensShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - Quick Action Card (kept for potential reuse)
