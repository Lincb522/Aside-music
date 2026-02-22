import Foundation
import SwiftData

/// 已下载歌曲数据模型
@Model
final class DownloadedSong {
    @Attribute(.unique) var uniqueKey: String  // "ncm_123" 或 "qq_456"，避免跨平台 ID 冲突
    var id: Int
    var name: String
    var artistName: String
    var albumName: String?
    var coverUrl: String?
    var duration: Int?
    
    /// 下载状态
    var statusRaw: String
    /// 下载进度 0.0 ~ 1.0
    var progress: Double
    /// 音质等级
    var qualityRaw: String
    /// 本地文件相对路径
    var localPath: String?
    /// 文件大小（字节）
    var fileSize: Int64
    /// 下载时间
    var downloadedAt: Date?
    /// 创建时间（加入队列时间）
    var createdAt: Date
    
    // MARK: - QQ 音乐扩展字段
    /// QQ 音乐歌曲 mid（用于获取播放 URL）
    var qqMid: String?
    /// 是否为 QQ 音乐歌曲
    var isQQMusic: Bool
    /// QQ 音乐音质（仅 QQ 音乐歌曲使用）
    var qqQualityRaw: String?
    
    enum Status: String {
        case waiting = "waiting"
        case downloading = "downloading"
        case completed = "completed"
        case failed = "failed"
    }
    
    var status: Status {
        get { Status(rawValue: statusRaw) ?? .waiting }
        set { statusRaw = newValue.rawValue }
    }
    
    var quality: SoundQuality {
        get { SoundQuality(rawValue: qualityRaw) ?? .exhigh }
        set { qualityRaw = newValue.rawValue }
    }
    
    /// QQ 音乐音质
    var qqQuality: QQMusicQuality? {
        get {
            guard let raw = qqQualityRaw else { return nil }
            return QQMusicQuality(rawValue: raw)
        }
        set { qqQualityRaw = newValue?.rawValue }
    }
    
    init(
        id: Int,
        name: String,
        artistName: String,
        albumName: String? = nil,
        coverUrl: String? = nil,
        duration: Int? = nil,
        quality: SoundQuality = .exhigh,
        qqMid: String? = nil,
        isQQMusic: Bool = false,
        qqQuality: QQMusicQuality? = nil
    ) {
        self.uniqueKey = isQQMusic ? "qq_\(id)" : "ncm_\(id)"
        self.id = id
        self.name = name
        self.artistName = artistName
        self.albumName = albumName
        self.coverUrl = coverUrl
        self.duration = duration
        self.statusRaw = Status.waiting.rawValue
        self.progress = 0
        self.qualityRaw = quality.rawValue
        self.localPath = nil
        self.fileSize = 0
        self.downloadedAt = nil
        self.createdAt = Date()
        self.qqMid = qqMid
        self.isQQMusic = isQQMusic
        self.qqQualityRaw = qqQuality?.rawValue
    }
    
    /// 从 Song 模型创建（网易云）
    convenience init(from song: Song, quality: SoundQuality = .exhigh) {
        self.init(
            id: song.id,
            name: song.name,
            artistName: song.artistName,
            albumName: song.al?.name,
            coverUrl: song.coverUrl?.absoluteString,
            duration: song.dt,
            quality: quality,
            qqMid: song.qqMid,
            isQQMusic: song.isQQMusic
        )
    }
    
    /// 从 Song 模型创建（QQ 音乐）
    convenience init(from song: Song, qqQuality: QQMusicQuality) {
        self.init(
            id: song.id,
            name: song.name,
            artistName: song.artistName,
            albumName: song.al?.name,
            coverUrl: song.coverUrl?.absoluteString,
            duration: song.dt,
            qqMid: song.qqMid,
            isQQMusic: true,
            qqQuality: qqQuality
        )
    }
    
    /// 转换为 Song 模型（用于离线播放）
    func toSong() -> Song {
        return Song(
            id: id,
            name: name,
            ar: [Artist(id: 0, name: artistName)],
            al: Album(id: 0, name: albumName ?? "", picUrl: coverUrl),
            dt: duration,
            fee: nil,
            mv: nil,
            h: nil, m: nil, l: nil, sq: nil, hr: nil,
            alia: nil,
            privilege: nil,
            source: isQQMusic ? .qqmusic : nil,
            qqMid: qqMid
        )
    }
    
    /// 本地音频文件完整 URL
    var localFileURL: URL? {
        guard let path = localPath else { return nil }
        return DownloadedSong.downloadsDirectory.appendingPathComponent(path)
    }
    
    /// 下载目录
    static var downloadsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// 格式化文件大小
    var fileSizeText: String {
        if fileSize == 0 { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}
