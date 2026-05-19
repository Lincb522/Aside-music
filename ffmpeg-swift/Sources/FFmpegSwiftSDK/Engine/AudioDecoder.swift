// AudioDecoder.swift
// FFmpegSwiftSDK
//
// Decodes compressed audio packets into PCM AudioBuffer data.
// Uses FFmpeg's avcodec API for decoding and SwrContext for
// resampling/converting to Float32 interleaved PCM format.

import Foundation
import CFFmpeg

// MARK: - Decoder Protocol

/// A protocol for decoders that convert compressed packets into decoded output.
///
/// Conforming types decode `AVPacket` data into their associated `Output` type
/// and support flushing internal buffers.
protocol Decoder {
    associatedtype Output

    /// Decodes a compressed packet into the output type.
    ///
    /// - Parameter packet: A pointer to the AVPacket containing compressed data.
    /// - Returns: The decoded output.
    /// - Throws: `FFmpegError` if decoding fails.
    func decode(packet: UnsafeMutablePointer<AVPacket>) throws -> Output

    /// Flushes the decoder's internal buffers.
    ///
    /// Call this when seeking or when the stream ends to ensure all
    /// buffered frames are processed.
    func flush()
}

// MARK: - Supported Codec Validation

/// The set of audio codec IDs supported by the SDK.
///
/// Used by `AudioDecoder` to validate that a codec is supported
/// before attempting to open a decoder.
let supportedAudioCodecIDs: Set<UInt32> = [
    AV_CODEC_ID_AAC.rawValue,
    AV_CODEC_ID_MP3.rawValue,
    AV_CODEC_ID_FLAC.rawValue,
    AV_CODEC_ID_VORBIS.rawValue,
    AV_CODEC_ID_OPUS.rawValue,
    AV_CODEC_ID_ALAC.rawValue,
    AV_CODEC_ID_PCM_S16LE.rawValue,
    AV_CODEC_ID_PCM_S16BE.rawValue,
    AV_CODEC_ID_PCM_S24LE.rawValue,
    AV_CODEC_ID_PCM_S24BE.rawValue,
    AV_CODEC_ID_PCM_S32LE.rawValue,
    AV_CODEC_ID_PCM_S32BE.rawValue,
    AV_CODEC_ID_PCM_F32LE.rawValue,
    AV_CODEC_ID_PCM_F32BE.rawValue,
    AV_CODEC_ID_PCM_F64LE.rawValue,
    AV_CODEC_ID_PCM_MULAW.rawValue,
    AV_CODEC_ID_PCM_ALAW.rawValue,
    AV_CODEC_ID_WAVPACK.rawValue,
    AV_CODEC_ID_APE.rawValue,
    AV_CODEC_ID_TAK.rawValue,
    AV_CODEC_ID_WMAV1.rawValue,
    AV_CODEC_ID_WMAV2.rawValue,
    AV_CODEC_ID_AC3.rawValue,
    AV_CODEC_ID_EAC3.rawValue,
    AV_CODEC_ID_DTS.rawValue,
    AV_CODEC_ID_TTA.rawValue,
    AV_CODEC_ID_COOK.rawValue,
    AV_CODEC_ID_ADPCM_IMA_WAV.rawValue,
    AV_CODEC_ID_ADPCM_MS.rawValue,
]

/// The set of video codec IDs supported by the SDK.
///
/// Used by `VideoDecoder` to validate that a codec is supported
/// before attempting to open a decoder.
let supportedVideoCodecIDs: Set<UInt32> = [
    AV_CODEC_ID_H264.rawValue,
    AV_CODEC_ID_HEVC.rawValue
]

/// Checks whether a given codec ID is in the supported set and throws if not.
///
/// - Parameters:
///   - codecID: The FFmpeg codec ID to validate.
///   - supportedIDs: The set of supported codec ID raw values.
/// - Throws: `FFmpegError.unsupportedFormat` if the codec is not supported.
func validateCodecSupported(_ codecID: AVCodecID, in supportedIDs: Set<UInt32>) throws {
    guard supportedIDs.contains(codecID.rawValue) else {
        let codecName = String(cString: avcodec_get_name(codecID))
        throw FFmpegError.unsupportedFormat(codecName: codecName)
    }
}

// MARK: - AudioDecoder

/// Decodes compressed audio packets into Float32 interleaved PCM `AudioBuffer` data.
///
/// `AudioDecoder` wraps an FFmpeg `AVCodecContext` for audio decoding and a
/// `SwrContext` for converting the decoded audio to Float32 interleaved PCM format.
///
/// Supported codecs: AAC, MP3 (per Requirement 3.5).
///
/// Usage:
/// ```swift
/// let decoder = try AudioDecoder(codecParameters: stream.codecpar, codecID: AV_CODEC_ID_AAC)
/// let audioBuffer = try decoder.decode(packet: audioPacket)
/// // Use audioBuffer.data, audioBuffer.frameCount, etc.
/// ```
///
/// - Important: This is an internal type used by the engine layer.
///   It is not exposed as public API.
final class AudioDecoder: Decoder {
    typealias Output = AudioBuffer

    // MARK: - Properties

    /// The codec context wrapper managing the underlying AVCodecContext.
    private let codecContext: FFmpegCodecContext

    /// The resampling context for converting decoded audio to Float32 PCM.
    private var resampleContext: OpaquePointer?

    /// 实际输出采样率（保持与源一致，支持 Hi-Res 192kHz）
    private(set) var outputSampleRate: Int

    /// 实际输出声道数
    private(set) var outputChannelCount: Int

    // MARK: - Initialization

    /// Creates a new `AudioDecoder` for the given codec parameters.
    ///
    /// 解码并转换为 Float32 interleaved PCM。
    /// 如果指定了 targetSampleRate 且与源不同，SwrContext 会自动重采样。
    ///
    /// - Parameters:
    ///   - codecParameters: The codec parameters from the audio stream.
    ///   - codecID: The codec ID to decode.
    ///   - targetSampleRate: 目标输出采样率。nil 表示保持源采样率。
    /// - Throws: `FFmpegError.unsupportedFormat` if the codec is not supported,
    ///   or other `FFmpegError` variants if initialization fails.
    init(codecParameters: UnsafePointer<AVCodecParameters>, codecID: AVCodecID, targetSampleRate: Int? = nil) throws {
        // Validate supported codec
        try validateCodecSupported(codecID, in: supportedAudioCodecIDs)

        // Find the decoder
        guard let decoder = avcodec_find_decoder(codecID) else {
            let codecName = String(cString: avcodec_get_name(codecID))
            throw FFmpegError.unsupportedFormat(codecName: codecName)
        }

        // Allocate and configure codec context
        codecContext = try FFmpegCodecContext(codec: decoder)
        try codecContext.setParameters(from: codecParameters)
        try codecContext.open(codec: decoder)

        guard let ctx = codecContext.rawPointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVCodecContext (nil after open)")
        }

        // Extract audio parameters
        let inputRate = Int(ctx.pointee.sample_rate)
        outputChannelCount = Int(ctx.pointee.ch_layout.nb_channels)
        // 如果指定了目标采样率就用它，否则保持源采样率
        outputSampleRate = targetSampleRate ?? inputRate

        // Set up SwrContext for conversion to Float32 interleaved PCM
        // 保持原始采样率，支持 Hi-Res 192kHz 母带音质
        resampleContext = try AudioDecoder.createResampleContext(
            codecContext: ctx,
            outputSampleRate: Int32(outputSampleRate)
        )
    }

    // MARK: - Resampling Setup

    /// Creates and initializes a SwrContext for converting decoded audio to Float32 interleaved PCM.
    ///
    /// 保持原始采样率不变，仅做格式转换（planar → interleaved, 任意位深 → Float32）。
    /// 支持 Hi-Res 192kHz/24bit 母带音质。
    ///
    /// - Parameter codecContext: The opened codec context with valid audio parameters.
    /// - Returns: An initialized SwrContext opaque pointer.
    /// - Throws: `FFmpegError.resourceAllocationFailed` if allocation or initialization fails.
    private static func createResampleContext(
        codecContext ctx: UnsafeMutablePointer<AVCodecContext>,
        outputSampleRate: Int32
    ) throws -> OpaquePointer {
        // Allocate SwrContext
        var swrCtx: OpaquePointer? = swr_alloc()
        guard swrCtx != nil else {
            throw FFmpegError.resourceAllocationFailed(resource: "SwrContext")
        }

        // Configure input channel layout from the codec context
        var inLayout = ctx.pointee.ch_layout
        var outLayout = AVChannelLayout()
        av_channel_layout_default(&outLayout, ctx.pointee.ch_layout.nb_channels)

        // Use swr_alloc_set_opts2 for modern FFmpeg API
        // Free the previously allocated context since swr_alloc_set_opts2 allocates a new one
        swr_free(&swrCtx)

        var newSwrCtx: OpaquePointer?
        let ret = swr_alloc_set_opts2(
            &newSwrCtx,
            &outLayout,                          // output channel layout
            AV_SAMPLE_FMT_FLT,                   // output sample format: Float32 interleaved
            outputSampleRate,                     // output sample rate（可能与输入不同）
            &inLayout,                            // input channel layout
            ctx.pointee.sample_fmt,               // input sample format
            ctx.pointee.sample_rate,              // input sample rate
            0,                                    // log offset
            nil                                   // log context
        )

        guard ret >= 0, let finalCtx = newSwrCtx else {
            if newSwrCtx != nil { swr_free(&newSwrCtx) }
            throw FFmpegError.resourceAllocationFailed(resource: "SwrContext (swr_alloc_set_opts2)")
        }

        // Initialize the resampling context
        let initRet = swr_init(finalCtx)
        guard initRet >= 0 else {
            var ctx = Optional(finalCtx)
            swr_free(&ctx)
            throw FFmpegError.from(code: initRet)
        }

        return finalCtx
    }

    // MARK: - Decoding

    /// Decodes a compressed audio packet into one or more Float32 PCM `AudioBuffer`s.
    ///
    /// Sends the packet to the decoder, then loops `avcodec_receive_frame` to
    /// drain all decoded frames (a single packet can produce multiple frames).
    /// Each frame is converted to Float32 interleaved PCM via SwrContext.
    ///
    /// - Parameter packet: A pointer to the AVPacket containing compressed audio data.
    /// - Returns: An array of `AudioBuffer`s containing the decoded Float32 PCM data.
    /// - Throws: `FFmpegError.decodingFailed` if decoding fails.
    func decodeAll(packet: UnsafeMutablePointer<AVPacket>) throws -> [AudioBuffer] {
        guard let ctx = codecContext.rawPointer else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVCodecContext (nil)")
        }
        guard let swrCtx = resampleContext else {
            throw FFmpegError.resourceAllocationFailed(resource: "SwrContext (nil)")
        }

        // Send packet to decoder
        let sendRet = avcodec_send_packet(ctx, packet)
        guard sendRet >= 0 else {
            throw FFmpegError.decodingFailed(code: sendRet, message: "avcodec_send_packet failed")
        }

        // Allocate frame for receiving decoded data
        guard let frame = av_frame_alloc() else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFrame")
        }
        defer {
            var framePtr: UnsafeMutablePointer<AVFrame>? = frame
            av_frame_free(&framePtr)
        }

        var buffers: [AudioBuffer] = []

        // Loop to receive ALL decoded frames from this packet
        while true {
            let recvRet = avcodec_receive_frame(ctx, frame)
            if recvRet == -Int32(EAGAIN) || recvRet == FFmpegErrorCode.AVERROR_EOF {
                // No more frames available for this packet
                break
            }
            guard recvRet >= 0 else {
                // If we already got some buffers, return them; otherwise throw
                if !buffers.isEmpty { break }
                throw FFmpegError.decodingFailed(code: recvRet, message: "avcodec_receive_frame failed")
            }

            let buffer = try convertFrameToBuffer(frame: frame, swrCtx: swrCtx)
            buffers.append(buffer)
        }

        return buffers
    }

    /// Decodes a single frame from a packet (legacy convenience, returns first frame).
    func decode(packet: UnsafeMutablePointer<AVPacket>) throws -> AudioBuffer {
        let buffers = try decodeAll(packet: packet)
        guard let first = buffers.first else {
            throw FFmpegError.decodingFailed(code: -1, message: "No frames decoded")
        }
        return first
    }

    /// Converts a decoded AVFrame to a Float32 interleaved PCM AudioBuffer.
    private func convertFrameToBuffer(
        frame: UnsafeMutablePointer<AVFrame>,
        swrCtx: OpaquePointer
    ) throws -> AudioBuffer {
        let frameCount = Int(frame.pointee.nb_samples)
        let channelCount = outputChannelCount

        // 使用 swr_get_out_samples 计算实际需要的输出缓冲区大小
        // 这对 FLAC 等格式很重要，SwrContext 内部可能有延迟缓冲
        let estimatedOutSamples = Int(swr_get_out_samples(swrCtx, Int32(frameCount)))
        let outFrameCount = max(estimatedOutSamples, frameCount) + 256 // 额外余量
        let totalSamples = outFrameCount * channelCount

        let outputBuffer = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)

        var outputPtr: UnsafeMutablePointer<UInt8>? = UnsafeMutableRawPointer(outputBuffer)
            .bindMemory(to: UInt8.self, capacity: totalSamples * MemoryLayout<Float>.size)

        let inputPtr: UnsafePointer<UnsafePointer<UInt8>?>? = frame.pointee.extended_data.map {
            UnsafeRawPointer($0).assumingMemoryBound(to: UnsafePointer<UInt8>?.self)
        }

        let convertedSamples = swr_convert(
            swrCtx,
            &outputPtr,
            Int32(outFrameCount),
            inputPtr,
            Int32(frameCount)
        )

        guard convertedSamples > 0 else {
            outputBuffer.deallocate()
            if convertedSamples == 0 {
                // 没有输出采样，返回空 buffer
                let emptyBuf = UnsafeMutablePointer<Float>.allocate(capacity: 1)
                emptyBuf.pointee = 0
                return AudioBuffer(data: emptyBuf, frameCount: 0, channelCount: channelCount, sampleRate: outputSampleRate)
            }
            throw FFmpegError.decodingFailed(
                code: convertedSamples,
                message: "swr_convert failed"
            )
        }

        let actualSamples = Int(convertedSamples) * channelCount
        return AudioBuffer(
            data: outputBuffer,
            frameCount: Int(convertedSamples),
            channelCount: channelCount,
            sampleRate: outputSampleRate
        )
    }

    // MARK: - Flush & Drain

    /// Flushes the decoder's internal buffers (discards buffered frames).
    /// Used when seeking.
    func flush() {
        guard let ctx = codecContext.rawPointer else { return }
        avcodec_flush_buffers(ctx)
    }

    /// Drains the decoder at EOF: sends NULL packet then receives all remaining buffered frames.
    /// Returns the final decoded audio buffers that were stuck in the decoder's pipeline.
    func drain() -> [AudioBuffer] {
        guard let ctx = codecContext.rawPointer else { return [] }
        guard let swrCtx = resampleContext else { return [] }

        // Signal EOF to decoder
        avcodec_send_packet(ctx, nil)

        guard let frame = av_frame_alloc() else { return [] }
        defer {
            var framePtr: UnsafeMutablePointer<AVFrame>? = frame
            av_frame_free(&framePtr)
        }

        var buffers: [AudioBuffer] = []
        while true {
            let ret = avcodec_receive_frame(ctx, frame)
            if ret < 0 { break }
            if let buffer = try? convertFrameToBuffer(frame: frame, swrCtx: swrCtx) {
                buffers.append(buffer)
            }
        }

        // Also flush any samples buffered inside SwrContext
        var outPtr: UnsafeMutablePointer<UInt8>?
        let maxFlush = 8192
        let flushBuf = UnsafeMutablePointer<Float>.allocate(capacity: maxFlush * outputChannelCount)
        outPtr = UnsafeMutableRawPointer(flushBuf)
            .bindMemory(to: UInt8.self, capacity: maxFlush * outputChannelCount * MemoryLayout<Float>.size)
        let flushed = swr_convert(swrCtx, &outPtr, Int32(maxFlush), nil, 0)
        if flushed > 0 {
            let count = Int(flushed) * outputChannelCount
            let trimmed = UnsafeMutablePointer<Float>.allocate(capacity: count)
            trimmed.initialize(from: flushBuf, count: count)
            flushBuf.deallocate()
            buffers.append(AudioBuffer(
                data: trimmed,
                frameCount: Int(flushed),
                channelCount: outputChannelCount,
                sampleRate: outputSampleRate
            ))
        } else {
            flushBuf.deallocate()
        }

        return buffers
    }

    // MARK: - Deinitialization

    deinit {
        if resampleContext != nil {
            swr_free(&resampleContext)
        }
    }
}
