import Foundation

/// 歌单数据仓库
@MainActor
final class PlaylistRepository {
    private let store: MonoStore

    init(store: MonoStore = DatabaseManager.shared.store) {
        self.store = store
    }

    // MARK: - 查询

    /// 根据 ID 获取歌单
    func getPlaylist(id: Int) -> CachedPlaylist? {
        store.first(CachedPlaylist.self) { $0.id == id }
    }

    /// 获取用户歌单（根据创建者名称）
    func getUserPlaylists(creatorName: String) -> [CachedPlaylist] {
        store.fetch(
            CachedPlaylist.self,
            where: { $0.creatorName == creatorName },
            sortBy: { $0.cachedAt > $1.cachedAt }
        )
    }

    /// 获取最近访问的歌单
    func getRecentlyAccessed(limit: Int = 20) -> [CachedPlaylist] {
        store.fetch(
            CachedPlaylist.self,
            where: { $0.lastAccessedAt != nil },
            sortBy: { ($0.lastAccessedAt ?? .distantPast) > ($1.lastAccessedAt ?? .distantPast) },
            limit: limit
        )
    }

    // MARK: - 保存

    /// 保存歌单
    func save(playlist: Playlist, trackIds: [Int] = []) {
        if let existing = getPlaylist(id: playlist.id) {
            // 更新现有记录
            existing.name = playlist.name
            existing.coverUrl = playlist.coverUrl?.absoluteString
            existing.creatorName = playlist.creator?.nickname
            existing.trackCount = playlist.trackCount
            existing.playCount = playlist.playCount
            existing.desc = playlist.description
            existing.tags = playlist.tags
            existing.cachedAt = Date()
            if !trackIds.isEmpty {
                existing.trackIds = trackIds
            }
        } else {
            store.insert(CachedPlaylist(from: playlist, trackIds: trackIds))
        }

        store.save()
    }

    /// 批量保存歌单
    func save(playlists: [Playlist]) {
        for playlist in playlists {
            save(playlist: playlist)
        }
    }

    /// 更新歌单的歌曲 ID 列表
    func updateTrackIds(playlistId: Int, trackIds: [Int]) {
        if let playlist = getPlaylist(id: playlistId) {
            playlist.trackIds = trackIds
            playlist.trackCount = trackIds.count
            store.save()
        }
    }

    /// 记录访问
    func recordAccess(playlistId: Int) {
        if let playlist = getPlaylist(id: playlistId) {
            playlist.recordAccess()
            store.save()
        }
    }

    // MARK: - 删除

    /// 删除歌单
    func delete(id: Int) {
        if let playlist = getPlaylist(id: id) {
            store.delete(playlist)
            store.save()
        }
    }

    /// 清空所有歌单缓存
    func deleteAll() {
        store.deleteAll(CachedPlaylist.self)
        store.save()
    }

    // MARK: - 统计

    func count() -> Int {
        store.count(CachedPlaylist.self)
    }
}
