// VideoFrame.swift
// FFmpegSwiftSDK
//
// Represents a decoded video frame with its pixel data and timing information.

import Foundation
import CoreVideo

/// A decoded video frame containing pixel data and presentation metadata.
///
/// `VideoFrame` wraps a `CVPixelBuffer` along with timing and dimension
/// information extracted from the decoded AVFrame. It is produced by
/// `VideoDecoder.decode(packet:)` and consumed by the rendering layer.
public struct VideoFrame {

    /// The pixel buffer containing the decoded image data.
    ///
    /// Typically in NV12 (420v) format, suitable for display via
    /// CoreVideo or Metal rendering pipelines.
    public let pixelBuffer: CVPixelBuffer

    /// The presentation timestamp in seconds.
    ///
    /// Indicates when this frame should be displayed relative to the
    /// start of the stream.
    public let pts: TimeInterval

    /// The duration of this frame in seconds.
    ///
    /// Indicates how long this frame should be displayed before the
    /// next frame replaces it.
    public let duration: TimeInterval

    /// The width of the video frame in pixels.
    public let width: Int

    /// The height of the video frame in pixels.
    public let height: Int

    /// Creates a new `VideoFrame`.
    ///
    /// - Parameters:
    ///   - pixelBuffer: The pixel buffer containing decoded image data.
    ///   - pts: The presentation timestamp in seconds.
    ///   - duration: The frame duration in seconds.
    ///   - width: The frame width in pixels.
    ///   - height: The frame height in pixels.
    public init(pixelBuffer: CVPixelBuffer, pts: TimeInterval, duration: TimeInterval, width: Int, height: Int) {
        self.pixelBuffer = pixelBuffer
        self.pts = pts
        self.duration = duration
        self.width = width
        self.height = height
    }
}
