import SwiftUI

/// 睡眠定时器设置弹窗：预设时长网格、自定义分钟数输入、
/// "播完本集再停"策略开关，以及实时倒计时状态卡片；直接读写 PlayerManager 的定时器状态。
struct PodcastTimerSheet: View {
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss

    private struct PresetOption: Identifiable {
        let titleKey: String
        let minutes: Int

        var id: Int { minutes }
    }

    private let presetOptions: [PresetOption] = [
        .init(titleKey: "podcast_timer_10", minutes: 10),
        .init(titleKey: "podcast_timer_20", minutes: 20),
        .init(titleKey: "podcast_timer_30", minutes: 30),
        .init(titleKey: "podcast_timer_60", minutes: 60),
    ]

    private let presetColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var presetMinutes: Set<Int> {
        Set(presetOptions.map(\.minutes))
    }

    // MARK: - 状态派生

    private var hasActivePlan: Bool {
        player.sleepTimerRemaining != nil || player.pendingSleepStopAfterCurrentTrack
    }

    private var formattedRemaining: String {
        guard let remaining = player.sleepTimerRemaining else { return "" }
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var currentStatusTitle: String {
        if player.pendingSleepStopAfterCurrentTrack {
            return String(localized: "podcast_timer_wait_current_track")
        }
        if player.sleepTimerRemaining != nil {
            return String(
                format: String(localized: "podcast_timer_status_running_format"),
                formattedRemaining
            )
        }
        return String(localized: "podcast_timer_inactive")
    }

    private var currentStatusSubtitle: String {
        if player.pendingSleepStopAfterCurrentTrack {
            return String(localized: "podcast_timer_status_pending_desc")
        }
        if player.sleepTimerRemaining != nil {
            return String(localized: "podcast_timer_status_running_desc")
        }
        return String(localized: "podcast_timer_status_ready")
    }

    private var statusTint: Color {
        hasActivePlan ? activeTint : secondaryTextColor
    }

    private var customMinutesText: String? {
        guard let configuredMinutes = player.sleepTimerConfiguredMinutes,
              !presetMinutes.contains(configuredMinutes) else {
            return nil
        }
        return String(
            format: String(localized: "podcast_timer_custom_value"),
            configuredMinutes
        )
    }

    private func isSelected(minutes: Int?) -> Bool {
        switch minutes {
        case nil:
            return player.sleepTimerConfiguredMinutes == nil
        case .some(let value):
            return player.sleepTimerConfiguredMinutes == value
        }
    }

    private var isCustomSelected: Bool {
        guard let configuredMinutes = player.sleepTimerConfiguredMinutes else { return false }
        return !presetMinutes.contains(configuredMinutes)
    }

    private var stopAfterTrackDescription: String {
        player.sleepTimerStopAfterCurrentTrack
            ? String(localized: "podcast_timer_stop_after_track_desc_on")
            : String(localized: "podcast_timer_stop_after_track_desc_off")
    }

    /// 弹出自定义分钟数输入框；非法输入（1~1440 之外）提示后重新弹出。
    private func presentCustomTimerInput() {
        AlertManager.shared.showInput(
            title: String(localized: "podcast_timer_custom"),
            message: String(localized: "podcast_timer_custom_prompt"),
            placeholder: String(localized: "podcast_timer_custom_placeholder"),
            primaryButtonTitle: String(localized: "confirm"),
            secondaryButtonTitle: String(localized: "alert_cancel"),
            onConfirm: { input in
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let minutes = Int(trimmed), minutes > 0, minutes <= 1440 else {
                    AlertManager.shared.show(
                        title: String(localized: "podcast_timer_invalid_title"),
                        message: String(localized: "podcast_timer_invalid_message"),
                        primaryButtonTitle: String(localized: "confirm"),
                        primaryAction: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                presentCustomTimerInput()
                            }
                        }
                    )
                    return
                }

                player.startSleepTimer(minutes: minutes)
            }
        )
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 20) {
                    statusCard
                    presetsSection
                    strategySection

                    if hasActivePlan {
                        cancelSection
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .iPadContentWidth(520)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .background {
            MonoSheetAwareBackground {
                ThemedPageBackground()
            }
        }
    }

    // MARK: - 子视图

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("podcast_timer_title"))
                    .font(titleFont)
                    .foregroundStyle(primaryTextColor)

                Text(LocalizedStringKey("podcast_timer_strategy_subtitle"))
                    .font(captionFont)
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer()

            Button {
                dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss)
            } label: {
                ZStack {
                    Circle()
                        .fill((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? Color.clear : Color.monoTextPrimary.opacity(0.08))
                        .frame(width: 34, height: 34)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true)
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, role: .list)
                            }
                        }

                    MonoIcon(icon: .close, size: 14, color: secondaryTextColor)
                }
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            .accessibilityLabel(Text(LocalizedStringKey("alert_cancel")))
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .iPadContentWidth(520)
    }

    private var statusCard: some View {
        TimerSheetCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(statusTint.opacity(0.12))
                            .frame(width: 52, height: 52)

                        MonoIcon(icon: .clock, size: 20, color: statusTint)
                    }

                    Spacer(minLength: 12)

                    if hasActivePlan {
                        TimerStatusBadge(
                            text: String(localized: "podcast_timer_active"),
                            tint: activeTint
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(currentStatusTitle)
                        .font(player.sleepTimerRemaining != nil
                              ? .system(size: 22, weight: .bold, design: .monospaced)
                              : titleFont)
                        .foregroundStyle(hasActivePlan ? primaryTextColor : secondaryTextColor)
                        .monospacedDigit()

                    Text(currentStatusSubtitle)
                        .font(bodyCaptionFont)
                        .foregroundStyle(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if let configuredMinutes = player.sleepTimerConfiguredMinutes {
                        TimerStatusBadge(
                            text: String(
                                format: String(localized: "podcast_timer_custom_value"),
                                configuredMinutes
                            ),
                            tint: activeTint
                        )
                    }

                    if player.pendingSleepStopAfterCurrentTrack ||
                        (player.sleepTimerRemaining != nil && player.sleepTimerStopAfterCurrentTrack) {
                        TimerStatusBadge(
                            text: String(localized: "podcast_timer_stop_after_track"),
                            tint: secondaryTextColor
                        )
                    }
                }
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: LocalizedStringKey("podcast_timer_presets"),
                subtitle: LocalizedStringKey("podcast_timer_presets_subtitle")
            )

            LazyVGrid(columns: presetColumns, spacing: 12) {
                ForEach(presetOptions) { option in
                    presetCard(option)
                }
            }

                    Button {
                presentCustomTimerInput()
            } label: {
                TimerSheetCard {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(activeTint.opacity(isCustomSelected ? 0.18 : 0.10))
                                .frame(width: 44, height: 44)

                            MonoIcon(icon: .add, size: 16, color: activeTint)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("podcast_timer_custom"))
                                .font(rowTitleFont(isSelected: isCustomSelected))
                                .foregroundStyle(isCustomSelected ? activeTint : primaryTextColor)

                            Text(customMinutesText ?? String(localized: "podcast_timer_custom_subtitle"))
                                .font(captionFont)
                                .foregroundStyle(isCustomSelected ? activeTint.opacity(0.85) : secondaryTextColor)
                        }

                        Spacer(minLength: 12)

                        if isCustomSelected {
                            MonoIcon(icon: .checkmark, size: 16, color: activeTint)
                        } else {
                            MonoIcon(icon: .chevronRight, size: 12, color: secondaryTextColor.opacity(0.45))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: LocalizedStringKey("podcast_timer_strategy"),
                subtitle: LocalizedStringKey("podcast_timer_strategy_subtitle")
            )

            TimerSheetCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("podcast_timer_stop_after_track"))
                                .font(rowTitleFont(isSelected: false))
                                .foregroundStyle(primaryTextColor)

                            Text(stopAfterTrackDescription)
                                .font(captionFont)
                                .foregroundStyle(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Toggle("", isOn: $player.sleepTimerStopAfterCurrentTrack)
                            .labelsHidden()
                            .tint(activeTint)
                    }
                }
            }

            Button {
                player.activateSleepStopAfterCurrentTrack()
                    } label: {
                TimerSheetCard {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(activeTint.opacity(player.pendingSleepStopAfterCurrentTrack ? 0.18 : 0.10))
                                .frame(width: 44, height: 44)

                            MonoIcon(icon: .stop, size: 16, color: activeTint)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("podcast_timer_stop_current_track_now"))
                                .font(rowTitleFont(isSelected: player.pendingSleepStopAfterCurrentTrack))
                                .foregroundStyle(player.pendingSleepStopAfterCurrentTrack ? activeTint : primaryTextColor)

                            Text(LocalizedStringKey("podcast_timer_stop_current_track_now_subtitle"))
                                .font(captionFont)
                                .foregroundStyle(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        if player.pendingSleepStopAfterCurrentTrack {
                            TimerStatusBadge(
                                text: String(localized: "podcast_timer_active"),
                                tint: activeTint
                            )
                        } else {
                            MonoIcon(icon: .chevronRight, size: 12, color: secondaryTextColor.opacity(0.45))
                        }
                    }
                }
                    }
                    .buttonStyle(.plain)
            .disabled(player.pendingSleepStopAfterCurrentTrack)
        }
    }

    private var cancelSection: some View {
        Button {
            player.cancelSleepTimer()
        } label: {
            TimerSheetCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(destructiveTint.opacity(0.10))
                            .frame(width: 44, height: 44)

                        MonoIcon(icon: .close, size: 16, color: destructiveTint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("podcast_timer_cancel_action"))
                            .font(rowTitleFont(isSelected: false))
                            .foregroundStyle(primaryTextColor)

                        Text(LocalizedStringKey("podcast_timer_cancel_subtitle"))
                            .font(captionFont)
                            .foregroundStyle(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func presetCard(_ option: PresetOption) -> some View {
        let selected = isSelected(minutes: option.minutes)

        return Button {
            player.startSleepTimer(minutes: option.minutes)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(LocalizedStringKey(option.titleKey))
                        .font(rowTitleFont(isSelected: selected))
                        .foregroundStyle(selected ? activeTint : primaryTextColor)

                    Spacer(minLength: 8)

                    if selected {
                        MonoIcon(icon: .checkmark, size: 15, color: activeTint)
                    }
                }

                Text(LocalizedStringKey("podcast_timer_presets_subtitle"))
                    .font(smallCaptionFont)
                    .foregroundStyle(secondaryTextColor.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(14)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(
                        cornerRadius: 18,
                        elevated: false,
                        pressed: selected,
                        tint: selected ? NeumorphicStyle.accent.opacity(0.16) : nil
                    )
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(
                        cornerRadius: 18,
                        elevated: selected,
                        pressed: !selected,
                        fill: selected ? activeTint.opacity(0.12) : SequoiaStyle.materialList,
                        role: selected ? .selected : .list
                    )
                } else {
                    selected ? Color.monoAccent.opacity(0.12) : Color.monoTextPrimary.opacity(0.04)
                }
            }
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
            .overlay {
                if !NeumorphicStyle.isActive && !SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(selected ? Color.monoAccent.opacity(0.25) : Color.monoTextPrimary.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(sectionHeaderFont)
                .foregroundStyle(secondaryTextColor)

            Text(subtitle)
                .font(captionFont)
                .foregroundStyle(secondaryTextColor.opacity(0.78))
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 主题化字体与颜色

    private var activeTint: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monoAccent
    }

    private var destructiveTint: Color {
        SequoiaStyle.isActive ? SequoiaStyle.red : .red
    }

    private var primaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    private var secondaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }

    private var titleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(20, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(20, weight: .semibold) }
        return .rounded(size: 20, weight: .bold)
    }

    private var sectionHeaderFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var captionFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 12, design: .rounded)
    }

    private var bodyCaptionFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        return .system(size: 13, design: .rounded)
    }

    private var smallCaptionFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .regular) }
        return .system(size: 11, design: .rounded)
    }

    private func rowTitleFont(isSelected: Bool) -> Font {
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(16, weight: isSelected ? .semibold : .medium) }
        return .rounded(size: 16, weight: isSelected ? .bold : .semibold)
    }
}

/// 弹窗内的通用卡片容器（主题化背景/描边）。
private struct TimerSheetCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 22, elevated: false, role: .list)
                } else {
                    Color.monoTextPrimary.opacity(0.04)
                }
            }
            .clipShape(.rect(cornerRadius: (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 22 : 20, style: .continuous))
            .overlay {
                if !NeumorphicStyle.isActive && !SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.monoTextPrimary.opacity(0.06), lineWidth: 1)
                }
            }
    }
}

/// 状态胶囊徽章（如"进行中"）。
private struct TimerStatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .semibold) : .system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.15), lightweight: true)
                } else if SequoiaStyle.isActive {
                    Capsule()
                        .fill(SequoiaStyle.materialList.opacity(0.78))
                        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 0.55))
                } else {
                    tint.opacity(0.12)
                }
            }
            .clipShape(.capsule)
    }
}
