import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    @ViewBuilder
    var capsuleProfileDashboard: some View {
        capsuleProfileHeader

        capsuleProfileIdentityPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        capsuleProfileMetricDeck
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .capsule)

        capsuleProfilePortalGrid
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        capsuleLogoutButton
    }

    var capsuleProfileHeader: some View {
        CapsulePageHeader(
            eyebrow: "PROFILE",
            title: String(localized: "tab_profile")
        ) {
            NavigationLink(value: ProfileNavigationDestination.settings) {
                CapsuleIconBadge(icon: .settings, tint: CapsuleStyle.accent, size: 46)
            }
            .buttonStyle(.plain)
        }
    }

    var capsuleProfileIdentityPanel: some View {
        let profile = displayedProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                capsuleAvatar(profile: profile, size: 82)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                            .font(CapsuleStyle.titleFont(23, weight: .bold))
                            .foregroundStyle(CapsuleStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        if loginIdentity.activeSource == .netease, let userLevel {
                            CapsulePillLabel(
                                title: "Lv.\(userLevel)",
                                tint: CapsuleStyle.violet,
                                selected: true
                            )
                        }
                    }

                    Text(signature.isEmpty ? String(localized: "profile_login_hint") : signature)
                        .font(CapsuleStyle.bodyFont(12, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        CapsulePillLabel(
                            title: String(format: String(localized: "profile_recent_count"), playerManager.history.count),
                            icon: .clock,
                            tint: CapsuleStyle.cyan
                        )
                        CapsulePillLabel(
                            title: identityPrimaryMetricValue,
                            icon: identityPrimaryMetricIcon,
                            tint: CapsuleStyle.mint
                        )
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Capsule()
                    .fill(CapsuleStyle.accent)
                    .frame(width: 58, height: 8)
                Capsule()
                    .fill(CapsuleStyle.cyan.opacity(0.75))
                    .frame(width: 34, height: 8)
                Capsule()
                    .fill(CapsuleStyle.violet.opacity(0.75))
                    .frame(width: 18, height: 8)
                Spacer(minLength: 0)
                CapsulePillLabel(
                    title: "CAPSULE",
                    tint: CapsuleStyle.accent
                )
            }
        }
        .padding(17)
        .background(CapsuleSurfaceBackground(cornerRadius: 32, elevated: true, tint: CapsuleStyle.surface.opacity(0.94)))
    }

    @ViewBuilder
    func capsuleAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .fill(CapsuleStyle.surfaceTint)
                .frame(width: size, height: size)
                .background(
                    CapsuleSurfaceBackground(
                        cornerRadius: size * 0.42,
                        elevated: true,
                        tint: CapsuleStyle.surfaceRaised.opacity(0.98)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: size * 0.42, style: .continuous))

            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: size - 12, height: size - 12) {
                    RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                        .fill(CapsuleStyle.surfaceTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size - 12, height: size - 12)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            } else {
                MonoIcon(
                    icon: .profileFilled,
                    size: size * 0.36,
                    color: CapsuleStyle.accent,
                    lineWidth: 1.65
                )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .stroke(CapsuleStyle.hairline.opacity(0.85), lineWidth: 1)
        )
    }

    var capsuleProfileMetricDeck: some View {
        HStack(spacing: 10) {
            CapsuleProfileMetricTile(
                value: identityPrimaryMetricValue,
                label: identityPrimaryMetricLabel,
                tint: CapsuleStyle.accent,
                icon: identityPrimaryMetricIcon
            )
            CapsuleProfileMetricTile(
                value: "\(localPlaylistCount)",
                label: String(localized: "profile_local_playlists"),
                tint: CapsuleStyle.mint,
                icon: .musicNoteList
            )
            CapsuleProfileMetricTile(
                value: "\(downloadedSongCount)",
                label: String(localized: "profile_downloads"),
                tint: CapsuleStyle.amber,
                icon: .download
            )
        }
    }

    var capsuleProfilePortalGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 11),
                GridItem(.flexible(), spacing: 11),
            ],
            spacing: 11
        ) {
            Button { navigationPath.append(ProfileNavigationDestination.platformAccounts) } label: {
                CapsuleProfilePortalTile(
                    icon: .musicNote,
                    title: "平台账号管理",
                    value: "4 个平台",
                    tint: CapsuleStyle.accent
                )
            }
            .buttonStyle(CapsulePressStyle())

            // 保留下载入口结构，由功能开关统一控制。
            if AppConfig.Features.downloadEnabled {
                NavigationLink(destination: DownloadManageView()) {
                    CapsuleProfilePortalTile(
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: "\(downloadedSongCount)",
                        tint: CapsuleStyle.amber
                    )
                }
                .buttonStyle(CapsulePressStyle())
            }

            NavigationLink(destination: ListeningStatsView()) {
                CapsuleProfilePortalTile(
                    icon: .sparkle,
                    title: String(localized: "cloud_sync_listening_stats"),
                    value: "STATS",
                    tint: CapsuleStyle.violet
                )
            }
            .buttonStyle(CapsulePressStyle())

            NavigationLink(destination: StorageManageView()) {
                CapsuleProfilePortalTile(
                    icon: .storage,
                    title: String(localized: "profile_cache_manage"),
                    value: "CACHE",
                    tint: CapsuleStyle.cyan
                )
            }
            .buttonStyle(CapsulePressStyle())

            if loginIdentity.activeSource == .netease {
                NavigationLink(destination: CloudDiskView()) {
                    CapsuleProfilePortalTile(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: ""),
                        value: "CLOUD",
                        tint: CapsuleStyle.violet
                    )
                }
                .buttonStyle(CapsulePressStyle())
            }
        }
    }

    var capsuleLogoutButton: some View {
        logoutButton
            .padding(.top, 0)
    }

}
