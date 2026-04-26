import SwiftUI

/// Bottom spacer for pages that scroll behind the custom floating bar.
/// It stays compact when the mini player is collapsed, and grows just enough
/// to keep the final action row tappable when a song is playing.
struct FloatingBarBottomSpacer: View {
    var extra: CGFloat = 0

    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var player = PlayerManager.shared

    var body: some View {
        Color.clear
            .frame(height: max(0, baseHeight + extra))
            .accessibilityHidden(true)
    }

    private var baseHeight: CGFloat {
        guard !player.isTabBarHidden else { return 24 }

        if settings.useSystemTabBar {
            return player.currentSong == nil ? 20 : 72
        }

        switch settings.floatingBarStyle {
        case .unified:
            if player.currentSong == nil {
                return ThemedPageStyle.isActive ? 76 : 68
            }
            return ThemedPageStyle.isActive ? 124 : 114

        case .classic:
            return player.currentSong == nil ? 56 : 104

        case .minimal:
            return player.currentSong == nil ? 72 : 82

        case .floatingBall:
            return 88
        }
    }
}
