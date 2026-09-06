import Foundation

struct MonoVaultMaintenanceReport: Sendable {
    let cachedSongs: Int
    let cachedPlaylists: Int
    let cachedArtists: Int
    let cachedLyrics: Int
    let searchHistory: Int
    let playHistory: Int
    let downloadedSongs: Int
    let localPlaylists: Int
    let didTrimSongs: Bool
    let didTrimHistory: Bool
    let storeSizeBytes: Int64
}

struct MonoVaultHealth: Sendable {
    let storeSizeBytes: Int64
    let pendingWrites: Int
    let loadedEntities: [String]
    let cachedSongs: Int
    let cachedPlaylists: Int
    let cachedArtists: Int
    let cachedLyrics: Int
    let searchHistory: Int
    let playHistory: Int
    let downloadedSongs: Int
    let localPlaylists: Int
}

/// MonoVault Engine：App 端统一数据库引擎。
///
/// SwiftData 与 Core Data 继续由 `MonoStore` 屏蔽差异；本层负责写入合并、
/// 每日维护和容量治理，避免每个业务模块各自实现保存/裁剪策略。
@MainActor
final class MonoVaultEngine {
    private enum Keys {
        static let lastMaintenanceDate = "mono_database_engine_last_maintenance"
    }

    private let store: MonoStore
    private var scheduledFlush: Task<Void, Never>?

    init(store: MonoStore) {
        self.store = store
    }

    @discardableResult
    func flush() -> Bool {
        scheduledFlush?.cancel()
        scheduledFlush = nil
        return store.save()
    }

    func scheduleFlush(after delay: Duration = .milliseconds(350)) {
        scheduledFlush?.cancel()
        scheduledFlush = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// 统一批处理入口，确保一批仓库写入只触发一次底层保存。
    func performBatch(_ operations: () -> Void) {
        store.performBatch(operations)
    }

    func health() -> MonoVaultHealth {
        MonoVaultHealth(
            storeSizeBytes: store.storeSizeBytes(),
            pendingWrites: store.pendingWriteCount,
            loadedEntities: store.loadedEntityNames,
            cachedSongs: store.count(CachedSong.self),
            cachedPlaylists: store.count(CachedPlaylist.self),
            cachedArtists: store.count(CachedArtist.self),
            cachedLyrics: store.count(CachedLyrics.self),
            searchHistory: store.count(SearchHistory.self),
            playHistory: store.count(PlayHistory.self),
            downloadedSongs: store.count(DownloadedSong.self),
            localPlaylists: store.count(LocalPlaylist.self)
        )
    }

    /// 清理所有可再生缓存，不触碰下载文件和用户创建的本地歌单。
    func purgeExpiredCaches(olderThan days: Int = 30, date: Date = Date()) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date
        store.deleteAll(CachedSong.self) { $0.cachedAt < cutoff && $0.playCount <= 5 }
        store.deleteAll(CachedSong.self) {
            $0.cachedAt < recentCutoff && $0.playCount == 0 && $0.lastPlayedAt == nil
        }
        store.deleteAll(CachedPlaylist.self) { $0.cachedAt < cutoff }
        store.deleteAll(CachedArtist.self) { $0.cachedAt < cutoff }
        store.deleteAll(CachedLyrics.self) { $0.cachedAt < cutoff }
        store.deleteAll(SearchHistory.self) {
            $0.searchedAt < (Calendar.current.date(byAdding: .day, value: -90, to: date) ?? date)
        }
        flush()
    }

    @discardableResult
    func performMaintenance(force: Bool = false, date: Date = Date()) -> MonoVaultMaintenanceReport? {
        let day = Calendar.current.startOfDay(for: date)
        if !force,
           let last = UserDefaults.standard.object(forKey: Keys.lastMaintenanceDate) as? Date,
           Calendar.current.isDate(last, inSameDayAs: day) {
            return nil
        }

        let initialSongCount = store.count(CachedSong.self)
        let initialHistoryCount = store.count(PlayHistory.self)
        var didTrimSongs = false
        var didTrimHistory = false

        if initialSongCount > 2_000 {
            let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: date) ?? date
            store.deleteAll(CachedSong.self) {
                $0.cachedAt < cutoff && $0.playCount <= 5
            }
            didTrimSongs = true
        }

        if initialHistoryCount > 20_000 {
            let ordered = store.fetch(PlayHistory.self, sortBy: { $0.playedAt > $1.playedAt })
            for history in ordered.dropFirst(20_000) {
                store.delete(history)
            }
            didTrimHistory = initialHistoryCount > 20_000
        }

        // 全局缓存的过期策略统一由引擎执行，下载记录和本地歌单永不自动删除。
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: date) ?? date
        store.deleteAll(CachedSong.self) { $0.cachedAt < cutoff && $0.playCount <= 5 }
        store.deleteAll(CachedPlaylist.self) { $0.cachedAt < cutoff }
        store.deleteAll(CachedArtist.self) { $0.cachedAt < cutoff }
        store.deleteAll(CachedLyrics.self) { $0.cachedAt < cutoff }
        let searchCutoff = Calendar.current.date(byAdding: .day, value: -90, to: date) ?? date
        store.deleteAll(SearchHistory.self) { $0.searchedAt < searchCutoff }

        guard flush() else { return nil }
        UserDefaults.standard.set(day, forKey: Keys.lastMaintenanceDate)

        let report = MonoVaultMaintenanceReport(
            cachedSongs: store.count(CachedSong.self),
            cachedPlaylists: store.count(CachedPlaylist.self),
            cachedArtists: store.count(CachedArtist.self),
            cachedLyrics: store.count(CachedLyrics.self),
            searchHistory: store.count(SearchHistory.self),
            playHistory: store.count(PlayHistory.self),
            downloadedSongs: store.count(DownloadedSong.self),
            localPlaylists: store.count(LocalPlaylist.self),
            didTrimSongs: didTrimSongs,
            didTrimHistory: didTrimHistory,
            storeSizeBytes: store.storeSizeBytes()
        )
        AppLogger.info(
            "MonoVault 全局维护完成 — 歌曲: \(report.cachedSongs), 歌单: \(report.cachedPlaylists), 歌手: \(report.cachedArtists), 歌词: \(report.cachedLyrics), 搜索: \(report.searchHistory), 历史: \(report.playHistory), 下载: \(report.downloadedSongs), 本地歌单: \(report.localPlaylists)"
        )
        return report
    }
}

typealias DatabaseMaintenanceReport = MonoVaultMaintenanceReport
typealias MonoDatabaseEngine = MonoVaultEngine
