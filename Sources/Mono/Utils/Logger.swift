// 统一应用诊断日志 — 线程安全、结构化、脱敏并自动折叠高频重复记录

import Foundation

extension Notification.Name {
    static let appLoggerDidChange = Notification.Name("com.mono.logger.didChange")
}

/// 一条可持久化、可筛选的结构化诊断记录。
struct LogEntry: Identifiable, Hashable, Codable, Sendable {
    enum Category: String, CaseIterable, Hashable, Codable, Sendable {
        case app
        case playback
        case audio
        case network
        case appleMusic
        case lyrics
        case ai
        case modelTraining
        case localModel
        case cloud
        case database
        case download
        case session
        case interface
        case other
    }

    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: Category
    let event: String
    let message: String
    let file: String
    let line: Int
    let function: String
    let thread: String
    let step: String
    let sessionID: String
    let context: [String: String]
    let repeatCount: Int

    init(
        id: UUID = UUID(),
        timestamp: Date,
        level: LogLevel,
        category: Category = .other,
        event: String = "",
        message: String,
        file: String,
        line: Int,
        function: String = "",
        thread: String = "",
        step: String = "",
        sessionID: String = "",
        context: [String: String] = [:],
        repeatCount: Int = 1
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.event = event
        self.message = message
        self.file = file
        self.line = line
        self.function = function
        self.thread = thread
        self.step = step
        self.sessionID = sessionID
        self.context = context
        self.repeatCount = max(1, repeatCount)
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

    var resolvedEvent: String {
        let explicitEvent = event.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicitEvent.isEmpty {
            return explicitEvent
        }
        return resolvedStep
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
        components.append("[MODULE: \(category.rawValue)]")
        if resolvedEvent != "—" {
            components.append("[EVENT: \(resolvedEvent)]")
        }
        if !sessionID.isEmpty {
            components.append("[SESSION: \(sessionID)]")
        }
        if repeatCount > 1 {
            components.append("[REPEAT: \(repeatCount)]")
        }
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
        if !context.isEmpty {
            let value = context.keys.sorted().compactMap { key -> String? in
                guard let item = context[key] else { return nil }
                return "\(key)=\(item)"
            }.joined(separator: ", ")
            components.append("[CONTEXT: \(value)]")
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
            || resolvedEvent.localizedCaseInsensitiveContains(normalized)
            || category.rawValue.localizedCaseInsensitiveContains(normalized)
            || sessionID.localizedCaseInsensitiveContains(normalized)
            || context.contains { key, value in
                key.localizedCaseInsensitiveContains(normalized)
                    || value.localizedCaseInsensitiveContains(normalized)
            }
            || level.rawValue.localizedCaseInsensitiveContains(normalized)
    }

    fileprivate var duplicateSignature: String {
        [
            level.rawValue,
            category.rawValue,
            resolvedEvent,
            file,
            "\(line)",
            message,
            context.keys.sorted().compactMap { key in
                context[key].map { "\(key)=\($0)" }
            }.joined(separator: "&")
        ].joined(separator: "|")
    }

    fileprivate func coalescing(with newer: LogEntry) -> LogEntry {
        LogEntry(
            id: id,
            timestamp: newer.timestamp,
            level: level,
            category: category,
            event: event,
            message: message,
            file: file,
            line: line,
            function: function,
            thread: newer.thread,
            step: step,
            sessionID: sessionID,
            context: context,
            repeatCount: repeatCount + newer.repeatCount
        )
    }
}

struct AppLogSnapshot: Sendable {
    let entries: [LogEntry]
    let counts: [LogEntry.LogLevel: Int]
    let categoryCounts: [LogEntry.Category: Int]
    let droppedCount: Int
    let coalescedCount: Int
    let revision: UInt64

    static let empty = AppLogSnapshot(
        entries: [],
        counts: [:],
        categoryCounts: [:],
        droppedCount: 0,
        coalescedCount: 0,
        revision: 0
    )

    func count(for level: LogEntry.LogLevel) -> Int {
        counts[level, default: 0]
    }

    func count(for category: LogEntry.Category) -> Int {
        categoryCounts[category, default: 0]
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
    typealias Category = LogEntry.Category

    private struct ExportArchive: Codable {
        let version: Int
        let generatedAt: Date
        let sessionID: String
        let droppedCount: Int
        let coalescedCount: Int
        let entries: [LogEntry]
    }

    private static let maxLogs = 2_500
    private static let maxPersistedLogs = 800
    private static let maximumMessageLength = 12_000
    private static let duplicateWindow: TimeInterval = 2.5
    private static let launchSessionID = String(UUID().uuidString.prefix(8)).uppercased()
    private static let stateLock = NSLock()
    private static let persistenceQueue = DispatchQueue(
        label: "com.mono.runtime-log-persistence",
        qos: .utility
    )
    private static let persistenceURL = diagnosticStorageURL("runtime-logs-v2.json")
    private static let silenceIncidentURL = diagnosticStorageURL("audio-silence-latest-v1.json")
    private nonisolated(unsafe) static var logs: [LogEntry] = loadPersistedEntries()
    private nonisolated(unsafe) static var droppedCount = 0
    private nonisolated(unsafe) static var coalescedCount = 0
    private nonisolated(unsafe) static var revision: UInt64 = 0
    private nonisolated(unsafe) static var changeNotificationPending = false
    private nonisolated(unsafe) static var persistenceScheduled = false
    private nonisolated(unsafe) static var collectionEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "log_collection_enabled") == nil {
            return true
        }
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
        let currentCoalescedCount = coalescedCount
        let currentRevision = revision
        stateLock.unlock()

        var counts: [LogEntry.LogLevel: Int] = [:]
        var categoryCounts: [LogEntry.Category: Int] = [:]
        counts.reserveCapacity(LogEntry.LogLevel.allCases.count)
        categoryCounts.reserveCapacity(LogEntry.Category.allCases.count)
        for entry in entries {
            counts[entry.level, default: 0] += 1
            categoryCounts[entry.category, default: 0] += 1
        }
        return AppLogSnapshot(
            entries: entries,
            counts: counts,
            categoryCounts: categoryCounts,
            droppedCount: currentDroppedCount,
            coalescedCount: currentCoalescedCount,
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
        coalescedCount = 0
        revision &+= 1
        stateLock.unlock()
        clearPersistedLogs()
        scheduleChangeNotification()
    }

    static func textExport(entries: [LogEntry]) -> String {
        entries.map(\.exportText).joined(separator: "\n")
    }

    static func jsonExport(entries: [LogEntry]) -> String? {
        let snapshot = snapshot()
        let archive = ExportArchive(
            version: 2,
            generatedAt: Date(),
            sessionID: launchSessionID,
            droppedCount: snapshot.droppedCount,
            coalescedCount: snapshot.coalescedCount,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(archive) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func silenceDiagnosticsJSON() -> String? {
        persistenceQueue.sync {
            guard let data = try? Data(contentsOf: silenceIncidentURL) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }

    static var hasSilenceDiagnostics: Bool {
        persistenceQueue.sync {
            FileManager.default.fileExists(atPath: silenceIncidentURL.path)
        }
    }

    static func info(
        _ message: @autoclosure () -> String,
        step: String = "",
        category: Category? = nil,
        event: String = "",
        context: [String: String] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(
            .info,
            message: message,
            step: step,
            category: category,
            event: event,
            context: context,
            file: file,
            line: line,
            function: function
        )
    }

    static func debug(
        _ message: @autoclosure () -> String,
        step: String = "",
        category: Category? = nil,
        event: String = "",
        context: [String: String] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(
            .debug,
            message: message,
            step: step,
            category: category,
            event: event,
            context: context,
            file: file,
            line: line,
            function: function
        )
    }

    static func warning(
        _ message: @autoclosure () -> String,
        step: String = "",
        category: Category? = nil,
        event: String = "",
        context: [String: String] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(
            .warning,
            message: message,
            step: step,
            category: category,
            event: event,
            context: context,
            file: file,
            line: line,
            function: function
        )
    }

    static func error(
        _ message: @autoclosure () -> String,
        step: String = "",
        category: Category? = nil,
        event: String = "",
        context: [String: String] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(
            .error,
            message: message,
            step: step,
            category: category,
            event: event,
            context: context,
            file: file,
            line: line,
            function: function
        )
    }

    static func network(
        _ message: @autoclosure () -> String,
        step: String = "",
        category: Category? = nil,
        event: String = "",
        context: [String: String] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(
            .network,
            message: message,
            step: step,
            category: category ?? .network,
            event: event,
            context: context,
            file: file,
            line: line,
            function: function
        )
    }

    static func success(
        _ message: @autoclosure () -> String,
        step: String = "",
        category: Category? = nil,
        event: String = "",
        context: [String: String] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        record(
            .success,
            message: message,
            step: step,
            category: category,
            event: event,
            context: context,
            file: file,
            line: line,
            function: function
        )
    }

    static func failure(
        _ error: Error,
        message: String = "",
        step: String = "",
        category: Category? = nil,
        event: String = "",
        context: [String: String] = [:],
        file: String = #file,
        line: Int = #line,
        function: String = #function
    ) {
        let prefix = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = error.localizedDescription
        record(
            .error,
            message: { prefix.isEmpty ? detail : "\(prefix): \(detail)" },
            step: step,
            category: category,
            event: event,
            context: context,
            file: file,
            line: line,
            function: function
        )
    }

    private static func record(
        _ level: LogEntry.LogLevel,
        message: () -> String,
        step: String,
        category: Category?,
        event: String,
        context: [String: String],
        file: String,
        line: Int,
        function: String
    ) {
        guard isCollectionEnabled else { return }
        let rawValue = message()
        let value = sanitizedMessage(rawValue)
        let sourcePath = normalizedSourcePath(file)
        let resolvedCategory = category ?? inferredCategory(
            file: sourcePath,
            message: value,
            level: level
        )
        let resolvedEvent = normalizedEvent(
            explicitEvent: event,
            step: step,
            message: value,
            function: function
        )
        let safeContext = sanitizedContext(context)

        #if DEBUG
        let source = (sourcePath as NSString).lastPathComponent
        let eventLabel = resolvedEvent.isEmpty ? "" : " [\(resolvedEvent)]"
        Swift.print(
            "\(level.rawValue) [\(resolvedCategory.rawValue)] "
                + "[\(source):\(line)]\(eventLabel) \(value)"
        )
        #endif

        addLog(
            LogEntry(
                timestamp: Date(),
                level: level,
                category: resolvedCategory,
                event: resolvedEvent,
                message: value,
                file: sourcePath,
                line: line,
                function: function,
                thread: currentThreadName,
                step: step,
                sessionID: launchSessionID,
                context: safeContext
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
        if let previous = logs.last,
           previous.duplicateSignature == entry.duplicateSignature,
           entry.timestamp.timeIntervalSince(previous.timestamp) <= duplicateWindow
        {
            logs[logs.count - 1] = previous.coalescing(with: entry)
            coalescedCount += 1
        } else {
            logs.append(entry)
        }
        if logs.count > maxLogs {
            let overflow = logs.count - maxLogs
            logs.removeFirst(overflow)
            droppedCount += overflow
        }
        revision &+= 1
        stateLock.unlock()

        let isSilenceIncident = entry.event.hasPrefix("audio.silence.")
        if isSilenceIncident {
            persistCurrentLogsSynchronously(includeSilenceIncident: true)
        } else {
            schedulePersistence()
        }
        scheduleChangeNotification()
    }

    private static func schedulePersistence() {
        stateLock.lock()
        guard !persistenceScheduled else {
            stateLock.unlock()
            return
        }
        persistenceScheduled = true
        stateLock.unlock()

        persistenceQueue.asyncAfter(deadline: .now() + 0.75) {
            drainPersistenceQueue()
        }
    }

    private static func drainPersistenceQueue() {
        let captured = persistenceSnapshot()
        write(captured, to: persistenceURL)

        stateLock.lock()
        persistenceScheduled = false
        let changedDuringWrite = revision != captured.revision
        stateLock.unlock()
        if changedDuringWrite {
            schedulePersistence()
        }
    }

    private static func persistCurrentLogsSynchronously(includeSilenceIncident: Bool) {
        let captured = persistenceSnapshot()
        persistenceQueue.sync {
            write(captured, to: persistenceURL)
            if includeSilenceIncident {
                write(captured, to: silenceIncidentURL)
            }
        }
    }

    private static func persistenceSnapshot() -> AppLogSnapshot {
        let current = snapshot()
        guard current.entries.count > maxPersistedLogs else { return current }
        return AppLogSnapshot(
            entries: Array(current.entries.suffix(maxPersistedLogs)),
            counts: current.counts,
            categoryCounts: current.categoryCounts,
            droppedCount: current.droppedCount,
            coalescedCount: current.coalescedCount,
            revision: current.revision
        )
    }

    private static func write(_ snapshot: AppLogSnapshot, to url: URL) {
        let archive = ExportArchive(
            version: 2,
            generatedAt: Date(),
            sessionID: launchSessionID,
            droppedCount: snapshot.droppedCount,
            coalescedCount: snapshot.coalescedCount,
            entries: snapshot.entries
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(archive) else { return }
        try? data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUnlessOpen]
        )
    }

    private static func loadPersistedEntries() -> [LogEntry] {
        guard let data = try? Data(contentsOf: persistenceURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let archive = try? decoder.decode(ExportArchive.self, from: data) else { return [] }
        return Array(archive.entries.sorted { $0.timestamp < $1.timestamp }.suffix(maxPersistedLogs))
    }

    private static func clearPersistedLogs() {
        persistenceQueue.sync {
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: persistenceURL)
            try? fileManager.removeItem(at: silenceIncidentURL)
        }
    }

    private static func diagnosticStorageURL(_ fileName: String) -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = baseURL
            .appendingPathComponent("Mono", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func normalizedSourcePath(_ file: String) -> String {
        let separators = [
            "/Sources/",
            "/ffmpeg-swift/",
            "/music/",
            "/Server/",
            "/Tests/"
        ]
        for separator in separators {
            guard let range = file.range(of: separator) else { continue }
            let suffix = file[range.lowerBound...].dropFirst()
            return String(suffix)
        }
        return (file as NSString).lastPathComponent
    }

    private static func normalizedEvent(
        explicitEvent: String,
        step: String,
        message: String,
        function: String
    ) -> String {
        let candidates = [explicitEvent, step, leadingTag(in: message), baseFunctionName(function)]
        for candidate in candidates {
            let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return String(value.prefix(80))
            }
        }
        return ""
    }

    private static func leadingTag(in message: String) -> String {
        guard message.hasPrefix("["),
              let closingIndex = message.firstIndex(of: "]")
        else {
            return ""
        }
        let value = message[message.index(after: message.startIndex)..<closingIndex]
        return String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func baseFunctionName(_ function: String) -> String {
        let value = function.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parameterStart = value.firstIndex(of: "(") else { return value }
        return String(value[..<parameterStart])
    }

    /// 根据调用文件、消息前缀与日志级别推断诊断分类；匹配顺序体现更具体类别的优先级。
    private static func inferredCategory(
        file: String,
        message: String,
        level: LogEntry.LogLevel
    ) -> Category {
        let source = file.lowercased()
        let content = message.lowercased()

        if source.contains("applemusic") || content.contains("apple music") || content.contains("[applemusic]") {
            return .appleMusic
        }
        if source.contains("lyrics") || source.contains("lyric") || content.contains("歌词") {
            return .lyrics
        }
        if source.contains("audiotrainingadmin")
            || content.contains("[modeltraining]")
            || content.contains("model-training.")
        {
            return .modelTraining
        }
        if source.contains("audiotrainingondevicemodel")
            || content.contains("[localmodel]")
            || content.contains("local-model.")
        {
            return .localModel
        }
        if source.contains("aiequalizer")
            || source.contains("aiprovider")
            || source.contains("monoagent")
            || content.contains("[aiequalizer")
            || content.contains("mono audio agent")
        {
            return .ai
        }
        if source.contains("ffmpeg")
            || source.contains("audiosession")
            || source.contains("audiofilter")
            || source.contains("eqmanager")
            || content.contains("[ffmpeg")
        {
            return .audio
        }
        if source.contains("monoplaybackengine")
            || source.contains("/playback/")
            || source.contains("gapless")
            || source.contains("mediasourceresolver")
            || content.contains("[gapless]")
        {
            return .playback
        }
        if source.contains("monosession") || content.contains("[monosession") || content.contains("一起听") {
            return .session
        }
        if source.contains("cloud")
            || source.contains("sync")
            || source.contains("serverline")
            || content.contains("[cloud")
        {
            return .cloud
        }
        if source.contains("database")
            || source.contains("repository")
            || source.contains("cache")
            || content.contains("core data")
            || content.contains("swiftdata")
        {
            return .database
        }
        if source.contains("download")
            || source.contains("localmusic")
            || content.contains("[download")
            || content.contains("下载")
        {
            return .download
        }
        if level == .network
            || source.contains("/network/")
            || source.contains("api")
            || source.contains("service")
            || content.contains("http")
            || content.contains("请求")
        {
            return .network
        }
        if source.contains("/views/")
            || source.contains("/viewmodels/")
            || source.contains("/themes/")
        {
            return .interface
        }
        if source.contains("monoapp") || source.contains("settings") || source.contains("manager") {
            return .app
        }
        return .other
    }

    private static func sanitizedContext(_ context: [String: String]) -> [String: String] {
        guard !context.isEmpty else { return [:] }
        var result: [String: String] = [:]
        result.reserveCapacity(context.count)
        for (key, value) in context {
            let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedKey.isEmpty else { continue }
            if isSensitiveKey(normalizedKey) {
                result[normalizedKey] = "<redacted>"
            } else {
                result[normalizedKey] = sanitizedMessage(value)
            }
        }
        return result
    }

    private static func sanitizedMessage(_ message: String) -> String {
        var result = message
            .replacingOccurrences(of: "\0", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")

        let lowercased = result.lowercased()
        if sensitiveMarkers.contains(where: lowercased.contains) {
            for rule in redactionRules {
                result = result.replacingOccurrences(
                    of: rule.pattern,
                    with: rule.replacement,
                    options: .regularExpression
                )
            }
        }

        if result.count > maximumMessageLength {
            result = String(result.prefix(maximumMessageLength)) + "… <truncated>"
        }
        return result
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let value = key.lowercased()
        return sensitiveMarkers.contains(where: value.contains)
    }

    private static let sensitiveMarkers = [
        "authorization",
        "bearer",
        "api_key",
        "apikey",
        "api-key",
        "token",
        "cookie",
        "password",
        "passwd",
        "secret",
        "music_u",
        "csrf"
    ]

    private static let redactionRules: [(pattern: String, replacement: String)] = [
        (
            #"(?i)(authorization\s*[:：=]\s*(?:bearer\s+)?)[^\s,;\]\}]+"#,
            "$1<redacted>"
        ),
        (
            #"(?i)((?:api[_-]?key|token|cookie|password|passwd|secret|music_u|csrf)\s*[:：=]\s*)[^\s,;\]\}]+"#,
            "$1<redacted>"
        ),
        (
            #"(?i)([?&](?:api[_-]?key|token|access_token|cookie|password|secret|music_u|csrf)=)[^&\s]+"#,
            "$1<redacted>"
        ),
        (
            #"(?i)(device\s+token[^:：=]*[:：=]\s*)[a-f0-9_-]{8,}"#,
            "$1<redacted>"
        )
    ]

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

/// 兼容直接 `print` 的旧调用点：保留控制台输出，同时纳入统一诊断、分类与脱敏。
func print(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n",
    file: String = #file,
    line: Int = #line,
    function: String = #function
) {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    let normalized = message.lowercased()
    if message.contains("❌") || normalized.contains("失败") || normalized.contains("error") {
        AppLogger.error(message, file: file, line: line, function: function)
    } else if message.contains("⚠️") || normalized.contains("warning") || normalized.contains("警告") {
        AppLogger.warning(message, file: file, line: line, function: function)
    } else if message.contains("✅") || normalized.contains("成功") {
        AppLogger.success(message, file: file, line: line, function: function)
    } else {
        AppLogger.debug(message, file: file, line: line, function: function)
    }
}
