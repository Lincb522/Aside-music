import SwiftUI

extension SettingsView {
    // MARK: - 日夜模式

    var themeSection: some View {
        SettingsSection(title: String(localized: "settings_theme_mode_section_title")) {
            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode,
                isSelectionEnabled: !settings.globalThemeId.requiresDarkAppearance,
                lockedSelection: settings.globalThemeId.requiresDarkAppearance ? "dark" : nil
            )
        }
    }

    // MARK: - 导航入口卡片

    var navigationCardsSection: some View {
        VStack(spacing: 14) {
            SettingsRouteLinkRow(
                icon: .sparkle,
                title: settingsText("settings_navigation_appearance_title"),
                subtitle: settingsText("settings_navigation_appearance_subtitle"),
                destination: .appearance,
                verticalPadding: 16
            )
            .themedSettingsStandaloneCard(cornerRadius: 18, tint: MangaStyle.bubblePink)

            SettingsRouteLinkRow(
                icon: .soundQuality,
                title: settingsText("settings_navigation_playback_title"),
                subtitle: settingsText("settings_navigation_playback_subtitle"),
                destination: .playback,
                verticalPadding: 16
            )
            .themedSettingsStandaloneCard(cornerRadius: 18, tint: MangaStyle.bubbleBlue)

            SettingsRouteLinkRow(
                icon: .cloud,
                title: settingsText("settings_navigation_cloud_sync_title"),
                subtitle: hasToken ? playlistSyncStatusText : settingsText("settings_navigation_cloud_sync_disabled"),
                destination: .cloudSync,
                verticalPadding: 16
            )
            .themedSettingsStandaloneCard(cornerRadius: 18, tint: MangaStyle.paperCool)
        }
    }

    var mangaSettingsModePanel: some View {
        // 去卡片化：日夜模式行直接排在纸上，下方细墨线收尾
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "settings_theme_mode_section_title"), mark: .star)

            VStack(spacing: 0) {
                SettingsThemeRow(
                    icon: .sparkle,
                    title: String(localized: "settings_theme_mode"),
                    selection: $settings.themeMode
                )

                Rectangle()
                    .fill(MangaStyle.strokeInk.opacity(0.18))
                    .frame(height: 1)
            }
        }
    }

    var mangaSettingsPortalGrid: some View {
        // 去卡片化：报刊目录式条目，规则线分隔，右侧小字页码式徽标
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "profile_settings"), mark: .heart)

            VStack(spacing: 0) {
                SettingsNavigationLink(destination: .appearance) {
                    MangaSettingsPortalCard(
                        icon: .sparkle,
                        title: settingsText("settings_navigation_appearance_title"),
                        badge: "STYLE",
                        tint: MangaStyle.bubblePink
                    )
                }
                .buttonStyle(.plain)

                MangaListDivider().opacity(0.6)

                SettingsNavigationLink(destination: .playback) {
                    MangaSettingsPortalCard(
                        icon: .soundQuality,
                        title: settingsText("settings_navigation_playback_title"),
                        badge: "PLAY",
                        tint: MangaStyle.bubbleBlue
                    )
                }
                .buttonStyle(.plain)

                MangaListDivider().opacity(0.6)

                SettingsNavigationLink(destination: .cloudSync) {
                    MangaSettingsPortalCard(
                        icon: .cloud,
                        title: settingsText("settings_navigation_cloud_sync_title"),
                        badge: hasToken ? "SYNC" : "OFF",
                        tint: MangaStyle.paperCool
                    )
                }
                .buttonStyle(.plain)

                MangaListDivider().opacity(0.6)

                SettingsNavigationLink(destination: .storage) {
                    MangaSettingsPortalCard(
                        icon: .storage,
                        title: String(localized: "settings_storage_manage"),
                        badge: cacheSize,
                        tint: MangaStyle.mint
                    )
                }
                .buttonStyle(.plain)

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    MangaListDivider().opacity(0.6)

                    SettingsNavigationLink(destination: .download) {
                        MangaSettingsPortalCard(
                            icon: .download,
                            title: String(localized: "settings_download_manage"),
                            badge: "DL",
                            tint: MangaStyle.bubbleBlue
                        )
                    }
                    .buttonStyle(.plain)
                }

                MangaListDivider().opacity(0.6)

                SettingsNavigationLink(destination: .about) {
                    MangaSettingsPortalCard(
                        icon: .infoCircle,
                        title: String(localized: "settings_about"),
                        badge: appVersion,
                        tint: MangaStyle.paperWarm
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var mujiSettingsNotebook: some View {
        VStack(alignment: .leading, spacing: 14) {
            MujiSectionTitle(title: String(localized: "profile_settings"))

            VStack(spacing: 0) {
                MujiThemeModeRow(selection: $settings.themeMode)

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    destination: .appearance
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    destination: .playback
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    destination: .cloudSync
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    destination: .storage
                )

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    MujiSettingsDivider()

                    MujiSettingsLedgerLink(
                        icon: .download,
                        title: String(localized: "settings_download_manage"),
                        value: "DOWNLOAD",
                        destination: .download
                    )
                }

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .infoCircle,
                    title: String(localized: "settings_about"),
                    value: appVersion,
                    destination: .about
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: MujiStyle.cardRadius, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
            )
        }
    }

}
