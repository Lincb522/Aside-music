import SwiftUI

struct PodcastSpeedSheet: View {
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            Text("podcast_speed_title")
                .font(.rounded(size: 17, weight: .bold))
                .foregroundColor(.monologueTextPrimary)
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
                                .font(.rounded(size: 16, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .monologueAccentBlue : .monologueTextPrimary)

                            Spacer()

                            if isSelected {
                                MonologueIcon(icon: .checkmark, size: 16, color: .monologueAccentBlue, lineWidth: 2)
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.vertical, 14)
                        .background(isSelected ? Color.monologueAccentBlue.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.isPad ? 24 : 16)

            Spacer()
        }
        .background {
            Rectangle()
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
        }
        .ignoresSafeArea(edges: .bottom)
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
