import SwiftUI
import Combine
import QQMusicKit

// MARK: - QQ 歌手详情页（Hero 大图 + Tab）

struct QQArtistDetailView: View {
    let mid: String
    let name: String
    let coverUrl: String?
    
    @StateObject private var viewModel: QQArtistDetailViewModel
    
    @State private var selectedTab = 0
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedQQMV: QQMVVidItem?
    @State private var selectedAlbumMid: String?
    @State private var selectedAlbumName: String?
    @State private var selectedAlbumCover: String?
    @State private var selectedAlbumArtist: String?
    @State private var showAlbumDetail = false
    @State private var showFullDescription = false
    @State private var artistSearchText = ""
    @State private var isArtistSearching = false
    @State private var isArtistSelectMode = false
    @State private var artistSelectedIds: Set<String> = []
    @State private var showArtistBatchPlaylist = false

    
    init(mid: String, name: String, coverUrl: String?) {
        self.mid = mid
        self.name = name
        self.coverUrl = coverUrl
        _viewModel = StateObject(wrappedValue: QQArtistDetailViewModel(mid: mid))
    }
    
    private var displayName: String { viewModel.resolvedName ?? name }
    
    private var displayCoverUrl: URL? {
        if let resolved = viewModel.resolvedCoverUrl, let url = URL(string: resolved) { return url }
        if let c = coverUrl, let url = URL(string: c) { return url }
        return nil
    }
    
    var body: some View {
        ArtistDetailPage(
            identity: ArtistNameArtworkIdentity(name: displayName, aliases: [], qqMid: mid),
            coverURL: displayCoverUrl,
            source: MusicSource.qqmusic.shortName,
            fansCount: viewModel.fansCount,
            summary: viewModel.resolvedDesc,
            tabs: [
                ArtistDetailTab(id: 0, title: String(localized: "artist_tab_songs"), count: viewModel.songCount),
                ArtistDetailTab(id: 1, title: String(localized: "artist_tab_album"), count: viewModel.albumCount),
                ArtistDetailTab(id: 2, title: String(localized: "artist_tab_video"))
            ],
            selectedTab: $selectedTab,
            canPlay: !viewModel.songs.isEmpty,
            play: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            },
            secondaryAction: { showArtistBatchPlaylist = true },
            showBiography: { showFullDescription = true }
        ) {
            tabContent
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumMid = selectedAlbumMid {
                QQMusicDetailView(detailType: .album(
                    mid: albumMid,
                    name: selectedAlbumName ?? "",
                    coverUrl: selectedAlbumCover,
                    artistName: selectedAlbumArtist
                ))
            } else {
                EmptyView()
            }
        }
        .fullScreenCover(item: $selectedQQMV) { item in
            QQMVPlayerView(vid: item.vid)
        }
        .monoSheet(isPresented: $showFullDescription, preset: .standard){
            if let desc = viewModel.resolvedDesc {
                QQArtistBioSheet(name: displayName, coverUrl: displayCoverUrl, desc: desc)
            }
        }
        .monoSheet(isPresented: $showArtistBatchPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: isArtistSelectMode ? artistFilteredSongs.filter { artistSelectedIds.contains($0.identityKey) } : viewModel.songs)
        }
        .onAppear {
            viewModel.loadSongs()
            viewModel.loadInfo()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 { viewModel.loadAlbums() }
            if newTab == 2 { viewModel.loadMVs() }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: songsTab
        case 1: albumsTab
        case 2: mvsTab
        default: EmptyView()
        }
    }
    
    private var artistFilteredSongs: [Song] {
        viewModel.songs.filtered(by: artistSearchText)
    }
    
    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                ArtistContentState(isLoading: true, text: "")
            } else if viewModel.songs.isEmpty {
                ArtistContentState(text: String(localized: "qq_no_songs"))
            } else {
                VStack(spacing: 0) {
                    ArtistSongToolbar(
                        searchText: $artistSearchText,
                        isSearching: $isArtistSearching,
                        onSearchActivated: { viewModel.loadAllSongs() },
                        isSelectMode: $isArtistSelectMode,
                        selectedIds: $artistSelectedIds,
                        songs: artistFilteredSongs,
                        onBatchQueue: {
                            let selected = artistFilteredSongs.filter { artistSelectedIds.contains($0.identityKey) }
                            SongBatchActionHelper.addToQueue(selected) {
                                isArtistSelectMode = false
                                artistSelectedIds.removeAll()
                            }
                        },
                        onBatchDownload: { batchDownload(from: artistFilteredSongs, ids: artistSelectedIds, reset: { isArtistSelectMode = false; artistSelectedIds.removeAll() }) },
                        onBatchCollect: { showArtistBatchPlaylist = true }
                    )
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(artistFilteredSongs.enumerated()), id: \.element.identityKey) { index, song in
                            SongListRow(song: song, index: index, isSelecting: isArtistSelectMode, isSelected: artistSelectedIds.contains(song.identityKey), onArtistTap: { _ in }, onDetailTap: { s in
                                selectedSongForDetail = s
                                showSongDetail = true
                            }, onAlbumTap: { _ in }, onTap: {
                                if isArtistSelectMode {
                                    if artistSelectedIds.contains(song.identityKey) {
                                        artistSelectedIds.remove(song.identityKey)
                                    } else {
                                        artistSelectedIds.insert(song.identityKey)
                                    }
                                } else {
                                    PlayerManager.shared.play(song: song, in: artistFilteredSongs)
                                }
                            }, usesArtistStyle: true)
                            .onAppear {
                                if !isArtistSearching && index == viewModel.songs.count - 3 { viewModel.loadMoreSongs() }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var albumsTab: some View {
        if viewModel.isLoadingAlbums && viewModel.albums.isEmpty {
            ArtistContentState(isLoading: true, text: "")
        } else if viewModel.albums.isEmpty {
            ArtistContentState(text: String(localized: "qq_no_albums"))
        } else {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.albums) { album in
                    ArtistAlbumRow(album: album) {
                        selectedAlbumMid = album.qqAlbumMid ?? extractMidFromPicUrl(album.picUrl)
                        selectedAlbumName = album.name
                        selectedAlbumCover = album.picUrl
                        selectedAlbumArtist = album.artistName
                        showAlbumDetail = true
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var mvsTab: some View {
        if viewModel.isLoadingMVs && viewModel.mvs.isEmpty {
            ArtistContentState(isLoading: true, text: "")
        } else if viewModel.mvs.isEmpty {
            ArtistContentState(text: String(localized: "qq_no_videos"))
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                ForEach(viewModel.mvs) { mv in
                    ArtistVideoCard(name: mv.name, coverURL: mv.coverUrl.flatMap(URL.init(string:)), duration: mv.durationText) {
                        selectedQQMV = QQMVVidItem(vid: mv.vid)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func extractMidFromPicUrl(_ picUrl: String?) -> String {
        guard let url = picUrl else { return "" }
        // 匹配 M000 后面到 .jpg 之间的字符串
        if let range = url.range(of: "M000") {
            let afterM000 = url[range.upperBound...]
            if let dotRange = afterM000.range(of: ".") {
                return String(afterM000[..<dotRange.lowerBound])
            }
        }
        return ""
    }
    
    private func batchDownload(from songs: [Song], ids: Set<String>, reset: @escaping () -> Void) {
        let selected = songs.filter { ids.contains($0.identityKey) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "download_batch_added_title"), message: L10n.format("download_batch_queue_added_format", selected.count), primaryButtonTitle: String(localized: "common_confirm"), primaryAction: {})
        withAnimation { reset() }
    }
}
