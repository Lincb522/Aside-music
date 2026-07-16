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

/// 可独立于歌曲播放平台选择的歌词来源。
enum LyricSource: String, Codable, CaseIterable, Identifiable {
    case netease = "netease"
    case qqmusic = "qqmusic"
    case qishui = "qishui"

    static let storageKey = "defaultLyricSource"
    static let followSongRawValue = "followSong"

    /// `nil` 表示关闭全局覆盖，歌词跟随歌曲自身的平台。
    static var globalDefaultOverride: LyricSource? {
        let rawValue = UserDefaults.standard.string(forKey: storageKey)
        guard rawValue != followSongRawValue else { return nil }
        return rawValue.flatMap(LyricSource.init(rawValue:)) ?? .netease
    }

    static func resolvedGlobalSource(for song: Song) -> LyricSource {
        globalDefaultOverride ?? source(matching: song.musicSource)
    }

    static func source(matching musicSource: MusicSource) -> LyricSource {
        switch musicSource {
        case .netease, .local: return .netease
        case .qqmusic: return .qqmusic
        case .qishui: return .qishui
        }
    }

    var id: String { rawValue }

    var musicSource: MusicSource {
        switch self {
        case .netease: return .netease
        case .qqmusic: return .qqmusic
        case .qishui: return .qishui
        }
    }

    var shortName: String {
        musicSource.shortName
    }
}
