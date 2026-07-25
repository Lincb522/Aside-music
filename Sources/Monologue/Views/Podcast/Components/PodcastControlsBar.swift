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
                MonologueIcon(icon: .skipBack, size: isAside ? 18 : 20, color: .monologueTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: onSeekBack) {
                MonologueIcon(icon: .rewind15, size: isAside ? 22 : 24, color: .monologueTextPrimary, lineWidth: 1.4)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: onPlayPause) {
                ZStack {
                    if isAside {
                        Circle()
                            .fill(Color.monologueTextPrimary)
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.monologueTextPrimary.opacity(0.22), radius: 14, x: 0, y: 7)
                    } else {
                        Circle()
                            .fill(Color.monologueGlassTint)
                            .frame(width: 72, height: 72)
                            .monologueGlassCircle()
                            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                    }

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isAside ? Color(.systemBackground) : .monologueTextPrimary))
                            .scaleEffect(1.2)
                    } else {
                        MonologueIcon(
                            icon: isPlaying ? .pause : .play,
                            size: isAside ? 26 : 28,
                            color: isAside ? Color(.systemBackground) : .monologueTextPrimary,
                            lineWidth: 2.0
                        )
                        .offset(x: isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))

            Spacer()

            Button(action: onSeekForward) {
                MonologueIcon(icon: .forward15, size: isAside ? 22 : 24, color: .monologueTextPrimary, lineWidth: 1.4)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: onNext) {
                MonologueIcon(icon: .skipForward, size: isAside ? 18 : 20, color: .monologueTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, 28)
    }
}
