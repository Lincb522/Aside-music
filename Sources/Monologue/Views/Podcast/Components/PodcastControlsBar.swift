import SwiftUI

struct PodcastControlsBar: View {
    let isPlaying: Bool
    let isLoading: Bool

    var onPrevious: () -> Void
    var onSeekBack: () -> Void
    var onPlayPause: () -> Void
    var onSeekForward: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPrevious) {
                MonologueIcon(icon: .skipBack, size: 20, color: .monologueTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: onSeekBack) {
                VStack(spacing: 1) {
                    MonologueIcon(icon: .rewind15, size: 24, color: .monologueTextPrimary, lineWidth: 1.4)
                }
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(Color.monologueGlassTint)
                        .frame(width: 72, height: 72)
                        .monologueGlassCircle()
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .monologueTextPrimary))
                            .scaleEffect(1.2)
                    } else {
                        MonologueIcon(
                            icon: isPlaying ? .pause : .play,
                            size: 28,
                            color: .monologueTextPrimary,
                            lineWidth: 2.0
                        )
                        .offset(x: isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))

            Spacer()

            Button(action: onSeekForward) {
                VStack(spacing: 1) {
                    MonologueIcon(icon: .forward15, size: 24, color: .monologueTextPrimary, lineWidth: 1.4)
                }
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())

            Spacer()

            Button(action: onNext) {
                MonologueIcon(icon: .skipForward, size: 20, color: .monologueTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, 28)
    }
}
