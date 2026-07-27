import SwiftUI

/// 左侧边缘右滑关闭，适用于 fullScreenCover 一类没有原生返回手势的页面。
private struct MonoEdgeSwipeDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let isEnabled: Bool
    let edgeWidth: CGFloat
    let dismissThreshold: CGFloat
    let minimumDistance: CGFloat

    @State private var isSwiping = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                Color.clear
                    .frame(width: edgeWidth)
                    .contentShape(Rectangle())
                    .allowsHitTesting(isEnabled)
                    .gesture(
                        DragGesture(minimumDistance: minimumDistance)
                            .onChanged { value in
                                guard shouldTrack(value) else { return }
                                if !isSwiping {
                                    isSwiping = true
                                    EdgeSwipeGuard.shared.beginSwipe()
                                }
                            }
                            .onEnded { value in
                                defer {
                                    if isSwiping {
                                        isSwiping = false
                                        EdgeSwipeGuard.shared.endSwipe()
                                    }
                                }

                                guard shouldTrack(value) else { return }

                                let projectedTranslation = max(
                                    value.translation.width,
                                    value.predictedEndTranslation.width
                                )
                                if projectedTranslation >= dismissThreshold {
                                    dismiss()
                                }
                            }
                    )
            }
    }

    private func shouldTrack(_ value: DragGesture.Value) -> Bool {
        guard isEnabled else { return false }
        guard value.translation.width > 0 else { return false }
        return abs(value.translation.width) > abs(value.translation.height)
    }
}

extension View {
    func monoEdgeSwipeToDismiss(
        isEnabled: Bool = true,
        edgeWidth: CGFloat = 28,
        dismissThreshold: CGFloat = 96,
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
