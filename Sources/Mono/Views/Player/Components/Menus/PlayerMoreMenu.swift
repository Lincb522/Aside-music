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
    @ObservedObject private var aiEqualizerAgent = AIEqualizerAgent.shared
    @ObservedObject private var monoSuite = MonoNextSuiteManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var lyricViewModel = LyricViewModel.shared
    @ObservedObject private var monoSession = MonoSessionManager.shared
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var lyricDownloadManager = LyricDownloadManager.shared
    @AppStorage("enableKaraoke") private var enableKaraoke = false
    @AppStorage("showTranslation") private var showTranslation = true
    @State private var showTimerSheet = false
    @State private var showLyricSourceSheet = false
    @State private var showImmersiveSettings = false
    @State private var showPlayerTypography = false
    @State private var showMonoSession = false
    @State private var showCurrentSongDownload = false
    @State private var showDownloadManager = false
    @State private var selectedSongForStory: Song?
    /// 子级页面关闭时，Sheet 的绑定会先复位；单独保留转场状态，避免菜单短暂重绘。
    @State private var isPresentingChild = false

    private let textColor: Color = .monoTextPrimary

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

    private var soundCenterStatusText: String {
        if player.currentSong?.isAppleMusic == true {
            return String(localized: "apple_music_protected_audio")
        }
        if aiEqualizerAgent.phase.isWorking {
            return String(localized: "mono_audio_tuning")
        }

        if aiEqualizerAgent.isCurrentProposalApplied {
            let name = aiEqualizerAgent.proposal?.profileName
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty { return name }
        }

        if eqManager.isEnabled {
            let name = eqManager.currentPreset?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? String(localized: "eq_custom") : name
        }

        let activeEnhancements = [
            MonoNextFeature.spatialLive,
            .dna,
            .recovery
        ].filter { monoSuite.isEnabled($0) }.count
        if activeEnhancements > 0 {
            return String(
                format: String(localized: "mono_suite_running_count"),
                activeEnhancements,
                3
            )
        }

        return String(localized: "settings_off")
    }

    private var currentDownloadStatus: String? {
        guard let song = player.currentSong else { return nil }
        if song.isAppleMusic {
            return String(localized: "apple_music_download_unavailable")
        }
        if downloadManager.localFileURL(for: song) != nil {
            return String(localized: "已下载")
        }
        if let task = downloadManager.task(for: song) {
            return "\(Int(task.progress * 100))%"
        }
        if lyricDownloadManager.record(for: song) != nil {
            return String(localized: "歌词已下载")
        }
        return nil
    }

    private var downloadManagerStatus: String? {
        let count = downloadManager.fetchAllDownloaded().count + lyricDownloadManager.records.count
        return count > 0 ? "\(count)" : nil
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { proxy in
            let panelWidth = min(292, max(240, proxy.size.width - 24))
            let panelMaxHeight = max(280, proxy.size.height - resolvedTopPadding - 12)

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
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: panelMaxHeight, alignment: .top)
                        .padding(.top, resolvedTopPadding)
                        .padding(.trailing, resolvedTrailingPadding(containerWidth: proxy.size.width))
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
                }
            }
        }
        .monoSheet(isPresented: $showTimerSheet, onDismiss: {
            closeMenu()
        }, preset: .standard){
            PodcastTimerSheet()

        }
        .monoSheet(isPresented: $showLyricSourceSheet, onDismiss: {
            closeMenu()
        }, preset: .compact) {
            CurrentSongLyricSourceSheet()
        }
        .monoSheet(isPresented: $showCurrentSongDownload, onDismiss: {
            closeMenu()
        }, preset: .standard) {
            CurrentSongDownloadSheet()
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
        .fullScreenCover(isPresented: $showMonoSession, onDismiss: {
            closeMenu()
        }) {
            NavigationStack {
                MonoSessionPlayerView()
            }
        }
        .fullScreenCover(isPresented: $showDownloadManager, onDismiss: {
            closeMenu()
        }) {
            NavigationStack {
                DownloadManageView()
            }
        }
        .fullScreenCover(item: $selectedSongForStory, onDismiss: {
            closeMenu()
        }) { song in
            NavigationStack {
                SongDetailView(song: song)
            }
        }
    }

    private var menuPanel: some View {
        MonoMoreMenuPanel(
            title: String(localized: "player_more_title"),
            isDarkBackground: isDarkBackground,
            closeAction: closeMenu
        ) {
            ScrollView {
                menuPanelContent
            }
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var menuPanelContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            menuSection(title: String(localized: "player_more_playback_section")) {
                playbackQuickActions
            }

            menuSection(title: String(localized: "player_more_lyrics_section")) {
                lyricActionList
            }

            menuSection(title: String(localized: "player_more_player_section")) {
                playerActionList
            }
        }
    }

    private var lyricActionList: some View {
        menuGroup {
            menuActionRow(
                icon: .musicNoteList,
                title: String(localized: "lyric_source_change"),
                status: currentLyricSource?.shortName,
                statusSource: currentLyricSource?.musicSource,
                isEnabled: player.currentSong != nil
            ) {
                isPresentingChild = true
                showLyricSourceSheet = true
            }

            menuDivider

            menuActionRow(
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
    }

    private var playerActionList: some View {
        menuGroup {
            menuActionRow(
                icon: .catStory,
                title: String(localized: "player_more_behind_music"),
                isEnabled: player.currentSong != nil
            ) {
                guard let song = player.currentSong else { return }
                isPresentingChild = true
                selectedSongForStory = song
            }

            menuDivider

            menuActionRow(
                icon: .personCircle,
                title: String(localized: "mono_session_title"),
                status: monoSessionMenuStatus
            ) {
                isPresentingChild = true
                showMonoSession = true
            }

            if let onTheme {
                menuDivider

                menuActionRow(
                    icon: .playerTheme,
                    title: String(localized: "theme_title")
                ) {
                    closeMenu()
                    onTheme()
                }
            }

            if showImmersiveEntry {
                menuDivider
                immersiveMenuRow
            }

            menuDivider

            menuToggleRow(
                icon: .waveform,
                title: String(localized: "player_more_game_mode"),
                isOn: Binding(
                    get: { gameMode.isActive },
                    set: { newValue in
                        guard newValue != gameMode.isActive else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        gameMode.toggle()
                    }
                )
            )

            if AppConfig.Features.restrictedDownloadEnabled {
                menuDivider

                menuActionRow(
                    icon: .playerDownload,
                    title: String(localized: "下载当前歌曲"),
                    status: currentDownloadStatus,
                    isEnabled: player.currentSong != nil
                        && player.currentSong?.isAppleMusic != true
                ) {
                    isPresentingChild = true
                    showCurrentSongDownload = true
                }

                menuDivider

                menuActionRow(
                    icon: .storage,
                    title: String(localized: "下载管理"),
                    status: downloadManagerStatus
                ) {
                    isPresentingChild = true
                    showDownloadManager = true
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
                title: String(localized: "mono_audio_center_title"),
                status: soundCenterStatusText
            ) {
                closeMenu()
                onEQ()
            }
        }
    }

    private var monoSessionMenuStatus: String? {
        guard let room = monoSession.room else { return nil }
        return String(format: String(localized: "mono_session_member_count"), room.participants.count)
    }

    private func menuActionRow(
        icon: MonoIcon.IconType,
        title: String,
        status: String? = nil,
        statusSource: MusicSource? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                menuRowIcon(icon, isActive: false, isEnabled: isEnabled)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor.opacity(isEnabled ? 0.92 : 0.34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)

                if let status, !status.isEmpty {
                    if let statusSource {
                        PlatformBadgeLabel(text: status, source: statusSource, fontSize: 9.5)
                            .opacity(isEnabled ? 1 : 0.34)
                    } else {
                        Text(status)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.monoTextSecondary.opacity(isEnabled ? 1 : 0.34))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .monospacedDigit()
                    }
                }

                MonoIcon(
                    icon: .chevronRight,
                    size: 10,
                    color: .monoTextSecondary.opacity(isEnabled ? 0.62 : 0.22)
                )
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityValue(status ?? "")
    }

    private func menuToggleRow(
        icon: MonoIcon.IconType,
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                isOn.wrappedValue.toggle()
            }
            HapticManager.shared.light()
        } label: {
            HStack(spacing: 10) {
                menuRowIcon(icon, isActive: isOn.wrappedValue, isEnabled: true)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor.opacity(0.92))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Capsule(style: .continuous)
                    .fill(isOn.wrappedValue ? Color.monoAccent : textColor.opacity(0.11))
                    .frame(width: 30, height: 18)
                    .overlay(alignment: isOn.wrappedValue ? .trailing : .leading) {
                        Circle()
                            .fill(isOn.wrappedValue ? Color.white : textColor.opacity(0.58))
                            .frame(width: 14, height: 14)
                            .padding(2)
                    }
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn.wrappedValue ? "1" : "0")
    }

    private var immersiveMenuRow: some View {
        HStack(spacing: 0) {
            Button {
                closeMenu()
                ImmersiveModeController.shared.present()
            } label: {
                HStack(spacing: 10) {
                    menuRowIcon(.immersive, isActive: false, isEnabled: true)

                    Text(String(localized: "player_more_enter_immersive"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(textColor.opacity(0.92))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.leading, 11)
                .frame(maxWidth: .infinity, minHeight: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.monoSeparator.opacity(0.8))
                .frame(width: 0.5, height: 22)

            Button {
                isPresentingChild = true
                showImmersiveSettings = true
            } label: {
                MonoIcon(icon: .settings, size: 15, color: textColor.opacity(0.72))
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "player_more_immersive_settings"))
        }
    }

    private func menuRowIcon(
        _ icon: MonoIcon.IconType,
        isActive: Bool,
        isEnabled: Bool
    ) -> some View {
        MonoIcon(
            icon: icon,
            size: 14,
            color: isActive
                ? .monoAccent
                : textColor.opacity(isEnabled ? 0.78 : 0.3)
        )
        .frame(width: 26, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    isActive
                        ? Color.monoAccent.opacity(0.13)
                        : textColor.opacity(isEnabled ? 0.04 : 0.02)
                )
        )
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.monoSeparator.opacity(0.72))
            .frame(height: 0.5)
            .padding(.leading, 47)
    }

    private func menuGroup<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(textColor.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.monoSeparator.opacity(0.52), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func menuSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundColor(.monoTextSecondary)
                .padding(.horizontal, 4)

            content()
        }
    }

    private func quickAction(
        icon: MonoIcon.IconType,
        title: String,
        status: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                MonoIcon(
                    icon: icon,
                    size: 16,
                    color: textColor.opacity(isEnabled ? 0.9 : 0.34)
                )

                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor.opacity(isEnabled ? 0.9 : 0.34))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, minHeight: 14, alignment: .center)

                if let status, !status.isEmpty {
                    Text(status)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.monoTextSecondary.opacity(isEnabled ? 1 : 0.38))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66, alignment: .center)
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
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss
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
                                .fill(Color.monoSeparator)
                                .frame(height: 0.5)
                                .padding(.leading, 18)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.monoTextPrimary.opacity(0.055))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.monoSeparator, lineWidth: 0.5)
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
                    .foregroundColor(.monoTextPrimary)

                if let song = player.currentSong {
                    Text(song.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                close()
            } label: {
                MonoIcon(icon: .close, size: 14, color: .monoTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.monoTextPrimary.opacity(0.06)))
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
                        MonoIcon(icon: .checkmark, size: 15, color: tint, lineWidth: 2)
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
            monoSheetDismiss: monoSheetDismiss
        )
    }
}
