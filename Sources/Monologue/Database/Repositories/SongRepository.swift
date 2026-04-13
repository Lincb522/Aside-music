import Foundation
import SwiftData
import Combine

/// 歌曲数据仓库
@MainActor
final class SongRepository {
    private let context: ModelContext
    
    init(context: ModelContext = DatabaseManager.shared.context) {
        self.context = context
    }
    
    // MARK: - 查询
    
    /// 根据 ID 获取歌曲
    func getSong(id: Int) -> CachedSong? {
        let predicate = #Predicate<CachedSong> { $0.id == id }
        let descriptor = FetchDescriptor<CachedSong>(predicate: predicate)
        
        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            AppLogger.error("获取歌曲失败: \(error)")
            return nil
        }
    }
    
    /// 批量获取歌曲
    func getSongs(ids: [Int]) -> [CachedSong] {
        let predicate = #Predicate<CachedSong> { ids.contains($0.id) }
        let descriptor = FetchDescriptor<CachedSong>(predicate: predicate)
        
        do {
            return try context.fetch(descriptor)
        } catch {
            AppLogger.error("批量获取歌曲失败: \(error)")
            return []
        }
    }
    
    /// 获取最近播放的歌曲
    func getRecentlyPlayed(limit: Int = 50) -> [CachedSong] {
        var descriptor = FetchDescriptor<CachedSong>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            AppLogger.error("获取最近播放失败: \(error)")
            return []
        }
    }
    
    /// 获取播放次数最多的歌曲
    func getMostPlayed(limit: Int = 50) -> [CachedSong] {
        var descriptor = FetchDescriptor<CachedSong>(
            predicate: #Predicate { $0.playCount > 0 },
            sortBy: [SortDescriptor(\.playCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            AppLogger.error("获取最常播放失败: \(error)")
            return []
        }
    }
    
    // MARK: - 保存
    
    /// 保存单首歌曲
    func save(song: Song) {
        if let existing = getSong(id: song.id) {
            // 更新现有记录
            existing.name = song.name
            existing.artistName = song.artistName
            existing.albumName = song.al?.name
            existing.coverUrl = song.coverUrl?.absoluteString
            existing.duration = song.dt
            existing.cachedAt = Date()
        } else {
            // 创建新记录
            let cached = CachedSong(from: song)
            context.insert(cached)
        }
        
        try? context.save()
    }
    
    /// 批量保存歌曲（优化版 — 先批量查询已有 ID，减少逐条查询开销）
    func save(songs: [Song]) {
        guard !songs.isEmpty else { return }
        
        // 一次性查询所有已存在的歌曲 ID
        let ids = songs.map { $0.id }
        let existingMap: [Int: CachedSong] = {
            let predicate = #Predicate<CachedSong> { ids.contains($0.id) }
            let descriptor = FetchDescriptor<CachedSong>(predicate: predicate)
            let results = (try? context.fetch(descriptor)) ?? []
            return Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        }()
        
        for song in songs {
            if let existing = existingMap[song.id] {
                existing.name = song.name
                existing.artistName = song.artistName
                existing.albumName = song.al?.name
                existing.coverUrl = song.coverUrl?.absoluteString
                existing.duration = song.dt
                existing.cachedAt = Date()
            } else {
                let cached = CachedSong(from: song)
                context.insert(cached)
            }
        }
        
        try? context.save()
    }
    
    /// 记录播放
    func recordPlay(songId: Int) {
        if let song = getSong(id: songId) {
            song.recordPlay()
            try? context.save()
        }
    }
    
    // MARK: - 删除
    
    /// 删除歌曲
    func delete(id: Int) {
        if let song = getSong(id: id) {
            context.delete(song)
            try? context.save()
        }
    }
    
    /// 清空所有歌曲缓存
    func deleteAll() {
        do {
            try context.delete(model: CachedSong.self)
            try context.save()
        } catch {
            AppLogger.error("清空歌曲缓存失败: \(error)")
        }
    }
    
    // MARK: - 统计
    
    /// 获取缓存歌曲数量
    func count() -> Int {
        let descriptor = FetchDescriptor<CachedSong>()
        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}
