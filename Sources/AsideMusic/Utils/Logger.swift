// Logger.swift
// 条件日志工具 — Release 构建下不输出日志，避免泄露敏感信息

import Foundation

/// 统一日志管理器
/// 仅在 DEBUG 模式下输出日志，Release 构建自动静默
enum AppLogger {
    
    /// 普通信息日志
    static func info(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("ℹ️ [\(fileName):\(line)] \(message())")
        #endif
    }
    
    /// 调试日志
    static func debug(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("🔍 [\(fileName):\(line)] \(message())")
        #endif
    }
    
    /// 警告日志
    static func warning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("⚠️ [\(fileName):\(line)] \(message())")
        #endif
    }
    
    /// 错误日志（Release 下也输出，但不包含敏感信息）
    static func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("❌ [\(fileName):\(line)] \(message())")
        #endif
    }
    
    /// 网络请求日志（仅 DEBUG，避免泄露 URL 中的 API Key）
    static func network(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("🔗 \(message())")
        #endif
    }
    
    /// 成功日志
    static func success(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("✅ \(message())")
        #endif
    }
}
