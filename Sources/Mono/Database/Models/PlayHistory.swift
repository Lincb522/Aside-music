import Foundation

/// 播放历史记录
final class PlayHistory {
    var id: UUID
    var songId: Int
    var songName: String
    var artistName: String
    var coverUrl: String?
    var playedAt: Date
    var playDuration: Int // 播放时长（秒）
    var completed: Bool // 是否播放完成
    var trackDuration: Int
    var effectivePlay: Bool
    var qualificationVersion: Int
    
    // 协议 v2 起同步音乐来源。
    var sourceRaw: String? // MusicSource.rawValue
    var qqMid: String?
    var qqAlbumMid: String?
    var qishuiTrackId: Int?
    var appleMusicID: String?
    var appleMusicISRC: String?
    
    init(
        songId: Int,
        songName: String,
        artistName: String,
        coverUrl: String? = nil,
        playDuration: Int = 0,
        completed: Bool = false,
        trackDuration: Int = 0,
        effectivePlay: Bool = false,
        qualificationVersion: Int = 0,
        sourceRaw: String? = nil,
        qqMid: String? = nil,
        qqAlbumMid: String? = nil,
        qishuiTrackId: Int? = nil,
        appleMusicID: String? = nil,
        appleMusicISRC: String? = nil
    ) {
        self.id = UUID()
        self.songId = songId
        self.songName = songName
        self.artistName = artistName
        self.coverUrl = coverUrl
        self.playedAt = Date()
        self.playDuration = playDuration
        self.completed = completed
        self.trackDuration = trackDuration
        self.effectivePlay = effectivePlay
        self.qualificationVersion = qualificationVersion
        self.sourceRaw = sourceRaw
        self.qqMid = qqMid
        self.qqAlbumMid = qqAlbumMid
        self.qishuiTrackId = qishuiTrackId
        self.appleMusicID = appleMusicID
        self.appleMusicISRC = appleMusicISRC
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
            trackDuration: max(0, (song.dt ?? 0) / 1_000),
            sourceRaw: song.source?.rawValue,
            qqMid: song.qqMid,
            qqAlbumMid: song.qqAlbumMid,
            qishuiTrackId: song.qishuiTrackId,
            appleMusicID: song.appleMusicID,
            appleMusicISRC: song.appleMusicISRC
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
            dt: trackDuration > 0 ? trackDuration * 1_000 : nil,
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
        song.qishuiTrackId = qishuiTrackId
        song.appleMusicID = appleMusicID
        song.appleMusicISRC = appleMusicISRC
        return song
    }
}

/// 搜索历史记录
final class SearchHistory {
    var id: UUID
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

// MARK: - MonoEntity (PlayHistory / SearchHistory / CachedLyrics)

extension PlayHistory: MonoEntity {
    static let monoEntityName = "PlayHistory"
    static let monoAttributes: [MonoAttribute] = [
        .init("id", .uuid), .init("songId", .int), .init("songName", .string),
        .init("artistName", .string), .init("coverUrl", .string), .init("playedAt", .date),
        .init("playDuration", .int), .init("completed", .bool),
        .init("trackDuration", .int), .init("effectivePlay", .bool),
        .init("qualificationVersion", .int), .init("sourceRaw", .string),
        .init("qqMid", .string), .init("qqAlbumMid", .string), .init("qishuiTrackId", .int),
        .init("appleMusicID", .string), .init("appleMusicISRC", .string)
    ]

    var monoUniqueKey: String { id.uuidString }

    func monoSnapshot() -> [String: Any?] {
        [
            "id": id, "songId": songId, "songName": songName, "artistName": artistName,
            "coverUrl": coverUrl, "playedAt": playedAt, "playDuration": playDuration,
            "completed": completed, "trackDuration": trackDuration,
            "effectivePlay": effectivePlay, "qualificationVersion": qualificationVersion,
            "sourceRaw": sourceRaw, "qqMid": qqMid,
            "qqAlbumMid": qqAlbumMid, "qishuiTrackId": qishuiTrackId,
            "appleMusicID": appleMusicID, "appleMusicISRC": appleMusicISRC
        ]
    }

    static func monoMake(from s: [String: Any?]) -> Self {
        let obj = PlayHistory(
            songId: MonoSnapshotValue.int(s, "songId"),
            songName: MonoSnapshotValue.string(s, "songName"),
            artistName: MonoSnapshotValue.string(s, "artistName"),
            coverUrl: MonoSnapshotValue.stringOpt(s, "coverUrl"),
            playDuration: MonoSnapshotValue.int(s, "playDuration"),
            completed: MonoSnapshotValue.bool(s, "completed"),
            trackDuration: MonoSnapshotValue.int(s, "trackDuration"),
            effectivePlay: MonoSnapshotValue.bool(s, "effectivePlay"),
            qualificationVersion: MonoSnapshotValue.int(s, "qualificationVersion"),
            sourceRaw: MonoSnapshotValue.stringOpt(s, "sourceRaw"),
            qqMid: MonoSnapshotValue.stringOpt(s, "qqMid"),
            qqAlbumMid: MonoSnapshotValue.stringOpt(s, "qqAlbumMid"),
            qishuiTrackId: MonoSnapshotValue.intOpt(s, "qishuiTrackId"),
            appleMusicID: MonoSnapshotValue.stringOpt(s, "appleMusicID"),
            appleMusicISRC: MonoSnapshotValue.stringOpt(s, "appleMusicISRC")
        )
        obj.id = MonoSnapshotValue.uuid(s, "id")
        obj.playedAt = MonoSnapshotValue.date(s, "playedAt")
        return unsafeDowncast(obj, to: Self.self)
    }
}

extension SearchHistory: MonoEntity {
    static let monoEntityName = "SearchHistory"
    static let monoAttributes: [MonoAttribute] = [
        .init("id", .uuid), .init("keyword", .string),
        .init("searchedAt", .date), .init("resultCount", .int)
    ]

    var monoUniqueKey: String { id.uuidString }

    func monoSnapshot() -> [String: Any?] {
        ["id": id, "keyword": keyword, "searchedAt": searchedAt, "resultCount": resultCount]
    }

    static func monoMake(from s: [String: Any?]) -> Self {
        let obj = SearchHistory(
            keyword: MonoSnapshotValue.string(s, "keyword"),
            resultCount: MonoSnapshotValue.int(s, "resultCount")
        )
        obj.id = MonoSnapshotValue.uuid(s, "id")
        obj.searchedAt = MonoSnapshotValue.date(s, "searchedAt")
        return unsafeDowncast(obj, to: Self.self)
    }
}

extension CachedLyrics: MonoEntity {
    static let monoEntityName = "CachedLyrics"
    static let monoAttributes: [MonoAttribute] = [
        .init("songId", .int), .init("lyrics", .string),
        .init("translatedLyrics", .string), .init("cachedAt", .date)
    ]

    var monoUniqueKey: String { String(songId) }

    func monoSnapshot() -> [String: Any?] {
        ["songId": songId, "lyrics": lyrics, "translatedLyrics": translatedLyrics, "cachedAt": cachedAt]
    }

    static func monoMake(from s: [String: Any?]) -> Self {
        let obj = CachedLyrics(
            songId: MonoSnapshotValue.int(s, "songId"),
            lyrics: MonoSnapshotValue.string(s, "lyrics"),
            translatedLyrics: MonoSnapshotValue.stringOpt(s, "translatedLyrics")
        )
        obj.cachedAt = MonoSnapshotValue.date(s, "cachedAt")
        return unsafeDowncast(obj, to: Self.self)
    }
}

/// 缓存的歌词
final class CachedLyrics {
    var songId: Int
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
