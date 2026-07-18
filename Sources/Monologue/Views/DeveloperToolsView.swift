import SwiftUI

// MARK: - 开发者模式

@MainActor
struct DeveloperToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var aiProvider = AIProviderConfigurationStore.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "dev_mode_title"),
                        eyebrow: "DEVELOPER",
                        icon: .unlock
                    )

                    VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                        SettingsSection(title: String(localized: "developer_tools_section_testing")) {
                            SettingsRouteLinkRow(
                                icon: .sparkle,
                                title: String(localized: "ai_provider_settings_title"),
                                value: aiProvider.wireProtocol.title,
                                destination: .aiProviderSettings
                            )

                            Divider()
                                .padding(.leading, 58)

                            SettingsRouteLinkRow(
                                icon: .gridSquare,
                                title: String(localized: "dev_popup_catalog_title"),
                                value: "\(DeveloperPopupCatalogView.previewCount)",
                                destination: .developerPopupCatalog
                            )

                            Divider()
                                .padding(.leading, 58)

                            SettingsRouteLinkRow(
                                icon: .logDebug,
                                title: String(localized: "settings_debug_log"),
                                value: "\(AppLogger.getAllLogs().count)",
                                destination: .debugLog
                            )
                        }

                        SettingsSection(title: String(localized: "developer_tools_section_access")) {
                            SettingsInfoRow(
                                icon: .unlock,
                                title: String(localized: "dev_mode_title"),
                                value: String(localized: "dev_mode_enabled_short")
                            )

                            Divider()
                                .padding(.leading, 58)

                            SettingsButtonRow(
                                icon: .lock,
                                title: String(localized: "dev_mode_disable_action"),
                                titleColor: .red,
                                action: confirmDisableDeveloperMode
                            )
                        }

                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .iPadContentWidth(SettingsPageLayout.contentWidth)
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: SettingsPageLayout.scrollCoordinateSpace)
            .themeRenderScrollLayer()
        }
        .asideSettingsDetailChrome(String(localized: "dev_mode_title"))
    }

    private func confirmDisableDeveloperMode() {
        AlertManager.shared.show(
            title: String(localized: "dev_mode_disable"),
            message: "",
            primaryButtonTitle: String(localized: "dev_mode_confirm"),
            secondaryButtonTitle: String(localized: "dev_mode_cancel"),
            primaryAction: {
                UserDefaults.standard.set(false, forKey: "qqDevMode")
                HapticManager.shared.success()
                dismiss()
            }
        )
    }
}

// MARK: - 开发者弹窗预览

@MainActor
struct DeveloperPopupCatalogView: View {
    private enum PreviewGroup: String, CaseIterable, Identifiable {
        case alerts
        case launch
        case feature

        var id: String { rawValue }

        var title: String {
            switch self {
            case .alerts: return String(localized: "dev_popup_group_alerts")
            case .launch: return String(localized: "dev_popup_group_launch")
            case .feature: return String(localized: "dev_popup_group_features")
            }
        }
    }

    private enum PopupPreview: String, CaseIterable, Identifiable {
        case informationAlert
        case confirmationAlert
        case textInputAlert
        case secureInputAlert
        case changelog
        case greetingDaily
        case greetingSolarBirthday
        case greetingLunarBirthday
        case reportWeekly
        case reportMonthly
        case musicQueue
        case podcastQueue
        case soundQuality
        case qishuiQuality
        case equalizer
        case playerTheme
        case backgroundAudio
        case sleepTimer
        case podcastSpeed
        case lyricSource
        case immersiveBackground
        case addToPlaylist
        case downloadQuality

        var id: String { rawValue }

        var group: PreviewGroup {
            switch self {
            case .informationAlert, .confirmationAlert, .textInputAlert, .secureInputAlert:
                return .alerts
            case .changelog, .greetingDaily, .greetingSolarBirthday, .greetingLunarBirthday,
                 .reportWeekly, .reportMonthly:
                return .launch
            default:
                return .feature
            }
        }

        var title: String {
            NSLocalizedString("dev_popup_\(rawValue)", comment: "")
        }

        var icon: MonologueIcon.IconType {
            switch self {
            case .informationAlert: return .infoCircle
            case .confirmationAlert: return .warning
            case .textInputAlert: return .save
            case .secureInputAlert: return .lock
            case .changelog: return .history
            case .greetingDaily, .greetingSolarBirthday, .greetingLunarBirthday: return .emoji
            case .reportWeekly, .reportMonthly: return .chart
            case .musicQueue: return .musicNoteList
            case .podcastQueue: return .podcast
            case .soundQuality, .qishuiQuality, .downloadQuality: return .soundQuality
            case .equalizer: return .equalizer
            case .playerTheme: return .playerTheme
            case .backgroundAudio: return .headphones
            case .sleepTimer: return .clock
            case .podcastSpeed: return .waveform
            case .lyricSource: return .translate
            case .immersiveBackground: return .immersive
            case .addToPlaylist: return .addToQueue
            }
        }

        var sheetPreset: MonologueSheetPreset {
            switch self {
            case .equalizer, .immersiveBackground:
                return .large
            case .playerTheme:
                return .themePicker
            case .podcastSpeed, .lyricSource, .downloadQuality:
                return .compact
            default:
                return .standard
            }
        }

        var isSheet: Bool {
            group == .feature
        }
    }

    @ObservedObject private var settings = SettingsManager.shared
    @State private var presentedSheet: PopupPreview?
    @State private var previewNeteaseQuality: SoundQuality = .lossless
    @State private var previewQQQuality: QQMusicQuality = .flac
    @State private var previewQishuiQuality = "lossless"

    static var previewCount: Int { PopupPreview.allCases.count }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                LazyVStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "dev_popup_catalog_title"),
                        eyebrow: "PREVIEW",
                        icon: .gridSquare
                    )

                    LazyVStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                        ForEach(PreviewGroup.allCases) { group in
                            previewSection(group)
                        }

                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .iPadContentWidth(SettingsPageLayout.contentWidth)
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: SettingsPageLayout.scrollCoordinateSpace)
            .themeRenderScrollLayer()
        }
        .asideSettingsDetailChrome(String(localized: "dev_popup_catalog_title"))
        .monologueSheet(
            item: $presentedSheet,
            preset: presentedSheet?.sheetPreset ?? .standard
        ) { preview in
            sheetContent(for: preview)
        }
    }

    private func previewSection(_ group: PreviewGroup) -> some View {
        let previews = PopupPreview.allCases.filter { $0.group == group }

        return SettingsSection(title: group.title) {
            ForEach(Array(previews.enumerated()), id: \.element.id) { index, preview in
                SettingsNavigationRow(
                    icon: preview.icon,
                    title: preview.title,
                    action: { present(preview) }
                )

                if index < previews.count - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
    }

    private func present(_ preview: PopupPreview) {
        HapticManager.shared.light()

        switch preview {
        case .informationAlert:
            AlertManager.shared.show(
                title: String(localized: "dev_popup_sample_info_title"),
                message: String(localized: "dev_popup_sample_info_message"),
                primaryButtonTitle: String(localized: "common_ok"),
                primaryAction: {}
            )

        case .confirmationAlert:
            AlertManager.shared.show(
                title: String(localized: "dev_popup_sample_confirm_title"),
                message: String(localized: "dev_popup_sample_confirm_message"),
                primaryButtonTitle: String(localized: "confirm"),
                secondaryButtonTitle: String(localized: "alert_cancel"),
                primaryAction: {}
            )

        case .textInputAlert:
            AlertManager.shared.showInput(
                title: String(localized: "dev_popup_sample_input_title"),
                message: "",
                placeholder: String(localized: "dev_popup_sample_input_placeholder"),
                primaryButtonTitle: String(localized: "common_submit"),
                secondaryButtonTitle: String(localized: "alert_cancel"),
                onConfirm: { _ in }
            )

        case .secureInputAlert:
            AlertManager.shared.showInput(
                title: String(localized: "dev_popup_sample_secure_title"),
                message: "",
                placeholder: String(localized: "dev_mode_password"),
                isSecure: true,
                primaryButtonTitle: String(localized: "common_submit"),
                secondaryButtonTitle: String(localized: "alert_cancel"),
                onConfirm: { _ in }
            )

        case .changelog:
            ChangelogManager.shared.presentPreview(previewRelease)

        case .greetingDaily:
            presentGreeting(.daily(
                dayCount: SpecialGreetingManager.dayCount(),
                message: "今天也给自己留一点从容，让喜欢的歌慢慢把心情照亮。"
            ))

        case .greetingSolarBirthday:
            presentGreeting(.birthday(
                dayCount: SpecialGreetingManager.dayCount(),
                isLunar: false,
                message: "愿新一岁的日子有喜欢的旋律，也有被认真收藏的小小快乐。"
            ))

        case .greetingLunarBirthday:
            presentGreeting(.birthday(
                dayCount: SpecialGreetingManager.dayCount(),
                isLunar: true,
                message: "愿新一岁的日子有喜欢的旋律，也有被认真收藏的小小快乐。"
            ))

        case .reportWeekly:
            ListeningReportCenter.shared.presentPreview(kind: .week)

        case .reportMonthly:
            ListeningReportCenter.shared.presentPreview(kind: .month)

        default:
            guard preview.isSheet else { return }
            presentedSheet = preview
        }
    }

    private func presentGreeting(_ greeting: SpecialGreetingManager.Greeting) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            SpecialGreetingManager.shared.pending = greeting
        }
    }

    private var previewRelease: AppChangelogRelease {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return AppChangelogRelease(
            id: "developer-preview-\(build)",
            version: version,
            build: build,
            title: String(localized: "dev_popup_changelog_title"),
            channel: "TestFlight",
            summary: nil,
            releaseNotes: String(localized: "dev_popup_changelog_notes"),
            publishedAt: nil
        )
    }

    private var previewSong: Song {
        var song = PreviewMocks.song
        song.source = .qqmusic
        song.qqMid = nil
        song.qqAlbumMid = nil
        return song
    }

    private func sheetContent(for preview: PopupPreview) -> AnyView {
        switch preview {
        case .musicQueue:
            return AnyView(PlaylistPopupView())

        case .podcastQueue:
            return AnyView(PodcastPlaylistPopupView())

        case .soundQuality:
            return AnyView(
                SoundQualitySheet(
                    currentQuality: previewNeteaseQuality,
                    currentQQQuality: previewQQQuality,
                    isQQMusic: false,
                    onSelectNetease: { quality in
                        previewNeteaseQuality = quality
                        presentedSheet = nil
                    },
                    onSelectQQ: { quality in
                        previewQQQuality = quality
                        presentedSheet = nil
                    }
                )
            )

        case .qishuiQuality:
            return AnyView(
                QishuiQualityPickerSheet(
                    currentQuality: previewQishuiQuality,
                    onSelect: { quality in
                        previewQishuiQuality = quality
                        presentedSheet = nil
                    }
                )
            )

        case .equalizer:
            return AnyView(NavigationStack { EQSettingsView() })

        case .playerTheme:
            return AnyView(PlayerThemePickerSheet())

        case .backgroundAudio:
            return AnyView(BackgroundAudioPolicySheet())

        case .sleepTimer:
            return AnyView(PodcastTimerSheet())

        case .podcastSpeed:
            return AnyView(PodcastSpeedSheet())

        case .lyricSource:
            return AnyView(CurrentSongLyricSourceSheet())

        case .immersiveBackground:
            return AnyView(ImmersiveBackgroundSheet())

        case .addToPlaylist:
            return AnyView(AddToPlaylistSheet(song: previewSong))

        case .downloadQuality:
            return AnyView(
                DownloadQualitySheet(song: previewSong) {
                    presentedSheet = nil
                }
            )

        default:
            return AnyView(EmptyView())
        }
    }
}
