import Foundation
import Combine

struct LocalPlaylistExportPayload {
    let data: Data
    let suggestedFileName: String
}

struct LocalPlaylistSummary: Equatable {
    let id: String
    let name: String
    let desc: String?
    let isSystem: Bool
    let isFavorite: Bool
    let isLocalMusic: Bool
    let isDownload: Bool
    let trackCount: Int
    let displayCoverUrl: URL?
    let updatedAt: Date

    init(playlist: LocalPlaylist, songs: [Song]) {
        self.id = playlist.id
        self.name = playlist.name
        self.desc = playlist.desc
        self.isSystem = playlist.isSystem
        self.isFavorite = playlist.isFavorite
        self.isLocalMusic = playlist.isLocalMusic
        self.isDownload = playlist.isDownload
        self.trackCount = songs.count
        self.displayCoverUrl = Self.resolveCoverUrl(playlist: playlist, songs: songs)
        self.updatedAt = playlist.updatedAt
    }

    private static func resolveCoverUrl(playlist: LocalPlaylist, songs: [Song]) -> URL? {
        if let url = playlist.coverUrl, !url.isEmpty {
            return URL(string: url)
        }
        return songs.first?.coverUrl
    }
}

private struct LocalPlaylistCacheSignature: Equatable {
    let name: String
    let desc: String?
    let coverUrl: String?
    let updatedAt: Date
    let songsDataSize: Int
    let isSystem: Bool

    init(playlist: LocalPlaylist) {
        self.name = playlist.name
        self.desc = playlist.desc
        self.coverUrl = playlist.coverUrl
        self.updatedAt = playlist.updatedAt
        self.songsDataSize = playlist.songsData?.count ?? 0
        self.isSystem = playlist.isSystem
    }
}

/// 本地歌单管理器
@MainActor
class LocalPlaylistManager: ObservableObject {
    static let shared = LocalPlaylistManager()
    
    @Published var playlists: [LocalPlaylist] = []
    private(set) var revision = 0
    
    private let store: MonoStore
    private var downloadSyncCancellable: AnyCancellable?
    private var summaryCache: [String: (signature: LocalPlaylistCacheSignature, summary: LocalPlaylistSummary)] = [:]
    private var songCache: [String: (signature: LocalPlaylistCacheSignature, songs: [Song], ids: Set<Int>)] = [:]
    
    private init() {
        self.store = DatabaseManager.shared.store
        ensureSystemPlaylists()
        reload()
        observeDownloads()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.syncLocalMusicPlaylist()
        }
    }
    
    // MARK: - 系统预置歌单
    
    /// 确保「我喜欢」「本地音乐」歌单存在。
    /// 旧「下载」系统歌单不再新建、也绝不删除：老用户的历史下载条目
    /// 原样保留在库里，内容并入「本地音乐」统一展示。
    private func ensureSystemPlaylists() {
        let favId = LocalPlaylist.favoriteId
        let localMusicId = LocalPlaylist.localMusicId
        
        if store.first(LocalPlaylist.self, where: { $0.id == favId }) == nil {
            let fav = LocalPlaylist(id: favId, name: String(localized: "我喜欢"), isSystem: true)
            store.insert(fav)
        }

        if store.first(LocalPlaylist.self, where: { $0.id == localMusicId }) == nil {
            let localMusic = LocalPlaylist(id: localMusicId, name: String(localized: "本地音乐"), isSystem: true)
            store.insert(localMusic)
        }

        store.save()
    }
    
    // MARK: - 刷新
    
    func reload() {
        var all = store.fetch(LocalPlaylist.self, sortBy: { $0.updatedAt > $1.updatedAt })
        
        // 系统歌单置顶：我喜欢 > 本地音乐 > 其他按 updatedAt 排序。
        // 旧「下载」歌单仍留在库里（历史数据不动），只是不再单独展示：
        // 其内容已并入「本地音乐」。
        let favorite = all.first { $0.isFavorite }
        let localMusic = all.first { $0.isLocalMusic }
        all.removeAll { $0.isSystem }
        
        var sorted: [LocalPlaylist] = []
        if let f = favorite { sorted.append(f) }
        if let l = localMusic { sorted.append(l) }
        sorted.append(contentsOf: all)
        
        trimCaches(validIds: Set(sorted.map(\.id)))
        revision += 1
        playlists = sorted
    }
    
    // MARK: - 预置歌单快捷访问
    
    var favoritePlaylist: LocalPlaylist? {
        playlists.first { $0.isFavorite }
    }

    var localMusicPlaylist: LocalPlaylist? {
        playlists.first { $0.isLocalMusic }
    }

    /// 旧「下载」系统歌单（已并入本地音乐，不在 playlists 中展示，
    /// 仅供同步/恢复历史下载记录时读写）
    var downloadPlaylist: LocalPlaylist? {
        store.first(LocalPlaylist.self, where: { $0.id == LocalPlaylist.downloadId })
    }
    
    /// 检查歌曲是否在「我喜欢」歌单中
    func isFavorite(songId: Int) -> Bool {
        guard let favoritePlaylist else { return false }
        return songIds(for: favoritePlaylist).contains(songId)
    }

    func summary(for playlist: LocalPlaylist) -> LocalPlaylistSummary {
        let signature = LocalPlaylistCacheSignature(playlist: playlist)
        if let cached = summaryCache[playlist.id], cached.signature == signature {
            return cached.summary
        }

        let songs = songs(for: playlist)
        let summary = LocalPlaylistSummary(playlist: playlist, songs: songs)
        summaryCache[playlist.id] = (signature, summary)
        return summary
    }

    func songs(for playlist: LocalPlaylist) -> [Song] {
        let signature = LocalPlaylistCacheSignature(playlist: playlist)
        if let cached = songCache[playlist.id], cached.signature == signature {
            return cached.songs
        }

        let songs = playlist.songs
        songCache[playlist.id] = (signature, songs, Set(songs.map(\.id)))
        return songs
    }

    func songIds(for playlist: LocalPlaylist) -> Set<Int> {
        let signature = LocalPlaylistCacheSignature(playlist: playlist)
        if let cached = songCache[playlist.id], cached.signature == signature {
            return cached.ids
        }

        let songs = playlist.songs
        let ids = Set(songs.map(\.id))
        songCache[playlist.id] = (signature, songs, ids)
        return ids
    }

    func contains(songId: Int, in playlist: LocalPlaylist) -> Bool {
        songIds(for: playlist).contains(songId)
    }

    func addableSongCount(_ songs: [Song], for playlist: LocalPlaylist) -> Int {
        let existingIds = songIds(for: playlist)
        return songs.reduce(0) { partial, song in
            partial + (existingIds.contains(song.id) ? 0 : 1)
        }
    }
    
    /// 添加到「我喜欢」
    func addToFavorite(_ song: Song) {
        guard let fav = favoritePlaylist else { return }
        addSong(song, to: fav)
    }
    
    /// 从「我喜欢」移除
    func removeFromFavorite(songId: Int) {
        guard let fav = favoritePlaylist else { return }
        removeSong(id: songId, from: fav)
    }
    
    // MARK: - 下载 / 本地音乐同步（下载内容并入本地音乐展示）
    
    private func observeDownloads() {
        downloadSyncCancellable = DownloadManager.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncDownloadPlaylist()
            }
    }
    
    /// 下载记录变化时：先把记录镜像回旧「下载」歌单（老用户历史数据存档），
    /// 再刷新合并后的「本地音乐」歌单
    func syncDownloadPlaylist() {
        let songs = DownloadManager.shared.fetchDownloadPlaylistSongs()

        if let target = downloadPlaylist {
            target.songs = songs
            store.save()
        }

        syncLocalMusicPlaylist()
    }

    /// 本地音乐歌单 = 导入的本地曲库 + 已下载歌曲（含旧下载歌单存档与云端恢复的记录），按 id 去重
    func syncLocalMusicPlaylist(with librarySongs: [Song]? = nil) {
        guard let localMusic = localMusicPlaylist else { return }
        let playlistId = localMusic.id
        guard let target = store.first(LocalPlaylist.self, where: { $0.id == playlistId }) else { return }

        let imported = librarySongs ?? LocalMusicLibraryManager.shared.songs
        let downloads = DownloadManager.shared.fetchDownloadPlaylistSongs()
        // 兜底：旧「下载」歌单里可能还留有下载记录已丢失的历史条目，一并展示
        // （用户明确删除过的条目按墓碑过滤，避免"删了又回来"）
        let legacyArchived = (downloadPlaylist.map { songs(for: $0) } ?? [])
            .filter { !DownloadTombstoneStore.shared.isTombstoned(songId: $0.id) }

        var seen = Set<Int>()
        var merged: [Song] = []
        for song in imported + downloads + legacyArchived {
            guard seen.insert(song.id).inserted else { continue }
            merged.append(song)
        }

        target.songs = merged
        store.save()
        reload()
    }

    /// 在「本地音乐」里删除一首已下载歌曲：
    /// 删除该 id 的**全部**下载记录与音频文件（兼容历史 key 变体与云端恢复的重复记录），
    /// 并清掉旧「下载」存档里的对应条目，避免同步时被重新并回
    func removeDownloadedSong(_ song: Song) {
        DownloadManager.shared.deleteAllDownloadRecords(for: song)

        if let archive = downloadPlaylist {
            var current = songs(for: archive)
            let originalCount = current.count
            current.removeAll { $0.id == song.id }
            if current.count != originalCount {
                archive.songs = current
                store.save()
            }
        }

        syncLocalMusicPlaylist()
    }

    /// 从云端恢复下载记录（仅元数据）：补进旧「下载」歌单存档，并刷新合并后的「本地音乐」
    func restoreDownloadPlaylistSongs(_ cloudSongs: [Song]) {
        // 本地明确删除过的条目不再从云端并回（删除墓碑权威）
        let cloudSongs = cloudSongs.filter { !DownloadTombstoneStore.shared.isTombstoned(songId: $0.id) }

        let target: LocalPlaylist
        if let existing = downloadPlaylist {
            target = existing
        } else if !cloudSongs.isEmpty {
            // 新设备恢复旧账号：重建存档歌单（不在列表中展示，仅存历史记录）
            let archive = LocalPlaylist(id: LocalPlaylist.downloadId, name: String(localized: "下载"), isSystem: true)
            store.insert(archive)
            target = archive
        } else {
            syncLocalMusicPlaylist()
            return
        }

        let existingIds = songIds(for: target)
        let newSongs = cloudSongs.filter { !existingIds.contains($0.id) }
        if !newSongs.isEmpty {
            var current = songs(for: target)
            current.append(contentsOf: newSongs)
            target.songs = current
            store.save()
        }

        syncLocalMusicPlaylist()
    }

    var syncablePlaylists: [LocalPlaylist] {
        playlists.filter { Self.isCloudSyncablePlaylist($0) }
    }

    var hasSyncableContent: Bool {
        let hasPlaylistContent = syncablePlaylists.contains { playlist in
            if playlist.isFavorite {
                return !songs(for: playlist).isEmpty
            }
            return true
        }
        let hasDownloads = !DownloadManager.shared.fetchCloudSyncedDownloads().isEmpty
        let hasPodcasts = !SubscriptionManager.shared.localSubscribedRadios.isEmpty
        return hasPlaylistContent || hasDownloads || hasPodcasts
    }

    func currentSyncDigest() -> String {
        let playlistPayload = syncablePlaylists.map { playlist in
            LocalPlaylistCloudPlaylist(
                id: playlist.id,
                name: playlist.name,
                desc: playlist.desc,
                coverUrl: playlist.coverUrl,
                createdAt: playlist.createdAt,
                updatedAt: playlist.updatedAt,
                isSystem: playlist.isSystem,
                songs: songs(for: playlist)
            )
        }
        let downloads = DownloadManager.shared.fetchCloudSyncedDownloads().map { CloudDownloadRecord(from: $0) }
        let podcasts = SubscriptionManager.shared.localSubscribedRadios

        struct DigestPayload: Encodable {
            let playlists: [LocalPlaylistCloudPlaylist]
            let downloads: [CloudDownloadRecord]
            let podcasts: [RadioStation]
        }
        let digest = DigestPayload(playlists: playlistPayload, downloads: downloads, podcasts: podcasts)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(digest) else { return "" }
        return data.base64EncodedString()
    }

    func makeCloudSnapshot(deviceId: String, deviceName: String) -> LocalPlaylistCloudSnapshot {
        let cloudPlaylists = syncablePlaylists.map { playlist in
            LocalPlaylistCloudPlaylist(
                id: playlist.id,
                name: playlist.name,
                desc: playlist.desc,
                coverUrl: playlist.coverUrl,
                createdAt: playlist.createdAt,
                updatedAt: playlist.updatedAt,
                isSystem: playlist.isSystem,
                songs: songs(for: playlist)
            )
        }

        let downloads = DownloadManager.shared.fetchCloudSyncedDownloads().map { CloudDownloadRecord(from: $0) }
        let podcasts = SubscriptionManager.shared.localSubscribedRadios

        return LocalPlaylistCloudSnapshot(
            updatedAt: Date(),
            deviceId: deviceId,
            deviceName: deviceName,
            playlists: cloudPlaylists,
            downloads: downloads.isEmpty ? nil : downloads,
            localRadioSubscriptions: podcasts.isEmpty ? nil : podcasts
        )
    }

    @discardableResult
    func replaceSyncablePlaylists(with remotePlaylists: [LocalPlaylistCloudPlaylist]) -> Int {
        ensureSystemPlaylists()
        let remotePlaylists = remotePlaylists.filter { Self.isCloudSyncablePlaylistId($0.id) }

        let favoriteId = LocalPlaylist.favoriteId
        let favorite = store.first(LocalPlaylist.self, where: { $0.id == favoriteId })
        let remoteFavorite = remotePlaylists.first { $0.id == favoriteId }

        if let favorite, let remoteFavorite {
            apply(remoteFavorite, to: favorite)
        } else if let favorite {
            favorite.name = String(localized: "我喜欢")
            favorite.desc = nil
            favorite.coverUrl = nil
            favorite.songs = []
        }

        let locals = store.fetchAll(LocalPlaylist.self)
        locals
            .filter { !$0.isSystem }
            .forEach { store.delete($0) }

        remotePlaylists
            .filter { !$0.isSystem }
            .forEach { remote in
                let playlist = LocalPlaylist(
                    id: remote.id,
                    name: remote.name,
                    desc: remote.desc,
                    isSystem: false
                )
                playlist.coverUrl = remote.coverUrl
                playlist.createdAt = remote.createdAt
                playlist.songs = remote.songs
                playlist.updatedAt = remote.updatedAt
                store.insert(playlist)
            }

        store.save()
        reload()
        return remotePlaylists.count
    }

    @discardableResult
    func mergeSyncablePlaylists(
        with remotePlaylists: [LocalPlaylistCloudPlaylist],
        preservingLocalChangesSince baseline: Date?
    ) -> Int {
        ensureSystemPlaylists()
        let remotePlaylists = remotePlaylists.filter { Self.isCloudSyncablePlaylistId($0.id) }

        let localPlaylists = store.fetchAll(LocalPlaylist.self)
        var remoteByID = Dictionary(uniqueKeysWithValues: remotePlaylists.map { ($0.id, $0) })

        for playlist in localPlaylists {
            if playlist.isLocalMusic { continue }

            let shouldPreserveLocal = shouldPreserveLocalChanges(for: playlist, since: baseline)

            if let remote = remoteByID.removeValue(forKey: playlist.id) {
                if shouldPreserveLocal {
                    continue
                }

                apply(remote, to: playlist)
                continue
            }

            // 旧「下载」歌单是老用户的历史下载存档：远端没有也绝不删除
            if playlist.isDownload { continue }

            if playlist.isFavorite {
                if shouldPreserveLocal {
                    continue
                }

                playlist.name = String(localized: "我喜欢")
                playlist.desc = nil
                playlist.coverUrl = nil
                playlist.songs = []
                playlist.updatedAt = Date()
                continue
            }

            if shouldPreserveLocal {
                continue
            }

            store.delete(playlist)
        }

        for remote in remoteByID.values where !remote.isSystem {
            let playlist = LocalPlaylist(
                id: remote.id,
                name: remote.name,
                desc: remote.desc,
                isSystem: false
            )
            playlist.coverUrl = remote.coverUrl
            playlist.createdAt = remote.createdAt
            playlist.songs = remote.songs
            playlist.updatedAt = remote.updatedAt
            store.insert(playlist)
        }

        store.save()
        reload()
        return playlists.filter { Self.isCloudSyncablePlaylist($0) }.count
    }

    @discardableResult
    func clearSyncablePlaylistsLocally() -> Int {
        replaceSyncablePlaylists(with: [])
    }
    
    // MARK: - CRUD
    
    @discardableResult
    func createPlaylist(name: String, desc: String? = nil) -> LocalPlaylist {
        let playlist = LocalPlaylist(name: name, desc: desc)
        store.insert(playlist)
        store.save()
        reload()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
        return playlist
    }
    
    func renamePlaylist(_ playlist: LocalPlaylist, name: String) {
        guard !playlist.isSystem else { return }
        playlist.name = name
        playlist.updatedAt = Date()
        store.save()
        reload()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
    }
    
    func deletePlaylist(_ playlist: LocalPlaylist) {
        guard !playlist.isSystem else { return }
        store.delete(playlist)
        store.save()
        reload()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
    }
    
    // MARK: - 歌曲操作
    
    func addSong(_ song: Song, to playlist: LocalPlaylist) {
        _ = addSongs([song], to: playlist)
    }

    @discardableResult
    func addSongs(_ songs: [Song], to playlist: LocalPlaylist) -> Int {
        guard !songs.isEmpty else { return 0 }

        let targetId = playlist.id
        guard let target = store.first(LocalPlaylist.self, where: { $0.id == targetId }) else {
            AppLogger.error("添加歌曲失败: 找不到歌单 \(playlist.name)")
            return 0
        }

        var current = self.songs(for: target)
        var existingIds = Set(current.map(\.id))
        var songsToInsert: [Song] = []

        for song in songs where !existingIds.contains(song.id) {
            var normalizedSong = song
            if normalizedSong.source == nil {
                normalizedSong.source = normalizedSong.musicSource
            }
            songsToInsert.append(normalizedSong)
            existingIds.insert(normalizedSong.id)
        }

        guard !songsToInsert.isEmpty else { return 0 }

        current.insert(contentsOf: songsToInsert, at: 0)
        target.songs = current
        store.save()
        reload()
        if Self.isCloudSyncablePlaylist(target) {
            LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
        }
        return songsToInsert.count
    }
    
    func removeSong(id: Int, from playlist: LocalPlaylist) {
        removeSongs(ids: [id], from: playlist)
    }

    func removeSongs(ids: Set<Int>, from playlist: LocalPlaylist) {
        guard !ids.isEmpty else { return }

        let targetId = playlist.id
        guard let target = store.first(LocalPlaylist.self, where: { $0.id == targetId }) else { return }

        var current = songs(for: target)
        let originalCount = current.count
        current.removeAll { ids.contains($0.id) }
        guard current.count != originalCount else { return }
        target.songs = current
        store.save()
        reload()
        if Self.isCloudSyncablePlaylist(target) {
            LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
        }
    }
    
    /// 添加已下载歌曲到"下载"歌单（自动创建）
    func addDownloadedSong(_ song: Song) {
        guard let dl = downloadPlaylist else { return }
        addSong(song, to: dl)
    }
    
    // MARK: - 导入

    func exportPlaylist(_ playlist: LocalPlaylist) throws -> LocalPlaylistExportPayload {
        let songs = songs(for: playlist)
        let exportSongs: [[String: Any]] = songs.map { song in
            var dict: [String: Any] = [
                "id": song.id,
                "name": song.name,
                "artist": song.artistName,
                "source": song.musicSource.rawValue
            ]

            if let albumName = song.album?.name, !albumName.isEmpty {
                dict["album"] = albumName
            }
            if let coverURL = song.coverUrl?.absoluteString, !coverURL.isEmpty {
                dict["cover"] = coverURL
            }
            if let duration = song.dt {
                dict["duration"] = duration
            }
            if let localRelativePath = song.localRelativePath, !localRelativePath.isEmpty {
                dict["localRelativePath"] = localRelativePath
            }
            if let qqMid = song.qqMid, !qqMid.isEmpty {
                dict["qqMid"] = qqMid
            }

            return dict
        }

        let export: [String: Any] = [
            "id": playlist.id,
            "name": playlist.name,
            "description": playlist.desc ?? "",
            "isSystem": playlist.isSystem,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "trackCount": songs.count,
            "songIds": songs.map(\.id),
            "songs": exportSongs
        ]

        let jsonData = try JSONSerialization.data(
            withJSONObject: export,
            options: [.prettyPrinted, .sortedKeys]
        )
        let sanitizedName = Self.sanitizedExportFileName(for: playlist.name)
        return LocalPlaylistExportPayload(
            data: jsonData,
            suggestedFileName: sanitizedName
        )
    }

    private static func sanitizedExportFileName(for name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:\n\r\t")
        let cleaned = name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "playlist" : cleaned
    }

    static func parseExportFile(url: URL) throws -> (name: String, songIds: [Int]) {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "LocalPlaylist", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "无效的歌单文件")])
        }
        let name = json["name"] as? String ?? String(localized: "导入歌单")
        if let ids = json["songIds"] as? [Int], !ids.isEmpty {
            return (name, ids)
        }
        guard let songs = json["songs"] as? [[String: Any]] else {
            throw NSError(domain: "LocalPlaylist", code: -2, userInfo: [NSLocalizedDescriptionKey: String(localized: "歌单中没有歌曲")])
        }
        let ids = songs.compactMap { $0["id"] as? Int }
        return (name, ids)
    }
    
    @discardableResult
    func importPlaylist(name: String, songs: [Song]) -> LocalPlaylist {
        let playlist = LocalPlaylist(name: name)
        playlist.songs = songs
        store.insert(playlist)
        store.save()
        reload()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
        return playlist
    }

    private func apply(_ remote: LocalPlaylistCloudPlaylist, to playlist: LocalPlaylist) {
        playlist.name = remote.name
        playlist.desc = remote.desc
        playlist.coverUrl = remote.coverUrl
        playlist.createdAt = remote.createdAt
        playlist.songs = remote.songs
        playlist.updatedAt = remote.updatedAt
    }

    private func shouldPreserveLocalChanges(for playlist: LocalPlaylist, since baseline: Date?) -> Bool {
        guard Self.isCloudSyncablePlaylist(playlist) else { return false }
        if playlist.isDownload { return false }
        guard let baseline else {
            return playlist.isFavorite ? !songs(for: playlist).isEmpty : true
        }
        return playlist.updatedAt > baseline
    }

    private static func isCloudSyncablePlaylist(_ playlist: LocalPlaylist) -> Bool {
        isCloudSyncablePlaylistId(playlist.id)
    }

    private static func isCloudSyncablePlaylistId(_ id: String) -> Bool {
        id != LocalPlaylist.localMusicId
    }

    private func trimCaches(validIds: Set<String>) {
        summaryCache = summaryCache.filter { validIds.contains($0.key) }
        songCache = songCache.filter { validIds.contains($0.key) }
    }
}
