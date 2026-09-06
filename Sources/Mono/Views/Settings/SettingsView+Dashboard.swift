import SwiftUI

extension SettingsView {
    // MARK: - aside 设置主页分组（编辑部信息架构）

    /// 分组内行间发丝分隔线
    var asideRowDivider: some View {
        Rectangle()
            .fill(SignalStyle.isActive ? SignalStyle.separator.opacity(0.52) : Color.monoSeparator.opacity(0.55))
            .frame(height: 0.5)
            .padding(.leading, 58)
    }

    var asidePersonalizationSection: some View {
        SettingsSection(title: settingsText("settings_section_personalization")) {
            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode,
                isSelectionEnabled: !settings.globalThemeId.requiresDarkAppearance,
                lockedSelection: settings.globalThemeId.requiresDarkAppearance ? "dark" : nil
            )

            asideRowDivider

            SettingsRouteLinkRow(
                icon: .playerTheme,
                title: settingsText("settings_navigation_appearance_title"),
                subtitle: settingsText("settings_navigation_appearance_subtitle"),
                destination: .appearance
            )
        }
    }

    var asidePlaybackSection: some View {
        SettingsSection(title: settingsText("settings_section_playback")) {
            SettingsRouteLinkRow(
                icon: .soundQuality,
                title: settingsText("settings_navigation_playback_title"),
                subtitle: settingsText("settings_navigation_playback_subtitle"),
                destination: .playback
            )
        }
    }

    var asideDataSection: some View {
        SettingsSection(title: settingsText("settings_section_data")) {
            SettingsRouteLinkRow(
                icon: .cloud,
                title: settingsText("settings_navigation_cloud_sync_title"),
                subtitle: hasToken ? playlistSyncStatusText : settingsText("settings_navigation_cloud_sync_disabled"),
                destination: .cloudSync
            )

            asideRowDivider

            SettingsRouteLinkRow(
                icon: .storage,
                title: String(localized: "settings_storage_manage"),
                subtitle: String(localized: "settings_storage_manage_desc"),
                value: cacheSize,
                destination: .storage
            )
        }
    }

    @ViewBuilder
    var mangaSettingsContent: some View {

        settingsHeaderCard

        mangaSettingsModePanel
        mangaSettingsPortalGrid

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    var petWhiteSettingsContent: some View {
        petWhiteSettingsModeBoard
        petWhiteSettingsPortalGrid
        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    var neumorphicSettingsContent: some View {
        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    var signalSettingsContent: some View {
        settingsHeaderCard
        asidePersonalizationSection
        asidePlaybackSection
        asideDataSection
        signalSystemSection

        if qqDevMode {
            otherSection
        }
    }

    var signalSystemSection: some View {
        SettingsSection(title: String(localized: "settings_about")) {
            if AppConfig.Features.downloadEnabled {
                SettingsRouteLinkRow(
                    icon: .download,
                    title: String(localized: "settings_download_manage"),
                    destination: .download
                )

                asideRowDivider
            }

            SettingsRouteLinkRow(
                icon: .infoCircle,
                title: String(localized: "settings_about"),
                value: appVersion,
                destination: .about
            )
        }
    }

    @ViewBuilder
    var bentoSettingsContent: some View {
        settingsHeaderCard
        bentoSettingsModeBlock
        bentoSettingsGrid

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    var capsuleSettingsContent: some View {
        capsuleModeDeck
        capsuleSettingsMatrix

        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    var sequoiaSettingsContent: some View {
        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    var liquidGlassSettingsContent: some View {
        liquidGlassModeDeck

        liquidGlassSettingsMatrix

        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    var mujiSettingsContent: some View {
        settingsHeaderCard
        mujiSettingsNotebook

        if qqDevMode {
            otherSection
        }
    }

    var petWhiteSettingsModeBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: String(localized: "settings_theme_mode_section_title"),
                detail: String(localized: "settings_appearance_global_theme_section"),
                icon: .sparkle,
                tint: PetWhiteStyle.mint
            )

            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode
            )
            .background(
                PetWhiteSurfaceBackground(
                    cornerRadius: 20,
                    elevated: false,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: PetWhiteStyle.mint
                )
            )
        }
    }

    var petWhiteSettingsPortalGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: String(localized: "profile_settings"),
                detail: String(localized: "settings_appearance_layout_section"),
                icon: .settings,
                tint: PetWhiteStyle.butter
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                SettingsNavigationLink(destination: .appearance) {
                    PetWhiteSettingsPortalCard(
                        icon: .sparkle,
                        title: settingsText("settings_navigation_appearance_title"),
                        badge: "STYLE",
                        tint: PetWhiteStyle.dogOrange
                    )
                }
                .buttonStyle(.plain)

                SettingsNavigationLink(destination: .playback) {
                    PetWhiteSettingsPortalCard(
                        icon: .soundQuality,
                        title: settingsText("settings_navigation_playback_title"),
                        badge: "PLAY",
                        tint: PetWhiteStyle.mint
                    )
                }
                .buttonStyle(.plain)

                SettingsNavigationLink(destination: .cloudSync) {
                    PetWhiteSettingsPortalCard(
                        icon: .cloud,
                        title: settingsText("settings_navigation_cloud_sync_title"),
                        badge: hasToken ? "SYNC" : "OFF",
                        tint: PetWhiteStyle.sky
                    )
                }
                .buttonStyle(.plain)

                SettingsNavigationLink(destination: .storage) {
                    PetWhiteSettingsPortalCard(
                        icon: .storage,
                        title: String(localized: "settings_storage_manage"),
                        badge: cacheSize,
                        tint: PetWhiteStyle.butter
                    )
                }
                .buttonStyle(.plain)

                // 保留下载入口结构，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    SettingsNavigationLink(destination: .download) {
                        PetWhiteSettingsPortalCard(
                            icon: .download,
                            title: String(localized: "settings_download_manage"),
                            badge: "DL",
                            tint: PetWhiteStyle.blush
                        )
                    }
                    .buttonStyle(.plain)
                }

                SettingsNavigationLink(destination: .about) {
                    PetWhiteSettingsPortalCard(
                        icon: .infoCircle,
                        title: String(localized: "settings_about"),
                        badge: appVersion,
                        tint: PetWhiteStyle.mint
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var capsuleModeDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CapsuleIconBadge(icon: .sparkle, tint: CapsuleStyle.accent, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("MODE")
                        .font(CapsuleStyle.labelFont(10, weight: .bold))
                        .foregroundStyle(CapsuleStyle.accent)
                        .tracking(1.1)
                    Text(String(localized: "settings_theme_mode_section_title"))
                        .font(CapsuleStyle.titleFont(17, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }

            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode
            )
            .background(
                CapsuleSurfaceBackground(
                    cornerRadius: 20,
                    elevated: false,
                    tint: CapsuleStyle.surfaceTint.opacity(0.8)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(14)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 28,
                elevated: true,
                tint: CapsuleStyle.surface.opacity(0.92)
            )
        )
    }

    var capsuleSettingsMatrix: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            SettingsNavigationLink(destination: .appearance) {
                CapsuleSettingsTile(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    tint: CapsuleStyle.accent
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .playback) {
                CapsuleSettingsTile(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    tint: CapsuleStyle.violet
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .cloudSync) {
                CapsuleSettingsTile(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    tint: CapsuleStyle.mint
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .storage) {
                CapsuleSettingsTile(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    tint: CapsuleStyle.cyan
                )
            }
            .buttonStyle(.plain)

            // 保留下载入口结构，由功能开关统一控制。
            if AppConfig.Features.downloadEnabled {
                SettingsNavigationLink(destination: .download) {
                    CapsuleSettingsTile(
                        icon: .download,
                        title: String(localized: "settings_download_manage"),
                        value: "DL",
                        tint: CapsuleStyle.amber
                    )
                }
                .buttonStyle(.plain)
            }

            SettingsNavigationLink(destination: .about) {
                CapsuleSettingsTile(
                    icon: .infoCircle,
                    title: String(localized: "settings_about"),
                    value: appVersion,
                    tint: CapsuleStyle.coral
                )
            }
            .buttonStyle(.plain)
        }
    }

    var liquidGlassModeDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LiquidGlassIconBadge(icon: .sparkle, tint: LiquidGlassStyle.accent, size: 34)

                Text(String(localized: "settings_theme_mode_section_title"))
                    .font(LiquidGlassStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)

                Spacer(minLength: 0)
            }

            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode
            )
            .background(LiquidGlassSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, role: .list))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .padding(14)
        .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.accent, cornerRadius: 26))
    }

    var liquidGlassSettingsMatrix: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            SettingsNavigationLink(destination: .appearance) {
                LiquidGlassSettingsTile(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    tint: LiquidGlassStyle.accent
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .playback) {
                LiquidGlassSettingsTile(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    tint: LiquidGlassStyle.violet
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .cloudSync) {
                LiquidGlassSettingsTile(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    tint: LiquidGlassStyle.mint
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .storage) {
                LiquidGlassSettingsTile(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    tint: LiquidGlassStyle.cyan
                )
            }
            .buttonStyle(.plain)

            // 保留下载入口结构，由功能开关统一控制。
            if AppConfig.Features.downloadEnabled {
                SettingsNavigationLink(destination: .download) {
                    LiquidGlassSettingsTile(
                        icon: .download,
                        title: String(localized: "settings_download_manage"),
                        value: "DL",
                        tint: LiquidGlassStyle.amber
                    )
                }
                .buttonStyle(.plain)
            }

            SettingsNavigationLink(destination: .about) {
                LiquidGlassSettingsTile(
                    icon: .infoCircle,
                    title: String(localized: "settings_about"),
                    value: appVersion,
                    tint: LiquidGlassStyle.pink
                )
            }
            .buttonStyle(.plain)
        }
    }

    var bentoSettingsModeBlock: some View {
        BentoBlock(fill: BentoStyle.surface, radius: 24, padding: 12, stroked: true) {
            VStack(alignment: .leading, spacing: 12) {
                BentoBlockHeader(
                    eyebrow: "MODE",
                    title: String(localized: "settings_theme_mode_section_title"),
                    titleColor: BentoStyle.ink,
                    eyebrowColor: BentoStyle.tomato,
                    tightSpacing: true
                )

                SettingsThemeRow(
                    icon: .sparkle,
                    title: String(localized: "settings_theme_mode"),
                    selection: $settings.themeMode
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BentoStyle.paperWarm.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(BentoStyle.hairline.opacity(0.55), lineWidth: 0.7)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    var bentoSettingsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: BentoStyle.blockSpacing),
                GridItem(.flexible(), spacing: BentoStyle.blockSpacing),
            ],
            spacing: BentoStyle.blockSpacing
        ) {
            SettingsNavigationLink(destination: .appearance) {
                BentoSettingsTile(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    tint: BentoStyle.tomato
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .playback) {
                BentoSettingsTile(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    tint: BentoStyle.ocean
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .cloudSync) {
                BentoSettingsTile(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    tint: BentoStyle.matcha
                )
            }
            .buttonStyle(.plain)

            SettingsNavigationLink(destination: .storage) {
                BentoSettingsTile(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    tint: BentoStyle.mustard
                )
            }
            .buttonStyle(.plain)

            // 保留下载入口结构，由功能开关统一控制。
            if AppConfig.Features.downloadEnabled {
                SettingsNavigationLink(destination: .download) {
                    BentoSettingsTile(
                        icon: .download,
                        title: String(localized: "settings_download_manage"),
                        value: "DL",
                        tint: BentoStyle.salmon
                    )
                }
                .buttonStyle(.plain)
            }

            SettingsNavigationLink(destination: .about) {
                BentoSettingsTile(
                    icon: .infoCircle,
                    title: String(localized: "settings_about"),
                    value: appVersion,
                    tint: BentoStyle.nori
                )
            }
            .buttonStyle(.plain)
        }
    }

}
