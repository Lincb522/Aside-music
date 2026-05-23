import SwiftUI

// MARK: - 左右滑动切歌手势修饰器

/// 为 MiniPlayer 区域添加左右滑动切换上/下一首歌曲的手势。
/// 右滑 → 下一曲，左滑 → 上一曲。外层悬浮栏保持稳定，只让播放内容横向接力。
struct SwipeToSkipModifier: ViewModifier {
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var swipeState = FloatingBarSwipeAnimationState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let triggerDistance: CGFloat = 54
    private let predictedTriggerDistance: CGFloat = 86
    private let maxInteractiveOffset: CGFloat = 76
    private let exitDistance: CGFloat = 116

    func body(content: Content) -> some View {
        content
        .contentShape(Rectangle())
        .simultaneousGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard player.currentSong != nil, !swipeState.isSkipping else { return }

                if swipeState.gestureAxis == nil {
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal > 8 || vertical > 8 else { return }
                    swipeState.gestureAxis = horizontal > vertical * 1.18 ? .horizontal : .vertical
                }

                guard swipeState.gestureAxis == .horizontal else { return }
                let direction = SwipeSkipDirection(translation: value.translation.width)
                swipeState.activeDirection = direction
                swipeState.contentOpacity = 1
                swipeState.contentScale = 1
                swipeState.dragOffset = rubberBand(value.translation.width, limit: maxInteractiveOffset)
            }
            .onEnded { value in
                defer { swipeState.gestureAxis = nil }
                guard swipeState.gestureAxis == .horizontal, player.currentSong != nil, !swipeState.isSkipping else {
                    resetSwipe()
                    return
                }

                let raw = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let shouldCommit = abs(raw) > triggerDistance || abs(predicted) > predictedTriggerDistance

                if shouldCommit {
                    skip(direction: SwipeSkipDirection(translation: abs(predicted) > abs(raw) ? predicted : raw))
                } else {
                    resetSwipe()
                }
            }
    }

    private func skip(direction: SwipeSkipDirection) {
        swipeState.isSkipping = true
        swipeState.activeDirection = direction
        HapticManager.shared.medium()

        if reduceMotion {
            performSkip(direction)
            resetSwipe()
            swipeState.isSkipping = false
            return
        }

        let exitOffset = direction == .next ? exitDistance : -exitDistance
        let enterOffset = -exitOffset * 0.62

        withAnimation(.easeInOut(duration: 0.14)) {
            swipeState.dragOffset = exitOffset
            swipeState.contentOpacity = 0.18
            swipeState.contentScale = 0.985
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            performSkip(direction)
            swipeState.dragOffset = enterOffset
            swipeState.contentOpacity = 0.08
            swipeState.contentScale = 0.985

            withAnimation(.spring(response: 0.34, dampingFraction: 0.84, blendDuration: 0)) {
                swipeState.dragOffset = 0
                swipeState.contentOpacity = 1
                swipeState.contentScale = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                swipeState.activeDirection = nil
                swipeState.isSkipping = false
            }
        }
    }

    private func performSkip(_ direction: SwipeSkipDirection) {
        switch direction {
        case .next:
            player.next()
        case .previous:
            player.previous()
        }
    }

    private func resetSwipe() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0)) {
            swipeState.dragOffset = 0
            swipeState.contentOpacity = 1
            swipeState.contentScale = 1
        }
        swipeState.activeDirection = nil
    }

    private func rubberBand(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        let sign: CGFloat = value >= 0 ? 1 : -1
        let distance = abs(value)
        guard distance > limit else { return value }
        return sign * (limit + sqrt(distance - limit) * 3.8)
    }
}

private struct SwipeSkipTextMotionModifier: ViewModifier {
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var swipeState = FloatingBarSwipeAnimationState.shared

    private var swipeProgress: CGFloat {
        min(abs(swipeState.dragOffset) / 54, 1)
    }

    func body(content: Content) -> some View {
        content
            .id(player.currentSong.map { "\($0.id)" } ?? "empty")
            .offset(x: swipeState.dragOffset)
            .scaleEffect(swipeState.contentScale - (swipeProgress * 0.006), anchor: .leading)
            .opacity(swipeState.contentOpacity)
            .clipped()
    }
}

private final class FloatingBarSwipeAnimationState: ObservableObject {
    nonisolated(unsafe) static let shared = FloatingBarSwipeAnimationState()

    @Published var gestureAxis: SwipeGestureAxis?
    @Published var dragOffset: CGFloat = 0
    @Published var contentOpacity: Double = 1
    @Published var contentScale: CGFloat = 1
    @Published var isSkipping = false
    @Published var activeDirection: SwipeSkipDirection?

    private init() {}
}

private enum SwipeGestureAxis {
    case horizontal
    case vertical
}

private enum SwipeSkipDirection {
    case next
    case previous

    init(translation: CGFloat) {
        self = translation >= 0 ? .next : .previous
    }
}

// MARK: - View Extension

extension View {
    /// 添加左右滑动切歌手势（左滑上一曲，右滑下一曲）
    func swipeToSkip() -> some View {
        modifier(SwipeToSkipModifier())
    }

    /// 只让歌曲信息文本参与左右切歌的接力动画，封面和控制按钮保持稳定。
    func swipeSkipTextMotion() -> some View {
        modifier(SwipeSkipTextMotionModifier())
    }
}
