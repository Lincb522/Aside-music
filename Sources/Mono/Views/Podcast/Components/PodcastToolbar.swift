import SwiftUI

/// 播客页底部工具栏：倍速、睡眠定时器、节目列表三个胶囊按钮；
/// `isAside`（默认主题）与主题化页面使用不同的间距与描边样式。
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
    private func toolButton(label: String?, icon: MonoIcon.IconType?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    MonoIcon(icon: icon, size: isAside ? 13 : 16, color: isAside ? .monoTextPrimary.opacity(0.8) : .monoTextSecondary, lineWidth: 1.4)
                }
                if let label {
                    Text(label)
                        .font(isAside ? .rounded(size: 12, weight: .semibold) : .system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(isAside ? .monoTextPrimary.opacity(0.8) : .monoTextSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if !isAside {
                    Capsule().fill(Color.monoGlassTint.opacity(0.5))
                }
            }
            .overlay {
                if isAside {
                    Capsule().stroke(Color.monoSeparator.opacity(0.95), lineWidth: 0.8)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(MonoBouncingButtonStyle())
    }
}
