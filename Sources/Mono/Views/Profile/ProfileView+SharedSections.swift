import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    // MARK: - Stats Bar

    @ViewBuilder
    var statsBar: some View {
        if MangaStyle.isActive {
            HStack(spacing: 10) {
                MangaMetricTile(
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel,
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
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel
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
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel,
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
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel
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
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel
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
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.55))
                    .frame(height: 0.65)
            }
        } else if SequoiaStyle.isActive {
            HStack(spacing: 0) {
                StatCell(
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel
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
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel
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
                    value: identityPrimaryMetricValue,
                    label: identityPrimaryMetricLabel
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

    var statDivider: some View {
        Rectangle()
            .fill(PetWhiteStyle.isActive ? PetWhiteStyle.separator : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.68) : (SignalStyle.isActive ? SignalStyle.separator.opacity(0.7) : (SequoiaStyle.isActive ? SequoiaStyle.separator.opacity(0.9) : (LiquidGlassStyle.isActive ? LiquidGlassStyle.separator.opacity(0.82) : Color.monoSeparator)))))
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Recent Plays

    var recentlyPlayedSection: some View {
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
                    ForEach(playerManager.history.prefix(15), id: \.identityKey) { song in
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

    var menuList: some View {
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

                if loginIdentity.activeSource == .netease {
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
            }
            .themedProfileSurface(cornerRadius: PetWhiteStyle.isActive ? PetWhiteStyle.cardRadius : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (SignalStyle.isActive ? 24 : (NeumorphicStyle.isActive ? 20 : (SequoiaStyle.isActive ? 18 : 20))))), mangaTint: MangaStyle.bubbleWhite)
        }
    }

    // MARK: - Logout

    func restoreQQSessionIfNeeded() {
        guard !hasRequestedQQSessionRestore,
              !qqSession.isLoggedIn,
              qqSession.hasStoredCredentials else { return }
        hasRequestedQQSessionRestore = true
        Task { @MainActor in
            await qqSession.refresh()
        }
    }

    func performLogout() {
        guard let source = loginIdentity.activeSource else { return }

        switch source {
        case .netease:
            let logoutPublisher = UnsafeSendableBox(APIService.shared.logout())
            isAppLoggedIn = false
            loginIdentity.accountDidLogOut(.netease)
            Task {
                do {
                    _ = try await logoutPublisher.value.async()
                } catch {
                    AppLogger.warning("NCM 远端退出失败，本地已退出: \(error)")
                }
            }
        case .qqmusic:
            qqSession.onLogout()
            loginIdentity.accountDidLogOut(.qqmusic)
        case .kugou:
            KCMMusicService.shared.logout {
                loginIdentity.accountDidLogOut(.kugou)
            }
        case .qishui, .appleMusic, .local:
            return
        }

        cacheDisplayedProfile(
            loginIdentity.displayedProfile(ncmProfile: viewModel.userProfile)
        )
        hasAppeared = false
        userLevel = nil
        listenSongs = nil
        // 播放记录是设备本地数据，退出账号不清空
        AlertManager.shared.dismiss()
    }

    var logoutButton: some View {
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

    var notLoggedInContent: AnyView {
        if MinimalWhiteStyle.isActive {
            return AnyView(minimalWhiteNotLoggedInContent)
        }
        if SignalStyle.isActive {
            return AnyView(signalNotLoggedInContent)
        }
        if MangaStyle.isActive {
            return AnyView(mangaNotLoggedInContent)
        }
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteNotLoggedInContent)
        }
        if MujiStyle.isActive {
            return AnyView(mujiNotLoggedInContent)
        }
        if NeumorphicStyle.isActive {
            return AnyView(neumorphicNotLoggedInContent)
        }
        if CapsuleStyle.isActive {
            return AnyView(capsuleNotLoggedInContent)
        }
        if LiquidGlassStyle.isActive {
            return AnyView(liquidGlassNotLoggedInContent)
        }
        if !ThemedPageStyle.isActive {
            return AnyView(asideNotLoggedInContent)
        }
        return fallbackNotLoggedInContent
    }

    private var fallbackNotLoggedInContent: AnyView {
        AnyView(
            NavigationStack(path: $navigationPath) {
                ZStack {
                    ThemedProfileBackground()
                    fallbackGuestContent
                }
                .navigationTitle(ThemedPageStyle.isActive ? "" : String(localized: "tab_profile"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .profileNavigationDestinations()
            }
        )
    }

    private var fallbackGuestContent: AnyView {
        AnyView(
            VStack(spacing: 0) {
                fallbackGuestHeader
                Spacer()
                fallbackGuestIdentityCard
                Spacer()
                fallbackGuestMenu
            }
        )
    }

    private var fallbackGuestHeader: AnyView {
        if MangaStyle.isActive {
            return AnyView(mangaProfileHeader)
        }
        if NeumorphicStyle.isActive {
            return AnyView(neumorphicProfileHeader)
        }
        if CapsuleStyle.isActive {
            return AnyView(capsuleProfileHeader)
        }
        if SignalStyle.isActive {
            return AnyView(signalProfileHeaderBar)
        }
        if MujiStyle.isActive {
            return AnyView(mujiProfileHeader)
        }
        if SequoiaStyle.isActive {
            return AnyView(sequoiaProfileHeaderBar)
        }
        return AnyView(EmptyView())
    }

    private var fallbackGuestIdentityCard: AnyView {
        AnyView(
            VStack(spacing: 28) {
                fallbackGuestAvatar
                fallbackGuestCopy
                fallbackGuestLoginButton
            }
            .padding(ThemedPageStyle.isActive ? 24 : 0)
            .background { fallbackGuestCardBackground }
            .padding(.horizontal, ThemedPageStyle.isActive ? DeviceLayout.homeHorizontalPadding : 0)
        )
    }

    private var fallbackGuestAvatar: AnyView {
        AnyView(
            ZStack {
                Circle()
                    .fill(Color.monoGlassTint)
                    .monoGlassCircle()
                    .frame(width: 100, height: 100)

                MonoIcon(icon: .profile, size: 40, color: .monoTextSecondary.opacity(0.3))
            }
        )
    }

    private var fallbackGuestCopy: AnyView {
        AnyView(
            VStack(spacing: 10) {
                Text(LocalizedStringKey("profile_not_logged_in"))
                    .font(MangaStyle.isActive ? MangaStyle.titleFont(26, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(26, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(26, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(25, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(25, weight: .semibold) : .system(size: 26, weight: .bold, design: .rounded))))))
                    .foregroundColor(.monoTextPrimary)

                Text(LocalizedStringKey("profile_login_hint"))
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(14, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(14, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .system(size: 14, weight: .medium, design: .rounded))))))
                    .foregroundColor(.monoTextSecondary)
            }
        )
    }

    private var fallbackGuestLoginButton: AnyView {
        AnyView(
            Button(action: { navigationPath.append(ProfileNavigationDestination.loginNCM) }) {
                Text(LocalizedStringKey("profile_login_button"))
                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(16, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(16, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(16, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(16, weight: .semibold) : .system(size: 16, weight: .bold, design: .rounded)))))
                    .foregroundColor(MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (MujiStyle.isActive ? MujiStyle.onTint : (NeumorphicStyle.isActive ? Color(light: .white, dark: .black) : (SignalStyle.isActive ? SignalStyle.onAccent : .monoIconForeground))))
                    .frame(width: 200)
                    .padding(.vertical, 15)
                    .background { fallbackGuestLoginButtonBackground }
            }
            .buttonStyle(MonoBouncingButtonStyle())
        )
    }

    private var fallbackGuestLoginButtonBackground: AnyView {
        if MangaStyle.isActive {
            return AnyView(
                RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                    .fill(MangaStyle.labelYellow)
            )
        }
        if NeumorphicStyle.isActive {
            return AnyView(Capsule().fill(NeumorphicStyle.accent))
        }
        if SignalStyle.isActive {
            return AnyView(Capsule().fill(SignalStyle.accent))
        }
        if MujiStyle.isActive {
            return AnyView(Capsule().fill(MujiStyle.clay))
        }
        if SequoiaStyle.isActive {
            return AnyView(Capsule().fill(SequoiaStyle.accentGradient))
        }
        return AnyView(Capsule().fill(Color.monoIconBackground))
    }

    private var fallbackGuestCardBackground: AnyView {
        if MangaStyle.isActive {
            return AnyView(MangaCardBackground(cornerRadius: MangaStyle.cardRadius, elevated: true))
        }
        if NeumorphicStyle.isActive {
            return AnyView(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true))
        }
        if SignalStyle.isActive {
            return AnyView(SignalSurfaceBackground(cornerRadius: 16, elevated: true, fill: SignalStyle.device))
        }
        if MujiStyle.isActive {
            // Muji：清新水洗底
            return AnyView(
                RoundedRectangle(cornerRadius: MujiStyle.cardRadius, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
            )
        }
        if SequoiaStyle.isActive {
            return AnyView(SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, fill: SequoiaStyle.material))
        }
        return AnyView(EmptyView())
    }

    private var fallbackGuestMenu: AnyView {
        AnyView(
            VStack(spacing: 0) {
                fallbackGuestPlatformAccountsRow

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    fallbackGuestDivider
                    fallbackGuestDownloadsRow
                }

                fallbackGuestDivider
                fallbackGuestListeningStatsRow
                fallbackGuestDivider
                fallbackGuestStorageRow
                fallbackGuestDivider
                fallbackGuestSettingsRow
            }
            .themedProfileSurface(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 20 : (SignalStyle.isActive ? 16 : (SequoiaStyle.isActive ? 16 : 20)))), mangaTint: MangaStyle.bubbleWhite)
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.bottom, 140)
        )
    }

    private var fallbackGuestDivider: AnyView {
        AnyView(Divider().padding(.leading, 56))
    }

    private var fallbackGuestPlatformAccountsRow: AnyView {
        AnyView(
            Button(action: { navigationPath.append(ProfileNavigationDestination.platformAccounts) }) {
                ProfileMenuRow(
                    icon: .musicNote,
                    title: "平台账号管理",
                    trailingText: "4 个平台"
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        )
    }

    private var fallbackGuestDownloadsRow: AnyView {
        AnyView(
            NavigationLink(destination: DownloadManageView()) {
                ProfileMenuRow(
                    icon: .download,
                    title: NSLocalizedString("profile_downloads", comment: ""),
                    trailingText: String(format: String(localized: "profile_recent_count"), downloadedSongCount)
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        )
    }

    private var fallbackGuestListeningStatsRow: AnyView {
        AnyView(
            NavigationLink(destination: ListeningStatsView()) {
                ProfileMenuRow(
                    icon: .sparkle,
                    title: String(localized: "cloud_sync_listening_stats")
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        )
    }

    private var fallbackGuestStorageRow: AnyView {
        AnyView(
            NavigationLink(destination: StorageManageView()) {
                ProfileMenuRow(
                    icon: .storage,
                    title: String(localized: "profile_cache_manage")
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        )
    }

    private var fallbackGuestSettingsRow: AnyView {
        AnyView(
            NavigationLink(value: ProfileNavigationDestination.settings) {
                ProfileMenuRow(
                    icon: .settings,
                    title: NSLocalizedString("profile_settings", comment: "")
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        )
    }

}
