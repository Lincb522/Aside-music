import Combine
import QQMusicKit
import SwiftUI

private struct ThemedProfileBackground: View {
    var body: some View {
        ThemedPageBackground(useRenderLayer: true)
    }
}

enum ProfileNavigationDestination: Hashable {
    case settings
    case platformAccounts
    case loginNCM
}

private extension View {
    func profileNavigationDestinations() -> some View {
        navigationDestination(for: ProfileNavigationDestination.self) { destination in
            switch destination {
            case .settings:
                SettingsView()
            case .platformAccounts:
                PlatformAccountManagementView()
            case .loginNCM:
                PlatformLoginView(initialPlatform: .ncm)
            }
        }
    }
}

struct ProfileView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var qqSession = QQUserSession.shared

    private var viewModel: HomeViewModel {
        HomeViewModel.shared
    }

    private var playerManager: PlayerManager {
        PlayerManager.shared
    }

    @AppStorage("isLoggedIn") private var isAppLoggedIn = false

    @State private var cachedProfile: UserProfile?
    @State private var hasAppeared = false
    @State private var hasRequestedQQSessionRestore = false
    @State private var navigationPath = NavigationPath()

    @State private var userLevel: Int?
    @State private var listenSongs: Int?
    /// aside 数据带的本周收听秒数（来自听歌统计日志）
    @State private var weekListenSeconds: Int?

    @State private var downloadedSongCount = DownloadManager.shared.downloadedSongIds.count
    @State private var localPlaylistCount = LocalPlaylistManager.shared.playlists.count

    var body: some View {
        let _ = settings.globalThemeRevision

        Group {
            if isAppLoggedIn {
                loggedInContent
            } else {
                notLoggedInContent
            }
        }
        .onAppear {
            restoreQQSessionIfNeeded()
            if isAppLoggedIn {
                refreshWeekListeningDuration()
                if let profile = viewModel.userProfile, profile.userId != cachedProfile?.userId {
                    cachedProfile = profile
                }
                guard !hasAppeared else {
                    GlobalRefreshManager.shared.markProfileDataReady()
                    return
                }
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cachedProfile = viewModel.userProfile
                    GlobalRefreshManager.shared.markProfileDataReady()
                    fetchUserExtra()
                    // 移除网易云历史记录抓取，统一使用播放器本地历史
                }
            } else {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(GlobalRefreshManager.shared.refreshProfilePublisher) { _ in
            if isAppLoggedIn {
                cachedProfile = viewModel.userProfile
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(viewModel.$userProfile) { profile in
            if profile != nil {
                cachedProfile = profile
            }
        }
        .onReceive(DownloadManager.shared.$downloadedSongIds.map(\.count).removeDuplicates()) { count in
            downloadedSongCount = count
        }
        .onReceive(LocalPlaylistManager.shared.$playlists.map(\.count).removeDuplicates()) { count in
            localPlaylistCount = count
        }
    }

    // MARK: - Logged In

    private var loggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    LazyVStack(spacing: themedProfileSpacing) {
                        loggedInDashboardContent
                        FloatingBarBottomSpacer()
                    }
                    .iPadContentWidth(700)
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

    private var themedProfileSpacing: CGFloat {
        if MinimalWhiteStyle.isActive { return 24 }
        if MangaStyle.isActive { return 14 }
        if PetWhiteStyle.isActive { return 16 }
        if NeumorphicStyle.isActive { return 18 }
        if CapsuleStyle.isActive { return 16 }
        if SignalStyle.isActive { return 17 }
        if MujiStyle.isActive { return 18 }
        if SequoiaStyle.isActive { return 16 }
        if LiquidGlassStyle.isActive { return 16 }
        return 16
    }

    @ViewBuilder
    private var loggedInDashboardContent: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteProfileDashboard
        } else if MangaStyle.isActive {
            mangaProfileDashboard
        } else if PetWhiteStyle.isActive {
            petWhiteProfileDashboard
        } else if NeumorphicStyle.isActive {
            neumorphicProfileDashboard
        } else if CapsuleStyle.isActive {
            capsuleProfileDashboard
        } else if SignalStyle.isActive {
            signalProfileDashboard
        } else if MujiStyle.isActive {
            mujiProfileDashboard
        } else if SequoiaStyle.isActive {
            sequoiaProfileDashboard
        } else if LiquidGlassStyle.isActive {
            liquidGlassProfileDashboard
        } else {
            // aside：编辑部风格 —— 刊头眉题 + 身份区 + 发丝数据带 + 索引式目录
            asideProfileMasthead
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, 8)
                .monoPageHeaderCollapse()

            asideStatsBand
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, 2)

            ProfileRecentPlaysHost(variant: .standard)

            asideMenuIndex
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            asideLogoutButton
        }
    }

    // MARK: - aside 我的页

    /// 刊头：眉题行 + 问候语 + 大号昵称 + 引文式签名，全部直接落在页面上
    private var asideProfileMasthead: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 18, height: 3)

                Text("PROFILE")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundColor(.monoTextSecondary.opacity(0.72))
                    .fixedSize()

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.5))
                    .frame(height: 0.5)

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    MonoIcon(icon: .settings, size: 19, color: .monoTextPrimary.opacity(0.85), lineWidth: 1.7)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.monoIconBackground.opacity(0.1))
                                .overlay(Circle().stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 0.8))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
            }
            .padding(.bottom, 14)

            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url, width: 72, height: 72) {
                            Circle().fill(Color.monoSeparator)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.monoSeparator)
                            .frame(width: 72, height: 72)
                            .overlay(
                                MonoIcon(icon: .profile, size: 30, color: .monoTextSecondary.opacity(0.4))
                            )
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 1.2)
                        .padding(-5)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: LocalizedStringResource(stringLiteral: MonoTimeGreeting.localizedKey)))
                        .font(.rounded(size: 12.5, weight: .semibold))
                        .foregroundColor(.monoTextSecondary.opacity(0.85))

                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                            .font(.system(size: 27, weight: .heavy, design: .rounded))
                            .foregroundColor(.monoTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        if let level = userLevel {
                            Text("LV.\(level)")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundColor(.monoTextPrimary.opacity(0.72))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .overlay(
                                    Capsule().stroke(Color.monoTextPrimary.opacity(0.3), lineWidth: 0.8)
                                )
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            if !signature.isEmpty {
                // 签名作引文：左侧短竖线 + 弱化正文
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.monoAccent.opacity(0.8))
                        .frame(width: 2)
                        .padding(.vertical, 2)

                    Text(signature)
                        .font(.rounded(size: 13))
                        .foregroundColor(.monoTextSecondary)
                        .lineSpacing(3)
                        .lineLimit(2)
                }
                .padding(.top, 16)
                .padding(.leading, 2)
            }
        }
        .padding(.top, 4)
    }

    /// 数据带：上下发丝线之间的裸排大数字，去掉玻璃容器
    private var asideStatsBand: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            asideStatCell(
                value: formatNumber(listenSongs ?? 0),
                label: String(localized: "profile_total_songs")
            )

            asideStatCell(
                value: "\(localPlaylistCount)",
                label: String(localized: "profile_local_playlists")
            )

            asideStatCell(
                value: asideWeekListenValue,
                label: String(localized: "profile_week_listen")
            )
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.monoSeparator.opacity(0.55)).frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.monoSeparator.opacity(0.55)).frame(height: 0.5)
        }
        .task {
            refreshWeekListeningDuration()
        }
    }

    private func refreshWeekListeningDuration() {
        weekListenSeconds = ListeningStatsService.shared.fetchStats(for: .week).totalDuration
    }

    private var asideWeekListenValue: String {
        guard let seconds = weekListenSeconds else { return "—" }
        let hours = Double(seconds) / 3600
        if hours >= 10 { return "\(Int(hours))h" }
        if hours >= 1 { return String(format: "%.1fh", hours) }
        return "\(max(seconds / 60, 0))m"
    }

    private func asideStatCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.monoTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.monoAccent)
                    .frame(width: 4, height: 4)

                Text(label)
                    .font(.rounded(size: 10.5, weight: .semibold))
                    .foregroundColor(.monoTextSecondary.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    /// 目录：索引编号 + 发丝分隔的平铺行，不再装玻璃卡片
    private var asideMenuIndex: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 13)

                Text(String(localized: "profile_settings"))
                    .font(.rounded(size: 15, weight: .bold))
                    .foregroundColor(.monoTextPrimary)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 6)

            Button {
                navigationPath.append(ProfileNavigationDestination.platformAccounts)
            } label: {
                asideMenuRow(
                    index: 1,
                    title: "平台账号管理",
                    trailingText: "4 个平台"
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            asideMenuHairline

            NavigationLink(destination: ListeningStatsView()) {
                asideMenuRow(index: 2, title: String(localized: "cloud_sync_listening_stats"))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            asideMenuHairline

            NavigationLink(destination: CloudDiskView()) {
                asideMenuRow(index: 3, title: NSLocalizedString("profile_cloud_disk", comment: ""))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        }
    }

    private func asideMenuRow(index: Int, title: String, trailingText: String? = nil) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundColor(.monoTextSecondary.opacity(0.45))
                .monospacedDigit()

            Text(title)
                .font(.rounded(size: 15.5, weight: .semibold))
                .foregroundColor(.monoTextPrimary)

            Spacer(minLength: 0)

            if let trailingText {
                Text(trailingText)
                    .font(.rounded(size: 12.5))
                    .foregroundColor(.monoTextSecondary.opacity(0.85))
            }

            MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary.opacity(0.4))
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    private var asideMenuHairline: some View {
        Rectangle()
            .fill(Color.monoSeparator.opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 32)
    }

    private var asideLogoutButton: some View {
        Button {
            AlertManager.shared.show(
                title: NSLocalizedString("alert_logout_title", comment: ""),
                message: NSLocalizedString("alert_logout_message", comment: ""),
                primaryButtonTitle: NSLocalizedString("alert_logout_confirm", comment: ""),
                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
            ) {
                performLogout()
            }
        } label: {
            Text(LocalizedStringKey("action_logout"))
                .font(.rounded(size: 12.5, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.monoTextSecondary.opacity(0.75))
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8)
                )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var minimalWhiteProfileDashboard: some View {
        minimalWhiteProfileHeader
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)

        minimalWhiteIdentity
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        minimalWhiteMetrics
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .standard)

        menuList
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        logoutButton
    }

    private var minimalWhiteProfileHeader: some View {
        HStack(spacing: 12) {
            Text(String(localized: "tab_profile"))
                .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)

            Spacer(minLength: 0)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(icon: .settings, size: 17, color: MinimalWhiteStyle.ink, lineWidth: 1.7)
                    .frame(width: 40, height: 40)
                    .background(MinimalWhiteCircleBackground(elevated: true, selected: true))
            }
            .buttonStyle(.plain)
        }
        .monoPageHeaderCollapse()
    }

    private var minimalWhiteIdentity: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(spacing: 16) {
            minimalWhiteAvatar(profile: profile, size: 72)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MinimalWhiteStyle.titleFont(22, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(1)

                    if let userLevel {
                        Text("Lv.\(userLevel)")
                            .font(MinimalWhiteStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(MinimalWhiteStyle.inkSoft)
                    }
                }

                if !signature.isEmpty {
                    Text(signature)
                        .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                        .foregroundStyle(MinimalWhiteStyle.inkMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        )
    }

    @ViewBuilder
    private func minimalWhiteAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                Circle().fill(MinimalWhiteStyle.controlGlassFill)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth))
        } else {
            Circle()
                .fill(MinimalWhiteStyle.controlGlassFill)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: 25, color: MinimalWhiteStyle.inkMuted))
                .overlay(Circle().stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth))
        }
    }

    private var minimalWhiteMetrics: some View {
        HStack(spacing: 0) {
            StatCell(value: formatNumber(listenSongs ?? 0), label: String(localized: "profile_total_songs"))
            statDivider
            StatCell(value: "\(localPlaylistCount)", label: String(localized: "profile_local_playlists"))
            statDivider
            StatCell(value: "\(downloadedSongCount)", label: String(localized: "profile_downloads"))
        }
        .padding(.vertical, 16)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.cardRadius,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(MinimalWhiteStyle.hairline).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(MinimalWhiteStyle.hairline).frame(height: 1)
        }
    }

    // MARK: - Hero Card

    private var mangaProfileHeader: some View {
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

    private var mujiProfileHeader: some View {
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

    private var neumorphicProfileHeader: some View {
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
    private var mangaProfileDashboard: some View {
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

    @ViewBuilder
    private var petWhiteProfileDashboard: some View {
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

    private var petWhiteProfileIdentityDeck: some View {
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
    private func petWhiteProfileAvatar(profile: UserProfile?, size: CGFloat) -> some View {
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

    private var petWhiteProfileQuickActions: some View {
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

    private var petWhiteProfileAccountPanel: some View {
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

    private var petWhiteLogoutButton: some View {
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

    @ViewBuilder
    private var neumorphicProfileDashboard: some View {
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

    private var neumorphicProfileHeaderBar: some View {
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

    @ViewBuilder
    private var capsuleProfileDashboard: some View {
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

    private var capsuleProfileHeader: some View {
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

    private var capsuleProfileIdentityPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile
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

                        if let userLevel {
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
                            title: formatNumber(listenSongs ?? 0),
                            icon: .headphones,
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
    private func capsuleAvatar(profile: UserProfile?, size: CGFloat) -> some View {
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

    private var capsuleProfileMetricDeck: some View {
        HStack(spacing: 10) {
            CapsuleProfileMetricTile(
                value: formatNumber(listenSongs ?? 0),
                label: String(localized: "profile_total_songs"),
                tint: CapsuleStyle.accent,
                icon: .headphones
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

    private var capsuleProfilePortalGrid: some View {
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

    private var capsuleLogoutButton: some View {
        logoutButton
            .padding(.top, 0)
    }

    @ViewBuilder
    private var signalProfileDashboard: some View {
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

    private var signalProfileHeaderBar: some View {
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
    private var sequoiaProfileDashboard: some View {
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

    private var sequoiaProfileHeaderBar: some View {
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

    @ViewBuilder
    private var liquidGlassProfileDashboard: some View {
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

    private var liquidGlassProfileTopRibbon: some View {
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

    private var liquidGlassProfileLensBoard: some View {
        let profile = cachedProfile ?? viewModel.userProfile
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
                            if let userLevel {
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
                    LiquidGlassPill(text: formatNumber(listenSongs ?? 0), icon: .headphones, tint: LiquidGlassStyle.violet, compact: true)
                    LiquidGlassPill(text: "\(localPlaylistCount)", icon: .musicNoteList, tint: LiquidGlassStyle.mint, compact: true)
                    LiquidGlassPill(text: "\(downloadedSongCount)", icon: .download, tint: LiquidGlassStyle.amber, compact: true)
                }
            }
            .padding(17)
        }
        .frame(minHeight: 176)
    }

    private var liquidGlassProfileMetricStreams: some View {
        HStack(spacing: 10) {
            liquidGlassMetricStream(
                value: formatNumber(listenSongs ?? 0),
                label: String(localized: "profile_total_songs"),
                tint: LiquidGlassStyle.violet,
                icon: .headphones
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

    private func liquidGlassMetricStream(
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

    private var liquidGlassRecentFlow: some View {
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
                    ForEach(Array(playerManager.history.prefix(12).enumerated()), id: \.element.id) { index, song in
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

    private func liquidGlassRecentShard(song: Song, index: Int) -> some View {
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

    private var liquidGlassProfilePortalCloud: some View {
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

    private func liquidGlassProfilePortalTile(
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

    private var liquidGlassLogoutButton: some View {
        logoutButton
            .padding(.top, 0)
    }

    private var liquidGlassProfileHeaderBar: some View {
        HStack(spacing: 13) {
            LiquidGlassDropletMark(tint: LiquidGlassStyle.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text("PROFILE")
                    .font(LiquidGlassStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.inkMuted)

                Text(String(localized: "tab_profile"))
                    .font(LiquidGlassStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 8)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                LiquidGlassIconBadge(icon: .settings, tint: LiquidGlassStyle.accent, size: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .padding(14)
        .background(LiquidGlassChromeBar(cornerRadius: 24))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
        .monoPageHeaderCollapse()
    }

    private var liquidGlassProfileHeroPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(alignment: .center, spacing: 15) {
            liquidGlassAvatar(profile: profile, size: 82)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(LiquidGlassStyle.titleFont(23, weight: .semibold))
                        .foregroundStyle(LiquidGlassStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if let level = userLevel {
                        LiquidGlassPill(text: "Lv.\(level)", tint: LiquidGlassStyle.accent, selected: true, compact: true)
                    }
                }

                Text(signature.isEmpty ? String(localized: "profile_login_hint") : signature)
                    .font(LiquidGlassStyle.labelFont(12, weight: .regular))
                    .foregroundStyle(LiquidGlassStyle.inkSoft)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    LiquidGlassPill(text: formatNumber(listenSongs ?? 0), icon: .headphones, tint: LiquidGlassStyle.cyan, compact: true)
                    LiquidGlassPill(text: "\(localPlaylistCount)", icon: .musicNoteList, tint: LiquidGlassStyle.mint, compact: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.accent, cornerRadius: 28))
    }

    @ViewBuilder
    private func liquidGlassAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .fill(LiquidGlassStyle.glassList)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous).stroke(LiquidGlassStyle.luminousEdge.opacity(0.45), lineWidth: 0.7))
        } else {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(LiquidGlassStyle.glassList)
                .frame(width: size, height: size)
                .background(LiquidGlassSurfaceBackground(cornerRadius: size * 0.31, elevated: true, role: .selected))
                .overlay(MonoIcon(icon: .profileFilled, size: size * 0.36, color: LiquidGlassStyle.accent, lineWidth: 1.55))
        }
    }

    private var sequoiaProfileHeroPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ZStack(alignment: .bottomTrailing) {
            SequoiaGlassBand(tint: SequoiaStyle.accent, cornerRadius: 26)

            HStack(spacing: 15) {
                sequoiaProfileAvatar(profile: profile, size: 82)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                            .font(SequoiaStyle.titleFont(22, weight: .semibold))
                            .foregroundStyle(SequoiaStyle.ink)
                            .lineLimit(1)

                        if let level = userLevel {
                            SequoiaPill(text: "Lv.\(level)", tint: SequoiaStyle.accent, selected: true, compact: true)
                        }
                    }

                    Text(signature.isEmpty ? String(localized: "Mono") : signature)
                        .font(SequoiaStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(SequoiaStyle.inkSoft)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        SequoiaPill(
                            text: String(format: String(localized: "profile_recent_count"), playerManager.history.count),
                            icon: .clock,
                            tint: SequoiaStyle.aqua,
                            selected: false,
                            compact: true
                        )
                        SequoiaMeter(tint: SequoiaStyle.aqua, count: 8)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(15)
        }
        .frame(minHeight: 116)
    }

    @ViewBuilder
    private func sequoiaProfileAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                Circle().fill(SequoiaStyle.materialList)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(SequoiaStyle.luminousSeparator.opacity(0.62), lineWidth: 1))
            .shadow(color: SequoiaStyle.accent.opacity(0.14), radius: 10, y: 5)
        } else {
            Circle()
                .fill(SequoiaStyle.materialList)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: size * 0.38, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
                .overlay(Circle().stroke(SequoiaStyle.separator, lineWidth: 0.7))
        }
    }

    private var signalProfileHeroPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 14) {
                signalAvatar(profile: profile, size: 78)

                VStack(alignment: .leading, spacing: 7) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(SignalStyle.titleFont(24, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(profile?.signature?.isEmpty == false ? profile?.signature ?? "" : String(localized: "profile_login_hint"))
                        .font(SignalStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(SignalStyle.inkSoft)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let userLevel {
                            SignalPill(text: "Lv.\(userLevel)", tint: SignalStyle.accent, selected: true, compact: true)
                        }
                        SignalPill(text: formatNumber(listenSongs ?? 0), tint: SignalStyle.olive, icon: .headphones, compact: true)
                    }
                }

                Spacer(minLength: 0)
            }

            SignalProfilePulseStrip(tint: SignalStyle.accent)
        }
        .padding(16)
        .background(SignalSurfaceBackground(cornerRadius: 30, elevated: true, fill: SignalStyle.device))
    }

    @ViewBuilder
    private func signalAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(SignalStyle.controlPressed)
                .frame(width: size, height: size)
                .background(SignalSurfaceBackground(cornerRadius: size * 0.32, elevated: true, fill: SignalStyle.deviceRaised))

            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: size - 14, height: size - 14) {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(SignalStyle.controlPressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size - 14, height: size - 14)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            } else {
                MonoIcon(icon: .profileFilled, size: size * 0.36, color: SignalStyle.accent, lineWidth: 1.75)
            }
        }
    }

    private var neumorphicProfileHeroPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile

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
                        if let level = userLevel {
                            NeumorphicPill(text: "Lv.\(level)", tint: NeumorphicStyle.accent, compact: true)
                        }
                        NeumorphicPill(
                            text: formatNumber(listenSongs ?? 0),
                            tint: NeumorphicStyle.warm,
                            icon: .headphones,
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
                Text(String(localized: "profile_total_songs"))
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
    private func neumorphicAvatar(profile: UserProfile?, size: CGFloat) -> some View {
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

    private var neumorphicProfileMetricDeck: some View {
        HStack(spacing: 8) {
            NeumorphicProfileMetricTile(
                value: formatNumber(listenSongs ?? 0),
                label: String(localized: "profile_total_songs"),
                tint: NeumorphicStyle.accent,
                icon: .headphones
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

    private var neumorphicRecentPlaysPanel: some View {
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

    private var neumorphicProfileShortcutGrid: some View {
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

    private var neumorphicShortcutColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var neumorphicLogoutButton: some View {
        logoutButton
            .padding(.bottom, 6)
    }

    private func neumorphicProfileSignalBar(tint: Color, width: CGFloat) -> some View {
        Capsule()
            .fill(tint.opacity(0.48))
            .frame(width: width, height: 6)
    }

    private var mangaGuestProfilePanel: some View {
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

    private var mangaGuestActionList: some View {
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

    private var mangaNotLoggedInContent: some View {
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

    private var mujiGuestJournalPanel: some View {
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

    private var mujiGuestLedger: some View {
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

    private var mujiNotLoggedInContent: some View {
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    private var neumorphicLoginPromptPanel: some View {
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

    private var neumorphicGuestShortcutGrid: some View {
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

    private var neumorphicNotLoggedInContent: some View {
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

    @ViewBuilder
    private var mujiProfileDashboard: some View {
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

    private var mangaProfileHeroPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile

        return HStack(alignment: .center, spacing: 14) {
            mangaAvatar(profile: profile, size: 76)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    MangaMisprintTitle(text: profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""), size: 24)
                        .layoutPriority(1)

                    if let level = userLevel {
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

    private var mangaProfileActionGrid: some View {
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
            .padding(.vertical, 4)
        }
    }

    private var mangaRecentPlaysPanel: some View {
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
                    ForEach(playerManager.history.prefix(12)) { song in
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

    private var mujiProfileJournalPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                mujiAvatar(profile: profile, size: 72)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        if let level = userLevel {
                            MujiPill(text: "Lv.\(level)", tint: MujiStyle.clay)
                        }
                        MujiPill(text: formatNumber(listenSongs ?? 0), tint: MujiStyle.tea)
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

    private var mujiProfileLedger: some View {
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

                NavigationLink(destination: CloudDiskView()) {
                    MujiProfileLedgerRow(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: ""),
                        value: "CLOUD"
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

    @ViewBuilder
    private func mangaAvatar(profile: UserProfile?, size: CGFloat) -> some View {
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

    @ViewBuilder
    private func mujiAvatar(profile: UserProfile?, size: CGFloat) -> some View {
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

    private var profileHeroCard: some View {
        let profile = cachedProfile ?? viewModel.userProfile

        return HStack(spacing: 16) {
            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize) {
                    Circle().fill(Color.monoSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                .clipShape(Circle())
                .overlay(Circle().stroke(PetWhiteStyle.isActive ? PetWhiteStyle.stroke : Color.clear, lineWidth: 2))
            } else if PetWhiteStyle.isActive {
                PetWhiteMascotMark(kind: .pair, size: DeviceLayout.profileAvatarSize)
                    .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                    .background(
                        PetWhiteSurfaceBackground(
                            cornerRadius: DeviceLayout.profileAvatarSize * 0.5,
                            elevated: true,
                            tint: PetWhiteStyle.surfaceRaised,
                            accent: PetWhiteStyle.mint
                        )
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.monoSeparator)
                    .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                    .overlay(
                        MonoIcon(icon: .profile, size: 30, color: .monoTextSecondary.opacity(0.4))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MangaStyle.isActive ? MangaStyle.titleFont(22, weight: .black) : (PetWhiteStyle.isActive ? PetWhiteStyle.titleFont(22, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(22, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(22, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(21, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(21, weight: .semibold) : .system(size: 20, weight: .bold, design: .rounded)))))))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : .monoTextPrimary)
                        .lineLimit(1)

                    if let level = userLevel {
                        Text("Lv.\(level)")
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(10, weight: .bold) : (PetWhiteStyle.isActive ? PetWhiteStyle.labelFont(10, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(10, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(10, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(10, weight: .semibold) : .system(size: 10, weight: .bold, design: .rounded)))))))
                            .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : .monoIconForeground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(PetWhiteStyle.isActive ? PetWhiteStyle.mint : Color.monoIconBackground)
                            .clipShape(Capsule())
                    }
                }

                if let signature = profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(MangaStyle.isActive ? MangaStyle.comicFont(12, weight: .medium) : (PetWhiteStyle.isActive ? PetWhiteStyle.bodyFont(12, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded)))))))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : .monoTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(ThemedPageStyle.isActive ? 16 : 18)
        .themedProfileSurface(cornerRadius: PetWhiteStyle.isActive ? PetWhiteStyle.cardRadius : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 24 : (SignalStyle.isActive ? 16 : (SequoiaStyle.isActive ? 18 : 22))))), mangaTint: MangaStyle.paperWarm)
    }

    // MARK: - Stats Bar

    @ViewBuilder
    private var statsBar: some View {
        if MangaStyle.isActive {
            HStack(spacing: 10) {
                MangaMetricTile(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs"),
                    tint: MangaStyle.labelYellow
                )
                MangaMetricTile(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists"),
                    tint: MangaStyle.decoBlue
                )
                MangaMetricTile(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads"),
                    tint: MangaStyle.accentPink
                )
            }
            .padding(.vertical, 4)
            .overlay(alignment: .top) {
                Rectangle().fill(MangaStyle.strokeInk.opacity(0.22)).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(MangaStyle.strokeInk.opacity(0.22)).frame(height: 1)
            }
        } else if PetWhiteStyle.isActive {
            HStack(spacing: 0) {
                StatCell(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs")
                )
                statDivider
                StatCell(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists")
                )
                statDivider
                StatCell(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads")
                )
            }
            .padding(.vertical, 14)
            .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        } else if MujiStyle.isActive {
            // 杂志数据带：裸排统计签，靠上缘发丝线分区
            HStack(alignment: .top, spacing: 22) {
                MujiMetricTile(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs"),
                    tint: MujiStyle.ink
                )
                MujiMetricTile(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists"),
                    tint: MujiStyle.ink
                )
                MujiMetricTile(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads"),
                    tint: MujiStyle.clay
                )
            }
        } else if NeumorphicStyle.isActive {
            HStack(spacing: 10) {
                StatCell(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs")
                )
                statDivider
                StatCell(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists")
                )
                statDivider
                StatCell(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads")
                )
            }
            .padding(.vertical, 14)
            .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true))
        } else if SignalStyle.isActive {
            HStack(spacing: 0) {
                StatCell(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs")
                )
                statDivider
                StatCell(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists")
                )
                statDivider
                StatCell(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads")
                )
            }
            .padding(.vertical, 14)
            .background(SignalSurfaceBackground(cornerRadius: 16, elevated: true, fill: SignalStyle.device))
        } else if SequoiaStyle.isActive {
            HStack(spacing: 0) {
                StatCell(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs")
                )
                statDivider
                StatCell(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists")
                )
                statDivider
                StatCell(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads")
                )
            }
            .padding(.vertical, 13)
            .background(SequoiaSurfaceBackground(cornerRadius: 20, elevated: true, role: .chrome))
        } else if LiquidGlassStyle.isActive {
            HStack(spacing: 0) {
                StatCell(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs")
                )
                statDivider
                StatCell(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists")
                )
                statDivider
                StatCell(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads")
                )
            }
            .padding(.vertical, 13)
            .background(LiquidGlassSurfaceBackground(cornerRadius: 20, elevated: true, role: .chrome))
        } else {
            HStack(spacing: 0) {
                StatCell(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs")
                )
                statDivider
                StatCell(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists")
                )
                statDivider
                StatCell(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads")
                )
            }
            .padding(.vertical, 14)
            .monoGlass(cornerRadius: 18)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PetWhiteStyle.isActive ? PetWhiteStyle.separator : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.68) : (SignalStyle.isActive ? SignalStyle.separator.opacity(0.7) : (SequoiaStyle.isActive ? SequoiaStyle.separator.opacity(0.9) : (LiquidGlassStyle.isActive ? LiquidGlassStyle.separator.opacity(0.82) : Color.monoSeparator)))))
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Recent Plays

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(MangaStyle.isActive ? MangaStyle.titleFont(18, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))))
                    .foregroundColor(.monoTextPrimary)

                Spacer()

                NavigationLink(
                    destination: RecentPlayHistoryView()
                ) {
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "profile_recent_count"), playerManager.history.count))
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))))
                            .foregroundColor(.monoTextSecondary)
                        MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(playerManager.history.prefix(15)) { song in
                        Button(action: {
                            playerManager.play(song: song, in: playerManager.history)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: song.coverUrl, width: 110, height: 110) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.monoSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded))))
                                        .foregroundColor(.monoTextPrimary)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(11, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded))))
                                        .foregroundColor(.monoTextSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    // MARK: - Menu List

    private var menuList: some View {
        VStack(alignment: .leading, spacing: ThemedPageStyle.isActive ? 12 : 0) {
            if MangaStyle.isActive {
                MangaSectionTitle(title: String(localized: "profile_settings"))
            } else if MujiStyle.isActive {
                MujiSectionTitle(title: String(localized: "profile_settings"))
            } else if PetWhiteStyle.isActive {
                PetWhiteSectionTitle(
                    title: String(localized: "快捷操作"),
                    detail: String(localized: "常用入口"),
                    icon: .sparkle,
                    tint: PetWhiteStyle.butter
                )
            } else if NeumorphicStyle.isActive {
                NeumorphicSectionTitle(title: String(localized: "profile_settings"), detail: nil)
            } else if SignalStyle.isActive {
                SignalSectionTitle(title: String(localized: "profile_settings"))
            } else if SequoiaStyle.isActive {
                HStack(spacing: 9) {
                    Rectangle()
                        .fill(SequoiaStyle.accent.opacity(0.72))
                        .frame(width: 3, height: 17)
                        .clipShape(Capsule())
                    Text(String(localized: "profile_settings"))
                        .font(SequoiaStyle.titleFont(17, weight: .semibold))
                        .foregroundStyle(SequoiaStyle.ink)
                    Spacer(minLength: 0)
                }
            } else if LiquidGlassStyle.isActive {
                HStack(spacing: 9) {
                    LiquidGlassDropletMark(tint: LiquidGlassStyle.violet)
                        .scaleEffect(0.72)
                    Text(String(localized: "profile_settings"))
                        .font(LiquidGlassStyle.titleFont(17, weight: .semibold))
                        .foregroundStyle(LiquidGlassStyle.ink)
                    Spacer(minLength: 0)
                }
            } else if SettingsManager.shared.globalThemeId == .default {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.monoAccent)
                        .frame(width: 3, height: 13)

                    Text(String(localized: "profile_settings"))
                        .font(.rounded(size: 15, weight: .bold))
                        .foregroundColor(.monoTextPrimary)

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 10)
            }

            VStack(spacing: 0) {
                Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                    ProfileMenuRow(
                        icon: .musicNote,
                    title: "平台账号管理",
                        trailingText: "4 个平台"
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    Divider().padding(.leading, 56)

                    NavigationLink(
                        destination: DownloadManageView()
                    ) {
                        ProfileMenuRow(
                            icon: .download,
                            title: NSLocalizedString("profile_downloads", comment: ""),
                            trailingText: String(format: String(localized: "profile_recent_count"), downloadedSongCount)
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                }

                Divider().padding(.leading, 56)

                NavigationLink(
                    destination: ListeningStatsView()
                ) {
                    ProfileMenuRow(
                        icon: .sparkle,
                        title: String(localized: "cloud_sync_listening_stats")
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(
                    destination: StorageManageView()
                ) {
                    ProfileMenuRow(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage")
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(
                    destination: CloudDiskView()
                ) {
                    ProfileMenuRow(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: "")
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
            }
            .themedProfileSurface(cornerRadius: PetWhiteStyle.isActive ? PetWhiteStyle.cardRadius : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (SignalStyle.isActive ? 24 : (NeumorphicStyle.isActive ? 20 : (SequoiaStyle.isActive ? 18 : 20))))), mangaTint: MangaStyle.bubbleWhite)
        }
    }

    // MARK: - Logout

    private func restoreQQSessionIfNeeded() {
        guard !hasRequestedQQSessionRestore,
              !qqSession.isLoggedIn,
              qqSession.hasStoredCredentials else { return }
        hasRequestedQQSessionRestore = true
        Task { @MainActor in
            await qqSession.refresh()
        }
    }

    private func performLogout() {
        let logoutPublisher = UnsafeSendableBox(APIService.shared.logout())
        isAppLoggedIn = false
        cachedProfile = nil
        hasAppeared = false
        userLevel = nil
        listenSongs = nil
        // 播放记录是设备本地数据，退出账号不清空
        AlertManager.shared.dismiss()

        Task {
            do {
                _ = try await logoutPublisher.value.async()
            } catch {
                AppLogger.warning("远端退出登录失败，本地已退出: \(error)")
            }
        }
    }

    private var logoutButton: some View {
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
            Text(LocalizedStringKey("action_logout"))
                .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (PetWhiteStyle.isActive ? PetWhiteStyle.labelFont(13, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded)))))
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : .monoTextSecondary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - Not Logged In

    @ViewBuilder
    private var notLoggedInContent: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteNotLoggedInContent
        } else if MangaStyle.isActive {
            mangaNotLoggedInContent
        } else if PetWhiteStyle.isActive {
            petWhiteNotLoggedInContent
        } else if MujiStyle.isActive {
            mujiNotLoggedInContent
        } else if NeumorphicStyle.isActive {
            neumorphicNotLoggedInContent
        } else if CapsuleStyle.isActive {
            capsuleNotLoggedInContent
        } else if LiquidGlassStyle.isActive {
            liquidGlassNotLoggedInContent
        } else if !ThemedPageStyle.isActive {
            asideNotLoggedInContent
        } else {
            NavigationStack(path: $navigationPath) {
                ZStack {
                    ThemedProfileBackground()

                    VStack(spacing: 0) {
                        if MangaStyle.isActive {
                            mangaProfileHeader
                        } else if NeumorphicStyle.isActive {
                            neumorphicProfileHeader
                        } else if CapsuleStyle.isActive {
                            capsuleProfileHeader
                        } else if SignalStyle.isActive {
                            signalProfileHeaderBar
                        } else if MujiStyle.isActive {
                            mujiProfileHeader
                        } else if SequoiaStyle.isActive {
                            sequoiaProfileHeaderBar
                        }

                        Spacer()

                        VStack(spacing: 28) {
                            ZStack {
                                Circle()
                                    .fill(Color.monoGlassTint)
                                    .monoGlassCircle()
                                    .frame(width: 100, height: 100)

                                MonoIcon(icon: .profile, size: 40, color: .monoTextSecondary.opacity(0.3))
                            }

                            VStack(spacing: 10) {
                                Text(LocalizedStringKey("profile_not_logged_in"))
                                    .font(MangaStyle.isActive ? MangaStyle.titleFont(26, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(26, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(26, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(25, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(25, weight: .semibold) : .system(size: 26, weight: .bold, design: .rounded))))))
                                    .foregroundColor(.monoTextPrimary)

                                Text(LocalizedStringKey("profile_login_hint"))
                                    .font(MangaStyle.isActive ? MangaStyle.comicFont(14, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(14, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .system(size: 14, weight: .medium, design: .rounded))))))
                                    .foregroundColor(.monoTextSecondary)
                            }

                            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                                Text(LocalizedStringKey("profile_login_button"))
                                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(16, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(16, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(16, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(16, weight: .semibold) : .system(size: 16, weight: .bold, design: .rounded)))))
                                    .foregroundColor(MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (MujiStyle.isActive ? MujiStyle.onTint : (NeumorphicStyle.isActive ? Color(light: .white, dark: .black) : (SignalStyle.isActive ? SignalStyle.onAccent : .monoIconForeground))))
                                    .frame(width: 200)
                                    .padding(.vertical, 15)
                                    .background {
                                        if MangaStyle.isActive {
                                            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                                .fill(MangaStyle.labelYellow)
                                        } else if NeumorphicStyle.isActive {
                                            Capsule()
                                                .fill(NeumorphicStyle.accent)
                                        } else if SignalStyle.isActive {
                                            Capsule()
                                                .fill(SignalStyle.accent)
                                        } else if MujiStyle.isActive {
                                            Capsule()
                                                .fill(MujiStyle.clay)
                                        } else if SequoiaStyle.isActive {
                                            Capsule()
                                                .fill(SequoiaStyle.accentGradient)
                                        } else {
                                            Capsule()
                                                .fill(Color.monoIconBackground)
                                        }
                                    }
                            }
                            .buttonStyle(MonoBouncingButtonStyle())
                        }
                        .padding(ThemedPageStyle.isActive ? 24 : 0)
                        .background {
                            if MangaStyle.isActive {
                                MangaCardBackground(cornerRadius: MangaStyle.cardRadius, elevated: true)
                            } else if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true)
                            } else if SignalStyle.isActive {
                                SignalSurfaceBackground(cornerRadius: 16, elevated: true, fill: SignalStyle.device)
                            } else if MujiStyle.isActive {
                                // Muji：清新水洗底
                                RoundedRectangle(cornerRadius: MujiStyle.cardRadius, style: .continuous)
                                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, fill: SequoiaStyle.material)
                            }
                        }
                        .padding(.horizontal, ThemedPageStyle.isActive ? DeviceLayout.homeHorizontalPadding : 0)

                        Spacer()

                        VStack(spacing: 0) {
                            Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                                ProfileMenuRow(
                                    icon: .musicNote,
                    title: "平台账号管理",
                                    trailingText: "4 个平台"
                                )
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                            // 保留下载入口结构，由功能开关统一控制。
                            if AppConfig.Features.downloadEnabled {
                                Divider().padding(.leading, 56)

                                NavigationLink(
                                    destination: DownloadManageView()
                                ) {
                                    ProfileMenuRow(
                                        icon: .download,
                                        title: NSLocalizedString("profile_downloads", comment: ""),
                                        trailingText: String(format: String(localized: "profile_recent_count"), downloadedSongCount)
                                    )
                                }
                                .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                            }

                            Divider().padding(.leading, 56)

                            NavigationLink(
                                destination: ListeningStatsView()
                            ) {
                                ProfileMenuRow(
                                    icon: .sparkle,
                                    title: String(localized: "cloud_sync_listening_stats")
                                )
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                            Divider().padding(.leading, 56)

                            NavigationLink(
                                destination: StorageManageView()
                            ) {
                                ProfileMenuRow(
                                    icon: .storage,
                                    title: String(localized: "profile_cache_manage")
                                )
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                            Divider().padding(.leading, 56)

                            NavigationLink(value: ProfileNavigationDestination.settings) {
                                ProfileMenuRow(
                                    icon: .settings,
                                    title: NSLocalizedString("profile_settings", comment: "")
                                )
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                        }
                        .themedProfileSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 20 : (SignalStyle.isActive ? 16 : (SequoiaStyle.isActive ? 16 : 20)))), mangaTint: MangaStyle.bubbleWhite)
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .padding(.bottom, 140)
                    }
                }
                .navigationTitle(ThemedPageStyle.isActive ? "" : String(localized: "tab_profile"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .profileNavigationDestinations()
            }
        }
    }

    // MARK: - aside 未登录页

    /// 编辑部风格的未登录页：眉题 + 大字状态 + 引文说明 + 索引目录，与登录后的版式同一套语汇
    private var asideNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                VStack(alignment: .leading, spacing: 0) {
                    asideGuestEyebrow
                        .padding(.top, 12)

                    Spacer(minLength: 0)

                    asideGuestHero

                    Spacer(minLength: 0)

                    asideGuestMenuIndex
                        .padding(.bottom, 140)
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .iPadContentWidth(700)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    private var asideGuestEyebrow: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.monoAccent)
                .frame(width: 18, height: 3)

            Text("PROFILE")
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .tracking(2.4)
                .foregroundColor(.monoTextSecondary.opacity(0.72))
                .fixedSize()

            Rectangle()
                .fill(Color.monoSeparator.opacity(0.5))
                .frame(height: 0.5)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(icon: .settings, size: 19, color: .monoTextPrimary.opacity(0.85), lineWidth: 1.7)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.monoIconBackground.opacity(0.1))
                            .overlay(Circle().stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 0.8))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
        }
    }

    private var asideGuestHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: LocalizedStringResource(stringLiteral: MonoTimeGreeting.localizedKey)))
                .font(.rounded(size: 12.5, weight: .semibold))
                .foregroundColor(.monoTextSecondary.opacity(0.85))

            Text(LocalizedStringKey("profile_not_logged_in"))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.monoTextPrimary)
                .padding(.top, 6)

            Text(LocalizedStringKey("profile_login_desc"))
                .font(.rounded(size: 13))
                .foregroundColor(.monoTextSecondary)
                .lineSpacing(3)
                .padding(.top, 14)
                .padding(.leading, 2)

            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey("profile_login_button"))
                        .font(.rounded(size: 14, weight: .bold))

                    MonoIcon(icon: .chevronRight, size: 11, color: .monoIconForeground)
                }
                .foregroundColor(.monoIconForeground)
                .padding(.horizontal, 26)
                .padding(.vertical, 13)
                .background(Capsule().fill(Color.monoIconBackground))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
            .padding(.top, 26)
        }
    }

    /// 登录前仍可使用的入口：QCM 独立登录、本地听歌统计
    private var asideGuestMenuIndex: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 13)

                Text(String(localized: "profile_settings"))
                    .font(.rounded(size: 15, weight: .bold))
                    .foregroundColor(.monoTextPrimary)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 6)

            Button {
                navigationPath.append(ProfileNavigationDestination.platformAccounts)
            } label: {
                asideMenuRow(
                    index: 1,
                    title: "平台账号管理",
                    trailingText: "4 个平台"
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            asideMenuHairline

            NavigationLink(destination: ListeningStatsView()) {
                asideMenuRow(index: 2, title: String(localized: "cloud_sync_listening_stats"))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        }
    }

    private var minimalWhiteNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                MinimalWhiteRootBackdrop().ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack {
                        Text(String(localized: "tab_profile"))
                            .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                            .foregroundStyle(MinimalWhiteStyle.ink)

                        Spacer(minLength: 0)

                        NavigationLink(value: ProfileNavigationDestination.settings) {
                            MonoIcon(icon: .settings, size: 17, color: MinimalWhiteStyle.ink, lineWidth: 1.7)
                                .frame(width: 40, height: 40)
                                .background(MinimalWhiteCircleBackground(elevated: true, selected: true))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    MonoIcon(icon: .profile, size: 30, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5)
                        .frame(width: 76, height: 76)
                        .background(MinimalWhiteCircleBackground(elevated: true))

                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(MinimalWhiteStyle.titleFont(21, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)

                    Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                        Text(LocalizedStringKey("profile_login_button"))
                            .font(MinimalWhiteStyle.labelFont(15, weight: .semibold))
                            .foregroundStyle(MinimalWhiteStyle.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(MinimalWhiteStyle.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding + 8)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    private var petWhiteNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        petWhiteGuestIdentityDeck
                            .padding(.horizontal, 14)
                            .padding(.top, 8)

                        petWhiteProfileQuickActions
                            .padding(.horizontal, 14)

                        petWhiteProfileAccountPanel
                            .padding(.horizontal, 14)

                        FloatingBarBottomSpacer()
                    }
                    .iPadContentWidth(700)
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

    private var petWhiteGuestIdentityDeck: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    PetWhitePill(text: "PAWCELAIN", tint: PetWhiteStyle.mint)

                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(PetWhiteStyle.titleFont(29, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(LocalizedStringKey("profile_login_hint"))
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

            HStack(alignment: .center, spacing: 16) {
                PetWhitePetPetIcon(size: 96)
                    .frame(width: 96, height: 96)
                    .background(PetWhiteStyle.surfacePressed, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                        HStack(spacing: 8) {
                            PetWhitePackIcon(icon: .profileFilled, size: 16, visualScale: 1.06)
                            Text(LocalizedStringKey("profile_login_button"))
                                .font(PetWhiteStyle.labelFont(15, weight: .black))
                        }
                        .foregroundStyle(PetWhiteStyle.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(PetWhiteStyle.mint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(MonoBouncingButtonStyle())

                    HStack(spacing: 8) {
                        PetWhitePill(text: "NCM", tint: PetWhiteStyle.butter)
                        PetWhitePill(text: "QCM", tint: PetWhiteStyle.sky)
                    }
                }
            }
        }
        .padding(18)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 30,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.dogOrange
            )
        )
    }

    private var capsuleNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        capsuleProfileHeader

                        VStack(spacing: 18) {
                            CapsuleIconBadge(icon: .profileFilled, tint: CapsuleStyle.accent, size: 78)

                            VStack(spacing: 8) {
                                Text(LocalizedStringKey("profile_not_logged_in"))
                                    .font(CapsuleStyle.titleFont(25, weight: .bold))
                                    .foregroundStyle(CapsuleStyle.ink)

                                Text(LocalizedStringKey("profile_login_hint"))
                                    .font(CapsuleStyle.bodyFont(13, weight: .medium))
                                    .foregroundStyle(CapsuleStyle.inkSoft)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }

                            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                                Text(LocalizedStringKey("profile_login_button"))
                                    .font(CapsuleStyle.labelFont(16, weight: .bold))
                                    .foregroundStyle(CapsuleStyle.readableLabel(on: CapsuleStyle.accent))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        Capsule()
                                            .fill(CapsuleStyle.accent)
                                            .shadow(color: CapsuleStyle.accent.opacity(0.22), radius: 12, x: 0, y: 7)
                                    )
                            }
                            .buttonStyle(CapsulePressStyle())
                        }
                        .padding(22)
                        .background(CapsuleSurfaceBackground(cornerRadius: 34, elevated: true, tint: CapsuleStyle.surface.opacity(0.95)))
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        VStack(alignment: .leading, spacing: 12) {
                            CapsuleSectionTitle(title: String(localized: "profile_settings"), tint: CapsuleStyle.violet)

                            VStack(spacing: 10) {
                                Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                                    ProfileMenuRow(
                                        icon: .musicNote,
                    title: "平台账号管理",
                                        trailingText: "4 个平台"
                                    )
                                }
                                .buttonStyle(CapsulePressStyle())

                                // 保留下载入口结构，由功能开关统一控制。
                                if AppConfig.Features.downloadEnabled {
                                    NavigationLink(destination: DownloadManageView()) {
                                        ProfileMenuRow(
                                            icon: .download,
                                            title: NSLocalizedString("profile_downloads", comment: ""),
                                            trailingText: String(format: String(localized: "profile_recent_count"), downloadedSongCount)
                                        )
                                    }
                                    .buttonStyle(CapsulePressStyle())
                                }

                                NavigationLink(destination: ListeningStatsView()) {
                                    ProfileMenuRow(
                                        icon: .sparkle,
                                        title: String(localized: "cloud_sync_listening_stats")
                                    )
                                }
                                .buttonStyle(CapsulePressStyle())

                                NavigationLink(destination: StorageManageView()) {
                                    ProfileMenuRow(
                                        icon: .storage,
                                        title: String(localized: "profile_cache_manage")
                                    )
                                }
                                .buttonStyle(CapsulePressStyle())

                                NavigationLink(value: ProfileNavigationDestination.settings) {
                                    ProfileMenuRow(
                                        icon: .settings,
                                        title: NSLocalizedString("profile_settings", comment: "")
                                    )
                                }
                                .buttonStyle(CapsulePressStyle())
                            }
                        }
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        FloatingBarBottomSpacer()
                    }
                    .iPadContentWidth(700)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    private var liquidGlassNotLoggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        liquidGlassProfileHeaderBar

                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 15) {
                                liquidGlassAvatar(profile: nil, size: 78)

                                VStack(alignment: .leading, spacing: 7) {
                                    Text(LocalizedStringKey("profile_not_logged_in"))
                                        .font(LiquidGlassStyle.titleFont(24, weight: .semibold))
                                        .foregroundStyle(LiquidGlassStyle.ink)

                                    Text(LocalizedStringKey("profile_login_hint"))
                                        .font(LiquidGlassStyle.labelFont(13, weight: .regular))
                                        .foregroundStyle(LiquidGlassStyle.inkSoft)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)
                            }

                            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                                HStack(spacing: 9) {
                                    MonoIcon(icon: .profileFilled, size: 15, color: LiquidGlassStyle.onAccent, lineWidth: 1.55)
                                    Text(LocalizedStringKey("profile_login_button"))
                                        .font(LiquidGlassStyle.labelFont(15, weight: .semibold))
                                        .foregroundStyle(LiquidGlassStyle.onAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.accent, cornerRadius: 18))
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                        }
                        .padding(16)
                        .background(LiquidGlassSurfaceBackground(cornerRadius: 28, elevated: true, role: .chrome))
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        menuList
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

    // MARK: - Data Fetching

    private func fetchUserExtra() {
        guard let uid = APIService.shared.currentUserId else { return }
        APIService.shared.fetchUserDetail(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [self] response in
                      userLevel = response.level
                      listenSongs = response.listenSongs
                  })
            .store(in: &ProfileCancellableStore.shared.cancellables)
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 10000 {
            return String(format: "%.1fw", Double(value) / 10000)
        }
        return "\(value)"
    }
}

// MARK: - Cancellable Store

private class ProfileCancellableStore: @unchecked Sendable {
    static let shared = ProfileCancellableStore()
    var cancellables = Set<AnyCancellable>()
}

// MARK: - Stat Cell

struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(valueFont)
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (LiquidGlassStyle.isActive ? LiquidGlassStyle.ink : .monoTextPrimary)))

            Text(label)
                .font(labelFont)
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (LiquidGlassStyle.isActive ? LiquidGlassStyle.inkSoft : .monoTextSecondary)))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var valueFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(18, weight: .black) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.titleFont(18, weight: .black) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.titleFont(18, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(18, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(18, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.titleFont(17, weight: .bold) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.titleFont(18, weight: .semibold) }
        return .system(size: 18, weight: .bold, design: .rounded)
    }

    private var labelFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(10, weight: .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(10, weight: .bold) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.labelFont(10, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(10, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(10, weight: .regular) }
        if SignalStyle.isActive { return SignalStyle.labelFont(10, weight: .medium) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(10, weight: .medium) }
        return .system(size: 10, weight: .medium, design: .rounded)
    }
}

private enum ProfileRecentPlaysVariant {
    case standard
    case manga
    case neumorphic
    case capsule
    case signal
    case sequoia
}

private struct SignalProfilePulseStrip: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(index < 12 ? tint.opacity(0.82) : SignalStyle.inkMuted.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4 + CGFloat(index % 5))
            }
        }
        .padding(12)
        .background(SignalScreenBackground(cornerRadius: 18))
    }
}

private struct ProfileRecentPlaysHost: View {
    let variant: ProfileRecentPlaysVariant

    @State private var history = PlayerManager.shared.history
    @State private var currentSongID = PlayerManager.shared.currentSong?.id
    @State private var isPlaying = PlayerManager.shared.isPlaying

    var body: some View {
        Group {
            if !history.isEmpty {
                if PetWhiteStyle.isActive {
                    petWhiteRecentPlays(history: history)
                } else {
                switch variant {
                case .standard:
                    standardRecentPlays(history: history)
                case .manga:
                    mangaRecentPlays(history: history)
                case .neumorphic:
                    neumorphicRecentPlays(history: history)
                case .capsule:
                    capsuleRecentPlays(history: history)
                case .signal:
                    signalRecentPlays(history: history)
                case .sequoia:
                    sequoiaRecentPlays(history: history)
                }
                }
            }
        }
        .onReceive(PlayerManager.shared.$history.removeDuplicates()) { history in
            self.history = history
        }
        .onReceive(PlayerManager.shared.$currentSong.map { $0?.id }.removeDuplicates()) { currentSongID in
            self.currentSongID = currentSongID
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            self.isPlaying = isPlaying
        }
    }

    private func petWhiteRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                PetWhiteIconBadge(icon: .history, tint: PetWhiteStyle.sky, size: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "profile_recently_played"))
                        .font(PetWhiteStyle.titleFont(18, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)

                    Text(String(format: String(localized: "profile_recent_count"), history.count))
                        .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                NavigationLink(destination: RecentPlayHistoryView()) {
                    PetWhitePill(
                        text: String(localized: "view_all"),
                        tint: PetWhiteStyle.butter
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12).enumerated()), id: \.element.id) { index, song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: song.coverUrl) {
                                    PetWhiteMascotMark(kind: index.isMultiple(of: 2) ? .cat : .dog, size: 44)
                                        .frame(width: 112, height: 112)
                                        .background(PetWhiteStyle.surfacePressed)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 112, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    PetWhitePackIcon(icon: .play, size: 14, visualScale: 1.06)
                                        .frame(width: 30, height: 30)
                                        .background(PetWhiteStyle.mint, in: Circle())
                                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
                                        .padding(8)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(PetWhiteStyle.bodyFont(13, weight: .black))
                                        .foregroundStyle(PetWhiteStyle.ink)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                                        .foregroundStyle(PetWhiteStyle.inkSoft)
                                        .lineLimit(1)
                                }
                                .frame(width: 112, alignment: .leading)
                            }
                            .padding(10)
                            .background(
                                PetWhiteSurfaceBackground(
                                    cornerRadius: 22,
                                    elevated: true,
                                    tint: PetWhiteStyle.surfaceRaised,
                                    accent: PetWhiteStyle.sky
                                )
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func sequoiaRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 3, height: 18)

                Text(String(localized: "profile_recently_played"))
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                NavigationLink(destination: RecentPlayHistoryView()) {
                    SequoiaPill(
                        text: String(format: String(localized: "profile_recent_count"), history.count),
                        icon: .chevronRight,
                        tint: SequoiaStyle.aqua,
                        compact: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(15))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            SequoiaProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func capsuleRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            CapsuleSectionTitle(title: String(localized: "profile_recently_played"), tint: CapsuleStyle.cyan) {
                NavigationLink(destination: RecentPlayHistoryView()) {
                    CapsulePillLabel(
                        title: String(format: String(localized: "profile_recent_count"), history.count),
                        icon: .chevronRight,
                        tint: CapsuleStyle.cyan
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(14))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            CapsuleProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
                        }
                        .buttonStyle(CapsulePressStyle())
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func standardRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(MangaStyle.isActive ? MangaStyle.titleFont(18, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))))
                    .foregroundColor(.monoTextPrimary)

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "profile_recent_count"), history.count))
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))))
                            .foregroundColor(.monoTextSecondary)
                        MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(history.prefix(15))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: song.coverUrl, width: 110, height: 110) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.monoSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded))))
                                        .foregroundColor(.monoTextPrimary)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(11, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded))))
                                        .foregroundColor(.monoTextSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func mangaRecentPlays(history: [Song]) -> some View {
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
                        text: String(format: String(localized: "profile_recent_count"), history.count),
                        tint: MangaStyle.decoBlue,
                        small: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
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

    private func neumorphicRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                NeumorphicIconBadge(icon: .history, tint: NeumorphicStyle.sage, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "profile_recently_played"))
                        .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)

                    Text(String(format: String(localized: "profile_recent_count"), history.count))
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
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            NeumorphicProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
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

    private func signalRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SignalIconBadge(icon: .history, tint: SignalStyle.olive, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "profile_recently_played"))
                        .font(SignalStyle.titleFont(18, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)

                    Text(String(format: String(localized: "profile_recent_count"), history.count))
                        .font(SignalStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(SignalStyle.inkMuted)
                }

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    SignalPill(
                        text: String(localized: "common_view_more"),
                        tint: SignalStyle.accent,
                        icon: .chevronRight,
                        compact: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            SignalProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
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
}

private struct CapsuleProfileMetricTile: View {
    let value: String
    let label: String
    let tint: Color
    let icon: MonoIcon.IconType

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                CapsuleIconBadge(icon: icon, tint: tint, size: 32)

                Spacer(minLength: 4)

                Capsule()
                    .fill(tint.opacity(0.72))
                    .frame(width: 24, height: 7)
            }

            Text(value)
                .font(CapsuleStyle.titleFont(18, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(CapsuleStyle.labelFont(9.5, weight: .semibold))
                .foregroundStyle(CapsuleStyle.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(12)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 22,
                elevated: true,
                tint: CapsuleStyle.surfaceRaised.opacity(0.92)
            )
        )
    }
}

private struct CapsuleProfilePortalTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                CapsuleIconBadge(icon: icon, tint: tint, size: 38)

                Spacer(minLength: 8)

                Text(value)
                    .font(CapsuleStyle.labelFont(9.5, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                    )
            }

            Text(title)
                .font(CapsuleStyle.titleFont(15, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 114, alignment: .topLeading)
        .padding(14)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 26,
                elevated: true,
                tint: CapsuleStyle.surface.opacity(0.94)
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct CapsuleProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 118, height: 92) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(CapsuleStyle.surfaceTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 118, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.9), lineWidth: 1)
                )

                ZStack {
                    Capsule()
                        .fill(isPlaying ? CapsuleStyle.accent : CapsuleStyle.surfaceRaised)
                        .frame(width: 42, height: 32)
                        .shadow(color: CapsuleStyle.accent.opacity(isPlaying ? 0.18 : 0.05), radius: 8, x: 0, y: 4)

                    if isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: CapsuleStyle.readableLabel(on: CapsuleStyle.accent))
                            .frame(width: 17, height: 13)
                    } else {
                        MonoIcon(icon: .play, size: 12, color: CapsuleStyle.accent, lineWidth: 1.8)
                    }
                }
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(CapsuleStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(CapsuleStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(CapsuleStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 118, alignment: .leading)
        }
        .padding(10)
        .background(CapsuleSurfaceBackground(cornerRadius: 28, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct SequoiaProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 112, height: 112) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SequoiaStyle.materialList)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.52), lineWidth: 0.65)
                )

                if isPlaying {
                    SequoiaPill(text: "ON", tint: SequoiaStyle.accent, selected: true, compact: true)
                        .padding(7)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(SequoiaStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(SequoiaStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(SequoiaStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(8)
        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: false, role: .list))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SignalProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 112, height: 112) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SignalStyle.controlPressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                )

                if isPlaying {
                    SignalPill(text: "ON", tint: SignalStyle.olive, selected: true, compact: true)
                        .padding(7)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(SignalStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(SignalStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(8)
        .background(SignalSurfaceBackground(cornerRadius: 22, elevated: true, fill: SignalStyle.paper))
    }
}

private struct NeumorphicProfileMetricTile: View {
    let value: String
    let label: String
    let tint: Color
    let icon: MonoIcon.IconType

    var body: some View {
        HStack(spacing: 8) {
            MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.55)
                .frame(width: 28, height: 28)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 10,
                        elevated: false,
                        pressed: true,
                        tint: tint.opacity(0.16),
                        lightweight: true
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(NeumorphicStyle.titleFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(label)
                    .font(NeumorphicStyle.labelFont(8.5, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: true, lightweight: true))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.28), lineWidth: 0.7)
        }
    }
}

private struct NeumorphicProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 118, height: 94) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 118, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                }

                ZStack {
                    Circle()
                        .fill(NeumorphicStyle.surfaceRaised)
                        .frame(width: 32, height: 32)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true, lightweight: true))
                        .clipShape(Circle())

                    if isPlaying {
                        PlayingVisualizerView(isAnimating: true, color: NeumorphicStyle.accent)
                            .frame(width: 16, height: 13)
                    } else {
                        MonoIcon(icon: .play, size: 11, color: NeumorphicStyle.accent, lineWidth: 1.7)
                    }
                }
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(NeumorphicStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(NeumorphicStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 118, alignment: .leading)
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct NeumorphicProfileShortcutTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                MonoIcon(icon: icon, size: 17, color: tint, lineWidth: 1.55)
                    .frame(width: 38, height: 38)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 14,
                            elevated: false,
                            pressed: true,
                            tint: tint.opacity(0.15),
                            lightweight: true
                        )
                    )

                Spacer(minLength: 8)

                MonoIcon(icon: .chevronRight, size: 12, color: NeumorphicStyle.inkMuted, lineWidth: 1.6)
                    .frame(width: 28, height: 28)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 10, elevated: false, pressed: true, lightweight: true))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(NeumorphicStyle.labelFont(14, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Text(value)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(14)
        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.28), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PetWhiteProfileMetricPill: View {
    let value: String
    let label: String
    let icon: MonoIcon.IconType
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            PetWhiteClayPuck(shape: Circle(), tint: tint)
                .frame(width: 30, height: 30)
                .overlay(
                    PetWhitePackIcon(icon: icon, size: 14, visualScale: 1.02, lineWidth: 1.6)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(PetWhiteStyle.titleFont(15, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(label)
                    .font(PetWhiteStyle.labelFont(9.5))
                    .foregroundStyle(PetWhiteStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: PetWhiteStyle.compactRadius,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
    }
}

private struct PetWhiteProfileActionTile: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                PetWhiteClayPuck(shape: Circle(), tint: tint)
                    .frame(width: 36, height: 36)
                    .overlay(
                        PetWhitePackIcon(icon: icon, size: 17, visualScale: 1.04, lineWidth: 1.7)
                    )

                Spacer(minLength: 8)

                PetWhitePackIcon(icon: .chevronRight, size: 14, visualScale: 1.02, fallbackColor: PetWhiteStyle.inkMuted)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PetWhiteStyle.bodyFont(14, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(value)
                    .font(PetWhiteStyle.labelFont(11))
                    .foregroundStyle(PetWhiteStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(14)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: PetWhiteStyle.cardRadius,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous))
    }
}

// MARK: - Menu Row

struct ProfileMenuRow: View {
    let icon: MonoIcon.IconType
    let title: String
    var trailingText: String? = nil
    var petWhiteAssetName: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            profileMenuIcon

            Text(title)
                .font(MangaStyle.isActive ? MangaStyle.comicFont(15, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(15, weight: .regular) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(15, weight: .bold) : (SignalStyle.isActive ? SignalStyle.labelFont(15, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded))))))
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : .monoTextPrimary)))

            Spacer()

            if let text = trailingText {
                Text(text)
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(13, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .regular) : .system(size: 13, weight: .regular, design: .rounded))))))
                    .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : .monoTextSecondary)))
            }
            if PetWhiteStyle.isActive {
                PetWhitePackIcon(icon: .chevronRight, size: 13, visualScale: 1.04)
                    .foregroundStyle(PetWhiteStyle.inkMuted)
            } else {
                MonoIcon(icon: .chevronRight, size: 13, color: CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : .monoTextSecondary.opacity(0.4)))
            }
        }
        .padding(.horizontal, PetWhiteStyle.isActive ? 14 : (CapsuleStyle.isActive ? 14 : 18))
        .padding(.vertical, CapsuleStyle.isActive ? 12 : 14)
        .background {
            if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(
                    cornerRadius: 18,
                    elevated: false,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: PetWhiteStyle.mint
                )
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 22, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.78))
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var profileMenuIcon: some View {
        if MangaStyle.isActive {
            MonoIcon(
                icon: icon,
                size: 15,
                color: ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk),
                lineWidth: 1.8
            )
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).fill(MangaStyle.labelYellow))
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.6))
                .background(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 1.8, y: 1.8))
        } else if PetWhiteStyle.isActive {
            if let petWhiteAssetName {
                petWhiteAssetBadge(assetName: petWhiteAssetName, tint: PetWhiteStyle.sky, size: 36)
            } else {
                PetWhiteIconBadge(icon: icon, tint: icon == .settings ? PetWhiteStyle.mint : PetWhiteStyle.sky, size: 36)
            }
        } else if MujiStyle.isActive {
            Circle()
                .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.25))
                .frame(width: 31, height: 31)
                .overlay(MonoIcon(icon: icon, size: 14, color: MujiStyle.clay, lineWidth: 1.5))
        } else if NeumorphicStyle.isActive {
            NeumorphicIconBadge(icon: icon, tint: NeumorphicStyle.accent, size: 32)
        } else if CapsuleStyle.isActive {
            CapsuleIconBadge(icon: icon, tint: CapsuleStyle.accent, size: 34)
        } else if SignalStyle.isActive {
            SignalIconBadge(icon: icon, tint: SignalStyle.accent, size: 32)
        } else {
            MonoIcon(icon: icon, size: 18, color: .monoTextPrimary)
                .frame(width: 28, height: 28)
        }
    }

    private func petWhiteAssetBadge(assetName: String, tint: Color, size: CGFloat) -> some View {
        PetWhiteClayPuck(
            shape: RoundedRectangle(cornerRadius: max(13, size * 0.34), style: .continuous),
            tint: tint
        )
        .frame(width: size, height: size)
        .overlay(
            PetWhiteSelectedLyricToggleIcon(assetName: assetName, size: size * 0.66)
        )
    }
}

private struct MangaProfileInfoPill: View {
    let text: String
    let tint: Color

    var body: some View {
        // 印刷角标:矩形色块 + 墨线 + 可读前景
        Text(text)
            .font(MangaStyle.labelFont(10, weight: .black))
            .foregroundStyle(
                ThemeColorCustomization.readableForegroundColor(on: tint, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
            )
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(tint)
            )
    }
}

private struct MangaProfileActionRow: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            MonoIcon(
                icon: icon,
                size: 16,
                color: ThemeColorCustomization.readableForegroundColor(on: tint, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk),
                lineWidth: 1.8
            )
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .fill(tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MangaStyle.comicFont(14, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(value)
                    .font(MangaStyle.comicFont(11, weight: .bold))
                    .foregroundStyle(MangaStyle.inkSub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            MonoIcon(icon: .chevronRight, size: 13, color: MangaStyle.inkSub, lineWidth: 1.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct MangaProfileActionDivider: View {
    var body: some View {
        Rectangle()
            .fill(MangaStyle.strokeInk.opacity(0.12))
            .frame(height: 1)
            .padding(.leading, 60)
            .padding(.trailing, 14)
    }
}

private struct MangaProfileRecentCard: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: song.coverUrl, width: 112, height: 112) {
                RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous)
                    .fill(MangaStyle.bubbleWhite)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous).stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(MangaStyle.comicFont(13, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(MangaStyle.comicFont(11, weight: .bold))
                    .foregroundStyle(MangaStyle.inkSub)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
    }
}

private struct MujiProfileLedgerRow: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 13) {
            MonoIcon(icon: icon, size: 15, color: tint, lineWidth: 1.4)
                .frame(width: 22, alignment: .leading)

            Text(title)
                .font(MujiStyle.bodyFont(15, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(value)
                .font(MujiStyle.labelFont(10, weight: .semibold))
                .foregroundStyle(MujiStyle.inkMuted)
                .tracking(1.1)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            MonoIcon(icon: .chevronRight, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.4)
        }
        .padding(.vertical, 13.5)
        .contentShape(Rectangle())
    }

    private var tint: Color {
        switch icon {
        case .cloud:
            return MujiStyle.tea
        case .download:
            return MujiStyle.indigo
        case .storage:
            return MujiStyle.straw
        default:
            return MujiStyle.clay
        }
    }
}

private struct MujiProfileDivider: View {
    var body: some View {
        MujiListDivider()
            .padding(.leading, 35)
    }
}

private extension View {
    @ViewBuilder
    func themedProfileSurface(cornerRadius: CGFloat, mangaTint: Color = MangaStyle.bubbleWhite) -> some View {
        if MangaStyle.isActive {
            background(MangaCardBackground(cornerRadius: cornerRadius, elevated: true, tint: mangaTint))
        } else if PetWhiteStyle.isActive {
            background(
                PetWhiteSurfaceBackground(
                    cornerRadius: cornerRadius,
                    elevated: true,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: PetWhiteStyle.mint
                )
            )
        } else if MujiStyle.isActive {
            // Muji：清新水洗底，柔圆角不描边
            background(
                RoundedRectangle(cornerRadius: max(cornerRadius, MujiStyle.cardRadius), style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
            )
        } else if NeumorphicStyle.isActive {
            background(NeumorphicSurfaceBackground(cornerRadius: cornerRadius, elevated: true, lightweight: true))
        } else if CapsuleStyle.isActive {
            background(CapsuleSurfaceBackground(cornerRadius: min(max(cornerRadius, 22), 30), elevated: true, tint: CapsuleStyle.surface.opacity(0.94)))
        } else if SignalStyle.isActive {
            background(SignalSurfaceBackground(cornerRadius: min(max(cornerRadius, 18), 28), elevated: true, fill: SignalStyle.device))
        } else if SequoiaStyle.isActive {
            background(SequoiaSurfaceBackground(cornerRadius: min(max(cornerRadius, 16), 22), elevated: true, role: .chrome))
        } else if LiquidGlassStyle.isActive {
            background(LiquidGlassSurfaceBackground(cornerRadius: min(max(cornerRadius, 18), 28), elevated: true, role: .chrome))
        } else {
            monoGlass(cornerRadius: cornerRadius)
        }
    }
}

private struct LiquidGlassProfileLensShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let width = rect.width
        let height = rect.height

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + width * 0.12, y: rect.minY + height * 0.05))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.88, y: rect.minY + height * 0.02),
            control1: CGPoint(x: rect.minX + width * 0.32, y: rect.minY - height * 0.02),
            control2: CGPoint(x: rect.minX + width * 0.64, y: rect.minY + height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.98, y: rect.minY + height * 0.72),
            control1: CGPoint(x: rect.maxX + width * 0.02, y: rect.minY + height * 0.12),
            control2: CGPoint(x: rect.maxX - width * 0.02, y: rect.minY + height * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.62, y: rect.minY + height * 0.98),
            control1: CGPoint(x: rect.maxX - width * 0.04, y: rect.maxY + height * 0.03),
            control2: CGPoint(x: rect.minX + width * 0.78, y: rect.maxY - height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.04, y: rect.minY + height * 0.78),
            control1: CGPoint(x: rect.minX + width * 0.35, y: rect.maxY + height * 0.02),
            control2: CGPoint(x: rect.minX - width * 0.02, y: rect.maxY - height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.12, y: rect.minY + height * 0.05),
            control1: CGPoint(x: rect.minX + width * 0.0, y: rect.minY + height * 0.52),
            control2: CGPoint(x: rect.minX - width * 0.01, y: rect.minY + height * 0.16)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> LiquidGlassProfileLensShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - Quick Action Card (kept for potential reuse)

struct QuickActionCard: View {
    let icon: MonoIcon.IconType
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 10) {
                MonoIcon(icon: icon, size: 22, color: .monoTextPrimary)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .monoGlass(cornerRadius: 20)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
    }
}

// MARK: - Profile Menu Item (kept for backward compatibility)

struct ProfileMenuItem: View {
    let icon: MonoIcon.IconType
    let title: String
    var trailing: TrailingType = .chevron
    var action: (() -> Void)? = nil

    enum TrailingType {
        case chevron
        case text(String)
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                MonoIcon(icon: icon, size: 20, color: .monoTextPrimary)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.monoTextPrimary)

                Spacer()

                switch trailing {
                case .chevron:
                    MonoIcon(icon: .chevronRight, size: 14, color: .monoTextSecondary.opacity(0.5))
                case let .text(value):
                    Text(value)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                    MonoIcon(icon: .chevronRight, size: 14, color: .monoTextSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
    }
}
