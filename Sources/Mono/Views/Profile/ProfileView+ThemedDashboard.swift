import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    // MARK: - Hero Card

    var mangaProfileHeader: some View {
        MangaPageHeader(
            eyebrow: "PROFILE",
            title: String(localized: "tab_profile"),
            subtitle: ""
        ) {
            NavigationLink(value: ProfileNavigationDestination.settings) {
                MangaIconBadge(icon: .settings, size: 48, tint: MangaStyle.decoBlue)
            }
            .buttonStyle(.plain)
        }
    }

    var mujiProfileHeader: some View {
        MujiPageHeader(
            eyebrow: "listening notebook",
            title: String(localized: "tab_profile"),
            subtitle: ""
        ) {
            NavigationLink(value: ProfileNavigationDestination.settings) {
                MujiIconBadge(icon: .settings, tint: MujiStyle.inkSoft, size: 44)
            }
            .buttonStyle(.plain)
        }
    }

    var neumorphicProfileHeader: some View {
        NeumorphicPageHeader(
            eyebrow: "profile",
            title: String(localized: "tab_profile"),
            subtitle: ""
        ) {
            NavigationLink(value: ProfileNavigationDestination.settings) {
                NeumorphicIconBadge(icon: .settings, tint: NeumorphicStyle.accent, size: 48)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    var mangaProfileDashboard: some View {
        mangaProfileHeroPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, 8)

        statsBar
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .manga)

        mangaProfileActionGrid
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        logoutButton
    }

}
