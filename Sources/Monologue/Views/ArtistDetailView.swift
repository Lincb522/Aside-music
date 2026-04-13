import SwiftUI

// MARK: - 歌手详情页（参考ncm风格：大图 Hero + Tab 切换）

struct ArtistDetailView: View {
    let artistId: Int
    @State private var viewModel = ArtistDetailViewModel()
    @ObservedObject var playerManager = PlayerManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab = 0 // 0: 音乐, 1: 专辑, 2: 视频, 3: 相似
    @State private var showFullDescription = false
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var selectedMV: MVIdItem?
    @State private var headerImageHeight: CGFloat = 320
    @State private var scrollOffset: CGFloat = 0
    @State private var isArtistSelectMode = false
    @State private var artistSelectedSongIds: Set<Int> = []
    @State private var showArtistBatchPlaylist = false
    @State private var artistSongSearch = ""
    @State private var isArtistSongSearching = false

    // 从封面提取的颜色
    @State private var dominantColor: Color = .clear
    @State private var isAppeared = false

    var body: some View {
        ZStack {
            // 背景色
            (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero 大图区域（弹性拉伸）
                    heroSection

                    // 信息区域（名字、粉丝、关注按钮、播放按钮）
                    infoSection
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, -40)

                    // Tab 栏
                    tabBar
                        .padding(.top, 20)

                    // Tab 内容
                    tabContent
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                }
                .iPadContentWidth(900)
            }
            .scrollIndicators(.hidden)
            .monologueScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        .fullScreenCover(item: $selectedMV) { item in
            MVPlayerView(mvId: item.id)
        }
        .monologueSheet(isPresented: $showFullDescription, preset: .standard){
            ArtistBioSheet(viewModel: viewModel, artistId: artistId)
        }
        .onAppear {
            viewModel.loadData(artistId: artistId)
            withAnimation(.easeOut(duration: 0.5)) { isAppeared = true }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 { viewModel.loadAlbums(artistId: artistId) }
            if newTab == 2 { viewModel.loadMVs(artistId: artistId) }
            if newTab == 3 { viewModel.loadSimiArtists(artistId: artistId) }
        }
    }
}


// MARK: - Hero 大图

extension ArtistDetailView {

    private var heroSection: some View {
        let stretchHeight = headerImageHeight - scrollOffset
        
        return ZStack(alignment: .bottom) {
            // 歌手大图（弹性拉伸）
            if let artist = viewModel.artist, let coverUrl = artist.coverUrl?.sized(800) {
                CachedAsyncImage(url: coverUrl) {
                    Rectangle().fill(Color.monologueGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: stretchHeight)
                .clipped()
                .monologueBackgroundExtension()
            } else {
                Rectangle()
                    .fill(Color.monologueGlassTint)
                    .frame(height: stretchHeight)
            }

            // 底部渐变遮罩
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7")).opacity(0.6),
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: stretchHeight)
        }
        .frame(height: stretchHeight)
        .padding(.bottom, scrollOffset)
        .offset(y: scrollOffset)
    }
}

// MARK: - 信息区域

extension ArtistDetailView {

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.artist?.name ?? "")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(2)

            // 粉丝数 + 简介
            HStack(spacing: 16) {
                if viewModel.fansCount > 0 {
                    Text(String(format: NSLocalizedString("artist_fans_count", comment: ""), formatFansCount(viewModel.fansCount)))
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                }

                if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                    Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                }

                if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                    Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                        .font(.rounded(size: 13))
                        .foregroundColor(.monologueTextSecondary)
                }
            }

            // 简介（可点击展开）
            if let desc = viewModel.artist?.briefDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 4) {
                        Text(desc)
                            .font(.rounded(size: 13))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                        MonologueIcon(icon: .chevronRight, size: 10, color: .monologueTextSecondary)
                    }
                }
            }

            // 播放全部按钮
            HStack(spacing: 12) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .play, size: 14, color: .monologueIconForeground)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(.monologueIconForeground)
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.monologueIconBackground))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
                .disabled(viewModel.songs.isEmpty)

                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private func formatFansCount(_ count: Int) -> String {
        if count >= 10000 {
            let wan = Double(count) / 10000.0
            return wan >= 100 ? String(localized: "\(Int(wan))万") : String(format: String(localized: "%.1f万"), wan)
        }
        return "\(count)"
    }
}


// MARK: - Tab 栏

extension ArtistDetailView {

    private var tabBar: some View {
        HStack(spacing: 28) {
            tabItem(NSLocalizedString("artist_tab_music", comment: ""), index: 0)
            tabItem(NSLocalizedString("artist_tab_album", comment: ""), index: 1)
            tabItem(NSLocalizedString("artist_tab_video", comment: ""), index: 2)
            tabItem(NSLocalizedString("artist_tab_similar", comment: ""), index: 3)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tabItem(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.rounded(size: 17, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? .monologueTextPrimary : .monologueTextSecondary)

                Capsule()
                    .fill(selectedTab == index ? Color.monologueIconBackground : Color.clear)
                    .frame(width: 20, height: 3)
            }
        }
    }
}

// MARK: - Tab 内容

extension ArtistDetailView {

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            songsTab
        case 1:
            albumsTab
        case 2:
            mvsTab
        case 3:
            simiArtistsTab
        default:
            EmptyView()
        }
    }

    // MARK: 音乐 Tab

    private var artistSongFiltered: [Song] { viewModel.songs.filtered(by: artistSongSearch) }
    
    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                loadingPlaceholder
            } else if viewModel.songs.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_songs", comment: ""))
            } else {
                VStack(spacing: 0) {
                    PlaylistSearchBar(
                        searchText: $artistSongSearch,
                        isSearching: $isArtistSongSearching,
                        isSelectMode: $isArtistSelectMode,
                        selectedIds: $artistSelectedSongIds,
                        songs: artistSongFiltered,
                        onBatchQueue: {
                            let selected = artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) }
                            SongBatchActionHelper.addToQueue(selected) {
                                isArtistSelectMode = false
                                artistSelectedSongIds.removeAll()
                            }
                        },
                        onBatchDownload: { artistBatchDownload() },
                        onBatchCollect: { showArtistBatchPlaylist = true }
                    )
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(artistSongFiltered.enumerated()), id: \.element.id) { index, song in
                            SongListRow(song: song, index: index, isSelecting: isArtistSelectMode, isSelected: artistSelectedSongIds.contains(song.id), onArtistTap: { artistId in
                                selectedArtistId = artistId
                                showArtistDetail = true
                            }, onDetailTap: { detailSong in
                                selectedSongForDetail = detailSong
                                showSongDetail = true
                            }, onAlbumTap: { albumId in
                                selectedAlbumId = albumId
                                showAlbumDetail = true
                            }, onTap: {
                                if isArtistSelectMode {
                                    if artistSelectedSongIds.contains(song.id) {
                                        artistSelectedSongIds.remove(song.id)
                                    } else {
                                        artistSelectedSongIds.insert(song.id)
                                    }
                                } else {
                                    PlayerManager.shared.play(song: song, in: artistSongFiltered)
                                }
                            })
                        }
                    }
                }
                .padding(.vertical, 10)
                .monologueSheet(isPresented: $showArtistBatchPlaylist, preset: .standard){
                    BatchAddToPlaylistSheet(songs: artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) })
                }
            }
        }
    }
    
    private func artistBatchDownload() {
        let selected = artistSongFiltered.filter { artistSelectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: PlayerManager.shared.qqMusicQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: PlayerManager.shared.soundQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isArtistSelectMode = false; artistSelectedSongIds.removeAll() }
    }

    // MARK: 专辑 Tab

    private var albumsTab: some View {
        Group {
            if viewModel.isLoadingAlbums && viewModel.albums.isEmpty {
                loadingPlaceholder
            } else if viewModel.albums.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_albums", comment: ""))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.albums) { album in
                        albumRow(album)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }

    private func albumRow(_ album: AlbumInfo) -> some View {
        Button(action: {
            selectedAlbumId = album.id
            showAlbumDetail = true
        }) {
            HStack(spacing: 14) {
                // 专辑封面
                if let coverUrl = album.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: 10).fill(Color.monologueGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.monologueGlassTint)
                        .frame(width: 72, height: 72)
                        .overlay(MonologueIcon(icon: .album, size: 24, color: .monologueTextSecondary.opacity(0.3)))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(album.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !album.publishDateText.isEmpty {
                            Text(album.publishDateText)
                                .font(.rounded(size: 12))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        if let size = album.size, size > 0 {
                            Text("\(size) Tracks")
                                .font(.rounded(size: 12))
                                .foregroundColor(.monologueTextSecondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }

    // MARK: 视频 Tab

    private var mvsTab: some View {
        Group {
            if viewModel.isLoadingMVs && viewModel.mvs.isEmpty {
                loadingPlaceholder
            } else if viewModel.mvs.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_videos", comment: ""))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.mvs) { mv in
                        MVGridCard(mv: mv) {
                            selectedMV = MVIdItem(id: mv.id)
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }

    // MARK: 相似歌手 Tab

    private var simiArtistsTab: some View {
        Group {
            if viewModel.isLoadingSimi && viewModel.simiArtists.isEmpty {
                loadingPlaceholder
            } else if viewModel.simiArtists.isEmpty {
                emptyPlaceholder(NSLocalizedString("artist_no_similar", comment: ""))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.simiArtists) { artist in
                        Button(action: {
                            selectedArtistId = artist.id
                            showArtistDetail = true
                        }) {
                            VStack(spacing: 10) {
                                if let coverUrl = artist.coverUrl?.sized(300) {
                                    CachedAsyncImage(url: coverUrl) {
                                        Circle().fill(Color.monologueGlassTint)
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.monologueGlassTint)
                                        .frame(width: 90, height: 90)
                                        .overlay(MonologueIcon(icon: .personCircle, size: 32, color: .monologueTextSecondary.opacity(0.3)))
                                }
                                
                                Text(artist.name)
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.monologueTextPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }

    // MARK: 占位视图

    private var loadingPlaceholder: some View {
        VStack {
            Spacer().frame(height: 60)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .monologueTextSecondary))
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyPlaceholder(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Text(text)
                .font(.rounded(size: 15))
                .foregroundColor(.monologueTextSecondary)
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - 歌手简介 Sheet

struct ArtistBioSheet: View {
    var viewModel: ArtistDetailViewModel
    let artistId: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部：歌手头像 + 名字
            HStack(spacing: 14) {
                if let artist = viewModel.artist {
                    CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                        Circle().fill(Color.monologueGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.artist?.name ?? "")
                        .font(.rounded(size: 20, weight: .bold))
                        .foregroundColor(.monologueTextPrimary)

                    HStack(spacing: 12) {
                        if let albumSize = viewModel.artist?.albumSize, albumSize > 0 {
                            HStack(spacing: 4) {
                                MonologueIcon(icon: .album, size: 12, color: .monologueTextSecondary)
                                Text(String(format: NSLocalizedString("artist_album_count", comment: ""), albumSize))
                            }
                            .font(.rounded(size: 12))
                            .foregroundColor(.monologueTextSecondary)
                        }
                        if let musicSize = viewModel.artist?.musicSize, musicSize > 0 {
                            HStack(spacing: 4) {
                                MonologueIcon(icon: .musicNote, size: 12, color: .monologueTextSecondary)
                                Text(String(format: NSLocalizedString("artist_song_count", comment: ""), musicSize))
                            }
                            .font(.rounded(size: 12))
                            .foregroundColor(.monologueTextSecondary)
                        }
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: .monologueTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.monologueSeparator)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            if viewModel.isLoadingDesc {
                Spacer()
                MonologueLoadingView(text: "LOADING")
                Spacer()
            } else if let desc = viewModel.descResult {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let brief = desc.briefDesc, !brief.isEmpty {
                            bioCard {
                                Text(brief)
                                    .font(.rounded(size: 15, weight: .regular))
                                    .foregroundColor(.monologueTextPrimary)
                                    .lineSpacing(6)
                            }
                        }

                        ForEach(desc.sections) { section in
                            bioCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title)
                                        .font(.rounded(size: 16, weight: .semibold))
                                        .foregroundColor(.monologueTextPrimary)
                                    Text(section.content)
                                        .font(.rounded(size: 14, weight: .regular))
                                        .foregroundColor(.monologueTextSecondary)
                                        .lineSpacing(5)
                                }
                            }
                        }

                        if (desc.briefDesc ?? "").isEmpty && desc.sections.isEmpty {
                            noContentView
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let brief = viewModel.artist?.briefDesc, !brief.isEmpty {
                            bioCard {
                                Text(brief)
                                    .font(.rounded(size: 15, weight: .regular))
                                    .foregroundColor(.monologueTextPrimary)
                                    .lineSpacing(6)
                            }
                        } else {
                            noContentView
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            viewModel.loadDesc(artistId: artistId)
        }
    }

    private func bioCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .monologueGlass(cornerRadius: 20)
    }

    private var noContentView: some View {
        VStack(spacing: 14) {
            MonologueIcon(icon: .info, size: 36, color: .monologueTextSecondary.opacity(0.3))
            Text(LocalizedStringKey("artist_no_bio"))
                .font(.rounded(size: 15))
                .foregroundColor(.monologueTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
