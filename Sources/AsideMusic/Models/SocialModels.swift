// SocialModels.swift
// 社交、私信、云盘、Mlog、动态等数据模型

import Foundation

// MARK: - 私信模型

struct PrivateMessage: Identifiable {
    let id = UUID()
    let userId: Int
    let nickname: String
    let avatarUrl: String?
    let lastMsg: String
    let lastMsgTime: Int
    let newMsgCount: Int
    
    var avatarURL: URL? {
        avatarUrl.flatMap { URL(string: $0) }
    }
    
    var timeText: String {
        let date = Date(timeIntervalSince1970: Double(lastMsgTime) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let fromUserId: Int
    let fromNickname: String
    let fromAvatarUrl: String?
    let msg: String
    let time: Int
    
    var fromAvatarURL: URL? {
        fromAvatarUrl.flatMap { URL(string: $0) }
    }
    
    var timeText: String {
        let date = Date(timeIntervalSince1970: Double(time) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 通知模型

struct NoticeItem: Identifiable {
    let id: Int
    let time: Int
    let type: Int
    let content: String
    
    var timeText: String {
        let date = Date(timeIntervalSince1970: Double(time) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 用户动态模型

struct UserEvent: Identifiable {
    let id: Int
    let eventTime: Int
    let actName: String
    let content: String
    let song: Song?
    let userName: String
    let userAvatarUrl: String?
    
    var userAvatarURL: URL? {
        userAvatarUrl.flatMap { URL(string: $0) }
    }
    
    var timeText: String {
        let date = Date(timeIntervalSince1970: Double(eventTime) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct UserEventResult {
    let events: [UserEvent]
    let lasttime: Int
    let more: Bool
}

// MARK: - Mlog 模型

struct MlogItem: Identifiable {
    let id: String
    let text: String
    let coverUrl: String?
    let duration: Int
    let song: Song?
    
    var coverURL: URL? {
        coverUrl.flatMap { URL(string: $0) }
    }
    
    var durationText: String {
        let seconds = duration / 1000
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - 听歌识曲模型

struct AudioMatchResult {
    let songs: [Song]
}
