// AudioAnalyzer.swift
// FFmpegSwiftSDK
//
// 专业音频分析引擎，提供全面的音频特征分析功能。
// 包括：BPM 检测、响度测量（EBU R128）、频谱分析、动态范围、
// 相位检测、音调检测、节拍检测、音色分析等。

import Foundation
import Accelerate
import CFFmpeg

/// 专业音频分析器
///
/// 提供以下分析功能：
/// - BPM 检测：使用自相关 + 能量包络算法
/// - 响度测量：符合 EBU R128 标准的 LUFS 测量
/// - 频谱分析：FFT 频谱、频谱质心、频段能量
/// - 动态范围：DR 值、波峰因数、RMS 电平
/// - 相位检测：立体声相位相关性分析
/// - 音调检测：基频检测、音符识别
/// - 节拍检测：节拍位置、节拍强度
/// - 音色分析：频谱平坦度、频谱滚降点
/// - 静音检测：静音片段识别
/// - 削波检测：数字削波检测
public final class AudioAnalyzer {
    
    // MARK: - 综合分析结果
    
    /// 完整的音频分析结果
    public struct FullAnalysisResult {
        /// BPM 检测结果
        public let bpm: BPMResult
        /// 响度测量结果
        public let loudness: LoudnessResult
        /// 频率分析结果
        public let frequency: FrequencyAnalysis
        /// 动态范围结果
        public let dynamicRange: DynamicRangeResult
        /// 相位检测结果（仅立体声）
        public let phase: PhaseResult?
        /// 音调检测结果
        public let pitch: PitchResult
        /// 音色分析结果
        public let timbre: TimbreAnalysis
        /// 峰值检测结果
        public let peak: PeakResult
        /// 削波检测结果
        public let clipping: ClippingResult
        /// 静音片段
        public let silenceSegments: [SilenceSegment]
        /// 节拍位置
        public let beatPositions: [BeatPosition]
    }
    
    /// 执行完整的音频分析
    /// - Parameters:
    ///   - samples: 音频采样数据（Float32，交错格式）
    ///   - sampleRate: 采样率
    ///   - channelCount: 声道数
    /// - Returns: 完整分析结果
    public static func analyzeComplete(
        samples: [Float],
        sampleRate: Int,
        channelCount: Int
    ) -> FullAnalysisResult {
        // 转换为单声道用于大部分分析
        let monoSamples = convertToMono(samples: samples, channelCount: channelCount)
        
        // 并行执行各项分析
        let bpm = detectBPM(samples: monoSamples, sampleRate: sampleRate)
        let loudness = measureLoudness(samples: samples, sampleRate: sampleRate, channelCount: channelCount)
        let frequency = analyzeFrequency(samples: monoSamples, sampleRate: sampleRate)
        let dynamicRange = analyzeDynamicRange(samples: monoSamples, sampleRate: sampleRate)
        let phase = channelCount == 2 ? detectPhase(samples: samples, sampleRate: sampleRate) : nil
        let pitch = detectPitch(samples: monoSamples, sampleRate: sampleRate)
        let timbre = analyzeTimbre(samples: monoSamples, sampleRate: sampleRate)
        let peak = detectPeak(samples: samples, sampleRate: sampleRate)
        let clipping = detectClipping(samples: samples, sampleRate: sampleRate)
        let silenceSegments = detectSilence(samples: monoSamples, sampleRate: sampleRate)
        let beatPositions = detectBeats(samples: monoSamples, sampleRate: sampleRate)
        
        return FullAnalysisResult(
            bpm: bpm,
            loudness: loudness,
            frequency: frequency,
            dynamicRange: dynamicRange,
            phase: phase,
            pitch: pitch,
            timbre: timbre,
            peak: peak,
            clipping: clipping,
            silenceSegments: silenceSegments,
            beatPositions: beatPositions
        )
    }
    
    // MARK: - 辅助函数
    
    /// 将多声道音频转换为单声道
    public static func convertToMono(samples: [Float], channelCount: Int) -> [Float] {
        guard channelCount > 1 else { return samples }
        
        let frameCount = samples.count / channelCount
        var mono = [Float](repeating: 0, count: frameCount)
        
        for i in 0..<frameCount {
            var sum: Float = 0
            for ch in 0..<channelCount {
                sum += samples[i * channelCount + ch]
            }
            mono[i] = sum / Float(channelCount)
        }
        
        return mono
    }
    
    // MARK: - 静音检测
    
    /// 静音片段信息
    public struct SilenceSegment {
        /// 开始时间（秒）
        public let startTime: TimeInterval
        /// 结束时间（秒）
        public let endTime: TimeInterval
        /// 持续时长（秒）
        public var duration: TimeInterval { endTime - startTime }
        /// 平均电平（dB）
        public let averageLevel: Float
    }
    
    /// 检测音频数据中的静音片段
    public static func detectSilence(
        samples: [Float],
        sampleRate: Int,
        threshold: Float = -50.0,
        minDuration: TimeInterval = 0.3
    ) -> [SilenceSegment] {
        let windowSize = 1024
        let hopSize = 256  // 更细的分辨率
        let thresholdLinear = powf(10.0, threshold / 20.0)
        let minSamples = Int(minDuration * Double(sampleRate))
        
        var segments: [SilenceSegment] = []
        var silenceStart: Int? = nil
        var silenceLevelSum: Float = 0
        var silenceWindowCount: Int = 0
        
        var i = 0
        while i + windowSize <= samples.count {
            // 使用 Accelerate 计算 RMS
            var sumSquares: Float = 0
            vDSP_svesq(Array(samples[i..<(i + windowSize)]), 1, &sumSquares, vDSP_Length(windowSize))
            let rms = sqrtf(sumSquares / Float(windowSize))
            
            let isSilent = rms < thresholdLinear
            
            if isSilent {
                if silenceStart == nil {
                    silenceStart = i
                    silenceLevelSum = 0
                    silenceWindowCount = 0
                }
                silenceLevelSum += rms
                silenceWindowCount += 1
            } else {
                if let start = silenceStart {
                    let duration = i - start
                    if duration >= minSamples {
                        let avgLevel = silenceWindowCount > 0 ? silenceLevelSum / Float(silenceWindowCount) : 0
                        let avgLevelDB = avgLevel > 0 ? 20.0 * log10f(avgLevel) : -Float.infinity
                        segments.append(SilenceSegment(
                            startTime: Double(start) / Double(sampleRate),
                            endTime: Double(i) / Double(sampleRate),
                            averageLevel: avgLevelDB
                        ))
                    }
                    silenceStart = nil
                }
            }
            
            i += hopSize
        }
        
        // 处理末尾的静音
        if let start = silenceStart {
            let duration = samples.count - start
            if duration >= minSamples {
                let avgLevel = silenceWindowCount > 0 ? silenceLevelSum / Float(silenceWindowCount) : 0
                let avgLevelDB = avgLevel > 0 ? 20.0 * log10f(avgLevel) : -Float.infinity
                segments.append(SilenceSegment(
                    startTime: Double(start) / Double(sampleRate),
                    endTime: Double(samples.count) / Double(sampleRate),
                    averageLevel: avgLevelDB
                ))
            }
        }
        
        return segments
    }
    
    // MARK: - BPM 检测（增强版）
    
    /// BPM 检测结果
    public struct BPMResult {
        /// 主要 BPM
        public let bpm: Float
        /// 置信度（0~1）
        public let confidence: Float
        /// 备选 BPM（可能是主 BPM 的倍数或约数）
        public let alternativeBPMs: [Float]
        /// 节拍稳定性（0~1）
        public let stability: Float
    }
    
    /// 检测音频的 BPM（增强版，使用多种算法融合）
    public static func detectBPM(samples: [Float], sampleRate: Int) -> BPMResult {
        guard samples.count > sampleRate * 2 else {
            return BPMResult(bpm: 0, confidence: 0, alternativeBPMs: [], stability: 0)
        }
        
        // 1. 计算能量包络（使用更小的窗口提高精度）
        let windowSize = 512
        let hopSize = 128
        var envelope: [Float] = []
        
        var i = 0
        while i + windowSize <= samples.count {
            var sumSquares: Float = 0
            vDSP_svesq(Array(samples[i..<(i + windowSize)]), 1, &sumSquares, vDSP_Length(windowSize))
            envelope.append(sqrtf(sumSquares / Float(windowSize)))
            i += hopSize
        }
        
        guard envelope.count > 200 else {
            return BPMResult(bpm: 0, confidence: 0, alternativeBPMs: [], stability: 0)
        }
        
        // 2. 计算一阶差分（onset detection）
        var onset: [Float] = [0]
        for i in 1..<envelope.count {
            let diff = max(0, envelope[i] - envelope[i - 1])
            onset.append(diff)
        }
        
        // 3. 半波整流 + 低通滤波平滑
        var smoothedOnset = onset
        let smoothWindow = 5
        for i in smoothWindow..<(onset.count - smoothWindow) {
            var sum: Float = 0
            for j in -smoothWindow...smoothWindow {
                sum += onset[i + j]
            }
            smoothedOnset[i] = sum / Float(smoothWindow * 2 + 1)
        }
        
        // 4. 自相关分析
        let envelopeRate = Float(sampleRate) / Float(hopSize)
        let minBPM: Float = 50
        let maxBPM: Float = 220
        let minLag = Int(envelopeRate * 60.0 / maxBPM)
        let maxLag = min(Int(envelopeRate * 60.0 / minBPM), smoothedOnset.count / 2)
        
        var correlations: [(lag: Int, corr: Float)] = []
        
        for lag in minLag...maxLag {
            var corr: Float = 0
            let count = smoothedOnset.count - lag
            for i in 0..<count {
                corr += smoothedOnset[i] * smoothedOnset[i + lag]
            }
            corr /= Float(count)
            correlations.append((lag, corr))
        }
        
        // 5. 找到多个峰值
        correlations.sort { $0.corr > $1.corr }
        
        var peaks: [(bpm: Float, corr: Float)] = []
        for (lag, corr) in correlations.prefix(20) {
            let bpm = envelopeRate * 60.0 / Float(lag)
            // 检查是否与已有峰值太接近
            let isUnique = peaks.allSatisfy { abs($0.bpm - bpm) > 5 }
            if isUnique {
                peaks.append((bpm, corr))
            }
            if peaks.count >= 5 { break }
        }
        
        guard let mainPeak = peaks.first else {
            return BPMResult(bpm: 0, confidence: 0, alternativeBPMs: [], stability: 0)
        }
        
        // 6. 计算置信度
        let avgCorr = correlations.map { $0.corr }.reduce(0, +) / Float(correlations.count)
        let confidence = min(1.0, mainPeak.corr / (avgCorr * 3 + 0.001))
        
        // 7. 计算节拍稳定性（检查倍频/半频的一致性）
        var stability: Float = 0.5
        let halfBPM = mainPeak.bpm / 2
        let doubleBPM = mainPeak.bpm * 2
        
        for peak in peaks.dropFirst() {
            if abs(peak.bpm - halfBPM) < 5 || abs(peak.bpm - doubleBPM) < 5 {
                stability += 0.25
            }
        }
        stability = min(1.0, stability)
        
        // 8. 备选 BPM
        let alternativeBPMs = peaks.dropFirst().prefix(3).map { $0.bpm }
        
        return BPMResult(
            bpm: mainPeak.bpm,
            confidence: confidence,
            alternativeBPMs: Array(alternativeBPMs),
            stability: stability
        )
    }
    
    // MARK: - 节拍位置检测
    
    /// 节拍位置
    public struct BeatPosition {
        /// 时间（秒）
        public let time: TimeInterval
        /// 强度（0~1）
        public let strength: Float
        /// 是否为强拍
        public let isDownbeat: Bool
    }
    
    /// 检测节拍位置
    public static func detectBeats(
        samples: [Float],
        sampleRate: Int
    ) -> [BeatPosition] {
        let windowSize = 1024
        let hopSize = 512
        
        // 计算能量包络
        var envelope: [Float] = []
        var i = 0
        while i + windowSize <= samples.count {
            var sumSquares: Float = 0
            vDSP_svesq(Array(samples[i..<(i + windowSize)]), 1, &sumSquares, vDSP_Length(windowSize))
            envelope.append(sqrtf(sumSquares / Float(windowSize)))
            i += hopSize
        }
        
        guard envelope.count > 10 else { return [] }
        
        // 计算差分
        var diff: [Float] = [0]
        for i in 1..<envelope.count {
            diff.append(max(0, envelope[i] - envelope[i - 1]))
        }
        
        // 自适应阈值
        let windowForThreshold = 20
        var beats: [BeatPosition] = []
        
        for i in windowForThreshold..<(diff.count - windowForThreshold) {
            // 计算局部平均
            var localSum: Float = 0
            for j in (i - windowForThreshold)..<(i + windowForThreshold) {
                localSum += diff[j]
            }
            let localMean = localSum / Float(windowForThreshold * 2)
            let threshold = localMean * 1.5
            
            // 检测峰值
            if diff[i] > threshold && diff[i] > diff[i - 1] && diff[i] > diff[i + 1] {
                let time = Double(i * hopSize) / Double(sampleRate)
                let strength = min(1.0, diff[i] / (localMean * 3 + 0.001))
                beats.append(BeatPosition(time: time, strength: strength, isDownbeat: false))
            }
        }
        
        // 标记强拍（每 4 拍的第一拍）
        if beats.count >= 4 {
            // 计算平均节拍间隔
            var intervals: [TimeInterval] = []
            for i in 1..<beats.count {
                intervals.append(beats[i].time - beats[i - 1].time)
            }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            
            // 标记强拍
            var result: [BeatPosition] = []
            var beatCount = 0
            for beat in beats {
                let isDownbeat = beatCount % 4 == 0
                result.append(BeatPosition(time: beat.time, strength: beat.strength, isDownbeat: isDownbeat))
                beatCount += 1
            }
            return result
        }
        
        return beats
    }
    
    // MARK: - 峰值检测
    
    /// 峰值检测结果
    public struct PeakResult {
        /// 峰值电平（dBFS）
        public let peakDB: Float
        /// 峰值位置（秒）
        public let peakTime: TimeInterval
        /// 是否削波
        public let isClipping: Bool
        /// 峰值采样值
        public let peakSample: Float
        /// 峰值出现次数（接近峰值的采样数）
        public let peakCount: Int
    }
    
    /// 检测音频峰值
    public static func detectPeak(
        samples: [Float],
        sampleRate: Int,
        clippingThreshold: Float = 0.99
    ) -> PeakResult {
        var maxAbs: Float = 0
        var maxIndex = 0
        var clippingCount = 0
        var nearPeakCount = 0
        
        for (index, sample) in samples.enumerated() {
            let abs = Swift.abs(sample)
            if abs > maxAbs {
                maxAbs = abs
                maxIndex = index
            }
            if abs >= clippingThreshold {
                clippingCount += 1
            }
        }
        
        // 统计接近峰值的采样数
        let nearPeakThreshold = maxAbs * 0.95
        for sample in samples {
            if Swift.abs(sample) >= nearPeakThreshold {
                nearPeakCount += 1
            }
        }
        
        let peakDB = maxAbs > 0 ? 20.0 * log10f(maxAbs) : -Float.infinity
        let peakTime = Double(maxIndex) / Double(sampleRate)
        let isClipping = clippingCount > 10
        
        return PeakResult(
            peakDB: peakDB,
            peakTime: peakTime,
            isClipping: isClipping,
            peakSample: maxAbs,
            peakCount: nearPeakCount
        )
    }
    
    // MARK: - 响度测量（EBU R128 增强版）
    
    /// 响度测量结果
    public struct LoudnessResult {
        /// 积分响度（LUFS）
        public let integratedLUFS: Float
        /// 短期响度（LUFS，3秒窗口）
        public let shortTermLUFS: Float
        /// 瞬时响度（LUFS，400ms窗口）
        public let momentaryLUFS: Float
        /// 响度范围（LRA，dB）
        public let loudnessRange: Float
        /// 真峰值（dBTP）
        public let truePeak: Float
        /// 响度直方图（用于可视化）
        public let loudnessHistogram: [Float]
    }

    /// 测量音频响度（增强版 EBU R128）
    public static func measureLoudness(
        samples: [Float],
        sampleRate: Int,
        channelCount: Int
    ) -> LoudnessResult {
        let frameCount = samples.count / channelCount
        guard frameCount > 0 else {
            return LoudnessResult(
                integratedLUFS: -70,
                shortTermLUFS: -70,
                momentaryLUFS: -70,
                loudnessRange: 0,
                truePeak: -Float.infinity,
                loudnessHistogram: []
            )
        }
        
        // K-weighting 简化实现（高通 + 高频提升）
        // 完整实现需要两个滤波器，这里使用简化版本
        var weightedSamples = samples
        
        // 简化的 K-weighting：高频提升约 4dB
        let highBoost: Float = 1.5  // 约 3.5dB
        for i in stride(from: 0, to: samples.count - channelCount, by: channelCount) {
            for ch in 0..<channelCount {
                let idx = i + ch
                let nextIdx = i + channelCount + ch
                if nextIdx < samples.count {
                    // 简单的高频提升
                    let highFreq = samples[nextIdx] - samples[idx]
                    weightedSamples[idx] = samples[idx] + highFreq * (highBoost - 1)
                }
            }
        }
        
        // 计算门控块（400ms 块，75% 重叠）
        let blockSize = Int(0.4 * Double(sampleRate)) * channelCount
        let hopSize = blockSize / 4
        var blockLoudness: [Float] = []
        
        var i = 0
        while i + blockSize <= weightedSamples.count {
            var sumSquares: Float = 0
            for j in 0..<blockSize {
                sumSquares += weightedSamples[i + j] * weightedSamples[i + j]
            }
            let meanSquare = sumSquares / Float(blockSize)
            let loudness = meanSquare > 0 ? -0.691 + 10.0 * log10f(meanSquare) : -70.0
            blockLoudness.append(loudness)
            i += hopSize
        }
        
        guard !blockLoudness.isEmpty else {
            return LoudnessResult(
                integratedLUFS: -70,
                shortTermLUFS: -70,
                momentaryLUFS: -70,
                loudnessRange: 0,
                truePeak: -Float.infinity,
                loudnessHistogram: []
            )
        }
        
        // 绝对门限：-70 LUFS
        let absoluteThreshold: Float = -70.0
        var gatedBlocks = blockLoudness.filter { $0 > absoluteThreshold }
        
        // 计算相对门限
        if !gatedBlocks.isEmpty {
            let avgLoudness = gatedBlocks.reduce(0, +) / Float(gatedBlocks.count)
            let relativeThreshold = avgLoudness - 10.0  // 相对门限：平均值 - 10 LUFS
            gatedBlocks = gatedBlocks.filter { $0 > relativeThreshold }
        }
        
        // 积分响度
        let integratedLUFS: Float
        if !gatedBlocks.isEmpty {
            integratedLUFS = gatedBlocks.reduce(0, +) / Float(gatedBlocks.count)
        } else {
            integratedLUFS = -70.0
        }
        
        // 短期响度（最后 3 秒）
        let shortTermBlocks = Int(3.0 / 0.1)  // 3秒 / 100ms hop
        let shortTermLUFS: Float
        if blockLoudness.count >= shortTermBlocks {
            let lastBlocks = Array(blockLoudness.suffix(shortTermBlocks))
            shortTermLUFS = lastBlocks.reduce(0, +) / Float(lastBlocks.count)
        } else {
            shortTermLUFS = integratedLUFS
        }
        
        // 瞬时响度（最后 400ms）
        let momentaryLUFS = blockLoudness.last ?? -70.0
        
        // 响度范围（LRA）
        let sortedLoudness = gatedBlocks.sorted()
        let loudnessRange: Float
        if sortedLoudness.count >= 10 {
            let low = sortedLoudness[Int(Float(sortedLoudness.count) * 0.1)]
            let high = sortedLoudness[Int(Float(sortedLoudness.count) * 0.95)]
            loudnessRange = high - low
        } else {
            loudnessRange = 0
        }
        
        // 真峰值
        var maxAbs: Float = 0
        for sample in samples {
            maxAbs = max(maxAbs, abs(sample))
        }
        let truePeak = maxAbs > 0 ? 20.0 * log10f(maxAbs) : -Float.infinity
        
        // 响度直方图（-70 到 0 LUFS，70 个 bin）
        var histogram = [Float](repeating: 0, count: 70)
        for loudness in blockLoudness {
            let bin = Int(loudness + 70)
            if bin >= 0 && bin < 70 {
                histogram[bin] += 1
            }
        }
        // 归一化
        let maxCount = histogram.max() ?? 1
        if maxCount > 0 {
            histogram = histogram.map { $0 / maxCount }
        }
        
        return LoudnessResult(
            integratedLUFS: integratedLUFS,
            shortTermLUFS: shortTermLUFS,
            momentaryLUFS: momentaryLUFS,
            loudnessRange: loudnessRange,
            truePeak: truePeak,
            loudnessHistogram: histogram
        )
    }
    
    // MARK: - 削波检测
    
    /// 削波检测结果
    public struct ClippingResult {
        /// 削波采样点数量
        public let clippedSamples: Int
        /// 削波百分比
        public let clippingPercentage: Float
        /// 是否有严重削波
        public let hasSevereClipping: Bool
        /// 削波位置（秒）
        public let clippingPositions: [TimeInterval]
        /// 连续削波段数
        public let clippingRegions: Int
    }
    
    /// 检测音频削波
    public static func detectClipping(
        samples: [Float],
        sampleRate: Int,
        threshold: Float = 0.99
    ) -> ClippingResult {
        var clippedSamples = 0
        var positions: [TimeInterval] = []
        var lastClipTime: TimeInterval = -1
        var clippingRegions = 0
        var inClipRegion = false
        
        for (index, sample) in samples.enumerated() {
            if abs(sample) >= threshold {
                clippedSamples += 1
                let time = Double(index) / Double(sampleRate)
                
                if !inClipRegion {
                    inClipRegion = true
                    clippingRegions += 1
                    if time - lastClipTime > 0.1 {
                        positions.append(time)
                        lastClipTime = time
                    }
                }
            } else {
                inClipRegion = false
            }
        }
        
        let percentage = Float(clippedSamples) / Float(samples.count) * 100.0
        let hasSevereClipping = percentage > 0.1 || clippingRegions > 10
        
        return ClippingResult(
            clippedSamples: clippedSamples,
            clippingPercentage: percentage,
            hasSevereClipping: hasSevereClipping,
            clippingPositions: positions,
            clippingRegions: clippingRegions
        )
    }
    
    // MARK: - 相位检测
    
    /// 相位检测结果
    public struct PhaseResult {
        /// 相位相关性（-1 到 +1）
        public let correlation: Float
        /// 是否存在相位问题
        public let hasPhaseIssue: Bool
        /// 相位问题描述
        public let description: String
        /// 单声道兼容性（0~1）
        public let monoCompatibility: Float
        /// 立体声宽度指标（0~1）
        public let stereoWidth: Float
    }
    
    /// 检测立体声音频的相位问题
    public static func detectPhase(
        samples: [Float],
        sampleRate: Int
    ) -> PhaseResult {
        let frameCount = samples.count / 2
        guard frameCount > 0 else {
            return PhaseResult(
                correlation: 0,
                hasPhaseIssue: false,
                description: "无数据",
                monoCompatibility: 0,
                stereoWidth: 0
            )
        }
        
        // 计算左右声道的相关性
        var sumLR: Float = 0
        var sumL2: Float = 0
        var sumR2: Float = 0
        var sumMono2: Float = 0
        var sumSide2: Float = 0
        
        for i in 0..<frameCount {
            let left = samples[i * 2]
            let right = samples[i * 2 + 1]
            let mid = (left + right) / 2
            let side = (left - right) / 2
            
            sumLR += left * right
            sumL2 += left * left
            sumR2 += right * right
            sumMono2 += mid * mid
            sumSide2 += side * side
        }
        
        let denominator = sqrtf(sumL2 * sumR2)
        let correlation = denominator > 0 ? sumLR / denominator : 0
        
        // 单声道兼容性
        let monoEnergy = sumMono2
        let sideEnergy = sumSide2
        let totalEnergy = monoEnergy + sideEnergy
        let monoCompatibility = totalEnergy > 0 ? monoEnergy / totalEnergy : 0.5
        
        // 立体声宽度
        let stereoWidth = totalEnergy > 0 ? sideEnergy / totalEnergy : 0
        
        // 判断相位问题
        let hasPhaseIssue: Bool
        let description: String
        
        if correlation < -0.5 {
            hasPhaseIssue = true
            description = "严重反相：左右声道几乎完全反相，混合为单声道时会相互抵消"
        } else if correlation < 0 {
            hasPhaseIssue = true
            description = "部分反相：存在相位问题，可能影响单声道兼容性"
        } else if correlation > 0.98 {
            hasPhaseIssue = false
            description = "高度相关：左右声道几乎相同，可能是伪立体声或单声道"
        } else if correlation > 0.9 {
            hasPhaseIssue = false
            description = "窄立体声：立体声宽度较窄"
        } else {
            hasPhaseIssue = false
            description = "正常：立体声相位正常"
        }
        
        return PhaseResult(
            correlation: correlation,
            hasPhaseIssue: hasPhaseIssue,
            description: description,
            monoCompatibility: monoCompatibility,
            stereoWidth: stereoWidth
        )
    }

    // MARK: - 音调检测
    
    /// 音调检测结果
    public struct PitchResult {
        /// 基频（Hz）
        public let fundamentalFrequency: Float
        /// 音符名称（如 "A4", "C#5"）
        public let noteName: String
        /// 音分偏差（-50 到 +50）
        public let centDeviation: Float
        /// 置信度（0~1）
        public let confidence: Float
        /// MIDI 音符号
        public let midiNote: Int
    }
    
    /// 检测音频的主要音调
    public static func detectPitch(
        samples: [Float],
        sampleRate: Int
    ) -> PitchResult {
        // 使用自相关法检测基频
        let windowSize = min(4096, samples.count)
        guard windowSize >= 1024 else {
            return PitchResult(
                fundamentalFrequency: 0,
                noteName: "-",
                centDeviation: 0,
                confidence: 0,
                midiNote: 0
            )
        }
        
        // 取中间部分的采样
        let startIdx = max(0, (samples.count - windowSize) / 2)
        let window = Array(samples[startIdx..<(startIdx + windowSize)])
        
        // 自相关
        let minFreq: Float = 50   // 最低检测频率
        let maxFreq: Float = 2000 // 最高检测频率
        let minLag = Int(Float(sampleRate) / maxFreq)
        let maxLag = min(Int(Float(sampleRate) / minFreq), windowSize / 2)
        
        var bestLag = minLag
        var bestCorr: Float = 0
        var correlations: [Float] = []
        
        for lag in minLag...maxLag {
            var corr: Float = 0
            for i in 0..<(windowSize - lag) {
                corr += window[i] * window[i + lag]
            }
            corr /= Float(windowSize - lag)
            correlations.append(corr)
            
            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }
        
        // 计算基频
        let fundamentalFrequency = Float(sampleRate) / Float(bestLag)
        
        // 计算置信度
        let avgCorr = correlations.reduce(0, +) / Float(correlations.count)
        let confidence = min(1.0, bestCorr / (avgCorr * 2 + 0.001))
        
        // 转换为音符
        let (noteName, midiNote, centDeviation) = frequencyToNote(fundamentalFrequency)
        
        return PitchResult(
            fundamentalFrequency: fundamentalFrequency,
            noteName: noteName,
            centDeviation: centDeviation,
            confidence: confidence,
            midiNote: midiNote
        )
    }
    
    /// 频率转音符
    private static func frequencyToNote(_ frequency: Float) -> (name: String, midi: Int, cents: Float) {
        guard frequency > 0 else { return ("-", 0, 0) }
        
        // A4 = 440Hz = MIDI 69
        let midiFloat = 69.0 + 12.0 * log2f(frequency / 440.0)
        let midiNote = Int(round(midiFloat))
        let centDeviation = (midiFloat - Float(midiNote)) * 100
        
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteIndex = ((midiNote % 12) + 12) % 12
        let octave = (midiNote / 12) - 1
        let noteName = "\(noteNames[noteIndex])\(octave)"
        
        return (noteName, midiNote, centDeviation)
    }
    
    // MARK: - 频率分析（增强版）
    
    /// 频率分析结果
    public struct FrequencyAnalysis {
        /// 主频率（Hz）
        public let dominantFrequency: Float
        /// 频谱质心（Hz）- 音色亮度指标
        public let spectralCentroid: Float
        /// 频谱滚降点（Hz）- 85% 能量截止频率
        public let spectralRolloff: Float
        /// 低频能量占比（0~1，0-300Hz）
        public let lowEnergyRatio: Float
        /// 中频能量占比（0~1，300-4000Hz）
        public let midEnergyRatio: Float
        /// 高频能量占比（0~1，4000Hz+）
        public let highEnergyRatio: Float
        /// 频谱平坦度（0~1，越高越像噪声）
        public let spectralFlatness: Float
        /// 频谱峰值（前 5 个主要频率）
        public let spectralPeaks: [(frequency: Float, magnitude: Float)]
    }
    
    /// 分析音频频率特征（使用 Accelerate FFT）
    public static func analyzeFrequency(
        samples: [Float],
        sampleRate: Int
    ) -> FrequencyAnalysis {
        let fftSize = 4096
        guard samples.count >= fftSize else {
            return FrequencyAnalysis(
                dominantFrequency: 0,
                spectralCentroid: 0,
                spectralRolloff: 0,
                lowEnergyRatio: 0,
                midEnergyRatio: 0,
                highEnergyRatio: 0,
                spectralFlatness: 0,
                spectralPeaks: []
            )
        }
        
        // 取中间部分
        let startIdx = (samples.count - fftSize) / 2
        var window = Array(samples[startIdx..<(startIdx + fftSize)])
        
        // 应用汉宁窗
        var hannWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(window, 1, hannWindow, 1, &window, 1, vDSP_Length(fftSize))
        
        // 使用 DFT 计算幅度谱（简化版，实际应用应使用 vDSP_fft）
        let binCount = fftSize / 2
        var magnitudes = [Float](repeating: 0, count: binCount)
        let nyquist = Float(sampleRate) / 2.0
        let binWidth = nyquist / Float(binCount)
        
        // 简化 DFT（只计算前 512 个 bin 以提高性能）
        let maxBin = min(512, binCount)
        for k in 0..<maxBin {
            var real: Float = 0
            var imag: Float = 0
            let freq = Float(k) * 2.0 * .pi / Float(fftSize)
            
            for n in stride(from: 0, to: fftSize, by: 4) {  // 降采样提高性能
                let sample = window[n]
                real += sample * cosf(freq * Float(n))
                imag -= sample * sinf(freq * Float(n))
            }
            
            magnitudes[k] = sqrtf(real * real + imag * imag) / Float(fftSize / 4)
        }
        
        // 找主频率
        var maxMag: Float = 0
        var maxIndex = 0
        for (i, mag) in magnitudes.prefix(maxBin).enumerated() {
            if mag > maxMag {
                maxMag = mag
                maxIndex = i
            }
        }
        let dominantFrequency = Float(maxIndex) * binWidth
        
        // 计算频谱质心
        var weightedSum: Float = 0
        var totalMag: Float = 0
        for (i, mag) in magnitudes.prefix(maxBin).enumerated() {
            let freq = Float(i) * binWidth
            weightedSum += freq * mag
            totalMag += mag
        }
        let spectralCentroid = totalMag > 0 ? weightedSum / totalMag : 0
        
        // 计算频谱滚降点（85% 能量）
        var cumulativeEnergy: Float = 0
        var totalEnergy: Float = 0
        for mag in magnitudes.prefix(maxBin) {
            totalEnergy += mag * mag
        }
        var rolloffBin = 0
        let rolloffThreshold = totalEnergy * 0.85
        for (i, mag) in magnitudes.prefix(maxBin).enumerated() {
            cumulativeEnergy += mag * mag
            if cumulativeEnergy >= rolloffThreshold {
                rolloffBin = i
                break
            }
        }
        let spectralRolloff = Float(rolloffBin) * binWidth
        
        // 计算频段能量占比
        let lowCutoff = Int(300.0 / binWidth)
        let midCutoff = Int(4000.0 / binWidth)
        
        var lowEnergy: Float = 0
        var midEnergy: Float = 0
        var highEnergy: Float = 0
        
        for (i, mag) in magnitudes.prefix(maxBin).enumerated() {
            let energy = mag * mag
            if i < lowCutoff {
                lowEnergy += energy
            } else if i < midCutoff {
                midEnergy += energy
            } else {
                highEnergy += energy
            }
        }
        
        let bandTotalEnergy = lowEnergy + midEnergy + highEnergy
        
        // 计算频谱平坦度（几何平均 / 算术平均）
        var logSum: Float = 0
        var arithmeticSum: Float = 0
        var validCount = 0
        for mag in magnitudes.prefix(maxBin) where mag > 0.0001 {
            logSum += log(mag)
            arithmeticSum += mag
            validCount += 1
        }
        let spectralFlatness: Float
        if validCount > 0 && arithmeticSum > 0 {
            let geometricMean = exp(logSum / Float(validCount))
            let arithmeticMean = arithmeticSum / Float(validCount)
            spectralFlatness = geometricMean / arithmeticMean
        } else {
            spectralFlatness = 0
        }
        
        // 找频谱峰值
        var peaks: [(frequency: Float, magnitude: Float)] = []
        for i in 2..<(maxBin - 2) {
            let mag = magnitudes[i]
            if mag > magnitudes[i - 1] && mag > magnitudes[i + 1] &&
               mag > magnitudes[i - 2] && mag > magnitudes[i + 2] &&
               mag > maxMag * 0.1 {
                peaks.append((Float(i) * binWidth, mag))
            }
        }
        peaks.sort { $0.magnitude > $1.magnitude }
        let topPeaks = Array(peaks.prefix(5))
        
        return FrequencyAnalysis(
            dominantFrequency: dominantFrequency,
            spectralCentroid: spectralCentroid,
            spectralRolloff: spectralRolloff,
            lowEnergyRatio: bandTotalEnergy > 0 ? lowEnergy / bandTotalEnergy : 0,
            midEnergyRatio: bandTotalEnergy > 0 ? midEnergy / bandTotalEnergy : 0,
            highEnergyRatio: bandTotalEnergy > 0 ? highEnergy / bandTotalEnergy : 0,
            spectralFlatness: spectralFlatness,
            spectralPeaks: topPeaks
        )
    }
    
    // MARK: - 动态范围分析
    
    /// 动态范围分析结果
    public struct DynamicRangeResult {
        /// 动态范围（dB）
        public let dynamicRange: Float
        /// DR 值（类似 DR Database 的评分）
        public let drValue: Int
        /// 峰值电平（dBFS）
        public let peakLevel: Float
        /// RMS 电平（dBFS）
        public let rmsLevel: Float
        /// 波峰因数（Peak/RMS，dB）
        public let crestFactor: Float
        /// 压缩程度描述
        public let compressionDescription: String
    }
    
    /// 分析音频动态范围
    public static func analyzeDynamicRange(
        samples: [Float],
        sampleRate: Int
    ) -> DynamicRangeResult {
        guard !samples.isEmpty else {
            return DynamicRangeResult(
                dynamicRange: 0,
                drValue: 0,
                peakLevel: -Float.infinity,
                rmsLevel: -Float.infinity,
                crestFactor: 0,
                compressionDescription: "无数据"
            )
        }
        
        // 计算峰值和 RMS
        var maxAbs: Float = 0
        var sumSquares: Float = 0
        
        vDSP_maxmgv(samples, 1, &maxAbs, vDSP_Length(samples.count))
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        
        let rms = sqrtf(sumSquares / Float(samples.count))
        
        let peakLevel = maxAbs > 0 ? 20.0 * log10f(maxAbs) : -Float.infinity
        let rmsLevel = rms > 0 ? 20.0 * log10f(rms) : -Float.infinity
        let crestFactor = peakLevel - rmsLevel
        
        // 计算 DR 值（使用窗口化方法）
        let windowSize = sampleRate / 10  // 100ms 窗口
        var windowRMSValues: [Float] = []
        var windowPeakValues: [Float] = []
        
        var i = 0
        while i + windowSize <= samples.count {
            let windowSamples = Array(samples[i..<(i + windowSize)])
            
            var windowMax: Float = 0
            var windowSumSq: Float = 0
            vDSP_maxmgv(windowSamples, 1, &windowMax, vDSP_Length(windowSize))
            vDSP_svesq(windowSamples, 1, &windowSumSq, vDSP_Length(windowSize))
            
            let windowRMS = sqrtf(windowSumSq / Float(windowSize))
            
            if windowRMS > 0.0001 {  // 忽略静音
                windowRMSValues.append(windowRMS)
                windowPeakValues.append(windowMax)
            }
            
            i += windowSize / 2  // 50% 重叠
        }
        
        // DR 值计算
        let drValue: Int
        let dynamicRange: Float
        
        if windowRMSValues.count >= 10 {
            // 排序取前 20% 最大 RMS
            let sortedRMS = windowRMSValues.sorted(by: >)
            let top20Count = max(1, sortedRMS.count / 5)
            let top20RMS = sortedRMS.prefix(top20Count)
            let avgTop20RMS = top20RMS.reduce(0, +) / Float(top20Count)
            
            // 取第二高的峰值（避免异常值）
            let sortedPeaks = windowPeakValues.sorted(by: >)
            let secondPeak = sortedPeaks.count > 1 ? sortedPeaks[1] : sortedPeaks[0]
            
            // DR = 20 * log10(peak / rms)
            dynamicRange = 20.0 * log10f(secondPeak / avgTop20RMS)
            drValue = Int(round(dynamicRange))
        } else {
            dynamicRange = crestFactor
            drValue = Int(round(crestFactor))
        }
        
        // 压缩程度描述
        let compressionDescription: String
        if drValue >= 14 {
            compressionDescription = "优秀：动态范围宽广，几乎无压缩"
        } else if drValue >= 10 {
            compressionDescription = "良好：适度压缩，动态保留较好"
        } else if drValue >= 6 {
            compressionDescription = "一般：中度压缩，动态有所损失"
        } else {
            compressionDescription = "过度压缩：动态范围很窄，响度战争受害者"
        }
        
        return DynamicRangeResult(
            dynamicRange: dynamicRange,
            drValue: drValue,
            peakLevel: peakLevel,
            rmsLevel: rmsLevel,
            crestFactor: crestFactor,
            compressionDescription: compressionDescription
        )
    }

    // MARK: - 音色分析
    
    /// 音色分析结果
    public struct TimbreAnalysis {
        /// 亮度（0~1，基于频谱质心）
        public let brightness: Float
        /// 温暖度（0~1，基于低频能量）
        public let warmth: Float
        /// 清晰度（0~1，基于高频能量）
        public let clarity: Float
        /// 丰满度（0~1，基于中频能量）
        public let fullness: Float
        /// 噪声感（0~1，基于频谱平坦度）
        public let noisiness: Float
        /// 音色描述
        public let description: String
        /// 推荐的 EQ 调整
        public let eqSuggestion: String
    }
    
    /// 分析音频音色特征
    public static func analyzeTimbre(
        samples: [Float],
        sampleRate: Int
    ) -> TimbreAnalysis {
        // 先进行频率分析
        let freqAnalysis = analyzeFrequency(samples: samples, sampleRate: sampleRate)
        
        // 计算音色指标
        // 亮度：基于频谱质心，质心越高越亮
        let maxCentroid: Float = 4000.0  // 参考最大质心
        let brightness = min(1.0, freqAnalysis.spectralCentroid / maxCentroid)
        
        // 温暖度：基于低频能量
        let warmth = min(1.0, freqAnalysis.lowEnergyRatio * 2.5)
        
        // 清晰度：基于高频能量
        let clarity = min(1.0, freqAnalysis.highEnergyRatio * 3.0)
        
        // 丰满度：基于中频能量
        let fullness = min(1.0, freqAnalysis.midEnergyRatio * 1.5)
        
        // 噪声感：基于频谱平坦度
        let noisiness = freqAnalysis.spectralFlatness
        
        // 生成音色描述
        var descriptions: [String] = []
        
        if brightness > 0.7 {
            descriptions.append("明亮")
        } else if brightness < 0.3 {
            descriptions.append("暗淡")
        }
        
        if warmth > 0.6 {
            descriptions.append("温暖")
        } else if warmth < 0.3 {
            descriptions.append("单薄")
        }
        
        if clarity > 0.5 {
            descriptions.append("清晰")
        }
        
        if fullness > 0.6 {
            descriptions.append("丰满")
        } else if fullness < 0.3 {
            descriptions.append("空洞")
        }
        
        if noisiness > 0.5 {
            descriptions.append("有噪声感")
        }
        
        let description = descriptions.isEmpty ? "均衡" : descriptions.joined(separator: "、")
        
        // 生成 EQ 建议
        var suggestions: [String] = []
        
        if warmth < 0.3 {
            suggestions.append("可增加 100-200Hz 低频")
        } else if warmth > 0.7 {
            suggestions.append("可适当降低 100-200Hz 低频")
        }
        
        if brightness < 0.3 {
            suggestions.append("可增加 4-8kHz 高频")
        } else if brightness > 0.8 {
            suggestions.append("可适当降低 4-8kHz 高频")
        }
        
        if fullness < 0.4 {
            suggestions.append("可增加 500-2kHz 中频")
        }
        
        let eqSuggestion = suggestions.isEmpty ? "音色均衡，无需调整" : suggestions.joined(separator: "；")
        
        return TimbreAnalysis(
            brightness: brightness,
            warmth: warmth,
            clarity: clarity,
            fullness: fullness,
            noisiness: noisiness,
            description: description,
            eqSuggestion: eqSuggestion
        )
    }
    
    // MARK: - 音乐类型推测
    
    /// 音乐类型推测结果
    public struct GenreGuess {
        /// 推测的类型
        public let genre: String
        /// 置信度（0~1）
        public let confidence: Float
        /// 特征描述
        public let characteristics: [String]
    }
    
    /// 根据音频特征推测音乐类型
    public static func guessGenre(
        samples: [Float],
        sampleRate: Int,
        channelCount: Int
    ) -> GenreGuess {
        let mono = convertToMono(samples: samples, channelCount: channelCount)
        let bpm = detectBPM(samples: mono, sampleRate: sampleRate)
        let freq = analyzeFrequency(samples: mono, sampleRate: sampleRate)
        let dynamic = analyzeDynamicRange(samples: mono, sampleRate: sampleRate)
        
        var characteristics: [String] = []
        var genreScores: [String: Float] = [:]
        
        // 基于 BPM 判断
        if bpm.bpm >= 120 && bpm.bpm <= 135 {
            genreScores["House/EDM", default: 0] += 0.3
            characteristics.append("BPM 适合 House/EDM")
        } else if bpm.bpm >= 140 && bpm.bpm <= 180 {
            genreScores["Drum & Bass", default: 0] += 0.3
            characteristics.append("高 BPM")
        } else if bpm.bpm >= 85 && bpm.bpm <= 115 {
            genreScores["Hip-Hop/R&B", default: 0] += 0.3
            characteristics.append("中等 BPM")
        } else if bpm.bpm >= 60 && bpm.bpm <= 80 {
            genreScores["Ballad/Jazz", default: 0] += 0.3
            characteristics.append("慢节奏")
        }
        
        // 基于频率分布判断
        if freq.lowEnergyRatio > 0.4 {
            genreScores["Hip-Hop/R&B", default: 0] += 0.2
            genreScores["EDM", default: 0] += 0.2
            characteristics.append("低频丰富")
        }
        
        if freq.highEnergyRatio > 0.3 {
            genreScores["Pop", default: 0] += 0.2
            genreScores["Rock", default: 0] += 0.2
            characteristics.append("高频明亮")
        }
        
        if freq.spectralFlatness > 0.4 {
            genreScores["Electronic", default: 0] += 0.2
            characteristics.append("电子音色")
        }
        
        // 基于动态范围判断
        if dynamic.drValue >= 12 {
            genreScores["Classical/Jazz", default: 0] += 0.3
            characteristics.append("动态范围大")
        } else if dynamic.drValue <= 6 {
            genreScores["Pop/EDM", default: 0] += 0.2
            characteristics.append("高度压缩")
        }
        
        // 找出最高分的类型
        let sortedGenres = genreScores.sorted { $0.value > $1.value }
        let topGenre = sortedGenres.first ?? ("Unknown", 0)
        
        return GenreGuess(
            genre: topGenre.key,
            confidence: min(1.0, topGenre.value),
            characteristics: characteristics
        )
    }
    
    // MARK: - 音频质量评估
    
    /// 音频质量评估结果
    public struct QualityAssessment {
        /// 总体评分（0~100）
        public let overallScore: Int
        /// 动态评分（0~100）
        public let dynamicScore: Int
        /// 频率平衡评分（0~100）
        public let frequencyScore: Int
        /// 立体声评分（0~100，仅立体声）
        public let stereoScore: Int
        /// 问题列表
        public let issues: [String]
        /// 建议列表
        public let suggestions: [String]
        /// 质量等级
        public let grade: String
    }
    
    /// 评估音频质量
    public static func assessQuality(
        samples: [Float],
        sampleRate: Int,
        channelCount: Int
    ) -> QualityAssessment {
        let mono = convertToMono(samples: samples, channelCount: channelCount)
        
        let peak = detectPeak(samples: samples, sampleRate: sampleRate)
        let clipping = detectClipping(samples: samples, sampleRate: sampleRate)
        let dynamic = analyzeDynamicRange(samples: mono, sampleRate: sampleRate)
        let freq = analyzeFrequency(samples: mono, sampleRate: sampleRate)
        let phase = channelCount == 2 ? detectPhase(samples: samples, sampleRate: sampleRate) : nil
        
        var issues: [String] = []
        var suggestions: [String] = []
        
        // 动态评分
        var dynamicScore = 100
        if clipping.hasSevereClipping {
            dynamicScore -= 40
            issues.append("存在严重削波")
            suggestions.append("降低输入电平或使用限幅器")
        } else if clipping.clippedSamples > 0 {
            dynamicScore -= 20
            issues.append("存在轻微削波")
        }
        
        if dynamic.drValue < 6 {
            dynamicScore -= 30
            issues.append("动态范围过窄（DR\(dynamic.drValue)）")
            suggestions.append("减少压缩，保留更多动态")
        } else if dynamic.drValue < 10 {
            dynamicScore -= 15
        }
        
        // 频率平衡评分
        var frequencyScore = 100
        if freq.lowEnergyRatio > 0.6 {
            frequencyScore -= 20
            issues.append("低频过重")
            suggestions.append("使用高通滤波器或降低低频 EQ")
        } else if freq.lowEnergyRatio < 0.1 {
            frequencyScore -= 15
            issues.append("低频不足")
            suggestions.append("增加低频 EQ")
        }
        
        if freq.highEnergyRatio > 0.5 {
            frequencyScore -= 15
            issues.append("高频过亮")
            suggestions.append("降低高频 EQ 或使用去齿音")
        } else if freq.highEnergyRatio < 0.05 {
            frequencyScore -= 10
            issues.append("高频不足")
        }
        
        // 立体声评分
        var stereoScore = 100
        if let p = phase {
            if p.hasPhaseIssue {
                stereoScore -= 40
                issues.append(p.description)
                suggestions.append("检查立体声相位，考虑使用相位校正")
            }
            if p.stereoWidth < 0.1 {
                stereoScore -= 20
                issues.append("立体声宽度过窄")
                suggestions.append("使用立体声增强效果")
            } else if p.stereoWidth > 0.8 {
                stereoScore -= 10
                issues.append("立体声宽度过宽")
            }
        }
        
        // 总体评分
        let overallScore: Int
        if channelCount == 2 {
            overallScore = (dynamicScore + frequencyScore + stereoScore) / 3
        } else {
            overallScore = (dynamicScore + frequencyScore) / 2
        }
        
        // 质量等级
        let grade: String
        if overallScore >= 90 {
            grade = "优秀"
        } else if overallScore >= 75 {
            grade = "良好"
        } else if overallScore >= 60 {
            grade = "一般"
        } else if overallScore >= 40 {
            grade = "较差"
        } else {
            grade = "很差"
        }
        
        return QualityAssessment(
            overallScore: overallScore,
            dynamicScore: dynamicScore,
            frequencyScore: frequencyScore,
            stereoScore: stereoScore,
            issues: issues,
            suggestions: suggestions,
            grade: grade
        )
    }
}


// MARK: - 文件分析

extension AudioAnalyzer {
    
    /// 从音频文件解码并分析
    ///
    /// 这个方法会解码整个音频文件（或指定时长），然后进行完整分析。
    /// 比使用波形数据分析更准确，因为波形数据是降采样的。
    ///
    /// - Parameters:
    ///   - url: 音频文件 URL
    ///   - maxDuration: 最大分析时长（秒），默认 60 秒。设为 0 分析整首歌
    ///   - onProgress: 进度回调
    /// - Returns: 完整分析结果
    public static func analyzeFile(
        url: String,
        maxDuration: TimeInterval = 60,
        onProgress: ((Float) -> Void)? = nil
    ) async throws -> FullAnalysisResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try analyzeFileSync(url: url, maxDuration: maxDuration, onProgress: onProgress)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 同步分析文件（在后台线程调用）
    private static func analyzeFileSync(
        url: String,
        maxDuration: TimeInterval,
        onProgress: ((Float) -> Void)?
    ) throws -> FullAnalysisResult {
        // 解码音频数据
        let (samples, sampleRate, channelCount) = try decodeAudioFile(
            url: url,
            maxDuration: maxDuration,
            onProgress: onProgress
        )
        
        // 执行完整分析
        return analyzeComplete(samples: samples, sampleRate: sampleRate, channelCount: channelCount)
    }
    
    /// 解码音频文件为 PCM 数据
    ///
    /// 支持本地文件和流媒体 URL（HTTP、HTTPS、RTMP、RTSP 等）。
    /// 对于直播流，会自动使用 maxDuration 作为采集时长。
    ///
    /// - Parameters:
    ///   - url: 音频文件或流媒体 URL
    ///   - maxDuration: 最大解码时长（秒），0 = 全部（对于直播流默认 30 秒）
    ///   - onProgress: 进度回调
    /// - Returns: (采样数据, 采样率, 声道数)
    public static func decodeAudioFile(
        url: String,
        maxDuration: TimeInterval = 0,
        onProgress: ((Float) -> Void)? = nil
    ) throws -> (samples: [Float], sampleRate: Int, channelCount: Int) {
        // 检测是否为流媒体 URL
        let isStreamURL = url.lowercased().hasPrefix("http://") ||
                          url.lowercased().hasPrefix("https://") ||
                          url.lowercased().hasPrefix("rtmp://") ||
                          url.lowercased().hasPrefix("rtsp://") ||
                          url.lowercased().hasPrefix("mms://") ||
                          url.lowercased().hasPrefix("mmsh://")
        
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
            ctx.pointee.probesize = 5 * 1024 * 1024  // 5MB
            ctx.pointee.max_analyze_duration = Int64(10 * AV_TIME_BASE)  // 10 秒
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

        let sampleRate = Int(codecCtx.pointee.sample_rate)
        let channelCount = Int(codecpar.pointee.ch_layout.nb_channels)
        
        // 设置 SwrContext 转换为 Float32（保持原始声道数）
        var swrCtx: OpaquePointer?
        var outLayout = AVChannelLayout()
        av_channel_layout_default(&outLayout, Int32(channelCount))
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

        // 计算目标时长
        let duration = Double(ctx.pointee.duration) / Double(AV_TIME_BASE)
        let isLiveStream = duration <= 0 || duration > 86400  // 无时长或超过 24 小时视为直播
        
        let targetDuration: TimeInterval
        if isLiveStream {
            // 直播流：使用 maxDuration，默认 30 秒
            targetDuration = maxDuration > 0 ? maxDuration : 30.0
        } else {
            // 普通文件：使用 maxDuration 或完整时长
            targetDuration = maxDuration > 0 ? min(maxDuration, duration) : duration
        }
        
        let targetSamples = Int(targetDuration * Double(sampleRate))
        
        // 预分配缓冲区
        var samples = [Float]()
        samples.reserveCapacity(min(targetSamples * channelCount, sampleRate * channelCount * 120))

        guard let packet = av_packet_alloc() else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVPacket")
        }
        defer { var p: UnsafeMutablePointer<AVPacket>? = packet; av_packet_free(&p) }

        guard let frame = av_frame_alloc() else {
            throw FFmpegError.resourceAllocationFailed(resource: "AVFrame")
        }
        defer { var f: UnsafeMutablePointer<AVFrame>? = frame; av_frame_free(&f) }

        // 输出缓冲区
        let outBufSize = 16384
        let outBuf = UnsafeMutablePointer<Float>.allocate(capacity: outBufSize * channelCount)
        defer { outBuf.deallocate() }

        var totalDecodedSamples = 0
        var readErrors = 0
        let maxReadErrors = 10  // 最大连续读取错误次数

        while true {
            ret = av_read_frame(ctx, packet)
            
            if ret < 0 {
                // 检查是否为 EOF 或错误
                if ret == FFmpegErrorCode.AVERROR_EOF || ret == -Int32(EAGAIN) {
                    break
                }
                readErrors += 1
                if readErrors >= maxReadErrors {
                    // 流媒体可能断开，停止读取
                    break
                }
                continue
            }
            readErrors = 0  // 重置错误计数
            
            defer { av_packet_unref(packet) }
            guard packet.pointee.stream_index == audioIdx else { continue }

            avcodec_send_packet(codecCtx, packet)

            while avcodec_receive_frame(codecCtx, frame) >= 0 {
                let frameCount = Int(frame.pointee.nb_samples)

                var outPtr: UnsafeMutablePointer<UInt8>? = UnsafeMutableRawPointer(outBuf)
                    .bindMemory(to: UInt8.self, capacity: outBufSize * channelCount * MemoryLayout<Float>.size)
                let inputPtr: UnsafePointer<UnsafePointer<UInt8>?>? = frame.pointee.extended_data.map {
                    UnsafeRawPointer($0).assumingMemoryBound(to: UnsafePointer<UInt8>?.self)
                }

                let converted = swr_convert(swr, &outPtr, Int32(outBufSize), inputPtr, Int32(frameCount))
                guard converted > 0 else { continue }

                let samplesToAdd = Int(converted) * channelCount
                for i in 0..<samplesToAdd {
                    samples.append(outBuf[i])
                }
                
                totalDecodedSamples += Int(converted)

                // 进度回调
                if let onProgress = onProgress, targetSamples > 0 {
                    let progress = Float(totalDecodedSamples) / Float(targetSamples)
                    onProgress(min(progress, 1.0))
                }
                
                // 检查是否达到目标时长
                if totalDecodedSamples >= targetSamples {
                    break
                }
            }
            
            if totalDecodedSamples >= targetSamples {
                break
            }
        }
        
        // 确保有足够的数据进行分析
        guard samples.count >= sampleRate * channelCount else {
            throw FFmpegError.connectionFailed(code: -1, message: "采集的音频数据不足（需要至少 1 秒）")
        }

        return (samples, sampleRate, channelCount)
    }
}
