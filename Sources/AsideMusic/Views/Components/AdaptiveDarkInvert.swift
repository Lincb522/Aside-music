import SwiftUI

/// 深色模式自动反色修饰符
/// 用于本地黑色图标在深色模式下自动反色为白色
struct AdaptiveDarkInvertModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.colorInvert()
        } else {
            content
        }
    }
}

extension View {
    func adaptiveDarkInvert() -> some View {
        modifier(AdaptiveDarkInvertModifier())
    }
}
