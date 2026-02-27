import SwiftUI

// MARK: - 多手势组合修饰器（单击 + 双击 + 长按）

/// 自定义手势处理器，减少单击延迟
private struct MultiGestureModifier: ViewModifier {
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var tapCount = 0
    @State private var tapWorkItem: DispatchWorkItem?
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.5) {
                // 长按触发时取消单击等待
                tapWorkItem?.cancel()
                tapCount = 0
                HapticManager.shared.heavy()
                onLongPress()
            }
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        tapCount += 1
                        tapWorkItem?.cancel()
                        
                        if tapCount >= 2 {
                            // 双击 — 立即触发
                            tapCount = 0
                            HapticManager.shared.medium()
                            onDoubleTap()
                        } else {
                            // 单击 — 等待 200ms 确认不是双击（比系统默认 300ms 更短）
                            let item = DispatchWorkItem {
                                tapCount = 0
                                HapticManager.shared.light()
                                onTap()
                            }
                            tapWorkItem = item
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
                        }
                    }
            )
    }
}

extension View {
    /// 同时支持单击、双击、长按的手势组合
    /// - Parameters:
    ///   - onTap: 单击回调
    ///   - onDoubleTap: 双击回调
    ///   - onLongPress: 长按回调
    func asideMultiGesture(
        onTap: @escaping () -> Void = {},
        onDoubleTap: @escaping () -> Void = {},
        onLongPress: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(MultiGestureModifier(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress
        ))
    }
}
