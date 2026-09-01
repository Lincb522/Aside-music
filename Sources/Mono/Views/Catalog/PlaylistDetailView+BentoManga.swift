import SwiftUI

extension PlaylistDetailView {
    // MARK: - Bento header
    var bentoPlaylistHeaderContent: some View {
        VStack(spacing: BentoStyle.blockSpacing) {
            // 大 hero 块：封面 + 标题 + 元信息
            BentoBlock(fill: BentoStyle.surface, radius: BentoStyle.blockRadiusLarge, padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(BentoStyle.buckwheat.opacity(0.5))
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: DeviceLayout.usesExpandedLayout ? 160 : 120, height: DeviceLayout.usesExpandedLayout ? 160 : 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("PLAYLIST")
                                .font(BentoStyle.labelFont(10, weight: .heavy))
                                .foregroundStyle(BentoStyle.tomato)
                                .tracking(1.4)
                            Text(viewModel.playlistDetail?.name ?? playlist.name)
                                .font(BentoStyle.displayFont(20, weight: .heavy))
                                .foregroundStyle(BentoStyle.ink)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                                Text(creator)
                                    .font(BentoStyle.labelFont(11, weight: .regular))
                                    .foregroundStyle(BentoStyle.inkSoft)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                            bentoPill(text: "\(count) 首", tint: BentoStyle.matcha)
                        }
                        if let playCount = playlist.playCount, playCount > 0 {
                            bentoPill(text: formatCount(playCount), tint: BentoStyle.nori)
                        }
                    }
                }
            }

            // 操作按钮区
            HStack(spacing: BentoStyle.blockSpacing) {
                Button {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllRemainingToQueue()
                    }
                } label: {
                    HStack(spacing: 6) {
                        MonoIcon(icon: .play, size: 14, color: BentoStyle.onAccent, lineWidth: 2)
                        Text("立即播放")
                            .font(BentoStyle.bodyFont(13, weight: .heavy))
                    }
                    .foregroundStyle(BentoStyle.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BentoStyle.tomato))
                }
                .buttonStyle(BentoPressStyle())
                .disabled(viewModel.songs.isEmpty)
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)

                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.usesLocalCollection && subManager.isPlaylistSubscribed(playlist.id)
                    let collected = isCollectedLocally || serverSubscribed
                    Button {
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
                    } label: {
                        HStack(spacing: 6) {
                            MonoIcon(icon: collected ? .liked : .like, size: 14, color: collected ? BentoStyle.onAccent : BentoStyle.ink, lineWidth: 2)
                            Text(collected ? "已收藏" : "收藏")
                                .font(BentoStyle.bodyFont(13, weight: .heavy))
                                .foregroundStyle(collected ? BentoStyle.onAccent : BentoStyle.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(collected ? BentoStyle.matcha : BentoStyle.surface))
                    }
                    .buttonStyle(BentoPressStyle())
                    .disabled(playlist.usesLocalCollection && (isCollectedLocally || viewModel.songs.isEmpty))
                }
            }
        }
        .padding(.horizontal, BentoStyle.blockSpacing)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .iPadContentWidth(900)
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

    func bentoPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(BentoStyle.labelFont(11, weight: .heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    var mangaPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    MangaStyle.paperCool
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.usesExpandedLayout ? 170 : 124, height: DeviceLayout.usesExpandedLayout ? 170 : 124)
                .clipShape(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: 2.2)
                )
                .background(
                    RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 3, y: 3)
                )
                .rotationEffect(.degrees(-1.6))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 22, foreground: MangaStyle.ink)
                        MangaLabel(text: "PLAYLIST", tint: MangaStyle.labelYellow, small: true)
                    }

                    MangaMisprintTitle(text: viewModel.playlistDetail?.name ?? playlist.name, size: DeviceLayout.usesExpandedLayout ? 26 : 22)
                        .fixedSize(horizontal: false, vertical: true)

                    if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                        Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                            .font(MangaStyle.bodyFont(12, weight: .bold))
                            .foregroundColor(MangaStyle.inkSub)
                            .lineLimit(1)
                    }

                    HStack(spacing: 7) {
                        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                            MangaLabel(text: "\(count) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true, foreground: MangaStyle.ink)
                        }
                        if let playCount = playlist.playCount, playCount > 0 {
                            MangaLabel(text: formatCount(playCount), tint: MangaStyle.mint, small: true)
                        }
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
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

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
                }
            }
        }
        .padding(16)
        .background(
            // 歌单详情页唯一焦点分格：保留厚墨框错版投影
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite, poster: true)
        )
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 40 : 20)
        .padding(.top, DeviceLayout.usesExpandedLayout ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
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

    func toolbarTrackCountView(_ count: Int) -> some View {
        Group {
            if MinimalWhiteStyle.isActive {
                minimalWhiteDetailPill(text: "\(count)")
            } else if MujiStyle.isActive {
                MujiPill(text: "\(count) \(String(localized: "songs_unit"))", tint: MujiStyle.tea)
            } else if NeumorphicStyle.isActive {
                NeumorphicPill(text: "\(count)", tint: NeumorphicStyle.sage, icon: .musicNoteList, compact: true)
            } else if SignalStyle.isActive {
                SignalPill(text: "\(count)", tint: SignalStyle.olive, icon: .musicNoteList, compact: true)
            } else if CapsuleStyle.isActive {
                CapsuleDetailChip(text: "\(count)", icon: .musicNoteList, tint: CapsuleStyle.mint)
            } else {
                HStack(spacing: 4) {
                    MonoIcon(icon: .musicNoteList, size: 10, color: .monoTextSecondary.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .background(Color.monoTextPrimary.opacity(0.08))
                        .clipShape(Capsule())

                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.monoTextPrimary)

                    Text(LocalizedStringKey("songs_unit"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.monoTextPrimary.opacity(0.06))
                .clipShape(Capsule())
            }
        }
    }

    func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        }
        if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }

    var filteredSongs: [Song] {
        viewModel.songs.filtered(by: searchText)
    }

}
