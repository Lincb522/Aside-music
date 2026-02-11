// MVModels.swift
// MV 相关数据模型

import Foundation

// MARK: - MV 基础模型

struct MV: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let artistName: String?
    let artistId: Int?
    let cover: String?
    let playCount: Int?
    let duration: Int?
    let desc: String?
    let publishTime: String?

    // MV 列表接口返回的字段
    let artists: [MVArtist]?
    let briefDesc: String?

    enum CodingKeys: String, CodingKey {
        case id, name, cover, duration, desc, publishTime
        case artistName, artistId
        case artists, briefDesc
        case playCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.cover = try container.decodeIfPresent(String.self, forKey: .cover)
        self.duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        self.desc = try container.decodeIfPresent(String.self, forKey: .desc)
        self.publishTime = try container.decodeIfPresent(String.self, forKey: .publishTime)
        self.artists = try container.decodeIfPresent([MVArtist].self, forKey: .artists)
        self.briefDesc = try container.decodeIfPresent(String.self, forKey: .briefDesc)
        self.playCount = try container.decodeIfPresent(Int.self, forKey: .playCount)

        // artistName 可能直接给，也可能从 artists 数组取
        if let name = try container.decodeIfPresent(String.self, forKey: .artistName) {
            self.artistName = name
        } else if let first = self.artists?.first {
            self.artistName = first.name
        } else {
            self.artistName = nil
        }

        if let aid = try container.decodeIfPresent(Int.self, forKey: .artistId) {
            self.artistId = aid
        } else if let first = self.artists?.first {
            self.artistId = first.id
        } else {
            self.artistId = nil
        }
    }

    var coverUrl: String? {
        cover
    }

    /// 格式化播放量
    var playCountText: String {
        guard let count = playCount else { return "" }
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }

    /// 格式化时长
    var durationText: String {
        guard let ms = duration else { return "" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MV, rhs: MV) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MV 歌手

struct MVArtist: Codable, Identifiable {
    let id: Int
    let name: String?
    let img1v1Url: String?
}

// MARK: - MV 详情

struct MVDetail: Codable {
    let id: Int
    let name: String?
    let artistName: String?
    let artistId: Int?
    let artists: [MVArtist]?
    let cover: String?
    let playCount: Int?
    let subCount: Int?
    let shareCount: Int?
    let commentCount: Int?
    let duration: Int?
    let desc: String?
    let publishTime: String?
    let brs: [String: Int]?  // 可用分辨率

    var coverUrl: String? { cover }

    var durationText: String {
        guard let ms = duration else { return "" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var displayArtistName: String {
        artistName ?? artists?.first?.name ?? "未知歌手"
    }
}

// MARK: - MV URL

struct MVUrl: Codable {
    let id: Int?
    let url: String?
    let r: Int?  // 分辨率
    let size: Int?
    let code: Int?
}

// MARK: - MV 互动数据（点赞/评论/分享）

struct MVDetailInfo: Codable {
    let liked: Bool?
    let commentCount: Int?
    let likedCount: Int?
    let shareCount: Int?

    enum CodingKeys: String, CodingKey {
        case liked, commentCount, likedCount, shareCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.liked = try container.decodeIfPresent(Bool.self, forKey: .liked)
        self.commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        self.likedCount = try container.decodeIfPresent(Int.self, forKey: .likedCount)
        self.shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount)
    }
}

// MARK: - 已收藏 MV 项

struct MVSubItem: Codable, Identifiable {
    let vid: String?
    let title: String?
    let creator: [MVSubCreator]?
    let coverUrl: String?
    let playTime: Int?
    let durationms: Int?

    var id: String { vid ?? UUID().uuidString }

    var artistName: String? {
        creator?.first?.userName
    }

    var playCountText: String {
        guard let count = playTime else { return "" }
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }

    var durationText: String {
        guard let ms = durationms else { return "" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MVSubCreator: Codable {
    let userId: Int?
    let userName: String?
}
