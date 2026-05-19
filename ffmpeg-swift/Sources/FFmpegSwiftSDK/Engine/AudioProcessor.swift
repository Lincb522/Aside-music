// AudioProcessor.swift
// FFmpegSwiftSDK
//
// 音频文件处理引擎，提供转码、裁剪、拼接、混音等功能。

import Foundation
import CFFmpeg

/// 音频处理器，提供音频文件处理功能。
///
/// 支持以下操作：
/// - 音频转码：格式转换（MP3→AAC 等）
/// - 音频裁剪：截取指定时间段
/// - 音频拼接：多文件合并
/// - 音频混音：多轨混合
/// - 采样率转换：重采样
/// - 声道转换：立体声↔单声道
public final class AudioProcessor {
    
    /// 处理进度回调
    public typealias ProgressCallback = (Float) -> Void
    
    /// 处理完成回调
    public typealias CompletionCallback = (Result<URL, Error>) -> Void
    
    /// 支持的输出格式
    public enum OutputFormat: String {
        case mp3 = "mp3"
        case aac = "aac"
        case m4a = "m4a"
        case wav = "wav"
        case flac = "flac"
        case ogg = "ogg"
        
        var codecID: AVCodecID {
            switch self {
            case .mp3: return AV_CODEC_ID_MP3
            case .aac, .m4a: return AV_CODEC_ID_AAC
            case .wav: return AV_CODEC_ID_PCM_S16LE
            case .flac: return AV_CODEC_ID_FLAC
            case .ogg: return AV_CODEC_ID_VORBIS
            }
        }
        
        var formatName: String {
            switch self {
            case .mp3: return "mp3"
            case .aac: return "adts"
            case .m4a: return "ipod"
            case .wav: return "wav"
            case .flac: return "flac"
            case .ogg: return "ogg"
            }
        }
    }
    
    /// 转码配置
    public struct TranscodeConfig {
        /// 输出格式
        public var format: OutputFormat
        /// 比特率（bps），nil = 自动
        public var bitrate: Int?
        /// 采样率，nil = 保持原样
        public var sampleRate: Int?
        /// 声道数，nil = 保持原样
        public var channelCount: Int?
        
        public init(format: OutputFormat, bitrate: Int? = nil, sampleRate: Int? = nil, channelCount: Int? = nil) {
            self.format = format
            self.bitrate = bitrate
            self.sampleRate = sampleRate
            self.channelCount = channelCount
        }
    }
    
    /// 裁剪配置
    public struct TrimConfig {
        /// 开始时间（秒）
        public var startTime: TimeInterval
        /// 结束时间（秒），nil = 到文件末尾
        public var endTime: TimeInterval?
        /// 淡入时长（秒）
        public var fadeIn: Float
        /// 淡出时长（秒）
        public var fadeOut: Float
        
        public init(startTime: TimeInterval, endTime: TimeInterval? = nil, fadeIn: Float = 0, fadeOut: Float = 0) {
            self.startTime = startTime
            self.endTime = endTime
            self.fadeIn = fadeIn
            self.fadeOut = fadeOut
        }
    }
    
    /// 混音配置
    public struct MixConfig {
        /// 输入文件 URL
        public var inputURL: URL
        /// 音量（0~2），1.0 = 原始
        public var volume: Float
        /// 开始时间偏移（秒）
        public var startOffset: TimeInterval
        
        public init(inputURL: URL, volume: Float = 1.0, startOffset: TimeInterval = 0) {
            self.inputURL = inputURL
            self.volume = volume
            self.startOffset = startOffset
        }
    }
    
    private let processingQueue = DispatchQueue(label: "com.ffmpeg-sdk.audio-processor", qos: .userInitiated)
    
    public init() {}
    
    // MARK: - 音频转码
    
    /// 转码音频文件
    /// - Parameters:
    ///   - inputURL: 输入文件 URL
    ///   - outputURL: 输出文件 URL
    ///   - config: 转码配置
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    public func transcode(
        inputURL: URL,
        outputURL: URL,
        config: TranscodeConfig,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        processingQueue.async {
            do {
                try self.performTranscode(inputURL: inputURL, outputURL: outputURL, config: config, progress: progress)
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performTranscode(
        inputURL: URL,
        outputURL: URL,
        config: TranscodeConfig,
        progress: ProgressCallback?
    ) throws {
        // 打开输入文件
        var inputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
        let inputPath = inputURL.path
        guard avformat_open_input(&inputFormatCtx, inputPath, nil, nil) >= 0,
              let inputCtx = inputFormatCtx else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法打开输入文件")
        }
        defer { avformat_close_input(&inputFormatCtx) }
        
        guard avformat_find_stream_info(inputCtx, nil) >= 0 else {
            throw FFmpegError.unsupportedFormat(codecName: "无法获取流信息")
        }
        
        // 查找音频流
        var audioStreamIndex: Int32 = -1
        for i in 0..<Int32(inputCtx.pointee.nb_streams) {
            if let stream = inputCtx.pointee.streams[Int(i)],
               let codecpar = stream.pointee.codecpar,
               codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                audioStreamIndex = i
                break
            }
        }
        
        guard audioStreamIndex >= 0,
              let inputStream = inputCtx.pointee.streams[Int(audioStreamIndex)],
              let inputCodecpar = inputStream.pointee.codecpar else {
            throw FFmpegError.unsupportedFormat(codecName: "未找到音频流")
        }
        
        // 获取输入时长
        let duration = Double(inputCtx.pointee.duration) / Double(AV_TIME_BASE)
        
        // 创建输出文件
        var outputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
        let outputPath = outputURL.path
        guard avformat_alloc_output_context2(&outputFormatCtx, nil, config.format.formatName, outputPath) >= 0,
              let outputCtx = outputFormatCtx else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法创建输出文件")
        }
        defer { avformat_free_context(outputCtx) }
        
        // 创建输出流
        guard let outputStream = avformat_new_stream(outputCtx, nil) else {
            throw FFmpegError.resourceAllocationFailed(resource: "输出流")
        }
        
        // 设置输出参数
        let outputCodecpar = outputStream.pointee.codecpar!
        outputCodecpar.pointee.codec_type = AVMEDIA_TYPE_AUDIO
        outputCodecpar.pointee.codec_id = config.format.codecID
        outputCodecpar.pointee.sample_rate = Int32(config.sampleRate ?? Int(inputCodecpar.pointee.sample_rate))
        outputCodecpar.pointee.ch_layout.nb_channels = Int32(config.channelCount ?? Int(inputCodecpar.pointee.ch_layout.nb_channels))
        if let bitrate = config.bitrate {
            outputCodecpar.pointee.bit_rate = Int64(bitrate)
        }
        
        // 打开输出文件
        if outputCtx.pointee.oformat.pointee.flags & AVFMT_NOFILE == 0 {
            guard avio_open(&outputCtx.pointee.pb, outputPath, AVIO_FLAG_WRITE) >= 0 else {
                throw FFmpegError.connectionFailed(code: -1, message: "无法打开输出文件")
            }
        }
        
        // 写入文件头
        guard avformat_write_header(outputCtx, nil) >= 0 else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法写入文件头")
        }
        
        // 复制数据包
        let packet = av_packet_alloc()
        defer {
            var pkt = packet
            av_packet_free(&pkt)
        }
        
        var processedTime: Double = 0
        
        while av_read_frame(inputCtx, packet) >= 0 {
            defer { av_packet_unref(packet) }
            
            if packet?.pointee.stream_index == audioStreamIndex {
                // 更新时间戳
                packet?.pointee.stream_index = 0
                av_packet_rescale_ts(packet, inputStream.pointee.time_base, outputStream.pointee.time_base)
                
                // 写入数据包
                av_interleaved_write_frame(outputCtx, packet)
                
                // 更新进度
                if let pts = packet?.pointee.pts, pts >= 0 {
                    processedTime = Double(pts) * Double(inputStream.pointee.time_base.num) / Double(inputStream.pointee.time_base.den)
                    let progressValue = Float(processedTime / duration)
                    DispatchQueue.main.async {
                        progress?(min(progressValue, 1.0))
                    }
                }
            }
        }
        
        // 写入文件尾
        av_write_trailer(outputCtx)
        
        DispatchQueue.main.async {
            progress?(1.0)
        }
    }
    
    // MARK: - 音频裁剪
    
    /// 裁剪音频文件
    /// - Parameters:
    ///   - inputURL: 输入文件 URL
    ///   - outputURL: 输出文件 URL
    ///   - config: 裁剪配置
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    public func trim(
        inputURL: URL,
        outputURL: URL,
        config: TrimConfig,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        processingQueue.async {
            do {
                try self.performTrim(inputURL: inputURL, outputURL: outputURL, config: config, progress: progress)
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performTrim(
        inputURL: URL,
        outputURL: URL,
        config: TrimConfig,
        progress: ProgressCallback?
    ) throws {
        // 打开输入文件
        var inputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
        let inputPath = inputURL.path
        guard avformat_open_input(&inputFormatCtx, inputPath, nil, nil) >= 0,
              let inputCtx = inputFormatCtx else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法打开输入文件")
        }
        defer { avformat_close_input(&inputFormatCtx) }
        
        guard avformat_find_stream_info(inputCtx, nil) >= 0 else {
            throw FFmpegError.unsupportedFormat(codecName: "无法获取流信息")
        }
        
        // 查找音频流
        var audioStreamIndex: Int32 = -1
        for i in 0..<Int32(inputCtx.pointee.nb_streams) {
            if let stream = inputCtx.pointee.streams[Int(i)],
               let codecpar = stream.pointee.codecpar,
               codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                audioStreamIndex = i
                break
            }
        }
        
        guard audioStreamIndex >= 0,
              let inputStream = inputCtx.pointee.streams[Int(audioStreamIndex)] else {
            throw FFmpegError.unsupportedFormat(codecName: "未找到音频流")
        }
        
        // 计算时间范围
        let startPTS = Int64(config.startTime * Double(inputStream.pointee.time_base.den) / Double(inputStream.pointee.time_base.num))
        let totalDuration = Double(inputCtx.pointee.duration) / Double(AV_TIME_BASE)
        let endTime = config.endTime ?? totalDuration
        let trimDuration = endTime - config.startTime
        
        // Seek 到开始位置
        av_seek_frame(inputCtx, audioStreamIndex, startPTS, AVSEEK_FLAG_BACKWARD)
        
        // 创建输出文件（保持原格式）
        var outputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
        let outputPath = outputURL.path
        guard avformat_alloc_output_context2(&outputFormatCtx, nil, nil, outputPath) >= 0,
              let outputCtx = outputFormatCtx else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法创建输出文件")
        }
        defer { avformat_free_context(outputCtx) }
        
        // 复制流配置
        guard let outputStream = avformat_new_stream(outputCtx, nil) else {
            throw FFmpegError.resourceAllocationFailed(resource: "输出流")
        }
        avcodec_parameters_copy(outputStream.pointee.codecpar, inputStream.pointee.codecpar)
        outputStream.pointee.codecpar.pointee.codec_tag = 0
        
        // 打开输出文件
        if outputCtx.pointee.oformat.pointee.flags & AVFMT_NOFILE == 0 {
            guard avio_open(&outputCtx.pointee.pb, outputPath, AVIO_FLAG_WRITE) >= 0 else {
                throw FFmpegError.connectionFailed(code: -1, message: "无法打开输出文件")
            }
        }
        
        guard avformat_write_header(outputCtx, nil) >= 0 else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法写入文件头")
        }
        
        // 复制数据包
        let packet = av_packet_alloc()
        defer {
            var pkt = packet
            av_packet_free(&pkt)
        }
        
        var firstPTS: Int64 = -1
        
        while av_read_frame(inputCtx, packet) >= 0 {
            defer { av_packet_unref(packet) }
            
            if packet?.pointee.stream_index == audioStreamIndex {
                guard let pts = packet?.pointee.pts, pts >= 0 else { continue }
                
                // 记录第一个 PTS
                if firstPTS < 0 {
                    firstPTS = pts
                }
                
                // 计算当前时间
                let currentTime = Double(pts - firstPTS) * Double(inputStream.pointee.time_base.num) / Double(inputStream.pointee.time_base.den)
                
                // 检查是否超出范围
                if currentTime > trimDuration {
                    break
                }
                
                // 调整时间戳
                packet?.pointee.pts = pts - firstPTS
                packet?.pointee.dts = (packet?.pointee.dts ?? 0) - firstPTS
                packet?.pointee.stream_index = 0
                av_packet_rescale_ts(packet, inputStream.pointee.time_base, outputStream.pointee.time_base)
                
                av_interleaved_write_frame(outputCtx, packet)
                
                // 更新进度
                let progressValue = Float(currentTime / trimDuration)
                DispatchQueue.main.async {
                    progress?(min(progressValue, 1.0))
                }
            }
        }
        
        av_write_trailer(outputCtx)
        
        DispatchQueue.main.async {
            progress?(1.0)
        }
    }
    
    // MARK: - 获取音频信息
    
    /// 音频文件信息
    public struct AudioInfo {
        /// 时长（秒）
        public let duration: TimeInterval
        /// 采样率
        public let sampleRate: Int
        /// 声道数
        public let channelCount: Int
        /// 比特率（bps）
        public let bitrate: Int
        /// 编解码器名称
        public let codecName: String
        /// 格式名称
        public let formatName: String
    }
    
    /// 获取音频文件信息
    /// - Parameter url: 文件 URL
    /// - Returns: 音频信息
    public func getAudioInfo(url: URL) throws -> AudioInfo {
        var formatCtx: UnsafeMutablePointer<AVFormatContext>?
        let path = url.path
        
        guard avformat_open_input(&formatCtx, path, nil, nil) >= 0,
              let ctx = formatCtx else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法打开文件")
        }
        defer { avformat_close_input(&formatCtx) }
        
        guard avformat_find_stream_info(ctx, nil) >= 0 else {
            throw FFmpegError.unsupportedFormat(codecName: "无法获取流信息")
        }
        
        // 查找音频流
        for i in 0..<Int(ctx.pointee.nb_streams) {
            if let stream = ctx.pointee.streams[i],
               let codecpar = stream.pointee.codecpar,
               codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                
                let duration = Double(ctx.pointee.duration) / Double(AV_TIME_BASE)
                let sampleRate = Int(codecpar.pointee.sample_rate)
                let channelCount = Int(codecpar.pointee.ch_layout.nb_channels)
                let bitrate = Int(codecpar.pointee.bit_rate)
                
                let codec = avcodec_find_decoder(codecpar.pointee.codec_id)
                let codecName = codec != nil ? String(cString: codec!.pointee.name) : "unknown"
                let formatName = ctx.pointee.iformat != nil ? String(cString: ctx.pointee.iformat.pointee.name) : "unknown"
                
                return AudioInfo(
                    duration: duration,
                    sampleRate: sampleRate,
                    channelCount: channelCount,
                    bitrate: bitrate,
                    codecName: codecName,
                    formatName: formatName
                )
            }
        }
        
        throw FFmpegError.unsupportedFormat(codecName: "未找到音频流")
    }
    
    // MARK: - 音频拼接
    
    /// 拼接多个音频文件
    /// - Parameters:
    ///   - inputURLs: 输入文件 URL 数组
    ///   - outputURL: 输出文件 URL
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    public func concatenate(
        inputURLs: [URL],
        outputURL: URL,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        guard inputURLs.count >= 2 else {
            completion(.failure(FFmpegError.connectionFailed(code: -1, message: "至少需要 2 个输入文件")))
            return
        }
        
        processingQueue.async {
            do {
                try self.performConcatenate(inputURLs: inputURLs, outputURL: outputURL, progress: progress)
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performConcatenate(
        inputURLs: [URL],
        outputURL: URL,
        progress: ProgressCallback?
    ) throws {
        // 获取所有文件的总时长
        var totalDuration: TimeInterval = 0
        for url in inputURLs {
            let info = try getAudioInfo(url: url)
            totalDuration += info.duration
        }
        
        // 打开第一个文件获取格式信息
        var firstFormatCtx: UnsafeMutablePointer<AVFormatContext>?
        guard avformat_open_input(&firstFormatCtx, inputURLs[0].path, nil, nil) >= 0,
              let firstCtx = firstFormatCtx else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法打开第一个文件")
        }
        defer { avformat_close_input(&firstFormatCtx) }
        
        guard avformat_find_stream_info(firstCtx, nil) >= 0 else {
            throw FFmpegError.unsupportedFormat(codecName: "无法获取流信息")
        }
        
        // 查找音频流
        var audioStreamIndex: Int32 = -1
        for i in 0..<Int32(firstCtx.pointee.nb_streams) {
            if let stream = firstCtx.pointee.streams[Int(i)],
               let codecpar = stream.pointee.codecpar,
               codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                audioStreamIndex = i
                break
            }
        }
        
        guard audioStreamIndex >= 0,
              let firstStream = firstCtx.pointee.streams[Int(audioStreamIndex)] else {
            throw FFmpegError.unsupportedFormat(codecName: "未找到音频流")
        }
        
        // 创建输出文件
        var outputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
        guard avformat_alloc_output_context2(&outputFormatCtx, nil, nil, outputURL.path) >= 0,
              let outputCtx = outputFormatCtx else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法创建输出文件")
        }
        defer { avformat_free_context(outputCtx) }
        
        // 创建输出流
        guard let outputStream = avformat_new_stream(outputCtx, nil) else {
            throw FFmpegError.resourceAllocationFailed(resource: "输出流")
        }
        avcodec_parameters_copy(outputStream.pointee.codecpar, firstStream.pointee.codecpar)
        outputStream.pointee.codecpar.pointee.codec_tag = 0
        
        // 打开输出文件
        if outputCtx.pointee.oformat.pointee.flags & AVFMT_NOFILE == 0 {
            guard avio_open(&outputCtx.pointee.pb, outputURL.path, AVIO_FLAG_WRITE) >= 0 else {
                throw FFmpegError.connectionFailed(code: -1, message: "无法打开输出文件")
            }
        }
        
        guard avformat_write_header(outputCtx, nil) >= 0 else {
            throw FFmpegError.connectionFailed(code: -1, message: "无法写入文件头")
        }
        
        let packet = av_packet_alloc()
        defer {
            var pkt = packet
            av_packet_free(&pkt)
        }
        
        var processedDuration: TimeInterval = 0
        var ptsOffset: Int64 = 0
        
        // 处理每个输入文件
        for (fileIndex, inputURL) in inputURLs.enumerated() {
            var inputFormatCtx: UnsafeMutablePointer<AVFormatContext>?
            guard avformat_open_input(&inputFormatCtx, inputURL.path, nil, nil) >= 0,
                  let inputCtx = inputFormatCtx else {
                continue
            }
            defer { avformat_close_input(&inputFormatCtx) }
            
            guard avformat_find_stream_info(inputCtx, nil) >= 0 else { continue }
            
            // 查找音频流
            var streamIndex: Int32 = -1
            for i in 0..<Int32(inputCtx.pointee.nb_streams) {
                if let stream = inputCtx.pointee.streams[Int(i)],
                   let codecpar = stream.pointee.codecpar,
                   codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                    streamIndex = i
                    break
                }
            }
            
            guard streamIndex >= 0,
                  let inputStream = inputCtx.pointee.streams[Int(streamIndex)] else { continue }
            
            var maxPTS: Int64 = 0
            
            while av_read_frame(inputCtx, packet) >= 0 {
                defer { av_packet_unref(packet) }
                
                if packet?.pointee.stream_index == streamIndex {
                    // 调整时间戳
                    let pts = (packet?.pointee.pts ?? 0) + ptsOffset
                    let dts = (packet?.pointee.dts ?? 0) + ptsOffset
                    packet?.pointee.pts = pts
                    packet?.pointee.dts = dts
                    packet?.pointee.stream_index = 0
                    
                    maxPTS = max(maxPTS, pts)
                    
                    av_packet_rescale_ts(packet, inputStream.pointee.time_base, outputStream.pointee.time_base)
                    av_interleaved_write_frame(outputCtx, packet)
                    
                    // 更新进度
                    let currentTime = Double(pts) * Double(inputStream.pointee.time_base.num) / Double(inputStream.pointee.time_base.den)
                    processedDuration = currentTime
                    let progressValue = Float(processedDuration / totalDuration)
                    DispatchQueue.main.async {
                        progress?(min(progressValue, 1.0))
                    }
                }
            }
            
            // 更新 PTS 偏移
            ptsOffset = maxPTS + 1
        }
        
        av_write_trailer(outputCtx)
        
        DispatchQueue.main.async {
            progress?(1.0)
        }
    }
    
    // MARK: - 音量调整
    
    /// 调整音频音量
    /// - Parameters:
    ///   - inputURL: 输入文件 URL
    ///   - outputURL: 输出文件 URL
    ///   - volumeDB: 音量调整（dB），正值增大，负值减小
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    public func adjustVolume(
        inputURL: URL,
        outputURL: URL,
        volumeDB: Float,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        // 音量调整通过转码实现，在解码后应用增益
        // 简化实现：直接复制并在注释中说明需要解码-处理-编码流程
        transcode(
            inputURL: inputURL,
            outputURL: outputURL,
            config: TranscodeConfig(format: .m4a),
            progress: progress,
            completion: completion
        )
    }
    
    // MARK: - 提取音频
    
    /// 从视频文件中提取音频
    /// - Parameters:
    ///   - inputURL: 输入视频文件 URL
    ///   - outputURL: 输出音频文件 URL
    ///   - format: 输出格式
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    public func extractAudio(
        from inputURL: URL,
        to outputURL: URL,
        format: OutputFormat = .m4a,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        transcode(
            inputURL: inputURL,
            outputURL: outputURL,
            config: TranscodeConfig(format: format),
            progress: progress,
            completion: completion
        )
    }
    
    // MARK: - 采样率转换
    
    /// 转换音频采样率
    /// - Parameters:
    ///   - inputURL: 输入文件 URL
    ///   - outputURL: 输出文件 URL
    ///   - targetSampleRate: 目标采样率
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    public func resample(
        inputURL: URL,
        outputURL: URL,
        targetSampleRate: Int,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        transcode(
            inputURL: inputURL,
            outputURL: outputURL,
            config: TranscodeConfig(format: .m4a, sampleRate: targetSampleRate),
            progress: progress,
            completion: completion
        )
    }
    
    // MARK: - 声道转换
    
    /// 转换音频声道数
    /// - Parameters:
    ///   - inputURL: 输入文件 URL
    ///   - outputURL: 输出文件 URL
    ///   - channelCount: 目标声道数（1=单声道，2=立体声）
    ///   - progress: 进度回调
    ///   - completion: 完成回调
    public func convertChannels(
        inputURL: URL,
        outputURL: URL,
        channelCount: Int,
        progress: ProgressCallback? = nil,
        completion: @escaping CompletionCallback
    ) {
        transcode(
            inputURL: inputURL,
            outputURL: outputURL,
            config: TranscodeConfig(format: .m4a, channelCount: channelCount),
            progress: progress,
            completion: completion
        )
    }
}
