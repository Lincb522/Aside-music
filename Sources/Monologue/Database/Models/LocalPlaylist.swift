import Foundation
import SwiftData

/// 本地歌单数据模型
@Model
final class LocalPlaylist {
    @Attribute(.unique) var id: String
    var name: String
    var desc: String?
    var coverUrl: String?
    var createdAt: Date
    var updatedAt: Date
    /// 歌曲数据（JSON 编码的 [Song]）
    var songsData: Data?
    /// 系统预置歌单不可删除/重命名
    var isSystem: Bool = false
    
    // MARK: - 预置歌单 ID
    static let favoriteId = "__system_favorite__"
    static let localMusicId = "__system_local_music__"
    static let downloadId = "__system_download__"
    
    var isFavorite: Bool { id == Self.favoriteId }
    var isLocalMusic: Bool { id == Self.localMusicId }
    var isDownload: Bool { id == Self.downloadId }
    
    /// 歌曲列表（计算属性）
    var songs: [Song] {
        get {
            guard let data = songsData else { return [] }
            return (try? JSONDecoder().decode([Song].self, from: data)) ?? []
        }
        set {
            // 在保存/同步前，确保显式补全 source 字段，防止传到云端后丢失平台信息
            let cleanedSongs = newValue.map { song -> Song in
                var s = song
                if s.source == nil {
                    s.source = s.musicSource
                }
                return s
            }
            songsData = try? JSONEncoder().encode(cleanedSongs)
            updatedAt = Date()
        }
    }
    
    var trackCount: Int { songs.count }
    
    /// 封面：优先自定义封面，否则取第一首歌的封面
    var displayCoverUrl: URL? {
        if let url = coverUrl, !url.isEmpty { return URL(string: url) }
        return songs.first?.coverUrl
    }
    
    init(id: String = UUID().uuidString, name: String, desc: String? = nil, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.desc = desc
        self.coverUrl = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.songsData = nil
        self.isSystem = isSystem
    }
    
    /// 添加歌曲（去重）
    func addSong(_ song: Song) {
        var current = songs
        guard !current.contains(where: { $0.id == song.id }) else { return }
        current.insert(song, at: 0)
        songs = current
    }
    
    /// 移除歌曲
    func removeSong(id: Int) {
        var current = songs
        current.removeAll { $0.id == id }
        songs = current
    }
    
    /// 是否包含某首歌
    func containsSong(id: Int) -> Bool {
        songs.contains { $0.id == id }
    }
}
