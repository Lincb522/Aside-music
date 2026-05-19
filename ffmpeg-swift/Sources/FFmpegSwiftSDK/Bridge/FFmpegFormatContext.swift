// FFmpegFormatContext.swift
// FFmpegSwiftSDK
//
// Swift wrapper around AVFormatContext that manages allocation, opening,
// stream info discovery, and guaranteed cleanup via deinit.
// Hides raw C pointer operations behind a safe Swift interface.

import Foundation
import CFFmpeg

/// Wraps an FFmpeg `AVFormatContext`, providing safe allocation, input opening,
/// stream information discovery, and automatic resource cleanup.
///
/// On `deinit`, any opened input is closed via `avformat_close_input`,
/// ensuring no resource leaks even if the caller forgets to close explicitly.
///
/// - Important: This is an internal type used by the engine layer.
///   It is not exposed as public API.
final class FFmpegFormatContext {

    // MARK: - Properties

    /// The underlying C pointer to AVFormatContext.
    /// `nil` after deallocation or if allocation failed.
    private var pointer: UnsafeMutablePointer<AVFormatContext>?

    /// Whether `avformat_open_input` has been successfully called.
    /// Used to determine the correct cleanup path in `deinit`.
    private var isInputOpened: Bool = false

    /// Provides read-only access to the underlying pointer for engine-layer consumers.
    /// Returns `nil` if the context has been freed or was never allocated.
    var rawPointer: UnsafeMutablePointer<AVFormatContext>? {
        return pointer
    }

    /// The number of streams found in the opened input.
    /// Returns 0 if no input is opened or `findStreamInfo` has not been called.
    var streamCount: Int {
        guard let ctx = pointer else { return 0 }
        return Int(ctx.pointee.nb_streams)
    }

    // MARK: - Initialization

    /// Allocates a new `AVFormatContext` using `avformat_alloc_context()`.
    ///
    /// - Throws: `FFmpegError.resourceAllocationFailed` if allocation fails.
    init() throws {
        pointer = avformat_alloc_context()
        guard pointer != nil else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFormatContext")
        }
    }

    /// Creates a wrapper around an existing `AVFormatContext` pointer.
    /// The wrapper takes ownership and will free the context on `deinit`.
    ///
    /// - Parameter existingPointer: A pre-allocated AVFormatContext pointer.
    ///   Pass `nil` to create an empty (no-op) wrapper.
    init(existingPointer: UnsafeMutablePointer<AVFormatContext>?) {
        self.pointer = existingPointer
    }

    // MARK: - Operations

    /// Opens an input stream for reading.
    ///
    /// Calls `avformat_open_input` with the given URL. On success, the context
    /// is ready for stream discovery and packet reading.
    ///
    /// - Parameter url: The URL of the media source (file path, RTMP, HLS, RTSP, etc.).
    /// - Throws: `FFmpegError` mapped from the FFmpeg error code on failure.
    ///
    /// - Note: After a successful call, `avformat_close_input` will be called
    ///   automatically in `deinit`.
    func openInput(url: String) throws {
        try openInput(url: url, options: nil)
    }

    /// Opens an input stream for reading with optional format options.
    ///
    /// Calls `avformat_open_input` with the given URL and options dictionary.
    /// On success, the context is ready for stream discovery and packet reading.
    ///
    /// - Parameters:
    ///   - url: The URL of the media source (file path, RTMP, HLS, RTSP, etc.).
    ///   - options: An optional `OpaquePointer` to an `AVDictionary` of format options
    ///     (e.g., timeout settings). The caller is responsible for freeing the dictionary
    ///     after this call returns.
    /// - Throws: `FFmpegError` mapped from the FFmpeg error code on failure.
    ///
    /// - Note: After a successful call, `avformat_close_input` will be called
    ///   automatically in `deinit`.
    func openInput(url: String, options: UnsafeMutablePointer<OpaquePointer?>?) throws {
        var ctx = pointer
        let ret = avformat_open_input(&ctx, url, nil, options)
        guard ret >= 0 else {
            // avformat_open_input frees the context on failure and sets *ps to NULL,
            // so we must update our pointer accordingly.
            pointer = ctx
            isInputOpened = false
            throw FFmpegError.from(code: ret)
        }
        pointer = ctx
        isInputOpened = true
    }

    /// Reads packets to determine stream information (codecs, duration, etc.).
    ///
    /// Should be called after `openInput(url:)` to populate stream metadata.
    ///
    /// - Throws: `FFmpegError.resourceAllocationFailed` if the context is nil or input
    ///   has not been opened. `FFmpegError` mapped from the FFmpeg error code on other failures.
    func findStreamInfo() throws {
        guard let ctx = pointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFormatContext (nil)")
        }
        guard isInputOpened else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFormatContext (input not opened)")
        }
        let ret = avformat_find_stream_info(ctx, nil)
        guard ret >= 0 else {
            throw FFmpegError.from(code: ret)
        }
    }

    /// Provides access to a stream at the given index.
    ///
    /// - Parameter index: The zero-based stream index.
    /// - Returns: A pointer to the `AVStream`, or `nil` if the index is out of bounds
    ///   or the context is not available.
    func stream(at index: Int) -> UnsafeMutablePointer<AVStream>? {
        guard let ctx = pointer,
              index >= 0,
              index < Int(ctx.pointee.nb_streams),
              let streams = ctx.pointee.streams else {
            return nil
        }
        return streams[index]
    }

    // MARK: - Seek

    /// Seeks to the specified timestamp in the stream.
    ///
    /// Calls `av_seek_frame` with `AVSEEK_FLAG_BACKWARD` to seek to the nearest
    /// keyframe before the given timestamp.
    ///
    /// - Parameters:
    ///   - timestamp: The target timestamp in AV_TIME_BASE units (microseconds).
    ///   - streamIndex: The stream index to seek in, or -1 for default.
    /// - Throws: `FFmpegError` on failure.
    func seek(to timestamp: Int64, streamIndex: Int32 = -1) throws {
        guard let ctx = pointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFormatContext (nil)")
        }
        let ret = av_seek_frame(ctx, streamIndex, timestamp, AVSEEK_FLAG_BACKWARD)
        guard ret >= 0 else {
            throw FFmpegError.from(code: ret)
        }
    }

    // MARK: - Deinitialization

    deinit {
        if pointer != nil {
            if isInputOpened {
                // avformat_close_input frees the context and sets the pointer to NULL.
                var ctx = pointer
                avformat_close_input(&ctx)
            } else {
                // If input was never opened, just free the allocated context.
                avformat_free_context(pointer)
            }
            pointer = nil
        }
    }
}
