// StreamInfo.swift
// FFmpegSwiftSDK
//
// Describes the streams found in a media container after demuxing.
// Contains metadata about audio and video streams such as codec names,
// sample rates, dimensions, and duration.

import Foundation

/// Metadata describing the audio and video streams found in a media container.
///
/// `StreamInfo` is produced by `Demuxer.findStreams()` after analyzing the
/// format context. It provides a high-level summary of what the media contains
/// without exposing FFmpeg internals.
///
/// - Note: For live streams (e.g., RTMP, RTSP), `duration` will be `nil`.
public struct StreamInfo {

    /// The URL of the media source that was opened.
    public let url: String

    /// Whether the container includes at least one audio stream.
    public let hasAudio: Bool

    /// Whether the container includes at least one video stream.
    public let hasVideo: Bool

    /// The name of the audio codec (e.g., "aac", "mp3"), or `nil` if no audio stream exists.
    public let audioCodec: String?

    /// The name of the video codec (e.g., "h264", "hevc"), or `nil` if no video stream exists.
    public let videoCodec: String?

    /// The audio sample rate in Hz (e.g., 44100, 48000), or `nil` if no audio stream exists.
    public let sampleRate: Int?

    /// The number of audio channels (e.g., 1 for mono, 2 for stereo), or `nil` if no audio stream exists.
    public let channelCount: Int?

    /// The audio bit depth (e.g., 16, 24, 32), or `nil` if no audio stream exists.
    public let bitDepth: Int?

    /// The video frame width in pixels, or `nil` if no video stream exists.
    public let width: Int?

    /// The video frame height in pixels, or `nil` if no video stream exists.
    public let height: Int?

    /// The total duration of the media in seconds, or `nil` for live streams.
    public let duration: TimeInterval?

    /// 容器格式名称（如 "mov,mp4,m4a,3gp,3g2,mj2"、"flac"、"ogg"、"matroska,webm"）。
    public let containerFormat: String?

    /// 音频是否为无损格式（FLAC、ALAC、WAV PCM、WavPack、APE、TAK、TTA、DSD）。
    public var isLossless: Bool {
        guard let codec = audioCodec?.lowercased() else { return false }
        let losslessCodecs: Set<String> = [
            "flac", "alac", "wavpack", "ape", "tak", "tta",
            "pcm_s16le", "pcm_s16be", "pcm_s24le", "pcm_s24be",
            "pcm_s32le", "pcm_s32be", "pcm_f32le", "pcm_f32be", "pcm_f64le",
            "dsd_lsbf", "dsd_msbf", "dsd_lsbf_planar", "dsd_msbf_planar",
            "wmalossless"
        ]
        return losslessCodecs.contains(codec)
    }

    /// 是否为 Hi-Res 音频（采样率 > 48kHz 或 位深 > 16bit）。
    public var isHiRes: Bool {
        if let sr = sampleRate, sr > 48000 { return true }
        if let bd = bitDepth, bd > 16 { return true }
        return false
    }

    /// 音频质量描述标签。
    public var qualityLabel: String {
        if isHiRes {
            let sr = sampleRate.map { "\($0 / 1000)kHz" } ?? ""
            let bd = bitDepth.map { "\($0)bit" } ?? ""
            return "Hi-Res \(bd)/\(sr)".trimmingCharacters(in: .whitespaces)
        } else if isLossless {
            return "Lossless"
        } else {
            return "Lossy"
        }
    }

    /// Creates a new `StreamInfo` instance.
    ///
    /// - Parameters:
    ///   - url: The URL of the media source.
    ///   - hasAudio: Whether an audio stream was found.
    ///   - hasVideo: Whether a video stream was found.
    ///   - audioCodec: The audio codec name, or `nil`.
    ///   - videoCodec: The video codec name, or `nil`.
    ///   - sampleRate: The audio sample rate in Hz, or `nil`.
    ///   - channelCount: The number of audio channels, or `nil`.
    ///   - bitDepth: The audio bit depth, or `nil`.
    ///   - width: The video width in pixels, or `nil`.
    ///   - height: The video height in pixels, or `nil`.
    ///   - duration: The media duration in seconds, or `nil` for live streams.
    ///   - containerFormat: The container format name, or `nil`.
    public init(
        url: String,
        hasAudio: Bool,
        hasVideo: Bool,
        audioCodec: String?,
        videoCodec: String?,
        sampleRate: Int?,
        channelCount: Int?,
        bitDepth: Int?,
        width: Int?,
        height: Int?,
        duration: TimeInterval?,
        containerFormat: String? = nil
    ) {
        self.url = url
        self.hasAudio = hasAudio
        self.hasVideo = hasVideo
        self.audioCodec = audioCodec
        self.videoCodec = videoCodec
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.width = width
        self.height = height
        self.duration = duration
        self.containerFormat = containerFormat
    }
}
