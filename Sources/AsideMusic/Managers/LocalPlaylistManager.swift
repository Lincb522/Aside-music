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
}
