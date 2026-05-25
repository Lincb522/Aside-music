import Foundation

struct LocalPlaylistCloudPlaylist: Codable, Hashable {
    var id: String
    var name: String
    var desc: String?
    var coverUrl: String?
    var createdAt: Date
    var updatedAt: Date
    var isSystem: Bool
    var songs: [Song]
}

// MARK: - 下载记录云端模型（仅元数据，不含音频文件）

struct CloudDownloadRecord: Codable, Hashable {
    var songId: Int
    var name: String
    var artistName: String
    var albumName: String?
    var coverUrl: String?
    var duration: Int?
    var source: String?        // MusicSource.rawValue
    var qqMid: String?
    var qishuiTrackId: Int?
    var qishuiQualityRaw: String?
    var qualityRaw: String?
    var qqQualityRaw: String?
    var downloadedAt: Date?

    /// 从 DownloadedSong 创建（仅保存元数据）
    init(from downloaded: DownloadedSong) {
        self.songId = downloaded.id
        self.name = downloaded.name
        self.artistName = downloaded.artistName
        self.albumName = downloaded.albumName
        self.coverUrl = downloaded.coverUrl
        self.duration = downloaded.duration
        self.qqMid = downloaded.qqMid
        self.qishuiTrackId = downloaded.qishuiTrackId
        self.qishuiQualityRaw = downloaded.qishuiQualityRaw
        self.qualityRaw = downloaded.qualityRaw
        self.qqQualityRaw = downloaded.qqQualityRaw
        self.downloadedAt = downloaded.downloadedAt

        if downloaded.isQishui {
            self.source = MusicSource.qishui.rawValue
        } else if downloaded.isQQMusic {
            self.source = MusicSource.qqmusic.rawValue
        } else {
            self.source = MusicSource.netease.rawValue
        }
    }

    /// 转换为 Song（用于下载歌单恢复显示）
    func toSong() -> Song {
        var song = Song(
            id: songId,
            name: name,
            ar: [Artist(id: 0, name: artistName)],
            al: Album(id: 0, name: albumName ?? "", picUrl: coverUrl),
            dt: duration,
            fee: nil,
            mv: nil,
            h: nil, m: nil, l: nil, sq: nil, hr: nil,
            alia: nil,
            privilege: nil
        )
        song.source = MusicSource(rawValue: source ?? "") ?? song.musicSource
        song.qqMid = qqMid
        song.qishuiTrackId = qishuiTrackId
        return song
    }
}

// MARK: - 云端快照

struct LocalPlaylistCloudSnapshot: Codable, Hashable {
    var updatedAt: Date
    var deviceId: String
    var deviceName: String
    var playlists: [LocalPlaylistCloudPlaylist]
    /// 下载记录元数据（v2 新增）
    var downloads: [CloudDownloadRecord]?
    /// 本地播客订阅（v2 新增）
    var localRadioSubscriptions: [RadioStation]?
}

struct LocalPlaylistCloudFetchResponse: Codable {
    var ok: Bool
    var tokenName: String?
    var hasSnapshot: Bool
    var updatedAt: Date?
    var revision: String?
    var playlists: [LocalPlaylistCloudPlaylist]
    /// 下载记录元数据（v2 新增）
    var downloads: [CloudDownloadRecord]?
    /// 本地播客订阅（v2 新增）
    var localRadioSubscriptions: [RadioStation]?
}

struct LocalPlaylistCloudUploadResponse: Codable {
    var ok: Bool
    var updatedAt: Date
    var revision: String
    var playlistCount: Int
    var songCount: Int
}

struct LocalPlaylistCloudDeleteResponse: Codable {
    var ok: Bool
    var updatedAt: Date
}
