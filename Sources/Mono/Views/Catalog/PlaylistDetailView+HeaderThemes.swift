import SwiftUI

extension PlaylistDetailView {
    var neumorphicPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    NeumorphicStyle.surfacePressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.usesExpandedLayout ? 172 : 128, height: DeviceLayout.usesExpandedLayout ? 172 : 128)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        NeumorphicPill(text: "PLAYLIST", tint: NeumorphicStyle.accent, selected: true, compact: true)
                        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                            NeumorphicPill(text: "\(count) \(String(localized: "songs_unit"))", tint: NeumorphicStyle.sage, compact: true)
                        }
                    }

                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(NeumorphicStyle.titleFont(DeviceLayout.usesExpandedLayout ? 28 : 23, weight: .semibold))
                        .foregroundColor(NeumorphicStyle.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                        Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                            .font(NeumorphicStyle.labelFont(12, weight: .medium))
                            .foregroundColor(NeumorphicStyle.inkSoft)
                            .lineLimit(1)
                    }

                    HStack(spacing: 7) {
                        if let playCount = playlist.playCount, playCount > 0 {
                            NeumorphicPill(text: formatCount(playCount), tint: NeumorphicStyle.warm, compact: true)
                        }
                            if playlist.usesLocalCollection {
                            NeumorphicPill(text: playlist.sourceShortName, tint: (playlist.source ?? .netease).themedBadgeColor, compact: true)
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
                    NeumorphicPlayPill(title: String(localized: "play_now"), tint: NeumorphicStyle.accent)
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
                }
            }
        }
        .padding(17)
        .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true))
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

    var signalPlaylistHeaderContent: some View {
        SignalPlaylistHero(
            coverURL: playlist.coverUrl,
            title: viewModel.playlistDetail?.name ?? playlist.name,
            sourceLabel: playlist.sourceShortName,
            subtitle: (viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname).map {
                String(format: NSLocalizedString("created_by_format", comment: ""), $0)
            },
            descriptionText: viewModel.playlistDetail?.description ?? playlist.description,
            trackCount: viewModel.playlistDetail?.trackCount ?? playlist.trackCount,
            playDisabled: viewModel.songs.isEmpty,
            onPlay: playBannerPlaylist
        ) {
            if playlist.creator?.userId != APIService.shared.currentUserId {
                let serverSubscribed = !playlist.usesLocalCollection && subManager.isPlaylistSubscribed(playlist.id)
                SubscribeButton(
                    isSubscribed: isCollectedLocally || serverSubscribed,
                    action: handleBannerPlaylistCollectTap
                )
                .disabled(playlist.usesLocalCollection && (isCollectedLocally || viewModel.songs.isEmpty))
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

    /// Muji：杂志特辑页 —— 眉题行 + 跨页封面图 + 衬线大标题 + 署名行 + 图注式简介
    var mujiPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 眉题行
            HStack(alignment: .center, spacing: 8) {
                MujiDotMark()

                Text("PLAYLIST")
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(2.2)
                    .fixedSize()

                Spacer(minLength: 8)

                if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                    Text("\(count) \(String(localized: "songs_unit"))")
                        .font(MujiStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(MujiStyle.inkMuted)
                        .tracking(1.1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            // 跨页封面图
            CachedAsyncImage(url: playlist.coverUrl?.sized(800)) {
                Rectangle().fill(MujiStyle.wash(MujiStyle.clay))
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: DeviceLayout.usesExpandedLayout ? 300 : 216)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: MujiStyle.ink.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 14)

            // 标题与署名
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.playlistDetail?.name ?? playlist.name)
                    .font(MujiStyle.titleFont(DeviceLayout.usesExpandedLayout ? 30 : 26, weight: .regular))
                    .foregroundStyle(MujiStyle.ink)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                        Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                            .font(MujiStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineLimit(1)
                    }

                    if let playCount = playlist.playCount, playCount > 0 {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(MujiStyle.clay.opacity(0.85))
                                .frame(width: 3.5, height: 3.5)

                            Text(formatCount(playCount))
                                .font(MujiStyle.labelFont(10.5, weight: .semibold))
                                .foregroundStyle(MujiStyle.inkMuted)
                                .tracking(0.8)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)

            // 简介作图注：左侧陶土竖线 + 衬线弱化文字，可点开全文
            if let desc = (viewModel.playlistDetail?.description ?? playlist.description)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                Button(action: { showPlaylistDesc = true }) {
                    HStack(alignment: .top, spacing: 11) {
                        Rectangle()
                            .fill(MujiStyle.clay.opacity(0.8))
                            .frame(width: 2)
                            .padding(.vertical, 2)

                        Text(desc.replacingOccurrences(of: "\n", with: " "))
                            .font(MujiStyle.bodyFont(12.5, weight: .regular))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineSpacing(4)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 12)
            }

            // 动作行
            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllRemainingToQueue()
                    }
                }) {
                    MujiActionPill(
                        title: String(localized: "play_now"),
                        icon: .play,
                        selected: true,
                        tint: MujiStyle.clay
                    )
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
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)

            MujiListDivider()
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 18)
        }
        .padding(.top, DeviceLayout.usesExpandedLayout ? 24 : 14)
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

}
