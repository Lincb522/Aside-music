import Foundation
import Combine

// MARK: - PlaylistDetailViewModel

@MainActor
class PlaylistDetailViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var playlistDetail: Playlist?
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var hasMore = true
    
    private var cancellables = Set<AnyCancellable>()
    private var currentOffset = 0
    private let limit = 30
    private var playlistId: Int?
    private var isFirstPageLoaded = false
    
    /// 缓存 key 前缀
    private func cacheKey(for id: Int) -> String {
        "playlist_tracks_\(id)"
    }
    
    func fetchSongs(playlistId: Int) {
        // 如果已经加载过同一个歌单，做静默刷新（不清空列表）
        if self.playlistId == playlistId && !songs.isEmpty {
            silentRefresh(playlistId: playlistId)
            return
        }
        
        self.playlistId = playlistId
        currentOffset = 0
        hasMore = true
        isLoadingMore = false
        isFirstPageLoaded = false
        
        // 1. 先尝试从缓存加载，立即显示
        if let cached = OptimizedCacheManager.shared.getObject(forKey: cacheKey(for: playlistId), type: [Song].self),
           !cached.isEmpty {
            AppLogger.debug("[PlaylistDetail] 缓存命中，加载 \(cached.count) 首歌曲")
            self.songs = cached
            self.isLoading = false
            self.isFirstPageLoaded = true
            self.currentOffset = cached.count
            // 缓存命中后，静默刷新第一页
            silentRefresh(playlistId: playlistId)
        } else {
            // 无缓存，正常加载（显示 loading）
            AppLogger.debug("[PlaylistDetail] 无缓存，开始加载歌单 \(playlistId)")
            songs = []
            isLoading = true
            loadMore()
        }
        
        // 加载歌单元数据
        APIService.shared.fetchPlaylistDetail(id: playlistId, cachePolicy: .staleWhileRevalidate, ttl: 3600)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] detail in
                self?.playlistDetail = detail
            })
            .store(in: &cancellables)
    }
    
    /// 静默刷新第一页 — 不清空列表，不显示 loading
    private func silentRefresh(playlistId: Int) {
        APIService.shared.fetchPlaylistTracks(id: playlistId, limit: limit, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("[PlaylistDetail] 静默刷新失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] fetchedSongs in
                guard let self = self, !fetchedSongs.isEmpty else { return }
                // 只有数据确实不同时才更新
                let currentIds = self.songs.prefix(fetchedSongs.count).map(\.id)
                let newIds = fetchedSongs.map(\.id)
                if currentIds != newIds {
                    // 替换第一页，保留后续已加载的页
                    var updated = fetchedSongs
                    if self.songs.count > fetchedSongs.count {
                        let remaining = self.songs.suffix(from: min(self.limit, self.songs.count))
                        // 去重追加
                        let newIdSet = Set(fetchedSongs.map(\.id))
                        let filtered = remaining.filter { !newIdSet.contains($0.id) }
                        updated.append(contentsOf: filtered)
                    }
                    self.songs = updated
                    self.currentOffset = updated.count
                }
                // 更新缓存
                OptimizedCacheManager.shared.setObject(fetchedSongs, forKey: self.cacheKey(for: playlistId), ttl: 3600)
            })
            .store(in: &cancellables)
    }
    
    func loadMore() {
        guard let id = playlistId, !isLoadingMore, hasMore else {
            AppLogger.debug("[PlaylistDetail] loadMore 被跳过: isLoadingMore=\(isLoadingMore), hasMore=\(hasMore)")
            return
        }
        
        // 只有在首页加载完成后，加载更多时才显示 isLoadingMore
        if isFirstPageLoaded && !songs.isEmpty {
            isLoadingMore = true
        }
        
        AppLogger.debug("[PlaylistDetail] 开始加载: offset=\(currentOffset), limit=\(limit)")
        
        APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: currentOffset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                // 确保 loading 状态被正确重置
                if self.currentOffset == 0 || !self.isFirstPageLoaded {
                    self.isLoading = false
                    self.isFirstPageLoaded = true
                }
                self.isLoadingMore = false
                
                if case .failure(let error) = completion {
                    AppLogger.error("[PlaylistDetail] 加载失败: \(error.localizedDescription)")
                    // 加载失败时,如果是首页且没有数据,确保显示错误而不是空白
                    if self.currentOffset == 0 && self.songs.isEmpty {
                        self.isLoading = false
                        self.hasMore = false
                    }
                }
            }, receiveValue: { [weak self] fetchedSongs in
                guard let self = self else { return }
                
                AppLogger.debug("[PlaylistDetail] 加载成功: 获取 \(fetchedSongs.count) 首歌曲")
                
                if self.currentOffset == 0 {
                    // 首页加载
                    self.songs = fetchedSongs
                    self.currentOffset = fetchedSongs.count
                    self.isFirstPageLoaded = true
                    self.isLoading = false
                    
                    // 缓存第一页
                    if !fetchedSongs.isEmpty {
                        OptimizedCacheManager.shared.setObject(fetchedSongs, forKey: self.cacheKey(for: id), ttl: 3600)
                        AppLogger.debug("[PlaylistDetail] 已缓存 \(fetchedSongs.count) 首歌曲")
                    } else {
                        AppLogger.warning("[PlaylistDetail] 首页返回空数据")
                    }
                } else {
                    // 加载更多
                    let newSongs = fetchedSongs.filter { newSong in
                        !self.songs.contains(where: { $0.id == newSong.id })
                    }
                    self.songs.append(contentsOf: newSongs)
                    self.currentOffset += fetchedSongs.count
                    AppLogger.debug("[PlaylistDetail] 追加 \(newSongs.count) 首新歌曲,总计 \(self.songs.count) 首")
                }
                
                // 判断是否还有更多
                if fetchedSongs.isEmpty || fetchedSongs.count < self.limit {
                    self.hasMore = false
                    AppLogger.debug("[PlaylistDetail] 已加载全部歌曲")
                } else {
                    self.hasMore = true
                }
            })
            .store(in: &cancellables)
    }
    
    func setSongs(_ songs: [Song]) {
        self.songs = songs
        self.isLoading = false
        self.isFirstPageLoaded = true
        self.hasMore = false
    }
    
    func getCurrentList() -> [Song] {
        return songs
    }
}
