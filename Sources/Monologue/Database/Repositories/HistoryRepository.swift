import Foundation

/// 历史记录仓库
@MainActor
final class HistoryRepository {
    private let store: MonoStore

    init(store: MonoStore = DatabaseManager.shared.store) {
        self.store = store
    }

    // MARK: - 播放历史

    /// 添加播放记录
    func addPlayHistory(song: Song, duration: Int = 0, completed: Bool = false) {
        let history = PlayHistory(from: song, duration: duration, completed: completed)
        store.insert(history)

        // 限制历史记录数量
        trimPlayHistory(maxCount: 500)

        store.save()
    }

    /// 获取播放历史
    func getPlayHistory(limit: Int = 100) -> [PlayHistory] {
        store.fetch(
            PlayHistory.self,
            sortBy: { $0.playedAt > $1.playedAt },
            limit: limit
        )
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
