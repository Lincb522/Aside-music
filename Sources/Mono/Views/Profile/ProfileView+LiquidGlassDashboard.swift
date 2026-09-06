import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    @ViewBuilder
    var liquidGlassProfileDashboard: some View {
        liquidGlassProfileTopRibbon

        liquidGlassProfileLensBoard
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        liquidGlassProfileMetricStreams
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        liquidGlassRecentFlow

        liquidGlassProfilePortalCloud
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        liquidGlassLogoutButton
    }

    var liquidGlassProfileTopRibbon: some View {
        HStack(alignment: .center, spacing: 14) {
            LiquidGlassDropletMark(tint: LiquidGlassStyle.violet)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(LiquidGlassStyle.violet.opacity(0.72))
                        .frame(width: 30, height: 5)
                    Capsule()
                        .fill(LiquidGlassStyle.cyan.opacity(0.45))
                        .frame(width: 11, height: 5)
                }

                Text(String(localized: "tab_profile"))
                    .font(LiquidGlassStyle.titleFont(28, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 10)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                LiquidGlassIconBadge(icon: .settings, tint: LiquidGlassStyle.accent, size: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
        .monoPageHeaderCollapse()
    }

    var liquidGlassProfileLensBoard: some View {
        let profile = displayedProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ZStack(alignment: .bottomTrailing) {
            LiquidGlassProfileLensShape()
                .fill(LiquidGlassStyle.glassRaised.opacity(0.68))
                .overlay(LiquidGlassProfileLensShape().fill(LiquidGlassStyle.accent.opacity(0.08)))
                .overlay(LiquidGlassProfileLensShape().strokeBorder(LiquidGlassStyle.luminousEdge.opacity(0.48), lineWidth: 0.75))
                .shadow(color: LiquidGlassStyle.accent.opacity(0.11), radius: 22, x: 0, y: 10)

            Circle()
                .fill(LiquidGlassStyle.cyan.opacity(0.16))
                .frame(width: 128, height: 128)
                .blur(radius: 18)
                .offset(x: 36, y: 36)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    liquidGlassAvatar(profile: profile, size: 88)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                            .font(LiquidGlassStyle.titleFont(25, weight: .semibold))
                            .foregroundStyle(LiquidGlassStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text(signature.isEmpty ? String(localized: "profile_login_hint") : signature)
                            .font(LiquidGlassStyle.labelFont(12.5, weight: .regular))
                            .foregroundStyle(LiquidGlassStyle.inkSoft)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            if loginIdentity.activeSource == .netease, let userLevel {
                                LiquidGlassPill(text: "Lv.\(userLevel)", tint: LiquidGlassStyle.accent, selected: true, compact: true)
                            }
                            LiquidGlassPill(text: String(format: String(localized: "profile_recent_count"), playerManager.history.count), icon: .clock, tint: LiquidGlassStyle.cyan, compact: true)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 0)
                }

                LiquidGlassHairline(tint: LiquidGlassStyle.accent.opacity(0.32))

                HStack(spacing: 8) {
                    LiquidGlassPill(text: identityPrimaryMetricValue, icon: identityPrimaryMetricIcon, tint: LiquidGlassStyle.violet, compact: true)
                    LiquidGlassPill(text: "\(localPlaylistCount)", icon: .musicNoteList, tint: LiquidGlassStyle.mint, compact: true)
                    LiquidGlassPill(text: "\(downloadedSongCount)", icon: .download, tint: LiquidGlassStyle.amber, compact: true)
                }
            }
            .padding(17)
        }
        .frame(minHeight: 176)
    }

    var liquidGlassProfileMetricStreams: some View {
        HStack(spacing: 10) {
            liquidGlassMetricStream(
                value: identityPrimaryMetricValue,
                label: identityPrimaryMetricLabel,
                tint: LiquidGlassStyle.violet,
                icon: identityPrimaryMetricIcon
            )
            liquidGlassMetricStream(
                value: "\(localPlaylistCount)",
                label: String(localized: "profile_local_playlists"),
                tint: LiquidGlassStyle.mint,
                icon: .musicNoteList
            )
            liquidGlassMetricStream(
                value: "\(downloadedSongCount)",
                label: String(localized: "profile_downloads"),
                tint: LiquidGlassStyle.amber,
                icon: .download
            )
        }
    }

    func liquidGlassMetricStream(
        value: String,
        label: String,
        tint: Color,
        icon: MonoIcon.IconType
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.5)
                Spacer(minLength: 0)
                Capsule()
                    .fill(tint.opacity(0.28))
                    .frame(width: 20, height: 5)
            }

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(LiquidGlassStyle.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(LiquidGlassStyle.labelFont(10, weight: .medium))
                .foregroundStyle(LiquidGlassStyle.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 18, elevated: true, fill: tint.opacity(0.08), role: .list))
    }

    var liquidGlassRecentFlow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LiquidGlassIconBadge(icon: .history, tint: LiquidGlassStyle.cyan, size: 34)

                Text(String(localized: "profile_recently_played"))
                    .font(LiquidGlassStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)

                Spacer(minLength: 8)

                NavigationLink(destination: RecentPlayHistoryView()) {
                    LiquidGlassPill(
                        text: String(format: String(localized: "profile_recent_count"), playerManager.history.count),
                        icon: .chevronRight,
                        tint: LiquidGlassStyle.cyan,
                        compact: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(playerManager.history.prefix(12).enumerated()), id: \.element.identityKey) { index, song in
                        Button {
                            playerManager.play(song: song, in: playerManager.history)
                        } label: {
                            liquidGlassRecentShard(song: song, index: index)
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    func liquidGlassRecentShard(song: Song, index: Int) -> some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: song.coverUrl, width: 48, height: 48) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LiquidGlassStyle.glassList)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(song.name)
                    .font(LiquidGlassStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(LiquidGlassStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(LiquidGlassStyle.inkMuted)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(9)
        .background(
            LiquidGlassSurfaceBackground(
                cornerRadius: index.isMultiple(of: 2) ? 24 : 18,
                elevated: false,
                role: .list
            )
        )
    }

    var liquidGlassProfilePortalCloud: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            Button { navigationPath.append(ProfileNavigationDestination.platformAccounts) } label: {
                liquidGlassProfilePortalTile(
                    icon: .musicNote,
                    title: "平台账号管理",
                    value: "4 个平台",
                    tint: LiquidGlassStyle.accent
                )
            }
            .buttonStyle(.plain)

            // 保留下载入口结构，由功能开关统一控制。
            if AppConfig.Features.downloadEnabled {
                NavigationLink(destination: DownloadManageView()) {
                    liquidGlassProfilePortalTile(
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: "\(downloadedSongCount)",
                        tint: LiquidGlassStyle.amber
                    )
                }
                .buttonStyle(.plain)
            }

            NavigationLink(destination: ListeningStatsView()) {
                liquidGlassProfilePortalTile(
                    icon: .sparkle,
                    title: String(localized: "cloud_sync_listening_stats"),
                    value: "STATS",
                    tint: LiquidGlassStyle.violet
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StorageManageView()) {
                liquidGlassProfilePortalTile(
                    icon: .storage,
                    title: String(localized: "profile_cache_manage"),
                    value: "CACHE",
                    tint: LiquidGlassStyle.mint
                )
            }
            .buttonStyle(.plain)

            if loginIdentity.activeSource == .netease {
                NavigationLink(destination: CloudDiskView()) {
                    liquidGlassProfilePortalTile(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: ""),
                        value: "CLOUD",
                        tint: LiquidGlassStyle.violet
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    func liquidGlassProfilePortalTile(
        icon: MonoIcon.IconType,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                LiquidGlassIconBadge(icon: icon, tint: tint, size: 36)
                Spacer(minLength: 8)
                Text(value)
                    .font(LiquidGlassStyle.labelFont(9.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(title)
                .font(LiquidGlassStyle.titleFont(15, weight: .semibold))
                .foregroundStyle(LiquidGlassStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(13)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 22, elevated: true, fill: tint.opacity(0.08), role: .chrome))
    }

    var liquidGlassLogoutButton: some View {
        logoutButton
            .padding(.top, 0)
    }

}
