// MusicSource.swift
// 音乐平台来源标识

import Foundation

/// 音乐平台来源
enum MusicSource: String, Codable, CaseIterable {
    /// ncm（默认）
    case netease = "netease"
    /// qcm
    case qqmusic = "qqmusic"
    /// 汽水音乐
    case qishui = "qishui"
    /// 本地音乐
    case local = "local"
    
    var displayName: String {
        switch self {
        case .netease: return "NCM"
        case .qqmusic: return "QCM"
        case .qishui: return "QSM"
        case .local: return "Local"
        }
    }
    
    var shortName: String {
        switch self {
        case .netease: return "NCM"
        case .qqmusic: return "QCM"
        case .qishui: return "QSM"
        case .local: return "Local"
        }
    }

    var widgetDisplayName: String {
        switch self {
        case .netease: return "NCM"
        case .qqmusic: return "QCM"
        case .qishui: return "QSM"
        case .local: return "Local"
        }
    }
}
