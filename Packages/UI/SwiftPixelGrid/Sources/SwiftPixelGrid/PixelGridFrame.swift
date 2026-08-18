import SwiftUI

/// 3×3 像素网格在某一时刻的完整亮度状态。
///
/// 该类型集中维护固定九格拓扑、单元编号、强度归一化与 SwiftUI 向量运算。
struct PixelGridFrame: VectorArithmetic, Hashable, Sendable {
    enum Cell: Int, CaseIterable, Hashable, Sendable {
        case topLeft = 1
        case top
        case topRight
        case left
        case center
        case right
        case bottomLeft
        case bottom
        case bottomRight

        static let rows: [[Self]] = [
            [.topLeft, .top, .topRight],
            [.left, .center, .right],
            [.bottomLeft, .bottom, .bottomRight],
        ]

        var index: Int {
            rawValue - 1
        }

        var row: Int {
            index / 3
        }

        var column: Int {
            index % 3
        }
    }

    static let cellCount = Cell.allCases.count
    static let off = Self(vectorValues: Array(repeating: 0, count: cellCount))
    static let on = Self(vectorValues: Array(repeating: 1, count: cellCount))
    static let zero = off

    private var vectorValues: [Double]

    /// 从任意长度数组生成九格亮度；缺值补 0，多余值忽略，非法值归零。
    init(intensities: [Double]) {
        vectorValues = Cell.allCases.map { cell in
            guard intensities.indices.contains(cell.index) else { return 0 }
            return Self.normalizedIntensity(intensities[cell.index])
        }
    }

    /// 从 1...9 单元编号生成二值帧；非法编号和重复编号被忽略。
    init(activeCellNumbers: some Sequence<Int>) {
        let activeCells = Set(activeCellNumbers.compactMap(Cell.init(rawValue:)))
        vectorValues = Cell.allCases.map { activeCells.contains($0) ? 1 : 0 }
    }

    private init(vectorValues: [Double]) {
        precondition(vectorValues.count == Self.cellCount)
        self.vectorValues = vectorValues
    }

    var intensities: [Double] {
        Cell.allCases.map { intensity(at: $0) }
    }

    var activeCellNumbers: [Int] {
        Cell.allCases.compactMap { cell in
            intensity(at: cell) > 0 ? cell.rawValue : nil
        }
    }

    func intensity(at cell: Cell) -> Double {
        Self.normalizedIntensity(vectorValues[cell.index])
    }

    func isActive(_ cell: Cell) -> Bool {
        intensity(at: cell) > 0
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(
            vectorValues: zip(lhs.vectorValues, rhs.vectorValues).map(+)
        )
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(
            vectorValues: zip(lhs.vectorValues, rhs.vectorValues).map(-)
        )
    }

    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    static func -= (lhs: inout Self, rhs: Self) {
        lhs = lhs - rhs
    }

    mutating func scale(by rhs: Double) {
        vectorValues = vectorValues.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        vectorValues.reduce(0) { partialResult, value in
            partialResult + value * value
        }
    }

    private static func normalizedIntensity(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
