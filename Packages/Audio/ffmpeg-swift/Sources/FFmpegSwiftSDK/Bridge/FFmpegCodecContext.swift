// FFmpegCodecContext.swift
// FFmpegSwiftSDK
//
// Swift wrapper around AVCodecContext that manages allocation, codec opening,
// and guaranteed cleanup via deinit.
// Hides raw C pointer operations behind a safe Swift interface.

import Foundation
import CFFmpeg

/// Wraps an FFmpeg `AVCodecContext`, providing safe allocation, codec initialization,
/// and automatic resource cleanup.
///
/// On `deinit`, the codec context is freed via `avcodec_free_context`,
/// ensuring no resource leaks.
///
/// - Important: This is an internal type used by the engine layer.
///   It is not exposed as public API.
final class FFmpegCodecContext {

    // MARK: - Properties

    /// The underlying C pointer to AVCodecContext.
    /// `nil` after deallocation or if allocation failed.
    private var pointer: UnsafeMutablePointer<AVCodecContext>?

    /// Provides read-only access to the underlying pointer for engine-layer consumers.
    /// Returns `nil` if the context has been freed or was never allocated.
    var rawPointer: UnsafeMutablePointer<AVCodecContext>? {
        return pointer
    }

    // MARK: - Initialization

    /// Allocates a new `AVCodecContext` for the given codec.
    ///
    /// Calls `avcodec_alloc_context3` with the provided codec. If `codec` is `nil`,
    /// a generic context is allocated without codec-specific defaults.
    ///
    /// - Parameter codec: The codec to associate with this context, or `nil` for a generic context.
    /// - Throws: `FFmpegError.resourceAllocationFailed` if allocation fails.
    init(codec: UnsafePointer<AVCodec>? = nil) throws {
        pointer = avcodec_alloc_context3(codec)
        guard pointer != nil else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVCodecContext")
        }
    }

    // MARK: - Operations

    /// Copies codec parameters from a stream's `AVCodecParameters` into this context.
    ///
    /// Typically called after finding streams in a format context, to configure
    /// the codec context before opening the codec.
    ///
    /// - Parameter parameters: A pointer to the `AVCodecParameters` to copy from.
    /// - Throws: `FFmpegError` mapped from the FFmpeg error code on failure.
    func setParameters(from parameters: UnsafePointer<AVCodecParameters>) throws {
        guard let ctx = pointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVCodecContext (nil)")
        }
        let ret = avcodec_parameters_to_context(ctx, parameters)
        guard ret >= 0 else {
            throw FFmpegError.from(code: ret)
        }
    }

    /// Opens the codec context with the specified codec.
    ///
    /// After this call, the context is ready for decoding or encoding operations.
    ///
    /// - Parameter codec: The codec to open. Must match the codec used during allocation
    ///   (if one was provided), or be a compatible codec.
    /// - Throws: `FFmpegError` mapped from the FFmpeg error code on failure.
    func open(codec: UnsafePointer<AVCodec>) throws {
        guard let ctx = pointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVCodecContext (nil)")
        }
        // avcodec_open2 expects a mutable pointer to AVCodec, but the API
        // actually treats it as const. We use UnsafeMutablePointer cast.
        let ret = avcodec_open2(ctx, codec, nil)
        guard ret >= 0 else {
            throw FFmpegError.from(code: ret)
        }
    }

    /// Finds a decoder for the given codec ID and opens this context with it.
    ///
    /// This is a convenience method that combines `avcodec_find_decoder` and `open(codec:)`.
    ///
    /// - Parameter codecID: The FFmpeg codec ID to find a decoder for.
    /// - Throws: `FFmpegError.unsupportedFormat` if no decoder is found for the codec ID,
    ///   or `FFmpegError` from the FFmpeg error code if opening fails.
    func openDecoder(for codecID: AVCodecID) throws {
        guard let decoder = avcodec_find_decoder(codecID) else {
            let codecName = String(cString: avcodec_get_name(codecID))
            throw FFmpegError.unsupportedFormat(codecName: codecName)
        }
        try open(codec: decoder)
    }

    // MARK: - Deinitialization

    deinit {
        if pointer != nil {
            var ctx = pointer
            avcodec_free_context(&ctx)
            pointer = nil
        }
    }
}
