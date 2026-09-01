import SwiftUI

/// 全屏横向返回手势，适用于 fullScreenCover 一类没有原生返回手势的页面。
/// 手势与子控件同时识别，并通过方向、距离和预测速度三重门槛过滤纵向滚动。
private struct MonoEdgeSwipeDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    let isEnabled: Bool
    let edgeWidth: CGFloat
    let dismissThreshold: CGFloat
    let minimumDistance: CGFloat

    @State private var isSwiping = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: minimumDistance, coordinateSpace: .global)
                    .onChanged { value in
                        guard shouldTrack(value) else { return }
                        if !isSwiping {
                            isSwiping = true
                            EdgeSwipeGuard.shared.beginSwipe()
                        }
                    }
                    .onEnded { value in
                        defer { finishTracking() }
                        guard shouldTrack(value) else { return }

                        let projected = directional(value.predictedEndTranslation.width)
                        let translated = directional(value.translation.width)
                        if max(projected, translated) >= dismissThreshold {
                            dismiss()
                        }
                    },
                including: isEnabled ? .all : .subviews
            )
    }

    private func shouldTrack(_ value: DragGesture.Value) -> Bool {
        guard isEnabled else { return false }
        let viewportWidth = DeviceLayout.viewportWidth
        let startsAtBackEdge = layoutDirection == .rightToLeft
            ? value.startLocation.x >= viewportWidth - edgeWidth
            : value.startLocation.x <= edgeWidth
        guard startsAtBackEdge else { return false }
        let horizontal = directional(value.translation.width)
        guard horizontal > 0 else { return false }
        return abs(value.translation.width) > abs(value.translation.height) * 1.55
    }

    private func directional(_ value: CGFloat) -> CGFloat {
        layoutDirection == .rightToLeft ? -value : value
    }

    private func finishTracking() {
        guard isSwiping else { return }
        isSwiping = false
        EdgeSwipeGuard.shared.endSwipe()
    }
}

extension View {
    func monoEdgeSwipeToDismiss(
        isEnabled: Bool = true,
        edgeWidth: CGFloat = 28,
        dismissThreshold: CGFloat = 112,
        minimumDistance: CGFloat = 12
    ) -> some View {
        modifier(MonoEdgeSwipeDismissModifier(
            isEnabled: isEnabled,
            edgeWidth: edgeWidth,
            dismissThreshold: dismissThreshold,
            minimumDistance: minimumDistance
        ))
    }
}
