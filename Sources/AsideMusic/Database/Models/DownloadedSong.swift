import Foundation
import SwiftData

/// 已下载歌曲数据模型
@Model
final class DownloadedSong {
    @Attribute(.unique) var id: Int
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
    
    init(
        id: Int,
        name: String,
        artistName: String,
        albumName: String? = nil,
        coverUrl: String? = nil,
        duration: Int? = nil,
        quality: SoundQuality = .exhigh
    ) {
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
    }
    
    /// 从 Song 模型创建
    convenience init(from song: Song, quality: SoundQuality = .exhigh) {
        self.init(
            id: song.id,
            name: song.name,
            artistName: song.artistName,
            albumName: song.al?.name,
            coverUrl: song.coverUrl?.absoluteString,
            duration: song.dt,
            quality: quality
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
            privilege: nil
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
