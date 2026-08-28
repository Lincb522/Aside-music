import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    @ViewBuilder
    var signalProfileDashboard: some View {
        signalProfileHeaderBar

        signalProfileHeroPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        statsBar
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .signal)

        menuList
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        logoutButton
    }

    var signalProfileHeaderBar: some View {
        HStack(spacing: 13) {
            SignalIconBadge(icon: .profileFilled, tint: SignalStyle.accent, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("PROFILE")
                    .font(SignalStyle.labelFont(11, weight: .bold))
                    .foregroundStyle(SignalStyle.accent)

                Text(String(localized: "tab_profile"))
                    .font(SignalStyle.titleFont(24, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
            }

            Spacer(minLength: 8)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(icon: .settings, size: 17, color: SignalStyle.accent, lineWidth: 1.55)
                    .frame(width: 42, height: 42)
                    .background(SignalSurfaceBackground(cornerRadius: 11, elevated: true, fill: SignalStyle.control))
                    .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
        .monoPageHeaderCollapse()
    }

    @ViewBuilder
    var sequoiaProfileDashboard: some View {
        sequoiaProfileHeaderBar

        sequoiaProfileHeroPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        statsBar
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .sequoia)

        menuList
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        logoutButton
    }

    var sequoiaProfileHeaderBar: some View {
        HStack(spacing: 13) {
            VStack(spacing: 4) {
                Capsule()
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 4, height: 25)
                Capsule()
                    .fill(SequoiaStyle.separator)
                    .frame(width: 4, height: 10)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("PROFILE")
                    .font(SequoiaStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.inkMuted)
                    .tracking(0.9)

                Text(String(localized: "tab_profile"))
                    .font(SequoiaStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
            }

            Spacer(minLength: 8)

            SequoiaMeter(tint: SequoiaStyle.accent, count: 8)
                .padding(.horizontal, 8)
                .padding(.vertical, 9)
                .background(SequoiaSurfaceBackground(cornerRadius: 15, elevated: false, role: .list))

            NavigationLink(value: ProfileNavigationDestination.settings) {
                SequoiaControlButton(icon: .settings, tint: SequoiaStyle.accent, size: 40)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .padding(14)
        .background(SequoiaChromeBar(cornerRadius: 23))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
        .monoPageHeaderCollapse()
    }

}
