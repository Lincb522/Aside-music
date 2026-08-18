import SwiftUI

/// 弹窗高度约束：固定高度或屏幕高度百分比上限。
enum MonoSheetHeightConstraint: Equatable {
    case fixed(CGFloat)
    case maximumRatio(CGFloat)
}

/// 全局弹窗的尺寸/交互预设，从 compact 到 detail 逐级增大；`custom` 可完全自定义各项参数。
enum MonoSheetPreset: Equatable {
    case compact
    case standard
    case themePicker
    case large
    case detail
    case custom(
        height: MonoSheetHeightConstraint,
        maxContentWidth: CGFloat,
        horizontalPadding: CGFloat = 12,
        bottomPadding: CGFloat = 10,
        cornerRadius: CGFloat = 30,
        showsHandle: Bool = true,
        minTopSpacing: CGFloat = 24,
        allowsBackgroundDismiss: Bool = true,
        allowsDragToDismiss: Bool = true,
        backdropOpacity: Double = 0.16
    )

    var heightConstraint: MonoSheetHeightConstraint {
        switch self {
        case .compact:
            return .maximumRatio(0.52)
        case .standard:
            return .maximumRatio(0.72)
        case .themePicker:
            return .maximumRatio(0.76)
        case .large:
            return .maximumRatio(0.84)
        case .detail:
            return .maximumRatio(0.92)
        case .custom(let height, _, _, _, _, _, _, _, _, _):
            return height
        }
    }

    var maxContentWidth: CGFloat {
        switch self {
        case .compact:
            return 560
        case .standard:
            return 620
        case .themePicker:
            return 640
        case .large:
            return 720
        case .detail:
            return 920
        case .custom(_, let maxContentWidth, _, _, _, _, _, _, _, _):
            return maxContentWidth
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact, .standard, .themePicker, .large, .detail:
            return 12
        case .custom(_, _, let horizontalPadding, _, _, _, _, _, _, _):
            return horizontalPadding
        }
    }

    var bottomPadding: CGFloat {
        switch self {
        case .compact, .standard, .themePicker, .large, .detail:
            return 10
        case .custom(_, _, _, let bottomPadding, _, _, _, _, _, _):
            return bottomPadding
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact, .standard, .themePicker, .large, .detail:
            return 30
        case .custom(_, _, _, _, let cornerRadius, _, _, _, _, _):
            return cornerRadius
        }
    }

    /// 按当前激活的主题对圆角做钳制，使弹窗与各主题的卡片圆角风格一致。
    var monoResolvedCornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive {
            return min(cornerRadius, MinimalWhiteStyle.chromeRadius)
        }
        if MangaStyle.isActive {
            return min(cornerRadius, 14)
        }
        if PetWhiteStyle.isActive {
            return min(max(cornerRadius, 26), 34)
        }
        if MujiStyle.isActive {
            return min(cornerRadius, 20)
        }
        if NeumorphicStyle.isActive {
            return min(cornerRadius, 28)
        }
        if CapsuleStyle.isActive {
            return min(max(cornerRadius, 24), 32)
        }
        if ClarityStyle.isActive {
            return min(max(cornerRadius, 30), 36)
        }
        if SequoiaStyle.isActive {
            return min(max(cornerRadius, 24), 30)
        }
        if LiquidGlassStyle.isActive {
            return min(max(cornerRadius, 26), 32)
        }
        if SignalStyle.isActive {
            return min(max(cornerRadius, 28), 32)
        }
        if BentoStyle.isActive {
            return min(max(cornerRadius, 24), 28)
        }
        return cornerRadius
    }

    var showsHandle: Bool {
        switch self {
        case .compact, .standard, .themePicker, .large, .detail:
            return true
        case .custom(_, _, _, _, _, let showsHandle, _, _, _, _):
            return showsHandle
        }
    }

    var minTopSpacing: CGFloat {
        switch self {
        case .compact:
            return 96
        case .standard:
            return 56
        case .themePicker:
            return 44
        case .large:
            return 32
        case .detail:
            return 18
        case .custom(_, _, _, _, _, _, let minTopSpacing, _, _, _):
            return minTopSpacing
        }
    }

    var allowsBackgroundDismiss: Bool {
        switch self {
        case .compact, .standard, .themePicker, .large, .detail:
            return true
        case .custom(_, _, _, _, _, _, _, let allowsBackgroundDismiss, _, _):
            return allowsBackgroundDismiss
        }
    }

    var allowsDragToDismiss: Bool {
        switch self {
        case .compact, .standard, .themePicker, .large, .detail:
            return true
        case .custom(_, _, _, _, _, _, _, _, let allowsDragToDismiss, _):
            return allowsDragToDismiss
        }
    }

    var backdropOpacity: Double {
        switch self {
        case .compact:
            return 0.12
        case .standard:
            return 0.15
        case .themePicker:
            return 0.16
        case .large:
            return 0.18
        case .detail:
            return 0.2
        case .custom(_, _, _, _, _, _, _, _, _, let backdropOpacity):
            return backdropOpacity
        }
    }
}

@available(iOS 16.0, *)
extension MonoSheetPreset {
    /// 转换为系统 sheet 的 detent（固定高度不低于 160，比例钳制到 0.25~0.98）。
    var systemDetents: Set<PresentationDetent> {
        switch heightConstraint {
        case .fixed(let value):
            return [.height(max(160, value))]
        case .maximumRatio(let value):
            let clampedValue = min(max(value, 0.25), 0.98)
            return [.fraction(clampedValue)]
        }
    }
}
