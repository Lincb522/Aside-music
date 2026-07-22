import SwiftUI

struct PodcastToolbar: View {
    @ObservedObject private var model = PodcastToolbarModel.shared

    var onSpeedTap: () -> Void
    var onTimerTap: () -> Void
    var onPlaylistTap: () -> Void

    private var isAside: Bool {
        !ThemedPageStyle.isActive
    }

    var body: some View {
        HStack(spacing: isAside ? 14 : 24) {
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
                    MonologueIcon(icon: icon, size: isAside ? 13 : 16, color: isAside ? .monologueTextPrimary.opacity(0.8) : .monologueTextSecondary, lineWidth: 1.4)
                }
                if let label {
                    Text(label)
                        .font(isAside ? .rounded(size: 12, weight: .semibold) : .system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(isAside ? .monologueTextPrimary.opacity(0.8) : .monologueTextSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if !isAside {
                    Capsule().fill(Color.monologueGlassTint.opacity(0.5))
                }
            }
            .overlay {
                if isAside {
                    Capsule().stroke(Color.monologueSeparator.opacity(0.95), lineWidth: 0.8)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }
}
