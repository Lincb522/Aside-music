import SwiftUI

private struct PlayerMoreMenuAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

extension View {
    func playerMoreMenuAnchor() -> some View {
        anchorPreference(key: PlayerMoreMenuAnchorKey.self, value: .bounds) { $0 }
    }

    // Resolve both views in the overlay's coordinates, including safe areas and
    // theme-specific insets, without writing geometry back into view state.
    func playerMoreMenuOverlay<Menu: View>(
        @ViewBuilder menu: @escaping (CGRect) -> Menu
    ) -> some View {
        overlayPreferenceValue(PlayerMoreMenuAnchorKey.self) { anchor in
            if let anchor {
                GeometryReader { proxy in
                    menu(proxy[anchor])
                }
            }
        }
    }
}
