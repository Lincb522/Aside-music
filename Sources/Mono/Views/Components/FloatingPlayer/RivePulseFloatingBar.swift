import class RiveRuntime.RiveViewModel
import SwiftUI

/// 可见性优先的 Rive 试验入口：播放状态由 `.riv` 状态机表达，
/// 歌曲信息、真实进度与四个主导航仍由原生 SwiftUI 保持可访问性和响应速度。
@MainActor
struct RivePulseFloatingBar: View {
    @Binding var currentTab: Tab

    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var playbackTime = PlaybackTimePublisher.shared
    @StateObject private var colors = CoverColorExtractor(minimumColorCount: 4)
    @StateObject private var riveControl = RivePulseControlModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var showsQueue = false
    @Namespace private var selection

    private var artworkURL: String? {
        player.currentSong?.coverUrl?.sized(240).absoluteString
    }

    private var progress: Double {
        guard playbackTime.duration.isFinite,
              playbackTime.duration > 0,
              playbackTime.currentTime.isFinite else { return 0 }
        return min(max(playbackTime.currentTime / playbackTime.duration, 0), 1)
    }

    private var accent: Color {
        colors.resolvedURL == artworkURL ? colors.dominantColor : .monoAccent
    }

    private var secondaryAccent: Color {
        colors.resolvedURL == artworkURL ? colors.secondaryColor : .monoAccent.opacity(0.66)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let song = player.currentSong {
                playbackRow(song)

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.48))
                    .frame(height: 0.6)
                    .padding(.horizontal, 13)
            }

            navigationRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(height: player.currentSong == nil ? 62 : 108)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.25 : 0.88),
                            accent.opacity(colorScheme == .dark ? 0.20 : 0.12),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: accent.opacity(colorScheme == .dark ? 0.17 : 0.11), radius: 18, x: 0, y: 8)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: currentTab)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.9), value: player.currentSong?.id)
        .onAppear {
            colors.extract(from: artworkURL)
            riveControl.synchronize(isPlaying: player.isPlaying, reduceMotion: reduceMotion)
        }
        .onChange(of: artworkURL) { _, url in
            colors.extract(from: url)
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            riveControl.synchronize(isPlaying: isPlaying, reduceMotion: reduceMotion)
        }
        .onChange(of: reduceMotion) { _, enabled in
            riveControl.synchronize(isPlaying: player.isPlaying, reduceMotion: enabled)
        }
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private var surface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.monoStructuralBackground)

            LinearGradient(
                colors: [
                    accent.opacity(colorScheme == .dark ? 0.13 : 0.10),
                    Color.clear,
                    secondaryAccent.opacity(colorScheme == .dark ? 0.09 : 0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 132, height: 132)
                .blur(radius: 28)
                .offset(x: 128, y: -28)
                .allowsHitTesting(false)
        }
    }

    private func playbackRow(_ song: Song) -> some View {
        HStack(spacing: 9) {
            CachedAsyncImage(url: song.coverUrl?.sized(180)) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.monoSeparator.opacity(0.28))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 39, height: 39)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 0.6)
            }

            VStack(alignment: .leading, spacing: 1) {
                MarqueeText(
                    text: song.name,
                    font: .system(size: 13.5, weight: .semibold, design: .rounded),
                    color: .monoTextPrimary,
                    speed: 24
                )

                MarqueeText(
                    text: player.lyricLineText ?? song.artistName,
                    font: .system(size: 10.5, weight: .medium, design: .rounded),
                    color: .monoTextSecondary,
                    speed: 22
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapWithHaptic { openPlayer() }
            .swipeToSkip()

            Button {
                HapticManager.shared.light()
                showsQueue = true
            } label: {
                MonoIcon(icon: .list, size: 14, color: .monoTextSecondary, lineWidth: 1.7)
                    .frame(width: 31, height: 31)
                    .background(Color.monoTextPrimary.opacity(0.055), in: Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
            .accessibilityLabel(String(localized: "player_queue"))

            Button {
                player.togglePlayPause()
            } label: {
                rivePlaybackControl
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
            .accessibilityLabel(player.isPlaying ? String(localized: "暂停") : String(localized: "action_play"))
        }
        .frame(height: 44)
        .overlay(alignment: .bottomLeading) {
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.monoSeparator.opacity(0.26))
                    .frame(height: 1.4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent, secondaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * progress, height: 1.4)
                    }
            }
            .frame(height: 2)
            .padding(.leading, 48)
            .padding(.trailing, 3)
        }
    }

    @ViewBuilder
    private var rivePlaybackControl: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.92 : 0.96))

            Circle()
                .stroke(accent.opacity(0.22), lineWidth: 1)

            if player.isLoading {
                ProgressView()
                    .tint(accent)
                    .scaleEffect(0.72)
            } else if let animation = riveControl.animation {
                animation.view()
                    .frame(width: 35, height: 35)
                    .allowsHitTesting(false)
            } else {
                MonoIcon(
                    icon: player.isPlaying ? .pause : .play,
                    size: 15,
                    color: .black,
                    lineWidth: 1.8
                )
            }
        }
        .frame(width: 40, height: 40)
        .shadow(color: accent.opacity(0.18), radius: 8, x: 0, y: 3)
        .contentShape(Circle())
    }

    private var navigationRow: some View {
        HStack(spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let isSelected = currentTab == tab
                Button {
                    guard currentTab != tab else { return }
                    HapticManager.shared.light()
                    currentTab = tab
                } label: {
                    HStack(spacing: 5) {
                        MonoIcon(
                            icon: tab.icon,
                            size: isSelected ? 14 : 13,
                            color: isSelected ? .monoTextPrimary : .monoTextSecondary,
                            lineWidth: isSelected ? 1.9 : 1.5
                        )

                        if isSelected {
                            Text(LocalizedStringKey(tab.titleKey()))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.monoTextPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .frame(maxWidth: isSelected ? 94 : 48)
                    .frame(height: 36)
                    .background {
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [accent.opacity(0.18), secondaryAccent.opacity(0.08)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.56), lineWidth: 0.7)
                                }
                                .matchedGeometryEffect(id: "rive-pulse-tab", in: selection)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: isSelected ? 94 : 48)
                .accessibilityLabel(Text(LocalizedStringKey(tab.titleKey())))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
    }

    private func openPlayer() {
        withAnimation(MonoAnimation.playerTransition) {
            switch player.playSource {
            case .fm:
                NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
            case let .podcast(radioID):
                NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioID)
            case .normal:
                NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
            }
        }
    }
}

@MainActor
private final class RivePulseControlModel: ObservableObject {
    let animation: RiveViewModel?

    init() {
        guard Bundle.main.url(forResource: "play_pause", withExtension: "riv") != nil else {
            animation = nil
            return
        }

        animation = RiveViewModel(
            fileName: "play_pause",
            stateMachineName: "State Machine 1",
            fit: .contain,
            alignment: .center,
            autoPlay: true,
            loadCdn: false
        )
    }

    func synchronize(isPlaying: Bool, reduceMotion: Bool) {
        guard let animation else { return }
        animation.setPreferredFramesPerSecond(preferredFramesPerSecond: reduceMotion ? 30 : 60)
        animation.setInput("Play", value: isPlaying)
    }
}
