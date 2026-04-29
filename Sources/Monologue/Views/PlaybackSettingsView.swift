//
//  PlaybackSettingsView.swift
//  Monologue
//
//  播放设置子页面
//

import SwiftUI

struct PlaybackSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var eqManager = EQManager.shared
    @ObservedObject private var gameMode = GameModeManager.shared

    @State private var showPlaybackQualitySheet = false
    @State private var showQQPlaybackQualitySheet = false
    @State private var showQishuiPlaybackQualitySheet = false
    @State private var showBackgroundAudioPolicyDialog = false

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(spacing: 20) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "settings_navigation_playback_title"),
                        eyebrow: "PLAY",
                        icon: .soundQuality
                    )

                    VStack(spacing: 20) {
                        qualitySection
                        queueSection
                        effectsSection
                        storageSyncSection
                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .iPadContentWidth(700)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: settings.gaplessPlaybackEnabled) { _, enabled in
            PlayerManager.shared.handleGaplessPlaybackSettingChanged(enabled: enabled)
        }
        .onChange(of: settings.backgroundAudioPolicyRaw) { _, _ in
            PlayerManager.shared.handleBackgroundAudioPolicySettingChanged()
        }
        .confirmationDialog(
            String(localized: "settings_background_audio_policy"),
            isPresented: $showBackgroundAudioPolicyDialog
        ) {
            ForEach(BackgroundAudioPolicy.allCases) { policy in
                Button(policy.displayName) {
                    settings.backgroundAudioPolicy = policy
                }
            }
        } message: {
            Text(backgroundAudioPolicySubtitle)
        }
        .monologueSheet(isPresented: $showPlaybackQualitySheet, preset: .standard) {
            SoundQualitySheet(
                currentQuality: SoundQuality(rawValue: settings.defaultPlaybackQuality) ?? .standard,
                currentQQQuality: .mp3_320,
                isUnblocked: false,
                isQQMusic: false,
                onSelectNetease: { quality in
                    settings.defaultPlaybackQuality = quality.rawValue
                    showPlaybackQualitySheet = false
                },
                onSelectQQ: { _ in }
            )
        }
        .monologueSheet(isPresented: $showQQPlaybackQualitySheet, preset: .standard) {
            SoundQualitySheet(
                currentQuality: .standard,
                currentQQQuality: QQMusicQuality(rawValue: settings.defaultQQPlaybackQuality) ?? .mp3_320,
                isUnblocked: false,
                isQQMusic: true,
                onSelectNetease: { _ in },
                onSelectQQ: { quality in
                    settings.defaultQQPlaybackQuality = quality.rawValue
                    showQQPlaybackQualitySheet = false
                }
            )
        }
        .monologueSheet(isPresented: $showQishuiPlaybackQualitySheet, preset: .standard) {
            QishuiQualityPickerSheet(
                currentQuality: settings.defaultQishuiPlaybackQuality,
                onSelect: { quality in
                    settings.defaultQishuiPlaybackQuality = quality
                    PlayerManager.shared.qishuiSelectedQuality = quality
                    showQishuiPlaybackQualitySheet = false
                }
            )
        }
    }

    // MARK: - Sections

    private var qualitySection: some View {
        SettingsSection(title: String(localized: "settings_playback_quality_section")) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: .soundQuality,
                    title: String(localized: "settings_prefer_highest_playback_quality"),
                    subtitle: String(localized: "settings_prefer_highest_playback_quality_desc"),
                    isOn: $settings.preferHighestPlaybackQuality
                )

                if !settings.preferHighestPlaybackQuality {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    SettingsNavigationRow(
                        icon: .soundQuality,
                        title: String(localized: "settings_netease_playback_quality"),
                        value: defaultPlaybackQualityText
                    ) {
                        showPlaybackQualitySheet = true
                    }

                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    SettingsNavigationRow(
                        icon: .soundQuality,
                        title: String(localized: "settings_qq_playback_quality"),
                        value: defaultQQPlaybackQualityText
                    ) {
                        showQQPlaybackQualitySheet = true
                    }

                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 62)

                    SettingsNavigationRow(
                        icon: .soundQuality,
                        title: "QSM 默认音质",
                        value: defaultQishuiPlaybackQualityText
                    ) {
                        showQishuiPlaybackQualitySheet = true
                    }
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: settings.preferHighestPlaybackQuality)
        }
    }

    private var queueSection: some View {
        SettingsSection(title: String(localized: "settings_playback_queue_section")) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: .musicNoteList,
                    title: String(localized: "settings_insert_playback_context"),
                    subtitle: playbackContextModeSubtitle,
                    isOn: $settings.insertPlaybackContext
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .podcast,
                    title: String(localized: "播客播放顺序"),
                    subtitle: settings.podcastSortAscending ? String(localized: "最早一期优先") : String(localized: "最新一期优先"),
                    isOn: $settings.podcastSortAscending
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                // 无缝切歌设置项暂时隐藏，默认关闭
                // SettingsToggleRow(
                //     icon: .playNext,
                //     title: String(localized: "settings_gapless_playback"),
                //     subtitle: String(localized: "settings_gapless_playback_desc"),
                //     isOn: $settings.gaplessPlaybackEnabled
                // )

                // Divider()
                //     .opacity(0.4)
                //     .padding(.leading, 62)

                SettingsNavigationRow(
                    icon: .headphones,
                    title: String(localized: "settings_background_audio_policy"),
                    subtitle: backgroundAudioPolicySubtitle
                ) {
                    showBackgroundAudioPolicyDialog = true
                }
            }
        }
    }

    private var effectsSection: some View {
        SettingsSection(title: String(localized: "settings_playback_effects_section")) {
            VStack(spacing: 0) {
                SettingsLinkRow(
                    icon: .waveform,
                    title: String(localized: "game_mode_settings_entry"),
                    subtitle: gameModeSubtitle,
                    destination: GameModeSettingsView()
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .waveform,
                    title: String(localized: "settings_global_equalizer"),
                    subtitle: globalEqualizerSubtitle,
                    isOn: $eqManager.isEnabled
                )
            }
        }
    }

    private var storageSyncSection: some View {
        SettingsSection(title: String(localized: "settings_playback_local_sync_section")) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: .lock,
                    title: String(localized: "settings_qmc_decrypt"),
                    subtitle: String(localized: "settings_qmc_decrypt_desc"),
                    isOn: $settings.qmcDecryptEnabled
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .download,
                    title: String(localized: "settings_cache_play"),
                    subtitle: String(localized: "settings_cache_play_desc"),
                    isOn: $settings.listenAndSave
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .like,
                    title: String(localized: "settings_sync_like_ncm_title"),
                    subtitle: String(localized: "settings_sync_like_ncm_subtitle"),
                    isOn: $settings.syncLikeToNetease
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .musicNoteList,
                    title: String(localized: "settings_like_choose_playlist_title"),
                    subtitle: String(localized: "settings_like_choose_playlist_subtitle"),
                    isOn: $settings.likeToChoosePlaylist
                )
            }
        }
    }

    // MARK: - Helpers

    private var defaultPlaybackQualityText: String {
        (SoundQuality(rawValue: settings.defaultPlaybackQuality) ?? .standard).displayName
    }

    private var defaultQQPlaybackQualityText: String {
        (QQMusicQuality(rawValue: settings.defaultQQPlaybackQuality) ?? .mp3_320).displayName
    }

    private var defaultQishuiPlaybackQualityText: String {
        QishuiQualityPickerSheet.displayName(for: settings.defaultQishuiPlaybackQuality)
    }

    private var playbackContextModeSubtitle: String {
        settings.insertPlaybackContext
            ? String(localized: "settings_insert_playback_context_desc_insert")
            : String(localized: "settings_insert_playback_context_desc_replace")
    }

    private var globalEqualizerSubtitle: String {
        if eqManager.isEnabled {
            let presetName = eqManager.currentPreset?.name ?? NSLocalizedString("eq_custom", comment: "")
            return String(format: String(localized: "settings_global_equalizer_enabled"), presetName)
        }
        return String(localized: "settings_global_equalizer_desc")
    }

    private var gameModeSubtitle: String {
        gameMode.isActive
            ? String(localized: "game_mode_settings_subtitle_on")
            : String(localized: "game_mode_settings_subtitle_off")
    }

    private var backgroundAudioPolicySubtitle: String {
        settings.backgroundAudioPolicy.detailText
    }
}
