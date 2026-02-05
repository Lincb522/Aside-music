import Foundation
import Combine
import SwiftData
import UIKit
import SwiftUI
import LiquidGlassEffect

/// 优化的缓存管理器
/// 三级缓存架构：内存缓存 -> SwiftData 数据库 -> 磁盘文件缓存
@MainActor
final class OptimizedCacheManager: ObservableObject {
    static let shared = OptimizedCacheManager()
    
    // MARK: - 内存缓存（L1）
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    // MARK: - 数据库仓库（L2）
    private lazy var songRepo = SongRepository()
    private lazy var playlistRepo = PlaylistRepository()
    private lazy var historyRepo = HistoryRepository()
    
    // MARK: - 磁盘缓存（L3）- 用于大文件如图片
    private let diskCache = CacheManager.shared
    
    // MARK: - 预加载状态
    @Published var isPreloading = false
    @Published var preloadProgress: Double = 0
    @Published var preloadStage: PreloadStage = .idle
    
    // MARK: - 数据就绪状态
    @Published var isDailySongsReady = false
    @Published var isPlaylistsReady = false
    @Published var isUserDataReady = false
    
    // MARK: - 缓存配置
    private let memoryCacheLimit = 30 * 1024 * 1024 // 30MB (降低)
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24小时
    private let dailyCacheKey = "daily_cache_timestamp"
    private let lastSyncKey = "last_sync_timestamp"
    
    private var cancellables = Set<AnyCancellable>()
    
    // 预加载阶段
    enum PreloadStage: String {
        case idle = "空闲"
        case loadingFromDB = "从数据库加载"
        case loadingFromDisk = "从磁盘加载"
        case fetchingFromNetwork = "从网络获取"
        case complete = "完成"
    }
    
    private init() {
        memoryCache.totalCostLimit = memoryCacheLimit
        memoryCache.countLimit = 200 // 降低到 200 个对象
        
        // 监听内存警告
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    // MARK: - 数据就绪检查
    
    var isAllDataReady: Bool {
        return isDailySongsReady && isPlaylistsReady
    }
    
    func resetDataReadyState() {
        isDailySongsReady = false
        isPlaylistsReady = false
        isUserDataReady = false
    }
    
    func markDailySongsReady() {
        isDailySongsReady = true
        print("✅ 每日推荐数据就绪")
    }
    
    func markPlaylistsReady() {
        isPlaylistsReady = true
        print("✅ 歌单数据就绪")
    }
    
    func markUserDataReady() {
        isUserDataReady = true
        print("✅ 用户数据就绪")
    }
    
    // MARK: - 预加载系统
    
    /// 预加载核心数据（登录后调用）
    /// 这是一个快速的本地缓存加载，不涉及网络请求
    func preloadCoreData() async {
        isPreloading = true
        preloadProgress = 0
        preloadStage = .loadingFromDB
        
        print("🚀 开始预加载核心数据...")
        
        // 1. 从数据库加载缓存的歌曲到内存 (20%)
        await preloadSongsToMemory()
        preloadProgress = 0.2
        
        // 2. 从数据库加载缓存的歌单到内存 (40%)
        await preloadPlaylistsToMemory()
        preloadProgress = 0.4
        
        // 3. 预热磁盘缓存的关键数据 (60%)
        preloadStage = .loadingFromDisk
        await warmupDiskCache()
        preloadProgress = 0.6
        
        // 4. 加载用户偏好数据 (80%)
        await loadUserPreferences()
        preloadProgress = 0.8
        
        // 5. 完成
        preloadProgress = 1.0
        preloadStage = .complete
        isPreloading = false
        
        print("✅ 核心数据预加载完成")
    }
    
    /// 快速预加载 - 仅加载最关键的数据用于首屏显示
    func quickPreload() async {
        print("⚡ 快速预加载开始...")
        
        // 只加载首屏需要的数据
        let keysToWarmup = [
            "daily_songs",
            "recommend_playlists",
            "user_profile_detail",
            "banners"
        ]
        
        for key in keysToWarmup {
            if let data = diskCache.getData(forKey: key) {
                let cacheKey = key as NSString
                memoryCache.setObject(data as AnyObject, forKey: cacheKey)
            }
        }
        
        // 检查是否有缓存数据
        if let _ = diskCache.getObject(forKey: "daily_songs", type: [Song].self) {
            isDailySongsReady = true
        }
        if let _ = diskCache.getObject(forKey: "recommend_playlists", type: [Playlist].self) {
            isPlaylistsReady = true
        }
        
        print("⚡ 快速预加载完成")
    }
    
    /// 预加载歌曲到内存
    private func preloadSongsToMemory() async {
        // 只加载最近播放的歌曲（减少数量）
        let recentSongs = songRepo.getRecentlyPlayed(limit: 20)
        for dbSong in recentSongs {
            let song = dbSong.toSong()
            let cacheKey = "song_\(song.id)" as NSString
            memoryCache.setObject(song as AnyObject, forKey: cacheKey)
        }
        
        print("  📀 预加载了 \(recentSongs.count) 首歌曲到内存")
    }
    
    /// 预加载歌单到内存
    private func preloadPlaylistsToMemory() async {
        let recentPlaylists = playlistRepo.getRecentlyAccessed(limit: 10)
        for dbPlaylist in recentPlaylists {
            let playlist = dbPlaylist.toPlaylist()
            let cacheKey = "playlist_\(playlist.id)" as NSString
            memoryCache.setObject(playlist as AnyObject, forKey: cacheKey)
        }
        
        print("  📋 预加载了 \(recentPlaylists.count) 个歌单到内存")
    }
    
    /// 预热磁盘缓存
    private func warmupDiskCache() async {
        // 将关键的磁盘缓存数据加载到内存
        let keysToWarmup = [
            "daily_songs",
            "popular_songs", 
            "recommend_playlists",
            "user_playlists",
            "user_profile_detail",
            "banners"
        ]
        
        for key in keysToWarmup {
            // 尝试加载到内存（如果存在）
            if let data = diskCache.getData(forKey: key) {
                let cacheKey = key as NSString
                memoryCache.setObject(data as AnyObject, forKey: cacheKey)
            }
        }
        
        print("  🔥 磁盘缓存预热完成")
    }
    
    /// 加载用户偏好
    private func loadUserPreferences() async {
        // 加载搜索历史
        _ = historyRepo.getSearchHistory(limit: 20)
        
        // 加载播放历史
        _ = historyRepo.getPlayHistory(limit: 50)
        
        print("  👤 用户偏好数据加载完成")
    }
    
    // MARK: - 后台同步
    
    /// 后台同步数据到数据库
    func syncToDatabase() async {
        print("🔄 开始后台同步数据到数据库...")
        
        // 同步每日推荐歌曲
        if let songs = diskCache.getObject(forKey: "daily_songs", type: [Song].self) {
            songRepo.save(songs: songs)
        }
        
        // 同步热门歌曲
        if let songs = diskCache.getObject(forKey: "popular_songs", type: [Song].self) {
            songRepo.save(songs: songs)
        }
        
        // 同步最近播放
        if let songs = diskCache.getObject(forKey: "recent_songs", type: [Song].self) {
            songRepo.save(songs: songs)
        }
        
        // 同步推荐歌单
        if let playlists = diskCache.getObject(forKey: "recommend_playlists", type: [Playlist].self) {
            playlistRepo.save(playlists: playlists)
        }
        
        // 同步用户歌单
        if let playlists = diskCache.getObject(forKey: "user_playlists", type: [Playlist].self) {
            playlistRepo.save(playlists: playlists)
        }
        
        // 记录同步时间
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        
        print("✅ 后台同步完成")
    }
    
    /// 检查是否需要同步
    func shouldSync() -> Bool {
        guard let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date else {
            return true
        }
        // 每小时同步一次
        return Date().timeIntervalSince(lastSync) > 3600
    }
    
    // MARK: - 智能刷新策略
    
    /// 检查是否需要刷新每日数据
    func shouldRefreshDailyData() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: dailyCacheKey) as? Date else {
            return true
        }
        
        let calendar = Calendar.current
        // 如果不是今天，需要刷新
        if !calendar.isDateInToday(lastUpdate) {
            return true
        }
        
        // 如果超过缓存有效期，需要刷新
        if Date().timeIntervalSince(lastUpdate) > cacheValidityDuration {
            return true
        }
        
        return false
    }
    
    /// 标记每日数据已刷新
    func markDailyDataRefreshed() {
        UserDefaults.standard.set(Date(), forKey: dailyCacheKey)
    }
    
    /// 智能获取数据（优先缓存，必要时刷新）
    func smartFetch<T: Codable>(
        key: String,
        type: T.Type,
        maxAge: TimeInterval = 3600, // 默认1小时
        fetcher: @escaping () async throws -> T
    ) async -> T? {
        // 1. 检查内存缓存
        let cacheKey = key as NSString
        if let cached = memoryCache.object(forKey: cacheKey) as? T {
            return cached
        }
        
        // 2. 检查磁盘缓存（带时间戳）
        let timestampKey = "\(key)_timestamp"
        if let diskCached = diskCache.getObject(forKey: key, type: type),
           let timestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date,
           Date().timeIntervalSince(timestamp) < maxAge {
            // 缓存有效，回填内存
            memoryCache.setObject(diskCached as AnyObject, forKey: cacheKey)
            return diskCached
        }
        
        // 3. 需要从网络获取
        do {
            let freshData = try await fetcher()
            // 更新所有缓存层
            memoryCache.setObject(freshData as AnyObject, forKey: cacheKey)
            diskCache.setObject(freshData, forKey: key)
            UserDefaults.standard.set(Date(), forKey: timestampKey)
            return freshData
        } catch {
            print("❌ 获取数据失败: \(error)")
            // 返回过期的缓存数据（如果有）
            return diskCache.getObject(forKey: key, type: type)
        }
    }
    
    // MARK: - 歌曲缓存（增强版）
    
    /// 获取歌曲（优先内存 -> 数据库）
    func getSong(id: Int) -> Song? {
        let cacheKey = "song_\(id)" as NSString
        
        // L1: 内存缓存
        if let cached = memoryCache.object(forKey: cacheKey) as? Song {
            return cached
        }
        
        // L2: 数据库
        if let dbSong = songRepo.getSong(id: id) {
            let song = dbSong.toSong()
            memoryCache.setObject(song as AnyObject, forKey: cacheKey)
            return song
        }
        
        return nil
    }
    
    /// 批量获取歌曲（优化版）
    func getSongs(ids: [Int]) -> [Song] {
        var result: [Song] = []
        var missedIds: [Int] = []
        
        // 先从内存获取
        for id in ids {
            let cacheKey = "song_\(id)" as NSString
            if let cached = memoryCache.object(forKey: cacheKey) as? Song {
                result.append(cached)
            } else {
                missedIds.append(id)
            }
        }
        
        // 从数据库批量获取缺失的
        if !missedIds.isEmpty {
            let dbSongs = songRepo.getSongs(ids: missedIds)
            for dbSong in dbSongs {
                let song = dbSong.toSong()
                let cacheKey = "song_\(song.id)" as NSString
                memoryCache.setObject(song as AnyObject, forKey: cacheKey)
                result.append(song)
            }
        }
        
        return result
    }
    
    /// 缓存歌曲
    func cacheSong(_ song: Song) {
        let cacheKey = "song_\(song.id)" as NSString
        memoryCache.setObject(song as AnyObject, forKey: cacheKey)
        
        Task.detached { @MainActor in
            self.songRepo.save(song: song)
        }
    }
    
    /// 批量缓存歌曲（优化版 - 批量写入）
    func cacheSongs(_ songs: [Song]) {
        // 先更新内存缓存
        for song in songs {
            let cacheKey = "song_\(song.id)" as NSString
            memoryCache.setObject(song as AnyObject, forKey: cacheKey)
        }
        
        // 异步批量写入数据库
        Task.detached { @MainActor in
            self.songRepo.save(songs: songs)
        }
    }
    
    /// 记录歌曲播放
    func recordSongPlay(_ song: Song, duration: Int = 0, completed: Bool = false) {
        songRepo.recordPlay(songId: song.id)
        historyRepo.addPlayHistory(song: song, duration: duration, completed: completed)
    }
    
    // MARK: - 歌单缓存（增强版）
    
    /// 获取歌单
    func getPlaylist(id: Int) -> Playlist? {
        let cacheKey = "playlist_\(id)" as NSString
        
        if let cached = memoryCache.object(forKey: cacheKey) as? Playlist {
            return cached
        }
        
        if let dbPlaylist = playlistRepo.getPlaylist(id: id) {
            let playlist = dbPlaylist.toPlaylist()
            memoryCache.setObject(playlist as AnyObject, forKey: cacheKey)
            playlistRepo.recordAccess(playlistId: id)
            return playlist
        }
        
        return nil
    }
    
    /// 获取歌单的歌曲 ID 列表
    func getPlaylistTrackIds(playlistId: Int) -> [Int]? {
        if let dbPlaylist = playlistRepo.getPlaylist(id: playlistId) {
            return dbPlaylist.trackIds.isEmpty ? nil : dbPlaylist.trackIds
        }
        return nil
    }
    
    /// 缓存歌单
    func cachePlaylist(_ playlist: Playlist, trackIds: [Int] = []) {
        let cacheKey = "playlist_\(playlist.id)" as NSString
        memoryCache.setObject(playlist as AnyObject, forKey: cacheKey)
        
        Task.detached { @MainActor in
            self.playlistRepo.save(playlist: playlist, trackIds: trackIds)
        }
    }
    
    /// 批量缓存歌单
    func cachePlaylists(_ playlists: [Playlist]) {
        for playlist in playlists {
            let cacheKey = "playlist_\(playlist.id)" as NSString
            memoryCache.setObject(playlist as AnyObject, forKey: cacheKey)
        }
        
        Task.detached { @MainActor in
            self.playlistRepo.save(playlists: playlists)
        }
    }
    
    /// 更新歌单歌曲列表
    func updatePlaylistTracks(playlistId: Int, songs: [Song]) {
        let trackIds = songs.map { $0.id }
        playlistRepo.updateTrackIds(playlistId: playlistId, trackIds: trackIds)
        cacheSongs(songs)
    }
    
    // MARK: - 历史记录
    
    func getPlayHistory(limit: Int = 100) -> [PlayHistory] {
        return historyRepo.getPlayHistory(limit: limit)
    }
    
    func getSearchHistory(limit: Int = 20) -> [SearchHistory] {
        return historyRepo.getSearchHistory(limit: limit)
    }
    
    func addSearchHistory(keyword: String, resultCount: Int = 0) {
        historyRepo.addSearchHistory(keyword: keyword, resultCount: resultCount)
    }
    
    func deleteSearchHistory(keyword: String) {
        historyRepo.deleteSearchHistory(keyword: keyword)
    }
    
    func clearSearchHistory() {
        historyRepo.clearSearchHistory()
    }
    
    // MARK: - 歌词缓存
    
    func getLyrics(songId: Int) -> (lyrics: String, translated: String?)? {
        if let cached = historyRepo.getLyrics(songId: songId) {
            return (cached.lyrics, cached.translatedLyrics)
        }
        return nil
    }
    
    func cacheLyrics(songId: Int, lyrics: String, translated: String? = nil) {
        historyRepo.saveLyrics(songId: songId, lyrics: lyrics, translated: translated)
    }
    
    // MARK: - 通用对象缓存（兼容旧 API）
    
    func getObject<T: Codable>(forKey key: String, type: T.Type) -> T? {
        let cacheKey = key as NSString
        
        if let cached = memoryCache.object(forKey: cacheKey) as? T {
            return cached
        }
        
        if let diskCached = diskCache.getObject(forKey: key, type: type) {
            memoryCache.setObject(diskCached as AnyObject, forKey: cacheKey)
            return diskCached
        }
        
        return nil
    }
    
    func setObject<T: Codable>(_ object: T, forKey key: String, ttl: TimeInterval? = nil) {
        let cacheKey = key as NSString
        memoryCache.setObject(object as AnyObject, forKey: cacheKey)
        diskCache.setObject(object, forKey: key, ttl: ttl)
    }
    
    // MARK: - 内存管理
    
    /// 处理内存警告
    private func handleMemoryWarning() {
        print("⚠️ 收到内存警告，清理内存缓存...")
        
        // 清理所有内存缓存
        memoryCache.removeAllObjects()
        
        // 清理图片缓存
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        
        // 通知 LiquidGlass 释放缓存
        Task { @MainActor in
            LiquidGlassEngine.shared.releaseAllCaches()
        }
        
        print("✅ 内存缓存已清理")
    }
    
    /// 清理过期数据
    func cleanupExpiredData() async {
        DatabaseManager.shared.cleanExpiredData(olderThan: 30)
    }
    
    /// 清空所有缓存
    func clearAll() {
        memoryCache.removeAllObjects()
        DatabaseManager.shared.clearAllData()
        diskCache.clearAll()
        UserDefaults.standard.removeObject(forKey: dailyCacheKey)
    }
    
    /// 获取缓存大小
    func getCacheSize() -> String {
        let dbSize = DatabaseManager.shared.calculateDatabaseSize()
        let diskSize = diskCache.calculateCacheSize()
        return "数据库: \(dbSize), 文件: \(diskSize)"
    }
    
    // MARK: - 统计
    
    func getStatistics() -> CacheStatistics {
        return CacheStatistics(
            cachedSongs: songRepo.count(),
            cachedPlaylists: playlistRepo.count(),
            databaseSize: DatabaseManager.shared.calculateDatabaseSize(),
            diskCacheSize: diskCache.calculateCacheSize()
        )
    }
}

// MARK: - 缓存统计

struct CacheStatistics {
    let cachedSongs: Int
    let cachedPlaylists: Int
    let databaseSize: String
    let diskCacheSize: String
    
    var totalSize: String {
        return "数据库: \(databaseSize), 文件: \(diskCacheSize)"
    }
}
