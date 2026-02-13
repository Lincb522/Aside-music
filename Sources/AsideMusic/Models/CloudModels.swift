// CloudModels.swift
// 云盘相关数据模型

import Foundation

// MARK: - 云盘歌曲

struct CloudSong: Identifiable, Codable {
    let songId: Int
    let songName: String
    let artist: String
    let album: String
    let fileSize: Int
    let bitrate: Int
    let addTime: Int?
    let fileName: String?
    let cover: Int?
    
    // 关联的标准歌曲信息（simpleSong）
    let simpleSong: Song?
    
    var id: Int { songId }
    
    /// 文件大小格式化
    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    /// 码率格式化
    var bitrateText: String {
        "\(bitrate / 1000)kbps"
    }
    
    /// 添加时间格式化
    var addTimeText: String {
        guard let ts = addTime else { return "" }
        let date = Date(timeIntervalSince1970: Double(ts) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 转换为标准 Song 用于播放
    func toSong() -> Song {
        if let s = simpleSong {
            return s
        }
        // 降级：用云盘信息构造
        return Song(
            id: songId,
            name: songName,
            ar: [Artist(id: 0, name: artist)],
            al: Album(id: 0, name: album, picUrl: nil),
            dt: nil,
            fee: 0,
            mv: 0,
            h: nil, m: nil, l: nil, sq: nil, hr: nil,
            alia: nil
        )
    }
}

// MARK: - 云盘列表响应

struct CloudListResponse {
    let data: [CloudSong]
    let count: Int
    let hasMore: Bool
    let size: String  // 已用空间
    let maxSize: String  // 总空间
}
