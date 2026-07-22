// Logger.swift
// 条件日志工具 — 线程安全、事件驱动的内存日志缓冲区

import Foundation

extension Notification.Name {
    static let appLoggerDidChange = Notification.Name("com.monologue.logger.didChange")
}

struct LogEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
    let file: String
    let line: Int
    let function: String
    let thread: String
    let step: String

    init(
        id: UUID = UUID(),
        timestamp: Date,
        level: LogLevel,
        message: String,
        file: String,
        line: Int,
        function: String = "",
        thread: String = "",
        step: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.file = file
        self.line = line
        self.function = function
        self.thread = thread
        self.step = step
    }

    enum LogLevel: String, CaseIterable, Hashable, Codable, Sendable {
        case info = "INFO"
        case debug = "DEBUG"
        case warning = "WARNING"
        case error = "ERROR"
        case network = "NETWORK"
        case success = "SUCCESS"
    }

    var formattedTime: String {
        LogTimestampFormatter.timeString(from: timestamp)
    }

    var detailedTimestamp: String {
        LogTimestampFormatter.detailString(from: timestamp)
    }

    var fileName: String {
        (file as NSString).lastPathComponent
    }

    var sourceDescription: String {
        guard !fileName.isEmpty else { return "—" }
        return line > 0 ? "\(fileName):\(line)" : fileName
    }

    var fullSourceDescription: String {
        guard !file.isEmpty else { return "—" }
        return line > 0 ? "\(file):\(line)" : file
    }

    var resolvedStep: String {
        let explicitStep = step.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicitStep.isEmpty {
            return explicitStep
        }

        if message.hasPrefix("["),
           let closingIndex = message.firstIndex(of: "]")
        {
            let tag = String(message[message.index(after: message.startIndex)..<closingIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !tag.isEmpty, tag.count <= 48 {
                let actionStart = message.index(after: closingIndex)
                let remainder = String(message[actionStart...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let separators = CharacterSet(charactersIn: ":：,，\n")
                let action = remainder.components(separatedBy: separators).first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !action.isEmpty {
                    return "\(tag) · \(String(action.prefix(40)))"
                }
                return tag
            }
        }

        let functionName = function.trimmingCharacters(in: .whitespacesAndNewlines)
        return functionName.isEmpty ? "—" : functionName
    }

    var exportText: String {
        var components = ["[\(detailedTimestamp)]", level.rawValue]
        if !fileName.isEmpty {
            components.append("[\(sourceDescription)]")
        }
        if !file.isEmpty, file != fileName {
            components.append("[PATH: \(file)]")
        }
        if !function.isEmpty {
            components.append("[\(function)]")
        }
        if resolvedStep != "—" {
            components.append("[STEP: \(resolvedStep)]")
        }
        if !thread.isEmpty {
            components.append("[\(thread)]")
        }
        components.append(message)
        return components.joined(separator: " ")
    }

    func matches(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        return message.localizedCaseInsensitiveContains(normalized)
            || fileName.localizedCaseInsensitiveContains(normalized)
            || file.localizedCaseInsensitiveContains(normalized)
            || function.localizedCaseInsensitiveContains(normalized)
            || thread.localizedCaseInsensitiveContains(normalized)
            || resolvedStep.localizedCaseInsensitiveContains(normalized)
            || level.rawValue.localizedCaseInsensitiveContains(normalized)
    }
}

struct AppLogSnapshot: Sendable {
    let entries: [LogEntry]
    let counts: [LogEntry.LogLevel: Int]
    let droppedCount: Int
    let revision: UInt64

    static let empty = AppLogSnapshot(entries: [], counts: [:], droppedCount: 0, revision: 0)

    func count(for level: LogEntry.LogLevel) -> Int {
        counts[level, default: 0]
    }
}

private enum LogTimestampFormatter {
    private static let lock = NSLock()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static let detail: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    static func timeString(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return time.string(from: date)
    }

    static func detailString(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return detail.string(from: date)
    }
}

enum AppLogger {
    private struct ExportArchive: Codable {
        let version: Int
        let generatedAt: Date
        let entries: [LogEntry]
    }

    private static let maxLogs = 2_500
    private static let stateLock = NSLock()
    private nonisolated(unsafe) static var logs: [LogEntry] = []
    private nonisolated(unsafe) static var droppedCount = 0
    private nonisolated(unsafe) static var revision: UInt64 = 0
    private nonisolated(unsafe) static var changeNotificationPending = false
    private nonisolated(unsafe) static var collectionEnabled: Bool = {
        #if DEBUG
        if UserDefaults.standard.object(forKey: "log_collection_enabled") == nil {
            return true
        }
        #endif
        return UserDefaults.standard.bool(forKey: "log_collection_enabled")
    }()

    static var isCollectionEnabled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return collectionEnabled
    }

    static func setCollectionEnabled(_ enabled: Bool) {
        stateLock.lock()
        guard collectionEnabled != enabled else {
            stateLock.unlock()
            return
        }
        collectionEnabled = enabled
        revision &+= 1
        stateLock.unlock()

        UserDefaults.standard.set(enabled, forKey: "log_collection_enabled")
        scheduleChangeNotification()
    }

    static func snapshot() -> AppLogSnapshot {
        stateLock.lock()
        let entries = logs
        let currentDroppedCount = droppedCount
        let currentRevision = revision
        stateLock.unlock()

        var counts: [LogEntry.LogLevel: Int] = [:]
        counts.reserveCapacity(LogEntry.LogLevel.allCases.count)
        for entry in entries {
            counts[entry.level, default: 0] += 1
        }
        return AppLogSnapshot(
            entries: entries,
            counts: counts,
            droppedCount: currentDroppedCount,
            revision: currentRevision
        )
    }

    static func getAllLogs() -> [LogEntry] {
        snapshot().entries
    }

    static func clearLogs() {
        stateLock.lock()
        logs.removeAll(keepingCapacity: true)
        droppedCount = 0
        revision &+= 1
        stateLock.unlock()
        scheduleChangeNotification()
    }

    static func textExport(entries: [LogEntry]) -> String {
        entries.map(\.exportText).joined(separator: "\n")
    }

    static func jsonExport(entries: [LogEntry]) -> String? {
        let archive = ExportArchive(version: 1, generatedAt: Date(), entries: entries)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(archive) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func info(
        _ message: @autoclosure () -> String,
        step: String = "",
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(.info, message: message, step: step, file: file, line: line, function: function)
    }

    static func debug(
        _ message: @autoclosure () -> String,
        step: String = "",
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(.debug, message: message, step: step, file: file, line: line, function: function)
    }

    static func warning(
        _ message: @autoclosure () -> String,
        step: String = "",
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(.warning, message: message, step: step, file: file, line: line, function: function)
    }

    static func error(
        _ message: @autoclosure () -> String,
        step: String = "",
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(.error, message: message, step: step, file: file, line: line, function: function)
    }

    static func network(
        _ message: @autoclosure () -> String,
        step: String = "",
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(.network, message: message, step: step, file: file, line: line, function: function)
    }

    static func success(
        _ message: @autoclosure () -> String,
        step: String = "",
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(.success, message: message, step: step, file: file, line: line, function: function)
    }

    private static func record(
        _ level: LogEntry.LogLevel,
        message: () -> String,
        step: String,
        file: String,
        line: Int,
        function: String
    ) {
        guard isCollectionEnabled else { return }
        let value = message()

        #if DEBUG
        let source = (file as NSString).lastPathComponent
        let stepLabel = step.isEmpty ? "" : " [\(step)]"
        print("\(level.rawValue) [\(source):\(line)]\(stepLabel) \(value)")
        #endif

        addLog(
            LogEntry(
                timestamp: Date(),
                level: level,
                message: value,
                file: file,
                line: line,
                function: function,
                thread: currentThreadName,
                step: step
            )
        )
    }

    private static var currentThreadName: String {
        if Thread.isMainThread { return "main" }
        let name = Thread.current.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "background" : name
    }

    private static func addLog(_ entry: LogEntry) {
        stateLock.lock()
        logs.append(entry)
        if logs.count > maxLogs {
            let overflow = logs.count - maxLogs
            logs.removeFirst(overflow)
            droppedCount += overflow
        }
        revision &+= 1
        stateLock.unlock()
        scheduleChangeNotification()
    }

    private static func scheduleChangeNotification() {
        stateLock.lock()
        guard !changeNotificationPending else {
            stateLock.unlock()
            return
        }
        changeNotificationPending = true
        stateLock.unlock()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            stateLock.lock()
            changeNotificationPending = false
            let currentRevision = revision
            stateLock.unlock()

            NotificationCenter.default.post(
                name: .appLoggerDidChange,
                object: nil,
                userInfo: ["revision": currentRevision]
            )
        }
    }
}
