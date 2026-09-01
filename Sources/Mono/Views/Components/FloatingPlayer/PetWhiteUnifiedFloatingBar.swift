import SwiftUI

struct PetWhiteUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared

    var body: some View {
        VStack(spacing: 7) {
            if let song = player.currentSong {
                PetWhiteUnifiedNowPlayingTicket(song: song)
                    .swipeToSkip()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom))
                    ))
            }

            PetWhiteUnifiedTabPawDock(currentTab: $currentTab)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius + 4, style: .continuous),
                tint: PetWhiteStyle.paper,
                accent: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                lineWidth: 1
            )
        }
        .animation(MonoAnimation.floatingBar, value: player.currentSong != nil)
        .themeRenderInteractiveLayer()
    }
}

struct PetWhiteUnifiedNowPlayingTicket: View {
    let song: Song
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @State private var showPlaylist = false

    private var subtitleText: String {
        player.lyricLineText ?? song.artistName
    }

    var body: some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: song.coverUrl, width: 42, height: 42) {
                PetWhiteMascotMark(kind: .pair, size: 24)
                    .frame(width: 42, height: 42)
                    .background(PetWhiteStyle.butter)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(PetWhiteStyle.stroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                MarqueeText(
                    text: song.name,
                    font: PetWhiteStyle.bodyFont(13, weight: .semibold),
                    color: PetWhiteStyle.ink,
                    speed: 25
                )
                .frame(height: 16)

                MarqueeText(
                    text: subtitleText,
                    font: PetWhiteStyle.bodyFont(11),
                    color: PetWhiteStyle.inkSoft,
                    speed: 22
                )
                .frame(height: 13)
            }
            .swipeSkipTextMotion()

            Spacer(minLength: 6)

            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: PetWhiteStyle.onAccent))
                            .scaleEffect(0.58)
                    } else {
                        PetWhitePackIcon(icon: player.isPlaying ? .pause : .play, size: 22, visualScale: 1.08)
                    }
                }
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

            Button(action: { showPlaylist.toggle() }) {
                PetWhitePackIcon(icon: .list, size: 22, visualScale: 1.04, fallbackColor: PetWhiteStyle.ink)
                    .frame(width: 32, height: 32)
                    .background(PetWhiteStyle.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(PetWhiteStyle.separator, lineWidth: 1)
                    )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

            if !player.isPlaying {
                Button {
                    withAnimation(MonoAnimation.floatingBar) {
                        player.dismissMiniPlayerPreservingQueue()
                    }
                } label: {
                    PetWhitePackIcon(icon: .close, size: 18, visualScale: 1.04, fallbackColor: PetWhiteStyle.inkMuted)
                        .frame(width: 30, height: 30)
                        .background(PetWhiteStyle.surfacePressed)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(PetWhiteStyle.separator, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background {
            PetWhiteFrostedFloatingSurface(
                shape: UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 22,
                        bottomLeading: 22,
                        bottomTrailing: 16,
                        topTrailing: 28
                    ),
                    style: .continuous
                ),
                tint: PetWhiteStyle.surfaceRaised,
                accent: player.isPlaying ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint,
                lineWidth: 1.4
            )
            .overlay(alignment: .bottomLeading) {
                ProgressBarView(height: 4, minFillWidth: 7)
                    .frame(height: 4)
                    .padding(.leading, 58)
                    .padding(.trailing, 82)
                    .offset(y: -3)
            }
        }
        .contentShape(Rectangle())
        .onTapWithHaptic { openPlayer() }
        .monoSheet(isPresented: $showPlaylist, preset: .standard) {
            if player.isPlayingPodcast {
                PodcastPlaylistPopupView()
            } else {
                PlaylistPopupView()
            }
        }
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

struct PetWhiteUnifiedTabPawDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    HapticManager.shared.light()
                    withAnimation(MonoAnimation.tabSwitch) {
                        currentTab = tab
                    }
                } label: {
                    let selected = currentTab == tab
                    VStack(spacing: 3) {
                        PetWhitePackIcon(
                            icon: selected ? tab.icon : tab.monoIcon,
                            size: selected ? 18 : 16,
                            visualScale: 1,
                            fallbackColor: selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted,
                            lineWidth: 1.45,
                            artworkContrastBackground: selected ? tabTint(tab) : nil
                        )

                        Text(NSLocalizedString(tab.titleKey(isLocalMode: !onlineAccess.canUseOnlineFeatures), comment: ""))
                            .font(PetWhiteStyle.labelFont(9, weight: selected ? .black : .bold))
                            .foregroundColor(selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        if selected {
                            PetWhiteClayPuck(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                tint: tabTint(tab),
                                pressedLook: true
                            )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.9))
            }
        }
        .padding(5)
        .background {
            PetWhiteFrostedFloatingSurface(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                tint: PetWhiteStyle.surfaceRaised,
                accent: PetWhiteStyle.mint,
                strokeColor: PetWhiteStyle.separator,
                lineWidth: 1.1,
                elevated: false
            )
        }
    }

    private func tabTint(_ tab: Tab) -> Color {
        switch tab {
        case .home: return PetWhiteStyle.dogOrange
        case .podcast: return PetWhiteStyle.mint
        case .library: return PetWhiteStyle.butter
        case .profile: return PetWhiteStyle.blush.opacity(0.88)
        }
    }
}
