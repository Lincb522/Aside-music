// WaveformGenerator.swift
// FFmpegSwiftSDK
//
// 波形预览生成器。解码音频，提取峰值数据，
// 生成类似 SoundCloud 的波形缩略图数据。
// 支持本地文件和流媒体 URL。

import Foundation
import CFFmpeg

/// 波形数据点，包含正负峰值。
public struct WaveformSample {
    /// 正峰值 [0, 1]
    public let positive: Float
    /// 负峰值 [-1, 0]
    public let negative: Float
}

/// 波形生成进度回调。progress 范围 [0, 1]。
public typealias WaveformProgressCallback = (_ progress: Float) -> Void

/// 波形预览生成器。
///
/// 独立于播放 pipeline，在后台解码音频并提取波形数据。
/// 返回指定数量的采样点，可直接用于绘制波形图。
/// 支持本地文件和流媒体 URL（HTTP、RTMP 等）。
///
/// ```swift
/// let generator = WaveformGenerator()
/// let waveform = try await generator.generate(
///     url: "https://example.com/stream.mp3",
///     samplesCount: 200
/// )
/// // waveform: [WaveformSample]，长度 = 200
/// ```
public final class WaveformGenerator {

    public init() {}

    /// 生成波形数据。
    ///
    /// 在后台线程解码音频，按时间均匀采样，提取每个区间的峰值。
    /// 对于流媒体，会采集 maxDuration 时长的数据。
    ///
    /// - Parameters:
    ///   - url: 音频文件或流媒体 URL
    ///   - samplesCount: 输出采样点数量，默认 200
    ///   - maxDuration: 最大采集时长（秒），对于流媒体默认 60 秒
    ///   - onProgress: 进度回调（可选）
    /// - Returns: 波形采样数组
    /// - Throws: FFmpegError
    public func generate(
        url: String,
        samplesCount: Int = 200,
        maxDuration: TimeInterval = 60,
        onProgress: WaveformProgressCallback? = nil
    ) async throws -> [WaveformSample] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.generateSync(
                        url: url,
                        samplesCount: samplesCount,
                        maxDuration: maxDuration,
                        onProgress: onProgress
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 同步生成波形数据（在后台线程调用）
    private func generateSync(
        url: String,
        samplesCount: Int,
        maxDuration: TimeInterval,
        onProgress: WaveformProgressCallback?
    ) throws -> [WaveformSample] {
        // 检测是否为流媒体 URL
        let isStreamURL = url.lowercased().hasPrefix("http://") ||
                          url.lowercased().hasPrefix("https://") ||
                          url.lowercased().hasPrefix("rtmp://") ||
                          url.lowercased().hasPrefix("rtsp://") ||
                          url.lowercased().hasPrefix("mms://")
        
        // 设置网络选项
        var options: OpaquePointer?
        if isStreamURL {
            av_dict_set(&options, "timeout", "10000000", 0)  // 10 秒超时
            av_dict_set(&options, "reconnect", "1", 0)
            av_dict_set(&options, "reconnect_streamed", "1", 0)
            av_dict_set(&options, "reconnect_delay_max", "5", 0)
        }
        defer { av_dict_free(&options) }
        
        // 打开文件/流
        var fmtCtx: UnsafeMutablePointer<AVFormatContext>?
        var ret = avformat_open_input(&fmtCtx, url, nil, &options)
        guard ret >= 0, let ctx = fmtCtx else {
            throw FFmpegError.connectionFailed(code: ret, message: "无法打开: \(url)")
        }
        defer { avformat_close_input(&fmtCtx) }

        // 对于流媒体，设置更长的探测时间
        if isStreamURL {
            ctx.pointee.probesize = 5 * 1024 * 1024
            ctx.pointee.max_analyze_duration = Int64(10 * AV_TIME_BASE)
        }
        
        ret = avformat_find_stream_info(ctx, nil)
        guard ret >= 0 else {
            throw FFmpegError.from(code: ret)
        }

        // 找到音频流
        var audioIdx: Int32 = -1
        for i in 0..<Int(ctx.pointee.nb_streams) {
            if let stream = ctx.pointee.streams[i],
               let codecpar = stream.pointee.codecpar,
               codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                audioIdx = Int32(i)
                break
            }
        }
        guard audioIdx >= 0,
              let stream = ctx.pointee.streams[Int(audioIdx)],
              let codecpar = stream.pointee.codecpar else {
            throw FFmpegError.unsupportedFormat(codecName: "未找到音频流")
        }

        // 打开解码器
        let codecID = codecpar.pointee.codec_id
        guard let codec = avcodec_find_decoder(codecID) else {
            throw FFmpegError.unsupportedFormat(codecName: String(cString: avcodec_get_name(codecID)))
        }
        guard let codecCtx = avcodec_alloc_context3(codec) else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVCodecContext")
        }
        defer {
            var p: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&p)
        }

        avcodec_parameters_to_context(codecCtx, codecpar)
        ret = avcodec_open2(codecCtx, codec, nil)
        guard ret >= 0 else { throw FFmpegError.from(code: ret) }

        // 设置 SwrContext 转换为 Float32 mono
        var swrCtx: OpaquePointer?
        var outLayout = AVChannelLayout()
        av_channel_layout_default(&outLayout, 1) // mono
        var inLayout = codecpar.pointee.ch_layout

        swr_alloc_set_opts2(
            &swrCtx, &outLayout, AV_SAMPLE_FMT_FLT, codecCtx.pointee.sample_rate,
            &inLayout, codecCtx.pointee.sample_fmt, codecCtx.pointee.sample_rate,
            0, nil
        )
        guard let swr = swrCtx else {
            throw FFmpegError.resourceAllocationFailed(resource: "SwrContext")
        }
        defer { var s: OpaquePointer? = swr; swr_free(&s) }
        swr_init(swr)

        // 计算目标时长和采样数
        let duration = Double(ctx.pointee.duration) / Double(AV_TIME_BASE)
        let isLiveStream = duration <= 0 || duration > 86400
        
        let targetDuration: TimeInterval
        if isLiveStream {
            targetDuration = maxDuration
        } else {
            targetDuration = maxDuration > 0 ? min(maxDuration, duration) : duration
        }
        
        let sampleRate = Int(codecCtx.pointee.sample_rate)
        let totalSamples = Int(targetDuration * Double(sampleRate))
        let samplesPerBin = max(totalSamples / samplesCount, 1)

        // 解码并提取峰值
        var bins = [[Float]](repeating: [], count: samplesCount)
        var currentSample = 0

        guard let packet = av_packet_alloc() else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVPacket")
        }
        defer { var p: UnsafeMutablePointer<AVPacket>? = packet; av_packet_free(&p) }

        guard let frame = av_frame_alloc() else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFrame")
        }
        defer { var f: UnsafeMutablePointer<AVFrame>? = frame; av_frame_free(&f) }

        // 输出缓冲区
        let outBufSize = 8192
        let outBuf = UnsafeMutablePointer<Float>.allocate(capacity: outBufSize)
        defer { outBuf.deallocate() }

        var readErrors = 0
        let maxReadErrors = 10

        while true {
            ret = av_read_frame(ctx, packet)
            
            if ret < 0 {
                if ret == FFmpegErrorCode.AVERROR_EOF || ret == -Int32(EAGAIN) {
                    break
                }
                readErrors += 1
                if readErrors >= maxReadErrors {
                    break
                }
                continue
            }
            readErrors = 0
            
            defer { av_packet_unref(packet) }
            guard packet.pointee.stream_index == audioIdx else { continue }

            avcodec_send_packet(codecCtx, packet)

            while avcodec_receive_frame(codecCtx, frame) >= 0 {
                let frameCount = Int(frame.pointee.nb_samples)

                var outPtr: UnsafeMutablePointer<UInt8>? = UnsafeMutableRawPointer(outBuf)
                    .bindMemory(to: UInt8.self, capacity: outBufSize * MemoryLayout<Float>.size)
                let inputPtr: UnsafePointer<UnsafePointer<UInt8>?>? = frame.pointee.extended_data.map {
                    UnsafeRawPointer($0).assumingMemoryBound(to: UnsafePointer<UInt8>?.self)
                }

                let converted = swr_convert(swr, &outPtr, Int32(outBufSize), inputPtr, Int32(frameCount))
                guard converted > 0 else { continue }

                for i in 0..<Int(converted) {
                    let binIdx = min(currentSample / samplesPerBin, samplesCount - 1)
                    bins[binIdx].append(outBuf[i])
                    currentSample += 1
                }

                // 进度回调
                if let onProgress = onProgress, totalSamples > 0 {
                    let progress = Float(currentSample) / Float(totalSamples)
                    onProgress(min(progress, 1.0))
                }
                
                // 检查是否达到目标采样数
                if currentSample >= totalSamples {
                    break
                }
            }
            
            if currentSample >= totalSamples {
                break
            }
        }

        // 计算每个 bin 的峰值
        var waveform = [WaveformSample]()
        for bin in bins {
            if bin.isEmpty {
                waveform.append(WaveformSample(positive: 0, negative: 0))
            } else {
                let pos = bin.max() ?? 0
                let neg = bin.min() ?? 0
                waveform.append(WaveformSample(positive: min(pos, 1.0), negative: max(neg, -1.0)))
            }
        }

        return waveform
    }
}
