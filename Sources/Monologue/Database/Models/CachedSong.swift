import Foundation
import SwiftData

/// 缓存的歌曲数据模型
@Model
final class CachedSong {
    @Attribute(.unique) var id: Int
    var name: String
    var artistName: String
    var albumName: String?
    var coverUrl: String?
    var duration: Int?
    var cachedAt: Date
    var lastPlayedAt: Date?
    var playCount: Int
    
    // 权限信息
    var maxBitrate: Int?
    var fee: Int?
    var canPlay: Bool
    
    init(
        id: Int,
        name: String,
        artistName: String,
        albumName: String? = nil,
        coverUrl: String? = nil,
        duration: Int? = nil,
        maxBitrate: Int? = nil,
        fee: Int? = nil,
        canPlay: Bool = true
    ) {
        self.id = id
        self.name = name
        self.artistName = artistName
        self.albumName = albumName
        self.coverUrl = coverUrl
        self.duration = duration
        self.cachedAt = Date()
        self.lastPlayedAt = nil
        self.playCount = 0
        self.maxBitrate = maxBitrate
        self.fee = fee
        self.canPlay = canPlay
    }
    
    /// 从 Song 模型创建
    convenience init(from song: Song) {
        self.init(
            id: song.id,
            name: song.name,
            artistName: song.artistName,
            albumName: song.al?.name,
            coverUrl: song.coverUrl?.absoluteString,
            duration: song.dt,
            maxBitrate: nil,
            fee: song.fee,
            canPlay: true
        )
    }
    
    /// 转换为 Song 模型
    func toSong() -> Song {
        return Song(
            id: id,
            name: name,
            ar: [Artist(id: 0, name: artistName)],
            al: Album(id: 0, name: albumName ?? "", picUrl: coverUrl),
            dt: duration,
            fee: fee,
            mv: nil,
            h: nil,
            m: nil,
            l: nil,
            sq: nil,
            hr: nil,
            alia: nil,
            privilege: nil
        )
    }
    
    /// 更新播放记录
    func recordPlay() {
        lastPlayedAt = Date()
        playCount += 1
    }
}
