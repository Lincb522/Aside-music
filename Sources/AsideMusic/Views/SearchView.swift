import SwiftUI

// MARK: - SearchView

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedPlaylist: Playlist?
    @State private var showPlaylistDetail = false
    @State private var selectedMVId: MVIdItem?
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @FocusState private var isFocused: Bool
    
    // QQ 音乐详情导航
    @State private var qqDetailType: QQDetailType?
    @State private var showQQDetail = false
    @State private var selectedQQMV: QQMVVidItem?
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                searchBarSection
                
                ZStack {
                    searchContentView
                    suggestionsOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showPlaylistDetail) {
            if let playlist = selectedPlaylist {
                PlaylistDetailView(playlist: playlist, songs: nil)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showQQDetail) {
            if let detail = qqDetailType {
                QQMusicDetailView(detailType: detail)
            } else {
                EmptyView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
        .fullScreenCover(item: $selectedMVId) { item in
            MVPlayerView(mvId: item.id)
        }
        .fullScreenCover(item: $selectedQQMV) { item in
            QQMVPlayerView(vid: item.vid)
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - 搜索栏
    
    private var searchBarSection: some View {
        VStack(spacing: 16) {
            HStack {
                AsideBackButton()
                
                Text(LocalizedStringKey("tab_search"))
                    .font(.rounded(size: 28, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, DeviceLayout.headerTopPadding)
            
            HStack(spacing: 12) {
                HStack {
                    AsideIcon(icon: .magnifyingGlass, size: 18, color: .gray)
                    
                    ZStack(alignment: .leading) {
                        // 默认搜索词（当输入框为空时显示）
                        if viewModel.query.isEmpty, let defaultKw = viewModel.defaultKeyword {
                            Text(defaultKw.showKeyword)
                                .font(.rounded(size: 16, weight: .medium))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                                .lineLimit(1)
                                .onTapWithHaptic {
                                    viewModel.performSearch(keyword: defaultKw.realkeyword)
                                    isFocused = false
                                }
                        }
                        
                        TextField("", text: $viewModel.query)
                            .foregroundColor(.asideTextPrimary)
                            .font(.rounded(size: 16, weight: .medium))
                            .focused($isFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                if !viewModel.query.isEmpty {
                                    viewModel.performSearch(keyword: viewModel.query)
                                } else if let defaultKw = viewModel.defaultKeyword {
                                    viewModel.performSearch(keyword: defaultKw.realkeyword)
                                }
                            }
                            .onChange(of: viewModel.query) { _, newValue in
                                if !newValue.isEmpty {
                                    if viewModel.hasSearched {
                                        viewModel.hasSearched = false
                                        viewModel.showSuggestions = true
                                    }
                                }
                            }
                    }
                    
                    if !viewModel.query.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            AsideIcon(icon: .xmark, size: 18, color: .gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 12)
    }

    // MARK: - 搜索类型 Tab 栏
    
    private var searchTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Button(action: {
                    viewModel.switchTab(tab)
                }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.rounded(size: 14, weight: viewModel.currentTab == tab ? .semibold : .regular))
                            .foregroundColor(viewModel.currentTab == tab ? .asideTextPrimary : .asideTextSecondary)
                        
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(viewModel.currentTab == tab ? Color.asideTextPrimary : Color.clear)
                            .frame(width: 20, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    // MARK: - 搜索内容区域
    
    @ViewBuilder
    private var searchContentView: some View {
        if viewModel.hasSearched {
            VStack(spacing: 0) {
                searchTabBar
                
                if viewModel.isLoading && viewModel.currentResultsEmpty {
                    Spacer()
                    AsideLoadingView(text: "SEARCHING")
                    Spacer()
                } else if viewModel.currentResultsEmpty {
                    Spacer()
                    emptyResultsView
                    Spacer()
                } else {
                    // 展开单平台 or 双列模式
                    if let expanded = viewModel.expandedSource {
                        expandedResultsView(source: expanded)
                    } else {
                        dualPlatformResultsView
                    }
                }
            }
        } else if viewModel.query.isEmpty {
            emptySearchView
        }
    }
    
    // MARK: - 双平台并列结果
    
    private var dualPlatformResultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // 最佳匹配卡片（暂时隐藏）
                // if let match = viewModel.multimatchResult {
                //     bestMatchSection(match: match)
                // }
                
                switch viewModel.currentTab {
                case .songs:
                    dualSongsSections
                case .artists:
                    dualArtistsSections
                case .playlists:
                    dualPlaylistsSections
                case .albums:
                    dualAlbumsSections
                case .mvs:
                    // 网易云 MV
                    platformSection(title: String(localized: "search_platform_netease"), source: .netease, isLoading: viewModel.isNeteaseLoading, count: viewModel.neteaseMVResults.count) {
                        mvsResultList(mvs: viewModel.neteaseMVResults)
                    }
                    // QQ 音乐 MV
                    platformSection(title: String(localized: "search_platform_qq"), source: .qqmusic, isLoading: viewModel.isQQLoading, count: viewModel.qqMVResults.count) {
                        qqMVsResultList(mvs: viewModel.qqMVResults)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .simultaneousGesture(DragGesture().onChanged { _ in
            isFocused = false
        })
    }
    
    // MARK: - 双平台单曲
    
    private var dualSongsSections: some View {
        VStack(spacing: 20) {
            // 网易云
            platformSection(title: String(localized: "search_platform_netease"), source: .netease, isLoading: viewModel.isNeteaseLoading, count: viewModel.neteaseResults.count) {
                ForEach(Array(viewModel.neteaseResults.prefix(5).enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, onArtistTap: { artistId in
                        selectedArtistId = artistId
                        showArtistDetail = true
                    }, onDetailTap: { detailSong in
                        selectedSongForDetail = detailSong
                        showSongDetail = true
                    }, onAlbumTap: { albumId in
                        selectedAlbumId = albumId
                        showAlbumDetail = true
                    })
                    .asButton {
                        PlayerManager.shared.play(song: song, in: viewModel.neteaseResults)
                        isFocused = false
                    }
                }
            }
            
            // QQ 音乐
            platformSection(title: String(localized: "search_platform_qq"), source: .qqmusic, isLoading: viewModel.isQQLoading, count: viewModel.qqResults.count) {
                ForEach(Array(viewModel.qqResults.prefix(5).enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, onArtistTap: { _ in }, onDetailTap: { detailSong in
                        selectedSongForDetail = detailSong
                        showSongDetail = true
                    }, onAlbumTap: { _ in })
                    .asButton {
                        PlayerManager.shared.play(song: song, in: viewModel.qqResults)
                        isFocused = false
                    }
                }
            }
        }
    }
    
    // MARK: - 双平台歌手
    
    private var dualArtistsSections: some View {
        VStack(spacing: 20) {
            platformSection(title: String(localized: "search_platform_netease"), source: .netease, isLoading: viewModel.isNeteaseLoading, count: viewModel.neteaseArtistResults.count) {
                ForEach(viewModel.neteaseArtistResults.prefix(5)) { artist in
                    artistRow(artist: artist)
                }
            }
            
            platformSection(title: String(localized: "search_platform_qq"), source: .qqmusic, isLoading: viewModel.isQQLoading, count: viewModel.qqArtistResults.count) {
                ForEach(viewModel.qqArtistResults.prefix(5)) { artist in
                    artistRow(artist: artist)
                }
            }
        }
    }
    
    // MARK: - 双平台歌单
    
    private var dualPlaylistsSections: some View {
        VStack(spacing: 20) {
            platformSection(title: String(localized: "search_platform_netease"), source: .netease, isLoading: viewModel.isNeteaseLoading, count: viewModel.neteasePlaylistResults.count) {
                ForEach(viewModel.neteasePlaylistResults.prefix(5)) { playlist in
                    playlistRow(playlist: playlist)
                }
            }
            
            platformSection(title: String(localized: "search_platform_qq"), source: .qqmusic, isLoading: viewModel.isQQLoading, count: viewModel.qqPlaylistResults.count) {
                ForEach(viewModel.qqPlaylistResults.prefix(5)) { playlist in
                    playlistRow(playlist: playlist)
                }
            }
        }
    }
    
    // MARK: - 双平台专辑
    
    private var dualAlbumsSections: some View {
        VStack(spacing: 20) {
            platformSection(title: String(localized: "search_platform_netease"), source: .netease, isLoading: viewModel.isNeteaseLoading, count: viewModel.neteaseAlbumResults.count) {
                ForEach(viewModel.neteaseAlbumResults.prefix(5)) { album in
                    albumRow(album: album)
                }
            }
            
            platformSection(title: String(localized: "search_platform_qq"), source: .qqmusic, isLoading: viewModel.isQQLoading, count: viewModel.qqAlbumResults.count) {
                ForEach(viewModel.qqAlbumResults.prefix(5)) { album in
                    albumRow(album: album)
                }
            }
        }
    }

    // MARK: - 平台 Section 容器
    
    private func platformSection<Content: View>(
        title: String,
        source: MusicSource,
        isLoading: Bool = false,
        count: Int = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 平台标题栏
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                
                Spacer()
                
                if count > 5 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.expandedSource = source
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey("view_all"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            AsideIcon(icon: .chevronRight, size: 10, color: .asideTextSecondary)
                        }
                        .foregroundColor(.asideTextSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            
            if isLoading && count == 0 {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if count == 0 {
                Text(LocalizedStringKey("search_no_results"))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.asideTextSecondary.opacity(0.6))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            } else {
                content()
            }
        }
    }
    
    // MARK: - 展开单平台全屏列表
    
    private func expandedResultsView(source: MusicSource) -> some View {
        VStack(spacing: 0) {
            // 返回双列模式按钮
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.expandedSource = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        AsideIcon(icon: .chevronLeft, size: 14, color: .asideTextPrimary)
                        Text(source == .netease ? String(localized: "search_platform_netease") : String(localized: "search_platform_qq"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    switch viewModel.currentTab {
                    case .songs:
                        expandedSongsList(source: source)
                    case .artists:
                        expandedArtistsList(source: source)
                    case .playlists:
                        expandedPlaylistsList(source: source)
                    case .albums:
                        expandedAlbumsList(source: source)
                    case .mvs:
                        if source == .netease {
                            expandedMVsList
                        } else {
                            expandedQQMVsList
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .simultaneousGesture(DragGesture().onChanged { _ in
                isFocused = false
            })
        }
    }
    
    // MARK: - 展开歌曲列表
    
    private func expandedSongsList(source: MusicSource) -> some View {
        let songs = source == .netease ? viewModel.neteaseResults : viewModel.qqResults
        return ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
            SongListRow(song: song, index: index, onArtistTap: { artistId in
                selectedArtistId = artistId
                showArtistDetail = true
            }, onDetailTap: { detailSong in
                selectedSongForDetail = detailSong
                showSongDetail = true
            }, onAlbumTap: { albumId in
                selectedAlbumId = albumId
                showAlbumDetail = true
            })
            .asButton {
                PlayerManager.shared.play(song: song, in: songs)
                isFocused = false
            }
            .onAppear {
                if index == songs.count - 3 {
                    viewModel.loadMore(source: source)
                }
            }
        }
    }
    
    // MARK: - 展开歌手列表
    
    private func expandedArtistsList(source: MusicSource) -> some View {
        let artists = source == .netease ? viewModel.neteaseArtistResults : viewModel.qqArtistResults
        return ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
            artistRow(artist: artist)
                .onAppear {
                    if index == artists.count - 3 {
                        viewModel.loadMore(source: source)
                    }
                }
        }
    }
    
    // MARK: - 展开歌单列表
    
    private func expandedPlaylistsList(source: MusicSource) -> some View {
        let playlists = source == .netease ? viewModel.neteasePlaylistResults : viewModel.qqPlaylistResults
        return ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
            playlistRow(playlist: playlist)
                .onAppear {
                    if index == playlists.count - 3 {
                        viewModel.loadMore(source: source)
                    }
                }
        }
    }
    
    // MARK: - 展开专辑列表
    
    private func expandedAlbumsList(source: MusicSource) -> some View {
        let albums = source == .netease ? viewModel.neteaseAlbumResults : viewModel.qqAlbumResults
        return ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
            albumRow(album: album)
                .onAppear {
                    if index == albums.count - 3 {
                        viewModel.loadMore(source: source)
                    }
                }
        }
    }
    
    // MARK: - 展开 MV 列表（仅网易云）
    
    private var expandedMVsList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(viewModel.neteaseMVResults.enumerated()), id: \.element.id) { index, mv in
                MVGridCard(mv: mv) {
                    selectedMVId = MVIdItem(id: mv.id)
                    isFocused = false
                }
                .onAppear {
                    if index == viewModel.neteaseMVResults.count - 3 {
                        viewModel.loadMore(source: .netease)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - 通用行组件
    
    private func artistRow(artist: ArtistInfo) -> some View {
        Button(action: {
            if artist.isQQMusic, let mid = artist.qqMid {
                qqDetailType = .artist(mid: mid, name: artist.name, coverUrl: artist.coverUrl?.absoluteString)
                showQQDetail = true
            } else {
                selectedArtistId = artist.id
                showArtistDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                    Circle().fill(Color.asideCardBackground)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let albumSize = artist.albumSize, albumSize > 0 {
                            Text(String(format: String(localized: "search_album_count"), albumSize))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.asideTextSecondary)
                        }
                        if let musicSize = artist.musicSize, musicSize > 0 {
                            Text(String(format: String(localized: "search_song_count"), musicSize))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                }
                
                Spacer()
                
                AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func playlistRow(playlist: Playlist) -> some View {
        Button(action: {
            if playlist.isQQMusic {
                qqDetailType = .playlist(id: playlist.id, name: playlist.name, coverUrl: playlist.coverUrl?.absoluteString, creatorName: playlist.creator?.nickname)
                showQQDetail = true
            } else {
                selectedPlaylist = playlist
                showPlaylistDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.asideCardBackground)
                }
                .frame(width: 56, height: 56)
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let trackCount = playlist.trackCount, trackCount > 0 {
                            Text(String(format: String(localized: "search_track_count"), trackCount))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.asideTextSecondary)
                        }
                        if let creator = playlist.creator?.nickname {
                            Text("by \(creator)")
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.asideTextSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func albumRow(album: SearchAlbum) -> some View {
        Button(action: {
            if album.isQQMusic, let mid = album.qqMid {
                qqDetailType = .album(mid: mid, name: album.name, coverUrl: album.coverUrl?.absoluteString, artistName: album.artistName)
                showQQDetail = true
            } else {
                selectedAlbumId = album.id
                showAlbumDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: album.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.asideCardBackground)
                }
                .frame(width: 56, height: 56)
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(album.artistName)
                            .font(.rounded(size: 12, weight: .regular))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                        
                        if let size = album.size, size > 0 {
                            Text(String(format: String(localized: "search_track_count"), size))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                }
                
                Spacer()
                
                AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func mvsResultList(mvs: [MV]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(mvs.prefix(4)) { mv in
                MVGridCard(mv: mv) {
                    selectedMVId = MVIdItem(id: mv.id)
                    isFocused = false
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }
    
    // MARK: - QQ MV 结果列表
    
    private func qqMVsResultList(mvs: [QQMV]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(mvs.prefix(4)) { mv in
                qqMVGridCard(mv: mv)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }
    
    // MARK: - QQ MV 网格卡片
    
    private func qqMVGridCard(mv: QQMV) -> some View {
        Button(action: {
            selectedQQMV = QQMVVidItem(vid: mv.vid)
            isFocused = false
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.asideTextSecondary.opacity(0.06))
                        }
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.asideTextSecondary.opacity(0.06))
                            .frame(height: 100)
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                    
                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mv.name)
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(mv.singerName ?? String(localized: "search_unknown_artist"))
                            .font(.rounded(size: 12))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                        
                        if !mv.playCountText.isEmpty {
                            Circle()
                                .fill(Color.asideTextSecondary.opacity(0.3))
                                .frame(width: 3, height: 3)
                            Text(mv.playCountText + String(localized: "search_play_count_suffix"))
                                .font(.rounded(size: 11))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
    }
    
    // MARK: - 展开 QQ MV 列表
    
    private var expandedQQMVsList: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(viewModel.qqMVResults.enumerated()), id: \.element.id) { index, mv in
                qqMVGridCard(mv: mv)
                    .onAppear {
                        if index == viewModel.qqMVResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - 最佳匹配卡片
    
    private func bestMatchSection(match: SearchMultimatchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("search_best_match"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if let artist = match.artist {
                        bestMatchCard(
                            imageUrl: artist.coverUrl?.sized(200),
                            title: artist.name,
                            subtitle: String(localized: "search_type_artist"),
                            isCircle: true
                        ) {
                            selectedArtistId = artist.id
                            showArtistDetail = true
                        }
                    }
                    
                    if let album = match.album {
                        bestMatchCard(
                            imageUrl: album.coverUrl?.sized(200),
                            title: album.name,
                            subtitle: album.artistName,
                            isCircle: false
                        ) {
                            selectedAlbumId = album.id
                            showAlbumDetail = true
                        }
                    }
                    
                    if let playlist = match.playlist {
                        bestMatchCard(
                            imageUrl: playlist.coverUrl?.sized(200),
                            title: playlist.name,
                            subtitle: playlist.creator?.nickname ?? "",
                            isCircle: false
                        ) {
                            selectedPlaylist = playlist
                            showPlaylistDetail = true
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 4)
    }
    
    private func bestMatchCard(
        imageUrl: URL?,
        title: String,
        subtitle: String,
        isCircle: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: imageUrl) {
                    RoundedRectangle(cornerRadius: isCircle ? 25 : 10)
                        .fill(Color.asideCardBackground)
                }
                .frame(width: 50, height: 50)
                .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 10)))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary.opacity(0.5))
            }
            .padding(12)
            .frame(width: 220)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.asideGlassOverlay)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
    }
    
    // MARK: - 空结果提示
    
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            AsideIcon(icon: .musicNoteList, size: 50, color: .gray.opacity(0.3))
            Text(LocalizedStringKey("empty_no_results"))
                .font(.rounded(size: 16, weight: .medium))
                .foregroundColor(.asideTextSecondary)
        }
    }

    // MARK: - 搜索历史 & 热搜
    
    private var emptySearchView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 搜索历史
                if !viewModel.searchHistory.isEmpty {
                    HStack {
                        Text(LocalizedStringKey("search_history"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.clearAllHistory()
                        }) {
                            AsideIcon(icon: .trash, size: 16, color: .asideTextSecondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ForEach(viewModel.searchHistory, id: \.id) { item in
                        Button(action: {
                            viewModel.performSearch(keyword: item.keyword)
                            isFocused = false
                        }) {
                            HStack(spacing: 14) {
                                AsideIcon(icon: .clock, size: 16, color: .asideTextSecondary)
                                
                                Text(item.keyword)
                                    .font(.rounded(size: 16, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.deleteHistoryItem(keyword: item.keyword)
                                }) {
                                    AsideIcon(icon: .xmark, size: 12, color: .asideTextSecondary.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // 热门搜索
                if !viewModel.hotSearchItems.isEmpty {
                    Text(LocalizedStringKey("search_hot"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(Array(viewModel.hotSearchItems.prefix(20).enumerated()), id: \.offset) { index, item in
                            Button(action: {
                                viewModel.performSearch(keyword: item.searchWord)
                                isFocused = false
                            }) {
                                Text(item.searchWord)
                                    .font(.rounded(size: 14, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 120)
        }
    }

    // MARK: - 搜索建议浮层
    
    @ViewBuilder
    private var suggestionsOverlay: some View {
        if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
            AsideBackground()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button(action: {
                            viewModel.performSearch(keyword: suggestion)
                            isFocused = false
                        }) {
                            HStack(spacing: 16) {
                                AsideIcon(icon: .magnifyingGlass, size: 16, color: .gray)
                                
                                Text(suggestion)
                                    .font(.rounded(size: 16, weight: .regular))
                                    .foregroundColor(.asideTextPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 10)
            }
            .asideBackground()
        }
    }
}
