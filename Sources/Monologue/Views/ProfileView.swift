import SwiftUI
import Combine
import QQMusicKit

struct ProfileView: View {
    private var viewModel: HomeViewModel { HomeViewModel.shared }
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false

    @State private var showLoginView = false
    @State private var showQQAccount = false
    @State private var cachedProfile: UserProfile?
    @State private var hasAppeared = false

    @State private var userLevel: Int?
    @State private var listenSongs: Int?


    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var localPlaylistManager = LocalPlaylistManager.shared

    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()

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
        .fullScreenCover(isPresented: $showLoginView) {
            LoginView()

        }
        .onReceive(playerManager.$currentSong.dropFirst()) { newSong in
            guard newSong != nil, isAppLoggedIn else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 移除本地独立历史刷新，统一由 playerManager 数据驱动
            }
        }
    }

    // MARK: - Logged In

    private var loggedInContent: some View {
        NavigationStack {
            ZStack {
                MonologueBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if MangaStyle.isActive {
                            mangaProfileHeader
                        } else if MujiStyle.isActive {
                            mujiProfileHeader
                        }

                        profileHeroCard
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        statsBar
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        if !playerManager.history.isEmpty {
                            recentlyPlayedSection
                        }

                        menuList
                            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                        logoutButton

                        Color.clear.frame(height: 100)
                    }
                    .iPadContentWidth(700)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle((MangaStyle.isActive || MujiStyle.isActive) ? "" : String(localized: "我的"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !MangaStyle.isActive && !MujiStyle.isActive {
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

    // MARK: - Hero Card

    private var mangaProfileHeader: some View {
        MangaPageHeader(
            eyebrow: "PROFILE",
            title: String(localized: "我的"),
            subtitle: ""
        ) {
            NavigationLink(destination: SettingsView()) {
                MangaIconBadge(systemName: "gearshape.fill", size: 48, tint: MangaStyle.decoBlue)
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

    private var profileHeroCard: some View {
        let profile = cachedProfile ?? viewModel.userProfile

        return HStack(spacing: 16) {
            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) {
                    Circle().fill(Color.monologueSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                .clipShape(Circle())
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
                        .font(MangaStyle.isActive ? MangaStyle.comicFont(22, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(22, weight: .regular) : .system(size: 20, weight: .bold, design: .rounded)))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    if let level = userLevel {
                        Text("Lv.\(level)")
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(10, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(10, weight: .semibold) : .system(size: 10, weight: .bold, design: .rounded)))
                            .foregroundColor(.monologueIconForeground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.monologueIconBackground)
                            .clipShape(Capsule())
                    }
                }

                if let signature = profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(MangaStyle.isActive ? MangaStyle.comicFont(12, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded)))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding((MangaStyle.isActive || MujiStyle.isActive) ? 16 : 18)
        .monologueGlass(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : 22))
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
                    value: "\(localPlaylistManager.playlists.count)",
                    label: String(localized: "profile_local_playlists"),
                    tint: MangaStyle.decoBlue
                )
                MangaMetricTile(
                    value: "\(downloadManager.downloadedSongIds.count)",
                    label: String(localized: "profile_downloads"),
                    tint: MangaStyle.accentPink
                )
            }
            .padding(14)
            .background(MangaCardBackground(cornerRadius: 12, elevated: true))
        } else if MujiStyle.isActive {
            HStack(spacing: 10) {
                MujiMetricTile(
                    value: formatNumber(listenSongs ?? 0),
                    label: String(localized: "profile_total_songs"),
                    tint: MujiStyle.clay
                )
                MujiMetricTile(
                    value: "\(localPlaylistManager.playlists.count)",
                    label: String(localized: "profile_local_playlists"),
                    tint: MujiStyle.tea
                )
                MujiMetricTile(
                    value: "\(downloadManager.downloadedSongIds.count)",
                    label: String(localized: "profile_downloads"),
                    tint: MujiStyle.indigo
                )
            }
            .padding(14)
            .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
        } else {
        HStack(spacing: 0) {
            StatCell(
                value: formatNumber(listenSongs ?? 0),
                label: String(localized: "profile_total_songs")
            )
            statDivider
            StatCell(
                value: "\(localPlaylistManager.playlists.count)",
                label: String(localized: "profile_local_playlists")
            )
            statDivider
            StatCell(
                value: "\(downloadManager.downloadedSongIds.count)",
                label: String(localized: "profile_downloads")
            )
        }
        .padding(.vertical, 14)
        .monologueGlass(cornerRadius: 18)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.monologueSeparator)
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Recent Plays

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(18, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .regular) : .system(size: 18, weight: .bold, design: .rounded)))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(
                    destination: RecentPlayHistoryView()
                ) {
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "profile_recent_count"), playerManager.history.count))
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : .system(size: 13, weight: .medium, design: .rounded)))
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
                                CachedAsyncImage(url: song.coverUrl) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.monologueSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : .system(size: 13, weight: .semibold, design: .rounded)))
                                        .foregroundColor(.monologueTextPrimary)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(11, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded)))
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
        }
    }

    // MARK: - Menu List

    private var menuList: some View {
        VStack(alignment: .leading, spacing: (MangaStyle.isActive || MujiStyle.isActive) ? 12 : 0) {
            if MangaStyle.isActive {
                MangaSectionTitle(title: String(localized: "profile_settings"))
            } else if MujiStyle.isActive {
                MujiSectionTitle(title: String(localized: "profile_settings"))
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
                .sheet(isPresented: $showQQAccount) {
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
                        trailingText: String(format: String(localized: "profile_recent_count"), downloadManager.downloadedSongIds.count)
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
            .monologueGlass(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : 20))
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
                .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : .system(size: 13, weight: .medium, design: .rounded)))
                .foregroundColor(.monologueTextSecondary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - Not Logged In

    private var notLoggedInContent: some View {
        NavigationStack {
            ZStack {
                MonologueBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if MangaStyle.isActive {
                        mangaProfileHeader
                    } else if MujiStyle.isActive {
                        mujiProfileHeader
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
                                .font(MangaStyle.isActive ? MangaStyle.comicFont(26, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(26, weight: .regular) : .system(size: 26, weight: .bold, design: .rounded)))
                                .foregroundColor(.monologueTextPrimary)

                            Text(LocalizedStringKey("profile_login_hint"))
                                .font(MangaStyle.isActive ? MangaStyle.comicFont(14, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(14, weight: .regular) : .system(size: 14, weight: .medium, design: .rounded)))
                                .foregroundColor(.monologueTextSecondary)
                        }

                        Button(action: { showLoginView = true }) {
                            Text(LocalizedStringKey("profile_login_button"))
                                .font(MangaStyle.isActive ? MangaStyle.comicFont(16, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(16, weight: .semibold) : .system(size: 16, weight: .bold, design: .rounded)))
                                .foregroundColor(.monologueIconForeground)
                                .frame(width: 200)
                                .padding(.vertical, 15)
                                .background(Color.monologueIconBackground)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                    }
                    .padding((MangaStyle.isActive || MujiStyle.isActive) ? 24 : 0)
                    .background {
                        if MangaStyle.isActive {
                            MangaCardBackground(cornerRadius: 12, elevated: true)
                        } else if MujiStyle.isActive {
                            MujiPaperCardBackground(cornerRadius: 12, elevated: true)
                        }
                    }
                    .padding(.horizontal, (MangaStyle.isActive || MujiStyle.isActive) ? DeviceLayout.homeHorizontalPadding : 0)

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
                        .sheet(isPresented: $showQQAccount) {
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
                                trailingText: String(format: String(localized: "profile_recent_count"), downloadManager.downloadedSongIds.count)
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
                    .monologueGlass(cornerRadius: 20)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle((MangaStyle.isActive || MujiStyle.isActive) ? "" : String(localized: "我的"))
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
                .font(MangaStyle.isActive ? MangaStyle.comicFont(18, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .medium) : .system(size: 18, weight: .bold, design: .rounded)))
                .foregroundColor(.monologueTextPrimary)

            Text(label)
                .font(MangaStyle.isActive ? MangaStyle.comicFont(10, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(10, weight: .regular) : .system(size: 10, weight: .medium, design: .rounded)))
                .foregroundColor(.monologueTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Row

struct ProfileMenuRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var trailingText: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            MonologueIcon(icon: icon, size: 18, color: .monologueTextPrimary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(MangaStyle.isActive ? MangaStyle.comicFont(15, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(15, weight: .regular) : .system(size: 15, weight: .medium, design: .rounded)))
                .foregroundColor(.monologueTextPrimary)

            Spacer()

            if let text = trailingText {
                Text(text)
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : .system(size: 13, weight: .regular, design: .rounded)))
                    .foregroundColor(.monologueTextSecondary)
            }
            MonologueIcon(icon: .chevronRight, size: 13, color: .monologueTextSecondary.opacity(0.4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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
                case .text(let value):
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
