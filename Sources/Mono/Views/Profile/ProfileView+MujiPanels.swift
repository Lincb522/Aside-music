import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    var mujiGuestJournalPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                mujiAvatar(profile: nil, size: 72)

                VStack(alignment: .leading, spacing: 7) {
                    MujiPill(text: "GUEST", tint: MujiStyle.tea)

                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(MujiStyle.titleFont(26, weight: .regular))
                        .foregroundStyle(MujiStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(LocalizedStringKey("profile_login_hint"))
                        .font(MujiStyle.bodyFont(12.5, weight: .regular))
                        .foregroundStyle(MujiStyle.inkSoft)
                        .lineSpacing(3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                HStack(spacing: 9) {
                    MonoIcon(icon: .profileFilled, size: 15, color: MujiStyle.onTint, lineWidth: 1.45)

                    Text(LocalizedStringKey("profile_login_button"))
                        .font(MujiStyle.labelFont(15, weight: .medium))
                        .foregroundStyle(MujiStyle.onTint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(MujiStyle.clay, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        }
    }

    var mujiGuestLedger: some View {
        VStack(alignment: .leading, spacing: 14) {
            MujiSectionTitle(title: String(localized: "profile_settings"))

            VStack(spacing: 0) {
                Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                    MujiProfileLedgerRow(
                        icon: .musicNote,
                    title: "平台账号管理",
                        value: "4 个平台"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    NavigationLink(destination: DownloadManageView()) {
                        MujiProfileLedgerRow(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            value: "\(downloadedSongCount)"
                        )
                    }
                    .buttonStyle(.plain)

                    MujiProfileDivider()
                }

                NavigationLink(destination: ListeningStatsView()) {
                    MujiProfileLedgerRow(
                        icon: .sparkle,
                        title: String(localized: "cloud_sync_listening_stats"),
                        value: "STATS"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: StorageManageView()) {
                    MujiProfileLedgerRow(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    MujiProfileLedgerRow(
                        icon: .settings,
                        title: NSLocalizedString("profile_settings", comment: ""),
                        value: "SYSTEM"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: MujiStyle.cardRadius, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
            )
        }
    }

    var mujiNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 30) {
                        mujiProfileHeader

                        mujiGuestJournalPanel
                            .padding(.horizontal, 28)

                        mujiGuestLedger
                            .padding(.horizontal, 28)
                    }
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    @ViewBuilder
    var mujiProfileDashboard: some View {
        mujiProfileHeader

        mujiProfileJournalPanel
            .padding(.horizontal, 28)

        statsBar
            .padding(.horizontal, 28)
            .padding(.top, 6)

        ProfileRecentPlaysHost(variant: .standard)
            .padding(.top, 4)

        mujiProfileLedger
            .padding(.horizontal, 28)
            .padding(.top, 4)

        logoutButton
    }

    var mujiProfileJournalPanel: some View {
        let profile = displayedProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                mujiAvatar(profile: profile, size: 72)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        if loginIdentity.activeSource == .netease, let level = userLevel {
                            MujiPill(text: "Lv.\(level)", tint: MujiStyle.clay)
                        }
                        MujiPill(text: identityPrimaryMetricValue, tint: MujiStyle.tea)
                    }

                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MujiStyle.titleFont(27, weight: .regular))
                        .foregroundStyle(MujiStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }

            if !signature.isEmpty {
                // 签名作引文：左侧陶土短竖线 + 衬线弱化正文
                HStack(alignment: .top, spacing: 11) {
                    Rectangle()
                        .fill(MujiStyle.clay.opacity(0.8))
                        .frame(width: 2)
                        .padding(.vertical, 2)

                    Text(signature)
                        .font(MujiStyle.bodyFont(13, weight: .regular))
                        .foregroundStyle(MujiStyle.inkSoft)
                        .lineSpacing(4)
                        .lineLimit(2)
                }
                .padding(.top, 15)
            }
        }
    }

    var mujiProfileLedger: some View {
        VStack(alignment: .leading, spacing: 14) {
            MujiSectionTitle(title: String(localized: "profile_settings"))

            VStack(spacing: 0) {
                Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                    MujiProfileLedgerRow(
                        icon: .musicNote,
                    title: "平台账号管理",
                        value: "4 个平台"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    NavigationLink(destination: DownloadManageView()) {
                        MujiProfileLedgerRow(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            value: "\(downloadedSongCount)"
                        )
                    }
                    .buttonStyle(.plain)

                    MujiProfileDivider()
                }

                NavigationLink(destination: ListeningStatsView()) {
                    MujiProfileLedgerRow(
                        icon: .sparkle,
                        title: String(localized: "cloud_sync_listening_stats"),
                        value: "STATS"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: StorageManageView()) {
                    MujiProfileLedgerRow(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE"
                    )
                }
                .buttonStyle(.plain)

                if loginIdentity.activeSource == .netease {
                    MujiProfileDivider()

                    NavigationLink(destination: CloudDiskView()) {
                        MujiProfileLedgerRow(
                            icon: .cloud,
                            title: NSLocalizedString("profile_cloud_disk", comment: ""),
                            value: "CLOUD"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: MujiStyle.cardRadius, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
            )
        }
    }

    @ViewBuilder
    func mujiAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MujiStyle.surfaceRaised)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.58), lineWidth: 0.7))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MujiStyle.surfaceRaised)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: size * 0.42, color: MujiStyle.inkMuted))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.58), lineWidth: 0.7))
        }
    }

}
