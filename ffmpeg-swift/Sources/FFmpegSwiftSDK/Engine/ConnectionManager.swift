// ConnectionManager.swift
// FFmpegSwiftSDK
//
// Manages streaming media connections with support for RTMP, HLS, and RTSP protocols.
// Provides async connect/disconnect with a 10-second timeout mechanism and
// delegate-based state change notifications.

import Foundation
import CFFmpeg

// MARK: - ConnectionState

/// Represents the current state of a streaming connection.
enum ConnectionState: Equatable {
    /// No connection attempt has been made.
    case idle
    /// A connection attempt is in progress.
    case connecting
    /// Successfully connected and ready for streaming.
    case connected
    /// The connection has been explicitly closed.
    case disconnected
    /// The connection failed with the given error.
    case failed(FFmpegError)
}

// MARK: - ConnectionManagerDelegate

/// Delegate protocol for receiving connection state changes and errors.
protocol ConnectionManagerDelegate: AnyObject {
    /// Called when the connection state changes.
    func connectionManager(_ manager: ConnectionManager, didChangeState state: ConnectionState)
    /// Called when a connection error occurs.
    func connectionManager(_ manager: ConnectionManager, didFailWith error: FFmpegError)
}

// MARK: - ConnectionManager

/// Manages the lifecycle of a streaming media connection.
///
/// `ConnectionManager` handles establishing connections to media sources via
/// RTMP, HLS, and RTSP protocols. It enforces a 10-second timeout on connection
/// attempts and provides delegate-based notifications for state changes.
///
/// Usage:
/// ```swift
/// let manager = ConnectionManager()
/// manager.delegate = self
/// let context = try await manager.connect(url: "rtmp://example.com/live/stream")
/// // ... use context for demuxing ...
/// manager.disconnect()
/// ```
///
/// - Important: This is an internal type used by the engine layer.
///   It is not exposed as public API.
final class ConnectionManager {

    // MARK: - Properties

    /// The timeout interval for connection attempts, in seconds.
    let timeoutInterval: TimeInterval = 10.0

    /// Serial queue for synchronizing connection state changes.
    private let workQueue = DispatchQueue(label: "com.ffmpeg-sdk.connection")

    /// The current connection state.
    private(set) var state: ConnectionState = .idle {
        didSet {
            if oldValue != state {
                delegate?.connectionManager(self, didChangeState: state)
            }
        }
    }

    /// Delegate for receiving state change and error notifications.
    weak var delegate: ConnectionManagerDelegate?

    /// The format context for the current connection, if any.
    private var formatContext: FFmpegFormatContext?

    /// Optional decryption key for CENC-encrypted media (e.g. 汽水音乐).
    var decryptionKey: String?

    // MARK: - Protocol Detection

    /// Supported streaming protocol schemes.
    private enum StreamProtocol: String {
        case rtmp
        case rtmps
        case hls  // detected via URL extension or content
        case rtsp
        case rtsps
        case http
        case https
        case file
    }

    /// Determines the streaming protocol from a URL string.
    ///
    /// - Parameter url: The URL to analyze.
    /// - Returns: The detected protocol, or `nil` if unrecognized.
    private func detectProtocol(from url: String) -> StreamProtocol? {
        let lowered = url.lowercased()
        if lowered.hasPrefix("rtmp://") { return .rtmp }
        if lowered.hasPrefix("rtmps://") { return .rtmps }
        if lowered.hasPrefix("rtsp://") { return .rtsp }
        if lowered.hasPrefix("rtsps://") { return .rtsps }
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            // HLS streams are typically served over HTTP(S) with .m3u8 extension
            if lowered.contains(".m3u8") {
                return .hls
            }
            return lowered.hasPrefix("https://") ? .https : .http
        }
        if lowered.hasPrefix("file://") || lowered.hasPrefix("/") { return .file }
        return nil
    }

    // MARK: - Timeout Options

    /// Builds an `AVDictionary` with appropriate timeout options for the given URL.
    ///
    /// - RTSP uses `stimeout` (in microseconds).
    /// - Other network protocols use `timeout` (in microseconds).
    /// - File URLs do not need timeout options.
    ///
    /// - Parameters:
    ///   - url: The media URL.
    ///   - timeoutMicroseconds: The timeout value in microseconds.
    /// - Returns: An `OpaquePointer?` to the allocated `AVDictionary`, or `nil`.
    ///   The caller must free this dictionary with `av_dict_free`.
    private func buildTimeoutOptions(for url: String, timeoutMicroseconds: Int64) -> OpaquePointer? {
        var opts: OpaquePointer? = nil
        let proto = detectProtocol(from: url)
        let timeoutStr = String(timeoutMicroseconds)

        switch proto {
        case .rtsp, .rtsps:
            // RTSP uses `stimeout` for socket timeout (microseconds)
            av_dict_set(&opts, "stimeout", timeoutStr, 0)
        case .rtmp, .rtmps:
            // RTMP uses `timeout` (in seconds for some implementations)
            // but we use the generic `timeout` in microseconds for avformat
            av_dict_set(&opts, "timeout", timeoutStr, 0)
        case .hls, .http, .https:
            // HTTP-based protocols use `timeout` in microseconds
            av_dict_set(&opts, "timeout", timeoutStr, 0)
            // 设置 User-Agent，避免 CDN 拒绝连接或提前断开
            av_dict_set(&opts, "user_agent", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", 0)
            // 根据域名设置对应的 Referer（不同 CDN 会校验来源）
            let loweredURL = url.lowercased()
            if loweredURL.contains("qqmusic") || loweredURL.contains("gtimg.cn") || loweredURL.contains("qq.com") {
                av_dict_set(&opts, "referer", "https://y.qq.com/", 0)
            } else {
                av_dict_set(&opts, "referer", "https://music.163.com/", 0)
            }
            // HTTP 重连策略（CDN 常见 302 跳转、TCP RST、token 过期等场景）
            av_dict_set(&opts, "reconnect", "1", 0)
            av_dict_set(&opts, "reconnect_streamed", "1", 0)
            av_dict_set(&opts, "reconnect_delay_max", "5", 0)
            av_dict_set(&opts, "reconnect_on_network_error", "1", 0)
            av_dict_set(&opts, "reconnect_on_http_error", "4xx,5xx", 0)
            // HTTP Range 请求支持：断流后可从上次字节偏移继续请求
            av_dict_set(&opts, "multiple_requests", "1", 0)
            av_dict_set(&opts, "seekable", "1", 0)
            // 增大 I/O 缓冲区到 512KB（默认 32KB 太小，CDN 断流时容易被打空）
            av_dict_set(&opts, "buffer_size", "524288", 0)
        case .file, .none:
            // No timeout needed for local files; for unknown protocols, set a generic timeout
            if proto == nil {
                av_dict_set(&opts, "timeout", timeoutStr, 0)
            }
        }

        // I/O-level read/write timeout: 30 秒，给 HTTP 重连留足时间
        if proto != .file {
            let rwTimeoutStr = String(30_000_000)
            av_dict_set(&opts, "rw_timeout", rwTimeoutStr, 0)
        }

        return opts
    }

    // MARK: - Connect

    /// Establishes a connection to the media source at the given URL.
    ///
    /// Supports RTMP, HLS, RTSP, and other protocols recognized by FFmpeg.
    /// The connection attempt is subject to a 10-second timeout. On success,
    /// returns an `FFmpegFormatContext` ready for demuxing.
    ///
    /// - Parameter url: The URL of the media source.
    /// - Returns: An `FFmpegFormatContext` with the input opened and stream info populated.
    /// - Throws:
    ///   - `FFmpegError.connectionTimeout` if the connection exceeds 10 seconds.
    ///   - `FFmpegError.connectionFailed` if the URL is invalid or the server is unreachable.
    ///   - Other `FFmpegError` variants for resource allocation or format issues.
    func connect(url: String) async throws -> FFmpegFormatContext {
        // Transition to connecting state
        workQueue.sync { self.state = .connecting }

        do {
            let context = try await performConnect(url: url)
            workQueue.sync { self.state = .connected }
            return context
        } catch {
            let ffError: FFmpegError
            if let fe = error as? FFmpegError {
                ffError = fe
            } else {
                ffError = .connectionFailed(code: -1, message: error.localizedDescription)
            }
            workQueue.sync {
                self.state = .failed(ffError)
            }
            delegate?.connectionManager(self, didFailWith: ffError)
            throw ffError
        }
    }

    /// Performs the actual connection work with timeout enforcement.
    ///
    /// Uses `Task` with a timeout to enforce the 10-second limit. The FFmpeg
    /// `avformat_open_input` and `avformat_find_stream_info` calls are executed
    /// on the work queue.
    ///
    /// - Parameter url: The media URL.
    /// - Returns: An `FFmpegFormatContext` on success.
    /// - Throws: `FFmpegError` on failure or timeout.
    private func performConnect(url: String) async throws -> FFmpegFormatContext {
        let timeoutNanoseconds = UInt64(timeoutInterval * 1_000_000_000)
        let timeoutMicroseconds = Int64(timeoutInterval * 1_000_000)

        return try await withThrowingTaskGroup(of: FFmpegFormatContext.self) { group in
            // Connection task
            group.addTask { [weak self] in
                guard let self = self else {
                    throw FFmpegError.resourceAllocationFailed(resource: "ConnectionManager deallocated")
                }
                return try self.openConnection(url: url, timeoutMicroseconds: timeoutMicroseconds)
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw FFmpegError.connectionTimeout
            }

            // Return whichever finishes first
            let result = try await group.next()!
            group.cancelAll()

            // Store the format context for later disconnect
            self.formatContext = result
            return result
        }
    }

    /// Opens the FFmpeg connection synchronously.
    ///
    /// 1. Allocates an `FFmpegFormatContext`.
    /// 2. Builds timeout options appropriate for the detected protocol.
    /// 3. Calls `openInput(url:options:)` to connect.
    /// 4. Calls `findStreamInfo()` to populate stream metadata.
    ///
    /// - Parameters:
    ///   - url: The media URL.
    ///   - timeoutMicroseconds: Timeout value in microseconds for FFmpeg options.
    /// - Returns: An `FFmpegFormatContext` on success.
    /// - Throws: `FFmpegError` on failure.
    private func openConnection(url: String, timeoutMicroseconds: Int64) throws -> FFmpegFormatContext {
        // Check for task cancellation before starting
        try Task.checkCancellation()

        // Allocate format context
        let context = try FFmpegFormatContext()

        // Build timeout options
        var opts = buildTimeoutOptions(for: url, timeoutMicroseconds: timeoutMicroseconds)
        defer {
            if opts != nil {
                av_dict_free(&opts)
            }
        }

        if let key = decryptionKey, !key.isEmpty {
            av_dict_set(&opts, "decryption_key", key, 0)
        }

        // Open input with options
        try context.openInput(url: url, options: &opts)

        // Check for cancellation after open
        try Task.checkCancellation()

        // Find stream info
        try context.findStreamInfo()

        return context
    }

    // MARK: - Disconnect

    /// Disconnects from the current media source and releases all resources.
    ///
    /// After calling this method, the `ConnectionManager` returns to the `idle` state
    /// (via `disconnected`) and the previously returned `FFmpegFormatContext` is invalidated.
    ///
    /// Safe to call multiple times or when not connected.
    func disconnect() {
        workQueue.sync {
            // Release the format context (deinit will call avformat_close_input)
            self.formatContext = nil
            if case .idle = self.state {
                // Already idle, no state change needed
            } else {
                self.state = .disconnected
            }
        }
    }
}
