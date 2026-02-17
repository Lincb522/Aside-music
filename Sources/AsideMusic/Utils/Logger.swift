// Logger.swift
// 条件日志工具 — Release 构建下不输出日志，避免泄露敏感信息

import Foundation

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let file: String
    let line: Int
    
    enum LogLevel: String {
        case info = "INFO"
        case debug = "DEBUG"
        case warning = "WARNING"
        case error = "ERROR"
        case network = "NETWORK"
        case success = "SUCCESS"
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .debug: return "gray"
            case .warning: return "orange"
            case .error: return "red"
            case .network: return "purple"
            case .success: return "green"
            }
        }
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var fileName: String {
        (file as NSString).lastPathComponent
    }
}

/// 统一日志管理器
/// 仅在 DEBUG 模式下输出日志，Release 构建自动静默
enum AppLogger {
    
    // 日志存储（最多保留 1000 条）
    private static var logs: [LogEntry] = []
    private static let maxLogs = 1000
    private static let lock = NSLock()
    
    /// 获取所有日志
    static func getAllLogs() -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return logs
    }
    
    /// 清空日志
    static func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        logs.removeAll()
    }
    
    /// 添加日志
    private static func addLog(_ entry: LogEntry) {
        lock.lock()
        defer { lock.unlock() }
        logs.append(entry)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }
    
    /// 普通信息日志
    static func info(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        #if DEBUG
        print("INFO [\(fileName):\(line)] \(msg)")
        #endif
        addLog(LogEntry(timestamp: Date(), level: .info, message: msg, file: file, line: line))
    }
    
    /// 调试日志
    static func debug(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        #if DEBUG
        print("DEBUG [\(fileName):\(line)] \(msg)")
        #endif
        addLog(LogEntry(timestamp: Date(), level: .debug, message: msg, file: file, line: line))
    }
    
    /// 警告日志
    static func warning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        #if DEBUG
        print("WARNING [\(fileName):\(line)] \(msg)")
        #endif
        addLog(LogEntry(timestamp: Date(), level: .warning, message: msg, file: file, line: line))
    }
    
    /// 错误日志（Release 下也输出，但不包含敏感信息）
    static func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        #if DEBUG
        print("ERROR [\(fileName):\(line)] \(msg)")
        #endif
        addLog(LogEntry(timestamp: Date(), level: .error, message: msg, file: file, line: line))
    }
    
    /// 网络请求日志（仅 DEBUG，避免泄露 URL 中的 API Key）
    static func network(_ message: @autoclosure () -> String) {
        let msg = message()
        #if DEBUG
        print("NETWORK \(msg)")
        #endif
        addLog(LogEntry(timestamp: Date(), level: .network, message: msg, file: "", line: 0))
    }
    
    /// 成功日志
    static func success(_ message: @autoclosure () -> String) {
        let msg = message()
        #if DEBUG
        print("SUCCESS \(msg)")
        #endif
        addLog(LogEntry(timestamp: Date(), level: .success, message: msg, file: "", line: 0))
    }
}
