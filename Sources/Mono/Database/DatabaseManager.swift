import Foundation
import Combine

/// 数据库管理器（双持久化门面）
/// - iOS 17+：SwiftData 后端（沿用旧版实体与存储文件，老数据无缝保留）
/// - iOS 16：Core Data 后端（编程式模型，独立 SQLite 文件）
@MainActor
final class DatabaseManager {
    static let shared = DatabaseManager()

    /// 全部持久化实体
    static let allEntityTypes: [any MonoEntity.Type] = [
        CachedSong.self,
        CachedPlaylist.self,
        CachedArtist.self,
        PlayHistory.self,
        SearchHistory.self,
        CachedLyrics.self,
        DownloadedSong.self,
        LocalPlaylist.self
    ]

    let store: MonoStore
    let engine: MonoVaultEngine

    private init() {
        let resolvedStore: MonoStore
        if #available(iOS 17, *) {
            let backend = SwiftDataBackend()
            Self.migrateCoreDataStoreIfNeeded(into: backend)
            resolvedStore = MonoStore(backend: backend)
        } else {
            resolvedStore = MonoStore(backend: CoreDataBackend(entityTypes: Self.allEntityTypes))
        }
        store = resolvedStore
        engine = MonoVaultEngine(store: resolvedStore)
    }

    /// 用户从 iOS 16 升级到 iOS 17+ 时，将 Core Data 存储的数据一次性迁入 SwiftData
    @available(iOS 17, *)
    private static func migrateCoreDataStoreIfNeeded(into backend: SwiftDataBackend) {
        guard CoreDataBackend.storeExists else { return }
        AppLogger.info("检测到 iOS 16 时期的 Core Data 存储，开始迁移到 SwiftData")

        let source = CoreDataBackend(entityTypes: allEntityTypes)
        var migrated = 0
        for type in allEntityTypes {
            let name = type.monoEntityName
            for snapshot in source.loadAll(entityName: name) {
                let object = type.monoMake(from: snapshot)
                backend.upsert(entityName: name, uniqueKey: object.monoUniqueKey, snapshot: object.monoSnapshot())
                migrated += 1
            }
        }
        backend.flush()
        CoreDataBackend.destroyStore()
        AppLogger.success("Core Data -> SwiftData 迁移完成，共 \(migrated) 条记录")
    }

    // MARK: - Save

    func save() {
        engine.flush()
    }

    /// 合并短时间内的高频写入；强一致场景继续使用 `save()`。
    func scheduleSave() {
        engine.scheduleFlush()
    }

    // MARK: - 批量操作（事务优化）

    /// 批量执行操作后统一保存，减少 I/O 次数
    func performBatch(_ operations: () -> Void) {
        engine.performBatch(operations)
    }

    /// 异步批量操作（后台线程安全）
    func performBatchAsync(_ operations: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            self.engine.performBatch {
                operations()
            }
        }
    }

    // MARK: - 数据库大小

    func calculateDatabaseSize() -> String {
        let size = store.storeSizeBytes()
        if size <= 0 { return "0 MB" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    // MARK: - 清理数据库

    /// 清空缓存数据（保留下载记录和本地歌单）
    func clearCacheData() {
        store.deleteAll(CachedSong.self)
        store.deleteAll(CachedPlaylist.self)
        store.deleteAll(CachedArtist.self)
        store.deleteAll(PlayHistory.self)
        store.deleteAll(SearchHistory.self)
        store.deleteAll(CachedLyrics.self)
        save()
        AppLogger.success("数据库缓存已清空（保留下载记录和本地歌单）")
    }

    /// 清空所有数据（包括下载记录和本地歌单）
    func clearAllData() {
        store.deleteAll(CachedSong.self)
        store.deleteAll(CachedPlaylist.self)
        store.deleteAll(CachedArtist.self)
        store.deleteAll(PlayHistory.self)
        store.deleteAll(SearchHistory.self)
        store.deleteAll(CachedLyrics.self)
        store.deleteAll(DownloadedSong.self)
        store.deleteAll(LocalPlaylist.self)
        save()
        AppLogger.success("数据库已清空（含下载记录和本地歌单）")
    }

    // MARK: - 清理过期数据

    /// 智能清理过期数据 — 分层策略
    /// - 30天以上未访问的缓存直接删除
    /// - 7天以上未播放且播放次数为0的歌曲删除
    /// - 保留高频播放歌曲（playCount > 5）不受时间限制
    func cleanExpiredData(olderThan days: Int = 30) {
        engine.purgeExpiredCaches(olderThan: days)
        AppLogger.success("智能清理完成：已清理 \(days) 天前的过期数据（保留高频歌曲）")
    }

    // MARK: - 数据库健康检查

    /// 执行数据库健康检查和自动维护
    func performMaintenance() {
        engine.performMaintenance()
    }

    func databaseHealth() -> MonoVaultHealth {
        engine.health()
    }
}
