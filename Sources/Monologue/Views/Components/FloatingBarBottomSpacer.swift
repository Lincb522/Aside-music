import Combine
import SwiftUI

/// Bottom spacer for pages that scroll behind the custom floating bar.
/// It stays compact when the mini player is collapsed, and grows just enough
/// to keep the final action row tappable when a song is playing.
struct FloatingBarBottomSpacer: View {
    var extra: CGFloat = 0

    @AppStorage("useSystemTabBar") private var useSystemTabBar = false
    @AppStorage("floatingBarStyle") private var floatingBarStyleRaw = FloatingBarStyle.unified.rawValue
    @AppStorage("globalThemeId") private var globalThemeIdRaw = GlobalThemeId.appDefault.rawValue
    @State private var isTabBarHidden = PlayerManager.shared.isTabBarHidden
    @State private var hasCurrentSong = PlayerManager.shared.currentSong != nil

    var body: some View {
        Color.clear
            .frame(height: max(0, baseHeight + extra))
            .accessibilityHidden(true)
            .onReceive(PlayerManager.shared.$isTabBarHidden.removeDuplicates()) { hidden in
                isTabBarHidden = hidden
            }
            .onReceive(PlayerManager.shared.$currentSong.map { $0 != nil }.removeDuplicates()) { hasCurrentSong in
                self.hasCurrentSong = hasCurrentSong
            }
    }

    private var baseHeight: CGFloat {
        guard !isTabBarHidden else { return 24 }

        if useSystemTabBar {
            return hasCurrentSong ? 72 : 20
        }

        switch floatingBarStyle {
        case .unified:
            if globalThemeIdRaw == GlobalThemeId.neumorphic.rawValue {
                return hasCurrentSong ? 176 : 108
            }
            if !hasCurrentSong {
                return isThemedPageActive ? 88 : 80
            }
            return isThemedPageActive ? 152 : 142

        case .classic:
            return hasCurrentSong ? 130 : 70

        case .minimal:
            return hasCurrentSong ? 112 : 88

        case .floatingBall:
            return 88
        }
    }

    private var floatingBarStyle: FloatingBarStyle {
        FloatingBarStyle(rawValue: floatingBarStyleRaw) ?? .unified
    }

    private var isThemedPageActive: Bool {
        globalThemeIdRaw != GlobalThemeId.default.rawValue
    }
}
