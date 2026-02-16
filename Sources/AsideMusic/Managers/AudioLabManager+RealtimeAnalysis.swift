// AudioLabManager+RealtimeAnalysis.swift
// AsideMusic
//
// 实时频谱分析（回退方案）：收集频谱数据、频段分析、BPM 估算、音色分析

import Foundation

extension AudioLabManager {
    
    // MARK: - 实时频谱分析（回退方案）
    
    /// 收集频谱数据（收集更多帧以获得稳定结果）
    func collectSpectrumData() async throws -> [Float] {
        let analyzer = PlayerManager.shared.spectrumAnalyzer
        analyzer.isEnabled = true
        
        var collectedSpectrums: [[Float]] = []
        let targetFrames = 100
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var frameCount = 0
            var hasResumed = false
            
            analyzer.onSpectrum = { magnitudes in
                collectedSpectrums.append(magnitudes)
                frameCount += 1
                if frameCount >= targetFrames && !hasResumed {
                    hasResumed = true
                    analyzer.onSpectrum = nil
                    continuation.resume()
                }
            }
            
            // 超时保护（5秒）
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !hasResumed {
                    hasResumed = true
                    analyzer.onSpectrum = nil
                    continuation.resume()
                }
            }
        }
        
        analyzer.isEnabled = false
        
        guard !collectedSpectrums.isEmpty else { return [] }
        
        // 计算平均频谱（去除最高和最低 10% 的异常值）
        let bandCount = collectedSpectrums[0].count
        var averageSpectrum = [Float](repeating: 0, count: bandCount)
        
        for bandIndex in 0..<bandCount {
            var bandValues: [Float] = []
            for spectrum in collectedSpectrums {
                if bandIndex < spectrum.count {
                    bandValues.append(spectrum[bandIndex])
                }
            }
            
            bandValues.sort()
            let trimCount = max(1, bandValues.count / 10)
            let trimmedValues = Array(bandValues.dropFirst(trimCount).dropLast(trimCount))
            
            if !trimmedValues.isEmpty {
                averageSpectrum[bandIndex] = trimmedValues.reduce(0, +) / Float(trimmedValues.count)
            }
        }
        
        return averageSpectrum
    }
    
    /// 基于频谱数据分析音频特征（回退方案）
    func analyzeFromSpectrum(spectrumData: [Float]) -> AudioAnalysisResult {
        let (lowRatio, midRatio, highRatio) = calculateFrequencyRatios(spectrum: spectrumData)
        let centroid = calculateSpectralCentroid(spectrum: spectrumData)
        let bpm = estimateBPMFromSpectrum(spectrum: spectrumData)
        let genre = inferGenre(lowRatio: lowRatio, midRatio: midRatio, highRatio: highRatio, centroid: centroid, bpm: bpm)
        let timbre = analyzeTimbreFromSpectrum(lowRatio: lowRatio, midRatio: midRatio, highRatio: highRatio, centroid: centroid)
        
        let recommendedEffects = generateRecommendedEffects(
            genre: genre,
            lowRatio: lowRatio,
            midRatio: midRatio,
            highRatio: highRatio,
            centroid: centroid,
            timbre: timbre
        )
        
        return AudioAnalysisResult(
            bpm: bpm,
            bpmConfidence: 0.6,
            loudness: -14.0,
            dynamicRange: 10.0,
            spectralCentroid: centroid,
            lowFrequencyRatio: lowRatio,
            midFrequencyRatio: midRatio,
            highFrequencyRatio: highRatio,
            suggestedGenre: genre,
            recommendedPresetId: getRecommendedPreset(for: genre),
            recommendedEffects: recommendedEffects,
            timbreAnalysis: timbre,
            qualityAssessment: nil
        )
    }

    /// 计算频段能量分布
    func calculateFrequencyRatios(spectrum: [Float]) -> (low: Float, mid: Float, high: Float) {
        guard !spectrum.isEmpty else { return (0.33, 0.34, 0.33) }
        
        let count = spectrum.count
        let lowEnd = count / 4
        let midEnd = count * 3 / 4
        
        var lowSum: Float = 0
        var midSum: Float = 0
        var highSum: Float = 0
        
        for i in 0..<count {
            let mag = spectrum[i] * spectrum[i]
            if i < lowEnd {
                lowSum += mag
            } else if i < midEnd {
                midSum += mag
            } else {
                highSum += mag
            }
        }
        
        let total = lowSum + midSum + highSum
        guard total > 0 else { return (0.33, 0.34, 0.33) }
        
        return (lowSum / total, midSum / total, highSum / total)
    }
    
    /// 计算频谱质心
    func calculateSpectralCentroid(spectrum: [Float]) -> Float {
        guard !spectrum.isEmpty else { return 1000 }
        
        let nyquist: Float = 22050
        let binWidth = nyquist / Float(spectrum.count)
        
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for (i, mag) in spectrum.enumerated() {
            let freq = Float(i) * binWidth
            weightedSum += freq * mag
            magnitudeSum += mag
        }
        
        guard magnitudeSum > 0 else { return 1000 }
        return weightedSum / magnitudeSum
    }
    
    /// 基于频谱估算 BPM
    func estimateBPMFromSpectrum(spectrum: [Float]) -> Float {
        let lowEnergy = spectrum.prefix(spectrum.count / 4).reduce(0, +)
        let totalEnergy = spectrum.reduce(0, +)
        let lowRatio = totalEnergy > 0 ? lowEnergy / totalEnergy : 0.3
        
        if lowRatio > 0.4 {
            return 128
        } else if lowRatio > 0.3 {
            return 110
        } else {
            return 85
        }
    }
    
    /// 推断音乐类型
    func inferGenre(lowRatio: Float, midRatio: Float, highRatio: Float, centroid: Float, bpm: Float) -> SuggestedGenre {
        if lowRatio > 0.4 && midRatio < 0.35 {
            return bpm > 120 ? .electronic : .hiphop
        }
        if midRatio > 0.45 {
            return centroid > 2000 ? .vocal : .acoustic
        }
        if highRatio > 0.35 {
            return centroid > 3000 ? .classical : .jazz
        }
        if bpm > 110 {
            return lowRatio > 0.35 ? .rock : .pop
        }
        if lowRatio > 0.35 && bpm < 100 {
            return .rnb
        }
        return .pop
    }

    /// 分析音色特征
    func analyzeTimbreFromSpectrum(lowRatio: Float, midRatio: Float, highRatio: Float, centroid: Float) -> TimbreInfo {
        let brightness = min(1.0, centroid / 4000.0)
        let warmth = min(1.0, lowRatio * 2.5)
        let clarity = min(1.0, highRatio * 3.0)
        let fullness = min(1.0, midRatio * 1.5)
        
        var descriptions: [String] = []
        if brightness > 0.7 { descriptions.append("明亮") }
        else if brightness < 0.3 { descriptions.append("暗淡") }
        if warmth > 0.6 { descriptions.append("温暖") }
        else if warmth < 0.3 { descriptions.append("单薄") }
        if clarity > 0.5 { descriptions.append("清晰") }
        if fullness > 0.6 { descriptions.append("丰满") }
        else if fullness < 0.3 { descriptions.append("空洞") }
        
        let description = descriptions.isEmpty ? "均衡" : descriptions.joined(separator: "、")
        
        var suggestions: [String] = []
        if warmth < 0.3 { suggestions.append("增加低频") }
        else if warmth > 0.7 { suggestions.append("降低低频") }
        if brightness < 0.3 { suggestions.append("增加高频") }
        else if brightness > 0.8 { suggestions.append("降低高频") }
        if fullness < 0.4 { suggestions.append("增加中频") }
        
        let eqSuggestion = suggestions.isEmpty ? "音色均衡" : suggestions.joined(separator: "；")
        
        return TimbreInfo(
            brightness: brightness,
            warmth: warmth,
            clarity: clarity,
            fullness: fullness,
            description: description,
            eqSuggestion: eqSuggestion
        )
    }
    
    /// 生成推荐的音效参数（实时分析版本）
    func generateRecommendedEffects(
        genre: SuggestedGenre,
        lowRatio: Float,
        midRatio: Float,
        highRatio: Float,
        centroid: Float,
        timbre: TimbreInfo
    ) -> RecommendedEffects {
        var eqGains: [Float] = Array(repeating: 0, count: 10)
        
        let idealLow: Float = 0.30
        let idealMid: Float = 0.40
        let idealHigh: Float = 0.30
        
        let lowDiff = idealLow - lowRatio
        let midDiff = idealMid - midRatio
        let highDiff = idealHigh - highRatio
        
        let lowBoost = lowDiff * 15
        eqGains[0] = clampGain(lowBoost * 0.8)
        eqGains[1] = clampGain(lowBoost * 1.0)
        eqGains[2] = clampGain(lowBoost * 0.9)
        eqGains[3] = clampGain(lowBoost * 0.3 + midDiff * 0.3)
        
        let midBoost = midDiff * 12
        eqGains[4] = clampGain(midBoost * 0.7)
        eqGains[5] = clampGain(midBoost * 1.0)
        eqGains[6] = clampGain(midBoost * 0.8)
        
        let highBoost = highDiff * 15
        eqGains[7] = clampGain(highBoost * 0.7)
        eqGains[8] = clampGain(highBoost * 1.0)
        eqGains[9] = clampGain(highBoost * 0.8)
        
        let centroidTarget: Float = 2000
        let brightnessAdjust = clampGain((centroidTarget - centroid) / 500)
        eqGains[7] += brightnessAdjust * 0.3
        eqGains[8] += brightnessAdjust * 0.5
        eqGains[9] += brightnessAdjust * 0.4
        
        for i in 0..<10 {
            eqGains[i] = clampGain(eqGains[i])
        }
        
        var bassGain: Float = lowDiff * 8
        var trebleGain: Float = highDiff * 8
        var surroundLevel: Float = 0.2 + lowRatio * 0.4
        var reverbLevel: Float = 0.1 + highRatio * 0.3
        let balance = 1.0 - abs(lowRatio - highRatio)
        var stereoWidth: Float = 1.0 + balance * 0.5
        let loudnormEnabled = false
        
        switch genre {
        case .electronic, .hiphop:
            bassGain += 2.0
            surroundLevel = min(1.0, surroundLevel + 0.15)
        case .classical, .jazz:
            surroundLevel = max(0.1, surroundLevel - 0.1)
            reverbLevel = min(0.5, reverbLevel + 0.15)
            stereoWidth = min(1.5, stereoWidth)
        case .rock, .metal:
            trebleGain += 1.5
            surroundLevel = min(1.0, surroundLevel + 0.1)
        case .vocal, .acoustic:
            surroundLevel = max(0.1, surroundLevel - 0.15)
            reverbLevel = max(0.05, reverbLevel - 0.1)
        default:
            break
        }
        
        return RecommendedEffects.defaultNewFilters(
            bassGain: clampGain(bassGain),
            trebleGain: clampGain(trebleGain),
            surroundLevel: max(0, min(1, surroundLevel)),
            reverbLevel: max(0, min(1, reverbLevel)),
            stereoWidth: max(0.5, min(2, stereoWidth)),
            loudnormEnabled: loudnormEnabled,
            eqGains: eqGains
        )
    }
}
