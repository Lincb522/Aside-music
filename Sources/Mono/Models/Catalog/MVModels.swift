// MV 相关数据模型

import Foundation

private func normalizedMVDisplayName(_ rawName: String?, artistName: String?) -> String {
    let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let lowercased = trimmed.lowercased()
    let isNumeric = !trimmed.isEmpty && trimmed.allSatisfy { $0.isNumber }
    let generatedPatterns = [
        #"^mmexport\d+$"#,
        #"^(vid|mv|wx_camera|dji)_?\d+$"#,
        #"^[a-f0-9]{20,}$"#,
    ]
    let isGenerated = generatedPatterns.contains {
        lowercased.range(of: $0, options: .regularExpression) != nil
    }
    guard !trimmed.isEmpty, !isNumeric, !isGenerated else {
        if let artist = artistName?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            return "\(artist) · MV"
        }
        return String(localized: "mv_unknown_name")
    }
    return trimmed
}

// MARK: - MV 基础模型

/// 统一不同 MV 接口字段差异的视频条目。
///
/// 歌手与封面既可能直接返回，也可能嵌在数组或接口专用字段中，解码时统一归一化。
struct MV: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let artistName: String?
    let artistId: Int?
    let cover: String?
    let imgurl: String?       // 歌手 MV 接口返回的封面字段
    let imgurl16v9: String?   // 歌手 MV 接口返回的 16:9 封面
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
        case imgurl, imgurl16v9
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.cover = try container.decodeIfPresent(String.self, forKey: .cover)
        self.imgurl = try container.decodeIfPresent(String.self, forKey: .imgurl)
        self.imgurl16v9 = try container.decodeIfPresent(String.self, forKey: .imgurl16v9)
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

    /// 封面 URL — 优先 imgurl16v9 > imgurl > cover（兼容不同接口返回格式）
    var coverUrl: String? {
        imgurl16v9 ?? imgurl ?? cover
    }

    /// 过滤接口偶尔返回的导出文件名或纯编号，避免把内部编号直接展示给用户。
    var displayName: String {
        normalizedMVDisplayName(name, artistName: artistName)
    }

    /// 格式化播放量
    var playCountText: String {
        guard let count = playCount else { return "" }
        if count >= 100_000_000 {
            return String(format: String(localized: "count_hundred_million"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "count_ten_thousand"), Double(count) / 10_000)
        }
        return "\(count)"
    }

    /// 格式化时长
    var durationText: String {
        guard let ms = duration, ms > 0 else { return "" }
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

// MARK: - KCM MV

struct KCMMV: Identifiable, Hashable, Sendable {
    let hash: String
    let videoID: Int?
    let name: String
    let artistName: String?
    let artistID: Int?
    let coverURL: String?
    let duration: Int?
    let playCount: Int?
    let publishDate: String?
    let description: String?

    var id: String { hash.lowercased() }

    var durationText: String {
        guard let duration, duration > 0 else { return "" }
        return String(format: "%d:%02d", duration / 60, duration % 60)
    }

    var playCountText: String {
        guard let playCount else { return "" }
        if playCount >= 100_000_000 {
            return String(format: String(localized: "count_hundred_million"), Double(playCount) / 100_000_000)
        }
        if playCount >= 10_000 {
            return String(format: String(localized: "count_ten_thousand"), Double(playCount) / 10_000)
        }
        return String(playCount)
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
    let brs: [String: Int]?  // 可用分辨率（可能是字典或数组，用自定义解码兼容）

    enum CodingKeys: String, CodingKey {
        case id, name, artistName, artistId, artists, cover
        case playCount, subCount, shareCount, commentCount
        case duration, desc, publishTime, brs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName)
        artistId = try container.decodeIfPresent(Int.self, forKey: .artistId)
        artists = try container.decodeIfPresent([MVArtist].self, forKey: .artists)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount)
        subCount = try container.decodeIfPresent(Int.self, forKey: .subCount)
        shareCount = try container.decodeIfPresent(Int.self, forKey: .shareCount)
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        desc = try container.decodeIfPresent(String.self, forKey: .desc)
        publishTime = try container.decodeIfPresent(String.self, forKey: .publishTime)
        // brs 可能是 {"1080": 1, "720": 1} 或 [{"size":xxx,"br":1080}]，兼容处理
        brs = try? container.decodeIfPresent([String: Int].self, forKey: .brs)
    }

    var coverUrl: String? { cover }

    var durationText: String {
        guard let ms = duration, ms > 0 else { return "" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var displayArtistName: String {
        artistName ?? artists?.first?.name ?? String(localized: "search_unknown_artist")
    }

    var displayName: String {
        normalizedMVDisplayName(name, artistName: displayArtistName)
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
            return String(format: String(localized: "count_hundred_million"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "count_ten_thousand"), Double(count) / 10_000)
        }
        return "\(count)"
    }

    var durationText: String {
        guard let ms = durationms, ms > 0 else { return "" }
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
