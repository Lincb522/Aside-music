import SwiftUI

// MARK: - Main View
struct PlaylistDetailView: View {
    let playlist: Playlist
    let initialSongs: [Song]?
    
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
    
    init(playlist: Playlist, songs: [Song]? = nil) {
        self.playlist = playlist
        self.initialSongs = songs
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
            if SettingsManager.shared.coverBgPlaylist {
                PlaylistColorBackground(coverUrl: playlist.coverUrl?.sized(200))
            } else {
                MonologueBackground()
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
    
    private var playlistHeaderContent: some View {
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

    private func toolbarTrackCountView(_ count: Int) -> some View {
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
    
    private var filteredSongs: [Song] {
        viewModel.songs.filtered(by: searchText)
    }
    
    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                MonologueLoadingView(text: "LOADING TRACKS")
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
                
                Color.clear.frame(height: 100)
            }
        }
    }
    
    // MARK: - 相关歌单推荐
    
    private var relatedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("related_playlists"))
                .font(.rounded(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
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
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.monologueGlassTint)
                                        .monologueGlass(cornerRadius: 12)
                                }
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Text(rp.name)
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.monologueTextPrimary)
                                    .lineLimit(2)
                                    .frame(width: 130, height: 34, alignment: .topLeading)
                                
                                Text(rp.creatorName.isEmpty ? " " : rp.creatorName)
                                    .font(.rounded(size: 11))
                                    .foregroundColor(.monologueTextSecondary)
                                    .lineLimit(1)
                                    .frame(width: 130, alignment: .leading)
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
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


