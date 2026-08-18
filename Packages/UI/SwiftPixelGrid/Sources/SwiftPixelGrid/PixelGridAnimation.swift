import Foundation

/// 3×3 像素动画的定义。
///
/// `delays` 保存九个像素的独立延迟，`duration` 保存点亮保持时间，
/// 时间单位统一使用秒。
public struct PixelGridAnimation: Hashable, Identifiable, Sendable {
    /// 用于标识动画的稳定名称。
    public let name: String

    /// 九个像素分别对应的启动延迟，单位为秒。
    public let delays: [TimeInterval]

    /// 单元完全点亮后的保持时长，单位为秒。
    public let duration: TimeInterval

    /// 可选的九格独立颜色。
    public let colors: [PixelGridColor]?

    /// 可选的统一颜色；设置后用于全部九格。
    public let color: PixelGridColor?

    public var id: String { name }

    var appearance: PixelGridAppearance {
        PixelGridAppearance(color: color, colors: colors)
    }

    /// 创建连续延迟动画；延迟或颜色数组必须恰好包含九项。
    public init(
        name: String,
        delays: [TimeInterval],
        duration: TimeInterval,
        colors: [PixelGridColor]? = nil,
        color: PixelGridColor? = nil
    ) throws {
        guard delays.count == PixelGridFrame.cellCount else {
            throw PixelGridAnimationError.invalidDelayCount(delays.count)
        }
        guard delays.allSatisfy({ $0 >= 0 && $0.isFinite }) else {
            throw PixelGridAnimationError.invalidDelay
        }
        guard duration > 0 && duration.isFinite else {
            throw PixelGridAnimationError.invalidDuration
        }
        if let colors, colors.count != PixelGridFrame.cellCount {
            throw PixelGridAnimationError.invalidColorCount(colors.count)
        }

        self.name = name
        self.delays = delays
        self.duration = duration
        self.colors = colors
        self.color = color
    }

    /// 返回使用统一颜色的新配置；多色预设会被统一颜色覆盖。
    public func withColor(_ color: PixelGridColor) -> Self {
        Self(
            uncheckedName: name,
            delays: delays,
            duration: duration,
            colors: nil,
            color: color
        )
    }

    init(
        uncheckedName name: String,
        delaysInMilliseconds delays: [Int],
        durationInMilliseconds duration: Int,
        colors: [PixelGridColor]? = nil
    ) {
        self.name = name
        self.delays = delays.map { TimeInterval($0) / 1_000 }
        self.duration = TimeInterval(duration) / 1_000
        self.colors = colors
        self.color = nil
    }

    private init(
        uncheckedName name: String,
        delays: [TimeInterval],
        duration: TimeInterval,
        colors: [PixelGridColor]?,
        color: PixelGridColor?
    ) {
        self.name = name
        self.delays = delays
        self.duration = duration
        self.colors = colors
        self.color = color
    }
}

/// 创建 ``PixelGridAnimation`` 时可能出现的配置错误。
public enum PixelGridAnimationError: Error, Equatable, Sendable {
    /// 延迟数量不是九项。
    case invalidDelayCount(Int)

    /// 延迟包含负数或非有限值。
    case invalidDelay

    /// 保持时长不是正有限值。
    case invalidDuration

    /// 逐格颜色数量不是九项。
    case invalidColorCount(Int)
}

/// 内置的 24 个动画预设。
public enum PixelGridPreset: String, CaseIterable, Identifiable, Sendable {
    /// 从左向右传播的波浪。
    case waveLeftToRight = "wave-lr"
    /// 从右向左传播的波浪。
    case waveRightToLeft = "wave-rl"
    /// 从上向下传播的波浪。
    case waveTopToBottom = "wave-tb"
    /// 从下向上传播的波浪。
    case waveBottomToTop = "wave-bt"
    /// 顺时针螺旋。
    case spiralClockwise = "spiral-cw"
    /// 四角优先点亮。
    case cornersFirst = "corners-first"
    /// 从中心向外扩散。
    case centerOut = "center-out"
    /// 从左上角沿对角线传播。
    case diagonalTopLeft = "diagonal-tl"
    /// 蛇形逐格传播。
    case snake
    /// 十字形同步传播。
    case cross
    /// 棋盘格交替点亮。
    case checkerboard
    /// 雨滴式错落传播。
    case rain
    /// 风车式旋转传播。
    case pinwheel
    /// 环绕中心运行。
    case orbit
    /// 从外侧向中心汇聚。
    case converge
    /// 之字形传播。
    case zigzag
    /// 极光配色的对角波浪。
    case aurora
    /// 余烬配色的螺旋。
    case ember
    /// 光谱配色的逐格传播。
    case prism
    /// 霓虹配色的十字。
    case neonCross = "neon-cross"
    /// 潮汐配色的纵向波浪。
    case tide
    /// 日落配色的反向纵向波浪。
    case sunset
    /// 荧光绿色的四角波浪。
    case toxic
    /// 冰霜配色的中心扩散。
    case frost

    public var id: String { rawValue }

    /// 通过持久化名称查找预设。
    public static func named(_ name: String) -> Self? {
        Self(rawValue: name)
    }

    /// 预设对应的完整连续延迟动画配置。
    public var animation: PixelGridAnimation {
        switch self {
        case .waveLeftToRight:
            preset([0, 120, 240, 0, 120, 240, 0, 120, 240], 200)
        case .waveRightToLeft:
            preset([240, 120, 0, 240, 120, 0, 240, 120, 0], 200)
        case .waveTopToBottom:
            preset([0, 0, 0, 120, 120, 120, 240, 240, 240], 200)
        case .waveBottomToTop:
            preset([240, 240, 240, 120, 120, 120, 0, 0, 0], 200)
        case .spiralClockwise:
            preset([0, 80, 160, 560, 640, 240, 480, 400, 320], 180)
        case .cornersFirst:
            preset([0, 200, 0, 200, 400, 200, 0, 200, 0], 200)
        case .centerOut:
            preset([240, 120, 240, 120, 0, 120, 240, 120, 240], 200)
        case .diagonalTopLeft:
            preset([0, 100, 200, 100, 200, 300, 200, 300, 400], 180)
        case .snake:
            preset([0, 80, 160, 400, 320, 240, 480, 560, 640], 160)
        case .cross:
            preset([300, 0, 300, 0, 0, 0, 300, 0, 300], 250)
        case .checkerboard:
            preset([0, 250, 0, 250, 0, 250, 0, 250, 0], 220)
        case .rain:
            preset([0, 180, 60, 120, 300, 240, 360, 80, 420], 170)
        case .pinwheel:
            preset([0, 160, 480, 320, 640, 160, 480, 320, 0], 150)
        case .orbit:
            preset([0, 80, 160, 480, 640, 240, 400, 320, 560], 120)
        case .converge:
            preset([0, 160, 80, 240, 320, 240, 80, 160, 0], 260)
        case .zigzag:
            preset([0, 160, 320, 400, 240, 80, 480, 560, 640], 140)
        case .aurora:
            preset(
                [0, 100, 200, 100, 200, 300, 200, 300, 400],
                220,
                [.cyan, .cyan, .teal, .teal, .blue, .blue, .purple, .purple, .magenta]
            )
        case .ember:
            preset(
                [0, 80, 160, 560, 640, 240, 480, 400, 320],
                180,
                [.yellow, .orange, .orange, .orange, .red, .red, .red, .magenta, .magenta]
            )
        case .prism:
            preset(
                [0, 80, 160, 240, 320, 400, 480, 560, 640],
                160,
                [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .magenta, .pink]
            )
        case .neonCross:
            preset(
                [300, 0, 300, 0, 0, 0, 300, 0, 300],
                250,
                [.magenta, .cyan, .magenta, .cyan, .white, .cyan, .magenta, .cyan, .magenta]
            )
        case .tide:
            preset(
                [0, 0, 0, 120, 120, 120, 240, 240, 240],
                200,
                [.teal, .cyan, .teal, .blue, .teal, .blue, .purple, .blue, .purple]
            )
        case .sunset:
            preset(
                [240, 240, 240, 120, 120, 120, 0, 0, 0],
                200,
                [.purple, .blue, .purple, .magenta, .red, .magenta, .orange, .yellow, .orange]
            )
        case .toxic:
            preset(
                [0, 200, 0, 200, 400, 200, 0, 200, 0],
                200,
                [.lime, .green, .lime, .green, .yellow, .green, .lime, .green, .lime]
            )
        case .frost:
            preset(
                [240, 120, 240, 120, 0, 120, 240, 120, 240],
                200,
                [.blue, .cyan, .blue, .cyan, .white, .cyan, .blue, .cyan, .blue]
            )
        }
    }

    private func preset(
        _ delays: [Int],
        _ duration: Int,
        _ colors: [PixelGridColor]? = nil
    ) -> PixelGridAnimation {
        PixelGridAnimation(
            uncheckedName: rawValue,
            delaysInMilliseconds: delays,
            durationInMilliseconds: duration,
            colors: colors
        )
    }
}
