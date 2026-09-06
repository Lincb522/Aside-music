import Foundation
import Combine

/// 数据库管理器（双持久化门面）
/// - iOS 17+：SwiftData 后端（沿用旧版实体与存储文件，老数据无缝保留）
/// - iOS 16：Core Data 后端（编程式模型，独立 SQLite 文件）
@MainActor
final class DatabaseManager: ObservableObject {
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

    @Published private(set) var initializationError: String?

    private let openBackend: @MainActor () throws -> any MonoStoreBackend

    init(openBackend: @escaping @MainActor () throws -> any MonoStoreBackend = DatabaseManager.openDefaultBackend) {
        self.openBackend = openBackend
        let store = MonoStore()
        self.store = store
        engine = MonoVaultEngine(store: store)
        retryInitialization()
    }

    func retryInitialization() {
        guard !store.isAvailable else { return }
        do {
            store.open(backend: try openBackend())
            initializationError = nil
        } catch {
            initializationError = error.localizedDescription
            AppLogger.error("Database unavailable; original store retained: \(error.localizedDescription)")
        }
    }

    static func openDefaultBackend() throws -> any MonoStoreBackend {
        if #available(iOS 17, *) {
            let backend = try SwiftDataBackend()
            try migrateCoreDataStoreIfNeeded(into: backend)
            return backend
        }
        return try CoreDataBackend(entityTypes: allEntityTypes)
    }

    @available(iOS 17, *)
    private static func migrateCoreDataStoreIfNeeded(into backend: SwiftDataBackend) throws {
        let completionKey = "mono_core_data_migration_committed_v1"
        guard CoreDataBackend.storeExists,
              !UserDefaults.standard.bool(forKey: completionKey) else { return }

        let source = try CoreDataBackend(entityTypes: allEntityTypes)
        try migrateStore(from: source, into: backend, reopen: { try SwiftDataBackend() })
        UserDefaults.standard.set(true, forKey: completionKey)
        AppLogger.success("Core Data migration committed and verified; recovery copy retained")
    }

    static func migrateStore(
        from source: any MonoStoreBackend,
        into backend: any MonoStoreBackend,
        reopen: @MainActor () throws -> any MonoStoreBackend
    ) throws {
        var expected: [String: [String: [String: Any?]]] = [:]
        for type in allEntityTypes {
            let name = type.monoEntityName
            var records = Dictionary(uniqueKeysWithValues: backend.loadAll(entityName: name).map {
                let entity = type.monoMake(from: $0)
                return (entity.monoUniqueKey, entity.monoSnapshot())
            })
            for snapshot in source.loadAll(entityName: name) {
                let entity = type.monoMake(from: snapshot)
                // A retry must not replace records already edited in the destination.
                guard records[entity.monoUniqueKey] == nil else { continue }
                let normalized = entity.monoSnapshot()
                backend.upsert(entityName: name, uniqueKey: entity.monoUniqueKey, snapshot: normalized)
                records[entity.monoUniqueKey] = normalized
            }
            expected[name] = records
        }
        try backend.flush()

        // Read back from a new context before the caller marks migration complete.
        // The source remains untouched as a recovery copy.
        let persisted = try reopen()
        for type in allEntityTypes {
            let actual = Dictionary(uniqueKeysWithValues: persisted.loadAll(entityName: type.monoEntityName).map {
                let entity = type.monoMake(from: $0)
                return (entity.monoUniqueKey, entity.monoSnapshot())
            })
            for (key, snapshot) in expected[type.monoEntityName] ?? [:] {
                guard let saved = actual[key],
                      NSDictionary(dictionary: snapshot.compactMapValues { $0 })
                        .isEqual(to: saved.compactMapValues { $0 }) else {
                    throw CocoaError(.persistentStoreSave)
                }
            }
        }
    }

    // MARK: - Save

    @discardableResult
    func save() -> Bool {
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

    /// Clear regenerable caches while retaining user records.
    func clearCacheData() {
        store.deleteAll(CachedSong.self)
        store.deleteAll(CachedPlaylist.self)
        store.deleteAll(CachedArtist.self)
        store.deleteAll(CachedLyrics.self)
        if save() { AppLogger.success("数据库缓存已清空，用户记录已保留") }
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
