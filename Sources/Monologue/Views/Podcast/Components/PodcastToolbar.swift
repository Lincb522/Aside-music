import SwiftUI

struct PodcastToolbar: View {
    @ObservedObject private var model = PodcastToolbarModel.shared

    var onSpeedTap: () -> Void
    var onTimerTap: () -> Void
    var onPlaylistTap: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            toolButton(label: model.speedText, icon: nil, action: onSpeedTap)
            toolButton(label: model.timerText, icon: .clock, action: onTimerTap)
            toolButton(label: nil, icon: .list, action: onPlaylistTap)
        }
    }

    @ViewBuilder
    private func toolButton(label: String?, icon: MonologueIcon.IconType?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    MonologueIcon(icon: icon, size: 16, color: .monologueTextSecondary, lineWidth: 1.4)
                }
                if let label {
                    Text(label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.monologueGlassTint.opacity(0.5))
            .clipShape(Capsule())
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }
}
