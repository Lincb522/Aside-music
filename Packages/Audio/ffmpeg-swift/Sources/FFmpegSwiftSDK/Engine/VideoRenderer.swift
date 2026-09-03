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
/// directly into a UIView layer hierarchy by the caller.
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
        enqueue(frame, displayImmediately: false)
    }

    /// Renders a frame whose pacing is controlled by the caller.
    ///
    /// This is used by the silent video pipeline. Its wall clock is independent
    /// from the app's audio renderer, so the sample must not wait on an audio
    /// timebase inside `AVSampleBufferDisplayLayer`.
    func renderImmediately(_ frame: VideoFrame) {
        enqueue(frame, displayImmediately: true)
    }

    private func enqueue(_ frame: VideoFrame, displayImmediately: Bool) {
        guard let sampleBuffer = createSampleBuffer(from: frame) else { return }
        if displayImmediately {
            markForImmediateDisplay(sampleBuffer)
        }

        let layer = sampleBufferDisplayLayer
        let buffer = sampleBuffer
        renderQueue.async { [weak self] in
            guard let self, !self.isCleared else { return }
            DispatchQueue.main.async {
                if layer.status == .failed {
                    layer.flush()
                }
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

    private func markForImmediateDisplay(_ sampleBuffer: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: true
        ), CFArrayGetCount(attachments) > 0 else {
            return
        }

        let attachment = unsafeBitCast(
            CFArrayGetValueAtIndex(attachments, 0),
            to: CFMutableDictionary.self
        )
        CFDictionarySetValue(
            attachment,
            Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
            Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        )
    }
}
