#if os(macOS)
import SwiftUI

struct MacNowPlayingView: View {
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showLyrics = true
    @State private var isDraggingProgress = false
    @State private var dragProgress: Double = 0

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                if let song = player.currentSong {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            coverSection(song: song, size: geo.size)
                                .frame(width: showLyrics ? geo.size.width * 0.48 : geo.size.width)
                                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showLyrics)

                            if showLyrics {
                                lyricsSection
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                    progressSection
                        .padding(.horizontal, 40)
                        .padding(.top, 12)

                    controlsSection
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                } else {
                    Spacer()
                    Text("No song playing")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            if let url = player.currentSong?.coverUrl {
                CachedAsyncImage(url: url) {
                    Color(nsColor: .windowBackgroundColor)
                }
                .aspectRatio(contentMode: .fill)
                .blur(radius: 80)
                .scaleEffect(1.3)
                .opacity(0.4)
                .ignoresSafeArea()
            }

            Rectangle()
                .fill(
                    colorScheme == .dark
                    ? Color.black.opacity(0.65)
                    : Color.white.opacity(0.65)
                )
                .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(0.3)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Group {
                    if PetWhiteStyle.isActive {
                        PetWhiteChevronIcon(direction: .down, size: 13, fallbackColor: .secondary)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)

            Spacer()

            if player.currentSong != nil {
                VStack(spacing: 1) {
                    Text("PLAYING FROM")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .tracking(1.5)

                    Text(player.playContext?.name ?? "Queue")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { withAnimation { showLyrics.toggle() } }) {
                Image(systemName: showLyrics ? "text.quote" : "text.quote")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(showLyrics ? .primary : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(showLyrics ? Color.primary.opacity(0.1) : Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Cover

    private func coverSection(song: Song, size: CGSize) -> some View {
        VStack(spacing: 20) {
            Spacer()

            CachedAsyncImage(url: song.coverUrl) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: min(size.width * 0.4, 320))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 12)

            VStack(spacing: 6) {
                Text(song.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                Text(song.artistName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let albumName = song.album?.name, !albumName.isEmpty {
                    Text(albumName)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Lyrics

    private var lyricsSection: some View {
        VStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    if let song = player.currentSong {
                        LyricsView(song: song)
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 60)
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.leading, 8)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let progress = isDraggingProgress
                    ? dragProgress
                    : (player.duration > 0 ? player.currentTime / player.duration : 0)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 4)

                    Circle()
                        .fill(Color.primary)
                        .frame(width: isDraggingProgress ? 14 : 0, height: isDraggingProgress ? 14 : 0)
                        .offset(x: geo.size.width * CGFloat(max(0, min(1, progress))) - 7)
                        .animation(.spring(response: 0.2), value: isDraggingProgress)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingProgress = true
                            dragProgress = max(0, min(1, Double(value.location.x / geo.size.width)))
                        }
                        .onEnded { value in
                            let frac = max(0, min(1, Double(value.location.x / geo.size.width)))
                            player.seek(to: frac * player.duration)
                            isDraggingProgress = false
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(formatTime(isDraggingProgress ? dragProgress * player.duration : player.currentTime))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("-" + formatTime(max(0, player.duration - player.currentTime)))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 32) {
            nowPlayingButton(icon: "shuffle", isActive: player.mode == .shuffle) {
                player.switchMode()
            }

            nowPlayingButton(icon: "backward.fill", size: 18) {
                player.previous()
            }

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 52, height: 52)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)

            nowPlayingButton(icon: "forward.fill", size: 18) {
                player.next()
            }

            nowPlayingButton(icon: "repeat", isActive: player.mode == .loopSingle) {
                player.switchMode()
            }
        }
    }

    private func nowPlayingButton(icon: String, size: CGFloat = 14, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let total = Int(max(0, seconds))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
#endif
