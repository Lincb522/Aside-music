// MusicActivityAttributes.swift
// 灵动岛 & Live Activity 数据模型
// 注意：此文件与 music/MusicActivityAttributes.swift 内容一致
// 主 App 和 Widget Extension 各自编译一份

import ActivityKit
import Foundation

struct MusicActivityAttributes: ActivityAttributes {
    
    /// 动态状态（播放过程中会变化的数据）
    public struct ContentState: Codable, Hashable {
        /// 是否正在播放
        var isPlaying: Bool
        /// 当前播放时间（秒）
        var currentTime: Double
        /// 总时长（秒）
        var duration: Double
        /// 歌手名
        var artistName: String
        /// 播放进度 (0.0 ~ 1.0)
        var progress: Double {
            guard duration > 0 else { return 0 }
            return min(currentTime / duration, 1.0)
        }
    }
    
    /// 固定属性（歌曲切换时才变化）
    var songName: String
    var artistName: String
    var albumName: String
    /// 封面图 URL 字符串
    var coverUrlString: String?
    /// 总时长（秒）
    var duration: Double
}
