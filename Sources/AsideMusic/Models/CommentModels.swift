// CommentModels.swift
// 评论系统数据模型

import Foundation

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
    
    /// 格式化时间
    var formattedTime: String {
        if let str = timeStr, !str.isEmpty { return str }
        let date = Date(timeIntervalSince1970: Double(time) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// IP 属地文本
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
        case .recommended: return "推荐"
        case .hot: return "最热"
        case .latest: return "最新"
        }
    }
}
