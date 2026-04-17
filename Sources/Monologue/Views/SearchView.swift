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
    @Environment(\.dismiss) private var dismiss
    @State private var showAlbumDetail = false
    @FocusState private var isFocused: Bool
    @State private var isSearchBarExpanded: Bool = true
    
    // qcm详情导航
    @State private var qqDetailType: QQDetailType?
    @State private var showQQDetail = false
    @State private var selectedQQMV: QQMVVidItem?
    @State private var isSearchSelectMode = false
    @State private var searchSelectedIds: Set<Int> = []
    @State private var showSearchBatchPlaylist = false
    @State private var searchFilterText = ""
    @State private var isSearchFiltering = false
    
    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                searchBarSection
                
                ZStack {
                    searchContentView
                    suggestionsOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .iPadContentWidth()
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
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
        let showFullSearch = !viewModel.hasSearched || isSearchBarExpanded
        
        return HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.monologueTextPrimary.opacity(0.04))
                    .clipShape(Circle())
                    .liquidGlassStyle(cornerRadius: 21)
                    .overlay(
                        Circle().stroke(Color.monologueTextPrimary.opacity(0.05), lineWidth: 0.5)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            if !showFullSearch {
                Spacer(minLength: 0)
            }

            HStack(spacing: showFullSearch ? 8 : 0) {
                MonologueIcon(icon: .magnifyingGlass, size: 18, color: .gray)
                
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        if viewModel.query.isEmpty, let defaultKw = viewModel.defaultKeyword {
                            Text(defaultKw.showKeyword)
                                .font(.rounded(size: 16, weight: .medium))
                                .foregroundColor(.monologueTextSecondary.opacity(0.6))
                                .lineLimit(1)
                                .onTapWithHaptic {
                                    viewModel.performSearch(keyword: defaultKw.realkeyword)
                                    isFocused = false
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchBarExpanded = false
                                    }
                                }
                        }
                        
                        TextField("", text: $viewModel.query)
                            .foregroundColor(.monologueTextPrimary)
                            .font(.rounded(size: 16, weight: .medium))
                            .monologueTextInputBehavior()
                            .focused($isFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                if !viewModel.query.isEmpty {
                                    viewModel.performSearch(keyword: viewModel.query)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchBarExpanded = false
                                    }
                                } else if let defaultKw = viewModel.defaultKeyword {
                                    viewModel.performSearch(keyword: defaultKw.realkeyword)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isSearchBarExpanded = false
                                    }
                                }
                            }
                    }
                    
                    if !viewModel.query.isEmpty {
                        Button(action: {
                            viewModel.query = ""
                            isFocused = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isSearchBarExpanded = false
                            }
                        }) {
                            MonologueIcon(icon: .xmark, size: 18, color: .gray)
                        }
                        .padding(.leading, 8)
                    }
                }
                .frame(maxWidth: showFullSearch ? .infinity : 0)
                .opacity(showFullSearch ? 1 : 0)
                .clipped()
            }
            .padding(.horizontal, showFullSearch ? 16 : 12)
            .padding(.vertical, showFullSearch ? 10 : 12)
            .liquidGlassStyle(cornerRadius: showFullSearch ? 16 : 21)
            .onTapGesture {
                if !showFullSearch {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSearchBarExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isFocused = true
                    }
                }
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .onChange(of: viewModel.hasSearched) { searched in
            if !searched {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearchBarExpanded = true
                }
            }
        }
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
                            .font(.rounded(size: 14, weight: viewModel.currentTab == tab ? .bold : .medium))
                            .foregroundColor(viewModel.currentTab == tab ? .monologueTextPrimary : .monologueTextSecondary)
                            .animation(.none, value: viewModel.currentTab)
                        
                        Capsule()
                            .fill(Color.monologueTextPrimary)
                            .frame(width: 24, height: 3)
                            .opacity(viewModel.currentTab == tab ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentTab)
    }

    // MARK: - 搜索内容区域
    
    @ViewBuilder
    private var searchContentView: some View {
        if viewModel.hasSearched {
            VStack(spacing: 0) {
                searchTabBar
                platformTabBar
                
                let platformLoading = isPlatformLoading
                let platformEmpty = isPlatformEmpty
                
                if platformLoading && platformEmpty {
                    Spacer()
                    MonologueLoadingView(text: "SEARCHING")
                    Spacer()
                } else if platformEmpty {
                    Spacer()
                    emptyResultsView
                    Spacer()
                } else {
                    if viewModel.currentTab == .songs {
                        searchSongsToolbarView
                    }
                    platformResultsView
                }
            }
        } else if viewModel.query.isEmpty {
            emptySearchView
        }
    }
    
    // MARK: - 歌曲列表工具栏
    
    @ViewBuilder
    private var searchSongsToolbarView: some View {
        let currentSource = viewModel.selectedPlatform
        let currentSongs = expandedFilteredSongs(source: currentSource)
        
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: currentSongs,
                    onBatchQueue: {
                        let selected = currentSongs.filter { searchSelectedIds.contains($0.id) }
                        SongBatchActionHelper.addToQueue(selected) {
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                        }
                    },
                    onBatchDownload: { searchBatchDownload(source: currentSource) },
                    onBatchCollect: { showSearchBatchPlaylist = true }
                )
            } else if isSearchFiltering {
                HStack(spacing: 8) {
                    PlaylistSearchBar(
                        searchText: $searchFilterText,
                        isSearching: $isSearchFiltering
                    )
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    Button(action: {
                        if !currentSongs.isEmpty {
                            viewModel.playAllSongs(source: currentSource, currentSongs: currentSongs)
                        }
                    }) {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: .play, size: 14, color: Color(UIColor.systemBackground))
                                .frame(width: 24, height: 24)
                                .background(Color.monologueTextPrimary)
                                .clipShape(Circle())
                            
                            Text(String(localized: "artist_play_all"))
                                .font(.rounded(size: 14, weight: .semibold))
                                .foregroundColor(.monologueTextPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.monologueTextPrimary.opacity(0.04))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFiltering = true
                        }
                    } label: {
                        MonologueIcon(icon: .search, size: 15, color: .monologueTextSecondary)
                            .frame(width: 30, height: 30)
                            .background(Color.monologueTextPrimary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchSelectMode = true
                            searchSelectedIds.removeAll()
                        }
                    } label: {
                        MonologueIcon(icon: .checkmark, size: 15, color: .monologueTextSecondary)
                            .frame(width: 30, height: 30)
                            .background(Color.monologueTextPrimary.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - 平台标签页

    private var platformTabBar: some View {
        let platforms: [MusicSource] = viewModel.currentTab == .songs
            ? [.netease, .qqmusic, .qishui]
            : [.netease, .qqmusic]
        return HStack(spacing: 0) {
            ForEach(platforms, id: \.self) { platform in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedPlatform = platform
                    }
                }) {
                    Text(platformTabName(platform))
                        .font(.rounded(size: 13, weight: viewModel.selectedPlatform == platform ? .bold : .medium))
                        .foregroundColor(viewModel.selectedPlatform == platform ? .monologueTextPrimary : .monologueTextSecondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            viewModel.selectedPlatform == platform
                                ? Capsule().fill(Color.monologueTextPrimary.opacity(0.08))
                                : nil
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 4)
    }
    
    private func platformTabName(_ source: MusicSource) -> String {
        switch source {
        case .netease: return "NCM"
        case .qqmusic: return "QCM"
        case .qishui: return "QSM"
        case .local: return "Local"
        }
    }
    
    private var isPlatformLoading: Bool {
        switch viewModel.selectedPlatform {
        case .netease: return viewModel.isNeteaseLoading
        case .qqmusic: return viewModel.isQQLoading
        case .qishui: return viewModel.isQishuiLoading
        case .local: return false
        }
    }
    
    private var isPlatformEmpty: Bool {
        switch viewModel.selectedPlatform {
        case .netease:
            switch viewModel.currentTab {
            case .songs: return viewModel.neteaseResults.isEmpty
            case .artists: return viewModel.neteaseArtistResults.isEmpty
            case .playlists: return viewModel.neteasePlaylistResults.isEmpty
            case .albums: return viewModel.neteaseAlbumResults.isEmpty
            case .mvs: return viewModel.neteaseMVResults.isEmpty
            }
        case .qqmusic:
            switch viewModel.currentTab {
            case .songs: return viewModel.qqResults.isEmpty
            case .artists: return viewModel.qqArtistResults.isEmpty
            case .playlists: return viewModel.qqPlaylistResults.isEmpty
            case .albums: return viewModel.qqAlbumResults.isEmpty
            case .mvs: return viewModel.qqMVResults.isEmpty
            }
        case .qishui: return viewModel.qishuiResults.isEmpty
        case .local: return true
        }
    }
    
    // MARK: - 平台结果列表
    
    private var platformResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch viewModel.selectedPlatform {
                case .netease:
                    neteaseResultsContent
                case .qqmusic:
                    qqResultsContent
                case .qishui:
                    qishuiResultsContent
                case .local:
                    EmptyView()
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .simultaneousGesture(DragGesture().onChanged { _ in
            isFocused = false
        })
    }
    
    @ViewBuilder
    private var neteaseResultsContent: some View {
        switch viewModel.currentTab {
        case .songs:
            expandedSongsList(source: .netease)
        case .artists:
            ForEach(Array(viewModel.neteaseArtistResults.enumerated()), id: \.element.id) { index, artist in
                artistRow(artist: artist)
                    .onAppear {
                        if index == viewModel.neteaseArtistResults.count - 3 {
                            viewModel.loadMore(source: .netease)
                        }
                    }
            }
        case .playlists:
            ForEach(Array(viewModel.neteasePlaylistResults.enumerated()), id: \.element.id) { index, playlist in
                playlistRow(playlist: playlist)
                    .onAppear {
                        if index == viewModel.neteasePlaylistResults.count - 3 {
                            viewModel.loadMore(source: .netease)
                        }
                    }
            }
        case .albums:
            ForEach(Array(viewModel.neteaseAlbumResults.enumerated()), id: \.element.id) { index, album in
                albumRow(album: album)
                    .onAppear {
                        if index == viewModel.neteaseAlbumResults.count - 3 {
                            viewModel.loadMore(source: .netease)
                        }
                    }
            }
        case .mvs:
            let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 16) {
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
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var qqResultsContent: some View {
        switch viewModel.currentTab {
        case .songs:
            expandedSongsList(source: .qqmusic)
        case .artists:
            ForEach(Array(viewModel.qqArtistResults.enumerated()), id: \.element.id) { index, artist in
                artistRow(artist: artist)
                    .onAppear {
                        if index == viewModel.qqArtistResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        case .playlists:
            ForEach(Array(viewModel.qqPlaylistResults.enumerated()), id: \.element.id) { index, playlist in
                playlistRow(playlist: playlist)
                    .onAppear {
                        if index == viewModel.qqPlaylistResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        case .albums:
            ForEach(Array(viewModel.qqAlbumResults.enumerated()), id: \.element.id) { index, album in
                albumRow(album: album)
                    .onAppear {
                        if index == viewModel.qqAlbumResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        case .mvs:
            let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(viewModel.qqMVResults.enumerated()), id: \.element.id) { index, mv in
                    qqMVGridCard(mv: mv)
                        .onAppear {
                            if index == viewModel.qqMVResults.count - 3 {
                                viewModel.loadMore(source: .qqmusic)
                            }
                        }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var qishuiResultsContent: some View {
        if viewModel.currentTab == .songs {
            expandedSongsList(source: .qishui)
        } else {
            EmptyView()
        }
    }
    
    // MARK: - (旧双列代码已移除，改为标签页模式)
    
    // MARK: - 展开单平台全屏列表
    
    private func expandedResultsView(source: MusicSource) -> some View {
        VStack(spacing: 0) {
            if isSearchSelectMode {
                PlaylistSearchBar(
                    searchText: $searchFilterText,
                    isSearching: $isSearchFiltering,
                    isSelectMode: $isSearchSelectMode,
                    selectedIds: $searchSelectedIds,
                    songs: expandedFilteredSongs(source: source),
                    onBatchQueue: {
                        let selected = expandedFilteredSongs(source: source).filter { searchSelectedIds.contains($0.id) }
                        SongBatchActionHelper.addToQueue(selected) {
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                        }
                    },
                    onBatchDownload: { searchBatchDownload(source: source) },
                    onBatchCollect: { showSearchBatchPlaylist = true }
                )
            } else if isSearchFiltering {
                HStack(spacing: 8) {
                    PlaylistSearchBar(
                        searchText: $searchFilterText,
                        isSearching: $isSearchFiltering
                    )
                }
            } else {
                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.expandedSource = nil
                            isSearchSelectMode = false
                            searchSelectedIds.removeAll()
                            searchFilterText = ""
                            isSearchFiltering = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .back, size: 16, color: .monologueTextPrimary)
                            Text(expandedSourceName(source))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    if viewModel.currentTab == .songs {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchFiltering = true
                            }
                        } label: {
                            MonologueIcon(icon: .search, size: 15, color: .monologueTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monologueTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSearchSelectMode = true
                                searchSelectedIds.removeAll()
                            }
                        } label: {
                            MonologueIcon(icon: .checkmark, size: 15, color: .monologueTextSecondary)
                                .frame(width: 30, height: 30)
                                .background(Color.monologueTextPrimary.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 8)
            }
            
            ScrollView {
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
            .scrollIndicators(.hidden)
            .simultaneousGesture(DragGesture().onChanged { _ in
                isFocused = false
            })
        }
    }
    
    // MARK: - 展开歌曲列表
    
    private func expandedSourceName(_ source: MusicSource) -> String {
        switch source {
        case .netease: return String(localized: "search_platform_netease")
        case .qqmusic: return String(localized: "search_platform_qq")
        case .qishui: return "QSM"
        case .local: return "本地"
        }
    }
    
    private func expandedFilteredSongs(source: MusicSource) -> [Song] {
        let songs: [Song]
        switch source {
        case .netease: songs = viewModel.neteaseResults
        case .qqmusic: songs = viewModel.qqResults
        case .qishui: songs = viewModel.qishuiResults
        case .local: songs = []
        }
        return songs.filtered(by: searchFilterText)
    }
    
    private func expandedSongsList(source: MusicSource) -> some View {
        let allSongs: [Song] = {
            switch source {
            case .netease: return viewModel.neteaseResults
            case .qqmusic: return viewModel.qqResults
            case .qishui: return viewModel.qishuiResults
            case .local: return []
            }
        }()
        let songs = expandedFilteredSongs(source: source)
        return Group {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                SongListRow(song: song, index: index, isSelecting: isSearchSelectMode, isSelected: searchSelectedIds.contains(song.id), onArtistTap: { artistId in
                    selectedArtistId = artistId
                    showArtistDetail = true
                }, onDetailTap: { detailSong in
                    selectedSongForDetail = detailSong
                    showSongDetail = true
                }, onAlbumTap: { albumId in
                    selectedAlbumId = albumId
                    showAlbumDetail = true
                }, onTap: {
                    if isSearchSelectMode {
                        if searchSelectedIds.contains(song.id) {
                            searchSelectedIds.remove(song.id)
                        } else {
                            searchSelectedIds.insert(song.id)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: songs)
                        isFocused = false
                    }
                })
                .onAppear {
                    if index == allSongs.count - 3 {
                        viewModel.loadMore(source: source)
                    }
                }
            }
        }
        .monologueSheet(isPresented: $showSearchBatchPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: songs.filter { searchSelectedIds.contains($0.id) })
        }
    }
    
    private func searchBatchDownload(source: MusicSource) {
        let songs = expandedFilteredSongs(source: source)
        let selected = songs.filter { searchSelectedIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isSearchSelectMode = false; searchSelectedIds.removeAll() }
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
    
    // MARK: - 展开 MV 列表（仅ncm）
    
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
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
    }

    // MARK: - 通用行组件
    
    private func artistRow(artist: ArtistInfo) -> some View {
        Button(action: {
            if artist.isQQMusic {
                let mid = artist.qqMid ?? "\(artist.id)"
                qqDetailType = .artist(mid: mid, name: artist.name, coverUrl: artist.coverUrl?.absoluteString)
                showQQDetail = true
            } else {
                selectedArtistId = artist.id
                showArtistDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                    Circle().fill(Color.monologueSeparator)
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let albumSize = artist.albumSize, albumSize > 0 {
                            Text(String(format: String(localized: "search_album_count"), albumSize))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        if let musicSize = artist.musicSize, musicSize > 0 {
                            Text(String(format: String(localized: "search_song_count"), musicSize))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.monologueTextSecondary)
                        }
                    }
                }
                
                Spacer()
                
                MonologueIcon(icon: .chevronRight, size: 14, color: .monologueTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
                    RoundedRectangle(cornerRadius: 12).fill(Color.monologueSeparator)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let trackCount = playlist.trackCount, trackCount > 0 {
                            Text(String(format: String(localized: "search_track_count"), trackCount))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        if let creator = playlist.creator?.nickname {
                            Text("by \(creator)")
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.monologueTextSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                MonologueIcon(icon: .chevronRight, size: 14, color: .monologueTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func albumRow(album: SearchAlbum) -> some View {
        Button(action: {
            if album.isQQMusic {
                let mid = album.qqMid ?? "\(album.id)"
                qqDetailType = .album(mid: mid, name: album.name, coverUrl: album.coverUrl?.absoluteString, artistName: album.artistName)
                showQQDetail = true
            } else {
                selectedAlbumId = album.id
                showAlbumDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: album.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: 12).fill(Color.monologueSeparator)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(album.artistName)
                            .font(.rounded(size: 12, weight: .regular))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                        
                        if let size = album.size, size > 0 {
                            Text(String(format: String(localized: "search_track_count"), size))
                                .font(.rounded(size: 12, weight: .regular))
                                .foregroundColor(.monologueTextSecondary)
                        }
                    }
                }
                
                Spacer()
                
                MonologueIcon(icon: .chevronRight, size: 14, color: .monologueTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
                                .fill(Color.monologueTextSecondary.opacity(0.06))
                        }
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.monologueTextSecondary.opacity(0.06))
                            .frame(height: 100)
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                    
                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.clear).monologueGlass(cornerRadius: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mv.name)
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(mv.singerName ?? String(localized: "search_unknown_artist"))
                            .font(.rounded(size: 12))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                        
                        if !mv.playCountText.isEmpty {
                            Circle()
                                .fill(Color.monologueTextSecondary.opacity(0.3))
                                .frame(width: 3, height: 3)
                            Text(mv.playCountText + String(localized: "search_play_count_suffix"))
                                .font(.rounded(size: 11))
                                .foregroundColor(.monologueTextSecondary.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
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
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
    }

    // MARK: - 最佳匹配卡片
    
    private func bestMatchSection(match: SearchMultimatchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("search_best_match"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 10)
            
            ScrollView(.horizontal) {
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
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
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
                        .fill(Color.monologueSeparator)
                }
                .frame(width: 50, height: 50)
                .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 10)))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.rounded(size: 12))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                MonologueIcon(icon: .chevronRight, size: 14, color: .monologueTextSecondary.opacity(0.5))
            }
            .padding(12)
            .frame(width: 220)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: 20)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }
    
    // MARK: - 空结果提示
    
    private var emptyResultsView: some View {
        ContentUnavailableView.search(text: viewModel.query)
    }

    // MARK: - 搜索历史 & 热搜
    
    private var emptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 搜索历史
                if !viewModel.searchHistory.isEmpty {
                    HStack {
                        Text(LocalizedStringKey("search_history"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.clearAllHistory()
                        }) {
                            MonologueIcon(icon: .trash, size: 16, color: .monologueTextSecondary)
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ForEach(viewModel.searchHistory, id: \.id) { item in
                        Button(action: {
                            viewModel.performSearch(keyword: item.keyword)
                            isFocused = false
                        }) {
                            HStack(spacing: 14) {
                                MonologueIcon(icon: .clock, size: 16, color: .monologueTextSecondary)
                                
                                Text(item.keyword)
                                    .font(.rounded(size: 16, weight: .regular))
                                    .foregroundColor(.monologueTextPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.deleteHistoryItem(keyword: item.keyword)
                                }) {
                                    MonologueIcon(icon: .xmark, size: 12, color: .monologueTextSecondary.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
                        .foregroundColor(.monologueTextSecondary)
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(viewModel.hotSearchItems.prefix(20), id: \.searchWord) { item in
                            Button(action: {
                                viewModel.performSearch(keyword: item.searchWord)
                                isFocused = false
                            }) {
                                Text(item.searchWord)
                                    .font(.rounded(size: 14, weight: .regular))
                                    .foregroundColor(.monologueTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .monologueGlass(cornerRadius: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 搜索建议浮层

    @ViewBuilder
    private var suggestionsOverlay: some View {
        if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.suggestions, id: \.self) { suggestion in
                            HStack(spacing: 12) {
                                MonologueIcon(icon: .magnifyingGlass, size: 14, color: .monologueTextSecondary)

                                Text(suggestion)
                                    .font(.rounded(size: 15, weight: .regular))
                                    .foregroundColor(.monologueTextPrimary)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isFocused = false
                                viewModel.performSearch(keyword: suggestion)
                            }

                            if suggestion != viewModel.suggestions.last {
                                Divider()
                                    .opacity(0.4)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollDismissesKeyboard(.never)
                .scrollIndicators(.hidden)
                .frame(maxHeight: 320)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .monologueGlass(cornerRadius: 16)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 4)
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
        }
    }
}
