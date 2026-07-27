import SwiftUI

/// 播客播放控制栏：上一集 / 回退15s / 播放暂停 / 快进15s / 下一集。
struct PodcastControlsBar: View {
    let isPlaying: Bool
    let isLoading: Bool

    var onPrevious: () -> Void
    var onSeekBack: () -> Void
    var onPlayPause: () -> Void
    var onSeekForward: () -> Void
    var onNext: () -> Void

    private var isAside: Bool {
        !ThemedPageStyle.isActive
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPrevious) {
                MonoIcon(icon: .skipBack, size: isAside ? 18 : 20, color: .monoTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonoBouncingButtonStyle())

            Spacer()

            Button(action: onSeekBack) {
                MonoIcon(icon: .rewind15, size: isAside ? 22 : 24, color: .monoTextPrimary, lineWidth: 1.4)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonoBouncingButtonStyle())

            Spacer()

            Button(action: onPlayPause) {
                ZStack {
                    if isAside {
                        Circle()
                            .fill(Color.monoTextPrimary)
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.monoTextPrimary.opacity(0.22), radius: 14, x: 0, y: 7)
                    } else {
                        Circle()
                            .fill(Color.monoGlassTint)
                            .frame(width: 72, height: 72)
                            .monoGlassCircle()
                            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                    }

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isAside ? Color(.systemBackground) : .monoTextPrimary))
                            .scaleEffect(1.2)
                    } else {
                        MonoIcon(
                            icon: isPlaying ? .pause : .play,
                            size: isAside ? 26 : 28,
                            color: isAside ? Color(.systemBackground) : .monoTextPrimary,
                            lineWidth: 2.0
                        )
                        .offset(x: isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))

            Spacer()

            Button(action: onSeekForward) {
                MonoIcon(icon: .forward15, size: isAside ? 22 : 24, color: .monoTextPrimary, lineWidth: 1.4)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonoBouncingButtonStyle())

            Spacer()

            Button(action: onNext) {
                MonoIcon(icon: .skipForward, size: isAside ? 18 : 20, color: .monoTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonoBouncingButtonStyle())
        }
        .padding(.horizontal, 28)
    }
}
