import SwiftUI

/// The glass surface has no playback-clock or lyric dependency.
struct FluidFloatingBarShell: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let shape = Capsule(style: .continuous)

        if settings.defaultThemeUsesLiquidGlassTabBar {
            shape
                .fill(Color.monoFloatingBarFill)
                .monoGlassCapsule()
        } else {
            shape
                .fill(Color.monoStructuralBackground)
        }
    }
}
