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
        AppLogger.error("API_BASE_URL 未配置，请在 Secrets.xcconfig 中设置")
        #if DEBUG
        return "http://localhost:3000"
        #else
        assertionFailure("API_BASE_URL 未配置")
        return "http://localhost:3000"
        #endif
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
        AppLogger.error("QQ_MUSIC_BASE_URL 未配置，请在 Secrets.xcconfig 中设置")
        #if DEBUG
        return "http://localhost:8000"
        #else
        assertionFailure("QQ_MUSIC_BASE_URL 未配置")
        return "http://localhost:8000"
        #endif
    }
    
    /// 解灰源服务器地址
    static var unblockServerURL: String {
        if let envURL = ProcessInfo.processInfo.environment["UNBLOCK_SERVER_URL"],
           !envURL.isEmpty {
            return envURL
        }
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "UNBLOCK_SERVER_URL") as? String,
           !plistURL.isEmpty,
           !plistURL.hasPrefix("$(") {
            return plistURL
        }
        AppLogger.error("UNBLOCK_SERVER_URL 未配置，请在 Secrets.xcconfig 中设置")
        #if DEBUG
        return "http://localhost:4000"
        #else
        assertionFailure("UNBLOCK_SERVER_URL 未配置")
        return "http://localhost:4000"
        #endif
    }
}
