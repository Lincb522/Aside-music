//
//  GameModeSettingsView.swift
//  Monologue
//
//  游戏模式设置页：一键模式 + 子项配置
//

import SwiftUI

struct GameModeSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var gameMode = GameModeManager.shared
    @ObservedObject private var localPlaylists = LocalPlaylistManager.shared

    @State private var showQualityDialog = false
    @State private var showPlaylistDialog = false

    private let gameQualityOptions: [SoundQuality] = [
        .standard, .higher, .exhigh, .lossless
    ]

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(spacing: 20) {
                    mainSection
                    scenariosSection
                    optionsSection
                    presetsSection
                    infoSection
                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.isPad ? 32 : 24)
                .iPadContentWidth(700)
                .padding(.top, 16)
            }
            .onChange(of: settings.gameModeAutoDucking) { _, _ in refreshMatchedPreset() }
            .onChange(of: settings.gameModeLowerQuality) { _, _ in refreshMatchedPreset() }
            .onChange(of: settings.gameModeSilentNowPlaying) { _, _ in refreshMatchedPreset() }
            .onChange(of: settings.gameModeAutoExit) { _, _ in refreshMatchedPreset() }
        }
        .themedNavigationChrome(title: String(localized: "game_mode_settings_title"), eyebrow: "GAME", icon: .gridSquare)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "game_mode_preferred_quality_title"),
            isPresented: $showQualityDialog,
            titleVisibility: .visible
        ) {
            Button(String(localized: "game_mode_preferred_quality_auto"), role: .none) {
                settings.gameModePreferredQuality = nil
            }
            ForEach(gameQualityOptions, id: \.self) { quality in
                Button(quality.displayName) {
                    settings.gameModePreferredQuality = quality
                }
            }
        } message: {
            Text(String(localized: "game_mode_preferred_quality_desc"))
        }
        .confirmationDialog(
            String(localized: "game_mode_preset_playlist_title"),
            isPresented: $showPlaylistDialog,
            titleVisibility: .visible
        ) {
            Button(String(localized: "game_mode_preset_playlist_none"), role: .destructive) {
                settings.gameModeAutoPlaylistLocalId = ""
            }
            ForEach(localPlaylists.playlists, id: \.id) { playlist in
                Button(playlist.name) {
                    settings.gameModeAutoPlaylistLocalId = playlist.id
                }
            }
        } message: {
            Text(String(localized: "game_mode_preset_playlist_desc"))
        }
    }

    // MARK: - 主开关区

    private var mainSection: some View {
        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                gameMode.toggle()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(gameMode.isActive
                                  ? Color(hex: "FF8FA8")
                                  : Color.monologueIconBackground)
                            .frame(width: 44, height: 44)
                        MonologueIcon(
                            icon: .waveform,
                            size: 22,
                            color: gameMode.isActive ? .white : .monologueIconForeground
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "game_mode_main_title"))
                            .font(.rounded(size: 16, weight: .semibold))
                            .foregroundColor(.monologueTextPrimary)
                        Text(gameMode.isActive
                             ? String(localized: "game_mode_main_subtitle_on")
                             : String(localized: "game_mode_main_subtitle_off"))
                            .font(.rounded(size: 12, weight: .medium))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // 大开关视觉
                    ZStack {
                        Capsule()
                            .fill(gameMode.isActive ? Color(hex: "FF8FA8") : Color.monologueIconBackground)
                            .frame(width: 48, height: 28)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .offset(x: gameMode.isActive ? 10 : -10)
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: gameMode.isActive)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monologueCardBackground)
        )
    }

    // MARK: - 场景预设（FPS / RPG / 音游）

    @State private var matchedPreset: GameModeScenarioPreset? = GameModeScenarioApplier.currentMatchedPreset

    private func refreshMatchedPreset() {
        let newValue = GameModeScenarioApplier.currentMatchedPreset
        if newValue != matchedPreset {
            withAnimation(.easeInOut(duration: 0.22)) {
                matchedPreset = newValue
            }
        }
    }

    private var scenariosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "game_mode_preset_section_title"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                Text(String(localized: "game_mode_preset_section_subtitle"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 10) {
                ForEach(GameModeScenarioPreset.allCases) { preset in
                    scenarioCard(preset)
                }
            }
        }
    }

    private func scenarioCard(_ preset: GameModeScenarioPreset) -> some View {
        let isSelected = matchedPreset == preset
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            GameModeScenarioApplier.apply(preset)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                matchedPreset = preset
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                MonologueSymbolIcon(
                    name: preset.systemIconName,
                    size: 19,
                    color: isSelected ? .white : .monologueTextPrimary
                )
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(
                            isSelected
                            ? Color(hex: "FF8FA8")
                            : Color.monologueIconBackground.opacity(0.6)
                        )
                    )
                Text(preset.localizedTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)
                Text(preset.localizedSubtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.monologueCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color(hex: "FF8FA8") : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 子项

    private var optionsSection: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(
                icon: .audioWave,
                title: String(localized: "game_mode_option_ducking_title"),
                subtitle: String(localized: "game_mode_option_ducking_subtitle"),
                isOn: Binding(
                    get: { settings.gameModeAutoDucking },
                    set: { newValue in
                        settings.gameModeAutoDucking = newValue
                        // 若游戏模式已开启，立即重新应用 AVAudioSession options
                        if gameMode.isActive {
                            PlayerManager.shared.handleGameModeDuckingChanged()
                        }
                    }
                )
            )

            Divider()
                .opacity(0.4)
                .padding(.leading, 62)

            SettingsToggleRow(
                icon: .soundQuality,
                title: String(localized: "game_mode_option_quality_title"),
                subtitle: String(localized: "game_mode_option_quality_subtitle"),
                isOn: Binding(
                    get: { settings.gameModeLowerQuality },
                    set: { newValue in
                        settings.gameModeLowerQuality = newValue
                        gameMode.reapplyQualityPreference()
                    }
                )
            )

            Divider()
                .opacity(0.4)
                .padding(.leading, 62)

            SettingsToggleRow(
                icon: .close,
                title: String(localized: "game_mode_option_auto_exit_title"),
                subtitle: String(localized: "game_mode_option_auto_exit_subtitle"),
                isOn: Binding(
                    get: { settings.gameModeAutoExit },
                    set: { newValue in
                        settings.gameModeAutoExit = newValue
                        if gameMode.isActive {
                            gameMode.reapplyAutoExitObserver()
                        }
                    }
                )
            )

            Divider()
                .opacity(0.4)
                .padding(.leading, 62)

            SettingsToggleRow(
                icon: .lock,
                title: String(localized: "game_mode_option_silent_np_title"),
                subtitle: String(localized: "game_mode_option_silent_np_subtitle"),
                isOn: Binding(
                    get: { settings.gameModeSilentNowPlaying },
                    set: { newValue in
                        settings.gameModeSilentNowPlaying = newValue
                        if gameMode.isActive {
                            PlayerManager.shared.updateNowPlayingInfo()
                        }
                    }
                )
            )

            if settings.gameModeSilentNowPlaying {
                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .list,
                    title: String(localized: "game_mode_option_minimal_np_title"),
                    subtitle: String(localized: "game_mode_option_minimal_np_subtitle"),
                    isOn: Binding(
                        get: { settings.gameModeMinimalNowPlaying },
                        set: { newValue in
                            settings.gameModeMinimalNowPlaying = newValue
                            if gameMode.isActive {
                                PlayerManager.shared.updateNowPlayingInfo()
                            }
                        }
                    )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: settings.gameModeSilentNowPlaying)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monologueCardBackground)
        )
    }

    // MARK: - 指定歌单 / 指定音质

    private var presetsSection: some View {
        VStack(spacing: 0) {
            // 指定音质
            Button {
                showQualityDialog = true
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(icon: .soundQuality)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "game_mode_preferred_quality_entry_title"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                        Text(preferredQualitySubtitle)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.45), lineWidth: 1.6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .opacity(0.4)
                .padding(.leading, 62)

            // 指定歌单
            Button {
                showPlaylistDialog = true
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(icon: .list)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "game_mode_preset_playlist_entry_title"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)
                        Text(presetPlaylistSubtitle)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.45), lineWidth: 1.6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monologueCardBackground)
        )
    }

    private var preferredQualitySubtitle: String {
        if let quality = settings.gameModePreferredQuality {
            return quality.displayName
        }
        return String(localized: "game_mode_preferred_quality_auto")
    }

    private var presetPlaylistSubtitle: String {
        let id = settings.gameModeAutoPlaylistLocalId
        if id.isEmpty {
            return String(localized: "game_mode_preset_playlist_none")
        }
        if let match = localPlaylists.playlists.first(where: { $0.id == id }) {
            return match.name
        }
        return String(localized: "game_mode_preset_playlist_invalid")
    }

    // MARK: - 说明

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "game_mode_info_title"))
                .font(.rounded(size: 13, weight: .semibold))
                .foregroundColor(.monologueTextPrimary)
            Text(String(localized: "game_mode_info_body"))
                .font(.rounded(size: 12, weight: .medium))
                .foregroundColor(.monologueTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monologueCardBackground.opacity(0.6))
        )
    }
}
