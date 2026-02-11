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
                CachedLyrics.self,
                DownloadedSong.self
            ])
            
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            container = try ModelContainer(for: schema, configurations: [config])
            context = container.mainContext
            context.autosaveEnabled = true
            
            AppLogger.success("SwiftData 初始化成功")
        } catch {
            // 数据库损坏时尝试删除后重建，避免 Release 崩溃
            AppLogger.error("SwiftData 初始化失败: \(error)，尝试重建数据库")
            
            // 删除损坏的数据库文件
            let fileManager = FileManager.default
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dbPath = appSupport.appendingPathComponent("default.store")
                try? fileManager.removeItem(at: dbPath)
                // 同时删除 WAL 和 SHM 文件
                try? fileManager.removeItem(at: dbPath.appendingPathExtension("wal"))
                try? fileManager.removeItem(at: dbPath.appendingPathExtension("shm"))
            }
            
            do {
                let schema = Schema([
                    CachedSong.self, CachedPlaylist.self, CachedArtist.self,
                    PlayHistory.self, SearchHistory.self, CachedLyrics.self,
                    DownloadedSong.self
                ])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
                container = try ModelContainer(for: schema, configurations: [config])
                context = container.mainContext
                context.autosaveEnabled = true
                AppLogger.success("SwiftData 重建成功")
            } catch {
                // 最后兜底：使用内存数据库，确保 App 不崩溃
                AppLogger.error("SwiftData 重建失败: \(error)，降级为内存数据库")
                let schema = Schema([
                    CachedSong.self, CachedPlaylist.self, CachedArtist.self,
                    PlayHistory.self, SearchHistory.self, CachedLyrics.self,
                    DownloadedSong.self
                ])
                let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
                // swiftlint:disable:next force_try
                container = try! ModelContainer(for: schema, configurations: [memConfig])
                context = container.mainContext
                context.autosaveEnabled = true
            }
        }
    }
    
    // MARK: - Save
    
    func save() {
        do {
            try context.save()
        } catch {
            AppLogger.error("SwiftData 保存失败: \(error)")
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
            AppLogger.success("数据库已清空")
        } catch {
            AppLogger.error("清空数据库失败: \(error)")
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
            AppLogger.success("已清理 \(days) 天前的过期数据")
        } catch {
            AppLogger.error("清理过期数据失败: \(error)")
        }
    }
}
