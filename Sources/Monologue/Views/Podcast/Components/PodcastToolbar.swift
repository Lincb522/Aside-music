import SwiftUI

struct PodcastToolbar: View {
    @ObservedObject private var player = PlayerManager.shared

    var onSpeedTap: () -> Void
    var onTimerTap: () -> Void
    var onPlaylistTap: () -> Void

    private var speedText: String {
        let speed = player.playbackSpeed
        if speed == Float(Int(speed)) {
            return String(format: "%.0fx", speed)
        }
        return String(format: "%.1fx", speed)
    }

    private var timerText: String? {
        if player.pendingSleepStopAfterCurrentTrack {
            return String(localized: "podcast_timer_pending_short")
        }
        guard let remaining = player.sleepTimerRemaining else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 24) {
            toolButton(label: speedText, icon: nil, action: onSpeedTap)
            toolButton(label: timerText, icon: .clock, action: onTimerTap)
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
