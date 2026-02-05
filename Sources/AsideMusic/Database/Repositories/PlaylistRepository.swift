import Foundation
import SwiftData

/// 歌单数据仓库
@MainActor
final class PlaylistRepository {
    private let context: ModelContext
    
    init(context: ModelContext = DatabaseManager.shared.context) {
        self.context = context
    }
    
    // MARK: - 查询
    
    /// 根据 ID 获取歌单
    func getPlaylist(id: Int) -> CachedPlaylist? {
        let predicate = #Predicate<CachedPlaylist> { $0.id == id }
        let descriptor = FetchDescriptor<CachedPlaylist>(predicate: predicate)
        
        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("❌ 获取歌单失败: \(error)")
            return nil
        }
    }
    
    /// 获取用户歌单（根据创建者名称）
    func getUserPlaylists(creatorName: String) -> [CachedPlaylist] {
        let predicate = #Predicate<CachedPlaylist> { $0.creatorName == creatorName }
        let descriptor = FetchDescriptor<CachedPlaylist>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.cachedAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ 获取用户歌单失败: \(error)")
            return []
        }
    }
    
    /// 获取最近访问的歌单
    func getRecentlyAccessed(limit: Int = 20) -> [CachedPlaylist] {
        var descriptor = FetchDescriptor<CachedPlaylist>(
            predicate: #Predicate { $0.lastAccessedAt != nil },
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ 获取最近访问歌单失败: \(error)")
            return []
        }
    }
    
    // MARK: - 保存
    
    /// 保存歌单
    func save(playlist: Playlist, trackIds: [Int] = []) {
        if let existing = getPlaylist(id: playlist.id) {
            // 更新现有记录
            existing.name = playlist.name
            existing.coverUrl = playlist.coverUrl?.absoluteString
            existing.creatorName = playlist.creator?.nickname
            // Creator 没有 userId，跳过
            existing.trackCount = playlist.trackCount
            existing.playCount = playlist.playCount
            existing.desc = playlist.description
            existing.tags = playlist.tags
            existing.cachedAt = Date()
            if !trackIds.isEmpty {
                existing.trackIds = trackIds
            }
        } else {
            let cached = CachedPlaylist(from: playlist, trackIds: trackIds)
            context.insert(cached)
        }
        
        try? context.save()
    }
    
    /// 批量保存歌单
    func save(playlists: [Playlist]) {
        for playlist in playlists {
            save(playlist: playlist)
        }
    }
    
    /// 更新歌单的歌曲 ID 列表
    func updateTrackIds(playlistId: Int, trackIds: [Int]) {
        if let playlist = getPlaylist(id: playlistId) {
            playlist.trackIds = trackIds
            playlist.trackCount = trackIds.count
            try? context.save()
        }
    }
    
    /// 记录访问
    func recordAccess(playlistId: Int) {
        if let playlist = getPlaylist(id: playlistId) {
            playlist.recordAccess()
            try? context.save()
        }
    }
    
    // MARK: - 删除
    
    /// 删除歌单
    func delete(id: Int) {
        if let playlist = getPlaylist(id: id) {
            context.delete(playlist)
            try? context.save()
        }
    }
    
    /// 清空所有歌单缓存
    func deleteAll() {
        do {
            try context.delete(model: CachedPlaylist.self)
            try context.save()
        } catch {
            print("❌ 清空歌单缓存失败: \(error)")
        }
    }
    
    // MARK: - 统计
    
    func count() -> Int {
        let descriptor = FetchDescriptor<CachedPlaylist>()
        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}
