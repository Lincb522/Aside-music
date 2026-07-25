// AudioBuffer.swift
// FFmpegSwiftSDK
//
// Represents a buffer of PCM audio data with associated metadata.

import Foundation

/// A buffer containing PCM audio sample data.
///
/// `AudioBuffer` wraps a pointer to interleaved Float32 PCM samples along with
/// metadata describing the buffer's format (frame count, channel count, sample rate).
///
/// - Note: The caller is responsible for managing the lifetime of the `data` pointer.
///   This struct does not own or deallocate the underlying memory.
public struct AudioBuffer {
    /// Pointer to interleaved Float32 PCM sample data.
    ///
    /// The total number of Float values is `frameCount * channelCount`.
    public let data: UnsafeMutablePointer<Float>

    /// The number of audio frames in the buffer.
    ///
    /// Each frame contains one sample per channel.
    public let frameCount: Int

    /// The number of audio channels (e.g., 1 for mono, 2 for stereo).
    public let channelCount: Int

    /// The sample rate in Hz (e.g., 44100, 48000).
    public let sampleRate: Int

    /// The duration of the audio buffer in seconds.
    ///
    /// Computed as `frameCount / sampleRate`.
    public var duration: TimeInterval {
        TimeInterval(frameCount) / TimeInterval(sampleRate)
    }

    /// Creates a new `AudioBuffer`.
    ///
    /// - Parameters:
    ///   - data: Pointer to interleaved Float32 PCM sample data.
    ///   - frameCount: The number of audio frames.
    ///   - channelCount: The number of audio channels.
    ///   - sampleRate: The sample rate in Hz.
    public init(data: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int, sampleRate: Int) {
        self.data = data
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
    }
}
