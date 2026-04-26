import SwiftUI
import Combine
import QQMusicKit

private struct ThemedProfileBackground: View {
    var body: some View {
        ThemedPageBackground()
    }
}

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
            ThemedProfileBackground()

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
                ThemedProfileBackground()

                ScrollView {
                    VStack(spacing: themedProfileSpacing) {
                        loggedInDashboardContent
                        FloatingBarBottomSpacer()
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

    private var themedProfileSpacing: CGFloat {
        if MangaStyle.isActive { return 14 }
        if MujiStyle.isActive { return 18 }
        return 16
    }

    @ViewBuilder
    private var loggedInDashboardContent: some View {
        if MangaStyle.isActive {
            mangaProfileDashboard
        } else if MujiStyle.isActive {
            mujiProfileDashboard
        } else {
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

    @ViewBuilder
    private var mangaProfileDashboard: some View {
        mangaProfileHeroPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, 8)

        statsBar
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        if !playerManager.history.isEmpty {
            mangaRecentPlaysPanel
        }

        mangaProfileActionGrid
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        logoutButton
    }

    @ViewBuilder
    private var mujiProfileDashboard: some View {
        mujiProfileHeader

        mujiProfileJournalPanel
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        statsBar
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        if !playerManager.history.isEmpty {
            recentlyPlayedSection
        }

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
                        value: "\(downloadManager.downloadedSongIds.count)",
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
        .sheet(isPresented: $showQQAccount) {
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
                        number: "01",
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
                        number: "02",
                        icon: .download,
                        title: NSLocalizedString("profile_downloads", comment: ""),
                        value: "\(downloadManager.downloadedSongIds.count)"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: StorageManageView()) {
                    MujiProfileLedgerRow(
                        number: "03",
                        icon: .storage,
                        title: String(localized: "profile_cache_manage"),
                        value: "cache"
                    )
                }
                .buttonStyle(.plain)

                MujiProfileDivider()

                NavigationLink(destination: CloudDiskView()) {
                    MujiProfileLedgerRow(
                        number: "04",
                        icon: .cloud,
                        title: NSLocalizedString("profile_cloud_disk", comment: ""),
                        value: "cloud"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(MujiPaperCardBackground(cornerRadius: 12, elevated: false))
        }
        .sheet(isPresented: $showQQAccount) {
            NavigationStack {
                QQAccountView()
            }
        }
    }

    @ViewBuilder
    private func mangaAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url) {
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
            CachedAsyncImage(url: url) {
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
        .themedProfileSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : 22), mangaTint: MangaStyle.paperWarm)
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
            .themedProfileSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : 20), mangaTint: MangaStyle.bubbleWhite)
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
                ThemedProfileBackground()

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
                                .foregroundColor(MangaStyle.isActive ? MangaStyle.strokeInk : (MujiStyle.isActive ? MujiStyle.onTint : .monologueIconForeground))
                                .frame(width: 200)
                                .padding(.vertical, 15)
                                .background {
                                    if MangaStyle.isActive {
                                        Capsule()
                                            .fill(MangaStyle.labelYellow)
                                    } else if MujiStyle.isActive {
                                        Capsule()
                                            .fill(MujiStyle.clay)
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
                    .themedProfileSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : 20), mangaTint: MangaStyle.bubbleWhite)
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
            profileMenuIcon

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

    @ViewBuilder
    private var profileMenuIcon: some View {
        if MangaStyle.isActive {
            MonologueIcon(icon: icon, size: 15, color: MangaStyle.strokeInk, lineWidth: 1.8)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MangaStyle.labelYellow))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.6))
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 1.8, y: 1.8))
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(MujiStyle.clay.opacity(0.1))
                .frame(width: 31, height: 31)
                .overlay(MonologueIcon(icon: icon, size: 14, color: MujiStyle.clay, lineWidth: 1.4))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))
        } else {
            MonologueIcon(icon: icon, size: 18, color: .monologueTextPrimary)
                .frame(width: 28, height: 28)
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
            CachedAsyncImage(url: song.coverUrl) {
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
    let number: String
    let icon: MonologueIcon.IconType
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(MujiStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(MujiStyle.inkMuted)
                .frame(width: 24, alignment: .leading)

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
            self.background(MangaCardBackground(cornerRadius: cornerRadius, elevated: true, tint: mangaTint))
        } else if MujiStyle.isActive {
            self.background(MujiPaperCardBackground(cornerRadius: cornerRadius, elevated: true))
        } else {
            self.monologueGlass(cornerRadius: cornerRadius)
        }
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
