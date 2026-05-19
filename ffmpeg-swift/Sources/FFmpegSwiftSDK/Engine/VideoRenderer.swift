// VideoRenderer.swift
// FFmpegSwiftSDK
//
// Renders decoded video frames using AVSampleBufferDisplayLayer.
// The layer is exposed publicly so callers can embed it in their view hierarchy.

import Foundation
import CoreVideo
import QuartzCore
import AVFoundation

/// Renders decoded video frames via an `AVSampleBufferDisplayLayer`.
///
/// The `sampleBufferDisplayLayer` is created once at init and can be embedded
/// directly into a UIView/NSView layer hierarchy by the caller.
///
/// Thread safety: All layer operations are serialised through `renderQueue`
/// to prevent concurrent enqueue / flush races that crash in CoreMedia XPC.
final class VideoRenderer {

    // MARK: - Properties

    /// The display layer for video rendering. Embed this in your view hierarchy.
    let sampleBufferDisplayLayer: AVSampleBufferDisplayLayer

    /// Serial queue that serialises all layer operations (enqueue + flush).
    private let renderQueue = DispatchQueue(label: "ffmpeg.VideoRenderer.serial")

    /// Set to `true` when `clear()` is called; render ignores new frames
    /// until the next session starts.
    private var isCleared = false

    // MARK: - Initialization

    init() {
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        sampleBufferDisplayLayer.videoGravity = .resizeAspect
    }

    // MARK: - Rendering

    /// Renders a decoded video frame.
    func render(_ frame: VideoFrame) {
        guard let sampleBuffer = createSampleBuffer(from: frame) else { return }

        let layer = sampleBufferDisplayLayer
        let buffer = sampleBuffer
        renderQueue.async { [weak self] in
            guard let self, !self.isCleared else { return }
            DispatchQueue.main.async {
                layer.enqueue(buffer)
            }
        }
    }

    /// Clears the display, flushing any pending frames.
    /// Safe to call from any thread.
    func clear() {
        let layer = sampleBufferDisplayLayer
        renderQueue.sync { [weak self] in
            self?.isCleared = true
        }
        DispatchQueue.main.async {
            layer.flushAndRemoveImage()
        }
    }

    /// Resets the cleared flag so `render` works again for a new session.
    func resetForNewSession() {
        renderQueue.async { [weak self] in
            self?.isCleared = false
        }
    }

    // MARK: - Private Helpers

    private func createSampleBuffer(from frame: VideoFrame) -> CMSampleBuffer? {
        var formatDescription: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frame.pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr, let format = formatDescription else { return nil }

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(seconds: frame.duration, preferredTimescale: 90000),
            presentationTimeStamp: CMTime(seconds: frame.pts, preferredTimescale: 90000),
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frame.pixelBuffer,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard createStatus == noErr else { return nil }

        return sampleBuffer
    }
}
