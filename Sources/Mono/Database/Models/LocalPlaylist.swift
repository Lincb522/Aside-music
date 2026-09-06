import Foundation

/// 本地歌单数据模型
final class LocalPlaylist {
    var id: String
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
        guard !current.contains(song) else { return }
        current.insert(song, at: 0)
        songs = current
    }
    
    /// 移除歌曲
    func removeSong(_ song: Song) {
        var current = songs
        current.removeAll { $0 == song }
        songs = current
    }
    
    /// 是否包含某首歌
    func containsSong(_ song: Song) -> Bool {
        songs.contains(song)
    }
}

// MARK: - MonoEntity

extension LocalPlaylist: MonoEntity {
    static let monoEntityName = "LocalPlaylist"
    static let monoAttributes: [MonoAttribute] = [
        .init("id", .string), .init("name", .string), .init("desc", .string),
        .init("coverUrl", .string), .init("createdAt", .date), .init("updatedAt", .date),
        .init("songsData", .data), .init("isSystem", .bool)
    ]

    var monoUniqueKey: String { id }

    func monoSnapshot() -> [String: Any?] {
        [
            "id": id, "name": name, "desc": desc, "coverUrl": coverUrl,
            "createdAt": createdAt, "updatedAt": updatedAt,
            "songsData": songsData, "isSystem": isSystem
        ]
    }

    static func monoMake(from s: [String: Any?]) -> Self {
        let obj = LocalPlaylist(
            id: MonoSnapshotValue.string(s, "id"),
            name: MonoSnapshotValue.string(s, "name"),
            desc: MonoSnapshotValue.stringOpt(s, "desc"),
            isSystem: MonoSnapshotValue.bool(s, "isSystem")
        )
        obj.coverUrl = MonoSnapshotValue.stringOpt(s, "coverUrl")
        obj.createdAt = MonoSnapshotValue.date(s, "createdAt")
        obj.songsData = MonoSnapshotValue.dataOpt(s, "songsData")
        // updatedAt 最后设置（songsData 直接赋值不会触发 didSet，但保险起见仍放最后）
        obj.updatedAt = MonoSnapshotValue.date(s, "updatedAt")
        return unsafeDowncast(obj, to: Self.self)
    }
}
