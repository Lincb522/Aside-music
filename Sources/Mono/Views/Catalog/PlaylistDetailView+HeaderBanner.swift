import SwiftUI

extension PlaylistDetailView {
    @ViewBuilder
    var capsulePlaylistHeaderContent: some View {
        let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount
        let playCount = playlist.playCount ?? 0
        let source = playlist.sourceShortName
        let tint = (playlist.source ?? .netease).themedBadgeColor
        let chips = [
            count.map { "\($0) \(String(localized: "songs_unit"))" },
            playCount > 0 ? formatCount(playCount) : nil,
            source
        ].compactMap { $0 }

        CapsuleDetailHeader(
            eyebrow: "PLAYLIST",
            title: viewModel.playlistDetail?.name ?? playlist.name,
            subtitle: (viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname).map {
                String(format: NSLocalizedString("created_by_format", comment: ""), $0)
            } ?? "",
            coverURL: playlist.coverUrl?.sized(500),
            fallbackIcon: .musicNoteList,
            tint: tint,
            chips: chips
        ) {
            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllRemainingToQueue()
                    }
                }) {
                    CapsuleDetailActionPill(
                        title: String(localized: "play_now"),
                        icon: .play,
                        tint: tint
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.usesLocalCollection && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: handleBannerPlaylistCollectTap
                    )
                    .disabled(playlist.usesLocalCollection && (isCollectedLocally || viewModel.songs.isEmpty))
                }
            }
        }
        .confirmationDialog(String(localized: "playlist_collect"), isPresented: $showCollectOptions, titleVisibility: .visible) {
            Button(String(localized: "playlist_collect_local")) {
                collectBannerPlaylistLocally()
            }
            .disabled(isCollectedLocally || viewModel.songs.isEmpty)

            Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "lib_unsubscribe") : String(localized: "playlist_subscribe_to_ncm")) {
                subManager.togglePlaylistSubscription(id: playlist.id)
            }

            Button(String(localized: "cancel"), role: .cancel) {}
        }
    }

    func bannerPlaylistHeaderContent(_ imageURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            bannerPlaylistArtwork(imageURL)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    bannerHeaderBadge("BANNER", emphasis: true)
                    if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                        bannerHeaderBadge("\(count) \(String(localized: "songs_unit"))")
                    }
                    if let playCount = playlist.playCount, playCount > 0 {
                        bannerHeaderBadge(formatCount(playCount))
                    }
                }

                Text(viewModel.playlistDetail?.name ?? playlist.name)
                    .font(bannerHeaderTitleFont)
                    .foregroundStyle(bannerHeaderPrimaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                    Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                        .font(bannerHeaderMetaFont)
                        .foregroundStyle(bannerHeaderSecondaryText)
                        .lineLimit(1)
                }

                if let description = viewModel.playlistDetail?.description ?? playlist.description,
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(description)
                        .font(bannerHeaderDescriptionFont)
                        .foregroundStyle(bannerHeaderSecondaryText.opacity(0.88))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                bannerHeaderPlayButton

                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.usesLocalCollection && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: handleBannerPlaylistCollectTap
                    )
                    .disabled(playlist.usesLocalCollection && (isCollectedLocally || viewModel.songs.isEmpty))
                }
            }
        }
        .padding(bannerHeaderInnerPadding)
        .background {
            bannerHeaderSurface
        }
        .overlay {
            bannerHeaderBorder
        }
        .padding(.horizontal, bannerHeaderHorizontalPadding)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
        .confirmationDialog(String(localized: "playlist_collect"), isPresented: $showCollectOptions, titleVisibility: .visible) {
            Button(String(localized: "playlist_collect_local")) {
                collectBannerPlaylistLocally()
            }
            .disabled(isCollectedLocally || viewModel.songs.isEmpty)

            Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "lib_unsubscribe") : String(localized: "playlist_subscribe_to_ncm")) {
                subManager.togglePlaylistSubscription(id: playlist.id)
            }

            Button(String(localized: "cancel"), role: .cancel) {}
        }
    }

    func bannerPlaylistArtwork(_ imageURL: URL) -> some View {
        GeometryReader { proxy in
            CachedAsyncImage(
                url: imageURL.sized(1200),
                placeholder: {
                    bannerArtworkPlaceholder
                },
                contentMode: .fit,
                width: proxy.size.width,
                height: bannerArtworkHeight
            )
            .frame(width: proxy.size.width, height: bannerArtworkHeight)
            .background {
                bannerArtworkFill
            }
            .clipShape(RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous))
            .overlay {
                bannerArtworkBorder
            }
            .background {
                if MangaStyle.isActive {
                    RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 3, y: 3)
                }
            }
        }
        .frame(height: bannerArtworkHeight)
    }

    @ViewBuilder
    func bannerHeaderBadge(_ text: String, emphasis: Bool = false) -> some View {
        if MangaStyle.isActive {
            MangaLabel(
                text: text,
                tint: emphasis ? MangaStyle.labelYellow : MangaStyle.paperCool,
                small: true,
                foreground: MangaStyle.ink
            )
        } else if NeumorphicStyle.isActive {
            NeumorphicPill(
                text: text,
                tint: emphasis ? NeumorphicStyle.accent : NeumorphicStyle.sage,
                selected: emphasis,
                compact: true
            )
        } else if SignalStyle.isActive {
            SignalPill(
                text: text,
                tint: emphasis ? SignalStyle.accent : SignalStyle.olive,
                selected: emphasis,
                compact: true
            )
        } else if SequoiaStyle.isActive {
            SequoiaPill(
                text: text,
                tint: emphasis ? SequoiaStyle.accent : SequoiaStyle.aqua,
                selected: emphasis,
                compact: true
            )
        } else if MujiStyle.isActive {
            MujiPill(text: text, tint: emphasis ? MujiStyle.clay : MujiStyle.tea)
        } else {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(emphasis ? Color.monoIconForeground : Color.monoTextSecondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(emphasis ? Color.monoIconBackground : Color.monoTextPrimary.opacity(0.07), in: Capsule())
        }
    }

    @ViewBuilder
    var bannerHeaderPlayButton: some View {
        Button(action: playBannerPlaylist) {
            if MangaStyle.isActive {
                HStack(spacing: 7) {
                    MonoIcon(icon: .play, size: 12, color: MangaStyle.onStrokeInk, lineWidth: 2)
                    Text(LocalizedStringKey("play_now"))
                        .font(MangaStyle.labelFont(12, weight: .black))
                        .tracking(0.6)
                }
                .foregroundColor(MangaStyle.onStrokeInk)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(MangaStyle.strokeInk))
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(MangaStyle.accentPink)
                        .offset(x: 2.5, y: 2.5)
                )
            } else if NeumorphicStyle.isActive {
                NeumorphicPlayPill(title: String(localized: "play_now"), tint: NeumorphicStyle.accent)
            } else if SignalStyle.isActive {
                SignalPlayPill(title: String(localized: "play_now"))
            } else if SequoiaStyle.isActive {
                HStack(spacing: 7) {
                    MonoIcon(icon: .play, size: 12, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                    Text(LocalizedStringKey("play_now"))
                        .font(SequoiaStyle.labelFont(12, weight: .semibold))
                }
                .foregroundStyle(SequoiaStyle.onAccent)
                .padding(.horizontal, 15)
                .frame(height: 38)
                .background(SequoiaStyle.accentGradient, in: Capsule())
                .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
            } else if MujiStyle.isActive {
                MujiActionPill(
                    title: String(localized: "play_now"),
                    icon: .play,
                    selected: true,
                    tint: MujiStyle.clay
                )
            } else {
                HStack(spacing: 6) {
                    MonoIcon(icon: .play, size: 12, color: .monoIconForeground)
                    Text(LocalizedStringKey("play_now"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.monoIconForeground)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.monoIconBackground, in: Capsule())
                .monoGlassCapsule()
            }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
        .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
        .disabled(viewModel.songs.isEmpty)
    }

    func playBannerPlaylist() {
        guard let first = viewModel.songs.first else { return }
        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
        viewModel.loadAllRemainingToQueue()
    }

    func handleBannerPlaylistCollectTap() {
                            if playlist.usesLocalCollection {
            guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
            collectBannerPlaylistLocally()
        } else {
            showCollectOptions = true
        }
    }

    func collectBannerPlaylistLocally() {
        guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
        let name = viewModel.playlistDetail?.name ?? playlist.name
        Task {
            let allSongs = await viewModel.loadAllRemainingAsync()
            LocalPlaylistManager.shared.importPlaylist(name: name, songs: allSongs)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCollectedLocally = true
            }
        }
    }

    var bannerArtworkHeight: CGFloat {
        if SignalStyle.isActive { return DeviceLayout.isPad ? 230 : 160 }
        return DeviceLayout.isPad ? 220 : 148
    }

    var bannerArtworkRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if MujiStyle.isActive { return 12 }
        if NeumorphicStyle.isActive { return 22 }
        if SignalStyle.isActive { return 24 }
        if SequoiaStyle.isActive { return 22 }
        return 20
    }

    var bannerHeaderRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius + 4 }
        if MujiStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return 28 }
        if SignalStyle.isActive { return 30 }
        if SequoiaStyle.isActive { return 26 }
        return 24
    }

    var bannerHeaderInnerPadding: CGFloat {
        if MangaStyle.isActive { return 16 }
        if MujiStyle.isActive { return 18 }
        if NeumorphicStyle.isActive { return 17 }
        if SignalStyle.isActive { return 16 }
        if SequoiaStyle.isActive { return 16 }
        return 16
    }

    var bannerHeaderHorizontalPadding: CGFloat {
        if SignalStyle.isActive { return DeviceLayout.isPad ? 36 : 14 }
        if SequoiaStyle.isActive { return DeviceLayout.isPad ? 40 : 20 }
        return DeviceLayout.isPad ? 40 : 20
    }

    var bannerHeaderTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(DeviceLayout.isPad ? 27 : 23, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(DeviceLayout.isPad ? 32 : 28, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.titleFont(DeviceLayout.isPad ? 30 : 24, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold) }
        return .system(size: DeviceLayout.isPad ? 28 : 22, weight: .bold, design: .rounded)
    }

    var bannerHeaderMetaFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .medium) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    var bannerHeaderDescriptionFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .regular) }
        if SignalStyle.isActive { return SignalStyle.bodyFont(12, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 13, weight: .regular, design: .rounded)
    }

    var bannerHeaderPrimaryText: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    var bannerHeaderSecondaryText: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }

    @ViewBuilder
    var bannerHeaderSurface: some View {
        if MangaStyle.isActive {
            MangaCardBackground(cornerRadius: bannerHeaderRadius, elevated: true, tint: MangaStyle.bubbleWhite)
        } else if MujiStyle.isActive {
            // Muji：清新水洗底
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.8))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: bannerHeaderRadius, elevated: true)
        } else if SignalStyle.isActive {
            SignalSurfaceBackground(cornerRadius: bannerHeaderRadius, elevated: true, fill: SignalStyle.paper)
        } else if SequoiaStyle.isActive {
            SequoiaGlassBand(tint: SequoiaStyle.accent, cornerRadius: bannerHeaderRadius)
        } else {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .fill(Color.monoGlassTint)
        }
    }

    @ViewBuilder
    var bannerHeaderBorder: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 1.8)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
        } else if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.9)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(SequoiaStyle.separator.opacity(0.82), lineWidth: 0.6)
        }
    }

    @ViewBuilder
    var bannerArtworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
            .fill(bannerArtworkFillColor)
            .overlay(MonoIcon(icon: .musicNoteList, size: 28, color: bannerHeaderSecondaryText.opacity(0.5)))
    }

    @ViewBuilder
    var bannerArtworkFill: some View {
        RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
            .fill(bannerArtworkFillColor)
    }

    var bannerArtworkFillColor: Color {
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SignalStyle.isActive { return SignalStyle.controlPressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
        return Color.monoSeparator.opacity(0.35)
    }

    @ViewBuilder
    var bannerArtworkBorder: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 2)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.8)
        } else if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.8)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(SequoiaStyle.luminousSeparator.opacity(0.58), lineWidth: 0.7)
        } else {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
        }
    }

}
