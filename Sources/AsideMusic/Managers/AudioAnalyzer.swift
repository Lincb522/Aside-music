//
//  AudioAnalyzer.swift
//  AsideMusic
//
//  智能音频分析引擎 - 实时频谱分析、音乐类型检测、自动 EQ 推荐
//

import AVFoundation
import Accelerate

// MARK: - Audio Analysis Result

/// 音频分析结果
struct AudioAnalysisResult {
    /// 频谱能量分布 (10 段)
    var spectrumEnergy: [Float]
    
    /// 检测到的音乐类型
    var detectedGenre: DetectedGenre
    
    /// 推荐的 EQ 设置
    var recommendedEQ: [Float]
    
    /// 动态范围 (dB)
    var dynamicRange: Float
    
    /// 平均响度 (LUFS 近似)
    var averageLoudness: Float
    
    /// 噪声水平估计
    var noiseFloor: Float
    
    /// 是否需要降噪
    var needsDenoising: Bool
    
    /// 低音能量比例
    var bassRatio: Float
    
    /// 高音能量比例
    var trebleRatio: Float
    
    /// 人声检测置信度 (0-1)
    var vocalPresence: Float
}

/// 检测到的音乐类型
enum DetectedGenre: String {
    case vocal = "人声"
    case electronic = "电子"
    case rock = "摇滚"
    case classical = "古典"
    case jazz = "爵士"
    case hiphop = "嘻哈"
    case pop = "流行"
    case acoustic = "原声"
    case unknown = "未知"
    
    /// 对应的推荐 EQ 预设
    var recommendedPreset: EQPreset {
        switch self {
        case .vocal: return .vocal
        case .electronic: return .electronic
        case .rock: return .rock
        case .classical: return .classical
        case .jazz: return .jazz
        case .hiphop: return .hiphop
        case .pop: return .pop
        case .acoustic: return .acoustic
        case .unknown: return .flat
        }
    }
}


// MARK: - Audio Analyzer

/// 智能音频分析器
final class AudioAnalyzer {
    
    // FFT 设置
    private let fftSize: Int = 2048
    private var fftSetup: vDSP_DFT_Setup?
    
    // 分析缓冲区
    private var analysisBuffer: [Float]
    private var bufferIndex: Int = 0
    private var windowBuffer: [Float]
    
    // FFT 工作缓冲区
    private var realPart: [Float]
    private var imagPart: [Float]
    private var magnitudes: [Float]
    
    // 频谱历史 (用于平滑和趋势分析)
    private var spectrumHistory: [[Float]] = []
    private let historySize = 50
    
    // 噪声估计
    private var noiseEstimate: [Float]
    private var noiseUpdateCount: Int = 0
    
    // 分析结果
    private(set) var currentResult: AudioAnalysisResult
    
    // 采样率
    private var sampleRate: Float = 44100
    
    // 线程安全
    private let lock = NSLock()
    
    init() {
        analysisBuffer = [Float](repeating: 0, count: fftSize)
        windowBuffer = [Float](repeating: 0, count: fftSize)
        realPart = [Float](repeating: 0, count: fftSize / 2)
        imagPart = [Float](repeating: 0, count: fftSize / 2)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        noiseEstimate = [Float](repeating: -60, count: 10)
        
        currentResult = AudioAnalysisResult(
            spectrumEnergy: [Float](repeating: 0, count: 10),
            detectedGenre: .unknown,
            recommendedEQ: [Float](repeating: 0, count: 10),
            dynamicRange: 0,
            averageLoudness: -23,
            noiseFloor: -60,
            needsDenoising: false,
            bassRatio: 0,
            trebleRatio: 0,
            vocalPresence: 0
        )
        
        // 创建 Hann 窗
        vDSP_hann_window(&windowBuffer, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // 创建 FFT 设置
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    
    func updateSampleRate(_ rate: Float) {
        lock.lock()
        defer { lock.unlock() }
        sampleRate = rate
    }
    
    /// 分析音频数据
    func analyze(_ buffer: UnsafePointer<Float>, frameCount: Int, channelCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        // 混合为单声道并填充分析缓冲区
        for i in 0..<frameCount {
            var sample: Float = 0
            if channelCount == 2 {
                sample = (buffer[i * 2] + buffer[i * 2 + 1]) * 0.5
            } else {
                sample = buffer[i]
            }
            
            analysisBuffer[bufferIndex] = sample
            bufferIndex = (bufferIndex + 1) % fftSize
            
            // 缓冲区满时执行分析
            if bufferIndex == 0 {
                performAnalysis()
            }
        }
    }
    
    private func performAnalysis() {
        guard let setup = fftSetup else { return }
        
        // 应用窗函数
        var windowedBuffer = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(analysisBuffer, 1, windowBuffer, 1, &windowedBuffer, 1, vDSP_Length(fftSize))
        
        // 准备 FFT 输入
        var realInput = [Float](repeating: 0, count: fftSize)
        var imagInput = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            realInput[i] = windowedBuffer[i]
        }
        
        // 执行 FFT
        vDSP_DFT_Execute(setup, &realInput, &imagInput, &realPart, &imagPart)
        
        // 计算幅度谱
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
        
        // 转换为 dB
        var one: Float = 1
        vDSP_vdbcon(magnitudes, 1, &one, &magnitudes, 1, vDSP_Length(fftSize / 2), 0)
        
        // 计算 10 段频谱能量
        let spectrum = calculateBandEnergy()
        
        // 更新历史
        spectrumHistory.append(spectrum)
        if spectrumHistory.count > historySize {
            spectrumHistory.removeFirst()
        }
        
        // 分析并更新结果
        updateAnalysisResult(spectrum: spectrum)
    }

    
    /// 计算 10 段频带能量
    private func calculateBandEnergy() -> [Float] {
        // 10 段中心频率对应的 FFT bin 范围
        let bandFreqs: [(low: Float, high: Float)] = [
            (20, 45),      // 32 Hz
            (45, 90),      // 64 Hz
            (90, 180),     // 125 Hz
            (180, 355),    // 250 Hz
            (355, 710),    // 500 Hz
            (710, 1400),   // 1 kHz
            (1400, 2800),  // 2 kHz
            (2800, 5600),  // 4 kHz
            (5600, 11200), // 8 kHz
            (11200, 20000) // 16 kHz
        ]
        
        var bandEnergy = [Float](repeating: -60, count: 10)
        let binWidth = sampleRate / Float(fftSize)
        
        for (i, band) in bandFreqs.enumerated() {
            let lowBin = Int(band.low / binWidth)
            let highBin = min(Int(band.high / binWidth), fftSize / 2 - 1)
            
            if lowBin < highBin {
                var sum: Float = 0
                vDSP_sve(Array(magnitudes[lowBin...highBin]), 1, &sum, vDSP_Length(highBin - lowBin + 1))
                bandEnergy[i] = sum / Float(highBin - lowBin + 1)
            }
        }
        
        return bandEnergy
    }
    
    /// 更新分析结果
    private func updateAnalysisResult(spectrum: [Float]) {
        // 计算低音/高音比例
        let bassEnergy = (spectrum[0] + spectrum[1] + spectrum[2]) / 3
        let midEnergy = (spectrum[3] + spectrum[4] + spectrum[5] + spectrum[6]) / 4
        let trebleEnergy = (spectrum[7] + spectrum[8] + spectrum[9]) / 3
        let totalEnergy = bassEnergy + midEnergy + trebleEnergy
        
        let bassRatio = totalEnergy > -180 ? (bassEnergy + 60) / (totalEnergy + 180) : 0.33
        let trebleRatio = totalEnergy > -180 ? (trebleEnergy + 60) / (totalEnergy + 180) : 0.33
        
        // 人声检测 (1-4kHz 区域能量)
        let vocalEnergy = (spectrum[5] + spectrum[6] + spectrum[7]) / 3
        let vocalPresence = min(1, max(0, (vocalEnergy + 40) / 40))
        
        // 检测音乐类型
        let genre = detectGenre(spectrum: spectrum, bassRatio: bassRatio, trebleRatio: trebleRatio, vocalPresence: vocalPresence)
        
        // 计算推荐 EQ
        let recommendedEQ = calculateRecommendedEQ(spectrum: spectrum, genre: genre)
        
        // 估计噪声水平
        updateNoiseEstimate(spectrum: spectrum)
        let noiseFloor = noiseEstimate.reduce(0, +) / Float(noiseEstimate.count)
        let needsDenoising = noiseFloor > -50
        
        // 计算动态范围
        var maxLevel: Float = -100
        var minLevel: Float = 0
        for s in spectrumHistory {
            let avg = s.reduce(0, +) / Float(s.count)
            maxLevel = max(maxLevel, avg)
            minLevel = min(minLevel, avg)
        }
        let dynamicRange = maxLevel - minLevel
        
        // 平均响度
        let averageLoudness = spectrum.reduce(0, +) / Float(spectrum.count)
        
        currentResult = AudioAnalysisResult(
            spectrumEnergy: spectrum,
            detectedGenre: genre,
            recommendedEQ: recommendedEQ,
            dynamicRange: dynamicRange,
            averageLoudness: averageLoudness,
            noiseFloor: noiseFloor,
            needsDenoising: needsDenoising,
            bassRatio: bassRatio,
            trebleRatio: trebleRatio,
            vocalPresence: vocalPresence
        )
    }

    
    /// 检测音乐类型
    private func detectGenre(spectrum: [Float], bassRatio: Float, trebleRatio: Float, vocalPresence: Float) -> DetectedGenre {
        // 基于频谱特征的简单分类
        
        // 电子音乐: 强低音 + 强高音
        if bassRatio > 0.4 && trebleRatio > 0.3 {
            return .electronic
        }
        
        // 嘻哈: 强低音 + 人声
        if bassRatio > 0.4 && vocalPresence > 0.5 {
            return .hiphop
        }
        
        // 摇滚: 中等低音 + 强中高频
        if bassRatio > 0.3 && spectrum[4] > -30 && spectrum[5] > -30 {
            return .rock
        }
        
        // 古典: 平衡频谱 + 高动态范围
        let variance = calculateSpectrumVariance(spectrum)
        if variance < 100 && currentResult.dynamicRange > 20 {
            return .classical
        }
        
        // 爵士: 中频丰富 + 人声
        if spectrum[4] > -25 && spectrum[5] > -25 && vocalPresence > 0.4 {
            return .jazz
        }
        
        // 人声为主
        if vocalPresence > 0.6 {
            return .vocal
        }
        
        // 原声: 中频为主，低高频较弱
        if bassRatio < 0.35 && trebleRatio < 0.35 {
            return .acoustic
        }
        
        // 默认流行
        if vocalPresence > 0.3 {
            return .pop
        }
        
        return .unknown
    }
    
    private func calculateSpectrumVariance(_ spectrum: [Float]) -> Float {
        let mean = spectrum.reduce(0, +) / Float(spectrum.count)
        var variance: Float = 0
        for s in spectrum {
            variance += (s - mean) * (s - mean)
        }
        return variance / Float(spectrum.count)
    }
    
    /// 计算推荐 EQ 设置
    private func calculateRecommendedEQ(spectrum: [Float], genre: DetectedGenre) -> [Float] {
        // 基础: 使用预设
        var eq = genre.recommendedPreset.gains
        
        // 智能调整: 补偿频谱不平衡
        let targetLevel: Float = -30 // 目标平均电平
        
        for i in 0..<10 {
            let diff = targetLevel - spectrum[i]
            // 限制调整范围
            let adjustment = max(-6, min(6, diff * 0.3))
            eq[i] = max(-12, min(12, eq[i] + adjustment))
        }
        
        return eq
    }
    
    /// 更新噪声估计 (使用最小值跟踪)
    private func updateNoiseEstimate(spectrum: [Float]) {
        noiseUpdateCount += 1
        
        for i in 0..<min(spectrum.count, noiseEstimate.count) {
            // 缓慢更新噪声估计 (取最小值)
            if spectrum[i] < noiseEstimate[i] {
                noiseEstimate[i] = spectrum[i]
            } else {
                // 缓慢上升
                noiseEstimate[i] = noiseEstimate[i] * 0.999 + spectrum[i] * 0.001
            }
        }
    }
}
