import Foundation
import SwiftData
import Combine

/// 本地歌单管理器
@MainActor
class LocalPlaylistManager: ObservableObject {
    static let shared = LocalPlaylistManager()
    
    @Published var playlists: [LocalPlaylist] = []
    
    private let context: ModelContext
    
    private init() {
        self.context = DatabaseManager.shared.context
        reload()
    }
    
    // MARK: - 刷新
    
    func reload() {
        let descriptor = FetchDescriptor<LocalPlaylist>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        playlists = (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - CRUD
    
    @discardableResult
    func createPlaylist(name: String, desc: String? = nil) -> LocalPlaylist {
        let playlist = LocalPlaylist(name: name, desc: desc)
        context.insert(playlist)
        try? context.save()
        reload()
        return playlist
    }
    
    func renamePlaylist(_ playlist: LocalPlaylist, name: String) {
        playlist.name = name
        playlist.updatedAt = Date()
        try? context.save()
        reload()
    }
    
    func deletePlaylist(_ playlist: LocalPlaylist) {
        context.delete(playlist)
        try? context.save()
        reload()
    }
    
    // MARK: - 歌曲操作
    
    func addSong(_ song: Song, to playlist: LocalPlaylist) {
        playlist.addSong(song)
        try? context.save()
        reload()
    }
    
    func removeSong(id: Int, from playlist: LocalPlaylist) {
        playlist.removeSong(id: id)
        try? context.save()
        reload()
    }
    
    /// 添加已下载歌曲到"下载"歌单（自动创建）
    func addDownloadedSong(_ song: Song) {
        let downloaded = playlists.first { $0.name == "下载" }
            ?? createPlaylist(name: "下载")
        addSong(song, to: downloaded)
    }
    
    // MARK: - 导入
    
    /// 从导出的 JSON 文件导入歌单
    /// - Returns: (歌单名, 需要获取详情的歌曲ID列表)
    static func parseExportFile(url: URL) throws -> (name: String, songIds: [Int]) {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "LocalPlaylist", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的歌单文件"])
        }
        let name = json["name"] as? String ?? "导入歌单"
        guard let songs = json["songs"] as? [[String: Any]] else {
            throw NSError(domain: "LocalPlaylist", code: -2, userInfo: [NSLocalizedDescriptionKey: "歌单中没有歌曲"])
        }
        let ids = songs.compactMap { $0["id"] as? Int }
        return (name, ids)
    }
    
    /// 创建歌单并填入歌曲
    @discardableResult
    func importPlaylist(name: String, songs: [Song]) -> LocalPlaylist {
        let playlist = createPlaylist(name: name)
        var current = playlist.songs
        for song in songs where !current.contains(where: { $0.id == song.id }) {
            current.append(song)
        }
        playlist.songs = current
        try? context.save()
        reload()
        return playlist
    }
}
