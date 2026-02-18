import SwiftUI

// MARK: - 多手势组合修饰器（单击 + 双击 + 长按）

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
        self
            // 双击优先级最高
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
            // 单击（SwiftUI 会自动等待双击超时后才触发）
            .onTapGesture(count: 1) {
                onTap()
            }
            // 长按
            .onLongPressGesture(minimumDuration: 0.5) {
                onLongPress()
            }
    }
}
