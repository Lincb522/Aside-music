// MusicSource.swift
// 音乐平台来源标识

import Foundation

/// 音乐平台来源
enum MusicSource: String, Codable, CaseIterable {
    /// 网易云音乐（默认）
    case netease = "netease"
    /// QQ 音乐
    case qqmusic = "qqmusic"
    
    var displayName: String {
        switch self {
        case .netease: return "网易云音乐"
        case .qqmusic: return "QQ音乐"
        }
    }
    
    var shortName: String {
        switch self {
        case .netease: return "网易云"
        case .qqmusic: return "QQ"
        }
    }
}
