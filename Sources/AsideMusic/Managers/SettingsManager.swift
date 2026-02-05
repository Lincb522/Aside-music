//
//  SettingsManager.swift
//  AsideMusic
//
//  全局设置管理器
//

import SwiftUI
import Combine

/// 全局设置管理器
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - 外观设置
    
    /// 是否启用液态玻璃效果
    @AppStorage("liquidGlassEnabled") var liquidGlassEnabled: Bool = true {
        didSet {
            objectWillChange.send()
        }
    }
    
    // MARK: - 播放设置
    
    /// 音质设置
    @AppStorage("soundQuality") var soundQuality: String = "standard"
    
    /// 自动播放下一首
    @AppStorage("autoPlayNext") var autoPlayNext: Bool = true
    
    /// 启用解灰（灰色歌曲自动匹配其他音源）
    @AppStorage("unblockEnabled") var unblockEnabled: Bool = true
    
    // MARK: - 缓存设置
    
    /// 最大缓存大小 (MB)
    @AppStorage("maxCacheSize") var maxCacheSize: Int = 500
    
    // MARK: - 其他设置
    
    /// 触感反馈
    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true
    
    private init() {}
}
