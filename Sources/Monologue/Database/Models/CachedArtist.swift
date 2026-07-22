import Foundation

/// 缓存的艺术家数据模型
final class CachedArtist {
    var id: Int
    var name: String
    var coverUrl: String?
    var briefDesc: String?
    var albumSize: Int?
    var musicSize: Int?
    var cachedAt: Date
    var lastAccessedAt: Date?
    
    init(
        id: Int,
        name: String,
        coverUrl: String? = nil,
        briefDesc: String? = nil,
        albumSize: Int? = nil,
        musicSize: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.coverUrl = coverUrl
        self.briefDesc = briefDesc
        self.albumSize = albumSize
        self.musicSize = musicSize
        self.cachedAt = Date()
        self.lastAccessedAt = nil
    }
    
    /// 从 ArtistInfo 模型创建
    convenience init(from artist: ArtistInfo) {
        self.init(
            id: artist.id,
            name: artist.name,
            coverUrl: artist.coverUrl?.absoluteString,
            briefDesc: artist.briefDesc,
            albumSize: artist.albumSize,
            musicSize: artist.musicSize
        )
    }
    
    func toArtistInfo() -> ArtistInfo {
        return ArtistInfo(
            id: id,
            name: name,
            picUrl: coverUrl,
            img1v1Url: coverUrl,
            cover: nil,
            avatar: nil,
            musicSize: musicSize,
            albumSize: albumSize,
            mvSize: nil,
            briefDesc: briefDesc,
            alias: nil,
            followed: nil,
            accountId: nil
        )
    }
    
    /// 记录访问
    func recordAccess() {
        lastAccessedAt = Date()
    }
}

// MARK: - MonoEntity

extension CachedArtist: MonoEntity {
    static let monoEntityName = "CachedArtist"
    static let monoAttributes: [MonoAttribute] = [
        .init("id", .int), .init("name", .string), .init("coverUrl", .string),
        .init("briefDesc", .string), .init("albumSize", .int), .init("musicSize", .int),
        .init("cachedAt", .date), .init("lastAccessedAt", .date)
    ]

    var monoUniqueKey: String { String(id) }

    func monoSnapshot() -> [String: Any?] {
        [
            "id": id, "name": name, "coverUrl": coverUrl, "briefDesc": briefDesc,
            "albumSize": albumSize, "musicSize": musicSize, "cachedAt": cachedAt,
            "lastAccessedAt": lastAccessedAt
        ]
    }

    static func monoMake(from s: [String: Any?]) -> Self {
        let obj = CachedArtist(
            id: MonoSnapshotValue.int(s, "id"),
            name: MonoSnapshotValue.string(s, "name"),
            coverUrl: MonoSnapshotValue.stringOpt(s, "coverUrl"),
            briefDesc: MonoSnapshotValue.stringOpt(s, "briefDesc"),
            albumSize: MonoSnapshotValue.intOpt(s, "albumSize"),
            musicSize: MonoSnapshotValue.intOpt(s, "musicSize")
        )
        obj.cachedAt = MonoSnapshotValue.date(s, "cachedAt")
        obj.lastAccessedAt = MonoSnapshotValue.dateOpt(s, "lastAccessedAt")
        return unsafeDowncast(obj, to: Self.self)
    }
}
