import SwiftUI
import Combine
import QQMusicKit

// MARK: - QQ 歌单详情 ViewModel

@MainActor
class QQPlaylistDetailViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var resolvedCoverUrl: String?
    @Published var resolvedName: String?
    
    let playlistId: Int
    private var currentPage = 1
    private let songsRequest = LibraryRequestScope()
    private let pageRequest = LibraryRequestScope()
    private let detailRequest = LibraryRequestScope()
    private var allSongsTask: Task<[Song], Never>?
    private var appendLoadedSongsToQueue = false
    private var loadAllAfterFirstPage = false
    private var songsRevision = 0
    
    init(playlistId: Int) {
        self.playlistId = playlistId
    }
    
    func fetchSongs() {
        guard songs.isEmpty, !songsRequest.isRunning else { return }
        songsRevision += 1
        pageRequest.cancel()
        allSongsTask?.cancel()
        allSongsTask = nil
        isLoadingAll = false
        isLoadingMore = false
        isLoading = true
        currentPage = 1
        let request = songsRequest.begin()
        songsRequest.cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: playlistId, page: 1, num: 50)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.songsRequest.isCurrent(request) else { return }
                self.songsRequest.finish(request)
                self.isLoading = false
                if case .failure(let error) = completion { AppLogger.error("[QQPlaylist] 加载失败: \(error)") }
                if self.loadAllAfterFirstPage {
                    self.loadAllAfterFirstPage = false
                    self.loadAllSongs(appendToQueue: self.appendLoadedSongsToQueue)
                }
            }, receiveValue: { [weak self] songs in
                guard let self, self.songsRequest.isCurrent(request) else { return }
                self.songs = songs
                self.hasMore = songs.count >= 20
            })
    }
    
    func loadMore() {
        guard !isLoading, !isLoadingMore, !isLoadingAll, hasMore else { return }
        isLoadingMore = true
        let page = currentPage + 1
        let request = pageRequest.begin()
        pageRequest.cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: playlistId, page: page, num: 50)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.pageRequest.isCurrent(request) else { return }
                self.pageRequest.finish(request)
                self.isLoadingMore = false
            }, receiveValue: { [weak self] newSongs in
                guard let self, self.pageRequest.isCurrent(request) else { return }
                let ids = Set(self.songs.map(\.id))
                let unique = newSongs.filter { !ids.contains($0.id) }
                self.songs.append(contentsOf: unique)
                self.currentPage = page
                self.hasMore = newSongs.count >= 20 && !unique.isEmpty
            })
    }
    
    @Published var isLoadingAll = false
    
    func loadAllSongs(appendToQueue: Bool = false) {
        _ = startLoadingAllSongs(appendToQueue: appendToQueue)
    }
    
    @discardableResult
    func loadAllSongsAsync(appendToQueue: Bool = false) async -> [Song] {
        guard let task = startLoadingAllSongs(appendToQueue: appendToQueue) else { return songs }
        return await task.value
    }

    private func startLoadingAllSongs(appendToQueue: Bool) -> Task<[Song], Never>? {
        appendLoadedSongsToQueue = appendLoadedSongsToQueue || appendToQueue
        if let allSongsTask { return allSongsTask }
        if isLoading {
            loadAllAfterFirstPage = true
            return nil
        }
        guard hasMore else {
            appendLoadedSongsToQueue = false
            return nil
        }
        pageRequest.cancel()
        isLoadingMore = false
        isLoadingAll = true
        let revision = songsRevision
        let task = Task<[Song], Never> { @MainActor [weak self] in
            guard let self else { return [] }
            defer {
                if self.songsRevision == revision {
                    self.isLoadingAll = false
                    self.allSongsTask = nil
                    self.appendLoadedSongsToQueue = false
                }
            }
            while self.hasMore, !Task.isCancelled, self.songsRevision == revision {
                let page = self.currentPage + 1
                do {
                    let newSongs = try await APIService.shared.fetchQQPlaylistSongs(playlistId: self.playlistId, page: page, num: 50).async()
                    guard !Task.isCancelled, self.songsRevision == revision else { return self.songs }
                    let ids = Set(self.songs.map(\.id))
                    let unique = newSongs.filter { !ids.contains($0.id) }
                    self.hasMore = newSongs.count >= 20 && !unique.isEmpty
                    self.songs.append(contentsOf: unique)
                    self.currentPage = page
                    if self.appendLoadedSongsToQueue, !unique.isEmpty {
                        PlayerManager.shared.appendContext(songs: unique)
                    }
                } catch {
                    break
                }
            }
            return self.songs
        }
        allSongsTask = task
        return task
    }
    
    func fetchDetail() {
        guard !detailRequest.isRunning else { return }
        let request = detailRequest.begin()
        detailRequest.cancellable = APIService.shared.fetchQQPlaylistDetail(playlistId: playlistId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in self?.detailRequest.finish(request) }, receiveValue: { [weak self] json in
                guard let self, self.detailRequest.isCurrent(request) else { return }
                // 新版 API 信息嵌套在 info 下: { info: { title, picurl, desc, ... }, songs: [...] }
                let info = json["info"] ?? json["dirinfo"] ?? json
                let logoCandidates: [String?] = [
                    info["picurl"]?.stringValue,
                    info["logo"]?.stringValue,
                    info["dirpicurl"]?.stringValue,
                    info["coverImgUrl"]?.stringValue,
                    info["cover"]?.stringValue,
                    json["logo"]?.stringValue,
                    json["dirpicurl"]?.stringValue,
                    json["coverImgUrl"]?.stringValue,
                    json["cover"]?.stringValue
                ]
                if let logo = logoCandidates.compactMap({ $0 }).first(where: { !$0.isEmpty }) {
                    self.resolvedCoverUrl = logo
                }
                let nameCandidates: [String?] = [
                    info["title"]?.stringValue,
                    info["dissname"]?.stringValue,
                    info["name"]?.stringValue,
                    json["dissname"]?.stringValue,
                    json["title"]?.stringValue,
                    json["name"]?.stringValue
                ]
                if let name = nameCandidates.compactMap({ $0 }).first(where: { !$0.isEmpty }) {
                    self.resolvedName = name
                }
            })
    }

    deinit { allSongsTask?.cancel() }
}

// MARK: - QQ 歌单详情页

struct QQPlaylistDetailView: View {
    let playlistId: Int
    let name: String
    let coverUrl: String?
    let creatorName: String?
    
    @StateObject private var viewModel: QQPlaylistDetailViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var isCollectedLocally = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isPlaylistSelectMode = false
    @State private var playlistSelectedIds: Set<String> = []
    @State private var showPlaylistBatchPlaylist = false
    @State private var scrollOffset: CGFloat = 0

    /// aside(默认)分支使用歌手页风格 Hero 头部
    private var usesAsideHero: Bool { !MinimalWhiteStyle.isActive && !SignalStyle.isActive }

    init(playlistId: Int, name: String, coverUrl: String?, creatorName: String?) {
        self.playlistId = playlistId
        self.name = name
        self.coverUrl = coverUrl
        self.creatorName = creatorName
        _viewModel = StateObject(wrappedValue: QQPlaylistDetailViewModel(playlistId: playlistId))
    }
    
    private var displayName: String { viewModel.resolvedName ?? name }
    
    private var displayCoverUrl: URL? {
        if let resolved = viewModel.resolvedCoverUrl, let url = URL(string: resolved) { return url }
        if let c = coverUrl, let url = URL(string: c) { return url }
        return nil
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            MonoSheetAwareBackground {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteRootBackdrop()
                } else if SignalStyle.isActive {
                    SignalRootBackdrop()
                } else if SettingsManager.shared.usesPlaylistCoverBackground {
                    PlaylistColorBackground(coverUrl: displayCoverUrl?.sized(200))
                        .ignoresSafeArea()
                } else {
                    ThemedPageBackground().ignoresSafeArea()
                }
            }
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        if usesAsideHero || SignalStyle.isActive {
                            headerSection
                        } else {
                            headerSection
                                .monoPageHeaderCollapse()
                        }
                        PlaylistSearchBar(
                            searchText: $searchText,
                            isSearching: $isSearching,
                            onSearchActivated: { viewModel.loadAllSongs() },
                            isSelectMode: $isPlaylistSelectMode,
                            selectedIds: $playlistSelectedIds,
                            songs: viewModel.songs.filtered(by: searchText),
                            onBatchQueue: {
                                let selected = qqFilteredSongs.filter { playlistSelectedIds.contains($0.identityKey) }
                                SongBatchActionHelper.addToQueue(selected) {
                                    isPlaylistSelectMode = false
                                    playlistSelectedIds.removeAll()
                                }
                            },
                            onBatchDownload: { qqPlaylistBatchDownload() },
                            onBatchCollect: { showPlaylistBatchPlaylist = true }
                        )
                        songsList
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
                .monoScrollOffset($scrollOffset)
                .ignoresSafeArea(edges: (usesAsideHero || SignalStyle.isActive) ? .top : [])
            .themeRenderScrollLayer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .onAppear {
            if viewModel.songs.isEmpty {
                viewModel.fetchSongs()
                viewModel.fetchDetail()
            }
            isCollectedLocally = LocalPlaylistManager.shared.playlists.contains { $0.name == displayName }
        }
        .onChange(of: viewModel.resolvedName) { _, _ in
            isCollectedLocally = LocalPlaylistManager.shared.playlists.contains { $0.name == displayName }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .overlay {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                MonoLoadingView(text: MinimalWhiteStyle.isActive ? nil : "LOADING")
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteQQPlaylistHeaderSection
        } else if SignalStyle.isActive {
            signalQQPlaylistHeaderSection
        } else {
            AsideDetailHeroHeader(
                coverUrl: displayCoverUrl,
                title: displayName,
                subtitle: creatorName.map { "by \($0)" },
                metaItems: ["QCM"],
                scrollOffset: scrollOffset,
                heroHeight: displayCoverUrl == nil ? 220 : 320,
                playAllDisabled: viewModel.songs.isEmpty,
                onPlayAll: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllSongs(appendToQueue: true)
                    }
                }
            ) {
                SubscribeButton(
                    isSubscribed: isCollectedLocally,
                    action: {
                        guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
                        Task {
                            let allSongs = await viewModel.loadAllSongsAsync()
                            LocalPlaylistManager.shared.importPlaylist(name: displayName, songs: allSongs)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isCollectedLocally = true
                            }
                        }
                    }
                )
                .disabled(isCollectedLocally || viewModel.songs.isEmpty)
            }
            .padding(.bottom, DeviceLayout.usesExpandedLayout ? 20 : 12)
            .iPadContentWidth(900)
        }
    }

    private var signalQQPlaylistHeaderSection: some View {
        SignalPlaylistHero(
            coverURL: displayCoverUrl,
            title: displayName,
            sourceLabel: "QCM",
            subtitle: creatorName,
            trackCount: viewModel.songs.count,
            playDisabled: viewModel.songs.isEmpty,
            onPlay: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    viewModel.loadAllSongs(appendToQueue: true)
                }
            }
        ) {
            SubscribeButton(
                isSubscribed: isCollectedLocally,
                action: {
                    guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
                    Task {
                        let allSongs = await viewModel.loadAllSongsAsync()
                        LocalPlaylistManager.shared.importPlaylist(name: displayName, songs: allSongs)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isCollectedLocally = true
                        }
                    }
                }
            )
            .disabled(isCollectedLocally || viewModel.songs.isEmpty)
        }
    }

    private var minimalWhiteQQPlaylistHeaderSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let url = displayCoverUrl {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(MinimalWhiteStyle.controlGlassFill)
                                .overlay(MonoIcon(icon: .musicNote, size: 34, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
                        }
                        .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(MinimalWhiteStyle.controlGlassFill)
                            .overlay(MonoIcon(icon: .musicNote, size: 34, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
                    }
                }
                .frame(width: DeviceLayout.usesExpandedLayout ? 150 : 118, height: DeviceLayout.usesExpandedLayout ? 150 : 118)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 10) {
                    PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)

                    Text(displayName)
                        .font(MinimalWhiteStyle.titleFont(24, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(2)

                    if let creator = creatorName {
                        Text(creator)
                            .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkMuted)
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllSongs(appendToQueue: true)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonoIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent)
                        Text(LocalizedStringKey("play_now"))
                            .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                    }
                    .foregroundStyle(MinimalWhiteStyle.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                .disabled(viewModel.songs.isEmpty)
                .opacity(viewModel.songs.isEmpty ? 0.45 : 1)

                SubscribeButton(
                    isSubscribed: isCollectedLocally,
                    action: {
                        guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
                        Task {
                            let allSongs = await viewModel.loadAllSongsAsync()
                            LocalPlaylistManager.shared.importPlaylist(name: displayName, songs: allSongs)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isCollectedLocally = true
                            }
                        }
                    }
                )
                .disabled(isCollectedLocally || viewModel.songs.isEmpty)
            }
        }
        .padding(18)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 12)
        .padding(.bottom, 18)
    }
    
    private var qqFilteredSongs: [Song] {
        viewModel.songs.filtered(by: searchText)
    }
    
    private var songsList: some View {
        LazyVStack(spacing: 0) {
            if !viewModel.isLoading && qqFilteredSongs.isEmpty {
                VStack(spacing: 14) {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteIconBadge(icon: .musicNoteList, size: 52)
                    } else {
                        MonoIcon(icon: .musicNoteList, size: 40, color: QQDetailPalette.mutedText.opacity(0.36))
                    }
                    Text(String(localized: "qq_no_songs"))
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            }

            ForEach(Array(qqFilteredSongs.enumerated()), id: \.element.identityKey) { index, song in
                SongListRow(song: song, index: index, isSelecting: isPlaylistSelectMode, isSelected: playlistSelectedIds.contains(song.identityKey), onArtistTap: { _ in }, onDetailTap: { s in
                    selectedSongForDetail = s
                    showSongDetail = true
                }, onAlbumTap: { _ in }, onTap: {
                    if isPlaylistSelectMode {
                        if playlistSelectedIds.contains(song.identityKey) {
                            playlistSelectedIds.remove(song.identityKey)
                        } else {
                            playlistSelectedIds.insert(song.identityKey)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: qqFilteredSongs)
                    }
                })
                .onAppear {
                    if !isSearching && index == viewModel.songs.count - 3 { viewModel.loadMore() }
                }
            }
            .background {
                if MinimalWhiteStyle.isActive && !qqFilteredSongs.isEmpty {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.cardRadius,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
                }
            }
            
            if !isSearching {
                if viewModel.isLoadingMore {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("qq_loading_more").font(.rounded(size: 13)).foregroundColor(QQDetailPalette.secondaryText)
                    }
                    .padding(.vertical, 14)
                }
                
                if !viewModel.hasMore && !viewModel.songs.isEmpty {
                    NoMoreDataView()
                }
            }
        }
        .monoSheet(isPresented: $showPlaylistBatchPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: qqFilteredSongs.filter { playlistSelectedIds.contains($0.identityKey) })
        }
    }
    
    private func qqPlaylistBatchDownload() {
        let selected = qqFilteredSongs.filter { playlistSelectedIds.contains($0.identityKey) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "download_batch_added_title"), message: L10n.format("download_batch_queue_added_format", selected.count), primaryButtonTitle: String(localized: "common_confirm"), primaryAction: {})
        withAnimation { isPlaylistSelectMode = false; playlistSelectedIds.removeAll() }
    }
}
