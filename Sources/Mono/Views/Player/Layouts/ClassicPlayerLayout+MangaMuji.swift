import SwiftUI
import FFmpegSwiftSDK

extension ClassicPlayerLayout {
    func classicPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.playerHeaderTopPadding)
                .padding(.bottom, 20)

            ZStack {
                artworkView(size: geometry.size.width - 64)
                    .opacity(showLyrics ? 0 : 1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height > 100 { dismiss() }
                            }
                    )

                if let song = player.currentSong {
                    LyricsView(song: song, onBackgroundTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    })
                    .opacity(showLyrics ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)
                }
            }
            .frame(maxHeight: .infinity)
            .onTapWithHaptic {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                }
            }

            Spacer()

            // 底部区域 — spacing: 32 与原始一致
            VStack(spacing: 32) {
                ZStack(alignment: .leading) {
                    // 用 songInfoView 撑高度，保证切换歌词时不跳动
                    songInfoView.opacity(showLyrics ? 0 : 1)
                    lyricsModeSongInfo.opacity(showLyrics ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.25), value: showLyrics)

                progressSection
                    .padding(.vertical, 8)

                controlsView
            }
            .padding(.horizontal, DeviceLayout.playerHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    func mangaPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.playerHeaderTopPadding)
                .padding(.bottom, 14)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    mangaNowPlayingPanel(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: showLyrics)

            mangaTransportPanel
                .padding(.horizontal, DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 16)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    func mujiPlayerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.top, DeviceLayout.playerHeaderTopPadding)
                .padding(.bottom, 18)

            Group {
                if showLyrics {
                    themedLyricsPanel(geometry: geometry)
                } else {
                    mujiListeningTray(geometry: geometry)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeInOut(duration: 0.28), value: showLyrics)

            mujiTransportPanel
                .padding(.horizontal, DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 20)
                .padding(.bottom, DeviceLayout.playerBottomSafePadding)
        }
    }

    @ViewBuilder
    func themedLyricsPanel(geometry: GeometryProxy) -> some View {
        if let song = player.currentSong {
            LyricsView(song: song, onBackgroundTap: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                }
            })
            .padding(.horizontal, usesMangaStyle ? 18 : 20)
            .padding(.vertical, usesMangaStyle ? 14 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if usesMangaStyle {
                    MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite)
                } else if usesNeumorphicStyle {
                    NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true, tint: NeumorphicStyle.surface)
                } else if usesCapsuleStyle {
                    CapsuleSurfaceBackground(cornerRadius: 28, elevated: true, tint: CapsuleStyle.surface.opacity(0.94))
                } else if usesSequoiaStyle {
                    SequoiaSurfaceBackground(cornerRadius: 26, elevated: true, role: .chrome)
                } else if usesClayStyle {
                    ClaySurfaceBackground(cornerRadius: 30, tint: ClayStyle.cream.opacity(0.96), elevated: true)
                }
            }
            .padding(.horizontal, DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 18)
            .padding(.vertical, 8)
        } else {
            Color.clear
        }
    }

    func mangaNowPlayingPanel(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.usesExpandedLayout ? 220 : 172, max(132, geometry.size.width * 0.42))

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                artworkTile(size: artSize)
                    .frame(width: artSize, height: artSize)
                    .onTapWithHaptic {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showLyrics.toggle()
                        }
                    }

                VStack(alignment: .leading, spacing: 12) {
                    mangaTitleBlock

                    HStack(spacing: 10) {
                        qualityButton

                        if let song = player.currentSong {
                            LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 24, activeColor: MangaStyle.accentPink, inactiveColor: MangaStyle.ink)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                mangaPill(MangaStyle.bubbleBlue)
                mangaPill(MangaStyle.labelYellow)
                mangaPill(MangaStyle.bubblePink)
                Spacer()
                MonoIcon(icon: .karaoke, size: 16, color: MangaStyle.ink, lineWidth: 1.6)
                    .frame(width: 34, height: 34)
                    .background(MangaStyle.bubbleWhite, in: Circle())
                    .overlay(Circle().stroke(MangaStyle.strokeInk, lineWidth: 1.2))
            }
        }
        .padding(18)
        .background(MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.paperWarm))
        .overlay(alignment: .topTrailing) {
            ClassicDecorativeStar()
                .fill(MangaStyle.labelYellow)
                .overlay(ClassicDecorativeStar().stroke(MangaStyle.strokeInk, lineWidth: 1.5))
                .frame(width: 42, height: 42)
                .padding(10)
                .rotationEffect(.degrees(8))
        }
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 18)
    }

    var mangaTitleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(player.currentSong?.name ?? "Unknown Song")
                .monoPlayerDisplayFont(
                    size: 25,
                    weight: .black,
                    fallback: MangaStyle.titleFont(25, weight: .black)
                )
                .foregroundColor(MangaStyle.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.76)

            Button { showArtistDetail = true } label: {
                Text(player.currentSong?.artistName ?? "Unknown Artist")
                    .font(MangaStyle.bodyFont(15, weight: .bold))
                    .foregroundColor(MangaStyle.inkSub)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
        }
    }

    func mangaPill(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 38, height: 12)
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.2))
    }

    var mangaTransportPanel: some View {
        VStack(spacing: 16) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection
                .padding(.top, 2)

            controlsView
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite))
    }

    func mujiListeningTray(geometry: GeometryProxy) -> some View {
        let artSize = min(DeviceLayout.usesExpandedLayout ? 300 : 246, max(190, geometry.size.width - 112))

        return VStack(spacing: 24) {
            artworkTile(size: artSize)
                .frame(width: artSize, height: artSize)
                .onTapWithHaptic {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showLyrics.toggle()
                    }
                }

            mujiTrackLabel
        }
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? DeviceLayout.playerHorizontalPadding : 28)
    }

    var mujiTrackLabel: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    MujiDotMark()

                    Text("NOW PLAYING")
                        .font(MujiStyle.labelFont(9.5, weight: .semibold))
                        .foregroundColor(MujiStyle.clay)
                        .tracking(2)
                }

                Text(player.currentSong?.name ?? "Unknown Song")
                    .monoPlayerDisplayFont(
                        size: 25,
                        weight: .medium,
                        fallback: MujiStyle.titleFont(25, weight: .medium)
                    )
                    .foregroundColor(MujiStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Button { showArtistDetail = true } label: {
                    Text(player.currentSong?.artistName ?? "Unknown Artist")
                        .font(MujiStyle.labelFont(12.5, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundColor(MujiStyle.inkSoft)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 10)

            VStack(spacing: 10) {
                qualityButton

                if let song = player.currentSong {
                    LikeButton(songId: song.id, isQQMusic: song.isQQMusic, song: song, size: 24, activeColor: MujiStyle.clay, inactiveColor: MujiStyle.ink)
                }
            }
        }
        .padding(.top, 18)
    }

    var mujiTransportPanel: some View {
        VStack(spacing: 15) {
            if showLyrics {
                lyricsModeSongInfo
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }

            progressSection

            MujiStitchLine()
                .stroke(
                    MujiStyle.separator.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [0.1, 8])
                )
                .frame(height: 2)
                .padding(.horizontal, 22)

            controlsView
        }
        .padding(.horizontal, 6)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(MujiStyle.surface.opacity(0.92))
                .shadow(color: MujiStyle.ink.opacity(0.06), radius: 16, x: 0, y: 6)
        )
    }

}
