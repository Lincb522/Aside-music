import Foundation

public struct FFmpegDiagnosticEvent: Sendable {
    public enum Level: String, Sendable {
        case debug
        case info
        case warning
        case error
        case success
    }

    public let level: Level
    public let message: String
    public let file: String
    public let line: Int
    public let function: String

    public init(
        level: Level,
        message: String,
        file: String,
        line: Int,
        function: String
    ) {
        self.level = level
        self.message = message
        self.file = file
        self.line = line
        self.function = function
    }
}

public enum FFmpegDiagnosticLog {
    public typealias Handler = @Sendable (FFmpegDiagnosticEvent) -> Void

    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: Handler?

    public static func setHandler(_ handler: Handler?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    @discardableResult
    fileprivate static func emit(_ event: FFmpegDiagnosticEvent) -> Bool {
        lock.lock()
        let currentHandler = handler
        lock.unlock()
        currentHandler?(event)
        return currentHandler != nil
    }
}

// 将 SDK 中现有的控制台诊断统一桥接给宿主 App，同时保留 Xcode 控制台输出。
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
    let level: FFmpegDiagnosticEvent.Level
    if message.contains("❌") || normalized.contains(" failed") || normalized.contains("error") {
        level = .error
    } else if message.contains("⚠️")
        || normalized.contains("warning")
        || normalized.contains("rejected")
        || normalized.contains("unavailable")
    {
        level = .warning
    } else if message.contains("✅") || normalized.contains("success") {
        level = .success
    } else {
        level = .debug
    }

    let wasHandled = FFmpegDiagnosticLog.emit(
        FFmpegDiagnosticEvent(
            level: level,
            message: message,
            file: file,
            line: line,
            function: function
        )
    )
    if !wasHandled {
        Swift.print(message, terminator: terminator)
    }
}
