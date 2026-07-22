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

// MARK: - 播放记录与听歌统计

struct CloudPlayHistoryRecord: Codable, Equatable {
    var id: UUID
    var songId: Int
    var songName: String
    var artistName: String
    var coverUrl: String?
    var playedAt: Date
    var playDuration: Int
    var completed: Bool
    var sourceRaw: String?
    var qqMid: String?
    var qqAlbumMid: String?
    var qishuiTrackId: Int?

    init(from record: PlayHistory) {
        id = record.id
        songId = record.songId
        songName = record.songName
        artistName = record.artistName
        coverUrl = record.coverUrl
        playedAt = record.playedAt
        playDuration = record.playDuration
        completed = record.completed
        sourceRaw = record.sourceRaw
        qqMid = record.qqMid
        qqAlbumMid = record.qqAlbumMid
        qishuiTrackId = record.qishuiTrackId
    }

    func makeLocalRecord() -> PlayHistory {
        let record = PlayHistory(
            songId: songId,
            songName: songName,
            artistName: artistName,
            coverUrl: coverUrl,
            playDuration: max(0, playDuration),
            completed: completed,
            sourceRaw: sourceRaw,
            qqMid: qqMid,
            qqAlbumMid: qqAlbumMid,
            qishuiTrackId: qishuiTrackId
        )
        record.id = id
        record.playedAt = playedAt
        return record
    }
}

struct CloudPlaybackHistorySnapshot: Codable {
    var records: [CloudPlayHistoryRecord]
    var recentClearedAt: Date?
}

// MARK: - 个性化与音效

struct CloudThemeCustomizationEntry: Codable {
    var theme: GlobalThemeId
    var currentLight: ThemeColorPreset?
    var savedLight: [ThemeColorPreset]
    var currentDark: ThemeColorPreset?
    var savedDark: [ThemeColorPreset]
}

struct CloudThemeCustomizationSnapshot: Codable {
    var entries: [CloudThemeCustomizationEntry]
}

struct CloudAIEqualizerSongMetadata: Codable, Hashable {
    var songIdentifier: String
    var songId: Int
    var songName: String
    var artistName: String
    var albumName: String?
    var coverUrl: String?
    var sourceRaw: String

    init(song: Song) {
        let source = song.musicSource
        songIdentifier = "\(source.rawValue):\(song.id)"
        songId = song.id
        songName = song.name
        artistName = song.artistName
        albumName = song.al?.name
        coverUrl = song.coverUrl?.absoluteString
        sourceRaw = source.rawValue
    }
}

struct CloudAIEqualizerSnapshot: Codable {
    var cachedProposals: [String: AIEqualizerProposal]
    var savedProposals: [String: [AIEqualizerSavedProposal]]
    var proposalMetadata: [String: CloudAIEqualizerSongMetadata]? = nil
}

// MARK: - 云端快照

struct LocalPlaylistCloudSnapshot: Codable {
    /// 云端协议版本；服务端据此区分旧客户端未上传字段与新版主动清空。
    var version: Int = 3
    var updatedAt: Date
    var deviceId: String
    var deviceName: String
    var playlists: [LocalPlaylistCloudPlaylist]
    /// 下载记录元数据（v2 新增）
    var downloads: [CloudDownloadRecord]?
    /// 本地播客订阅（v2 新增）
    var localRadioSubscriptions: [RadioStation]?
    /// 个性化配色与用户保存的配色方案（v3 新增）
    var themeCustomization: CloudThemeCustomizationSnapshot?
    /// 播放记录是听歌统计的数据源（v3 新增）
    var playbackHistory: CloudPlaybackHistorySnapshot?
    /// AI 智能调音缓存与历史方案（v3 新增）
    var aiEqualizer: CloudAIEqualizerSnapshot?
    /// 用户自定义均衡器预设（v3 新增）
    var customEQPresets: [EQPreset]?
}

struct LocalPlaylistCloudFetchResponse: Codable {
    var ok: Bool
    var tokenName: String?
    var hasSnapshot: Bool
    var version: Int?
    var updatedAt: Date?
    var revision: String?
    var playlists: [LocalPlaylistCloudPlaylist]
    /// 下载记录元数据（v2 新增）
    var downloads: [CloudDownloadRecord]?
    /// 本地播客订阅（v2 新增）
    var localRadioSubscriptions: [RadioStation]?
    /// 个性化配色与用户保存的配色方案（v3 新增）
    var themeCustomization: CloudThemeCustomizationSnapshot?
    /// 播放记录与听歌统计（v3 新增）
    var playbackHistory: CloudPlaybackHistorySnapshot?
    /// AI 智能调音方案（v3 新增）
    var aiEqualizer: CloudAIEqualizerSnapshot?
    /// 用户自定义均衡器预设（v3 新增）
    var customEQPresets: [EQPreset]?
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
