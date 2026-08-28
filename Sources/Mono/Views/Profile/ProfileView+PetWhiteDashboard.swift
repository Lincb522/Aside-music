import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    @ViewBuilder
    var petWhiteProfileDashboard: some View {
        petWhiteProfileIdentityDeck
            .padding(.horizontal, 14)
            .padding(.top, 8)

        ProfileRecentPlaysHost(variant: .standard)

        petWhiteProfileQuickActions
            .padding(.horizontal, 14)

        petWhiteProfileAccountPanel
            .padding(.horizontal, 14)

        petWhiteLogoutButton
    }

    var petWhiteProfileIdentityDeck: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        PetWhitePill(text: "PAWCELAIN", tint: PetWhiteStyle.mint)
                        if let userLevel {
                            PetWhitePill(text: "LV.\(userLevel)", tint: PetWhiteStyle.butter)
                        }
                    }

                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(PetWhiteStyle.titleFont(30, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(signature.isEmpty ? String(localized: "profile_login_hint") : signature)
                        .font(PetWhiteStyle.bodyFont(13, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    PetWhiteIconBadge(icon: .settings, tint: PetWhiteStyle.sky, size: 48)
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
            }

            HStack(alignment: .center, spacing: 14) {
                petWhiteProfileAvatar(profile: profile, size: 96)

                VStack(spacing: 9) {
                    HStack(spacing: 9) {
                        PetWhiteProfileMetricPill(
                            value: formatNumber(listenSongs ?? 0),
                            label: String(localized: "profile_total_songs"),
                            icon: .headphones,
                            tint: PetWhiteStyle.dogOrange
                        )

                        PetWhiteProfileMetricPill(
                            value: "\(localPlaylistCount)",
                            label: String(localized: "profile_local_playlists"),
                            icon: .musicNoteList,
                            tint: PetWhiteStyle.mint
                        )
                    }

                    HStack(spacing: 9) {
                        PetWhiteProfileMetricPill(
                            value: "\(downloadedSongCount)",
                            label: String(localized: "profile_downloads"),
                            icon: .download,
                            tint: PetWhiteStyle.sky
                        )

                        PetWhiteProfileMetricPill(
                            value: "\(playerManager.history.count)",
                            label: String(localized: "profile_recently_played"),
                            icon: .history,
                            tint: PetWhiteStyle.butter
                        )
                    }
                }
            }

        }
        .padding(18)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: PetWhiteStyle.cardRadius,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.dogOrange
            )
        )
    }

    @ViewBuilder
    func petWhiteProfileAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(PetWhiteStyle.surfacePressed)
                .frame(width: size, height: size)

            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: size - 12, height: size - 12) {
                    PetWhiteMascotMark(kind: .pair, size: size - 28)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size - 12, height: size - 12)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                PetWhitePetPetIcon(size: size * 0.82)
            }
        }
        .petWhiteClayShadow()
    }

    var petWhiteProfileQuickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: String(localized: "快捷操作"),
                detail: String(localized: "常用入口"),
                icon: .sparkle,
                tint: PetWhiteStyle.butter
            )

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    NavigationLink(destination: DownloadManageView()) {
                        PetWhiteProfileActionTile(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            value: String(format: String(localized: "profile_recent_count"), downloadedSongCount),
                            tint: PetWhiteStyle.sky
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                }

                NavigationLink(destination: ListeningStatsView()) {
                    PetWhiteProfileActionTile(
                        icon: .headphones,
                        title: String(localized: "cloud_sync_listening_stats"),
                        value: formatNumber(listenSongs ?? 0),
                        tint: PetWhiteStyle.dogOrange
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))

                NavigationLink(destination: StorageManageView()) {
                    PetWhiteProfileActionTile(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: String(localized: "缓存"),
                        tint: PetWhiteStyle.mint
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))

                NavigationLink(destination: CloudDiskView()) {
                    PetWhiteProfileActionTile(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: ""),
                        value: "Cloud",
                        tint: PetWhiteStyle.lilac
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
            }
        }
    }

    var petWhiteProfileAccountPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: String(localized: "账号与偏好"),
                detail: String(localized: "登录、同步和外观"),
                icon: .profileFilled,
                tint: PetWhiteStyle.mint
            )

            VStack(spacing: 10) {
                Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                    ProfileMenuRow(
                        icon: .musicNote,
                    title: "平台账号管理",
                        trailingText: "4 个平台"
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    ProfileMenuRow(
                        icon: .settings,
                        title: NSLocalizedString("profile_settings", comment: "")
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
            }
        }
    }

    var petWhiteLogoutButton: some View {
        Button(action: {
            AlertManager.shared.show(
                title: NSLocalizedString("alert_logout_title", comment: ""),
                message: NSLocalizedString("alert_logout_message", comment: ""),
                primaryButtonTitle: NSLocalizedString("alert_logout_confirm", comment: ""),
                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
            ) {
                performLogout()
            }
        }) {
            HStack(spacing: 8) {
                PetWhitePackIcon(icon: .close, size: 15, visualScale: 1.05)
                Text(LocalizedStringKey("action_logout"))
                    .font(PetWhiteStyle.labelFont(13, weight: .black))
            }
            .foregroundStyle(PetWhiteStyle.inkSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                PetWhiteSurfaceBackground(
                    cornerRadius: 18,
                    elevated: false,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: PetWhiteStyle.blush
                )
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }

}
