// AudioFingerprint.swift
// FFmpegSwiftSDK
//
// 音频指纹生成器，用于歌曲识别。
// 基于频谱峰值的音频指纹算法（类似 Shazam）。

import Foundation
import Accelerate
import CFFmpeg

/// 音频指纹生成器，用于歌曲识别和音频匹配。
///
/// 基于频谱峰值的音频指纹算法：
/// 1. 将音频转换为频谱图
/// 2. 在每个时间窗口中找到频率峰值
/// 3. 将相邻峰值配对生成哈希值
/// 4. 哈希值集合构成音频指纹
///
/// 用法：
/// ```swift
/// // 生成指纹
/// let fingerprint = AudioFingerprint.generate(samples: audioSamples, sampleRate: 44100)
///
/// // 比较两个指纹
/// let similarity = AudioFingerprint.compare(fingerprint1, fingerprint2)
///
/// // 在数据库中搜索
/// let matches = fingerprint.searchIn(database: fingerprintDB)
/// ```
public final class AudioFingerprint {
    
    // MARK: - 类型定义
    
    /// 单个指纹哈希
    public struct Hash: Hashable, Codable {
        /// 锚点频率（Hz）
        public let anchorFrequency: UInt16
        /// 目标频率（Hz）
        public let targetFrequency: UInt16
        /// 时间差（帧数）
        public let timeDelta: UInt16
        /// 锚点时间（帧索引）
        public let anchorTime: UInt32
        
        /// 32 位哈希值
        public var hashValue32: UInt32 {
            return UInt32(anchorFrequency) << 20 |
                   UInt32(targetFrequency) << 8 |
                   UInt32(timeDelta)
        }
    }
    
    /// 频谱峰值
    private struct Peak {
        let frequency: Int      // 频率 bin 索引
        let time: Int           // 时间帧索引
        let magnitude: Float    // 幅度
    }
    
    /// 指纹数据
    public struct Fingerprint: Codable {
        /// 哈希值数组
        public let hashes: [Hash]
        /// 音频时长（秒）
        public let duration: TimeInterval
        /// 采样率
        public let sampleRate: Int
        /// 生成时间
        public let createdAt: Date
        
        public init(hashes: [Hash], duration: TimeInterval, sampleRate: Int) {
            self.hashes = hashes
            self.duration = duration
            self.sampleRate = sampleRate
            self.createdAt = Date()
        }
    }
    
    /// 匹配结果
    public struct MatchResult {
        /// 匹配的指纹 ID
        public let fingerprintID: String
        /// 匹配分数（0~1）
        public let score: Float
        /// 匹配的哈希数量
        public let matchedHashes: Int
        /// 时间偏移（秒）
        public let timeOffset: TimeInterval
        /// 置信度
        public let confidence: Float
    }
    
    // MARK: - 配置参数
    
    /// FFT 窗口大小
    private static let fftSize = 4096
    /// 窗口重叠率
    private static let overlapRatio: Float = 0.5
    /// 每个频段的峰值数量
    private static let peaksPerBand = 5
    /// 目标区域时间范围（帧数）
    private static let targetZoneFrames = 5
    /// 目标区域频率范围（bin 数）
    private static let targetZoneBins = 100
    /// 频段边界（Hz）
    private static let bandBoundaries = [0, 100, 200, 400, 800, 1600, 3200, 6400, 12800]
    
    // MARK: - 指纹生成
    
    /// 从音频采样生成指纹
    /// - Parameters:
    ///   - samples: 音频采样数据（Float32，单声道）
    ///   - sampleRate: 采样率
    /// - Returns: 音频指纹
    public static func generate(samples: [Float], sampleRate: Int) -> Fingerprint {
        let duration = Double(samples.count) / Double(sampleRate)
        
        // 1. 生成频谱图并提取峰值
        let peaks = extractPeaks(samples: samples, sampleRate: sampleRate)
        
        // 2. 生成哈希值
        let hashes = generateHashes(peaks: peaks, sampleRate: sampleRate)
        
        return Fingerprint(hashes: hashes, duration: duration, sampleRate: sampleRate)
    }
    
    /// 从音频文件或流媒体生成指纹
    /// - Parameters:
    ///   - url: 音频文件或流媒体 URL
    ///   - duration: 采样时长（秒），nil = 整首歌（流媒体默认 30 秒）
    /// - Returns: 音频指纹
    public static func generate(from url: URL, duration: TimeInterval? = nil) throws -> Fingerprint {
        // 直接解码音频文件获取采样数据
        let (samples, sampleRate) = try decodeAudioFile(url: url.absoluteString, maxDuration: duration)
        return generate(samples: samples, sampleRate: sampleRate)
    }
    
    /// 从 URL 字符串生成指纹（支持流媒体）
    /// - Parameters:
    ///   - urlString: 音频文件或流媒体 URL 字符串
    ///   - duration: 采样时长（秒），nil = 整首歌（流媒体默认 30 秒）
    /// - Returns: 音频指纹
    public static func generate(from urlString: String, duration: TimeInterval? = nil) throws -> Fingerprint {
        let (samples, sampleRate) = try decodeAudioFile(url: urlString, maxDuration: duration)
        return generate(samples: samples, sampleRate: sampleRate)
    }
    
    /// 解码音频文件获取采样数据（支持流媒体）
    private static func decodeAudioFile(url: String, maxDuration: TimeInterval?) throws -> (samples: [Float], sampleRate: Int) {
        // 检测是否为流媒体 URL
        let isStreamURL = url.lowercased().hasPrefix("http://") ||
                          url.lowercased().hasPrefix("https://") ||
                          url.lowercased().hasPrefix("rtmp://") ||
                          url.lowercased().hasPrefix("rtsp://") ||
                          url.lowercased().hasPrefix("mms://")
        
        // 设置网络选项
        var options: OpaquePointer?
        if isStreamURL {
            av_dict_set(&options, "timeout", "10000000", 0)
            av_dict_set(&options, "reconnect", "1", 0)
            av_dict_set(&options, "reconnect_streamed", "1", 0)
        }
        defer { av_dict_free(&options) }
        
        var fmtCtx: UnsafeMutablePointer<AVFormatContext>?
        var ret = avformat_open_input(&fmtCtx, url, nil, &options)
        guard ret >= 0, let ctx = fmtCtx else {
            throw FFmpegError.connectionFailed(code: ret, message: "无法打开: \(url)")
        }
        defer { avformat_close_input(&fmtCtx) }
        
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
        
        let sampleRate = Int(codecpar.pointee.sample_rate)
        
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
            &swrCtx, &outLayout, AV_SAMPLE_FMT_FLT, Int32(sampleRate),
            &inLayout, codecCtx.pointee.sample_fmt, Int32(sampleRate),
            0, nil
        )
        guard let swr = swrCtx else {
            throw FFmpegError.resourceAllocationFailed(resource: "SwrContext")
        }
        defer { var s: OpaquePointer? = swr; swr_free(&s) }
        swr_init(swr)
        
        // 计算目标采样数
        let duration = Double(ctx.pointee.duration) / Double(AV_TIME_BASE)
        let isLiveStream = duration <= 0 || duration > 86400
        
        let targetDuration: TimeInterval
        if let dur = maxDuration {
            targetDuration = dur
        } else if isLiveStream {
            targetDuration = 30.0  // 流媒体默认 30 秒
        } else {
            targetDuration = duration
        }
        
        let maxSamples = Int(targetDuration * Double(sampleRate))
        
        var allSamples: [Float] = []
        allSamples.reserveCapacity(min(maxSamples, sampleRate * 120))
        
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
        
        decodeLoop: while true {
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
                    allSamples.append(outBuf[i])
                    
                    // 检查是否达到最大采样数
                    if allSamples.count >= maxSamples {
                        break decodeLoop
                    }
                }
            }
        }
        
        return (allSamples, sampleRate)
    }
    
    // MARK: - 指纹比较
    
    /// 比较两个指纹的相似度
    /// - Parameters:
    ///   - fp1: 指纹 1
    ///   - fp2: 指纹 2
    /// - Returns: 相似度（0~1）
    public static func compare(_ fp1: Fingerprint, _ fp2: Fingerprint) -> Float {
        guard !fp1.hashes.isEmpty && !fp2.hashes.isEmpty else { return 0 }
        
        // 构建哈希集合
        let hashSet1 = Set(fp1.hashes.map { $0.hashValue32 })
        let hashSet2 = Set(fp2.hashes.map { $0.hashValue32 })
        
        // 计算交集
        let intersection = hashSet1.intersection(hashSet2)
        let union = hashSet1.union(hashSet2)
        
        // Jaccard 相似度
        return Float(intersection.count) / Float(union.count)
    }
    
    /// 在指纹数据库中搜索匹配
    /// - Parameters:
    ///   - query: 查询指纹
    ///   - database: 指纹数据库（ID -> Fingerprint）
    ///   - threshold: 匹配阈值（0~1）
    /// - Returns: 匹配结果数组，按分数降序排列
    public static func search(
        query: Fingerprint,
        in database: [String: Fingerprint],
        threshold: Float = 0.1
    ) -> [MatchResult] {
        var results: [MatchResult] = []
        
        // 构建查询哈希表
        var queryHashMap: [UInt32: [Hash]] = [:]
        for hash in query.hashes {
            let key = hash.hashValue32
            queryHashMap[key, default: []].append(hash)
        }
        
        for (id, fingerprint) in database {
            // 统计匹配的哈希
            var matchedHashes = 0
            var timeOffsets: [Int] = []
            
            for hash in fingerprint.hashes {
                let key = hash.hashValue32
                if let queryHashes = queryHashMap[key] {
                    matchedHashes += 1
                    // 计算时间偏移
                    for qh in queryHashes {
                        let offset = Int(hash.anchorTime) - Int(qh.anchorTime)
                        timeOffsets.append(offset)
                    }
                }
            }
            
            guard matchedHashes > 0 else { continue }
            
            // 计算分数
            let score = Float(matchedHashes) / Float(max(query.hashes.count, fingerprint.hashes.count))
            
            guard score >= threshold else { continue }
            
            // 计算最常见的时间偏移（投票）
            let offsetCounts = Dictionary(grouping: timeOffsets, by: { $0 }).mapValues { $0.count }
            let bestOffset = offsetCounts.max(by: { $0.value < $1.value })?.key ?? 0
            let bestOffsetCount = offsetCounts[bestOffset] ?? 0
            
            // 置信度：最佳偏移的投票数 / 总匹配数
            let confidence = Float(bestOffsetCount) / Float(matchedHashes)
            
            // 时间偏移转换为秒
            let hopSize = Int(Float(fftSize) * (1 - overlapRatio))
            let timeOffset = Double(bestOffset * hopSize) / Double(fingerprint.sampleRate)
            
            results.append(MatchResult(
                fingerprintID: id,
                score: score,
                matchedHashes: matchedHashes,
                timeOffset: timeOffset,
                confidence: confidence
            ))
        }
        
        // 按分数降序排列
        return results.sorted { $0.score > $1.score }
    }
    
    // MARK: - 私有方法
    
    /// 提取频谱峰值
    private static func extractPeaks(samples: [Float], sampleRate: Int) -> [Peak] {
        let hopSize = Int(Float(fftSize) * (1 - overlapRatio))
        let numFrames = (samples.count - fftSize) / hopSize + 1
        
        guard numFrames > 0 else { return [] }
        
        var allPeaks: [Peak] = []
        let binWidth = Float(sampleRate) / Float(fftSize)
        
        // 汉宁窗
        var window = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            window[i] = 0.5 * (1 - cosf(2 * .pi * Float(i) / Float(fftSize - 1)))
        }
        
        // 处理每一帧
        for frameIndex in 0..<numFrames {
            let startIndex = frameIndex * hopSize
            guard startIndex + fftSize <= samples.count else { break }
            
            // 应用窗函数
            var windowedSamples = [Float](repeating: 0, count: fftSize)
            for i in 0..<fftSize {
                windowedSamples[i] = samples[startIndex + i] * window[i]
            }
            
            // 简化 DFT（只计算需要的频率范围）
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            for k in 0..<(fftSize / 2) {
                var real: Float = 0
                var imag: Float = 0
                let freq = Float(k) * 2.0 * .pi / Float(fftSize)
                
                for n in 0..<fftSize {
                    real += windowedSamples[n] * cosf(freq * Float(n))
                    imag -= windowedSamples[n] * sinf(freq * Float(n))
                }
                
                magnitudes[k] = sqrtf(real * real + imag * imag)
            }
            
            // 在每个频段中找峰值
            for bandIndex in 0..<(bandBoundaries.count - 1) {
                let lowFreq = bandBoundaries[bandIndex]
                let highFreq = bandBoundaries[bandIndex + 1]
                let lowBin = Int(Float(lowFreq) / binWidth)
                let highBin = min(Int(Float(highFreq) / binWidth), fftSize / 2 - 1)
                
                guard lowBin < highBin else { continue }
                
                // 找这个频段的峰值
                var bandPeaks: [(bin: Int, mag: Float)] = []
                for bin in (lowBin + 1)..<highBin {
                    let mag = magnitudes[bin]
                    // 局部最大值
                    if mag > magnitudes[bin - 1] && mag > magnitudes[bin + 1] && mag > 0.01 {
                        bandPeaks.append((bin, mag))
                    }
                }
                
                // 取幅度最大的几个
                bandPeaks.sort { $0.mag > $1.mag }
                for i in 0..<min(peaksPerBand, bandPeaks.count) {
                    allPeaks.append(Peak(
                        frequency: bandPeaks[i].bin,
                        time: frameIndex,
                        magnitude: bandPeaks[i].mag
                    ))
                }
            }
        }
        
        return allPeaks
    }
    
    /// 从峰值生成哈希
    private static func generateHashes(peaks: [Peak], sampleRate: Int) -> [Hash] {
        guard peaks.count > 1 else { return [] }
        
        // 按时间排序
        let sortedPeaks = peaks.sorted { $0.time < $1.time }
        
        var hashes: [Hash] = []
        let binWidth = Float(sampleRate) / Float(fftSize)
        
        // 对每个锚点，在目标区域内找配对点
        for (i, anchor) in sortedPeaks.enumerated() {
            for j in (i + 1)..<sortedPeaks.count {
                let target = sortedPeaks[j]
                
                // 检查是否在目标区域内
                let timeDelta = target.time - anchor.time
                let freqDelta = abs(target.frequency - anchor.frequency)
                
                if timeDelta > 0 && timeDelta <= targetZoneFrames && freqDelta <= targetZoneBins {
                    let anchorFreq = UInt16(Float(anchor.frequency) * binWidth)
                    let targetFreq = UInt16(Float(target.frequency) * binWidth)
                    
                    hashes.append(Hash(
                        anchorFrequency: anchorFreq,
                        targetFrequency: targetFreq,
                        timeDelta: UInt16(timeDelta),
                        anchorTime: UInt32(anchor.time)
                    ))
                }
            }
        }
        
        return hashes
    }
}

// MARK: - 指纹数据库

/// 音频指纹数据库，用于存储和检索指纹
public final class FingerprintDatabase {
    
    /// 数据库条目
    public struct Entry: Codable {
        /// 唯一 ID
        public let id: String
        /// 歌曲标题
        public let title: String
        /// 艺术家
        public let artist: String
        /// 专辑
        public let album: String?
        /// 指纹数据
        public let fingerprint: AudioFingerprint.Fingerprint
        /// 添加时间
        public let addedAt: Date
        
        public init(id: String, title: String, artist: String, album: String? = nil, fingerprint: AudioFingerprint.Fingerprint) {
            self.id = id
            self.title = title
            self.artist = artist
            self.album = album
            self.fingerprint = fingerprint
            self.addedAt = Date()
        }
    }
    
    /// 识别结果
    public struct RecognitionResult {
        /// 歌曲 ID
        public let id: String
        /// 歌曲标题
        public let title: String
        /// 艺术家
        public let artist: String
        /// 专辑
        public let album: String?
        /// 匹配分数（0~1）
        public let score: Float
        /// 置信度
        public let confidence: Float
        /// 匹配位置（秒）
        public let matchPosition: TimeInterval
    }
    
    private var entries: [String: Entry] = [:]
    private var fingerprintMap: [String: AudioFingerprint.Fingerprint] = [:]
    private let lock = NSLock()
    
    public init() {}
    
    /// 添加歌曲到数据库
    public func add(entry: Entry) {
        lock.lock()
        entries[entry.id] = entry
        fingerprintMap[entry.id] = entry.fingerprint
        lock.unlock()
    }
    
    /// 从数据库移除歌曲
    public func remove(id: String) {
        lock.lock()
        entries.removeValue(forKey: id)
        fingerprintMap.removeValue(forKey: id)
        lock.unlock()
    }
    
    /// 识别音频
    /// - Parameters:
    ///   - samples: 音频采样（单声道）
    ///   - sampleRate: 采样率
    /// - Returns: 识别结果，nil = 未识别
    public func recognize(samples: [Float], sampleRate: Int) -> RecognitionResult? {
        let queryFingerprint = AudioFingerprint.generate(samples: samples, sampleRate: sampleRate)
        
        lock.lock()
        let db = fingerprintMap
        let allEntries = entries
        lock.unlock()
        
        let matches = AudioFingerprint.search(query: queryFingerprint, in: db, threshold: 0.05)
        
        guard let best = matches.first, best.score > 0.1 else { return nil }
        
        guard let entry = allEntries[best.fingerprintID] else { return nil }
        
        return RecognitionResult(
            id: entry.id,
            title: entry.title,
            artist: entry.artist,
            album: entry.album,
            score: best.score,
            confidence: best.confidence,
            matchPosition: best.timeOffset
        )
    }
    
    /// 数据库中的歌曲数量
    public var count: Int {
        lock.lock()
        let c = entries.count
        lock.unlock()
        return c
    }
    
    /// 导出数据库
    public func export() throws -> Data {
        lock.lock()
        let data = Array(entries.values)
        lock.unlock()
        return try JSONEncoder().encode(data)
    }
    
    /// 导入数据库
    public func importData(_ data: Data) throws {
        let imported = try JSONDecoder().decode([Entry].self, from: data)
        lock.lock()
        for entry in imported {
            entries[entry.id] = entry
            fingerprintMap[entry.id] = entry.fingerprint
        }
        lock.unlock()
    }
}
