import SwiftUI
import FFmpegSwiftSDK

extension ClassicPlayerLayout {
    func clayPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 12)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    clayListeningPod(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.48, dampingFraction: 0.86), value: showLyrics)

            clayTransportTray
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    func clayListeningPod(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.isPad ? 286 : 224, max(174, geometry.size.width - 142))

        return VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(Color.clear)
                    .background(ClaySurfaceBackground(cornerRadius: 42, tint: ClayStyle.sky.opacity(0.12), elevated: true))
                    .frame(width: artSize + 54, height: artSize + 62)
                    .rotationEffect(.degrees(-1.5))

                artworkTile(size: artSize)
                    .frame(width: artSize, height: artSize)
                    .rotationEffect(.degrees(1.2))
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                            showLyrics.toggle()
                        }
                    }

                VStack {
                    HStack {
                        qualityButton
                        Spacer()
                        if let song = player.currentSong {
                            LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 23, activeColor: ClayStyle.berry, inactiveColor: ClayStyle.inkSoft)
                                .frame(width: 42, height: 42)
                                .background(ClaySurfaceBackground(cornerRadius: 17, tint: ClayStyle.cream, elevated: true, compact: true))
                        }
                    }
                    Spacer()
                }
                .padding(18)
                .frame(width: artSize + 54, height: artSize + 62)
            }

            clayTrackCapsule
                .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 24)
        }
        .padding(.horizontal, DeviceLayout.isPad ? DeviceLayout.playerHorizontalPadding : 18)
    }

    var clayTrackCapsule: some View {
        HStack(alignment: .center, spacing: 14) {
            ClayIconBubble(icon: player.isPlaying ? .pause : .play, tint: ClayStyle.accent, size: 46)

            VStack(alignment: .leading, spacing: 6) {
                Text(player.currentSong?.name ?? "Unknown Song")
                    .monoPlayerDisplayFont(
                        size: 23,
                        weight: .bold,
                        fallback: ClayStyle.titleFont(23, weight: .bold)
                    )
                    .foregroundStyle(ClayStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(ClayStyle.bodyFont(14, weight: .medium))
                        .foregroundStyle(ClayStyle.inkSoft)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            MonoIcon(icon: .karaoke, size: 17, color: ClayStyle.inkMuted, lineWidth: 1.55)
                .frame(width: 36, height: 36)
                .background(ClaySurfaceBackground(cornerRadius: 15, tint: ClayStyle.creamPressed, elevated: false, pressed: true, compact: true))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(ClaySurfaceBackground(cornerRadius: 24, tint: ClayStyle.cream.opacity(0.96), elevated: true))
    }

    var clayTransportTray: some View {
        VStack(spacing: 15) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection
                .padding(.top, 2)

            HStack(spacing: 8) {
                Circle().fill(ClayStyle.butter).frame(width: 8, height: 8)
                Circle().fill(ClayStyle.mint).frame(width: 8, height: 8)
                Capsule().fill(ClayStyle.berry.opacity(0.8)).frame(width: 20, height: 8)
            }

            controlsView
        }
        .padding(.horizontal, 8)
        .padding(.top, 15)
        .padding(.bottom, 17)
        .background(ClaySurfaceBackground(cornerRadius: 28, tint: ClayStyle.cream.opacity(0.96), elevated: true))
    }

}
