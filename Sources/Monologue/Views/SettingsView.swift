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
    if MinimalWhiteStyle.isActive {
        return MinimalWhiteStyle.bodyFont(size, weight: weight)
    }
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
        // 杂志正文用衬线
        return MujiStyle.bodyFont(size, weight: weight == .bold ? .medium : weight)
    }
    return .system(size: size, weight: weight, design: .rounded)
}

private func themedSettingsPrimaryColor() -> Color {
    if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
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
    if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
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

enum SettingsNavigationDestination: Hashable {
    case appearance
    case playback
    case cloudSync
    case storage
    case download
    case about
    case developerTools
    case developerPopupCatalog
    case debugLog
    case aiProviderSettings

    @MainActor
    @ViewBuilder
    var view: some View {
        switch self {
        case .appearance:
            AppearanceSettingsView()
        case .playback:
            PlaybackSettingsView()
        case .cloudSync:
            CloudSyncSettingsView()
        case .storage:
            StorageManageView()
        case .download:
            DownloadManageView()
        case .about:
            AboutView()
        case .developerTools:
            DeveloperToolsView()
        case .developerPopupCatalog:
            DeveloperPopupCatalogView()
        case .debugLog:
            DebugLogView()
        case .aiProviderSettings:
            AIProviderDeveloperSettingsView()
        }
    }
}

private struct SettingsNavigationLink<Label: View>: View {
    let destination: SettingsNavigationDestination
    @ViewBuilder let label: () -> Label

    var body: some View {
        NavigationLink(value: destination) {
            label()
        }
    }
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
        settingsRoot
            .preferredColorScheme(settings.preferredColorScheme)
    }

    // 返回具体类型 AnyView（而非 some View）：规避 Swift 6.3 Release
    // 编译器展开此视图不透明类型链时的 SILGen 无限替换崩溃。
    private var settingsRoot: AnyView {
        AnyView(
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
            // aside / muji：标题落在页面内容里（刊头版式），导航栏只留返回；其余主题维持内联标题
            .themedInlineNavigationTitle(
                (settings.globalThemeId == .default || settings.globalThemeId == .muji) ? "" : String(localized: "settings_title")
            )
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsNavigationDestination.self) { destination in
                AnyView(destination.view)
            }
            .onAppear {
                updateCacheSize()
                apiTokenInput = SecureConfig.apiToken ?? ""
                isHeaderCardExpanded = false
            }
        )
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

    // 每个主题分支都在此处用 AnyView 擦除：十个分支叠成的 _ConditionalContent
    // 巨型类型会让 Swift 6.3 Release 编译器在类型替换时崩溃（SILGen abort）。
    // 用 VStack(spacing:) 包住 ViewBuilder 内容，保持与外层 LazyVStack 相同的间距。
    private var settingsContent: AnyView {
        let spacing = themedSettingsSpacing
        if MangaStyle.isActive {
            return AnyView(VStack(spacing: spacing) { mangaSettingsContent })
        } else if PetWhiteStyle.isActive {
            return AnyView(VStack(spacing: spacing) { petWhiteSettingsContent })
        } else if NeumorphicStyle.isActive {
            return AnyView(VStack(spacing: spacing) { neumorphicSettingsContent })
        } else if SignalStyle.isActive {
            return AnyView(VStack(spacing: spacing) { signalSettingsContent })
        } else if BentoStyle.isActive {
            return AnyView(VStack(spacing: spacing) { bentoSettingsContent })
        } else if CapsuleStyle.isActive {
            return AnyView(VStack(spacing: spacing) { capsuleSettingsContent })
        } else if SequoiaStyle.isActive {
            return AnyView(VStack(spacing: spacing) { sequoiaSettingsContent })
        } else if LiquidGlassStyle.isActive {
            return AnyView(VStack(spacing: spacing) { liquidGlassSettingsContent })
        } else if MujiStyle.isActive {
            return AnyView(VStack(spacing: spacing) { mujiSettingsContent })
        } else {
            return AnyView(VStack(spacing: spacing) { defaultSettingsContent })
        }
    }

    @ViewBuilder
    private var defaultSettingsContent: some View {
        asideSettingsMasthead
        settingsHeaderCard
        asidePersonalizationSection
        asidePlaybackSection
        asideDataSection
        if qqDevMode {
            otherSection
        }
    }

    // MARK: - aside 设置主页分组（编辑部信息架构）

    /// 刊头：眉题行 + 大号标题，与「我的」「音乐库」同一套编辑部版式，随滚动收缩
    private var asideSettingsMasthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monologueAccent)
                    .frame(width: 18, height: 3)

                Text("SETTINGS")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundColor(.monologueTextSecondary.opacity(0.72))
                    .fixedSize()

                Rectangle()
                    .fill(Color.monologueSeparator.opacity(0.5))
                    .frame(height: 0.5)
            }
            .padding(.bottom, 14)

            Text(String(localized: "settings_title"))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .monologuePageHeaderCollapse()
    }

    /// 分组内行间发丝分隔线
    private var asideRowDivider: some View {
        Rectangle()
            .fill(Color.monologueSeparator.opacity(0.55))
            .frame(height: 0.5)
            .padding(.leading, 58)
    }

    private var asidePersonalizationSection: some View {
        SettingsSection(title: settingsText("settings_section_personalization")) {
            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode
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

    private var asidePlaybackSection: some View {
        SettingsSection(title: settingsText("settings_section_playback")) {
            SettingsRouteLinkRow(
                icon: .soundQuality,
                title: settingsText("settings_navigation_playback_title"),
                subtitle: settingsText("settings_navigation_playback_subtitle"),
                destination: .playback
            )
        }
    }

    private var asideDataSection: some View {
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
    private var mangaSettingsContent: some View {
        mangaSettingsMasthead

        settingsHeaderCard

        mangaSettingsModePanel
        mangaSettingsPortalGrid

        if qqDevMode {
            otherSection
        }
    }

    /// 周刊印刷刊头:话数眉题 + 错版标题
    private var mangaSettingsMasthead: some View {
        VStack(alignment: .leading, spacing: 7) {
            MangaLabel(text: "SETUP DESK", tint: MangaStyle.labelYellow, small: true)

            MangaMisprintTitle(text: String(localized: "profile_settings"), size: 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .monologuePageHeaderCollapse()
    }

    @ViewBuilder
    private var petWhiteSettingsContent: some View {
        petWhiteSettingsModeBoard
        petWhiteSettingsPortalGrid
        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var neumorphicSettingsContent: some View {
        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var signalSettingsContent: some View {
        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var bentoSettingsContent: some View {
        settingsHeaderCard
        bentoSettingsModeBlock
        bentoSettingsGrid

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var capsuleSettingsContent: some View {
        capsuleModeDeck
        capsuleSettingsMatrix

        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var sequoiaSettingsContent: some View {
        settingsHeaderCard
        themeSection
        navigationCardsSection

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var liquidGlassSettingsContent: some View {
        liquidGlassModeDeck

        liquidGlassSettingsMatrix

        settingsHeaderCard

        if qqDevMode {
            otherSection
        }
    }

    @ViewBuilder
    private var mujiSettingsContent: some View {
        mujiSettingsMasthead
        settingsHeaderCard
        mujiSettingsNotebook

        if qqDevMode {
            otherSection
        }
    }

    /// Muji 设置刊头：圆点眉题 + 衬线大标题，替代导航栏内联标题
    private var mujiSettingsMasthead: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 8) {
                MujiDotMark()

                Text("SETTINGS INDEX")
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(2.2)
                    .fixedSize()
            }

            Text(String(localized: "settings_title"))
                .font(MujiStyle.titleFont(30, weight: .medium))
                .foregroundStyle(MujiStyle.ink)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .monologuePageHeaderCollapse()
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

                // 下载管理入口（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
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

            // 下载管理入口（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
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

            // 下载管理入口（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
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

            // 下载管理入口（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
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

    private var mangaSettingsModePanel: some View {
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

    private var mangaSettingsPortalGrid: some View {
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

                // 下载管理入口（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
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

    private var mujiSettingsNotebook: some View {
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

                // 下载管理入口（下载功能暂时隐藏，恢复时打开 AppConfig.Features.downloadEnabled）
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

    // MARK: - 存储管理

    private var cacheSection: some View {
        SettingsSection(title: String(localized: "settings_storage")) {
            SettingsRouteLinkRow(
                icon: .storage,
                title: String(localized: "settings_storage_manage"),
                subtitle: String(localized: "settings_storage_manage_desc"),
                value: cacheSize,
                destination: .storage
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

    private var headerPillShape: AnyShape {
        MangaStyle.isActive
            ? AnyShape(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous))
            : AnyShape(Capsule())
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

    /// aside（经典）主题使用重新设计的开发者名片，其余主题沿用原卡片。
    /// 与其他页面头部一致：滚出顶部时应用统一的收缩渐隐效果。
    private var settingsHeaderCard: some View {
        Group {
            if settings.globalThemeId == .default {
                asideDeveloperCard
            } else {
                legacySettingsHeaderCard
            }
        }
        .monologuePageHeaderCollapse()
    }

    // MARK: - Aside 开发者名片

    private var asideDeveloperCard: some View {
        VStack(spacing: 0) {
            // 身份区：头像 + 名字/徽章 + 关于入口
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image("WeChatAvatar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.monologueAccent.opacity(0.62),
                                            Color.monologueAccent.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.4
                                )
                        )
                        .shadow(color: Color.monologueAccent.opacity(0.16), radius: 10, x: 0, y: 5)

                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                        .overlay(
                            Circle().stroke(Color(light: .white, dark: .black).opacity(0.92), lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("ZIJIU522")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text("DEV")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(.monologueAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(
                                Capsule()
                                    .fill(Color.monologueAccent.opacity(0.13))
                                    .overlay(
                                        Capsule().stroke(Color.monologueAccent.opacity(0.3), lineWidth: 0.7)
                                    )
                            )
                    }

                    HStack(spacing: 5) {
                        MonologueIcon(icon: .comment, size: 11.5, color: .monologueTextSecondary.opacity(0.85))
                        Text(settingsText("settings_developer_status"))
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                SettingsNavigationLink(destination: .about) {
                    HStack(spacing: 4) {
                        Text(String(localized: "settings_about"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 9, color: .monologueTextSecondary, lineWidth: 1.9)
                    }
                    .foregroundColor(.monologueTextSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.monologueSeparator.opacity(0.36)))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // 授权状态条：点击展开 Token 与联系开发者
            Button {
                apiTokenInput = SecureConfig.apiToken ?? apiTokenInput
                isHeaderCardExpanded.toggle()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tokenStatusColor.opacity(0.13))
                            .frame(width: 30, height: 30)
                        MonologueIcon(icon: hasToken ? .lock : .unlock, size: 13, color: tokenStatusColor)
                    }

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(tokenStatusText)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)

                        Text(asideTokenSubtitle)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(
                                OnlineAccessManager.shared.lastTokenStatus == .expired && hasToken
                                    ? .red.opacity(0.8)
                                    : .monologueTextSecondary.opacity(0.85)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    PetWhiteDisclosureChevron(
                        isExpanded: isHeaderCardExpanded,
                        size: 10,
                        petWhiteSize: 14,
                        color: .monologueTextSecondary.opacity(0.7),
                        lineWidth: 1.8
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.monologueSeparator.opacity(0.28))
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            .padding(.horizontal, 14)

            SettingsHeaderReveal(isExpanded: isHeaderCardExpanded) {
                asideDeveloperExpandedContent
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }

            // 底部寄语
            HStack(spacing: 6) {
                MonologueIcon(icon: headerFooterIcon, size: 11, color: headerFooterIconColor)

                Text(headerFooterText)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(headerFooterTextColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 15)
        }
        .background(asideDeveloperCardBackground)
        .animation(
            .interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04),
            value: isHeaderCardExpanded
        )
    }

    private var asideTokenSubtitle: String {
        if hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return String(localized: "当前已过期：") + maskedToken
            }
            return maskedToken
        }
        return settingsText("settings_token_hint")
    }

    private var asideDeveloperExpandedContent: some View {
        VStack(spacing: 10) {
            // 联系开发者
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
                        MonologueIcon(
                            icon: wechatCopied ? .checkmark : .save,
                            size: 13,
                            color: wechatCopied ? .green : .monologueTextPrimary
                        )
                        Text(wechatCopied ? settingsText("settings_contact_copied") : "Fallin-Out0122")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(wechatCopied ? .green : .monologueTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(wechatCopied ? Color.green.opacity(0.12) : Color.monologueSeparator.opacity(0.32))
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
                        MonologueIcon(icon: .send, size: 13, color: Color(light: .white, dark: .black))
                        Text(settingsText("settings_open_wechat"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(light: .white, dark: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.monologueAccent)
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
            }

            // Token 输入
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.monologueSeparator.opacity(0.32))
                )

                Button {
                    submitAPIToken()
                } label: {
                    Text(settingsText("common_save"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(light: .white, dark: .black))
                        .frame(width: 48, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.monologueAccent)
                        )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
            }
        }
    }

    private var asideDeveloperCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.monologueGlassTint.opacity(0.55))
            .monologueGlass(cornerRadius: 24)
            .overlay(alignment: .topTrailing) {
                // 右上角强调色光晕，随封面主题色
                Circle()
                    .fill(Color.monologueAccent.opacity(0.14))
                    .frame(width: 170, height: 170)
                    .blur(radius: 52)
                    .offset(x: 55, y: -70)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    // MARK: - 其他主题的开发者卡片（原设计）

    private var legacySettingsHeaderCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("WeChatAvatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: headerAvatarRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: headerAvatarRadius, style: .continuous)
                            .stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1 : 0.7)
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
                    SettingsNavigationLink(destination: .about) {
                        Text(String(localized: "settings_about"))
                            .font(themedSettingsFont(11, weight: .semibold))
                            .foregroundColor(headerSecondaryTextColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                headerPillShape
                                    .fill(headerSoftFill)
                                    .overlay(headerPillShape.stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6))
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
                            headerPillShape
                                .fill(headerStatusButtonBackground)
                                .overlay(headerPillShape.stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6))
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
                                submitAPIToken()
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
        SettingsSection(title: String(localized: "developer_tools_title")) {
            SettingsRouteLinkRow(
                icon: .unlock,
                title: String(localized: "dev_mode_title"),
                value: String(localized: "dev_mode_enabled_short"),
                destination: .developerTools
            )
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

    /// 提交并校验 API Token（aside 名片与其他主题卡片共用）
    private func submitAPIToken() {
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
    }

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
        // 目录条目：色章图标 + 黑体标题 + 页码式小徽标，直接排在纸上
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tint)
                MonologueIcon(icon: icon, size: 15, color: iconForeground, lineWidth: 1.8)
            }
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(-3))

            Text(title)
                .font(MangaStyle.titleFont(15, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(badge)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(MangaStyle.inkMuted)
                .lineLimit(1)

            MonologueIcon(icon: .chevronRight, size: 12, color: MangaStyle.inkMuted, lineWidth: 1.8)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    private var iconForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: tint,
            light: MangaStyle.strokeInk,
            dark: MangaStyle.onStrokeInk
        )
    }
}

/// Muji 主题模式行：裸排行内三段文字选择（系统 / 浅色 / 深色），无展开无容器
private struct MujiThemeModeRow: View {
    @Binding var selection: String

    private let options: [(value: String, title: String)] = [
        ("system", String(localized: "settings_theme_auto")),
        ("light", String(localized: "settings_theme_light")),
        ("dark", String(localized: "settings_theme_dark")),
    ]

    var body: some View {
        HStack(spacing: 13) {
            MonologueIcon(icon: .sparkle, size: 15, color: MujiStyle.clay, lineWidth: 1.4)
                .frame(width: 22, alignment: .leading)

            Text(String(localized: "settings_theme_mode"))
                .font(MujiStyle.bodyFont(15, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                ForEach(options, id: \.value) { option in
                    Button {
                        guard selection != option.value else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = option.value
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(option.title)
                                .font(MujiStyle.labelFont(11.5, weight: selection == option.value ? .semibold : .regular))
                                .foregroundStyle(selection == option.value ? MujiStyle.clay : MujiStyle.inkMuted)
                                .lineLimit(1)

                            Rectangle()
                                .fill(selection == option.value ? MujiStyle.clay.opacity(0.85) : Color.clear)
                                .frame(height: 1.2)
                        }
                        .fixedSize()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 13.5)
    }
}

private struct MujiSettingsLedgerLink: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String
    let destination: SettingsNavigationDestination

    var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: 13) {
                MonologueIcon(icon: icon, size: 15, color: ledgerTint, lineWidth: 1.4)
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

                MonologueIcon(icon: .chevronRight, size: 10, color: MujiStyle.inkMuted, lineWidth: 1.4)
            }
            .padding(.vertical, 13.5)
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
        MujiListDivider()
            .padding(.leading, 35)
    }
}

// MARK: - Settings Icon Badge

struct SettingsIconBadge: View {
    let icon: MonologueIcon.IconType
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        if MinimalWhiteStyle.isActive {
            MonologueIcon(
                icon: icon,
                size: 14,
                color: MinimalWhiteStyle.inkSoft,
                lineWidth: 1.55
            )
            .frame(width: 32, height: 32)
            .background(
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.compactRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.controlGlassFill
                )
            )
        } else if MangaStyle.isActive {
            // 周刊印刷：单色墨线图标，不再上彩色底章
            MonologueIcon(
                icon: icon,
                size: 15,
                color: MangaStyle.ink,
                lineWidth: 1.8
            )
            .frame(width: 32, height: 32)
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
            Circle()
                .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.25))
                .frame(width: 31, height: 31)
                .overlay(
                    MonologueIcon(
                        icon: icon,
                        size: 14,
                        color: ThemeColorCustomization.visibleTintColor(MujiStyle.clay, darkFallback: MujiStyle.ink),
                        lineWidth: 1.5
                    )
                )
        } else if GlobalThemeId.persistedOrDefault == .default {
            // aside 编辑部风格：单色细线图标 + 发丝描边圆片，去掉彩色底
            ZStack {
                Circle()
                    .fill(Color.monologueGlassTint.opacity(0.5))
                Circle()
                    .stroke(Color.monologueSeparator.opacity(0.75), lineWidth: 0.6)
                MonologueIcon(
                    icon: icon,
                    size: 13.5,
                    color: .monologueTextSecondary,
                    lineWidth: 1.6
                )
            }
            .frame(width: 30, height: 30)
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

    /// aside 默认主题（编辑部风格分支）
    private var isAsideTheme: Bool {
        GlobalThemeId.persistedOrDefault == .default
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                if isAsideTheme {
                    // 编辑部 kicker：强调色小竖标
                    Capsule()
                        .fill(Color.monologueAccent)
                        .frame(width: 2.5, height: 9)
                } else if MujiStyle.isActive {
                    // Muji：双色圆点眉标
                    MujiDotMark()
                }

                Text(MinimalWhiteStyle.isActive ? title : title.uppercased())
                    .font(sectionTitleFont)
                    .foregroundColor(sectionTitleColor)
                    .tracking(MinimalWhiteStyle.isActive ? 0 : (MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive || BentoStyle.isActive ? 1.0 : (isAsideTheme ? 1.1 : 0.4)))
            }
            .padding(.leading, isAsideTheme ? 6 : 16)

            VStack(spacing: 0) {
                content
            }
            .background {
                if MangaStyle.isActive {
                    // 去卡片化：设置分组用上下规则线围合，内容直接排在纸上
                    VStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(MangaStyle.ink.opacity(0.72))
                                .frame(height: 1.6)
                            Rectangle()
                                .fill(MangaStyle.ink.opacity(0.26))
                                .frame(height: 0.8)
                        }
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(MangaStyle.strokeInk.opacity(0.22))
                            .frame(height: 1)
                    }
                } else if MujiStyle.isActive {
                    // Muji：清新水洗底，柔圆角不描边
                    RoundedRectangle(cornerRadius: MujiStyle.cardRadius, style: .continuous)
                        .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
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
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(12, weight: .semibold) }
        if MangaStyle.isActive { return MangaStyle.labelFont(12, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .semibold) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(11, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.labelFont(11, weight: .bold) }
        if BentoStyle.isActive { return BentoStyle.labelFont(11, weight: .heavy) }
        if isAsideTheme { return .system(size: 11, weight: .heavy, design: .rounded) }
        return .system(size: 12, weight: .bold, design: .rounded)
    }

    private var sectionTitleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkMuted }
        if isAsideTheme { return Color.monologueTextSecondary.opacity(0.8) }
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
        if MinimalWhiteStyle.isActive {
            background(
                MinimalWhiteSurfaceBackground(
                    cornerRadius: min(max(cornerRadius, MinimalWhiteStyle.compactRadius), MinimalWhiteStyle.chromeRadius),
                    elevated: true,
                    tint: MinimalWhiteStyle.glassFill
                )
            )
        } else if MangaStyle.isActive {
            // 设置页唯一焦点分格：开发者卡保留厚墨框错版投影
            background(MangaCardBackground(cornerRadius: cornerRadius, elevated: true, tint: tint, poster: true))
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
            // Muji：清新水洗底，柔圆角不描边
            background(
                RoundedRectangle(cornerRadius: MujiStyle.cardRadius, style: .continuous)
                    .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.7))
            )
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
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceTint.opacity(0.8) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed }
        if SignalStyle.isActive { return SignalStyle.controlPressed }
        if BentoStyle.isActive { return BentoStyle.paperWarm }
        return Color(light: Color.black.opacity(0.12), dark: Color.white.opacity(0.2))
    }

    private var offStrokeColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.hairline }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.45) }
        if CapsuleStyle.isActive { return CapsuleStyle.separator.opacity(0.48) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.72) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(0.52) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.62) }
        return Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.14))
    }

    private func knobColor(isOn: Bool) -> Color {
        if MinimalWhiteStyle.isActive {
            return isOn ? MinimalWhiteStyle.onAccent : MinimalWhiteStyle.paper
        }
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
            if MinimalWhiteStyle.isActive {
                return MinimalWhiteStyle.ink.opacity(0.08)
            }
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
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : (CapsuleStyle.isActive ? CapsuleStyle.accent : (BentoStyle.isActive ? BentoStyle.tomato : (SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monologueToggleTint)))
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

struct SettingsRouteLinkRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    let destination: SettingsNavigationDestination
    /// 相对默认行略增高入口卡片（设置主页「外观/播放」等）
    var verticalPadding: CGFloat = 13

    var body: some View {
        NavigationLink(value: destination) {
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
            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                .fill(MangaStyle.labelYellow.opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.4))
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
        if MangaStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
        }
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
        if MangaStyle.isActive {
            return isSelected
                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk)
                : MangaStyle.ink
        }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.ink }
        if BentoStyle.isActive { return isSelected ? BentoStyle.onAccent : BentoStyle.ink }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return isSelected ? CapsuleStyle.onAccent : CapsuleStyle.ink }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.ink : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent : SignalStyle.ink }
        return isSelected ? .monologueIconForeground : .monologueTextPrimary
    }

    private var iconColor: Color {
        if MangaStyle.isActive {
            return isSelected
                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk)
                : MangaStyle.inkSub
        }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.clay }
        if BentoStyle.isActive { return isSelected ? BentoStyle.onAccent : BentoStyle.tomato }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return isSelected ? CapsuleStyle.onAccent : CapsuleStyle.accent }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.accent : SequoiaStyle.inkSoft }
        if SignalStyle.isActive { return isSelected ? SignalStyle.onAccent : SignalStyle.accent }
        return isSelected ? .monologueIconForeground : .monologueTextSecondary
    }

    private var selectedMarkColor: Color {
        if MangaStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk)
        }
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
            // 去卡片化：图标直接排在选项面上，不再包底板
            MonologueIcon(icon: style.iconType, size: 17, color: iconColor, lineWidth: 1.8)
                .frame(width: 32, height: 32)
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
            // 去卡片化：选中平涂色块，未选中仅细墨线
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(isSelected ? MangaStyle.labelYellow : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(isSelected ? 0 : 0.32), lineWidth: 1)
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
            .contentShape(MangaStyle.isActive ? AnyShape(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)) : AnyShape(Capsule()))
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
            // 去卡片化筛选签：选中实色小章，未选中细墨线轮廓
            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                .fill(selected ? MangaStyle.labelYellow : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk.opacity(selected ? 0 : 0.35), lineWidth: 1)
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
