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

    @ViewBuilder
    var notLoggedInContent: some View {
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

}
