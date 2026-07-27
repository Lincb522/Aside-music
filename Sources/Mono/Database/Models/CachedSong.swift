import Foundation

/// 缓存的歌曲数据模型
/// 持久化：iOS 17+ 走 SwiftData 镜像实体，iOS 16 走 Core Data（见 MonoStoreBackend）
final class CachedSong {
    var id: Int
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
    
    // 音乐来源
    var sourceRaw: String?
    var qqMid: String?
    var qishuiTrackId: Int?
    var appleMusicID: String?
    var appleMusicISRC: String?
    
    init(
        id: Int,
        name: String,
        artistName: String,
        albumName: String? = nil,
        coverUrl: String? = nil,
        duration: Int? = nil,
        maxBitrate: Int? = nil,
        fee: Int? = nil,
        canPlay: Bool = true,
        sourceRaw: String? = nil,
        qqMid: String? = nil,
        qishuiTrackId: Int? = nil,
        appleMusicID: String? = nil,
        appleMusicISRC: String? = nil
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
        self.sourceRaw = sourceRaw
        self.qqMid = qqMid
        self.qishuiTrackId = qishuiTrackId
        self.appleMusicID = appleMusicID
        self.appleMusicISRC = appleMusicISRC
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
            canPlay: true,
            sourceRaw: song.source?.rawValue,
            qqMid: song.qqMid,
            qishuiTrackId: song.qishuiTrackId,
            appleMusicID: song.appleMusicID,
            appleMusicISRC: song.appleMusicISRC
        )
    }
    
    /// 转换为 Song 模型
    func toSong() -> Song {
        var song = Song(
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
        if let raw = sourceRaw {
            song.source = MusicSource(rawValue: raw)
        }
        song.qqMid = qqMid
        song.qishuiTrackId = qishuiTrackId
        song.appleMusicID = appleMusicID
        song.appleMusicISRC = appleMusicISRC
        return song
    }
    
    /// 更新播放记录
    func recordPlay() {
        lastPlayedAt = Date()
        playCount += 1
    }
}

// MARK: - MonoEntity

extension CachedSong: MonoEntity {
    static let monoEntityName = "CachedSong"
    static let monoAttributes: [MonoAttribute] = [
        .init("id", .int), .init("name", .string), .init("artistName", .string),
        .init("albumName", .string), .init("coverUrl", .string), .init("duration", .int),
        .init("cachedAt", .date), .init("lastPlayedAt", .date), .init("playCount", .int),
        .init("maxBitrate", .int), .init("fee", .int), .init("canPlay", .bool),
        .init("sourceRaw", .string), .init("qqMid", .string), .init("qishuiTrackId", .int),
        .init("appleMusicID", .string), .init("appleMusicISRC", .string)
    ]

    var monoUniqueKey: String { String(id) }

    func monoSnapshot() -> [String: Any?] {
        [
            "id": id, "name": name, "artistName": artistName, "albumName": albumName,
            "coverUrl": coverUrl, "duration": duration, "cachedAt": cachedAt,
            "lastPlayedAt": lastPlayedAt, "playCount": playCount, "maxBitrate": maxBitrate,
            "fee": fee, "canPlay": canPlay, "sourceRaw": sourceRaw, "qqMid": qqMid,
            "qishuiTrackId": qishuiTrackId, "appleMusicID": appleMusicID,
            "appleMusicISRC": appleMusicISRC
        ]
    }

    static func monoMake(from s: [String: Any?]) -> Self {
        let obj = CachedSong(
            id: MonoSnapshotValue.int(s, "id"),
            name: MonoSnapshotValue.string(s, "name"),
            artistName: MonoSnapshotValue.string(s, "artistName"),
            albumName: MonoSnapshotValue.stringOpt(s, "albumName"),
            coverUrl: MonoSnapshotValue.stringOpt(s, "coverUrl"),
            duration: MonoSnapshotValue.intOpt(s, "duration"),
            maxBitrate: MonoSnapshotValue.intOpt(s, "maxBitrate"),
            fee: MonoSnapshotValue.intOpt(s, "fee"),
            canPlay: MonoSnapshotValue.bool(s, "canPlay", default: true),
            sourceRaw: MonoSnapshotValue.stringOpt(s, "sourceRaw"),
            qqMid: MonoSnapshotValue.stringOpt(s, "qqMid"),
            qishuiTrackId: MonoSnapshotValue.intOpt(s, "qishuiTrackId"),
            appleMusicID: MonoSnapshotValue.stringOpt(s, "appleMusicID"),
            appleMusicISRC: MonoSnapshotValue.stringOpt(s, "appleMusicISRC")
        )
        obj.cachedAt = MonoSnapshotValue.date(s, "cachedAt")
        obj.lastPlayedAt = MonoSnapshotValue.dateOpt(s, "lastPlayedAt")
        obj.playCount = MonoSnapshotValue.int(s, "playCount")
        return unsafeDowncast(obj, to: Self.self)
    }
}
