//
//  SettingsView.swift
//  Monologue
//
//  设置界面
//

import SwiftUI

private func settingsText(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func settingsFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: settingsText(key), locale: Locale.current, arguments: arguments)
}

private func themedSettingsFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
    if MangaStyle.isActive {
        return MangaStyle.comicFont(size, weight: weight == .regular ? .bold : weight)
    }
    if PetWhiteStyle.isActive {
        return PetWhiteStyle.labelFont(size, weight: weight == .bold ? .black : weight)
    }
    if NeumorphicStyle.isActive {
        return NeumorphicStyle.labelFont(size, weight: weight)
    }
    if SignalStyle.isActive {
        return SignalStyle.labelFont(size, weight: weight)
    }
    if BentoStyle.isActive {
        return BentoStyle.labelFont(size, weight: weight == .bold ? .heavy : weight)
    }
    if CapsuleStyle.isActive {
        return CapsuleStyle.labelFont(size, weight: weight == .bold ? .bold : weight)
    }
    if SequoiaStyle.isActive {
        return SequoiaStyle.labelFont(size, weight: weight == .bold ? .semibold : weight)
    }
    if MujiStyle.isActive {
        return MujiStyle.labelFont(size, weight: weight == .bold ? .semibold : weight)
    }
    return .system(size: size, weight: weight, design: .rounded)
}

private func themedSettingsPrimaryColor() -> Color {
    if MangaStyle.isActive { return MangaStyle.ink }
    if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
    if MujiStyle.isActive { return MujiStyle.ink }
    if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
    if CapsuleStyle.isActive { return CapsuleStyle.ink }
    if SequoiaStyle.isActive { return SequoiaStyle.ink }
    if SignalStyle.isActive { return SignalStyle.ink }
    if BentoStyle.isActive { return BentoStyle.ink }
    return .monologueTextPrimary
}

private func themedSettingsSecondaryColor() -> Color {
    if MangaStyle.isActive { return MangaStyle.inkSub }
    if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
    if MujiStyle.isActive { return MujiStyle.inkSoft }
    if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
    if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
    if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
    if SignalStyle.isActive { return SignalStyle.inkSoft }
    if BentoStyle.isActive { return BentoStyle.inkSoft }
    return .monologueTextSecondary
}

struct ThemedSettingsBackground: View {
    var body: some View {
        ThemedPageBackground(useRenderLayer: true)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var playlistCloudSync = LocalPlaylistCloudSyncManager.shared
    @State private var cacheSize: String = .init(localized: "settings_calculating")
    @AppStorage("qqDevMode") private var qqDevMode = false
    @State private var apiTokenInput: String = SecureConfig.apiToken ?? ""
    @State private var tokenSaved = false
    @State private var isHeaderCardExpanded = false

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                LazyVStack(spacing: themedSettingsSpacing) {
                    settingsContent
                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, settingsOuterHorizontalPadding)
                .iPadContentWidth(700)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            updateCacheSize()
            apiTokenInput = SecureConfig.apiToken ?? ""
            isHeaderCardExpanded = false
        }
        .preferredColorScheme(settings.preferredColorScheme)
    }

    private var themedSettingsSpacing: CGFloat {
        if MangaStyle.isActive { return 16 }
        if PetWhiteStyle.isActive { return 16 }
        if NeumorphicStyle.isActive { return 18 }
        if SignalStyle.isActive { return 17 }
        if CapsuleStyle.isActive { return 16 }
        if SequoiaStyle.isActive { return 16 }
        if MujiStyle.isActive { return 18 }
        return 20
    }

    private var settingsOuterHorizontalPadding: CGFloat {
        DeviceLayout.settingsSectionHorizontalPadding
    }

    @ViewBuilder
    private var settingsContent: some View {
        if MangaStyle.isActive {
            mangaSettingsContent
        } else if PetWhiteStyle.isActive {
            petWhiteSettingsContent
        } else if NeumorphicStyle.isActive {
            neumorphicSettingsContent
        } else if SignalStyle.isActive {
            signalSettingsContent
        } else if BentoStyle.isActive {
            bentoSettingsContent
        } else if CapsuleStyle.isActive {
            capsuleSettingsContent
        } else if SequoiaStyle.isActive {
            sequoiaSettingsContent
        } else if LiquidGlassStyle.isActive {
            liquidGlassSettingsContent
        } else if MujiStyle.isActive {
            mujiSettingsContent
        } else {
            defaultSettingsContent
        }
    }

    @ViewBuilder
    private var defaultSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)
        settingsHeaderCard
        themeSection
        navigationCardsSection
        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var mangaSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        settingsHeaderCard

        mangaSettingsModePanel
        mangaSettingsPortalGrid

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var petWhiteSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        petWhiteSettingsModeBoard
        petWhiteSettingsPortalGrid
        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var neumorphicSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var signalSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var bentoSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        settingsHeaderCard
        bentoSettingsModeBlock
        bentoSettingsGrid

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var capsuleSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        capsuleModeDeck
        capsuleSettingsMatrix

        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var sequoiaSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var liquidGlassSettingsContent: some View {
        liquidGlassSettingsHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        liquidGlassModeDeck

        liquidGlassSettingsMatrix

        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var mujiSettingsContent: some View {
        settingsMainPageHeader
            .padding(.horizontal, -settingsOuterHorizontalPadding)

        settingsHeaderCard
        mujiSettingsNotebook

        if qqDevMode {
            otherSection
        }
    }

    private var petWhiteSettingsModeBoard: some View {
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

    private var petWhiteSettingsPortalGrid: some View {
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
                NavigationLink(destination: AppearanceSettingsView()) {
                    PetWhiteSettingsPortalCard(
                        icon: .sparkle,
                        title: settingsText("settings_navigation_appearance_title"),
                        badge: "STYLE",
                        tint: PetWhiteStyle.dogOrange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: PlaybackSettingsView()) {
                    PetWhiteSettingsPortalCard(
                        icon: .soundQuality,
                        title: settingsText("settings_navigation_playback_title"),
                        badge: "PLAY",
                        tint: PetWhiteStyle.mint
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: CloudSyncSettingsView()) {
                    PetWhiteSettingsPortalCard(
                        icon: .cloud,
                        title: settingsText("settings_navigation_cloud_sync_title"),
                        badge: hasToken ? "SYNC" : "OFF",
                        tint: PetWhiteStyle.sky
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: StorageManageView()) {
                    PetWhiteSettingsPortalCard(
                        icon: .storage,
                        title: String(localized: "settings_storage_manage"),
                        badge: cacheSize,
                        tint: PetWhiteStyle.butter
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: DownloadManageView()) {
                    PetWhiteSettingsPortalCard(
                        icon: .download,
                        title: String(localized: "settings_download_manage"),
                        badge: "DL",
                        tint: PetWhiteStyle.blush
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: AboutView()) {
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

    private var settingsMainPageHeader: some View {
        SettingsScrollablePageHeader(
            title: String(localized: "settings_title"),
            eyebrow: "SETTINGS",
            icon: .infoCircle
        )
    }

    private var capsuleModeDeck: some View {
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

    private var capsuleSettingsMatrix: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            NavigationLink(destination: AppearanceSettingsView()) {
                CapsuleSettingsTile(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    tint: CapsuleStyle.accent
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: PlaybackSettingsView()) {
                CapsuleSettingsTile(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    tint: CapsuleStyle.violet
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CloudSyncSettingsView()) {
                CapsuleSettingsTile(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    tint: CapsuleStyle.mint
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StorageManageView()) {
                CapsuleSettingsTile(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    tint: CapsuleStyle.cyan
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: DownloadManageView()) {
                CapsuleSettingsTile(
                    icon: .download,
                    title: String(localized: "settings_download_manage"),
                    value: "DL",
                    tint: CapsuleStyle.amber
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: AboutView()) {
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

    private var liquidGlassSettingsHeader: some View {
        HStack(spacing: 14) {
            LiquidGlassDropletMark(tint: LiquidGlassStyle.accent)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(LiquidGlassStyle.accentGradient)
                        .frame(width: 26, height: 5)
                    Capsule()
                        .fill(LiquidGlassStyle.mint.opacity(0.44))
                        .frame(width: 10, height: 5)
                }

                Text(String(localized: "settings_title"))
                    .font(LiquidGlassStyle.titleFont(27, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            LiquidGlassIconBadge(icon: .settings, tint: LiquidGlassStyle.cyan, size: 44)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 4)
    }

    private var liquidGlassModeDeck: some View {
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

    private var liquidGlassSettingsMatrix: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            NavigationLink(destination: AppearanceSettingsView()) {
                LiquidGlassSettingsTile(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    tint: LiquidGlassStyle.accent
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: PlaybackSettingsView()) {
                LiquidGlassSettingsTile(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    tint: LiquidGlassStyle.violet
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CloudSyncSettingsView()) {
                LiquidGlassSettingsTile(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    tint: LiquidGlassStyle.mint
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StorageManageView()) {
                LiquidGlassSettingsTile(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    tint: LiquidGlassStyle.cyan
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: DownloadManageView()) {
                LiquidGlassSettingsTile(
                    icon: .download,
                    title: String(localized: "settings_download_manage"),
                    value: "DL",
                    tint: LiquidGlassStyle.amber
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: AboutView()) {
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

    private var bentoSettingsModeBlock: some View {
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

    private var bentoSettingsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: BentoStyle.blockSpacing),
                GridItem(.flexible(), spacing: BentoStyle.blockSpacing),
            ],
            spacing: BentoStyle.blockSpacing
        ) {
            NavigationLink(destination: AppearanceSettingsView()) {
                BentoSettingsTile(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    tint: BentoStyle.tomato
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: PlaybackSettingsView()) {
                BentoSettingsTile(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    tint: BentoStyle.ocean
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: CloudSyncSettingsView()) {
                BentoSettingsTile(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    tint: BentoStyle.matcha
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StorageManageView()) {
                BentoSettingsTile(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    tint: BentoStyle.mustard
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: DownloadManageView()) {
                BentoSettingsTile(
                    icon: .download,
                    title: String(localized: "settings_download_manage"),
                    value: "DL",
                    tint: BentoStyle.salmon
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: AboutView()) {
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


    // MARK: - 日夜模式

    private var themeSection: some View {
        SettingsSection(title: String(localized: "settings_theme_mode_section_title")) {
            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode
            )
        }
    }

    // MARK: - 导航入口卡片

    private var navigationCardsSection: some View {
        VStack(spacing: 14) {
            SettingsLinkRow(
                icon: .sparkle,
                title: settingsText("settings_navigation_appearance_title"),
                subtitle: settingsText("settings_navigation_appearance_subtitle"),
                destination: AppearanceSettingsView(),
                verticalPadding: 16
            )
            .themedSettingsStandaloneCard(cornerRadius: 18, tint: MangaStyle.bubblePink)

            SettingsLinkRow(
                icon: .soundQuality,
                title: settingsText("settings_navigation_playback_title"),
                subtitle: settingsText("settings_navigation_playback_subtitle"),
                destination: PlaybackSettingsView(),
                verticalPadding: 16
            )
            .themedSettingsStandaloneCard(cornerRadius: 18, tint: MangaStyle.bubbleBlue)

            SettingsLinkRow(
                icon: .cloud,
                title: settingsText("settings_navigation_cloud_sync_title"),
                subtitle: hasToken ? playlistSyncStatusText : settingsText("settings_navigation_cloud_sync_disabled"),
                destination: CloudSyncSettingsView(),
                verticalPadding: 16
            )
            .themedSettingsStandaloneCard(cornerRadius: 18, tint: MangaStyle.labelYellow)
        }
    }

    private var mangaSettingsModePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "settings_theme_mode_section_title"), mark: .star)

            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode
            )
            .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: MangaStyle.bubbleWhite))
        }
    }

    private var mangaSettingsPortalGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            MangaSectionTitle(title: String(localized: "profile_settings"), mark: .heart)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                NavigationLink(destination: AppearanceSettingsView()) {
                    MangaSettingsPortalCard(
                        icon: .sparkle,
                        title: settingsText("settings_navigation_appearance_title"),
                        badge: "STYLE",
                        tint: MangaStyle.bubblePink
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: PlaybackSettingsView()) {
                    MangaSettingsPortalCard(
                        icon: .soundQuality,
                        title: settingsText("settings_navigation_playback_title"),
                        badge: "PLAY",
                        tint: MangaStyle.bubbleBlue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: CloudSyncSettingsView()) {
                    MangaSettingsPortalCard(
                        icon: .cloud,
                        title: settingsText("settings_navigation_cloud_sync_title"),
                        badge: hasToken ? "SYNC" : "OFF",
                        tint: MangaStyle.labelYellow
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: StorageManageView()) {
                    MangaSettingsPortalCard(
                        icon: .storage,
                        title: String(localized: "settings_storage_manage"),
                        badge: cacheSize,
                        tint: MangaStyle.mint
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: DownloadManageView()) {
                    MangaSettingsPortalCard(
                        icon: .download,
                        title: String(localized: "settings_download_manage"),
                        badge: "DL",
                        tint: MangaStyle.decoBlue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: AboutView()) {
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

    private var mujiSettingsNotebook: some View {
        VStack(alignment: .leading, spacing: 14) {
            MujiSectionTitle(title: String(localized: "profile_settings"))

            VStack(spacing: 0) {
                SettingsThemeRow(
                    icon: .sparkle,
                    title: String(localized: "settings_theme_mode"),
                    selection: $settings.themeMode
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .sparkle,
                    title: settingsText("settings_navigation_appearance_title"),
                    value: "STYLE",
                    destination: AppearanceSettingsView()
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .soundQuality,
                    title: settingsText("settings_navigation_playback_title"),
                    value: "PLAY",
                    destination: PlaybackSettingsView()
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .cloud,
                    title: settingsText("settings_navigation_cloud_sync_title"),
                    value: hasToken ? "SYNC" : "OFF",
                    destination: CloudSyncSettingsView()
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .storage,
                    title: String(localized: "settings_storage_manage"),
                    value: cacheSize,
                    destination: StorageManageView()
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .download,
                    title: String(localized: "settings_download_manage"),
                    value: "DOWNLOAD",
                    destination: DownloadManageView()
                )

                MujiSettingsDivider()

                MujiSettingsLedgerLink(
                    icon: .infoCircle,
                    title: String(localized: "settings_about"),
                    value: appVersion,
                    destination: AboutView()
                )
            }
            .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
        }
    }

    // MARK: - 存储管理

    private var cacheSection: some View {
        SettingsSection(title: String(localized: "settings_storage")) {
            SettingsLinkRow(
                icon: .storage,
                title: String(localized: "settings_storage_manage"),
                subtitle: String(localized: "settings_storage_manage_desc"),
                value: cacheSize,
                destination: StorageManageView()
            )
        }
    }

    // MARK: - 下载管理

    private var downloadSection: some View {
        SettingsSection(title: String(localized: "settings_download_manage")) {
            SettingsLinkRow(
                icon: .download,
                title: String(localized: "settings_download_manage"),
                destination: DownloadManageView()
            )
        }
    }

    // MARK: - 设置顶部卡片

    private var hasToken: Bool {
        !(SecureConfig.apiToken ?? "").isEmpty
    }

    private var maskedToken: String {
        let token = SecureConfig.apiToken ?? ""
        guard token.count > 2 else { return String(repeating: "•", count: 8) }
        return String(token.prefix(2)) + String(repeating: "•", count: token.count - 2)
    }

    private var headerActionButtonWidth: CGFloat {
        DeviceLayout.isPad ? 96 : 90
    }

    private var headerFooterText: String {
        if hasToken {
            return settingsText("settings_header_footer_authorized")
        }
        return settingsText("settings_header_footer_unauthorized")
    }

    private var headerFooterIcon: MonologueIcon.IconType {
        hasToken ? .liked : .infoCircle
    }

    private var headerFooterIconColor: Color {
        if MangaStyle.isActive {
            return hasToken ? MangaStyle.accentPink : MangaStyle.decoBlue
        }
        if NeumorphicStyle.isActive {
            return hasToken ? NeumorphicStyle.sage : NeumorphicStyle.accent
        }
        if SignalStyle.isActive {
            return hasToken ? SignalStyle.olive : SignalStyle.accent
        }
        if SequoiaStyle.isActive {
            return hasToken ? SequoiaStyle.green : SequoiaStyle.accent
        }
        if MujiStyle.isActive {
            return hasToken ? MujiStyle.tea : MujiStyle.clay
        }
        return hasToken ? Color.pink : Color.monologueAccent
    }

    private var headerFooterTextColor: Color {
        if MangaStyle.isActive {
            return hasToken ? MangaStyle.inkSub : MangaStyle.inkMuted
        }
        if NeumorphicStyle.isActive {
            return hasToken ? NeumorphicStyle.inkSoft : NeumorphicStyle.inkMuted
        }
        if SignalStyle.isActive {
            return hasToken ? SignalStyle.inkSoft : SignalStyle.inkMuted
        }
        if SequoiaStyle.isActive {
            return hasToken ? SequoiaStyle.inkSoft : SequoiaStyle.inkMuted
        }
        if BentoStyle.isActive {
            return hasToken ? BentoStyle.inkSoft : BentoStyle.inkMuted
        }
        if MujiStyle.isActive {
            return hasToken ? MujiStyle.inkSoft : MujiStyle.inkMuted
        }
        return hasToken ? Color.monologueTextSecondary.opacity(0.72) : Color.monologueTextSecondary.opacity(0.56)
    }

    private var headerStatusButtonBackground: Color {
        if MangaStyle.isActive {
            return tokenSaved || hasToken ? MangaStyle.bubbleBlue : MangaStyle.bubbleWhite
        }
        if NeumorphicStyle.isActive {
            return tokenSaved || hasToken ? NeumorphicStyle.sage.opacity(0.16) : NeumorphicStyle.surfacePressed.opacity(0.76)
        }
        if SignalStyle.isActive {
            return tokenSaved || hasToken ? SignalStyle.olive.opacity(0.16) : SignalStyle.controlPressed.opacity(0.82)
        }
        if BentoStyle.isActive {
            return tokenSaved || hasToken ? BentoStyle.matcha.opacity(0.16) : BentoStyle.paperWarm.opacity(0.78)
        }
        if SequoiaStyle.isActive {
            return tokenSaved || hasToken ? SequoiaStyle.green.opacity(0.14) : SequoiaStyle.materialList.opacity(0.86)
        }
        if MujiStyle.isActive {
            return tokenSaved || hasToken ? MujiStyle.tea.opacity(0.18) : MujiStyle.surface.opacity(0.82)
        }
        if tokenSaved || hasToken {
            return Color.green.opacity(0.12)
        }
        return Color.monologueSeparator.opacity(0.5)
    }

    private var headerPrimaryTextColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if BentoStyle.isActive { return BentoStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        return .monologueTextPrimary
    }

    private var headerSecondaryTextColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var headerDeveloperIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if BentoStyle.isActive { return BentoStyle.tomato }
        if SequoiaStyle.isActive { return SequoiaStyle.aqua }
        if MujiStyle.isActive { return MujiStyle.tea }
        return .green
    }

    private var headerSoftFill: Color {
        if MangaStyle.isActive { return MangaStyle.bubbleWhite.opacity(0.9) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.62) }
        if SignalStyle.isActive { return SignalStyle.controlPressed.opacity(0.78) }
        if BentoStyle.isActive { return BentoStyle.paperWarm.opacity(0.82) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.82) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.82) }
        return Color.monologueSeparator.opacity(0.4)
    }

    private var headerSoftStroke: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.5) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.5) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(0.56) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.58) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.5) }
        return Color.clear
    }

    private var headerPrimaryActionFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if BentoStyle.isActive { return BentoStyle.tomato }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MujiStyle.isActive { return MujiStyle.clay }
        return .monologueAccent
    }

    private var headerPrimaryActionForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        if SignalStyle.isActive { return SignalStyle.onAccent }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if MujiStyle.isActive { return MujiStyle.onTint }
        return Color(light: .white, dark: .black)
    }

    private var headerAvatarRadius: CGFloat {
        MangaStyle.isActive ? 16 : (MujiStyle.isActive ? 10 : (BentoStyle.isActive ? 17 : (SignalStyle.isActive ? 16 : (NeumorphicStyle.isActive ? 16 : (SequoiaStyle.isActive ? 14 : 14)))))
    }

    private var playlistSyncStatusText: String {
        if let message = playlistCloudSync.lastStatusMessage, !message.isEmpty {
            if let date = playlistCloudSync.lastSyncedAt {
                return "\(message) · \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            return message
        }
        return settingsText("playlist_sync_idle")
    }

    private var settingsHeaderCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("WeChatAvatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: headerAvatarRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: headerAvatarRadius, style: .continuous)
                            .stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.6 : 0.7)
                    }
                    .background {
                        if MangaStyle.isActive {
                            RoundedRectangle(cornerRadius: headerAvatarRadius, style: .continuous)
                                .fill(MangaStyle.strokeInk)
                                .offset(x: 2, y: 2)
                        }
                    }
                    .shadow(color: .black.opacity(MangaStyle.isActive ? 0.02 : 0.08), radius: 3, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ZIJIU522")
                        .font(MangaStyle.isActive ? MangaStyle.titleFont(18, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .medium) : .system(size: 17, weight: .bold, design: .rounded)))
                        .foregroundColor(headerPrimaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    HStack(spacing: 5) {
                        MonologueIcon(icon: .comment, size: 12, color: headerDeveloperIconColor)
                        Text(settingsText("settings_developer_status"))
                            .font(themedSettingsFont(11, weight: .medium))
                            .foregroundColor(headerSecondaryTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    NavigationLink(
                        destination: AboutView()
                    ) {
                        Text(String(localized: "settings_about"))
                            .font(themedSettingsFont(11, weight: .semibold))
                            .foregroundColor(headerSecondaryTextColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(headerSoftFill)
                                    .overlay(Capsule().stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6))
                            }
                    }
                    .frame(width: headerActionButtonWidth)
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))

                    Button {
                        apiTokenInput = SecureConfig.apiToken ?? apiTokenInput
                        isHeaderCardExpanded.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            MonologueIcon(
                                icon: hasToken ? .lock : .unlock,
                                size: 10,
                                color: tokenStatusColor
                            )

                            Text(tokenStatusText)
                                .font(themedSettingsFont(11, weight: .semibold))
                                .minimumScaleFactor(0.84)

                            PetWhiteDisclosureChevron(
                                isExpanded: isHeaderCardExpanded,
                                size: 10,
                                petWhiteSize: 14,
                                color: tokenStatusColor,
                                lineWidth: 1.8
                            )
                        }
                        .foregroundColor(tokenStatusColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(headerStatusButtonBackground)
                                .overlay(Capsule().stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6))
                        )
                    }
                    .frame(width: headerActionButtonWidth)
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
                }
                .layoutPriority(2)
            }

            SettingsHeaderReveal(isExpanded: isHeaderCardExpanded) {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Button {
                            PlatformPasteboard.copy("Fallin-Out0122")
                            HapticManager.shared.success()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                wechatCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { wechatCopied = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: wechatCopied ? .checkmark : .save, size: 13, color: wechatCopied ? headerDeveloperIconColor : headerPrimaryTextColor)
                                Text(wechatCopied ? settingsText("settings_contact_copied") : "Fallin-Out0122")
                                    .font(themedSettingsFont(13, weight: .semibold))
                            }
                            .foregroundColor(wechatCopied ? headerDeveloperIconColor : headerPrimaryTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(wechatCopied ? headerDeveloperIconColor.opacity(0.13) : headerSoftFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6)
                                    )
                            )
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))

                        Button {
                            PlatformPasteboard.copy("Fallin-Out0122")
                            HapticManager.shared.success()
                            if let url = URL(string: "weixin://dl/contacts") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .send, size: 13, color: headerPrimaryActionForeground)
                                Text(settingsText("settings_open_wechat"))
                                    .font(themedSettingsFont(13, weight: .semibold))
                            }
                            .foregroundColor(headerPrimaryActionForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(headerPrimaryActionFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(MangaStyle.isActive ? MangaStyle.strokeInk : Color.clear, lineWidth: 1.3)
                                    )
                            )
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            MonologueIcon(icon: hasToken ? .lock : .unlock, size: 14, color: tokenStatusColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(settingsText("access_token_title"))
                                    .font(themedSettingsFont(12, weight: .semibold))
                                    .foregroundColor(headerPrimaryTextColor)

                                if hasToken {
                                    if OnlineAccessManager.shared.lastTokenStatus == .expired {
                                        Text("当前已过期：" + maskedToken)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.red.opacity(0.8))
                                    } else {
                                        Text(settingsFormat("settings_token_authorized_format", maskedToken))
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(headerSecondaryTextColor)
                                    }
                                } else {
                                    Text(settingsText("settings_token_hint"))
                                        .font(themedSettingsFont(13, weight: .medium))
                                        .foregroundColor(headerSecondaryTextColor.opacity(0.78))
                                }
                            }

                            Spacer()
                        }

                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                MonologueIcon(icon: .unlock, size: 14, color: tokenStatusColor)
                                TextField(settingsText("access_token_input_placeholder"), text: $apiTokenInput)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .monologueTextInputBehavior()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(headerSoftFill.opacity(MangaStyle.isActive ? 0.74 : 1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6)
                                    )
                            )

                            Button {
                                let trimmed = apiTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                apiTokenInput = trimmed

                                Task {
                                    let status = await onlineAccess.submitToken(trimmed)

                                    await MainActor.run {
                                        switch status {
                                        case .valid, .validationDisabled:
                                            HapticManager.shared.success()
                                            tokenSaved = !trimmed.isEmpty
                                            isHeaderCardExpanded = trimmed.isEmpty

                                            if tokenSaved {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                    withAnimation { tokenSaved = false }
                                                }
                                            }
                                        case .missing:
                                            tokenSaved = false
                                            isHeaderCardExpanded = true
                                        case .invalid:
                                            AlertManager.shared.show(
                                                title: settingsText("access_invalid_title"),
                                                message: settingsText("access_invalid_message"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        case .expired:
                                            AlertManager.shared.show(
                                                title: String(localized: "Token 已过期"),
                                                message: String(localized: "您输入的 Token 已经过期，请获取新的 Token 或者重新授权。"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        case .deviceMismatch:
                                            AlertManager.shared.show(
                                                title: String(localized: "设备不匹配"),
                                                message: String(localized: "此 Token 已绑定到其他设备，无法在当前设备使用。"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        case .networkError:
                                            AlertManager.shared.show(
                                                title: settingsText("access_network_error_title"),
                                                message: settingsText("access_network_error_message"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        }
                                    }
                                }
                            } label: {
                                Text(settingsText("common_save"))
                                    .font(themedSettingsFont(13, weight: .semibold))
                                    .foregroundColor(headerPrimaryActionForeground)
                                    .frame(width: 44, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(headerPrimaryActionFill)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(MangaStyle.isActive ? MangaStyle.strokeInk : Color.clear, lineWidth: 1.3)
                                            )
                                    )
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
                        }
                    }
                }
                .padding(.top, 16)
            }

            HStack(spacing: 6) {
                MonologueIcon(icon: headerFooterIcon, size: 11, color: headerFooterIconColor)

                Text(headerFooterText)
                    .font(themedSettingsFont(12, weight: .medium))
                    .foregroundColor(headerFooterTextColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, isHeaderCardExpanded ? 14 : 12)
            .transition(.opacity)
        }
        .padding(16)
        .themedSettingsStandaloneCard(cornerRadius: 22, tint: MangaStyle.paperWarm)
    }

    private var otherSection: some View {
        SettingsSection(title: String(localized: "settings_other")) {
            VStack(spacing: 0) {
                SettingsLinkRow(
                    icon: .logDebug,
                    title: String(localized: "settings_debug_log"),
                    subtitle: String(localized: "settings_debug_log_desc"),
                    value: "\(AppLogger.getAllLogs().count)",
                    destination: DebugLogView()
                )
            }
        }
    }

    @State private var wechatCopied = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var tokenStatusText: String {
        if tokenSaved {
            return settingsText("settings_token_saved")
        }
        if hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return String(localized: "已过期")
            }
            return settingsText("settings_token_authorized")
        }
        return settingsText("settings_token_unauthorized")
    }

    private var tokenStatusColor: Color {
        if tokenSaved || hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return .red
            }
            if MangaStyle.isActive { return MangaStyle.decoBlue }
            if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
            if CapsuleStyle.isActive { return CapsuleStyle.mint }
            if SequoiaStyle.isActive { return SequoiaStyle.green }
            if MujiStyle.isActive { return MujiStyle.tea }
            return .green
        }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        return .monologueTextSecondary
    }

    // MARK: - Actions

    private func updateCacheSize() {
        Task {
            let cacheTotal = await Task.detached(priority: .utility) {
                let fm = FileManager.default
                var total: Int64 = 0

                if let cacheBase = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let cacheDir = cacheBase.appendingPathComponent("MonologueCache")
                    if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: .skipsHiddenFiles) {
                        for file in files {
                            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
                        }
                    }
                }

                if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    let dbPath = appSupport.appendingPathComponent("default.store").path
                    for ext in ["", ".wal", ".shm"] {
                        let path = ext.isEmpty ? dbPath : dbPath + ext
                        if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? Int64 {
                            total += size
                        }
                    }
                }

                return total
            }.value

            let total = cacheTotal + DownloadManager.shared.totalDownloadSize()

            let formattedSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)

            cacheSize = formattedSize
        }
    }

    private func clearCache() {
        OptimizedCacheManager.shared.clearAll()
        CacheManager.shared.clearAll()
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        updateCacheSize()
    }
}

// MARK: - Themed Settings Navigation

private struct PetWhiteSettingsPortalCard: View {
    let icon: MonologueIcon.IconType
    let title: String
    let badge: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                PetWhiteIconBadge(icon: icon, tint: tint, size: 38)

                Spacer(minLength: 8)

                PetWhitePill(text: badge, tint: tint)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(title)
                .font(PetWhiteStyle.titleFont(15, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 116, alignment: .topLeading)
        .padding(14)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 16,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MangaSettingsPortalCard: View {
    let icon: MonologueIcon.IconType
    let title: String
    let badge: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                MangaIconBadge(icon: icon, size: 38, tint: tint)

                Spacer()

                MangaLabel(text: badge, tint: MangaStyle.bubbleWhite, small: true)
                    .frame(maxWidth: 74, alignment: .trailing)
            }

            Text(title)
                .font(MangaStyle.comicFont(15, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 116, alignment: .topLeading)
        .padding(14)
        .background(MangaCardBackground(cornerRadius: 16, elevated: true, tint: tint.opacity(0.72)))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MujiSettingsLedgerLink<Destination: View>: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                MujiIconBadge(icon: icon, tint: ledgerTint, size: 34)

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
        .buttonStyle(.plain)
    }

    private var ledgerTint: Color {
        switch icon {
        case .cloud:
            return MujiStyle.tea
        case .download, .storage:
            return MujiStyle.indigo
        case .soundQuality:
            return MujiStyle.straw
        default:
            return MujiStyle.clay
        }
    }
}

private struct MujiSettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(MujiStyle.separator.opacity(0.58))
            .frame(height: 0.6)
            .padding(.leading, 64)
            .padding(.trailing, 14)
    }
}

// MARK: - Settings Icon Badge

struct SettingsIconBadge: View {
    let icon: MonologueIcon.IconType
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        if MangaStyle.isActive {
            MonologueIcon(
                icon: icon,
                size: 15,
                color: ThemeColorCustomization.mangaExtraColor(suffix: "settingsIcon", lightFallback: "17151F", darkFallback: "17151F"),
                lineWidth: 1.8
            )
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MangaStyle.accentPink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: 1.7)
            )
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MangaStyle.strokeInk)
                    .offset(x: 1.8, y: 1.8)
            )
        } else if NeumorphicStyle.isActive {
            NeumorphicIconBadge(icon: icon, tint: NeumorphicStyle.accent, size: 32)
        } else if SignalStyle.isActive {
            SignalIconBadge(icon: icon, tint: SignalStyle.accent, size: 32)
        } else if CapsuleStyle.isActive {
            CapsuleIconBadge(icon: icon, tint: CapsuleStyle.accent, size: 32)
        } else if PetWhiteStyle.isActive {
            PetWhiteIconBadge(icon: icon, tint: petWhiteSettingsIconTint, size: 36)
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(BentoStyle.tomato.opacity(0.14))
                .frame(width: 32, height: 32)
                .overlay(
                    MonologueIcon(icon: icon, size: 15, color: BentoStyle.tomato, lineWidth: 1.65)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65)
                )
        } else if SequoiaStyle.isActive {
            SequoiaIconBadge(icon: icon, tint: SequoiaStyle.accent, size: 32)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(MujiStyle.clay.opacity(0.11))
                .frame(width: 31, height: 31)
                .overlay(
                    MonologueIcon(
                        icon: icon,
                        size: 14,
                        color: ThemeColorCustomization.visibleTintColor(MujiStyle.clay, darkFallback: MujiStyle.ink),
                        lineWidth: 1.4
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.monologueAccent.opacity(0.14))
                    .frame(width: 30, height: 30)
                MonologueIcon(
                    icon: icon,
                    size: 14,
                    color: ThemeColorCustomization.visibleTintColor(
                        Color.monologueAccent,
                        darkFallback: Color.monologueTextPrimary
                    ),
                    lineWidth: 1.6
                )
            }
        }
    }

    private var petWhiteSettingsIconTint: Color {
        switch icon {
        case .settings, .sparkle:
            return PetWhiteStyle.mint
        case .playerTheme, .tabBar, .gridSquare:
            return PetWhiteStyle.butter
        case .download, .storage, .cloud:
            return PetWhiteStyle.sky
        default:
            return PetWhiteStyle.sky
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(sectionTitleFont)
                .foregroundColor(sectionTitleColor)
                .padding(.leading, 16)
                .tracking(MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive || BentoStyle.isActive ? 1.0 : 0.4)

            VStack(spacing: 0) {
                content
            }
            .background {
                if MangaStyle.isActive {
                    MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite)
                } else if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 15, elevated: false)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true)
                } else if CapsuleStyle.isActive {
                    CapsuleSurfaceBackground(cornerRadius: 22, elevated: true, tint: CapsuleStyle.surface.opacity(0.9))
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 16, elevated: true, fill: SignalStyle.device)
                } else if BentoStyle.isActive {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(BentoStyle.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(BentoStyle.hairline.opacity(0.56), lineWidth: 0.7)
                        )
                }
            }
            .monologueGlassConditionalForSettings(cornerRadius: 22)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var sectionTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(12, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(11, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.labelFont(11, weight: .bold) }
        if BentoStyle.isActive { return BentoStyle.labelFont(11, weight: .heavy) }
        return .system(size: 12, weight: .bold, design: .rounded)
    }

    private var sectionTitleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkMuted }
        return Color.secondary
    }
}

private extension View {
    @ViewBuilder
    func monologueGlassConditionalForSettings(cornerRadius: CGFloat) -> some View {
        if MangaStyle.isActive || PetWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || SequoiaStyle.isActive || SignalStyle.isActive || BentoStyle.isActive {
            self
        } else {
            monologueGlass(cornerRadius: cornerRadius)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    func themedSettingsStandaloneCard(cornerRadius: CGFloat, tint: Color = MangaStyle.bubbleWhite) -> some View {
        if MangaStyle.isActive {
            background(MangaCardBackground(cornerRadius: cornerRadius, elevated: true, tint: tint))
        } else if PetWhiteStyle.isActive {
            background(
                PetWhiteSurfaceBackground(
                    cornerRadius: min(max(cornerRadius, 16), 28),
                    elevated: true,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: tint
                )
            )
        } else if MujiStyle.isActive {
            background(MujiPaperCardBackground(cornerRadius: min(cornerRadius, 14), elevated: true))
        } else if NeumorphicStyle.isActive {
            background(NeumorphicSurfaceBackground(cornerRadius: min(max(cornerRadius, 18), 26), elevated: true, lightweight: true))
        } else if CapsuleStyle.isActive {
            background(
                CapsuleSurfaceBackground(
                    cornerRadius: min(max(cornerRadius, 18), 26),
                    elevated: true,
                    tint: CapsuleStyle.surface.opacity(0.9)
                )
            )
        } else if SequoiaStyle.isActive {
            background(SequoiaSurfaceBackground(cornerRadius: min(max(cornerRadius, 16), 24), elevated: true, role: .chrome))
        } else if SignalStyle.isActive {
            background(SignalSurfaceBackground(cornerRadius: min(max(cornerRadius, 12), 18), elevated: true, fill: SignalStyle.device))
        } else if BentoStyle.isActive {
            background(
                RoundedRectangle(cornerRadius: min(max(cornerRadius, 18), 26), style: .continuous)
                    .fill(BentoStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: min(max(cornerRadius, 18), 26), style: .continuous)
                            .stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.7)
                    )
            )
        } else {
            monologueGlass(cornerRadius: cornerRadius)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Settings Rows

struct SettingsSwitchToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme

    private var offTrackColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceTint.opacity(0.8) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed }
        if SignalStyle.isActive { return SignalStyle.controlPressed }
        if BentoStyle.isActive { return BentoStyle.paperWarm }
        return Color(light: Color.black.opacity(0.12), dark: Color.white.opacity(0.2))
    }

    private var offStrokeColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.45) }
        if CapsuleStyle.isActive { return CapsuleStyle.separator.opacity(0.48) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.72) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(0.52) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.62) }
        return Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.14))
    }

    private func knobColor(isOn: Bool) -> Color {
        if NeumorphicStyle.isActive {
            return isOn ? NeumorphicStyle.surfaceRaised : NeumorphicStyle.surface
        }
        if SequoiaStyle.isActive {
            return isOn ? SequoiaStyle.onAccent : SequoiaStyle.materialRaised
        }
        if CapsuleStyle.isActive {
            return isOn ? CapsuleStyle.onAccent : CapsuleStyle.surfaceRaised
        }
        if SignalStyle.isActive {
            return isOn ? SignalStyle.accent : SignalStyle.deviceRaised
        }
        if BentoStyle.isActive {
            return isOn ? BentoStyle.onAccent : BentoStyle.surface
        }
        if isOn {
            return colorScheme == .dark ? .black : .white
        }
        return .white
    }

    private func strokeColor(isOn: Bool) -> Color {
        if isOn {
            if SequoiaStyle.isActive {
                return SequoiaStyle.accent.opacity(colorScheme == .dark ? 0.28 : 0.16)
            }
            if BentoStyle.isActive {
                return BentoStyle.tomato.opacity(0.22)
            }
            if CapsuleStyle.isActive {
                return CapsuleStyle.accent.opacity(0.28)
            }
            return Color.monologueToggleTint.opacity(colorScheme == .dark ? 0.24 : 0.08)
        }
        return offStrokeColor
    }

    var trackSize: CGSize {
        CGSize(width: 52, height: 32)
    }

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? activeTrackColor : offTrackColor)
                    .overlay {
                        Capsule()
                            .stroke(strokeColor(isOn: configuration.isOn), lineWidth: 1)
                    }
                    .frame(width: trackSize.width, height: trackSize.height)

                Circle()
                    .fill(knobColor(isOn: configuration.isOn))
                    .frame(width: 28, height: 28)
                    .padding(2)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12), radius: 6, x: 0, y: 2)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.84), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }

    private var activeTrackColor: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.accent : (CapsuleStyle.isActive ? CapsuleStyle.accent : (BentoStyle.isActive ? BentoStyle.tomato : (SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monologueToggleTint)))
    }
}

struct SettingsToggleRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(themedSettingsFont(15, weight: .medium))
                    .foregroundColor(themedSettingsPrimaryColor())

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(themedSettingsFont(11, weight: .regular))
                        .foregroundColor(themedSettingsSecondaryColor())
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SettingsSwitchToggleStyle())
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

struct SettingsNavigationRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var subtitle: String?
    var subtitleColor: Color?
    var value: String?
    let action: () -> Void

    init(icon: MonologueIcon.IconType, title: String, value: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.action = action
    }

    init(icon: MonologueIcon.IconType, title: String, subtitle: String? = nil, subtitleColor: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(themedSettingsFont(15, weight: .medium))
                        .foregroundColor(themedSettingsPrimaryColor())

                    if let subtitle {
                        if let subtitleColor {
                            Text(subtitle)
                                .font(themedSettingsFont(11, weight: .regular))
                                .foregroundColor(subtitleColor)
                        } else {
                            Text(subtitle)
                                .font(themedSettingsFont(11, weight: .regular))
                                .foregroundColor(themedSettingsSecondaryColor())
                        }
                    }
                }

                Spacer()

                if let value {
                    Text(value)
                        .font(themedSettingsFont(14, weight: .regular))
                        .foregroundColor(themedSettingsSecondaryColor())
                }

                MonologueIcon(icon: .chevronRight, size: 11, color: themedSettingsSecondaryColor())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsLinkRow<Destination: View>: View {
    let icon: MonologueIcon.IconType
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    let destination: Destination
    /// 相对默认行略增高入口卡片（设置主页「外观/播放」等）
    var verticalPadding: CGFloat = 13

    var body: some View {
        NavigationLink(
            destination: destination
        ) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(themedSettingsFont(15, weight: .medium))
                        .foregroundColor(themedSettingsPrimaryColor())

                    if let subtitle {
                        Text(subtitle)
                            .font(themedSettingsFont(11, weight: .regular))
                            .foregroundColor(themedSettingsSecondaryColor())
                    }
                }

                Spacer()

                if let value {
                    Text(value)
                        .font(themedSettingsFont(13, weight: .medium))
                        .foregroundColor(themedSettingsSecondaryColor())
                }

                MonologueIcon(icon: .chevronRight, size: 11, color: themedSettingsSecondaryColor())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPadding)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsInfoRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: icon)

            Text(title)
                .font(themedSettingsFont(15, weight: .medium))
                .foregroundColor(themedSettingsPrimaryColor())

            Spacer()

            Text(value)
                .font(themedSettingsFont(14, weight: .regular))
                .foregroundColor(themedSettingsSecondaryColor())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

struct SettingsButtonRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var titleColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: icon)

                Text(title)
                    .font(themedSettingsFont(15, weight: .medium))
                    .foregroundColor(titleColor ?? themedSettingsPrimaryColor())

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 主题选择行

struct SettingsThemeRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    @Binding var selection: String
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    SettingsIconBadge(icon: summaryIcon)

                    Text(title)
                        .font(themedSettingsFont(16, weight: .medium))
                        .foregroundColor(themedSettingsPrimaryColor())

                    Spacer(minLength: 12)

                    Text(summaryText)
                        .font(themedSettingsFont(14, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)
                        .foregroundColor(themedSettingsSecondaryColor())

                    PetWhiteDisclosureChevron(
                        isExpanded: isExpanded,
                        size: 11,
                        color: themedSettingsSecondaryColor(),
                        lineWidth: 1.7
                    )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            SettingsHeaderReveal(isExpanded: isExpanded) {
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    themeModeOptionRow(
                        value: "system",
                        icon: .sparkle,
                        title: String(localized: "settings_theme_auto")
                    )

                    Divider()
                        .opacity(0.28)
                        .padding(.leading, 62)

                    themeModeOptionRow(
                        value: "light",
                        icon: .sun,
                        title: String(localized: "settings_theme_light")
                    )

                    Divider()
                        .opacity(0.28)
                        .padding(.leading, 62)

                    themeModeOptionRow(
                        value: "dark",
                        icon: .moon,
                        title: String(localized: "settings_theme_dark")
                    )
                }
            }
        }
    }

    private var summaryText: String {
        switch selection {
        case "light":
            return String(localized: "settings_theme_light")
        case "dark":
            return String(localized: "settings_theme_dark")
        default:
            return String(localized: "settings_theme_auto")
        }
    }

    private var summaryIcon: MonologueIcon.IconType {
        switch selection {
        case "light":
            return .sun
        case "dark":
            return .moon
        default:
            return icon
        }
    }

    private func themeModeOptionRow(value: String, icon: MonologueIcon.IconType, title: String) -> some View {
        let isSelected = selection == value

        return Button {
            selection = value
            isExpanded = false
        } label: {
            HStack(spacing: 14) {
                SettingsIconBadge(icon: icon)

                Text(title)
                    .font(themedSettingsFont(15, weight: .medium))
                    .foregroundColor(themedSettingsPrimaryColor())

                Spacer()

                if isSelected {
                    MonologueIcon(icon: .checkmark, size: 16, color: themedSettingsPrimaryColor(), lineWidth: 1.8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Header Reveal

private struct SettingsHeaderReveal<Content: View>: View {
    let isExpanded: Bool
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var measuredHeight: CGFloat = 0

    private var targetHeight: CGFloat {
        isExpanded ? measuredHeight : 0
    }

    private var revealAnimation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.12)
        }
        return .interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04)
    }

    private var revealOffset: CGFloat {
        isExpanded || reduceMotion ? 0 : -10
    }

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .opacity(isExpanded ? 1 : 0)
            .offset(y: revealOffset)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateMeasuredHeight(proxy.size.height) }
                        .onChange(of: proxy.size.height) { _, newValue in
                            updateMeasuredHeight(newValue)
                        }
                }
            }
            .frame(height: targetHeight, alignment: .top)
            .clipShape(Rectangle())
            .clipped()
            .contentShape(Rectangle())
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
            .animation(revealAnimation, value: isExpanded)
    }

    private func updateMeasuredHeight(_ height: CGFloat) {
        guard height > 0, abs(measuredHeight - height) > 0.5 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            measuredHeight = height
        }
    }
}

// MARK: - 悬浮栏样式选择行

struct SettingsFloatingBarRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    @Binding var selection: FloatingBarStyle
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    SettingsIconBadge(icon: icon)

                    Text(title)
                        .font(themedSettingsFont(16, weight: .medium))
                        .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (BentoStyle.isActive ? BentoStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))))))

                    Spacer(minLength: 12)

                    Text(selection.displayName)
                        .font(themedSettingsFont(13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectionPillBackground)
                        .foregroundColor(selectionPillForeground)

                    PetWhiteDisclosureChevron(
                        isExpanded: isExpanded,
                        size: 11,
                        color: MangaStyle.isActive ? MangaStyle.strokeInk : (MujiStyle.isActive ? MujiStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (BentoStyle.isActive ? BentoStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.8))))))),
                        lineWidth: 1.7
                    )
                }
            }
            .buttonStyle(.plain)

            SettingsHeaderReveal(isExpanded: isExpanded) {
                LazyVGrid(columns: optionColumns, spacing: 8) {
                    ForEach(FloatingBarStyle.allCases) { style in
                        Button {
                            selection = style
                            isExpanded = false
                        } label: {
                            SettingsFloatingBarOptionCard(
                                style: style,
                                isSelected: selection == style
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var optionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
    }

    @ViewBuilder
    private var selectionPillBackground: some View {
        if MangaStyle.isActive {
            Capsule()
                .fill(MangaStyle.labelYellow.opacity(0.96))
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.4))
        } else if MujiStyle.isActive {
            Capsule()
                .fill(MujiStyle.clay.opacity(0.12))
                .overlay(Capsule().stroke(MujiStyle.hairline.opacity(0.52), lineWidth: 0.6))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true)
        } else if CapsuleStyle.isActive {
            Capsule()
                .fill(CapsuleStyle.accent.opacity(0.12))
                .overlay(Capsule().stroke(CapsuleStyle.accent.opacity(0.24), lineWidth: 0.7))
        } else if SequoiaStyle.isActive {
            Capsule()
                .fill(SequoiaStyle.selectedWash.opacity(0.86))
                .overlay(Capsule().stroke(SequoiaStyle.accent.opacity(0.2), lineWidth: 0.55))
        } else if SignalStyle.isActive {
            SignalSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
        } else if BentoStyle.isActive {
            Capsule()
                .fill(BentoStyle.tomato.opacity(0.14))
                .overlay(Capsule().stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65))
        } else {
            Capsule()
                .fill(Color.monologueIconBackground.opacity(0.16))
        }
    }

    private var selectionPillForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if BentoStyle.isActive { return BentoStyle.tomato }
        return .monologueTextSecondary
    }
}

private struct SettingsFloatingBarOptionCard: View {
    let style: FloatingBarStyle
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                iconBadge
                Spacer()
                selectedMark
            }

            Text(style.displayName)
                .font(cardTitleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundColor(titleColor)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    private var cardRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if MujiStyle.isActive { return 11 }
        if BentoStyle.isActive { return 18 }
        if NeumorphicStyle.isActive { return 18 }
        if CapsuleStyle.isActive { return 20 }
        if SequoiaStyle.isActive { return 16 }
        if SignalStyle.isActive { return 18 }
        return 12
    }

    private var cardTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(13, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .semibold) }
        if BentoStyle.isActive { return BentoStyle.labelFont(13, weight: .heavy) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(13, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.labelFont(13, weight: .bold) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var titleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.ink }
        if BentoStyle.isActive { return isSelected ? BentoStyle.onAccent : BentoStyle.ink }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return isSelected ? CapsuleStyle.onAccent : CapsuleStyle.ink }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.ink : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent : SignalStyle.ink }
        return isSelected ? .monologueIconForeground : .monologueTextPrimary
    }

    private var iconColor: Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.strokeInk : MangaStyle.inkSub }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.clay }
        if BentoStyle.isActive { return isSelected ? BentoStyle.onAccent : BentoStyle.tomato }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return isSelected ? CapsuleStyle.onAccent : CapsuleStyle.accent }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.accent : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent : SignalStyle.accent }
        return isSelected ? .monologueIconForeground : .monologueTextSecondary
    }

    private var selectedMarkColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if SignalStyle.isActive { return SignalStyle.onAccent }
        return .monologueIconForeground
    }

    @ViewBuilder
    private var iconBadge: some View {
        if MangaStyle.isActive {
            MonologueIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.8)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? MangaStyle.bubbleWhite : MangaStyle.paperWarm)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: 1.5)
                )
        } else if MujiStyle.isActive {
            MonologueIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.45)
                .frame(width: 31, height: 31)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? MujiStyle.onTint.opacity(0.16) : MujiStyle.surfaceRaised.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? MujiStyle.onTint.opacity(0.28) : MujiStyle.hairline.opacity(0.44), lineWidth: 0.6)
                )
        } else if NeumorphicStyle.isActive {
            MonologueIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.55)
                .frame(width: 32, height: 32)
                .background(NeumorphicSurfaceBackground(cornerRadius: 11, elevated: false, pressed: isSelected, lightweight: true))
        } else if CapsuleStyle.isActive {
            MonologueIcon(icon: style.iconType, size: 16, color: iconColor, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? CapsuleStyle.onAccent.opacity(0.16) : CapsuleStyle.surfaceTint.opacity(0.74))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? CapsuleStyle.onAccent.opacity(0.28) : CapsuleStyle.separator.opacity(0.42), lineWidth: 0.7)
                        )
                )
        } else if SequoiaStyle.isActive {
            MonologueIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.55)
                .frame(width: 32, height: 32)
                .background(
                    SequoiaSurfaceBackground(
                        cornerRadius: 11,
                        elevated: isSelected,
                        pressed: !isSelected,
                        fill: isSelected ? SequoiaStyle.selectedWash : SequoiaStyle.materialList,
                        role: isSelected ? .selected : .list
                    )
                )
        } else if SignalStyle.isActive {
            MonologueIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.55)
                .frame(width: 32, height: 32)
                .background(SignalSurfaceBackground(cornerRadius: 11, elevated: false, pressed: isSelected, fill: isSelected ? SignalStyle.accent : SignalStyle.control))
        } else if BentoStyle.isActive {
            MonologueIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isSelected ? BentoStyle.tomato.opacity(0.92) : BentoStyle.paperWarm.opacity(0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.65)
                        )
                )
        } else {
            MonologueIcon(icon: style.iconType, size: 18, color: iconColor, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.monologueIconBackground.opacity(0.22) : Color.monologueSeparator.opacity(0.38))
                )
        }
    }

    @ViewBuilder
    private var selectedMark: some View {
        if isSelected {
            MonologueIcon(icon: .checkmark, size: 10, color: selectedMarkColor, lineWidth: 1.8)
                .frame(width: MangaStyle.isActive ? 21 : 20, height: MangaStyle.isActive ? 21 : 20)
                .background(selectedMarkBackground)
        } else {
            Circle()
                .fill(markEmptyFill)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var selectedMarkBackground: some View {
        if MangaStyle.isActive {
            Circle()
                .fill(MangaStyle.bubblePink)
                .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.3))
        } else if MujiStyle.isActive {
            Circle()
                .fill(MujiStyle.tea)
        } else if NeumorphicStyle.isActive {
            Circle()
                .fill(NeumorphicStyle.accent)
        } else if CapsuleStyle.isActive {
            Circle()
                .fill(CapsuleStyle.accent)
        } else if SequoiaStyle.isActive {
            Circle()
                .fill(SequoiaStyle.accent)
        } else if SignalStyle.isActive {
            Circle()
                .fill(SignalStyle.accent)
        } else if BentoStyle.isActive {
            Circle()
                .fill(BentoStyle.tomato)
        } else {
            Circle()
                .fill(Color.monologueIconBackground)
        }
    }

    private var markEmptyFill: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.18) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.45) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.65) }
        if CapsuleStyle.isActive { return CapsuleStyle.separator.opacity(0.72) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.86) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(0.72) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.82) }
        return .monologueSeparator.opacity(0.8)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if MangaStyle.isActive {
            MangaCardBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                tint: isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite
            )
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? MujiStyle.clay : MujiStyle.surface)
                .overlay(
                    MujiPaperTexture(opacity: isSelected ? 0.05 : 0.1)
                        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(isSelected ? MujiStyle.clay.opacity(0.28) : MujiStyle.hairline.opacity(0.5), lineWidth: 0.65)
                )
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                pressed: !isSelected,
                tint: isSelected ? NeumorphicStyle.surfaceRaised : NeumorphicStyle.surface,
                lightweight: true
            )
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                tint: isSelected ? CapsuleStyle.accent : CapsuleStyle.surface.opacity(0.9)
            )
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? SequoiaStyle.selectedWash : SequoiaStyle.materialList,
                role: isSelected ? .selected : .list
            )
        } else if SignalStyle.isActive {
            SignalSurfaceBackground(
                cornerRadius: cardRadius,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? SignalStyle.accent : SignalStyle.control
            )
        } else if BentoStyle.isActive {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? BentoStyle.tomato : BentoStyle.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(BentoStyle.hairline.opacity(isSelected ? 0.25 : 0.58), lineWidth: 0.7)
                )
        } else {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? Color.monologueIconBackground : Color.monologueSeparator.opacity(0.48))
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(Color.monologueIconBackground.opacity(isSelected ? 0.24 : 0), lineWidth: 1)
                )
        }
    }
}

private struct BentoSettingsTile: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        BentoBlock(fill: tint, foreground: BentoStyle.onAccent, radius: 24, padding: 13) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    MonologueIcon(icon: icon, size: 18, color: BentoStyle.onAccent, lineWidth: 1.75)
                        .frame(width: 36, height: 36)
                        .background(BentoStyle.onAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Spacer(minLength: 8)

                    Text(value.uppercased())
                        .font(BentoStyle.labelFont(10, weight: .black))
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(BentoStyle.onAccent.opacity(0.88))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BentoStyle.onAccent.opacity(0.14), in: Capsule())
                }

                Text(title)
                    .font(BentoStyle.titleFont(15, weight: .heavy))
                    .foregroundStyle(BentoStyle.onAccent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 116)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CapsuleSettingsTile: View {
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
                    .font(CapsuleStyle.labelFont(10, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                            .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 0.7))
                    )
            }

            Text(title)
                .font(CapsuleStyle.titleFont(15, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Capsule()
                    .fill(tint.opacity(0.72))
                    .frame(width: 28, height: 6)
                Capsule()
                    .fill(CapsuleStyle.cyan.opacity(0.42))
                    .frame(width: 10, height: 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .padding(14)
        .background(CapsuleSurfaceBackground(cornerRadius: 26, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - 一言类型选择行

struct SettingsHitokotoTypeRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    @Binding var selection: String
    @State private var isExpanded = false

    private static let types: [(key: String, label: String)] = [
        ("", String(localized: "随机")),
        ("i", String(localized: "诗词")),
        ("d", String(localized: "文学")),
        ("k", String(localized: "哲学")),
        ("h", String(localized: "影视")),
        ("j", "ncm"),
        ("a", String(localized: "动画")),
        ("c", String(localized: "游戏")),
        ("e", String(localized: "原创")),
        ("l", String(localized: "抖机灵")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    SettingsIconBadge(icon: icon)

                    Text(title)
                        .font(themedSettingsFont(16, weight: .medium))
                        .foregroundColor(themedSettingsPrimaryColor())

                    Spacer()

                    Text(Self.types.first { $0.key == selection }?.label ?? String(localized: "随机"))
                        .font(themedSettingsFont(14, weight: .medium))
                        .foregroundStyle(activeSummaryColor)

                    PetWhiteDisclosureChevron(
                        isExpanded: isExpanded,
                        size: 11,
                        color: themedSettingsSecondaryColor(),
                        lineWidth: 1.7
                    )
                }
            }
            .buttonStyle(.plain)

            SettingsHeaderReveal(isExpanded: isExpanded) {
                SettingsHitokotoFlowLayout(spacing: 8) {
                    ForEach(Self.types, id: \.key) { type in
                        Button {
                            selection = type.key
                            isExpanded = false
                        } label: {
                            hitokotoTypeChip(label: type.label, selected: selection == type.key)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var activeSummaryColor: Color {
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if BentoStyle.isActive { return BentoStyle.tomato }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        return .secondary
    }

    private func hitokotoTypeChip(label: String, selected: Bool) -> some View {
        Text(label)
            .font(themedSettingsFont(13, weight: selected ? .semibold : .medium))
            .lineLimit(1)
            .padding(.horizontal, chipHorizontalPadding)
            .padding(.vertical, chipVerticalPadding)
            .foregroundColor(chipForeground(selected: selected))
            .background(chipBackground(selected: selected))
            .contentShape(Capsule())
    }

    private var chipHorizontalPadding: CGFloat {
        MangaStyle.isActive ? 13 : (BentoStyle.isActive ? 13 : 12)
    }

    private var chipVerticalPadding: CGFloat {
        NeumorphicStyle.isActive ? 7 : (BentoStyle.isActive ? 7 : 6)
    }

    @ViewBuilder
    private func chipBackground(selected: Bool) -> some View {
        if MangaStyle.isActive {
            Capsule()
                .fill(selected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite)
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: selected ? 1.7 : 1.2))
                .background(
                    Capsule()
                        .fill(MangaStyle.strokeInk)
                        .offset(x: selected ? 1.6 : 0, y: selected ? 1.6 : 0)
                )
        } else if MujiStyle.isActive {
            Capsule()
                .fill(selected ? MujiStyle.clay.opacity(0.15) : MujiStyle.surface.opacity(0.76))
                .overlay(Capsule().stroke(selected ? MujiStyle.clay.opacity(0.42) : MujiStyle.hairline.opacity(0.44), lineWidth: 0.65))
                .overlay(MujiPaperTexture(opacity: selected ? 0.04 : 0.08).clipShape(Capsule()))
        } else if BentoStyle.isActive {
            Capsule()
                .fill(selected ? BentoStyle.tomato : BentoStyle.surface)
                .overlay(Capsule().stroke(BentoStyle.hairline.opacity(selected ? 0.3 : 0.58), lineWidth: 0.65))
        } else if CapsuleStyle.isActive {
            Capsule()
                .fill(selected ? CapsuleStyle.accent : CapsuleStyle.surfaceRaised.opacity(0.78))
                .overlay(Capsule().stroke(selected ? Color.white.opacity(0.34) : CapsuleStyle.separator.opacity(0.46), lineWidth: 0.7))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 15,
                elevated: selected,
                pressed: !selected,
                tint: selected ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface,
                lightweight: true
            )
        } else if SequoiaStyle.isActive {
            Capsule()
                .fill(selected ? SequoiaStyle.selectedWash.opacity(0.88) : SequoiaStyle.materialList.opacity(0.72))
                .overlay(Capsule().stroke(selected ? SequoiaStyle.accent.opacity(0.22) : SequoiaStyle.separator.opacity(0.82), lineWidth: 0.55))
        } else if SignalStyle.isActive {
            SignalSurfaceBackground(
                cornerRadius: 15,
                elevated: selected,
                pressed: !selected,
                fill: selected ? SignalStyle.accent : SignalStyle.control
            )
        } else {
            Capsule()
                .fill(selected ? Color.monologueIconBackground : Color.monologueSeparator.opacity(0.6))
        }
    }

    private func chipForeground(selected: Bool) -> Color {
        if MangaStyle.isActive {
            return selected
                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
                : MangaStyle.inkSub
        }
        if MujiStyle.isActive { return selected ? MujiStyle.clay : MujiStyle.inkSoft }
        if BentoStyle.isActive { return selected ? BentoStyle.onAccent : BentoStyle.inkSoft }
        if CapsuleStyle.isActive { return selected ? CapsuleStyle.onAccent : CapsuleStyle.inkSoft }
        if NeumorphicStyle.isActive { return selected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return selected ? SequoiaStyle.accent : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return selected ? SignalStyle.onAccent : SignalStyle.inkSoft }
        return selected ? Color.monologueIconForeground : Color.monologueTextSecondary
    }
}

private struct LiquidGlassSettingsTile: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                LiquidGlassIconBadge(icon: icon, tint: tint, size: 38)

                Spacer(minLength: 8)

                Text(value)
                    .font(LiquidGlassStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                            .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 0.55))
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(LiquidGlassStyle.titleFont(16, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 5) {
                    Capsule()
                        .fill(tint.opacity(0.58))
                        .frame(width: 28, height: 4)
                    Capsule()
                        .fill(LiquidGlassStyle.luminousEdge.opacity(0.46))
                        .frame(width: 10, height: 4)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.1),
                            Color.clear,
                            LiquidGlassStyle.cyan.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
    }
}

private struct SettingsHitokotoFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
