import Foundation
import SwiftData

/// 播放历史记录
@Model
final class PlayHistory {
    @Attribute(.unique) var id: UUID
    var songId: Int
    var songName: String
    var artistName: String
    var coverUrl: String?
    var playedAt: Date
    var playDuration: Int // 播放时长（秒）
    var completed: Bool // 是否播放完成
    
    // 音乐来源信息（v2 新增）
    var sourceRaw: String? // MusicSource.rawValue
    var qqMid: String?
    var qqAlbumMid: String?
    
    init(
        songId: Int,
        songName: String,
        artistName: String,
        coverUrl: String? = nil,
        playDuration: Int = 0,
        completed: Bool = false,
        sourceRaw: String? = nil,
        qqMid: String? = nil,
        qqAlbumMid: String? = nil
    ) {
        self.id = UUID()
        self.songId = songId
        self.songName = songName
        self.artistName = artistName
        self.coverUrl = coverUrl
        self.playedAt = Date()
        self.playDuration = playDuration
        self.completed = completed
        self.sourceRaw = sourceRaw
        self.qqMid = qqMid
        self.qqAlbumMid = qqAlbumMid
    }
    
    /// 从 Song 创建
    convenience init(from song: Song, duration: Int = 0, completed: Bool = false) {
        self.init(
            songId: song.id,
            songName: song.name,
            artistName: song.artistName,
            coverUrl: song.coverUrl?.absoluteString,
            playDuration: duration,
            completed: completed,
            sourceRaw: song.source?.rawValue,
            qqMid: song.qqMid,
            qqAlbumMid: song.qqAlbumMid
        )
    }
    
    /// 转换为 Song（用于历史记录恢复）
    func toSong() -> Song {
        let coverAlbum: Album? = if let coverUrl = coverUrl {
            Album(id: 0, name: "", picUrl: coverUrl)
        } else {
            nil
        }
        var song = Song(
            id: songId,
            name: songName,
            ar: [Artist(id: 0, name: artistName)],
            al: coverAlbum,
            dt: nil,
            fee: nil,
            mv: nil,
            h: nil, m: nil, l: nil, sq: nil, hr: nil,
            alia: nil,
            privilege: nil
        )
        // 恢复音乐来源信息
        if let raw = sourceRaw {
            song.source = MusicSource(rawValue: raw)
        }
        song.qqMid = qqMid
        song.qqAlbumMid = qqAlbumMid
        return song
    }
}

/// 搜索历史记录
@Model
final class SearchHistory {
    @Attribute(.unique) var id: UUID
    var keyword: String
    var searchedAt: Date
    var resultCount: Int
    
    init(keyword: String, resultCount: Int = 0) {
        self.id = UUID()
        self.keyword = keyword
        self.searchedAt = Date()
        self.resultCount = resultCount
    }
}

/// 缓存的歌词
@Model
final class CachedLyrics {
    @Attribute(.unique) var songId: Int
    var lyrics: String // 原始歌词
    var translatedLyrics: String? // 翻译歌词
    var cachedAt: Date
    
    init(songId: Int, lyrics: String, translatedLyrics: String? = nil) {
        self.songId = songId
        self.lyrics = lyrics
        self.translatedLyrics = translatedLyrics
        self.cachedAt = Date()
    }
}
