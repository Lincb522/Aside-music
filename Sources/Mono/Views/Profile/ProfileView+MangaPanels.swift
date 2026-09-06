import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    var mangaGuestProfilePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                mangaAvatar(profile: nil, size: 78)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        MangaMisprintTitle(text: String(localized: "profile_not_logged_in"), size: 24)
                            .layoutPriority(1)

                        MangaProfileInfoPill(text: "GUEST", tint: MangaStyle.labelYellow)
                    }

                    Text(LocalizedStringKey("profile_login_hint"))
                        .font(MangaStyle.comicFont(12, weight: .bold))
                        .foregroundStyle(MangaStyle.inkSub)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                let loginForeground = ThemeColorCustomization.readableForegroundColor(
                    on: MangaStyle.labelYellow,
                    light: MangaStyle.strokeInk,
                    dark: MangaStyle.onStrokeInk
                )
                HStack(spacing: 10) {
                    MonoIcon(icon: .profileFilled, size: 16, color: loginForeground, lineWidth: 1.85)

                    Text(LocalizedStringKey("profile_login_button"))
                        .font(MangaStyle.labelFont(15, weight: .black))
                        .foregroundStyle(loginForeground)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .fill(MangaStyle.labelYellow)
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))

            HStack(spacing: 8) {
                MangaLabel(text: "NCM", tint: MangaStyle.bubblePink, small: true)
                MangaLabel(text: "QCM", tint: MangaStyle.decoBlue, small: true)
                MangaLabel(text: "LOCAL", tint: MangaStyle.mint, small: true)
                Spacer(minLength: 0)
                MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 24)
            }
        }
        .padding(16)
        .background(
            // 未登录页唯一焦点分格：保留厚墨框错版投影
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 2, elevated: true, tint: MangaStyle.paperWarm, poster: true)
        )
    }

    var mangaGuestActionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "profile_settings"), mark: .heart)

            VStack(spacing: 0) {
                Button {
                    navigationPath.append(ProfileNavigationDestination.platformAccounts)
                } label: {
                    MangaProfileActionRow(
                        icon: .musicNote,
                    title: "平台账号管理",
                        value: "4 个平台",
                        tint: MangaStyle.labelYellow
                    )
                }
                .buttonStyle(.plain)

                MangaProfileActionDivider()

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    NavigationLink(destination: DownloadManageView()) {
                        MangaProfileActionRow(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            value: "\(downloadedSongCount)",
                            tint: MangaStyle.decoBlue
                        )
                    }
                    .buttonStyle(.plain)

                    MangaProfileActionDivider()
                }


                MangaProfileActionDivider()

                NavigationLink(destination: ListeningStatsView()) {
                    MangaProfileActionRow(
                        icon: .sparkle,
                        title: String(localized: "cloud_sync_listening_stats"),
                        value: "STATS",
                        tint: MangaStyle.decoBlue
                    )
                }
                .buttonStyle(.plain)
                NavigationLink(destination: StorageManageView()) {
                    MangaProfileActionRow(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE",
                        tint: MangaStyle.mint
                    )
                }
                .buttonStyle(.plain)

                MangaProfileActionDivider()

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    MangaProfileActionRow(
                        icon: .settings,
                        title: NSLocalizedString("profile_settings", comment: ""),
                        value: "SYSTEM",
                        tint: MangaStyle.bubblePink
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    var mangaNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        mangaProfileHeader

                        mangaGuestProfilePanel
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        mangaGuestActionList
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    }
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    var mangaProfileHeroPanel: some View {
        let profile = displayedProfile

        return HStack(alignment: .center, spacing: 14) {
            mangaAvatar(profile: profile, size: 76)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    MangaMisprintTitle(text: profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""), size: 24)
                        .layoutPriority(1)

                    if loginIdentity.activeSource == .netease, let level = userLevel {
                        MangaProfileInfoPill(text: "Lv.\(level)", tint: MangaStyle.accentPink)
                    }
                }

                if let signature = profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(MangaStyle.comicFont(12, weight: .bold))
                        .foregroundStyle(MangaStyle.inkSub)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(icon: .settings, size: 18, color: MangaStyle.strokeInk, lineWidth: 1.9)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                            .fill(MangaStyle.bubbleWhite.opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                            .stroke(MangaStyle.strokeInk.opacity(0.55), lineWidth: MangaStyle.fineStrokeWidth)
                    )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .padding(.vertical, 4)
    }

    var mangaProfileActionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "profile_settings"), mark: .heart)

            VStack(spacing: 0) {
                Button {
                    navigationPath.append(ProfileNavigationDestination.platformAccounts)
                } label: {
                    MangaProfileActionRow(
                        icon: .musicNote,
                    title: "平台账号管理",
                        value: "4 个平台",
                        tint: MangaStyle.labelYellow
                    )
                }
                .buttonStyle(.plain)

                MangaProfileActionDivider()

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    NavigationLink(destination: DownloadManageView()) {
                        MangaProfileActionRow(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            value: "\(downloadedSongCount)",
                            tint: MangaStyle.decoBlue
                        )
                    }
                    .buttonStyle(.plain)

                    MangaProfileActionDivider()
                }

                NavigationLink(destination: ListeningStatsView()) {
                    MangaProfileActionRow(
                        icon: .sparkle,
                        title: String(localized: "cloud_sync_listening_stats"),
                        value: "STATS",
                        tint: MangaStyle.decoBlue
                    )
                }
                .buttonStyle(.plain)

                MangaProfileActionDivider()

                NavigationLink(destination: StorageManageView()) {
                    MangaProfileActionRow(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE",
                        tint: MangaStyle.mint
                    )
                }
                .buttonStyle(.plain)

                if loginIdentity.activeSource == .netease {
                    MangaProfileActionDivider()

                    NavigationLink(destination: CloudDiskView()) {
                        MangaProfileActionRow(
                            icon: .cloud,
                            title: NSLocalizedString("profile_cloud_disk", comment: ""),
                            value: "CLOUD",
                            tint: MangaStyle.bubblePink
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    var mangaRecentPlaysPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                MangaSectionMark(kind: .star)

                Text(String(localized: "profile_recently_played"))
                    .font(MangaStyle.titleFont(18, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Rectangle()
                    .fill(MangaStyle.ink.opacity(0.22))
                    .frame(height: 1.4)

                NavigationLink(destination: RecentPlayHistoryView()) {
                    MangaLabel(
                        text: String(format: String(localized: "profile_recent_count"), playerManager.history.count),
                        tint: MangaStyle.decoBlue,
                        small: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(playerManager.history.prefix(12), id: \.identityKey) { song in
                        Button(action: {
                            playerManager.play(song: song, in: playerManager.history)
                        }) {
                            MangaProfileRecentCard(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    @ViewBuilder
    func mangaAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MangaStyle.bubbleWhite)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous).stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1.2))
        } else {
            RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous)
                .fill(MangaStyle.bubbleWhite)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: size * 0.42, color: MangaStyle.strokeInk))
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.cardRadius + 2, style: .continuous).stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1.2))
        }
    }

}
