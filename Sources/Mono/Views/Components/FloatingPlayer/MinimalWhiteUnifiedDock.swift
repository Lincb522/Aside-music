import SwiftUI

struct MinimalWhiteUnifiedDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @State private var showPlaylist = false
    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 8) {
            if let song = player.currentSong {
                nowPlayingStrip(song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
            }

            tabRail
        }
        .padding(8)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
        )
        .animation(.easeOut(duration: 0.18), value: player.currentSong != nil)
        .animation(MonoAnimation.tabSwitch, value: currentTab)
        .themeRenderInteractiveLayer()
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
    }

    private func nowPlayingStrip(_ song: Song) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 11) {
                CachedAsyncImage(url: song.coverUrl, width: 42, height: 42) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: song.name,
                        font: MinimalWhiteStyle.bodyFont(14, weight: .semibold),
                        color: MinimalWhiteStyle.ink,
                        speed: 24
                    )
                    .frame(height: 17)

                    MarqueeText(
                        text: player.lyricLineText ?? song.artistName,
                        font: MinimalWhiteStyle.labelFont(11, weight: .regular),
                        color: MinimalWhiteStyle.inkMuted,
                        speed: 22
                    )
                    .frame(height: 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .swipeSkipTextMotion()

                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(MinimalWhiteStyle.ink)
                            .frame(width: 34, height: 34)

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: MinimalWhiteStyle.onAccent))
                                .scaleEffect(0.58)
                        } else {
                            MonoIcon(
                                icon: player.isPlaying ? .pause : .play,
                                size: 14,
                                color: MinimalWhiteStyle.onAccent,
                                lineWidth: 1.8
                            )
                        }
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

                Button(action: { showPlaylist.toggle() }) {
                    MonoIcon(icon: .list, size: 15, color: MinimalWhiteStyle.inkSoft, lineWidth: 1.7)
                        .frame(width: 34, height: 34)
                        .background(MinimalWhiteCircleBackground())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
            }
            .contentShape(Rectangle())
            .onTapWithHaptic { openPlayer() }

            ProgressBarView(height: 2, minFillWidth: 5)
                .frame(height: 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: 18,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        )
    }

    private var tabRail: some View {
        HStack(spacing: 5) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonoAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    HStack(spacing: 6) {
                        MonoIcon(
                            icon: selected ? tab.icon : tab.monoIcon,
                            size: selected ? 17 : 16,
                            color: selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted,
                            lineWidth: 1.7
                        )

                        if selected {
                            Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                                .font(MinimalWhiteStyle.labelFont(11, weight: .semibold))
                                .foregroundStyle(MinimalWhiteStyle.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                    .frame(maxWidth: selected ? 118 : 52, minHeight: 42)
                    .background {
                        if selected {
                            Capsule(style: .continuous)
                                .fill(MinimalWhiteStyle.selectedFill)
                                .overlay(Capsule(style: .continuous).stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth))
                                .matchedGeometryEffect(id: "minimalWhiteUnifiedTab", in: tabNamespace)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(3)
        .background(Capsule(style: .continuous).fill(MinimalWhiteStyle.controlGlassFill))
        .overlay(Capsule(style: .continuous).stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth))
    }

    private func openPlayer() {
        withAnimation(MonoAnimation.playerTransition) {
            switch player.playSource {
            case .fm:
                NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
            case let .podcast(radioId):
                NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: radioId)
            case .normal:
                NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
            }
        }
    }
}
