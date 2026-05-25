import Foundation
import SwiftData
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
    
    private let context: ModelContext
    private var downloadSyncCancellable: AnyCancellable?
    private var summaryCache: [String: (signature: LocalPlaylistCacheSignature, summary: LocalPlaylistSummary)] = [:]
    private var songCache: [String: (signature: LocalPlaylistCacheSignature, songs: [Song], ids: Set<Int>)] = [:]
    
    private init() {
        self.context = DatabaseManager.shared.context
        ensureSystemPlaylists()
        reload()
        observeDownloads()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.syncDownloadPlaylist()
        }
    }
    
    // MARK: - 系统预置歌单
    
    /// 确保「我喜欢」「本地音乐」和「下载」歌单存在
    private func ensureSystemPlaylists() {
        let favId = LocalPlaylist.favoriteId
        let localMusicId = LocalPlaylist.localMusicId
        let dlId = LocalPlaylist.downloadId
        
        let favDesc = FetchDescriptor<LocalPlaylist>(predicate: #Predicate { $0.id == favId })
        if (try? context.fetch(favDesc))?.first == nil {
            let fav = LocalPlaylist(id: favId, name: String(localized: "我喜欢"), isSystem: true)
            context.insert(fav)
        }

        let localMusicDesc = FetchDescriptor<LocalPlaylist>(predicate: #Predicate { $0.id == localMusicId })
        if (try? context.fetch(localMusicDesc))?.first == nil {
            let localMusic = LocalPlaylist(id: localMusicId, name: String(localized: "本地音乐"), isSystem: true)
            context.insert(localMusic)
        }
        
        let dlDesc = FetchDescriptor<LocalPlaylist>(predicate: #Predicate { $0.id == dlId })
        if (try? context.fetch(dlDesc))?.first == nil {
            let dl = LocalPlaylist(id: dlId, name: String(localized: "下载"), isSystem: true)
            context.insert(dl)
        }
        
        try? context.save()
    }
    
    // MARK: - 刷新
    
    func reload() {
        let descriptor = FetchDescriptor<LocalPlaylist>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        var all = (try? context.fetch(descriptor)) ?? []
        
        // 系统歌单置顶：我喜欢 > 本地音乐 > 下载 > 其他按 updatedAt 排序
        let favorite = all.first { $0.isFavorite }
        let localMusic = all.first { $0.isLocalMusic }
        let download = all.first { $0.isDownload }
        all.removeAll { $0.isSystem }
        
        var sorted: [LocalPlaylist] = []
        if let f = favorite { sorted.append(f) }
        if let l = localMusic { sorted.append(l) }
        if let d = download { sorted.append(d) }
        sorted.append(contentsOf: all)
        
        trimCaches(validIds: Set(sorted.map(\.id)))
        revision += 1
        playlists = sorted
    }
    
    // MARK: - 预置歌单快捷访问
    
    var favoritePlaylist: LocalPlaylist? {
        playlists.first { $0.isFavorite }
    }
    
    var downloadPlaylist: LocalPlaylist? {
        playlists.first { $0.isDownload }
    }

    var localMusicPlaylist: LocalPlaylist? {
        playlists.first { $0.isLocalMusic }
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
    
    // MARK: - 下载歌单自动同步
    
    private func observeDownloads() {
        downloadSyncCancellable = DownloadManager.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncDownloadPlaylist()
            }
    }
    
    func syncDownloadPlaylist() {
        guard let dl = downloadPlaylist else { return }
        let songs = DownloadManager.shared.fetchDownloadPlaylistSongs()
        
        let dlId = dl.id
        let descriptor = FetchDescriptor<LocalPlaylist>(predicate: #Predicate { $0.id == dlId })
        guard let target = (try? context.fetch(descriptor))?.first else { return }
        target.songs = songs
        try? context.save()
        reload()
    }

    func syncLocalMusicPlaylist(with songs: [Song]) {
        guard let localMusic = localMusicPlaylist else { return }
        let playlistId = localMusic.id
        let descriptor = FetchDescriptor<LocalPlaylist>(predicate: #Predicate { $0.id == playlistId })
        guard let target = (try? context.fetch(descriptor))?.first else { return }

        target.songs = songs
        try? context.save()
        reload()
    }

    /// 从云端恢复下载记录到下载歌单（仅补充元数据，不重复已存在的）
    func restoreDownloadPlaylistSongs(_ cloudSongs: [Song]) {
        guard let dl = downloadPlaylist else { return }
        let dlId = dl.id
        let descriptor = FetchDescriptor<LocalPlaylist>(predicate: #Predicate { $0.id == dlId })
        guard let target = (try? context.fetch(descriptor))?.first else { return }

        let existingIds = songIds(for: target)
        let newSongs = cloudSongs.filter { !existingIds.contains($0.id) }
        guard !newSongs.isEmpty else { return }

        var current = songs(for: target)
        current.append(contentsOf: newSongs)
        target.songs = current
        try? context.save()
        reload()
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
        let favoriteDescriptor = FetchDescriptor<LocalPlaylist>(
            predicate: #Predicate { $0.id == favoriteId }
        )
        let favorite = (try? context.fetch(favoriteDescriptor))?.first
        let remoteFavorite = remotePlaylists.first { $0.id == favoriteId }

        if let favorite, let remoteFavorite {
            apply(remoteFavorite, to: favorite)
        } else if let favorite {
            favorite.name = String(localized: "我喜欢")
            favorite.desc = nil
            favorite.coverUrl = nil
            favorite.songs = []
        }

        let descriptor = FetchDescriptor<LocalPlaylist>()
        let locals = (try? context.fetch(descriptor)) ?? []
        locals
            .filter { !$0.isSystem }
            .forEach(context.delete)

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
                context.insert(playlist)
            }

        try? context.save()
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

        let descriptor = FetchDescriptor<LocalPlaylist>()
        let localPlaylists = (try? context.fetch(descriptor)) ?? []
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

            context.delete(playlist)
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
            context.insert(playlist)
        }

        try? context.save()
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
        context.insert(playlist)
        try? context.save()
        reload()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
        return playlist
    }
    
    func renamePlaylist(_ playlist: LocalPlaylist, name: String) {
        guard !playlist.isSystem else { return }
        playlist.name = name
        playlist.updatedAt = Date()
        try? context.save()
        reload()
        LocalPlaylistCloudSyncManager.shared.scheduleSyncForLocalMutation()
    }
    
    func deletePlaylist(_ playlist: LocalPlaylist) {
        guard !playlist.isSystem else { return }
        context.delete(playlist)
        try? context.save()
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
        let descriptor = FetchDescriptor<LocalPlaylist>(
            predicate: #Predicate { $0.id == targetId }
        )
        guard let target = (try? context.fetch(descriptor))?.first else {
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
        try? context.save()
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
        let descriptor = FetchDescriptor<LocalPlaylist>(
            predicate: #Predicate { $0.id == targetId }
        )
        guard let target = (try? context.fetch(descriptor))?.first else { return }

        var current = songs(for: target)
        let originalCount = current.count
        current.removeAll { ids.contains($0.id) }
        guard current.count != originalCount else { return }
        target.songs = current
        try? context.save()
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
        context.insert(playlist)
        try? context.save()
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
