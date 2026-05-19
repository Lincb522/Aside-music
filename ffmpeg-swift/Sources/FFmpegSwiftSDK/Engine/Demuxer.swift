// Demuxer.swift
// FFmpegSwiftSDK
//
// Separates audio and video streams from a media container format.
// Reads packets from the format context and classifies them by stream type.
// Produces StreamInfo metadata after locating available streams.

import Foundation
import CFFmpeg

// MARK: - Demuxer

/// Demultiplexes a media container into separate audio and video packet streams.
///
/// `Demuxer` wraps an `FFmpegFormatContext` (which must already have been opened
/// with `openInput` and `findStreamInfo` called) and provides methods to:
/// 1. Discover audio/video streams and build a `StreamInfo` summary.
/// 2. Read packets one at a time, classified as `.audio` or `.video`.
///
/// Usage:
/// ```swift
/// let demuxer = Demuxer(formatContext: context, url: "rtmp://example.com/live")
/// let info = try demuxer.findStreams()
/// while let packet = try demuxer.readNextPacket() {
///     switch packet {
///     case .audio(let pkt): // handle audio packet
///     case .video(let pkt): // handle video packet
///     }
/// }
/// ```
///
/// - Important: This is an internal type used by the engine layer.
///   It is not exposed as public API.
final class Demuxer {

    // MARK: - PacketType

    /// Classifies a demuxed packet as either audio or video.
    enum PacketType {
        /// An audio packet read from the audio stream.
        case audio(UnsafeMutablePointer<AVPacket>)
        /// A video packet read from the video stream.
        case video(UnsafeMutablePointer<AVPacket>)
    }

    // MARK: - Properties

    /// The format context containing the opened media input.
    private let formatContext: FFmpegFormatContext

    /// The URL of the media source, stored for inclusion in `StreamInfo`.
    private let url: String

    /// The index of the best audio stream, or -1 if none found.
    private var audioStreamIndex: Int32 = -1

    /// The index of the best video stream, or -1 if none found.
    private var videoStreamIndex: Int32 = -1

    // MARK: - Initialization

    /// Creates a new `Demuxer` for the given format context.
    ///
    /// The format context must already have been opened with `openInput(url:)` and
    /// `findStreamInfo()` called, so that stream metadata is available.
    ///
    /// - Parameters:
    ///   - formatContext: An opened `FFmpegFormatContext` with stream info populated.
    ///   - url: The URL of the media source (used in `StreamInfo`).
    init(formatContext: FFmpegFormatContext, url: String) {
        self.formatContext = formatContext
        self.url = url
    }

    // MARK: - Stream Discovery

    /// Locates audio and video streams in the format context and builds stream metadata.
    ///
    /// Iterates through all streams in the format context, identifying the first audio
    /// and first video stream by their codec type. Extracts codec names, sample rates,
    /// channel counts, dimensions, and duration from the stream parameters.
    ///
    /// - Returns: A `StreamInfo` describing the discovered streams.
    /// - Throws: `FFmpegError.resourceAllocationFailed` if the format context is nil.
    func findStreams() throws -> StreamInfo {
        guard let ctx = formatContext.rawPointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFormatContext (nil)")
        }

        let streamCount = formatContext.streamCount

        var audioCodecName: String?
        var videoCodecName: String?
        var sampleRate: Int?
        var channelCount: Int?
        var bitDepth: Int?
        var width: Int?
        var height: Int?

        // Reset stream indices
        audioStreamIndex = -1
        videoStreamIndex = -1

        // Iterate through all streams to find audio and video
        for i in 0..<streamCount {
            guard let stream = formatContext.stream(at: i) else { continue }
            guard let codecpar = stream.pointee.codecpar else { continue }

            let codecType = codecpar.pointee.codec_type

            if codecType == AVMEDIA_TYPE_AUDIO && audioStreamIndex == -1 {
                audioStreamIndex = Int32(i)

                // Extract audio codec name
                let codecID = codecpar.pointee.codec_id
                let namePtr = avcodec_get_name(codecID)
                if let namePtr = namePtr {
                    audioCodecName = String(cString: namePtr)
                }

                // Extract audio parameters
                sampleRate = Int(codecpar.pointee.sample_rate)

                // Get channel count from ch_layout
                channelCount = Int(codecpar.pointee.ch_layout.nb_channels)

                // Get bit depth from bits_per_raw_sample or bits_per_coded_sample
                let rawBits = Int(codecpar.pointee.bits_per_raw_sample)
                let codedBits = Int(codecpar.pointee.bits_per_coded_sample)
                if rawBits > 0 {
                    bitDepth = rawBits
                } else if codedBits > 0 {
                    bitDepth = codedBits
                }

            } else if codecType == AVMEDIA_TYPE_VIDEO && videoStreamIndex == -1 {
                videoStreamIndex = Int32(i)

                // Extract video codec name
                let codecID = codecpar.pointee.codec_id
                let namePtr = avcodec_get_name(codecID)
                if let namePtr = namePtr {
                    videoCodecName = String(cString: namePtr)
                }

                // Extract video dimensions
                width = Int(codecpar.pointee.width)
                height = Int(codecpar.pointee.height)
            }

            // Stop early if both streams found
            if audioStreamIndex != -1 && videoStreamIndex != -1 {
                break
            }
        }

        // Determine duration
        // AVFormatContext.duration is in AV_TIME_BASE units (microseconds).
        // A value of AV_NOPTS_VALUE indicates unknown/live duration.
        let duration: TimeInterval?
        let rawDuration = ctx.pointee.duration
        if rawDuration != Int64(bitPattern: UInt64(0x8000000000000000)) && rawDuration > 0 {
            // AV_NOPTS_VALUE is 0x8000000000000000 as Int64
            duration = TimeInterval(rawDuration) / TimeInterval(AV_TIME_BASE)
        } else {
            duration = nil
        }

        // 提取容器格式名称
        let containerFormat: String?
        if let iformat = ctx.pointee.iformat, let name = iformat.pointee.name {
            containerFormat = String(cString: name)
        } else {
            containerFormat = nil
        }

        return StreamInfo(
            url: url,
            hasAudio: audioStreamIndex != -1,
            hasVideo: videoStreamIndex != -1,
            audioCodec: audioCodecName,
            videoCodec: videoCodecName,
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitDepth: bitDepth,
            width: width,
            height: height,
            duration: duration,
            containerFormat: containerFormat
        )
    }

    // MARK: - Packet Reading

    /// Reads the next packet from the format context and classifies it.
    ///
    /// Calls `av_read_frame` to read the next packet. If the packet belongs to
    /// the audio or video stream, it is returned as the corresponding `PacketType`.
    /// Packets from other streams (e.g., subtitles) are silently skipped.
    ///
    /// The returned packet is allocated via `av_packet_alloc` and the caller is
    /// responsible for freeing it with `av_packet_free` when done.
    ///
    /// Network-related errors (connection reset, broken pipe, I/O errors) are
    /// detected and thrown as `FFmpegError.networkDisconnected` to enable the
    /// caller to handle disconnection appropriately.
    ///
    /// - Returns: A classified `PacketType`, or `nil` when end-of-file is reached.
    /// - Throws: `FFmpegError.networkDisconnected` for network errors,
    ///   or other `FFmpegError` variants for non-network read failures.
    /// 网络错误连续重试次数上限。
    /// FFmpeg 的 reconnect_on_network_error 需要重新调用 av_read_frame 才能触发重连，
    /// 第一次返回错误，第二次调用时 HTTP 协议层才会尝试重新建立连接。
    private let maxNetworkRetries = 3

    func readNextPacket() throws -> PacketType? {
        guard let ctx = formatContext.rawPointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFormatContext (nil)")
        }

        var eagainCount = 0
        var networkRetryCount = 0
        while true {
            guard let packet = av_packet_alloc() else {
                throw FFmpegError.resourceAllocationFailed(resource: "AVPacket")
            }

            let ret = av_read_frame(ctx, packet)

            if ret < 0 {
                var pkt: UnsafeMutablePointer<AVPacket>? = packet
                av_packet_free(&pkt)

                if ret == FFmpegErrorCode.AVERROR_EOF {
                    return nil
                }

                if ret == -Int32(EAGAIN) {
                    eagainCount += 1
                    let backoff = min(Double(eagainCount) * 0.002, 0.02)
                    Thread.sleep(forTimeInterval: backoff)
                    continue
                }

                // 网络错误：给 FFmpeg 的 HTTP reconnect 机制几次重试机会。
                // av_read_frame 第一次返回网络错误后，下次调用时 HTTP 协议层
                // 会检测到连接断开并尝试重新建立连接（需要 reconnect_on_network_error=1）。
                if Demuxer.isNetworkError(ret) {
                    networkRetryCount += 1
                    if networkRetryCount <= maxNetworkRetries {
                        let backoff = min(Double(networkRetryCount) * 0.5, 2.0)
                        print(
                            "[Demuxer] ⚠️ network error (code=\(ret)), retry \(networkRetryCount)/\(maxNetworkRetries) " +
                            "after \(String(format: "%.1f", backoff))s"
                        )
                        Thread.sleep(forTimeInterval: backoff)
                        continue
                    }
                    throw FFmpegError.networkDisconnected
                }

                throw FFmpegError.from(code: ret)
            }

            eagainCount = 0
            networkRetryCount = 0
            let streamIndex = packet.pointee.stream_index

            if streamIndex == audioStreamIndex {
                return .audio(packet)
            } else if streamIndex == videoStreamIndex {
                return .video(packet)
            } else {
                av_packet_unref(packet)
                var pkt: UnsafeMutablePointer<AVPacket>? = packet
                av_packet_free(&pkt)
                continue
            }
        }
    }

    // MARK: - Network Error Detection

    /// Determines whether an FFmpeg error code indicates a network disconnection.
    ///
    /// Checks for connection reset, broken pipe, I/O errors, and timeout —
    /// all of which typically signal that the network connection has been lost.
    ///
    /// - Parameter code: A negative FFmpeg error code.
    /// - Returns: `true` if the error is network-related.
    static func isNetworkError(_ code: Int32) -> Bool {
        switch code {
        case FFmpegErrorCode.AVERROR_ECONNRESET,
             FFmpegErrorCode.AVERROR_EPIPE,
             FFmpegErrorCode.AVERROR_EIO,
             FFmpegErrorCode.AVERROR_ETIMEDOUT:
            return true
        default:
            return false
        }
    }

    // MARK: - Seek

    /// Seeks to the specified time position in seconds.
    ///
    /// Converts the time to AV_TIME_BASE units and delegates to the format context.
    /// After seeking, the caller should flush decoder buffers.
    ///
    /// - Parameter timeInSeconds: The target position in seconds.
    /// - Throws: `FFmpegError` on failure.
    func seek(to timeInSeconds: TimeInterval) throws {
        let timestamp = Int64(timeInSeconds * Double(AV_TIME_BASE))
        try formatContext.seek(to: timestamp)
    }

    // MARK: - Stream Index Accessors

    /// The index of the discovered audio stream, or -1 if none.
    var currentAudioStreamIndex: Int32 {
        return audioStreamIndex
    }

    /// The index of the discovered video stream, or -1 if none.
    var currentVideoStreamIndex: Int32 {
        return videoStreamIndex
    }
}
