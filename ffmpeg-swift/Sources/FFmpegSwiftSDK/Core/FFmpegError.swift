// FFmpegError.swift
// FFmpegSwiftSDK
//
// Unified error type for FFmpeg operations, mapping FFmpeg C error codes
// to Swift-friendly enum cases with human-readable descriptions.

import Foundation

/// FFmpeg error codes as known Int32 constants.
/// These mirror the AVERROR macros from libavutil/error.h.
/// AVERROR codes are typically negative POSIX error codes or FFmpeg-specific tags.
internal enum FFmpegErrorCode {
    // POSIX-based AVERROR codes: AVERROR(e) = -e on most platforms
    static let AVERROR_ECONNREFUSED: Int32 = -111   // AVERROR(ECONNREFUSED)
    static let AVERROR_ETIMEDOUT: Int32    = -110    // AVERROR(ETIMEDOUT)
    static let AVERROR_ENOMEM: Int32       = -12     // AVERROR(ENOMEM)
    static let AVERROR_EIO: Int32          = -5      // AVERROR(EIO)
    static let AVERROR_ECONNRESET: Int32   = -104    // AVERROR(ECONNRESET)
    static let AVERROR_EPIPE: Int32        = -32     // AVERROR(EPIPE)
    static let AVERROR_ENOENT: Int32       = -2      // AVERROR(ENOENT)

    // FFmpeg-specific AVERROR tag codes (computed as FFERRTAG)
    // AVERROR_INVALIDDATA = FFERRTAG('I','N','D','A')
    static let AVERROR_INVALIDDATA: Int32  = -1094995529
    // AVERROR_EOF = FFERRTAG('E','O','F',' ')
    static let AVERROR_EOF: Int32          = -541478725
    // AVERROR_DEMUXER_NOT_FOUND = FFERRTAG(0xF8,'D','E','M')
    static let AVERROR_DEMUXER_NOT_FOUND: Int32 = -1296385272
    // AVERROR_DECODER_NOT_FOUND = FFERRTAG(0xF8,'D','E','C')
    static let AVERROR_DECODER_NOT_FOUND: Int32 = -1128613112
    // AVERROR_PROTOCOL_NOT_FOUND = FFERRTAG(0xF8,'P','R','O')
    static let AVERROR_PROTOCOL_NOT_FOUND: Int32 = -1330794744
    // AVERROR_STREAM_NOT_FOUND = FFERRTAG(0xF8,'S','T','R')
    static let AVERROR_STREAM_NOT_FOUND: Int32 = -1381258232
}

/// Unified error type representing errors from FFmpeg operations.
///
/// Each case captures relevant context (error codes, messages, resource names)
/// to aid in debugging and user-facing error reporting.
///
/// Use `FFmpegError.from(code:)` to convert raw FFmpeg negative error codes
/// into the appropriate enum case.
public enum FFmpegError: Error, CustomStringConvertible, Equatable {

    /// Connection to the media source failed.
    /// - Parameters:
    ///   - code: The original FFmpeg error code.
    ///   - message: A human-readable description of the failure.
    case connectionFailed(code: Int32, message: String)

    /// The connection attempt timed out.
    case connectionTimeout

    /// The media format or codec is not supported.
    /// - Parameter codecName: The name or identifier of the unsupported codec/format.
    case unsupportedFormat(codecName: String)

    /// Decoding of audio or video data failed.
    /// - Parameters:
    ///   - code: The original FFmpeg error code.
    ///   - message: A human-readable description of the failure.
    case decodingFailed(code: Int32, message: String)

    /// A required resource could not be allocated (e.g., memory, codec context).
    /// - Parameter resource: A description of the resource that failed to allocate.
    case resourceAllocationFailed(resource: String)

    /// The network connection was lost during an active session.
    case networkDisconnected

    /// An unknown or unmapped FFmpeg error occurred.
    /// - Parameter code: The original FFmpeg error code.
    case unknown(code: Int32)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .connectionFailed(let code, let message):
            return "Connection failed (code: \(code)): \(message)"
        case .connectionTimeout:
            return "Connection timed out (code: \(FFmpegErrorCode.AVERROR_ETIMEDOUT))"
        case .unsupportedFormat(let codecName):
            return "Unsupported format: \(codecName)"
        case .decodingFailed(let code, let message):
            return "Decoding failed (code: \(code)): \(message)"
        case .resourceAllocationFailed(let resource):
            return "Resource allocation failed: \(resource)"
        case .networkDisconnected:
            return "Network disconnected"
        case .unknown(let code):
            return "Unknown FFmpeg error (code: \(code))"
        }
    }

    // MARK: - FFmpeg Error Code

    /// The original FFmpeg error code associated with this error.
    public var ffmpegCode: Int32 {
        switch self {
        case .connectionFailed(let code, _):
            return code
        case .connectionTimeout:
            return FFmpegErrorCode.AVERROR_ETIMEDOUT
        case .unsupportedFormat:
            return FFmpegErrorCode.AVERROR_DECODER_NOT_FOUND
        case .decodingFailed(let code, _):
            return code
        case .resourceAllocationFailed:
            return FFmpegErrorCode.AVERROR_ENOMEM
        case .networkDisconnected:
            return FFmpegErrorCode.AVERROR_ECONNRESET
        case .unknown(let code):
            return code
        }
    }

    // MARK: - Error Classification

    /// Whether this error is unrecoverable and should trigger an automatic stop.
    ///
    /// Unrecoverable errors include connection failures, timeouts, resource
    /// allocation failures, network disconnections, and unsupported formats.
    /// Recoverable errors (e.g., individual frame decoding failures) return `false`.
    public var isUnrecoverable: Bool {
        switch self {
        case .connectionFailed, .connectionTimeout, .resourceAllocationFailed,
             .networkDisconnected, .unsupportedFormat:
            return true
        case .decodingFailed:
            return false
        case .unknown:
            // Unknown errors are treated as unrecoverable to be safe
            return true
        }
    }

    // MARK: - Factory Method

    /// Maps a raw FFmpeg negative error code to the appropriate `FFmpegError` case.
    ///
    /// Known FFmpeg error codes are mapped to specific cases with descriptive messages.
    /// Unrecognized codes are mapped to `.unknown(code:)`.
    ///
    /// - Parameter code: A negative Int32 error code returned by an FFmpeg C function.
    /// - Returns: An `FFmpegError` instance representing the error.
    public static func from(code: Int32) -> FFmpegError {
        switch code {
        // Connection refused
        case FFmpegErrorCode.AVERROR_ECONNREFUSED:
            return .connectionFailed(code: code, message: "Connection refused by remote host")

        // Protocol not found
        case FFmpegErrorCode.AVERROR_PROTOCOL_NOT_FOUND:
            return .connectionFailed(code: code, message: "Protocol not found")

        // No such file or directory (often invalid URL)
        case FFmpegErrorCode.AVERROR_ENOENT:
            return .connectionFailed(code: code, message: "No such file or URL")

        // Connection timeout
        case FFmpegErrorCode.AVERROR_ETIMEDOUT:
            return .connectionTimeout

        // Invalid data / unsupported format
        case FFmpegErrorCode.AVERROR_INVALIDDATA:
            return .unsupportedFormat(codecName: "unknown (invalid data)")

        // Decoder not found
        case FFmpegErrorCode.AVERROR_DECODER_NOT_FOUND:
            return .unsupportedFormat(codecName: "unknown (decoder not found)")

        // Demuxer not found
        case FFmpegErrorCode.AVERROR_DEMUXER_NOT_FOUND:
            return .unsupportedFormat(codecName: "unknown (demuxer not found)")

        // Stream not found
        case FFmpegErrorCode.AVERROR_STREAM_NOT_FOUND:
            return .unsupportedFormat(codecName: "unknown (stream not found)")

        // I/O error (decoding failure)
        case FFmpegErrorCode.AVERROR_EIO:
            return .decodingFailed(code: code, message: "I/O error during decoding")

        // End of file
        case FFmpegErrorCode.AVERROR_EOF:
            return .decodingFailed(code: code, message: "End of file reached")

        // Out of memory
        case FFmpegErrorCode.AVERROR_ENOMEM:
            return .resourceAllocationFailed(resource: "memory")

        // Connection reset (network disconnected)
        case FFmpegErrorCode.AVERROR_ECONNRESET:
            return .networkDisconnected

        // Broken pipe (network disconnected)
        case FFmpegErrorCode.AVERROR_EPIPE:
            return .networkDisconnected

        // Unknown / unmapped error code
        default:
            return .unknown(code: code)
        }
    }
}
