import SwiftUI

struct PlayerQualitySelectionAvailabilityModifier: ViewModifier {
    @ObservedObject private var player = PlayerManager.shared

    func body(content: Content) -> some View {
        content
            .disabled(!player.isCurrentPlaybackQualitySelectable)
            .opacity(player.isCurrentPlaybackQualitySelectable ? 1 : 0.42)
    }
}

extension View {
    func playerQualitySelectionAvailability() -> some View {
        modifier(PlayerQualitySelectionAvailabilityModifier())
    }
}

/// 播放器右上角三点菜单 — 全屏遮罩 + 右上角弹出菜单
struct PlayerMoreMenu: View {
    @Binding var isPresented: Bool
    var anchorFrame: CGRect? = nil
    var isDarkBackground: Bool = false
    /// 是否显示"沉浸模式"入口（沉浸模式内部的菜单不显示）
    var showImmersiveEntry: Bool = true
    var onQuality: (() -> Void)? = nil
    var onEQ: () -> Void
    var onTheme: (() -> Void)? = nil
    
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var gameMode = GameModeManager.shared
    @ObservedObject private var eqManager = EQManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var lyricViewModel = LyricViewModel.shared
    @AppStorage("enableKaraoke") private var enableKaraoke = false
    @AppStorage("showTranslation") private var showTranslation = true
    @State private var showTimerSheet = false
    @State private var showLyricSourceSheet = false
    @State private var showImmersiveSettings = false
    @State private var showPlayerTypography = false
    /// 子级页面关闭时，Sheet 的绑定会先复位；单独保留转场状态，避免菜单短暂重绘。
    @State private var isPresentingChild = false

    private let textColor: Color = .monologueTextPrimary

    private var currentLyricSource: LyricSource? {
        guard let song = player.currentSong else { return nil }
        return lyricViewModel.selectedSource(for: song)
    }
    
    private var timerStatusText: String? {
        if player.pendingSleepStopAfterCurrentTrack {
            return String(localized: "podcast_timer_pending_short")
        }
        guard let remaining = player.sleepTimerRemaining else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var equalizerStatusText: String {
        guard eqManager.isEnabled else { return String(localized: "settings_off") }
        let name = eqManager.currentPreset?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "eq_custom") : name
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { proxy in
            let panelWidth = min(292, max(240, proxy.size.width - 24))

            ZStack(alignment: .topTrailing) {
                Color.black.opacity(isDarkBackground ? 0.07 : 0.035)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeMenu()
                    }

                if !isPresentingChild {
                    menuPanel
                        .frame(width: panelWidth)
                        .padding(.top, resolvedTopPadding)
                        .padding(.trailing, resolvedTrailingPadding(containerWidth: proxy.size.width))
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
                }
            }
        }
        .monologueSheet(isPresented: $showTimerSheet, onDismiss: {
            closeMenu()
        }, preset: .standard){
            PodcastTimerSheet()

        }
        .monologueSheet(isPresented: $showLyricSourceSheet, onDismiss: {
            closeMenu()
        }, preset: .compact) {
            CurrentSongLyricSourceSheet()
        }
        .fullScreenCover(isPresented: $showImmersiveSettings, onDismiss: {
            closeMenu()
        }) {
            // 从普通播放器进入：全程竖屏，不做横竖屏切换
            NavigationStack {
                AriaSettingsPage(palette: .fallback, managesOrientation: false)
            }
        }
        .fullScreenCover(isPresented: $showPlayerTypography, onDismiss: {
            closeMenu()
        }) {
            NavigationStack {
                PlayerTypographySettingsView()
            }
        }
    }

    private var menuPanel: some View {
        MonologueMoreMenuPanel(
            title: String(localized: "player_more_title"),
            isDarkBackground: isDarkBackground,
            closeAction: closeMenu
        ) {
            VStack(alignment: .leading, spacing: 16) {
                menuSection(title: String(localized: "player_more_playback_section")) {
                    playbackQuickActions
                }

                menuSection(title: String(localized: "player_more_lyrics_section")) {
                    lyricActions
                }

                menuSection(title: String(localized: "player_more_player_section")) {
                    playerActions
                }
            }
        }
    }

    private var playbackQuickActions: some View {
        HStack(spacing: 8) {
            if let onQuality {
                quickAction(
                    icon: .soundQuality,
                    title: String(localized: "quality_title"),
                    status: player.qualityButtonText,
                    isEnabled: player.currentSong != nil && player.isCurrentPlaybackQualitySelectable
                ) {
                    closeMenu()
                    onQuality()
                }
            }

            quickAction(
                icon: .clock,
                title: String(localized: "podcast_timer_title"),
                status: timerStatusText
            ) {
                isPresentingChild = true
                showTimerSheet = true
            }

            quickAction(
                icon: .audioWave,
                title: String(localized: "settings_equalizer"),
                status: equalizerStatusText
            ) {
                closeMenu()
                onEQ()
            }
        }
    }

    private var lyricActions: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: .musicNoteList,
                title: String(localized: "lyric_source_change"),
                trailingText: currentLyricSource?.shortName,
                trailingColor: currentLyricSource?.musicSource.themedBadgeColor ?? .monologueTextSecondary,
                isEnabled: player.currentSong != nil
            ) {
                isPresentingChild = true
                showLyricSourceSheet = true
            }

            menuDivider

            menuRow(
                icon: .translate,
                title: String(localized: "player_more_lyrics_appearance")
            ) {
                isPresentingChild = true
                showPlayerTypography = true
            }

            menuDivider

            menuToggleRow(
                icon: .karaoke,
                title: String(localized: "逐字歌词"),
                isOn: $enableKaraoke
            )

            menuDivider

            menuToggleRow(
                icon: .translate,
                title: String(localized: "显示翻译"),
                isOn: $showTranslation
            )
        }
        .background(groupBackground)
    }

    private var playerActions: some View {
        VStack(spacing: 0) {
            if let onTheme {
                menuRow(
                    icon: .playerTheme,
                    title: String(localized: "theme_title")
                ) {
                    closeMenu()
                    onTheme()
                }

                menuDivider
            }

            if showImmersiveEntry {
                immersiveActionRow
                menuDivider
            }

            gameModeToggle
        }
        .background(groupBackground)
    }

    private var immersiveActionRow: some View {
        HStack(spacing: 0) {
            Button {
                closeMenu()
                CinemaModeController.shared.present()
            } label: {
                HStack(spacing: 11) {
                    rowIcon(.immersive)

                    Text(String(localized: "player_more_enter_immersive"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 8)

                    MonologueIcon(icon: .chevronRight, size: 11, color: .monologueTextSecondary)
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .frame(minHeight: 46)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(width: 0.5, height: 24)

            Button {
                isPresentingChild = true
                showImmersiveSettings = true
            } label: {
                MonologueIcon(icon: .settings, size: 16, color: .monologueTextSecondary)
                    .frame(width: 46, height: 46)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "player_more_immersive_settings"))
        }
    }

    private var gameModeToggle: some View {
        Toggle(isOn: Binding(
            get: { gameMode.isActive },
            set: { newValue in
                guard newValue != gameMode.isActive else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                gameMode.toggle()
            }
        )) {
            HStack(spacing: 11) {
                rowIcon(.waveform, isActive: gameMode.isActive)

                Text(String(localized: "player_more_game_mode"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
            }
        }
        .tint(.monologueAccent)
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
    }

    private func menuSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .padding(.horizontal, 4)

            content()
        }
    }

    private func quickAction(
        icon: MonologueIcon.IconType,
        title: String,
        status: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MonologueIcon(
                    icon: icon,
                    size: 18,
                    color: textColor.opacity(isEnabled ? 0.9 : 0.34)
                )

                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor.opacity(isEnabled ? 0.9 : 0.34))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .center)

                if let status, !status.isEmpty {
                    Text(status)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary.opacity(isEnabled ? 1 : 0.38))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 82, alignment: .center)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(textColor.opacity(isEnabled ? 0.055 : 0.025))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityValue(status ?? "")
    }

    private func menuRow(
        icon: MonologueIcon.IconType,
        title: String,
        trailingText: String? = nil,
        trailingColor: Color = .monologueTextSecondary,
        isEnabled: Bool = true,
        dimsWhenDisabled: Bool = true,
        showsProgress: Bool = false,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        let contentOpacity = isEnabled || !dimsWhenDisabled ? 1.0 : 0.36

        return Button(action: action) {
            HStack(spacing: 11) {
                rowIcon(icon)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor.opacity(contentOpacity))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(trailingColor.opacity(contentOpacity))
                        .lineLimit(1)
                }

                if showsProgress {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.monologueAccent)
                        .frame(width: 11, height: 11)
                } else if showsChevron {
                    MonologueIcon(
                        icon: .chevronRight,
                        size: 11,
                        color: .monologueTextSecondary.opacity(isEnabled ? 0.8 : 0.28)
                    )
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func menuToggleRow(
        icon: MonologueIcon.IconType,
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn.animation(.spring(response: 0.3, dampingFraction: 0.86))) {
            HStack(spacing: 11) {
                rowIcon(icon, isActive: isOn.wrappedValue)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
            }
        }
        .tint(.monologueAccent)
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
    }

    private func rowIcon(_ icon: MonologueIcon.IconType, isActive: Bool = false) -> some View {
        MonologueIcon(
            icon: icon,
            size: 16,
            color: isActive ? .monologueAccent : textColor.opacity(0.82)
        )
        .frame(width: 30, height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isActive ? Color.monologueAccent.opacity(0.12) : textColor.opacity(0.045))
        )
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.monologueSeparator)
            .frame(height: 0.5)
            .padding(.leading, 53)
    }

    private var groupBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(textColor.opacity(0.04))
    }

    private var resolvedTopPadding: CGFloat {
        if let anchorFrame {
            return max(12, anchorFrame.maxY + 8)
        }
        return DeviceLayout.headerTopPadding + 52
    }

    private func resolvedTrailingPadding(containerWidth: CGFloat) -> CGFloat {
        guard let anchorFrame else { return 16 }
        return max(12, containerWidth - anchorFrame.maxX)
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.18)) {
            isPresented = false
        }
    }
}

struct CurrentSongLyricSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var lyricViewModel = LyricViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 18) {
            header

            if let song = player.currentSong {
                VStack(spacing: 0) {
                    ForEach(LyricSource.allCases) { source in
                        sourceRow(source, song: song)

                        if source != LyricSource.allCases.last {
                            Rectangle()
                                .fill(Color.monologueSeparator)
                                .frame(height: 0.5)
                                .padding(.leading, 18)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.monologueTextPrimary.opacity(0.055))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.monologueSeparator, lineWidth: 0.5)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 10)
        .iPadContentWidth(500)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "lyric_source_change"))
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                if let song = player.currentSong {
                    Text(song.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                close()
            } label: {
                MonologueIcon(icon: .close, size: 14, color: .monologueTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.monologueTextPrimary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "common_close"))
        }
    }

    private func sourceRow(_ source: LyricSource, song: Song) -> some View {
        let isSelected = lyricViewModel.selectedSource(for: song) == source
        let tint = source.musicSource.themedBadgeColor

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            lyricViewModel.changeSource(source, for: song)
            close()
        } label: {
            HStack(spacing: 12) {
                PlatformBadgeLabel(text: source.shortName, source: source.musicSource, fontSize: 12)

                Spacer(minLength: 0)

                if isSelected {
                    if lyricViewModel.isLoading && lyricViewModel.activeSource == source {
                        ProgressView()
                            .tint(tint)
                            .controlSize(.small)
                    } else {
                        MonologueIcon(icon: .checkmark, size: 15, color: tint, lineWidth: 2)
                    }
                }
            }
            .frame(minHeight: 54)
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? String(localized: "lyric_source_selected") : "")
    }

    private func close() {
        dismissCurrentPresentation(
            systemDismiss: dismiss,
            monologueSheetDismiss: monologueSheetDismiss
        )
    }
}
