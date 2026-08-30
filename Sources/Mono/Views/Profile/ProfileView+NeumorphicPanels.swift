import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    var neumorphicProfileHeroPanel: some View {
        let profile = displayedProfile

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                neumorphicAvatar(profile: profile, size: 82)

                VStack(alignment: .leading, spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(NeumorphicStyle.titleFont(24, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if let signature = profile?.signature, !signature.isEmpty {
                        Text(signature)
                            .font(NeumorphicStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(String(localized: "profile_login_hint"))
                            .font(NeumorphicStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkMuted)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        if loginIdentity.activeSource == .netease, let level = userLevel {
                            NeumorphicPill(text: "Lv.\(level)", tint: NeumorphicStyle.accent, compact: true)
                        }
                        NeumorphicPill(
                            text: identityPrimaryMetricValue,
                            tint: NeumorphicStyle.warm,
                            icon: identityPrimaryMetricIcon,
                            compact: true
                        )
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                neumorphicProfileSignalBar(tint: NeumorphicStyle.accent, width: 56)
                neumorphicProfileSignalBar(tint: NeumorphicStyle.sage, width: 38)
                neumorphicProfileSignalBar(tint: NeumorphicStyle.warm, width: 48)
                Spacer(minLength: 0)
                Text(identityPrimaryMetricLabel)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true))
        }
        .padding(18)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 30,
                elevated: true,
                tint: NeumorphicStyle.surface.opacity(0.95),
                lightweight: true
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.7)
        }
    }

    @ViewBuilder
    func neumorphicAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(Color.clear)
                .frame(width: size, height: size)
                .background(NeumorphicSurfaceBackground(cornerRadius: size * 0.32, elevated: true, lightweight: true))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))

            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: size - 14, height: size - 14) {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size - 14, height: size - 14)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .frame(width: size - 14, height: size - 14)
                    .overlay(MonoIcon(icon: .profileFilled, size: size * 0.36, color: NeumorphicStyle.inkMuted))
            }
        }
    }

    var neumorphicProfileMetricDeck: some View {
        HStack(spacing: 8) {
            NeumorphicProfileMetricTile(
                value: identityPrimaryMetricValue,
                label: identityPrimaryMetricLabel,
                tint: NeumorphicStyle.accent,
                icon: identityPrimaryMetricIcon
            )
            NeumorphicProfileMetricTile(
                value: "\(localPlaylistCount)",
                label: String(localized: "profile_local_playlists"),
                tint: NeumorphicStyle.sage,
                icon: .musicNoteList
            )
            NeumorphicProfileMetricTile(
                value: "\(downloadedSongCount)",
                label: String(localized: "profile_downloads"),
                tint: NeumorphicStyle.warm,
                icon: .download
            )
        }
    }

    var neumorphicRecentPlaysPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                NeumorphicIconBadge(icon: .history, tint: NeumorphicStyle.sage, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "profile_recently_played"))
                        .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)

                    Text(String(format: String(localized: "profile_recent_count"), playerManager.history.count))
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                }

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    NeumorphicPill(
                        text: String(localized: "common_view_more"),
                        tint: NeumorphicStyle.accent,
                        icon: .chevronRight,
                        compact: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(playerManager.history.prefix(12)) { song in
                        Button {
                            playerManager.play(song: song, in: playerManager.history)
                        } label: {
                            NeumorphicProfileRecentCard(song: song, isPlaying: playerManager.currentSong?.id == song.id && playerManager.isPlaying)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    var neumorphicProfileShortcutGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            NeumorphicSectionTitle(title: String(localized: "profile_settings"), detail: nil)

            LazyVGrid(columns: neumorphicShortcutColumns, spacing: 12) {
                Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                    NeumorphicProfileShortcutTile(
                        icon: .musicNote,
                    title: "平台账号管理",
                        value: "4 个平台",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    NavigationLink(destination: DownloadManageView()) {
                        NeumorphicProfileShortcutTile(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            value: String(format: String(localized: "profile_recent_count"), downloadedSongCount),
                            tint: NeumorphicStyle.warm
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                }

                NavigationLink(destination: ListeningStatsView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .sparkle,
                        title: String(localized: "cloud_sync_listening_stats"),
                        value: "STATS",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                NavigationLink(destination: StorageManageView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE",
                        tint: NeumorphicStyle.sage
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))

                if loginIdentity.activeSource == .netease {
                    NavigationLink(destination: CloudDiskView()) {
                        NeumorphicProfileShortcutTile(
                            icon: .cloud,
                            title: NSLocalizedString("profile_cloud_disk", comment: ""),
                            value: "CLOUD",
                            tint: NeumorphicStyle.accent
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                }
            }
        }
    }

    var neumorphicShortcutColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    var neumorphicLogoutButton: some View {
        logoutButton
            .padding(.bottom, 6)
    }

    func neumorphicProfileSignalBar(tint: Color, width: CGFloat) -> some View {
        Capsule()
            .fill(tint.opacity(0.48))
            .frame(width: width, height: 6)
    }

    var neumorphicLoginPromptPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.clear)
                        .frame(width: 86, height: 86)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 30, elevated: true, lightweight: true))
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                    MonoIcon(icon: .profileFilled, size: 34, color: NeumorphicStyle.inkMuted, lineWidth: 1.45)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(NeumorphicStyle.titleFont(24, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)

                    Text(LocalizedStringKey("profile_login_hint"))
                        .font(NeumorphicStyle.labelFont(13, weight: .regular))
                        .foregroundStyle(NeumorphicStyle.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                HStack(spacing: 10) {
                    MonoIcon(icon: .profile, size: 16, color: Color(light: .white, dark: .black), lineWidth: 1.55)
                    Text(LocalizedStringKey("profile_login_button"))
                        .font(NeumorphicStyle.labelFont(15, weight: .semibold))
                }
                .foregroundStyle(Color(light: .white, dark: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 18,
                        elevated: true,
                        tint: NeumorphicStyle.accent
                    )
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            HStack(spacing: 10) {
                neumorphicProfileSignalBar(tint: NeumorphicStyle.accent, width: 62)
                neumorphicProfileSignalBar(tint: NeumorphicStyle.warm, width: 34)
                neumorphicProfileSignalBar(tint: NeumorphicStyle.sage, width: 48)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true))
        }
        .padding(18)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 30,
                elevated: true,
                tint: NeumorphicStyle.surface.opacity(0.95),
                lightweight: true
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.7)
        }
    }

    var neumorphicGuestShortcutGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            NeumorphicSectionTitle(title: String(localized: "profile_settings"), detail: nil)

            LazyVGrid(columns: neumorphicShortcutColumns, spacing: 12) {
                Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                    NeumorphicProfileShortcutTile(
                        icon: .musicNote,
                    title: "平台账号管理",
                        value: "4 个平台",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    NavigationLink(destination: DownloadManageView()) {
                        NeumorphicProfileShortcutTile(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            value: String(format: String(localized: "profile_recent_count"), downloadedSongCount),
                            tint: NeumorphicStyle.warm
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                }

                NavigationLink(destination: ListeningStatsView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .sparkle,
                        title: String(localized: "cloud_sync_listening_stats"),
                        value: "STATS",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: StorageManageView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE",
                        tint: NeumorphicStyle.sage
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    NeumorphicProfileShortcutTile(
                        icon: .settings,
                        title: NSLocalizedString("profile_settings", comment: ""),
                        value: "SYSTEM",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
            }
        }
    }

    var neumorphicNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        neumorphicProfileHeaderBar

                        neumorphicLoginPromptPanel
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        neumorphicGuestShortcutGrid
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    }
                    .padding(.top, 8)
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

}
