import SwiftUI

/// 现役 Aria 沉浸模式的全局呈现入口。
@MainActor
final class ImmersiveModeController: ObservableObject {
    static let shared = ImmersiveModeController()

    @Published var isPresented = false

    private init() {}

    func present() {
        OrientationManager.shared.enterLandscape()
        isPresented = true
    }
}
