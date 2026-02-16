import Foundation
import SwiftData

/// 缓存的艺术家数据模型
@Model
final class CachedArtist {
    @Attribute(.unique) var id: Int
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
