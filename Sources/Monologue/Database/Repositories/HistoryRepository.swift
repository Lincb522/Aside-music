import Foundation

/// 历史记录仓库
@MainActor
final class HistoryRepository {
    private let store: MonoStore

    init(store: MonoStore = DatabaseManager.shared.store) {
        self.store = store
    }

    // MARK: - 播放历史

    /// 添加播放记录，返回新建的行（听歌统计会持续把真实播放秒数写回这一行）
    @discardableResult
    func addPlayHistory(song: Song, duration: Int = 0, completed: Bool = false) -> PlayHistory {
        let history = PlayHistory(from: song, duration: duration, completed: completed)
        store.insert(history)

        // 播放日志是听歌统计的数据源，只按总量兜底裁剪，不再 500 条就丢
        trimPlayHistory(maxCount: 20000)

        store.save()
        return history
    }

    /// 获取播放历史；cutoff 之后的才返回（「最近播放」清空只挪 cutoff，不删统计日志）
    func getPlayHistory(limit: Int = 100, after cutoff: Date? = nil) -> [PlayHistory] {
        let predicate: ((PlayHistory) -> Bool)? = cutoff.map { cutoff in
            { $0.playedAt > cutoff }
        }
        return store.fetch(
            PlayHistory.self,
            where: predicate,
            sortBy: { $0.playedAt > $1.playedAt },
            limit: limit
        )
    }

    /// 播放中的行属性被就地更新（真实播放秒数）后落盘
    func savePlayHistoryUpdates() {
        store.save()
    }

    func makeCloudPlaybackHistorySnapshot() -> CloudPlaybackHistorySnapshot? {
        let records = store.fetchAll(PlayHistory.self)
            .sorted { $0.playedAt > $1.playedAt }
            .prefix(20_000)
            .map { CloudPlayHistoryRecord(from: $0) }
        let clearedAtValue = UserDefaults.standard.double(forKey: "playHistory.recentClearedAt")
        let clearedAt = clearedAtValue > 0 ? Date(timeIntervalSince1970: clearedAtValue) : nil

        guard !records.isEmpty || clearedAt != nil else { return nil }
        return CloudPlaybackHistorySnapshot(
            records: Array(records),
            recentClearedAt: clearedAt
        )
    }

    @discardableResult
    func mergeCloudPlaybackHistory(_ snapshot: CloudPlaybackHistorySnapshot) -> Int {
        let localRecords = store.fetchAll(PlayHistory.self)
        var existingByID = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.id, $0) })
        var inserted = 0

        for remote in snapshot.records {
            if let local = existingByID[remote.id] {
                local.playDuration = max(local.playDuration, remote.playDuration)
                local.completed = local.completed || remote.completed
                if local.coverUrl == nil { local.coverUrl = remote.coverUrl }
                if local.sourceRaw == nil { local.sourceRaw = remote.sourceRaw }
                if local.qqMid == nil { local.qqMid = remote.qqMid }
                if local.qqAlbumMid == nil { local.qqAlbumMid = remote.qqAlbumMid }
                if local.qishuiTrackId == nil { local.qishuiTrackId = remote.qishuiTrackId }
                if local.appleMusicID == nil { local.appleMusicID = remote.appleMusicID }
                if local.appleMusicISRC == nil { local.appleMusicISRC = remote.appleMusicISRC }
            } else {
                let record = remote.makeLocalRecord()
                store.insert(record)
                existingByID[remote.id] = record
                inserted += 1
            }
        }

        if let remoteClearedAt = snapshot.recentClearedAt {
            let localValue = UserDefaults.standard.double(forKey: "playHistory.recentClearedAt")
            if remoteClearedAt.timeIntervalSince1970 > localValue {
                UserDefaults.standard.set(
                    remoteClearedAt.timeIntervalSince1970,
                    forKey: "playHistory.recentClearedAt"
                )
            }
        }

        trimPlayHistory(maxCount: 20_000)
        store.save()
        ListeningReportCenter.shared.retryAfterHistoryRestore()
        return inserted
    }

    /// 获取某首歌的播放历史
    func getPlayHistory(songId: Int) -> [PlayHistory] {
        store.fetch(
            PlayHistory.self,
            where: { $0.songId == songId },
            sortBy: { $0.playedAt > $1.playedAt }
        )
    }

    /// 清理播放历史（保留最近 N 条）
    private func trimPlayHistory(maxCount: Int) {
        let allHistory = store.fetch(PlayHistory.self, sortBy: { $0.playedAt > $1.playedAt })
        if allHistory.count > maxCount {
            for history in allHistory.dropFirst(maxCount) {
                store.delete(history)
            }
        }
    }

    /// 清空播放历史
    func clearPlayHistory() {
        store.deleteAll(PlayHistory.self)
        store.save()
    }

    // MARK: - 搜索历史

    /// 添加搜索记录
    func addSearchHistory(keyword: String, resultCount: Int = 0) {
        // 先删除相同关键词的旧记录
        store.deleteAll(SearchHistory.self) { $0.keyword == keyword }

        // 添加新记录
        store.insert(SearchHistory(keyword: keyword, resultCount: resultCount))

        // 限制搜索历史数量
        trimSearchHistory(maxCount: 50)

        store.save()
    }

    /// 获取搜索历史
    func getSearchHistory(limit: Int = 20) -> [SearchHistory] {
        store.fetch(
            SearchHistory.self,
            sortBy: { $0.searchedAt > $1.searchedAt },
            limit: limit
        )
    }

    /// 删除搜索记录
    func deleteSearchHistory(keyword: String) {
        store.deleteAll(SearchHistory.self) { $0.keyword == keyword }
        store.save()
    }

    /// 清理搜索历史（保留最近 N 条）
    private func trimSearchHistory(maxCount: Int) {
        let allHistory = store.fetch(SearchHistory.self, sortBy: { $0.searchedAt > $1.searchedAt })
        if allHistory.count > maxCount {
            for history in allHistory.dropFirst(maxCount) {
                store.delete(history)
            }
        }
    }

    /// 清空搜索历史
    func clearSearchHistory() {
        store.deleteAll(SearchHistory.self)
        store.save()
    }

    // MARK: - 歌词缓存

    /// 保存歌词
    func saveLyrics(songId: Int, lyrics: String, translated: String? = nil) {
        // 先删除旧的
        store.deleteAll(CachedLyrics.self) { $0.songId == songId }

        // 添加新的
        store.insert(CachedLyrics(songId: songId, lyrics: lyrics, translatedLyrics: translated))

        store.save()
    }

    /// 获取歌词
    func getLyrics(songId: Int) -> CachedLyrics? {
        store.first(CachedLyrics.self) { $0.songId == songId }
    }

    func deleteLyrics(songId: Int) {
        store.deleteAll(CachedLyrics.self) { $0.songId == songId }
        store.save()
    }
}
