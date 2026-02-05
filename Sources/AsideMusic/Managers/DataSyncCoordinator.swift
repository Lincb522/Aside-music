import Foundation
import Combine

/// 数据同步协调器
/// 协调网络请求、缓存和数据库之间的数据流
@MainActor
final class DataSyncCoordinator: ObservableObject {
    static let shared = DataSyncCoordinator()
    
    // MARK: - 同步状态
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    
    // MARK: - 配置
    private let syncIntervalKey = "last_full_sync_time"
    private let minSyncInterval: TimeInterval = 300 // 5分钟最小同步间隔
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private let cache = OptimizedCacheManager.shared
    
    private init() {
        lastSyncTime = UserDefaults.standard.object(forKey: syncIntervalKey) as? Date
    }
    
    // MARK: - 同步策略
    
    /// 检查是否需要同步
    var needsSync: Bool {
        guard let lastSync = lastSyncTime else { return true }
        return Date().timeIntervalSince(lastSync) > minSyncInterval
    }
    
    /// 智能同步 - 根据数据新鲜度决定是否从网络获取
    func smartSync<T: Codable>(
        key: String,
        maxAge: TimeInterval,
        fetcher: @escaping () -> AnyPublisher<T, Error>
    ) -> AnyPublisher<T, Never> {
        // 1. 先尝试从缓存获取
        if let cached = cache.getObject(forKey: key, type: T.self) {
            let timestampKey = "\(key)_timestamp"
            if let timestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date,
               Date().timeIntervalSince(timestamp) < maxAge {
                // 缓存有效，直接返回
                return Just(cached).eraseToAnyPublisher()
            }
        }
        
        // 2. 缓存无效或不存在，从网络获取
        return fetcher()
            .handleEvents(receiveOutput: { [weak self] data in
                // 更新缓存
                Task { @MainActor in
                    self?.cache.setObject(data, forKey: key)
                    UserDefaults.standard.set(Date(), forKey: "\(key)_timestamp")
                }
            })
            .catch { [weak self] error -> AnyPublisher<T, Never> in
                // 网络失败，尝试返回过期缓存
                if let cached = self?.cache.getObject(forKey: key, type: T.self) {
                    return Just(cached).eraseToAnyPublisher()
                }
                return Empty().eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 批量同步
    
    /// 同步所有核心数据
    func syncAllCoreData() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        print("🔄 开始同步所有核心数据...")
        
        do {
            // 并行获取所有数据
            async let dailySongs = syncDailySongs()
            async let playlists = syncRecommendPlaylists()
            async let userPlaylists = syncUserPlaylists()
            
            // 等待所有任务完成
            _ = await (dailySongs, playlists, userPlaylists)
            
            // 更新同步时间
            lastSyncTime = Date()
            UserDefaults.standard.set(lastSyncTime, forKey: syncIntervalKey)
            
            print("✅ 核心数据同步完成")
        } catch {
            syncError = error
            print("❌ 数据同步失败: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - 单项同步
    
    private func syncDailySongs() async -> [Song] {
        return await withCheckedContinuation { continuation in
            apiService.fetchDailySongs()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure = completion {
                            continuation.resume(returning: [])
                        }
                    },
                    receiveValue: { songs in
                        Task { @MainActor in
                            self.cache.setObject(songs, forKey: "daily_songs")
                            self.cache.cacheSongs(songs)
                        }
                        continuation.resume(returning: songs)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func syncRecommendPlaylists() async -> [Playlist] {
        return await withCheckedContinuation { continuation in
            apiService.fetchRecommendPlaylists()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure = completion {
                            continuation.resume(returning: [])
                        }
                    },
                    receiveValue: { playlists in
                        Task { @MainActor in
                            self.cache.setObject(playlists, forKey: "recommend_playlists")
                            self.cache.cachePlaylists(playlists)
                        }
                        continuation.resume(returning: playlists)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func syncUserPlaylists() async -> [Playlist] {
        guard let uid = apiService.currentUserId else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            apiService.fetchUserPlaylists(uid: uid)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure = completion {
                            continuation.resume(returning: [])
                        }
                    },
                    receiveValue: { playlists in
                        Task { @MainActor in
                            self.cache.setObject(playlists, forKey: "user_playlists")
                            self.cache.cachePlaylists(playlists)
                        }
                        continuation.resume(returning: playlists)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - 增量同步
    
    /// 同步单个歌单的歌曲
    func syncPlaylistTracks(playlistId: Int) async -> [Song] {
        // 先检查缓存
        if let trackIds = cache.getPlaylistTrackIds(playlistId: playlistId),
           !trackIds.isEmpty {
            let cachedSongs = cache.getSongs(ids: trackIds)
            if cachedSongs.count == trackIds.count {
                return cachedSongs
            }
        }
        
        // 从网络获取
        return await withCheckedContinuation { continuation in
            apiService.fetchPlaylistTracks(id: playlistId)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure = completion {
                            continuation.resume(returning: [])
                        }
                    },
                    receiveValue: { songs in
                        Task { @MainActor in
                            self.cache.updatePlaylistTracks(playlistId: playlistId, songs: songs)
                        }
                        continuation.resume(returning: songs)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - 清理
    
    /// 清理过期数据
    func cleanupExpiredData() async {
        await cache.cleanupExpiredData()
    }
}
