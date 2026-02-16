// SecureConfig.swift
// 安全配置管理 — 从 Info.plist 读取敏感配置，避免硬编码在源码中

import Foundation

/// 安全配置管理器
/// 所有敏感信息（API Key、服务器地址等）从 Info.plist 或环境变量读取
enum SecureConfig {
    
    // MARK: - API 服务器
    
    /// 网易云 API 服务器地址
    static var apiBaseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !envURL.isEmpty {
            return envURL
        }
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !plistURL.isEmpty,
           !plistURL.hasPrefix("$(") {
            return plistURL
        }
        // 兜底默认值
        AppLogger.warning("API_BASE_URL 未配置，使用默认值")
        return "https://ncm.zijiu522.cn"
    }
    
    /// QQ 音乐 API 服务器地址
    static var qqMusicBaseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["QQ_MUSIC_BASE_URL"],
           !envURL.isEmpty {
            return envURL
        }
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "QQ_MUSIC_BASE_URL") as? String,
           !plistURL.isEmpty,
           !plistURL.hasPrefix("$(") {
            return plistURL
        }
        return "http://114.66.31.109:8000"
    }
}
