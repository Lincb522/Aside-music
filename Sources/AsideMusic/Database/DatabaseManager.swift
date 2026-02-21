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
                DownloadedSong.self,
                LocalPlaylist.self
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
                    DownloadedSong.self, LocalPlaylist.self
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
                    DownloadedSong.self, LocalPlaylist.self
                ])
                let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
                // 内存数据库初始化失败的可能性极低，但仍做安全处理
                do {
                    container = try ModelContainer(for: schema, configurations: [memConfig])
                } catch {
                    // 极端情况：内存数据库也失败，创建最小化容器
                    AppLogger.error("内存数据库初始化失败: \(error)")
                    do {
                        container = try ModelContainer(for: CachedSong.self)
                    } catch {
                        // 终极兜底：纯内存最小化容器
                        AppLogger.error("最小化容器也失败: \(error)，使用纯内存最小化容器")
                        let minimalConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                        // 此处如果仍然失败，说明系统级问题，无法恢复
                        // 使用 preconditionFailure 替代 try! 以提供更清晰的错误信息
                        guard let minimalContainer = try? ModelContainer(for: CachedSong.self, configurations: minimalConfig) else {
                            preconditionFailure("SwiftData 完全不可用，应用无法继续运行")
                        }
                        container = minimalContainer
                    }
                }
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
    
    // MARK: - 批量操作（事务优化）
    
    /// 批量执行操作后统一保存，减少 I/O 次数
    func performBatch(_ operations: () -> Void) {
        operations()
        save()
    }
    
    /// 异步批量操作（后台线程安全）
    func performBatchAsync(_ operations: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            operations()
            self.save()
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
    
    /// 智能清理过期数据 — 分层策略
    /// - 30天以上未访问的缓存直接删除
    /// - 7天以上未播放且播放次数为0的歌曲删除
    /// - 保留高频播放歌曲（playCount > 5）不受时间限制
    func cleanExpiredData(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        do {
            // 清理过期歌曲缓存（排除高频播放歌曲）
            let songPredicate = #Predicate<CachedSong> {
                $0.cachedAt < cutoffDate && $0.playCount <= 5
            }
            try context.delete(model: CachedSong.self, where: songPredicate)
            
            // 清理 7 天内未播放且从未播放过的歌曲
            let coldSongPredicate = #Predicate<CachedSong> {
                $0.cachedAt < recentCutoff && $0.playCount == 0 && $0.lastPlayedAt == nil
            }
            try context.delete(model: CachedSong.self, where: coldSongPredicate)
            
            // 清理过期歌单缓存
            let playlistPredicate = #Predicate<CachedPlaylist> { $0.cachedAt < cutoffDate }
            try context.delete(model: CachedPlaylist.self, where: playlistPredicate)
            
            // 清理过期艺术家缓存
            let artistPredicate = #Predicate<CachedArtist> { $0.cachedAt < cutoffDate }
            try context.delete(model: CachedArtist.self, where: artistPredicate)
            
            try context.save()
            AppLogger.success("智能清理完成：已清理 \(days) 天前的过期数据（保留高频歌曲）")
        } catch {
            AppLogger.error("清理过期数据失败: \(error)")
        }
    }
    
    // MARK: - 数据库健康检查
    
    /// 执行数据库健康检查和自动维护
    func performMaintenance() {
        let songCount = (try? context.fetchCount(FetchDescriptor<CachedSong>())) ?? 0
        let playlistCount = (try? context.fetchCount(FetchDescriptor<CachedPlaylist>())) ?? 0
        let historyCount = (try? context.fetchCount(FetchDescriptor<PlayHistory>())) ?? 0
        
        AppLogger.info("数据库状态 — 歌曲: \(songCount), 歌单: \(playlistCount), 历史: \(historyCount)")
        
        // 歌曲缓存超过 2000 条时自动清理最旧的
        if songCount > 2000 {
            cleanExpiredData(olderThan: 14)
        }
        
        // 播放历史超过 1000 条时裁剪
        if historyCount > 1000 {
            trimPlayHistory(keepCount: 500)
        }
    }
    
    /// 裁剪播放历史到指定数量
    private func trimPlayHistory(keepCount: Int) {
        do {
            let descriptor = FetchDescriptor<PlayHistory>(
                sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
            )
            let allHistory = try context.fetch(descriptor)
            if allHistory.count > keepCount {
                for history in allHistory.dropFirst(keepCount) {
                    context.delete(history)
                }
                try context.save()
                AppLogger.info("播放历史已裁剪至 \(keepCount) 条")
            }
        } catch {
            AppLogger.error("裁剪播放历史失败: \(error)")
        }
    }
}
