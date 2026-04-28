import SwiftUI

struct PodcastSpeedSheet: View {
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            Text("podcast_speed_title")
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .rounded(size: 17, weight: .bold))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
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
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(16, weight: isSelected ? .semibold : .medium) : .rounded(size: 16, weight: isSelected ? .semibold : .regular))
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
                            } else {
                                isSelected ? Color.monologueAccentBlue.opacity(0.08) : Color.clear
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 16 : 12, style: .continuous))
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
            } else {
                Rectangle()
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var selectedTint: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueAccentBlue
    }

    private var defaultTextColor: Color {
        NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
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
