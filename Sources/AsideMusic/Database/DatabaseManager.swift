import Foundation
import SwiftData
import Combine

/// SwiftData 数据库管理器
/// 用于本地持久化存储，优化缓存加载机制
@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()
    
    // MARK: - SwiftData Container
    
    let container: ModelContainer
    let context: ModelContext
    
    private init() {
        do {
            let schema = Schema([
                CachedSong.self,
                CachedPlaylist.self,
                CachedArtist.self,
                PlayHistory.self,
                SearchHistory.self,
                CachedLyrics.self
            ])
            
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            container = try ModelContainer(for: schema, configurations: [config])
            context = container.mainContext
            context.autosaveEnabled = true
            
            print("✅ SwiftData 初始化成功")
        } catch {
            fatalError("❌ SwiftData 初始化失败: \(error)")
        }
    }
    
    // MARK: - Save
    
    func save() {
        do {
            try context.save()
        } catch {
            print("❌ SwiftData 保存失败: \(error)")
        }
    }
    
    // MARK: - 数据库大小
    
    func calculateDatabaseSize() -> String {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return "0 MB"
        }
        
        let dbPath = appSupport.appendingPathComponent("default.store")
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: dbPath.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            // 数据库文件可能不存在或路径不同
        }
        
        return "0 MB"
    }
    
    // MARK: - 清理数据库
    
    func clearAllData() {
        do {
            try context.delete(model: CachedSong.self)
            try context.delete(model: CachedPlaylist.self)
            try context.delete(model: CachedArtist.self)
            try context.delete(model: PlayHistory.self)
            try context.delete(model: SearchHistory.self)
            try context.delete(model: CachedLyrics.self)
            try context.save()
            print("✅ 数据库已清空")
        } catch {
            print("❌ 清空数据库失败: \(error)")
        }
    }
    
    // MARK: - 清理过期数据
    
    func cleanExpiredData(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        do {
            // 清理过期歌曲缓存
            let songPredicate = #Predicate<CachedSong> { $0.cachedAt < cutoffDate }
            try context.delete(model: CachedSong.self, where: songPredicate)
            
            // 清理过期歌单缓存
            let playlistPredicate = #Predicate<CachedPlaylist> { $0.cachedAt < cutoffDate }
            try context.delete(model: CachedPlaylist.self, where: playlistPredicate)
            
            // 清理过期艺术家缓存
            let artistPredicate = #Predicate<CachedArtist> { $0.cachedAt < cutoffDate }
            try context.delete(model: CachedArtist.self, where: artistPredicate)
            
            try context.save()
            print("✅ 已清理 \(days) 天前的过期数据")
        } catch {
            print("❌ 清理过期数据失败: \(error)")
        }
    }
}
