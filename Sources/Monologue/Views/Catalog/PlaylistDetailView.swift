import SwiftUI

// MARK: - Main View
struct PlaylistDetailView: View {
    let playlist: Playlist
    let initialSongs: [Song]?
    let bannerCoverURL: URL?

    @StateObject private var viewModel = PlaylistDetailViewModel()

    @ObservedObject var playerManager = PlayerManager.shared
    @ObservedObject var subManager = SubscriptionManager.shared
    @ObservedObject private var settings = SettingsManager.shared

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
    @State private var showPlaylistDesc = false

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

    private var petWhiteDetailHorizontalPadding: CGFloat {
        DeviceLayout.isPad ? 8 : 4
    }

    /// aside(default) 及无独立分支主题走歌手页式 Hero 头部
    private var usesAsideHero: Bool {
        bannerCoverURL == nil
            && !MinimalWhiteStyle.isActive && !PetWhiteStyle.isActive
            && !MangaStyle.isActive && !NeumorphicStyle.isActive
            && !SignalStyle.isActive && !MujiStyle.isActive
            && !CapsuleStyle.isActive && !BentoStyle.isActive
            && !SequoiaStyle.isActive
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteRootBackdrop()
            } else if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if PetWhiteStyle.isActive {
                PetWhiteRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else if SignalStyle.isActive {
                ThemeRenderBackdrop(theme: .default)
            } else if BentoStyle.isActive {
                BentoRootBackdrop()
            } else if CapsuleStyle.isActive {
                CapsuleRootBackdrop()
            } else if SettingsManager.shared.coverBgPlaylist {
                PlaylistColorBackground(coverUrl: playlist.coverUrl?.sized(200))
            } else {
                ThemedPageBackground()
            }

            ScrollView {
                VStack(spacing: 0) {
                    if usesAsideHero {
                        // Hero 头部自带拉伸/视差，不叠加收缩动效
                        playlistHeaderContent
                    } else {
                        playlistHeaderContent
                            .monologuePageHeaderCollapse()
                    }
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
            .monologueScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: usesAsideHero ? .top : [])
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
        .monologueSheet(isPresented: $showPlaylistDesc, preset: .standard){
            PlaylistDescSheet(
                coverUrl: playlist.coverUrl?.sized(200),
                title: viewModel.playlistDetail?.name ?? playlist.name,
                subtitle: playlist.creator?.nickname,
                descriptionText: viewModel.playlistDetail?.description ?? playlist.description
            )
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
            title: String(localized: "download_batch_added_title"),
            message: L10n.format("download_batch_queue_added_format", selected.count),
            primaryButtonTitle: String(localized: "common_confirm"),
            primaryAction: {}
        )
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }

    // MARK: - Components

    @ViewBuilder
    private var playlistHeaderContent: some View {
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
    private var asideHeroMetaItems: [String] {
        var items: [String] = []
        if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
            items.append(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
        }
        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
            items.append("\(count) \(String(localized: "songs_unit"))")
        }
        return items
    }

    private var minimalWhitePlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonologueIcon(icon: .musicNoteList, size: 26, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.55))
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
                        MonologueIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent, lineWidth: 1.75)
                        Text(LocalizedStringKey("play_now"))
                            .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                    }
                    .foregroundStyle(MinimalWhiteStyle.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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

    private func minimalWhiteDetailPill(text: String) -> some View {
        Text(text)
            .font(MinimalWhiteStyle.labelFont(11, weight: .medium))
            .foregroundStyle(MinimalWhiteStyle.inkMuted)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(MinimalWhiteCapsuleBackground())
    }

    private var petWhitePlaylistHeaderContent: some View {
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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

    private func petWhiteHeaderAction(title: String, icon: MonologueIcon.IconType, tint: Color, filled: Bool) -> some View {
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

    private var sequoiaPlaylistHeaderContent: some View {
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
                        MonologueIcon(icon: .play, size: 13, color: SequoiaStyle.onAccent, lineWidth: 1.7)
                        Text(LocalizedStringKey("play_now"))
                            .font(SequoiaStyle.labelFont(12, weight: .semibold))
                    }
                    .foregroundStyle(SequoiaStyle.onAccent)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(SequoiaStyle.accentGradient, in: Capsule())
                    .overlay(Capsule().stroke(SequoiaStyle.luminousSeparator.opacity(0.24), lineWidth: 0.55))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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

    private var sequoiaPlaylistCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(SequoiaStyle.materialList)
            .overlay(MonologueIcon(icon: .musicNoteList, size: 30, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
    }

    @ViewBuilder
    private var capsulePlaylistHeaderContent: some View {
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
                    MonologueIcon(icon: .play, size: 12, color: MangaStyle.onStrokeInk, lineWidth: 2)
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
                    MonologueIcon(icon: .play, size: 12, color: SequoiaStyle.onAccent, lineWidth: 1.7)
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
                            if playlist.usesLocalCollection {
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
        if SignalStyle.isActive { return DeviceLayout.isPad ? 230 : 160 }
        return DeviceLayout.isPad ? 220 : 148
    }

    private var bannerArtworkRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if MujiStyle.isActive { return 12 }
        if NeumorphicStyle.isActive { return 22 }
        if SignalStyle.isActive { return 24 }
        if SequoiaStyle.isActive { return 22 }
        return 20
    }

    private var bannerHeaderRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius + 4 }
        if MujiStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return 28 }
        if SignalStyle.isActive { return 30 }
        if SequoiaStyle.isActive { return 26 }
        return 24
    }

    private var bannerHeaderInnerPadding: CGFloat {
        if MangaStyle.isActive { return 16 }
        if MujiStyle.isActive { return 18 }
        if NeumorphicStyle.isActive { return 17 }
        if SignalStyle.isActive { return 16 }
        if SequoiaStyle.isActive { return 16 }
        return 16
    }

    private var bannerHeaderHorizontalPadding: CGFloat {
        if SignalStyle.isActive { return DeviceLayout.isPad ? 36 : 14 }
        if SequoiaStyle.isActive { return DeviceLayout.isPad ? 40 : 20 }
        return DeviceLayout.isPad ? 40 : 20
    }

    private var bannerHeaderTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(DeviceLayout.isPad ? 27 : 23, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(DeviceLayout.isPad ? 32 : 28, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.titleFont(DeviceLayout.isPad ? 30 : 24, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(DeviceLayout.isPad ? 28 : 23, weight: .semibold) }
        return .system(size: DeviceLayout.isPad ? 28 : 22, weight: .bold, design: .rounded)
    }

    private var bannerHeaderMetaFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .medium) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var bannerHeaderDescriptionFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .regular) }
        if SignalStyle.isActive { return SignalStyle.bodyFont(12, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 13, weight: .regular, design: .rounded)
    }

    private var bannerHeaderPrimaryText: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var bannerHeaderSecondaryText: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    @ViewBuilder
    private var bannerHeaderSurface: some View {
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
                .fill(Color.monologueGlassTint)
        }
    }

    @ViewBuilder
    private var bannerHeaderBorder: some View {
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(MangaStyle.strokeInk, lineWidth: 1.8)
        } else if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.32), lineWidth: 0.8)
        } else if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(SignalStyle.accent.opacity(0.22), lineWidth: 0.9)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerHeaderRadius, style: .continuous)
                .stroke(SequoiaStyle.separator.opacity(0.82), lineWidth: 0.6)
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
        if SignalStyle.isActive { return SignalStyle.controlPressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
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
        } else if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.8)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: bannerArtworkRadius, style: .continuous)
                .stroke(SequoiaStyle.luminousSeparator.opacity(0.58), lineWidth: 0.7)
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
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

    private var signalPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    SignalStyle.controlPressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 178 : 132, height: DeviceLayout.isPad ? 178 : 132)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.8)
                )
                .background(SignalSurfaceBackground(cornerRadius: 26, elevated: true, fill: SignalStyle.control))

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        SignalPill(text: "PLAYLIST", tint: SignalStyle.accent, selected: true, compact: true)
                        if let count = viewModel.playlistDetail?.trackCount ?? playlist.trackCount {
                            SignalPill(text: "\(count) \(String(localized: "songs_unit"))", tint: SignalStyle.olive, compact: true)
                        }
                    }

                    Text(viewModel.playlistDetail?.name ?? playlist.name)
                        .font(SignalStyle.titleFont(DeviceLayout.isPad ? 30 : 24, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let creator = viewModel.playlistDetail?.creator?.nickname ?? playlist.creator?.nickname {
                        Text(String(format: NSLocalizedString("created_by_format", comment: ""), creator))
                            .font(SignalStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(SignalStyle.inkSoft)
                            .lineLimit(1)
                    }

                    HStack(spacing: 7) {
                        if let playCount = playlist.playCount, playCount > 0 {
                            SignalPill(text: formatCount(playCount), tint: SignalStyle.amber, compact: true)
                        }
                            if playlist.usesLocalCollection {
                            SignalPill(text: playlist.sourceShortName, tint: (playlist.source ?? .netease).themedBadgeColor, compact: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(action: playBannerPlaylist) {
                    SignalPlayPill(title: String(localized: "play_now"))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
        .background(SignalSurfaceBackground(cornerRadius: 30, elevated: true, fill: SignalStyle.paper))
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 18)
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

    /// Muji：杂志特辑页 —— 眉题行 + 跨页封面图 + 衬线大标题 + 署名行 + 图注式简介
    private var mujiPlaylistHeaderContent: some View {
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
            .frame(height: DeviceLayout.isPad ? 300 : 216)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: MujiStyle.ink.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 14)

            // 标题与署名
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.playlistDetail?.name ?? playlist.name)
                    .font(MujiStyle.titleFont(DeviceLayout.isPad ? 30 : 26, weight: .regular))
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
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
        .padding(.top, DeviceLayout.isPad ? 24 : 14)
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

    // MARK: - Bento header
    private var bentoPlaylistHeaderContent: some View {
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
                        .frame(width: DeviceLayout.isPad ? 160 : 120, height: DeviceLayout.isPad ? 160 : 120)
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
                        MonologueIcon(icon: .play, size: 14, color: BentoStyle.onAccent, lineWidth: 2)
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
                            MonologueIcon(icon: collected ? .liked : .like, size: 14, color: collected ? BentoStyle.onAccent : BentoStyle.ink, lineWidth: 2)
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

    private func bentoPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(BentoStyle.labelFont(11, weight: .heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    private var mangaPlaylistHeaderContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    MangaStyle.paperCool
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 170 : 124, height: DeviceLayout.isPad ? 170 : 124)
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

                    MangaMisprintTitle(text: viewModel.playlistDetail?.name ?? playlist.name, size: DeviceLayout.isPad ? 26 : 22)
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
                        MonologueIcon(icon: .play, size: 12, color: MangaStyle.onStrokeInk, lineWidth: 2)
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
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))

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
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 20)
        .padding(.top, DeviceLayout.isPad ? 28 : 18)
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

    private func toolbarTrackCountView(_ count: Int) -> some View {
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
        Group {
            if MinimalWhiteStyle.isActive {
                minimalWhiteSongListSection
            } else if CapsuleStyle.isActive {
                capsuleSongListSection
            } else if PetWhiteStyle.isActive {
                petWhiteSongListSection
            } else {
                defaultSongListSection
            }
        }
    }

    private var minimalWhiteSongListSection: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            MinimalWhiteSectionTitle(title: String(localized: "歌曲")) {
                if !filteredSongs.isEmpty {
                    Text("\(filteredSongs.count)")
                        .font(MinimalWhiteStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(MinimalWhiteStyle.inkMuted)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            if viewModel.isLoading {
                MonologueLoadingView(text: "")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else if filteredSongs.isEmpty {
                playlistEmptyState
            } else {
                LazyVStack(spacing: 0) {
                    playlistSongRows
                    playlistPagination
                }
                .background(
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.cardRadius,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
                )
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                if !isSearching && !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                    relatedPlaylistsSection
                }

                FloatingBarBottomSpacer()
            }
        }
        .padding(.top, 4)
    }

    private var capsuleSongListSection: some View {
        LazyVStack(spacing: 16) {
            if viewModel.isLoading {
                CapsuleDetailSection(title: "TRACKS", icon: .musicNoteList, tint: CapsuleStyle.accent) {
                    MonologueLoadingView(text: "LOADING TRACKS")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else if filteredSongs.isEmpty {
                CapsuleDetailSection(title: "TRACKS", icon: .musicNoteList, tint: CapsuleStyle.accent) {
                    CapsuleDetailEmptyState(title: "album_no_songs", icon: .musicNoteList, tint: CapsuleStyle.accent)
                }
            } else {
                CapsuleDetailSection(
                    title: "TRACKS",
                    subtitle: String(format: NSLocalizedString("songs_count_format", comment: ""), filteredSongs.count),
                    icon: .musicNoteList,
                    tint: CapsuleStyle.accent
                ) {
                    playlistSongRows
                    playlistPagination
                }

                if !isSearching && !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                    relatedPlaylistsSection
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    private var petWhiteSongListSection: some View {
        LazyVStack(spacing: 14) {
            if viewModel.isLoading {
                petWhiteTrackSection(title: "TRACKS", detail: nil) {
                    MonologueLoadingView(text: "LOADING TRACKS")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                }
            } else if filteredSongs.isEmpty {
                petWhiteTrackSection(title: "TRACKS", detail: nil) {
                    playlistEmptyState
                        .padding(.top, 0)
                }
            } else {
                petWhiteTrackSection(
                    title: "TRACKS",
                    detail: String(format: NSLocalizedString("songs_count_format", comment: ""), filteredSongs.count)
                ) {
                    playlistSongRows
                    playlistPagination
                }

                if !isSearching && !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                    relatedPlaylistsSection
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    private func petWhiteTrackSection<Content: View>(
        title: String,
        detail: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: title,
                detail: detail,
                icon: .musicNoteList,
                tint: PetWhiteStyle.butter
            )

            LazyVStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.butter))
        .padding(.horizontal, petWhiteDetailHorizontalPadding)
    }

    private var defaultSongListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                MonologueLoadingView(text: "LOADING TRACKS")
            } else {
                if filteredSongs.isEmpty {
                    playlistEmptyState
                } else {
                    playlistSongRows
                }

                if !isSearching {
                    playlistPagination

                    if !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                        relatedPlaylistsSection
                    }
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    private var playlistEmptyState: some View {
        VStack(spacing: 14) {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .musicNoteList, size: 54)
            } else if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .musicNoteList, tint: NeumorphicStyle.accent, size: 54)
            } else if SignalStyle.isActive {
                SignalIconBadge(icon: .musicNoteList, tint: SignalStyle.accent, size: 54)
            } else {
                MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
            }

            Text(LocalizedStringKey("album_no_songs"))
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : .rounded(size: 15))))
                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, (ThemedPageStyle.isActive || MinimalWhiteStyle.isActive) ? 34 : 0)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: 26, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
            }
        }
        .padding(.horizontal, (ThemedPageStyle.isActive || MinimalWhiteStyle.isActive) ? DeviceLayout.viewHorizontalPadding : 0)
        .padding(.top, 40)
    }

    private var playlistSongRows: some View {
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
                },
                horizontalPadding: PetWhiteStyle.isActive ? CGFloat(0) : nil
            )
        }
    }

    private var playlistPagination: some View {
        Group {
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
        }
    }

    // MARK: - 相关歌单推荐

    private var relatedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if MangaStyle.isActive {
                MangaSectionTitle(title: String(localized: "related_playlists"), mark: .star)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if NeumorphicStyle.isActive {
                NeumorphicSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if SignalStyle.isActive {
                SignalSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if MujiStyle.isActive {
                MujiSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if CapsuleStyle.isActive {
                HStack {
                    CapsuleDetailChip(
                        text: String(localized: "related_playlists"),
                        icon: .musicNoteList,
                        tint: CapsuleStyle.cyan,
                        selected: true
                    )
                    Spacer()
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 16)
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
                                    RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                        .fill(relatedPlaylistCoverFill)
                                        .monologueGlass(cornerRadius: relatedPlaylistCoverRadius)
                                }
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous))
                                .overlay {
                                    if MangaStyle.isActive {
                                        RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                            .stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1)
                                    } else if MujiStyle.isActive {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                                    } else if NeumorphicStyle.isActive {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                                    } else if SignalStyle.isActive {
                                        RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                            .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                                    } else if MinimalWhiteStyle.isActive {
                                        RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                                    }
                                }

                                Text(rp.name)
                                    .font(relatedPlaylistTitleFont)
                                    .foregroundColor(relatedPlaylistTitleColor)
                                    .lineLimit(2)
                                    .frame(width: 130, height: 34, alignment: .topLeading)

                                Text(rp.creatorName.isEmpty ? " " : rp.creatorName)
                                    .font(relatedPlaylistMetaFont)
                                    .foregroundColor(relatedPlaylistMetaColor)
                                    .lineLimit(1)
                                    .frame(width: 130, alignment: .leading)
                            }
                            .padding(ThemedPageStyle.isActive && !MangaStyle.isActive ? 8 : 0)
                            .background {
                                if MangaStyle.isActive {
                                    // 去卡片化：相关歌单直接排在纸上
                                    EmptyView()
                                } else if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, lightweight: true)
                                } else if SignalStyle.isActive {
                                    SignalSurfaceBackground(cornerRadius: 22, elevated: false, fill: SignalStyle.paper)
                                } else if MinimalWhiteStyle.isActive {
                                    MinimalWhiteSurfaceBackground(
                                        cornerRadius: MinimalWhiteStyle.cardRadius,
                                        elevated: false,
                                        tint: MinimalWhiteStyle.glassFill
                                    )
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

    private var relatedPlaylistCoverRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 12 }
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if MujiStyle.isActive { return 8 }
        if NeumorphicStyle.isActive { return 16 }
        if SignalStyle.isActive { return 18 }
        return 12
    }

    private var relatedPlaylistCoverFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SignalStyle.isActive { return SignalStyle.controlPressed }
        return Color.monologueGlassTint
    }

    private var relatedPlaylistTitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(13, weight: .medium) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.labelFont(13, weight: .bold) }
        return .rounded(size: 13, weight: .medium)
    }

    private var relatedPlaylistMetaFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(11, weight: .regular) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(11, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(11, weight: .medium) }
        return .rounded(size: 11)
    }

    private var relatedPlaylistTitleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        return .monologueTextPrimary
    }

    private var relatedPlaylistMetaColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        return .monologueTextSecondary
    }
}

// MARK: - 歌单简介 Sheet（aside）

/// 歌单 / 本地歌单详情页共用的介绍弹层，与歌手简介同一交互：
/// 头部封面 + 名称 + 创建者，下方滚动阅读完整介绍
struct PlaylistDescSheet: View {
    let coverUrl: URL?
    let title: String
    var subtitle: String? = nil
    let descriptionText: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.monologueGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rounded(size: 20, weight: .bold))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.rounded(size: 12))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: .monologueTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.monologueSeparator))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let desc = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !desc.isEmpty {
                        Text(desc)
                            .font(.rounded(size: 15, weight: .regular))
                            .foregroundColor(.monologueTextPrimary)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.monologueGlassTint)
                                    .monologueGlass(cornerRadius: 20)
                            }
                    } else {
                        VStack(spacing: 14) {
                            MonologueIcon(icon: .info, size: 34, color: .monologueTextSecondary.opacity(0.5))
                            Text(String(localized: "暂无介绍"))
                                .font(.rounded(size: 14))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 20)
            }
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
