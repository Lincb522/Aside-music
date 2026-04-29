import SwiftUI

// MARK: - Main View
struct PlaylistDetailView: View {
    let playlist: Playlist
    let initialSongs: [Song]?
    let bannerCoverURL: URL?

    @State private var viewModel = PlaylistDetailViewModel()

    @ObservedObject var playerManager = PlayerManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared

    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var selectedRelatedPlaylist: Playlist?
    @State private var showRelatedPlaylist = false
    @State private var isCollectedLocally = false
    @State private var showCollectOptions = false

    @State private var scrollOffset: CGFloat = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false

    init(playlist: Playlist, songs: [Song]? = nil, bannerCoverURLString: String? = nil) {
        self.playlist = playlist
        self.initialSongs = songs
        self.bannerCoverURL = bannerCoverURLString.flatMap(URL.init(string:))
    }

    struct Theme {
        static let cream = Color.clear
        static let milk = Color.monologueMilk
        static let accent = Color.monologueIconBackground // 黑/白自适应
        static let text = Color.monologueTextPrimary
        static let secondaryText = Color.monologueTextSecondary
        static let softShadow = Color.clear
    }

    var body: some View {
        ZStack {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else if SettingsManager.shared.coverBgPlaylist {
                PlaylistColorBackground(coverUrl: playlist.coverUrl?.sized(200))
            } else {
                ThemedPageBackground()
            }

            ScrollView {
                VStack(spacing: 0) {
                    playlistHeaderContent
                    PlaylistSearchBar(
                        searchText: $searchText,
                        isSearching: $isSearching,
                        onSearchActivated: { viewModel.loadAllRemaining() },
                        isSelectMode: $isSelectMode,
                        selectedIds: $selectedSongIds,
                        songs: filteredSongs,
                        onBatchQueue: {
                            let selected = filteredSongs.filter { selectedSongIds.contains($0.id) }
                            SongBatchActionHelper.addToQueue(selected) {
                                isSelectMode = false
                                selectedSongIds.removeAll()
                            }
                        },
                        onBatchDownload: { batchDownloadSelected() },
                        onBatchCollect: { showBatchAddToPlaylist = true }
                    )
                    songListSection
                        .padding(.bottom, 100)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                    toolbarTrackCountView(count)
                }
            }
        }
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            }
        }
        .navigationDestination(isPresented: $showRelatedPlaylist) {
            if let pl = selectedRelatedPlaylist {
                PlaylistDetailView(playlist: pl, songs: nil)

            }
        }
        .onAppear {
            if let songs = initialSongs {
                viewModel.setSongs(songs)
            } else {
                viewModel.fetchSongs(playlistId: playlist.id, source: playlist.source, playlist: playlist)
            }
            let name = playlist.name
            isCollectedLocally = LocalPlaylistManager.shared.playlists.contains { $0.name == name }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            let selected = filteredSongs.filter { selectedSongIds.contains($0.id) }
            BatchAddToPlaylistSheet(songs: selected)
        }
    }

    private func batchDownloadSelected() {
        let selected = filteredSongs.filter { selectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(
            title: String(localized: "已加入下载"),
            message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"),
            primaryButtonTitle: String(localized: "确定"),
            primaryAction: {}
        )
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }

    // MARK: - Components

    @ViewBuilder
    private var playlistHeaderContent: some View {
        if let bannerCoverURL {
            bannerPlaylistHeaderContent(bannerCoverURL)
        } else if MangaStyle.isActive {
            mangaPlaylistHeaderContent
        } else if NeumorphicStyle.isActive {
            neumorphicPlaylistHeaderContent
        } else if MujiStyle.isActive {
            mujiPlaylistHeaderContent
        } else {
            VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 180 : 120, height: DeviceLayout.isPad ? 180 : 120)
                .cornerRadius(DeviceLayout.isPad ? 20 : 16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                    Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer().frame(height: 4)

                    HStack(spacing: 8) {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                                viewModel.loadAllRemainingToQueue()
                            }
                        }) {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .play, size: 12, color: .monologueIconForeground)
                                Text(LocalizedStringKey("play_now"))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.monologueIconForeground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.accent)
                            .cornerRadius(20)
                            .monologueGlassCapsule()
                            .shadow(color: Theme.accent.opacity(0.2), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                        // 收藏歌单按钮
                        if playlist.creator?.userId != APIService.shared.currentUserId {
                            let serverSubscribed = !playlist.isQQMusic && subManager.isPlaylistSubscribed(playlist.id)
                            SubscribeButton(
                                isSubscribed: isCollectedLocally || serverSubscribed,
                                action: {
                                    if playlist.isQQMusic {
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
                            .disabled((playlist.isQQMusic && (isCollectedLocally || viewModel.songs.isEmpty)))
                            .confirmationDialog(String(localized: "收藏歌单"), isPresented: $showCollectOptions, titleVisibility: .visible) {
                                Button(String(localized: "收藏到本地")) {
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

                                Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "取消订阅") : String(localized: "playlist_subscribe_to_ncm")) {
                                    subManager.togglePlaylistSubscription(id: playlist.id)
                                }

                                Button(String(localized: "取消"), role: .cancel) {}
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 24)
        .padding(.top, DeviceLayout.isPad ? 24 : 16)
        .padding(.bottom, DeviceLayout.isPad ? 32 : 24)
        .iPadContentWidth(900)
        }
    }

    private func bannerPlaylistHeaderContent(_ imageURL: URL) -> some View {
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
                    let serverSubscribed = !playlist.isQQMusic && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: handleBannerPlaylistCollectTap
                    )
                    .disabled(playlist.isQQMusic && (isCollectedLocally || viewModel.songs.isEmpty))
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
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
        .confirmationDialog(String(localized: "收藏歌单"), isPresented: $showCollectOptions, titleVisibility: .visible) {
            Button(String(localized: "收藏到本地")) {
                collectBannerPlaylistLocally()
            }
            .disabled(isCollectedLocally || viewModel.songs.isEmpty)

            Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "取消订阅") : String(localized: "playlist_subscribe_to_ncm")) {
                subManager.togglePlaylistSubscription(id: playlist.id)
            }

            Button(String(localized: "取消"), role: .cancel) {}
        }
    }

    private func bannerPlaylistArtwork(_ imageURL: URL) -> some View {
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
    private func bannerHeaderBadge(_ text: String, emphasis: Bool = false) -> some View {
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
        } else if MujiStyle.isActive {
            MujiPill(text: text, tint: emphasis ? MujiStyle.clay : MujiStyle.tea)
        } else {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(emphasis ? Color.monologueIconForeground : Color.monologueTextSecondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(emphasis ? Color.monologueIconBackground : Color.monologueTextPrimary.opacity(0.07), in: Capsule())
        }
    }

    @ViewBuilder
    private var bannerHeaderPlayButton: some View {
        Button(action: playBannerPlaylist) {
            if MangaStyle.isActive {
                HStack(spacing: 7) {
                    MonologueIcon(icon: .play, size: 12, color: MangaStyle.strokeInk, lineWidth: 2)
                    Text(LocalizedStringKey("play_now"))
                        .font(MangaStyle.labelFont(12, weight: .black))
                }
                .foregroundColor(MangaStyle.strokeInk)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Capsule().fill(MangaStyle.labelYellow))
                .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.5))
                .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
            } else if NeumorphicStyle.isActive {
                NeumorphicPlayPill(title: String(localized: "play_now"), tint: NeumorphicStyle.accent)
            } else if MujiStyle.isActive {
                MujiActionPill(
                    title: String(localized: "play_now"),
                    icon: .play,
                    selected: true,
                    tint: MujiStyle.clay
                )
            } else {
                HStack(spacing: 6) {
                    MonologueIcon(icon: .play, size: 12, color: .monologueIconForeground)
                    Text(LocalizedStringKey("play_now"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.monologueIconForeground)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.monologueIconBackground, in: Capsule())
                .monologueGlassCapsule()
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
        .disabled(viewModel.songs.isEmpty)
    }

    private func playBannerPlaylist() {
        guard let first = viewModel.songs.first else { return }
        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
        viewModel.loadAllRemainingToQueue()
    }

    private func handleBannerPlaylistCollectTap() {
        if playlist.isQQMusic {
            guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
            collectBannerPlaylistLocally()
        } else {
            showCollectOptions = true
        }
    }

    private func collectBannerPlaylistLocally() {
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

    private var bannerArtworkHeight: CGFloat {
        DeviceLayout.isPad ? 220 : 148
    }

    private var bannerArtworkRadius: CGFloat {
        if MangaStyle.isActive { return 16 }
        if MujiStyle.isActive { return 12 }
        if NeumorphicStyle.isActive { return 22 }
        return 20
    }

    private var bannerHeaderRadius: CGFloat {
        if MangaStyle.isActive { return 22 }
        if MujiStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return 28 }
        return 24
    }

    private var bannerHeaderInnerPadding: CGFloat {
        if MangaStyle.isActive { return 16 }
        if MujiStyle.isActive { return 18 }
        if NeumorphicStyle.isActive { return 17 }
        return 16
    }

    private var bannerHeaderTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(DeviceLayout.isPad ? 27 : 23, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(DeviceLayout.isPad ? 32 : 28, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold) }
        return .system(size: DeviceLayout.isPad ? 28 : 22, weight: .bold, design: .rounded)
    }

    private var bannerHeaderMetaFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var bannerHeaderDescriptionFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .regular) }
        return .system(size: 13, weight: .regular, design: .rounded)
    }

    private var bannerHeaderPrimaryText: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
    }

    private var bannerHeaderSecondaryText: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return .monologueTextSecondary
    }

    @ViewBuilder
    private var bannerHeaderSurface: some View {
        if MangaStyle.isActive {
            MangaCardBackground(cornerRadius: bannerHeaderRadius, elevated: true, tint: MangaStyle.bubbleWhite)
        } else if MujiStyle.isActive {
            MujiPaperCardBackground(cornerRadius: bannerHeaderRadius, elevated: true)
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: bannerHeaderRadius, elevated: true)
        } else {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .fill(Color.monologueGlassTint)
        }
    }

    @ViewBuilder
    private var bannerHeaderBorder: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 1.8)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.58), lineWidth: 0.7)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private var bannerArtworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
            .fill(bannerArtworkFillColor)
            .overlay(MonologueIcon(icon: .musicNoteList, size: 28, color: bannerHeaderSecondaryText.opacity(0.5)))
    }

    @ViewBuilder
    private var bannerArtworkFill: some View {
        RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
            .fill(bannerArtworkFillColor)
    }

    private var bannerArtworkFillColor: Color {
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        return Color.monologueSeparator.opacity(0.35)
    }

    @ViewBuilder
    private var bannerArtworkBorder: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 2)
        } else if MujiStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.8)
        } else {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(Color.monologueTextPrimary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private var neumorphicPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    NeumorphicStyle.surfacePressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 172 : 128, height: DeviceLayout.isPad ? 172 : 128)
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
                        .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold))
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
                        if playlist.isQQMusic {
                            NeumorphicPill(text: "QCM", tint: MusicSource.qqmusic.themedBadgeColor, compact: true)
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.isQQMusic && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: {
                            if playlist.isQQMusic {
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
                    .disabled((playlist.isQQMusic && (isCollectedLocally || viewModel.songs.isEmpty)))
                }
            }
        }
        .padding(17)
        .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
        .confirmationDialog(String(localized: "收藏歌单"), isPresented: $showCollectOptions, titleVisibility: .visible) {
            Button(String(localized: "收藏到本地")) {
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

            Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "取消订阅") : String(localized: "playlist_subscribe_to_ncm")) {
                subManager.togglePlaylistSubscription(id: playlist.id)
            }

            Button(String(localized: "取消"), role: .cancel) {}
        }
    }

    private var mujiPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    MujiPill(text: "PLAYLIST", tint: MujiStyle.clay)
                    if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                        MujiPill(text: "\(count) \(String(localized: "songs_unit"))", tint: MujiStyle.tea)
                    }
                    if let playCount = playlist.playCount, playCount > 0 {
                        MujiPill(text: formatCount(playCount), tint: MujiStyle.indigo)
                    }
                }

                Text(viewModel.playlistDetail?.name ?? playlist.name)
                    .font(MujiStyle.titleFont(DeviceLayout.isPad ? 32 : 28, weight: .regular))
                    .foregroundStyle(MujiStyle.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                    Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                        .font(MujiStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(MujiStyle.inkSoft)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            VStack(alignment: .leading, spacing: 14) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    MujiStyle.surfaceRaised
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 230 : 190, height: DeviceLayout.isPad ? 230 : 190)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
                )
                .shadow(color: Color.black.opacity(0.055), radius: 10, x: 0, y: 5)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)

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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.55 : 1)
                .disabled(viewModel.songs.isEmpty)

                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.isQQMusic && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: {
                            if playlist.isQQMusic {
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
                    .disabled((playlist.isQQMusic && (isCollectedLocally || viewModel.songs.isEmpty)))
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            MujiListDivider()
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
        .confirmationDialog(String(localized: "收藏歌单"), isPresented: $showCollectOptions, titleVisibility: .visible) {
            Button(String(localized: "收藏到本地")) {
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

            Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "取消订阅") : String(localized: "playlist_subscribe_to_ncm")) {
                subManager.togglePlaylistSubscription(id: playlist.id)
            }

            Button(String(localized: "取消"), role: .cancel) {}
        }
    }

    private var mangaPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    MangaStyle.paperCool
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 170 : 124, height: DeviceLayout.isPad ? 170 : 124)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MangaStyle.strokeInk, lineWidth: 2.2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MangaStyle.strokeInk)
                        .offset(x: 3, y: 3)
                )
                .rotationEffect(.degrees(-1.6))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 22, foreground: MangaStyle.ink)
                        MangaLabel(text: "PLAYLIST", tint: MangaStyle.labelYellow, small: true)
                    }

                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(MangaStyle.titleFont(DeviceLayout.isPad ? 26 : 22, weight: .black))
                        .foregroundColor(MangaStyle.ink)
                        .lineLimit(3)
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
                        MonologueIcon(icon: .play, size: 12, color: MangaStyle.strokeInk, lineWidth: 2)
                        Text(LocalizedStringKey("play_now"))
                            .font(MangaStyle.labelFont(12, weight: .black))
                    }
                    .foregroundColor(MangaStyle.strokeInk)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(MangaStyle.labelYellow))
                    .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.5))
                    .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

                if playlist.creator?.userId != APIService.shared.currentUserId {
                    let serverSubscribed = !playlist.isQQMusic && subManager.isPlaylistSubscribed(playlist.id)
                    SubscribeButton(
                        isSubscribed: isCollectedLocally || serverSubscribed,
                        action: {
                            if playlist.isQQMusic {
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
                    .disabled((playlist.isQQMusic && (isCollectedLocally || viewModel.songs.isEmpty)))
                }
            }
        }
        .padding(16)
        .background(MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
        .confirmationDialog(String(localized: "收藏歌单"), isPresented: $showCollectOptions, titleVisibility: .visible) {
            Button(String(localized: "收藏到本地")) {
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

            Button(subManager.isPlaylistSubscribed(playlist.id) ? String(localized: "取消订阅") : String(localized: "playlist_subscribe_to_ncm")) {
                subManager.togglePlaylistSubscription(id: playlist.id)
            }

            Button(String(localized: "取消"), role: .cancel) {}
        }
    }

    private func toolbarTrackCountView(_ count: Int) -> some View {
        Group {
            if MujiStyle.isActive {
                MujiPill(text: "\(count) \(String(localized: "songs_unit"))", tint: MujiStyle.tea)
            } else if NeumorphicStyle.isActive {
                NeumorphicPill(text: "\(count)", tint: NeumorphicStyle.sage, icon: .musicNoteList, compact: true)
            } else {
                HStack(spacing: 4) {
                    MonologueIcon(icon: .musicNoteList, size: 10, color: .monologueTextSecondary.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .background(Color.monologueTextPrimary.opacity(0.08))
                        .clipShape(Capsule())

                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text(LocalizedStringKey("songs_unit"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.monologueTextPrimary.opacity(0.06))
                .clipShape(Capsule())
            }
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        }
        if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }

    private var filteredSongs: [Song] {
        viewModel.songs.filtered(by: searchText)
    }

    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                MonologueLoadingView(text: "LOADING TRACKS")
            } else {
                if filteredSongs.isEmpty {
                    VStack(spacing: 14) {
                        if NeumorphicStyle.isActive {
                            NeumorphicIconBadge(icon: .musicNoteList, tint: NeumorphicStyle.accent, size: 54)
                        } else {
                            MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        }

                        Text(LocalizedStringKey("album_no_songs"))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NeumorphicStyle.isActive ? 34 : 0)
                    .background {
                        if NeumorphicStyle.isActive {
                            NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
                        }
                    }
                    .padding(.horizontal, NeumorphicStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
                    .padding(.top, 40)
                } else {
                    ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
                        SongListRow(
                            song: song,
                            index: index,
                            isSelecting: isSelectMode,
                            isSelected: selectedSongIds.contains(song.id),
                            onArtistTap: { artistId in
                                selectedArtistId = artistId
                                showArtistDetail = true
                            },
                            onDetailTap: { detailSong in
                                selectedSongForDetail = detailSong
                                showSongDetail = true
                            },
                            onAlbumTap: { albumId in
                                selectedAlbumId = albumId
                                showAlbumDetail = true
                            },
                            onTap: {
                                if isSelectMode {
                                    if selectedSongIds.contains(song.id) {
                                        selectedSongIds.remove(song.id)
                                    } else {
                                        selectedSongIds.insert(song.id)
                                    }
                                } else {
                                    PlayerManager.shared.play(song: song, in: filteredSongs)
                                }
                            }
                        )
                    }
                }

                if !isSearching {
                    if viewModel.isLoadingMore {
                        MonologueLoadingView(text: "LOADING MORE", centered: false)
                            .padding()
                    }
                    if viewModel.hasMore && !viewModel.isLoading && !viewModel.isLoadingMore {
                        Color.clear.frame(height: 20).onAppear { viewModel.loadMore() }
                    }
                    if !viewModel.hasMore && !viewModel.songs.isEmpty && !viewModel.isLoading {
                        NoMoreDataView()
                    }

                    if !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                        relatedPlaylistsSection
                    }
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    // MARK: - 相关歌单推荐

    private var relatedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if MangaStyle.isActive {
                MangaSectionTitle(title: String(localized: "related_playlists"), mark: .star)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if NeumorphicStyle.isActive {
                NeumorphicSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if MujiStyle.isActive {
                MujiSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else {
                Text(LocalizedStringKey("related_playlists"))
                    .font(.rounded(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(viewModel.relatedPlaylists) { rp in
                        Button(action: {
                            let pl = Playlist(
                                id: rp.id,
                                name: rp.name,
                                coverImgUrl: rp.coverImgUrl,
                                picUrl: nil,
                                trackCount: nil,
                                playCount: nil,
                                subscribedCount: nil,
                                shareCount: nil,
                                commentCount: nil,
                                creator: nil,
                                description: nil,
                                tags: nil
                            )
                            selectedRelatedPlaylist = pl
                            showRelatedPlaylist = true
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: rp.coverUrl?.sized(300)) {
                                    RoundedRectangle(cornerRadius: MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 8 : (NeumorphicStyle.isActive ? 16 : 12)))
                                        .fill(MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)))
                                        .monologueGlass(cornerRadius: MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 8 : (NeumorphicStyle.isActive ? 16 : 12)))
                                }
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 8 : (NeumorphicStyle.isActive ? 16 : 12)), style: .continuous))
                                .overlay {
                                    if MangaStyle.isActive {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
                                    } else if MujiStyle.isActive {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                                    } else if NeumorphicStyle.isActive {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                                    }
                                }

                                Text(rp.name)
                                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(13, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .rounded(size: 13, weight: .medium))))
                                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)))
                                    .lineLimit(2)
                                    .frame(width: 130, height: 34, alignment: .topLeading)

                                Text(rp.creatorName.isEmpty ? " " : rp.creatorName)
                                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(11, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : .rounded(size: 11))))
                                    .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)))
                                    .lineLimit(1)
                                    .frame(width: 130, alignment: .leading)
                            }
                            .padding(ThemedPageStyle.isActive ? 8 : 0)
                            .background {
                                if MangaStyle.isActive {
                                    MangaCardBackground(cornerRadius: 14, elevated: true, tint: MangaStyle.bubbleWhite)
                                } else if MujiStyle.isActive {
                                    MujiPaperCardBackground(cornerRadius: 10)
                                } else if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, lightweight: true)
                                }
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }
}

// MARK: - Utilities

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
