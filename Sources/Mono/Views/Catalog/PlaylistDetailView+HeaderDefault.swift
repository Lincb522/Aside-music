import SwiftUI

extension PlaylistDetailView {
    // MARK: - Components

    @ViewBuilder
    var playlistHeaderContent: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhitePlaylistHeaderContent
        } else if let bannerCoverURL {
            bannerPlaylistHeaderContent(bannerCoverURL)
        } else if PetWhiteStyle.isActive {
            petWhitePlaylistHeaderContent
        } else if MangaStyle.isActive {
            mangaPlaylistHeaderContent
        } else if NeumorphicStyle.isActive {
            neumorphicPlaylistHeaderContent
        } else if SignalStyle.isActive {
            signalPlaylistHeaderContent
        } else if MujiStyle.isActive {
            mujiPlaylistHeaderContent
        } else if CapsuleStyle.isActive {
            capsulePlaylistHeaderContent
        } else if BentoStyle.isActive {
            bentoPlaylistHeaderContent
        } else if SequoiaStyle.isActive {
            sequoiaPlaylistHeaderContent
        } else {
            AsideDetailHeroHeader(
                coverUrl: playlist.coverUrl?.sized(800),
                title: viewModel.playlistDetail?.name ?? playlist.name,
                metaItems: asideHeroMetaItems,
                descriptionText: viewModel.playlistDetail?.description ?? playlist.description,
                onDescriptionTap: { showPlaylistDesc = true },
                scrollOffset: scrollOffset,
                playAllDisabled: viewModel.songs.isEmpty,
                onPlayAll: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllRemainingToQueue()
                    }
                }
            ) {
                // 收藏歌单按钮
                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.usesLocalCollection && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: {
                            if playlist.usesLocalCollection {
                                guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
                                let name = viewModel.playlistDetail?.name ?? playlist.name
                                Task {
                                    let allSongs = await viewModel.loadAllRemainingAsync()
                                    LocalPlaylistManager.shared.importPlaylist(name: name, songs: allSongs)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isCollectedLocally = true
                                    }
                                }
                            } else {
                                showCollectOptions = true
                            }
                        }
                    )
                    .disabled((playlist.usesLocalCollection && (isCollectedLocally || viewModel.songs.isEmpty)))
                    .confirmationDialog(String(localized: "playlist_collect"), isPresented: $showCollectOptions, titleVisibility: .visible) {
                        Button(String(localized: "playlist_collect_local")) {
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
                        .disabled(isCollectedLocally || viewModel.songs.isEmpty)

                        Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "lib_unsubscribe") : String(localized: "playlist_subscribe_to_ncm")) {
                            subManager.togglePlaylistSubscription(id: playlist.id)
                        }

                        Button(String(localized: "cancel"), role: .cancel) {}
                    }
                }
            }
            .padding(.bottom, DeviceLayout.isPad ? 20 : 12)
            .iPadContentWidth(900)
        }
    }

    /// Hero 头部元信息：创建者 + 曲目数 + 播放量
    var asideHeroMetaItems: [String] {
        var items: [String] = []
        if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
            items.append(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
        }
        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
            items.append("\(count) \(String(localized: "songs_unit"))")
        }
        return items
    }

    var minimalWhitePlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonoIcon(icon: .musicNoteList, size: 26, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.55))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 156 : 118, height: DeviceLayout.isPad ? 156 : 118)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        minimalWhiteDetailPill(text: playlist.sourceShortName)
                        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                            minimalWhiteDetailPill(text: "\(count) \(String(localized: "songs_unit"))")
                        }
                    }

                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(MinimalWhiteStyle.titleFont(DeviceLayout.isPad ? 28 : 22, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                        Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                            .font(MinimalWhiteStyle.labelFont(12, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(action: playBannerPlaylist) {
                    HStack(spacing: 7) {
                        MonoIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent, lineWidth: 1.75)
                        Text(LocalizedStringKey("play_now"))
                            .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                    }
                    .foregroundStyle(MinimalWhiteStyle.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
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
        .padding(16)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassFill
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 12)
        .padding(.bottom, 14)
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

    func minimalWhiteDetailPill(text: String) -> some View {
        Text(text)
            .font(MinimalWhiteStyle.labelFont(11, weight: .medium))
            .foregroundStyle(MinimalWhiteStyle.inkMuted)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(MinimalWhiteCapsuleBackground())
    }

    var petWhitePlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    PetWhiteStyle.mint.opacity(0.30)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 168 : 124, height: DeviceLayout.isPad ? 168 : 124)
                .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.cardRadius, style: .continuous))
                .petWhiteClayShadow()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(playlist.sourceShortName)
                            .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(PetWhiteStyle.dogEar)

                        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                            Text("· \(count) \(String(localized: "songs_unit"))")
                                .font(PetWhiteStyle.labelFont(11))
                                .foregroundStyle(PetWhiteStyle.inkMuted)
                        }
                    }
                    .lineLimit(1)

                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(PetWhiteStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .bold))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                        Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                            .font(PetWhiteStyle.labelFont(12))
                            .foregroundStyle(PetWhiteStyle.inkSoft)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllRemainingToQueue()
                    }
                }) {
                    petWhiteHeaderAction(title: String(localized: "play_now"), icon: .play, tint: PetWhiteStyle.dogOrange, filled: true)
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.usesLocalCollection && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: {
                            if playlist.usesLocalCollection {
                                guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
                                let name = viewModel.playlistDetail?.name ?? playlist.name
                                Task {
                                    let allSongs = await viewModel.loadAllRemainingAsync()
                                    LocalPlaylistManager.shared.importPlaylist(name: name, songs: allSongs)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isCollectedLocally = true
                                    }
                                }
                            } else {
                                showCollectOptions = true
                            }
                        }
                    )
                    .disabled((playlist.usesLocalCollection && (isCollectedLocally || viewModel.songs.isEmpty)))
                    .confirmationDialog(String(localized: "playlist_collect"), isPresented: $showCollectOptions, titleVisibility: .visible) {
                        Button(String(localized: "playlist_collect_local")) {
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
                        .disabled(isCollectedLocally || viewModel.songs.isEmpty)

                        Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "lib_unsubscribe") : String(localized: "playlist_subscribe_to_ncm")) {
                            subManager.togglePlaylistSubscription(id: playlist.id)
                        }

                        Button(String(localized: "cancel"), role: .cancel) {}
                    }
                }
            }
        }
        .padding(16)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        .padding(.horizontal, petWhiteDetailHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
        .padding(.bottom, 14)
        .iPadContentWidth(1280)
    }

    func petWhiteHeaderAction(title: String, icon: MonoIcon.IconType, tint: Color, filled: Bool) -> some View {
        HStack(spacing: 7) {
            PetWhitePackIcon(icon: icon, size: 14, visualScale: 1.05, fallbackColor: filled ? PetWhiteStyle.onAccent : PetWhiteStyle.ink)
            Text(title)
                .font(PetWhiteStyle.labelFont(12, weight: .black))
        }
        .foregroundStyle(filled ? PetWhiteStyle.onAccent : PetWhiteStyle.ink)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(filled ? tint : PetWhiteStyle.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: PetWhiteStyle.fineStrokeWidth))
    }

    var sequoiaPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 15) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    sequoiaPlaylistCoverPlaceholder
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 168 : 126, height: DeviceLayout.isPad ? 168 : 126)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.56), lineWidth: 0.7)
                )
                .background(SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        SequoiaPill(text: "PLAYLIST", icon: .musicNoteList, tint: SequoiaStyle.accent, selected: true, compact: true)
                        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                            SequoiaPill(text: "\(count) \(String(localized: "songs_unit"))", tint: SequoiaStyle.aqua, compact: true)
                        }
                    }

                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(SequoiaStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold))
                        .foregroundStyle(SequoiaStyle.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                        Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                            .font(SequoiaStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(SequoiaStyle.inkSoft)
                            .lineLimit(1)
                    }

                    HStack(spacing: 7) {
                        if let playCount = playlist.playCount, playCount > 0 {
                            SequoiaPill(text: formatCount(playCount), tint: SequoiaStyle.green, compact: true)
                        }
                        SequoiaPill(
                            text: playlist.sourceShortName,
                            tint: (playlist.source ?? .netease).themedBadgeColor,
                            compact: true
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllRemainingToQueue()
                    }
                }) {
                    HStack(spacing: 7) {
                        MonoIcon(icon: .play, size: 13, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                        Text(LocalizedStringKey("play_now"))
                            .font(SequoiaStyle.labelFont(12, weight: .semibold))
                    }
                    .foregroundStyle(SequoiaStyle.onAccent)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(SequoiaStyle.accentGradient, in: Capsule())
                    .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
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
        .padding(16)
        .background(SequoiaGlassBand(tint: (playlist.source ?? .netease).themedBadgeColor, cornerRadius: 26))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
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

    var sequoiaPlaylistCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(SequoiaStyle.materialList)
            .overlay(MonoIcon(icon: .musicNoteList, size: 30, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
    }

}
