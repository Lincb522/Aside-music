// 评论系统数据模型

import Foundation

// MARK: - 评论资源

/// 应用内统一的评论资源类型，避免跨平台模型直接依赖单一平台 SDK。
enum CommentResourceType: Int, Equatable, Sendable {
    case song = 0
    case mv = 1
    case playlist = 2
    case album = 3
    case dj = 4
    case video = 5
    case event = 6
}

/// 评论接口使用的平台原始资源标识，避免把应用内部的稳定 ID 误传给其他平台。
struct CommentResource: Equatable {
    let source: MusicSource
    let type: CommentResourceType
    let platformID: String

    init(source: MusicSource, type: CommentResourceType = .song, platformID: String) {
        self.source = source
        self.type = type
        self.platformID = platformID
    }

    init?(song: Song) {
        source = song.musicSource
        type = .song
        switch song.musicSource {
        case .netease:
            platformID = String(song.id)
        case .qqmusic:
            platformID = String(song.id)
        case .kugou:
            guard let mixSongID = song.kugouAlbumAudioID, mixSongID > 0 else { return nil }
            platformID = String(mixSongID)
        case .qishui, .appleMusic, .local:
            return nil
        }
    }

    var numericID: Int? { Int(platformID) }
    var supportsWriting: Bool { source == .netease }
    var supportsSorting: Bool { source == .netease || source == .qqmusic }
}

struct PlatformCommentPage {
    let comments: [Comment]
    let totalCount: Int
    let hasMore: Bool
    let cursor: String
}

// MARK: - 评论用户

struct CommentUser: Codable, Identifiable {
    let userId: Int
    let nickname: String
    let avatarUrl: String?
    let vipType: Int?
    
    var id: Int { userId }
    
    var avatarURL: URL? {
        guard let url = avatarUrl else { return nil }
        return URL(string: url)
    }
}

// MARK: - 评论 IP 属地

struct IPLocation: Codable {
    let location: String?
}

// MARK: - 评论被回复对象

struct CommentReplyInfo: Codable {
    let user: CommentUser?
    let content: String?
    let beRepliedCommentId: Int?
}

// MARK: - 评论

struct Comment: Codable, Identifiable {
    let commentId: Int
    let content: String
    let time: Int
    let likedCount: Int
    let liked: Bool
    let user: CommentUser
    let beReplied: [CommentReplyInfo]?
    let ipLocation: IPLocation?
    let timeStr: String?
    let parentCommentId: Int?
    
    var id: Int { commentId }
    
    nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .short
        return f
    }()
    
    var formattedTime: String {
        if let str = timeStr, !str.isEmpty { return str }
        let date = Date(timeIntervalSince1970: Double(time) / 1000)
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    var locationText: String? {
        ipLocation?.location
    }
}

// MARK: - 评论列表响应（commentNew 接口）

struct CommentNewResponse: Codable {
    let code: Int?
    let data: CommentNewData?
}

struct CommentNewData: Codable {
    let totalCount: Int?
    let hasMore: Bool?
    let cursor: String?
    let comments: [Comment]?
    let sortType: Int?
}

// MARK: - 热评响应

struct HotCommentResponse: Codable {
    let code: Int?
    let hotComments: [Comment]?
    let total: Int?
    let hasMore: Bool?
}

// MARK: - 评论排序类型

enum CommentSortType: Int, CaseIterable {
    case recommended = 99  // 推荐排序
    case hot = 2           // 热度排序
    case latest = 3        // 最新排序
    
    var title: String {
        switch self {
        case .recommended: return String(localized: "推荐")
        case .hot: return String(localized: "最热")
        case .latest: return String(localized: "最新")
        }
    }
}
