import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    @ViewBuilder
    var neumorphicProfileDashboard: some View {
        neumorphicProfileHeaderBar

        neumorphicProfileHeroPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        neumorphicProfileMetricDeck
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .neumorphic)

        neumorphicProfileShortcutGrid
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        neumorphicLogoutButton
    }

    var neumorphicProfileHeaderBar: some View {
        HStack(spacing: 14) {
            NeumorphicIconBadge(icon: .profileFilled, tint: NeumorphicStyle.accent, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text("PROFILE")
                    .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.inkMuted)

                Text(String(localized: "tab_profile"))
                    .font(NeumorphicStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
            }

            Spacer(minLength: 8)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(icon: .settings, size: 17, color: NeumorphicStyle.accent, lineWidth: 1.55)
                    .frame(width: 44, height: 44)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true, lightweight: true))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
        .monoPageHeaderCollapse()
    }

}
