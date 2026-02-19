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
    @Published var relatedPlaylists: [RelatedPlaylist] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var currentOffset = 0
    private let limit = 30
    private var playlistId: Int?
    private var isFirstPageLoaded = false
    private var retryCount = 0
    private let maxRetries = 2
    
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
        retryCount = 0
        
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
        
        // 加载相关歌单推荐
        loadRelatedPlaylists(playlistId: playlistId)
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
                    // 首页加载失败时自动重试
                    if self.currentOffset == 0 && self.songs.isEmpty {
                        if self.retryCount < self.maxRetries {
                            self.retryCount += 1
                            let delay = Double(self.retryCount) * 1.5
                            AppLogger.debug("[PlaylistDetail] 第 \(self.retryCount) 次重试，\(delay)s 后执行")
                            self.isLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                                self?.loadMore()
                            }
                        } else {
                            AppLogger.error("[PlaylistDetail] 重试 \(self.maxRetries) 次后仍失败")
                            self.isLoading = false
                            self.hasMore = false
                        }
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
                        self.retryCount = 0
                    } else {
                        AppLogger.warning("[PlaylistDetail] 首页返回空数据")
                        // 空数据也触发重试（可能是后端临时故障）
                        if self.retryCount < self.maxRetries {
                            self.retryCount += 1
                            let delay = Double(self.retryCount) * 1.5
                            AppLogger.debug("[PlaylistDetail] 空数据，第 \(self.retryCount) 次重试，\(delay)s 后执行")
                            self.isLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                                self?.loadMore()
                            }
                        }
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
    
    private func loadRelatedPlaylists(playlistId: Int) {
        // 同时加载 relatedPlaylist 和 simiPlaylist，合并去重
        let relatedPub = APIService.shared.fetchRelatedPlaylists(id: playlistId)
        let simiPub = APIService.shared.fetchSimiPlaylists(id: playlistId)
        
        Publishers.Zip(relatedPub, simiPub)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (related, simi) in
                var merged = related
                let existingIds = Set(related.map(\.id))
                // 将 simiPlaylist 转换为 RelatedPlaylist 并追加
                for playlist in simi {
                    if !existingIds.contains(playlist.id) {
                        merged.append(RelatedPlaylist(
                            id: playlist.id,
                            name: playlist.name,
                            coverImgUrl: playlist.coverImgUrl,
                            creatorName: playlist.creator?.nickname ?? ""
                        ))
                    }
                }
                self?.relatedPlaylists = merged
            })
            .store(in: &cancellables)
    }
}
