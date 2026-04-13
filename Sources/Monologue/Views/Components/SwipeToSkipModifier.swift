import SwiftUI

// MARK: - 左右滑动切歌手势修饰器

/// 为 MiniPlayer 区域添加左右滑动切换上/下一首歌曲的手势
/// 右滑 → 下一首，左滑 → 上一首
/// 无动画，仅触觉反馈
struct SwipeToSkipModifier: ViewModifier {
    @ObservedObject private var player = PlayerManager.shared
    @State private var isSkipping = false
    
    private let triggerDistance: CGFloat = 50
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 18, coordinateSpace: .local)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.3 else { return }
                        guard player.currentSong != nil, !isSkipping else { return }
                        
                        if value.translation.width > triggerDistance {
                            skip { player.next() }
                        } else if value.translation.width < -triggerDistance {
                            skip { player.previous() }
                        }
                    }
            )
    }
    
    private func skip(_ action: () -> Void) {
        isSkipping = true
        HapticManager.shared.medium()
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSkipping = false
        }
    }
}

// MARK: - View Extension

extension View {
    /// 添加左右滑动切歌手势（右滑下一首，左滑上一首）
    func swipeToSkip() -> some View {
        modifier(SwipeToSkipModifier())
    }
}
