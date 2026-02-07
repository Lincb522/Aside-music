import SwiftUI

/// 浅色模式下反色修饰符
/// 网易云图标是白色的，浅色模式下需要反色为黑色才能看见
struct LightModeInvertModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .light {
            content.colorInvert()
        } else {
            content
        }
    }
}
