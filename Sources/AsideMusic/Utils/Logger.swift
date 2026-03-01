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
/// DEBUG 模式：始终收集 + 控制台输出
/// Release 模式：默认不收集，打开调试日志界面后才开始收集，零额外开销
enum AppLogger {
    
    private nonisolated(unsafe) static var logs: [LogEntry] = []
    private static let maxLogs = 1000
    private static let lock = NSLock()
    
    #if DEBUG
    nonisolated(unsafe) static var isCollectionEnabled = true
    #else
    nonisolated(unsafe) static var isCollectionEnabled = false
    #endif
    
    static func getAllLogs() -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return logs
    }
    
    static func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        logs.removeAll()
    }
    
    private static func addLog(_ entry: LogEntry) {
        lock.lock()
        defer { lock.unlock() }
        logs.append(entry)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }
    
    static func info(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        print("INFO [\(fileName):\(line)] \(msg)")
        addLog(LogEntry(timestamp: Date(), level: .info, message: msg, file: file, line: line))
        #else
        guard isCollectionEnabled else { return }
        addLog(LogEntry(timestamp: Date(), level: .info, message: message(), file: file, line: line))
        #endif
    }
    
    static func debug(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        print("DEBUG [\(fileName):\(line)] \(msg)")
        addLog(LogEntry(timestamp: Date(), level: .debug, message: msg, file: file, line: line))
        #else
        guard isCollectionEnabled else { return }
        addLog(LogEntry(timestamp: Date(), level: .debug, message: message(), file: file, line: line))
        #endif
    }
    
    static func warning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        print("WARNING [\(fileName):\(line)] \(msg)")
        addLog(LogEntry(timestamp: Date(), level: .warning, message: msg, file: file, line: line))
        #else
        guard isCollectionEnabled else { return }
        addLog(LogEntry(timestamp: Date(), level: .warning, message: message(), file: file, line: line))
        #endif
    }
    
    static func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        print("ERROR [\(fileName):\(line)] \(msg)")
        addLog(LogEntry(timestamp: Date(), level: .error, message: msg, file: file, line: line))
        #else
        guard isCollectionEnabled else { return }
        addLog(LogEntry(timestamp: Date(), level: .error, message: message(), file: file, line: line))
        #endif
    }
    
    static func network(_ message: @autoclosure () -> String) {
        #if DEBUG
        let msg = message()
        print("NETWORK \(msg)")
        addLog(LogEntry(timestamp: Date(), level: .network, message: msg, file: "", line: 0))
        #else
        guard isCollectionEnabled else { return }
        addLog(LogEntry(timestamp: Date(), level: .network, message: message(), file: "", line: 0))
        #endif
    }
    
    static func success(_ message: @autoclosure () -> String) {
        #if DEBUG
        let msg = message()
        print("SUCCESS \(msg)")
        addLog(LogEntry(timestamp: Date(), level: .success, message: msg, file: "", line: 0))
        #else
        guard isCollectionEnabled else { return }
        addLog(LogEntry(timestamp: Date(), level: .success, message: message(), file: "", line: 0))
        #endif
    }
}
