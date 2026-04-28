import SwiftUI

struct PodcastTimerSheet: View {
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

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
        hasActivePlan ? .monologueAccentBlue : .monologueTextSecondary
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
        }
        .background {
            MonologueSheetAwareBackground {
                ThemedPageBackground()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("podcast_timer_title"))
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundStyle(Color.monologueTextPrimary)

                Text(LocalizedStringKey("podcast_timer_strategy_subtitle"))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.monologueTextSecondary)
            }

            Spacer()

            Button {
                dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
            } label: {
                ZStack {
                    Circle()
                        .fill(NeumorphicStyle.isActive ? Color.clear : Color.monologueTextPrimary.opacity(0.08))
                        .frame(width: 34, height: 34)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true)
                            }
                        }

                    MonologueIcon(icon: .close, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextPrimary)
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
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

                        MonologueIcon(icon: .clock, size: 20, color: statusTint)
                    }

                    Spacer(minLength: 12)

                    if hasActivePlan {
                        TimerStatusBadge(
                            text: String(localized: "podcast_timer_active"),
                            tint: Color.monologueAccentBlue
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(currentStatusTitle)
                        .font(player.sleepTimerRemaining != nil
                              ? .system(size: 22, weight: .bold, design: .monospaced)
                              : .rounded(size: 18, weight: .bold))
                        .foregroundStyle(hasActivePlan ? Color.monologueTextPrimary : Color.monologueTextSecondary)
                        .monospacedDigit()

                    Text(currentStatusSubtitle)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.monologueTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if let configuredMinutes = player.sleepTimerConfiguredMinutes {
                        TimerStatusBadge(
                            text: String(
                                format: String(localized: "podcast_timer_custom_value"),
                                configuredMinutes
                            ),
                            tint: Color.monologueAccentBlue
                        )
                    }

                    if player.pendingSleepStopAfterCurrentTrack ||
                        (player.sleepTimerRemaining != nil && player.sleepTimerStopAfterCurrentTrack) {
                        TimerStatusBadge(
                            text: String(localized: "podcast_timer_stop_after_track"),
                            tint: Color.monologueTextSecondary
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
                                .fill(Color.monologueAccentBlue.opacity(isCustomSelected ? 0.18 : 0.10))
                                .frame(width: 44, height: 44)

                            MonologueIcon(icon: .add, size: 16, color: .monologueAccentBlue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("podcast_timer_custom"))
                                .font(.rounded(size: 16, weight: isCustomSelected ? .bold : .semibold))
                                .foregroundStyle(isCustomSelected ? Color.monologueAccentBlue : Color.monologueTextPrimary)

                            Text(customMinutesText ?? String(localized: "podcast_timer_custom_subtitle"))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(isCustomSelected ? Color.monologueAccentBlue.opacity(0.85) : Color.monologueTextSecondary)
                        }

                        Spacer(minLength: 12)

                        if isCustomSelected {
                            MonologueIcon(icon: .checkmark, size: 16, color: .monologueAccentBlue)
                        } else {
                            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.45))
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
                                .font(.rounded(size: 16, weight: .semibold))
                                .foregroundStyle(Color.monologueTextPrimary)

                            Text(stopAfterTrackDescription)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.monologueTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Toggle("", isOn: $player.sleepTimerStopAfterCurrentTrack)
                            .labelsHidden()
                            .tint(Color.monologueAccentBlue)
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
                                .fill(Color.monologueAccentBlue.opacity(player.pendingSleepStopAfterCurrentTrack ? 0.18 : 0.10))
                                .frame(width: 44, height: 44)

                            MonologueIcon(icon: .stop, size: 16, color: .monologueAccentBlue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("podcast_timer_stop_current_track_now"))
                                .font(.rounded(size: 16, weight: player.pendingSleepStopAfterCurrentTrack ? .bold : .semibold))
                                .foregroundStyle(player.pendingSleepStopAfterCurrentTrack ? Color.monologueAccentBlue : Color.monologueTextPrimary)

                            Text(LocalizedStringKey("podcast_timer_stop_current_track_now_subtitle"))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.monologueTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        if player.pendingSleepStopAfterCurrentTrack {
                            TimerStatusBadge(
                                text: String(localized: "podcast_timer_active"),
                                tint: Color.monologueAccentBlue
                            )
                        } else {
                            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.45))
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
                            .fill(Color.red.opacity(0.10))
                            .frame(width: 44, height: 44)

                        MonologueIcon(icon: .close, size: 16, color: .red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("podcast_timer_cancel_action"))
                            .font(.rounded(size: 16, weight: .semibold))
                            .foregroundStyle(Color.monologueTextPrimary)

                        Text(LocalizedStringKey("podcast_timer_cancel_subtitle"))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.monologueTextSecondary)
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
                        .font(.rounded(size: 16, weight: selected ? .bold : .semibold))
                        .foregroundStyle(selected ? Color.monologueAccentBlue : Color.monologueTextPrimary)

                    Spacer(minLength: 8)

                    if selected {
                        MonologueIcon(icon: .checkmark, size: 15, color: .monologueAccentBlue)
                    }
                }

                Text(LocalizedStringKey("podcast_timer_presets_subtitle"))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.monologueTextSecondary.opacity(0.78))
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
                } else {
                    selected ? Color.monologueAccentBlue.opacity(0.12) : Color.monologueTextPrimary.opacity(0.04)
                }
            }
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
            .overlay {
                if !NeumorphicStyle.isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(selected ? Color.monologueAccentBlue.opacity(0.22) : Color.monologueTextPrimary.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.monologueTextSecondary)

            Text(subtitle)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color.monologueTextSecondary.opacity(0.78))
        }
        .padding(.horizontal, 4)
    }
}

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
                } else {
                    Color.monologueTextPrimary.opacity(0.04)
                }
            }
            .clipShape(.rect(cornerRadius: NeumorphicStyle.isActive ? 22 : 20, style: .continuous))
            .overlay {
                if !NeumorphicStyle.isActive {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.monologueTextPrimary.opacity(0.06), lineWidth: 1)
                }
            }
    }
}

private struct TimerStatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.15), lightweight: true)
                } else {
                    tint.opacity(0.12)
                }
            }
            .clipShape(.capsule)
    }
}
