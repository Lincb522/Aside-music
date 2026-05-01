import SwiftUI

struct PodcastSpeedSheet: View {
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 0) {
            Text("podcast_speed_title")
                .font(titleFont)
                .foregroundColor(primaryTextColor)
                .padding(.bottom, 20)

            VStack(spacing: 6) {
                ForEach(speeds, id: \.self) { speed in
                    let isSelected = abs(player.playbackSpeed - speed) < 0.01

                    Button {
                        player.setPlaybackSpeed(speed)
                        dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                    } label: {
                        HStack {
                            Text(speedLabel(speed))
                                .font(optionFont(isSelected: isSelected))
                                .foregroundColor(isSelected ? selectedTint : defaultTextColor)

                            Spacer()

                            if isSelected {
                                MonologueIcon(icon: .checkmark, size: 16, color: selectedTint, lineWidth: 2)
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.vertical, 14)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(
                                    cornerRadius: 16,
                                    elevated: false,
                                    pressed: isSelected,
                                    tint: isSelected ? NeumorphicStyle.accent.opacity(0.16) : nil
                                )
                            } else if SequoiaStyle.isActive {
                                SequoiaSurfaceBackground(
                                    cornerRadius: 16,
                                    elevated: isSelected,
                                    pressed: !isSelected,
                                    fill: isSelected ? SequoiaStyle.accent.opacity(0.12) : SequoiaStyle.materialList,
                                    role: isSelected ? .selected : .list
                                )
                            } else {
                                isSelected ? Color.monologueAccentBlue.opacity(0.08) : Color.clear
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.isPad ? 24 : 16)

            Spacer()
        }
        .background {
            if NeumorphicStyle.isActive {
                Color.clear
            } else if SequoiaStyle.isActive {
                Color.clear
            } else {
                Rectangle()
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var selectedTint: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monologueAccentBlue
    }

    private var defaultTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var primaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var titleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(18, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(18, weight: .semibold) }
        return .rounded(size: 17, weight: .bold)
    }

    private func optionFont(isSelected: Bool) -> Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(16, weight: isSelected ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(16, weight: isSelected ? .semibold : .regular) }
        return .rounded(size: 16, weight: isSelected ? .semibold : .regular)
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 {
            return String(localized: "podcast_speed_normal")
        }
        if speed == Float(Int(speed)) {
            return String(format: "%.0fx", speed)
        }
        return String(format: "%.2gx", speed)
    }
}
