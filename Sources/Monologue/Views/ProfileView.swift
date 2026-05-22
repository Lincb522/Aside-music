import Combine
import QQMusicKit
import SwiftUI

private struct ThemedProfileBackground: View {
    var body: some View {
        ThemedPageBackground(useRenderLayer: true)
    }
}

struct ProfileView: View {
    @ObservedObject private var settings = SettingsManager.shared

    private var viewModel: HomeViewModel {
        HomeViewModel.shared
    }

    private var playerManager: PlayerManager {
        PlayerManager.shared
    }

    @AppStorage("isLoggedIn") private var isAppLoggedIn = false

    @State private var showLoginView = false
    @State private var showQQAccount = false
    @State private var cachedProfile: UserProfile?
    @State private var hasAppeared = false

    @State private var userLevel: Int?
    @State private var listenSongs: Int?

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
            if isAppLoggedIn {
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
        .fullScreenCover(isPresented: $showLoginView) {
            LoginView()
        }
    }

    // MARK: - Logged In

    private var loggedInContent: some View {
        NavigationStack {
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
            .navigationTitle(ThemedPageStyle.isActive ? "" : String(localized: "我的"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !ThemedPageStyle.isActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(
                            destination: SettingsView()
                        ) {
                            MonologueIcon(icon: .settings, size: 16)
                        }
                    }
                }
            }
        }
    }

    private var themedProfileSpacing: CGFloat {
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
        if MangaStyle.isActive {
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
            profileHeroCard
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            statsBar
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ProfileRecentPlaysHost(variant: .standard)

            menuList
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            logoutButton
        }
    }

    // MARK: - Hero Card

    private var mangaProfileHeader: some View {
        MangaPageHeader(
            eyebrow: "PROFILE",
            title: String(localized: "我的"),
            subtitle: ""
        ) {
            NavigationLink(destination: SettingsView()) {
                MangaIconBadge(icon: .settings, size: 48, tint: MangaStyle.decoBlue)
            }
            .buttonStyle(.plain)
        }
    }

    private var mujiProfileHeader: some View {
        MujiPageHeader(
            eyebrow: "listening notebook",
            title: String(localized: "我的"),
            subtitle: ""
        ) {
            NavigationLink(destination: SettingsView()) {
                MujiIconBadge(icon: .settings, tint: MujiStyle.indigo, size: 48)
            }
            .buttonStyle(.plain)
        }
    }

    private var neumorphicProfileHeader: some View {
        NeumorphicPageHeader(
            eyebrow: "profile",
            title: String(localized: "我的"),
            subtitle: ""
        ) {
            NavigationLink(destination: SettingsView()) {
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

                NavigationLink(destination: SettingsView()) {
                    PetWhiteIconBadge(icon: .settings, tint: PetWhiteStyle.sky, size: 48)
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
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

            HStack(spacing: 8) {
                Capsule().fill(PetWhiteStyle.dogOrange).frame(width: 54, height: 6)
                Capsule().fill(PetWhiteStyle.mint).frame(width: 34, height: 6)
                Capsule().fill(PetWhiteStyle.sky).frame(width: 20, height: 6)
                Spacer(minLength: 0)
                PetWhiteProfileHeadIcon(filled: true, size: 26)
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
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(PetWhiteStyle.stroke, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(PetWhiteStyle.stroke.opacity(0.12))
                .offset(y: 4)
        )
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
                NavigationLink(destination: DownloadManageView()) {
                    PetWhiteProfileActionTile(
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: String(format: String(localized: "profile_recent_count"), downloadedSongCount),
                        tint: PetWhiteStyle.sky
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))

                NavigationLink(destination: ListeningStatsView()) {
                    PetWhiteProfileActionTile(
                        icon: .headphones,
                        title: String(localized: "听歌统计"),
                        value: formatNumber(listenSongs ?? 0),
                        tint: PetWhiteStyle.dogOrange
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))

                NavigationLink(destination: StorageManageView()) {
                    PetWhiteProfileActionTile(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: String(localized: "缓存"),
                        tint: PetWhiteStyle.mint
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))

                NavigationLink(destination: CloudDiskView()) {
                    PetWhiteProfileActionTile(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: ""),
                        value: "Cloud",
                        tint: PetWhiteStyle.lilac
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
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
                Button(action: { showQQAccount = true }) {
                    ProfileMenuRow(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        trailingText: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in"),
                        petWhiteAssetName: "qqAccount"
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                .monologueSheet(isPresented: $showQQAccount, preset: .large) {
                    NavigationStack {
                        QQAccountView()
                    }
                }

                NavigationLink(destination: SettingsView()) {
                    ProfileMenuRow(
                        icon: .settings,
                        title: NSLocalizedString("profile_settings", comment: "")
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
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
                Task { @MainActor in
                    do {
                        _ = try await APIService.shared.logout().async()
                    } catch {
                        APIService.shared.currentCookie = nil
                        OptimizedCacheManager.shared.clearAll()
                    }
                    isAppLoggedIn = false
                    cachedProfile = nil
                    hasAppeared = false
                    userLevel = nil
                    listenSongs = nil
                    playerManager.clearPlaybackHistory()
                    AlertManager.shared.dismiss()
                }
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
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
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

                Text(String(localized: "我的"))
                    .font(NeumorphicStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
            }

            Spacer(minLength: 8)

            NavigationLink(destination: SettingsView()) {
                MonologueIcon(icon: .settings, size: 17, color: NeumorphicStyle.accent, lineWidth: 1.55)
                    .frame(width: 44, height: 44)
                    .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true, lightweight: true))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
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
            title: String(localized: "我的")
        ) {
            NavigationLink(destination: SettingsView()) {
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
                MonologueIcon(
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
            Button { showQQAccount = true } label: {
                CapsuleProfilePortalTile(
                    icon: .musicNote,
                    title: String(localized: "settings_qq_account"),
                    value: QQUserSession.shared.isLoggedIn ? String(localized: "settings_qq_logged_in") : String(localized: "settings_qq_not_logged_in"),
                    tint: CapsuleStyle.accent
                )
            }
            .buttonStyle(CapsulePressStyle())
            .monologueSheet(isPresented: $showQQAccount, preset: .large) {
                NavigationStack {
                    QQAccountView()
                }
            }

            NavigationLink(destination: DownloadManageView()) {
                CapsuleProfilePortalTile(
                    icon: .download,
                    title: NSLocalizedString("profile_downloads", comment: ""),
                    value: "\(downloadedSongCount)",
                    tint: CapsuleStyle.amber
                )
            }
            .buttonStyle(CapsulePressStyle())

            NavigationLink(destination: ListeningStatsView()) {
                CapsuleProfilePortalTile(
                    icon: .sparkle,
                    title: String(localized: "听歌统计"),
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

                Text(String(localized: "我的"))
                    .font(SignalStyle.titleFont(24, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
            }

            Spacer(minLength: 8)

            NavigationLink(destination: SettingsView()) {
                MonologueIcon(icon: .settings, size: 17, color: SignalStyle.accent, lineWidth: 1.55)
                    .frame(width: 42, height: 42)
                    .background(SignalSurfaceBackground(cornerRadius: 11, elevated: true, fill: SignalStyle.control))
                    .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
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

                Text(String(localized: "我的"))
                    .font(SequoiaStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
            }

            Spacer(minLength: 8)

            SequoiaMeter(tint: SequoiaStyle.accent, count: 8)
                .padding(.horizontal, 8)
                .padding(.vertical, 9)
                .background(SequoiaSurfaceBackground(cornerRadius: 15, elevated: false, role: .list))

            NavigationLink(destination: SettingsView()) {
                SequoiaControlButton(icon: .settings, tint: SequoiaStyle.accent, size: 40)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
        .padding(14)
        .background(SequoiaChromeBar(cornerRadius: 23))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
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

                Text(String(localized: "我的"))
                    .font(LiquidGlassStyle.titleFont(28, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 10)

            NavigationLink(destination: SettingsView()) {
                LiquidGlassIconBadge(icon: .settings, tint: LiquidGlassStyle.accent, size: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
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
        icon: MonologueIcon.IconType
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.5)
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
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
            Button { showQQAccount = true } label: {
                liquidGlassProfilePortalTile(
                    icon: .musicNote,
                    title: String(localized: "settings_qq_account"),
                    value: QQUserSession.shared.isLoggedIn ? String(localized: "settings_qq_logged_in") : String(localized: "settings_qq_not_logged_in"),
                    tint: LiquidGlassStyle.accent
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: DownloadManageView()) {
                liquidGlassProfilePortalTile(
                    icon: .download,
                    title: NSLocalizedString("profile_downloads", comment: ""),
                    value: "\(downloadedSongCount)",
                    tint: LiquidGlassStyle.amber
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ListeningStatsView()) {
                liquidGlassProfilePortalTile(
                    icon: .sparkle,
                    title: String(localized: "听歌统计"),
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
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack {
                QQAccountView()
            }
        }
    }

    private func liquidGlassProfilePortalTile(
        icon: MonologueIcon.IconType,
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

                Text(String(localized: "我的"))
                    .font(LiquidGlassStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 8)

            NavigationLink(destination: SettingsView()) {
                LiquidGlassIconBadge(icon: .settings, tint: LiquidGlassStyle.accent, size: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
        .padding(14)
        .background(LiquidGlassChromeBar(cornerRadius: 24))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
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
                .overlay(MonologueIcon(icon: .profileFilled, size: size * 0.36, color: LiquidGlassStyle.accent, lineWidth: 1.55))
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

                    Text(signature.isEmpty ? String(localized: "mono") : signature)
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
                .overlay(MonologueIcon(icon: .profile, size: size * 0.38, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
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
                MonologueIcon(icon: .profileFilled, size: size * 0.36, color: SignalStyle.accent, lineWidth: 1.75)
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
                    .overlay(MonologueIcon(icon: .profileFilled, size: size * 0.36, color: NeumorphicStyle.inkMuted))
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
                        text: String(localized: "查看更多"),
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
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
                Button(action: { showQQAccount = true }) {
                    NeumorphicProfileShortcutTile(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        value: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in"),
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: DownloadManageView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: String(format: String(localized: "profile_recent_count"), downloadedSongCount),
                        tint: NeumorphicStyle.warm
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: ListeningStatsView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .sparkle,
                        title: String(localized: "听歌统计"),
                        value: "STATS",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))


                NavigationLink(destination: ListeningStatsView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .sparkle,
                        title: String(localized: "听歌统计"),
                        value: "STATS",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                NavigationLink(destination: StorageManageView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE",
                        tint: NeumorphicStyle.sage
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: CloudDiskView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: ""),
                        value: "CLOUD",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            }
        }
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack {
                QQAccountView()
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
                        Text(LocalizedStringKey("profile_not_logged_in"))
                            .font(MangaStyle.comicFont(24, weight: .black))
                            .foregroundStyle(MangaStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

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

            Button(action: { showLoginView = true }) {
                HStack(spacing: 10) {
                    MonologueIcon(icon: .profileFilled, size: 16, color: MangaStyle.strokeInk, lineWidth: 1.85)

                    Text(LocalizedStringKey("profile_login_button"))
                        .font(MangaStyle.comicFont(15, weight: .black))
                        .foregroundStyle(MangaStyle.strokeInk)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MangaStyle.labelYellow)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 2.6, y: 2.6)
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

            HStack(spacing: 8) {
                MangaLabel(text: "NCM", tint: MangaStyle.bubblePink, small: true)
                MangaLabel(text: "QCM", tint: MangaStyle.decoBlue, small: true)
                MangaLabel(text: "LOCAL", tint: MangaStyle.mint, small: true)
                Spacer(minLength: 0)
                MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 24)
            }
        }
        .padding(16)
        .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: MangaStyle.paperWarm))
    }

    private var mangaGuestActionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "profile_settings"), mark: .heart)

            VStack(spacing: 0) {
                Button {
                    showQQAccount = true
                } label: {
                    MangaProfileActionRow(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        value: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in"),
                        tint: MangaStyle.labelYellow
                    )
                }
                .buttonStyle(.plain)

                MangaProfileActionDivider()

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


                MangaProfileActionDivider()

                NavigationLink(destination: ListeningStatsView()) {
                    MangaProfileActionRow(
                        icon: .sparkle,
                        title: String(localized: "听歌统计"),
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

                NavigationLink(destination: SettingsView()) {
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
            .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: MangaStyle.bubbleWhite))
        }
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack {
                QQAccountView()
            }
        }
    }

    private var mangaNotLoggedInContent: some View {
        NavigationStack {
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
        }
    }

    private var mujiGuestJournalPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                mujiAvatar(profile: nil, size: 76)

                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("profile_not_logged_in"))
                        .font(MujiStyle.titleFont(24, weight: .regular))
                        .foregroundStyle(MujiStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(LocalizedStringKey("profile_login_hint"))
                        .font(MujiStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(MujiStyle.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    MujiPill(text: "GUEST", tint: MujiStyle.tea)
                }

                Spacer(minLength: 0)
            }

            Button(action: { showLoginView = true }) {
                HStack(spacing: 9) {
                    MonologueIcon(icon: .profileFilled, size: 15, color: MujiStyle.onTint, lineWidth: 1.45)

                    Text(LocalizedStringKey("profile_login_button"))
                        .font(MujiStyle.labelFont(15, weight: .medium))
                        .foregroundStyle(MujiStyle.onTint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(MujiStyle.clay, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.22), lineWidth: 0.6)
                )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
        }
        .padding(16)
        .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
    }

    private var mujiGuestLedger: some View {
        VStack(alignment: .leading, spacing: 14) {
            MujiSectionTitle(title: String(localized: "profile_settings"))

            VStack(spacing: 0) {
                Button(action: { showQQAccount = true }) {
                    MujiProfileLedgerRow(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        value: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in")
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: DownloadManageView()) {
                    MujiProfileLedgerRow(
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: "\(downloadedSongCount)"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: ListeningStatsView()) {
                    MujiProfileLedgerRow(
                        icon: .sparkle,
                        title: String(localized: "听歌统计"),
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

                NavigationLink(destination: SettingsView()) {
                    MujiProfileLedgerRow(
                        icon: .settings,
                        title: NSLocalizedString("profile_settings", comment: ""),
                        value: "SYSTEM"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(MujiPaperCardBackground(cornerRadius: 12, elevated: false))
        }
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack {
                QQAccountView()
            }
        }
    }

    private var mujiNotLoggedInContent: some View {
        NavigationStack {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        mujiProfileHeader

                        mujiGuestJournalPanel
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        mujiGuestLedger
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

                    MonologueIcon(icon: .profileFilled, size: 34, color: NeumorphicStyle.inkMuted, lineWidth: 1.45)
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

            Button(action: { showLoginView = true }) {
                HStack(spacing: 10) {
                    MonologueIcon(icon: .profile, size: 16, color: Color(light: .white, dark: .black), lineWidth: 1.55)
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
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

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
                Button(action: { showQQAccount = true }) {
                    NeumorphicProfileShortcutTile(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        value: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in"),
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: DownloadManageView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: String(format: String(localized: "profile_recent_count"), downloadedSongCount),
                        tint: NeumorphicStyle.warm
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: ListeningStatsView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .sparkle,
                        title: String(localized: "听歌统计"),
                        value: "STATS",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: StorageManageView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "CACHE",
                        tint: NeumorphicStyle.sage
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

                NavigationLink(destination: SettingsView()) {
                    NeumorphicProfileShortcutTile(
                        icon: .settings,
                        title: NSLocalizedString("profile_settings", comment: ""),
                        value: "SYSTEM",
                        tint: NeumorphicStyle.accent
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
            }
        }
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack {
                QQAccountView()
            }
        }
    }

    private var neumorphicNotLoggedInContent: some View {
        NavigationStack {
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
        }
    }

    @ViewBuilder
    private var mujiProfileDashboard: some View {
        mujiProfileHeader

        mujiProfileJournalPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        statsBar
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .standard)

        mujiProfileLedger
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        logoutButton
    }

    private var mangaProfileHeroPanel: some View {
        let profile = cachedProfile ?? viewModel.userProfile

        return HStack(alignment: .center, spacing: 14) {
            mangaAvatar(profile: profile, size: 76)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MangaStyle.comicFont(24, weight: .black))
                        .foregroundStyle(MangaStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

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

            NavigationLink(destination: SettingsView()) {
                MonologueIcon(icon: .settings, size: 18, color: MangaStyle.strokeInk, lineWidth: 1.9)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(MangaStyle.bubbleWhite.opacity(0.94))
                    )
                    .overlay(
                        Circle()
                            .stroke(MangaStyle.strokeInk.opacity(0.58), lineWidth: MangaStyle.fineStrokeWidth)
                    )
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        }
        .padding(.vertical, 4)
    }

    private var mangaProfileActionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "profile_settings"), mark: .heart)

            VStack(spacing: 0) {
                Button {
                    showQQAccount = true
                } label: {
                    MangaProfileActionRow(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        value: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in"),
                        tint: MangaStyle.labelYellow
                    )
                }
                .buttonStyle(.plain)

                MangaProfileActionDivider()

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

                NavigationLink(destination: ListeningStatsView()) {
                    MangaProfileActionRow(
                        icon: .sparkle,
                        title: String(localized: "听歌统计"),
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
            .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: MangaStyle.bubbleWhite))
        }
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack {
                QQAccountView()
            }
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

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                mujiAvatar(profile: profile, size: 76)

                VStack(alignment: .leading, spacing: 7) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MujiStyle.titleFont(24, weight: .regular))
                        .foregroundStyle(MujiStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if let signature = profile?.signature, !signature.isEmpty {
                        Text(signature)
                            .font(MujiStyle.labelFont(12, weight: .regular))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        if let level = userLevel {
                            MujiPill(text: "Lv.\(level)", tint: MujiStyle.clay)
                        }
                        MujiPill(text: formatNumber(listenSongs ?? 0), tint: MujiStyle.tea)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
    }

    private var mujiProfileLedger: some View {
        VStack(alignment: .leading, spacing: 14) {
            MujiSectionTitle(title: String(localized: "profile_settings"))

            VStack(spacing: 0) {
                Button(action: { showQQAccount = true }) {
                    MujiProfileLedgerRow(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        value: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in")
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: DownloadManageView()) {
                    MujiProfileLedgerRow(
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: "\(downloadedSongCount)"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: ListeningStatsView()) {
                    MujiProfileLedgerRow(
                        icon: .sparkle,
                        title: String(localized: "听歌统计"),
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
            .background(MujiPaperCardBackground(cornerRadius: 12, elevated: false))
        }
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack {
                QQAccountView()
            }
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 3, y: 3))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MangaStyle.bubbleWhite)
                .frame(width: size, height: size)
                .overlay(MonologueIcon(icon: .profile, size: size * 0.42, color: MangaStyle.strokeInk))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 3, y: 3))
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
                .overlay(MonologueIcon(icon: .profile, size: size * 0.42, color: MujiStyle.inkMuted))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.58), lineWidth: 0.7))
        }
    }

    private var profileHeroCard: some View {
        let profile = cachedProfile ?? viewModel.userProfile

        return HStack(spacing: 16) {
            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize) {
                    Circle().fill(Color.monologueSeparator)
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
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 2))
            } else {
                Circle()
                    .fill(Color.monologueSeparator)
                    .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                    .overlay(
                        MonologueIcon(icon: .profile, size: 30, color: .monologueTextSecondary.opacity(0.4))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MangaStyle.isActive ? MangaStyle.comicFont(22, weight: .bold) : (PetWhiteStyle.isActive ? PetWhiteStyle.titleFont(22, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(22, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(22, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(21, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(21, weight: .semibold) : .system(size: 20, weight: .bold, design: .rounded)))))))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : .monologueTextPrimary)
                        .lineLimit(1)

                    if let level = userLevel {
                        Text("Lv.\(level)")
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(10, weight: .bold) : (PetWhiteStyle.isActive ? PetWhiteStyle.labelFont(10, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(10, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(10, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(10, weight: .semibold) : .system(size: 10, weight: .bold, design: .rounded)))))))
                            .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.stroke : .monologueIconForeground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(PetWhiteStyle.isActive ? PetWhiteStyle.mint : Color.monologueIconBackground)
                            .clipShape(Capsule())
                    }
                }

                if let signature = profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(MangaStyle.isActive ? MangaStyle.comicFont(12, weight: .medium) : (PetWhiteStyle.isActive ? PetWhiteStyle.bodyFont(12, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded)))))))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : .monologueTextSecondary)
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
            .padding(14)
            .background(MangaCardBackground(cornerRadius: 12, elevated: true))
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
            .background(PetWhiteSurfaceBackground(cornerRadius: 20, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        } else if MujiStyle.isActive {
            HStack(spacing: 10) {
                MujiMetricTile(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs"),
                    tint: MujiStyle.clay
                )
                MujiMetricTile(
                    value: "\(localPlaylistCount)",
                    label: String(localized: "profile_local_playlists"),
                    tint: MujiStyle.tea
                )
                MujiMetricTile(
                    value: "\(downloadedSongCount)",
                    label: String(localized: "profile_downloads"),
                    tint: MujiStyle.indigo
                )
            }
            .padding(14)
            .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
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
            .monologueGlass(cornerRadius: 18)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PetWhiteStyle.isActive ? PetWhiteStyle.separator : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.68) : (SignalStyle.isActive ? SignalStyle.separator.opacity(0.7) : (SequoiaStyle.isActive ? SequoiaStyle.separator.opacity(0.9) : (LiquidGlassStyle.isActive ? LiquidGlassStyle.separator.opacity(0.82) : Color.monologueSeparator)))))
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Recent Plays

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(18, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(
                    destination: RecentPlayHistoryView()
                ) {
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "profile_recent_count"), playerManager.history.count))
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))))
                            .foregroundColor(.monologueTextSecondary)
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary)
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
                                        .fill(Color.monologueSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded))))
                                        .foregroundColor(.monologueTextPrimary)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(11, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded))))
                                        .foregroundColor(.monologueTextSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
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
            }

            VStack(spacing: 0) {
                Button(action: { showQQAccount = true }) {
                    ProfileMenuRow(
                        icon: .musicNote,
                        title: String(localized: "settings_qq_account"),
                        trailingText: QQUserSession.shared.isLoggedIn
                            ? String(localized: "settings_qq_logged_in")
                            : String(localized: "settings_qq_not_logged_in")
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                .monologueSheet(isPresented: $showQQAccount, preset: .large) {
                    NavigationStack {
                        QQAccountView()
                    }
                }

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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(
                    destination: ListeningStatsView()
                ) {
                    ProfileMenuRow(
                        icon: .sparkle,
                        title: String(localized: "听歌统计")
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(
                    destination: StorageManageView()
                ) {
                    ProfileMenuRow(
                        icon: .storage,
                        title: String(localized: "profile_cache_manage")
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                Divider().padding(.leading, 56)

                NavigationLink(
                    destination: CloudDiskView()
                ) {
                    ProfileMenuRow(
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: "")
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            }
            .themedProfileSurface(cornerRadius: PetWhiteStyle.isActive ? PetWhiteStyle.cardRadius : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (SignalStyle.isActive ? 24 : (NeumorphicStyle.isActive ? 20 : (SequoiaStyle.isActive ? 18 : 20))))), mangaTint: MangaStyle.bubbleWhite)
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button(action: {
            AlertManager.shared.show(
                title: NSLocalizedString("alert_logout_title", comment: ""),
                message: NSLocalizedString("alert_logout_message", comment: ""),
                primaryButtonTitle: NSLocalizedString("alert_logout_confirm", comment: ""),
                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
            ) {
                Task { @MainActor in
                    do {
                        _ = try await APIService.shared.logout().async()
                    } catch {
                        APIService.shared.currentCookie = nil
                        OptimizedCacheManager.shared.clearAll()
                    }
                    isAppLoggedIn = false
                    cachedProfile = nil
                    hasAppeared = false
                    userLevel = nil
                    listenSongs = nil
                    playerManager.clearPlaybackHistory()
                    AlertManager.shared.dismiss()
                }
            }
        }) {
            Text(LocalizedStringKey("action_logout"))
                .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (PetWhiteStyle.isActive ? PetWhiteStyle.labelFont(13, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded)))))
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : .monologueTextSecondary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - Not Logged In

    @ViewBuilder
    private var notLoggedInContent: some View {
        if MangaStyle.isActive {
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
        } else {
            NavigationStack {
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
                                    .fill(Color.monologueGlassTint)
                                    .monologueGlassCircle()
                                    .frame(width: 100, height: 100)

                                MonologueIcon(icon: .profile, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            }

                            VStack(spacing: 10) {
                                Text(LocalizedStringKey("profile_not_logged_in"))
                                    .font(MangaStyle.isActive ? MangaStyle.comicFont(26, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(26, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(26, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(25, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(25, weight: .semibold) : .system(size: 26, weight: .bold, design: .rounded))))))
                                    .foregroundColor(.monologueTextPrimary)

                                Text(LocalizedStringKey("profile_login_hint"))
                                    .font(MangaStyle.isActive ? MangaStyle.comicFont(14, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(14, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .system(size: 14, weight: .medium, design: .rounded))))))
                                    .foregroundColor(.monologueTextSecondary)
                            }

                            Button(action: { showLoginView = true }) {
                                Text(LocalizedStringKey("profile_login_button"))
                                    .font(MangaStyle.isActive ? MangaStyle.comicFont(16, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(16, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(16, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(16, weight: .semibold) : .system(size: 16, weight: .bold, design: .rounded)))))
                                    .foregroundColor(MangaStyle.isActive ? MangaStyle.strokeInk : (MujiStyle.isActive ? MujiStyle.onTint : (NeumorphicStyle.isActive ? Color(light: .white, dark: .black) : (SignalStyle.isActive ? SignalStyle.onAccent : .monologueIconForeground))))
                                    .frame(width: 200)
                                    .padding(.vertical, 15)
                                    .background {
                                        if MangaStyle.isActive {
                                            Capsule()
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
                                                .fill(Color.monologueIconBackground)
                                        }
                                    }
                                    .overlay {
                                        if MangaStyle.isActive {
                                            Capsule()
                                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                                        }
                                    }
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                        }
                        .padding(ThemedPageStyle.isActive ? 24 : 0)
                        .background {
                            if MangaStyle.isActive {
                                MangaCardBackground(cornerRadius: 12, elevated: true)
                            } else if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true)
                            } else if SignalStyle.isActive {
                                SignalSurfaceBackground(cornerRadius: 16, elevated: true, fill: SignalStyle.device)
                            } else if MujiStyle.isActive {
                                MujiPaperCardBackground(cornerRadius: 12, elevated: true)
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, fill: SequoiaStyle.material)
                            }
                        }
                        .padding(.horizontal, ThemedPageStyle.isActive ? DeviceLayout.homeHorizontalPadding : 0)

                        Spacer()

                        VStack(spacing: 0) {
                            Button(action: { showQQAccount = true }) {
                                ProfileMenuRow(
                                    icon: .musicNote,
                                    title: String(localized: "settings_qq_account"),
                                    trailingText: QQUserSession.shared.isLoggedIn
                                        ? String(localized: "settings_qq_logged_in")
                                        : String(localized: "settings_qq_not_logged_in")
                                )
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                            .monologueSheet(isPresented: $showQQAccount, preset: .large) {
                                NavigationStack {
                                    QQAccountView()
                                }
                            }

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
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                            Divider().padding(.leading, 56)

                            NavigationLink(
                                destination: ListeningStatsView()
                            ) {
                                ProfileMenuRow(
                                    icon: .sparkle,
                                    title: String(localized: "听歌统计")
                                )
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                            Divider().padding(.leading, 56)

                            NavigationLink(
                                destination: StorageManageView()
                            ) {
                                ProfileMenuRow(
                                    icon: .storage,
                                    title: String(localized: "profile_cache_manage")
                                )
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                            Divider().padding(.leading, 56)

                            NavigationLink(
                                destination: SettingsView()
                            ) {
                                ProfileMenuRow(
                                    icon: .settings,
                                    title: NSLocalizedString("profile_settings", comment: "")
                                )
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
                        }
                        .themedProfileSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 20 : (SignalStyle.isActive ? 16 : (SequoiaStyle.isActive ? 16 : 20)))), mangaTint: MangaStyle.bubbleWhite)
                        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                        .padding(.bottom, 140)
                    }
                }
                .navigationTitle(ThemedPageStyle.isActive ? "" : String(localized: "我的"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }

    private var petWhiteNotLoggedInContent: some View {
        NavigationStack {
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

                NavigationLink(destination: SettingsView()) {
                    PetWhiteIconBadge(icon: .settings, tint: PetWhiteStyle.sky, size: 48)
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }

            HStack(alignment: .center, spacing: 16) {
                PetWhitePetPetIcon(size: 96)
                    .frame(width: 96, height: 96)
                    .background(PetWhiteStyle.surfacePressed, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(PetWhiteStyle.stroke, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { showLoginView = true }) {
                        HStack(spacing: 8) {
                            PetWhitePackIcon(icon: .profileFilled, size: 16, visualScale: 1.06)
                            Text(LocalizedStringKey("profile_login_button"))
                                .font(PetWhiteStyle.labelFont(15, weight: .black))
                        }
                        .foregroundStyle(PetWhiteStyle.stroke)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(PetWhiteStyle.mint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(PetWhiteStyle.stroke, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())

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
        NavigationStack {
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

                            Button(action: { showLoginView = true }) {
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
                                Button(action: { showQQAccount = true }) {
                                    ProfileMenuRow(
                                        icon: .musicNote,
                                        title: String(localized: "settings_qq_account"),
                                        trailingText: QQUserSession.shared.isLoggedIn
                                            ? String(localized: "settings_qq_logged_in")
                                            : String(localized: "settings_qq_not_logged_in")
                                    )
                                }
                                .buttonStyle(CapsulePressStyle())
                                .monologueSheet(isPresented: $showQQAccount, preset: .large) {
                                    NavigationStack {
                                        QQAccountView()
                                    }
                                }

                                NavigationLink(destination: DownloadManageView()) {
                                    ProfileMenuRow(
                                        icon: .download,
                                        title: NSLocalizedString("profile_downloads", comment: ""),
                                        trailingText: String(format: String(localized: "profile_recent_count"), downloadedSongCount)
                                    )
                                }
                                .buttonStyle(CapsulePressStyle())

                                NavigationLink(destination: ListeningStatsView()) {
                                    ProfileMenuRow(
                                        icon: .sparkle,
                                        title: String(localized: "听歌统计")
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

                                NavigationLink(destination: SettingsView()) {
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
        }
    }

    private var liquidGlassNotLoggedInContent: some View {
        NavigationStack {
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

                            Button(action: { showLoginView = true }) {
                                HStack(spacing: 9) {
                                    MonologueIcon(icon: .profileFilled, size: 15, color: LiquidGlassStyle.onAccent, lineWidth: 1.55)
                                    Text(LocalizedStringKey("profile_login_button"))
                                        .font(LiquidGlassStyle.labelFont(15, weight: .semibold))
                                        .foregroundStyle(LiquidGlassStyle.onAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.accent, cornerRadius: 18))
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
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
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (LiquidGlassStyle.isActive ? LiquidGlassStyle.ink : .monologueTextPrimary)))

            Text(label)
                .font(labelFont)
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (LiquidGlassStyle.isActive ? LiquidGlassStyle.inkSoft : .monologueTextSecondary)))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var valueFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(18, weight: .bold) }
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
                                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
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
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(18, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "profile_recent_count"), history.count))
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))))
                            .foregroundColor(.monologueTextSecondary)
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary)
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
                                        .fill(Color.monologueSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded))))
                                        .foregroundColor(.monologueTextPrimary)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(11, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded))))
                                        .foregroundColor(.monologueTextSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
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
                        text: String(localized: "查看更多"),
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
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
                        text: String(localized: "查看更多"),
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
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
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
    let icon: MonologueIcon.IconType

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
    let icon: MonologueIcon.IconType
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
                        MonologueIcon(icon: .play, size: 12, color: CapsuleStyle.accent, lineWidth: 1.8)
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
    let icon: MonologueIcon.IconType

    var body: some View {
        HStack(spacing: 8) {
            MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.55)
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
                        MonologueIcon(icon: .play, size: 11, color: NeumorphicStyle.accent, lineWidth: 1.7)
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
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                MonologueIcon(icon: icon, size: 17, color: tint, lineWidth: 1.55)
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

                MonologueIcon(icon: .chevronRight, size: 12, color: NeumorphicStyle.inkMuted, lineWidth: 1.6)
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
    let icon: MonologueIcon.IconType
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            PetWhiteIconBadge(icon: icon, tint: tint, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(PetWhiteStyle.titleFont(15, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(label)
                    .font(PetWhiteStyle.labelFont(9.5, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
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
                cornerRadius: 18,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
    }
}

private struct PetWhiteProfileActionTile: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                PetWhiteIconBadge(icon: icon, tint: tint, size: 40)

                Spacer(minLength: 8)

                PetWhitePackIcon(icon: .chevronRight, size: 15, visualScale: 1.04)
                    .frame(width: 32, height: 32)
                    .background(PetWhiteStyle.surfacePressed, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.separator, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(PetWhiteStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(value)
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .padding(14)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Menu Row

struct ProfileMenuRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var trailingText: String? = nil
    var petWhiteAssetName: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            profileMenuIcon

            Text(title)
                .font(MangaStyle.isActive ? MangaStyle.comicFont(15, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(15, weight: .regular) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(15, weight: .bold) : (SignalStyle.isActive ? SignalStyle.labelFont(15, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded))))))
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : .monologueTextPrimary)))

            Spacer()

            if let text = trailingText {
                Text(text)
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(13, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .regular) : .system(size: 13, weight: .regular, design: .rounded))))))
                    .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : .monologueTextSecondary)))
            }
            if PetWhiteStyle.isActive {
                PetWhitePackIcon(icon: .chevronRight, size: 13, visualScale: 1.04)
                    .foregroundStyle(PetWhiteStyle.inkMuted)
            } else {
                MonologueIcon(icon: .chevronRight, size: 13, color: CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : .monologueTextSecondary.opacity(0.4)))
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
            MonologueIcon(icon: icon, size: 15, color: MangaStyle.strokeInk, lineWidth: 1.8)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MangaStyle.labelYellow))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.6))
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 1.8, y: 1.8))
        } else if PetWhiteStyle.isActive {
            if let petWhiteAssetName {
                petWhiteAssetBadge(assetName: petWhiteAssetName, tint: PetWhiteStyle.sky, size: 36)
            } else {
                PetWhiteIconBadge(icon: icon, tint: icon == .settings ? PetWhiteStyle.mint : PetWhiteStyle.sky, size: 36)
            }
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(MujiStyle.clay.opacity(0.1))
                .frame(width: 31, height: 31)
                .overlay(MonologueIcon(icon: icon, size: 14, color: MujiStyle.clay, lineWidth: 1.4))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))
        } else if NeumorphicStyle.isActive {
            NeumorphicIconBadge(icon: icon, tint: NeumorphicStyle.accent, size: 32)
        } else if CapsuleStyle.isActive {
            CapsuleIconBadge(icon: icon, tint: CapsuleStyle.accent, size: 34)
        } else if SignalStyle.isActive {
            SignalIconBadge(icon: icon, tint: SignalStyle.accent, size: 32)
        } else {
            MonologueIcon(icon: icon, size: 18, color: .monologueTextPrimary)
                .frame(width: 28, height: 28)
        }
    }

    private func petWhiteAssetBadge(assetName: String, tint: Color, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(12, size * 0.30), style: .continuous)
            .fill(tint)
            .frame(width: size, height: size)
            .overlay(
                PetWhiteSelectedLyricToggleIcon(assetName: assetName, size: size * 0.72)
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(12, size * 0.30), style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: max(1.5, size * 0.04))
            )
            .overlay(alignment: .topTrailing) {
                PetWhiteProfileHeadIcon(filled: true, size: max(14, size * 0.30))
                    .offset(x: size * 0.10, y: -size * 0.10)
            }
    }
}

private struct MangaProfileInfoPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(MangaStyle.comicFont(11, weight: .black))
            .foregroundStyle(MangaStyle.strokeInk)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.78))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(MangaStyle.strokeInk.opacity(0.46), lineWidth: MangaStyle.fineStrokeWidth)
            )
    }
}

private struct MangaProfileActionRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            MonologueIcon(icon: icon, size: 16, color: MangaStyle.strokeInk, lineWidth: 1.8)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(0.58), lineWidth: MangaStyle.fineStrokeWidth)
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

            MonologueIcon(icon: .chevronRight, size: 13, color: MangaStyle.inkSub, lineWidth: 1.8)
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

private struct MangaProfilePortalCard: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                MangaIconBadge(icon: icon, size: 38, tint: tint)

                Spacer()

                MangaLabel(text: value, tint: MangaStyle.bubbleWhite, small: true)
                    .frame(maxWidth: 76, alignment: .trailing)
            }

            Text(title)
                .font(MangaStyle.comicFont(14, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: tint.opacity(0.72)))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MangaProfileRecentCard: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: song.coverUrl, width: 112, height: 112) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(MangaStyle.bubbleWhite)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.8))
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 2.5, y: 2.5))

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
        .padding(8)
        .background(MangaCardBackground(cornerRadius: 15, elevated: true, tint: MangaStyle.bubbleWhite))
    }
}

private struct MujiProfileLedgerRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            MujiIconBadge(icon: icon, tint: tint, size: 34)

            Text(title)
                .font(MujiStyle.bodyFont(15, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(value)
                .font(MujiStyle.labelFont(11, weight: .medium))
                .foregroundStyle(MujiStyle.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            MonologueIcon(icon: .chevronRight, size: 11, color: MujiStyle.inkMuted, lineWidth: 1.4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
        Rectangle()
            .fill(MujiStyle.separator.opacity(0.58))
            .frame(height: 0.6)
            .padding(.leading, 64)
            .padding(.trailing, 14)
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
            background(MujiPaperCardBackground(cornerRadius: cornerRadius, elevated: true))
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
            monologueGlass(cornerRadius: cornerRadius)
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
    let icon: MonologueIcon.IconType
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 10) {
                MonologueIcon(icon: icon, size: 22, color: .monologueTextPrimary)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .monologueGlass(cornerRadius: 20)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }
}

// MARK: - Profile Menu Item (kept for backward compatibility)

struct ProfileMenuItem: View {
    let icon: MonologueIcon.IconType
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
                MonologueIcon(icon: icon, size: 20, color: .monologueTextPrimary)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                switch trailing {
                case .chevron:
                    MonologueIcon(icon: .chevronRight, size: 14, color: .monologueTextSecondary.opacity(0.5))
                case let .text(value):
                    Text(value)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                    MonologueIcon(icon: .chevronRight, size: 14, color: .monologueTextSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
}
