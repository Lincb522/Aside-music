import Foundation
import Combine

/// 歌曲数据仓库
@MainActor
final class SongRepository {
    private let store: MonoStore

    init(store: MonoStore = DatabaseManager.shared.store) {
        self.store = store
    }

    // MARK: - 查询

    /// 根据 ID 获取歌曲
    func getSong(id: Int) -> CachedSong? {
        store.first(CachedSong.self) { $0.id == id }
    }

    /// 批量获取歌曲
    func getSongs(ids: [Int]) -> [CachedSong] {
        let idSet = Set(ids)
        return store.fetch(CachedSong.self, where: { idSet.contains($0.id) })
    }

    /// 获取最近播放的歌曲
    func getRecentlyPlayed(limit: Int = 50) -> [CachedSong] {
        store.fetch(
            CachedSong.self,
            where: { $0.lastPlayedAt != nil },
            sortBy: { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) },
            limit: limit
        )
    }

    /// 启动预热候选：优先最近播放，其余按最近缓存时间补足。
    /// 不能只筛选 lastPlayedAt，否则刚从首页/资料库缓存、尚未播放过的歌曲会全部漏掉。
    func getWarmupCandidates(limit: Int = 50) -> [CachedSong] {
        store.fetch(
            CachedSong.self,
            sortBy: { lhs, rhs in
                switch (lhs.lastPlayedAt, rhs.lastPlayedAt) {
                case let (left?, right?):
                    return left > right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.cachedAt > rhs.cachedAt
                }
            },
            limit: limit
        )
    }

    /// 获取播放次数最多的歌曲
    func getMostPlayed(limit: Int = 50) -> [CachedSong] {
        store.fetch(
            CachedSong.self,
            where: { $0.playCount > 0 },
            sortBy: { $0.playCount > $1.playCount },
            limit: limit
        )
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
            store.insert(CachedSong(from: song))
        }

        store.save()
    }

    /// 批量保存歌曲
    func save(songs: [Song]) {
        guard !songs.isEmpty else { return }

        let ids = Set(songs.map { $0.id })
        let existingMap: [Int: CachedSong] = {
            let results = store.fetch(CachedSong.self, where: { ids.contains($0.id) })
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
                store.insert(CachedSong(from: song))
            }
        }

        store.save()
    }

    /// 记录播放
    func recordPlay(songId: Int) {
        if let song = getSong(id: songId) {
            song.recordPlay()
            store.save()
        }
    }

    // MARK: - 删除

    /// 删除歌曲
    func delete(id: Int) {
        if let song = getSong(id: id) {
            store.delete(song)
            store.save()
        }
    }

    /// 清空所有歌曲缓存
    func deleteAll() {
        store.deleteAll(CachedSong.self)
        store.save()
    }

    // MARK: - 统计

    /// 获取缓存歌曲数量
    func count() -> Int {
        store.count(CachedSong.self)
    }
}
